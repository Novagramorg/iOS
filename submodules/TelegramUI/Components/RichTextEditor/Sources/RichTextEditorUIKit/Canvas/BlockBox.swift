#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// One paragraph block in the canvas: a TextKit 2 layout plus the structural
/// fields not stored in the attributed string, its frame in canvas coordinates, and its start in the
/// document-wide global position space.
@available(iOS 17.0, *)
final class BlockBox {
    let id: BlockID
    var style: ParagraphStyleName
    var listMembership: ListMembership?
    var paragraphAttributes: ParagraphAttributes
    let layout: BlockLayout
    let mapper: AttributedStringMapper

    var frame: CGRect = .zero
    var globalStart: Int = 0
    /// Default vertical inset above/below a block's text — half of the full gap between two
    /// default-spaced blocks. The owning `BlockStack` may shrink the facing inset for adjacent blocks.
    static let defaultVerticalInset: CGFloat = 8
    // x is always 0 — the horizontal page margin lives in frame.minX (set by the root BlockStack layout
    // origin); inside a table cell the frame already starts past the cell padding.
    let textInset = CGPoint(x: 0, y: BlockBox.defaultVerticalInset)
    // Vertical insets above/below the text, set per-layout by the owning `BlockStack`. They default to
    // `defaultVerticalInset`, but the facing inset shrinks between adjacent blocks (0 between list items
    // so they stack like paragraph lines; half between two body paragraphs).
    var topInset: CGFloat = BlockBox.defaultVerticalInset
    var bottomInset: CGFloat = BlockBox.defaultVerticalInset

    /// The Core `ListNumbering` marker label for this box (e.g. "1.", "•"), stamped by the canvas
    /// during layout (numbering is document-wide). nil = not a list item / not stamped (table cells
    /// are never stamped, matching today's top-level-only marker rendering). Presentation only.
    var resolvedListMarker: String?

    /// True only for boxes laid out as the document root's children (set by the canvas during layout).
    /// Gates placeholder drawing so empty TABLE-CELL paragraphs draw no placeholder (parity with today,
    /// where placeholders are a top-level-only concern). Default false.
    var isTopLevelBlock = false

    /// A plain body paragraph (not a list item) — the spacing between two of these is tightened.
    var isBodyParagraph: Bool { style == .body && listMembership == nil }

    /// A cheap value that changes iff this box's rendered output would change: text/attribute version,
    /// frame size (wrapping/extent), and the stamped decoration state (marker label, top-level/placeholder
    /// gate). Used to skip a `setNeedsDisplay` when nothing changed.
    var renderSignature: Int {
        var h = Hasher()
        h.combine(layout.renderVersion)
        h.combine(frame.size.width); h.combine(frame.size.height)
        h.combine(resolvedListMarker)
        h.combine(isTopLevelBlock)
        // Defensive: a STYLE or list-LEVEL change on an EMPTY paragraph (where `restyle()` early-returns
        // and renderVersion may not bump) changes the placeholder text / marker indent. Capture it
        // structurally rather than coincidentally.
        h.combine(style)
        h.combine(listMembership?.level)
        return h.finalize()
    }

    init(paragraph: ParagraphBlock, mapper: AttributedStringMapper, width: CGFloat) {
        id = paragraph.id
        style = paragraph.style
        listMembership = paragraph.list
        paragraphAttributes = paragraph.paragraph
        self.mapper = mapper
        layout = BlockLayout(attributedString: mapper.attributedString(for: paragraph),
                             width: max(width, 1))
    }

    var length: Int { layout.length }
    var textRef: TextNodeRef { .paragraph(id) }
    var height: CGFloat { max(layout.boundingHeight, emptyLineHeight) + topInset + bottomInset }
    var textOrigin: CGPoint { CGPoint(x: frame.minX + textInset.x, y: frame.minY + topInset) }

    /// Height of one line in this paragraph's font, reserved only when the paragraph is EMPTY (TextKit 2
    /// lays out no fragment for empty text, so `boundingHeight` is ~0). Keeps a blank paragraph — and a
    /// blank table cell, which collapses its row otherwise — at a real line's height, matching what it
    /// becomes once text is typed (the font the style will use).
    private var emptyLineHeight: CGFloat {
        guard layout.length == 0 else { return 0 }
        let font = (mapper.attributes(for: CharacterAttributes(), style: style)[.font] as? UIFont)
            ?? UIFont.preferredFont(forTextStyle: .body)
        let ps = mapper.styleSheet.paragraphStyle(for: style, attributes: paragraphAttributes, list: listMembership)
        let mult = ps.lineHeightMultiple > 0 ? ps.lineHeightMultiple : 1
        return font.lineHeight * mult
    }

