#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// One block-quote container in the canvas: a `CanvasBlock` that branches on `collapsed`.
///
/// **Expanded** (`collapsed == false`): a container hosting one child `BlockStack` built via `makeBox`,
/// so any block type nests — including nested block quotes (the factory is recursive). Token size =
/// children + 2; `recompute()` assigns child `nodeStart`s and lays out frames; `leafRegions()` /
/// `closestPosition` delegate to the child stack. The fill (accent bar + tinted background) is painted
/// by `blockquoteDecorations()` — this box draws only its children.
///
/// **Collapsed** (`collapsed == true`): a non-editable ATOM (nodeSize 3, empty leafRegions) drawing a
/// ≤3-line folded preview + a trailing expand glyph — mirroring `CollapsedQuoteBox`. Children are still
/// built (for `currentBlock()` round-trip + expand); the collapsed branch only changes the axis/geometry/draw.
/// This matches `DocumentTree` (Task 2), which maps a collapsed blockQuote to a `.mediaBlock`+`.mediaAtom`
/// atom (nodeSize 3) — so the box's nodeSize MUST also be 3 when collapsed.
@available(iOS 13.0, *)
final class BlockQuoteBox: CanvasBlock {
    // MARK: - Collapsed preview geometry constants
    // (Formerly on the removed CollapsedQuoteBox; kept here so BlockQuoteBox's collapsed mode is self-contained.)
    static let maxPreviewLines: Int = 3
    /// Square side of the trailing "expand" glyph, plus its gap from the text content.
    static let expandGlyphSize: CGFloat = 18
    static let expandGlyphGap: CGFloat = 6

    /// Text attributes used by the collapsed preview layout (body font, primary text color, tail-truncating).
    /// Uses the mapper's body paragraph style (carries lineHeightMultiple + spacing from StyleSheet.metrics)
    /// so the collapsed preview's per-line height exactly matches the expanded child BlockBox, giving the
    /// same total height for a single-line quote regardless of collapsed/expanded state.
    static func previewAttributes(mapper: AttributedStringMapper) -> [NSAttributedString.Key: Any] {
        let base = mapper.styleSheet.paragraphStyle(for: .body, attributes: .default)
        let ps = (base.mutableCopy() as! NSMutableParagraphStyle)
        ps.lineBreakMode = .byTruncatingTail
        return [.font: mapper.styleSheet.font(for: .body, attributes: .plain),
                .foregroundColor: mapper.theme.primaryText,
                .paragraphStyle: ps]
    }

    let id: BlockID
    let mapper: AttributedStringMapper
    let quoteStyle: QuoteStyle
    let pullQuoteStyle: PullQuoteStyle
    let expandImage: UIImage?
    /// Collapse glyph drawn on an expanded box that is tall enough (mirrors QuoteCollapseControlsView's glyph
    /// for the flat quote but self-contained here so nested quotes work and the flat mechanism is untouched).
    let collapseImage: UIImage?
    /// Whether the block quote is collapsed. When true the box is a non-editable atom (nodeSize 3).
    let collapsed: Bool

    var frame: CGRect = .zero
    var nodeStart: Int = 0
    private(set) var layoutWidth: CGFloat

    /// Interior top padding (fill → first child). Mirrors `CodeBlockBox`: uses the QuoteStyle vertical
    /// inset if the mapper's stylesheet has one, otherwise the block-box default (8pt).
    var topInset: CGFloat
    /// Interior bottom padding (last child → fill bottom). Mirrors `topInset`.
    var bottomInset: CGFloat

    /// The single child stack — one `BlockStack` analogous to a single table cell. Children are built via
    /// `makeBox`, so any block type (paragraph, code, nested block quote, …) can appear here. The stack
    /// uses the document-standard `BlockBox.defaultVerticalInset` (8pt) between children — not 0 like a
    /// table cell — because the children are regular document blocks with normal inter-block spacing.
    let children: BlockStack

    /// Display-only preview layout for collapsed mode (nil when expanded). NOT part of the position axis.
    private let previewLayout: BlockLayoutEngine?

