import Foundation
import SwiftSignalKit
import TelegramCore
import WalletEngineFFI

let walletStreamingMaximumFrameBytes = 4 * 1024 * 1024

enum WalletStreamingError: Error, Equatable {
    case invalidURL
    case expiredURL
    case notConnected
    case invalidResponse
    case frameTooLarge
}

final class WalletStreamingLogger: @unchecked Sendable {
    private let log: (String) -> Void

    init(_ log: @escaping (String) -> Void) {
        self.log = log
    }

    func callAsFunction(_ message: String) {
        self.log(message)
    }
}

private func walletStreamingErrorFields(_ error: Error) -> String {
    let nsError = error as NSError
    return "error_type=\(String(reflecting: type(of: error))) error_domain=\(nsError.domain) error_code=\(nsError.code)"
}

private final class WalletStreamingEngineURLSource: @unchecked Sendable {
    let engine: TelegramEngine

    init(engine: TelegramEngine) {
        self.engine = engine
    }

    func fetch() async throws -> WalletStreamingUrl {
        try await WalletSignalRequestContext<WalletStreamingUrl>().run(
            self.engine.wallet.getStreamingUrl()
        )
    }
}

actor WalletStreamingURLProvider {
    typealias Fetch = @Sendable () async throws -> WalletStreamingUrl
    typealias Now = @Sendable () -> Int64

    private struct CachedValue {
        let url: URL
        let expires: Int64
    }

    private let fetch: Fetch
    private let now: Now
    private let log: WalletStreamingLogger
    private var cached: CachedValue?

    init(
        fetch: @escaping Fetch,
        now: @escaping Now = { Int64(Date().timeIntervalSince1970) },
        log: WalletStreamingLogger = WalletStreamingLogger { _ in }
    ) {
        self.fetch = fetch
        self.now = now
        self.log = log
    }

    init(engine: TelegramEngine, log: WalletStreamingLogger) {
        let source = WalletStreamingEngineURLSource(engine: engine)
        self.fetch = { try await source.fetch() }
        self.now = { Int64(Date().timeIntervalSince1970) }
        self.log = log
    }

    func url(forceRefresh: Bool = false) async throws -> URL {
        let currentTimestamp = self.now()
        if !forceRefresh, let cached = self.cached, cached.expires > currentTimestamp + 30 {
            self.log("event=wallet_stream_url_cache_hit expires_in=\(cached.expires - currentTimestamp)")
            return cached.url
        }

        do {
            self.log("event=wallet_stream_url_fetch_start")
            let value = try await self.fetch()
            try Task.checkCancellation()
            let parsed = try Self.parse(value, now: self.now())
            self.cached = parsed
            self.log("event=wallet_stream_url_fetch_success expires_in=\(parsed.expires - self.now())")
            return parsed.url
        } catch is CancellationError {
            self.log("event=wallet_stream_url_fetch_cancelled")
            throw CancellationError()
        } catch {
            try Task.checkCancellation()
            let fallbackTimestamp = self.now()
            if let cached = self.cached, cached.expires > fallbackTimestamp {
                self.log("event=wallet_stream_url_fetch_failed_using_cache expires_in=\(cached.expires - fallbackTimestamp) \(walletStreamingErrorFields(error))")
                return cached.url
            }
            self.log("event=wallet_stream_url_fetch_failed \(walletStreamingErrorFields(error))")
            throw error
        }
    }

    private static func parse(_ value: WalletStreamingUrl, now: Int64) throws -> CachedValue {
        let expires = Int64(value.expires)
        guard expires > now,
              let components = URLComponents(string: value.url),
              components.scheme?.lowercased() == "https",
              components.host?.isEmpty == false,
              components.user == nil,
              components.password == nil,
              components.fragment == nil,
              let url = components.url else {
            if expires <= now {
                throw WalletStreamingError.expiredURL
            }
            throw WalletStreamingError.invalidURL
        }
        return CachedValue(url: url, expires: expires)
    }
}

protocol WalletStreamingTransport: Sendable {
    func connect(subscription: Data) async throws
    func receive() async throws -> Data
    func close() async
}

protocol WalletStreamingTransportFactory: Sendable {
    func makeTransport() -> any WalletStreamingTransport
}

private final class WalletStreamingDataTask: @unchecked Sendable {
    private let lock = NSLock()
    private var task: URLSessionDataTask?
    private var session: URLSession?
    private var cancelled = false

