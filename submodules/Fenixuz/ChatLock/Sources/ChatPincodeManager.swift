import Foundation
import Security
import Postbox

// Keychain service identifier — picks up our own bundle's namespace so
// extensions cannot accidentally read this app's pincodes.
private let keychainService = "uz.fenixuz.app.ChatLock"

// Legacy UserDefaults location — only read once at startup, then deleted.
private let legacyDefaultsKey = "chat_pincode_map"
private let legacyMigrationDoneKey = "chat_pincode_migration_done"

public final class ChatPincodeManager {
    public static let shared = ChatPincodeManager()

    private let lock = NSLock()
    private var hasMigratedLegacy = false

    private init() {
        self.migrateLegacyIfNeeded()
    }

    // MARK: - Public API

    public func getPincode(for peerId: PeerId) -> String? {
        return self.read(account: self.account(for: peerId))
    }

    public func setPincode(_ code: String, for peerId: PeerId) {
        self.write(code, account: self.account(for: peerId))
    }

    public func removePincode(for peerId: PeerId) {
        self.delete(account: self.account(for: peerId))
    }

    public func isLocked(_ peerId: PeerId) -> Bool {
        return self.read(account: self.account(for: peerId)) != nil
    }

    public func verify(_ code: String, for peerId: PeerId) -> Bool {
        guard let stored = self.read(account: self.account(for: peerId)) else {
            return false
        }
        // Constant-time compare to avoid timing side channels.
        return constantTimeEquals(stored, code)
    }

    // MARK: - Keychain plumbing

    private func account(for peerId: PeerId) -> String {
        return "\(peerId.toInt64())"
    }

    private func baseQuery(account: String) -> [String: Any] {
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
    }

    private func read(account: String) -> String? {
        var query = self.baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data, let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    private func write(_ value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }

        // Try update first.
        let updateQuery = self.baseQuery(account: account)
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        // No existing item — add a fresh one.
        var addQuery = self.baseQuery(account: account)
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        _ = SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func delete(account: String) {
        let query = self.baseQuery(account: account)
        _ = SecItemDelete(query as CFDictionary)
    }

    // MARK: - One-time legacy migration

    private func migrateLegacyIfNeeded() {
        self.lock.lock()
        defer { self.lock.unlock() }

        if self.hasMigratedLegacy {
            return
        }
        self.hasMigratedLegacy = true

        let defaults = UserDefaults.standard
        if defaults.bool(forKey: legacyMigrationDoneKey) {
            return
        }

        // Read whatever may still be living in plaintext.
        if let legacy = defaults.dictionary(forKey: legacyDefaultsKey) as? [String: String] {
            for (account, code) in legacy {
                if !code.isEmpty {
                    self.write(code, account: account)
                }
            }
        }

        // Delete the plaintext copy so it never lingers.
        defaults.removeObject(forKey: legacyDefaultsKey)
        defaults.set(true, forKey: legacyMigrationDoneKey)
    }
}

// MARK: - Constant-time string compare

private func constantTimeEquals(_ a: String, _ b: String) -> Bool {
    let aBytes = Array(a.utf8)
    let bBytes = Array(b.utf8)
    if aBytes.count != bBytes.count {
        return false
    }
    var diff: UInt8 = 0
    for i in 0..<aBytes.count {
        diff |= aBytes[i] ^ bBytes[i]
    }
    return diff == 0
}
