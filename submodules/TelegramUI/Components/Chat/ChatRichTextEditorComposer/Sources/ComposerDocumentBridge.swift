import Foundation
import UIKit
import TelegramCore
import RichTextEditorCore
import TextFormat

/// Pure bidirectional bridge between the chat composer's `ChatTextInputAttributes`-keyed
/// `NSAttributedString` and the RichTextEditor `Document` model. Phase 1: body/quote paragraphs +
/// inline styles + spoiler + link + mention/date (via tg:// link schemes) + custom emoji (EmojiRef).
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
                    if let emoji = dict[ChatTextInputAttributes.customEmoji] as? ChatTextInputTextCustomEmojiAttribute {
                        // Map the composer's custom-emoji placeholder to a single-U+FFFC EmojiRef run.
                        // The original placeholder text (whatever the attribute rode on) is preserved as
                        // altText so the reverse path can re-emit it verbatim, while the Document interior
                        // stays one U+FFFC per the editor invariant. instanceID uses the editor's own
                        // BlockID.generate() convention.
                        var emojiCA = CharacterAttributes.plain
                        emojiCA.emoji = EmojiRef(
                            id: String(emoji.fileId),
                            instanceID: BlockID.generate().rawValue,
                            altText: fullString.substring(with: range)
                        )
                        runs.append(TextRun(text: "\u{FFFC}", attributes: emojiCA))
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
                    if let mention = dict[ChatTextInputAttributes.textMention] as? ChatTextInputTextMentionAttribute {
                        ca.link = mentionMarkdownURL(peerId: mention.peerId)
                    } else if let date = dict[ChatTextInputAttributes.date] as? ChatTextInputTextDateAttribute {
                        ca.link = dateMarkdownURL(timestamp: date.date)
                    } else if let url = dict[ChatTextInputAttributes.textUrl] as? ChatTextInputTextUrlAttribute {
                        ca.link = url.url
                    }
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
                if let emoji = run.attributes.emoji {
                    // Re-emit a custom emoji as a ChatTextInputAttributes.customEmoji run. Prefer the
                    // preserved placeholder text (altText) so the entity length/text matches what the user
                    // composed; fall back to a single U+FFFC. file: nil — the renderer/send path resolve the
                    // file from fileId. A non-numeric id (should not occur from this path) degrades to plain
                    // text rather than crashing.
                    let displayText = (emoji.altText?.isEmpty == false) ? emoji.altText! : "\u{FFFC}"
                    let piece = NSMutableAttributedString(string: displayText, attributes: [.font: baseFont])
                    let range = NSRange(location: 0, length: piece.length)
                    if let fileId = Int64(emoji.id) {
                        piece.addAttribute(
                            ChatTextInputAttributes.customEmoji,
                            value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: fileId, file: nil),
                            range: range
                        )
                    }
                    result.append(piece)
                    continue
                }
                let text = run.text
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
                    let attribute = chatInputLinkAttribute(forLink: link)
                    piece.addAttribute(attribute.key, value: attribute.value, range: range)
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
            ChatTextInputAttributes.textUrl, ChatTextInputAttributes.block,
            ChatTextInputAttributes.customEmoji, ChatTextInputAttributes.textMention, ChatTextInputAttributes.date
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
        // Custom emoji: compare fileId at each range explicitly. ChatTextInputTextCustomEmojiAttribute.isEqual
        // is identity-based, so isEqual would treat two equal-fileId instances (always freshly built on a
        // round-trip) as different; compare the fileId, mirroring the .textUrl block above.
        var lEmoji: [(NSRange, Int64)] = []
        var rEmoji: [(NSRange, Int64)] = []
        lhs.enumerateAttribute(ChatTextInputAttributes.customEmoji, in: full, options: []) { value, range, _ in
            if let v = value as? ChatTextInputTextCustomEmojiAttribute { lEmoji.append((range, v.fileId)) }
        }
        rhs.enumerateAttribute(ChatTextInputAttributes.customEmoji, in: full, options: []) { value, range, _ in
            if let v = value as? ChatTextInputTextCustomEmojiAttribute { rEmoji.append((range, v.fileId)) }
        }
        if lEmoji.count != rEmoji.count { return false }
        for (l, r) in zip(lEmoji, rEmoji) where l.0 != r.0 || l.1 != r.1 { return false }
        // Mention and date also carry semantic payload; their attribute classes implement value-based isEqual
        // (peerId / timestamp), so compare the attribute values at matching ranges.
        for key in [ChatTextInputAttributes.textMention, ChatTextInputAttributes.date] {
            var lValues: [(NSRange, NSObject)] = []
            var rValues: [(NSRange, NSObject)] = []
            lhs.enumerateAttribute(key, in: full, options: []) { value, range, _ in if let v = value as? NSObject { lValues.append((range, v)) } }
            rhs.enumerateAttribute(key, in: full, options: []) { value, range, _ in if let v = value as? NSObject { rValues.append((range, v)) } }
            if lValues.count != rValues.count { return false }
            for (l, r) in zip(lValues, rValues) where l.0 != r.0 || !l.1.isEqual(r.1) { return false }
        }
        return true
    }
}
