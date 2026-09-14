import Foundation
import CryptoKit
import Security
import PasscodeCore

public struct WalletSecretEnvelope: Codable, Equatable, Sendable {
    public let version: Int
    public let vaultId: String
    public let secretId: String
    public let wrappedDek: Data
    public let ciphertext: Data

    public static func encrypt(_ secret: Data, vaultId: String, access: PasscodeSession) throws -> WalletSecretEnvelope {
        guard !secret.isEmpty, !vaultId.isEmpty else { throw PasscodeError.corrupted }
        let secretId = UUID().uuidString
        var dek = try random(32)
        defer { dek.resetBytes(in: 0 ..< dek.count) }
        return try access.withDerivedKey(namespace: vaultId, domain: "telegram.wallet.dek.v1") { key in
            WalletSecretEnvelope(version: 1, vaultId: vaultId, secretId: secretId,
                wrappedDek: try seal(dek, key: key, context: "dek.v1:\(vaultId):\(secretId)"),
                ciphertext: try seal(secret, key: dek, context: "secret.v1:\(vaultId):\(secretId)"))
        }
    }

    public func decrypt(vaultId: String, access: PasscodeSession) throws -> Data {
        guard self.version == 1, self.vaultId == vaultId, !self.secretId.isEmpty else { throw PasscodeError.corrupted }
        return try access.withDerivedKey(namespace: vaultId, domain: "telegram.wallet.dek.v1") { key in
            var dek = try Self.open(self.wrappedDek, key: key, context: "dek.v1:\(vaultId):\(self.secretId)")
            defer { dek.resetBytes(in: 0 ..< dek.count) }
            return try Self.open(self.ciphertext, key: dek, context: "secret.v1:\(vaultId):\(self.secretId)")
        }
    }

    private static func random(_ count: Int) throws -> Data {
        var bytes = Data(count: count)
        let status = bytes.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!) }
        guard status == errSecSuccess else { throw PasscodeError.keychain(status) }
        return bytes
    }

    private static func seal(_ data: Data, key: Data, context: String) throws -> Data {
        guard key.count == 32 else { throw PasscodeError.corrupted }
        let nonce = try AES.GCM.Nonce(data: random(12))
        guard let result = try AES.GCM.seal(data, using: SymmetricKey(data: key), nonce: nonce, authenticating: Data(context.utf8)).combined else {
            throw PasscodeError.corrupted
        }
        return result
    }

    private static func open(_ data: Data, key: Data, context: String) throws -> Data {
        guard key.count == 32, data.count >= 28 else { throw PasscodeError.corrupted }
        do {
            return try AES.GCM.open(AES.GCM.SealedBox(combined: data), using: SymmetricKey(data: key), authenticating: Data(context.utf8))
        } catch {
            throw PasscodeError.corrupted
        }
    }
}

protocol WalletVaultStorage {
    func read(service: String, account: String) throws -> Data?
    func insert(_ data: Data, service: String, account: String) throws
    func remove(service: String, account: String) throws
}

struct WalletVaultMigrator {
    let storage: WalletVaultStorage

    func migrate(namespace: String, account: String, access: () throws -> PasscodeSession) throws {
        let oldService = WalletVault.legacyPrefix + namespace
        guard var secret = try self.storage.read(service: oldService, account: account) else { return }
        defer { secret.resetBytes(in: 0 ..< secret.count) }
        let access = try access()
        let newService = WalletVault.service(namespace: namespace)
        if try self.storage.read(service: newService, account: account) == nil {
            let envelope = try WalletSecretEnvelope.encrypt(secret, vaultId: namespace, access: access)
            try self.storage.insert(JSONEncoder().encode(envelope), service: newService, account: account)
        }
        guard let saved = try self.storage.read(service: newService, account: account),
              let envelope = try? JSONDecoder().decode(WalletSecretEnvelope.self, from: saved),
              try envelope.decrypt(vaultId: namespace, access: access) == secret else { throw PasscodeError.corrupted }
        try self.storage.remove(service: oldService, account: account)
    }
}

private struct WalletVaultKeychain: WalletVaultStorage {
    func read(service: String, account: String) throws -> Data? { try WalletVault.read(service: service, account: account) }

    func insert(_ data: Data, service: String, account: String) throws {
        var query = try WalletVault.query(service: service, account: account)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        query[kSecValueData as String] = data
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw PasscodeError.keychain(status) }
    }

    func remove(service: String, account: String) throws {
        let status = SecItemDelete(try WalletVault.query(service: service, account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw PasscodeError.keychain(status) }
    }
}

