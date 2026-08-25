#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// One code block in the canvas: a monospace TextKit layout (multi-line; interior "\n"s) drawn inside a
/// plain, `tableHeader`-coloured band that spans its container's interior edge to edge, with the code
/// text at the paragraph inset of its nesting level. Mirrors `BlockBox` but is a distinct `Block.code`
/// type and builds its own monospace attributed string (so no `ParagraphStyleName`/StyleSheet change).
/// Inline formatting is not represented inside a code block — runs are plain.
@available(iOS 13.0, *)
final class CodeBlockBox {
    let id: BlockID
    var language: String?
    let layout: BlockLayoutEngine
    let mapper: AttributedStringMapper

    var frame: CGRect = .zero
    var globalStart: Int = 0
    /// Host placeholder strings (stamped by the canvas in `stampListMarkers`). Drives the empty-code hint.
    var placeholders: RichTextEditorPlaceholders = .default
    /// Monospace point size — matches the quote's 15pt so a code block reads at the same scale as a quote.
    static let fontSize: CGFloat = 15

    /// How far this block's BAND extends past its frame on each side, to reach the enclosing
    /// container's interior edges. GEOMETRIC sides (`minXSide` is always the smaller-x edge), matching
    /// the renderer's `InstantPageV2ChildBleed`. Assigned by the `BlockStack` that lays this box out,
    /// not at construction — it moves with the host's content margins while the box does not.
    var horizontalBleed: (minXSide: CGFloat, maxXSide: CGFloat) = (0, 0)

    /// The bold, lowercased language line, or nil. Sans + bold at the BODY size — the same derivation
    /// the quote author uses — so it cannot be set to something the renderer disagrees with.
    private(set) var languageLine: NSAttributedString?

    var topInset: CGFloat
    var bottomInset: CGFloat

    /// The monospace face code renders in. Extracted so the metrics-only readers (empty-line height)
    /// need no colour.
    static var codeFont: UIFont {
        UIFont.monospacedSystemFont(ofSize: CodeBlockBox.fontSize, weight: .regular)
    }

    /// `textColor` is REQUIRED, not defaulted: an attributed string with no `.foregroundColor` draws
    /// BLACK, which is invisible on a dark background — the bug this parameter exists to prevent.
    /// It is render-only and never reaches the model (`currentCode()` reads the plain string back).
    static func codeAttributes(textColor: UIColor) -> [NSAttributedString.Key: Any] {
        let ps = NSMutableParagraphStyle()
        ps.lineBreakMode = .byWordWrapping
        return [.font: codeFont,
                .paragraphStyle: ps,
                .foregroundColor: textColor]
    }

    static func attributedString(for code: CodeBlock, textColor: UIColor) -> NSAttributedString {
        NSAttributedString(string: code.text, attributes: codeAttributes(textColor: textColor))
    }

    /// The bold language line for `language`, or nil when absent/empty. Lowercased here, not at draw
    /// time, so the model's casing ("Swift", "SWIFT") cannot reach the screen — mirroring the
    /// renderer's `instantPageV2CodeLanguageDisplayText`.
    static func languageLine(for language: String?, mapper: AttributedStringMapper) -> NSAttributedString? {
        guard let language = language, !language.isEmpty else { return nil }
        let font = FontResolver.font(spec: mapper.styleSheet.metrics.body, bold: true, italic: false, family: nil)
        return NSAttributedString(string: language.lowercased(), attributes: [
            .font: font,
            .foregroundColor: mapper.theme.containerPlaceholder
        ])
    }

    init(code: CodeBlock, mapper: AttributedStringMapper, width: CGFloat) {
        self.id = code.id
        self.language = code.language
        self.mapper = mapper
        self.topInset = mapper.styleSheet.codeVerticalInset
        self.bottomInset = mapper.styleSheet.codeVerticalInset
        self.languageLine = CodeBlockBox.languageLine(for: code.language, mapper: mapper)
        // With no `codeHorizontalInset` the code text measures at the FULL content width — the same
        // measure a sibling paragraph gets, which is what makes the two align on both edges. A host
        // that indents the text inside its band narrows the measure by that inset on each side.
        self.layout = makeBlockLayout(
            attributedString: CodeBlockBox.attributedString(for: code, textColor: mapper.theme.primaryText),
            width: max(width - mapper.styleSheet.codeHorizontalInset * 2, 1))
    }

    var spacingKind: RichTextBlockSpacingKind { .preformatted }