    init(blockQuote: BlockQuote, mapper: AttributedStringMapper,
         quoteStyle: QuoteStyle = .default,
         pullQuoteStyle: PullQuoteStyle = .default,
         expandImage: UIImage? = nil,
         collapseImage: UIImage? = nil,
         width: CGFloat) {
        // Derive a 15pt-body mapper for all quote content. This preserves the host's quote insets,
        // spacing, theme, emoji scale, and writing direction (unlike `tableCellVariant()`, which
        // swaps in the fixed `.tableCells` stylesheet). Nested quotes and quotes-in-cells call
        // withBodyBaseSize(15) on their already-15pt mapper → idempotent; no per-level shrink.
        let quoteMapper = mapper.withBodyBaseSize(15)
        self.id = blockQuote.id
        self.mapper = quoteMapper
        self.quoteStyle = quoteStyle
        self.pullQuoteStyle = pullQuoteStyle
        self.expandImage = expandImage
        self.collapseImage = collapseImage
        self.collapsed = blockQuote.collapsed
        self.layoutWidth = max(width, 1)
        // Vertical insets mirror CodeBlockBox: prefer the QuoteStyle-sourced stylesheet value.
        // Read from quoteMapper so the insets are consistent with the quote's own stylesheet.
        self.topInset = quoteMapper.styleSheet.quoteTopInset ?? BlockBox.defaultVerticalInset
        self.bottomInset = quoteMapper.styleSheet.quoteBottomInset ?? BlockBox.defaultVerticalInset

        let inner = max(width - quoteStyle.leadingInset - quoteStyle.trailingInset, 1)
        let stack = BlockStack(boxes: blockQuote.children.compactMap {
            makeBox(for: $0, mapper: quoteMapper, quoteStyle: quoteStyle, pullQuoteStyle: pullQuoteStyle,
                    expandImage: expandImage, collapseImage: collapseImage, horizontalBleed: 0, width: inner)
        })
        // 0 inset base so the first child's content-top aligns with the collapsed preview's text-top
        // (frame.minY + topInset). The collapsed preview starts there; the expanded first child must start
        // there too, so the two modes are visually consistent. Inter-child spacing comes from each child's
        // own topInset/bottomInset (via `facingInset`), exactly like table cells whose cell frame owns all
        // vertical padding. The quote's topInset/bottomInset are the sole outer padding.
        stack.verticalInsetBase = 0
        self.children = stack

        // Collapsed mode: build a display-only preview layout from the children's flattened plain text.
        // Newlines → spaces so the preview is a single wrapped text run (≤3 lines), matching BlockQuoteBox.
        if blockQuote.collapsed {
            let joined = blockQuote.children.map { blockPlainText($0) }.joined(separator: "\n")
            let previewText = joined.replacingOccurrences(of: "\n", with: " ")
            let tw = max(width - quoteStyle.leadingInset
                         - (max(quoteStyle.trailingInset, 0)
                            + BlockQuoteBox.expandGlyphSize
                            + BlockQuoteBox.expandGlyphGap), 1)
            let attrs = BlockQuoteBox.previewAttributes(mapper: quoteMapper)
            self.previewLayout = makeBlockLayout(
                attributedString: NSAttributedString(string: previewText, attributes: attrs),
                width: tw)
        } else {
            self.previewLayout = nil
        }
    }

    // MARK: - Collapsed preview helpers (mirror CollapsedQuoteBox geometry)

    private var leadingPad: CGFloat { quoteStyle.leadingInset }
    private var trailingPad: CGFloat {
        max(quoteStyle.trailingInset, 0) + BlockQuoteBox.expandGlyphSize + BlockQuoteBox.expandGlyphGap
    }
    private func previewTextWidth(_ width: CGFloat) -> CGFloat {
        max(width - leadingPad - trailingPad, 1)
    }
    private var lineHeight: CGFloat {
        mapper.styleSheet.font(for: .body, attributes: .plain).lineHeight
    }
    private var previewHeight: CGFloat {
        guard let layout = previewLayout else { return 0 }
        return min(layout.boundingHeight, lineHeight * CGFloat(BlockQuoteBox.maxPreviewLines))
    }