enum WalletVault {
    static let legacyPrefix = "org.telegram.ton-wallet.engine.v2.secret."
    private static let prefix = "org.telegram.ton-wallet.vault.v1.envelope."
    private static let migrationLock = NSRecursiveLock()

    static func service(namespace: String) -> String { self.prefix + namespace }

    static func keychainAccessGroup() throws -> String {
        return try PasscodeEnvironment.shared.privateAccessGroup()
    }

    static func access(namespace: String) throws -> PasscodeSession {
        if let session = WalletAuthorizationScope.session {
            try PasscodeCredentialStore.shared.validate(session, scope: .resource(namespace: namespace))
            return session
        }
        return try PasscodeCredentialStore.shared.unprotectedSession(namespace: namespace)
    }

    static func encrypt(_ data: Data, namespace: String) throws -> Data {
        let access = try self.access(namespace: namespace)
        return try JSONEncoder().encode(WalletSecretEnvelope.encrypt(data, vaultId: namespace, access: access))
    }

    static func decrypt(_ data: Data, namespace: String) throws -> Data {
        let access = try self.access(namespace: namespace)
        guard let envelope = try? JSONDecoder().decode(WalletSecretEnvelope.self, from: data) else { throw PasscodeError.corrupted }
        return try envelope.decrypt(vaultId: namespace, access: access)
    }

    fileprivate static func query(service: String, account: String) throws -> [String: Any] {
        return [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
            kSecAttrAccount as String: account, kSecAttrSynchronizable as String: false,
            kSecAttrAccessGroup as String: try self.keychainAccessGroup()]
    }

    fileprivate static func read(service: String, account: String) throws -> Data? {
        var query = try self.query(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &value)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = value as? Data else { throw PasscodeError.keychain(status) }
        return data
    }

    static func migrate(namespace: String, account: String) throws {
        self.migrationLock.lock(); defer { self.migrationLock.unlock() }
        try WalletVaultMigrator(storage: WalletVaultKeychain()).migrate(namespace: namespace, account: account) {
            try self.access(namespace: namespace)
        }
    }

    static func removeLegacy(namespace: String, account: String) throws {
        let status = SecItemDelete(try self.query(service: self.legacyPrefix + namespace, account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw PasscodeError.keychain(status) }
    }

    static func removeAll(environment: PasscodeEnvironment = .shared) throws {
        try self.removeAll(environment: environment, readAttributes: { query in
            var result: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            return (status, result)
        }, delete: { query in SecItemDelete(query as CFDictionary) })
    }

    static func removeAll(environment: PasscodeEnvironment, readAttributes: ([String: Any]) -> (OSStatus, CFTypeRef?), delete: ([String: Any]) -> OSStatus) throws {
        let group = try environment.privateAccessGroup()
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecReturnAttributes as String: true, kSecMatchLimit as String: kSecMatchLimitAll,
            kSecAttrSynchronizable as String: false, kSecAttrAccessGroup as String: group]
        let (status, result) = readAttributes(query)
        if status == errSecItemNotFound { return }
        guard status == errSecSuccess, let items = result as? [[String: Any]] else { throw PasscodeError.keychain(status) }
        for item in items {
            guard let service = item[kSecAttrService as String] as? String,
                  service.hasPrefix("org.telegram.ton-wallet."),
                  let account = item[kSecAttrAccount as String] as? String else { continue }
            let deletion: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service, kSecAttrAccount as String: account,
                kSecAttrSynchronizable as String: false, kSecAttrAccessGroup as String: group]
            let status = delete(deletion)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw PasscodeError.keychain(status) }
        }
    }

    static func migrateAll() throws {
        self.migrationLock.lock(); defer { self.migrationLock.unlock() }
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecReturnAttributes as String: true, kSecMatchLimit as String: kSecMatchLimitAll,
            kSecAttrSynchronizable as String: false]
        query[kSecAttrAccessGroup as String] = try self.keychainAccessGroup()
        var value: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &value)
        if status == errSecItemNotFound { return }
        guard status == errSecSuccess, let items = value as? [[String: Any]] else { throw PasscodeError.keychain(status) }
        for item in items {
            guard let service = item[kSecAttrService as String] as? String, service.hasPrefix(self.legacyPrefix),
                  let account = item[kSecAttrAccount as String] as? String else { continue }
            try self.migrate(namespace: String(service.dropFirst(self.legacyPrefix.count)), account: account)
        }
    }
}
