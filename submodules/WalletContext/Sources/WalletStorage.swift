import Foundation
import Security
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

enum WalletEngineKeyRotationStoragePhase: String, Codable, Equatable, Sendable {
    case candidateStored
    case submissionStarted
    case chainApplied
    case backupDisabled
    case previousRestored
}

struct WalletEngineKeyRotationRecord: Codable, Equatable, Sendable {
    let operationId: String
    let recordId: String
    let walletAddress: String
    let walletPublicKey: Data
    let activeSecretRef: String
    let rollbackSecretRef: String
    let candidateSecretRef: String
    let previousPublicKey: Data
    let newPublicKey: Data
    let validUntil: UInt64
    var phase: WalletEngineKeyRotationStoragePhase
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
    private let secretService: String
    private let journalService: String
    private let tonConnectService: String

    init(namespace: String) {
        self.descriptorService = "org.telegram.ton-wallet.engine.v2.descriptor.\(namespace)"
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

    func loadTransferReceipts() throws -> [WalletEngineTransferReceipt] {
        try self.readCodable(service: self.descriptorService, account: "transfer-receipts") ?? []
    }

    func saveTransferReceipt(_ receipt: WalletEngineTransferReceipt) throws {
        // Retain the short-lived UI receipts independently of the engine journal.
        // Include the pending draft so a crash before the Postbox write can recover it.
        var receipts = try self.loadTransferReceipts().filter {
            $0.pendingTransfer.id != receipt.pendingTransfer.id
                && Int64($0.receivedAt) + Int64(walletPendingTransferUILifetime) > Int64(receipt.receivedAt)
        }
        receipts.append(receipt)
        try self.writeCodable(receipts, service: self.descriptorService, account: "transfer-receipts")
    }

    func loadReplacementCandidate() throws -> WalletEngineDescriptorRecord? {
        try self.readCodable(service: self.descriptorService, account: "replacement-candidate")
    }

    func saveReplacementCandidate(_ descriptor: WalletEngineDescriptorRecord) throws {
        try self.writeCodable(descriptor, service: self.descriptorService, account: "replacement-candidate")
    }

    func installReplacementCandidate(
        _ descriptor: WalletEngineDescriptorRecord,
        secret: Data
    ) throws {
        guard let secretRef = descriptor.secretRef,
              !secretRef.isEmpty,
              !secret.isEmpty else {
            throw WalletEngineStorageError.corrupted
        }
        if let existing = try self.loadReplacementCandidate(), existing != descriptor {
            throw WalletEngineStorageError.corrupted
        }
        try self.write(secret, service: self.secretService, account: secretRef)
        do {
            try self.saveReplacementCandidate(descriptor)
        } catch let saveError {
            do {
                try self.remove(service: self.secretService, account: secretRef)
            } catch let cleanupError {
                throw cleanupError
            }
            throw saveError
        }
    }

    func removeReplacementCandidate() throws {
        try self.remove(service: self.descriptorService, account: "replacement-candidate")
    }

    func loadKeyRotation() throws -> WalletEngineKeyRotationRecord? {
        try self.readCodable(service: self.descriptorService, account: "key-rotation")
    }

    func installKeyRotationCandidate(
        operationId: String,
        descriptor: WalletEngineDescriptorRecord,
        previousPublicKey: Data,
        newPublicKey: Data,
        validUntil: UInt64,
        candidateSecret: Data
    ) throws -> WalletEngineKeyRotationRecord {
        guard !operationId.isEmpty,
              previousPublicKey.count == 32,
              newPublicKey.count == 32,
              !candidateSecret.isEmpty,
              let activeSecretRef = descriptor.secretRef,
              !activeSecretRef.isEmpty,
              let currentSecret = try self.read(service: self.secretService, account: activeSecretRef),
              !currentSecret.isEmpty else {
            throw WalletEngineStorageError.corrupted
        }
        if let current = try self.loadKeyRotation() {
            guard current.operationId == operationId,
                  current.recordId == descriptor.recordId,
                  current.walletAddress == descriptor.address,
                  current.walletPublicKey == descriptor.publicKey,
                  current.previousPublicKey == previousPublicKey,
                  current.newPublicKey == newPublicKey,
                  current.validUntil == validUntil else {
                throw WalletEngineStorageError.corrupted
            }
            return current
        }

        let rollbackSecretRef = "wallet:\(descriptor.recordId):key-rotation-rollback:\(operationId)"
        let candidateSecretRef = "wallet:\(descriptor.recordId):key-rotation-candidate:\(operationId)"
        try self.write(currentSecret, service: self.secretService, account: rollbackSecretRef)
        try self.write(candidateSecret, service: self.secretService, account: candidateSecretRef)
        let record = WalletEngineKeyRotationRecord(
            operationId: operationId,
            recordId: descriptor.recordId,
            walletAddress: descriptor.address,
            walletPublicKey: descriptor.publicKey,
            activeSecretRef: activeSecretRef,
            rollbackSecretRef: rollbackSecretRef,
            candidateSecretRef: candidateSecretRef,
            previousPublicKey: previousPublicKey,
            newPublicKey: newPublicKey,
            validUntil: validUntil,
            phase: .candidateStored
        )
        try self.writeCodable(record, service: self.descriptorService, account: "key-rotation")
        return record
    }

    func markKeyRotationSubmissionStarted(operationId: String) throws -> WalletEngineKeyRotationRecord {
        guard var record = try self.loadKeyRotation(), record.operationId == operationId else {
            throw WalletEngineStorageError.corrupted
        }
        if record.phase == .candidateStored {
            record.phase = .submissionStarted
            try self.writeCodable(record, service: self.descriptorService, account: "key-rotation")
        } else if record.phase != .submissionStarted {
            throw WalletEngineStorageError.corrupted
        }
        return record
    }

    func keyRotationCandidateSecret(operationId: String) throws -> Data {
        guard let record = try self.loadKeyRotation(), record.operationId == operationId,
              let candidate = try self.read(service: self.secretService, account: record.candidateSecretRef),
              !candidate.isEmpty else {
            throw WalletEngineStorageError.corrupted
        }
        return candidate
    }

    func markKeyRotationChainApplied(
        operationId: String,
        verifiedPublicKey: Data
    ) throws -> WalletEngineKeyRotationRecord {
        guard var record = try self.loadKeyRotation(), record.operationId == operationId else {
            throw WalletEngineStorageError.corrupted
        }
        guard verifiedPublicKey == record.newPublicKey,
              (record.phase == .submissionStarted || record.phase == .chainApplied || record.phase == .backupDisabled) else {
            throw WalletEngineStorageError.corrupted
        }
        if record.phase == .backupDisabled {
            guard let activeSecret = try self.read(service: self.secretService, account: record.activeSecretRef),
                  !activeSecret.isEmpty else {
                throw WalletEngineStorageError.corrupted
            }
            return record
        }
        guard let candidate = try self.read(service: self.secretService, account: record.candidateSecretRef),
              !candidate.isEmpty else {
            throw WalletEngineStorageError.corrupted
        }
        try self.write(candidate, service: self.secretService, account: record.activeSecretRef)
        if record.phase == .submissionStarted {
            record.phase = .chainApplied
            try self.writeCodable(record, service: self.descriptorService, account: "key-rotation")
        }
        return record
    }

    func restorePreviousKeyRotationSecret(
        operationId: String,
        verifiedPublicKey: Data,
        removeRecord: Bool
    ) throws {
        guard var record = try self.loadKeyRotation(), record.operationId == operationId,
              record.previousPublicKey == verifiedPublicKey,
              let previousSecret = try self.read(service: self.secretService, account: record.rollbackSecretRef),
              !previousSecret.isEmpty else {
            throw WalletEngineStorageError.corrupted
        }
        try self.write(previousSecret, service: self.secretService, account: record.activeSecretRef)
        if removeRecord {
            record.phase = .previousRestored
            try self.writeCodable(record, service: self.descriptorService, account: "key-rotation")
            try self.cleanupRestoredKeyRotation(operationId: operationId)
        } else if record.phase == .chainApplied {
            record.phase = .submissionStarted
            try self.writeCodable(record, service: self.descriptorService, account: "key-rotation")
        }
    }

    func discardUnsubmittedKeyRotation(operationId: String) throws {
        guard var record = try self.loadKeyRotation(), record.operationId == operationId else {
            return
        }
        guard record.phase == .candidateStored,
              let previousSecret = try self.read(service: self.secretService, account: record.rollbackSecretRef),
              !previousSecret.isEmpty else {
            throw WalletEngineStorageError.corrupted
        }
        try self.write(previousSecret, service: self.secretService, account: record.activeSecretRef)
        record.phase = .previousRestored
        try self.writeCodable(record, service: self.descriptorService, account: "key-rotation")
        try self.cleanupRestoredKeyRotation(operationId: operationId)
    }

    func cleanupRestoredKeyRotation(operationId: String) throws {
        guard let record = try self.loadKeyRotation() else {
            return
        }
        guard record.operationId == operationId, record.phase == .previousRestored else {
            throw WalletEngineStorageError.corrupted
        }
        try self.removeKeyRotation(record)
    }

    func completeKeyRotation(operationId: String) throws {
        guard var record = try self.loadKeyRotation() else {
            return
        }
        guard record.operationId == operationId,
              (record.phase == .chainApplied || record.phase == .backupDisabled) else {
            throw WalletEngineStorageError.corrupted
        }
        if record.phase == .chainApplied {
            record.phase = .backupDisabled
            try self.writeCodable(record, service: self.descriptorService, account: "key-rotation")
        }
        try self.removeKeyRotation(record)
    }

    func discardOrphanedKeyRotation(operationId: String, activeSecretRef: String?) throws {
        guard let record = try self.loadKeyRotation(), record.operationId == operationId else {
            return
        }
        let descriptor = try self.loadDescriptor()
        guard record.recordId != descriptor?.recordId,
              record.activeSecretRef != activeSecretRef else {
            throw WalletEngineStorageError.corrupted
        }
        try self.removeKeyRotation(record)
    }

    private func removeKeyRotation(_ record: WalletEngineKeyRotationRecord) throws {
        try self.remove(service: self.secretService, account: record.candidateSecretRef)
        try self.remove(service: self.secretService, account: record.rollbackSecretRef)
        try self.remove(service: self.descriptorService, account: "key-rotation")
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
    private let logger: WalletLogger
    private var captureNextProtectedSecret = false
    private var transientProtectedSecrets: [String: Data] = [:]

    init(storage: WalletEngineStorage, logger: WalletLogger) {
        self.storage = storage
        self.logger = logger
    }

    func now() async -> UInt64 {
        UInt64(max(0, Date().timeIntervalSince1970.rounded(.down)))
    }

    func beginTransientProtectedSecretCapture() {
        self.captureNextProtectedSecret = true
    }

    func cancelTransientProtectedSecretCapture() {
        self.captureNextProtectedSecret = false
    }

    func transientProtectedSecret(secretRef: ProtectedSecretRef) -> Data? {
        self.transientProtectedSecrets[secretRef.value]
    }

    func containsTransientProtectedSecret(secretRef: ProtectedSecretRef) -> Bool {
        self.transientProtectedSecrets[secretRef.value] != nil
    }

    func removeTransientProtectedSecret(secretRef: ProtectedSecretRef) {
        self.transientProtectedSecrets[secretRef.value] = nil
    }

    func removeAllTransientProtectedSecrets() {
        self.captureNextProtectedSecret = false
        self.transientProtectedSecrets.removeAll()
    }

    func readProtectedSecret(request: ProtectedSecretRead) async throws -> Data {
        if let data = self.transientProtectedSecrets[request.secretRef.value] {
            return data
        }
        do {
            return try await self.storage.readProtectedSecret(request)
        } catch let error as ProtectedSecretHostError {
            self.logger.error("wallet_protected_secret_read_failed", error)
            throw error
        } catch {
            self.logger.error("wallet_protected_secret_read_failed", error)
            throw protectedSecretFailure(.unavailable, String(describing: error))
        }
    }

    func storeProtectedSecret(request: ProtectedSecretStore) async throws {
        if self.captureNextProtectedSecret {
            self.captureNextProtectedSecret = false
            guard !request.secretRef.value.isEmpty, !request.bytes.isEmpty else {
                throw protectedSecretFailure(.policyViolation, "Protected secret is empty")
            }
            self.transientProtectedSecrets[request.secretRef.value] = request.bytes
            return
        }
        do {
            try await self.storage.storeProtectedSecret(request)
        } catch let error as ProtectedSecretHostError {
            self.logger.error("wallet_protected_secret_store_failed", error)
            throw error
        } catch {
            self.logger.error("wallet_protected_secret_store_failed", error)
            throw protectedSecretFailure(.unavailable, String(describing: error))
        }
    }

    func deleteProtectedSecret(secretRef: ProtectedSecretRef) async throws {
        if self.transientProtectedSecrets.removeValue(forKey: secretRef.value) != nil {
            return
        }
        do {
            try await self.storage.deleteProtectedSecret(secretRef)
        } catch {
            self.logger.error("wallet_protected_secret_delete_failed", error)
            throw protectedSecretFailure(.unavailable, String(describing: error))
        }
    }

    func loadJournal(key: JournalKey) async throws -> JournalRecord? {
        do {
            return try await self.storage.loadJournal(key)
        } catch let error as JournalHostError {
            self.logger.error("wallet_journal_load_failed", error)
            throw error
        } catch {
            self.logger.error("wallet_journal_load_failed", error)
            throw journalFailure(.unavailable, String(describing: error))
        }
    }

    func compareExchangeJournal(mutation: JournalCompareExchange) async throws -> JournalCompareExchangeResult {
        do {
            return try await self.storage.compareExchangeJournal(mutation)
        } catch let error as JournalHostError {
            self.logger.error("wallet_journal_compare_exchange_failed", error)
            throw error
        } catch {
            self.logger.error("wallet_journal_compare_exchange_failed", error)
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