    func set(task: URLSessionDataTask, session: URLSession) {
        self.lock.lock()
        if self.cancelled {
            self.lock.unlock()
            task.cancel()
            session.invalidateAndCancel()
        } else {
            self.task = task
            self.session = session
            self.lock.unlock()
        }
    }

    func cancel() {
        self.lock.lock()
        self.cancelled = true
        let task = self.task
        let session = self.session
        self.task = nil
        self.session = nil
        self.lock.unlock()
        task?.cancel()
        session?.invalidateAndCancel()
    }
}

private final class WalletStreamingSessionDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let expectedURL: URL
    private let continuation: AsyncThrowingStream<Data, Error>.Continuation
    private let log: WalletStreamingLogger
    private var eventBytes = 0
    private var previousWasLineFeed = false
    private var finished = false

    init(
        expectedURL: URL,
        continuation: AsyncThrowingStream<Data, Error>.Continuation,
        log: WalletStreamingLogger
    ) {
        self.expectedURL = expectedURL
        self.continuation = continuation
        self.log = log
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        self.log("event=wallet_stream_redirect_rejected status_code=\(response.statusCode)")
        completionHandler(nil)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let response = response as? HTTPURLResponse,
              response.url == self.expectedURL else {
            self.log("event=wallet_stream_response_rejected")
            self.finish(throwing: WalletStreamingError.invalidResponse)
            completionHandler(.cancel)
            return
        }
        let isEventStream = response.value(forHTTPHeaderField: "Content-Type")?
            .split(separator: ";", maxSplits: 1)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() == "text/event-stream"
        guard (200 ..< 300).contains(response.statusCode), isEventStream else {
            self.log("event=wallet_stream_response_rejected status_code=\(response.statusCode) event_stream=\(isEventStream ? 1 : 0)")
            self.finish(throwing: WalletStreamingError.invalidResponse)
            completionHandler(.cancel)
            return
        }
        self.log("event=wallet_stream_response_accepted status_code=\(response.statusCode)")
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard !self.finished else { return }
        for byte in data {
            self.eventBytes += 1
            if byte == 0x0a {
                if self.previousWasLineFeed {
                    self.eventBytes = 0
                }
                self.previousWasLineFeed = true
            } else if byte != 0x0d {
                self.previousWasLineFeed = false
            }
            if self.eventBytes > walletStreamingMaximumFrameBytes {
                self.log("event=wallet_stream_event_too_large")
                self.finish(throwing: WalletStreamingError.frameTooLarge)
                dataTask.cancel()
                return
            }
        }
        self.continuation.yield(data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard !self.finished else { return }
        if let error {
            self.log("event=wallet_stream_request_completed \(walletStreamingErrorFields(error))")
            self.finish(throwing: error)
        } else {
            self.log("event=wallet_stream_request_completed")
            self.finish()
        }
    }

    private func finish(throwing error: Error? = nil) {
        guard !self.finished else { return }
        self.finished = true
        if let error {
            self.continuation.finish(throwing: error)
        } else {
            self.continuation.finish()
        }
    }
}

final class WalletURLSessionStreamingTransportFactory: WalletStreamingTransportFactory, @unchecked Sendable {
    private let provider: WalletStreamingURLProvider
    private let log: WalletStreamingLogger

    init(provider: WalletStreamingURLProvider, log: WalletStreamingLogger) {
        self.provider = provider
        self.log = log
    }

    func makeTransport() -> any WalletStreamingTransport {
        WalletURLSessionStreamingTransport(provider: self.provider, log: self.log)
    }
}

