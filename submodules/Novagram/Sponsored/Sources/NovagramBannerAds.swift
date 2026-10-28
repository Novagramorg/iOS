import Foundation
import UIKit
import SwiftSignalKit
import AccountContext
import NovagramAds

/// A chat-list banner, neutral so this module needs no GlobalControlPanelsContext dependency; the hook
/// in `GlobalControlPanelsContext.swift` maps it to Telegram's `.link` chat-list notice.
public struct NovagramBannerNotice: Equatable {
    /// `novagram-banner:<uuid>` (closable) or `novagram-banner-fixed:<uuid>` (no "X", contract §2.4).
    public let id: String
    /// Empty when the banner is not tappable.
    public let url: String
    public let title: String
    public let text: String
}

/// System banners above the chat list (`/api/banner_ads/*`, contract §2.4–2.6). OURS-FIRST: while one
/// is live it takes the chat-list notice slot; otherwise Telegram's own notices show unchanged.
public enum NovagramBannerAds {
    static let closablePrefix = "novagram-banner:"
    static let fixedPrefix = "novagram-banner-fixed:"
    static let changedNotification = Notification.Name("NovagramBannerChanged")
    static let store = NovagramBannerStore()

    /// The first live, not-closed banner of the account. Refreshes on subscribe (app start, account
    /// switch) and when the app returns to the foreground; the feed itself throttles to 15 minutes.
    /// While a banner is on screen, its `ends_at` is re-checked by a timer (contract §2.4).
    public static func bannerNotice(context: AccountContext) -> Signal<NovagramBannerNotice?, NoError> {
        guard let feed = NovagramSponsored.bannerFeed(context: context) else {
            return .single(nil)
        }
        let userId = NovagramSponsored.userId(context)
        let source = Signal<NovagramBannerNotice?, NoError> { subscriber in
            let subscription = NovagramBannerSubscription(feed: feed, userId: userId, emit: { notice in
                subscriber.putNext(notice)
            })
            subscription.start()
            return ActionDisposable {
                subscription.stop()
            }
        }
        // nil first: the chat-list notice combineLatest must never wait for our network call.
        return NovagramSponsored.gated(empty: nil, .single(nil) |> then(source))
        |> distinctUntilChanged
    }

    static func notice(_ banner: SDKBannerAd) -> NovagramBannerNotice {
        let prefix = banner.dismissible ? self.closablePrefix : self.fixedPrefix
        return NovagramBannerNotice(
            id: prefix + banner.id.uuidString,
            url: banner.linkURL?.absoluteString ?? "",
            title: banner.title,
            text: banner.text
        )
    }

    static func bannerId(noticeId: String) -> UUID? {
        for prefix in [self.closablePrefix, self.fixedPrefix] where noticeId.hasPrefix(prefix) {
            return UUID(uuidString: String(noticeId.dropFirst(prefix.count)))
        }
        return nil
    }

    /// The url to open for a tap on a chat-list `.link` notice. Telegram's own notices get `url` back
    /// unchanged; OUR banner counts the click and returns its link, or nil when it is not tappable.
    public static func urlForTap(noticeId: String, url: String, context: AccountContext) -> String? {
        guard let bannerId = self.bannerId(noticeId: noticeId) else {
            return url
        }
        guard let banner = self.store.banner(id: bannerId), let link = banner.linkURL else {
            return nil
        }
        if let feed = NovagramSponsored.bannerFeed(context: context) {
            // Fire-and-forget: the link opens without waiting for the click request.
            Task {
                _ = await feed.click(banner)
            }
        }
        return link.absoluteString
    }

    /// Closes OUR banner: hidden at once, remembered by the feed, sent to the server (retried later when
    /// offline). Returns false for Telegram's own `.link` notices.
    public static func dismissIfOurs(noticeId: String, context: AccountContext) -> Bool {
        guard let bannerId = self.bannerId(noticeId: noticeId) else {
            return false
        }
        self.store.close(userId: NovagramSponsored.userId(context), id: bannerId)
        NotificationCenter.default.post(name: self.changedNotification, object: nil)
        if let banner = self.store.banner(id: bannerId), let feed = NovagramSponsored.bannerFeed(context: context) {
            Task {
                await feed.dismiss(banner)
            }
        }
        return true
    }
}

