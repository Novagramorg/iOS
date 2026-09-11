import Foundation
import WalletEngineFFI

struct SessionUpdate: Sendable {
    let info: TonConnectSessionInfo
    let interactions: [TonConnectInteraction]
    let removed: Bool
}

// The gate prevents actor reentrancy from interleaving protocol transitions.
actor Session {
    private let engine: any ProtocolSession
    private let storage: any TonConnectSessionStorage
    private let transport: any TonConnectTransport
    private let wallet: any TonConnectWalletExecutor
    private let clock: any TonConnectClock
    private let device: TonConnectDevice
    private let update: @Sendable (SessionUpdate) async -> Void
    private var record: TonConnectStoredSession
    private var previews: [String: TonConnectPreview] = [:]
    private var interactions: [TonConnectInteraction] = []
    private var error: TonConnectFailure?
    private var dirty = true
    private var closing = false
    private var removed = false
    private var stopped = false
    private var stopping = false
    private var networkEnabled = false
    private var environmentRevision: UInt64 = 0
    private var busy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var streamTask: Task<Void, Never>?
    private var streamGeneration: UInt64 = 0
    private var retryTask: Task<Void, Never>?
    private var retryGeneration: UInt64 = 0
    private var retryAttempt = 0
    private var cancelWork: (@Sendable () -> Void)?

    init(engine: any ProtocolSession, record: TonConnectStoredSession,
         storage: any TonConnectSessionStorage, transport: any TonConnectTransport,
         wallet: any TonConnectWalletExecutor, clock: any TonConnectClock, device: TonConnectDevice,
         update: @escaping @Sendable (SessionUpdate) async -> Void) {
        self.engine = engine
        self.record = record
        self.storage = storage
        self.transport = transport
        self.wallet = wallet
        self.clock = clock
        self.device = device
        self.update = update
    }

    func start(networkEnabled: Bool) async {
        await self.acquire()
        defer { self.release() }
        guard !self.stopped, !self.stopping else { return }
        if self.environmentRevision == 0 { self.networkEnabled = networkEnabled }
        await self.driveSafely()
    }

    func setNetworkEnabled(_ enabled: Bool, revision: UInt64) async {
        // Cancel I/O before acquiring the gate, which may be waiting on that I/O.
        guard !self.stopped, !self.stopping, revision > self.environmentRevision else { return }
        self.environmentRevision = revision
        let changed = self.networkEnabled != enabled
        self.networkEnabled = enabled
        if changed {
            self.retryTask?.cancel()
            self.retryTask = nil
            self.retryGeneration &+= 1
            if !enabled {
                self.stopStream()
                self.cancelWork?()
            }
            self.retryAttempt = 0
        }
        await self.acquire()
        defer { self.release() }
        guard revision == self.environmentRevision, !self.stopped, !self.stopping else { return }
        await self.driveSafely()
    }

    func setReturnTarget(_ target: TonConnectReturnTarget) async {
        await self.acquire()
        defer { self.release() }
        guard !self.stopped, !self.stopping, !self.removed else { return }
        self.record.returnTarget = target
        self.dirty = true
        await self.driveSafely()
    }

    func decide(interactionId: String, approve: Bool) async throws -> TonConnectDecision {
        await self.acquire()
        defer { self.release() }
        // Release the gate so the outbox worker can finish.
        while !self.stopped, !self.stopping, !self.removed, !self.closing {
            let post = try self.engine.pendingPost()
            if !self.dirty, post == nil { break }
            self.scheduleRetry(immediate: true)
            self.release()
            do { try await self.clock.sleep(seconds: 1) }
            catch { await self.acquire(); throw error }
            await self.acquire()
        }
        guard !self.stopped, !self.stopping, !self.removed, !self.closing, !self.dirty, self.record.executingRequestId == nil,
              let interaction = self.interactions.first(where: { $0.id == interactionId }),
              try self.engine.pendingPost() == nil else { throw TonConnectFailure.unavailable }
        self.stopStream()
        var failure: TonConnectFailure?
        switch interaction.content {
        case .connect:
            guard let prompt = try self.engine.prompt(), let manifest = self.record.manifest else {
                throw TonConnectFailure.unavailable
            }
            if approve {
                let account = try await self.wallet.account(for: self.record.wallet)
                guard prompt.requestedNetwork == nil || prompt.requestedNetwork == account.network else {
                    throw TonConnectFailure.wrongNetwork
                }
                var proof: TonConnectProofReply?
                if let payload = prompt.proofPayload {
                    let timestamp = self.clock.now
                    let signature = try await self.wallet.signProof(wallet: self.record.wallet, domain: manifest.domain,
                                                                  timestamp: timestamp, payload: payload)
                    proof = TonConnectProofReply(timestamp: timestamp, domain: manifest.domain, payload: payload, signature: signature.signature)
                }
                try self.engine.approve(account: account, proof: proof, device: self.device)
            } else {
                try self.engine.reject()
                self.closing = true
            }
        case let .operation(original, _):
            // Re-decode now: expiration may have passed while another dApp was on screen.
            guard let request = try self.engine.requests(now: self.clock.now).first(where: { $0.requestId == original.requestId }) else {
                throw TonConnectFailure.unavailable
            }
            if !approve {
                try self.engine.respond(id: request.requestId, response: .error(.userDeclined, "User declined the TON Connect request"))
            } else if case let .unsupported(_, _, code, message) = request {
                try self.engine.respond(id: request.requestId, response: .error(code, message))
                failure = .unavailable
            } else {
                // The FFI cannot recover signed results after a crash; this marker prevents re-signing.
                self.record.executingRequestId = request.requestId
                self.dirty = true
                do {
                    try await self.persist()
                } catch {
                    self.record.executingRequestId = nil
                    self.dirty = true
                    await self.driveSafely()
                    throw TonConnectFailure.storageUnavailable
                }
                do {
                    let result = try await self.wallet.execute(wallet: self.record.wallet, request: request)
                    try self.engine.respond(id: request.requestId, response: .signed(result))
                } catch TonConnectFailure.walletBusy {
                    // This error explicitly means the engine rejected the call before signing.
                    self.record.executingRequestId = nil
                    self.dirty = true
                    await self.persistDecision()
                    await self.driveSafely()
                    throw TonConnectFailure.walletBusy
                } catch {
                    failure = .outcomeUnknown
                    do {
                        try self.engine.respond(id: request.requestId, response: .error(.unknown, TonConnectFailure.outcomeUnknown.message))
                    } catch {
                        self.dirty = true
                        await self.driveSafely()
                        throw TonConnectFailure.outcomeUnknown
                    }
                }
                self.record.executingRequestId = nil
            }
            self.previews[original.requestId] = nil
            self.record.requestOrder.removeAll(where: { $0 == original.requestId })
        }
        self.interactions.removeAll(where: { $0.id == interactionId })
        self.dirty = true
        await self.persistDecision()
        self.scheduleRetry(immediate: true)
        await self.publish()
        return TonConnectDecision(approved: approve && failure == nil, deliveryPending: true,
                                  failure: failure, returnTarget: self.record.returnTarget)
    }

    func disconnect() async {
        await self.acquire()
        defer { self.release() }
        guard !self.stopped, !self.stopping, !self.removed else { return }
        self.stopStream()
        self.record.disconnectRequested = true
        self.interactions = []
        self.dirty = true
        await self.driveSafely()
    }

    func shutdown() async {
        // Finish persisting any accepted signature before switching the wallet runtime.
        self.stopping = true
        self.networkEnabled = false
        self.stopStream()
        self.cancelWork?()
        self.retryTask?.cancel()
        await self.acquire()
        defer { self.release() }
        self.stopped = true
        self.stopStream()
        self.retryTask?.cancel()
        self.retryTask = nil
        self.retryGeneration &+= 1
        self.interactions = []
        await self.publish()
    }

    private func driveSafely() async {
        do {
            try await self.drive()
        } catch {
            self.stopStream()
            self.error = self.dirty ? .storageUnavailable : (error as? TonConnectFailure ?? .bridgeUnavailable)
            self.scheduleRetry()
        }
        await self.publish()
    }

    private func drive() async throws {
        guard !self.stopped, !self.stopping, !self.removed else { return }
        if self.dirty { try await self.persist() }
        while !self.removed {
            if let post = try self.engine.pendingPost() {
                self.stopStream()
                guard self.networkEnabled else { return }
                try await self.performCancellableWork { [transport = self.transport] in try await transport.post(post) }
                try self.engine.completePost()
                self.dirty = true
                try await self.persist()
                self.error = nil
                self.retryAttempt = 0
            }
            if self.closing {
                try await self.remove()
                return
            }
            let requests = try self.engine.requests(now: self.clock.now)
            if let executing = self.record.executingRequestId {
                if requests.contains(where: { $0.requestId == executing }) {
                    try self.engine.respond(id: executing, response: .error(.unknown, TonConnectFailure.outcomeUnknown.message))
                }
                self.record.executingRequestId = nil
                self.error = .outcomeUnknown
                self.dirty = true
                try await self.persist()
                continue
            }
            let phase = try self.engine.phase()
            if phase == .disconnected {
                self.interactions = []
                self.closing = true
                self.stopStream()
                if let disconnect = requests.first(where: { if case .disconnect = $0 { return true }; return false }) {
                    try self.engine.respond(id: disconnect.requestId, response: .disconnect)
                    self.dirty = true
                    try await self.persist()
                    continue
                }
                try await self.remove()
                return
            }
            if self.record.disconnectRequested {
                self.interactions = []
                self.closing = true
                self.stopStream()
                if phase == .pendingConnect { try self.engine.reject() } else { try self.engine.disconnect() }
                self.dirty = true
                try await self.persist()
                continue
            }
            if self.record.manifest == nil {
                guard self.networkEnabled else { return }
                guard let prompt = try self.engine.prompt() else { throw TonConnectFailure.unavailable }
                let json: String
                do {
                    json = try await self.performCancellableWork { [transport = self.transport] in
                        try await transport.loadManifest(from: prompt.manifestUrl)
                    }
                } catch {
                    if let failure = error as? TonConnectFailure, failure == .responseTooLarge || failure == .invalidLink {
                        self.error = .invalidManifest
                        self.closing = true
                        try await self.remove()
                        return
                    }
                    throw TonConnectFailure.bridgeUnavailable
                }
                do {
                    self.record.manifest = TonConnectManifestInfo(try parseTonConnectManifest(json: json))
                    guard prompt.requestedNetwork == nil || prompt.requestedNetwork == self.record.wallet.network else {
                        throw TonConnectFailure.wrongNetwork
                    }
                } catch {
                    // Native rejectConnect only supports UserDeclined; report manifest/network errors locally.
                    self.error = (error as? TonConnectFailure) == .wrongNetwork ? .wrongNetwork : .invalidManifest
                    self.closing = true
                    try await self.remove()
                    return
                }
                self.dirty = true
                try await self.persist()
            }
            guard let manifest = self.record.manifest else { return }
            if phase == .pendingConnect {
                if let prompt = try self.engine.prompt() {
                    self.interactions = [TonConnectInteraction(id: self.interactionId("connect"), sessionId: self.record.id,
                                                               manifest: manifest, content: .connect(prompt))]
                }
                return
            }
            let ids = Set(requests.map(\.requestId))
            self.record.requestOrder.removeAll(where: { !ids.contains($0) })
            for request in requests where !self.record.requestOrder.contains(request.requestId) {
                self.record.requestOrder.append(request.requestId)
            }
            self.previews = self.previews.filter { ids.contains($0.key) }
            if let unsupported = requests.first(where: { if case .unsupported = $0 { return true }; return false }),
               case let .unsupported(id, _, code, message) = unsupported {
                try self.engine.respond(id: id, response: .error(code, message))
                self.interactions.removeAll(where: { $0.id == self.interactionId(id) })
                self.dirty = true
                try await self.persist()
                continue
            }
            var prepared: [TonConnectInteraction] = []
            var previewFailed = false
            for id in self.record.requestOrder {
                guard let request = requests.first(where: { $0.requestId == id }) else { continue }
                if self.previews[id] == nil {
                    guard self.networkEnabled else { continue }
                    do {
                        self.previews[id] = try await self.performCancellableWork { [wallet = self.wallet, identity = self.record.wallet] in
                            try await wallet.preview(wallet: identity, request: request)
                        }
                    } catch {
                        if error is CancellationError || !self.networkEnabled || self.stopping { throw CancellationError() }
                        try self.engine.respond(id: id, response: .error(.unknown, TonConnectFailure.previewFailed.message))
                        self.dirty = true
                        try await self.persist()
                        previewFailed = true
                        break
                    }
                }
                if let preview = self.previews[id] {
                    prepared.append(TonConnectInteraction(id: self.interactionId(id), sessionId: self.record.id,
                                                           manifest: manifest, content: .operation(request, preview)))
                }
            }
            if previewFailed { continue }
            self.interactions = prepared
            self.dirty = true
            try await self.persist()
            if self.networkEnabled, requests.count < 32 { try self.startStream() } else { self.stopStream() }
            return
        }
    }

    private func persist() async throws {
        self.record.rustSession = try self.engine.persisted()
        try await self.storage.saveSession(JSONEncoder().encode(self.record), recordId: self.record.wallet.recordId, sessionId: self.record.id)
        self.dirty = false
    }

    private func performCancellableWork<Value: Sendable>(
        _ work: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        guard self.networkEnabled, !self.stopping, !self.stopped else { throw CancellationError() }
        let task = Task { try await work() }
        self.cancelWork = { task.cancel() }
        defer { self.cancelWork = nil }
        do {
            let value = try await task.value
            if task.isCancelled { throw CancellationError() }
            return value
        } catch {
            if task.isCancelled { throw CancellationError() }
            throw error
        }
    }

    private func persistDecision() async {
        var attempt = 0
        while true {
            do {
                try await self.persist()
                self.error = nil
                return
            } catch {
                self.error = .storageUnavailable
                await self.publish()
                // UI cancellation must not discard a signed response still waiting for storage.
                try? await self.clock.sleep(seconds: min(30, pow(2, Double(min(attempt, 5)))))
                attempt += 1
            }
        }
    }

    private func remove() async throws {
        self.stopStream()
        self.interactions = []
        try await self.storage.removeSession(recordId: self.record.wallet.recordId, sessionId: self.record.id)
        self.removed = true
        self.retryTask?.cancel()
        self.retryTask = nil
        self.retryGeneration &+= 1
    }

    private func startStream() throws {
        guard self.streamTask == nil, self.networkEnabled, !self.stopped, !self.stopping else { return }
        let url = try self.engine.eventsURL()
        self.streamGeneration &+= 1
        let generation = self.streamGeneration
        self.streamTask = Task { [weak self, transport = self.transport] in
            do {
                try await transport.stream(from: url) { [weak self] data in
                    guard let self else { throw CancellationError() }
                    // Ingest can cancel its own SSE source; finish persistence in an independent task.
                    let command = Task { await self.receive(data, generation: generation) }
                    await command.value
                }
                await self?.streamEnded(generation: generation, error: .bridgeUnavailable)
            } catch {
                await self?.streamEnded(generation: generation, error: error as? TonConnectFailure ?? .bridgeUnavailable)
            }
        }
    }

    private func stopStream() {
        self.streamGeneration &+= 1
        self.streamTask?.cancel()
        self.streamTask = nil
    }

    private func receive(_ data: Data, generation: UInt64) async {
        await self.acquire()
        defer { self.release() }
        guard !self.stopped, !self.stopping, !self.removed, generation == self.streamGeneration, !self.dirty else { return }
        do {
            let requests = try self.engine.ingest(data, now: self.clock.now)
            self.dirty = true
            for request in requests where !self.record.requestOrder.contains(request.requestId) {
                self.record.requestOrder.append(request.requestId)
            }
            try await self.persist()
            self.retryAttempt = 0
            self.error = nil
            await self.driveSafely()
        } catch {
            self.stopStream()
            self.error = self.dirty ? .storageUnavailable : .invalidResponse
            self.scheduleRetry()
            await self.publish()
        }
    }

    private func streamEnded(generation: UInt64, error: TonConnectFailure) async {
        await self.acquire()
        defer { self.release() }
        guard generation == self.streamGeneration, !self.stopped else { return }
        self.streamTask = nil
        self.error = error
        self.scheduleRetry()
        await self.publish()
    }

    private func scheduleRetry(immediate: Bool = false) {
        guard self.retryTask == nil, self.networkEnabled || self.dirty, !self.stopped, !self.stopping, !self.removed else { return }
        let base = min(25, pow(2, Double(min(self.retryAttempt, 5))))
        let delay = immediate ? 0 : base + Double.random(in: 0...(base * 0.2))
        self.retryAttempt += 1
        self.retryGeneration &+= 1
        let generation = self.retryGeneration
        self.retryTask = Task { [weak self, clock = self.clock] in
            do {
                try await clock.sleep(seconds: delay)
                try Task.checkCancellation()
                await self?.retry(generation: generation)
            } catch {}
        }
    }

    private func retry(generation: UInt64) async {
        await self.acquire()
        defer { self.release() }
        guard generation == self.retryGeneration else { return }
        self.retryTask = nil
        guard !Task.isCancelled, !self.stopped else { return }
        await self.driveSafely()
    }

    private func publish() async {
        let phase = try? self.engine.phase()
        let status: TonConnectSessionInfo.Status = self.closing || self.record.disconnectRequested || phase == .disconnected
            ? .disconnecting : (phase == .connected ? .connected : .connecting)
        await self.update(SessionUpdate(info: TonConnectSessionInfo(id: self.record.id, manifest: self.record.manifest,
            status: status, deliveryPending: (try? self.engine.pendingPost()) != nil, error: self.error),
            interactions: self.stopped || self.stopping || self.closing || self.record.disconnectRequested ? [] : self.interactions, removed: self.removed))
    }

    private func interactionId(_ requestId: String) -> String {
        self.record.id + ":" + Data(requestId.utf8).base64EncodedString()
    }

    private func acquire() async {
        if !self.busy { self.busy = true; return }
        await withCheckedContinuation { self.waiters.append($0) }
    }

    private func release() {
        if self.waiters.isEmpty { self.busy = false } else { self.waiters.removeFirst().resume() }
    }
}