actor WalletURLSessionStreamingTransport: WalletStreamingTransport {
    private let provider: WalletStreamingURLProvider
    private let log: WalletStreamingLogger
    private var cancellation: WalletStreamingDataTask?
    private var iterator: AsyncThrowingStream<Data, Error>.Iterator?
    private var connectionId: UUID?

    init(provider: WalletStreamingURLProvider, log: WalletStreamingLogger) {
        self.provider = provider
        self.log = log
    }

    func connect(subscription: Data) async throws {
        guard subscription.count <= walletStreamingMaximumFrameBytes else {
            throw WalletStreamingError.frameTooLarge
        }
        // Every SSE reconnect asks Telegram for a current signed endpoint. If that
        // request fails, the provider can still fall back to an unexpired cached URL.
        let url = try await self.provider.url(forceRefresh: true)
        try Task.checkCancellation()

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.httpBody = subscription

        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 24 * 60 * 60

        let cancellation = WalletStreamingDataTask()
        let log = self.log
        let stream = AsyncThrowingStream<Data, Error> { continuation in
            let value = WalletStreamingSessionDelegate(
                expectedURL: url,
                continuation: continuation,
                log: log
            )
            let session = URLSession(configuration: configuration, delegate: value, delegateQueue: nil)
            let task = session.dataTask(with: request)
            cancellation.set(task: task, session: session)
            continuation.onTermination = { @Sendable _ in
                cancellation.cancel()
            }
            task.resume()
        }
        let connectionId = UUID()
        self.connectionId = connectionId
        self.cancellation = cancellation
        self.iterator = stream.makeAsyncIterator()
    }

    func receive() async throws -> Data {
        guard let connectionId = self.connectionId, var iterator = self.iterator else {
            throw WalletStreamingError.notConnected
        }
        let value = try await iterator.next()
        guard self.connectionId == connectionId else {
            throw CancellationError()
        }
        self.iterator = iterator
        guard let value else {
            throw WalletStreamingError.notConnected
        }
        return value
    }

    func close() async {
        self.connectionId = nil
        self.iterator = nil
        self.cancellation?.cancel()
        self.cancellation = nil
    }
}

enum WalletStreamingParsedEvent: Sendable, Equatable {
    case subscribed
    case changed
}

enum WalletStreamingDemand {
    static func isActive(
        foreground: Bool,
        accountIsCurrent: Bool,
        networkAvailable: Bool,
        subscriberCount: Int,
        hasPendingTransfer: Bool
    ) -> Bool {
        foreground
            && accountIsCurrent
            && networkAvailable
            && (subscriberCount > 0 || hasPendingTransfer)
    }

    static func acceptsEvent(
        generation: UInt64,
        rawAddress: String,
        currentGeneration: UInt64,
        currentRawAddress: String?,
        isActive: Bool
    ) -> Bool {
        isActive && generation == currentGeneration && rawAddress == currentRawAddress
    }
}

struct WalletSynchronizationRequestGate {
    private(set) var isRunning = false
    private(set) var hasQueuedRequest = false

    mutating func beginOrQueue() -> Bool {
        if self.isRunning {
            self.hasQueuedRequest = true
            return false
        }
        self.isRunning = true
        return true
    }

    mutating func complete() -> Bool {
        self.isRunning = false
        let shouldRestart = self.hasQueuedRequest
        self.hasQueuedRequest = false
        return shouldRestart
    }

    mutating func cancel() {
        self.isRunning = false
        self.hasQueuedRequest = false
    }
}

struct WalletStreamingRefreshGate {
    private(set) var isScheduled = false

    mutating func schedule() -> Bool {
        guard !self.isScheduled else { return false }
        self.isScheduled = true
        return true
    }

    mutating func consume() {
        self.isScheduled = false
    }
}

struct WalletStreamingSSEParser {
    private static let dataField = Data("data".utf8)

    private var buffer = Data()
    private var dataLines: [Data] = []
    private var dataBytes = 0

    mutating func append(_ chunk: Data) throws -> [Data] {
        self.buffer.append(chunk)
        var events: [Data] = []
        while let newlineIndex = self.buffer.firstIndex(of: 0x0a) {
            var line = Data(self.buffer[self.buffer.startIndex ..< newlineIndex])
            self.buffer.removeSubrange(self.buffer.startIndex ... newlineIndex)
            if line.last == 0x0d {
                line.removeLast()
            }
            if let event = try self.consume(line: line) {
                events.append(event)
            }
        }
        guard self.dataBytes + self.buffer.count <= walletStreamingMaximumFrameBytes else {
            throw WalletStreamingError.frameTooLarge
        }
        return events
    }

    private mutating func consume(line: Data) throws -> Data? {
        if line.isEmpty {
            return self.finishEvent()
        }
        guard line.first != 0x3a, let colonIndex = line.firstIndex(of: 0x3a) else {
            return nil
        }
        guard Data(line[line.startIndex ..< colonIndex]) == Self.dataField else {
            return nil
        }
        var valueStart = line.index(after: colonIndex)
        if valueStart < line.endIndex, line[valueStart] == 0x20 {
            valueStart = line.index(after: valueStart)
        }
        let value = Data(line[valueStart ..< line.endIndex])
        let separatorBytes = self.dataLines.isEmpty ? 0 : 1
        guard self.dataBytes + separatorBytes + value.count <= walletStreamingMaximumFrameBytes else {
            throw WalletStreamingError.frameTooLarge
        }
        self.dataBytes += separatorBytes + value.count
        self.dataLines.append(value)
        return nil
    }

