import Foundation
import TONCore

/// The result of emulating a message: what *would* happen if it were sent.
///
/// This is what a wallet shows the user before they approve — so a wrong reading here
/// means the user authorizes something other than what they saw.
public struct EmulationResult: Sendable {
    /// Masterchain block the emulation ran against.
    public let mcBlockSeqno: Int
    /// Every transaction the message would cause, sender first.
    public let transactions: [ChainTransaction]
    /// The execution tree, which shows causality that a flat list does not.
    public let trace: EmulationTraceNode?
    /// True when the emulator could not follow the whole tree — a partial preview that
    /// must not be presented as complete.
    public let isIncomplete: Bool

    public init(
        mcBlockSeqno: Int,
        transactions: [ChainTransaction],
        trace: EmulationTraceNode?,
        isIncomplete: Bool
    ) {
        self.mcBlockSeqno = mcBlockSeqno
        self.transactions = transactions
        self.trace = trace
        self.isIncomplete = isIncomplete
    }

    /// Whether every transaction succeeded.
    ///
    /// An incomplete emulation is **not** treated as successful: we cannot claim a
    /// transfer will work when part of the tree was not evaluated.
    public var allSucceeded: Bool {
        !isIncomplete && !transactions.contains(where: \.isFailed)
    }

    /// The first failing transaction, for explaining a rejection to the user.
    public var firstFailure: ChainTransaction? {
        transactions.first(where: \.isFailed)
    }

    /// Total fees across all transactions, in nanoton.
    public var totalFees: BigUInt {
        transactions.reduce(BigUInt(0)) { sum, tx in
            sum + (tx.totalFees.flatMap { BigUInt($0) } ?? 0)
        }
    }
}

/// A node in the emulated execution tree.
public struct EmulationTraceNode: Sendable {
    public let transactionHash: String
    public let children: [EmulationTraceNode]

    public init(transactionHash: String, children: [EmulationTraceNode]) {
        self.transactionHash = transactionHash
        self.children = children
    }

    /// Depth of the tree, useful for spotting unexpectedly deep call chains.
    public var depth: Int {
        1 + (children.map(\.depth).max() ?? 0)
    }

    public var transactionCount: Int {
        1 + children.reduce(0) { $0 + $1.transactionCount }
    }
}

/// Net value movement for one account, derived from an emulation.
///
/// This is the number a wallet actually shows: "you will send 1.5 TON and pay 0.004 in
/// fees". Computing it from the transaction list rather than trusting the requested
/// amount matters because the requested amount excludes fees and forwarded value.
public struct MoneyFlow: Sendable {
    /// Nanoton leaving the account, excluding fees.
    public let sent: BigUInt
    /// Nanoton arriving at the account.
    public let received: BigUInt
    /// Fees the account pays.
    public let fees: BigUInt

    public init(sent: BigUInt, received: BigUInt, fees: BigUInt) {
        self.sent = sent
        self.received = received
        self.fees = fees
    }

    /// Net change including fees. Negative values are returned as a magnitude plus a
    /// flag, since `BigUInt` cannot represent them.
    public var isOutgoing: Bool { sent + fees > received }

    public var netMagnitude: BigUInt {
        let outgoing = sent + fees
        return outgoing > received ? outgoing - received : received - outgoing
    }
}

extension EmulationResult {
    /// Computes value movement for one account across the emulated transactions.
    ///
    /// Fees are attributed only to transactions on that account — the recipient's fees
    /// are not the sender's problem, and folding them in would overstate the cost.
    public func moneyFlow(for address: String) -> MoneyFlow {
        var sent = BigUInt(0)
        var received = BigUInt(0)
        var fees = BigUInt(0)

        let target = address.uppercased()

        for tx in transactions {
            let isOurs = tx.account.uppercased() == target
                || (try? Mappers.canonical(address: tx.account)) == (try? Mappers.canonical(address: address))

            guard isOurs else { continue }

            fees += tx.totalFees.flatMap { BigUInt($0) } ?? 0

            // Inbound value credits the account.
            if let value = tx.inMessage?.value, let amount = BigUInt(value) {
                received += amount
            }
            // Outbound value debits it.
            for out in tx.outMessages {
                if let value = out.value, let amount = BigUInt(value) {
                    sent += amount
                }
            }
        }

        return MoneyFlow(sent: sent, received: received, fees: fees)
    }
}
