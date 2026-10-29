import Foundation

/// Settings → Novagram → Search → "Search features" (on by default). While it is off, search works like
/// plain Telegram: no dates / Unread only / Mentions only in the "From All Chats" menu, no "exact phrase"
/// or re: inside a chat, no saved searches (nothing new is saved, the stored ones stay) and no translated
/// section. Hidden and locked chats stay out of search either way (owner's rule): the privacy filter
/// does not read this switch.
public enum NovagramSearchFeatures {
    public static let defaultsKey = "novagram_search_features"

    private static let suiteName = "pro_messager"

    public static var isEnabled: Bool {
        get {
            return UserDefaults(suiteName: suiteName)?.object(forKey: defaultsKey) as? Bool ?? true
        }
        set {
            UserDefaults(suiteName: suiteName)?.set(newValue, forKey: defaultsKey)
        }
    }
}
