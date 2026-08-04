import Foundation
import TONCore

/// How settled a streamed event is.
///
/// The stream reports the same change more than once as it settles, so this is not decoration:
/// a wallet may show a pending transfer immediately but must not treat it as final, and a
/// `pending` event arriving *after* a `confirmed` one for the same trace is stale reordering
/// rather than a reversal.
public enum StreamFinality: String, Sendable, Comparable, CaseIterable {
    case pending
    case confirmed
    case finalized

    /// Ordering by how settled, so a later-but-weaker event can be recognised and dropped.
    private var rank: Int {
        switch self {
        case .pending: return 0
        case .confirmed: return 1
        case .finalized: return 2
        }
    }

    public static func < (lhs: StreamFinality, rhs: StreamFinality) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// What a subscription asks the server to send.
public enum StreamEventType: String, Sendable, CaseIterable {
    case transactions
    case accountState = "account_state_change"
    case jettons = "jettons_change"
}

/// An account's balance and status changed.
public struct BalanceUpdate: Sendable, Equatable {
    public let address: Address
    /// Nanoton.
    public let balance: BigUInt
    public let status: AccountStatus
    public let finality: StreamFinality
    /// Hash of the account state, so a consumer can tell two updates apart.
    public let stateHash: String?

    public init(
        address: Address,
        balance: BigUInt,
        status: AccountStatus,
        finality: StreamFinality,
        stateHash: String?
    ) {
        self.address = address
        self.balance = balance
        self.status = status
        self.finality = finality
        self.stateHash = stateHash
    }
}

/// Transactions touching a watched account arrived.
///
/// Carries the whole trace's transactions, filtered to the watched account: one transfer fans
/// out across several contracts, and a wallet showing every transaction in the trace would
/// report a jetton send as four unrelated events.
public struct TransactionUpdate: Sendable {
    public let address: Address
    public let transactions: [ChainTransaction]
    public let finality: StreamFinality
    /// Normalized external hash of the trace, `0x`-prefixed. Matches ``SentTransfer``'s hash,
    /// which is how a wallet recognises its own send arriving back on the stream.
    public let traceHash: String
    /// True when the chain discarded this trace — a pending transfer that never landed.
    public let isInvalidated: Bool

    public init(
        address: Address,
        transactions: [ChainTransaction],
        finality: StreamFinality,
        traceHash: String,
        isInvalidated: Bool = false
    ) {
        self.address = address
        self.transactions = transactions
        self.finality = finality
        self.traceHash = traceHash
        self.isInvalidated = isInvalidated
    }
}

/// A watched owner's jetton balance changed.
public struct JettonUpdate: Sendable, Equatable {
    public let owner: Address
    /// The jetton master.
    public let master: Address
    /// The owner's jetton wallet for this token.
    public let jettonWallet: Address?
    /// Balance in the token's base units.
    public let balance: BigUInt
    public let finality: StreamFinality

    public init(
        owner: Address,
        master: Address,
        jettonWallet: Address?,
        balance: BigUInt,
        finality: StreamFinality
    ) {
        self.owner = owner
        self.master = master
        self.jettonWallet = jettonWallet
        self.balance = balance
        self.finality = finality
    }
}

/// Anything the stream delivers.
public enum StreamEvent: Sendable {
    case balance(BalanceUpdate)
    case transactions(TransactionUpdate)
    case jettons(JettonUpdate)
    /// The connection dropped and is being retried. Not fatal — surfaced so an app can show a
    /// "reconnecting" state instead of appearing frozen while it silently recovers.
    case connectionChanged(isConnected: Bool)

    /// The account this event concerns, when it concerns one.
    public var address: Address? {
        switch self {
        case .balance(let update): return update.address
        case .transactions(let update): return update.address
        case .jettons(let update): return update.owner
        case .connectionChanged: return nil
        }
    }
}
