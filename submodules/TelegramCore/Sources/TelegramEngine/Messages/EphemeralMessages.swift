import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

private struct PreparedEphemeralMessageSend {
    let peerId: PeerId
    let localId: MessageId
    let botPeerId: PeerId
    let randomId: Int64
    let inputPeer: Api.InputPeer
    let inputUser: Api.InputUser
    let text: String
    let entities: [MessageTextEntity]
}

private func generateEphemeralLocalMessageId(peerId: PeerId, transaction: Transaction) -> MessageId {
    while true {
        var value: Int32 = 0
        arc4random_buf(&value, 4)
        if value == 0 {
            continue
        }
        let id: Int32
        if value == Int32.min {
            id = Int32.min
        } else {
            id = -abs(value)
        }
        let messageId = MessageId(peerId: peerId, namespace: Namespaces.Message.EphemeralLocal, id: id)
        if transaction.getMessage(messageId) == nil {
            return messageId
        }
    }
}

private func makeEphemeralStoreMessage(id: MessageId, accountPeerId: PeerId, botPeerId: PeerId, randomId: Int64, timestamp: Int32, text: String, entities: [MessageTextEntity], state: EphemeralOutgoingMessageAttribute.State) -> StoreMessage {
    var flags = StoreMessageFlags()
    if state == .sending {
        flags.insert(.Sending)
    }

    let attributes: [MessageAttribute] = [
        TextEntitiesMessageAttribute(entities: entities),
        OutgoingMessageInfoAttribute(uniqueId: randomId, flags: [], acknowledged: false, correlationId: nil, bubbleUpEmojiOrStickersets: [], partialReference: nil),
        EphemeralOutgoingMessageAttribute(botPeerId: botPeerId, randomId: randomId, state: state)
    ]

    return StoreMessage(
        id: id,
        customStableId: nil,
        globallyUniqueId: randomId,
        groupingKey: nil,
        threadId: nil,
        timestamp: timestamp,
        flags: flags,
        tags: [],
        globalTags: [],
        localTags: [],
        forwardInfo: nil,
        authorId: accountPeerId,
        text: text,
        attributes: attributes,
        media: []
    )
}

private func ephemeralOutgoingStoreMessageWithUpdatedState(_ message: Message, state: EphemeralOutgoingMessageAttribute.State) -> StoreMessage {
    var flags = StoreMessageFlags(message.flags)
    flags.remove(.Unsent)
    flags.remove(.Failed)
    if state == .sending {
        flags.insert(.Sending)
    } else {
        flags.remove(.Sending)
    }

    let attributes = message.attributes.map { attribute -> MessageAttribute in
        if let attribute = attribute as? EphemeralOutgoingMessageAttribute {
            return attribute.withUpdatedState(state)
        } else {
            return attribute
        }
    }

    return StoreMessage(id: message.id, customStableId: nil, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, threadId: message.threadId, timestamp: message.timestamp, flags: flags, tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo.flatMap(StoreMessageForwardInfo.init), authorId: message.author?.id, text: message.text, attributes: attributes, media: message.media)
}

private func preparedEphemeralMessageSend(account: Account, peerId: PeerId, botPeerId: PeerId, text: String, entities: [MessageTextEntity], randomId: Int64? = nil) -> Signal<PreparedEphemeralMessageSend?, NoError> {
    return account.postbox.transaction { transaction -> PreparedEphemeralMessageSend? in
        guard let peer = transaction.getPeer(peerId), let botPeer = transaction.getPeer(botPeerId), let inputPeer = apiInputPeer(peer), let inputUser = apiInputUser(botPeer) else {
            return nil
        }

        let randomId = randomId ?? Int64.random(in: Int64.min ... Int64.max)
        let localId = generateEphemeralLocalMessageId(peerId: peerId, transaction: transaction)
        let timestamp = Int32(account.network.context.globalTime())
        let message = makeEphemeralStoreMessage(id: localId, accountPeerId: account.peerId, botPeerId: botPeerId, randomId: randomId, timestamp: timestamp, text: text, entities: entities, state: .sending)
        let _ = transaction.addMessages([message], location: .Random)

        return PreparedEphemeralMessageSend(peerId: peerId, localId: localId, botPeerId: botPeerId, randomId: randomId, inputPeer: inputPeer, inputUser: inputUser, text: text, entities: entities)
    }
}

private func failPendingEphemeralMessage(account: Account, peerId: PeerId, localId: MessageId, randomId: Int64) -> Signal<MessageId?, NoError> {
    return account.postbox.transaction { transaction -> MessageId? in
        let pendingId = transaction.messageIdForGloballyUniqueMessageId(peerId: peerId, id: randomId) ?? localId
        transaction.updateMessage(pendingId, update: { currentMessage in
            return .update(ephemeralOutgoingStoreMessageWithUpdatedState(currentMessage, state: .failed))
        })
        return pendingId
    }
}

