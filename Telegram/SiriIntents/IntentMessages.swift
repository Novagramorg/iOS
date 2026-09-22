import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import Contacts
import Intents

extension MessageId {
    init?(string: String) {
        let components = string.components(separatedBy: "_")
        if components.count == 3, let peerIdValue = Int64(components[0]), let namespaceValue = Int32(components[1]), let idValue = Int32(components[2]) {
            self.init(peerId: PeerId(peerIdValue), namespace: namespaceValue, id: idValue)
        } else {
            return nil
        }
    }
}

/// The `INMessage.identifier` handed to Siri for a message; `MessageId.init(string:)` parses it back.
func intentMessageIdentifier(_ id: MessageId) -> String {
    return "\(id.peerId.toInt64())_\(id.namespace)_\(id.id)"
}

@available(iOSApplicationExtension 10.0, iOS 10.0, *)
func getMessages(account: Account, ids: [MessageId]) -> Signal<[INMessage], NoError> {
    return account.postbox.transaction { transaction -> [INMessage] in
        var messages: [INMessage] = []
        for id in ids {
            if let message = transaction.getMessage(id).flatMap(messageWithTelegramMessage) {
                messages.append(message)
            }
        }
        return messages.sorted { $0.dateSent!.compare($1.dateSent!) == .orderedDescending }
    }
}

/// Which chats "read my messages" looks at: private chats, groups and channels. Secret chats
/// stay out (their messages cannot be read or replied to from the extension).
func unreadMessagesIncludePeer(_ peerId: PeerId) -> Bool {
    switch peerId.namespace {
    case Namespaces.Peer.CloudUser, Namespaces.Peer.CloudGroup, Namespaces.Peer.CloudChannel:
        return true
    default:
        return false
    }
}

@available(iOSApplicationExtension 10.0, iOS 10.0, *)
func unreadMessages(account: Account) -> Signal<[INMessage], NoError> {
    return account.postbox.tailChatListView(groupId: .root, count: 20, summaryComponents: ChatListEntrySummaryComponents())
    |> take(1)
    |> mapToSignal { view -> Signal<[INMessage], NoError> in
        var signals: [Signal<[INMessage], NoError>] = []
        for entry in view.0.entries {
            if case let .MessageEntry(entryData) = entry {
                let index = entryData.index
                let readState = entryData.readState
                let isMuted = entryData.isRemovedFromTotalUnreadCount
                
                if !unreadMessagesIncludePeer(index.messageIndex.id.peerId) {
                    continue
                }
                
                var hasUnread = false
                var fixedCombinedReadStates: MessageHistoryViewReadState?
                if let readState = readState {
                    hasUnread = readState.state.count != 0
                    fixedCombinedReadStates = .peer([index.messageIndex.id.peerId: readState.state])
                }
                
                if !isMuted && hasUnread {
                    signals.append(account.postbox.aroundMessageHistoryViewForLocation(.peer(peerId: index.messageIndex.id.peerId, threadId: nil), anchor: .upperBound, ignoreMessagesInTimestampRange: nil, ignoreMessageIds: Set(), count: 10, fixedCombinedReadStates: fixedCombinedReadStates, topTaggedMessageIdNamespaces: Set(), tag: nil, appendMessagesFromTheSameGroup: false, namespaces: .not(Namespaces.Message.allNonRegular), orderStatistics: .combinedLocation)
                    |> take(1)
                    |> map { view -> [INMessage] in
                        var messages: [INMessage] = []
                        for entry in view.0.entries {
                            var isRead = true
                            if let readState = readState {
                                isRead = readState.state.isIncomingMessageIndexRead(entry.message.index)
                            }
                            
                            if !isRead {
                                if let message = messageWithTelegramMessage(entry.message) {
                                    messages.append(message)
                                }
                            }
                        }
                        return messages
                    })
                }
            }
        }
        
        if signals.isEmpty {
            return .single([])
        } else {
            return combineLatest(signals)
            |> map { results -> [INMessage] in
                return results.flatMap { $0 }.sorted { $0.dateSent!.compare($1.dateSent!) == .orderedDescending }
            }
        }
    }
}

