import Foundation

/// The chat-list header folds its extra buttons (post story, ghost mode, proxy) behind one chevron,
/// so four icons no longer squeeze the "Chats" title (support request, 2026-09-23). Folded by
/// default; whichever state the user leaves it in is remembered.
public enum FenixHeaderFold {
    private static let expandedKey = "fenix_header_buttons_expanded"

    public static var isExpanded: Bool {
        get {
            return UserDefaults(suiteName: "pro_messager")?.bool(forKey: expandedKey) ?? false
        }
        set {
            UserDefaults(suiteName: "pro_messager")?.set(newValue, forKey: expandedKey)
        }
    }

    /// The hidden buttons slide out to the left of the chevron, so it points left while folded
    /// and right (back in) while unfolded.
    public static func iconName(isExpanded: Bool) -> String {
        return isExpanded ? "chevron.right" : "chevron.left"
    }
}
