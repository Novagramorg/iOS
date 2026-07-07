import Foundation
import Security
import CryptoKit
import Postbox

// Keychain service identifier — picks up our own bundle's namespace so
// extensions cannot accidentally read this app's pincodes.
private let keychainService = "uz.fenixuz.app.ChatLock"

// Second keychain service for per-peer metadata (password type + biometric flag).
// Kept separate so legacy password items are never accidentally corrupted.
private let metadataService = "uz.fenixuz.app.ChatLock.meta"

// Legacy UserDefaults location — only read once at startup, then deleted.
private let legacyDefaultsKey = "chat_pincode_map"
private let legacyMigrationDoneKey = "chat_pincode_migration_done"

// Fallback store (UserDefaults) — engaged only when the keychain rejects writes in the
// current build. Fake-codesigned dev/simulator builds carry no keychain entitlements
// (no application-identifier / keychain-access-groups), so securityd fails every SecItem
// call with errSecMissingEntitlement (-34018) and the lock silently never engages.
// The credential is stored as a salted SHA-256 hash here — never plaintext.
private let fallbackSaltKey = "fenixuz_chatlock_fb_salt"
private let fallbackPasswordKeyPrefix = "fenixuz_chatlock_fb_pw_"
private let fallbackMetadataKeyPrefix = "fenixuz_chatlock_fb_meta_"

// MARK: - Password type

/// The credential variant chosen by the user for a given chat.
public enum ChatLockPasswordType: String, Codable {
    /// Classic 4-digit numeric PIN (original behaviour).
    case pin
    /// Alphanumeric password of any length ≥ 1.
    case text
}

// MARK: - Per-peer metadata

/// Stored alongside the credential to capture user-chosen options.
public struct ChatLockMetadata: Codable {
    /// Which entry mode the user chose.
    public var passwordType: ChatLockPasswordType
    /// Whether the user opted in to biometric unlock for this chat.
    public var biometricEnabled: Bool

    public init(passwordType: ChatLockPasswordType, biometricEnabled: Bool) {
        self.passwordType = passwordType
        self.biometricEnabled = biometricEnabled
    }

    // Default for chats that were locked before this feature existed (legacy PIN).
    public static let defaultLegacy = ChatLockMetadata(passwordType: .pin, biometricEnabled: false)
}

// MARK: - Manager

public final class ChatPincodeManager {
    public static let shared = ChatPincodeManager()

    private let lock = NSLock()
    private var hasMigratedLegacy = false

    private init() {
        self.migrateLegacyIfNeeded()
    }

    // MARK: - Public credential API

    public func getPincode(for peerId: PeerId) -> String? {
        return self.readPassword(account: self.account(for: peerId))
    }

    /// Store a credential together with its options.
    public func setPincode(
        _ code: String,
        for peerId: PeerId,
        type: ChatLockPasswordType = .pin,
        biometricEnabled: Bool = false
    ) {
        let key = self.account(for: peerId)
        self.writePassword(code, account: key)
        self.writeMetadata(ChatLockMetadata(passwordType: type, biometricEnabled: biometricEnabled), account: key)
    }

    public func removePincode(for peerId: PeerId) {
        let key = self.account(for: peerId)
        self.deletePassword(account: key)
        self.deleteMetadata(account: key)
        self.deleteFallbackPassword(account: key)
        self.deleteFallbackMetadata(account: key)
    }

    public func isLocked(_ peerId: PeerId) -> Bool {
        let key = self.account(for: peerId)
        return self.readPassword(account: key) != nil || self.readFallbackPasswordHash(account: key) != nil
    }

    public func verify(_ code: String, for peerId: PeerId) -> Bool {
        let key = self.account(for: peerId)
        if let stored = self.readPassword(account: key) {
            // Constant-time compare to avoid timing side channels.
            return constantTimeEquals(stored, code)
        }
        if let storedHash = self.readFallbackPasswordHash(account: key) {
            return constantTimeEquals(storedHash, self.fallbackHash(of: code))
        }
        return false
    }

