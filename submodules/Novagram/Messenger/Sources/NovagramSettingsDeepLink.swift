import Foundation
import UIKit
import Display
import AccountContext
import ItemListUI

// Feature #40 (part c): per-feature deep links into the Novagram settings screen.
//
//   tg://settings/novagrampro            → opens the screen, no scrolling, no animation
//   tg://settings/novagrampro/<slug>     → opens it, scrolls that row into view, traces an outline
//   tg://settings/novagrampro?f=<slug>   → same as above (accepted as an alias)
//
// The path form is canonical because upstream strips the query string before a settings URL ever
// reaches the resolver: `OpenUrl.swift` builds the path from `parsedUrl.pathComponents` only. The
// `?f=` alias is rewritten into the path form by a hook in `OpenUrl.swift`.

/// One shareable row of the Novagram settings screen.
///
/// The raw value is the slug that travels inside the link, so a case must never be renamed —
/// links already shared would stop resolving. Add a new case instead.
public enum NovagramSettingsFeature: String, CaseIterable {
    // Top rows
    case about = "about"
    case accounts = "accounts"
    case bots = "bots"

    // Interface
    case hideFolders = "hide-folders"
    case stories = "stories"
    case mutualContacts = "mutual-contacts"
    case unlimitedPins = "unlimited-pins"

    // Calls (same slug as the Mac)
    case callDataSaving = "call-data-saving"
    case callRecording = "call-recording"
    case callRecordingAuto = "call-recording-auto"
    case callRecordings = "call-recordings"

    // Chat
    case deletedMessages = "deleted-messages"
    case editedHistory = "edited-history"
    case firstMessage = "first-message"
    case ghostMode = "ghost-mode"
    case cameraPicker = "camera-picker"
    case roundVideo = "round-video"
    case forwardHideNames = "forward-hide-names"

    // Messaging
    case textStyle = "text-style"
    case autoText = "auto-text"
    case autoTranslate = "auto-translate"
    case translateButton = "translate-button"
    case translateLanguage = "translate-language"
    case translateOnSend = "translate-on-send"
    case autoSticker = "auto-sticker"
    case heartEffect = "heart-effect"

    // Voice → text
    case voiceToText = "voice-to-text"
    case voiceLanguage = "voice-language"
    case voiceTranslate = "voice-translate"

    // CarPlay
    case carPlay = "carplay"

    // Protection
    case blockForeign = "block-foreign"
    case chatLock = "chat-lock"
    case autoDownload = "auto-download"
    case sendConfirm = "send-confirm"
    case proxy = "proxy"

    // Appearance
    case whiteAccent = "white-accent"

    // Hidden chats
    case hiddenChats = "hidden-chats"
    case hiddenChatsBiometrics = "hidden-chats-biometrics"

    // Unread reminder
    case reminder = "reminder"
    case reminderTime = "reminder-time"
    case reminderSound = "reminder-sound"

    // Features
    case recommendedFolders = "recommended-folders"
    case foldersPrompt = "folders-prompt"
    case adminFolders = "admin-folders"
    case folderStyle = "folder-style"
    case channelHistory = "channel-history"
    case settingsLinks = "settings-links"
    case autoAccept = "auto-accept"
    case shareLink = "share-link"
    case storySaving = "story-saving"
    // Slug avoids "unlock" on purpose — it surfaces in the share sheet, and no user-visible
    // string in this fork may read as circumventing a paid tier (Apple 3.1.1).
    case translateChatsUnlock = "translate-entire-chats"
    // The hidden ads row deliberately has no deep link: it is reachable only through the
    // 10-tap gesture + admin login.
}

extension NovagramSettingsFeature {
    /// False for a row that lives in the Developer section while that section is hidden or the logged-in
    /// role cannot see the row: the slug then lands on the screen without scrolling or highlighting, like
    /// an unknown slug.
    var isAvailable: Bool {
        let item: NovagramDeveloperRole.Switch
        switch self {
        case .callRecording, .callRecordingAuto, .callRecordings:
            item = .callRecording
        case .callDataSaving:
            item = .callDataSaving
        default:
            return true
        }
        return NovagramDeveloperSection.isRevealed && NovagramDeveloperRole.current.canUse(item)
    }
}

/// Marks a settings row so the deep-link handler can scroll to it and the long-press menu can
/// tell which feature was pressed. Consumed by `ItemListController.itemNode(forTag:)` and by
/// `ItemListNodeState.ensureVisibleItemTag`.
public struct NovagramSettingsItemTag: ItemListItemTag, Equatable {
    public let feature: NovagramSettingsFeature

    public init(feature: NovagramSettingsFeature) {
        self.feature = feature
    }

