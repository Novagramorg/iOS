import Foundation
import TelegramCore
import WalletEngineFFI

struct WalletEngineActivation: @unchecked Sendable {
    let snapshot: WalletSnapshot
    let canSign: Bool
    let descriptor: WalletDescriptor?
}

struct WalletEngineStagedWallet: Equatable, Sendable {
    let recordId: String
    let address: String
    let publicKey: Data
}

enum WalletEngineKeyRotationResolution: Equatable, Sendable {
    case none
    case pending(operationId: String, retryAfterMilliseconds: UInt64?)
    case confirmed(operationId: String)
    case rolledBack(operationId: String, phase: SendPhase)
}

/// Serializes all UniFFI calls and owns the callback objects for one wallet identity.
actor WalletEngineRuntime {
    let storage: WalletEngineStorage
    private let errorLogger: WalletContextErrorLogger
    private let platformHost: WalletEnginePlatformHost
    private let statuslessHost: WalletEngineStatuslessHost
    private let lifecycle: WalletLifecycle
    private var client: WalletClient?
    private var descriptor: WalletDescriptor?
    private var tonConnectSession: TonConnectSession?
    private var ffiBusy = false
    private var ffiWaiters: [CheckedContinuation<Void, Never>] = []

    init(engine: TelegramEngine, storage: WalletEngineStorage, errorLogger: WalletContextErrorLogger) {
        self.storage = storage
        self.errorLogger = errorLogger
        self.platformHost = WalletEnginePlatformHost(storage: storage, errorLogger: errorLogger)
        self.statuslessHost = WalletEngineStatuslessHost(engine: engine, errorLogger: errorLogger)
        self.lifecycle = WalletLifecycle(platformHost: self.platformHost)
    }

    func activate(
        serverAddress: String,
        serverPublicKey: Data,
        exportedWords: [String]?
    ) async throws -> WalletEngineActivation {
        try await self.withFfi {
            try await self.activateUnlocked(
                serverAddress: serverAddress,
                serverPublicKey: serverPublicKey,
                exportedWords: exportedWords
            )
        }
    }

    func stageReplacement(words: [String]) async throws -> WalletEngineStagedWallet {
        try await self.withFfi {
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
                    self.errorLogger.error("wallet_replacement_secret_cleanup_failed", error)
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

    func commitReplacement(
        recordId: String,
        serverAddress: String,
        serverPublicKey: Data
    ) async throws -> WalletEngineActivation {
        try await self.withFfi {
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
                serverPublicKey: serverPublicKey,
                exportedWords: nil
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
        exportedWords: [String]?
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
            } else if exportedWords == nil {
                selectedRecord = WalletEngineDescriptorRecord(
                    recordId: stored.recordId,
                    address: stored.address,
                    publicKey: stored.publicKey,
                    secretRef: nil
                )
            }
        }

        if selectedRecord == nil, let exportedWords {
            let words = normalizedEngineMnemonic(exportedWords)
            guard detectMnemonicSchemes(words: words).contains(.rotation) else {
                throw WalletContext.WalletError.invalidMnemonic
            }
            let imported = try await self.lifecycle.importWallet(request: ImportWalletRequest(
                recordId: UUID().uuidString.lowercased(),
                network: .mainnet,
                recoveryWords: words
            ))
            guard walletEngineAddressesEqual(imported.address, serverAddress),
                  imported.publicKey == serverPublicKey else {
                do {
                    try await self.storage.deleteProtectedSecret(imported.secretRef)
                } catch {
                    self.errorLogger.error("wallet_imported_secret_cleanup_failed", error)
                }
                throw WalletContext.WalletError.storage(.identityMismatch)
            }
            let record = WalletEngineDescriptorRecord(descriptor: imported)
            do {
                try await self.storage.saveDescriptor(record)
            } catch {
                do {
                    try await self.storage.deleteProtectedSecret(imported.secretRef)
                } catch {
                    self.errorLogger.error("wallet_imported_secret_cleanup_failed", error)
                }
                throw error
            }
            selectedRecord = record
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
        let client = try WalletClient.newStatusless(
            config: config,
            statuslessHost: self.statuslessHost,
            platformHost: self.platformHost
        )
        self.client = client
        self.descriptor = record.descriptor
        try await self.recoverKeyRotationAfterActivation(record: record, client: client)
        return WalletEngineActivation(
            snapshot: try client.snapshot(),
            canSign: record.secretRef != nil,
            descriptor: record.descriptor
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

    private func deleteLocalWallet(_ record: WalletEngineDescriptorRecord) async throws {
        if let secretRef = record.secretRef {
            try await self.storage.deleteProtectedSecret(ProtectedSecretRef(value: secretRef))
        }
    }

    func refresh() async throws -> WalletUpdate {
        try await self.withFfi { try await self.requireClient().refresh() }
    }

    func refreshNfts() async throws -> WalletUpdate {
        try await self.withFfi { try await self.requireClient().refreshNfts() }
    }

    func loadMoreNfts() async throws -> WalletUpdate {
        try await self.withFfi { try await self.requireClient().loadMoreNfts() }
    }

    func snapshot() async throws -> WalletSnapshot {
        try await self.withFfi { try self.requireClient().snapshot() }
    }

    func waitForChange(afterRevision: UInt64) async throws -> WalletSnapshot {
        try await self.requireClient().waitForChange(afterRevision: afterRevision)
    }

    func resolveDns(_ name: String) async throws -> String? {
        try await self.withFfi { try await self.requireClient().resolveDns(name: name) }
    }

    func previewSend(intent: SendIntent) async throws -> SendPreview {
        try await self.withFfi {
            try await self.requireClient().previewSend(request: SendPreviewRequest(intent: intent))
        }
    }

    func send(operationId: String, intent: SendIntent) async throws -> SendResult {
        try await self.withFfi {
            try await self.ensureKeyRotationAllowsSigning()
            return try await self.requireClient().send(request: SendRequest(
                operationId: operationId,
                force: false,
                intent: intent
            ))
        }
    }

    func previewNft(operationId: String, intent: NftTransferIntent) async throws -> SendPreview {
        try await self.withFfi {
            try await self.requireClient().previewNftTransfer(request: NftTransferPreviewRequest(
                operationId: operationId,
                intent: intent
            ))
        }
    }

    func sendNft(operationId: String, intent: NftTransferIntent) async throws -> SendResult {
        try await self.withFfi {
            try await self.ensureKeyRotationAllowsSigning()
            return try await self.requireClient().sendNftTransfer(request: NftTransferRequest(
                operationId: operationId,
                force: false,
                intent: intent
            ))
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

    func keyRotationRecord() async throws -> WalletEngineKeyRotationRecord? {
        try await self.storage.loadKeyRotation()
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
            let record = try await self.storage.installKeyRotationReplacement(
                operationId: operationId,
                descriptor: descriptor,
                newPublicKey: newPublicKey,
                validUntil: validUntil,
                replacementSecret: replacementSecret
            )
            guard record.phase != .confirmed else {
                throw WalletContext.WalletError.unavailable
            }
            _ = try await self.storage.markKeyRotationSubmissionStarted(operationId: operationId)
            do {
                let result = try await self.requireClient().sendBoc(request: SendBocRequest(
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
                    snapshot = try self.requireClient().snapshot()
                } catch {
                    self.errorLogger.error("wallet_key_rotation_snapshot_failed", error)
                    snapshot = nil
                }
                if let snapshot {
                    if snapshot.send.operationId == operationId,
                       (snapshot.send.phase == .submitted
                        || snapshot.send.phase == .submissionUnknown
                        || snapshot.send.phase == .confirmed) {
                        do {
                            _ = try await self.reconcileKeyRotation(send: snapshot.send)
                        } catch {
                            self.errorLogger.error("wallet_key_rotation_reconciliation_failed", error)
                        }
                    } else {
                        do {
                            try await self.storage.rollbackKeyRotation(operationId: operationId)
                        } catch {
                            self.errorLogger.error("wallet_key_rotation_rollback_failed", error)
                        }
                    }
                } else {
                    do {
                        try await self.storage.rollbackKeyRotation(operationId: operationId)
                    } catch {
                        self.errorLogger.error("wallet_key_rotation_rollback_failed", error)
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
            if record.phase == .confirmed {
                return .confirmed(operationId: record.operationId)
            }
            if record.phase == .rollbackStored || record.phase == .replacementStored || record.phase == .rolledBack {
                try await self.storage.rollbackKeyRotation(operationId: record.operationId)
                return .rolledBack(operationId: record.operationId, phase: .cancelled)
            }
            do {
                let send = try await self.requireClient().resolvePending()
                return try await self.reconcileKeyRotation(send: send)
            } catch {
                let snapshot: WalletSnapshot?
                do {
                    snapshot = try self.requireClient().snapshot()
                } catch {
                    self.errorLogger.error("wallet_key_rotation_snapshot_failed", error)
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
        if record.phase == .confirmed {
            return .confirmed(operationId: record.operationId)
        }
        guard operationId == record.operationId else {
            if phase == .idle {
                try await self.storage.rollbackKeyRotation(operationId: record.operationId)
                return .rolledBack(operationId: record.operationId, phase: .cancelled)
            }
            return .pending(operationId: record.operationId, retryAfterMilliseconds: nil)
        }
        switch phase {
        case .confirmed:
            _ = try await self.storage.confirmKeyRotation(operationId: record.operationId)
            return .confirmed(operationId: record.operationId)
        case .replaced, .sequenceNumberConsumed, .expired, .superseded, .failed, .cancelled:
            try await self.storage.rollbackKeyRotation(operationId: record.operationId)
            return .rolledBack(operationId: record.operationId, phase: phase)
        case .idle, .validating, .authorizing, .preparing, .persisting, .readyToSubmit,
             .submitting, .submissionUnknown, .submitted, .handedOff:
            return .pending(
                operationId: record.operationId,
                retryAfterMilliseconds: retryAfterMilliseconds
            )
        }
    }

    func completeKeyRotation(operationId: String) async throws {
        try await self.storage.completeKeyRotation(operationId: operationId)
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
        try await self.withFfi { try await self.requireClient().previewTonConnect(request: request) }
    }

    func previewSignMessage(_ request: SignMessageRequest) async throws -> SignMessagePreview {
        try await self.withFfi {
            try await self.requireClient().previewSignMessage(request: SendPreviewRequest(intent: request.intent))
        }
    }

    func sendTonConnect(_ request: SendRequest) async throws -> SendResult {
        try await self.withFfi {
            try await self.ensureKeyRotationAllowsSigning()
            return try await self.requireClient().send(request: request)
        }
    }

    func signMessage(_ request: SignMessageRequest) async throws -> SignMessageResult {
        try await self.withFfi {
            try await self.ensureKeyRotationAllowsSigning()
            return try await self.requireClient().signMessage(request: request)
        }
    }

    func shutdown() async {
        do {
            try await self.withFfi {
                self.tonConnectSession = nil
                try await self.shutdownClient()
            }
        } catch {
            self.errorLogger.error("wallet_engine_shutdown_failed", error)
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
        guard rotation.schemaVersion == 1,
              rotation.recordId == descriptor.recordId,
              walletEngineAddressesEqual(rotation.walletAddress, descriptor.address),
              rotation.walletPublicKey == descriptor.publicKey,
              rotation.activeSecretRef == descriptor.secretRef else {
            try await self.storage.discardKeyRotation(operationId: rotation.operationId)
            return
        }
        switch rotation.phase {
        case .rollbackStored, .replacementStored, .rolledBack:
            try await self.storage.rollbackKeyRotation(operationId: rotation.operationId)
        case .submissionStarted:
            do {
                let send = try await client.resolvePending()
                _ = try await self.reconcileKeyRotation(send: send)
            } catch {
                // A transport failure is ambiguous. Keep both the replacement
                // secret and rollback material until provider evidence is available.
                self.errorLogger.error("wallet_key_rotation_recovery_failed", error)
            }
        case .confirmed:
            _ = try await self.storage.confirmKeyRotation(operationId: rotation.operationId)
        }
    }

    private func shutdownClient() async throws {
        if let client = self.client {
            self.client = nil
            try await client.shutdown()
        }
    }

    private func ensureKeyRotationAllowsSigning() async throws {
        if let rotation = try await self.storage.loadKeyRotation(), rotation.phase != .confirmed {
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

    private func withFfi<Value>(_ operation: () async throws -> Value) async throws -> Value {
        await self.acquireFfi()
        defer { self.releaseFfi() }
        try Task.checkCancellation()
        return try await operation()
    }

    private func acquireFfi() async {
        if !self.ffiBusy {
            self.ffiBusy = true
            return
        }
        await withCheckedContinuation { continuation in
            self.ffiWaiters.append(continuation)
        }
    }

    private func releaseFfi() {
        if self.ffiWaiters.isEmpty {
            self.ffiBusy = false
        } else {
            self.ffiWaiters.removeFirst().resume()
        }
    }
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
