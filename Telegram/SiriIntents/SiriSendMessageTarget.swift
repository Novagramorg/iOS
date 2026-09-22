import Foundation
import Postbox
import TelegramCore

/// The chat a Siri `INSendMessageIntent` is addressed to.
///
/// A reply to a message Siri just read arrives with that message's `conversationIdentifier`
/// (the chat's peer id, as `INMessage` published it) and the message's sender as recipient.
/// For a group message those differ, and sending to the recipient would drop a group reply
/// into the author's private chat, so the conversation wins whenever it is present. Without
/// one, the recipient is a person this extension resolved earlier, whose `customIdentifier`
/// is `tg<peerId>`.
func siriSendMessageTarget(conversationIdentifier: String?, recipientCustomIdentifier: String?) -> PeerId? {
    if let conversationIdentifier, let peerIdValue = Int64(conversationIdentifier) {
        return PeerId(peerIdValue)
    }
    if let recipientCustomIdentifier, recipientCustomIdentifier.hasPrefix("tg"), let peerIdValue = Int64(recipientCustomIdentifier.dropFirst(2)) {
        return PeerId(peerIdValue)
    }
    return nil
}

/// Whether Siri may send a message to this peer.
///
/// The standalone send swallows the server's refusal, so a chat the user cannot write to has to
/// be refused here or Siri would report the reply as sent: users and groups the user is still a
/// member of and may post text in, never a broadcast channel (Siri can read its posts, but a
/// "reply" there is not a thing the user can be offered), never a chat that charges for
/// messages, and not yet a forum or monoforum, because `INMessage.conversationIdentifier`
/// names the chat only and the reply would land in the wrong topic.
func peerAcceptsSiriMessages(_ peer: Peer) -> Bool {
    switch peer {
    case is TelegramUser:
        return true
    case let group as TelegramGroup:
        if group.membership != .Member {
            return false
        }
        return !group.hasBannedPermission(.banSendText)
    case let channel as TelegramChannel:
        if case .broadcast = channel.info {
            return false
        }
        if channel.participationStatus != .member {
            return false
        }
        if channel.flags.contains(.isForum) || channel.flags.contains(.isMonoforum) {
            return false
        }
        if channel.sendPaidMessageStars != nil {
            return false
        }
        return channel.hasBannedPermission(.banSendText) == nil
    default:
        return false
    }
}
