import Foundation
import UIKit
import os
import SwiftSignalKit
import TelegramCore
import AccountContext
import PhoneNumberFormat
import NovagramMessenger
import NovagramSponsoredBridge
import NovagramAds

/// Novagram ads (serving v2) — the shared core.
///
/// One `SDKClient` for the app, one `SDKAdsSession` and one `SDKBannerFeed` per Telegram account,
/// all kept for the app's lifetime (contract §4.1: tokens are valid only for the account they were
/// served to). Every surface is gated by `NovagramShowAdsGate` and shows ads to every user, Telegram
/// Premium included. The build only picks an SDK environment; the SDK binary carries the rest.
///
/// OUR sponsored messages carry an `AdMessageAttribute` whose `opaqueId` is `novagram:<random_id>`,
/// so the Telegram-owned hooks can tell them apart from Telegram's own ads.
///
/// Product rule, applied by `oursFirst` on every surface: Novagram ads first (to every user, Premium
/// included; all their events go only to our backend); Telegram's ads only as a fallback — when our
/// backend has no ad for the slot — and never for Premium users. "Remove all ads" hides both.
public enum NovagramSponsored {
    static let logger = Logger(subsystem: "uz.fenixuz.app", category: "NovagramAds")
    static let opaqueIdPrefix = "novagram:"
    static let registry = NovagramAdsRegistry()

    /// The environment compiled in from `--define=novagramAdsEnvironment`; production when the value is
    /// empty or unknown.
    static let environment: SDKEnvironment = {
        return SDKEnvironment(rawValue: NovagramSponsoredGeneratedEnvironment.name) ?? .production
    }()

    /// True when this build can serve ads (the SDK client exists).
    public static var isConfigured: Bool {
        return registry.client != nil
    }

    static func userId(_ context: AccountContext) -> Int64 {
        return context.account.peerId.id._internalGetInt64Value()
    }

    // MARK: - Opaque ids

    /// True for the `AdMessageAttribute.opaqueId` of one of OUR ads.
    public static func isOurs(opaqueId: Data) -> Bool {
        return token(opaqueId: opaqueId) != nil
    }

    static func opaqueId(token: String) -> Data {
        return Data((opaqueIdPrefix + token).utf8)
    }

    static func token(opaqueId: Data) -> String? {
        guard let value = String(data: opaqueId, encoding: .utf8), value.hasPrefix(opaqueIdPrefix) else {
            return nil
        }
        let token = String(value.dropFirst(opaqueIdPrefix.count))
        return token.isEmpty ? nil : token
    }

    // MARK: - Product rule

    /// The state of OUR side of a slot: still asking, nothing to show, or an ad.
    enum Slot<T> {
        case pending
        case none
        case ad(T)
    }

    /// Live Telegram Premium status of the account (Telegram's fallback ads are never shown to Premium).
    static func isPremium(context: AccountContext) -> Signal<Bool, NoError> {
        return context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
        |> map { peer -> Bool in
            return peer?.isPremium ?? false
        }
        |> distinctUntilChanged
    }

    /// Wraps OUR result as pending → none / ad, so Telegram's fallback never flashes before ours.
    static func slot<T>(_ ours: Signal<T?, NoError>) -> Signal<Slot<T>, NoError> {
        return .single(.pending)
        |> then(ours |> map { value -> Slot<T> in
            if let value {
                return .ad(value)
            }
            return .none
        })
    }

    /// Novagram ads first; Telegram's `fallback` only when our backend has no ad, never for Premium
    /// users; both hidden while "Remove all ads" is on. Logs which source is on screen
    /// (`<surface> source=novagram|telegram|none`, debug level) whenever it changes.
    static func oursFirst<Ours, Value>(context: AccountContext, surface: String, ours: Signal<Ours?, NoError>, fallback: Signal<Value, NoError>, empty: Value, isEmpty: @escaping (Value) -> Bool, map transform: @escaping (Ours) -> Value) -> Signal<Value, NoError> {
        let lastSource = Atomic<String?>(value: nil)
        let combined = combineLatest(self.slot(ours), fallback, self.isPremium(context: context))
        |> map { ours, fallback, isPremium -> Value in
            let value: Value
            let source: String
            switch ours {
            case let .ad(ad):
                value = transform(ad)
                source = "novagram"
            case .pending:
                value = empty
                source = "none"
            case .none:
                value = isPremium ? empty : fallback
                source = isEmpty(value) ? "none" : "telegram"
            }
            if lastSource.swap(source) != source {
                logger.debug("\(surface, privacy: .public) source=\(source, privacy: .public)\(isPremium ? " (premium)" : "", privacy: .public)")
            }
            return value
        }
        return self.gated(empty: empty, combined)
    }

