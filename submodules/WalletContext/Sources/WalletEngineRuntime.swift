import Foundation
import TelegramCore
import PasscodeCore
import WalletEngineFFI

@available(macOS 10.15, *)
struct WalletEngineActivation: @unchecked Sendable {
    let snapshot: WalletSnapshot
    let canSign: Bool
}

@available(macOS 10.15, *)
struct WalletEngineStagedWallet: Equatable, Sendable {
    let recordId: String
    let address: String
    let publicKey: Data
    let signingPublicKey: Data
}

@available(macOS 10.15, *)
struct WalletEngineSendExecution: @unchecked Sendable {
    let result: SendResult
    let didRecreateClient: Bool

    init(result: SendResult, didRecreateClient: Bool) {
        self.result = result
        self.didRecreateClient = didRecreateClient
    }
}

@available(macOS 10.15, *)
enum WalletEngineKeyRotationResolution: Equatable, Sendable {
    case none
    case pending(operationId: String, retryAfterMilliseconds: UInt64?)
    case confirmed(operationId: String)
    case rolledBack(operationId: String, phase: SendPhase)
}

@available(macOS 10.15, *)
private enum WalletEngineKeyRotationChainState: Equatable {
    case replacement
    case previous
    case different
}

@available(macOS 10.15, *)
actor WalletEngineRuntime {
    private enum FfiPriority {
        case background
        case userInitiated
    }

    private enum FfiCancellation: Equatable {
        case none
        case refresh
        case refreshNfts
        case loadMoreNfts
        case sendPreview
        case send
    }

    let storage: WalletEngineStorage
    private var lastKnownBalance: Int64?
    private let engine: TelegramEngine
    private let logger: WalletLogger
    private let platformHost: WalletEnginePlatformHost
    private var statuslessHost: WalletEngineStatuslessHost
    private let lifecycle: WalletLifecycle
    private var client: WalletClient?
    private var clientConfig: WalletClientConfig?
    private var clientRevision: UInt64 = 0
    private var descriptor: WalletDescriptor?
    private var serverWalletIdentity: (address: String, publicKey: Data)?
    private var serverStateRevision: UInt64 = 0
    private var transientReplacementDescriptor: WalletDescriptor?
    private var ffiBusy = false
    private var userInitiatedFfiWaiters: [CheckedContinuation<Void, Never>] = []
    private var backgroundFfiWaiters: [CheckedContinuation<Void, Never>] = []
    private var activeFfiOperation: (id: UUID, cancellation: FfiCancellation)?

    init(engine: TelegramEngine, storage: WalletEngineStorage, logger: WalletLogger) {
        self.storage = storage
        self.engine = engine
        self.logger = logger
        self.platformHost = WalletEnginePlatformHost(storage: storage, logger: logger)
        self.statuslessHost = WalletEngineStatuslessHost(engine: engine, logger: logger)
        self.lifecycle = WalletLifecycle(platformHost: self.platformHost)
    }

    func activate(
        serverAddress: String,
        serverPublicKey: Data,
        archivePreviousWallet: Bool = false,
        serverStateRevision: UInt64? = nil
    ) async throws -> WalletEngineActivation {
        let revision = serverStateRevision ?? self.serverStateRevision
        return try await self.withFfi {
            try await self.activateUnlocked(
                serverAddress: serverAddress,
                serverPublicKey: serverPublicKey,
                archivePreviousWallet: archivePreviousWallet,
                serverStateRevision: revision
            )
        }
    }

    func updateServerWalletIdentity(address: String, publicKey: Data, revision: UInt64) {
        guard revision > self.serverStateRevision else { return }
        self.serverStateRevision = revision
        self.serverWalletIdentity = (address, publicKey)
    }

    func invalidateServerWalletIdentity(revision: UInt64) {
        guard revision > self.serverStateRevision else { return }
        self.serverStateRevision = revision
        self.serverWalletIdentity = nil
    }

    private func adoptServerWalletIdentity(address: String, publicKey: Data, revision: UInt64) throws {
        guard revision >= self.serverStateRevision else { throw CancellationError() }
        self.serverStateRevision = revision
        self.serverWalletIdentity = (address, publicKey)
    }

    func stageReplacement(words: [String]) async throws -> WalletEngineStagedWallet {
        try await self.withFfi {
            await self.discardTransientReplacementUnlocked()
            let words = normalizedEngineMnemonic(words)
            guard detectMnemonicSchemes(words: words).contains(.rotation) else {
                throw WalletContext.WalletError.invalidMnemonic
            }
            if let existing = try await self.storage.loadReplacementCandidate() {
                try await self.deleteLocalWallet(existing)
                try await self.storage.removeReplacementCandidate()
            }
            let imported = try await self.lifecycle.importWallet(request: ImportWalletRequest(
                recordId: UUID().uuidString.lowercased(),
                network: .mainnet,
                recoveryWords: words
            ))
            let signingPublicKey = try walletMnemonicSigningPublicKey(words: words)
            let record = WalletEngineDescriptorRecord(descriptor: imported, signingPublicKey: signingPublicKey)
            do {
                try await self.storage.saveReplacementCandidate(record)
            } catch {
                do {
                    try await self.storage.deleteProtectedSecret(imported.secretRef)
                } catch {
                    self.logger.error("wallet_replacement_secret_cleanup_failed", error)
                }
                throw error
            }
            return WalletEngineStagedWallet(
                recordId: record.recordId,
                address: record.address,
                publicKey: record.publicKey,
                signingPublicKey: signingPublicKey
            )
        }
    }

    func stageTransientReplacement(words: [String]) async throws -> WalletEngineStagedWallet {
        let recordId = UUID().uuidString.lowercased()
        do {
            return try await self.withFfi {
                if let candidate = try await self.storage.loadReplacementCandidate() {
                    guard let descriptor = candidate.descriptor else { throw WalletContext.WalletError.storage(.corrupted) }
                    let existing = try await self.lifecycle.revealRecoveryPhrase(descriptor: descriptor)
                    guard normalizedEngineMnemonic(existing.phrase.split(whereSeparator: { $0.isWhitespace }).map(String.init)) == normalizedEngineMnemonic(words) else {
                        throw WalletContext.WalletError.operationInProgress
                    }
                    return WalletEngineStagedWallet(
                        recordId: candidate.recordId, address: candidate.address, publicKey: candidate.publicKey,
                        signingPublicKey: try walletMnemonicSigningPublicKey(words: words)
                    )
                }
                guard self.transientReplacementDescriptor == nil else {
                    throw WalletContext.WalletError.operationInProgress
                }
                let words = normalizedEngineMnemonic(words)
                guard detectMnemonicSchemes(words: words).contains(.rotation) else {
                    throw WalletContext.WalletError.invalidMnemonic
                }
                await self.platformHost.beginTransientProtectedSecretCapture()
                let imported: WalletDescriptor
                do {
                    imported = try await self.lifecycle.importWallet(request: ImportWalletRequest(
                        recordId: recordId,
                        network: .mainnet,
                        recoveryWords: words
                    ))
                } catch {
                    await self.platformHost.cancelTransientProtectedSecretCapture()
                    await self.platformHost.removeAllTransientProtectedSecrets()
                    throw error
                }
                await self.platformHost.cancelTransientProtectedSecretCapture()
                guard await self.platformHost.containsTransientProtectedSecret(secretRef: imported.secretRef) else {
                    throw WalletContext.WalletError.storage(.corrupted)
                }
                self.transientReplacementDescriptor = imported
                return WalletEngineStagedWallet(
                    recordId: imported.recordId,
                    address: imported.address,
                    publicKey: imported.publicKey,
                    signingPublicKey: try walletMnemonicSigningPublicKey(words: words)
                )
            }
        } catch {
            if self.transientReplacementDescriptor?.recordId == recordId {
                await self.discardTransientReplacementUnlocked(recordId: recordId)
            }
            throw error
        }
    }

    func signReplacementProof(
        recordId: String,
        expectedPublicKey: Data,
        domain: String,
        timestamp: UInt64,
        payload: String
    ) async throws -> Data {
        try await self.withFfi {
            let descriptor: WalletDescriptor?
            if let transient = self.transientReplacementDescriptor, transient.recordId == recordId {
                descriptor = transient
            } else {
                descriptor = try await self.storage.loadReplacementCandidate()?.descriptor
            }
            guard expectedPublicKey.count == 32, let descriptor,
                  descriptor.recordId == recordId, descriptor.publicKey == expectedPublicKey else {
                throw WalletContext.WalletError.storage(.identityMismatch)
            }
            let proof = try await self.lifecycle.signTonConnectProof(request: TonConnectProofSignRequest(
                descriptor: descriptor,
                domain: domain,
                timestamp: timestamp,
                payload: payload
            ))
            guard proof.signature.count == 64 else {
                throw WalletContext.WalletError.proofInvalid
            }
            return proof.signature
        }
    }

    func persistReplacementCandidate(recordId: String) async throws {
        try await self.withFfi {
            if let candidate = try await self.storage.loadReplacementCandidate(), candidate.recordId == recordId { return }
            _ = try await self.materializeTransientReplacementUnlocked(recordId: recordId)
        }
    }

    func commitReplacement(
        recordId: String,
        serverAddress: String,
        serverPublicKey: Data,
        archivePreviousWallet: Bool = false,
        serverStateRevision: UInt64? = nil
    ) async throws -> WalletEngineActivation {
        let revision = serverStateRevision ?? self.serverStateRevision
        return try await self.withFfi {
            try self.adoptServerWalletIdentity(address: serverAddress, publicKey: serverPublicKey, revision: revision)
            if self.transientReplacementDescriptor?.recordId == recordId {
                _ = try await self.materializeTransientReplacementUnlocked(recordId: recordId)
            }
            guard let candidate = try await self.storage.loadReplacementCandidate(),
                  candidate.recordId == recordId,
                  walletEngineAddressesEqual(candidate.address, serverAddress),
                  candidate.publicKey == serverPublicKey,
                  candidate.descriptor != nil else {
                throw WalletContext.WalletError.storage(.identityMismatch)
            }
            let signingPublicKey = try await self.signingPublicKey(for: candidate)
            guard self.serverStateRevision == revision else { throw CancellationError() }
            try await self.promoteReplacementCandidate(candidate.withSigningPublicKey(signingPublicKey), archivePreviousWallet: archivePreviousWallet)
            return try await self.activateUnlocked(
                serverAddress: serverAddress,
                serverPublicKey: serverPublicKey,
                archivePreviousWallet: false,
                serverStateRevision: revision
            )
        }
    }

    func reconcileReplacementCandidate(
        serverAddress: String,
        serverPublicKey: Data,
        discardMismatch: Bool,
        archivePreviousWallet: Bool = false,
        serverStateRevision: UInt64? = nil
    ) async throws -> Bool {
        let revision = serverStateRevision ?? self.serverStateRevision
        return try await self.withFfi {
            guard self.serverStateRevision <= revision else { throw CancellationError() }
            guard let candidate = try await self.storage.loadReplacementCandidate() else {
                return false
            }
            let signingPublicKey: Data?
            if let known = candidate.signingPublicKey {
                signingPublicKey = known
            } else if candidate.descriptor != nil {
                signingPublicKey = try? await self.signingPublicKey(for: candidate)
            } else {
                signingPublicKey = nil
            }
            guard self.serverStateRevision <= revision else { throw CancellationError() }
            if walletEngineAddressesEqual(candidate.address, serverAddress),
               candidate.publicKey == serverPublicKey,
               candidate.descriptor != nil {
                let verifiedCandidate = signingPublicKey.map { candidate.withSigningPublicKey($0) } ?? candidate
                try await self.promoteReplacementCandidate(verifiedCandidate, archivePreviousWallet: archivePreviousWallet)
                return true
            } else if discardMismatch, signingPublicKey != nil,
                      !walletEngineAddressesEqual(candidate.address, serverAddress) {
                try await self.deleteLocalWallet(candidate)
                try await self.storage.removeReplacementCandidate()
            }
            return false
        }
    }

    func discardReplacement(recordId: String) async throws {
        try await self.withFfi {
            if self.transientReplacementDescriptor?.recordId == recordId {
                await self.discardTransientReplacementUnlocked(recordId: recordId)
                return
            }
            guard let candidate = try await self.storage.loadReplacementCandidate(),
                  candidate.recordId == recordId else {
                return
            }
            try await self.deleteLocalWallet(candidate)
            try await self.storage.removeReplacementCandidate()
        }
    }

    func discardReplacementAfterAuthoritativeEmptyState() async throws {
        try await self.withFfi {
            await self.discardTransientReplacementUnlocked()
            guard let candidate = try await self.storage.loadReplacementCandidate() else {
                return
            }
            try await self.deleteLocalWallet(candidate)
            try await self.storage.removeReplacementCandidate()
        }
    }

    private func activateUnlocked(
        serverAddress: String,
        serverPublicKey: Data,
        archivePreviousWallet: Bool,
        serverStateRevision: UInt64
    ) async throws -> WalletEngineActivation {
        guard serverPublicKey.count == 32 else {
            throw WalletContext.WalletError.storage(.identityMismatch)
        }
        try self.adoptServerWalletIdentity(address: serverAddress, publicKey: serverPublicKey, revision: serverStateRevision)
        try await self.shutdownClient()

        _ = try await self.reconcileKeyRotationUnlocked(
            serverAddress: serverAddress, serverPublicKey: serverPublicKey, backupEnabled: true
        )

        let stored = try await self.storage.loadDescriptor()
        var selectedRecord: WalletEngineDescriptorRecord?
        var canSign = false
        if let stored,
           stored.schemaVersion == 2,
           stored.network == "mainnet",
           walletEngineAddressesEqual(stored.address, serverAddress),
           stored.publicKey == serverPublicKey {
            selectedRecord = stored
            if let secretRef = stored.secretRef,
               try await self.storage.containsProtectedSecret(ProtectedSecretRef(value: secretRef)) {
                let verifiedKey = try? await self.signingPublicKey(for: stored)
                if let verifiedKey {
                    selectedRecord = stored.withSigningPublicKey(verifiedKey)
                }
                canSign = true
            }
        }

        let record = selectedRecord ?? WalletEngineDescriptorRecord(
            recordId: UUID().uuidString.lowercased(),
            address: serverAddress,
            publicKey: serverPublicKey,
            secretRef: nil
        )
        guard let currentIdentity = self.serverWalletIdentity,
              self.serverStateRevision == serverStateRevision,
              walletEngineAddressesEqual(currentIdentity.address, serverAddress),
              currentIdentity.publicKey == serverPublicKey else {
            throw CancellationError()
        }
        let config = WalletClientConfig(
            recordId: record.recordId,
            address: record.address,
            publicKey: record.publicKey,
            localSecretRef: canSign ? record.secretRef.map(ProtectedSecretRef.init(value:)) : nil,
            network: .mainnet,
            sendValiditySeconds: 300,
            resolutionMarginSeconds: 60,
            providers: ProviderConfig(
                toncenterBaseUrl: "https://toncenter.com",
                dnsRootAddress: nil,
                requestTimeoutMs: 15_000
            )
        )
        let client = try self.makeClient(config: config)
        do {
            try await self.storage.saveDescriptor(record)
            if archivePreviousWallet, let stored,
               !walletEngineAddressesEqual(stored.address, serverAddress),
               stored.recordId != record.recordId,
               stored.secretRef != record.secretRef {
                try await self.archiveLocalWallet(stored)
            }
        } catch {
            try? await client.shutdown()
            throw error
        }
        self.client = client
        self.clientConfig = config
        self.clientRevision &+= 1
        self.descriptor = record.descriptor
        try await self.recoverKeyRotationAfterActivation(record: record, client: client)
        return WalletEngineActivation(
            snapshot: try client.snapshot(),
            canSign: canSign
        )
    }

    private func promoteReplacementCandidate(_ candidate: WalletEngineDescriptorRecord, archivePreviousWallet: Bool) async throws {
        let previous = try await self.storage.loadDescriptor()
        try await self.storage.saveDescriptor(candidate)
        try await self.storage.removeReplacementCandidate()
        if archivePreviousWallet, let previous,
           !walletEngineAddressesEqual(previous.address, candidate.address),
           previous.recordId != candidate.recordId,
           previous.secretRef != candidate.secretRef {
            try await self.archiveLocalWallet(previous)
        }
    }

    private func materializeTransientReplacementUnlocked(recordId: String) async throws -> WalletEngineDescriptorRecord {
        guard let descriptor = self.transientReplacementDescriptor,
              descriptor.recordId == recordId,
              let secret = try await self.platformHost.transientProtectedSecret(secretRef: descriptor.secretRef),
              !secret.isEmpty else {
            throw WalletContext.WalletError.storage(.identityMismatch)
        }
        guard let phrase = String(data: secret, encoding: .utf8) else {
            throw WalletContext.WalletError.invalidMnemonic
        }
        let signingPublicKey = try walletMnemonicSigningPublicKey(words: phrase.split(whereSeparator: { $0.isWhitespace }).map(String.init))
        let record = WalletEngineDescriptorRecord(descriptor: descriptor, signingPublicKey: signingPublicKey)
        try await self.storage.installReplacementCandidate(record, secret: secret)
        await self.platformHost.removeTransientProtectedSecret(secretRef: descriptor.secretRef)
        self.transientReplacementDescriptor = nil
        return record
    }

    private func discardTransientReplacementUnlocked(recordId: String? = nil) async {
        guard let descriptor = self.transientReplacementDescriptor,
              recordId == nil || descriptor.recordId == recordId else {
            return
        }
        await self.platformHost.removeTransientProtectedSecret(secretRef: descriptor.secretRef)
        self.transientReplacementDescriptor = nil
    }

    private func deleteLocalWallet(_ record: WalletEngineDescriptorRecord) async throws {
        if let secretRef = record.secretRef {
            try await self.storage.deleteProtectedSecret(ProtectedSecretRef(value: secretRef))
        }
    }

    func setLastKnownBalance(_ value: Int64?) {
        self.lastKnownBalance = value
    }

    private func archiveLocalWallet(_ record: WalletEngineDescriptorRecord) async throws {
        let balance = self.lastKnownBalance
        self.lastKnownBalance = nil
        do {
            try await self.storage.archiveWallet(record, balance: balance, archivedAt: currentWalletTimestamp())
        } catch {
            try await self.deleteLocalWallet(record)
        }
    }

    func archivedWallets() async throws -> [WalletContext.PreviousWallet] {
        try await self.storage.availableArchivedWallets().map {
            WalletContext.PreviousWallet(
                id: $0.descriptor.recordId,
                address: $0.descriptor.address,
                balance: $0.balance,
                lastUsedAt: $0.archivedAt
            )
        }
    }

    func refreshArchivedWalletBalances(_ wallets: [WalletContext.PreviousWallet]) async throws -> [WalletContext.PreviousWallet] {
        var balances: [String: Int64] = [:]
        for address in Set(wallets.map(\.address)) {
            try Task.checkCancellation()
            do {
                balances[address] = try await self.statuslessHost.walletBalance(address: address)
            } catch {
                try Task.checkCancellation()
                self.logger.error("wallet_archived_balance_refresh_failed", error)
            }
        }
        try Task.checkCancellation()
        try await self.storage.updateArchivedWalletBalances(balances)
        return try await self.archivedWallets()
    }

    func forgetArchivedWallet(recordId: String) async throws {
        try await self.storage.removeArchivedWallet(recordId: recordId)
    }

    func removeArchivedWallets() async throws {
        try await self.storage.removeArchivedWallets()
    }

    func revealArchivedRecoveryPhrase(recordId: String) async throws -> [String] {
        try await self.withFfi {
            guard let record = try await self.storage.loadArchivedWallets()
                .first(where: { $0.descriptor.recordId == recordId }),
                  let descriptor = record.descriptor.descriptor else {
                throw WalletContext.WalletError.unavailable
            }
            let phrase = try await self.lifecycle.revealRecoveryPhrase(descriptor: descriptor)
            return phrase.phrase.split(separator: " ").map(String.init)
        }
    }

    private func signingPublicKey(for record: WalletEngineDescriptorRecord) async throws -> Data {
        guard let descriptor = record.descriptor else {
            throw WalletContext.WalletError.storage(.identityMismatch)
        }
        let phrase = try await self.lifecycle.revealRecoveryPhrase(descriptor: descriptor)
        var words = normalizedEngineMnemonic(phrase.phrase.split(whereSeparator: { $0.isWhitespace }).map(String.init))
        defer { words.removeAll(keepingCapacity: false) }
        guard try rotationMnemonicPublicKey(phrase: words.joined(separator: " ")) == record.publicKey else {
            throw WalletContext.WalletError.storage(.identityMismatch)
        }
        return try walletMnemonicSigningPublicKey(words: words)
    }

    func refresh() async throws -> WalletUpdate {
        try await self.withFfi(priority: .background, cancellation: .refresh) {
            try await self.requireClient().refresh()
        }
    }

    func refreshNfts() async throws -> WalletUpdate {
        try await self.withFfi(priority: .background, cancellation: .refreshNfts) {
            try await self.requireClient().refreshNfts()
        }
    }

    func loadMoreNfts() async throws -> WalletUpdate {
        try await self.withFfi(priority: .background, cancellation: .loadMoreNfts) {
            try await self.requireClient().loadMoreNfts()
        }
    }

    func snapshot() async throws -> WalletSnapshot {
        try await self.withFfi { try self.requireClient().snapshot() }
    }

    func waitForChange(afterRevision: UInt64) async throws -> WalletSnapshot {
        try await self.requireClient().waitForChange(afterRevision: afterRevision)
    }

    func currentClientRevision() -> UInt64 {
        self.clientRevision
    }

    func resolveDns(_ name: String) async throws -> String? {
        try await self.withFfi(priority: .userInitiated) {
            try await self.requireClient().resolveDns(name: name)
        }
    }

    func previewSend(intent: SendIntent) async throws -> SendPreview {
        try await self.withFfi(priority: .userInitiated, cancellation: .sendPreview) {
            try await self.requireClient().previewSend(request: SendPreviewRequest(intent: intent))
        }
    }

    func createEncryptedComment(recipient: String, comment: String, recipientPublicKey: Data? = nil) async throws -> String {
        try await self.withFfi(priority: .userInitiated) {
            try await self.ensureKeyRotationAllowsSigning()
            return try await self.requireClient().createEncryptedComment(request: CreateEncryptedCommentRequest(
                recipient: recipient,
                comment: comment,
                recipientPublicKey: recipientPublicKey
            ))
        }
    }

    func decryptComment(sender: String, body: String) async throws -> String {
        try await self.withFfi(priority: .userInitiated) {
            try await self.ensureKeyRotationAllowsSigning()
            return try await self.requireClient().decryptComment(request: DecryptCommentRequest(
                sender: sender,
                body: body
            ))
        }
    }

    func prepareTransfer(operationId: String, intent: SendIntent) async throws -> (recordId: String, data: WalletEngineFFI.PreparedTransfer) {
        try await self.withFfi(priority: .userInitiated) {
            try await self.ensureApiTransferAllowsSigning()
            try await self.ensureKeyRotationAllowsSigning()
            guard let config = self.clientConfig else {
                throw WalletContext.WalletError.unavailable
            }
            let data = try await self.requireClient().prepareTransfer(request: PrepareTransferRequest(
                operationId: operationId,
                intent: intent
            ))
            return (config.recordId, data)
        }
    }

    func send(operationId: String, intent: SendIntent) async throws -> WalletEngineSendExecution {
        try await self.withFfi(priority: .userInitiated, cancellation: .send) {
            try await self.ensureApiTransferAllowsSigning()
            try await self.ensureKeyRotationAllowsSigning()
            let request = SendRequest(operationId: operationId, force: false, intent: intent)
            return try await self.sendRecoveringStuckClient { client in
                try await client.send(request: request)
            }
        }
    }

    func previewNft(operationId: String, intent: NftTransferIntent) async throws -> SendPreview {
        try await self.withFfi(priority: .userInitiated, cancellation: .sendPreview) {
            try await self.requireClient().previewNftTransfer(request: NftTransferPreviewRequest(
                operationId: operationId,
                intent: intent
            ))
        }
    }

    func sendNft(operationId: String, intent: NftTransferIntent) async throws -> WalletEngineSendExecution {
        try await self.withFfi(priority: .userInitiated, cancellation: .send) {
            try await self.ensureApiTransferAllowsSigning()
            try await self.ensureKeyRotationAllowsSigning()
            let request = NftTransferRequest(
                operationId: operationId,
                force: false,
                intent: intent
            )
            return try await self.sendRecoveringStuckClient { client in
                try await client.sendNftTransfer(request: request)
            }
        }
    }

    func revealRecoveryPhrase() async throws -> [String] {
        try await self.withFfi {
            try await self.ensureCurrentWalletIdentity()
            guard let descriptor = self.descriptor else {
                throw WalletContext.WalletError.unavailable
            }
            let phrase = try await self.lifecycle.revealRecoveryPhrase(descriptor: descriptor)
            return phrase.phrase.split(separator: " ").map(String.init)
        }
    }

    func prepareKeyRotation(validUntil: UInt64) async throws -> PreparedKeyRotation {
        try await self.withFfi {
            try await self.ensureApiTransferAllowsSigning()
            try await self.ensureKeyRotationAllowsSigning()
            return try await self.requireClient().prepareKeyRotation(request: PrepareKeyRotationRequest(
                validUntil: validUntil,
                messageKind: .external
            ))
        }
    }

    func previewKeyRotation(
        operationId: String,
        signedBoc: String,
        seqno: UInt32,
        validUntil: UInt64
    ) async throws -> SendPreview {
        try await self.withFfi(priority: .userInitiated, cancellation: .sendPreview) {
            guard validUntil > UInt64(max(0, currentWalletTimestamp())) else {
                throw WalletContext.WalletError.preparedBackupDisableExpired
            }
            do {
                return try await self.requireClient().previewSendBoc(request: SendBocRequest(
                    operationId: operationId,
                    force: false,
                    signedBoc: signedBoc,
                    seqno: seqno,
                    validUntil: validUntil
                ))
            } catch {
                if walletKeyRotationPreparationIsExpired(error, seqno: seqno) {
                    throw WalletContext.WalletError.preparedBackupDisableExpired
                }
                throw error
            }
        }
    }

    func keyRotationRecord() async throws -> WalletEngineKeyRotationRecord? {
        try await self.storage.loadKeyRotation()
    }

    @discardableResult
    func reconcileKeyRotation(serverAddress: String, serverPublicKey: Data, backupEnabled: Bool, serverStateRevision: UInt64? = nil) async throws -> WalletEngineKeyRotationResolution {
        let revision = serverStateRevision ?? self.serverStateRevision
        return try await self.withFfi {
            try self.adoptServerWalletIdentity(address: serverAddress, publicKey: serverPublicKey, revision: revision)
            let result = try await self.reconcileKeyRotationUnlocked(
                serverAddress: serverAddress, serverPublicKey: serverPublicKey, backupEnabled: backupEnabled
            )
            guard self.serverStateRevision == revision else { throw CancellationError() }
            return result
        }
    }

    private func reconcileKeyRotationUnlocked(serverAddress: String, serverPublicKey: Data, backupEnabled: Bool) async throws -> WalletEngineKeyRotationResolution {
        guard let record = try await self.storage.loadKeyRotation(),
              walletEngineAddressesEqual(record.walletAddress, serverAddress),
              record.newPublicKey == serverPublicKey,
              record.phase == .submissionStarted || record.phase == .chainApplied || record.phase == .backupDisabled else {
            return .none
        }
        _ = try await self.storage.markKeyRotationChainApplied(
            operationId: record.operationId, verifiedPublicKey: serverPublicKey
        )
        if !backupEnabled {
            try await self.storage.completeKeyRotation(operationId: record.operationId)
        }
        return .confirmed(operationId: record.operationId)
    }

    func signBackupDisableProof(
        expectedAddress: String,
        expectedPublicKey: Data,
        rotationOperationId: String?,
        domain: String,
        timestamp: UInt64,
        payload: String
    ) async throws -> Data {
        try await self.withFfi {
            guard let descriptor = self.descriptor,
                  walletEngineAddressesEqual(descriptor.address, expectedAddress),
                  expectedPublicKey.count == 32 else {
                throw WalletContext.WalletError.storage(.identityMismatch)
            }
            var words: [String]
            if let rotationOperationId, let rotation = try await self.storage.loadKeyRotation() {
                guard rotation.operationId == rotationOperationId,
                      rotation.recordId == descriptor.recordId,
                      walletEngineAddressesEqual(rotation.walletAddress, expectedAddress),
                      rotation.walletPublicKey == descriptor.publicKey,
                      rotation.newPublicKey == expectedPublicKey,
                      rotation.phase == .chainApplied || rotation.phase == .backupDisabled else {
                    throw WalletContext.WalletError.storage(.identityMismatch)
                }
                words = try await self.keyRotationRecoveryPhrase(operationId: rotationOperationId)
            } else {
                try await self.ensureKeyRotationAllowsSigning()
                let phrase = try await self.lifecycle.revealRecoveryPhrase(descriptor: descriptor)
                words = normalizedEngineMnemonic(phrase.phrase.split(whereSeparator: { $0.isWhitespace }).map(String.init))
            }
            defer { words.removeAll(keepingCapacity: false) }
            guard let serverIdentity = self.serverWalletIdentity,
                  walletEngineAddressesEqual(serverIdentity.address, expectedAddress),
                  serverIdentity.publicKey == descriptor.publicKey,
                  self.descriptor?.recordId == descriptor.recordId,
                  self.descriptor?.publicKey == descriptor.publicKey,
                  self.descriptor?.secretRef == descriptor.secretRef else {
                throw WalletContext.WalletError.storage(.identityMismatch)
            }
            try Task.checkCancellation()
            if rotationOperationId == nil {
                guard expectedPublicKey == descriptor.publicKey else {
                    throw WalletContext.WalletError.storage(.identityMismatch)
                }
                let proof = try await self.lifecycle.signTonConnectProof(request: TonConnectProofSignRequest(
                    descriptor: descriptor, domain: domain, timestamp: timestamp, payload: payload
                ))
                guard proof.signature.count == 64 else {
                    throw WalletContext.WalletError.proofInvalid
                }
                return proof.signature
            }
            return try walletOwnershipProofSignature(
                words: words, expectedAnchorPublicKey: descriptor.publicKey,
                expectedSigningPublicKey: expectedPublicKey, address: expectedAddress,
                domain: domain, timestamp: timestamp, payload: payload
            )
        }
    }

    func keyRotationRecoveryPhrase(operationId: String) async throws -> [String] {
        let secret = try await self.storage.keyRotationCandidateSecret(operationId: operationId)
        guard let phrase = String(data: secret, encoding: .utf8) else {
            throw WalletContext.WalletError.storage(.corrupted)
        }
        let words = normalizedEngineMnemonic(phrase.split(whereSeparator: { $0.isWhitespace }).map(String.init))
        guard words.count == 24, detectMnemonicSchemes(words: words).contains(.rotation) else {
            throw WalletContext.WalletError.invalidMnemonic
        }
        return words
    }

    func sendKeyRotation(
        operationId: String,
        words: [String],
        previousPublicKey: Data,
        newPublicKey: Data,
        signedBoc: String,
        seqno: UInt32,
        validUntil: UInt64
    ) async throws -> SendResult {
        try await self.withFfi {
            try await self.ensureApiTransferAllowsSigning()
            try await self.ensureKeyRotationAllowsSigning()
            guard let descriptor = try await self.storage.loadDescriptor(),
                  descriptor.recordId == self.descriptor?.recordId,
                  descriptor.address == self.descriptor?.address,
                  descriptor.publicKey == self.descriptor?.publicKey,
                  descriptor.secretRef == self.descriptor?.secretRef.value else {
                throw WalletContext.WalletError.storage(.identityMismatch)
            }
            let normalizedWords = normalizedEngineMnemonic(words)
            guard normalizedWords.count == 24,
                  detectMnemonicSchemes(words: normalizedWords).contains(.rotation),
                  newPublicKey.count == 32,
                  try walletMnemonicSigningPublicKey(words: normalizedWords) == newPublicKey,
                  !signedBoc.isEmpty else {
                throw WalletContext.WalletError.invalidMnemonic
            }
            guard let replacementSecret = normalizedWords.joined(separator: " ").data(using: .utf8) else {
                throw WalletContext.WalletError.invalidMnemonic
            }
            let client = try self.requireClient()
            try await self.ensureKeyRotationAllowsSigning()
            guard previousPublicKey.count == 32,
                  let signingIdentity = self.serverWalletIdentity,
                  walletEngineAddressesEqual(signingIdentity.address, descriptor.address),
                  signingIdentity.publicKey == previousPublicKey else {
                throw WalletContext.WalletError.storage(.identityMismatch)
            }
            guard validUntil > UInt64(max(0, currentWalletTimestamp())) else {
                throw WalletContext.WalletError.preparedBackupDisableExpired
            }
            let record = try await self.storage.installKeyRotationCandidate(
                operationId: operationId,
                descriptor: descriptor,
                previousPublicKey: previousPublicKey,
                newPublicKey: newPublicKey,
                validUntil: validUntil,
                candidateSecret: replacementSecret
            )
            guard record.phase == .candidateStored else {
                throw WalletContext.WalletError.unavailable
            }
            _ = try await self.storage.markKeyRotationSubmissionStarted(operationId: operationId)
            do {
                guard let currentIdentity = self.serverWalletIdentity,
                      walletEngineAddressesEqual(currentIdentity.address, signingIdentity.address),
                      currentIdentity.publicKey == signingIdentity.publicKey else {
                    throw WalletContext.WalletError.storage(.identityMismatch)
                }
                let result = try await client.sendBoc(request: SendBocRequest(
                    operationId: operationId,
                    force: false,
                    signedBoc: signedBoc,
                    seqno: seqno,
                    validUntil: validUntil
                ))
                _ = try await self.reconcileKeyRotation(
                    operationId: result.operationId,
                    phase: result.phase,
                    retryAfterMilliseconds: nil
                )
                return result
            } catch {
                let snapshot: WalletSnapshot?
                do {
                    snapshot = try client.snapshot()
                } catch {
                    self.logger.error("wallet_key_rotation_snapshot_failed", error)
                    snapshot = nil
                }
                if let snapshot {
                    do {
                        _ = try await self.reconcileKeyRotation(send: snapshot.send)
                    } catch {
                        self.logger.error("wallet_key_rotation_reconciliation_failed", error)
                    }
                }
                throw error
            }
        }
    }

    func resolveKeyRotation() async throws -> WalletEngineKeyRotationResolution {
        try await self.withFfi {
            guard let record = try await self.storage.loadKeyRotation() else {
                return .none
            }
            if record.phase == .candidateStored {
                try await self.storage.discardUnsubmittedKeyRotation(operationId: record.operationId)
                return .rolledBack(operationId: record.operationId, phase: .cancelled)
            }
            if record.phase == .previousRestored {
                try await self.storage.cleanupRestoredKeyRotation(operationId: record.operationId)
                return .rolledBack(operationId: record.operationId, phase: .cancelled)
            }
            if record.phase == .chainApplied || record.phase == .backupDisabled {
                return try await self.resolveAppliedKeyRotation(record)
            }
            do {
                let send = try await self.requireClient().resolvePending()
                return try await self.reconcileKeyRotation(send: send)
            } catch {
                let snapshot: WalletSnapshot?
                do {
                    snapshot = try self.requireClient().snapshot()
                } catch {
                    self.logger.error("wallet_key_rotation_snapshot_failed", error)
                    snapshot = nil
                }
                if let snapshot, snapshot.send.operationId == record.operationId {
                    return try await self.reconcileKeyRotation(send: snapshot.send)
                }
                throw error
            }
        }
    }

    func reconcileKeyRotation(send: SendSnapshot) async throws -> WalletEngineKeyRotationResolution {
        try await self.reconcileKeyRotation(
            operationId: send.operationId,
            phase: send.phase,
            retryAfterMilliseconds: send.resolution?.retryAfterHintMs
        )
    }

    private func reconcileKeyRotation(
        operationId: String?,
        phase: SendPhase,
        retryAfterMilliseconds: UInt64?
    ) async throws -> WalletEngineKeyRotationResolution {
        guard let record = try await self.storage.loadKeyRotation() else {
            return .none
        }
        if record.phase == .previousRestored {
            try await self.storage.cleanupRestoredKeyRotation(operationId: record.operationId)
            return .rolledBack(operationId: record.operationId, phase: .cancelled)
        }
        if record.phase == .chainApplied || record.phase == .backupDisabled {
            return try await self.resolveAppliedKeyRotation(record)
        }
        guard operationId == record.operationId else {
            if phase == .idle {
                return try await self.resolveTerminalKeyRotation(record, phase: .cancelled)
            }
            return .pending(operationId: record.operationId, retryAfterMilliseconds: nil)
        }
        switch phase {
        case .confirmed:
            return try await self.resolveAppliedKeyRotation(record)
        case .replaced, .sequenceNumberConsumed, .expired, .superseded, .failed, .cancelled:
            return try await self.resolveTerminalKeyRotation(record, phase: phase)
        case .idle, .validating, .authorizing, .preparing, .persisting, .readyToSubmit,
             .submitting, .submissionUnknown, .submitted, .handedOff:
            return .pending(
                operationId: record.operationId,
                retryAfterMilliseconds: retryAfterMilliseconds
            )
        }
    }

    private func resolveAppliedKeyRotation(
        _ record: WalletEngineKeyRotationRecord
    ) async throws -> WalletEngineKeyRotationResolution {
        switch try await self.keyRotationChainState(record) {
        case .replacement:
            _ = try await self.storage.markKeyRotationChainApplied(
                operationId: record.operationId,
                verifiedPublicKey: record.newPublicKey
            )
            return .confirmed(operationId: record.operationId)
        case .previous:
            let expired = self.keyRotationValidityHasElapsed(record)
            try await self.storage.restorePreviousKeyRotationSecret(
                operationId: record.operationId,
                verifiedPublicKey: record.previousPublicKey,
                removeRecord: expired
            )
            if expired {
                return .rolledBack(operationId: record.operationId, phase: .expired)
            }
            return .pending(operationId: record.operationId, retryAfterMilliseconds: 1_000)
        case .different, nil:
            return .pending(operationId: record.operationId, retryAfterMilliseconds: 1_000)
        }
    }

    private func resolveTerminalKeyRotation(
        _ record: WalletEngineKeyRotationRecord,
        phase: SendPhase
    ) async throws -> WalletEngineKeyRotationResolution {
        switch try await self.keyRotationChainState(record) {
        case .replacement:
            _ = try await self.storage.markKeyRotationChainApplied(
                operationId: record.operationId,
                verifiedPublicKey: record.newPublicKey
            )
            return .confirmed(operationId: record.operationId)
        case .previous:
            try await self.storage.restorePreviousKeyRotationSecret(
                operationId: record.operationId,
                verifiedPublicKey: record.previousPublicKey,
                removeRecord: true
            )
            return .rolledBack(operationId: record.operationId, phase: phase)
        case .different, nil:
            return .pending(operationId: record.operationId, retryAfterMilliseconds: 1_000)
        }
    }

    private func keyRotationChainState(
        _ record: WalletEngineKeyRotationRecord
    ) async throws -> WalletEngineKeyRotationChainState? {
        if let serverIdentity = self.serverWalletIdentity,
           walletEngineAddressesEqual(serverIdentity.address, record.walletAddress) {
            if serverIdentity.publicKey == record.newPublicKey {
                return .replacement
            }
            if serverIdentity.publicKey != record.previousPublicKey {
                return .different
            }
        }
        do {
            let publicKey = try await self.statuslessHost.walletPublicKey(address: record.walletAddress)
            guard let latestIdentity = self.serverWalletIdentity,
                  walletEngineAddressesEqual(latestIdentity.address, record.walletAddress) else {
                return .different
            }
            if latestIdentity.publicKey == record.newPublicKey {
                return .replacement
            }
            if latestIdentity.publicKey != record.previousPublicKey {
                return .different
            }
            if publicKey == record.newPublicKey {
                return .replacement
            }
            if publicKey == record.previousPublicKey {
                return .previous
            }
            self.logger.log("event=wallet_key_rotation_public_key_mismatch")
            return .different
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            self.logger.error("wallet_key_rotation_public_key_check_failed", error)
            return nil
        }
    }

    private func keyRotationValidityHasElapsed(_ record: WalletEngineKeyRotationRecord) -> Bool {
        let (deadline, overflow) = record.validUntil.addingReportingOverflow(120)
        guard !overflow else {
            return false
        }
        return UInt64(max(0, Date().timeIntervalSince1970.rounded(.down))) > deadline
    }

    func completeKeyRotationAfterBackupDisabled(operationId: String) async throws {
        try await self.withFfi {
            guard let record = try await self.storage.loadKeyRotation() else {
                return
            }
            guard record.operationId == operationId,
                  (record.phase == .chainApplied || record.phase == .backupDisabled) else {
                throw WalletContext.WalletError.storage(.corrupted)
            }
            let serverConfirmed = self.serverWalletIdentity.map {
                walletEngineAddressesEqual($0.address, record.walletAddress) && $0.publicKey == record.newPublicKey
            } ?? false
            if !serverConfirmed {
                guard try await self.keyRotationChainState(record) == .replacement else {
                    throw WalletContext.WalletError.operationInProgress
                }
            }
            _ = try await self.storage.markKeyRotationChainApplied(
                operationId: record.operationId,
                verifiedPublicKey: record.newPublicKey
            )
            try await self.storage.completeKeyRotation(operationId: operationId)
        }
    }

    func tonConnectIdentity() async throws -> TonConnectWalletIdentity {
        try await self.withFfi {
            guard let descriptor = self.descriptor else { throw WalletContext.WalletError.unavailable }
            let account = try self.lifecycle.tonConnectAccount(descriptor: descriptor)
            return TonConnectWalletIdentity(recordId: descriptor.recordId, address: account.address, network: account.network, publicKey: account.publicKey)
        }
    }

    private func validateTonConnectWallet(_ wallet: TonConnectWalletIdentity) throws {
        guard let descriptor = self.descriptor, descriptor.recordId == wallet.recordId else { throw WalletContext.WalletError.unavailable }
        let account = try self.lifecycle.tonConnectAccount(descriptor: descriptor)
        guard walletEngineAddressesEqual(account.address, wallet.address), account.network == wallet.network,
              wallet.publicKey == account.publicKey else { throw TonConnectFailure.keyMismatch }
    }

    func tonConnectAccount(wallet: TonConnectWalletIdentity) async throws -> TonConnectAccountInfo {
        try await self.withFfi {
            try self.validateTonConnectWallet(wallet)
            guard let descriptor = self.descriptor else {
                throw WalletContext.WalletError.unavailable
            }
            return try self.lifecycle.tonConnectAccount(descriptor: descriptor)
        }
    }

    func signTonConnectProof(
        wallet: TonConnectWalletIdentity,
        domain: String,
        timestamp: UInt64,
        payload: String,
        beforeSigning: @escaping @Sendable () throws -> Void = {}
    ) async throws -> TonConnectProofSignature {
        try await self.withFfi(beforeSigning: beforeSigning) {
            try self.validateTonConnectWallet(wallet)
            try await self.ensureKeyRotationAllowsSigning()
            guard let descriptor = self.descriptor else {
                throw WalletContext.WalletError.unavailable
            }
            try beforeSigning()
            return try await self.lifecycle.signTonConnectProof(request: TonConnectProofSignRequest(
                descriptor: descriptor,
                domain: domain,
                timestamp: timestamp,
                payload: payload
            ))
        }
    }

    func previewTonConnect(_ request: SendRequest, wallet: TonConnectWalletIdentity) async throws -> SendPreview {
        try await self.withFfi(priority: .userInitiated, cancellation: .sendPreview) {
            try self.validateTonConnectWallet(wallet)
            return try await self.requireClient().previewTonConnect(request: request)
        }
    }

    func previewSignMessage(_ request: SignMessageRequest, wallet: TonConnectWalletIdentity) async throws -> SignMessagePreview {
        try await self.withFfi(priority: .userInitiated, cancellation: .sendPreview) {
            try self.validateTonConnectWallet(wallet)
            return try await self.requireClient().previewSignMessage(request: SendPreviewRequest(intent: request.intent))
        }
    }

    func sendTonConnect(_ request: SendRequest, wallet: TonConnectWalletIdentity, beforeSigning: @escaping @Sendable () throws -> Void = {}) async throws -> SendResult {
        try await self.withFfi(priority: .userInitiated, cancellation: .send, beforeSigning: beforeSigning) {
            try await self.ensureApiTransferAllowsSigning()
            try self.validateTonConnectWallet(wallet)
            try await self.ensureKeyRotationAllowsSigning()
            let client = try self.requireClient()
            try beforeSigning()
            return try await client.send(request: request)
        }
    }

    func signMessage(_ request: SignMessageRequest, wallet: TonConnectWalletIdentity, beforeSigning: @escaping @Sendable () throws -> Void = {}) async throws -> SignMessageResult {
        try await self.withFfi(priority: .userInitiated, cancellation: .send, beforeSigning: beforeSigning) {
            try await self.ensureApiTransferAllowsSigning()
            try self.validateTonConnectWallet(wallet)
            try await self.ensureKeyRotationAllowsSigning()
            let client = try self.requireClient()
            try beforeSigning()
            return try await client.signMessage(request: request)
        }
    }

    func shutdown() async {
        do {
            try await self.withFfi {
                await self.discardTransientReplacementUnlocked()
                await self.platformHost.removeAllTransientProtectedSecrets()
                try await self.shutdownClient()
            }
        } catch {
            self.logger.error("wallet_engine_shutdown_failed", error)
        }
    }

    private func recoverKeyRotationAfterActivation(
        record descriptor: WalletEngineDescriptorRecord,
        client: WalletClient
    ) async throws {
        guard let rotation = try await self.storage.loadKeyRotation() else {
            return
        }
        guard rotation.recordId == descriptor.recordId,
              walletEngineAddressesEqual(rotation.walletAddress, descriptor.address),
              rotation.walletPublicKey == descriptor.publicKey,
              rotation.activeSecretRef == descriptor.secretRef else {
            if rotation.recordId == descriptor.recordId || rotation.activeSecretRef == descriptor.secretRef {
                throw WalletContext.WalletError.storage(.corrupted)
            }
            try await self.storage.discardOrphanedKeyRotation(
                operationId: rotation.operationId,
                activeSecretRef: descriptor.secretRef
            )
            return
        }
        if let serverIdentity = self.serverWalletIdentity,
           walletEngineAddressesEqual(serverIdentity.address, rotation.walletAddress),
           serverIdentity.publicKey == rotation.newPublicKey,
           rotation.phase == .submissionStarted || rotation.phase == .chainApplied || rotation.phase == .backupDisabled {
            _ = try await self.storage.markKeyRotationChainApplied(
                operationId: rotation.operationId, verifiedPublicKey: rotation.newPublicKey
            )
            return
        }
        switch rotation.phase {
        case .candidateStored:
            try await self.storage.discardUnsubmittedKeyRotation(operationId: rotation.operationId)
        case .submissionStarted:
            do {
                let send = try await client.resolvePending()
                _ = try await self.reconcileKeyRotation(send: send)
            } catch {
                self.logger.error("wallet_key_rotation_recovery_failed", error)
            }
        case .chainApplied, .backupDisabled:
            _ = try await self.resolveAppliedKeyRotation(rotation)
        case .previousRestored:
            try await self.storage.cleanupRestoredKeyRotation(operationId: rotation.operationId)
        }
    }

    private func shutdownClient() async throws {
        if let client = self.client {
            self.client = nil
            self.clientConfig = nil
            try await client.shutdown()
        }
    }

    private func makeClient(
        config: WalletClientConfig,
        statuslessHost: WalletEngineStatuslessHost? = nil
    ) throws -> WalletClient {
        try WalletClient.newStatusless(
            config: config,
            statuslessHost: statuslessHost ?? self.statuslessHost,
            platformHost: self.platformHost
        )
    }

    private func sendRecoveringStuckClient(
        _ operation: (WalletClient) async throws -> SendResult
    ) async throws -> WalletEngineSendExecution {
        let client = try self.requireClient()
        do {
            return WalletEngineSendExecution(
                result: try await operation(client),
                didRecreateClient: false
            )
        } catch {
            guard walletEngineIsSendAlreadyInProgress(error) else {
                throw error
            }
            guard self.client === client, let config = self.clientConfig else {
                throw error
            }

            self.logger.error("wallet_engine_stuck_send_recovery_started", error)
            try await client.shutdown()
            self.client = nil
            let replacementStatuslessHost = WalletEngineStatuslessHost(
                engine: self.engine,
                logger: self.logger
            )
            let replacement: WalletClient
            do {
                replacement = try self.makeClient(
                    config: config,
                    statuslessHost: replacementStatuslessHost
                )
            } catch {
                self.clientConfig = nil
                throw error
            }
            self.statuslessHost = replacementStatuslessHost
            self.client = replacement
            self.clientRevision &+= 1
            return WalletEngineSendExecution(
                result: try await operation(replacement),
                didRecreateClient: true
            )
        }
    }

    func ensureApiTransferAllowsSigning() async throws {
        guard let descriptor = self.descriptor else { throw WalletContext.WalletError.unavailable }
        if let record = try await self.storage.loadTransferSubmissions().first(where: {
            $0.recordId == descriptor.recordId || walletEngineAddressesEqual($0.walletAddress, descriptor.address)
        }),
           record.resolution == .pending {
            throw WalletContext.WalletError.operationInProgress
        }
    }

    private func ensureKeyRotationAllowsSigning() async throws {
        if try await self.storage.loadKeyRotation() != nil {
            throw WalletContext.WalletError.operationInProgress
        }
        try await self.ensureCurrentWalletIdentity()
    }

    private func ensureCurrentWalletIdentity() async throws {
        guard let descriptor = self.descriptor,
              let serverIdentity = self.serverWalletIdentity,
              walletEngineAddressesEqual(descriptor.address, serverIdentity.address),
              descriptor.publicKey == serverIdentity.publicKey,
              let stored = try await self.storage.loadDescriptor(),
              stored.recordId == descriptor.recordId,
              stored.publicKey == descriptor.publicKey,
              stored.secretRef == descriptor.secretRef.value else {
            throw WalletContext.WalletError.storage(.identityMismatch)
        }
        let signingPublicKey = try await self.signingPublicKey(for: stored)
        guard let currentIdentity = self.serverWalletIdentity,
              walletEngineAddressesEqual(currentIdentity.address, descriptor.address),
              currentIdentity.publicKey == descriptor.publicKey,
              self.descriptor?.recordId == descriptor.recordId,
              self.descriptor?.publicKey == descriptor.publicKey,
              self.descriptor?.secretRef == descriptor.secretRef else {
            throw WalletContext.WalletError.storage(.identityMismatch)
        }
        if stored.signingPublicKey != signingPublicKey {
            try await self.storage.saveDescriptor(stored.withSigningPublicKey(signingPublicKey))
        }
        guard let latestIdentity = self.serverWalletIdentity,
              walletEngineAddressesEqual(latestIdentity.address, descriptor.address),
              latestIdentity.publicKey == descriptor.publicKey,
              self.descriptor?.recordId == descriptor.recordId,
              self.descriptor?.publicKey == descriptor.publicKey,
              self.descriptor?.secretRef == descriptor.secretRef else {
            throw WalletContext.WalletError.storage(.identityMismatch)
        }
    }

    private func requireClient() throws -> WalletClient {
        guard let client = self.client else {
            throw WalletContext.WalletError.unavailable
        }
        return client
    }

    private func withFfi<Value>(
        priority: FfiPriority = .userInitiated,
        cancellation: FfiCancellation = .none,
        beforeSigning: (@Sendable () throws -> Void)? = nil,
        _ operation: @escaping () async throws -> Value
    ) async throws -> Value {
        if let session = WalletAuthorizationScope.session {
            try await session.waitUntilAvailable()
        }
        await self.acquireFfi(priority: priority)
        defer {
            self.activeFfiOperation = nil
            self.releaseFfi()
        }
        if let session = WalletAuthorizationScope.session {
            try await session.waitUntilAvailable()
        }
        try Task.checkCancellation()
        let operationId = UUID()
        self.activeFfiOperation = (operationId, cancellation)
        await self.platformHost.setAuthorization(WalletAuthorizationScope.session)
        await self.platformHost.setTonConnectSigningGuard(beforeSigning)
        let operationTask = Task { () -> Result<Value, Error> in
            do {
                return .success(try await operation())
            } catch {
                return .failure(error)
            }
        }
        let result = await withTaskCancellationHandler(operation: {
            await operationTask.value
        }, onCancel: { [weak self] in
            Task {
                await self?.cancelActiveFfiOperation(id: operationId, cancellation: cancellation)
            }
        })
        await self.platformHost.setTonConnectSigningGuard(nil)
        await self.platformHost.setAuthorization(nil)
        try Task.checkCancellation()
        return try result.get()
    }

    private func acquireFfi(priority: FfiPriority = .userInitiated) async {
        if !self.ffiBusy {
            self.ffiBusy = true
            return
        }
        await withCheckedContinuation { continuation in
            switch priority {
            case .userInitiated:
                self.userInitiatedFfiWaiters.append(continuation)
            case .background:
                self.backgroundFfiWaiters.append(continuation)
            }
        }
    }

    private func releaseFfi() {
        if !self.userInitiatedFfiWaiters.isEmpty {
            self.userInitiatedFfiWaiters.removeFirst().resume()
        } else if !self.backgroundFfiWaiters.isEmpty {
            self.backgroundFfiWaiters.removeFirst().resume()
        } else {
            self.ffiBusy = false
        }
    }

    private func cancelActiveFfiOperation(id: UUID, cancellation: FfiCancellation) async {
        guard cancellation != .none,
              self.activeFfiOperation?.id == id,
              self.activeFfiOperation?.cancellation == cancellation,
              let client = self.client else {
            return
        }
        do {
            switch cancellation {
            case .none:
                return
            case .refresh:
                try await client.cancelRefresh()
            case .refreshNfts:
                try await client.cancelRefreshNfts()
            case .loadMoreNfts:
                try await client.cancelLoadMoreNfts()
            case .sendPreview:
                try await client.cancelSendPreview()
            case .send:
                try await client.cancelSend()
            }
        } catch {
            self.logger.error("wallet_engine_operation_cancellation_failed", error)
        }
    }
}

