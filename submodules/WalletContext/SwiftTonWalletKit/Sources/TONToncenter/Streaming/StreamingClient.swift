import Foundation
import TONCore

/// A duplex text socket. The seam that keeps the client testable without a network.
public protocol StreamingSocket: Sendable {
    func connect() async throws
    /// Next text frame. Throws when the connection ends.
    func receive() async throws -> String
    func send(_ text: String) async throws
    func close() async
}

/// Builds a socket per connection attempt.
///
/// A factory rather than a single socket, because a reconnect needs a *new* socket — a closed
/// `URLSessionWebSocketTask` cannot be restarted.
public protocol StreamingSocketFactory: Sendable {
    func makeSocket() -> any StreamingSocket
}

/// Live Toncenter streaming over `URLSessionWebSocketTask`, available at the iOS 13 floor.
public struct URLSessionStreamingSocketFactory: StreamingSocketFactory {
    let urlProvider: @Sendable () async throws -> URL
    let session: URLSession

    public init(url: URL, session: URLSession = .shared) {
        self.urlProvider = { url }
        self.session = session
    }

    public init(
        urlProvider: @Sendable @escaping () async throws -> URL,
        session: URLSession = .shared
    ) {
        self.urlProvider = urlProvider
        self.session = session
    }

    public func makeSocket() -> any StreamingSocket {
        URLSessionStreamingSocket(urlProvider: urlProvider, session: session)
    }
}

/// One `URLSessionWebSocketTask`, wrapped as an actor.
///
/// An actor rather than a lock: the protocol's methods are async, and `NSLock` cannot be held
/// across a suspension. Reentrancy is wanted here — a `send` must be able to proceed while the
/// read loop is parked in `receive()`, which is where it spends nearly all its time.
actor URLSessionStreamingSocket: StreamingSocket {
    private let urlProvider: @Sendable () async throws -> URL
    private let session: URLSession
    private var task: URLSessionWebSocketTask?

    init(urlProvider: @Sendable @escaping () async throws -> URL, session: URLSession) {
        self.urlProvider = urlProvider
        self.session = session
    }

    func connect() async throws {
        let url = try await urlProvider()
        try Task.checkCancellation()
        let task = session.webSocketTask(with: url)
        self.task = task
        task.resume()
    }

    func receive() async throws -> String {
        guard let task else { throw StreamingError.notConnected }
        switch try await task.receive() {
        case .string(let text): return text
        case .data(let data): return String(decoding: data, as: UTF8.self)
        @unknown default: throw StreamingError.unexpectedFrame
        }
    }

    func send(_ text: String) async throws {
        guard let task else { throw StreamingError.notConnected }
        try await task.send(.string(text))
    }

    func close() async {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }
}

public enum StreamingError: Error, CustomStringConvertible {
    case notConnected
    case unexpectedFrame

    public var description: String {
        switch self {
        case .notConnected: return "The streaming socket is not connected"
        case .unexpectedFrame: return "The streaming socket delivered an unsupported frame"
        }
    }
}

