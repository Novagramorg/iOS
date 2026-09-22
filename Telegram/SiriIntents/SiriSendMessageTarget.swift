import Foundation
import Intents
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
/// be refused here or Siri would report the reply as sent: users that still exist and do not
/// gate their messages (paid messages are never spent from Siri; a Premium gate is honoured
/// unless the account is Premium), groups the user is still a member of and may post text in,
/// never a broadcast channel (Siri can read its posts, but a "reply" there is not a thing the
/// user can be offered), never a chat that charges for messages, and not yet a forum or
/// monoforum, because `INMessage.conversationIdentifier` names the chat only and the reply
/// would land in the wrong topic.
///
/// `cachedData` is the peer's `CachedUserData` when the store has it; without it the user's
/// own flags decide, the way the chat list does before the full data is fetched.
func peerAcceptsSiriMessages(_ peer: Peer, cachedData: CachedPeerData? = nil, accountIsPremium: Bool = false) -> Bool {
    switch peer {
    case let user as TelegramUser:
        if user.isDeleted || user.id.id._internalGetInt64Value() == 777000 {
            return false
        }
        if let cachedData = cachedData as? CachedUserData {
            if cachedData.sendPaidMessageStars != nil {
                return false
            }
            if cachedData.flags.contains(.premiumRequired) && !accountIsPremium {
                return false
            }
            return true
        }
        if user.flags.contains(.mutualContact) {
            return true
        }
        if user.flags.contains(.requireStars) {
            return false
        }
        if user.flags.contains(.requirePremium) && !accountIsPremium {
            return false
        }
        return true
    case let group as TelegramGroup:
        if group.membership != .Member {
            return false
        }
        if group.flags.contains(.deactivated) || group.migrationReference != nil {
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

/// What recipient resolution says about a peer Siri named, by conversation or by a person
/// this extension handed it earlier.
enum SiriRecipientDecision {
    /// The peer is not in the store; Siri has to ask again.
    case unknown
    /// The peer exists but is not something the user may message (a channel, a forum, a chat
    /// they cannot write to). Siri says so, and no send is attempted.
    case refused
    /// The peer Siri should address, as the person it will hand back in the send.
    case person(INPerson)
}

/// Every recipient Siri resolves goes through this, so `peerAcceptsSiriMessages` is applied
/// before Siri ever confirms a message, not only when the send runs.
func siriRecipientDecision(for peer: Peer?, cachedData: CachedPeerData? = nil, accountIsPremium: Bool = false) -> SiriRecipientDecision {
    guard let peer else {
        return .unknown
    }
    if !peerAcceptsSiriMessages(peer, cachedData: cachedData, accountIsPremium: accountIsPremium) {
        return .refused
    }
    return .person(personWithPeer(stableId: "tg\(peer.id.toInt64())", peer: peer))
}

/// The same decision, read out of the store: the peer, its cached data and whether the account
/// itself is Premium. Recipient resolution and the send both go through this, so the send can
/// never accept a peer that resolution refused.
func siriRecipientDecision(transaction: Transaction, accountPeerId: PeerId, peerId: PeerId) -> SiriRecipientDecision {
    let accountIsPremium = transaction.getPeer(accountPeerId)?.isPremium ?? false
    return siriRecipientDecision(
        for: transaction.getPeer(peerId),
        cachedData: transaction.getPeerCachedData(peerId: peerId),
        accountIsPremium: accountIsPremium
    )
}
