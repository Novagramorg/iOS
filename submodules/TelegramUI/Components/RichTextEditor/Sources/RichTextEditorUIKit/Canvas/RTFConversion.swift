#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// `Document` fragment ↔ RTF for cross-app copy/paste. Export carries only SEMANTIC inline formatting
/// (no theme colors); import reads back the supported inline flag set (bold/italic/underline/strike/link).
enum RTFConversion {
    // The custom-emoji marker URL. A custom emoji has no cross-app glyph, so RTF carries it as its altText
    // hyperlinked to this marker (the file id survives; import reconstructs the emoji) — symmetric with how
    // mentions/dates already round-trip as links. Replicated locally because the RichTextEditor package is
    // standalone (no TextFormat dependency); keep the format in sync with the canonical
    // submodules/TextFormat/Sources/CustomEmojiMarkdownMarker.swift — `tg://emoji?id=<fileId>`.
    private static let emojiMarkerPrefix = "tg://emoji?id="
    /// `tg://emoji?id=<id>&n=<seq>`. The `&n=` suffix is a per-export sequence number that makes EVERY
    /// emoji's URL unique, so NSAttributedString/RTF can't coalesce two adjacent identical emoji
    /// (same id + altText) into one run and lose the second on import. The canonical id is everything
    /// between `id=` and the first `&`.
    private static func emojiMarkerURL(id: String, dedup: Int) -> String { "\(emojiMarkerPrefix)\(id)&n=\(dedup)" }
    private static func emojiID(fromMarkerURL url: String) -> String? {
        guard url.hasPrefix(emojiMarkerPrefix) else { return nil }
        var id = String(url.dropFirst(emojiMarkerPrefix.count))
        if let amp = id.firstIndex(of: "&") { id = String(id[..<amp]) }   // drop the &n= de-dup suffix
        return id.isEmpty ? nil : id
    }

    private static func fontSize(for style: ParagraphStyleName) -> CGFloat {
        switch style {
        case .heading1: return 24; case .heading2: return 21; case .heading3: return 19
        case .body, .quote: return 17; case .caption: return 15
        }
    }

    private static func font(size: CGFloat, bold: Bool, italic: Bool, mono: Bool) -> UIFont {
        if mono { return UIFont.monospacedSystemFont(ofSize: size, weight: .regular) }
        var traits: UIFontDescriptor.SymbolicTraits = []
        if bold { traits.insert(.traitBold) }
        if italic { traits.insert(.traitItalic) }
        let base = UIFont.systemFont(ofSize: size)
        if let d = base.fontDescriptor.withSymbolicTraits(traits) { return UIFont(descriptor: d, size: size) }
        return base
    }

    static func rtfData(from fragment: Document) -> Data? {
        let out = NSMutableAttributedString()
        var emojiSeq = 0   // per-export sequence so each emoji marker URL is unique (no run coalescing)
        for (i, block) in fragment.blocks.enumerated() {
            if i > 0 { out.append(NSAttributedString(string: "\n")) }
            switch block {
            case .paragraph(let p):
                appendRuns(p.runs, style: p.style, mono: false, emojiSeq: &emojiSeq, to: out)
            case .code(let c):
                appendRuns(c.runs, style: .body, mono: true, emojiSeq: &emojiSeq, to: out)
            default:
                break   // media/table carry no RTF text representation
            }
        }
        guard out.length > 0 else { return nil }
        return try? out.data(from: NSRange(location: 0, length: out.length),
                              documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
    }

    private static func appendRuns(_ runs: [TextRun], style: ParagraphStyleName, mono: Bool,
                                   emojiSeq: inout Int, to out: NSMutableAttributedString) {
        let size = fontSize(for: style)
        for run in runs {
            let ca = run.attributes
            var attrs: [NSAttributedString.Key: Any] = [
                .font: font(size: size, bold: ca.bold, italic: ca.italic, mono: mono || ca.inlineCode),
            ]
            if ca.underline { attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue }
            if ca.strikethrough { attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
            let text: String
            if let emoji = ca.emoji {
                // An emoji run's text is U+FFFC; carry its altText hyperlinked to the tg://emoji?id= marker
                // so the file id survives cross-app and import can reconstruct the emoji. A nil/empty altText
                // falls back to a single space so the hyperlink rides on ≥1 character. (Mention/date already
                // arrive as `ca.link` and round-trip through the branch below.)
                let alt = emoji.altText ?? ""
                text = alt.isEmpty ? " " : alt
                if let url = URL(string: emojiMarkerURL(id: emoji.id, dedup: emojiSeq)) { attrs[.link] = url }
                emojiSeq += 1
            } else {
                if let link = ca.link, let url = URL(string: link) { attrs[.link] = url }
                text = run.text
            }
            out.append(NSAttributedString(string: text, attributes: attrs))
        }
    }

    static func fragment(fromRTF data: Data) -> Document? {
        guard let attr = try? NSAttributedString(data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
        else { return nil }
        let full = attr.string as NSString
        var blocks: [Block] = []
        var location = 0
        for line in full.components(separatedBy: "\n") {
            let lineLength = (line as NSString).length
            let range = NSRange(location: location, length: lineLength)
            blocks.append(.paragraph(ParagraphBlock(id: .generate(), runs: runs(in: attr, range: range))))
            location += lineLength + 1   // +1 for the "\n" separator
        }
        return Document(blocks: blocks)
    }

    /// Maps the attribute runs in `range` to clean TextRuns (supported inline flags + link only).
    private static func runs(in attr: NSAttributedString, range: NSRange) -> [TextRun] {
        guard range.length > 0 else { return [] }
        let full = attr.string as NSString
        var out: [TextRun] = []
        attr.enumerateAttributes(in: range, options: []) { dict, sub, _ in
            let text = full.substring(with: sub)
            var ca = CharacterAttributes()
            if let f = dict[.font] as? UIFont {
                let t = f.fontDescriptor.symbolicTraits
                ca.bold = t.contains(.traitBold)
                ca.italic = t.contains(.traitItalic)
            }
            if let u = dict[.underlineStyle] as? Int, u != 0 { ca.underline = true }
            if let s = dict[.strikethroughStyle] as? Int, s != 0 { ca.strikethrough = true }
            let linkString = (dict[.link] as? URL)?.absoluteString ?? (dict[.link] as? String)
            if let linkString, let emojiID = emojiID(fromMarkerURL: linkString) {
                // A tg://emoji?id= marker → reconstruct a single-U+FFFC custom emoji run (the model
                // invariant: one object-replacement char per emoji), altText = the display text. A fresh
                // instanceID matches the editor's own emoji-insert path (BlockID.generate()).
                ca.emoji = EmojiRef(id: emojiID, instanceID: BlockID.generate().rawValue, altText: text)
                out.append(TextRun(text: "\u{FFFC}", attributes: ca))
            } else {
                if let linkString { ca.link = linkString }
                out.append(TextRun(text: text, attributes: ca))
            }
        }
        return out
    }
}
#endif