    private mutating func finishEvent() -> Data? {
        guard !self.dataLines.isEmpty else {
            self.dataBytes = 0
            return nil
        }
        var event = Data()
        event.reserveCapacity(self.dataBytes)
        for index in self.dataLines.indices {
            if index != self.dataLines.startIndex {
                event.append(0x0a)
            }
            event.append(self.dataLines[index])
        }
        self.dataLines.removeAll(keepingCapacity: true)
        self.dataBytes = 0
        return event
    }
}

enum WalletStreamingEventParser {
    private struct Envelope: Decodable {
        let type: String?
        let status: String?
    }

    private struct AccountStateChange: Decodable {
        let account: String
    }

    private struct Transaction: Decodable {
        let account: String
    }

    private struct TransactionsChange: Decodable {
        let transactions: [Transaction]
    }

    private struct TraceInvalidated: Decodable {
        let traceExternalHashNorm: String

        enum CodingKeys: String, CodingKey {
            case traceExternalHashNorm = "trace_external_hash_norm"
        }
    }

    static func parse(_ data: Data, expectedRawAddress: String) -> WalletStreamingParsedEvent? {
        guard data.count <= walletStreamingMaximumFrameBytes else {
            return nil
        }
        let decoder = JSONDecoder()
        guard let envelope = try? decoder.decode(Envelope.self, from: data) else {
            return nil
        }
        if envelope.status == "subscribed" {
            return .subscribed
        }
        let expected = expectedRawAddress.lowercased()
        switch envelope.type {
        case "account_state_change":
            guard let value = try? decoder.decode(AccountStateChange.self, from: data),
                  value.account.lowercased() == expected else {
                return nil
            }
            return .changed
        case "transactions":
            guard let value = try? decoder.decode(TransactionsChange.self, from: data),
                  value.transactions.contains(where: { $0.account.lowercased() == expected }) else {
                return nil
            }
            return .changed
        case "trace_invalidated":
            guard let value = try? decoder.decode(TraceInvalidated.self, from: data),
                  !value.traceExternalHashNorm.isEmpty else {
                return nil
            }
            return .changed
        default:
            return nil
        }
    }

    static func diagnosticLabel(_ data: Data) -> String {
        guard data.count <= walletStreamingMaximumFrameBytes,
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else {
            return "malformed"
        }
        if let status = envelope.status {
            switch status {
            case "subscribed": return "subscribed"
            case "pong": return "pong"
            default: return "other_status"
            }
        }
        switch envelope.type {
        case "account_state_change": return "account_state_change_unmatched"
        case "transactions": return "transactions_unmatched"
        case "trace_invalidated": return "trace_invalidated_invalid"
        case .some: return "unknown_type"
        case nil: return "missing_type"
        }
    }
}

private struct WalletStreamingSubscribeRequest: Encodable {
    let types = ["account_state_change", "transactions"]
    let addresses: [String]
    let minFinality = "pending"
    let includeAddressBook = false
    let includeMetadata = false

    enum CodingKeys: String, CodingKey {
        case types
        case addresses
        case minFinality = "min_finality"
        case includeAddressBook = "include_address_book"
        case includeMetadata = "include_metadata"
    }
}