@available(iOSApplicationExtension 10.0, iOS 10.0, *)
struct CallRecord {
    let identifier: String
    let date: Date
    let caller: INPerson
    let duration: Int32?
    let unseen: Bool
    
    @available(iOSApplicationExtension 11.0, iOS 11.0, *)
    var intentCall: INCallRecord {
        return INCallRecord(identifier: self.identifier, dateCreated: self.date, caller: self.caller, callRecordType: .missed, callCapability: .audioCall, callDuration: self.duration.flatMap(Double.init), unseen: self.unseen)
    }
}

@available(iOSApplicationExtension 10.0, iOS 10.0, *)
func missedCalls(account: Account) -> Signal<[CallRecord], NoError> {
    return account.viewTracker.callListView(type: .missed, index: MessageIndex.absoluteUpperBound(), count: 30)
    |> take(1)
    |> map { view -> [CallRecord] in
        var calls: [CallRecord] = []
        for entry in view.entries {
            switch entry {
                case let .message(_, messages):
                    for message in messages {
                        if let call = callWithTelegramMessage(message, account: account) {
                            calls.append(call)
                        }
                    }
                default:
                    break
            }
        }
        return calls.sorted { $0.date.compare($1.date) == .orderedDescending }
    }
}

@available(iOSApplicationExtension 10.0, iOS 10.0, *)
private func callWithTelegramMessage(_ telegramMessage: Message, account: Account) -> CallRecord? {
    guard let author = telegramMessage.author, let user = telegramMessage.peers[author.id] as? TelegramUser else {
        return nil
    }
    
    let identifier = intentMessageIdentifier(telegramMessage.id)
    let personHandle: INPersonHandle
    if #available(iOSApplicationExtension 10.2, iOS 10.2, *) {
        var type: INPersonHandleType
        var label: INPersonHandleLabel?
        if let username = user.addressName {
            label = INPersonHandleLabel(rawValue: "@\(username)")
            type = .unknown
        } else if let phone = user.phone {
            label = INPersonHandleLabel(rawValue: formatPhoneNumber(phone))
            type = .phoneNumber
        } else {
            label = nil
            type = .unknown
        }
        personHandle = INPersonHandle(value: user.phone ?? "", type: type, label: label)
    } else {
        personHandle = INPersonHandle(value: user.phone ?? "", type: .phoneNumber)
    }
    
    let caller = INPerson(personHandle: personHandle, nameComponents: nil, displayName: user.nameOrPhone, image: nil, contactIdentifier: nil, customIdentifier: "tg\(user.id.toInt64())")
    let date = Date(timeIntervalSince1970: TimeInterval(telegramMessage.timestamp))
    
    var duration: Int32?
    for media in telegramMessage.media {
        if let action = media as? TelegramMediaAction, case let .phoneCall(_, _, callDuration, _) = action.action {
            duration = callDuration
        }
    }
    
    return CallRecord(identifier: identifier, date: date, caller: caller, duration: duration, unseen: true)
}

