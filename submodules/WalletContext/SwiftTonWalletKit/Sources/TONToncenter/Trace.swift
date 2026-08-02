import Foundation
import TONCore

/// A trace: one external message and every transaction it caused, as a tree.
///
/// Traces are how a wallet explains a transfer to the user. A flat transaction list loses
/// causality, which matters when a single jetton transfer fans out into four or five
/// transactions across the sender, the two jetton wallets, and a notification.
public struct Trace: Sendable {
    /// `0x`-prefixed hex.
    public let traceID: String
    /// Hash of the external message that started the trace. Present only for
    /// externally-triggered traces.
    public let externalHash: String?
    public let startLogicalTime: String?
    public let endLogicalTime: String?
    /// Unix seconds.
    public let startTime: Int?
    public let endTime: Int?
    /// True when the indexer has not yet seen the whole tree.
    public let isIncomplete: Bool
    public let info: TraceInfo?
    public let root: TraceNode?
    /// Transactions in causal order, root first.
    public let transactions: [ChainTransaction]

    public init(
        traceID: String,
        externalHash: String?,
        startLogicalTime: String?,
        endLogicalTime: String?,
        startTime: Int?,
        endTime: Int?,
        isIncomplete: Bool,
        info: TraceInfo?,
        root: TraceNode?,
        transactions: [ChainTransaction]
    ) {
        self.traceID = traceID
        self.externalHash = externalHash
        self.startLogicalTime = startLogicalTime
        self.endLogicalTime = endLogicalTime
        self.startTime = startTime
        self.endTime = endTime
        self.isIncomplete = isIncomplete
        self.info = info
        self.root = root
        self.transactions = transactions
    }

    /// Whether every transaction in the trace succeeded.
    ///
    /// An incomplete trace is not reported as successful: transactions we have not seen
    /// could still have failed.
    public var allSucceeded: Bool {
        !isIncomplete && !transactions.contains(where: \.isFailed)
    }

    public var firstFailure: ChainTransaction? {
        transactions.first(where: \.isFailed)
    }

    /// Total fees across the trace, in nanoton.
    public var totalFees: BigUInt {
        transactions.reduce(BigUInt(0)) { $0 + ($1.totalFees.flatMap { BigUInt($0) } ?? 0) }
    }

    /// Whether the indexer still expects more messages.
    public var isPending: Bool {
        (info?.pendingMessageCount ?? 0) > 0 || isIncomplete
    }
}

/// The indexer's summary of a trace.
public struct TraceInfo: Sendable {
    /// `complete`, `pending`, …
    public let state: String?
    public let messageCount: Int
    public let transactionCount: Int
    public let pendingMessageCount: Int
    /// `classified`, `unclassified` — whether the indexer has attached action semantics.
    public let classificationState: String?

    public init(
        state: String?,
        messageCount: Int,
        transactionCount: Int,
        pendingMessageCount: Int,
        classificationState: String?
    ) {
        self.state = state
        self.messageCount = messageCount
        self.transactionCount = transactionCount
        self.pendingMessageCount = pendingMessageCount
        self.classificationState = classificationState
    }
}

/// A node in a trace tree.
public struct TraceNode: Sendable {
    public let transactionHash: String
    /// Hash of the message that caused this transaction.
    public let inMessageHash: String?
    public let children: [TraceNode]

    public init(transactionHash: String, inMessageHash: String?, children: [TraceNode]) {
        self.transactionHash = transactionHash
        self.inMessageHash = inMessageHash
        self.children = children
    }

    public var depth: Int {
        1 + (children.map(\.depth).max() ?? 0)
    }

    public var transactionCount: Int {
        1 + children.reduce(0) { $0 + $1.transactionCount }
    }

    /// Depth-first pre-order walk, which is causal order.
    public func flattened() -> [TraceNode] {
        [self] + children.flatMap { $0.flattened() }
    }
}

/// A page of traces plus the human-readable address data returned with them.
public struct TracesPage: Sendable {
    public let traces: [Trace]
    /// Raw address to reverse-DNS name when available, otherwise its friendly form.
    public let addressBook: [String: String]

    public init(traces: [Trace], addressBook: [String: String] = [:]) {
        self.traces = traces
        self.addressBook = addressBook
    }
}
