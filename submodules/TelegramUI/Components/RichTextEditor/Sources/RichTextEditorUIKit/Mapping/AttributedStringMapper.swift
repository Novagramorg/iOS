#if canImport(UIKit)
import UIKit
import RichTextEditorCore

extension NSAttributedString.Key {
    /// Marks a run as inline code (GFM `code`). At render time the mapper swaps in a monospaced font
    /// + subtle background; on read-back it round-trips to `CharacterAttributes.inlineCode` (and
    /// suppresses fontFamily/highlight derivation so the mono font + code background don't leak into
    /// the model).
    static let rtInlineCode = NSAttributedString.Key("RTInlineCode")
    /// Marks a run as a spoiler. Render-only storage marker (the `rtInlineCode` precedent); the visible
    /// hide is a SEPARATE display-only `.foregroundColor` rendering attribute (see `BlockLayout`), so this
    /// marker carries no styling and round-trips cleanly to `CharacterAttributes.spoiler`.
    static let rtSpoiler = NSAttributedString.Key("RTSpoiler")
}

/// Converts between the Core model and `NSAttributedString` for one paragraph block.
public struct AttributedStringMapper {
    public let styleSheet: StyleSheet
    /// Square-side multiplier for inline emoji (× the font's ascender+|descender|). Baked into each
    /// `EmojiTextAttachment`, so a change takes effect on the next reload.
    public let emojiScale: CGFloat
    public init(styleSheet: StyleSheet = .default, emojiScale: CGFloat = 1.0) {
        self.styleSheet = styleSheet
        self.emojiScale = emojiScale
    }

    public func attributes(for ca: CharacterAttributes, style: ParagraphStyleName) -> [NSAttributedString.Key: Any] {
        if let emoji = ca.emoji {
            // An emoji run is purely the inline atom: an invisible square spacer sized to the style font.
            // No other char attributes apply (they'd be ignored on read-back anyway).
            return [.font: styleSheet.font(for: style, attributes: ca),
                    .attachment: EmojiTextAttachment(ref: emoji, scale: emojiScale)]
        }
        var dict: [NSAttributedString.Key: Any] = [:]
        dict[.font] = styleSheet.font(for: style, attributes: ca)
        dict[.foregroundColor] = (ca.foreground ?? .black).uiColor
        if let hl = ca.highlight { dict[.backgroundColor] = hl.uiColor }
        if ca.underline { dict[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        if ca.strikethrough { dict[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        if let link = ca.link {
            dict[.link] = link
            // Visible styling is render-derived from the link and suppressed on read-back (see
            // characterAttributes(from:)), mirroring the rtInlineCode precedent — so it never
            // contaminates the model's foreground/underline fields. If a run is also inline-code, the
            // code font/background win visually; both flags still round-trip independently.
            dict[.foregroundColor] = UIColor.link
            // No underline: reference design shows links as blue text only.
        }
        if let b = ca.baselineOffset { dict[.baselineOffset] = b }
        if ca.inlineCode {
            let size = styleSheet.font(for: style, attributes: ca).pointSize
            dict[.font] = UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
            dict[.backgroundColor] = UIColor.systemGray5
            dict[.rtInlineCode] = true
        }
        if ca.spoiler { dict[.rtSpoiler] = true }
        return dict
    }

    public func characterAttributes(from dict: [NSAttributedString.Key: Any]) -> CharacterAttributes {
        var ca = CharacterAttributes()
        if let att = dict[.attachment] as? EmojiTextAttachment {
            ca.emoji = att.ref   // emoji-only; never leak the spacer font/etc. into the model
            return ca
        }
        let isCode = (dict[.rtInlineCode] as? Bool) == true
        if let font = dict[.font] as? UIFont {
            let traits = font.fontDescriptor.symbolicTraits
            ca.bold = traits.contains(.traitBold)
            ca.italic = traits.contains(.traitItalic)
            if !isCode {
                ca.fontSize = Double(font.pointSize)
                let sansDefault = UIFont.systemFont(ofSize: font.pointSize).familyName
                let serifDefault = UIFont.systemFont(ofSize: font.pointSize).fontDescriptor
                    .withDesign(.serif).map { UIFont(descriptor: $0, size: font.pointSize).familyName }
                if font.familyName != sansDefault && font.familyName != serifDefault {
                    ca.fontFamily = font.familyName
                }
            }
        }
        if isCode { ca.inlineCode = true }
        let hasLink = dict[.link] != nil
        // A linked run keeps foreground == nil (the blue is render-only); a normal run reads back .black.
        if !hasLink, let color = dict[.foregroundColor] as? UIColor { ca.foreground = color.rgba }
        if !isCode, let bg = dict[.backgroundColor] as? UIColor { ca.highlight = bg.rgba }
        if !hasLink, let u = dict[.underlineStyle] as? Int, u != 0 { ca.underline = true }
        if let s = dict[.strikethroughStyle] as? Int, s != 0 { ca.strikethrough = true }
        if let link = dict[.link] as? String { ca.link = link }
        else if let url = dict[.link] as? URL { ca.link = url.absoluteString }
        if let b = dict[.baselineOffset] as? Double { ca.baselineOffset = b }
        else if let b = dict[.baselineOffset] as? CGFloat { ca.baselineOffset = Double(b) }
        if (dict[.rtSpoiler] as? Bool) == true { ca.spoiler = true }
        return ca
    }

    public func attributedString(for block: ParagraphBlock) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let paragraphStyle = styleSheet.paragraphStyle(for: block.style, attributes: block.paragraph,
                                                       list: block.list)
        for run in block.runs {
            var attrs = attributes(for: run.attributes, style: block.style)
            attrs[.paragraphStyle] = paragraphStyle
            result.append(NSAttributedString(string: run.text, attributes: attrs))
        }
        return result
    }

    public func runs(from attr: NSAttributedString) -> [TextRun] {
        var runs: [TextRun] = []
        let full = NSRange(location: 0, length: attr.length)
        attr.enumerateAttributes(in: full, options: []) { dict, range, _ in
            let text = (attr.string as NSString).substring(with: range)
            runs.append(TextRun(text: text, attributes: characterAttributes(from: dict)))
        }
        return runs
    }
}
#endif
