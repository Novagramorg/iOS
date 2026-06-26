#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// Resolves a paragraph style name to concrete fonts/paragraph layout (UIKit-only, hence here
/// rather than in Core).
@available(iOS 13.0, *)
public struct StyleSheet {
    public init() {}
    public static let `default` = StyleSheet()
    /// A style sheet for content inside table cells: the body/quote base size is reduced from the
    /// document's 17pt to 15pt (headings and captions keep their fixed sizes), so a table reads denser
    /// than surrounding body text. Selected per-cell via `AttributedStringMapper.tableCellVariant()`.
    public static let tableCells: StyleSheet = { var s = StyleSheet(); s.bodyBaseSize = 15; return s }()

    /// Base point size for body and quote paragraphs — 17pt in the document body, 15pt inside table
    /// cells (see `tableCells`). Headings and captions have fixed sizes independent of this.
    public var bodyBaseSize: CGFloat = 17

    /// Points of indentation per list nesting level (where each level's marker hangs).
    public static let listIndentStep: CGFloat = 24
    /// Horizontal gap reserved between a list marker and its text — the text hangs this far past the
    /// marker's column. Half the per-level indent step, so it's decoupled from nesting depth.
    public static let listMarkerSpacing: CGFloat = listIndentStep / 2
    /// Extra text inset applied to ORDERED (numbered) list items on top of `listMarkerSpacing`. A
    /// number marker ("1.", "iii.") is much wider than a bullet, so its text needs more breathing room
    /// after the marker than a bullet's does. The marker itself stays in its level's column; only the
    /// item text shifts right by this amount.
    public static let orderedListTextInset: CGFloat = 4

    private func baseSize(_ style: ParagraphStyleName) -> CGFloat {
        switch style {
        case .heading1: return 24
        case .heading2: return 21
        case .heading3: return 19
        case .body, .quote: return bodyBaseSize
        case .caption: return 15
        }
    }

    /// Render-only per-style spacing/line-height (model values are 0/1.0). Validated against the reference design.
    private struct StyleMetrics { var spacingBefore: CGFloat; var spacingAfter: CGFloat; var lineHeightMultiple: CGFloat }
    private func metrics(for style: ParagraphStyleName) -> StyleMetrics {
        switch style {
        case .heading1: return StyleMetrics(spacingBefore: 18, spacingAfter: 6, lineHeightMultiple: 1.05)
        case .heading2: return StyleMetrics(spacingBefore: 16, spacingAfter: 6, lineHeightMultiple: 1.05)
        case .heading3: return StyleMetrics(spacingBefore: 14, spacingAfter: 6, lineHeightMultiple: 1.05)
        case .body:     return StyleMetrics(spacingBefore: 0,  spacingAfter: 8, lineHeightMultiple: 1.10)
        case .caption:  return StyleMetrics(spacingBefore: 0,  spacingAfter: 8, lineHeightMultiple: 1.10)
        case .quote:    return StyleMetrics(spacingBefore: 8,  spacingAfter: 8, lineHeightMultiple: 1.10)
        }
    }

    public func font(for style: ParagraphStyleName, attributes: CharacterAttributes) -> UIFont {
        let size = attributes.fontSize.map { CGFloat($0) } ?? baseSize(style)
        // Headings are NOT bold by default — they read as regular-weight serif at a larger size.
        // Bold is purely user emphasis (`CharacterAttributes.bold`), so it stays an independent toggle
        // that round-trips uniformly in every style (no style-injected weight to leak into the model).
        let bold = attributes.bold
        let italic = attributes.italic   // quote is upright; its bar/fill is a drawn canvas decoration (see DocumentCanvasView+Decorations)
        let serif = style == .heading1 || style == .heading2 || style == .heading3
        return FontResolver.font(family: attributes.fontFamily, size: size, bold: bold, italic: italic, serif: serif)
    }

    public func paragraphStyle(for style: ParagraphStyleName, attributes: ParagraphAttributes,
                               list: ListMembership? = nil) -> NSParagraphStyle {
        let ps = NSMutableParagraphStyle()
        switch attributes.alignment {
        case .left: ps.alignment = .left
        case .center: ps.alignment = .center
        case .right: ps.alignment = .right
        case .justified: ps.alignment = .justified
        }
        ps.firstLineHeadIndent = CGFloat(attributes.firstLineIndent)
        ps.headIndent = CGFloat(attributes.headIndent)
        ps.paragraphSpacingBefore = CGFloat(attributes.paragraphSpacingBefore)
        ps.paragraphSpacing = CGFloat(attributes.paragraphSpacingAfter)
        ps.lineHeightMultiple = CGFloat(attributes.lineHeightMultiple)
        let m = metrics(for: style)
        ps.paragraphSpacingBefore += m.spacingBefore
        ps.paragraphSpacing += m.spacingAfter
        if ps.lineHeightMultiple == 1 { ps.lineHeightMultiple = m.lineHeightMultiple }
        if let list = list {
            // Marker sits at the level's indent; text hangs `listMarkerSpacing` past it. Ordered
            // (numbered) items get extra text inset since a number marker is wider than a bullet.
            var indent = StyleSheet.listIndentStep * CGFloat(list.level) + StyleSheet.listMarkerSpacing
            if list.marker == .ordered { indent += StyleSheet.orderedListTextInset }
            ps.firstLineHeadIndent += indent
            ps.headIndent += indent
        } else if style == .quote {
            ps.headIndent += 16; ps.firstLineHeadIndent += 16
        }
        return ps
    }
}
#endif
