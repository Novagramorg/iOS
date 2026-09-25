import Foundation

/// Localized strings for the edited-message history page. Self-contained
/// en/uz/ru so the module never has to touch the central FenixuzL10n.
enum EditedHistoryStrings {

    /// Fallback name for a document without a file name.
    static var file: String {
        localized(en: "File", uz: "Fayl", ru: "Файл", zh: "文件")
    }

    /// Generic label for media types the page does not preview (contact, location, ...).
    static var media: String {
        localized(en: "Media", uz: "Media", ru: "Медиа", zh: "媒体")
    }

    private static func localized(en: String, uz: String, ru: String, zh: String) -> String {
        let lang = Locale.current.languageCode ?? "en"
        switch lang {
        case "uz": return uz
        case "ru": return ru
        case "zh": return zh
        default:   return en
        }
    }
}