@available(macOS 10.15, *)
func walletEngineIsSendAlreadyInProgress(_ error: Error) -> Bool {
    guard let error = error as? WalletClientError else {
        return false
    }
    if case .SendAlreadyInProgress = error {
        return true
    }
    return false
}

@available(macOS 10.15, *)
func normalizedEngineMnemonic(_ words: [String]) -> [String] {
    words.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        .filter { !$0.isEmpty }
}

@available(macOS 10.15, *)
func walletEngineAddressesEqual(_ lhs: String, _ rhs: String) -> Bool {
    guard let left = try? convertTonAddress(value: lhs, format: .raw),
          let right = try? convertTonAddress(value: rhs, format: .raw) else {
        return lhs == rhs
    }
    return left == right
}

@available(macOS 10.15, *)
extension WalletEngineRuntime {
    func validateTonConnectAccess(wallet: TonConnectWalletIdentity) async throws {
        try await self.withTonConnectAnchor(wallet: wallet) { _ in () }
    }

    func tonConnectSessionPublicKey(wallet: TonConnectWalletIdentity, session: TelegramCore.WalletTonConnectSession) async throws -> String {
        try await self.withTonConnectSession(wallet: wallet, session: session, allowPendingRegistration: true) {
            $0.publicKey.map { String(format: "%02x", $0) }.joined()
        }
    }

