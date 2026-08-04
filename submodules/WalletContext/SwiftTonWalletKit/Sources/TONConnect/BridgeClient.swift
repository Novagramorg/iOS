import Foundation

/// A message relayed by the bridge.
public struct BridgeMessage: Sendable {
    /// Sender's session public key, hex — the dApp's `clientID`.
    public let from: String
    /// Base64 `nonce ‖ box`, to be opened with ``SessionCrypto``.
    public let message: String
    /// The SSE event id, persisted so a reconnect resumes rather than replaying.
    public let eventID: String?

    public init(from: String, message: String, eventID: String?) {
        self.from = from
        self.message = message
        self.eventID = eventID
    }
}

/// Reconnect pacing.
///
/// Exponential with a cap and jitter. Jitter matters: without it, every wallet that
/// dropped when a bridge restarted would reconnect in lockstep and knock it over again.
public struct BackoffPolicy: Sendable {
    public let initialDelay: TimeInterval
    public let maxDelay: TimeInterval
    public let multiplier: Double
    /// Fraction of the delay to randomize, 0...1.
    public let jitter: Double

    public init(
        initialDelay: TimeInterval = 1,
        maxDelay: TimeInterval = 60,
        multiplier: Double = 2,
        jitter: Double = 0.3
    ) {
        self.initialDelay = initialDelay
        self.maxDelay = maxDelay
        self.multiplier = multiplier
        self.jitter = jitter
    }

    /// Delay before attempt `n`, counting from 0.
    public func delay(forAttempt attempt: Int) -> TimeInterval {
        guard attempt > 0 else { return 0 }
        let exponential = initialDelay * pow(multiplier, Double(attempt - 1))
        let capped = min(exponential, maxDelay)
        guard jitter > 0 else { return capped }
        let spread = capped * jitter
        return max(0, capped - spread + Double.random(in: 0...(2 * spread)))
    }

    public static let `default` = BackoffPolicy()
    /// For tests: no waiting.
    public static let immediate = BackoffPolicy(initialDelay: 0, maxDelay: 0, multiplier: 1, jitter: 0)
}

/// Where the last seen event id is kept, so a reconnect resumes instead of replaying.
///
/// A protocol rather than a concrete store because the id must outlive the process: a
/// wallet relaunched after being killed should not re-deliver requests the user already
/// answered.
public protocol LastEventIDStore: Sendable {
    func load() async -> String?
    func save(_ id: String) async
}

/// In-memory store, for tests and for sessions that need not survive a restart.
public actor InMemoryLastEventIDStore: LastEventIDStore {
    private var id: String?

    public init(initial: String? = nil) {
        self.id = initial
    }

    public func load() async -> String? { id }
    public func save(_ newValue: String) async { id = newValue }
}

/// Streams bridge messages and posts replies.
///
/// The inbound side is Server-Sent Events over a long-lived HTTP connection. Built on
/// `URLSessionDataDelegate` rather than `URLSession.bytes(for:)`, which is iOS 15 — and the
/// delegate gives clearer control over cancellation and buffering anyway.
public final class BridgeClient: @unchecked Sendable {
    let bridgeURL: URL
    let clientID: String
    let session: URLSession
    let backoff: BackoffPolicy
    let lastEventIDStore: any LastEventIDStore

    /// Serialises access to the mutable connection state below.
    private let lock = NSLock()
    private var currentTask: URLSessionDataTask?
    private var isClosed = false

    public init(
        bridgeURL: URL,
        clientID: String,
        session: URLSession = .shared,
        backoff: BackoffPolicy = .default,
        lastEventIDStore: any LastEventIDStore = InMemoryLastEventIDStore()
    ) {
        self.bridgeURL = bridgeURL
        self.clientID = clientID
        self.session = session
        self.backoff = backoff
        self.lastEventIDStore = lastEventIDStore
    }

    // MARK: - Outbound

    /// How many times a send is retried before giving up.
    ///
    /// Bounded rather than open-ended: the caller is usually a user who just tapped approve or
    /// reject, and a reply that eventually arrives is better than one that never does — but
    /// only if the app can still tell them it failed.
    static let sendAttempts = 4

