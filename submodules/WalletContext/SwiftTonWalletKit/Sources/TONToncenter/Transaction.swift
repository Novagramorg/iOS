import Foundation
import TONCore

/// What triggered a transaction.
public enum TransactionKind: String, Sendable {
    /// Triggered by an inbound message — the ordinary case.
    case ordinary
    /// Triggered by the block itself, not a message. Masterchain system accounts
    /// (the config contract, the elector) receive these, and their `in_msg` is empty.
    case tickTock = "tick_tock"
    case storage
    case splitPrepare = "split_prepare"
    case splitInstall = "split_install"
    case mergePrepare = "merge_prepare"
    case mergeInstall = "merge_install"
    case unknown

    init(wire: String?) {
        switch wire {
        case "ord", "ordinary": self = .ordinary
        case "tick_tock", "tock", "tick": self = .tickTock
        case "storage": self = .storage
        case "split_prepare": self = .splitPrepare
        case "split_install": self = .splitInstall
        case "merge_prepare": self = .mergePrepare
        case "merge_install": self = .mergeInstall
        default: self = .unknown
        }
    }
}

/// A message attached to a transaction.
///
/// Fields are optional because `tick_tock` transactions carry an empty message object,
/// and because Toncenter omits fields for message kinds where they do not apply.
public struct ChainMessage: Sendable {
    public let hash: String?
    /// TEP-467 normalized hash, present only on inbound external messages.
    public let normalizedHash: String?
    public let source: String?
    public let destination: String?
    /// Nanoton, as a decimal string.
    public let value: String?
    public let forwardFee: String?
    public let createdLogicalTime: String?
    public let opcode: String?
    public let bounce: Bool
    public let bounced: Bool
    public let bodyBoc: String?
    public let comment: String?
    public let hasStateInit: Bool

    public init(
        hash: String?,
        normalizedHash: String? = nil,
        source: String? = nil,
        destination: String? = nil,
        value: String? = nil,
        forwardFee: String? = nil,
        createdLogicalTime: String? = nil,
        opcode: String? = nil,
        bounce: Bool = false,
        bounced: Bool = false,
        bodyBoc: String? = nil,
        comment: String? = nil,
        hasStateInit: Bool = false
    ) {
        self.hash = hash
        self.normalizedHash = normalizedHash
        self.source = source
        self.destination = destination
        self.value = value
        self.forwardFee = forwardFee
        self.createdLogicalTime = createdLogicalTime
        self.opcode = opcode
        self.bounce = bounce
        self.bounced = bounced
        self.bodyBoc = bodyBoc
        self.comment = comment
        self.hasStateInit = hasStateInit
    }
}

/// A transaction as the chain records it.
/// Why TVM never ran for a transaction.
///
/// Only ``noState`` is benign: the account had no code, so nothing could execute, but any
/// inbound value was still credited. ``noGas`` and ``badState`` are genuine failures.
public enum ComputeSkipReason: String, Sendable, Hashable {
    /// The account has no code — typically an address that has not been deployed.
    case noState = "no_state"
    /// The account's state could not be used.
    case badState = "bad_state"
    /// Not enough gas to begin execution.
    case noGas = "no_gas"
    case suspended

    /// An unrecognised reason. Kept rather than dropped so a new TVM reason does not silently
    /// read as "benign".
    public init?(wire: String?) {
        guard let wire else { return nil }
        self.init(rawValue: wire)
    }
}

public struct ChainTransaction: Sendable {
    public let account: String
    /// `0x`-prefixed hex.
    public let hash: String
    public let logicalTime: String
    /// Unix seconds.
    public let now: Int
    public let kind: TransactionKind
    public let aborted: Bool
    public let exitCode: Int?
    /// Why the compute phase was skipped, when it was.
    public let computeSkipReason: ComputeSkipReason?
    public let totalFees: String?
    public let previousTransaction: TransactionID?
    public let traceID: String?
    /// Currently always nil: Toncenter v3 no longer returns this field.
    public let traceExternalHash: String?
    /// Absent for `tick_tock` transactions, which are not message-driven.
    public let inMessage: ChainMessage?
    public let outMessages: [ChainMessage]

    public init(
        account: String,
        hash: String,
        logicalTime: String,
        now: Int,
        kind: TransactionKind,
        aborted: Bool,
        exitCode: Int?,
        computeSkipReason: ComputeSkipReason? = nil,
        totalFees: String?,
        previousTransaction: TransactionID?,
        traceID: String?,
        traceExternalHash: String?,
        inMessage: ChainMessage?,
        outMessages: [ChainMessage]
    ) {
        self.account = account
        self.hash = hash
        self.logicalTime = logicalTime
        self.now = now
        self.kind = kind
        self.aborted = aborted
        self.exitCode = exitCode
        self.computeSkipReason = computeSkipReason
        self.totalFees = totalFees
        self.previousTransaction = previousTransaction
        self.traceID = traceID
        self.traceExternalHash = traceExternalHash
        self.inMessage = inMessage
        self.outMessages = outMessages
    }

    /// Whether the transaction failed.
    ///
    /// `aborted` alone is not enough in either direction:
    ///
    /// - A non-zero compute exit code is a failure even when the transaction was not aborted.
    /// - A compute phase skipped for ``ComputeSkipReason/noState`` is **not** a failure, even
    ///   though TON sets `aborted`. The account simply had no code to run, and the inbound
    ///   value was still credited — which is exactly what happens when funding an address
    ///   before it is deployed. Treating it as failure made every such transfer show up as
    ///   "this will fail" in a preview.
    public var isFailed: Bool {
        // Checked before `aborted`, because a no_state skip is the *cause* of that flag.
        if computeSkipReason == .noState { return false }
        if aborted { return true }
        if let exitCode, exitCode != 0, exitCode != 1 { return true }
        return false
    }

    /// True when value arrived at an account that has no code yet.
    ///
    /// Worth surfacing separately: it is fine for a plain transfer, but a message carrying a
    /// payload meant for a contract did nothing, and the user should be told which they got.
    public var deliveredWithoutCode: Bool {
        computeSkipReason == .noState
    }
}

/// A page of transactions plus the address book Toncenter returns alongside.
public struct TransactionsPage: Sendable {
    public let transactions: [ChainTransaction]
    /// Raw address to reverse-DNS name when available, otherwise its friendly form.
    public let addressBook: [String: String]

    public init(transactions: [ChainTransaction], addressBook: [String: String] = [:]) {
        self.transactions = transactions
        self.addressBook = addressBook
    }
}