    /// Leading text indent (the paragraph style's `firstLineHeadIndent` — the list-marker spacing or
    /// quote inset) to apply to this paragraph's caret and placeholder *while it is EMPTY*. TextKit
    /// applies the indent to laid-out glyphs, but lays out no fragment for empty text, so the empty-line
    /// caret falls back to x=0 and the placeholder to `textOrigin` — both must add this so they align
    /// with where text will appear (past the marker). 0 once any text exists (the glyph layout carries
    /// it, so adding it again would double-indent). Mirrors `emptyLineHeight`.
    var emptyLineLeadingIndent: CGFloat {
        guard layout.length == 0 else { return 0 }
        return mapper.styleSheet.paragraphStyle(for: style, attributes: paragraphAttributes,
                                                list: listMembership).firstLineHeadIndent
    }

    func setWidth(_ width: CGFloat) { layout.setWidth(max(width - textInset.x * 2, 1)) }

    /// Y (relative to `textOrigin.y`) at which a list marker's baseline must sit to align with this
    /// paragraph's first text line. Uses the real laid-out baseline when text exists; for an empty list
    /// item it falls back to the style's line metrics, so the marker doesn't jump when the first glyph
    /// is typed (an empty TextKit 2 layout has no fragment to measure).
    func listMarkerBaselineFromTop(markerFont: UIFont) -> CGFloat {
        if let baseline = layout.firstLineBaselineFromTop { return baseline }
        let ps = mapper.styleSheet.paragraphStyle(for: style, attributes: paragraphAttributes, list: listMembership)
        let mult = ps.lineHeightMultiple > 0 ? ps.lineHeightMultiple : 1
        return markerFont.ascender + (mult - 1) * markerFont.lineHeight
    }

    /// This box's list-marker draw (label + canvas-coordinate origin + font), or nil when it has no
    /// stamped marker. Mirrors the geometry the canvas `listMarkerDraws()` seam used to compute, so the
    /// marker lands at the same place whether drawn here or by the seam.
    func listMarkerDraw() -> (label: String, origin: CGPoint, font: UIFont)? {
        guard let label = resolvedListMarker, let membership = listMembership else { return nil }
        let font = mapper.styleSheet.font(for: style, attributes: .plain)
        let x = textOrigin.x + StyleSheet.listIndentStep * CGFloat(membership.level)
        let y = textOrigin.y + listMarkerBaselineFromTop(markerFont: font) - font.ascender
        return (label, CGPoint(x: x, y: y), font)
    }

    /// Placeholder text for THIS empty paragraph, or nil. A list item's hint reflects what Return does.
    var placeholderText: String? {
        if let list = listMembership {
            return list.level > 0 ? "Press return to outdent" : "Press return to end the list"
        }
        switch style {
        case .title: return "Title"
        case .body:  return "Type something…"
        default:     return nil
        }
    }

    /// This box's placeholder draw (text + canvas-coordinate origin + font), or nil when it shouldn't
    /// show one (non-empty, non-top-level, or a style with no placeholder).
    func placeholderDraw() -> (text: String, origin: CGPoint, font: UIFont)? {
        guard isTopLevelBlock, layout.length == 0, let text = placeholderText else { return nil }
        let font = mapper.styleSheet.font(for: style, attributes: .plain)
        let ps = mapper.styleSheet.paragraphStyle(for: style, attributes: paragraphAttributes, list: listMembership)
        let mult = ps.lineHeightMultiple > 0 ? ps.lineHeightMultiple : 1
        let baselineShift = (mult - 1) * font.lineHeight
        let origin = CGPoint(x: textOrigin.x + emptyLineLeadingIndent, y: textOrigin.y + baselineShift)
        return (text, origin, font)
    }