actor WalletToncenterStreamingClient {
    struct Configuration: Sendable {
        let initialBackoff: TimeInterval
        let maximumBackoff: TimeInterval

        init(initialBackoff: TimeInterval = 1, maximumBackoff: TimeInterval = 60) {
            self.initialBackoff = initialBackoff
            self.maximumBackoff = maximumBackoff
        }
    }

    typealias Sleep = @Sendable (UInt64) async throws -> Void
    typealias Jitter = @Sendable (ClosedRange<Double>) -> Double

    private let factory: any WalletStreamingTransportFactory
    private let configuration: Configuration
    private let sleep: Sleep
    private let jitter: Jitter
    private let log: WalletStreamingLogger
    private var transport: (any WalletStreamingTransport)?
    private var pump: Task<Void, Never>?
    private var continuation: AsyncStream<WalletStreamingParsedEvent>.Continuation?
    private var connectionSubscribed = false

    init(
        factory: any WalletStreamingTransportFactory,
        configuration: Configuration = Configuration(),
        sleep: @escaping Sleep = { try await Task.sleep(nanoseconds: $0) },
        jitter: @escaping Jitter = { Double.random(in: $0) },
        log: WalletStreamingLogger = WalletStreamingLogger { _ in }
    ) {
        self.factory = factory
        self.configuration = configuration
        self.sleep = sleep
        self.jitter = jitter
        self.log = log
    }

    func events(rawAddress: String) -> AsyncStream<WalletStreamingParsedEvent> {
        if self.pump != nil {
            return AsyncStream { $0.finish() }
        }
        var continuation: AsyncStream<WalletStreamingParsedEvent>.Continuation!
        let stream = AsyncStream<WalletStreamingParsedEvent>(bufferingPolicy: .bufferingNewest(1)) {
            continuation = $0
        }
        self.continuation = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.stop() }
        }
        self.pump = Task { [weak self] in
            await self?.run(rawAddress: rawAddress)
        }
        return stream
    }

    func stop() async {
        self.pump?.cancel()
        self.pump = nil
        await self.transport?.close()
        self.transport = nil
        self.continuation?.finish()
        self.continuation = nil
    }

    private func run(rawAddress: String) async {
        var attempt = 0
        while !Task.isCancelled {
            if attempt > 0 {
                let exponential = min(
                    self.configuration.initialBackoff * pow(2, Double(attempt - 1)),
                    self.configuration.maximumBackoff
                )
                let delay = min(
                    max(exponential * self.jitter(0.85 ... 1.15), self.configuration.initialBackoff),
                    self.configuration.maximumBackoff
                )
                do {
                    self.log("event=wallet_stream_reconnect_wait attempt=\(attempt) delay_ms=\(Int(delay * 1000))")
                    try await self.sleep(UInt64(max(0, delay) * 1_000_000_000))
                } catch {
                    self.log("event=wallet_stream_reconnect_cancelled")
                    return
                }
            }
            guard !Task.isCancelled else { return }

            self.connectionSubscribed = false
            do {
                self.log("event=wallet_stream_connect_start attempt=\(attempt)")
                try await self.runConnection(rawAddress: rawAddress)
            } catch is CancellationError {
                if Task.isCancelled {
                    self.log("event=wallet_stream_connection_cancelled")
                    return
                }
            } catch {
                self.log("event=wallet_stream_connection_failed attempt=\(attempt) subscribed=\(self.connectionSubscribed ? 1 : 0) \(walletStreamingErrorFields(error))")
            }
            await self.transport?.close()
            self.transport = nil
            attempt = self.connectionSubscribed ? 1 : min(attempt + 1, 16)
        }
    }

    private func runConnection(rawAddress: String) async throws {
        let transport = self.factory.makeTransport()
        self.transport = transport
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let subscription = try encoder.encode(WalletStreamingSubscribeRequest(addresses: [rawAddress]))
        try await transport.connect(subscription: subscription)
        self.log("event=wallet_stream_request_started")
        var parser = WalletStreamingSSEParser()

        while !Task.isCancelled {
            let chunk = try await transport.receive()
            for data in try parser.append(chunk) {
                guard let event = WalletStreamingEventParser.parse(data, expectedRawAddress: rawAddress) else {
                    let label = WalletStreamingEventParser.diagnosticLabel(data)
                    self.log("event=wallet_stream_event_ignored kind=\(label)")
                    continue
                }
                if event == .subscribed {
                    self.connectionSubscribed = true
                    self.log("event=wallet_stream_subscribed")
                } else {
                    self.log("event=wallet_stream_change_received")
                }
                self.continuation?.yield(event)
            }
        }
        throw CancellationError()
    }
}

