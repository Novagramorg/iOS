import Foundation
import Security
import TONWalletKit

final class WalletTonConnectStorage: TONWalletKitStorage {
    enum Error: Swift.Error {
        case keychainStatus(OSStatus)
        case invalidValue
    }

    private let service: String

    init(namespace: String) {
        self.service = "org.telegram.ton-wallet.ton-connect.\(namespace)"
    }

    func set(key: String, value: String) async throws {
        guard let data = value.data(using: .utf8) else {
            throw Error.invalidValue
        }

        let query = self.query(key: key)
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw Error.keychainStatus(updateStatus)
        }

        var addQuery = query
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        addQuery[kSecValueData as String] = data
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw Error.keychainStatus(addStatus)
        }
    }

    func get(key: String) async throws -> String? {
        var query = self.query(key: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw Error.keychainStatus(status)
        }
        guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
            throw Error.invalidValue
        }
        return value
    }

    func remove(key: String) async throws {
        let status = SecItemDelete(self.query(key: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw Error.keychainStatus(status)
        }
    }

    func clear() async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw Error.keychainStatus(status)
        }
    }

    private func query(key: String) -> [String: Any] {
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: key
        ]
    }
}

func fatalStorageError(_ error: WalletTonConnectStorage.Error) -> WalletContext.FatalStorageError {
    switch error {
    case let .keychainStatus(status):
        return .keychainStatus(status)
    case .invalidValue:
        return .corrupted
    }
}
