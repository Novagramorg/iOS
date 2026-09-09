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

private func walletStoreMessage(_ message: Message) -> StoreMessage {
    var forwardInfo: StoreMessageForwardInfo?
    if let current = message.forwardInfo {
        forwardInfo = StoreMessageForwardInfo(authorId: current.author?.id, sourceId: current.source?.id, sourceMessageId: current.sourceMessageId, date: current.date, authorSignature: current.authorSignature, psaType: current.psaType, flags: current.flags)
    }
    return StoreMessage(id: message.id, customStableId: nil, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, threadId: message.threadId, timestamp: message.timestamp, flags: StoreMessageFlags(message.flags), tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: forwardInfo, authorId: message.author?.id, text: message.text, attributes: message.attributes, media: message.media)
}

private func findWalletMessage(transaction: Transaction, peerId: PeerId, namespace: MessageId.Namespace, afterId: Int32 = 0, unique: Bool = false, matches: (Message) -> Bool) -> Message? {
    var result: Message?
    var from = MessageIndex.upperBound(peerId: peerId, namespace: namespace)
    let to = MessageIndex.lowerBound(peerId: peerId, namespace: namespace)
    while true {
        let messages = transaction.getMessages(peerId: peerId, namespace: namespace, from: from, includeFrom: false, to: to, limit: 100)
        for message in messages where message.id.id > afterId && matches(message) {
            if !unique { return message }
            guard result == nil else { return nil }
            result = message
        }
        guard let oldest = messages.min(by: { $0.index < $1.index }), oldest.id.id > afterId else {
            return result
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
          let transactionId = pending.resolvedMessageId,
          walletTransferMessageMatches(serverMessage, peerId: localId.peerId, transactionId: transactionId),
          let localMessage = transaction.getMessage(localId),
          localMessage.attributes.contains(where: { ($0 as? PendingWalletTransferMessageAttribute)?.operationId == pending.operationId }),
          case let .Id(serverId) = serverMessage.id else {
        return false
    }
    guard pending.expiresAt > Int32(clamping: Int64(Date().timeIntervalSince1970)) else {
        removePendingWalletTransferMessage(transaction: transaction, id: localId)
        return false
    }
    let conflictingLocal = findWalletMessage(transaction: transaction, peerId: localId.peerId, namespace: Namespaces.Message.Local, matches: { message in
        guard message.id != localId,
              let other = message.attributes.first(where: { $0 is PendingWalletTransferMessageAttribute }) as? PendingWalletTransferMessageAttribute,
              other.expiresAt > Int32(clamping: Int64(Date().timeIntervalSince1970)),
              let otherId = other.resolvedMessageId else { return false }
        return walletTransferMessageMatches(serverMessage, peerId: localId.peerId, transactionId: otherId)
    })
    guard conflictingLocal == nil else {
        return false
    }
    transaction.setPendingMessageAction(type: .walletTransfer, id: localId, action: nil)
    transaction.deleteMessages([serverId], forEachMedia: nil)
    transaction.updateMessage(localId, update: { _ in
        return .update(serverMessage.withUpdatedCustomStableId(localMessage.stableId))
    })
    return true
}

func reconcileStoredWalletTransferMessage(transaction: Transaction, id: MessageId, pending: PendingWalletTransferMessageAttribute) {
    guard let transactionId = pending.resolvedMessageId else {
        return
    }
    if let message = findWalletMessage(transaction: transaction, peerId: id.peerId, namespace: Namespaces.Message.Cloud, afterId: pending.previousMessageId, unique: true, matches: {
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
        guard pending.expiresAt > Int32(clamping: Int64(Date().timeIntervalSince1970)) else {
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

func _internal_hasUnresolvedPendingWalletTransferMessage(postbox: Postbox, reference: WalletPendingTransferMessageReference) -> Signal<Bool, NoError> {
    return postbox.transaction { transaction in
        guard let pending = transaction.getPendingMessageAction(type: .walletTransfer, id: reference.messageId) as? PendingWalletTransferMessageAttribute,
              pending.operationId == reference.operationId else { return false }
        return pending.expiresAt > Int32(clamping: Int64(Date().timeIntervalSince1970)) && pending.resolvedMessageId == nil
    }
}

func _internal_resolvePendingWalletTransferMessage(postbox: Postbox, reference: WalletPendingTransferMessageReference, transactionId: String, failed: Bool) -> Signal<Void, NoError> {
    return postbox.transaction { transaction in
        guard !transactionId.isEmpty,
              let pending = transaction.getPendingMessageAction(type: .walletTransfer, id: reference.messageId) as? PendingWalletTransferMessageAttribute,
              pending.operationId == reference.operationId else {
            return
        }
        guard pending.expiresAt > Int32(clamping: Int64(Date().timeIntervalSince1970)) else {
            removePendingWalletTransferMessage(transaction: transaction, id: reference.messageId)
            return
        }
        guard pending.chainTraceId == nil else {
            return
        }
        if failed {
            guard pending.transactionId == nil else {
                return
            }
            removePendingWalletTransferMessage(transaction: transaction, id: reference.messageId)
        } else {
            guard pending.transactionId == nil || pending.transactionId == transactionId else {
                return
            }
            let updated = pending.resolving(transactionId: transactionId)
            if !updated.isEqual(to: pending) {
                updatePendingWalletTransferMessage(transaction: transaction, id: reference.messageId, attribute: updated)
            }
            reconcileStoredWalletTransferMessage(transaction: transaction, id: reference.messageId, pending: updated)
        }
    }
}

func _internal_resolvePendingWalletTransferMessage(postbox: Postbox, reference: WalletPendingTransferMessageReference, chainTraceId: String) -> Signal<Void, NoError> {
    return postbox.transaction { transaction in
        guard chainTraceId.utf8.count == 44, let hash = Data(base64Encoded: chainTraceId), hash.count == 32,
              let pending = transaction.getPendingMessageAction(type: .walletTransfer, id: reference.messageId) as? PendingWalletTransferMessageAttribute,
              pending.operationId == reference.operationId,
              pending.chainTraceId == nil || pending.chainTraceId == chainTraceId else {
            return
        }
        guard pending.expiresAt > Int32(clamping: Int64(Date().timeIntervalSince1970)) else {
            removePendingWalletTransferMessage(transaction: transaction, id: reference.messageId)
            return
        }
        let updated = pending.resolving(chainTraceId: chainTraceId)
        if !updated.isEqual(to: pending) {
            updatePendingWalletTransferMessage(transaction: transaction, id: reference.messageId, attribute: updated)
        }
        reconcileStoredWalletTransferMessage(transaction: transaction, id: reference.messageId, pending: updated)
    }
}