    /// Posts a sealed reply to `to`.
    ///
    /// `ttl` is how long the bridge should hold the message for a dApp that is not
    /// currently listening.
    ///
    /// Retries on rate limiting and server errors. Public bridges rate-limit pushes, and a
    /// wallet that gave up on the first 429 would drop the user's approval or rejection on the
    /// floor — the dApp would then wait forever for a reply that was generated and discarded.
    /// A 4xx other than 429 is not retried, because the request itself is wrong and repeating
    /// it changes nothing.
    public func send(
        _ sealedBase64: String,
        to recipientClientID: String,
        topic: String? = nil,
        ttl: Int = 300
    ) async throws {
        var components = URLComponents(
            url: bridgeURL.appendingPathComponent("message"),
            resolvingAgainstBaseURL: false
        )
        var query = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "to", value: recipientClientID),
            URLQueryItem(name: "ttl", value: String(ttl)),
        ]
        if let topic { query.append(URLQueryItem(name: "topic", value: topic)) }
        components?.queryItems = query

        guard let url = components?.url else {
            throw BridgeError.malformedURL(bridgeURL.absoluteString)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(sealedBase64.utf8)

        var lastError: Error?
        for attempt in 0..<Self.sendAttempts {
            if attempt > 0 {
                // `attempt`, not `attempt - 1`: `BackoffPolicy.delay(forAttempt: 0)` is zero, so
                // passing the previous index would make the first retry immediate. Retrying a
                // rate limiter with no pause burns an attempt and, on bridges that count every
                // request, extends the ban.
                let delay = retryDelay(forAttempt: attempt, lastError: lastError)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            try Task.checkCancellation()

            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw BridgeError.nonHTTPResponse
                }
                if (200..<300).contains(http.statusCode) { return }

                let error = BridgeError.sendFailed(
                    status: http.statusCode,
                    body: String(data: data, encoding: .utf8) ?? "",
                    retryAfter: Self.retryAfterSeconds(http)
                )
                guard error.isRetryable else { throw error }
                lastError = error
            } catch let error as BridgeError {
                guard error.isRetryable else { throw error }
                lastError = error
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // A transport failure — a dropped connection mid-post — is worth retrying;
                // the reply has not reached the bridge.
                lastError = error
            }
        }

        throw lastError ?? BridgeError.nonHTTPResponse
    }

    /// Backoff for the next send attempt, honouring `Retry-After` when the bridge sends one.
    private func retryDelay(forAttempt attempt: Int, lastError: Error?) -> TimeInterval {
        if case .some(BridgeError.sendFailed(_, _, .some(let retryAfter))) = lastError as? BridgeError {
            // The server said how long to wait. Capped, so a hostile or misconfigured bridge
            // cannot park a user's reply for minutes.
            return min(retryAfter, backoff.maxDelay)
        }
        return backoff.delay(forAttempt: attempt)
    }

    /// Parses `Retry-After`, which is seconds in every bridge implementation seen so far.
    static func retryAfterSeconds(_ response: HTTPURLResponse) -> TimeInterval? {
        guard let raw = response.value(forHTTPHeaderField: "Retry-After"),
              let seconds = TimeInterval(raw.trimmingCharacters(in: .whitespaces)),
              seconds >= 0
        else { return nil }
        return seconds
    }

    // MARK: - Inbound

    /// A stream of bridge messages that reconnects on its own.
    ///
    /// Reconnection is the normal case, not an error path: mobile connections drop
    /// constantly, and a wallet that stops listening after the first drop silently misses
    /// every later dApp request. Failures therefore feed the backoff rather than
    /// terminating the stream; only ``close()`` or task cancellation ends it.
    public func messages() -> AsyncThrowingStream<BridgeMessage, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { [weak self] in
                guard let self else { return }
                var attempt = 0

                while !Task.isCancelled, !self.checkClosed() {
                    let delay = self.backoff.delay(forAttempt: attempt)
                    if delay > 0 {
                        // Task.sleep(nanoseconds:) — sleep(for:) is iOS 16.
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    }
                    if Task.isCancelled || self.checkClosed() { break }

                    do {
                        try await self.streamOnce { message in
                            // Any successful delivery means the connection is healthy, so
                            // the backoff resets.
                            attempt = 0
                            if let id = message.eventID {
                                await self.lastEventIDStore.save(id)
                            }
                            continuation.yield(message)
                        }
                        // A clean end still warrants reconnecting; the bridge closes idle
                        // connections routinely.
                        attempt = min(attempt + 1, 16)
                    } catch is CancellationError {
                        break
                    } catch {
                        attempt = min(attempt + 1, 16)
                    }
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Runs one SSE connection until it ends.
    func streamOnce(onMessage: @escaping (BridgeMessage) async -> Void) async throws {
        var components = URLComponents(
            url: bridgeURL.appendingPathComponent("events"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "client_id", value: clientID)]
        guard let url = components?.url else {
            throw BridgeError.malformedURL(bridgeURL.absoluteString)
        }

        var request = URLRequest(url: url)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        // Resuming from the last id is what stops a reconnect replaying requests the user
        // already handled.
        if let lastID = await lastEventIDStore.load() {
            request.setValue(lastID, forHTTPHeaderField: "Last-Event-ID")
        }
        // No timeout: this connection is meant to stay open.
        request.timeoutInterval = .greatestFiniteMagnitude

        let delegate = SSEStreamDelegate(onMessage: onMessage)
        try await delegate.run(session: session, request: request) { task in
            self.setCurrentTask(task)
        }
    }

    /// Stops streaming and cancels any in-flight connection.
    public func close() {
        lock.lock()
        isClosed = true
        let task = currentTask
        currentTask = nil
        lock.unlock()
        task?.cancel()
    }

    private func checkClosed() -> Bool {
        lock.lock(); defer { lock.unlock() }
        return isClosed
    }

    private func setCurrentTask(_ task: URLSessionDataTask?) {
        lock.lock(); currentTask = task; lock.unlock()
    }
}

public enum BridgeError: Error, CustomStringConvertible {
    case malformedURL(String)
    case nonHTTPResponse
    /// `retryAfter` carries the server's `Retry-After` in seconds, when it sent one.
    case sendFailed(status: Int, body: String, retryAfter: TimeInterval? = nil)
    case streamFailed(status: Int)
    case transportFailure(Error)

    /// Whether repeating the request could plausibly succeed.
    ///
    /// Rate limiting and server errors are transient; any other 4xx means the request itself
    /// is wrong, and resending it just wastes the user's time before the same failure.
    public var isRetryable: Bool {
        switch self {
        case .sendFailed(let status, _, _):
            return status == 429 || (500..<600).contains(status)
        case .nonHTTPResponse, .transportFailure:
            return true
        case .malformedURL, .streamFailed:
            return false
        }
    }

    public var description: String {
        switch self {
        case .malformedURL(let s): return "Could not build a bridge URL from \"\(s)\""
        case .nonHTTPResponse: return "Bridge returned a non-HTTP response"
        case .sendFailed(let status, let body, let retryAfter):
            let suffix = retryAfter.map { ", retry after \($0)s" } ?? ""
            return "Bridge rejected the message (HTTP \(status)\(suffix)): \(body.prefix(200))"
        case .streamFailed(let status): return "Bridge stream failed with HTTP \(status)"
        case .transportFailure(let error): return "Bridge transport failure: \(error)"
        }
    }
}

/// Bridges `URLSessionDataDelegate` callbacks into the SSE parser.
///
/// A class because `URLSession` requires a delegate object, and the parser state has to
/// live across callbacks.
final class SSEStreamDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private var parser = SSEParser()
    private let onMessage: (BridgeMessage) async -> Void
    private var continuation: CheckedContinuation<Void, Error>?
    private let lock = NSLock()
    /// Queue of parsed events awaiting async delivery, so the delegate callback stays
    /// non-blocking.
    private var deliveryTask: Task<Void, Never>?

    init(onMessage: @escaping (BridgeMessage) async -> Void) {
        self.onMessage = onMessage
        super.init()
    }

    func run(
        session: URLSession,
        request: URLRequest,
        onStart: (URLSessionDataTask) -> Void
    ) async throws {
        // A dedicated session so this delegate receives the callbacks; the caller's session
        // may have no delegate of its own.
        let streamingSession = URLSession(
            configuration: session.configuration,
            delegate: self,
            delegateQueue: nil
        )
        let task = streamingSession.dataTask(with: request)
        onStart(task)

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                setContinuation(continuation)
                task.resume()
            }
        } onCancel: {
            task.cancel()
        }
    }

    private func setContinuation(_ c: CheckedContinuation<Void, Error>) {
        lock.lock(); continuation = c; lock.unlock()
    }

    private func finish(_ result: Result<Void, Error>) {
        lock.lock()
        let c = continuation
        continuation = nil
        lock.unlock()
        switch result {
        case .success: c?.resume()
        case .failure(let error): c?.resume(throwing: error)
        }
    }

    // MARK: - URLSessionDataDelegate

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let http = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            finish(.failure(BridgeError.nonHTTPResponse))
            return
        }
        guard (200..<300).contains(http.statusCode) else {
            completionHandler(.cancel)
            finish(.failure(BridgeError.streamFailed(status: http.statusCode)))
            return
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // Parsing happens synchronously here — it is cheap and must not reorder — while
        // delivery is handed to a task so the callback returns promptly.
        let events: [SSEEvent]
        lock.lock()
        do {
            events = try parser.consume(data)
        } catch {
            lock.unlock()
            dataTask.cancel()
            finish(.failure(error))
            return
        }
        lock.unlock()

        guard !events.isEmpty else { return }
        let messages = events.compactMap(Self.bridgeMessage(from:))
        guard !messages.isEmpty else { return }

        let deliver = onMessage
        Task {
            for message in messages { await deliver(message) }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            // A cancellation is a normal shutdown, not a failure.
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                finish(.success(()))
            } else {
                finish(.failure(BridgeError.transportFailure(error)))
            }
        } else {
            finish(.success(()))
        }
    }

    /// Decodes a bridge frame's JSON payload.
    ///
    /// Frames the bridge sends for its own purposes — heartbeats, or anything without a
    /// `from`/`message` pair — are skipped rather than treated as errors.
    static func bridgeMessage(from event: SSEEvent) -> BridgeMessage? {
        struct Frame: Decodable {
            let from: String
            let message: String
        }
        guard let data = event.data.data(using: .utf8),
              let frame = try? JSONDecoder().decode(Frame.self, from: data)
        else { return nil }
        return BridgeMessage(from: frame.from, message: frame.message, eventID: event.id)
    }
}
