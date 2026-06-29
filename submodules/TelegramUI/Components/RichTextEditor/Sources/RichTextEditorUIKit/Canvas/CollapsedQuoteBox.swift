#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// A collapsed (folded) blockquote in the canvas: a non-editable ATOM (audio-media-block shape, nodeSize 3)
/// drawing a ≤3-line truncated preview of its folded quote paragraphs. Its bar+fill is painted by the shared
/// `BlockquoteUnderlay` (its frame is reported as a run by `blockquoteDecorations()`); `draw` paints only the
/// preview text + an "expand" glyph. Tapping it expands it back to quote paragraphs (handled by the canvas).
@available(iOS 13.0, *)
final class CollapsedQuoteBox {
    let id: BlockID
    var paragraphs: [ParagraphBlock]
    let mapper: AttributedStringMapper
    let quoteStyle: QuoteStyle
    /// Display-only preview layout (NOT part of the position/selection axis).
    let layout: BlockLayoutEngine

    var frame: CGRect = .zero
    var globalStart: Int = 0

    static let maxPreviewLines: Int = 3
    static let verticalInset: CGFloat = 8
    /// Square side of the trailing "expand" glyph, plus its gap from the text.
    static let expandGlyphSize: CGFloat = 16
    static let expandGlyphGap: CGFloat = 6

    var topInset: CGFloat = CollapsedQuoteBox.verticalInset
    var bottomInset: CGFloat = CollapsedQuoteBox.verticalInset

    private var leadingPad: CGFloat { quoteStyle.leadingInset }
    private var trailingPad: CGFloat {
        max(quoteStyle.trailingInset, 0) + CollapsedQuoteBox.expandGlyphSize + CollapsedQuoteBox.expandGlyphGap
    }

    static func previewAttributes(mapper: AttributedStringMapper) -> [NSAttributedString.Key: Any] {
        let ps = NSMutableParagraphStyle()
        ps.lineBreakMode = .byTruncatingTail
        return [.font: mapper.styleSheet.font(for: .quote, attributes: .plain),
                .foregroundColor: mapper.theme.primaryText,
                .paragraphStyle: ps]
    }

    static func previewString(for q: CollapsedQuote, mapper: AttributedStringMapper) -> NSAttributedString {
        // Newlines collapsed to spaces — the preview is a single truncated text run (≤3 wrapped lines).
        NSAttributedString(string: q.previewText.replacingOccurrences(of: "\n", with: " "),
                           attributes: previewAttributes(mapper: mapper))
    }

    private func textWidth(_ width: CGFloat) -> CGFloat {
        max(width - leadingPad - trailingPad, 1)
    }

    init(collapsedQuote q: CollapsedQuote, mapper: AttributedStringMapper, quoteStyle: QuoteStyle, width: CGFloat) {
        self.id = q.id
        self.paragraphs = q.paragraphs
        self.mapper = mapper
        self.quoteStyle = quoteStyle
        let tw = max(width - quoteStyle.leadingInset
                     - (max(quoteStyle.trailingInset, 0) + CollapsedQuoteBox.expandGlyphSize + CollapsedQuoteBox.expandGlyphGap), 1)
        self.layout = makeBlockLayout(attributedString: CollapsedQuoteBox.previewString(for: q, mapper: mapper),
                                      width: tw)
    }

    private var lineHeight: CGFloat {
        mapper.styleSheet.font(for: .quote, attributes: .plain).lineHeight
    }

    /// Preview height capped at `maxPreviewLines` lines.
    private var previewHeight: CGFloat {
        min(layout.boundingHeight, lineHeight * CGFloat(CollapsedQuoteBox.maxPreviewLines))
    }

    func currentCollapsedQuote() -> CollapsedQuote { CollapsedQuote(id: id, paragraphs: paragraphs) }

    /// The trailing "expand" glyph rect in canvas coordinates (used by the canvas's tap routing too).
    func expandGlyphRect() -> CGRect {
        CGRect(x: frame.maxX - max(quoteStyle.trailingInset, 0) - CollapsedQuoteBox.expandGlyphSize,
               y: frame.minY + topInset,
               width: CollapsedQuoteBox.expandGlyphSize, height: CollapsedQuoteBox.expandGlyphSize)
    }
}

@available(iOS 13.0, *)
extension CollapsedQuoteBox: CanvasBlock {
    var rendersAsBlockView: Bool { true }
    var nodeStart: Int { get { globalStart } set { globalStart = newValue } }
    var nodeSize: Int { 3 }                          // caption-less atom (1) + wrapper (+2), like audio
    var textLayout: BlockLayoutEngine { layout }
    var textStart: Int { nodeStart }
    var textLength: Int { 0 }                         // non-editable: no text on the position axis
    var textRef: TextNodeRef { .paragraph(id) }       // unused (leafRegions is empty); a valid placeholder ref
    var textOrigin: CGPoint { CGPoint(x: frame.minX + leadingPad, y: frame.minY + topInset) }
    var height: CGFloat { previewHeight + topInset + bottomInset }

    func measuredHeight(forWidth width: CGFloat) -> CGFloat {
        let h = min(layout.boundingHeight(forWidth: textWidth(width)),
                    lineHeight * CGFloat(CollapsedQuoteBox.maxPreviewLines))
        return h + topInset + bottomInset
    }

    func setWidth(_ width: CGFloat) { layout.setWidth(textWidth(width)) }

    func currentBlock() -> Block { .collapsedQuote(currentCollapsedQuote()) }

    func closestPosition(toCanvasPoint point: CGPoint) -> Int { nodeStart }   // atom: caret lands at the gap

    func leafRegions() -> [LeafTextRegion] { [] }                             // off the editable text axis (like audio)

    func draw(in ctx: CGContext, imageProvider: (String) -> UIImage?) {
        // Bar+fill are drawn by the shared BlockquoteUnderlay (this box's frame is a blockquote run).
        // Clip the preview to maxPreviewLines, then draw the text and the expand glyph.
        ctx.saveGState()
        ctx.clip(to: CGRect(x: textOrigin.x, y: textOrigin.y,
                            width: textWidth(frame.width), height: previewHeight))
        layout.drawText(in: ctx, at: textOrigin)
        ctx.restoreGState()
        if let glyph = UIImage(systemName: "arrow.up.left.and.arrow.down.right")?
            .withTintColor(mapper.theme.accent, renderingMode: .alwaysOriginal) {
            glyph.draw(in: expandGlyphRect())
        }
    }
}
#endif
