import Foundation
import Security
import TONCrypto

extension WalletContext {
    struct PendingKeyRotation: Codable, Equatable {
        let words: [String]
        let publicKey: String
        let boc: String
        let normalizedHash: String
        let validUntil: Int32
    }

    struct SecretRecord: Codable {
        let schemaVersion: Int
        let words: [String]
        let walletVersion: WalletVersion
        let network: String
        let walletId: Int?
        let workchain: Int?
        let address: String
        let publicKey: String
        let originalPublicKey: String?
        let pendingKeyRotation: PendingKeyRotation?

        init(
            schemaVersion: Int,
            words: [String],
            walletVersion: WalletVersion,
            network: String,
            walletId: Int?,
            workchain: Int?,
            address: String,
            publicKey: String,
            originalPublicKey: String? = nil,
            pendingKeyRotation: PendingKeyRotation? = nil
        ) {
            self.schemaVersion = schemaVersion
            self.words = words
            self.walletVersion = walletVersion
            self.network = network
            self.walletId = walletId
            self.workchain = workchain
            self.address = address
            self.publicKey = publicKey
            self.originalPublicKey = originalPublicKey
            self.pendingKeyRotation = pendingKeyRotation
        }
    }

    struct MetadataRecord: Codable, Equatable {
        var schemaVersion: Int
        var pendingTransfers: [PendingTransfer]
        var balance: Int64?
        var balanceUpdatedAt: Int32?
        var fiatRates: [FiatCurrency: FiatRate]?
        var fiatRatesUpdatedAt: Int32?
        var selectedFiatCurrency: FiatCurrency?
        var transactions: [Transaction]?
        var collectibles: [Collectible]?

        init(
            schemaVersion: Int,
            pendingTransfers: [PendingTransfer],
            balance: Int64? = nil,
            balanceUpdatedAt: Int32? = nil,
            fiatRates: [FiatCurrency: FiatRate]? = nil,
            fiatRatesUpdatedAt: Int32? = nil,
            selectedFiatCurrency: FiatCurrency? = nil,
            transactions: [Transaction]? = nil,
            collectibles: [Collectible]? = nil
        ) {
            self.schemaVersion = schemaVersion
            self.pendingTransfers = pendingTransfers
            self.balance = balance
            self.balanceUpdatedAt = balanceUpdatedAt
            self.fiatRates = fiatRates
            self.fiatRatesUpdatedAt = fiatRatesUpdatedAt
            self.selectedFiatCurrency = selectedFiatCurrency
            self.transactions = transactions
            self.collectibles = collectibles
        }

        private enum CodingKeys: String, CodingKey {
            case schemaVersion
            case pendingTransfers
            case balance
            case balanceUpdatedAt
            case fiatRates
            case fiatRatesUpdatedAt
            case selectedFiatCurrency
            case transactions
            case collectibles
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
            self.pendingTransfers = try container.decode([PendingTransfer].self, forKey: .pendingTransfers)
            self.balance = try? container.decode(Int64.self, forKey: .balance)
            self.balanceUpdatedAt = try? container.decode(Int32.self, forKey: .balanceUpdatedAt)
            self.fiatRates = try? container.decode([FiatCurrency: FiatRate].self, forKey: .fiatRates)
            self.fiatRatesUpdatedAt = try? container.decode(Int32.self, forKey: .fiatRatesUpdatedAt)
            self.selectedFiatCurrency = try? container.decode(FiatCurrency.self, forKey: .selectedFiatCurrency)
            self.transactions = try? container.decode([Transaction].self, forKey: .transactions)
            self.collectibles = try? container.decode([Collectible].self, forKey: .collectibles)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.schemaVersion, forKey: .schemaVersion)
            try container.encode(self.pendingTransfers, forKey: .pendingTransfers)
            try container.encodeIfPresent(self.balance, forKey: .balance)
            try container.encodeIfPresent(self.balanceUpdatedAt, forKey: .balanceUpdatedAt)
            try container.encodeIfPresent(self.fiatRates, forKey: .fiatRates)
            try container.encodeIfPresent(self.fiatRatesUpdatedAt, forKey: .fiatRatesUpdatedAt)
            try container.encodeIfPresent(self.selectedFiatCurrency, forKey: .selectedFiatCurrency)
            try container.encodeIfPresent(self.transactions, forKey: .transactions)
            try container.encodeIfPresent(self.collectibles, forKey: .collectibles)
        }
    }
}

