import Foundation
import TelegramCore
import NovagramUzScriptCore

/// Converts a text and its entities to the new Uzbek Latin alphabet (2027).
///
/// Entity ranges are UTF-16 offsets, the same unit as `NSRange`, so they go through `UzScriptResult.mapRange`.
/// Links, mentions, hashtags, code, custom emoji and the like are protected: their text must come out unchanged,
/// otherwise the whole text is left alone. A wrong conversion must never reach a sent message.
enum NovagramUzScriptEntityText {
    /// One instance: `UzScriptSettings()` opens the `pro_messager` suite, and layouts call this for every bubble.
    static let settings = UzScriptSettings()

    struct Converted {
        let text: String
        let entities: [MessageTextEntity]
        let result: UzScriptResult
    }

    /// True for entities whose text is not prose: a link, a name, code or an emoji keeps its exact characters.
    static func isProtected(_ type: MessageTextEntityType) -> Bool {
        switch type {
        case .Bold, .Italic, .Strikethrough, .Underline, .Spoiler, .BlockQuote, .Unknown:
            return false
        default:
            // Url, TextUrl, Mention, TextMention, Hashtag, BotCommand, Email, PhoneNumber, Code, Pre, BankCard,
            // TonAddress, CustomEmoji, FormattedDate, Custom (cashtags) and any future type.
            return true
        }
    }

    /// nil means "leave the text alone": not Uzbek, nothing to change, or a range could not be mapped safely.
    static func convert(text: String, entities: [MessageTextEntity], target: UzScript = .latin2027) -> Converted? {
        let sourceText = text as NSString
        let sourceLength = sourceText.length
        guard sourceLength > 0 else {
            return nil
        }
        var protectedRanges: [NSRange] = []
        for entity in entities {
            guard entity.range.lowerBound >= 0, entity.range.upperBound <= sourceLength else {
                return nil
            }
            if self.isProtected(entity.type) {
                protectedRanges.append(self.nsRange(entity.range))
            }
        }
        // nil for Russian, English or text already in `target`. The SDK caches results.
        guard let result = UzScriptConverter.toScriptIfUzbek(text, to: target, protectedRanges: protectedRanges), result.text != text else {
            return nil
        }
        let convertedText = result.text as NSString
        var convertedEntities: [MessageTextEntity] = []
        for entity in entities {
            let sourceRange = self.nsRange(entity.range)
            guard let mapped = self.mapped(sourceRange, result: result, length: convertedText.length) else {
                return nil
            }
            if self.isProtected(entity.type) && convertedText.substring(with: mapped) != sourceText.substring(with: sourceRange) {
                return nil
            }
            convertedEntities.append(MessageTextEntity(range: mapped.location ..< mapped.location + mapped.length, type: entity.type))
        }
        return Converted(text: result.text, entities: convertedEntities, result: result)
    }

    /// The range in the converted text, or nil when it falls outside it or a non-empty range collapsed.
    static func mapped(_ range: NSRange, result: UzScriptResult, length: Int) -> NSRange? {
        let mapped = result.mapRange(range)
        guard mapped.location != NSNotFound, mapped.location >= 0, mapped.length >= 0, mapped.location + mapped.length <= length else {
            return nil
        }
        if range.length > 0 && mapped.length == 0 {
            return nil
        }
        return mapped
    }

    private static func nsRange(_ range: Range<Int>) -> NSRange {
        return NSRange(location: range.lowerBound, length: range.upperBound - range.lowerBound)
    }
}
