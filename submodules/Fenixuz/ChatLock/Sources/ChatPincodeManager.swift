import Foundation
import Security
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
    }

    public func isLocked(_ peerId: PeerId) -> Bool {
        return self.readPassword(account: self.account(for: peerId)) != nil
    }

    public func verify(_ code: String, for peerId: PeerId) -> Bool {
        guard let stored = self.readPassword(account: self.account(for: peerId)) else {
            return false
        }
        // Constant-time compare to avoid timing side channels.
        return constantTimeEquals(stored, code)
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
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        if SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary) == errSecSuccess {
            return
        }
        var addQuery = self.basePasswordQuery(account: account)
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        _ = SecItemAdd(addQuery as CFDictionary, nil)
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
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(ChatLockMetadata.self, from: data)
    }

    private func writeMetadata(_ metadata: ChatLockMetadata, account: String) {
        guard let data = try? JSONEncoder().encode(metadata) else { return }

        let updateQuery = self.baseMetadataQuery(account: account)
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        if SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary) == errSecSuccess {
            return
        }
        var addQuery = self.baseMetadataQuery(account: account)
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        _ = SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func deleteMetadata(account: String) {
        _ = SecItemDelete(self.baseMetadataQuery(account: account) as CFDictionary)
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
