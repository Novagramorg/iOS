import Foundation
import Security
import TelegramCore
import WalletEngineFFI

struct WalletEngineDescriptorRecord: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let recordId: String
    let address: String
    let publicKey: Data
    let network: String
    let secretRef: String?

    init(descriptor: WalletDescriptor) {
        self.schemaVersion = 2
        self.recordId = descriptor.recordId
        self.address = descriptor.address
        self.publicKey = descriptor.publicKey
        self.network = descriptor.network == .mainnet ? "mainnet" : "testnet"
        self.secretRef = descriptor.secretRef.value
    }

    init(recordId: String, address: String, publicKey: Data, secretRef: String?) {
        self.schemaVersion = 2
        self.recordId = recordId
        self.address = address
        self.publicKey = publicKey
        self.network = "mainnet"
        self.secretRef = secretRef
    }

    var descriptor: WalletDescriptor? {
        guard self.schemaVersion == 2,
              !self.recordId.isEmpty,
              self.publicKey.count == 32,
              let secretRef = self.secretRef,
              !secretRef.isEmpty else {
            return nil
        }
        return WalletDescriptor(
            recordId: self.recordId,
            address: self.address,
            publicKey: self.publicKey,
            network: self.network == "testnet" ? .testnet : .mainnet,
            secretRef: ProtectedSecretRef(value: secretRef)
        )
    }
}

struct WalletStoredTransaction: Codable, Equatable, Sendable {
    enum Peer: Codable, Equatable, @unchecked Sendable {
        case user(id: EnginePeer.Id, displayName: String)
        case address(String)
        case unsupported

        var userId: EnginePeer.Id? {
            if case let .user(id, _) = self {
                return id
            }
            return nil
        }
    }

    let id: String
    let transactionHash: String?
    let externalMessageHash: String?
    let logicalTime: String
    let timestamp: Int32
    let kind: WalletContext.Transaction.Kind
    let direction: WalletContext.Transaction.Direction
    let amount: Int64
    let fee: Int64
    let peer: Peer
    let comment: String?
    let currency: WalletContext.Transaction.Currency
    let collectible: WalletContext.Transaction.CollectibleTransfer?
    let status: WalletContext.Transaction.Status

    init(_ transaction: WalletContext.Transaction) {
        self.id = transaction.id
        self.transactionHash = transaction.transactionHash
        self.externalMessageHash = transaction.externalMessageHash
        self.logicalTime = transaction.logicalTime
        self.timestamp = transaction.timestamp
        self.kind = transaction.kind
        self.direction = transaction.direction
        self.amount = transaction.amount
        self.fee = transaction.fee
        switch transaction.peer {
        case let .user(peer):
            self.peer = .user(id: peer.id, displayName: peer.debugDisplayTitle)
        case let .address(address):
            self.peer = .address(address)
        case .unsupported:
            self.peer = .unsupported
        }
        self.comment = transaction.comment
        self.currency = transaction.currency
        self.collectible = transaction.collectible
        self.status = transaction.status
    }

    func transaction(peers: [EnginePeer.Id: EnginePeer]) -> WalletContext.Transaction {
        let peer: WalletContext.Transaction.Peer
        switch self.peer {
        case let .user(id, _):
            if let value = peers[id] {
                peer = .user(value)
            } else {
                peer = .unsupported
            }
        case let .address(address):
            peer = .address(address)
        case .unsupported:
            peer = .unsupported
        }
        return WalletContext.Transaction(
            id: self.id,
            transactionHash: self.transactionHash,
            externalMessageHash: self.externalMessageHash,
            logicalTime: self.logicalTime,
            timestamp: self.timestamp,
            direction: self.direction,
            amount: self.amount,
            fee: self.fee,
            peer: peer,
            comment: self.comment,
            currency: self.currency,
            collectible: self.collectible,
            status: self.status,
            kind: self.kind
        )
    }
}

struct WalletEngineMetadataRecord: Codable, Equatable, Sendable {
    var schemaVersion: Int = 2
    var walletAddress: String?
    var pendingTransfers: [WalletContext.PendingTransfer] = []
    var balance: Int64?
    var balanceUpdatedAt: Int32?
    var fiatRates: [WalletContext.FiatCurrency: WalletContext.FiatRate]?
    var fiatRatesUpdatedAt: Int32?
    var selectedFiatCurrency: WalletContext.FiatCurrency = .usd
    var transactions: [WalletStoredTransaction] = []
    var collectibles: [WalletContext.Collectible] = []
}

