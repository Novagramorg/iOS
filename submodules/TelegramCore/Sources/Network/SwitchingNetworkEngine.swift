import Foundation
import SwiftSignalKit
import MtProtoKit

private final class SwitchingRequestEntry {
    let id: Int
    let request: NetworkEngineRequest
    var generation: Int
    var disposable: Disposable?

    init(id: Int, request: NetworkEngineRequest, generation: Int) {
        self.id = id
        self.request = request
        self.generation = generation
    }
}

private final class SwitchingSessionDelegate: NetworkEngineSessionDelegate {
    weak var session: SwitchingNetworkSession?
    let generation: Int

    init(generation: Int) {
        self.generation = generation
    }

    func networkSessionAuthorizationRequired() {
        guard let session = self.session, session.isCurrent(generation: self.generation) else {
            return
        }
        session.delegate?.networkSessionAuthorizationRequired()
    }

    func networkSessionSoftAuthReset() {
        guard let session = self.session, session.isCurrent(generation: self.generation) else {
            return
        }
        session.delegate?.networkSessionSoftAuthReset()
    }

    func networkSessionConnectionStateChanged(_ state: NetworkEngineConnectionState) {
        guard let session = self.session, session.isCurrent(generation: self.generation) else {
            return
        }
        session.delegate?.networkSessionConnectionStateChanged(state)
    }
}

private final class SwitchingRequestService: NetworkEngineRequestService {
    weak var session: SwitchingNetworkSession?

    func add(_ request: NetworkEngineRequest) -> Disposable {
        guard let session = self.session else {
            return EmptyDisposable
        }
        return session.add(request)
    }
}

final class SwitchingNetworkSession: NetworkEngineSession {
    let datacenterId: Int
    var requestService: NetworkEngineRequestService {
        return self.switchingRequestService
    }

    fileprivate weak var delegate: NetworkEngineSessionDelegate?

    private let role: NetworkEngineSessionRole
    private let usageCalculationInfo: MTNetworkUsageCalculationInfo?
    private let hasDelegate: Bool
    private let switchingRequestService = SwitchingRequestService()
    private let lock = NSLock()
    private var current: NetworkEngineSession
    private var currentDelegate: SwitchingSessionDelegate?
    private var generation = 0
    private var draining: [Int: NetworkEngineSession] = [:]
    private var entries: [Int: SwitchingRequestEntry] = [:]
    private var nextEntryId = 0
    private var isPaused = true
    private var isOnline = false
    private var isStopped = false
    private var sinks: [NetworkEngineUpdateSink] = []

    init(engine: NetworkEngine, datacenterId: Int, role: NetworkEngineSessionRole, usageCalculationInfo: MTNetworkUsageCalculationInfo?, delegate: NetworkEngineSessionDelegate?) {
        self.datacenterId = datacenterId
        self.role = role
        self.usageCalculationInfo = usageCalculationInfo
        self.delegate = delegate
        self.hasDelegate = delegate != nil
        let sessionDelegate = delegate != nil ? SwitchingSessionDelegate(generation: 0) : nil
        self.currentDelegate = sessionDelegate
        self.current = engine.makeSession(datacenterId: datacenterId, role: role, usageCalculationInfo: usageCalculationInfo, delegate: sessionDelegate)
        sessionDelegate?.session = self
        self.switchingRequestService.session = self
    }

    fileprivate func isCurrent(generation: Int) -> Bool {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.generation == generation
    }

    fileprivate func add(_ request: NetworkEngineRequest) -> Disposable {
        self.lock.lock()
        if self.isStopped {
            self.lock.unlock()
            return EmptyDisposable
        }
        let id = self.nextEntryId
        self.nextEntryId += 1
        var generation = self.generation
        var target = self.current
        if !self.draining.isEmpty, let dependsOn = request.dependsOn {
            var dependency: SwitchingRequestEntry?
            for entry in self.entries.values where self.draining[entry.generation] != nil && dependsOn(entry.request.metadata) {
                if let current = dependency, current.id > entry.id {
                    continue
                }
                dependency = entry
            }
            if let dependency, let session = self.draining[dependency.generation] {
                generation = dependency.generation
                target = session
            }
        }
        self.entries[id] = SwitchingRequestEntry(id: id, request: request, generation: generation)
        self.lock.unlock()

        self.submit(entryId: id, request: request, generation: generation, to: target)

        return ActionDisposable { [weak self] in
            self?.cancel(entryId: id)
        }
    }