    // MARK: - Metadata API

    public func getMetadata(for peerId: PeerId) -> ChatLockMetadata {
        return self.readMetadata(account: self.account(for: peerId)) ?? .defaultLegacy
    }

    /// Update only the biometric flag without changing the stored credential.
    public func setBiometricEnabled(_ enabled: Bool, for peerId: PeerId) {
        let key = self.account(for: peerId)
        var meta = self.readMetadata(account: key) ?? .defaultLegacy
        meta.biometricEnabled = enabled
        self.writeMetadata(meta, account: key)
    }

    // MARK: - Master pincode API
    //
    // The "master" is one global credential that (a) gates whether the per-chat
    // lock feature is available at all, and (b) acts as a recovery key
    // ("Forgot pincode?") to clear a single chat's lock. It reuses the same
    // keychain + salted-hash fallback plumbing as per-chat credentials, stored
    // under a reserved account key that can never collide with a numeric
    // peerId.toInt64().
    private let masterAccount = "__fenix_master__"

    /// True when a master pincode has been set (i.e. the chat-lock feature is on).
    public func isMasterEnabled() -> Bool {
        return self.readPassword(account: self.masterAccount) != nil
            || self.readFallbackPasswordHash(account: self.masterAccount) != nil
    }

    /// Store the master credential together with its options.
    public func setMasterPincode(_ code: String, type: ChatLockPasswordType = .pin, biometricEnabled: Bool = false) {
        self.writePassword(code, account: self.masterAccount)
        self.writeMetadata(ChatLockMetadata(passwordType: type, biometricEnabled: biometricEnabled), account: self.masterAccount)
    }

    /// Verify a candidate against the stored master credential (constant-time).
    public func verifyMaster(_ code: String) -> Bool {
        if let stored = self.readPassword(account: self.masterAccount) {
            return constantTimeEquals(stored, code)
        }
        if let storedHash = self.readFallbackPasswordHash(account: self.masterAccount) {
            return constantTimeEquals(storedHash, self.fallbackHash(of: code))
        }
        return false
    }

    /// Master credential options (password type + biometric flag).
    public func getMasterMetadata() -> ChatLockMetadata {
        return self.readMetadata(account: self.masterAccount) ?? .defaultLegacy
    }

    /// Remove only the master credential (leaves per-chat locks in place).
    public func removeMaster() {
        self.deletePassword(account: self.masterAccount)
        self.deleteMetadata(account: self.masterAccount)
        self.deleteFallbackPassword(account: self.masterAccount)
        self.deleteFallbackMetadata(account: self.masterAccount)
    }

    /// Turn the whole chat-lock feature off: wipe the master AND every per-chat
    /// credential so nothing is stranded and re-enabling later starts clean.
    public func disableChatLock() {
        // The Secret Vault credential lives under the same keychain services but a
        // separate account; it is an independent feature, so snapshot it before the
        // service-wide sweep and put it back afterwards. Turning ChatLock off must
        // never disable the vault.
        let vaultPassword = self.readPassword(account: self.vaultAccount)
        let vaultFallbackHash = vaultPassword == nil ? self.readFallbackPasswordHash(account: self.vaultAccount) : nil
        let vaultMetadata = self.readMetadata(account: self.vaultAccount)

        // Keychain: drop every item under both of our services in one sweep.
        for service in [keychainService, metadataService] {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service
            ]
            _ = SecItemDelete(query as CFDictionary)
        }
        // UserDefaults fallback: remove every per-account password/metadata key.
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys
        where key.hasPrefix(fallbackPasswordKeyPrefix) || key.hasPrefix(fallbackMetadataKeyPrefix) {
            defaults.removeObject(forKey: key)
        }

