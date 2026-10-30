import Foundation

/// Settings → Novagram → Search → "Search features" (on by default). While it is off, search works like
/// plain Telegram: no dates / Unread only / Mentions only in the "From All Chats" menu, no "exact phrase"
/// or re: inside a chat, no saved searches (nothing new is saved, the stored ones stay) and no translated
/// section. Hidden and locked chats stay out of search either way (owner's rule): the privacy filter
/// does not read this switch.
///
/// The whole feature also sits behind the hidden Developer switch "Search features (beta)"
/// (`novagram_dev_search_features`, missing key = off). With it off the features behave as switched off and
/// the Settings rows are hidden; the user's own switch keeps its value.
public enum NovagramSearchFeatures {
    public static let defaultsKey = "novagram_search_features"
    /// The Developer switch. Same key as the Mac. Written only by the Developer section (NovagramDeveloperFlags).
    public static let developerFlagKey = "novagram_dev_search_features"

    private static let suiteName = "pro_messager"

    /// What every search feature reads: the Developer switch and the user's switch are both on.
    public static var isEnabled: Bool {
        return self.isDeveloperEnabled && self.isUserEnabled
    }

    /// The Developer switch "Search features (beta)". Missing key = off.
    public static var isDeveloperEnabled: Bool {
        return UserDefaults(suiteName: suiteName)?.object(forKey: developerFlagKey) as? Bool ?? false
    }

    /// The user's "Search features" switch as stored (missing key = on). Only the Settings row reads and writes it.
    public static var isUserEnabled: Bool {
        get {
            return UserDefaults(suiteName: suiteName)?.object(forKey: defaultsKey) as? Bool ?? true
        }
        set {
            UserDefaults(suiteName: suiteName)?.set(newValue, forKey: defaultsKey)
        }
    }
}
