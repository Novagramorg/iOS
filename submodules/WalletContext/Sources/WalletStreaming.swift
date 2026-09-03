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
                self.log("event=wallet_stream_url_fetch_failed_using_cache expires_in=\(cached.expires - fallbackTimestamp) \(walletContextErrorFields(error))")
                return cached.url
            }
            self.log("event=wallet_stream_url_fetch_failed \(walletContextErrorFields(error))")
            throw error
        }
    }

    private static func parse(_ value: WalletStreamingUrl, now: Int64) throws -> CachedValue {
        let expires = Int64(value.expires)
        guard expires > now,
              var components = URLComponents(string: value.url),
              components.host?.isEmpty == false,
              components.user == nil,
              components.password == nil,
              components.fragment == nil else {
            if expires <= now {
                throw WalletStreamingError.expiredURL
            }
            throw WalletStreamingError.invalidURL
        }

        switch components.scheme?.lowercased() {
        case "https":
            switch components.path {
            case "/s/api/streaming/", "/s/api/streaming":
                components.path = "/api/streaming/v2/ws"
            case "/api/streaming/v2/ws":
                break
            default:
                throw WalletStreamingError.invalidURL
            }
            components.scheme = "wss"
        case "wss":
            guard components.path == "/api/streaming/v2/ws" else {
                throw WalletStreamingError.invalidURL
            }
        default:
            throw WalletStreamingError.invalidURL
        }

        guard components.percentEncodedQuery?.isEmpty == false,
              let url = components.url else {
            throw WalletStreamingError.invalidURL
        }
        return CachedValue(url: url, expires: expires)
    }
}

protocol WalletStreamingTransport: Sendable {
    func connect(subscription: Data) async throws
    func send(message: Data) async throws
    func receive() async throws -> Data
    func close() async
}

protocol WalletStreamingTransportFactory: Sendable {
    func makeTransport() -> any WalletStreamingTransport
}

private final class WalletStreamingSessionDelegate: NSObject, URLSessionWebSocketDelegate, @unchecked Sendable {
    private let expectedURL: URL
    private let log: WalletStreamingLogger