/// Reloads one account's banner: on start, on foreground, after a close, and when the shown banner's
/// `ends_at` passes. Results are applied on the main queue; a newer reload wins over an older one.
final class NovagramBannerSubscription {
    private let feed: SDKBannerFeed
    private let userId: Int64
    private let emit: (NovagramBannerNotice?) -> Void
    private let generation = Atomic<Int>(value: 0)
    private var observers: [NSObjectProtocol] = []
    /// Main queue only.
    private var expiryTimer: SwiftSignalKit.Timer?
    /// Main queue only: a reload finishing after `stop()` must not schedule a new timer.
    private var isStopped = false

    init(feed: SDKBannerFeed, userId: Int64, emit: @escaping (NovagramBannerNotice?) -> Void) {
        self.feed = feed
        self.userId = userId
        self.emit = emit
    }

    func start() {
        self.reload(refresh: true)
        self.observers.append(NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.reload(refresh: true)
        })
        self.observers.append(NotificationCenter.default.addObserver(forName: NovagramBannerAds.changedNotification, object: nil, queue: .main) { [weak self] _ in
            self?.reload(refresh: false)
        })
    }

    func stop() {
        for observer in self.observers {
            NotificationCenter.default.removeObserver(observer)
        }
        self.observers.removeAll()
        // Dispose can come from any queue; the timer lives on the main queue (strong self until then).
        Queue.mainQueue().async {
            self.isStopped = true
            self.expiryTimer?.invalidate()
            self.expiryTimer = nil
        }
    }

    private func reload(refresh: Bool) {
        let current = self.generation.modify { $0 + 1 }
        let feed = self.feed
        let userId = self.userId
        Task { [weak self] in
            if refresh {
                await feed.refresh()
            }
            let banner = await feed.banners().first(where: { !NovagramBannerAds.store.isClosed(userId: userId, id: $0.id) })
            Queue.mainQueue().async {
                // A newer reload started meanwhile: let it report instead.
                guard let self, !self.isStopped, self.generation.with({ $0 }) == current else {
                    return
                }
                if let banner {
                    NovagramBannerAds.store.remember(banner)
                }
                self.scheduleExpiry(banner?.endsAt)
                self.emit(banner.map(NovagramBannerAds.notice))
            }
        }
    }

    /// Replaces the previous timer; `feed.banners()` drops the expired banner on the reload it triggers.
    private func scheduleExpiry(_ endsAt: Date?) {
        self.expiryTimer?.invalidate()
        self.expiryTimer = nil
        guard let endsAt else {
            return
        }
        let delay = max(1.0, endsAt.timeIntervalSinceNow + 1.0)
        let timer = SwiftSignalKit.Timer(timeout: delay, repeat: false, completion: { [weak self] in
            self?.reload(refresh: false)
        }, queue: Queue.mainQueue())
        self.expiryTimer = timer
        timer.start()
    }
}

/// Banners shown so far (to answer taps) and banners closed in this run, per account (hidden before
/// the feed knows).
final class NovagramBannerStore: @unchecked Sendable {
    private struct ClosedKey: Hashable {
        let userId: Int64
        let id: UUID
    }

    private let lock = NSLock()
    private var banners: [UUID: SDKBannerAd] = [:]
    private var closedKeys = Set<ClosedKey>()

    func remember(_ banner: SDKBannerAd) {
        self.lock.lock()
        self.banners[banner.id] = banner
        self.lock.unlock()
    }

    func banner(id: UUID) -> SDKBannerAd? {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.banners[id]
    }

    func close(userId: Int64, id: UUID) {
        self.lock.lock()
        self.closedKeys.insert(ClosedKey(userId: userId, id: id))
        self.lock.unlock()
    }

    func isClosed(userId: Int64, id: UUID) -> Bool {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.closedKeys.contains(ClosedKey(userId: userId, id: id))
    }
}