final class WalletKeychainVault {
    enum Error: Swift.Error {
        case keychainStatus(OSStatus)
        case corrupted
    }

    private let service = "org.telegram.ton-wallet"
    private let secretAccount: String
    private let metadataAccount: String

    init(namespace: String) {
        self.secretAccount = namespace + ".secret"
        self.metadataAccount = namespace + ".metadata"
    }

    func readSecret<Value: Decodable>(_ type: Value.Type) throws -> Value? {
        return try self.read(account: self.secretAccount, type: type)
    }

    func readMetadata<Value: Decodable>(_ type: Value.Type) throws -> Value? {
        return try self.read(account: self.metadataAccount, type: type)
    }

    func containsSecret() throws -> Bool {
        let status = SecItemCopyMatching(self.query(account: self.secretAccount) as CFDictionary, nil)
        if status == errSecSuccess {
            return true
        }
        if status == errSecItemNotFound {
            return false
        }
        throw Error.keychainStatus(status)
    }

    func writeSecret<Value: Encodable>(_ value: Value) throws {
        try self.write(value, account: self.secretAccount)
    }

    func writeMetadata<Value: Encodable>(_ value: Value) throws {
        try self.write(value, account: self.metadataAccount)
    }

    func deleteSecret() throws {
        try self.delete(account: self.secretAccount)
    }

    func deleteMetadata() throws {
        try self.delete(account: self.metadataAccount)
    }

    private func query(account: String) -> [String: Any] {
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: account
        ]
    }

    private func read<Value: Decodable>(account: String, type: Value.Type) throws -> Value? {
        var query = self.query(account: account)
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
        guard let data = result as? Data else {
            throw Error.corrupted
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw Error.corrupted
        }
    }

    private func write<Value: Encodable>(_ value: Value, account: String) throws {
        let data: Data
        do {
            data = try JSONEncoder().encode(value)
        } catch {
            throw Error.corrupted
        }
        let query = self.query(account: account)
        let update: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw Error.keychainStatus(updateStatus)
        }
        var addQuery = query
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        addQuery[kSecValueData as String] = data
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw Error.keychainStatus(addStatus)
        }
    }

    private func delete(account: String) throws {
        let status = SecItemDelete(self.query(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw Error.keychainStatus(status)
        }
    }
}

func fatalStorageError(_ error: WalletKeychainVault.Error) -> WalletContext.FatalStorageError {
    switch error {
    case let .keychainStatus(status):
        return .keychainStatus(status)
    case .corrupted:
        return .corrupted
    }
}

func walletInfo(secret: WalletContext.SecretRecord) -> WalletContext.WalletInfo {
    return WalletContext.WalletInfo(
        address: secret.address,
        publicKey: secret.publicKey,
        version: secret.walletVersion,
        canDisableBackup: secret.walletVersion == .v5Experimental
            && secret.originalPublicKey == nil
            && secret.pendingKeyRotation == nil
    )
}

func normalizedMnemonicWords(_ words: [String]) -> [String] {
    return words.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.filter { !$0.isEmpty }
}

func validatedMnemonicWords(_ words: [String]) throws -> [String] {
    let normalized = words.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
    guard !normalized.contains(where: { $0.isEmpty }) else {
        throw WalletContext.WalletError.invalidMnemonic
    }
    guard normalized.count == 12 || normalized.count == 24 else {
        throw WalletContext.WalletError.unsupportedMnemonicLength
    }
    guard (try? Mnemonic.validate(normalized)) == true else {
        throw WalletContext.WalletError.invalidMnemonic
    }
    return normalized
}