    /// Applies a RENDER-ONLY override to the display layout: paragraph `alignment` (overriding the
    /// cell's own, for table column alignment) and, when `forceBold`, a bold font trait on every run
    /// (for an emphasized column/row, e.g. a table's first column). The stored model is NOT changed —
    /// alignment is read back from `paragraphAttributes` (untouched here), and
    /// `TableBlockBox.currentBlock()` strips the synthetic bold from the emphasized cells. Idempotent.
    /// No-op on empty text (the override re-applies once text exists).
    func applyDisplayOverride(alignment: TextAlignment, forceBold: Bool, mapper: AttributedStringMapper) {
        let storage = layout.attributedString
        guard storage.length > 0 else { return }
        let m = NSMutableAttributedString(attributedString: storage)
        let full = NSRange(location: 0, length: m.length)
        // Alignment: rebuild the paragraph style from this box's own attributes but with the override
        // alignment, preserving list/indent properties.
        var pa = paragraphAttributes
        pa.alignment = alignment
        let ps = mapper.styleSheet.paragraphStyle(for: style, attributes: pa, list: listMembership)
        m.addAttribute(.paragraphStyle, value: ps, range: full)
        // Bold: only ADD the trait (e.g. the first column). Never remove — other cells keep user bold.
        if forceBold {
            m.enumerateAttribute(.font, in: full, options: []) { value, range, _ in
                guard let font = value as? UIFont,
                      !font.fontDescriptor.symbolicTraits.contains(.traitBold) else { return }
                var traits = font.fontDescriptor.symbolicTraits
                traits.insert(.traitBold)
                if let d = font.fontDescriptor.withSymbolicTraits(traits) {
                    m.addAttribute(.font, value: UIFont(descriptor: d, size: font.pointSize), range: range)
                }
            }
        }
        // Truly idempotent (as the doc above promises): assign only when the override actually changes the
        // storage. In the steady state the override is already present, so `m == storage` and we skip the
        // assignment. This matters because `recompute()` calls this on EVERY layout pass: an unconditional
        // re-assign would (1) bump `renderVersion` every pass — defeating the render-signature repaint gate
        // for every table cell — and, more seriously, (2) reset the layout's spoiler-hide ranges every pass
        // (the `attributedString` setter clears them), so `setSpoilerHidden` never reports "no change" and
        // `syncSpoilers` calls `setNeedsLayout()` on every pass → an infinite `layoutIfNeeded` loop whenever a
        // table cell holds a HIDDEN spoiler. (Regression: SpoilerCrossRegionTests.)
        if !m.isEqual(storage) { layout.attributedString = m }
    }

    func currentParagraph() -> ParagraphBlock {
        ParagraphBlock(id: id, style: style, paragraph: paragraphAttributes, list: listMembership,
                       runs: mapper.runs(from: layout.attributedString))
    }
}

@available(iOS 17.0, *)
extension BlockBox: CanvasBlock {
    var rendersAsBlockView: Bool { true }
    var nodeStart: Int { get { globalStart } set { globalStart = newValue } }
    var nodeSize: Int { length + 2 }
    var textLayout: BlockLayout { layout }
    var textStart: Int { globalStart }
    var textLength: Int { length }
    func currentBlock() -> Block { .paragraph(currentParagraph()) }
    func closestPosition(toCanvasPoint point: CGPoint) -> Int {
        textStart + layout.closestOffset(toPoint: CGPoint(x: point.x - textOrigin.x, y: point.y - textOrigin.y))
    }
    func leafRegions() -> [LeafTextRegion] {
        [LeafTextRegion(layout: layout, globalStart: globalStart, length: length,
                        ref: .paragraph(id), canvasOrigin: textOrigin,
                        emptyLineLeadingIndent: emptyLineLeadingIndent, emptyLineHeight: emptyLineHeight)]
    }
    func draw(in ctx: CGContext, imageProvider: (String) -> UIImage?) {
        layout.drawText(in: ctx, at: textOrigin)
        if let d = listMarkerDraw() {
            NSAttributedString(string: d.label,
                attributes: [.font: d.font, .foregroundColor: UIColor.label]).draw(at: d.origin)
        }
        if let pd = placeholderDraw() {
            NSAttributedString(string: pd.text,
                attributes: [.font: pd.font, .foregroundColor: UIColor.placeholderText]).draw(at: pd.origin)
        }
    }
}
#endif
