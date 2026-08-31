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

/// Serializes all UniFFI calls and owns the callback objects for one wallet identity.
actor WalletEngineRuntime {
    let storage: WalletEngineStorage
    private let platformHost: WalletEnginePlatformHost
    private let statuslessHost: WalletEngineStatuslessHost
    private let lifecycle: WalletLifecycle
    private var client: WalletClient?
    private var descriptor: WalletDescriptor?
    private var tonConnectSession: TonConnectSession?
    private var ffiBusy = false
    private var ffiWaiters: [CheckedContinuation<Void, Never>] = []

    init(engine: TelegramEngine, storage: WalletEngineStorage) {
        self.storage = storage
        self.platformHost = WalletEnginePlatformHost(storage: storage)
        self.statuslessHost = WalletEngineStatuslessHost(engine: engine)
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
                try? await self.storage.deleteProtectedSecret(imported.secretRef)
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
                try? await self.storage.deleteProtectedSecret(imported.secretRef)
                throw WalletContext.WalletError.storage(.identityMismatch)
            }
            let record = WalletEngineDescriptorRecord(descriptor: imported)
            do {
                try await self.storage.saveDescriptor(record)
            } catch {
                try? await self.storage.deleteProtectedSecret(imported.secretRef)
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
            try await self.requireClient().send(request: SendRequest(
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
            try await self.requireClient().sendNftTransfer(request: NftTransferRequest(
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
        try await self.withFfi { try await self.requireClient().send(request: request) }
    }

    func signMessage(_ request: SignMessageRequest) async throws -> SignMessageResult {
        try await self.withFfi { try await self.requireClient().signMessage(request: request) }
    }

    func shutdown() async {
        try? await self.withFfi {
            self.tonConnectSession = nil
            try await self.shutdownClient()
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

    private func shutdownClient() async throws {
        if let client = self.client {
            self.client = nil
            try await client.shutdown()
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
