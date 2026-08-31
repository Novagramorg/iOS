import Foundation
import SwiftSignalKit
import TelegramCore
import WalletEngineFFI

let walletStreamingMaximumFrameBytes = 4 * 1024 * 1024

enum WalletStreamingError: Error, Equatable {
    case invalidURL
    case expiredURL
    case notConnected
    case unsupportedFrame
    case frameTooLarge
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
    private var cached: CachedValue?

    init(
        fetch: @escaping Fetch,
        now: @escaping Now = { Int64(Date().timeIntervalSince1970) }
    ) {
        self.fetch = fetch
        self.now = now
    }

    init(engine: TelegramEngine) {
        let source = WalletStreamingEngineURLSource(engine: engine)
        self.fetch = { try await source.fetch() }
        self.now = { Int64(Date().timeIntervalSince1970) }
    }

    func url() async throws -> URL {
        let currentTimestamp = self.now()
        if let cached = self.cached, cached.expires > currentTimestamp + 30 {
            return cached.url
        }

        do {
            let value = try await self.fetch()
            try Task.checkCancellation()
            let parsed = try Self.parse(value, now: self.now())
            self.cached = parsed
            return parsed.url
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try Task.checkCancellation()
            let fallbackTimestamp = self.now()
            if let cached = self.cached, cached.expires > fallbackTimestamp {
                return cached.url
            }
            throw error
        }
    }