extension WalletContext {
    func evaluateStreamingDemand() {
        assert(Queue.mainQueue().isCurrent())
        let demandIsActive = WalletStreamingDemand.isActive(
            foreground: self.isApplicationInForeground,
            accountIsCurrent: self.isAccountCurrent,
            networkAvailable: self.isNetworkAvailable,
            subscriberCount: self.stateSubscriberCount,
            hasPendingTransfer: !self.currentState.pendingTransfers.isEmpty
        )
        guard demandIsActive else {
            if self.streamingTask != nil || self.streamingClient != nil {
                self.streamingLog("event=wallet_stream_demand_inactive foreground=\(self.isApplicationInForeground ? 1 : 0) account_current=\(self.isAccountCurrent ? 1 : 0) network_available=\(self.isNetworkAvailable ? 1 : 0) has_subscribers=\(self.stateSubscriberCount > 0 ? 1 : 0) has_pending_transfer=\(self.currentState.pendingTransfers.isEmpty ? 0 : 1)")
            }
            self.stopStreaming()
            return
        }
        guard case let .wallet(info) = self.currentState.phase else {
            if self.streamingTask != nil || self.streamingClient != nil {
                self.streamingLog("event=wallet_stream_wallet_inactive")
            }
            self.stopStreaming()
            return
        }
        guard let rawAddress = try? convertTonAddress(value: info.address, format: .raw) else {
            self.streamingLog("event=wallet_stream_address_conversion_failed")
            self.stopStreaming()
            return
        }

        let generation = self.activationGeneration
        if self.streamingTask != nil,
           self.streamingAddress == rawAddress,
           self.streamingGeneration == generation {
            return
        }

        self.stopStreaming()
        self.streamingLog("event=wallet_stream_start generation=\(generation)")
        let client = WalletToncenterStreamingClient(factory: self.streamingTransportFactory, log: self.streamingLog)
        self.streamingClient = client
        self.streamingAddress = rawAddress
        self.streamingGeneration = generation
        self.streamingTask = Task { @MainActor [weak self] in
            let events = await client.events(rawAddress: rawAddress)
            for await event in events {
                guard let self,
                      !Task.isCancelled,
                      self.streamingGeneration == generation,
                      WalletStreamingDemand.acceptsEvent(
                        generation: generation,
                        rawAddress: rawAddress,
                        currentGeneration: self.activationGeneration,
                        currentRawAddress: self.streamingAddress,
                        isActive: WalletStreamingDemand.isActive(
                            foreground: self.isApplicationInForeground,
                            accountIsCurrent: self.isAccountCurrent,
                            networkAvailable: self.isNetworkAvailable,
                            subscriberCount: self.stateSubscriberCount,
                            hasPendingTransfer: !self.currentState.pendingTransfers.isEmpty
                        )
                      ) else {
                    break
                }
                switch event {
                case .subscribed, .changed:
                    self.scheduleStreamingRefresh(generation: generation, rawAddress: rawAddress)
                }
            }
            await client.stop()
            guard let self else { return }
            if self.streamingClient === client {
                self.streamingClient = nil
                self.streamingTask = nil
                self.streamingAddress = nil
                self.streamingGeneration = nil
            }
        }
    }

    func stopStreaming() {
        assert(Queue.mainQueue().isCurrent())
        if self.streamingTask != nil || self.streamingClient != nil {
            self.streamingLog("event=wallet_stream_stop")
        }
        self.streamingTask?.cancel()
        self.streamingTask = nil
        self.streamingRefreshTask?.cancel()
        self.streamingRefreshTask = nil
        self.streamingRefreshTaskId = nil
        self.streamingRefreshGate.consume()
        self.streamingAddress = nil
        self.streamingGeneration = nil
        let client = self.streamingClient
        self.streamingClient = nil
        if let client {
            Task { await client.stop() }
        }
    }

    private func scheduleStreamingRefresh(generation: UInt64, rawAddress: String) {
        guard self.streamingRefreshTask == nil,
              self.activationGeneration == generation,
              self.streamingGeneration == generation,
              self.streamingAddress == rawAddress else {
            return
        }
        guard self.streamingRefreshGate.schedule() else { return }
        self.streamingLog("event=wallet_stream_refresh_scheduled")
        let taskId = UUID()
        self.streamingRefreshTaskId = taskId
        self.streamingRefreshTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            } catch {
                return
            }
            guard let self,
                  self.streamingRefreshTaskId == taskId,
                  self.activationGeneration == generation,
                  self.streamingGeneration == generation,
                  self.streamingAddress == rawAddress,
                  self.canUseNetworkRuntime,
                  self.stateSubscriberCount > 0 || !self.currentState.pendingTransfers.isEmpty else {
                return
            }
            self.streamingRefreshTask = nil
            self.streamingRefreshTaskId = nil
            self.streamingRefreshGate.consume()
            self.streamingLog("event=wallet_stream_refresh_requested")
            self.requestSynchronization(force: true)
        }
    }
}