    func openTonConnectChallenge(_ data: Data, wallet: TonConnectWalletIdentity, session: TelegramCore.WalletTonConnectSession) async throws -> Data {
        try await self.withTonConnectSession(wallet: wallet, session: session, allowPendingRegistration: true) {
            try $0.openChallenge(data)
        }
    }

    func openTonConnectPacket(_ data: Data, wallet: TonConnectWalletIdentity, session: TelegramCore.WalletTonConnectSession) async throws -> Data {
        try await self.withTonConnectSession(wallet: wallet, session: session, allowPendingRegistration: false) {
            try $0.open(data)
        }
    }

    func sealTonConnectPacket(_ data: Data, wallet: TonConnectWalletIdentity, session: TelegramCore.WalletTonConnectSession) async throws -> Data {
        try await self.withTonConnectSession(wallet: wallet, session: session, allowPendingRegistration: true) {
            try $0.seal(data)
        }
    }

    func signTonConnectData(_ digest: Data, wallet: TonConnectWalletIdentity, beforeSigning: @escaping @Sendable () throws -> Void = {}) async throws -> Data {
        try await self.withTonConnectAnchor(wallet: wallet, beforeSigning: beforeSigning) { anchor in
            try beforeSigning()
            return try anchor.sign(digest)
        }
    }