    public func isEqual(to other: ItemListItemTag) -> Bool {
        guard let other = other as? NovagramSettingsItemTag else {
            return false
        }
        return self.feature == other.feature
    }
}

public enum NovagramSettingsDeepLink {
    /// What a `tg://settings/...` path asks for.
    public enum Target: Equatable {
        case screen
        case feature(NovagramSettingsFeature)
    }

    /// First path component of every Novagram settings link. Also the legacy bare link.
    public static let rootPath = "novagrampro"
    /// Query parameter accepted by the `?f=<slug>` alias.
    public static let featureQueryKey = "f"

    private static let scheme = "tg://settings/"

    /// Link that opens the settings screen with nothing highlighted.
    public static var screenLink: String {
        return self.scheme + self.rootPath
    }

    /// Link that opens the settings screen, scrolls to `feature` and traces an outline around it.
    public static func link(for feature: NovagramSettingsFeature) -> String {
        return self.scheme + self.rootPath + "/" + feature.rawValue
    }

    /// Reads an already-resolved `ResolvedUrl.settings(.path(...))` payload.
    /// Returns nil when the path belongs to Telegram's own settings deep links.
    public static func target(forSettingsPath path: String) -> Target? {
        let components = path.split(separator: "/").map(String.init)
        guard let root = components.first, root.lowercased() == self.rootPath else {
            return nil
        }
        guard components.count > 1 else {
            return .screen
        }
        guard let feature = NovagramSettingsFeature(rawValue: components[1].lowercased()), feature.isAvailable else {
            // Unknown slug (older build, typo, future feature) — still land on the screen rather
            // than falling through to Telegram's generic handler, which would silently do nothing.
            // A slug whose row is behind an off Developer switch is treated the same way.
            return .screen
        }
        return .feature(feature)
    }

    /// Rewrites the `tg://settings/novagrampro?f=<slug>` alias into the canonical path form.
    /// Returns nil when the URL is not ours, so the caller can fall through untouched.
    public static func settingsPath(forUrlPath urlPath: String, featureParameter: String?) -> String? {
        let components = urlPath.split(separator: "/").map(String.init)
        guard components.count == 1, components[0].lowercased() == self.rootPath else {
            return nil
        }
        guard let featureParameter, let feature = NovagramSettingsFeature(rawValue: featureParameter.lowercased()) else {
            return self.rootPath
        }
        return self.rootPath + "/" + feature.rawValue
    }

    /// Single entry point for the `OpenResolvedUrl.swift` hook. Returns true when the path was
    /// ours and the screen has been pushed.
    @discardableResult
    public static func open(settingsPath path: String, context: AccountContext, navigationController: NavigationController) -> Bool {
        guard let target = self.target(forSettingsPath: path) else {
            return false
        }
        let highlight: NovagramSettingsFeature?
        switch target {
        case .screen:
            highlight = nil
        case let .feature(feature):
            highlight = feature
        }
        navigationController.pushViewController(novagramSettingsController(context: context, highlightFeature: highlight))
        return true
    }
}

// MARK: - Local string namespace (per-feature link menu)
// Kept in NovagramMessenger to avoid parallel-edit hazard on the shared Localization module.

enum NovagramSettingsLinkStrings {
    static func menuTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Ushbu sozlamaga havola"
        case "ru": return "Ссылка на эту настройку"
        case "zh": return "此设置的链接"
        default:   return "Link to this setting"
        }
    }

    static func copyLink(langCode: String) -> String {
        switch langCode {
        case "uz": return "Havolani nusxalash"
        case "ru": return "Копировать ссылку"
        case "zh": return "复制链接"
        default:   return "Copy link"
        }
    }

    static func shareLink(langCode: String) -> String {
        switch langCode {
        case "uz": return "Havolani ulashish"
        case "ru": return "Поделиться ссылкой"
        case "zh": return "分享链接"
        default:   return "Share link"
        }
    }

    static func copied(langCode: String) -> String {
        switch langCode {
        case "uz": return "Havola nusxalandi"
        case "ru": return "Ссылка скопирована"
        case "zh": return "链接已复制"
        default:   return "Link copied"
        }
    }

    /// Discoverability hint appended to the Features section footer.
    static func longPressHint(langCode: String) -> String {
        switch langCode {
        case "uz": return "Istalgan qatorni bosib turing — o'sha sozlamaning shaxsiy havolasini olasiz."
        case "ru": return "Нажмите и удерживайте любую строку — получите ссылку именно на эту настройку."
        case "zh": return "长按任意一行，即可获取直达该设置的链接。"
        default:   return "Press and hold any row to get a link straight to that setting."
        }
    }
}