/// Streams account, transaction, and jetton updates from Toncenter.
///
/// One connection carries every watched address. The server replaces the whole subscription on
/// each `subscribe`, so the client always sends the union of what is currently watched rather
/// than deltas — which also makes reconnect trivial: resubscribing is the same message.
///
/// Reconnection is the normal case, not an error path. The socket is dropped by the server
/// after roughly thirty idle seconds, so a keepalive ping runs unconditionally; without it the
/// stream simply stops and nothing says so.
public actor ToncenterStreaming {
    public struct Configuration: Sendable {
        /// How often to ping. Must be under the server's idle timeout, observed at ~30s.
        public let pingInterval: TimeInterval
        public let backoff: StreamBackoff
        /// Weakest finality to receive. `pending` shows a transfer the moment it is seen.
        public let minFinality: StreamFinality

        public init(
            pingInterval: TimeInterval = 15,
            backoff: StreamBackoff = .default,
            minFinality: StreamFinality = .pending
        ) {
            self.pingInterval = pingInterval
            self.backoff = backoff
            self.minFinality = minFinality
        }

        public static let `default` = Configuration()
    }

    public struct StreamBackoff: Sendable {
        public let initialDelay: TimeInterval
        public let maxDelay: TimeInterval
        public let multiplier: Double

        public init(initialDelay: TimeInterval = 0.5, maxDelay: TimeInterval = 30, multiplier: Double = 2) {
            self.initialDelay = initialDelay
            self.maxDelay = maxDelay
            self.multiplier = multiplier
        }

        public func delay(forAttempt attempt: Int) -> TimeInterval {
            guard attempt > 0 else { return 0 }
            return min(initialDelay * pow(multiplier, Double(attempt - 1)), maxDelay)
        }

        public static let `default` = StreamBackoff()
        public static let immediate = StreamBackoff(initialDelay: 0, maxDelay: 0, multiplier: 1)
    }

    private let factory: any StreamingSocketFactory
    private let configuration: Configuration
    private let now: @Sendable () -> Int64

    private var watched: [Address: Set<StreamEventType>] = [:]
    private var subscribers: [UUID: AsyncStream<StreamEvent>.Continuation] = [:]

    private var socket: (any StreamingSocket)?
    private var pump: Task<Void, Never>?
    private var pinger: Task<Void, Never>?
    private var requestCounter = 0

    /// Highest finality already seen per trace, and who cared.
    ///
    /// Two jobs: dropping a `pending` frame that arrives after `confirmed` for the same trace,
    /// and remembering which watched accounts a trace touched so a later `trace_invalidated` —
    /// which names no account — can be routed to them.
    private var traceRecord: [String: (finality: StreamFinality, accounts: Set<Address>)] = [:]

    public private(set) var isConnected = false

    public init(
        factory: any StreamingSocketFactory,
        configuration: Configuration = .default,
        now: @Sendable @escaping () -> Int64 = { Int64(Date().timeIntervalSince1970 * 1000) }
    ) {
        self.factory = factory
        self.configuration = configuration
        self.now = now
    }

    /// The endpoint for a network, with the key as a query parameter.
    ///
    /// A query parameter rather than a header because the WebSocket handshake in
    /// `URLSessionWebSocketTask` offers no way to attach one portably.
    public static func endpoint(network: Network, apiKey: String?) -> URL {
        let host = network == .mainnet ? "toncenter.com" : "testnet.toncenter.com"
        var components = URLComponents(string: "wss://\(host)/api/streaming/v2/ws")!
        if let apiKey {
            // Encoded strictly, for the same reason the REST transport does: `queryItems`
            // leaves `+` alone and a server reads it as a space. Keys are hex today, so this
            // is prevention rather than a fix — but the two paths behaving differently is
            // exactly how one of them ends up wrong later.
            components.percentEncodedQuery = "api_key=" + URLSessionTransport.encodeQueryComponent(apiKey)
        }
        return components.url!
    }

    // MARK: - Subscribing

    /// Events for the given addresses.
    ///
    /// Every subscriber gets its own stream; the client keeps one socket underneath. Ending the
    /// stream — by breaking out of the `for await` — removes the watch and resubscribes.
    public func events(
        for addresses: [Address],
        types: Set<StreamEventType> = Set(StreamEventType.allCases)
    ) -> AsyncStream<StreamEvent> {
        let id = UUID()
        // Unbounded: dropping a balance change because the consumer was briefly slow would
        // leave the UI showing a stale number with nothing to correct it.
        let (stream, continuation) = Self.makeStream()

        subscribers[id] = continuation
        for address in addresses {
            watched[address, default: []].formUnion(types)
        }

        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeSubscriber(id, addresses: addresses) }
        }

        Task { await self.ensureRunning() }
        return stream
    }

    private static func makeStream() -> (AsyncStream<StreamEvent>, AsyncStream<StreamEvent>.Continuation) {
        var continuation: AsyncStream<StreamEvent>.Continuation!
        let stream = AsyncStream<StreamEvent>(bufferingPolicy: .unbounded) { continuation = $0 }
        return (stream, continuation)
    }

    private func removeSubscriber(_ id: UUID, addresses: [Address]) async {
        subscribers[id] = nil
        if subscribers.isEmpty {
            watched.removeAll()
            await stop()
        } else {
            await resubscribe()
        }
    }

    /// Stops the connection and ends every stream.
    public func stop() async {
        pump?.cancel()
        pinger?.cancel()
        pump = nil
        pinger = nil
        await socket?.close()
        socket = nil
        setConnected(false)
        for continuation in subscribers.values { continuation.finish() }
        subscribers.removeAll()
        watched.removeAll()
        traceRecord.removeAll()
    }

    // MARK: - Connection

    private func ensureRunning() async {
        guard pump == nil else {
            await resubscribe()
            return
        }
        pump = Task { [weak self] in await self?.runLoop() }
    }

    private func runLoop() async {
        var attempt = 0
        while !Task.isCancelled {
            let delay = configuration.backoff.delay(forAttempt: attempt)
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            if Task.isCancelled { return }

            do {
                try await runOnce()
                // A clean end still warrants reconnecting: the server closes idle connections,
                // and a wallet that stopped listening after one close would silently go deaf.
                attempt = min(attempt + 1, 8)
            } catch is CancellationError {
                return
            } catch {
                attempt = min(attempt + 1, 8)
            }
            setConnected(false)
            broadcast(.connectionChanged(isConnected: false))
        }
    }

    /// One connection, from open until it fails.
    private func runOnce() async throws {
        let socket = factory.makeSocket()
        self.socket = socket
        try await socket.connect()

        setConnected(true)
        broadcast(.connectionChanged(isConnected: true))
        try await sendSubscription(over: socket)
        startPinging(over: socket)
        defer { pinger?.cancel(); pinger = nil }

        while !Task.isCancelled {
            let frame = try await socket.receive()
            handle(frame)
        }
    }

    private func startPinging(over socket: any StreamingSocket) {
        pinger?.cancel()
        let interval = configuration.pingInterval
        pinger = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                if Task.isCancelled { return }
                await self?.sendPing(over: socket)
            }
        }
    }

    private func sendPing(over socket: any StreamingSocket) async {
        requestCounter += 1
        let ping = StreamWire.PingRequest(id: "ping-\(requestCounter)")
        guard let data = try? JSONEncoder().encode(ping) else { return }
        // A failed ping is not handled here: the read loop will see the socket die and
        // reconnect, and reacting in two places would race.
        try? await socket.send(String(decoding: data, as: UTF8.self))
    }

    private func resubscribe() async {
        guard let socket, isConnected else { return }
        try? await sendSubscription(over: socket)
    }

    private func sendSubscription(over socket: any StreamingSocket) async throws {
        requestCounter += 1

        guard !watched.isEmpty else {
            let request = StreamWire.UnsubscribeRequest(id: "clear-\(requestCounter)", addresses: [])
            let data = try JSONEncoder().encode(request)
            try await socket.send(String(decoding: data, as: UTF8.self))
            return
        }

        let types = Set(watched.values.flatMap { $0 }).map(\.rawValue).sorted()
        // Sorted so the frame is deterministic, which makes it assertable in tests.
        let addresses = watched.keys.map(\.rawString).sorted()

        let request = StreamWire.SubscribeRequest(
            id: "sync-\(requestCounter)",
            types: types,
            addresses: addresses,
            minFinality: configuration.minFinality.rawValue,
            includeMetadata: true
        )
        let data = try JSONEncoder().encode(request)
        try await socket.send(String(decoding: data, as: UTF8.self))
    }

    private func setConnected(_ value: Bool) { isConnected = value }

    // MARK: - Frames

    func handle(_ frame: String) {
        // Transactions first: they need the watched set to split a trace by account, which the
        // generic path cannot do.
        let updates = StreamMappers.transactionUpdates(from: frame) { [watched] address in
            watched[address]?.contains(.transactions) ?? false
        }
        if !updates.isEmpty {
            for update in updates where accept(update) {
                broadcast(.transactions(update))
            }
            recordTrace(frame: frame, updates: updates)
            return
        }

        guard let event = StreamMappers.event(from: frame) else { return }

        switch event {
        case .transactions(let update) where update.isInvalidated:
            // The invalidation frame names no account, so it is routed from what the trace
            // touched earlier. Without that record the event would be silently dropped and a
            // pending transfer would sit in the UI forever.
            guard let record = traceRecord[update.traceHash] else { return }
            for address in record.accounts where watched[address]?.contains(.transactions) == true {
                broadcast(.transactions(
                    TransactionUpdate(
                        address: address,
                        transactions: [],
                        finality: update.finality,
                        traceHash: update.traceHash,
                        isInvalidated: true
                    )
                ))
            }
            traceRecord[update.traceHash] = nil

        case .balance(let update):
            guard watched[update.address]?.contains(.accountState) == true else { return }
            broadcast(event)

        case .jettons(let update):
            guard watched[update.owner]?.contains(.jettons) == true else { return }
            broadcast(event)

        default:
            broadcast(event)
        }
    }

    /// Whether a transaction update is newer than what was already reported for its trace.
    private func accept(_ update: TransactionUpdate) -> Bool {
        guard let record = traceRecord[update.traceHash] else { return true }
        // Equal finality is allowed through: a trace can legitimately grow more transactions
        // at the same level. Only a *weaker* frame is stale.
        return update.finality >= record.finality
    }

    private func recordTrace(frame: String, updates: [TransactionUpdate]) {
        guard let first = updates.first else { return }
        let accounts = Set(StreamMappers.accounts(inTransactionFrame: frame))
        var record = traceRecord[first.traceHash] ?? (finality: first.finality, accounts: [])
        record.finality = max(record.finality, first.finality)
        record.accounts.formUnion(accounts)
        traceRecord[first.traceHash] = record
    }

    private func broadcast(_ event: StreamEvent) {
        for continuation in subscribers.values { continuation.yield(event) }
    }

    // MARK: - Test access

    /// Frames the client would send, for tests that assert the subscription wire format.
    func currentlyWatched() -> [Address: Set<StreamEventType>] { watched }
}
