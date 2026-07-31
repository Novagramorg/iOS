import Foundation

/// Client-side unlocks for Premium features that upstream gates on `Peer.isPremium` even though
/// the server does not enforce them. Sibling of `FenixuzStoryUnlock`, same methodology: only
/// unlock what is provably client-side, never something the server rejects.
///
/// Zero dependencies on purpose — a graph leaf, so SettingsUI and TelegramUI can both read it
/// without pulling in the settings-screen dependency graph.
public enum FenixuzPremiumUnlock {
    private static let defaultsSuite = "pro_messager"
    private static let translateChatsKey = "fenix_translate_chats_unlock"

    /// "Translate Entire Chats" — the whole-chat translation bar.
    ///
    /// Safe to unlock because the gate is client-side in three places and nothing more:
    ///   - `LocalizationListControllerNode` builds the row with `locked: !isPremium`
    ///   - `ChatControllerContentData` builds the translation state only when
    ///     `isPremium || maybeSuggestPremium || hasAutoTranslate`
    ///   - `ChatHistoryListNode` applies the translation only when `isPremium || autoTranslate`
    ///
    /// The MTProto call behind it, `messages.translateText`, has no Premium error path —
    /// `TranslationError` is only `generic` / `invalidLanguage` / `INPUT_TEXT_EMPTY`. Compare
    /// `messages.composeMessageWithAI`, which DOES surface `AICOMPOSE_FLOOD_PREMIUM`: when
    /// Telegram gates a method server-side it says so. The decisive evidence is channel
    /// auto-translate — `hasAutoTranslate` already routes **non-Premium** accounts through this
    /// exact code path and this exact RPC, and that feature ships and works.
    ///
    /// Default **false**. `bool(forKey:)` returning false for a missing key IS that default.
    public static var isTranslateChatsUnlocked: Bool {
        get {
            return UserDefaults(suiteName: defaultsSuite)?.bool(forKey: translateChatsKey) ?? false
        }
        set {
            UserDefaults(suiteName: defaultsSuite)?.set(newValue, forKey: translateChatsKey)
        }
    }
}