        // Restore the vault credential if one existed before the sweep.
        if let vaultPassword {
            self.writePassword(vaultPassword, account: self.vaultAccount)
        } else if let vaultFallbackHash {
            UserDefaults.standard.set(vaultFallbackHash, forKey: fallbackPasswordKeyPrefix + self.vaultAccount)
        }
        if let vaultMetadata {
            self.writeMetadata(vaultMetadata, account: self.vaultAccount)
        }
    }

    // MARK: - Secret Vault pincode API
    //
    // The vault credential gates the hidden-chats "Secret Vault" feature. It is
    // fully independent from the master / per-chat locks (its own reserved account
    // key), but reuses the same keychain + salted-hash fallback plumbing so the
    // Secret Vault module never has to duplicate the Security-framework code.
    private let vaultAccount = "__fenix_vault__"

    /// True when a vault pincode has been set (i.e. the Secret Vault feature is on).
    public func isVaultEnabled() -> Bool {
        return self.readPassword(account: self.vaultAccount) != nil
            || self.readFallbackPasswordHash(account: self.vaultAccount) != nil
    }

    /// Store the vault credential together with its options.
    public func setVaultPincode(_ code: String, type: ChatLockPasswordType = .pin, biometricEnabled: Bool = false) {
        self.writePassword(code, account: self.vaultAccount)
        self.writeMetadata(ChatLockMetadata(passwordType: type, biometricEnabled: biometricEnabled), account: self.vaultAccount)
    }

    /// Verify a candidate against the stored vault credential (constant-time).
    public func verifyVault(_ code: String) -> Bool {
        if let stored = self.readPassword(account: self.vaultAccount) {
            return constantTimeEquals(stored, code)
        }
        if let storedHash = self.readFallbackPasswordHash(account: self.vaultAccount) {
            return constantTimeEquals(storedHash, self.fallbackHash(of: code))
        }
        return false
    }

    /// Vault credential options (password type + biometric flag).
    public func getVaultMetadata() -> ChatLockMetadata {
        return self.readMetadata(account: self.vaultAccount) ?? .defaultLegacy
    }

    /// Update only the vault biometric flag without touching the stored credential.
    /// Mirrors setBiometricEnabled(_:for:) but targets the reserved vault account.
    public func setVaultBiometricEnabled(_ enabled: Bool) {
        var meta = self.readMetadata(account: self.vaultAccount) ?? .defaultLegacy
        meta.biometricEnabled = enabled
        self.writeMetadata(meta, account: self.vaultAccount)
    }

    /// Remove the vault credential (turns the Secret Vault feature off). Leaves the
    /// vaulted-peer set untouched — the caller decides whether to also clear it.
    public func removeVault() {
        self.deletePassword(account: self.vaultAccount)
        self.deleteMetadata(account: self.vaultAccount)
        self.deleteFallbackPassword(account: self.vaultAccount)
        self.deleteFallbackMetadata(account: self.vaultAccount)
    }

    // MARK: - Keychain account key

    private func account(for peerId: PeerId) -> String {
        return "\(peerId.toInt64())"
    }

    // MARK: - Password keychain plumbing

    private func basePasswordQuery(account: String) -> [String: Any] {
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
    }

    private func readPassword(account: String) -> String? {
        var query = self.basePasswordQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return nil }
        return value
    }

    private func writePassword(_ value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }

        let updateQuery = self.basePasswordQuery(account: account)
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        if SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary) == errSecSuccess {
            self.deleteFallbackPassword(account: account)
            return
        }
        var addQuery = self.basePasswordQuery(account: account)
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        if SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess {
            self.deleteFallbackPassword(account: account)
        } else {
            // Keychain rejected the write (dev/simulator builds get -34018
            // errSecMissingEntitlement) — persist a salted hash instead so the
            // lock still engages rather than silently failing open.
            self.writeFallbackPassword(value, account: account)
        }
    }

    private func deletePassword(account: String) {
        _ = SecItemDelete(self.basePasswordQuery(account: account) as CFDictionary)
    }

    // MARK: - Metadata keychain plumbing

    private func baseMetadataQuery(account: String) -> [String: Any] {
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: metadataService,
            kSecAttrAccount as String: account
        ]
    }

    private func readMetadata(account: String) -> ChatLockMetadata? {
        var query = self.baseMetadataQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data {
            return try? JSONDecoder().decode(ChatLockMetadata.self, from: data)
        }
        // Keychain miss — check the fallback store (metadata is not secret: type + flag).
        if let data = UserDefaults.standard.data(forKey: fallbackMetadataKeyPrefix + account) {
            return try? JSONDecoder().decode(ChatLockMetadata.self, from: data)
        }
        return nil
    }

    private func writeMetadata(_ metadata: ChatLockMetadata, account: String) {
        guard let data = try? JSONEncoder().encode(metadata) else { return }

        let updateQuery = self.baseMetadataQuery(account: account)
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        if SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary) == errSecSuccess {
            self.deleteFallbackMetadata(account: account)
            return
        }
        var addQuery = self.baseMetadataQuery(account: account)
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        if SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess {
            self.deleteFallbackMetadata(account: account)
        } else {
            // Same keychain-unavailable case as writePassword — keep type/biometric
            // choices working on dev/simulator builds.
            UserDefaults.standard.set(data, forKey: fallbackMetadataKeyPrefix + account)
        }
    }

    private func deleteMetadata(account: String) {
        _ = SecItemDelete(self.baseMetadataQuery(account: account) as CFDictionary)
    }

    // MARK: - UserDefaults fallback (keychain-unavailable builds)

    private let saltLock = NSLock()

    /// Per-install random salt for the fallback hash. Created lazily on first use.
    private func fallbackSalt() -> String {
        self.saltLock.lock()
        defer { self.saltLock.unlock() }

        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: fallbackSaltKey) {
            return existing
        }
        var bytes = [UInt8](repeating: 0, count: 32)
        if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) != errSecSuccess {
            for i in 0..<bytes.count {
                bytes[i] = UInt8.random(in: .min ... .max)
            }
        }
        let salt = Data(bytes).base64EncodedString()
        defaults.set(salt, forKey: fallbackSaltKey)
        return salt
    }

    private func fallbackHash(of code: String) -> String {
        let payload = Data((self.fallbackSalt() + code).utf8)
        return SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
    }

    private func writeFallbackPassword(_ value: String, account: String) {
        UserDefaults.standard.set(self.fallbackHash(of: value), forKey: fallbackPasswordKeyPrefix + account)
    }

    private func readFallbackPasswordHash(account: String) -> String? {
        return UserDefaults.standard.string(forKey: fallbackPasswordKeyPrefix + account)
    }

    private func deleteFallbackPassword(account: String) {
        UserDefaults.standard.removeObject(forKey: fallbackPasswordKeyPrefix + account)
    }

    private func deleteFallbackMetadata(account: String) {
        UserDefaults.standard.removeObject(forKey: fallbackMetadataKeyPrefix + account)
    }

    // MARK: - One-time legacy migration

    private func migrateLegacyIfNeeded() {
        self.lock.lock()
        defer { self.lock.unlock() }

        if self.hasMigratedLegacy { return }
        self.hasMigratedLegacy = true

        let defaults = UserDefaults.standard
        if defaults.bool(forKey: legacyMigrationDoneKey) { return }

        // Read whatever may still be living in plaintext.
        if let legacy = defaults.dictionary(forKey: legacyDefaultsKey) as? [String: String] {
            for (account, code) in legacy where !code.isEmpty {
                self.writePassword(code, account: account)
                // Legacy entries had no metadata — write the default (PIN, no biometrics).
                self.writeMetadata(.defaultLegacy, account: account)
            }
        }

        defaults.removeObject(forKey: legacyDefaultsKey)
        defaults.set(true, forKey: legacyMigrationDoneKey)
    }
}

// MARK: - Constant-time string compare

private func constantTimeEquals(_ a: String, _ b: String) -> Bool {
    let aBytes = Array(a.utf8)
    let bBytes = Array(b.utf8)
    guard aBytes.count == bBytes.count else { return false }
    var diff: UInt8 = 0
    for i in 0..<aBytes.count {
        diff |= aBytes[i] ^ bBytes[i]
    }
    return diff == 0
}