    private func withTonConnectAnchor<Value>(wallet: TonConnectWalletIdentity, beforeSigning: (@Sendable () throws -> Void)? = nil, _ operation: @escaping (TonConnectAnchorKey) throws -> Value) async throws -> Value {
        try await self.withFfi(beforeSigning: beforeSigning) {
            try self.validateTonConnectWallet(wallet)
            _ = try self.requireClient()
            try await self.ensureKeyRotationAllowsSigning()
            guard let descriptor = self.descriptor else { throw WalletContext.WalletError.unavailable }
            let account = try self.lifecycle.tonConnectAccount(descriptor: descriptor)
            guard account.publicKey.count == 32, account.publicKey == descriptor.publicKey else {
                throw TonConnectFailure.keyMismatch
            }
            let phrase = try await self.lifecycle.revealRecoveryPhrase(descriptor: descriptor)
            var words = normalizedEngineMnemonic(phrase.phrase.split(whereSeparator: { $0.isWhitespace }).map(String.init))
            defer { words.removeAll(keepingCapacity: false) }
            let validatedPublicKey = try rotationMnemonicPublicKey(phrase: words.joined(separator: " "))
            guard validatedPublicKey == account.publicKey else { throw TonConnectFailure.keyMismatch }
            try await self.ensureKeyRotationAllowsSigning()
            try self.validateTonConnectWallet(wallet)
            _ = try self.requireClient()
            guard self.descriptor?.publicKey == descriptor.publicKey,
                  self.descriptor?.secretRef.value == descriptor.secretRef.value else {
                throw TonConnectFailure.keyMismatch
            }
            try Task.checkCancellation()
            let anchor = try TonConnectAnchorKey.derive(validatedRotationMnemonic: words, expectedPublicKey: account.publicKey)
            return try operation(anchor)
        }
    }