    private func submit(entryId: Int, request: NetworkEngineRequest, generation: Int, to session: NetworkEngineSession) {
        let disposable = session.requestService.add(self.wrap(request, entryId: entryId, generation: generation))
        self.lock.lock()
        if let entry = self.entries[entryId], entry.generation == generation {
            entry.disposable = disposable
            self.lock.unlock()
        } else {
            self.lock.unlock()
            disposable.dispose()
        }
    }

    private func isLive(entryId: Int, generation: Int) -> Bool {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.entries[entryId]?.generation == generation
    }

    private func wrap(_ request: NetworkEngineRequest, entryId: Int, generation: Int) -> NetworkEngineRequest {
        var acknowledged: (() -> Void)?
        if let requestAcknowledged = request.acknowledged {
            acknowledged = { [weak self] in
                if let self, self.isLive(entryId: entryId, generation: generation) {
                    requestAcknowledged()
                }
            }
        }
        var progress: ((Float, Int) -> Void)?
        if let requestProgress = request.progress {
            progress = { [weak self] value, packetLength in
                if let self, self.isLive(entryId: entryId, generation: generation) {
                    requestProgress(value, packetLength)
                }
            }
        }
        let completed = request.completed
        return NetworkEngineRequest(
            payload: request.payload,
            metadata: request.metadata,
            shortMetadata: request.shortMetadata,
            parse: request.parse,
            options: request.options,
            shouldContinueAfterError: request.shouldContinueAfterError,
            dependsOn: request.dependsOn,
            acknowledged: acknowledged,
            progress: progress,
            completed: { [weak self] result in
                guard let self else {
                    return
                }
                self.lock.lock()
                guard let entry = self.entries[entryId], entry.generation == generation else {
                    self.lock.unlock()
                    return
                }
                self.entries.removeValue(forKey: entryId)
                let drained = self.drainedGenerations()
                self.lock.unlock()
                completed(result)
                self.scheduleFinishDraining(generations: drained)
            }
        )
    }

    private func scheduleFinishDraining(generations: [Int]) {
        if generations.isEmpty {
            return
        }
        Queue.concurrentDefaultQueue().async { [weak self] in
            guard let self else {
                return
            }
            for generation in generations {
                self.finishDraining(generation: generation)
            }
        }
    }

    private func drainedGenerations() -> [Int] {
        if self.draining.isEmpty {
            return []
        }
        var waiting = Set<Int>()
        for entry in self.entries.values where self.draining[entry.generation] != nil {
            waiting.insert(entry.generation)
        }
        return self.draining.keys.filter { !waiting.contains($0) }
    }

    private func cancel(entryId: Int) {
        self.lock.lock()
        let entry = self.entries.removeValue(forKey: entryId)
        let drained = self.drainedGenerations()
        self.lock.unlock()
        entry?.disposable?.dispose()
        self.scheduleFinishDraining(generations: drained)
    }

    func switchEngine(to engine: NetworkEngine, drainTimeout: Double) {
        self.lock.lock()
        if self.isStopped {
            self.lock.unlock()
            return
        }
        let generation = self.generation + 1
        self.lock.unlock()

        let sessionDelegate = self.hasDelegate ? SwitchingSessionDelegate(generation: generation) : nil
        sessionDelegate?.session = self
        let replacement = engine.makeSession(datacenterId: self.datacenterId, role: self.role, usageCalculationInfo: self.usageCalculationInfo, delegate: sessionDelegate)

        self.lock.lock()
        if self.isStopped || self.generation + 1 != generation {
            self.lock.unlock()
            replacement.stop()
            return
        }
        self.generation = generation
        let previous = self.current
        let previousGeneration = generation - 1
        self.current = replacement
        self.currentDelegate = sessionDelegate
        self.draining[previousGeneration] = previous
        let sinks = self.sinks
        let isPaused = self.isPaused
        let isOnline = self.isOnline
        let hasPendingRequests = self.entries.values.contains(where: { $0.generation == previousGeneration })
        self.lock.unlock()

        for sink in sinks {
            replacement.addUpdateSink(sink)
        }
        replacement.setPaused(isPaused)
        replacement.setOnline(isOnline)

        if hasPendingRequests {
            Queue.concurrentDefaultQueue().after(drainTimeout, { [weak self] in
                self?.finishDraining(generation: previousGeneration)
            })
        } else {
            self.scheduleFinishDraining(generations: [previousGeneration])
        }
    }

