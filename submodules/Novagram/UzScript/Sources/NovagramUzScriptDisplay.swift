import Foundation
import TelegramCore
import NovagramUzScriptCore

/// "Show chats in the new alphabet": a message in Cyrillic or the old Latin is drawn in the new alphabet.
/// Only the text on screen changes; the stored message, copy and reply quotes keep the original.
/// Called from ChatMessageTextBubbleContentNode before its entity cache, so the cache keys on the converted text.
public enum NovagramUzScriptDisplay {
    private final class Entry {
        let sourceText: String
        let sourceEntities: [MessageTextEntity]?
        let text: String
        let entities: [MessageTextEntity]?

        init(sourceText: String, sourceEntities: [MessageTextEntity]?, text: String, entities: [MessageTextEntity]?) {
            self.sourceText = sourceText
            self.sourceEntities = sourceEntities
            self.text = text
            self.entities = entities
        }
    }

    private static let cacheLimit = 2000
    // Layouts run off the main thread; NSCache is thread-safe.
    private static let cache: NSCache<NSString, Entry> = {
        let cache = NSCache<NSString, Entry>()
        cache.countLimit = cacheLimit
        return cache
    }()

    /// `originalText` is the message's own text: when the bubble shows something else (a Telegram translation or
    /// summary, an edit in progress, an invoice or story text) nothing is converted.
    public static func apply(text: String, entities: [MessageTextEntity]?, messageId: EngineMessage.Id, originalText: String) -> (String, [MessageTextEntity]?) {
        guard NovagramUzScriptEntityText.settings.showChatsInNewAlphabet, !text.isEmpty, text == originalText else {
            return (text, entities)
        }
        let key = "\(messageId.peerId.toInt64()):\(messageId.namespace):\(messageId.id)" as NSString
        if let entry = self.cache.object(forKey: key), entry.sourceText == text, entry.sourceEntities == entities {
            return (entry.text, entry.entities)
        }
        var result: (String, [MessageTextEntity]?) = (text, entities)
        if let converted = NovagramUzScriptEntityText.convert(text: text, entities: entities ?? []) {
            result = (converted.text, entities == nil ? nil : converted.entities)
        }
        self.cache.setObject(Entry(sourceText: text, sourceEntities: entities, text: result.0, entities: result.1), forKey: key)
        return result
    }
}
