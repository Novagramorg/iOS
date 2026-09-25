// Strings for the "Translate entire chats" toggle (Features section).
// Kept local to ProMessager rather than added to the shared Localization module, so an
// upstream merge of that module cannot silently drop them.
//
// Same rule as FenixStoryUnlockStrings: the words "Premium", "unlock", "free" and "bypass"
// deliberately appear in NO user-facing string here — the fork already took one Apple 3.1.1
// rejection and nothing in the UI should read as circumventing a paid tier. Describe what the
// feature does, never where it came from.

enum FenixTranslateUnlockStrings {
    static func toggleTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Butun chatni tarjima qilish"
        case "ru": return "Переводить чат целиком"
        case "zh": return "翻译整个聊天"
        default:   return "Translate entire chats"
        }
    }

    static func toggleSubtitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Chatni to'liq tarjima qilish, har bir xabarni alohida emas"
        case "ru": return "Переводить чат целиком, а не каждое сообщение отдельно"
        case "zh": return "一次性翻译整个聊天，而不是逐条翻译消息"
        default:   return "Translate a whole chat at once instead of message by message"
        }
    }
}
