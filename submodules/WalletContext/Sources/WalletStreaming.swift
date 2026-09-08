import Foundation
import Dispatch
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

actor WalletStreamingURLProvider {
    private struct CachedValue {
        let url: URL
        let expires: Int64
    }

    private let engine: TelegramEngine
    private let logger: WalletLogger
    private var cached: CachedValue?

    init(engine: TelegramEngine, logger: WalletLogger) {
        self.engine = engine
        self.logger = logger
    }

    func url() async throws -> URL {
        do {
            let value = try await WalletSignalRequestContext<WalletStreamingUrl>().run(
                self.engine.wallet.getStreamingUrl()
            )
            try Task.checkCancellation()
            let parsed = try Self.parse(value, now: Int64(Date().timeIntervalSince1970))
            self.cached = parsed
            return parsed.url
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try Task.checkCancellation()
            let fallbackTimestamp = Int64(Date().timeIntervalSince1970)
            if let cached = self.cached, cached.expires > fallbackTimestamp {
                self.logger.error("wallet_stream_url_fetch_failed_using_cache", error, context: "expires_in=\(cached.expires - fallbackTimestamp)")
                return cached.url
            }
            self.logger.error("wallet_stream_url_fetch_failed", error)
            throw error
        }
    }

    private static func parse(_ value: WalletStreamingUrl, now: Int64) throws -> CachedValue {
        let expires = Int64(value.expires)
        guard expires > now,
              let components = URLComponents(string: value.url),
              components.scheme == "wss",
              components.host?.isEmpty == false,
              components.user == nil,
              components.password == nil,
              components.fragment == nil else {
            if expires <= now {
                throw WalletStreamingError.expiredURL
            }
            throw WalletStreamingError.invalidURL
        }
        guard components.percentEncodedQuery?.isEmpty == false,
              let url = components.url else {
            throw WalletStreamingError.invalidURL
        }
        return CachedValue(url: url, expires: expires)
    }
}

private final class WalletStreamingSessionDelegate: NSObject, URLSessionWebSocketDelegate, @unchecked Sendable {
    private let expectedURL: URL
    private let logger: WalletLogger

    init(
        expectedURL: URL,
        logger: WalletLogger
    ) {
        self.expectedURL = expectedURL
        self.logger = logger
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        self.logger.log("event=wallet_stream_redirect_rejected status_code=\(response.statusCode)")
        completionHandler(nil)
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        guard webSocketTask.originalRequest?.url == self.expectedURL else {
            self.logger.log("event=wallet_stream_response_rejected")
            webSocketTask.cancel(with: .policyViolation, reason: nil)
            return
        }
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        self.logger.log("event=wallet_stream_socket_closed close_code=\(closeCode.rawValue)")
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            self.logger.error("wallet_stream_socket_completed", error)
        }
    }
}

