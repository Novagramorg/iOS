import Foundation

/// Text matching for the search field at the top of Novagram settings. Strings-free, so the rule is easy to check.
///
/// A row matches when every word of the query is found in its texts (title, subtitle or its section's header).
/// Case, diacritics and the Uzbek apostrophes are ignored: "ozbek", "O'zbek" and "oʻzbek" all find each other.
enum NovagramSettingsSearch {
    // Uzbek Latin writes o' / g' with any of these; a user types whichever the keyboard gives.
    private static let apostrophes: Set<Character> = ["'", "`", "\u{2018}", "\u{2019}", "\u{02BB}", "\u{02BC}"]

    static func normalized(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
        return String(folded.filter { !self.apostrophes.contains($0) })
    }

    /// The query's words, normalized. Empty when the query is blank, which means "no search".
    static func words(_ query: String) -> [String] {
        return self.normalized(query).split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }

    static func matches(words: [String], texts: [String]) -> Bool {
        guard !words.isEmpty else {
            return false
        }
        let haystack = texts.map(self.normalized).joined(separator: "\n")
        return words.allSatisfy { haystack.contains($0) }
    }
}
