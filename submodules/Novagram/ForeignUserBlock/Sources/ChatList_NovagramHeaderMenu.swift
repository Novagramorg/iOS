import Foundation
import UIKit
import TelegramPresentationData
import NavigationBarComponent
import NovagramLocalization

/// The chat-list header's story / ghost / proxy buttons behind one menu button once there are two or more of
/// them, so the header always keeps two circles (menu + compose) and the title has room on every phone size.
public enum NovagramHeaderMenu {
    public static let buttonId = "novagramHeaderMenu"

    /// The menu button's icon: the purple ghost while Ghost mode is on (so its state stays visible), else "…".
    public static func icon(buttons: [NavigationBarComponent.Button]) -> UIImage {
        if buttons.contains(where: { $0.id == AnyHashable(ghostActiveId) }) {
            return NovagramHeaderIcons.ghostMode(isActive: true)
        }
        return moreImage
    }

    /// One menu row per header button, in the order given, each running that button's own action.
    public static func items(buttons: [NavigationBarComponent.Button], strings: PresentationStrings) -> [NavigationBarComponent.OverflowItem] {
        let l10n = NovagramL10n(strings)
        return buttons.compactMap { button -> NavigationBarComponent.OverflowItem? in
            let title: String
            let iconName: String
            switch button.id {
            case AnyHashable("story"):
                title = strings.StoryFeed_AddStory
                iconName = "Chat List/AddStoryIcon"
            case AnyHashable(ghostActiveId):
                title = l10n.header_menu_ghost_turn_off
                iconName = "Contact List/NovagramGhostIcon"
            case AnyHashable(ghostInactiveId):
                title = l10n.header_menu_ghost_turn_on
                iconName = "Contact List/NovagramGhostIcon"
            case AnyHashable("proxy"):
                title = strings.SocksProxySetup_Title
                iconName = "Chat List/ProxyShieldIcon"
            default:
                return nil
            }
            return NavigationBarComponent.OverflowItem(id: button.id, title: title, iconName: iconName, action: button.action)
        }
    }

    // Must match the ids `ChatListController.updateGhostModeButton()` gives the ghost button.
    private static let ghostActiveId = "ghostMode-on"
    private static let ghostInactiveId = "ghostMode-off"

    private static let moreImage: UIImage = {
        let configuration = UIImage.SymbolConfiguration(pointSize: 20.0, weight: .medium)
        return (UIImage(systemName: "ellipsis", withConfiguration: configuration) ?? UIImage()).withRenderingMode(.alwaysTemplate)
    }()
}
