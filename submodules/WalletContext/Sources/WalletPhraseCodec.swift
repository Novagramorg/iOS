import Foundation

enum WalletPhraseCodec {
    private static let textLength = 215
    // Only the padded text is split; WalletBackupCrypto prefixes each share.
    static func encode(words: [String]) -> Data? {
        let words = words
        .flatMap { value in
            value.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        }
        .map { $0.lowercased() }
        guard !words.isEmpty else {
            return nil
        }
        guard var text = words.joined(separator: " ").data(using: .utf8), text.count <= textLength else {
            return nil
        }
        text.append(Data(repeating: 0x20, count: textLength - text.count))
        return text
    }

    static func decode(_ data: Data) -> [String]? {
        guard data.count == textLength,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        let words = value.trimmingCharacters(in: .whitespacesAndNewlines)
        .split(whereSeparator: { $0.isWhitespace })
        .map { String($0).lowercased() }
        guard !words.isEmpty, encode(words: words) == data else {
            return nil
        }
        return words
    }
}