    init(
        expectedURL: URL,
        log: WalletStreamingLogger
    ) {
        self.expectedURL = expectedURL
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
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        guard webSocketTask.originalRequest?.url == self.expectedURL else {
            self.log("event=wallet_stream_response_rejected")
            webSocketTask.cancel(with: .policyViolation, reason: nil)
            return
        }
        self.log("event=wallet_stream_socket_open")
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        self.log("event=wallet_stream_socket_closed close_code=\(closeCode.rawValue)")
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            self.log("event=wallet_stream_socket_completed \(walletContextErrorFields(error))")
        } else {
            self.log("event=wallet_stream_socket_completed")
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
    private var session: URLSession?
    private var task: URLSessionWebSocketTask?
    private var connectionId: UUID?

    init(provider: WalletStreamingURLProvider, log: WalletStreamingLogger) {
        self.provider = provider
        self.log = log
    }

    func connect(subscription: Data) async throws {
        guard subscription.count <= walletStreamingMaximumFrameBytes else {
            throw WalletStreamingError.frameTooLarge
        }
        // Every WebSocket reconnect asks Telegram for a current signed endpoint. If that
        // request fails, the provider can still fall back to an unexpired cached URL.
        let url = try await self.provider.url(forceRefresh: true)
        try Task.checkCancellation()

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 60
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 24 * 60 * 60

        let delegate = WalletStreamingSessionDelegate(expectedURL: url, log: self.log)
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        let task = session.webSocketTask(with: request)
        task.maximumMessageSize = walletStreamingMaximumFrameBytes
        let connectionId = UUID()
        self.connectionId = connectionId
        self.session = session
        self.task = task
        task.resume()

        do {
            try await self.send(message: subscription)
        } catch {
            if self.connectionId == connectionId {
                self.connectionId = nil
                self.task = nil
                self.session = nil
            }
            task.cancel(with: .goingAway, reason: nil)
            session.invalidateAndCancel()
            throw error
        }
    }

    func send(message: Data) async throws {
        guard message.count <= walletStreamingMaximumFrameBytes else {
            throw WalletStreamingError.frameTooLarge
        }
        guard let task = self.task,
              self.connectionId != nil,
              let string = String(data: message, encoding: .utf8) else {
            throw WalletStreamingError.notConnected
        }
        try await task.send(.string(string))
    }

    func receive() async throws -> Data {
        guard let connectionId = self.connectionId, let task = self.task else {
            throw WalletStreamingError.notConnected
        }
        let message = try await task.receive()
        guard self.connectionId == connectionId else {
            throw CancellationError()
        }
        let data: Data
        switch message {
        case let .data(value):
            data = value
        case let .string(value):
            data = Data(value.utf8)
        @unknown default:
            throw WalletStreamingError.invalidResponse
        }
        guard data.count <= walletStreamingMaximumFrameBytes else {
            self.log("event=wallet_stream_event_too_large")
            throw WalletStreamingError.frameTooLarge
        }
        return data
    }

    func close() async {
        self.connectionId = nil
        let task = self.task
        let session = self.session
        self.task = nil
        self.session = nil
        task?.cancel(with: .goingAway, reason: nil)
        session?.invalidateAndCancel()
    }
}

enum WalletStreamingFinality: Int, Sendable, Equatable {
    case pending = 0
    case confirmed = 1
    case finalized = 2
}

enum WalletStreamingParsedEvent: Sendable, Equatable {
    case subscribed
    case accountStateChanged(balance: Int64, finality: WalletStreamingFinality)
    case transactionsChanged(
        traceId: String,
        finality: WalletStreamingFinality,
        transactions: [WalletContext.Transaction]
    )
    case traceInvalidated(traceId: String)
    case refreshOnly
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
        let error: String?
    }

    private struct AccountStateChange: Decodable {
        let account: String
        let finality: String
        let state: AccountState
    }

    private struct AccountState: Decodable {
        let balance: String
    }

    private struct StreamingMessage: Decodable {
        let source: String?
        let destination: String?
        let value: String?
        let bounced: Bool?
    }

    private struct TransactionDescription: Decodable {
        let aborted: Bool?
    }

    private struct StreamingTransaction: Decodable {
        let account: String
        let hash: String
        let lt: String
        let now: Int64
        let totalFees: String
        let description: TransactionDescription?
        let inMessage: StreamingMessage?
        let outMessages: [StreamingMessage]

        enum CodingKeys: String, CodingKey {
            case account
            case hash
            case lt
            case now
            case totalFees = "total_fees"
            case description
            case inMessage = "in_msg"
            case outMessages = "out_msgs"
        }
    }

    private struct TransactionsChange: Decodable {
        let finality: String
        let traceExternalHashNorm: String
        let transactions: [StreamingTransaction]

