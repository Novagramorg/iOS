import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ContextUI
import AppBundle
import OverlayStatusController
import PresentationDataUtils
import NovagramLocalization
import NovagramUzScriptCore

/// "Yangi alifbo", per chat: one "Script" item in a user's profile "…" menu. It opens a sub-list with Default,
/// Cyrillic, Old Latin and New Latin, the chat's current choice checked. The send step (NovagramUzScriptOutgoing)
/// reads that choice. Shown only while the "Lotin ↔ Кирилл" switch on the Yangi alifbo page is on.
public enum NovagramUzScriptChatMenu {
    // nil is "Default": no choice for this chat, the global switch decides.
    private static let choices: [UzScript?] = [nil, .cyrillic, .latin1995, .latin2027]

    /// nil when the switch is off, for Saved Messages and for anyone who is not a person (bots, groups and channels
    /// are left out in v1).
    public static func item(peer: EnginePeer, accountPeerId: EnginePeer.Id, presentationData: PresentationData, present: @escaping (ViewController) -> Void) -> ContextMenuItem? {
        let settings = UzScriptSettings()
        guard settings.cyrillicLatinEnabled, peer.id != accountPeerId, case let .user(user) = peer, user.botInfo == nil else {
            return nil
        }
        let peerKey = peer.id.toInt64()
        let texts = UzScriptStrings(languageCode: NovagramL10n.languageKey(for: presentationData.strings))
        let current = settings.chatSendScript(peerKey: peerKey)
        return .action(ContextMenuActionItem(text: texts.chatScriptMenuTitle, textLayout: .secondLineWithValue(self.title(current, texts: texts)), icon: { theme in
            return generateTintedImage(image: UIImage(systemName: "character.textbox"), color: theme.contextMenu.primaryColor)
        }, action: { c, _ in
            c?.pushItems(items: .single(ContextController.Items(content: .list(self.subItems(current: current, peerKey: peerKey, settings: settings, texts: texts, presentationData: presentationData, present: present)))))
        }))
    }

    private static func subItems(current: UzScript?, peerKey: Int64, settings: UzScriptSettings, texts: UzScriptStrings, presentationData: PresentationData, present: @escaping (ViewController) -> Void) -> [ContextMenuItem] {
        var items: [ContextMenuItem] = []
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Common_Back, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.contextMenu.primaryColor)
        }, iconPosition: .left, action: { c, _ in
            c?.popItems()
        })))
        items.append(.separator)
        for choice in self.choices {
            let isCurrent = choice == current
            items.append(.action(ContextMenuActionItem(text: self.title(choice, texts: texts), icon: { theme in
                return isCurrent ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : UIImage()
            }, action: { _, f in
                f(.default)
                settings.setChatSendScript(choice, peerKey: peerKey)
                // Default needs no notice: the global switch decides again.
                if let notice = self.notice(choice, texts: texts) {
                    present(OverlayStatusController(theme: presentationData.theme, type: .genericSuccess(notice, false)))
                }
            })))
        }
        return items
    }

    private static func title(_ script: UzScript?, texts: UzScriptStrings) -> String {
        guard let script else {
            return texts.chatScriptDefault
        }
        return texts.scriptName(script)
    }

    private static func notice(_ script: UzScript?, texts: UzScriptStrings) -> String? {
        switch script {
        case .cyrillic:
            return texts.sendingInCyrillicNotice
        case .latin1995:
            return texts.sendingInLatinNotice
        case .latin2027:
            return texts.sendingInNewLatinNotice
        case .unknown, .none:
            return nil
        }
    }
}
