import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import Display
import NovagramMessenger
import NovagramSponsoredBridge
import NovagramAds

/// The bridge implementation GalleryUI and the bubble components reach through
/// `NovagramSponsoredBridge.provider` (installed by `NovagramAdsRegistry.init`).
final class NovagramAdsBridgeProvider: NovagramAdsProvider {
    func videoAdHandle(context: AccountContext, message: Message, onUpdate: @escaping () -> Void) -> NovagramVideoAdHandle {
        let state = NovagramVideoAds.channelState(context: context, message: message)
        return NovagramVideoAdHandleImpl(context: context, state: state, messageId: Int64(message.id.id), onUpdate: onUpdate)
    }

    func recordVideoOpenIfOurs(opaqueId: Data) -> Bool {
        return NovagramSponsored.recordVideoOpenIfOurs(opaqueId: opaqueId)
    }

    func presentMenuIfOurs(opaqueId: Data, context: AccountContext, present: @escaping (ViewController) -> Void) -> Bool {
        return NovagramAdMenu.presentIfOurs(opaqueId: opaqueId, context: context, present: present)
    }
}

/// VIDEO slot (contract §3.4): a text banner over a channel video in the full-screen player, driven
/// only by the server's values — `start_delay` / `between_delay` from the response, `min_display_duration`
/// / `max_display_duration` from the ad (`SDKAdVideoTimers.fallback` when a degraded response omits them).
///
/// Timers run on PLAYBACK time (paused video = stopped timers) and live per channel, shared by every
/// gallery item of that channel: moving to a neighbouring video of the same channel neither requests
/// again nor resets them.
enum NovagramVideoAds {
    /// A channel state left without gallery items for this long starts over (the serve cache TTL).
    static let staleStateInterval: Double = 300.0
    private static var states: [String: NovagramVideoChannelState] = [:]

    /// Main queue only. Nil for messages that cannot carry OUR video ad (not a channel post, an ad
    /// itself, no API key) — the handle then only applies the fallback rules to Telegram's video ads.
    static func channelState(context: AccountContext, message: Message) -> NovagramVideoChannelState? {
        guard NovagramSponsored.isConfigured, message.id.namespace == Namespaces.Message.Cloud, message.id.id > 0, !NovagramSponsoredBridge.isOurs(message), !message.attributes.contains(where: { $0 is AdMessageAttribute }) else {
            return nil
        }
        guard let channelId = NovagramChannelAds.botApiChannelId(message.id.peerId) else {
            return nil
        }
        let key = "\(NovagramSponsored.userId(context)):\(channelId)"
        if let current = self.states[key], !current.isStale {
            return current
        }
        let state = NovagramVideoChannelState(context: context, peerId: message.id.peerId, channelId: channelId)
        self.states[key] = state
        return state
    }
}

/// One channel's VIDEO-slot schedule. Main queue only.
final class NovagramVideoChannelState {
    private struct Showing {
        let served: SDKServedAd
        let message: Message
        let shownAt: Double
    }

    private static let tickInterval: Double = 0.5

    private let context: AccountContext
    private let peerId: EnginePeer.Id
    private let channelId: Int64

    private var handles: [ObjectIdentifier: () -> Void] = [:]
    private var playingHandles = Set<ObjectIdentifier>()
    private var detachedAt: Double?

    /// Seconds of playback in this channel since the first video started.
    private var playback: Double = 0.0
    private var lastTick: Double?
    private var tickTimer: SwiftSignalKit.Timer?

    private var requested = false
    /// The video playing most recently (`msg_id` of the next request; the cache is per channel).
    private var lastMessageId: Int64 = 1
    private var inFlight = false
    /// The backend gave this channel an ad in this session: Telegram's fallback stays off.
    private var hadAd = false
    private var timers = SDKAdVideoTimers.fallback
    private var pending: SDKServedAd?
    private var dueAt: Double?
    private var showing: Showing?
    private let requestDisposable = MetaDisposable()

    init(context: AccountContext, peerId: EnginePeer.Id, channelId: Int64) {
        self.context = context
        self.peerId = peerId
        self.channelId = channelId
    }

    deinit {
        self.tickTimer?.invalidate()
        self.requestDisposable.dispose()
    }

    var isStale: Bool {
        guard self.handles.isEmpty, let detachedAt = self.detachedAt else {
            return false
        }
        return CFAbsoluteTimeGetCurrent() - detachedAt > NovagramVideoAds.staleStateInterval
    }

    /// While OUR request is out or the backend gave an ad, Telegram's video ad must not show.
    var suppressesFallback: Bool {
        return self.inFlight || self.hadAd
    }

    // MARK: Handles

    func attach(_ id: ObjectIdentifier, update: @escaping () -> Void) {
        self.handles[id] = update
        self.detachedAt = nil
        self.updateTimer()
    }