enum WalletEngineStorageError: Error, Equatable {
    case keychainStatus(Int32)
    case corrupted
}

actor WalletEngineStorage {
    private struct JournalDiskRecord: Codable {
        let version: UInt64
        let payload: Data
    }

    private let descriptorService: String
    private let metadataService: String
    private let secretService: String
    private let journalService: String
    private let tonConnectService: String

    init(namespace: String) {
        self.descriptorService = "org.telegram.ton-wallet.engine.v2.descriptor.\(namespace)"
        self.metadataService = "org.telegram.ton-wallet.engine.v2.metadata.\(namespace)"
        self.secretService = "org.telegram.ton-wallet.engine.v2.secret.\(namespace)"
        self.journalService = "org.telegram.ton-wallet.engine.v2.journal.\(namespace)"
        self.tonConnectService = "org.telegram.ton-wallet.engine.v2.ton-connect.\(namespace)"
    }

    func loadDescriptor() throws -> WalletEngineDescriptorRecord? {
        try self.readCodable(service: self.descriptorService, account: "wallet")
    }

    func saveDescriptor(_ descriptor: WalletEngineDescriptorRecord) throws {
        try self.writeCodable(descriptor, service: self.descriptorService, account: "wallet")
    }

    func removeDescriptor() throws {
        try self.remove(service: self.descriptorService, account: "wallet")
    }

    func loadReplacementCandidate() throws -> WalletEngineDescriptorRecord? {
        try self.readCodable(service: self.descriptorService, account: "replacement-candidate")
    }

    func saveReplacementCandidate(_ descriptor: WalletEngineDescriptorRecord) throws {
        try self.writeCodable(descriptor, service: self.descriptorService, account: "replacement-candidate")
    }

    func removeReplacementCandidate() throws {
        try self.remove(service: self.descriptorService, account: "replacement-candidate")
    }

    func loadMetadata() throws -> WalletEngineMetadataRecord? {
        try self.readCodable(service: self.metadataService, account: "state")
    }

    func saveMetadata(_ metadata: WalletEngineMetadataRecord) throws {
        try self.writeCodable(metadata, service: self.metadataService, account: "state")
    }

    func loadTonConnectSession(recordId: String) throws -> Data? {
        try self.read(service: self.tonConnectService, account: recordId)
    }

    func saveTonConnectSession(_ data: Data, recordId: String) throws {
        try self.write(data, service: self.tonConnectService, account: recordId)
    }

    func removeTonConnectSession(recordId: String) throws {
        try self.remove(service: self.tonConnectService, account: recordId)
    }

    func readProtectedSecret(_ request: ProtectedSecretRead) throws -> Data {
        guard let data = try self.read(service: self.secretService, account: request.secretRef.value),
              !data.isEmpty else {
            throw protectedSecretFailure(.notFound, "Protected secret was not found")
        }
        return data
    }

    func containsProtectedSecret(_ secretRef: ProtectedSecretRef) throws -> Bool {
        guard let data = try self.read(service: self.secretService, account: secretRef.value) else {
            return false
        }
        return !data.isEmpty
    }

    func storeProtectedSecret(_ request: ProtectedSecretStore) throws {
        guard !request.secretRef.value.isEmpty, !request.bytes.isEmpty else {
            throw protectedSecretFailure(.policyViolation, "Protected secret is empty")
        }
        // App policy intentionally ignores requireUserPresence.
        try self.write(request.bytes, service: self.secretService, account: request.secretRef.value)
    }

    func deleteProtectedSecret(_ secretRef: ProtectedSecretRef) throws {
        try self.remove(service: self.secretService, account: secretRef.value)
    }

    func loadJournal(_ key: JournalKey) throws -> JournalRecord? {
        let account = self.journalAccount(key)
        guard let value: JournalDiskRecord = try self.readCodable(service: self.journalService, account: account) else {
            return nil
        }
        guard value.version > 0, !value.payload.isEmpty else {
            throw journalFailure(.corruptData, "Wallet send journal is corrupt")
        }
        return JournalRecord(version: value.version, payload: value.payload)
    }

    func compareExchangeJournal(_ mutation: JournalCompareExchange) throws -> JournalCompareExchangeResult {
        let current = try self.loadJournal(mutation.key)
        guard current?.version == mutation.expectedVersion else {
            return JournalCompareExchangeResult(applied: false, current: current)
        }
        guard mutation.replacement.version > 0, !mutation.replacement.payload.isEmpty else {
            throw journalFailure(.corruptData, "Wallet send journal replacement is invalid")
        }
        try self.writeCodable(
            JournalDiskRecord(version: mutation.replacement.version, payload: mutation.replacement.payload),
            service: self.journalService,
            account: self.journalAccount(mutation.key)
        )
        return JournalCompareExchangeResult(applied: true, current: mutation.replacement)
    }

    private func journalAccount(_ key: JournalKey) -> String {
        Data("\(key.recordId)\u{0}\(key.slot)".utf8).base64EncodedString()
    }

    private func readCodable<Value: Decodable>(service: String, account: String) throws -> Value? {
        guard let data = try self.read(service: service, account: account) else {
            return nil
        }
        do {
            return try JSONDecoder().decode(Value.self, from: data)
        } catch {
            throw WalletEngineStorageError.corrupted
        }
    }

    private func writeCodable<Value: Encodable>(_ value: Value, service: String, account: String) throws {
        do {
            try self.write(JSONEncoder().encode(value), service: service, account: account)
        } catch let error as WalletEngineStorageError {
            throw error
        } catch {
            throw WalletEngineStorageError.corrupted
        }
    }

    private func baseQuery(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false
        ]
    }

    private func read(service: String, account: String) throws -> Data? {
        var query = self.baseQuery(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = item as? Data else {
            throw WalletEngineStorageError.keychainStatus(status)
        }
        return data
    }

    private func write(_ data: Data, service: String, account: String) throws {
        let query = self.baseQuery(service: service, account: account)
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw WalletEngineStorageError.keychainStatus(updateStatus)
        }
        var addQuery = query
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        addQuery[kSecValueData as String] = data
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw WalletEngineStorageError.keychainStatus(addStatus)
        }
    }

    private func remove(service: String, account: String) throws {
        let status = SecItemDelete(self.baseQuery(service: service, account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw WalletEngineStorageError.keychainStatus(status)
        }
    }
}

