import Foundation

/// The language "Ask to translate on send" (#37) translates into.
///
/// It used to read only the Auto-translate language (`auto_translate_lang`), which stays empty unless the
/// Auto-translate screen was set up. The switch then did nothing while "Translation language", the row right
/// above it, showed English. Now the Auto-translate language wins, else the Translation language, else English.
public enum NovagramSendTranslate {
    public static func confirmTargetLanguage() -> String {
        let autoTranslateLanguage = UserDefaults(suiteName: "pro_messager")?.string(forKey: "auto_translate_lang") ?? ""
        if !autoTranslateLanguage.isEmpty {
            return autoTranslateLanguage
        }
        let translationLanguage = UserDefaults(suiteName: "pro_messager_translation")?.string(forKey: "selected_language") ?? ""
        return translationLanguage.isEmpty ? "en" : translationLanguage
    }

    /// "English", "Русский", … in the app's language, for the settings row.
    static func languageName(code: String, appLangCode: String) -> String {
        let name = Locale(identifier: appLangCode).localizedString(forLanguageCode: code) ?? code.uppercased()
        return name.prefix(1).uppercased() + name.dropFirst()
    }
}
