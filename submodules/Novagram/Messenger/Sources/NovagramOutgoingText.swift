import Foundation
import TelegramCore
import TextFormat

/// What Novagram Settings change in every outgoing text piece: Auto Text is appended and the default Text Style
/// covers the whole piece. Applied to each piece the composer split the input into (`chatComposerTextMessages`),
/// as it was before Telegram moved that split into TextFormat.
public enum NovagramOutgoingText {
    private static let udSuite = "pro_messager"

    public static func apply(text: NSAttributedString, entities: [MessageTextEntity], businessLinkSetup: Bool) -> (text: NSAttributedString, entities: [MessageTextEntity]) {
        var text = text
        var entities = entities
        let defaults = UserDefaults(suiteName: self.udSuite)

        let autoContent = (defaults?.string(forKey: "auto_text_content") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if defaults?.bool(forKey: "auto_text_enabled") ?? false, !autoContent.isEmpty {
            let updatedText = NSMutableAttributedString(attributedString: text)
            let lastAttributes = text.length > 0 ? text.attributes(at: text.length - 1, effectiveRange: nil) : [:]
            updatedText.append(NSAttributedString(string: " " + autoContent, attributes: lastAttributes))
            text = updatedText
            // The rule chatComposerTextMessages uses, so links and mentions in the added text become entities too.
            if businessLinkSetup {
                entities = generateChatInputTextEntities(text, generateLinks: false)
            } else {
                entities = generateTextEntities(text.string, enabledTypes: .all, currentEntities: generateChatInputTextEntities(text, maxAnimatedEmojisInText: 0))
            }
        }

        let textLength = (text.string as NSString).length
        if textLength > 0, let type = self.defaultStyleEntityType(defaults?.string(forKey: "text_style")) {
            entities.append(MessageTextEntity(range: 0 ..< textLength, type: type))
        }
        return (text, entities)
    }

    private static func defaultStyleEntityType(_ style: String?) -> MessageTextEntityType? {
        switch style {
        case "bold":          return .Bold
        case "italic":        return .Italic
        case "monospace":     return .Code
        case "strikethrough": return .Strikethrough
        case "underline":     return .Underline
        case "spoiler":       return .Spoiler
        default:              return nil
        }
    }
}