    func detach(_ id: ObjectIdentifier) {
        self.accumulate()
        self.handles[id] = nil
        self.playingHandles.remove(id)
        if self.handles.isEmpty {
            self.detachedAt = CFAbsoluteTimeGetCurrent()
        }
        self.updateTimer()
    }

    func setPlaying(_ id: ObjectIdentifier, isPlaying: Bool, messageId: Int64) {
        self.accumulate()
        if isPlaying {
            self.playingHandles.insert(id)
            self.lastMessageId = messageId
        } else {
            self.playingHandles.remove(id)
        }
        // Contract §2.1: ask only when a channel video actually starts in the full-screen player.
        if isPlaying && !self.requested {
            self.requestFirst(messageId: messageId)
        }
        self.evaluate()
    }

    // MARK: Banner

    /// The banner on screen and a countdown origin that follows playback time.
    func currentBanner() -> (initialTimestamp: Int32, message: Message)? {
        self.accumulate()
        guard let showing = self.showing else {
            return nil
        }
        let elapsed = self.playback - showing.shownAt
        return (Int32(CFAbsoluteTimeGetCurrent() - elapsed), showing.message)
    }

    func isShowing(token: String) -> Bool {
        return self.showing?.served.ad.randomId == token
    }

    /// Close control: allowed once `min_display_duration` of playback has passed.
    func close(token: String) {
        self.accumulate()
        guard let showing = self.showing, showing.served.ad.randomId == token else {
            return
        }
        guard self.playback - showing.shownAt >= self.timers.minDisplayDuration else {
            return
        }
        self.hide()
    }

    /// A click hides the banner at once (the url opens).
    func hideAfterClick(token: String) {
        guard self.isShowing(token: token) else {
            return
        }
        self.hide()
    }

    // MARK: Schedule

    private var isPlaying: Bool {
        return !self.playingHandles.isEmpty
    }

    private func accumulate() {
        let now = CFAbsoluteTimeGetCurrent()
        if self.isPlaying, let lastTick = self.lastTick {
            self.playback += max(0.0, now - lastTick)
        }
        self.lastTick = now
    }

    private func updateTimer() {
        if self.handles.isEmpty {
            self.tickTimer?.invalidate()
            self.tickTimer = nil
            return
        }
        guard self.tickTimer == nil else {
            return
        }
        let timer = SwiftSignalKit.Timer(timeout: Self.tickInterval, repeat: true, completion: { [weak self] in
            self?.tick()
        }, queue: Queue.mainQueue())
        self.tickTimer = timer
        timer.start()
    }

    private func tick() {
        self.accumulate()
        self.evaluate()
        // Also while paused: the countdown origin moves with wall time so the countdown stays put.
        if self.showing != nil {
            self.notify()
        }
    }

    private func evaluate() {
        if let showing = self.showing {
            let hiddenLocally = NovagramSponsored.registry.isHidden(token: showing.served.ad.randomId)
            if hiddenLocally || self.playback - showing.shownAt >= self.timers.maxDisplayDuration {
                self.hide()
            }
            return
        }
        guard let dueAt = self.dueAt, self.playback >= dueAt else {
            return
        }
        if let pending = self.pending {
            self.show(pending)
        } else if !self.inFlight {
            self.requestNext()
        }
    }

    private func requestFirst(messageId: Int64) {
        self.requested = true
        self.inFlight = true
        let firstPlayback = self.playback
        let context = self.context
        let peerId = self.peerId
        let channelId = self.channelId
        let slot = SDKAdSlot.video(channelId: NovagramChannelAds.requestChannelId(channelId), messageId: messageId)
        let signal = NovagramChannelAds.eligibleChannel(context: context, peerId: peerId, channelId: channelId)
        |> mapToSignal { peer -> Signal<SDKServedAd?, NoError> in
            guard peer != nil else {
                return .single(nil)
            }
            return NovagramSponsored.session(context: context)
            |> mapToSignal { session -> Signal<SDKServedAd?, NoError> in
                guard let session else {
                    return .single(nil)
                }
                return novagramAsyncSignal {
                    return await session.ad(for: slot)
                }
            }
        }
        |> deliverOnMainQueue
        self.requestDisposable.set(signal.startStrict(next: { [weak self] served in
            guard let self else {
                return
            }
            self.inFlight = false
            if let served = self.accept(served) {
                self.pending = served
                self.dueAt = firstPlayback + self.timers.startDelay
            } else {
                self.dueAt = self.playback + self.timers.betweenDelay
            }
            self.evaluate()
            self.notify()
        }))
    }

