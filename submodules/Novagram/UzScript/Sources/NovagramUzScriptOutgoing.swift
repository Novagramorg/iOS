import Foundation
import TelegramCore
import NovagramUzScriptCore

/// "Send in the new alphabet": an outgoing Uzbek text piece written in Cyrillic or the old Latin goes out in the new
/// one. A chat's own choice from the profile menu ("Lotin → Кирилл") wins over that switch. Russian and English
/// text is never touched. Called first in `NovagramOutgoingText.apply`, so Auto Text added after it stays as written.
public enum NovagramUzScriptOutgoing {
    // The composer keeps a custom emoji as this attribute on its placeholder character (TextFormat's
    // ChatTextInputAttributes.customEmoji); spelled out here so this module does not depend on TextFormat.
    private static let customEmojiKey = NSAttributedString.Key(rawValue: "Attribute__CustomEmoji")

    public static func apply(text: NSAttributedString, entities: [MessageTextEntity], peerId: EnginePeer.Id?) -> (text: NSAttributedString, entities: [MessageTextEntity]) {
        guard text.length > 0, let target = self.target(peerId: peerId) else {
            return (text, entities)
        }
        guard let converted = NovagramUzScriptEntityText.convert(text: text.string, entities: entities, target: target) else {
            return (text, entities)
        }
        guard let updatedText = self.rebuild(text, converted: converted) else {
            return (text, entities)
        }
        return (updatedText, converted.entities)
    }

    /// The chat's own script if it has one, else the new Latin while the switch is on, else nil (send as typed).
    private static func target(peerId: EnginePeer.Id?) -> UzScript? {
        let settings = NovagramUzScriptEntityText.settings
        if let peerId {
            return settings.effectiveSendScript(peerKey: peerId.toInt64())
        }
        return settings.sendInNewAlphabet ? .latin2027 : nil
    }

    /// The converted string with the source attributes on the mapped ranges, or nil when a range cannot be
    /// mapped safely (then the piece is sent unconverted).
    private static func rebuild(_ text: NSAttributedString, converted: NovagramUzScriptEntityText.Converted) -> NSAttributedString? {
        let sourceText = text.string as NSString
        let updatedText = NSMutableAttributedString(string: converted.text)
        let updatedLength = updatedText.length
        var isSafe = true
        text.enumerateAttributes(in: NSRange(location: 0, length: text.length), options: []) { attributes, range, stop in
            if attributes.isEmpty {
                return
            }
            guard let mapped = NovagramUzScriptEntityText.mapped(range, result: converted.result, length: updatedLength) else {
                isSafe = false
                stop.pointee = true
                return
            }
            // A custom emoji or an attachment must keep its exact character.
            if attributes[self.customEmojiKey] != nil || attributes[.attachment] != nil {
                if (updatedText.string as NSString).substring(with: mapped) != sourceText.substring(with: range) {
                    isSafe = false
                    stop.pointee = true
                    return
                }
            }
            updatedText.addAttributes(attributes, range: mapped)
        }
        return isSafe ? updatedText : nil
    }
}
