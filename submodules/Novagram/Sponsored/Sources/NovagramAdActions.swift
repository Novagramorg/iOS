import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import NovagramAds

/// The `action` event (contract §2.2, §4.4): after a click on OUR ad (any slot), the user joined the
/// promoted CHANNEL or pressed Start in the promoted BOT. Detected by watching engine data in this
/// module — no hooks in Telegram files. Sent once, with the same `random_id` as the click, only within
/// 55 minutes of the serve, and never when the user was already a member at click time.
enum NovagramAdActions {
    /// Events for tokens older than this are dropped by the SDK anyway (contract §4.8).
    static let window: Double = 55.0 * 60.0
    /// Bot API channel id → inner id: `-(1_000_000_000_000 + id)`.
    private static let botApiChannelIdBase: Int64 = 1_000_000_000_000

    /// Main queue only: one watcher per clicked token.
    private static var watchers: [String: Disposable] = [:]

    /// Starts watching after a click was queued (so the SDK sees click before action). Main queue.
    static func watch(served: SDKServedAd, session: SDKAdsSession, context: AccountContext) {
        let token = served.ad.randomId
        guard self.watchers[token] == nil else {
            return
        }
        let remaining = served.servedAt.addingTimeInterval(self.window).timeIntervalSinceNow
        guard remaining > 0.0 else {
            return
        }
        let promoted = served.ad.promoted
        let clickedAt = Int32(Date().timeIntervalSince1970)

        let completed: Signal<Bool, NoError>
        switch promoted.type {
        case .bot:
            completed = self.botStarted(context: context, username: promoted.username, after: clickedAt)
        default:
            completed = self.channelJoined(context: context, username: promoted.username, telegramId: promoted.telegramId)
        }

        let disposable = MetaDisposable()
        self.watchers[token] = disposable
        disposable.set((completed
        |> filter { $0 }
        |> take(1)
        |> timeout(remaining, queue: .mainQueue(), alternate: .single(false))
        |> deliverOnMainQueue).startStrict(next: { didAct in
            if didAct {
                NovagramSponsored.logger.debug("action → novagram \(NovagramSponsored.masked(token), privacy: .public)")
                Task {
                    await session.recordAction(served)
                }
            }
        }, completed: {
            self.watchers[token]?.dispose()
            self.watchers[token] = nil
        }))
    }

    /// The promoted channel's peer id: from `telegram_id` when the peer is already known, else by username.
    private static func resolveChannel(context: AccountContext, username: String, telegramId: Int64?) -> Signal<EnginePeer.Id?, NoError> {
        let byUsername = context.engine.peers.resolvePeerByName(name: username, referrer: nil)
        |> mapToSignal { result -> Signal<EnginePeer.Id?, NoError> in
            guard case let .result(peer) = result else {
                return .complete()
            }
            return .single(peer?.id)
        }
        guard let telegramId, telegramId < -self.botApiChannelIdBase else {
            return byUsername
        }
        let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(-telegramId - self.botApiChannelIdBase))
        return context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        |> mapToSignal { peer -> Signal<EnginePeer.Id?, NoError> in
            if peer != nil {
                return .single(peerId)
            }
            return byUsername
        }
    }

    /// True once the user went from "not a member" (as first observed) to "member". Never true when the
    /// first observation already says member (joined before the click).
    private static func channelJoined(context: AccountContext, username: String, telegramId: Int64?) -> Signal<Bool, NoError> {
        return self.resolveChannel(context: context, username: username, telegramId: telegramId)
        |> take(1)
        |> mapToSignal { peerId -> Signal<Bool, NoError> in
            guard let peerId else {
                return .single(false)
            }
            let wasMemberAtClick = Atomic<Bool?>(value: nil)
            return context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
            |> map { peer -> Bool in
                guard case let .channel(channel) = peer else {
                    return false
                }
                let isMember = channel.participationStatus == .member
                let initial = wasMemberAtClick.modify { $0 ?? isMember }
                return isMember && initial == false
            }
        }
    }

    /// True once the user's own `/start` reaches the promoted bot's chat after the click.
    private static func botStarted(context: AccountContext, username: String, after clickedAt: Int32) -> Signal<Bool, NoError> {
        return context.engine.peers.resolvePeerByName(name: username, referrer: nil)
        |> mapToSignal { result -> Signal<EnginePeer.Id?, NoError> in
            guard case let .result(peer) = result else {
                return .complete()
            }
            return .single(peer?.id)
        }
        |> take(1)
        |> mapToSignal { peerId -> Signal<Bool, NoError> in
            guard let peerId else {
                return .single(false)
            }
            let key = PostboxViewKey.topChatMessage(peerIds: [peerId])
            return context.account.postbox.combinedView(keys: [key])
            |> map { views -> Bool in
                guard let view = views.views[key] as? TopChatMessageView, let message = view.messages[peerId] else {
                    return false
                }
                return !message.flags.contains(.Incoming) && message.timestamp >= clickedAt && message.text.hasPrefix("/start")
            }
        }
    }
}
