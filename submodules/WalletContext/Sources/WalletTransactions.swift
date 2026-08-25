import Foundation
import TONCore
import TONWalletKit

let walletTransactionFetchLimit = 30
let walletPreparedTransferLifetime: TimeInterval = 5.0 * 60.0
let walletPendingTransferLifetime: Int64 = 10 * 60
let walletUsdtJettonMasterAddress = "EQCxE6mUtQJKFnGfaROTKOt1lZbDiiX1kCixRv7Nw2Id_sDs"

struct ResolvedTransferInput {
    let address: String
    let amount: Int64
    let comment: String?
}

func resolveTransferInput(address: String, amount: Int64, comment: String?) throws -> ResolvedTransferInput {
    let transfer: TransferURL
    do {
        transfer = try TransferURL.parse(address)
    } catch TransferURLError.invalidAmount(_) {
        throw WalletContext.WalletError.invalidAmount
    } catch {
        throw WalletContext.WalletError.invalidAddress
    }

    var resolvedAmount = amount
    if resolvedAmount <= 0, let linkAmount = transfer.amount {
        guard let parsed = Int64(String(linkAmount)) else {
            throw WalletContext.WalletError.invalidAmount
        }
        resolvedAmount = parsed
    }
    guard resolvedAmount > 0 else {
        throw WalletContext.WalletError.invalidAmount
    }

    let resolvedComment = nonEmptyString(comment?.trimmingCharacters(in: .whitespacesAndNewlines))
        ?? transfer.text
    return ResolvedTransferInput(
        address: transfer.addressString(),
        amount: resolvedAmount,
        comment: resolvedComment
    )
}

enum WalletDataError: Error {
    case invalidData
}

func walletTransactions(
    from activities: [WalletActivity],
    usdtJettonWalletAddress: String?,
    collectibles: [String: WalletContext.Transaction.CollectibleTransfer]
) throws -> [WalletContext.Transaction] {
    let usdtJettonWallet = usdtJettonWalletAddress.flatMap { try? Address.parse($0) }
    var result: [WalletContext.Transaction] = []
    result.reserveCapacity(activities.count)

    for activity in activities {
        guard let fee = Int64(String(activity.fee)) else {
            throw WalletDataError.invalidData
        }

        let direction: WalletContext.Transaction.Direction
        switch activity.direction {
        case .incoming:
            direction = .incoming
        case .outgoing:
            direction = .outgoing
        }

        let status: WalletContext.Transaction.Status
        switch activity.status {
        case .pending:
            status = .pending
        case .completed:
            status = .completed
        }

        let kind: WalletContext.Transaction.Kind
        switch activity.kind {
        case .transfer:
            kind = .transfer
        case .deployContract:
            kind = .deployContract
        }

        let counterparty = activity.counterparty?.toString(bounceable: false)
        let amount: Int64
        let currency: WalletContext.Transaction.Currency
        let collectible: WalletContext.Transaction.CollectibleTransfer?
        let timestamp: Int32

        switch activity.asset {
        case .ton:
            guard let value = Int64(String(activity.amount)) else { continue }
            amount = value
            currency = .ton
            collectible = nil
            timestamp = Int32(clamping: activity.timestamp)
        case let .jetton(wallet):
            guard let usdtJettonWallet,
                  wallet == usdtJettonWallet,
                  let value = Int64(String(activity.amount)) else {
                continue
            }
            amount = value
            currency = .usdt
            collectible = nil
            guard let value = Int32(exactly: activity.timestamp) else {
                throw WalletDataError.invalidData
            }
            timestamp = value
        case let .nft(item):
            amount = 0
            currency = .ton
            let address = item.toString(bounceable: false)
            collectible = collectibles[item.rawString.lowercased()]
                ?? fallbackCollectible(address: address)
            guard let value = Int32(exactly: activity.timestamp) else {
                throw WalletDataError.invalidData
            }
            timestamp = value
        }

        result.append(WalletContext.Transaction(
            id: activity.id,
            transactionHash: activity.transactionHash,
            externalMessageHash: activity.externalMessageHash,
            logicalTime: activity.logicalTime,
            timestamp: timestamp,
            direction: direction,
            amount: amount,
            fee: fee,
            counterparty: counterparty,
            counterpartyName: activity.counterpartyName,
            comment: activity.comment,
            currency: currency,
            collectible: collectible,
            status: status,
            kind: kind
        ))
    }
    return result
}

func collectibleAddresses(in activities: [WalletActivity]) -> [String] {
    var result = Set<String>()
    for activity in activities {
        if case let .nft(item) = activity.asset {
            result.insert(item.rawString.lowercased())
        }
    }
    return Array(result)
}

private func fallbackCollectible(address: String) -> WalletContext.Transaction.CollectibleTransfer {
    WalletContext.Transaction.CollectibleTransfer(
        address: address,
        name: "NFT",
        imageUrl: nil,
        kind: .other
    )
}

private func rawAddress(_ value: String?) -> String? {
    guard let value else { return nil }
    return try? Address.parse(value).rawString.lowercased()
}

