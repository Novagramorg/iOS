import Foundation
import Postbox
import TelegramCore
import AccountContext
import Display

/// A thin, dependency-light entry point for modules that cannot depend on `NovagramSponsored`
/// (GalleryUI and chat bubble components sit below it in the dependency graph). The implementation is
/// installed by `NovagramSponsored` when its core is first used (app start: the chat-list banner source).
///
/// Product rule (same for every surface): Novagram ads first; Telegram's ads only as a fallback and
/// never for Premium users. The "Show ads" toggle hides both.
public enum NovagramSponsoredBridge {
    public static let opaqueIdPrefix = "novagram:"

    /// The installed implementation, or nil before `NovagramSponsored` started (or in a target without it).
    public static var provider: NovagramAdsProvider?

    /// True for the `AdMessageAttribute.opaqueId` of one of OUR ads.
    public static func isOurs(opaqueId: Data) -> Bool {
        guard let value = String(data: opaqueId, encoding: .utf8) else {
            return false
        }
        return value.hasPrefix(self.opaqueIdPrefix) && value.count > self.opaqueIdPrefix.count
    }

    /// True when `message` is one of OUR sponsored messages.
    public static func isOurs(_ message: Message) -> Bool {
        guard let attribute = message.attributes.first(where: { $0 is AdMessageAttribute }) as? AdMessageAttribute else {
            return false
        }
        return self.isOurs(opaqueId: attribute.opaqueId)
    }

    /// OUR ad's display durations (from the server), or nil for Telegram's own ads.
    public static func displayDurations(_ message: Message) -> (min: Int32, max: Int32)? {
        guard let attribute = message.attributes.first(where: { $0 is AdMessageAttribute }) as? AdMessageAttribute, self.isOurs(opaqueId: attribute.opaqueId) else {
            return nil
        }
        guard let minDuration = attribute.minDisplayDuration, let maxDuration = attribute.maxDisplayDuration else {
            return nil
        }
        return (minDuration, maxDuration)
    }
}

public protocol NovagramAdsProvider: AnyObject {
    /// A per-gallery-item handle for the VIDEO slot. Always returned for a message (even when the
    /// channel is not eligible) so the fallback rules for Telegram's own video ads apply too.
    func videoAdHandle(context: AccountContext, message: Message, onUpdate: @escaping () -> Void) -> NovagramVideoAdHandle

    /// Records `video_open` for OUR ad (full-screen open of its video). False for Telegram's ads.
    func recordVideoOpenIfOurs(opaqueId: Data) -> Bool

    /// Presents the About / Report sheet for OUR ad. False for Telegram's ads (caller keeps its path).
    func presentMenuIfOurs(opaqueId: Data, context: AccountContext, present: @escaping (ViewController) -> Void) -> Bool
}

/// The VIDEO-slot state as one gallery item's overlay sees it. Timers run on playback time and are
/// shared by every gallery item of the same channel.
public protocol NovagramVideoAdHandle: AnyObject {
    /// Feed the item's playback state (true only while its video is actually playing).
    func setPlaying(_ isPlaying: Bool)

    /// The banner to draw now: OUR banner, Telegram's `telegram` candidate as a fallback, or nil.
    /// `initialTimestamp` keeps the countdown component on playback time (it stays put while paused).
    func resolveBanner(telegram: (initialTimestamp: Int32, message: Message?)?) -> (initialTimestamp: Int32, message: Message?)?

    /// Counts a view of OUR banner. False for Telegram's ads.
    func recordViewIfOurs(_ message: Message) -> Bool

    /// The banner's close control was pressed. For OUR banner it closes only when allowed
    /// (`min_display_duration` reached) and never offers Premium. False for Telegram's ads.
    func closeIfOurs(_ message: Message, available: Bool) -> Bool

    /// The banner was tapped: queues OUR click, hides the banner, then calls `open` with the url on the
    /// main queue. False for Telegram's ads.
    func clickIfOurs(_ message: Message, open: @escaping (String) -> Void) -> Bool
}
