import Foundation

/// The languages Apple's `SFSpeechRecognizer` cannot handle but Vosk can, so they are
/// routed to the offline Vosk backend instead. Today: Uzbek only.
///
/// Extensible: add "kk"/"tg" with their model names to support Kazakh/Tajik later — no
/// other code changes are needed, just a download of the corresponding model.
public enum VoskLanguage {
    /// language-prefix → Vosk model name (also the on-disk cache dir + download file stem).
    public static let table: [String: String] = [
        "uz": "vosk-model-small-uz-0.22"
    ]

    /// True when the given locale id (e.g. "uz-UZ") should use Vosk rather than Apple.
    public static func isVoskOnly(_ localeId: String) -> Bool {
        return table.keys.contains(languagePrefix(localeId))
    }

    /// The Vosk model name for a locale id, or nil if Vosk doesn't cover it.
    public static func modelName(for localeId: String) -> String? {
        return table[languagePrefix(localeId)]
    }

    private static func languagePrefix(_ localeId: String) -> String {
        return String(localeId.prefix(2)).lowercased()
    }
}
