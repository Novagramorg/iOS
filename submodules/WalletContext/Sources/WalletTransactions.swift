import Foundation
import TelegramCore
import SwiftSignalKit
import WalletEngineFFI

let walletTransactionFetchLimit = 50

struct WalletPeerAddressMapping: @unchecked Sendable {
    let peer: EnginePeer
    let address: String
}

struct ResolvedTransferInput {
    let address: String
    let amount: Int64
    let body: SendMessageBody
    let comment: String?
    let expiration: SendExpiration
}

func resolveTransferInput(address: String, amount: Int64, comment: String?) throws -> ResolvedTransferInput {
    let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
    let link: ParsedTonTransferLink?
    if trimmed.lowercased().hasPrefix("ton://") {
        do {
            link = try parseTonTransferLink(value: trimmed)
        } catch {
            throw WalletContext.WalletError.invalidAddress
        }
    } else {
        link = nil
    }

    let recipient = link?.recipient ?? trimmed
    guard let info = try? parseTonAddress(value: recipient), !isTestnetAddress(info.format),
          let normalized = try? convertTonAddress(
            value: recipient,
            format: .userFriendly(bounceable: false, testnet: false)
          ) else {
        throw WalletContext.WalletError.invalidAddress
    }

    if let link {
        guard case .gram = link.asset else {
            throw WalletContext.WalletError.invalidAddress
        }
    }

    var resolvedAmount = amount
    if resolvedAmount <= 0, let linkAmount = link?.amount {
        guard let parsed = Int64(linkAmount) else {
            throw WalletContext.WalletError.invalidAmount
        }
        resolvedAmount = parsed
    }
    guard resolvedAmount > 0 else {
        throw WalletContext.WalletError.invalidAmount
    }

    let explicitComment = comment?.trimmingCharacters(in: .whitespacesAndNewlines)
    let linkComment: String?
    let linkBody: SendMessageBody
    if let payload = link?.payload {
        switch payload {
        case .none:
            linkComment = nil
            linkBody = .empty
        case let .text(text):
            linkComment = text
            linkBody = .comment(text: text)
        case let .boc(boc):
            linkComment = nil
            linkBody = .rawPayload(boc: boc)
        }
    } else {
        linkComment = nil
        linkBody = .empty
    }
    let resolvedComment = (explicitComment?.isEmpty == false ? explicitComment : nil) ?? linkComment
    let body: SendMessageBody
    if let resolvedComment {
        body = .comment(text: resolvedComment)
    } else {
        body = linkBody
    }
    return ResolvedTransferInput(
        address: normalized,
        amount: resolvedAmount,
        body: body,
        comment: resolvedComment,
        expiration: link?.expiration ?? .engineDefault
    )
}

private func isTestnetAddress(_ format: TonAddressFormat) -> Bool {
    switch format {
    case .raw:
        return false
    case let .userFriendly(_, testnet):
        return testnet
    }
}

func walletTransactions(
    from transactions: [TelegramCore.WalletTransaction]
) -> [WalletContext.Transaction] {
    var seenIds = Set<String>()
    var result: [WalletContext.Transaction] = []
    result.reserveCapacity(transactions.count)
    for transaction in transactions {
        guard seenIds.insert(transaction.id).inserted else {
            continue
        }
        let peer: WalletContext.Transaction.Peer
        switch transaction.peer {
        case let .user(enginePeer, address, domain):
            peer = .user(enginePeer, address: address, domain: domain)
        case let .address(address, domain):
            peer = .address(address, domain: domain)
        case .unsupported:
            peer = .unsupported
        }

        let status: WalletContext.Transaction.Status = transaction.failed ? .failed : .completed
        let logicalTime = transaction.id.split(separator: ":", maxSplits: 1).first.map(String.init)
            ?? transaction.id
        result.append(WalletContext.Transaction(
            id: transaction.id,
            transactionHash: transaction.txHash,
            logicalTime: logicalTime,
            timestamp: transaction.date,
            direction: transaction.incoming ? .incoming : .outgoing,
            amount: transaction.amount,
            fee: transaction.fee,
            peer: peer,
            comment: transaction.comment,
            status: status
        ))
    }
    return result
}

func walletTransactions(
    from transactions: [WalletStoredTransaction],
    engine: TelegramEngine
) async throws -> [WalletContext.Transaction] {
    let peerIds = Array(Set(transactions.compactMap { $0.peer.userId }))
    guard !peerIds.isEmpty else {
        return transactions.map { $0.transaction(peers: [:]) }
    }
    let values = try await WalletSignalRequestContext<[EnginePeer.Id: EnginePeer?]>().run(
        engine.data.get(EngineDataMap(
            peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:))
        ))
        |> castError(WalletContext.WalletError.self)
    )
    var peers: [EnginePeer.Id: EnginePeer] = [:]
    for (id, peer) in values {
        if let peer {
            peers[id] = peer
        }
    }
    return transactions.map { $0.transaction(peers: peers) }
}