    /// After a banner hid (or an empty answer): bypass the cache (contract §3.4).
    private func requestNext() {
        self.inFlight = true
        let context = self.context
        let slot = SDKAdSlot.video(channelId: NovagramChannelAds.requestChannelId(self.channelId), messageId: self.lastMessageId)
        let signal = NovagramSponsored.session(context: context)
        |> mapToSignal { session -> Signal<SDKServedAd?, NoError> in
            guard let session else {
                return .single(nil)
            }
            return novagramAsyncSignal {
                return await session.nextVideoAd(for: slot)
            }
        }
        |> deliverOnMainQueue
        self.requestDisposable.set(signal.startStrict(next: { [weak self] served in
            guard let self else {
                return
            }
            self.inFlight = false
            if let served = self.accept(served) {
                self.show(served)
            } else {
                self.dueAt = self.playback + self.timers.betweenDelay
            }
            self.notify()
        }))
    }

    /// Records the answer; nil for an empty answer or an ad the user reported.
    private func accept(_ served: SDKServedAd?) -> SDKServedAd? {
        let userId = NovagramSponsored.userId(self.context)
        guard let served, !NovagramSponsored.registry.isHidden(token: served.ad.randomId) else {
            NovagramSponsored.logger.debug("VIDEO: no ad")
            return nil
        }
        NovagramSponsored.registry.remember(served, userId: userId)
        self.hadAd = true
        self.timers = served.videoTimers ?? .fallback
        NovagramSponsored.logger.debug("VIDEO source=novagram start=\(self.timers.startDelay, privacy: .public) min=\(self.timers.minDisplayDuration, privacy: .public) max=\(self.timers.maxDisplayDuration, privacy: .public) between=\(self.timers.betweenDelay, privacy: .public)")
        return served
    }

    private func show(_ served: SDKServedAd) {
        let strings = self.context.sharedContext.currentPresentationData.with { $0 }.strings
        let durations = (min: Int32(self.timers.minDisplayDuration.rounded(.up)), max: Int32(self.timers.maxDisplayDuration.rounded(.up)))
        let message = NovagramAdMessage.make(served: served, peerId: self.peerId, chatPeer: nil, strings: strings, displayDurations: durations)
        self.showing = Showing(served: served, message: message, shownAt: self.playback)
        self.pending = nil
        self.dueAt = nil
        self.notify()
    }

    private func hide() {
        self.showing = nil
        self.dueAt = self.playback + self.timers.betweenDelay
        self.notify()
    }

    private func notify() {
        for update in self.handles.values {
            update()
        }
    }
}

/// One gallery item's view of its channel's VIDEO-slot state.
final class NovagramVideoAdHandleImpl: NovagramVideoAdHandle {
    private let context: AccountContext
    private let state: NovagramVideoChannelState?
    private let messageId: Int64

    init(context: AccountContext, state: NovagramVideoChannelState?, messageId: Int64, onUpdate: @escaping () -> Void) {
        self.context = context
        self.state = state
        self.messageId = messageId
        state?.attach(ObjectIdentifier(self), update: onUpdate)
    }

    deinit {
        // The gallery releases item nodes on the main queue.
        let id = ObjectIdentifier(self)
        if let state = self.state {
            Queue.mainQueue().async {
                state.detach(id)
            }
        }
    }

    func setPlaying(_ isPlaying: Bool) {
        self.state?.setPlaying(ObjectIdentifier(self), isPlaying: isPlaying, messageId: self.messageId)
    }

    func resolveBanner(telegram: (initialTimestamp: Int32, message: Message?)?) -> (initialTimestamp: Int32, message: Message?)? {
        guard NovagramShowAdsGate.isEnabled else {
            return nil
        }
        if let banner = self.state?.currentBanner() {
            return (banner.initialTimestamp, banner.message)
        }
        // Novagram ads first; Telegram's only as a fallback and never for Premium users.
        if self.state?.suppressesFallback == true || self.context.isPremium {
            return nil
        }
        return telegram
    }

    func recordViewIfOurs(_ message: Message) -> Bool {
        guard let token = self.token(message) else {
            return false
        }
        NovagramSponsored.recordView(token: token)
        return true
    }

    func closeIfOurs(_ message: Message, available: Bool) -> Bool {
        guard let token = self.token(message) else {
            return false
        }
        // Before min_display_duration the control is inactive; there is no Premium upsell on our banner.
        if available {
            self.state?.close(token: token)
        }
        return true
    }

    func clickIfOurs(_ message: Message, open: @escaping (String) -> Void) -> Bool {
        guard let token = self.token(message), let attribute = message.attributes.first(where: { $0 is AdMessageAttribute }) as? AdMessageAttribute else {
            return false
        }
        let url = attribute.url
        self.state?.hideAfterClick(token: token)
        NovagramSponsored.recordClick(token: token, thenOpen: {
            open(url)
        })
        return true
    }

    private func token(_ message: Message) -> String? {
        guard let attribute = message.attributes.first(where: { $0 is AdMessageAttribute }) as? AdMessageAttribute else {
            return nil
        }
        return NovagramSponsored.token(opaqueId: attribute.opaqueId)
    }
}