func mergeTransactions(
    existing: [WalletContext.Transaction],
    new: [WalletContext.Transaction]
) -> [WalletContext.Transaction] {
    var actionTransactionKeys = Set<String>()
    actionTransactionKeys.reserveCapacity(existing.count + new.count)
    for transaction in existing where transaction.transactionHash != nil {
        actionTransactionKeys.insert(transactionBlockchainKey(transaction))
    }
    for transaction in new where transaction.transactionHash != nil {
        actionTransactionKeys.insert(transactionBlockchainKey(transaction))
    }

    var transactionsByKey: [String: WalletContext.Transaction] = [:]
    transactionsByKey.reserveCapacity(existing.count + new.count)
    func insert(_ transaction: WalletContext.Transaction) {
        if transaction.transactionHash == nil,
           actionTransactionKeys.contains(transactionBlockchainKey(transaction)) {
            return
        }
        let key = transactionKey(transaction)
        if let current = transactionsByKey[key] {
            transactionsByKey[key] = preferredTransaction(current, over: transaction)
        } else {
            transactionsByKey[key] = transaction
        }
    }
    existing.forEach(insert)
    new.forEach(insert)
    return transactionsByKey.values.sorted { lhs, rhs in
        if lhs.timestamp != rhs.timestamp { return lhs.timestamp > rhs.timestamp }
        return logicalTimeIsGreater(lhs.logicalTime, than: rhs.logicalTime)
    }
}

func transactionKey(_ transaction: WalletContext.Transaction) -> String {
    let id = transactionHashKey(transaction.id)

    // TON transfers can share a transaction (batch sends), so retain their message-level
    // identity. This also recognizes the previous `trace:...:ton:<direction>:<hash>` format and
    // immediately removes duplicates already present in the current transaction list.
    for marker in [":ton:in:", ":ton:out:"] {
        if let range = id.range(of: marker, options: .backwards) {
            let messageHash = id[range.upperBound...]
            if !messageHash.isEmpty {
                return "message\(marker)\(messageHash)"
            }
        }
    }

    guard let transactionHash = transaction.transactionHash else {
        return id
    }
    let blockchainKey = transactionHashKey(transactionHash)
    if transaction.kind == .deployContract {
        let addressKey = transaction.counterparty.flatMap { rawAddress($0) }
            ?? transaction.counterparty.map(transactionHashKey)
            ?? "unknown"
        return "transaction:\(blockchainKey):deploy:\(addressKey)"
    }
    if let collectible = transaction.collectible {
        let itemKey = rawAddress(collectible.address) ?? transactionHashKey(collectible.address)
        return "transaction:\(blockchainKey):nft:\(transaction.direction.rawValue):\(itemKey)"
    }
    return "transaction:\(blockchainKey):\(transaction.currency.rawValue):\(transaction.direction.rawValue)"
}

private func preferredTransaction(
    _ lhs: WalletContext.Transaction,
    over rhs: WalletContext.Transaction
) -> WalletContext.Transaction {
    let lhsScore = transactionInformationScore(lhs)
    let rhsScore = transactionInformationScore(rhs)
    return lhsScore > rhsScore ? lhs : rhs
}

private func transactionInformationScore(_ transaction: WalletContext.Transaction) -> Int {
    var score = transaction.status == .completed ? 100 : 0
    if transaction.counterpartyName != nil { score += 4 }
    if let collectible = transaction.collectible {
        if collectible.name != "NFT" { score += 2 }
        if collectible.imageUrl != nil { score += 1 }
        if collectible.collectionName != nil { score += 1 }
    }
    return score
}

func transactionBlockchainKey(_ transaction: WalletContext.Transaction) -> String {
    transactionHashKey(transaction.transactionHash ?? transaction.id)
}

func transactionHashKey(_ value: String) -> String {
    value.lowercased()
}

func transactionTraceKey(_ value: String) -> String {
    value.lowercased()
}

private func logicalTimeIsGreater(_ lhs: String, than rhs: String) -> Bool {
    guard let normalizedLhs = normalizedUnsignedDecimal(lhs),
          let normalizedRhs = normalizedUnsignedDecimal(rhs) else {
        return lhs > rhs
    }
    if normalizedLhs.count != normalizedRhs.count { return normalizedLhs.count > normalizedRhs.count }
    return normalizedLhs > normalizedRhs
}

private func normalizedUnsignedDecimal(_ value: String) -> String? {
    let bytes = Array(value.utf8)
    guard !bytes.isEmpty, bytes.allSatisfy({ (48 ... 57).contains($0) }) else { return nil }
    let firstNonZero = bytes.firstIndex(where: { $0 != 48 }) ?? bytes.count
    if firstNonZero == bytes.count { return "0" }
    return String(decoding: bytes[firstNonZero...], as: UTF8.self)
}

private func nonEmptyString(_ value: String?) -> String? {
    guard let value, !value.isEmpty else { return nil }
    return value
}
