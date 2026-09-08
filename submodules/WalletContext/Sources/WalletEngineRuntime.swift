import Foundation
import TelegramCore
import WalletEngineFFI

struct WalletEngineActivation: @unchecked Sendable {
    let snapshot: WalletSnapshot
    let canSign: Bool
}

struct WalletEngineStagedWallet: Equatable, Sendable {
    let recordId: String
    let address: String
    let publicKey: Data
}

struct WalletEngineSendExecution: @unchecked Sendable {
    let result: SendResult
    let didRecreateClient: Bool
    let receipt: WalletEngineTransferReceipt?

    init(result: SendResult, didRecreateClient: Bool, receipt: WalletEngineTransferReceipt? = nil) {
        self.result = result
        self.didRecreateClient = didRecreateClient
        self.receipt = receipt
    }
}

enum WalletEngineKeyRotationResolution: Equatable, Sendable {
    case none
    case pending(operationId: String, retryAfterMilliseconds: UInt64?)
    case confirmed(operationId: String)
    case rolledBack(operationId: String, phase: SendPhase)
}

private enum WalletEngineKeyRotationChainState: Equatable {
    case replacement
    case previous
    case different
}

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
    private let engine: TelegramEngine
    private let logger: WalletLogger
    private let platformHost: WalletEnginePlatformHost
    private var statuslessHost: WalletEngineStatuslessHost
    private let lifecycle: WalletLifecycle
    private var client: WalletClient?
    private var clientConfig: WalletClientConfig?
    private var clientRevision: UInt64 = 0
    private var descriptor: WalletDescriptor?
    private var transientReplacementDescriptor: WalletDescriptor?
    private var tonConnectSession: TonConnectSession?
    private var ffiBusy = false
    private var userInitiatedFfiWaiters: [CheckedContinuation<Void, Never>] = []
    private var backgroundFfiWaiters: [CheckedContinuation<Void, Never>] = []
    private var activeFfiOperation: (id: UUID, cancellation: FfiCancellation)?

    init(engine: TelegramEngine, storage: WalletEngineStorage, logger: WalletLogger) {
        self.storage = storage
        self.engine = engine
        self.logger = logger
        self.platformHost = WalletEnginePlatformHost(storage: storage, logger: logger)
        self.statuslessHost = WalletEngineStatuslessHost(engine: engine, storage: storage, logger: logger)
        self.lifecycle = WalletLifecycle(platformHost: self.platformHost)
    }

    func activate(
        serverAddress: String,
        serverPublicKey: Data
    ) async throws -> WalletEngineActivation {
        try await self.withFfi {
            try await self.activateUnlocked(
                serverAddress: serverAddress,
                serverPublicKey: serverPublicKey
            )
        }
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
            let record = WalletEngineDescriptorRecord(descriptor: imported)
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
                publicKey: record.publicKey
            )
        }
    }

    func stageTransientReplacement(words: [String]) async throws -> WalletEngineStagedWallet {
        let recordId = UUID().uuidString.lowercased()
        do {
            return try await self.withFfi {
                guard try await self.storage.loadReplacementCandidate() == nil else {
                    throw WalletContext.WalletError.operationInProgress
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
                    publicKey: imported.publicKey
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
            guard expectedPublicKey.count == 32,
                  let descriptor = self.transientReplacementDescriptor,
                  descriptor.recordId == recordId,
                  descriptor.publicKey == expectedPublicKey,
                  await self.platformHost.containsTransientProtectedSecret(secretRef: descriptor.secretRef) else {
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
            _ = try await self.materializeTransientReplacementUnlocked(recordId: recordId)
        }
    }

    func commitReplacement(
        recordId: String,
        serverAddress: String,
        serverPublicKey: Data
    ) async throws -> WalletEngineActivation {
        try await self.withFfi {
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
            try await self.promoteReplacementCandidate(candidate)
            return try await self.activateUnlocked(
                serverAddress: serverAddress,
                serverPublicKey: serverPublicKey
            )
        }
    }

    /// Reconciles a candidate against an authoritative wallet.getState result.
    /// A mismatch from stateUpdates alone must not discard an ambiguous candidate.
    func reconcileReplacementCandidate(
        serverAddress: String,
        serverPublicKey: Data,
        discardMismatch: Bool
    ) async throws -> Bool {
        try await self.withFfi {
            guard let candidate = try await self.storage.loadReplacementCandidate() else {
                return false
            }
            if walletEngineAddressesEqual(candidate.address, serverAddress),
               candidate.publicKey == serverPublicKey,
               candidate.descriptor != nil {
                try await self.promoteReplacementCandidate(candidate)
                return true
            } else if discardMismatch {
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
        serverPublicKey: Data
    ) async throws -> WalletEngineActivation {
        guard serverPublicKey.count == 32 else {
            throw WalletContext.WalletError.storage(.identityMismatch)
        }
        self.tonConnectSession = nil
        try await self.shutdownClient()

        let stored = try await self.storage.loadDescriptor()
        var selectedRecord: WalletEngineDescriptorRecord?
        if let stored,
           stored.schemaVersion == 2,
           stored.network == "mainnet",
           walletEngineAddressesEqual(stored.address, serverAddress),
           stored.publicKey.count == 32,
           stored.publicKey == serverPublicKey {
            if let secretRef = stored.secretRef,
               try await self.storage.containsProtectedSecret(ProtectedSecretRef(value: secretRef)) {
                selectedRecord = stored
            } else {
                selectedRecord = WalletEngineDescriptorRecord(
                    recordId: stored.recordId,
                    address: stored.address,
                    publicKey: stored.publicKey,
                    secretRef: nil
                )
            }
        }

        let record = selectedRecord ?? WalletEngineDescriptorRecord(
            recordId: UUID().uuidString.lowercased(),
            address: serverAddress,
            publicKey: serverPublicKey,
            secretRef: nil
        )
        try await self.storage.saveDescriptor(record)
        if let stored,
           stored.recordId != record.recordId,
           stored.secretRef != record.secretRef {
            try await self.deleteLocalWallet(stored)
        }

        let config = WalletClientConfig(
            recordId: record.recordId,
            address: record.address,
            publicKey: record.publicKey,
            localSecretRef: record.secretRef.map(ProtectedSecretRef.init(value:)),
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
        self.client = client
        self.clientConfig = config
        self.clientRevision &+= 1
        self.descriptor = record.descriptor
        try await self.recoverKeyRotationAfterActivation(record: record, client: client)
        return WalletEngineActivation(
            snapshot: try client.snapshot(),
            canSign: record.secretRef != nil
        )
    }

    private func promoteReplacementCandidate(_ candidate: WalletEngineDescriptorRecord) async throws {
        let previous = try await self.storage.loadDescriptor()
        // Persisting the active descriptor is the durable commit point.
        try await self.storage.saveDescriptor(candidate)
        try await self.storage.removeReplacementCandidate()
        if let previous,
           previous.recordId != candidate.recordId,
           previous.secretRef != candidate.secretRef {
            try await self.deleteLocalWallet(previous)
        }
    }

    private func materializeTransientReplacementUnlocked(recordId: String) async throws -> WalletEngineDescriptorRecord {
        guard let descriptor = self.transientReplacementDescriptor,
              descriptor.recordId == recordId,
              let secret = await self.platformHost.transientProtectedSecret(secretRef: descriptor.secretRef),
              !secret.isEmpty else {
            throw WalletContext.WalletError.storage(.identityMismatch)
        }
        let record = WalletEngineDescriptorRecord(descriptor: descriptor)
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

    func createEncryptedComment(recipient: String, comment: String) async throws -> String {
        try await self.withFfi(priority: .userInitiated) {
            try await self.ensureKeyRotationAllowsSigning()
            return try await self.requireClient().createEncryptedComment(request: CreateEncryptedCommentRequest(
                recipient: recipient,
                comment: comment
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

    func send(pendingTransfer: WalletContext.PendingTransfer, intent: SendIntent, useWalletTransferApi: Bool) async throws -> WalletEngineSendExecution {
        try await self.withFfi(priority: .userInitiated, cancellation: .send) {
            try await self.ensureKeyRotationAllowsSigning()
            guard let config = self.clientConfig else {
                throw WalletContext.WalletError.unavailable
            }
            let request = SendRequest(
                operationId: pendingTransfer.id,
                force: false,
                intent: intent
            )
            // Keep the selected route for the entire operation, including client recreation.
            let submission: WalletEngineTransferSubmission? = useWalletTransferApi ? WalletEngineTransferSubmission(
                recordId: config.recordId,
                walletAddress: config.address,
                pendingTransfer: pendingTransfer
            ) : nil
            return try await self.sendRecoveringStuckClient(transferSubmission: submission) { client in
                try await client.send(request: request)
            }
        }
    }

    func transferReceipt(operationId: String) async -> WalletEngineTransferReceipt? {
        guard let recordId = self.clientConfig?.recordId else { return nil }
        do {
            return try await self.storage.loadTransferReceipts().last {
                $0.recordId == recordId && $0.pendingTransfer.id == operationId
            }
        } catch {
            self.logger.error("wallet_transfer_receipt_load_failed", error)
            return nil
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
            guard let descriptor = self.descriptor else {
                throw WalletContext.WalletError.unavailable
            }
            let phrase = try await self.lifecycle.revealRecoveryPhrase(descriptor: descriptor)
            return phrase.phrase.split(separator: " ").map(String.init)
        }
    }

    func prepareKeyRotation(validUntil: UInt64) async throws -> PreparedKeyRotation {
        try await self.withFfi {
            guard try await self.storage.loadKeyRotation() == nil else {
                throw WalletContext.WalletError.operationInProgress
            }
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
            try await self.requireClient().previewSendBoc(request: SendBocRequest(
                operationId: operationId,
                force: false,
                signedBoc: signedBoc,
                seqno: seqno,
                validUntil: validUntil
            ))
        }
    }

    func keyRotationRecord() async throws -> WalletEngineKeyRotationRecord? {
        try await self.storage.loadKeyRotation()
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
        newPublicKey: Data,
        signedBoc: String,
        seqno: UInt32,
        validUntil: UInt64
    ) async throws -> SendResult {
        try await self.withFfi {
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
                  !signedBoc.isEmpty else {
                throw WalletContext.WalletError.invalidMnemonic
            }
            guard let replacementSecret = normalizedWords.joined(separator: " ").data(using: .utf8) else {
                throw WalletContext.WalletError.invalidMnemonic
            }
            let client = try self.requireClient()
            let snapshot = try client.snapshot()
            let previousPublicKey: Data
            do {
                previousPublicKey = try await self.statuslessHost.walletPublicKey(address: descriptor.address)
            } catch {
                switch snapshot.account?.status {
                case .nonexistent, .uninitialized:
                    // Before the first deployment, the signing key is the
                    // stable anchor key represented by the descriptor.
                    previousPublicKey = descriptor.publicKey
                case .active, .frozen, .unknown, nil:
                    throw error
                }
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
                // submissionStarted is the app's durable boundary. An absent or
                // unrelated snapshot does not prove that provider handoff did
                // not happen, so both secrets remain stored for reconciliation.
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
        do {
            let publicKey = try await self.statuslessHost.walletPublicKey(address: record.walletAddress)
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
            guard try await self.keyRotationChainState(record) == .replacement else {
                throw WalletContext.WalletError.operationInProgress
            }
            _ = try await self.storage.markKeyRotationChainApplied(
                operationId: record.operationId,
                verifiedPublicKey: record.newPublicKey
            )
            try await self.storage.completeKeyRotation(operationId: operationId)
        }
    }

    func tonConnectAccount() async throws -> TonConnectAccountInfo {
        try await self.withFfi {
            guard let descriptor = self.descriptor else {
                throw WalletContext.WalletError.unavailable
            }
            return try self.lifecycle.tonConnectAccount(descriptor: descriptor)
        }
    }

    func signTonConnectProof(
        domain: String,
        timestamp: UInt64,
        payload: String
    ) async throws -> TonConnectProofSignature {
        try await self.withFfi {
            try await self.ensureKeyRotationAllowsSigning()
            guard let descriptor = self.descriptor else {
                throw WalletContext.WalletError.unavailable
            }
            return try await self.lifecycle.signTonConnectProof(request: TonConnectProofSignRequest(
                descriptor: descriptor,
                domain: domain,
                timestamp: timestamp,
                payload: payload
            ))
        }
    }

    func previewTonConnect(_ request: SendRequest) async throws -> SendPreview {
        try await self.withFfi(priority: .userInitiated, cancellation: .sendPreview) {
            try await self.requireClient().previewTonConnect(request: request)
        }
    }

    func previewSignMessage(_ request: SignMessageRequest) async throws -> SignMessagePreview {
        try await self.withFfi(priority: .userInitiated, cancellation: .sendPreview) {
            try await self.requireClient().previewSignMessage(request: SendPreviewRequest(intent: request.intent))
        }
    }

    func sendTonConnect(_ request: SendRequest) async throws -> SendResult {
        try await self.withFfi(priority: .userInitiated, cancellation: .send) {
            try await self.ensureKeyRotationAllowsSigning()
            return try await self.requireClient().send(request: request)
        }
    }

    func signMessage(_ request: SignMessageRequest) async throws -> SignMessageResult {
        try await self.withFfi(priority: .userInitiated, cancellation: .send) {
            try await self.ensureKeyRotationAllowsSigning()
            return try await self.requireClient().signMessage(request: request)
        }
    }

    func shutdown() async {
        do {
            try await self.withFfi {
                await self.discardTransientReplacementUnlocked()
                await self.platformHost.removeAllTransientProtectedSecrets()
                self.tonConnectSession = nil
                try await self.shutdownClient()
            }
        } catch {
            self.logger.error("wallet_engine_shutdown_failed", error)
        }
    }

    func restoreTonConnectSession(persisted: String, config: TonConnectSessionConfig) async throws -> TonConnectSessionPhase {
        try await self.withFfi {
            let session = try tonConnectSessionRestore(persisted: persisted, config: config)
            self.tonConnectSession = session
            return try session.phase()
        }
    }

    func startTonConnectSession(link: String, config: TonConnectSessionConfig) async throws -> TonConnectConnectPrompt {
        try await self.withFfi {
            let session = try tonConnectSessionFromLink(link: link, config: config)
            guard let prompt = try session.connectPrompt() else {
                throw WalletContext.WalletError.unavailable
            }
            self.tonConnectSession = session
            return prompt
        }
    }

    func tonConnectPhase() async throws -> TonConnectSessionPhase {
        try await self.withFfi { try self.requireTonConnectSession().phase() }
    }

    func tonConnectPrompt() async throws -> TonConnectConnectPrompt? {
        try await self.withFfi { try self.requireTonConnectSession().connectPrompt() }
    }

    func tonConnectPendingRequests(now: UInt64) async throws -> [TonConnectIncomingRequest] {
        try await self.withFfi { try self.requireTonConnectSession().pendingRequests(now: now) }
    }

    func tonConnectPendingPost() async throws -> TonConnectPreparedPost? {
        try await self.withFfi { try self.requireTonConnectSession().pendingPost() }
    }

    func tonConnectPersisted() async throws -> String {
        try await self.withFfi { try self.requireTonConnectSession().persisted() }
    }

    func tonConnectApprove(account: TonConnectAccountInfo, proof: TonConnectProofReply?, device: TonConnectDevice) async throws -> TonConnectPreparedPost {
        try await self.withFfi {
            try self.requireTonConnectSession().approveConnect(account: account, proof: proof, device: device)
        }
    }

    func tonConnectReject(message: String) async throws -> TonConnectPreparedPost {
        try await self.withFfi { try self.requireTonConnectSession().rejectConnect(message: message) }
    }

    func tonConnectPrepareSendSuccess(requestId: String, signedBoc: String) async throws -> TonConnectPreparedPost {
        try await self.withFfi {
            try self.requireTonConnectSession().prepareSendSuccess(requestId: requestId, signedBoc: signedBoc)
        }
    }

    func tonConnectPrepareSignSuccess(requestId: String, internalBoc: String) async throws -> TonConnectPreparedPost {
        try await self.withFfi {
            try self.requireTonConnectSession().prepareSignMessageSuccess(requestId: requestId, internalBoc: internalBoc)
        }
    }

    func tonConnectPrepareDisconnectSuccess(requestId: String) async throws -> TonConnectPreparedPost {
        try await self.withFfi {
            try self.requireTonConnectSession().prepareDisconnectSuccess(requestId: requestId)
        }
    }

    func tonConnectPrepareError(requestId: String, code: TonConnectRpcErrorCode, message: String) async throws -> TonConnectPreparedPost {
        try await self.withFfi {
            try self.requireTonConnectSession().prepareError(requestId: requestId, code: code, message: message)
        }
    }

    func tonConnectBeginEventsSubscription() async throws -> String {
        try await self.withFfi { try self.requireTonConnectSession().beginEventsSubscription() }
    }

    func tonConnectIngestSseChunk(_ chunk: Data, now: UInt64) async throws -> [TonConnectIncomingRequest] {
        try await self.withFfi {
            try self.requireTonConnectSession().ingestSseChunk(chunk: chunk, now: now)
        }
    }

    func tonConnectCompletePendingPost() async throws {
        try await self.withFfi { try self.requireTonConnectSession().completePendingPost() }
    }

    func clearTonConnectSession() async {
        await self.acquireFfi()
        self.tonConnectSession = nil
        self.releaseFfi()
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
        switch rotation.phase {
        case .candidateStored:
            try await self.storage.discardUnsubmittedKeyRotation(operationId: rotation.operationId)
        case .submissionStarted:
            do {
                let send = try await client.resolvePending()
                _ = try await self.reconcileKeyRotation(send: send)
            } catch {
                // A transport failure is ambiguous. Keep both the replacement
                // secret and rollback material until provider evidence is available.
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
        transferSubmission: WalletEngineTransferSubmission? = nil,
        _ operation: (WalletClient) async throws -> SendResult
    ) async throws -> WalletEngineSendExecution {
        let client = try self.requireClient()
        do {
            return WalletEngineSendExecution(
                result: try await self.performSend(client, transferSubmission: transferSubmission, operation: operation),
                didRecreateClient: false,
                receipt: await self.receiptForSubmission(transferSubmission)
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
                storage: self.storage,
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
                result: try await self.performSend(replacement, transferSubmission: transferSubmission, operation: operation),
                didRecreateClient: true,
                receipt: await self.receiptForSubmission(transferSubmission)
            )
        }
    }

    private func performSend(
        _ client: WalletClient,
        transferSubmission: WalletEngineTransferSubmission?,
        operation: (WalletClient) async throws -> SendResult
    ) async throws -> SendResult {
        let host = self.statuslessHost
        await host.setTransferSubmission(transferSubmission)
        do {
            let result = try await operation(client)
            await host.setTransferSubmission(nil)
            return result
        } catch {
            await host.setTransferSubmission(nil)
            throw error
        }
    }

    private func receiptForSubmission(_ submission: WalletEngineTransferSubmission?) async -> WalletEngineTransferReceipt? {
        guard let submission else { return nil }
        return await self.transferReceipt(operationId: submission.pendingTransfer.id)
    }

    private func ensureKeyRotationAllowsSigning() async throws {
        if try await self.storage.loadKeyRotation() != nil {
            throw WalletContext.WalletError.operationInProgress
        }
    }

    private func requireClient() throws -> WalletClient {
        guard let client = self.client else {
            throw WalletContext.WalletError.unavailable
        }
        return client
    }

    private func requireTonConnectSession() throws -> TonConnectSession {
        guard let session = self.tonConnectSession else {
            throw WalletContext.WalletError.unavailable
        }
        return session
    }

    private func withFfi<Value>(
        priority: FfiPriority = .userInitiated,
        cancellation: FfiCancellation = .none,
        _ operation: @escaping () async throws -> Value
    ) async throws -> Value {
        await self.acquireFfi(priority: priority)
        defer {
            self.activeFfiOperation = nil
            self.releaseFfi()
        }
        try Task.checkCancellation()
        let operationId = UUID()
        self.activeFfiOperation = (operationId, cancellation)
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

func walletEngineIsSendAlreadyInProgress(_ error: Error) -> Bool {
    guard let error = error as? WalletClientError else {
        return false
    }
    if case .SendAlreadyInProgress = error {
        return true
    }
    return false
}

func normalizedEngineMnemonic(_ words: [String]) -> [String] {
    words.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        .filter { !$0.isEmpty }
}

func walletEngineAddressesEqual(_ lhs: String, _ rhs: String) -> Bool {
    guard let left = try? convertTonAddress(value: lhs, format: .raw),
          let right = try? convertTonAddress(value: rhs, format: .raw) else {
        return lhs == rhs
    }
    return left == right
}