func _internal_failStaleEphemeralOutgoingMessages(postbox: Postbox) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        var messageIds: [MessageId] = []
        for peerId in Set(transaction.chatListGetAllPeerIds()) {
            transaction.scanMessageAttributes(peerId: peerId, namespace: Namespaces.Message.EphemeralLocal, limit: Int.max, { id, attributes in
                if attributes.contains(where: { attribute in
                    if let attribute = attribute as? EphemeralOutgoingMessageAttribute {
                        return attribute.state == .sending
                    } else {
                        return false
                    }
                }) {
                    messageIds.append(id)
                }
                return true
            })
        }

        for messageId in messageIds {
            transaction.updateMessage(messageId, update: { currentMessage in
                return .update(ephemeralOutgoingStoreMessageWithUpdatedState(currentMessage, state: .failed))
            })
        }
    }
}

private func completePendingEphemeralMessage(account: Account, prepared: PreparedEphemeralMessageSend, apiMessage: Api.EphemeralMessage) -> Signal<MessageId?, NoError> {
    return account.postbox.transaction { transaction -> MessageId? in
        let message = StoreMessage(apiEphemeralMessage: apiMessage)
        guard case let .Id(serverId) = message.id else {
            return nil
        }

        let pendingId = transaction.messageIdForGloballyUniqueMessageId(peerId: prepared.peerId, id: prepared.randomId) ?? prepared.localId
        let serverAlreadyExists = transaction.getMessage(serverId) != nil

        if serverAlreadyExists {
            if pendingId != serverId {
                transaction.deleteMessages([pendingId], forEachMedia: nil)
            }
            transaction.updateMessage(serverId, update: { _ in
                return .update(message)
            })
        } else if transaction.getMessage(pendingId) != nil {
            transaction.updateMessage(pendingId, update: { _ in
                return .update(message)
            })
        } else {
            let _ = transaction.addMessages([message], location: .Random)
        }

        return serverId
    }
}

private func performPreparedEphemeralMessageSend(account: Account, prepared: PreparedEphemeralMessageSend) -> Signal<MessageId?, NoError> {
    let apiEntities = apiEntitiesFromMessageTextEntities(prepared.entities, associatedPeers: SimpleDictionary())
    var flags: Int32 = 0
    if !apiEntities.isEmpty {
        flags |= (1 << 1)
    }

    return account.network.request(Api.functions.ephemeral.sendMessage(flags: flags, peer: prepared.inputPeer, receiverId: prepared.inputUser, queryId: nil, message: prepared.text, entities: apiEntities.isEmpty ? nil : apiEntities, media: nil, replyMarkup: nil, richMessage: nil, randomId: prepared.randomId))
    |> map { result -> Api.EphemeralMessage? in
        return result
    }
    |> `catch` { _ -> Signal<Api.EphemeralMessage?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<MessageId?, NoError> in
        if let result {
            return completePendingEphemeralMessage(account: account, prepared: prepared, apiMessage: result)
        } else {
            return failPendingEphemeralMessage(account: account, peerId: prepared.peerId, localId: prepared.localId, randomId: prepared.randomId)
        }
    }
}

func _internal_sendEphemeralBotCommand(account: Account, peerId: PeerId, botPeerId: PeerId, text: String, entities: [MessageTextEntity]) -> Signal<MessageId?, NoError> {
    return preparedEphemeralMessageSend(account: account, peerId: peerId, botPeerId: botPeerId, text: text, entities: entities)
    |> mapToSignal { prepared -> Signal<MessageId?, NoError> in
        guard let prepared else {
            return .single(nil)
        }
        return performPreparedEphemeralMessageSend(account: account, prepared: prepared)
    }
}

func _internal_retryEphemeralOutgoingMessage(account: Account, messageId: MessageId) -> Signal<MessageId?, NoError> {
    return account.postbox.transaction { transaction -> PreparedEphemeralMessageSend? in
        guard messageId.namespace == Namespaces.Message.EphemeralLocal, let currentMessage = transaction.getMessage(messageId), let outgoingAttribute = currentMessage.attributes.first(where: { $0 is EphemeralOutgoingMessageAttribute }) as? EphemeralOutgoingMessageAttribute, let peer = transaction.getPeer(messageId.peerId), let botPeer = transaction.getPeer(outgoingAttribute.botPeerId), let inputPeer = apiInputPeer(peer), let inputUser = apiInputUser(botPeer) else {
            return nil
        }

        var entities: [MessageTextEntity] = []
        if let entitiesAttribute = currentMessage.attributes.first(where: { $0 is TextEntitiesMessageAttribute }) as? TextEntitiesMessageAttribute {
            entities = entitiesAttribute.entities
        }

        transaction.updateMessage(messageId, update: { currentMessage in
            return .update(ephemeralOutgoingStoreMessageWithUpdatedState(currentMessage, state: .sending))
        })

        return PreparedEphemeralMessageSend(peerId: messageId.peerId, localId: messageId, botPeerId: outgoingAttribute.botPeerId, randomId: outgoingAttribute.randomId, inputPeer: inputPeer, inputUser: inputUser, text: currentMessage.text, entities: entities)
    }
    |> mapToSignal { prepared -> Signal<MessageId?, NoError> in
        guard let prepared else {
            return .single(nil)
        }
        return performPreparedEphemeralMessageSend(account: account, prepared: prepared)
    }
}
