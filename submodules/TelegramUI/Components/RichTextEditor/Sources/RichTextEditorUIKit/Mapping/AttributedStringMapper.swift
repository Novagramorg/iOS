#if canImport(UIKit)
import UIKit
import RichTextEditorCore

@available(iOS 17.0, *)
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
@available(iOS 17.0, *)
public struct AttributedStringMapper {
    public let styleSheet: StyleSheet
    /// Square-side multiplier for inline emoji (× the font's ascender+|descender|). Baked into each
    /// `EmojiTextAttachment`, so a change takes effect on the next reload.
    public let emojiScale: CGFloat
    /// Theme colors used for render-time defaults (primary/secondary text, link accent). Mutable so a
    /// host theme change can be applied to the shared mapper before the next reload.
    public var theme: RichTextEditorTheme
    public init(styleSheet: StyleSheet = .default, emojiScale: CGFloat = 1.0, theme: RichTextEditorTheme = .default) {
        self.styleSheet = styleSheet
        self.emojiScale = emojiScale
        self.theme = theme
    }

    /// Points to enlarge a rendered inline emoji beyond its glyph box, per paragraph style (decoupled from
    /// the layout box, so it never expands the line — see `EmojiTextAttachment.renderBoost`). Body emoji
    /// read small at their bare glyph box, so they get +4pt; other styles use their glyph box as-is.
    public func emojiRenderBoost(for style: ParagraphStyleName) -> CGFloat {
        return style == .body ? 4.0 : 0.0
    }

    public func attributes(for ca: CharacterAttributes, style: ParagraphStyleName) -> [NSAttributedString.Key: Any] {
        if let emoji = ca.emoji {
            // An emoji run is purely the inline atom: an invisible square spacer sized to the style font.
            // No other char attributes apply (they'd be ignored on read-back anyway).
            return [.font: styleSheet.font(for: style, attributes: ca),
                    .attachment: EmojiTextAttachment(ref: emoji, scale: emojiScale,
                                                     renderBoost: emojiRenderBoost(for: style))]
        }
        var dict: [NSAttributedString.Key: Any] = [:]
        dict[.font] = styleSheet.font(for: style, attributes: ca)
        // Un-colored runs render in the theme's per-style default (secondary for captions, else primary).
        // This default is stripped back to nil on read-back (characterAttributes(from:style:)), so it never
        // persists into the model and re-themes cleanly.
        dict[.foregroundColor] = ca.foreground?.uiColor ?? (style == .caption ? theme.secondaryText : theme.primaryText)
        if let hl = ca.highlight { dict[.backgroundColor] = hl.uiColor }
        if ca.underline { dict[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        if ca.strikethrough { dict[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        if let link = ca.link {
            dict[.link] = link
            // Visible styling is render-derived from the link and suppressed on read-back (see
            // characterAttributes(from:)), mirroring the rtInlineCode precedent — so it never
            // contaminates the model's foreground/underline fields. If a run is also inline-code, the
            // code font/background win visually; both flags still round-trip independently.
            dict[.foregroundColor] = theme.accent
            // No underline: reference design shows links as accent-colored text only.
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

    public func characterAttributes(from dict: [NSAttributedString.Key: Any], style: ParagraphStyleName = .body) -> CharacterAttributes {
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
        // A linked run keeps foreground == nil (the accent is render-only). For a normal run, a foreground
        // equal to the theme's per-style default is the render-injected default → treat as unset (nil), so
        // the model stays clean and re-themable; only a genuinely different color round-trips as explicit.
        if !hasLink, let color = dict[.foregroundColor] as? UIColor {
            let rgba = color.rgba
            let styleDefault = (style == .caption ? theme.secondaryText : theme.primaryText).rgba
            ca.foreground = (rgba == styleDefault) ? nil : rgba
        }
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

    public func runs(from attr: NSAttributedString, style: ParagraphStyleName = .body) -> [TextRun] {
        var runs: [TextRun] = []
        let full = NSRange(location: 0, length: attr.length)
        attr.enumerateAttributes(in: full, options: []) { dict, range, _ in
            let text = (attr.string as NSString).substring(with: range)
            runs.append(TextRun(text: text, attributes: characterAttributes(from: dict, style: style)))
        }
        return runs
    }
}
#endif
