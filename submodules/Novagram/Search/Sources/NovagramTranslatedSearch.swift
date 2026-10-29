import Foundation
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramPresentationData
import NovagramLocalization

/// Translates a global-search query into the user's translation language (Settings → Novagram →
/// Search → "Search the translated query too"; off by default, and only while "Search features" is on).
public enum NovagramQueryTranslator {
    public static let defaultsKey = "novagram_search_translate"
    public static let minQueryLength = 3

    private static let suiteName = "pro_messager"
    private static let languageKey = "auto_translate_lang"
    private static let fallbackLanguage = "en"
    private static let debounceSeconds: Double = 0.6
    private static let maxCachedQueries = 200
    private static let cache = Atomic<[String: String]>(value: [:])

    public static var isEnabled: Bool {
        get {
            return UserDefaults(suiteName: suiteName)?.object(forKey: defaultsKey) as? Bool ?? false
        }
        set {
            UserDefaults(suiteName: suiteName)?.set(newValue, forKey: defaultsKey)
        }
    }

    /// `auto_translate_lang`, or "en" when it is missing or empty.
    public static var targetLanguage: String {
        guard let lang = UserDefaults(suiteName: suiteName)?.string(forKey: languageKey), !lang.isEmpty else {
            return fallbackLanguage
        }
        return lang
    }

    /// nil first, then the translation (nil when there is none or it equals the query). The request
    /// starts 600 ms late, so typing cancels it; a cached answer comes at once.
    public static func translatedQuery(engine: TelegramEngine, query: String) -> Signal<String?, NoError> {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard NovagramSearchFeatures.isEnabled, isEnabled, query.count >= minQueryLength else {
            return .single(nil)
        }
        let lang = targetLanguage
        let key = lang + "\n" + query
        if let cached = cache.with({ $0[key] }) {
            return .single(cached.isEmpty ? nil : cached)
        }
        let request: Signal<String?, NoError> = engine.messages.translate(text: query, toLang: lang)
        |> map { result -> String? in
            let text = result?.0.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            store(isSame(text, query) ? "" : text, for: key)
            return isSame(text, query) ? nil : text
        }
        |> `catch` { _ -> Signal<String?, NoError> in
            return .single(nil)
        }
        return .single(nil) |> then(request |> delay(debounceSeconds, queue: .concurrentDefaultQueue()))
    }

    private static func isSame(_ lhs: String, _ rhs: String) -> Bool {
        if lhs.isEmpty {
            return true
        }
        return normalized(lhs) == normalized(rhs)
    }

    private static func normalized(_ text: String) -> String {
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        return words.filter { !$0.isEmpty }.joined(separator: " ")
    }

    private static func store(_ value: String, for key: String) {
        _ = cache.modify { current in
            var current = current
            if current.count >= maxCachedQueries {
                current.removeAll()
            }
            current[key] = value
            return current
        }
    }
}

/// The "Translated: …" section: messages found by the translated query. Shown above Messages,
/// never paged, never part of the gallery / player list or "load more".
public struct NovagramTranslatedMessages {
    public let text: String
    public let messages: [EngineMessage]

    public func title(strings: PresentationStrings) -> String {
        return NovagramL10n(languageCode: NovagramL10n.languageKey(for: strings)).search_translatedTitle(self.text)
    }

    /// The section's rows for one emission: without messages already under Messages (`shownIds`)
    /// and without hidden or locked chats. The set is built fresh by the caller every emission.
    public func rows(excluding shownIds: Set<EngineMessage.Id>, privacy: NovagramSearchPrivacyPass) -> [EngineMessage] {
        var seen = Set<EngineMessage.Id>()
        return self.messages.filter { message in
            guard !shownIds.contains(message.id), !seen.contains(message.id), !privacy.hidesMessage(message) else {
                return false
            }
            seen.insert(message.id)
            return true
        }
    }
}

private let novagramTranslatedLimit: Int32 = 20

public enum NovagramTranslatedSearch {
    /// Header id of the section (ChatListSearchItemHeaderType.text).
    public static let headerId: AnyHashable = "novagram.search.translated"

    /// Emits nil at once (so the other sections never wait for it), then the section, if it applies:
    /// switch on, Chats tab, the common search (one `.general` location, no forum / peer / community /
    /// saved-messages scope), and a query that is not a `#hashtag` or a `$cashtag`.
    public static func section(
        filter: NovagramSearchFilter,
        engine: TelegramEngine,
        query: String?,
        isChatsTab: Bool,
        chatLocation: ChatListControllerLocation,
        locations: [SearchMessagesLocation]
    ) -> Signal<NovagramTranslatedMessages?, NoError> {
        guard let query, let location = self.commonLocation(isChatsTab: isChatsTab, chatLocation: chatLocation, locations: locations) else {
            return .single(nil)
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.hasPrefix("#"), !trimmed.hasPrefix("$"), NovagramSearchFeatures.isEnabled, NovagramQueryTranslator.isEnabled else {
            return .single(nil)
        }
        let translated: Signal<NovagramTranslatedMessages?, NoError> = NovagramQueryTranslator.translatedQuery(engine: engine, query: trimmed)
        |> mapToSignal { text -> Signal<NovagramTranslatedMessages?, NoError> in
            guard let text else {
                return .single(nil)
            }
            // The Messages section's own location and filters: dates, Unread / Mentions only. One page only.
            return filter.searchMessages(engine: engine, location: location, query: text, state: nil, limit: novagramTranslatedLimit, fills: false)
            |> map { result, _ -> NovagramTranslatedMessages? in
                let messages = result.messages.prefix(Int(novagramTranslatedLimit)).map(EngineMessage.init)
                return NovagramTranslatedMessages(text: text, messages: messages.sorted(by: { $0.index > $1.index }))
            }
        }
        return .single(nil) |> then(translated)
    }

    private static func commonLocation(isChatsTab: Bool, chatLocation: ChatListControllerLocation, locations: [SearchMessagesLocation]) -> SearchMessagesLocation? {
        guard isChatsTab, case .chatList = chatLocation, locations.count == 1, let location = locations.first else {
            return nil
        }
        guard case let .general(scope, _, tags, _, _, _, communityId) = location, tags == nil, communityId == nil else {
            return nil
        }
        if case .globalPosts = scope {
            return nil
        }
        return location
    }
}