    // MARK: - Serving

    /// The account's session, created (and started) on first use with the account's targeting.
    static func session(context: AccountContext) -> Signal<SDKAdsSession?, NoError> {
        guard let client = registry.client else {
            return .single(nil)
        }
        let userId = self.userId(context)
        registry.setContext(context, userId: userId)
        if let session = registry.existingSession(userId: userId) {
            return .single(session)
        }
        return context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
        |> map { accountPeer -> SDKAdsSession? in
            let targeting = self.targeting(context: context, accountPeer: accountPeer)
            return registry.session(userId: userId, client: client, targeting: targeting)
        }
    }

    /// Contract §5: phone country by calling code (never the number itself), interface language,
    /// platform and app version.
    static func targeting(context: AccountContext, accountPeer: EnginePeer?) -> SDKAdTargeting {
        var phoneCountry: String?
        if case let .user(user) = accountPeer, let phone = user.phone, !phone.isEmpty {
            let countries = context.currentCountriesConfiguration.with { $0 }
            phoneCountry = lookupCountryIdByNumber(phone, configuration: countries)?.0.id
        }
        let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
        return SDKAdTargeting(
            phoneCountry: phoneCountry,
            lang: strings.baseLanguageCode,
            platform: "ios",
            appVersion: SDKAdTargeting.bundleAppVersion
        )
    }

    /// The ad for `slot` (cached by the session for `ttl_seconds`), minus ads hidden locally.
    static func visibleAd(context: AccountContext, slot: SDKAdSlot) -> Signal<SDKServedAd?, NoError> {
        let userId = self.userId(context)
        let served = session(context: context)
        |> mapToSignal { session -> Signal<SDKServedAd?, NoError> in
            guard let session else {
                return .single(nil)
            }
            return novagramAsyncSignal {
                return await session.ad(for: slot)
            }
        }
        |> map { served -> SDKServedAd? in
            logger.debug("\(slot.placement, privacy: .public): \(served == nil ? "no ad" : "ad served", privacy: .public)")
            if let served {
                registry.remember(served, userId: userId)
            }
            return served
        }
        return combineLatest(served, registry.hiddenVersion.get())
        |> map { served, _ -> SDKServedAd? in
            guard let served, !registry.isHidden(token: served.ad.randomId) else {
                return nil
            }
            return served
        }
    }

    /// Mirrors `source` while ads are allowed; emits `empty` while the hidden "Remove all ads" toggle is on.
    static func gated<T>(empty: T, _ source: Signal<T, NoError>) -> Signal<T, NoError> {
        return NovagramShowAdsGate.gate(empty: empty, source: source)
    }

    /// The chat-list notice slot while the hidden "Remove all ads" toggle is on: Telegram's promo and
    /// server notices (and our banner) are dropped, security notices (`isSecurity`) stay. Re-evaluates
    /// live when the toggle flips.
    public static func gatedNotice<T: Equatable>(_ source: Signal<T?, NoError>, isSecurity: @escaping (T) -> Bool) -> Signal<T?, NoError> {
        return combineLatest(source, NovagramShowAdsGate.enabledSignal |> distinctUntilChanged)
        |> map { notice, adsShown -> T? in
            guard !adsShown, let notice else {
                return notice
            }
            return isSecurity(notice) ? notice : nil
        }
        |> distinctUntilChanged
    }

    // MARK: - Events (called from the Telegram-owned hooks)

    /// Counts a view of OUR ad (the whole text was on screen). Returns false for Telegram's own ads.
    /// Repeats are ignored locally and by the SDK (one `view` per `random_id`).
    @discardableResult
    public static func recordViewIfOurs(opaqueId: Data) -> Bool {
        guard let token = token(opaqueId: opaqueId) else {
            return false
        }
        recordView(token: token)
        return true
    }

    /// Queues a click on OUR ad, then calls `open` on the main queue (contract §4.4: the click goes into the
    /// persistent queue before the url opens; it never waits for the network). Returns false — and does not
    /// call `open` — for Telegram's own ads, so the caller keeps its own path for those.
    public static func recordClickIfOurs(opaqueId: Data, thenOpen open: @escaping () -> Void) -> Bool {
        guard let token = token(opaqueId: opaqueId) else {
            return false
        }
        recordClick(token: token, thenOpen: open)
        return true
    }