    private static func parse(_ value: WalletStreamingUrl, now: Int64) throws -> CachedValue {
        let expires = Int64(value.expires)
        guard expires > now,
              let components = URLComponents(string: value.url),
              components.scheme?.lowercased() == "wss",
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

enum WalletStreamingFrame: Sendable, Equatable {
    case text(String)
    case data(Data)
}

protocol WalletStreamingSocket: Sendable {
    func connect() async throws
    func receive() async throws -> WalletStreamingFrame
    func send(_ text: String) async throws
    func close() async
}

protocol WalletStreamingSocketFactory: Sendable {
    func makeSocket() -> any WalletStreamingSocket
}

final class WalletStreamingSessionDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

final class WalletURLSessionStreamingSocketFactory: WalletStreamingSocketFactory, @unchecked Sendable {
    private let provider: WalletStreamingURLProvider
    private let delegate: WalletStreamingSessionDelegate
    private let session: URLSession

    init(provider: WalletStreamingURLProvider) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 30
        let delegate = WalletStreamingSessionDelegate()
        self.provider = provider
        self.delegate = delegate
        self.session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }

    deinit {
        self.session.invalidateAndCancel()
    }

    func makeSocket() -> any WalletStreamingSocket {
        WalletURLSessionStreamingSocket(provider: self.provider, session: self.session)
    }
}

actor WalletURLSessionStreamingSocket: WalletStreamingSocket {
    private let provider: WalletStreamingURLProvider
    private let session: URLSession
    private var task: URLSessionWebSocketTask?

    init(provider: WalletStreamingURLProvider, session: URLSession) {
        self.provider = provider
        self.session = session
    }

    func connect() async throws {
        let url = try await self.provider.url()
        try Task.checkCancellation()
        let task = self.session.webSocketTask(with: url)
        self.task = task
        task.resume()
    }

    func receive() async throws -> WalletStreamingFrame {
        guard let task = self.task else {
            throw WalletStreamingError.notConnected
        }
        switch try await task.receive() {
        case let .string(value):
            guard value.lengthOfBytes(using: .utf8) <= walletStreamingMaximumFrameBytes else {
                throw WalletStreamingError.frameTooLarge
            }
            return .text(value)
        case let .data(value):
            guard value.count <= walletStreamingMaximumFrameBytes else {
                throw WalletStreamingError.frameTooLarge
            }
            return .data(value)
        @unknown default:
            throw WalletStreamingError.unsupportedFrame
        }
    }

    func send(_ text: String) async throws {
        guard let task = self.task else {
            throw WalletStreamingError.notConnected
        }
        try await task.send(.string(text))
    }

    func close() async {
        self.task?.cancel(with: .goingAway, reason: nil)
        self.task = nil
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

    static func parse(_ frame: WalletStreamingFrame, expectedRawAddress: String) -> WalletStreamingParsedEvent? {
        let data: Data
        switch frame {
        case let .text(value):
            guard value.lengthOfBytes(using: .utf8) <= walletStreamingMaximumFrameBytes,
                  let value = value.data(using: .utf8) else {
                return nil
            }
            data = value
        case let .data(value):
            guard value.count <= walletStreamingMaximumFrameBytes else {
                return nil
            }
            data = value
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
}

private struct WalletStreamingSubscribeRequest: Encodable {
    let operation = "subscribe"
    let id: String
    let types = ["account_state_change", "transactions"]
    let addresses: [String]
    let minFinality = "pending"
    let includeMetadata = false

    enum CodingKeys: String, CodingKey {
        case operation
        case id
        case types
        case addresses
        case minFinality = "min_finality"
        case includeMetadata = "include_metadata"
    }
}

private struct WalletStreamingPingRequest: Encodable {
    let operation = "ping"
    let id: String
}

actor WalletToncenterStreamingClient {
    struct Configuration: Sendable {
        let pingInterval: TimeInterval
        let initialBackoff: TimeInterval
        let maximumBackoff: TimeInterval

        init(pingInterval: TimeInterval = 15, initialBackoff: TimeInterval = 1, maximumBackoff: TimeInterval = 60) {
            self.pingInterval = pingInterval
            self.initialBackoff = initialBackoff
            self.maximumBackoff = maximumBackoff
        }
    }

    typealias Sleep = @Sendable (UInt64) async throws -> Void
    typealias Jitter = @Sendable (ClosedRange<Double>) -> Double

    private let factory: any WalletStreamingSocketFactory
    private let configuration: Configuration
    private let sleep: Sleep
    private let jitter: Jitter
    private var socket: (any WalletStreamingSocket)?
    private var pump: Task<Void, Never>?
    private var pinger: Task<Void, Never>?
    private var continuation: AsyncStream<WalletStreamingParsedEvent>.Continuation?
    private var requestCounter = 0
    private var connectionSubscribed = false

    init(
        factory: any WalletStreamingSocketFactory,
        configuration: Configuration = Configuration(),
        sleep: @escaping Sleep = { try await Task.sleep(nanoseconds: $0) },
        jitter: @escaping Jitter = { Double.random(in: $0) }
    ) {
        self.factory = factory
        self.configuration = configuration
        self.sleep = sleep
        self.jitter = jitter
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
        self.pinger?.cancel()
        self.pump = nil
        self.pinger = nil
        await self.socket?.close()
        self.socket = nil
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
                    try await self.sleep(UInt64(max(0, delay) * 1_000_000_000))
                } catch {
                    return
                }
            }
            guard !Task.isCancelled else { return }

            self.connectionSubscribed = false
            do {
                try await self.runConnection(rawAddress: rawAddress)
            } catch is CancellationError {
                if Task.isCancelled {
                    return
                }
            } catch {
            }
            self.pinger?.cancel()
            self.pinger = nil
            await self.socket?.close()
            self.socket = nil
            attempt = self.connectionSubscribed ? 1 : min(attempt + 1, 16)
        }
    }

    private func runConnection(rawAddress: String) async throws {
        let socket = self.factory.makeSocket()
        self.socket = socket
        try await socket.connect()
        try await self.sendSubscription(rawAddress: rawAddress, over: socket)
        self.startPinging(over: socket)

        while !Task.isCancelled {
            let frame = try await socket.receive()
            guard let event = WalletStreamingEventParser.parse(frame, expectedRawAddress: rawAddress) else {
                continue
            }
            if event == .subscribed {
                self.connectionSubscribed = true
            }
            self.continuation?.yield(event)
        }
        throw CancellationError()
    }

    private func sendSubscription(rawAddress: String, over socket: any WalletStreamingSocket) async throws {
        self.requestCounter += 1
        let value = WalletStreamingSubscribeRequest(id: "subscribe-\(self.requestCounter)", addresses: [rawAddress])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        try await socket.send(String(decoding: data, as: UTF8.self))
    }

    private func startPinging(over socket: any WalletStreamingSocket) {
        self.pinger?.cancel()
        let interval = self.configuration.pingInterval
        let sleep = self.sleep
        self.pinger = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await sleep(UInt64(interval * 1_000_000_000))
                    guard let self, !Task.isCancelled else { return }
                    try await self.sendPing(over: socket)
                } catch {
                    await socket.close()
                    return
                }
            }
        }
    }

    private func sendPing(over socket: any WalletStreamingSocket) async throws {
        self.requestCounter += 1
        let value = WalletStreamingPingRequest(id: "ping-\(self.requestCounter)")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        try await socket.send(String(decoding: data, as: UTF8.self))
    }
}

extension WalletContext {
    func evaluateStreamingDemand() {
        assert(Queue.mainQueue().isCurrent())
        guard WalletStreamingDemand.isActive(
            foreground: self.isApplicationInForeground,
            accountIsCurrent: self.isAccountCurrent,
            networkAvailable: self.isNetworkAvailable,
            subscriberCount: self.stateSubscriberCount,
            hasPendingTransfer: !self.currentState.pendingTransfers.isEmpty
        ),
              case let .wallet(info) = self.currentState.phase,
              let rawAddress = try? convertTonAddress(value: info.address, format: .raw) else {
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
        let client = WalletToncenterStreamingClient(factory: self.streamingSocketFactory)
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
            self.requestSynchronization(force: true)
        }
    }
}
