import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import NovagramAds

/// BOT slot: the panel above a bot chat (Telegram's ad panel, `ChatAdPanelNode`). Label, title and
/// text; the whole panel is the click target; its "X" hides the ad locally for that `random_id`.
public enum NovagramBotAds {
    /// OURS-FIRST source for the bot ad panel (product rule: `NovagramSponsored.oursFirst`): our ad when
    /// the chat is a bot with a username and the backend has one; otherwise `fallback` (Telegram's own
    /// ad) unchanged — except never for Premium users. Hidden while "Remove all ads" is on.
    public static func panelMessage(context: AccountContext, peerId: EnginePeer.Id, fallback: Signal<Message?, NoError>) -> Signal<Message?, NoError> {
        // The panel is drawn for bot chats only; other chats keep Telegram's value untouched.
        guard peerId.namespace == Namespaces.Peer.CloudUser else {
            return fallback
        }
        return NovagramSponsored.oursFirst(context: context, surface: "BOT", ours: self.ourAdMessage(context: context, peerId: peerId), fallback: fallback, empty: nil, isEmpty: { $0 == nil }, map: { ours -> Message? in
            return ours
        })
    }

    static func ourAdMessage(context: AccountContext, peerId: EnginePeer.Id) -> Signal<Message?, NoError> {
        guard peerId.namespace == Namespaces.Peer.CloudUser, NovagramSponsored.isConfigured else {
            return .single(nil)
        }
        return context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        |> mapToSignal { peer -> Signal<Message?, NoError> in
            guard case let .user(user) = peer, user.botInfo != nil, let username = user.addressName, SDKAdSlot.bareBotUsername(username) != nil else {
                return .single(nil)
            }
            return NovagramSponsored.visibleAd(context: context, slot: .bot(username: username))
            |> mapToSignal { served -> Signal<Message?, NoError> in
                guard let served else {
                    return .single(nil)
                }
                // The advertiser photo when there is one (waits up to NovagramAdAvatar.loadTimeout).
                return NovagramAdAvatar.load(postbox: context.account.postbox, ad: served.ad)
                |> map { avatar -> Message? in
                    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
                    return NovagramAdMessage.make(served: served, peerId: peerId, chatPeer: user, strings: strings, avatar: avatar)
                }
            }
        }
    }
}
