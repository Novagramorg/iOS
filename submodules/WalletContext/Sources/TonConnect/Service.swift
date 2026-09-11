import Foundation
import WalletEngineFFI

public actor TonConnectService {
    private let identity: TonConnectWalletIdentity
    private let storage: any TonConnectSessionStorage
    private let transport: any TonConnectTransport
    private let wallet: any TonConnectWalletExecutor
    private let clock: any TonConnectClock
    private let device: TonConnectDevice
    private let create: @Sendable (String) throws -> any ProtocolSession
    private let restoreEngine: @Sendable (String) throws -> any ProtocolSession
    private let changed: @Sendable (TonConnectServiceState) async -> Void
    private var sessions: [String: Session] = [:]
    private var peers: [String: (id: String, request: String)] = [:]
    private var snapshots: [String: SessionUpdate] = [:]
    private var queue: [String] = []
    private var active: TonConnectActiveInteraction?
    private var decisions: [String: Task<TonConnectDecision, Error>] = [:]
    private var restoreTask: Task<Void, Error>?
    private var networkEnabled = false
    private var presentationEnabled = false
    private var environmentRevision: UInt64 = 0
    private var diagnostic: TonConnectDiagnostic?
    private var stopped = false
    private var stateRevision: UInt64 = 0

    public init(identity: TonConnectWalletIdentity, storage: any TonConnectSessionStorage,
                wallet: any TonConnectWalletExecutor, device: TonConnectDevice,
                transport: any TonConnectTransport = TonConnectHTTPTransport(),
                clock: any TonConnectClock = TonConnectSystemClock(),
                changed: @escaping @Sendable (TonConnectServiceState) async -> Void) {
        self.identity = identity
        self.storage = storage
        self.wallet = wallet
        self.device = device
        self.transport = transport
        self.clock = clock
        self.changed = changed
        self.create = { link in EngineSession(value: try tonConnectSessionFromLink(link: link, config: Self.config)) }
        self.restoreEngine = { value in EngineSession(value: try tonConnectSessionRestore(persisted: value, config: Self.config)) }
    }

    init(identity: TonConnectWalletIdentity, storage: any TonConnectSessionStorage,
         wallet: any TonConnectWalletExecutor, device: TonConnectDevice, transport: any TonConnectTransport,
         clock: any TonConnectClock,
         create: @escaping @Sendable (String) throws -> any ProtocolSession,
         restore: @escaping @Sendable (String) throws -> any ProtocolSession,
         changed: @escaping @Sendable (TonConnectServiceState) async -> Void) {
        self.identity = identity
        self.storage = storage
        self.wallet = wallet
        self.device = device
        self.transport = transport
        self.clock = clock
        self.create = create
        self.restoreEngine = restore
        self.changed = changed
    }

    public func restore() async throws {
        guard !self.stopped else { throw TonConnectFailure.unavailable }
        if let task = self.restoreTask { return try await task.value }
        let task = Task { try await self.load() }
        self.restoreTask = task
        do {
            try await task.value
        } catch {
            self.restoreTask = nil
            throw error
        }
    }

    public func open(_ value: String) async throws {
        let link = try TonConnectLink(value)
        try await self.restore()
        guard !self.stopped else { throw TonConnectFailure.unavailable }
        if let existing = self.peers[link.peerId], let session = self.sessions[existing.id] {
            guard link.request == nil || link.request == existing.request else { throw TonConnectFailure.conflictingLink }
            let task = Task { await session.setReturnTarget(link.returnTarget) }
            await task.value
            return
        }
        guard link.request != nil else { throw TonConnectFailure.unavailable }
        guard self.sessions.count < 64 else { throw TonConnectFailure.capacityExceeded }
        let engine = try self.create(link.value)
        let record = TonConnectStoredSession(id: UUID().uuidString.lowercased(), wallet: self.identity,
                                             link: link, rustSession: try engine.persisted())
        let session = self.install(engine: engine, record: record)
        let enabled = self.networkEnabled
        let task = Task { await session.start(networkEnabled: enabled) }
        await task.value
    }

    public func setEnvironment(presentationEnabled: Bool, networkEnabled: Bool, revision: UInt64? = nil) async {
        guard !self.stopped else { return }
        let revision = revision ?? (self.environmentRevision &+ 1)
        guard revision > self.environmentRevision else { return }
        self.presentationEnabled = presentationEnabled
        self.networkEnabled = networkEnabled
        self.environmentRevision = revision
        self.selectNext()
        await self.publish()
        await withTaskGroup(of: Void.self) { group in
            for session in self.sessions.values {
                group.addTask { await session.setNetworkEnabled(networkEnabled, revision: revision) }
            }
        }
    }

    public func decide(id: String, approve: Bool) async throws -> TonConnectDecision {
        if let task = self.decisions[id] { return try await task.value }
        guard !self.stopped, !approve || self.presentationEnabled, let active = self.active,
              active.interaction.id == id, case .ready = active.status,
              let session = self.sessions[active.interaction.sessionId] else { throw TonConnectFailure.unavailable }
        self.active?.status = .processing
        let task = Task { try await session.decide(interactionId: id, approve: approve) }
        self.decisions[id] = task
        await self.publish()
        do {
            let result = try await task.value
            if self.active?.interaction.id == id { self.active?.status = .completed(result) }
            else { self.decisions[id] = nil }
            await self.publish()
            return result
        } catch {
            self.decisions[id] = nil
            if self.active?.interaction.id == id {
                self.active?.status = self.availableInteractions()[id] == nil ? .invalidated : .ready
            } else if self.availableInteractions()[id] != nil, !self.queue.contains(id) {
                self.queue.insert(id, at: 0)
            }
            self.selectNext()
            await self.publish()
            throw error
        }
    }

    public func presentationClosed(id: String, rejectIfPending: Bool = false) async -> TonConnectReturnTarget? {
        guard self.active?.interaction.id == id else { return nil }
        var target: TonConnectReturnTarget?
        if let active = self.active, case let .completed(decision) = active.status { target = decision.returnTarget }
        if rejectIfPending, let active = self.active, case .ready = active.status {
            let decision = try? await self.decide(id: id, approve: false)
            target = decision?.returnTarget
        }
        guard self.active?.interaction.id == id else { return target }
        let wasProcessing: Bool
        if let active = self.active, case .processing = active.status { wasProcessing = true } else { wasProcessing = false }
        self.active = nil
        if !wasProcessing { self.decisions[id] = nil }
        self.queue.removeAll(where: { $0 == id })
        if self.decisions[id] == nil, self.availableInteractions()[id] != nil { self.queue.insert(id, at: 0) }
        self.selectNext()
        await self.publish()
        return target
    }

    public func disconnect(sessionId: String) async {
        guard !self.stopped, let session = self.sessions[sessionId] else { return }
        let task = Task { await session.disconnect() }
        await task.value
    }

    public func disconnectAll() async {
        let ids = Array(self.sessions.keys)
        for id in ids { await self.disconnect(sessionId: id) }
    }

    public func dismissDiagnostic(id: UUID) async {
        if self.diagnostic?.id == id { self.diagnostic = nil; await self.publish() }
    }

    public func shutdown() async {
        self.stopped = true
        self.presentationEnabled = false
        self.networkEnabled = false
        self.active?.status = .invalidated
        await self.publish()
        await withTaskGroup(of: Void.self) { group in
            for session in self.sessions.values { group.addTask { await session.shutdown() } }
        }
        self.sessions = [:]
        self.snapshots = [:]
        self.queue = []
        self.active = nil
        self.decisions = [:]
        await self.publish()
    }

    private func load() async throws {
        let values = try await self.storage.loadSessions(recordId: self.identity.recordId)
        guard !self.stopped else { throw TonConnectFailure.unavailable }
        for value in values {
            do {
                let record = try JSONDecoder().decode(TonConnectStoredSession.self, from: value)
                guard record.version == 1, record.wallet == self.identity,
                      self.sessions[record.id] == nil, self.peers[record.peerId] == nil else {
                    throw TonConnectFailure.unavailable
                }
                let session = self.install(engine: try self.restoreEngine(record.rustSession), record: record)
                let enabled = self.networkEnabled
                // A restored dApp's network request must not block other sessions.
                Task { await session.start(networkEnabled: enabled) }
            } catch {
                self.diagnostic = TonConnectDiagnostic(id: UUID(), failure: .storageUnavailable)
            }
        }
        await self.publish()
    }

    private func install(engine: any ProtocolSession, record: TonConnectStoredSession) -> Session {
        let session = Session(engine: engine, record: record, storage: self.storage, transport: self.transport,
                              wallet: self.wallet, clock: self.clock, device: self.device,
                              update: { [weak self] update in await self?.receive(update) })
        self.sessions[record.id] = session
        self.peers[record.peerId] = (record.id, record.connectRequest)
        return session
    }

    private func receive(_ update: SessionUpdate) async {
        guard !self.stopped else { return }
        if let error = update.info.error, error != self.snapshots[update.info.id]?.info.error,
           error != .bridgeUnavailable {
            self.diagnostic = TonConnectDiagnostic(id: UUID(), failure: error)
        }
        if update.removed {
            self.snapshots[update.info.id] = nil
            self.sessions[update.info.id] = nil
            self.peers = self.peers.filter { $0.value.id != update.info.id }
        } else {
            self.snapshots[update.info.id] = update
        }
        let available = self.availableInteractions()
        self.queue.removeAll(where: { available[$0] == nil })
        for interaction in update.interactions where self.active?.interaction.id != interaction.id
            && !self.queue.contains(interaction.id) && self.decisions[interaction.id] == nil {
            self.queue.append(interaction.id)
        }
        if let active = self.active, available[active.interaction.id] == nil, case .ready = active.status {
            self.active?.status = .invalidated
        }
        self.selectNext()
        await self.publish()
    }

    private func availableInteractions() -> [String: TonConnectInteraction] {
        var result: [String: TonConnectInteraction] = [:]
        for snapshot in self.snapshots.values {
            for interaction in snapshot.interactions { result[interaction.id] = interaction }
        }
        return result
    }

    private func selectNext() {
        guard self.active == nil, self.presentationEnabled else { return }
        let available = self.availableInteractions()
        while let id = self.queue.first {
            self.queue.removeFirst()
            if let interaction = available[id], self.decisions[id] == nil {
                self.active = TonConnectActiveInteraction(interaction: interaction, status: .ready)
                return
            }
        }
    }

    private func publish() async {
        self.stateRevision &+= 1
        await self.changed(TonConnectServiceState(revision: self.stateRevision,
                                                  sessions: self.snapshots.values.map(\.info).sorted { $0.id < $1.id },
                                                  active: self.active, presentationEnabled: self.presentationEnabled,
                                                  diagnostic: self.diagnostic))
    }

    private static var config: TonConnectSessionConfig {
        TonConnectSessionConfig(bridgeUrl: "https://connect.ton.org/bridge", maxEventBytes: 1_048_576, messageTtlSeconds: 300)
    }
}
