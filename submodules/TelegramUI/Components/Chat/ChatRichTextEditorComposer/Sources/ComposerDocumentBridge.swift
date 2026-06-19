import Foundation
import UIKit
import RichTextEditorCore
import TextFormat

/// Pure bidirectional bridge between the chat composer's `ChatTextInputAttributes`-keyed
/// `NSAttributedString` and the RichTextEditor `Document` model. Phase 1: body/quote paragraphs +
/// inline styles + spoiler + link; custom emoji → altText (real round-trip deferred to Phase 2).
enum ComposerDocumentBridge {
    /// composer attributed string → Document (host-push: initial load / draft restore / edit).
    static func document(from attributedText: NSAttributedString) -> Document {
        let fullString = attributedText.string as NSString
        var blocks: [Block] = []

        // Split into paragraphs on "\n", preserving per-paragraph attribute ranges.
        var paragraphRanges: [NSRange] = []
        var lineStart = 0
        let total = fullString.length
        var i = 0
        while i < total {
            if fullString.character(at: i) == 0x0A { // "\n"
                paragraphRanges.append(NSRange(location: lineStart, length: i - lineStart))
                lineStart = i + 1
            }
            i += 1
        }
        paragraphRanges.append(NSRange(location: lineStart, length: total - lineStart))

        for pRange in paragraphRanges {
            var runs: [TextRun] = []
            var isQuote = false
            if pRange.length > 0 {
                attributedText.enumerateAttributes(in: pRange, options: []) { dict, range, _ in
                    // Phase 1: drop custom-emoji placeholders. The composer represents a custom emoji as a
                    // U+FFFC object-replacement char carrying `.customEmoji`; mapping it to a real EmojiRef
                    // needs the Telegram file id/altText (TelegramCore types this module deliberately avoids),
                    // so the real round-trip is deferred to Phase 2. Skipping the run avoids leaving a stray
                    // U+FFFC glyph in the document on draft/edit load.
                    if dict[ChatTextInputAttributes.customEmoji] != nil {
                        return
                    }
                    let runText = fullString.substring(with: range)
                    var ca = CharacterAttributes.plain
                    if dict[ChatTextInputAttributes.bold] != nil { ca.bold = true }
                    if dict[ChatTextInputAttributes.italic] != nil { ca.italic = true }
                    if dict[ChatTextInputAttributes.monospace] != nil { ca.inlineCode = true }
                    if dict[ChatTextInputAttributes.strikethrough] != nil { ca.strikethrough = true }
                    if dict[ChatTextInputAttributes.underline] != nil { ca.underline = true }
                    if dict[ChatTextInputAttributes.spoiler] != nil { ca.spoiler = true }
                    if let url = dict[ChatTextInputAttributes.textUrl] as? ChatTextInputTextUrlAttribute { ca.link = url.url }
                    // Only a `.quote`-kind block maps to a quote paragraph. The `.block` attribute also
                    // carries `.code` blocks, which the editor's paragraph styles can't represent — those
                    // degrade to `.body` rather than being mislabeled as a quote. (The forward path only
                    // ever emits `.quote`, mirroring EntityMessageBuilder.)
                    if let quote = dict[ChatTextInputAttributes.block] as? ChatTextInputTextQuoteAttribute, case .quote = quote.kind {
                        isQuote = true
                    }
                    runs.append(TextRun(text: runText, attributes: ca))
                }
            }
            blocks.append(.paragraph(ParagraphBlock(
                id: BlockID.generate(),
                style: isQuote ? .quote : .body,
                runs: runs
            )))
        }

        if blocks.isEmpty {
            blocks = [.paragraph(ParagraphBlock(id: BlockID.generate()))]
        }
        return Document(blocks: blocks)
    }

    /// Document → composer attributed string (attributedText getter).
    static func attributedString(from document: Document, baseFontSize: CGFloat) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let marker = true as NSNumber
        let baseFont = UIFont.systemFont(ofSize: baseFontSize)
        var isFirstParagraph = true

