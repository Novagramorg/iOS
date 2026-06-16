import Foundation
import TelegramCore
import RichTextEditorCore

/// Map a single text run to inline `RichText`, applying its character attributes as nested wrappers.
func richText(from run: TextRun) -> RichText? {
    let attributes = run.attributes
    if let emoji = attributes.emoji {
        // v1: custom emoji has no backing file here — emit its alt text as plain text.
        let alt = emoji.altText ?? ""
        return alt.isEmpty ? nil : .plain(alt)
    }
    if run.text.isEmpty {
        return nil
    }
    var result: RichText = .plain(run.text)
    if attributes.inlineCode {
        result = .fixed(result)
    }
    if attributes.strikethrough {
        result = .strikethrough(result)
    }
    if attributes.underline {
        result = .underline(result)
    }
    if attributes.italic {
        result = .italic(result)
    }
    if attributes.bold {
        result = .bold(result)
    }
    if attributes.highlight != nil {
        result = .marked(result)
    }
    if let link = attributes.link {
        result = .url(text: result, url: link, webpageId: nil)
    }
    return result
}

/// Map a run array to one `RichText` (`.concat` when multiple, `.empty` when none).
func richText(from runs: [TextRun]) -> RichText {
    let parts = runs.compactMap(richText(from:))
    if parts.isEmpty {
        return .empty
    }
    if parts.count == 1 {
        return parts[0]
    }
    return .concat(parts)
}
