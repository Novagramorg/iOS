#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// `Document` fragment ↔ RTF for cross-app copy/paste. Export carries only SEMANTIC inline formatting
/// (no theme colors); import reads back the supported inline flag set (bold/italic/underline/strike/link).
enum RTFConversion {
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
        for (i, block) in fragment.blocks.enumerated() {
            if i > 0 { out.append(NSAttributedString(string: "\n")) }
            switch block {
            case .paragraph(let p):
                appendRuns(p.runs, style: p.style, mono: false, to: out)
            case .code(let c):
                appendRuns(c.runs, style: .body, mono: true, to: out)
            default:
                break   // media/table carry no RTF text representation
            }
        }
        guard out.length > 0 else { return nil }
        return try? out.data(from: NSRange(location: 0, length: out.length),
                              documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
    }

    private static func appendRuns(_ runs: [TextRun], style: ParagraphStyleName, mono: Bool,
                                   to out: NSMutableAttributedString) {
        let size = fontSize(for: style)
        for run in runs {
            let ca = run.attributes
            var attrs: [NSAttributedString.Key: Any] = [
                .font: font(size: size, bold: ca.bold, italic: ca.italic, mono: mono || ca.inlineCode),
            ]
            if ca.underline { attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue }
            if ca.strikethrough { attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
            if let link = ca.link, let url = URL(string: link) { attrs[.link] = url }
            // Emoji/mention/date degrade to their text form in RTF (altText already in run.text? no —
            // an emoji run's text is U+FFFC; substitute altText so RTF carries readable text).
            let text = run.attributes.emoji?.altText ?? run.text
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
            if let url = dict[.link] as? URL { ca.link = url.absoluteString }
            else if let str = dict[.link] as? String { ca.link = str }
            out.append(TextRun(text: text, attributes: ca))
        }
        return out
    }
}
#endif
