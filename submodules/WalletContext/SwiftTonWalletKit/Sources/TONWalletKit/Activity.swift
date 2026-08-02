import Foundation
import TONCore
import TONToncenter

/// One user-facing value movement extracted from a Toncenter trace.
///
/// This is deliberately independent of any application's presentation model. In particular,
/// a jetton is identified by the wallet contract that handled the message; the host decides
/// which master, symbol and formatting policy that contract represents.
public struct WalletActivity: Sendable, Equatable {
    public enum Direction: String, Sendable, Equatable {
        case incoming
        case outgoing
    }

    public enum Status: String, Sendable, Equatable {
        case pending
        case completed
    }

    public enum Asset: Sendable, Equatable {
        case ton
        case jetton(wallet: Address)
        case nft(item: Address)
    }

    public let id: String
    public let traceID: String
    /// TEP-467 normalized hash of the external message that started the trace.
    public let externalMessageHash: String?
    public let transactionHash: String
    public let logicalTime: String
    public let timestamp: Int
    public let direction: Direction
    public let asset: Asset
    /// Nanoton for TON, token base units for a jetton, and zero for an NFT.
    public let amount: BigUInt
    /// Total wallet-account fees attributed to this activity, in nanoton.
    public let fee: BigUInt
    public let counterparty: Address?
    public let counterpartyName: String?
    public let comment: String?
    public let status: Status

    public init(
        id: String,
        traceID: String,
        externalMessageHash: String? = nil,
        transactionHash: String,
        logicalTime: String,
        timestamp: Int,
        direction: Direction,
        asset: Asset,
        amount: BigUInt,
        fee: BigUInt,
        counterparty: Address?,
        counterpartyName: String?,
        comment: String?,
        status: Status
    ) {
        self.id = id
        self.traceID = traceID
        self.externalMessageHash = externalMessageHash
        self.transactionHash = transactionHash
        self.logicalTime = logicalTime
        self.timestamp = timestamp
        self.direction = direction
        self.asset = asset
        self.amount = amount
        self.fee = fee
        self.counterparty = counterparty
        self.counterpartyName = counterpartyName
        self.comment = comment
        self.status = status
    }
}

public enum WalletActivityError: Error, Equatable {
    case invalidFee(String)
}

/// Converts provider-level traces into stable wallet activities.
public enum WalletActivityExtractor {
    public static func activities(
        from page: TracesPage,
        walletAddress: Address
    ) throws -> [WalletActivity] {
        try page.traces.flatMap { trace in
            try activities(
                from: trace,
                walletAddress: walletAddress,
                addressBook: page.addressBook
            )
        }
    }

    public static func activities(
        from trace: Trace,
        walletAddress: Address,
        addressBook: [String: String] = [:],
        status: WalletActivity.Status? = nil
    ) throws -> [WalletActivity] {
        try activities(
            from: trace.transactions,
            traceID: trace.traceID,
            externalMessageHash: trace.externalHash,
            fallbackLogicalTime: trace.endLogicalTime ?? trace.startLogicalTime ?? "0",
            walletAddress: walletAddress,
            addressBook: addressBook,
            status: status ?? (trace.isPending ? .pending : .completed)
        )
    }

    public static func activities(
        from transactions: [ChainTransaction],
        traceID: String,
        externalMessageHash: String? = nil,
        walletAddress: Address,
        status: WalletActivity.Status
    ) throws -> [WalletActivity] {
        try activities(
            from: transactions,
            traceID: traceID,
            externalMessageHash: externalMessageHash,
            fallbackLogicalTime: transactions.first?.logicalTime ?? "0",
            walletAddress: walletAddress,
            addressBook: [:],
            status: status
        )
    }

