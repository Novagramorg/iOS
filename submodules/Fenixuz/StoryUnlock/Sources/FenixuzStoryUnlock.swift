import Foundation

/// Client-side unlock for two story-viewer menu items that upstream gates on `Peer.isPremium`
/// even though neither has any server-side enforcement — there is no "save story" or
/// "set story quality" MTProto method anywhere in the API surface:
///   - **Save to Gallery** — writing an already-downloaded story to the photo library.
///   - **Increase Quality** — the local HD/SD story video download preference.
///
/// Deliberately NOT covered:
///   - The author's content protection (`isForwardingDisabled` / noforwards). Protected stories
///     stay unsavable; the menu item is not even built for them. That check is upstream's and is
///     a different thing from the Premium gate.
///   - Stealth Mode. It fires `stories.activateStealthMode`, which the server rejects for a free
///     account — and the client swallows that error and writes a fake "stealth active" timestamp
///     locally, so unlocking it would show a confident lie.
///   - The global `isPremium` flag. 504 call sites read it; forcing it true would make every
///     contact read as Premium and make genuinely server-enforced features fail visibly.
///
/// Zero dependencies on purpose: this is a graph leaf so the story components, ChatListUI and
/// TelegramUI can all read it without pulling in the settings-screen dependency graph.
public enum FenixuzStoryUnlock {
    private static let defaultsSuite = "pro_messager"
    private static let enabledKey = "fenix_story_unlock_enabled"

    /// Default **false**. `bool(forKey:)` returning false for a missing key IS that default —
    /// do not switch to `object(forKey:) as? Bool ?? true`, which is the opposite idiom used by
    /// rows that default to on.
    public static var isEnabled: Bool {
        get {
            return UserDefaults(suiteName: defaultsSuite)?.bool(forKey: enabledKey) ?? false
        }
        set {
            UserDefaults(suiteName: defaultsSuite)?.set(newValue, forKey: enabledKey)
        }
    }
}