    /// The band: the frame grown outward by the bleed. This is the block's full drawn extent, which
    /// `BlockBackingView` clips to — a bleed missing here renders as a band clipped to the text column.
    var blockViewFrame: CGRect {
        CGRect(x: frame.minX - horizontalBleed.minXSide, y: frame.minY,
               width: frame.width + horizontalBleed.minXSide + horizontalBleed.maxXSide,
               height: frame.height)
    }

    /// Extra inset of the code text inward from the band's edges (host knob; 0 by default, which is
    /// the renderer's rule — the text sits at the paragraph inset and the BAND bleeds outward past it).
    var horizontalInset: CGFloat { mapper.styleSheet.codeHorizontalInset }

    /// Height the language line occupies above the code, gap included. Zero when there is no language.
    var languageLineExtent: CGFloat {
        guard let line = languageLine else { return 0 }
        return ceil(line.size().height) + mapper.styleSheet.codeLanguageSpacing
    }

    var length: Int { layout.length }
    var textOrigin: CGPoint {
        CGPoint(x: frame.minX + horizontalInset, y: frame.minY + topInset + languageLineExtent)
    }

    private var emptyLineHeight: CGFloat {
        guard layout.length == 0 else { return 0 }
        return CodeBlockBox.codeFont.lineHeight
    }

    /// Placeholder text for an empty code block, or nil when non-empty or the placeholder string is empty.
    var placeholderText: String? {
        guard layout.length == 0, !placeholders.codeBlock.isEmpty else { return nil }
        return placeholders.codeBlock
    }

    func currentCode() -> CodeBlock {
        CodeBlock(id: id, language: language, runs: [TextRun(text: layout.attributedString.string)])
    }
}

@available(iOS 13.0, *)
extension CodeBlockBox: CanvasBlock {
    var rendersAsBlockView: Bool { true }
    var nodeStart: Int { get { globalStart } set { globalStart = newValue } }
    var nodeSize: Int { length + 2 }
    var textLayout: BlockLayoutEngine { layout }
    var textStart: Int { globalStart }
    var textLength: Int { length }
    var textRef: TextNodeRef { .code(id) }
    var height: CGFloat {
        max(layout.correctedBoundingHeight, emptyLineHeight) + languageLineExtent + topInset + bottomInset
    }
    func measuredHeight(forWidth width: CGFloat) -> CGFloat {
        max(layout.correctedBoundingHeight(forWidth: max(width - horizontalInset * 2, 1)), emptyLineHeight)
            + languageLineExtent + topInset + bottomInset
    }
    func setWidth(_ width: CGFloat) { layout.setWidth(max(width - horizontalInset * 2, 1)) }
    func currentBlock() -> Block { .code(currentCode()) }
    func closestPosition(toCanvasPoint point: CGPoint) -> Int {
        textStart + layout.closestOffset(toPoint: CGPoint(x: point.x - textOrigin.x, y: point.y - textOrigin.y))
    }
    func leafRegions() -> [LeafTextRegion] {
        [LeafTextRegion(layout: layout, globalStart: globalStart, length: length,
                        ref: .code(id), canvasOrigin: textOrigin,
                        emptyLineLeadingIndent: 0, emptyLineHeight: emptyLineHeight)]
    }
    func draw(in ctx: CGContext, imageProvider: (String) -> UIImage?) {
        // The band is painted HERE, not by the shared `BlockquoteUnderlay`: a code block is no longer
        // a quote variant, and putting the fill on the box is also what makes a NESTED code block
        // filled at all — the underlay's feed only ever walked top-level boxes.
        mapper.theme.codeBackground.setFill()
        let radius = mapper.styleSheet.codeCornerRadius
        if radius > 0 {
            // Explicit path on `ctx` rather than `UIBezierPath.fill()`, which draws into
            // `UIGraphicsGetCurrentContext()` — not necessarily this one (a table cell draws through
            // a translated context).
            ctx.addPath(UIBezierPath(roundedRect: blockViewFrame, cornerRadius: radius).cgPath)
            ctx.fillPath()
        } else {
            ctx.fill(blockViewFrame)
        }
        if let line = languageLine {
            line.draw(at: CGPoint(x: frame.minX + horizontalInset, y: frame.minY + topInset))
        }
        layout.drawText(in: ctx, at: textOrigin)
        if let ph = placeholderText {
            NSAttributedString(string: ph, attributes: [
                .font: CodeBlockBox.codeFont,
                .foregroundColor: mapper.theme.containerPlaceholder
            ]).draw(at: textOrigin)
        }
    }
}
#endif