    private func withTonConnectSession<Value>(wallet: TonConnectWalletIdentity, session: TelegramCore.WalletTonConnectSession, allowPendingRegistration: Bool, _ operation: @escaping (TonConnectSessionCrypto) throws -> Value) async throws -> Value {
        let appPublicKey = try Self.tonConnectPublicKey(session.dappClientId)
        let registeredPublicKey = try session.clientId.map(Self.tonConnectPublicKey)
        guard registeredPublicKey != nil || (allowPendingRegistration && session.isPending && !session.isClosing && !session.isClosed) else {
            throw TonConnectFailure.keyMismatch
        }
        return try await self.withTonConnectAnchor(wallet: wallet) { anchor in
            try anchor.withSeed { seed in
                let crypto = try TonConnectSessionCrypto(anchorSeed: seed, appPublicKey: appPublicKey, serverNonce: session.nonce)
                if let registeredPublicKey, crypto.publicKey != registeredPublicKey {
                    throw TonConnectFailure.keyMismatch
                }
                return try operation(crypto)
            }
        }
    }

    private static func tonConnectPublicKey(_ value: String) throws -> Data {
        guard value.utf8.count == 64 else { throw TonConnectFailure.unavailable }
        let bytes = Array(value.utf8)
        func nibble(_ byte: UInt8) throws -> UInt8 {
            switch byte {
            case 48...57: return byte - 48
            case 65...70: return byte - 55
            case 97...102: return byte - 87
            default: throw TonConnectFailure.unavailable
            }
        }
        var result = Data(capacity: 32)
        for index in stride(from: 0, to: bytes.count, by: 2) {
            result.append(try (nibble(bytes[index]) << 4) | nibble(bytes[index + 1]))
        }
        return result
    }
}