        enum CodingKeys: String, CodingKey {
            case finality
            case traceExternalHashNorm = "trace_external_hash_norm"
            case transactions
        }
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
            return .refreshOnly
        }
        if envelope.status == "subscribed" {
            return .subscribed
        }
        let expected = expectedRawAddress.lowercased()
        switch envelope.type {
        case "account_state_change":
            guard let value = try? decoder.decode(AccountStateChange.self, from: data) else {
                return .refreshOnly
            }
            guard value.account.lowercased() == expected,
                  let finality = self.finality(value.finality),
                  finality != .pending,
                  let balance = self.unsignedInt64(value.state.balance) else {
                return .refreshOnly
            }
            return .accountStateChanged(balance: balance, finality: finality)
        case "transactions":
            guard let value = try? decoder.decode(TransactionsChange.self, from: data),
                  !value.traceExternalHashNorm.isEmpty,
                  let finality = self.finality(value.finality) else {
                return .refreshOnly
            }
            let matchingTransactions = value.transactions.filter { $0.account.lowercased() == expected }
            guard !matchingTransactions.isEmpty else {
                return .refreshOnly
            }
            return .transactionsChanged(
                traceId: value.traceExternalHashNorm,
                finality: finality,
                transactions: matchingTransactions.compactMap {
                    self.transaction($0, walletRawAddress: expected, finality: finality)
                }
            )
        case "trace_invalidated":
            guard let value = try? decoder.decode(TraceInvalidated.self, from: data),
                  !value.traceExternalHashNorm.isEmpty else {
                return .refreshOnly
            }
            return .traceInvalidated(traceId: value.traceExternalHashNorm)
        default:
            return nil
        }
    }

    private static func finality(_ value: String) -> WalletStreamingFinality? {
        switch value {
        case "pending": return .pending
        case "confirmed": return .confirmed
        case "finalized": return .finalized
        default: return nil
        }
    }

    private static func unsignedInt64(_ value: String) -> Int64? {
        guard !value.isEmpty, value.allSatisfy(\.isNumber) else {
            return nil
        }
        return Int64(value)
    }

    private static func transaction(
        _ value: StreamingTransaction,
        walletRawAddress: String,
        finality: WalletStreamingFinality
    ) -> WalletContext.Transaction? {
        guard !value.hash.isEmpty,
              !value.lt.isEmpty,
              value.lt.allSatisfy(\.isNumber),
              let timestamp = Int32(exactly: value.now),
              let fee = self.unsignedInt64(value.totalFees) else {
            return nil
        }

        struct Candidate {
            let direction: WalletContext.Transaction.Direction
            let amount: Int64
            let address: String
            let bounced: Bool
        }

        var candidates: [Candidate] = []
        if let message = value.inMessage,
           message.destination?.lowercased() == walletRawAddress,
           let source = message.source,
           !source.isEmpty,
           let amountValue = message.value,
           let amount = self.unsignedInt64(amountValue),
           amount > 0 {
            candidates.append(Candidate(
                direction: .incoming,
                amount: amount,
                address: source,
                bounced: message.bounced == true
            ))
        }
        for message in value.outMessages {
            guard message.source?.lowercased() == walletRawAddress,
                  let destination = message.destination,
                  !destination.isEmpty,
                  let amountValue = message.value,
                  let amount = self.unsignedInt64(amountValue),
                  amount > 0 else {
                continue
            }
            candidates.append(Candidate(
                direction: .outgoing,
                amount: amount,
                address: destination,
                bounced: message.bounced == true
            ))
        }
        guard candidates.count == 1, let candidate = candidates.first else {
            return nil
        }

        let status: WalletContext.Transaction.Status
        if value.description?.aborted == true || candidate.bounced {
            status = .failed
        } else if finality == .pending {
            status = .pending
        } else {
            status = .completed
        }
        let peerAddress = (try? convertTonAddress(
            value: candidate.address,
            format: .userFriendly(bounceable: false, testnet: false)
        )) ?? candidate.address
        return WalletContext.Transaction(
            id: "\(value.lt):\(value.hash):\(candidate.direction == .incoming ? "in" : "out")",
            transactionHash: value.hash,
            logicalTime: value.lt,
            timestamp: timestamp,
            direction: candidate.direction,
            amount: candidate.direction == .outgoing ? -candidate.amount : candidate.amount,
            fee: fee,
            peer: .address(peerAddress, domain: nil),
            comment: nil,
            status: status
        )
    }

    static func isServerError(_ data: Data) -> Bool {
        guard data.count <= walletStreamingMaximumFrameBytes,
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else {
            return false
        }
        return envelope.error?.isEmpty == false
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

struct WalletStreamingPresentationOverlay {
    private struct BalanceValue {
        let revision: UInt64
        let value: Int64
        let updatedAt: Int32
    }

    private struct TraceValue {
        let revision: UInt64
        let finality: WalletStreamingFinality
        let transactions: [WalletContext.Transaction]
    }

    private(set) var revision: UInt64 = 0
    private var balance: BalanceValue?
    private var traces: [String: TraceValue] = [:]

    var isEmpty: Bool {
        self.balance == nil && self.traces.isEmpty
    }

    mutating func apply(_ event: WalletStreamingParsedEvent, updatedAt: Int32) -> Bool {
        switch event {
        case .subscribed, .refreshOnly:
            return false
        case let .accountStateChanged(balance, _):
            self.revision &+= 1
            self.balance = BalanceValue(revision: self.revision, value: balance, updatedAt: updatedAt)
            return true
        case let .transactionsChanged(traceId, finality, transactions):
            if let current = self.traces[traceId], current.finality.rawValue > finality.rawValue {
                return false
            }
            self.revision &+= 1
            if transactions.isEmpty {
                return self.traces.removeValue(forKey: traceId) != nil
            } else {
                self.traces[traceId] = TraceValue(
                    revision: self.revision,
                    finality: finality,
                    transactions: transactions
                )
                return true
            }
        case let .traceInvalidated(traceId):
            self.revision &+= 1
            return self.traces.removeValue(forKey: traceId) != nil
        }
    }

    mutating func clearBalance(through revision: UInt64) -> Bool {
        guard let balance = self.balance, balance.revision <= revision else {
            return false
        }
        self.balance = nil
        return true
    }

    mutating func clearTransactions(through revision: UInt64) -> Bool {
        let previousCount = self.traces.count
        self.traces = self.traces.filter { $0.value.revision > revision }
        return self.traces.count != previousCount
    }

    mutating func removeAll() -> Bool {
        guard !self.isEmpty else {
            return false
        }
        self.balance = nil
        self.traces.removeAll()
        return true
    }

    func applying(
        to state: WalletContext.State,
        peerByAddress: [String: EnginePeer]
    ) -> WalletContext.State {
        let balance: WalletContext.Resource<Int64>
        if let overlayBalance = self.balance {
            balance = .value(overlayBalance.value, updatedAt: overlayBalance.updatedAt)
        } else {
            balance = state.balance
        }

        let overlayTransactions = self.traces.values.flatMap(\.transactions)
        let transactions: WalletContext.TransactionsState
        if overlayTransactions.isEmpty {
            transactions = state.transactions
        } else {
            transactions = WalletContext.TransactionsState(
                items: transactionsWithStreamingOverlay(
                    authoritative: state.transactions.items,
                    streaming: overlayTransactions,
                    peerByAddress: peerByAddress
                ),
                offset: state.transactions.offset,
                canLoadMore: state.transactions.canLoadMore,
                isLoadingMore: state.transactions.isLoadingMore,
                error: state.transactions.error
            )
        }
        return WalletContext.State(
            phase: state.phase,
            balance: balance,
            transactions: transactions,
            collectibles: state.collectibles,
            pendingTransfers: state.pendingTransfers,
            activeOperation: state.activeOperation,
            fiat: state.fiat
        )
    }
}

private struct WalletStreamingSubscribeRequest: Encodable {
    let operation = "subscribe"
    let types = ["account_state_change", "transactions"]
    let addresses: [String]
    let minFinality = "pending"
    let includeAddressBook = false
    let includeMetadata = false
    let id: String

    enum CodingKeys: String, CodingKey {
        case operation
        case types
        case addresses
        case minFinality = "min_finality"
        case includeAddressBook = "include_address_book"
        case includeMetadata = "include_metadata"
        case id
    }
}

private struct WalletStreamingPingRequest: Encodable {
    let operation = "ping"
}

actor WalletToncenterStreamingClient {
    struct Configuration: Sendable {
        let initialBackoff: TimeInterval
        let maximumBackoff: TimeInterval
        let pingInterval: TimeInterval

        init(
            initialBackoff: TimeInterval = 1,
            maximumBackoff: TimeInterval = 60,
            pingInterval: TimeInterval = 15
        ) {
            self.initialBackoff = initialBackoff
            self.maximumBackoff = maximumBackoff
            self.pingInterval = pingInterval
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
        let stream = AsyncStream<WalletStreamingParsedEvent>(bufferingPolicy: .bufferingNewest(64)) {
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
                self.log("event=wallet_stream_connection_failed attempt=\(attempt) subscribed=\(self.connectionSubscribed ? 1 : 0) \(walletContextErrorFields(error))")
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
        let subscription = try encoder.encode(WalletStreamingSubscribeRequest(
            addresses: [rawAddress],
            id: UUID().uuidString.lowercased()
        ))
        let ping = try encoder.encode(WalletStreamingPingRequest())
        try await transport.connect(subscription: subscription)
        self.log("event=wallet_stream_request_started")

        let sleep = self.sleep
        let pingInterval = self.configuration.pingInterval
        let log = self.log
        let pingTask = Task {
            while !Task.isCancelled {
                do {
                    try await sleep(UInt64(max(0, pingInterval) * 1_000_000_000))
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                do {
                    try await transport.send(message: ping)
                    log("event=wallet_stream_ping_sent")
                } catch {
                    log("event=wallet_stream_ping_failed \(walletContextErrorFields(error))")
                    await transport.close()
                    return
                }
            }
        }
        defer {
            pingTask.cancel()
        }

        while !Task.isCancelled {
            let data = try await transport.receive()
            if WalletStreamingEventParser.isServerError(data) {
                self.log("event=wallet_stream_server_rejected")
                throw WalletStreamingError.invalidResponse
            }
            guard let event = WalletStreamingEventParser.parse(data, expectedRawAddress: rawAddress) else {
                let label = WalletStreamingEventParser.diagnosticLabel(data)
                self.log("event=wallet_stream_event_ignored kind=\(label)")
                continue
            }
            if case .subscribed = event {
                self.connectionSubscribed = true
                self.log("event=wallet_stream_subscribed")
            } else {
                self.log("event=wallet_stream_change_received")
            }
            self.continuation?.yield(event)
        }
        throw CancellationError()
    }
}

extension WalletContextImpl {
    func evaluateStreamingDemand() {
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
        self.streamingTask = Task { [weak self] in
            await self?.runStreaming(client: client, generation: generation, rawAddress: rawAddress)
        }
    }

    private func runStreaming(
        client: WalletToncenterStreamingClient,
        generation: UInt64,
        rawAddress: String
    ) async {
        let events = await client.events(rawAddress: rawAddress)
        for await event in events {
            guard !Task.isCancelled,
                  !self.isShutdown,
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
            case .subscribed, .refreshOnly:
                self.scheduleStreamingRefresh(generation: generation, rawAddress: rawAddress)
            case .accountStateChanged, .transactionsChanged, .traceInvalidated:
                if self.streamingPresentationOverlay.apply(event, updatedAt: currentWalletTimestamp()) {
                    self.publishPresentationState()
                }
                self.scheduleStreamingRefresh(generation: generation, rawAddress: rawAddress)
            }
        }
        await client.stop()
        if self.streamingClient === client {
            self.streamingClient = nil
            self.streamingTask = nil
            self.streamingAddress = nil
            self.streamingGeneration = nil
        }
    }

    func stopStreaming() {
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
        self.streamingRefreshTask = Task { [weak self] in
            await self?.runStreamingRefreshDelay(
                taskId: taskId,
                generation: generation,
                rawAddress: rawAddress
            )
        }
    }

    private func runStreamingRefreshDelay(taskId: UUID, generation: UInt64, rawAddress: String) async {
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000)
        } catch {
            return
        }
        guard !self.isShutdown,
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
