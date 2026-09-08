import Foundation
import Postbox
import SwiftSignalKit

public struct WalletPendingTransferMessageReference: Codable, Equatable, Sendable {
    public let peerId: Int64
    public let localId: Int32
    public let operationId: String

    init(id: MessageId, operationId: String) {
        self.peerId = id.peerId.toInt64()
        self.localId = id.id
        self.operationId = operationId
    }

    var messageId: MessageId {
        return MessageId(peerId: PeerId(self.peerId), namespace: Namespaces.Message.Local, id: self.localId)
    }
}

func pendingWalletTransferTimestamp() -> Int32 {
    return Int32(clamping: Int64(Date().timeIntervalSince1970))
}

private func walletStoreMessage(_ message: Message) -> StoreMessage {
    var forwardInfo: StoreMessageForwardInfo?
    if let current = message.forwardInfo {
        forwardInfo = StoreMessageForwardInfo(authorId: current.author?.id, sourceId: current.source?.id, sourceMessageId: current.sourceMessageId, date: current.date, authorSignature: current.authorSignature, psaType: current.psaType, flags: current.flags)
    }
    return StoreMessage(id: message.id, customStableId: nil, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, threadId: message.threadId, timestamp: message.timestamp, flags: StoreMessageFlags(message.flags), tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: forwardInfo, authorId: message.author?.id, text: message.text, attributes: message.attributes, media: message.media)
}

private func findWalletMessage(transaction: Transaction, peerId: PeerId, namespace: MessageId.Namespace, afterId: Int32 = 0, matches: (Message) -> Bool) -> Message? {
    var from = MessageIndex.upperBound(peerId: peerId, namespace: namespace)
    let to = MessageIndex.lowerBound(peerId: peerId, namespace: namespace)
    while true {
        let messages = transaction.getMessages(peerId: peerId, namespace: namespace, from: from, includeFrom: false, to: to, limit: 100)
        if let message = messages.first(where: { $0.id.id > afterId && matches($0) }) {
            return message
        }
        guard let oldest = messages.min(by: { $0.index < $1.index }), oldest.id.id > afterId else {
            return nil
        }
        from = oldest.index
    }
}

func updatePendingWalletTransferMessage(transaction: Transaction, id: MessageId, attribute: PendingWalletTransferMessageAttribute) {
    guard let message = transaction.getMessage(id),
          message.attributes.contains(where: { ($0 as? PendingWalletTransferMessageAttribute)?.operationId == attribute.operationId }) else {
        return
    }
    let attributes = message.attributes.filter { !($0 is PendingWalletTransferMessageAttribute) } + [attribute]
    transaction.updateMessage(id, update: { _ in
        return .update(walletStoreMessage(message).withUpdatedAttributes(attributes))
    })
    transaction.setPendingMessageAction(type: .walletTransfer, id: id, action: attribute)
}

func removePendingWalletTransferMessage(transaction: Transaction, id: MessageId) {
    transaction.setPendingMessageAction(type: .walletTransfer, id: id, action: nil)
    guard id.namespace == Namespaces.Message.Local,
          let message = transaction.getMessage(id),
          message.attributes.contains(where: { $0 is PendingWalletTransferMessageAttribute }) else {
        return
    }
    transaction.deleteMessages([id], forEachMedia: nil)
}

private func walletTransferTransactionHash(_ transactionId: String) -> Data? {
    // wallet.Transaction.id is "lt:hash", whereas messageActionGramTransfer carries
    // only the transaction hash. Preserve the full id in storage for wallet APIs.
    let parts = transactionId.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
    let hash: String
    if parts.count == 2 {
        guard UInt64(parts[0]) != nil else {
            return nil
        }
        hash = String(parts[1])
    } else {
        hash = transactionId
    }
    guard let data = Data(base64Encoded: hash), data.count == 32 else {
        return nil
    }
    return data
}

func walletTransferMessageMatches(_ message: StoreMessage, peerId: PeerId, transactionId: String) -> Bool {
    guard case let .Id(id) = message.id,
          id.namespace == Namespaces.Message.Cloud, id.peerId == peerId,
          !message.flags.contains(.Incoming), message.forwardInfo == nil,
          !transactionId.isEmpty else {
        return false
    }
    return message.media.contains(where: { media in
        guard let action = media as? TelegramMediaAction,
              case let .gramTransfer(_, _, id, _, _) = action.action else {
            return false
        }
        if id == transactionId {
            return true
        }
        guard let messageHash = walletTransferTransactionHash(id),
              let pendingHash = walletTransferTransactionHash(transactionId) else {
            return false
        }
        return messageHash == pendingHash
    })
}