    /// Records `video_open` for OUR ad (its video opened full screen; the SDK ignores it unless the
    /// ad's media is a VIDEO). Returns false for Telegram's own ads.
    public static func recordVideoOpenIfOurs(opaqueId: Data) -> Bool {
        guard let token = token(opaqueId: opaqueId) else {
            return false
        }
        if self.skipEvent("video_open", token: token) {
            return true
        }
        logger.debug("video_open → novagram \(masked(token), privacy: .public)")
        guard let entry = registry.served(token: token), let session = registry.existingSession(userId: entry.userId) else {
            return true
        }
        let served = entry.ad
        Task {
            await session.recordVideoOpen(served)
        }
        return true
    }

    /// Hides OUR ad locally for its `random_id` (bot panel "X"; no server call, contract §3.2).
    /// Returns false for Telegram's own ads.
    public static func hideIfOurs(opaqueId: Data) -> Bool {
        guard let token = token(opaqueId: opaqueId) else {
            return false
        }
        registry.hide(token: token)
        return true
    }

    /// `random_id` for logs: first 8 characters only.
    static func masked(_ token: String) -> String {
        return String(token.prefix(8)) + "…"
    }

    /// True while the Developer switch "Don't send ad events" is on: the event is neither sent nor queued,
    /// and the caller must not mark the ad as viewed either, so a once-per-user ad keeps showing.
    static func skipEvent(_ event: String, token: String) -> Bool {
        guard NovagramDeveloperFlags.isAdEventsOff else {
            return false
        }
        logger.info("\(event, privacy: .public) → not sent (developer: ad events off) \(masked(token), privacy: .public)")
        return true
    }

    static func recordView(token: String) {
        if self.skipEvent("view", token: token) {
            return
        }
        guard let entry = registry.served(token: token), registry.markViewed(token: token), let session = registry.existingSession(userId: entry.userId) else {
            return
        }
        logger.debug("view → novagram \(masked(token), privacy: .public)")
        let served = entry.ad
        Task {
            await session.recordView(served)
        }
    }

    static func recordClick(token: String, thenOpen open: (() -> Void)? = nil) {
        if self.skipEvent("click", token: token) {
            // The ad still opens; without a click there is no action to watch for.
            if let open {
                Queue.mainQueue().async(open)
            }
            return
        }
        logger.debug("click → novagram \(masked(token), privacy: .public)")
        guard let entry = registry.served(token: token), let session = registry.existingSession(userId: entry.userId) else {
            if let open {
                Queue.mainQueue().async(open)
            }
            return
        }
        let served = entry.ad
        let userId = entry.userId
        Task {
            // Only persists the event to the on-disk queue (a few ms); the request is sent later.
            await session.recordClick(served)
            Queue.mainQueue().async {
                // The click is queued: now watch for the join / Start that makes it an `action`.
                if let context = registry.context(userId: userId) {
                    NovagramAdActions.watch(served: served, session: session, context: context)
                }
                open?()
            }
        }
    }

    /// Reports OUR ad and hides it at once. The caller thanks the user whatever the outcome (contract §6).
    static func report(token: String, reason: SDKAdReportReason) {
        registry.hide(token: token)
        guard let entry = registry.served(token: token), let session = registry.existingSession(userId: entry.userId) else {
            return
        }
        let served = entry.ad
        Task {
            let outcome = await session.report(served, reason: reason)
            if !outcome.isDelivered {
                logger.info("report not delivered: \(String(describing: outcome), privacy: .public)")
            }
        }
    }

    // MARK: - Banners

    static func bannerFeed(context: AccountContext) -> SDKBannerFeed? {
        guard let client = registry.client else {
            return nil
        }
        return registry.bannerFeed(userId: userId(context), client: client)
    }
}

/// Bridges an async call into a one-shot `Signal`; disposing cancels the task.
func novagramAsyncSignal<T>(_ operation: @escaping () async -> T) -> Signal<T, NoError> {
    return Signal { subscriber in
        let task = Task {
            let value = await operation()
            if Task.isCancelled {
                return
            }
            subscriber.putNext(value)
            subscriber.putCompletion()
        }
        return ActionDisposable {
            task.cancel()
        }
    }
}

/// Lock-protected state shared by every surface: the client, per-account sessions and banner feeds,
/// the served ads by `random_id`, and the ads hidden locally until the app restarts.
final class NovagramAdsRegistry: @unchecked Sendable {
    struct ServedEntry {
        let userId: Int64
        let ad: SDKServedAd
    }

