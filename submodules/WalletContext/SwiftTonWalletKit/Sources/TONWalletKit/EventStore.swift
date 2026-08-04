import Foundation

/// Lifecycle of a durable event.
public enum EventStatus: String, Codable, Sendable {
    /// Stored, not yet claimed.
    case new
    /// Claimed by a wallet and being handled.
    case processing
    case completed
    case errored
}

/// What kind of request an event carries.
public enum EventType: String, Codable, Sendable {
    case connect
    case disconnect
    case sendTransaction
    case signData
    case signMessage
    case unknown
}

/// A dApp request persisted so it survives an app restart.
///
/// Durability matters because a request arrives over the bridge and may sit unanswered
/// while the user is elsewhere. Losing it means the dApp waits forever for a reply that
/// will never come.
public struct StoredEvent: Codable, Sendable, Equatable {
    public let id: String
    /// The dApp session it belongs to. Absent for events not yet tied to a session.
    public var sessionID: String?
    public var eventType: EventType
    /// The raw bridge payload, kept verbatim so processing logic can change without
    /// invalidating stored events.
    public var payload: Data
    public var status: EventStatus
    /// Unix milliseconds.
    public var createdAt: Int64
    public var processingStartedAt: Int64?
    public var completedAt: Int64?
    /// Which wallet claimed it, so a stale claim can be identified.
    public var lockedBy: String?
    public var sizeBytes: Int
    public var retryCount: Int
    public var lastError: String?

    public init(
        id: String,
        sessionID: String?,
        eventType: EventType,
        payload: Data,
        status: EventStatus = .new,
        createdAt: Int64,
        processingStartedAt: Int64? = nil,
        completedAt: Int64? = nil,
        lockedBy: String? = nil,
        retryCount: Int = 0,
        lastError: String? = nil
    ) {
        self.id = id
        self.sessionID = sessionID
        self.eventType = eventType
        self.payload = payload
        self.status = status
        self.createdAt = createdAt
        self.processingStartedAt = processingStartedAt
        self.completedAt = completedAt
        self.lockedBy = lockedBy
        self.sizeBytes = payload.count
        self.retryCount = retryCount
        self.lastError = lastError
    }
}

/// Tuning for the durable event queue.
public struct DurableEventsConfig: Sendable {
    /// How often to sweep for events whose handler died mid-flight.
    public let recoveryInterval: TimeInterval
    /// How long a claim may be held before it is considered abandoned.
    public let processingTimeout: TimeInterval
    public let cleanupInterval: TimeInterval
    /// How long finished events are kept, for debugging and duplicate suppression.
    public let retention: TimeInterval
    public let retryDelay: TimeInterval
    public let maxRetries: Int
    /// Refuse events larger than this. A bridge peer should not be able to fill storage.
    public let maxEventBytes: Int

    public init(
        recoveryInterval: TimeInterval = 10,
        processingTimeout: TimeInterval = 60,
        cleanupInterval: TimeInterval = 60,
        retention: TimeInterval = 600,
        retryDelay: TimeInterval = 0.5,
        maxRetries: Int = 20,
        maxEventBytes: Int = 100 * 1024
    ) {
        self.recoveryInterval = recoveryInterval
        self.processingTimeout = processingTimeout
        self.cleanupInterval = cleanupInterval
        self.retention = retention
        self.retryDelay = retryDelay
        self.maxRetries = maxRetries
        self.maxEventBytes = maxEventBytes
    }

    public static let `default` = DurableEventsConfig()
}

