import Foundation
import UIKit
import Display
import AppBundle
import TelegramCore

/// The type badge a block-level button carries in its top-right corner — the same asset set and the
/// same action → icon mapping as a bot keyboard button
/// (`ChatMessageActionButtonsNode.swift:262-306`), so a `pageBlockButtonRow` and a reply-markup row
/// read alike.
///
/// Two deliberate differences from that mapping:
/// - `.url` cannot be resolved into an app / attach-bot link here. That test needs an
///   `AccountContext` to parse the internal URL, which InstantPageUI is not handed; a bare
///   `?startgroup=` check is all that survives, so app links get the plain link icon.
/// - `.openWebApp` gets the web-app icon. The keyboard path leaves it iconless, but only because its
///   switch predates the case — the icon is unambiguous.
///
/// Actions absent here are iconless by intent: `.callback` (nothing to promise the user),
/// `.requestPeer` / `.setupPoll` (keyboard-only, unreachable from `Api.InlineButtonType`), and
/// `.disabled`, which must read as inert.
func instantPageBlockButtonIconName(for action: ReplyMarkupButtonAction) -> String? {
    switch action {
    case .text:
        return "Chat/Message/BotMessage"
    case let .url(value):
        if value.lowercased().contains("?startgroup=") {
            return "Chat/Message/BotAddToChat"
        }
        return "Chat/Message/BotLink"
    case .urlAuth:
        return "Chat/Message/BotLink"
    case .requestPhone:
        return "Chat/Message/BotPhone"
    case .requestMap:
        return "Chat/Message/BotLocation"
    case .switchInline:
        return "Chat/Message/BotShare"
    case .payment:
        return "Chat/Message/BotPayment"
    case .openUserProfile:
        return "Chat/Message/BotProfile"
    case .openWebView, .openWebApp:
        return "Chat/Message/BotWebApp"
    case .copyText:
        return "Chat/Message/BotCopy"
    default:
        return nil
    }
}

/// The badge's own size. The assets are 10x10; the keyboard path draws them into a 12x12 node with
/// `contentMode = .center`, which comes to the same ink.
let instantPageBlockButtonIconSize = CGSize(width: 10.0, height: 10.0)

/// Distance from the pill's top-right corner. Larger than the keyboard button's 4pt because a pill is
/// fully rounded (`cornerRadius = height / 2`) rather than a rounded rect: at these insets the whole
/// badge box stays inside the arc on a 40pt-tall pill, where the keyboard button's own 4/4 would put
/// the badge's outer corner past it and `clipsToBounds` would shave it.
let instantPageBlockButtonIconInset = CGPoint(x: 8.0, y: 6.0)

/// Horizontal room a badge-bearing pill must keep clear on *each* side, so a centred label cannot run
/// under the badge. Mirrors the keyboard path's `minimumSideInset` (`4.0 + iconWidth`).
let instantPageBlockButtonIconReserve: CGFloat = instantPageBlockButtonIconSize.width + instantPageBlockButtonIconInset.x

/// Tinted badge for `action`, or nil when the action has none.
///
/// Rasterises on every call rather than caching: the keyboard path pre-generates these per theme in
/// `PresentationThemeEssentialGraphics`, which InstantPageUI has no equivalent of, and a 10x10 tint is
/// far cheaper than the global mutable cache it would take to avoid.
func instantPageBlockButtonIcon(for action: ReplyMarkupButtonAction, color: UIColor) -> UIImage? {
    guard let name = instantPageBlockButtonIconName(for: action) else {
        return nil
    }
    return generateTintedImage(image: UIImage(bundleImageName: name), color: color)
}