/// The Siri-facing sender of a message: its author when that is a user (the Telegram service
/// account excepted), or the channel itself for a channel post. Anything else has no sender
/// Siri could name, and such a message is not read out.
@available(iOSApplicationExtension 10.0, iOS 10.0, *)
private func intentSender(for author: Peer) -> INPerson? {
    let personIdentifier = "tg\(author.id.toInt64())"
    if let user = author as? TelegramUser {
        if user.id.id._internalGetInt64Value() == 777000 {
            return nil
        }
        let personHandle: INPersonHandle
        if #available(iOSApplicationExtension 10.2, iOS 10.2, *) {
            var type: INPersonHandleType
            var label: INPersonHandleLabel?
            if let username = user.addressName {
                label = INPersonHandleLabel(rawValue: "@\(username)")
                type = .unknown
            } else if let phone = user.phone {
                label = INPersonHandleLabel(rawValue: formatPhoneNumber(phone))
                type = .phoneNumber
            } else {
                label = nil
                type = .unknown
            }
            personHandle = INPersonHandle(value: user.phone ?? "", type: type, label: label)
        } else {
            personHandle = INPersonHandle(value: user.phone ?? "", type: .phoneNumber)
        }
        return INPerson(personHandle: personHandle, nameComponents: nil, displayName: user.nameOrPhone, image: nil, contactIdentifier: personIdentifier, customIdentifier: personIdentifier)
    } else if let channel = author as? TelegramChannel {
        let handleValue = channel.addressName.flatMap { "@\($0)" } ?? channel.title
        let personHandle = INPersonHandle(value: handleValue, type: .unknown)
        return INPerson(personHandle: personHandle, nameComponents: nil, displayName: channel.title, image: nil, contactIdentifier: personIdentifier, customIdentifier: personIdentifier)
    } else {
        return nil
    }
}

/// The name Siri prefixes a message with when it was posted in a group ("Alice in Weekend
/// Ride"). Private chats and channels have none: there the sender is the conversation. Nor
/// does a message the group itself wrote (an anonymous admin), whose sender already is the
/// group.
private func intentGroupName(for chatPeer: Peer?, author: Peer) -> String? {
    if let chatPeer, chatPeer.id == author.id {
        return nil
    }
    switch chatPeer {
    case let group as TelegramGroup:
        return group.title
    case let channel as TelegramChannel:
        if case .group = channel.info {
            return channel.title
        }
        return nil
    default:
        return nil
    }
}

@available(iOSApplicationExtension 10.0, iOS 10.0, *)
func messageWithTelegramMessage(_ telegramMessage: Message) -> INMessage? {
    guard let author = telegramMessage.author, let sender = intentSender(for: author) else {
        return nil
    }
    let groupName = intentGroupName(for: telegramMessage.peers[telegramMessage.id.peerId], author: author)
    
    let identifier = intentMessageIdentifier(telegramMessage.id)
    let date = Date(timeIntervalSince1970: TimeInterval(telegramMessage.timestamp))
    
    let message: INMessage
    if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
        var messageType: INMessageType = .text
        loop: for media in telegramMessage.media {
            if media is TelegramMediaImage {
                messageType = .mediaImage
                break loop
            }
            else if let file = media as? TelegramMediaFile {
                if file.isVideo {
                    messageType = .mediaVideo
                    break loop
                } else if file.isMusic {
                    messageType = .mediaAudio
                    break loop
                } else if file.isVoice {
                    messageType = .mediaAudio
                    break loop
                } else if file.isSticker || file.isAnimatedSticker {
                    messageType = .sticker
                    break loop
                } else if file.isAnimated {
                    messageType = .mediaVideo
                    break loop
                } else if #available(iOSApplicationExtension 12.0, iOS 12.0, *) {
                    messageType = .file
                    break loop
                }
            } else if media is TelegramMediaMap {
                messageType = .mediaLocation
                break loop
            } else if media is TelegramMediaContact {
                messageType = .mediaAddressCard
                break loop
            }
        }
        
        if telegramMessage.text.isEmpty && messageType == .text {
            return nil
        }
    
        message = INMessage(identifier: identifier, conversationIdentifier: "\(telegramMessage.id.peerId.toInt64())", content: telegramMessage.text, dateSent: date, sender: sender, recipients: [], groupName: groupName.flatMap { INSpeakableString(spokenPhrase: $0) }, messageType: messageType)
    } else {
        if telegramMessage.text.isEmpty {
            return nil
        }
        message = INMessage(identifier: identifier, content: telegramMessage.text, dateSent: date, sender: sender, recipients: [])
    }
    
    return message
}