/// A durable queue of dApp requests.
///
/// An actor, which is the whole reason this is simpler than the reference: that version
/// hand-rolls a `Map<string, Promise<void>>` lock table to serialise concurrent access to
/// the same event. Actor isolation gives that for free, so the claim logic here is a plain
/// check rather than a lock protocol layered over promises.
///
/// State is persisted after every mutation. That is more writes than strictly necessary,
/// but the alternative — batching — loses events on a kill, which is the exact failure this
/// exists to prevent.
public actor EventStore {
    private let storage: any WalletKitStorage
    private let config: DurableEventsConfig
    /// Injectable so tests control time rather than sleeping.
    private let now: @Sendable () -> Int64

    /// In-memory mirror of the persisted queue, keyed by event id.
    private var events: [String: StoredEvent] = [:]
    private var isLoaded = false

    public init(
        storage: any WalletKitStorage,
        config: DurableEventsConfig = .default,
        now: @Sendable @escaping () -> Int64 = { Int64(Date().timeIntervalSince1970 * 1000) }
    ) {
        self.storage = storage
        self.config = config
        self.now = now
    }

    public enum EventStoreError: Error, CustomStringConvertible, Equatable {
        case eventTooLarge(bytes: Int, limit: Int)
        case notFound(String)
        case statusMismatch(expected: EventStatus, actual: EventStatus)

        public var description: String {
            switch self {
            case .eventTooLarge(let bytes, let limit):
                return "Event of \(bytes) bytes exceeds the \(limit)-byte limit"
            case .notFound(let id):
                return "No event with id \(id)"
            case .statusMismatch(let expected, let actual):
                return "Event status was \(actual), expected \(expected)"
            }
        }
    }

    // MARK: - Persistence

    private func loadIfNeeded() async {
        guard !isLoaded else { return }
        isLoaded = true
        if let stored: [String: StoredEvent] = await storage.getJSON(StorageKey.durableEvents) {
            events = stored
        }
    }

    private func persist() async {
        try? await storage.setJSON(StorageKey.durableEvents, events)
    }

    // MARK: - Storing

    /// Persists a new event.
    ///
    /// The id is caller-supplied so a bridge message that arrives twice — which happens on
    /// reconnect without a resume point — maps to the same event rather than being handled
    /// twice.
    @discardableResult
    public func store(
        id: String,
        sessionID: String?,
        eventType: EventType,
        payload: Data
    ) async throws -> StoredEvent {
        await loadIfNeeded()

        guard payload.count <= config.maxEventBytes else {
            throw EventStoreError.eventTooLarge(bytes: payload.count, limit: config.maxEventBytes)
        }

        // Idempotent: re-storing a known id returns the existing event rather than
        // resetting its status and re-delivering it.
        if let existing = events[id] { return existing }

        let event = StoredEvent(
            id: id,
            sessionID: sessionID,
            eventType: eventType,
            payload: payload,
            createdAt: now()
        )
        events[id] = event
        await persist()
        return event
    }

    // MARK: - Querying

    public func event(id: String) async -> StoredEvent? {
        await loadIfNeeded()
        return events[id]
    }

    public func allEvents() async -> [StoredEvent] {
        await loadIfNeeded()
        return events.values.sorted { $0.createdAt < $1.createdAt }
    }

    /// Unclaimed events for the given sessions, oldest first.
    ///
    /// Oldest-first matters: a user who receives two requests should be shown them in the
    /// order the dApp sent them.
    public func pendingEvents(
        sessionIDs: [String],
        types: [EventType]
    ) async -> [StoredEvent] {
        await loadIfNeeded()
        let sessions = Set(sessionIDs)
        let wanted = Set(types)
        return events.values
            .filter { $0.status == .new }
            .filter { wanted.contains($0.eventType) }
            .filter { $0.sessionID.map(sessions.contains) ?? false }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// Unclaimed events not tied to any session — a connect request arrives before a
    /// session exists.
    public func pendingEventsWithoutSession(types: [EventType]) async -> [StoredEvent] {
        await loadIfNeeded()
        let wanted = Set(types)
        return events.values
            .filter { $0.status == .new && $0.sessionID == nil }
            .filter { wanted.contains($0.eventType) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    // MARK: - Claiming

    /// Claims an event for a wallet, or returns nil when someone else already has it.
    ///
    /// Returning nil rather than throwing keeps the caller's loop simple: losing a race is
    /// an ordinary outcome when several wallets poll the same queue.
    public func claim(id: String, walletID: String) async -> StoredEvent? {
        await loadIfNeeded()
        guard var event = events[id], event.status == .new else { return nil }

        event.status = .processing
        event.processingStartedAt = now()
        event.lockedBy = walletID
        events[id] = event
        await persist()
        return event
    }

    /// Releases a claim.
    ///
    /// With an error, the event goes back to `new` so it can be retried — up to
    /// `maxRetries`, after which it is marked `errored` rather than retried forever.
    @discardableResult
    public func release(id: String, error: String? = nil) async throws -> StoredEvent {
        await loadIfNeeded()
        guard var event = events[id] else { throw EventStoreError.notFound(id) }

        event.lockedBy = nil
        event.processingStartedAt = nil

        if let error {
            event.lastError = error
            event.retryCount += 1
            // Give up rather than loop forever on an event that always fails.
            event.status = event.retryCount >= config.maxRetries ? .errored : .new
        } else {
            event.status = .new
        }

        events[id] = event
        await persist()
        return event
    }

    /// Marks an event finished.
    @discardableResult
    public func complete(id: String) async throws -> StoredEvent {
        await loadIfNeeded()
        guard var event = events[id] else { throw EventStoreError.notFound(id) }

        event.status = .completed
        event.completedAt = now()
        event.lockedBy = nil
        events[id] = event
        await persist()
        return event
    }

    /// Compare-and-set on status, for callers that must not clobber a concurrent change.
    @discardableResult
    public func updateStatus(
        id: String,
        to newStatus: EventStatus,
        expecting oldStatus: EventStatus
    ) async throws -> StoredEvent {
        await loadIfNeeded()
        guard var event = events[id] else { throw EventStoreError.notFound(id) }
        guard event.status == oldStatus else {
            throw EventStoreError.statusMismatch(expected: oldStatus, actual: event.status)
        }
        event.status = newStatus
        events[id] = event
        await persist()
        return event
    }

    // MARK: - Recovery and cleanup

    /// Reclaims events whose handler died mid-flight.
    ///
    /// Without this, an app killed while showing a confirmation sheet would leave the
    /// request stuck in `processing` forever and the dApp waiting. Returns how many were
    /// recovered.
    @discardableResult
    public func recoverStaleEvents() async -> Int {
        await loadIfNeeded()
        let cutoff = now() - Int64(config.processingTimeout * 1000)
        var recovered = 0

        for (id, event) in events {
            guard event.status == .processing,
                  let startedAt = event.processingStartedAt,
                  startedAt < cutoff
            else { continue }

            var updated = event
            updated.status = .new
            updated.lockedBy = nil
            updated.processingStartedAt = nil
            updated.retryCount += 1
            updated.lastError = "Reclaimed after processing timeout"
            // A permanently failing event must not cycle forever.
            if updated.retryCount >= config.maxRetries { updated.status = .errored }
            events[id] = updated
            recovered += 1
        }

        if recovered > 0 { await persist() }
        return recovered
    }

    /// Drops finished events past the retention window. Returns how many were removed.
    ///
    /// Only terminal events are dropped: an unanswered request is never discarded on age,
    /// because the user may still act on it.
    @discardableResult
    public func cleanupOldEvents() async -> Int {
        await loadIfNeeded()
        let cutoff = now() - Int64(config.retention * 1000)
        let before = events.count

        events = events.filter { _, event in
            switch event.status {
            case .completed, .errored:
                let finishedAt = event.completedAt ?? event.createdAt
                return finishedAt >= cutoff
            case .new, .processing:
                return true
            }
        }

        let removed = before - events.count
        if removed > 0 { await persist() }
        return removed
    }

    /// Removes everything. Used when a user resets the wallet.
    public func clear() async {
        await loadIfNeeded()
        events.removeAll()
        await persist()
    }

    // MARK: - Introspection

    public func count(status: EventStatus? = nil) async -> Int {
        await loadIfNeeded()
        guard let status else { return events.count }
        return events.values.filter { $0.status == status }.count
    }
}
