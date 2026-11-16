import Foundation
import UIKit
import Display
import TelegramCore
import TelegramPresentationData
import ContextUI
import OverlayStatusController
import PresentationDataUtils
import NovagramLocalization
import NovagramUzScriptCore

/// "Yangi alifbo", per chat: one item in a user's profile "…" menu that makes the messages sent to this chat go out
/// in Cyrillic ("Lotin → Кирилл") or back to Latin ("Кирилл → Lotin"). Shown only while the "Lotin ↔ Кирилл"
/// switch on the Yangi alifbo page is on. The send step (NovagramUzScriptOutgoing) reads the chat's choice.
public enum NovagramUzScriptChatMenu {
    /// nil when the switch is off or the peer is not a person (groups, channels and bots are left out in v1).
    public static func item(peer: EnginePeer, presentationData: PresentationData, present: @escaping (ViewController) -> Void) -> ContextMenuItem? {
        let settings = UzScriptSettings()
        guard settings.cyrillicLatinEnabled, case let .user(user) = peer, user.botInfo == nil else {
            return nil
        }
        let peerKey = peer.id.toInt64()
        let isCyrillic = settings.chatSendScript(peerKey: peerKey) == .cyrillic
        let texts = UzScriptStrings(languageCode: NovagramL10n.languageKey(for: presentationData.strings))
        let title = isCyrillic ? UzScriptStrings.menuCyrillicToLatin : UzScriptStrings.menuLatinToCyrillic
        return .action(ContextMenuActionItem(text: title, icon: { theme in
            return generateTintedImage(image: UIImage(systemName: "character.textbox"), color: theme.contextMenu.primaryColor)
        }, action: { c, _ in
            c?.dismiss(completion: nil)
            let newScript: UzScript? = isCyrillic ? nil : .cyrillic
            settings.setChatSendScript(newScript, peerKey: peerKey)
            present(OverlayStatusController(theme: presentationData.theme, type: .genericSuccess(newScript == .cyrillic ? texts.sendingInCyrillicNotice : texts.sendingInLatinNotice, false)))
        }))
    }
}