    private static func activities(
        from transactions: [ChainTransaction],
        traceID: String,
        externalMessageHash fallbackExternalMessageHash: String?,
        fallbackLogicalTime: String,
        walletAddress: Address,
        addressBook: [String: String],
        status: WalletActivity.Status
    ) throws -> [WalletActivity] {
        let walletTransactions = transactions.filter {
            parsedAddress($0.account) == walletAddress
        }
        guard let firstWalletTransaction = walletTransactions.first else { return [] }

        var totalFee = BigUInt(0)
        for transaction in walletTransactions {
            let rawFee = transaction.totalFees ?? "0"
            guard let fee = BigUInt(rawFee, radix: 10) else {
                throw WalletActivityError.invalidFee(rawFee)
            }
            totalFee += fee
        }

        let logicalTime = firstWalletTransaction.logicalTime.isEmpty
            ? fallbackLogicalTime
            : firstWalletTransaction.logicalTime
        let externalMessageHash = firstWalletTransaction.inMessage?.normalizedHash
            ?? fallbackExternalMessageHash
        let timestamp = firstWalletTransaction.now
        let transactionHash = firstWalletTransaction.hash

        var containsJettonOperation = false
        for transaction in walletTransactions {
            for message in transaction.outMessages {
                guard let payload = TransferPayloadDecoder.jettonTransfer(from: message) else {
                    continue
                }
                containsJettonOperation = true
                guard let jettonWallet = parsedAddress(message.destination) else { continue }
                return [WalletActivity(
                    id: messageID(
                        kind: "jetton",
                        direction: .outgoing,
                        messageHash: message.hash,
                        transactionHash: transaction.hash
                    ),
                    traceID: traceID,
                    externalMessageHash: externalMessageHash,
                    transactionHash: transactionHash,
                    logicalTime: logicalTime,
                    timestamp: timestamp,
                    direction: .outgoing,
                    asset: .jetton(wallet: jettonWallet),
                    amount: payload.amount,
                    fee: totalFee,
                    counterparty: payload.destination,
                    counterpartyName: addressName(payload.destination, in: addressBook),
                    comment: nonEmptyString(payload.comment),
                    status: status
                )]
            }
            if let message = transaction.inMessage,
               let payload = TransferPayloadDecoder.jettonNotification(from: message) {
                containsJettonOperation = true
                guard let jettonWallet = parsedAddress(message.source) else { continue }
                return [WalletActivity(
                    id: messageID(
                        kind: "jetton",
                        direction: .incoming,
                        messageHash: message.hash,
                        transactionHash: transaction.hash
                    ),
                    traceID: traceID,
                    externalMessageHash: externalMessageHash,
                    transactionHash: transactionHash,
                    logicalTime: logicalTime,
                    timestamp: timestamp,
                    direction: .incoming,
                    asset: .jetton(wallet: jettonWallet),
                    amount: payload.amount,
                    fee: totalFee,
                    counterparty: payload.sender,
                    counterpartyName: addressName(payload.sender, in: addressBook),
                    comment: nonEmptyString(payload.comment),
                    status: status
                )]
            }
        }
        if containsJettonOperation {
            // Do not misrepresent the service TON attached to a malformed jetton call as a send.
            return []
        }

        for transaction in walletTransactions {
            for message in transaction.outMessages {
                guard let payload = TransferPayloadDecoder.nftTransfer(from: message),
                      let item = parsedAddress(message.destination) else {
                    continue
                }
                return [WalletActivity(
                    id: messageID(
                        kind: "nft",
                        direction: .outgoing,
                        messageHash: message.hash,
                        transactionHash: transaction.hash,
                        disambiguator: item.rawString.lowercased()
                    ),
                    traceID: traceID,
                    externalMessageHash: externalMessageHash,
                    transactionHash: transactionHash,
                    logicalTime: logicalTime,
                    timestamp: timestamp,
                    direction: .outgoing,
                    asset: .nft(item: item),
                    amount: 0,
                    fee: totalFee,
                    counterparty: payload.newOwner,
                    counterpartyName: addressName(payload.newOwner, in: addressBook),
                    comment: nonEmptyString(payload.comment),
                    status: status
                )]
            }
            if let message = transaction.inMessage,
               let payload = TransferPayloadDecoder.nftOwnershipAssigned(from: message),
               let item = parsedAddress(message.source) {
                return [WalletActivity(
                    id: messageID(
                        kind: "nft",
                        direction: .incoming,
                        messageHash: message.hash,
                        transactionHash: transaction.hash,
                        disambiguator: item.rawString.lowercased()
                    ),
                    traceID: traceID,
                    externalMessageHash: externalMessageHash,
                    transactionHash: transactionHash,
                    logicalTime: logicalTime,
                    timestamp: timestamp,
                    direction: .incoming,
                    asset: .nft(item: item),
                    amount: 0,
                    fee: totalFee,
                    counterparty: payload.previousOwner,
                    counterpartyName: addressName(payload.previousOwner, in: addressBook),
                    comment: nonEmptyString(payload.comment),
                    status: status
                )]
            }
        }

        var result: [WalletActivity] = []
        var didAssignFee = false
        for transaction in walletTransactions {
            if let message = transaction.inMessage,
               parsedAddress(message.source) != walletAddress,
               MessageClassifier.classify(message) == .tonTransfer,
               let amount = positiveAmount(message.value) {
                let counterparty = parsedAddress(message.source)
                result.append(WalletActivity(
                    id: messageID(
                        kind: "ton",
                        direction: .incoming,
                        messageHash: message.hash,
                        transactionHash: transaction.hash
                    ),
                    traceID: traceID,
                    externalMessageHash: externalMessageHash,
                    transactionHash: transaction.hash,
                    logicalTime: transaction.logicalTime,
                    timestamp: transaction.now,
                    direction: .incoming,
                    asset: .ton,
                    amount: amount,
                    fee: didAssignFee ? 0 : totalFee,
                    counterparty: counterparty,
                    counterpartyName: counterparty.flatMap { addressName($0, in: addressBook) },
                    comment: nonEmptyString(message.comment),
                    status: status
                ))
                didAssignFee = true
            }
            for message in transaction.outMessages
            where parsedAddress(message.destination) != walletAddress
                && MessageClassifier.classify(message) == .tonTransfer {
                guard let amount = positiveAmount(message.value) else { continue }
                let counterparty = parsedAddress(message.destination)
                result.append(WalletActivity(
                    id: messageID(
                        kind: "ton",
                        direction: .outgoing,
                        messageHash: message.hash,
                        transactionHash: transaction.hash
                    ),
                    traceID: traceID,
                    externalMessageHash: externalMessageHash,
                    transactionHash: transaction.hash,
                    logicalTime: transaction.logicalTime,
                    timestamp: transaction.now,
                    direction: .outgoing,
                    asset: .ton,
                    amount: amount,
                    fee: didAssignFee ? 0 : totalFee,
                    counterparty: counterparty,
                    counterpartyName: counterparty.flatMap { addressName($0, in: addressBook) },
                    comment: nonEmptyString(message.comment),
                    status: status
                ))
                didAssignFee = true
            }
        }
        return result
    }

    private static func messageID(
        kind: String,
        direction: WalletActivity.Direction,
        messageHash: String?,
        transactionHash: String,
        disambiguator: String? = nil
    ) -> String {
        var result = "message:\(kind):\(direction == .incoming ? "in" : "out"):\(messageHash ?? transactionHash)"
        if let disambiguator {
            result += ":\(disambiguator)"
        }
        return result
    }

    private static func parsedAddress(_ value: String?) -> Address? {
        guard let value else { return nil }
        return try? Address.parse(value)
    }

    private static func positiveAmount(_ value: String?) -> BigUInt? {
        guard let value, let amount = BigUInt(value, radix: 10), !amount.isZero else { return nil }
        return amount
    }

    private static func addressName(_ address: Address, in addressBook: [String: String]) -> String? {
        let value = addressBook.first { key, _ in
            parsedAddress(key) == address
        }?.value
        guard let value = nonEmptyString(value), (try? Address.parse(value)) == nil else { return nil }
        return value
    }

    private static func nonEmptyString(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