@discardableResult
func replacePendingWalletTransferMessage(transaction: Transaction, localId: MessageId, serverMessage: StoreMessage) -> Bool {
    guard let pending = transaction.getPendingMessageAction(type: .walletTransfer, id: localId) as? PendingWalletTransferMessageAttribute,
          let transactionId = pending.transactionId,
          walletTransferMessageMatches(serverMessage, peerId: localId.peerId, transactionId: transactionId),
          let localMessage = transaction.getMessage(localId),
          localMessage.attributes.contains(where: { ($0 as? PendingWalletTransferMessageAttribute)?.operationId == pending.operationId }),
          case let .Id(serverId) = serverMessage.id else {
        return false
    }
    guard pending.expiresAt > pendingWalletTransferTimestamp() else {
        removePendingWalletTransferMessage(transaction: transaction, id: localId)
        return false
    }
    // The hook runs after insertion, in the same Postbox transaction. Remove the server
    // copy before changing the local id so Postbox retains the local stable id.
    transaction.setPendingMessageAction(type: .walletTransfer, id: localId, action: nil)
    transaction.deleteMessages([serverId], forEachMedia: nil)
    transaction.updateMessage(localId, update: { _ in
        return .update(serverMessage.withUpdatedCustomStableId(localMessage.stableId))
    })
    return true
}

func reconcileStoredWalletTransferMessage(transaction: Transaction, id: MessageId, pending: PendingWalletTransferMessageAttribute) {
    guard let transactionId = pending.transactionId else {
        return
    }
    if let message = findWalletMessage(transaction: transaction, peerId: id.peerId, namespace: Namespaces.Message.Cloud, afterId: pending.previousMessageId, matches: {
        walletTransferMessageMatches(walletStoreMessage($0), peerId: id.peerId, transactionId: transactionId)
    }) {
        replacePendingWalletTransferMessage(transaction: transaction, localId: id, serverMessage: walletStoreMessage(message))
    }
}

func _internal_createPendingWalletTransferMessage(account: Account, peerId: PeerId, operationId: String, amount: Int64, address: String, comment: String?, commentEncrypted: Bool, timestamp: Int32) -> Signal<WalletPendingTransferMessageReference?, NoError> {
    return account.postbox.transaction { transaction in
        return createPendingWalletTransferMessage(transaction: transaction, accountPeerId: account.peerId, peerId: peerId, operationId: operationId, amount: amount, address: address, comment: comment, commentEncrypted: commentEncrypted, timestamp: timestamp)
    }
}

func createPendingWalletTransferMessage(transaction: Transaction, accountPeerId: PeerId, peerId: PeerId, operationId: String, amount: Int64, address: String, comment: String?, commentEncrypted: Bool, timestamp: Int32) -> WalletPendingTransferMessageReference? {
    guard peerId.namespace == Namespaces.Peer.CloudUser, amount > 0,
          let peer = transaction.getPeer(peerId) as? TelegramUser, peer.botInfo == nil else {
        return nil
    }
    if let existing = findWalletMessage(transaction: transaction, peerId: peerId, namespace: Namespaces.Message.Local, matches: { message in
        message.attributes.contains(where: { ($0 as? PendingWalletTransferMessageAttribute)?.operationId == operationId })
    }) {
        return WalletPendingTransferMessageReference(id: existing.id, operationId: operationId)
    }
    let attribute = PendingWalletTransferMessageAttribute(
        operationId: operationId,
        expiresAt: Int32(clamping: Int64(timestamp) + 90),
        previousMessageId: transaction.getTopPeerMessageId(peerId: peerId, namespace: Namespaces.Message.Cloud)?.id ?? 0
    )
    let uniqueId = Int64.random(in: Int64.min ... Int64.max)
    let message = StoreMessage(peerId: peerId, namespace: Namespaces.Message.Local, customStableId: nil, globallyUniqueId: uniqueId, groupingKey: nil, threadId: nil, timestamp: timestamp, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: accountPeerId, text: "", attributes: [attribute], media: [
        TelegramMediaAction(action: .gramTransfer(amount: amount, peerAddress: address, transactionId: "", comment: comment, commentEncrypted: commentEncrypted))
    ])
    guard let id = transaction.addMessages([message], location: .Random)[uniqueId] else {
        return nil
    }
    transaction.setPendingMessageAction(type: .walletTransfer, id: id, action: attribute)
    updatePeerChatInclusionWithMinTimestamp(transaction: transaction, id: peerId, minTimestamp: timestamp, forceRootGroupIfNotExists: true)
    return WalletPendingTransferMessageReference(id: id, operationId: operationId)
}

func _internal_acceptPendingWalletTransferMessage(postbox: Postbox, reference: WalletPendingTransferMessageReference, transfer: WalletSentTransfer, receivedAt: Int32) -> Signal<Void, NoError> {
    return postbox.transaction { transaction in
        guard let pending = transaction.getPendingMessageAction(type: .walletTransfer, id: reference.messageId) as? PendingWalletTransferMessageAttribute,
              pending.operationId == reference.operationId else {
            return
        }
        guard pending.expiresAt > pendingWalletTransferTimestamp() else {
            removePendingWalletTransferMessage(transaction: transaction, id: reference.messageId)
            return
        }
        updatePendingWalletTransferMessage(transaction: transaction, id: reference.messageId, attribute: pending.accepting(msgHash: transfer.msgHash, receivedAt: receivedAt))
    }
}

func _internal_removePendingWalletTransferMessage(postbox: Postbox, reference: WalletPendingTransferMessageReference) -> Signal<Void, NoError> {
    return postbox.transaction { transaction in
        guard let pending = transaction.getPendingMessageAction(type: .walletTransfer, id: reference.messageId) as? PendingWalletTransferMessageAttribute,
              pending.operationId == reference.operationId else {
            return
        }
        removePendingWalletTransferMessage(transaction: transaction, id: reference.messageId)
    }
}