        for block in document.blocks {
            guard case let .paragraph(paragraph) = block else { continue }
            if !isFirstParagraph {
                result.append(NSAttributedString(string: "\n", attributes: [.font: baseFont]))
            }
            isFirstParagraph = false

            let paragraphStart = result.length
            for run in paragraph.runs {
                let text: String
                if let emoji = run.attributes.emoji {
                    text = emoji.altText ?? ""   // Phase 1: custom emoji → altText (real round-trip deferred)
                } else {
                    text = run.text
                }
                if text.isEmpty { continue }
                let piece = NSMutableAttributedString(string: text, attributes: [.font: baseFont])
                let range = NSRange(location: 0, length: piece.length)
                let a = run.attributes
                if a.bold { piece.addAttribute(ChatTextInputAttributes.bold, value: marker, range: range) }
                if a.italic { piece.addAttribute(ChatTextInputAttributes.italic, value: marker, range: range) }
                if a.inlineCode { piece.addAttribute(ChatTextInputAttributes.monospace, value: marker, range: range) }
                if a.strikethrough { piece.addAttribute(ChatTextInputAttributes.strikethrough, value: marker, range: range) }
                if a.underline { piece.addAttribute(ChatTextInputAttributes.underline, value: marker, range: range) }
                if a.spoiler { piece.addAttribute(ChatTextInputAttributes.spoiler, value: marker, range: range) }
                if let link = a.link {
                    piece.addAttribute(ChatTextInputAttributes.textUrl, value: ChatTextInputTextUrlAttribute(url: link), range: range)
                }
                result.append(piece)
            }

            if paragraph.style == .quote {
                let length = result.length - paragraphStart
                if length > 0 {
                    result.addAttribute(
                        ChatTextInputAttributes.block,
                        value: ChatTextInputTextQuoteAttribute(kind: .quote, isCollapsed: false),
                        range: NSRange(location: paragraphStart, length: length)
                    )
                }
            }
        }
        return result
    }

    /// True if the two strings carry the same text and the same composer-meaningful attribute ranges
    /// (bold/italic/monospace/strikethrough/underline/spoiler/textUrl/block), ignoring font/color. Used by
    /// the node's `attributedText` setter to skip a redundant document rebuild (caret-thrash guard).
    static func composerContentEqual(_ lhs: NSAttributedString, _ rhs: NSAttributedString) -> Bool {
        if lhs.string != rhs.string { return false }
        let keys: [NSAttributedString.Key] = [
            ChatTextInputAttributes.bold, ChatTextInputAttributes.italic, ChatTextInputAttributes.monospace,
            ChatTextInputAttributes.strikethrough, ChatTextInputAttributes.underline, ChatTextInputAttributes.spoiler,
            ChatTextInputAttributes.textUrl, ChatTextInputAttributes.block
        ]
        let full = NSRange(location: 0, length: (lhs.string as NSString).length)
        for key in keys {
            var lRanges: [NSRange] = []
            var rRanges: [NSRange] = []
            lhs.enumerateAttribute(key, in: full, options: []) { value, range, _ in if value != nil { lRanges.append(range) } }
            rhs.enumerateAttribute(key, in: full, options: []) { value, range, _ in if value != nil { rRanges.append(range) } }
            if lRanges != rRanges { return false }
        }
        // `.textUrl` is the one key whose *value* carries semantic content that must round-trip (the URL
        // string). A same-range link with a changed URL passes the presence-range check above, so compare
        // the URL values too — otherwise an in-place URL edit would be silently dropped by the setter guard.
        var lUrls: [(NSRange, String)] = []
        var rUrls: [(NSRange, String)] = []
        lhs.enumerateAttribute(ChatTextInputAttributes.textUrl, in: full, options: []) { value, range, _ in
            if let url = value as? ChatTextInputTextUrlAttribute { lUrls.append((range, url.url)) }
        }
        rhs.enumerateAttribute(ChatTextInputAttributes.textUrl, in: full, options: []) { value, range, _ in
            if let url = value as? ChatTextInputTextUrlAttribute { rUrls.append((range, url.url)) }
        }
        if lUrls.count != rUrls.count { return false }
        for (l, r) in zip(lUrls, rUrls) where l.0 != r.0 || l.1 != r.1 { return false }
        return true
    }
}
