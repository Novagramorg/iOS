import Foundation
import TelegramCore

// Feature #21: "Folder display style" (Icons / Text / Automatic).
// Reads the "fenix_folder_display_style" setting (suite "pro_messager") and,
// for the "icon" style, renders a folder's emoticon as the chat-list filter
// tab content instead of its text title. "text" and "auto" keep the text title
// (current upstream behavior). If a folder has no emoticon, the text title is
// used as a safe fallback even in "icon" mode.
public enum FenixFolderStyle {
    public static func resolveTabTitle(_ title: ChatFolderTitle, emoticon: String?) -> ChatFolderTitle {
        let style = UserDefaults(suiteName: "pro_messager")?.string(forKey: "fenix_folder_display_style") ?? "auto"
        guard style == "icon", let emoticon = emoticon, !emoticon.isEmpty else {
            return title
        }
        return ChatFolderTitle(text: emoticon, entities: [], enableAnimations: false)
    }
}