    private let lock = NSLock()
    private var clientResolved = false
    private var clientValue: SDKClient?
    private var sessions: [Int64: SDKAdsSession] = [:]
    private var feeds: [Int64: SDKBannerFeed] = [:]
    private var servedAds: [String: ServedEntry] = [:]
    private var viewedTokens = Set<String>()
    private var hiddenTokens = Set<String>()
    private var hiddenCounter = 0
    private var backgroundObserver: NSObjectProtocol?
    private var contexts: [Int64: WeakContext] = [:]

    private final class WeakContext {
        weak var value: AccountContext?

        init(_ value: AccountContext) {
            self.value = value
        }
    }

    /// Bumped whenever an ad gets hidden, so the ad signals re-filter.
    let hiddenVersion = ValuePromise<Int>(0, ignoreRepeated: true)

    init() {
        // The registry is created on the first use of the core — at app start by the chat-list banner
        // source — so GalleryUI / bubble components find the implementation through the bridge.
        NovagramSponsoredBridge.provider = NovagramAdsBridgeProvider()
    }

    private func withLock<T>(_ body: () -> T) -> T {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return body()
    }

    var client: SDKClient? {
        return self.withLock {
            if !self.clientResolved {
                self.clientResolved = true
                self.clientValue = SDKClient(configuration: SDKConfiguration(environment: NovagramSponsored.environment))
            }
            return self.clientValue
        }
    }

    /// The account's context (weak), for watchers that outlive the screen that served the ad.
    func setContext(_ context: AccountContext, userId: Int64) {
        self.withLock {
            if self.contexts[userId]?.value !== context {
                self.contexts[userId] = WeakContext(context)
            }
        }
    }

    func context(userId: Int64) -> AccountContext? {
        return self.withLock {
            return self.contexts[userId]?.value
        }
    }

    func existingSession(userId: Int64) -> SDKAdsSession? {
        return self.withLock {
            return self.sessions[userId]
        }
    }

    func session(userId: Int64, client: SDKClient, targeting: SDKAdTargeting) -> SDKAdsSession {
        var created: SDKAdsSession?
        let session: SDKAdsSession = self.withLock {
            if let current = self.sessions[userId] {
                return current
            }
            // The SDK logger never receives the key and masks random_id (debug level, Console only).
            var configuration = SDKAdsSessionConfiguration.default
            configuration.logger = { message in
                NovagramSponsored.logger.debug("\(message, privacy: .public)")
            }
            let session = SDKAdsSession(client: client, userId: userId, targeting: targeting, configuration: configuration)
            self.sessions[userId] = session
            created = session
            return session
        }
        if let created {
            // Periodic flush; also sends the events left over from the last launch.
            Task {
                await created.start()
            }
            self.observeBackgroundIfNeeded()
        }
        return session
    }

    func bannerFeed(userId: Int64, client: SDKClient) -> SDKBannerFeed {
        return self.withLock {
            if let current = self.feeds[userId] {
                return current
            }
            let feed = SDKBannerFeed(client: client, userId: userId)
            self.feeds[userId] = feed
            return feed
        }
    }

    /// Contract §4.6: the event queue is flushed when the app goes to the background.
    private func observeBackgroundIfNeeded() {
        let needsObserver = self.withLock { self.backgroundObserver == nil }
        guard needsObserver else {
            return
        }
        let observer = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else {
                return
            }
            let sessions = self.withLock { Array(self.sessions.values) }
            for session in sessions {
                Task {
                    await session.flush()
                }
            }
        }
        self.withLock {
            self.backgroundObserver = observer
        }
    }

    func remember(_ served: SDKServedAd, userId: Int64) {
        self.withLock {
            self.servedAds[served.ad.randomId] = ServedEntry(userId: userId, ad: served)
        }
    }

    func served(token: String) -> ServedEntry? {
        return self.withLock {
            return self.servedAds[token]
        }
    }

    /// True the first time a token is seen, so a scrolling list does not spawn a task per frame.
    func markViewed(token: String) -> Bool {
        return self.withLock {
            return self.viewedTokens.insert(token).inserted
        }
    }

    func isHidden(token: String) -> Bool {
        return self.withLock {
            return self.hiddenTokens.contains(token)
        }
    }

    func hide(token: String) {
        let version: Int? = self.withLock {
            guard self.hiddenTokens.insert(token).inserted else {
                return nil
            }
            self.hiddenCounter += 1
            return self.hiddenCounter
        }
        if let version {
            self.hiddenVersion.set(version)
        }
    }
}
