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

    var frame: CGRect = .zero
    var globalStart: Int = 0

    /// Interior horizontal padding (each side). The fill spans full width; text is inset by this.
    static let horizontalPadding: CGFloat = 12
    /// Interior vertical padding (top and bottom). The fill spans full height; text is inset by this.
    static let verticalPadding: CGFloat = 8

    var leftInset: CGFloat { PullQuoteBox.horizontalPadding }
    var rightInset: CGFloat { PullQuoteBox.horizontalPadding }
    var topInset: CGFloat = PullQuoteBox.verticalPadding
    var bottomInset: CGFloat = PullQuoteBox.verticalPadding

    init(pullQuote: PullQuote, mapper: AttributedStringMapper, width: CGFloat) {
        self.id = pullQuote.id
        self.mapper = mapper
        self.layout = makeBlockLayout(
            attributedString: mapper.attributedString(for: ParagraphBlock(id: pullQuote.id, style: .pullQuote, runs: pullQuote.runs)),
            width: max(width - PullQuoteBox.horizontalPadding - PullQuoteBox.horizontalPadding, 1))
    }

    var length: Int { layout.length }
    var textOrigin: CGPoint { CGPoint(x: frame.minX + leftInset, y: frame.minY + topInset) }

    private var emptyLineHeight: CGFloat {
        guard layout.length == 0 else { return 0 }
        return mapper.styleSheet.font(for: .pullQuote, attributes: CharacterAttributes()).lineHeight
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
    }
}
#endif
