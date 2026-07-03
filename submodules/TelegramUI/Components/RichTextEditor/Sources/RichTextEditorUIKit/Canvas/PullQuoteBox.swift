#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// One pull-quote block in the canvas: a rich TextKit layout (centered, forced-italic) drawn inside a
/// box with symmetric horizontal and vertical padding. Mirrors `CodeBlockBox` but builds its attributed
/// string via the mapper (rich runs + forced italic/center) instead of a plain monospace string. The
/// pill background + corner marks are added by later tasks via the decorations layer — this box only
/// lays out and draws the (centered, italic) text.
@available(iOS 13.0, *)
final class PullQuoteBox {
    let id: BlockID
    let layout: BlockLayoutEngine
    let mapper: AttributedStringMapper
    let pullQuoteStyle: PullQuoteStyle

    var frame: CGRect = .zero
    var globalStart: Int = 0
    /// Placeholder strings stamped by the canvas in `stampListMarkers()`. Drives the centered
    /// "Type a quote here" hint and the empty-state pill width.
    var placeholders: RichTextEditorPlaceholders = .default

    var leftInset: CGFloat { pullQuoteStyle.horizontalPadding }
    var rightInset: CGFloat { pullQuoteStyle.horizontalPadding }
    var topInset: CGFloat
    var bottomInset: CGFloat

    init(pullQuote: PullQuote, mapper: AttributedStringMapper, pullQuoteStyle: PullQuoteStyle = .default, width: CGFloat) {
        self.id = pullQuote.id
        self.mapper = mapper
        self.pullQuoteStyle = pullQuoteStyle
        self.topInset = pullQuoteStyle.verticalPadding
        self.bottomInset = pullQuoteStyle.verticalPadding
        self.layout = makeBlockLayout(
            attributedString: mapper.attributedString(for: ParagraphBlock(id: pullQuote.id, style: .pullQuote, runs: pullQuote.runs)),
            width: max(width - pullQuoteStyle.horizontalPadding - pullQuoteStyle.horizontalPadding, 1))
    }

    var length: Int { layout.length }
    var textOrigin: CGPoint { CGPoint(x: frame.minX + leftInset, y: frame.minY + topInset) }

    /// Placeholder text for an empty pull quote, or nil when non-empty or placeholder string is empty.
    var placeholderText: String? {
        guard layout.length == 0, !placeholders.pullQuote.isEmpty else { return nil }
        return placeholders.pullQuote
    }

    /// Widest laid-out line width (glyph-hugging), for the content-hugging pill. When empty, returns
    /// the placeholder's measured width so the pill hugs it (floored by the Task-10 minWidth).
    var contentWidth: CGFloat {
        if length == 0 {
            guard let ph = placeholderText else { return 0 }
            let font = mapper.styleSheet.font(for: .pullQuote, attributes: .plain)
            return (ph as NSString).size(withAttributes: [.font: font]).width
        }
        return layout.selectionRects(start: 0, end: length).map(\.width).max() ?? 0
    }

    private var emptyLineHeight: CGFloat {
        guard layout.length == 0 else { return 0 }
        return mapper.styleSheet.font(for: .pullQuote, attributes: CharacterAttributes()).lineHeight
    }

    /// Attributes for text typed into a pull quote (italic + centered paragraph style). Used by
    /// `typingAttributeDict` and `insertPullQuoteNewline` so the first character typed into an
    /// empty pull quote is italic/centered, not body-upright-left.
    static func pullQuoteTypingAttributes(_ mapper: AttributedStringMapper) -> [NSAttributedString.Key: Any] {
        let probe = mapper.attributedString(for: ParagraphBlock(id: BlockID("pq-typing"), style: .pullQuote,
                                                                runs: [TextRun(text: " ")]))
        return probe.attributes(at: 0, effectiveRange: nil)
    }
}

@available(iOS 13.0, *)
extension PullQuoteBox: CanvasBlock {
    var rendersAsBlockView: Bool { true }
    var nodeStart: Int { get { globalStart } set { globalStart = newValue } }
    var nodeSize: Int { length + 2 }
    var textLayout: BlockLayoutEngine { layout }
    var textStart: Int { globalStart }
    var textLength: Int { length }
    var textRef: TextNodeRef { .pullQuote(id) }
    var height: CGFloat { max(layout.boundingHeight, emptyLineHeight) + topInset + bottomInset }
    func measuredHeight(forWidth width: CGFloat) -> CGFloat {
        max(layout.boundingHeight(forWidth: max(width - leftInset - rightInset, 1)), emptyLineHeight) + topInset + bottomInset
    }
    func setWidth(_ width: CGFloat) { layout.setWidth(max(width - leftInset - rightInset, 1)) }
    func currentBlock() -> Block {
        .pullQuote(PullQuote(id: id, runs: mapper.runs(from: layout.attributedString, style: .pullQuote)))
    }
    func closestPosition(toCanvasPoint point: CGPoint) -> Int {
        textStart + layout.closestOffset(toPoint: CGPoint(x: point.x - textOrigin.x, y: point.y - textOrigin.y))
    }
    func leafRegions() -> [LeafTextRegion] {
        [LeafTextRegion(layout: layout, globalStart: globalStart, length: length,
                        ref: .pullQuote(id), canvasOrigin: textOrigin,
                        emptyLineLeadingIndent: 0, emptyLineHeight: emptyLineHeight)]
    }
    func draw(in ctx: CGContext, imageProvider: (String) -> UIImage?) {
        // The pill background + corner marks are added by later tasks via the decorations layer.
        // This box draws only the (centered, italic) text.
        layout.drawText(in: ctx, at: textOrigin)
        if let ph = placeholderText {
            let font = mapper.styleSheet.font(for: .pullQuote, attributes: .plain)
            let ps = NSMutableParagraphStyle(); ps.alignment = .center
            let rect = CGRect(x: frame.minX + leftInset, y: textOrigin.y,
                              width: max(frame.width - leftInset - rightInset, 1), height: frame.height - topInset - bottomInset)
            NSAttributedString(string: ph, attributes: [.font: font, .foregroundColor: mapper.theme.placeholder,
                                                        .paragraphStyle: ps]).draw(in: rect)
        }
    }
}
#endif
