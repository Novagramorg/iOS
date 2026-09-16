import Foundation
import PasscodeCore

@available(macOS 10.15, *)
public struct WalletAuthorizationRequest: Sendable {
    public let id: UUID
    public let namespace: String
    public let reason: String
    public let lifetime: PasscodeSession.Lifetime
}

@available(macOS 10.15, *)
enum WalletAuthorizationScope {
    @TaskLocal static var session: PasscodeSession?
}

@available(macOS 10.15, *)
final class WalletAuthorizationContext: @unchecked Sendable {
    typealias Presenter = @Sendable (WalletAuthorizationRequest) async throws -> PasscodeSession
    let namespace: String
    private let credentials: PasscodeCredentialStore
    private let lock = NSLock()
    private var presenter: Presenter?
    private var generation: UInt64 = 0
    private var operationRevision: UInt64 = 0
    private let sessions = NSMapTable<NSUUID, PasscodeSession>(keyOptions: .strongMemory, valueOptions: .weakMemory)
    private var available = false
    private var availabilityWaiters: [UUID: CheckedContinuation<Void, Error>] = [:]
    private var resultGenerations: [UUID: UInt64] = [:]

    var isAvailable: Bool {
        self.lock.lock(); defer { self.lock.unlock() }
        return self.available
    }

    init(namespace: String, credentials: PasscodeCredentialStore = .shared) {
        self.namespace = namespace
        self.credentials = credentials
    }

    func operationGeneration(requireAvailable: Bool = true) throws -> UInt64 {
        self.lock.lock(); defer { self.lock.unlock() }
        guard !requireAvailable || self.available else { throw PasscodeError.cancelled }
        return requireAvailable ? self.operationRevision : self.generation
    }

    func validateGeneration(_ generation: UInt64, requireAvailable: Bool = true) throws {
        self.lock.lock(); defer { self.lock.unlock() }
        guard (!requireAvailable || self.available),
              (requireAvailable ? self.operationRevision : self.generation) == generation else { throw PasscodeError.cancelled }
    }

    func setPresenter(_ presenter: @escaping Presenter) {
        self.lock.lock(); self.presenter = presenter; self.lock.unlock()
    }

    func setAvailable(_ available: Bool) {
        self.lock.lock()
        self.available = available
        if !available { self.operationRevision &+= 1 }
        let revoked = available ? [] : (self.sessions.objectEnumerator()?.allObjects as? [PasscodeSession] ?? []).filter { $0.lifetime == .standard }
        for session in revoked { self.sessions.removeObject(forKey: session.id as NSUUID) }
        let waiters = available ? Array(self.availabilityWaiters.values) : []
        if available { self.availabilityWaiters.removeAll() }
        self.lock.unlock()
        for session in revoked { session.invalidate() }
        for waiter in waiters { waiter.resume() }
    }

    func invalidate(preservingResultFor operationId: UUID? = nil) {
        self.lock.lock()
        let preservedId = operationId.flatMap { self.resultGenerations[$0] == self.generation ? $0 : nil }
        self.generation &+= 1
        self.operationRevision &+= 1
        self.resultGenerations.removeAll()
        if let preservedId { self.resultGenerations[preservedId] = self.generation }
        let sessions = self.sessions.objectEnumerator()?.allObjects as? [PasscodeSession] ?? []
        self.sessions.removeAllObjects()
        let waiters = Array(self.availabilityWaiters.values)
        self.availabilityWaiters.removeAll()
        self.lock.unlock()
        for session in sessions { session.invalidate() }
        for waiter in waiters { waiter.resume(throwing: PasscodeError.cancelled) }
    }

    func beginResultDelivery(id: UUID) {
        self.lock.lock(); defer { self.lock.unlock() }
        self.resultGenerations[id] = self.generation
    }

    func resultDeliveryGeneration(id: UUID) throws -> UInt64 {
        self.lock.lock(); defer { self.lock.unlock() }
        guard let generation = self.resultGenerations[id], generation == self.generation else { throw PasscodeError.cancelled }
        return generation
    }

    func finishResultDelivery(id: UUID) {
        self.lock.lock(); defer { self.lock.unlock() }
        self.resultGenerations.removeValue(forKey: id)
    }