    /// Whether the collapse control should appear. Only when the quote's content is TALLER than the
    /// ≤`maxPreviewLines`-line collapsed preview would show — i.e. collapsing actually hides content
    /// ("more than 3 body lines worth of content, vertically"). A short quote gets no collapse glyph.
    var isCollapsible: Bool {
        children.measuredHeight(forWidth: innerWidth(layoutWidth)) > CGFloat(BlockQuoteBox.maxPreviewLines) * lineHeight
    }

    /// The trailing "expand" glyph rect in canvas coordinates (used by the canvas's tap routing, Task 12).
    func expandGlyphRect() -> CGRect {
        CGRect(x: frame.maxX - 4 - BlockQuoteBox.expandGlyphSize,
               y: frame.minY + 4,
               width: BlockQuoteBox.expandGlyphSize, height: BlockQuoteBox.expandGlyphSize)
    }

    /// The top-right "collapse" glyph rect for an EXPANDED box (drawn on every expanded quote regardless
    /// of height or nesting level). Mirrors `expandGlyphRect` geometry.
    func collapseGlyphRect() -> CGRect {
        let s = DocumentCanvasView.collapseButtonSize
        return CGRect(x: frame.maxX - 4 - s, y: frame.minY + 4, width: s, height: s)
    }

    // MARK: - Internal helpers

    private func innerWidth(_ w: CGFloat) -> CGFloat {
        max(w - quoteStyle.leadingInset - quoteStyle.trailingInset, 1)
    }

    // MARK: - CanvasBlock

    /// Block-quote boxes use a `BlockBackingView`, like tables and pull-quotes.
    var rendersAsBlockView: Bool { true }

    /// Collapsed → 3 (non-editable atom, matching DocumentTree's collapsed mapping).
    /// Expanded → open + children tokens + close (Σchildren + 2).
    var nodeSize: Int {
        collapsed ? 3 : children.boxes.reduce(0) { $0 + $1.nodeSize } + 2
    }

    func setWidth(_ width: CGFloat) {
        layoutWidth = max(width, 1)
        if collapsed {
            previewLayout?.setWidth(previewTextWidth(layoutWidth))
        } else {
            let inner = innerWidth(layoutWidth)
            for box in children.boxes { box.setWidth(inner) }
        }
    }

    /// Collapsed → preview height (capped at maxPreviewLines) + insets.
    /// Expanded → topInset + child stack measured height + bottomInset.
    var height: CGFloat {
        if collapsed {
            return previewHeight + topInset + bottomInset
        }
        return topInset + children.measuredHeight(forWidth: innerWidth(layoutWidth)) + bottomInset
    }

    func measuredHeight(forWidth width: CGFloat) -> CGFloat {
        if collapsed {
            guard let layout = previewLayout else { return topInset + bottomInset }
            let tw = previewTextWidth(max(width, 1))
            let h = min(layout.boundingHeight(forWidth: tw),
                        lineHeight * CGFloat(BlockQuoteBox.maxPreviewLines))
            return h + topInset + bottomInset
        }
        return topInset + children.measuredHeight(forWidth: innerWidth(max(width, 1))) + bottomInset
    }

    /// Assigns `nodeStart` to every child box and lays out child frames. Mirrors `TableBlockBox.recompute()`
    /// for the single-cell (no row/grid) case. Called by the canvas from `recomputeSpans()` and
    /// `layoutContent()` after the root layout has set `self.frame` and `self.nodeStart`.
    /// Recursively recomputes any nested `BlockQuoteBox` children.
    /// Collapsed → early return (children are off the position axis; their spans are irrelevant for layout).
    func recompute() {
        if collapsed { return }
        // Assign nodeStarts: baseOffset = this box's nodeStart (the open token).
        children.recompute(baseOffset: nodeStart)
        // Lay out child frames: content strip offset by the leading inset and top padding.
        children.layout(
            origin: CGPoint(x: frame.minX + quoteStyle.leadingInset, y: frame.minY + topInset),
            width: innerWidth(frame.width)
        )
        // Propagate recompute recursively into nested block quotes (their frames are now set above).
        for case let nested as BlockQuoteBox in children.boxes { nested.recompute() }
    }