actor WalletEnginePlatformHost: WalletPlatformHost {
    let storage: WalletEngineStorage

    init(storage: WalletEngineStorage) {
        self.storage = storage
    }

    func now() async -> UInt64 {
        UInt64(max(0, Date().timeIntervalSince1970.rounded(.down)))
    }

    func readProtectedSecret(request: ProtectedSecretRead) async throws -> Data {
        do {
            return try await self.storage.readProtectedSecret(request)
        } catch let error as ProtectedSecretHostError {
            throw error
        } catch {
            throw protectedSecretFailure(.unavailable, String(describing: error))
        }
    }

    func storeProtectedSecret(request: ProtectedSecretStore) async throws {
        do {
            try await self.storage.storeProtectedSecret(request)
        } catch let error as ProtectedSecretHostError {
            throw error
        } catch {
            throw protectedSecretFailure(.unavailable, String(describing: error))
        }
    }

    func deleteProtectedSecret(secretRef: ProtectedSecretRef) async throws {
        do {
            try await self.storage.deleteProtectedSecret(secretRef)
        } catch {
            throw protectedSecretFailure(.unavailable, String(describing: error))
        }
    }

    func loadJournal(key: JournalKey) async throws -> JournalRecord? {
        do {
            return try await self.storage.loadJournal(key)
        } catch let error as JournalHostError {
            throw error
        } catch {
            throw journalFailure(.unavailable, String(describing: error))
        }
    }

    func compareExchangeJournal(mutation: JournalCompareExchange) async throws -> JournalCompareExchangeResult {
        do {
            return try await self.storage.compareExchangeJournal(mutation)
        } catch let error as JournalHostError {
            throw error
        } catch {
            throw journalFailure(.unavailable, String(describing: error))
        }
    }
}

private func protectedSecretFailure(
    _ kind: ProtectedSecretHostErrorKind,
    _ diagnostic: String
) -> ProtectedSecretHostError {
    .Failed(kind: kind, diagnostic: sanitizedWalletEngineDiagnostic(diagnostic))
}

private func journalFailure(
    _ kind: JournalHostErrorKind,
    _ diagnostic: String
) -> JournalHostError {
    .Failed(kind: kind, diagnostic: sanitizedWalletEngineDiagnostic(diagnostic))
}

func sanitizedWalletEngineDiagnostic(_ value: String) -> String {
    String(
        value.unicodeScalars
            .map { CharacterSet.controlCharacters.contains($0) ? " " : String($0) }
            .joined()
            .prefix(256)
    )
}