    func waitUntilAvailable(generation: UInt64) async throws {
        let id = UUID()
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                self.lock.lock(); defer { self.lock.unlock() }
                if Task.isCancelled || self.generation != generation {
                    continuation.resume(throwing: PasscodeError.cancelled)
                } else if self.available {
                    continuation.resume()
                } else {
                    self.availabilityWaiters[id] = continuation
                }
            }
        }, onCancel: {
            self.lock.lock()
            let continuation = self.availabilityWaiters.removeValue(forKey: id)
            self.lock.unlock()
            continuation?.resume(throwing: PasscodeError.cancelled)
        })
        try Task.checkCancellation()
        try self.validateGeneration(generation, requireAvailable: false)
    }

    private func snapshot() throws -> (UInt64, UInt64, Presenter) {
        self.lock.lock(); defer { self.lock.unlock() }
        guard self.available, let presenter = self.presenter else { throw PasscodeError.authenticationRequired }
        return (self.generation, self.operationRevision, presenter)
    }

    private func install(_ session: PasscodeSession, generation: UInt64) throws -> PasscodeSession {
        do {
            try self.credentials.validate(session, scope: .resource(namespace: self.namespace))
        } catch {
            session.invalidate()
            throw error
        }
        self.lock.lock(); defer { self.lock.unlock() }
        guard self.available, self.generation == generation else { session.invalidate(); throw PasscodeError.cancelled }
        self.sessions.setObject(session, forKey: session.id as NSUUID)
        return session
    }

    func authorize(id: UUID, reason: String, lifetime: PasscodeSession.Lifetime = .standard) async throws -> PasscodeSession? {
        let generation = try self.operationGeneration()
        guard try walletProtectionSettings(credentials: self.credentials).enabled else {
            try self.validateGeneration(generation)
            return nil
        }
        let (credentialGeneration, presentationRevision, presenter) = try self.snapshot()
        let session = try await presenter(WalletAuthorizationRequest(id: id, namespace: self.namespace, reason: reason, lifetime: lifetime))
        do {
            try Task.checkCancellation()
            try self.validateGeneration(presentationRevision)
            guard session.lifetime == lifetime else { throw PasscodeError.authenticationRequired }
            return try self.install(session, generation: credentialGeneration)
        } catch {
            session.invalidate()
            throw error
        }
    }

    func beginSession(id: UUID, reason: String, lifetime: PasscodeSession.Lifetime = .standard) async throws -> PasscodeSession {
        if let session = try await self.authorize(id: id, reason: reason, lifetime: lifetime) { return session }
        let generation = try self.operationGeneration(requireAvailable: false)
        return try self.install(self.credentials.unprotectedSession(namespace: self.namespace, lifetime: lifetime), generation: generation)
    }

    func adoptSession(_ session: PasscodeSession?) throws -> PasscodeSession? {
        if let session {
            do {
                try self.validate(session)
                return session
            } catch {
                self.finish(session)
                return nil
            }
        }
        let generation = try self.operationGeneration(requireAvailable: false)
        guard try !walletProtectionSettings(credentials: self.credentials).enabled else { return nil }
        return try self.install(self.credentials.unprotectedSession(namespace: self.namespace), generation: generation)
    }

    func validate(_ session: PasscodeSession, boundTo sessionId: UUID? = nil, requireAvailable: Bool = true) throws {
        self.lock.lock()
        let valid = (!requireAvailable || session.lifetime == .ownerManaged || self.available)
            && self.sessions.object(forKey: session.id as NSUUID) === session
            && (sessionId == nil || sessionId == session.id)
        self.lock.unlock()
        guard valid else { throw PasscodeError.staleAuthorization }
        try self.credentials.validate(session, scope: .resource(namespace: self.namespace), requireAvailable: requireAvailable)
    }

    func withSession<Value>(_ session: PasscodeSession?, operation: nonisolated(nonsending) () async throws -> Value) async throws -> Value {
        if let session {
            try await session.waitUntilAvailable()
            try self.validate(session)
        }
        return try await WalletAuthorizationScope.$session.withValue(session, operation: operation)
    }

    func finish(_ session: PasscodeSession?) {
        guard let session else { return }
        self.lock.lock(); self.sessions.removeObject(forKey: session.id as NSUUID); self.lock.unlock()
        session.invalidate()
    }
}