    /// Round-trips back to the Core model: rebuilds the `BlockQuote` from the current child boxes.
    /// Children are preserved even in collapsed mode (for expand + send round-trip).
    func currentBlock() -> Block {
        .blockQuote(BlockQuote(id: id,
                               children: children.boxes.map { $0.currentBlock() },
                               collapsed: collapsed))
    }

    /// Collapsed → [] (non-editable atom, off the position axis).
    /// Expanded → delegates to the child stack (recurses into nested quotes).
    func leafRegions() -> [LeafTextRegion] {
        collapsed ? [] : children.leafRegions()
    }

    /// The child `BlockStack` + box that owns global position `pos`, with its local offset + index.
    /// Mirrors `TableBlockBox.cellStack(containing:)` for the single-stack (no row) case.
    func childStack(containing pos: Int) -> (stack: BlockStack, box: CanvasBlock, local: Int, index: Int)? {
        for (i, b) in children.boxes.enumerated() {
            if let first = b.leafRegions().first,
               pos >= first.globalStart, pos <= first.globalStart + first.length {
                return (children, b, pos - first.globalStart, i)
            }
        }
        return nil
    }

    /// Collapsed → nodeStart (atom: caret lands at the gap, like CollapsedQuoteBox).
    /// Expanded → delegates to the child stack.
    func closestPosition(toCanvasPoint point: CGPoint) -> Int {
        collapsed ? nodeStart : children.closestPosition(toCanvasPoint: point)
    }

    /// Collapsed → draws the clipped preview text + the tinted expand glyph (mirrors BlockQuoteBox.draw).
    /// Expanded → draws child boxes. The fill (accent bar + tinted background) is provided by
    /// `blockquoteDecorations()` in both modes — this method draws only the text content.
    func draw(in ctx: CGContext, imageProvider: (String) -> UIImage?) {
        if collapsed {
            guard let layout = previewLayout else { return }
            let textOrigin = CGPoint(x: frame.minX + leadingPad, y: frame.minY + topInset)
            let tw = previewTextWidth(frame.width)
            let ph = previewHeight
            ctx.saveGState()
            ctx.clip(to: CGRect(x: textOrigin.x, y: textOrigin.y, width: tw, height: ph))
            layout.drawText(in: ctx, at: textOrigin)
            ctx.restoreGState()
            if let image = expandImage {
                image.withTintColor(mapper.theme.accent, renderingMode: .alwaysOriginal).draw(in: expandGlyphRect())
            }
            return
        }
        children.draw(in: ctx, imageProvider: imageProvider)
        // Draw the collapse glyph only when the quote is worth collapsing (`isCollapsible`: content
        // taller than the ≤maxPreviewLines-line preview), at any nesting level. The flat-quote
        // QuoteCollapseControlsView gating is untouched — this glyph is the BlockQuoteBox's own control.
        if let image = collapseImage, isCollapsible {
            image.withTintColor(mapper.theme.accent, renderingMode: .alwaysOriginal).draw(in: collapseGlyphRect())
        }
    }

    // MARK: - Degenerate single-text-region members (unused: the canvas uses leafRegions())
    // Per-instance (not static): keeps any accidental write to one quote, not all. Mirrors TableBlockBox.
    private let emptyLayout = makeBlockLayout(attributedString: NSAttributedString(string: ""), width: 1)
    var textLayout: BlockLayoutEngine { emptyLayout }
    var textStart: Int { nodeStart }
    var textLength: Int { 0 }
    var textRef: TextNodeRef { .paragraph(id) }
    var textOrigin: CGPoint { frame.origin }
}
#endif
