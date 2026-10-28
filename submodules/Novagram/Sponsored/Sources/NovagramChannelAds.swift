import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import NovagramAds

/// The ad-source tuple `ChatHistoryListNode` consumes (`adMessagesContext.state`).
public typealias NovagramAdMessagesState = (interPostInterval: Int32?, messages: [Message], startDelay: Int32?, betweenDelay: Int32?)

/// CHANNEL_MESSAGE slot: one sponsored message after the last post of a public broadcast channel
/// with at least 1000 subscribers (contract §3.3 — the app does this filter, the server does not).
public enum NovagramChannelAds {
    static let minimumSubscribers = 1000
    /// How long to wait for the channel's subscriber count before giving up on the slot.
    static let participantCountTimeout: Double = 4.0
    /// Bot API channel id: `-(1_000_000_000_000 + inner id)` (contract §3.6).
    static let botApiChannelIdBase: Int64 = 1_000_000_000_000

    /// OURS-FIRST ad source for the channel history (product rule: `NovagramSponsored.oursFirst`):
    /// our ad when the backend has one for this channel; otherwise `fallback` (Telegram's own
    /// `adMessagesContext.state`) unchanged — except never for Premium users.
    public static func adMessages(context: AccountContext, peerId: EnginePeer.Id, fallback: Signal<NovagramAdMessagesState, NoError>) -> Signal<NovagramAdMessagesState, NoError> {
        return NovagramSponsored.oursFirst(context: context, surface: "CHANNEL_MESSAGE", ours: self.ourAdMessage(context: context, peerId: peerId), fallback: fallback, empty: (nil, [], nil, nil), isEmpty: { $0.messages.isEmpty }, map: { ours -> NovagramAdMessagesState in
            // interPostInterval nil = one fixed ad after the last post (no posts_between in v2).
            return (nil, [ours], nil, nil)
        })
    }

    /// The Bot API id of a channel peer (`-100…`), or nil when it is not a valid channel id.
    static func botApiChannelId(_ peerId: EnginePeer.Id) -> Int64? {
        guard peerId.namespace == Namespaces.Peer.CloudChannel else {
            return nil
        }
        let channelId = -(self.botApiChannelIdBase + peerId.id._internalGetInt64Value())
        return SDKAdSlot.isValidChannelId(channelId) ? channelId : nil
    }

    /// The `channel_id` sent to the backend for a channel. Debug builds only: the launch environment value
    /// `NOVAGRAM_ADS_DEBUG_CHANNEL_ID=-100…` replaces it, so an eligible channel of a test account can show
    /// the backend's test campaigns. Release builds always send the real id.
    static func requestChannelId(_ channelId: Int64) -> Int64 {
        #if DEBUG
        if let value = ProcessInfo.processInfo.environment["NOVAGRAM_ADS_DEBUG_CHANNEL_ID"], let override = Int64(value), SDKAdSlot.isValidChannelId(override) {
            return override
        }
        #endif
        return channelId
    }

    /// The channel peer when it may carry ads: a public broadcast channel (has a username) with at least
    /// 1000 subscribers — every channel, no exceptions. Emits once; nil when not eligible or unknown.
    static func eligibleChannel(context: AccountContext, peerId: EnginePeer.Id, channelId: Int64) -> Signal<EnginePeer?, NoError> {
        // The subscriber count lives in CachedChannelData, which arrives a moment after the chat opens.
        return context.engine.data.subscribe(
            TelegramEngine.EngineData.Item.Peer.Peer(id: peerId),
            TelegramEngine.EngineData.Item.Peer.ParticipantCount(id: peerId)
        )
        |> filter { _, participantCount in
            return participantCount != nil
        }
        |> take(1)
        |> timeout(self.participantCountTimeout, queue: .mainQueue(), alternate: .single((nil, nil)))
        |> map { peer, participantCount -> EnginePeer? in
            guard case let .channel(channel) = peer, case .broadcast = channel.info, channel.addressName != nil else {
                NovagramSponsored.logger.debug("channel slot skipped: not a public broadcast channel")
                return nil
            }
            guard let participantCount, participantCount >= self.minimumSubscribers else {
                NovagramSponsored.logger.debug("channel slot skipped: \(participantCount ?? -1, privacy: .public) subscribers")
                return nil
            }
            return peer
        }
    }

    static func ourAdMessage(context: AccountContext, peerId: EnginePeer.Id) -> Signal<Message?, NoError> {
        guard NovagramSponsored.isConfigured, let channelId = self.botApiChannelId(peerId) else {
            return .single(nil)
        }
        return self.eligibleChannel(context: context, peerId: peerId, channelId: channelId)
        |> mapToSignal { peer -> Signal<Message?, NoError> in
            guard let peer else {
                return .single(nil)
            }
            return NovagramSponsored.visibleAd(context: context, slot: .channel(channelId: self.requestChannelId(channelId)))
            |> mapToSignal { served -> Signal<Message?, NoError> in
                guard let served else {
                    return .single(nil)
                }
                // The advertiser photo when there is one (waits up to NovagramAdAvatar.loadTimeout).
                return NovagramAdAvatar.load(postbox: context.account.postbox, ad: served.ad)
                |> map { avatar -> Message? in
                    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
                    return NovagramAdMessage.make(served: served, peerId: peerId, chatPeer: peer._asPeer(), strings: strings, avatar: avatar)
                }
            }
        }
    }
}
