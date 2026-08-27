import Foundation

// Fenixuz — brand rewrite for server-delivered localization.
//
// The rebranded strings in `Telegram/Telegram-iOS/en.lproj/Localizable.strings` (286 of them)
// never reach a logged-in user: `PresentationStrings` is built from `LocalizationSettings`, whose
// entries come from Telegram's own language pack (`langpack.getLangPack`). The bundled file is
// only the pre-login fallback. So the app kept saying "Telegram" everywhere, in every language —
// `ru`/`uz` do not even ship a `Localizable.strings`, they are 100% server-sourced.
//
// Rewriting at `dictFromLocalization` fixes every language at once, whatever the server sends.
//
// What is deliberately NOT rewritten:
//   * Telegram's own products and entities — see `protectedPhrases`. We do not sell Premium,
//     Stars, Business or Gifts (the Apple 3.1.1 gate blocks them and points at the official app),
//     so "Novagram Premium" would be advertising something that does not exist. Passport is a
//     Telegram service; Desktop/Web/App name the official clients; Terms and Team are legal and
//     organisational references.
//   * Lowercase `telegram` — it only ever appears inside URLs (`telegram.org`, 41 occurrences).
//     Matching case-sensitively keeps every link intact without needing a URL parser.
public enum FenixuzBrandStrings {
    public static let brandName = "Novagram"

    /// Longest-first: `Telegram Stars` has to be claimed before `Telegram Star` can split it.
    private static let protectedPhrases: [String] = [
        "Telegram Passport",
        "Telegram Business",
        "Telegram Desktop",
        "Telegram Premium",
        "Telegram Terms",
        "Telegram Stars",
        "Telegram Star",
        "Telegram Team",
        "Telegram Web",
        "Telegram App"
    ]

    /// U+0000 cannot occur in a language-pack string, so it is safe as a placeholder marker.
    private static let marker = "\u{0}"

    public static func applyBrand(to value: String) -> String {
        // Almost every string is untouched; skip the work rather than rebuilding 13k strings.
        guard value.contains("Telegram") || value.contains("TELEGRAM") else {
            return value
        }

        var result = value
        for (index, phrase) in protectedPhrases.enumerated() {
            guard result.contains(phrase) else { continue }
            result = result.replacingOccurrences(of: phrase, with: "\(marker)\(index)\(marker)")
        }

        result = result.replacingOccurrences(of: "TELEGRAM", with: brandName.uppercased())
        result = result.replacingOccurrences(of: "Telegram", with: brandName)

        for (index, phrase) in protectedPhrases.enumerated() {
            let placeholder = "\(marker)\(index)\(marker)"
            guard result.contains(placeholder) else { continue }
            result = result.replacingOccurrences(of: placeholder, with: phrase)
        }
        return result
    }
}