    private func finishDraining(generation drainedGeneration: Int) {
        self.lock.lock()
        guard let session = self.draining.removeValue(forKey: drainedGeneration) else {
            self.lock.unlock()
            return
        }
        let target = self.current
        let targetGeneration = self.generation
        var moved: [SwitchingRequestEntry] = []
        var cancelled: [Disposable] = []
        if !self.isStopped {
            for entry in self.entries.values where entry.generation == drainedGeneration {
                entry.generation = targetGeneration
                if let disposable = entry.disposable {
                    cancelled.append(disposable)
                }
                entry.disposable = nil
                moved.append(entry)
            }
        }
        let sinks = self.sinks
        self.lock.unlock()

        for disposable in cancelled {
            disposable.dispose()
        }
        session.stop()
        moved.sort(by: { $0.id < $1.id })
        for entry in moved {
            self.submit(entryId: entry.id, request: entry.request, generation: targetGeneration, to: target)
        }
        if !moved.isEmpty {
            Logger.shared.log("Network", "Engine switch: dc\(self.datacenterId) moved \(moved.count) unanswered requests to the new engine")
        }
        for sink in sinks {
            sink.networkSessionDidReset()
        }
    }

    func setPaused(_ paused: Bool) {
        self.lock.lock()
        self.isPaused = paused
        let sessions = [self.current] + Array(self.draining.values)
        let isStopped = self.isStopped
        self.lock.unlock()
        if isStopped {
            return
        }
        for session in sessions {
            session.setPaused(paused)
        }
    }

    func setOnline(_ online: Bool) {
        self.lock.lock()
        self.isOnline = online
        let sessions = [self.current] + Array(self.draining.values)
        let isStopped = self.isStopped
        self.lock.unlock()
        if isStopped {
            return
        }
        for session in sessions {
            session.setOnline(online)
        }
    }

    func addUpdateSink(_ sink: NetworkEngineUpdateSink) {
        self.lock.lock()
        self.sinks.append(sink)
        let session = self.current
        self.lock.unlock()
        session.addUpdateSink(sink)
    }

    func stop() {
        self.lock.lock()
        if self.isStopped {
            self.lock.unlock()
            return
        }
        self.isStopped = true
        let sessions = [self.current] + Array(self.draining.values)
        self.draining.removeAll()
        let disposables = self.entries.values.compactMap(\.disposable)
        self.entries.removeAll()
        self.lock.unlock()
        for disposable in disposables {
            disposable.dispose()
        }
        for session in sessions {
            session.stop()
        }
    }
}

private final class WeakSwitchingSession {
    weak var value: SwitchingNetworkSession?

    init(_ value: SwitchingNetworkSession) {
        self.value = value
    }
}

final class SwitchingNetworkEngine: NetworkEngine {
    private let lock = NSLock()
    private let switchLock = NSLock()
    private var engine: NetworkEngine
    private var sessions: [WeakSwitchingSession] = []

    var kind: NetworkEngineKind {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.engine.kind
    }

    init(engine: NetworkEngine) {
        self.engine = engine
    }

    func makeSession(datacenterId: Int, role: NetworkEngineSessionRole, usageCalculationInfo: MTNetworkUsageCalculationInfo?, delegate: NetworkEngineSessionDelegate?) -> NetworkEngineSession {
        self.lock.lock()
        let engine = self.engine
        self.lock.unlock()

        let session = SwitchingNetworkSession(engine: engine, datacenterId: datacenterId, role: role, usageCalculationInfo: usageCalculationInfo, delegate: delegate)

        self.lock.lock()
        self.sessions.removeAll(where: { $0.value == nil })
        self.sessions.append(WeakSwitchingSession(session))
        let latest = self.engine
        self.lock.unlock()

        if latest !== engine {
            session.switchEngine(to: latest, drainTimeout: 0.0)
        }
        return session
    }

    func switchEngine(to kind: NetworkEngineKind, drainTimeout: Double, makeEngine: () -> NetworkEngine?) -> Bool {
        self.switchLock.lock()
        defer {
            self.switchLock.unlock()
        }
        if self.kind == kind {
            return true
        }
        guard let engine = makeEngine() else {
            return false
        }
        self.lock.lock()
        self.engine = engine
        self.sessions.removeAll(where: { $0.value == nil })
        let sessions = self.sessions.compactMap(\.value)
        self.lock.unlock()
        for session in sessions {
            session.switchEngine(to: engine, drainTimeout: drainTimeout)
        }
        return true
    }
}