func mergeTransactions(
    existing: [WalletContext.Transaction],
    new: [WalletContext.Transaction]
) -> [WalletContext.Transaction] {
    var values: [String: WalletContext.Transaction] = [:]
    for transaction in existing + new {
        let key = walletTransactionMergeKey(transaction)
        if let current = values[key] {
            let currentScore = transactionInformationScore(current)
            let candidateScore = transactionInformationScore(transaction)
            if candidateScore >= currentScore {
                values[key] = transaction
            }
        } else {
            values[key] = transaction
        }
    }
    return sortedWalletTransactions(Array(values.values))
}

func walletPendingTransferTransaction(
    _ pending: WalletContext.PendingTransfer
) -> WalletContext.Transaction? {
    guard pending.collectibleAddress == nil, pending.amount > 0 else {
        return nil
    }
    let status: WalletContext.Transaction.Status
    switch pending.status {
    case .broadcasting:
        return nil
    case .pending, .submissionUnknown:
        status = .pending
    case .confirmed:
        status = .completed
    }
    return WalletContext.Transaction(
        id: "pending:\(pending.id)",
        presentationId: "pending:\(pending.id)",
        transactionHash: pending.transactionHash,
        logicalTime: pending.transactionLt ?? "0",
        timestamp: pending.createdAt,
        direction: .outgoing,
        amount: -pending.amount,
        fee: pending.fee ?? 0,
        peer: .address(pending.recipient, domain: nil),
        comment: pending.comment,
        status: status
    )
}

func transactionsWithStreamingOverlay(
    authoritative: [WalletContext.Transaction],
    streaming: [WalletContext.Transaction],
    peerByAddress: [String: EnginePeer]
) -> [WalletContext.Transaction] {
    var values: [String: WalletContext.Transaction] = [:]
    for transaction in streaming {
        let resolved = transactionWithResolvedStreamingPeer(
            transaction,
            peerByAddress: peerByAddress
        )
        values[walletTransactionMergeKey(resolved)] = resolved
    }
    for transaction in authoritative {
        values[walletTransactionMergeKey(transaction)] = transaction
    }
    return sortedWalletTransactions(Array(values.values))
}

func walletAddressMappingKey(_ address: String) -> String? {
    let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, let info = try? parseTonAddress(value: trimmed) else {
        return nil
    }
    if case let .userFriendly(_, testnet) = info.format, testnet {
        return nil
    }
    return try? convertTonAddress(value: trimmed, format: .raw).lowercased()
}

private func transactionWithResolvedStreamingPeer(
    _ transaction: WalletContext.Transaction,
    peerByAddress: [String: EnginePeer]
) -> WalletContext.Transaction {
    guard case let .address(address, domain) = transaction.peer,
          let key = walletAddressMappingKey(address),
          let peer = peerByAddress[key] else {
        return transaction
    }
    return WalletContext.Transaction(
        id: transaction.id,
        presentationId: transaction.presentationId,
        transactionHash: transaction.transactionHash,
        logicalTime: transaction.logicalTime,
        timestamp: transaction.timestamp,
        direction: transaction.direction,
        amount: transaction.amount,
        fee: transaction.fee,
        peer: .user(peer, address: address, domain: domain),
        comment: transaction.comment,
        currency: transaction.currency,
        collectible: transaction.collectible,
        status: transaction.status,
        kind: transaction.kind
    )
}

func walletTransactionWithPresentationId(
    _ transaction: WalletContext.Transaction,
    presentationId: String
) -> WalletContext.Transaction {
    guard transaction.presentationId != presentationId else {
        return transaction
    }
    return WalletContext.Transaction(
        id: transaction.id,
        presentationId: presentationId,
        transactionHash: transaction.transactionHash,
        logicalTime: transaction.logicalTime,
        timestamp: transaction.timestamp,
        direction: transaction.direction,
        amount: transaction.amount,
        fee: transaction.fee,
        peer: transaction.peer,
        comment: transaction.comment,
        currency: transaction.currency,
        collectible: transaction.collectible,
        status: transaction.status,
        kind: transaction.kind
    )
}

func walletTransactionMergeKey(_ transaction: WalletContext.Transaction) -> String {
    transaction.transactionHash ?? transaction.id
}

private func sortedWalletTransactions(
    _ transactions: [WalletContext.Transaction]
) -> [WalletContext.Transaction] {
    transactions.sorted { lhs, rhs in
        if lhs.timestamp != rhs.timestamp {
            return lhs.timestamp > rhs.timestamp
        }
        return decimalStringIsGreater(lhs.logicalTime, rhs.logicalTime)
    }
}

private func transactionInformationScore(_ value: WalletContext.Transaction) -> Int {
    var score = value.status == .completed ? 100 : 0
    if value.peer.displayName != nil { score += 4 }
    if value.peer.domain != nil { score += 2 }
    if value.comment != nil { score += 1 }
    return score
}

private func decimalStringIsGreater(_ lhs: String, _ rhs: String) -> Bool {
    let left = normalizedUnsignedDecimal(lhs)
    let right = normalizedUnsignedDecimal(rhs)
    guard let left, let right else {
        return lhs > rhs
    }
    if left.count != right.count {
        return left.count > right.count
    }
    return left > right
}

private func normalizedUnsignedDecimal(_ value: String) -> String? {
    guard !value.isEmpty, value.allSatisfy(\.isNumber) else {
        return nil
    }
    let trimmed = value.drop(while: { $0 == "0" })
    return trimmed.isEmpty ? "0" : String(trimmed)
}