actor WalletURLSessionStreamingTransport {
    private let provider: WalletStreamingURLProvider
    private let logger: WalletLogger
    private var session: URLSession?
    private var task: URLSessionWebSocketTask?
    private var connectionId: UUID?

    init(provider: WalletStreamingURLProvider, logger: WalletLogger) {
        self.provider = provider
        self.logger = logger
    }

    func connect(subscription: Data) async throws {
        guard subscription.count <= walletStreamingMaximumFrameBytes else {
            throw WalletStreamingError.frameTooLarge
        }
        let url = try await self.provider.url()
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

        let delegate = WalletStreamingSessionDelegate(expectedURL: url, logger: self.logger)
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
            self.logger.log("event=wallet_stream_event_too_large")
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

    var diagnosticName: String {
        switch self {
        case .pending:
            return "pending"
        case .confirmed:
            return "confirmed"
        case .finalized:
            return "finalized"
        }
    }
}

enum WalletStreamingParsedEvent: Sendable, Equatable {
    case connecting
    case subscribed
    case disconnected
    case pong
    case accountStateChanged(balance: Int64, finality: WalletStreamingFinality)
    case transactionsChanged(
        traceId: String,
        finality: WalletStreamingFinality,
        transactions: [WalletContext.Transaction]
    )
    case traceInvalidated(traceId: String)
}

enum WalletStreamingConnectionState: Sendable, Equatable {
    case inactive
    case connecting
    case subscribed
    case disconnected
}

enum WalletStreamingDemand {
    static func isActive(
        foreground: Bool,
        accountIsCurrent: Bool,
        networkAvailable: Bool,
        walletScreenCount: Int,
        hasPendingTransfer: Bool
    ) -> Bool {
        foreground
            && accountIsCurrent
            && networkAvailable
            && (walletScreenCount > 0 || hasPendingTransfer)
    }

    static func needsPolling(connection: WalletStreamingConnectionState, hasPendingTransfer: Bool) -> Bool {
        connection != .subscribed || hasPendingTransfer
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

struct WalletStreamingRefreshTracker {
    private var finalizedBalance: Int64?
    private var remainingRetryCount = 0
    private var finalizedTraceIds = Set<String>()
    private var invalidatedTraceIds = Set<String>()
    private var traceOrder: [String] = []

    mutating func takeRetry() -> Bool {
        guard self.remainingRetryCount > 0 else { return false }
        self.remainingRetryCount -= 1
        return true
    }

    func hasFinalizedTrace(_ traceId: String) -> Bool {
        self.finalizedTraceIds.contains(traceId)
    }

    private mutating func remember(_ traceId: String) {
        self.traceOrder.removeAll(where: { $0 == traceId })
        self.traceOrder.append(traceId)
        if self.traceOrder.count > 256 {
            let removed = self.traceOrder.removeFirst()
            self.finalizedTraceIds.remove(removed)
            self.invalidatedTraceIds.remove(removed)
        }
    }

    mutating func requiresRefresh(_ event: WalletStreamingParsedEvent, knownTrace: Bool = false) -> Bool {
        switch event {
        case let .accountStateChanged(balance, finality):
            guard finality == .finalized, balance != self.finalizedBalance else { return false }
            self.finalizedBalance = balance
            self.remainingRetryCount = 2
            return true
        case let .transactionsChanged(traceId, finality, _):
            guard finality == .finalized, self.finalizedTraceIds.insert(traceId).inserted else { return false }
            self.invalidatedTraceIds.remove(traceId)
            self.remember(traceId)
            self.remainingRetryCount = 2
            return true
        case let .traceInvalidated(traceId):
            guard !self.invalidatedTraceIds.contains(traceId) else { return false }
            let wasFinalized = self.finalizedTraceIds.remove(traceId) != nil
            guard knownTrace || wasFinalized else { return false }
            self.invalidatedTraceIds.insert(traceId)
            self.remember(traceId)
            self.finalizedBalance = nil
            self.remainingRetryCount = 2
            return true
        case .connecting, .subscribed, .disconnected, .pong:
            return false
        }
    }
}

struct WalletSynchronizationScope: OptionSet, Sendable {
    let rawValue: Int

    static let account = WalletSynchronizationScope(rawValue: 1 << 0)
    static let transactions = WalletSynchronizationScope(rawValue: 1 << 1)
    static let nfts = WalletSynchronizationScope(rawValue: 1 << 2)
    static let all: WalletSynchronizationScope = [.account, .transactions, .nfts]
}

struct WalletSynchronizationRequestGate {
    private(set) var runningScope: WalletSynchronizationScope = []
    private(set) var isRunning = false
    var pendingScope: WalletSynchronizationScope { self.runningScope.union(self.queuedScope) }
    private(set) var queuedScope: WalletSynchronizationScope = []

    mutating func beginOrQueue(_ scope: WalletSynchronizationScope) -> WalletSynchronizationScope? {
        guard !scope.isEmpty else {
            return nil
        }
        if self.isRunning {
            self.queuedScope.formUnion(scope)
            return nil
        }
        self.isRunning = true
        self.runningScope = scope
        return scope
    }

    mutating func completedResource(_ scope: WalletSynchronizationScope) {
        self.runningScope.subtract(scope)
    }

    mutating func complete() -> WalletSynchronizationScope {
        self.isRunning = false
        self.runningScope = []
        let queuedScope = self.queuedScope
        self.queuedScope = []
        return queuedScope
    }

    mutating func cancel() {
        self.isRunning = false
        self.runningScope = []
        self.queuedScope = []
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

    private struct StreamingTransaction: Decodable {
        let account: String
        let hash: String
        let lt: String
        let now: Int64
        let totalFees: String
        let inMessage: StreamingMessage?
        let outMessages: [StreamingMessage]

        enum CodingKeys: String, CodingKey {
            case account
            case hash
            case lt
            case now
            case totalFees = "total_fees"
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

    private struct TransactionsHeader: Decodable {
        struct Transaction: Decodable {
            let account: String
        }

        let finality: String
        let traceExternalHashNorm: String
        let transactions: [Transaction]

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
            return nil
        }
        if envelope.status == "subscribed" {
            return .subscribed
        }
        if envelope.status == "pong" {
            return .pong
        }
        let expected = expectedRawAddress.lowercased()
        switch envelope.type {
        case "account_state_change":
            guard let value = try? decoder.decode(AccountStateChange.self, from: data) else {
                return nil
            }
            guard value.account.lowercased() == expected,
                  let finality = self.finality(value.finality),
                  finality != .pending,
                  let balance = self.unsignedInt64(value.state.balance) else {
                return nil
            }
            return .accountStateChanged(balance: balance, finality: finality)
        case "transactions":
            guard let header = try? decoder.decode(TransactionsHeader.self, from: data),
                  !header.traceExternalHashNorm.isEmpty,
                  let finality = self.finality(header.finality),
                  header.transactions.contains(where: { $0.account.lowercased() == expected }) else {
                return nil
            }
            // Finalized changes still need authoritative history when their payload
            // cannot be represented by the lightweight streaming transaction model.
            let value = try? decoder.decode(TransactionsChange.self, from: data)
            let matchingTransactions = value?.transactions.filter { $0.account.lowercased() == expected } ?? []
            return .transactionsChanged(
                traceId: header.traceExternalHashNorm,
                finality: finality,
                transactions: matchingTransactions.compactMap {
                    self.transaction($0, walletRawAddress: expected, finality: finality)
                }
            )
        case "trace_invalidated":
            guard let value = try? decoder.decode(TraceInvalidated.self, from: data),
                  !value.traceExternalHashNorm.isEmpty else {
                return nil
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
        if candidate.bounced {
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
        case .connecting, .subscribed, .disconnected, .pong:
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

    var hasFinalizedTransactions: Bool {
        self.traces.values.contains(where: { $0.finality == .finalized })
    }

    mutating func clearBalance(through revision: UInt64) -> Bool {
        guard let balance = self.balance, balance.revision <= revision else {
            return false
        }
        self.balance = nil
        return true
    }

    mutating func clearTransactions(
        through revision: UInt64,
        presentIn authoritativeTransactions: [WalletContext.Transaction],
        resolvedTraceIds: Set<String>
    ) -> Int {
        let authoritativeKeys = Set(authoritativeTransactions.map(walletTransactionMergeKey))
        let previousCount = self.traces.count
        self.traces = self.traces.filter { traceId, trace in
            guard trace.revision <= revision else {
                return true
            }
            if resolvedTraceIds.contains(traceId) {
                return false
            }
            return !trace.transactions.allSatisfy {
                authoritativeKeys.contains(walletTransactionMergeKey($0))
            }
        }
        return previousCount - self.traces.count
    }

    func transactionHashes(forTraceId traceId: String) -> [String]? {
        guard let trace = self.traces[traceId] else {
            return nil
        }
        let hashes = trace.transactions.compactMap(\.transactionHash)
        guard !hashes.isEmpty, hashes.count == trace.transactions.count else {
            return nil
        }
        return hashes
    }

    func containsTrace(_ traceId: String) -> Bool {
        self.traces[traceId] != nil
    }

    mutating func expirePendingTraces(
        _ traceIds: Set<String>
    ) -> (removedCount: Int, suppressedTraceIds: Set<String>) {
        var removedCount = 0
        var suppressedTraceIds = Set<String>()
        for traceId in traceIds {
            guard let trace = self.traces[traceId] else {
                suppressedTraceIds.insert(traceId)
                continue
            }
            guard trace.finality == .pending else {
                continue
            }
            self.traces.removeValue(forKey: traceId)
            suppressedTraceIds.insert(traceId)
            removedCount += 1
        }
        if removedCount != 0 {
            self.revision &+= 1
        }
        return (removedCount, suppressedTraceIds)
    }

    mutating func removeAll() -> Bool {
        guard !self.isEmpty else {
            return false
        }
        self.balance = nil
        self.traces.removeAll()
        return true
    }

    private func transactionsWithPendingComments(
        _ transactions: [WalletContext.Transaction],
        traceId: String,
        pendingTransfers: [WalletContext.PendingTransfer]
    ) -> [WalletContext.Transaction] {
        var pendingByRecipient: [String: [WalletContext.PendingTransfer]] = [:]
        for pending in pendingTransfers where pending.streamingTraceId == traceId
            && pending.collectibleAddress == nil && pending.amount > 0 {
            guard let recipient = walletAddressMappingKey(pending.recipient) else {
                continue
            }
            pendingByRecipient[recipient, default: []].append(pending)
        }
        guard !pendingByRecipient.isEmpty else {
            return transactions
        }

        var transactionIndicesByRecipient: [String: [Int]] = [:]
        for (index, transaction) in transactions.enumerated() {
            guard transaction.direction == .outgoing,
                  transaction.currency == .ton,
                  transaction.collectible == nil,
                  transaction.kind == .transfer,
                  let address = transaction.peer.address,
                  let recipient = walletAddressMappingKey(address) else {
                continue
            }
            transactionIndicesByRecipient[recipient, default: []].append(index)
        }

        var result = transactions
        // A trace can contain several transfers, so match uniquely on both sides.
        for (recipient, indices) in transactionIndicesByRecipient {
            guard indices.count == 1,
                  let index = indices.first,
                  let matchingPending = pendingByRecipient[recipient],
                  matchingPending.count == 1,
                  let pending = matchingPending.first,
                  let comment = pending.comment else {
                continue
            }
            let transaction = transactions[index]
            guard transaction.comment == nil else {
                continue
            }
            result[index] = WalletContext.Transaction(
                id: transaction.id,
                presentationId: transaction.presentationId,
                transactionHash: transaction.transactionHash,
                logicalTime: transaction.logicalTime,
                timestamp: transaction.timestamp,
                direction: transaction.direction,
                amount: transaction.amount,
                fee: transaction.fee,
                peer: transaction.peer,
                comment: comment,
                commentEncrypted: pending.commentEncrypted,
                currency: transaction.currency,
                collectible: transaction.collectible,
                status: transaction.status,
                kind: transaction.kind
            )
        }
        return result
    }

    func applying(
        to state: WalletContext.State,
        peerByAddress: [String: EnginePeer],
        presentationIdByTraceId: [String: String],
        presentationIdByTransactionHash: [String: String]
    ) -> WalletContext.State {
        let balance: WalletContext.Resource<Int64>
        if let overlayBalance = self.balance {
            balance = .value(overlayBalance.value, updatedAt: overlayBalance.updatedAt)
        } else {
            balance = state.balance
        }

        let authoritativeTransactions = state.transactions.items.map { transaction in
            guard let transactionHash = transaction.transactionHash,
                  let presentationId = presentationIdByTransactionHash[transactionHash] else {
                return transaction
            }
            return walletTransactionWithPresentationId(
                transaction,
                presentationId: presentationId
            )
        }
        let localTransactions = state.pendingTransfers.compactMap { pending -> WalletContext.Transaction? in
            if let traceId = pending.streamingTraceId, self.traces[traceId] != nil {
                return nil
            }
            return walletPendingTransferTransaction(pending)
        }
        let streamingTransactions = self.traces.flatMap { traceId, trace in
            let transactions = self.transactionsWithPendingComments(
                trace.transactions,
                traceId: traceId,
                pendingTransfers: state.pendingTransfers
            )
            return transactions.map { transaction in
                let presentationId: String?
                if trace.transactions.count == 1,
                   let value = presentationIdByTraceId[traceId] {
                    presentationId = value
                } else if let transactionHash = transaction.transactionHash {
                    presentationId = presentationIdByTransactionHash[transactionHash]
                } else {
                    presentationId = nil
                }
                guard let presentationId else {
                    return transaction
                }
                return walletTransactionWithPresentationId(
                    transaction,
                    presentationId: presentationId
                )
            }
        }
        let overlayTransactions = localTransactions + streamingTransactions
        let transactions: WalletContext.TransactionsState
        if overlayTransactions.isEmpty && authoritativeTransactions == state.transactions.items {
            transactions = state.transactions
        } else {
            transactions = WalletContext.TransactionsState(
                items: transactionsWithStreamingOverlay(
                    authoritative: authoritativeTransactions,
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
            fiat: state.fiat,
            gaslessInfo: state.gaslessInfo
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
        let inactivityTimeout: TimeInterval

        init(
            initialBackoff: TimeInterval = 1,
            maximumBackoff: TimeInterval = 60,
            pingInterval: TimeInterval = 15,
            inactivityTimeout: TimeInterval = 45
        ) {
            self.initialBackoff = initialBackoff
            self.maximumBackoff = maximumBackoff
            self.pingInterval = pingInterval
            self.inactivityTimeout = inactivityTimeout
        }
    }

    private let provider: WalletStreamingURLProvider
    private let configuration: Configuration
    private let logger: WalletLogger
    private var transport: WalletURLSessionStreamingTransport?
    private var pump: Task<Void, Never>?
    private var continuation: AsyncStream<WalletStreamingParsedEvent>.Continuation?
    private var connectionSubscribed = false
    private var lastConnectionActivityNanoseconds: UInt64?

    init(
        provider: WalletStreamingURLProvider,
        configuration: Configuration = Configuration(),
        logger: WalletLogger
    ) {
        self.provider = provider
        self.configuration = configuration
        self.logger = logger
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
        self.connectionSubscribed = false
        self.lastConnectionActivityNanoseconds = nil
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
                    max(exponential * Double.random(in: 0.85 ... 1.15), self.configuration.initialBackoff),
                    self.configuration.maximumBackoff
                )
                do {
                    self.logger.log("event=wallet_stream_reconnect_wait attempt=\(attempt) delay_ms=\(Int(delay * 1000))")
                    try await Task.sleep(nanoseconds: UInt64(max(0, delay) * 1_000_000_000))
                } catch {
                    return
                }
            }
            guard !Task.isCancelled else { return }

            self.connectionSubscribed = false
            self.lastConnectionActivityNanoseconds = nil
            self.continuation?.yield(.connecting)
            do {
                try await self.runConnection(rawAddress: rawAddress)
            } catch is CancellationError {
                if Task.isCancelled {
                    return
                }
            } catch {
                self.logger.error("wallet_stream_connection_failed", error, context: "attempt=\(attempt) subscribed=\(self.connectionSubscribed ? 1 : 0)")
            }
            let wasSubscribed = self.connectionSubscribed
            await self.transport?.close()
            self.transport = nil
            self.connectionSubscribed = false
            self.lastConnectionActivityNanoseconds = nil
            if !Task.isCancelled {
                self.continuation?.yield(.disconnected)
            }
            attempt = wasSubscribed ? 1 : min(attempt + 1, 16)
        }
    }

    private func runConnection(rawAddress: String) async throws {
        let transport = WalletURLSessionStreamingTransport(provider: self.provider, logger: self.logger)
        self.transport = transport
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let subscription = try encoder.encode(WalletStreamingSubscribeRequest(
            addresses: [rawAddress],
            id: UUID().uuidString.lowercased()
        ))
        let ping = try encoder.encode(WalletStreamingPingRequest())
        try await transport.connect(subscription: subscription)

        let pingInterval = self.configuration.pingInterval
        let inactivityTimeout = self.configuration.inactivityTimeout
        let logger = self.logger
        let pingTask = Task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: UInt64(max(0, pingInterval) * 1_000_000_000))
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                do {
                    try await transport.send(message: ping)
                } catch {
                    logger.error("wallet_stream_ping_failed", error)
                    await transport.close()
                    return
                }
            }
        }
        defer {
            pingTask.cancel()
        }

        let watchdogTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: UInt64(max(0, pingInterval) * 1_000_000_000))
                } catch {
                    return
                }
                guard !Task.isCancelled, let self else { return }
                if await self.connectionIsStale(
                    nowNanoseconds: DispatchTime.now().uptimeNanoseconds,
                    timeout: inactivityTimeout
                ) {
                    logger.log("event=wallet_stream_inactivity_timeout")
                    await transport.close()
                    return
                }
            }
        }
        defer {
            watchdogTask.cancel()
        }

        while !Task.isCancelled {
            let data = try await transport.receive()
            self.lastConnectionActivityNanoseconds = DispatchTime.now().uptimeNanoseconds
            if WalletStreamingEventParser.isServerError(data) {
                self.logger.log("event=wallet_stream_server_rejected")
                throw WalletStreamingError.invalidResponse
            }
            guard let event = WalletStreamingEventParser.parse(data, expectedRawAddress: rawAddress) else {
                let label = WalletStreamingEventParser.diagnosticLabel(data)
                self.logger.log("event=wallet_stream_event_ignored kind=\(label)")
                continue
            }
            if case .subscribed = event {
                self.connectionSubscribed = true
                self.logger.log("event=wallet_stream_subscribed")
            }
            self.continuation?.yield(event)
        }
        throw CancellationError()
    }

    private func connectionIsStale(nowNanoseconds: UInt64, timeout: TimeInterval) -> Bool {
        guard self.connectionSubscribed,
              let lastConnectionActivityNanoseconds = self.lastConnectionActivityNanoseconds else {
            return false
        }
        let timeoutNanoseconds = UInt64(max(0, timeout) * 1_000_000_000)
        return nowNanoseconds >= lastConnectionActivityNanoseconds
            && nowNanoseconds - lastConnectionActivityNanoseconds >= timeoutNanoseconds
    }
}

extension WalletContextImpl {
    func evaluateStreamingDemand() {
        let demandIsActive = WalletStreamingDemand.isActive(
            foreground: self.isApplicationInForeground,
            accountIsCurrent: self.isAccountCurrent,
            networkAvailable: self.isNetworkAvailable,
            walletScreenCount: self.walletScreenCount,
            hasPendingTransfer: !self.currentState.pendingTransfers.isEmpty
        )
        guard demandIsActive else {
            if self.streamingTask != nil || self.streamingClient != nil {
                self.logger.log("event=wallet_stream_demand_inactive foreground=\(self.isApplicationInForeground ? 1 : 0) account_current=\(self.isAccountCurrent ? 1 : 0) network_available=\(self.isNetworkAvailable ? 1 : 0) wallet_screen_visible=\(self.walletScreenCount > 0 ? 1 : 0) has_pending_transfer=\(self.currentState.pendingTransfers.isEmpty ? 0 : 1)")
            }
            self.stopStreaming()
            return
        }
        guard case let .wallet(info) = self.currentState.phase else {
            if self.streamingTask != nil || self.streamingClient != nil {
                self.logger.log("event=wallet_stream_wallet_inactive")
            }
            self.stopStreaming()
            return
        }
        guard let rawAddress = try? convertTonAddress(value: info.address, format: .raw) else {
            self.logger.log("event=wallet_stream_address_conversion_failed")
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
        self.logger.log("event=wallet_stream_start generation=\(generation)")
        let client = WalletToncenterStreamingClient(provider: self.streamingURLProvider, logger: self.logger)
        self.streamingClient = client
        self.streamingAddress = rawAddress
        self.streamingGeneration = generation
        self.streamingConnectionState = .connecting
        self.streamingHasSubscribed = false
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
                        walletScreenCount: self.walletScreenCount,
                        hasPendingTransfer: !self.currentState.pendingTransfers.isEmpty
                    )
                  ) else {
                break
            }
            switch event {
            case .connecting:
                self.streamingConnectionState = .connecting
            case .subscribed:
                let isReconnect = self.streamingHasSubscribed
                self.streamingHasSubscribed = true
                self.streamingConnectionState = .subscribed
                self.cancelWalletStateFallbackRefresh()
                if isReconnect {
                    self.scheduleStreamingRefresh(generation: generation, rawAddress: rawAddress)
                }
            case .disconnected:
                self.streamingConnectionState = .disconnected
            case .pong:
                break
            case let .accountStateChanged(_, finality):
                let changed = self.streamingPresentationOverlay.apply(
                    event,
                    updatedAt: currentWalletTimestamp()
                )
                if changed {
                    self.logger.log("event=wallet_stream_overlay_applied kind=account_state_change finality=\(finality.diagnosticName) changed=1")
                    self.publishPresentationState()
                }
                if self.streamingRefreshTracker.requiresRefresh(event) {
                    self.scheduleStreamingRefresh(generation: generation, rawAddress: rawAddress)
                }
            case let .transactionsChanged(traceId, finality, transactions):
                if self.streamingRefreshTracker.hasFinalizedTrace(traceId) {
                    continue
                }
                if finality == .pending,
                   self.expiredPendingStreamingTraceIds.contains(traceId) {
                    continue
                }
                if finality != .pending {
                    self.expiredPendingStreamingTraceIds.remove(traceId)
                }
                let filteredTransactions = transactions.filter {
                    $0.direction != .incoming || $0.amount >= self.transferMinAmount
                }
                let changed = self.streamingPresentationOverlay.apply(
                    .transactionsChanged(traceId: traceId, finality: finality, transactions: filteredTransactions),
                    updatedAt: currentWalletTimestamp()
                )
                if changed {
                    self.logger.log("event=wallet_stream_overlay_applied kind=transactions finality=\(finality.diagnosticName) transaction_count=\(filteredTransactions.count) changed=1")
                    self.publishPresentationState()
                }
                if self.streamingRefreshTracker.requiresRefresh(event) {
                    self.scheduleStreamingRefresh(generation: generation, rawAddress: rawAddress)
                }
            case let .traceInvalidated(traceId):
                let knownTrace = self.streamingPresentationOverlay.containsTrace(traceId)
                    || self.currentState.pendingTransfers.contains(where: { $0.streamingTraceId == traceId })
                self.expiredPendingStreamingTraceIds.remove(traceId)
                let changed = self.streamingPresentationOverlay.apply(
                    event,
                    updatedAt: currentWalletTimestamp()
                )
                if changed {
                    self.logger.log("event=wallet_stream_overlay_applied kind=trace_invalidated changed=1")
                    self.publishPresentationState()
                }
                if self.streamingRefreshTracker.requiresRefresh(event, knownTrace: knownTrace) {
                    self.scheduleStreamingRefresh(generation: generation, rawAddress: rawAddress)
                }
            }
            self.evaluatePollingDemand()
        }
        await client.stop()
        if self.streamingClient === client {
            self.streamingClient = nil
            self.streamingTask = nil
            self.streamingAddress = nil
            self.streamingGeneration = nil
            self.streamingConnectionState = .inactive
            self.streamingHasSubscribed = false
            self.evaluatePollingDemand()
        }
    }

    func stopStreaming() {
        if self.streamingTask != nil || self.streamingClient != nil {
            self.logger.log("event=wallet_stream_stop")
        }
        self.streamingTask?.cancel()
        self.streamingTask = nil
        self.streamingRefreshTask?.cancel()
        self.streamingRefreshTask = nil
        self.streamingRefreshTaskId = nil
        self.streamingRefreshScope = []
        self.streamingAddress = nil
        self.streamingGeneration = nil
        self.streamingConnectionState = .inactive
        self.streamingHasSubscribed = false
        let client = self.streamingClient
        self.streamingClient = nil
        if let client {
            Task { await client.stop() }
        }
    }

    func retryStreamingSynchronizationIfNeeded(scope: WalletSynchronizationScope) {
        guard self.streamingConnectionState == .subscribed,
              let generation = self.streamingGeneration,
              let rawAddress = self.streamingAddress else { return }
        if self.streamingRefreshTask == nil {
            guard self.streamingRefreshTracker.takeRetry() else { return }
        }
        self.scheduleStreamingRefresh(generation: generation, rawAddress: rawAddress, scope: scope, delay: 3_000_000_000)
    }

    private func scheduleStreamingRefresh(generation: UInt64, rawAddress: String, scope: WalletSynchronizationScope = [.account, .transactions], delay: UInt64 = 1_000_000_000) {
        guard self.activationGeneration == generation,
              self.streamingGeneration == generation,
              self.streamingAddress == rawAddress else {
            return
        }
        self.streamingRefreshScope.formUnion(scope)
        guard self.streamingRefreshTask == nil else { return }
        let taskId = UUID()
        self.streamingRefreshTaskId = taskId
        self.streamingRefreshTask = Task { [weak self] in
            await self?.runStreamingRefreshDelay(
                taskId: taskId,
                generation: generation,
                rawAddress: rawAddress,
                delay: delay
            )
        }
    }

    private func runStreamingRefreshDelay(taskId: UUID, generation: UInt64, rawAddress: String, delay: UInt64) async {
        defer {
            if self.streamingRefreshTaskId == taskId {
                self.streamingRefreshTask = nil
                self.streamingRefreshTaskId = nil
                self.streamingRefreshScope = []
            }
        }
        do {
            try await Task.sleep(nanoseconds: delay)
        } catch {
            return
        }
        guard !self.isShutdown,
              self.streamingRefreshTaskId == taskId,
              self.activationGeneration == generation,
              self.streamingGeneration == generation,
              self.streamingAddress == rawAddress,
              self.canUseNetworkRuntime,
              self.walletScreenCount > 0 || !self.currentState.pendingTransfers.isEmpty else {
            return
        }
        let scope = self.streamingRefreshScope
        self.streamingRefreshTask = nil
        self.streamingRefreshTaskId = nil
        self.streamingRefreshScope = []
        self.requestSynchronization(scope: scope)
    }
}
