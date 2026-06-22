#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// One code block in the canvas: a monospace TextKit layout (multi-line; interior "\n"s) drawn inside a
/// filled rounded-rect background with an optional language label. Mirrors `BlockBox` but is a distinct
/// `Block.code` type and builds its own monospace attributed string (so no `ParagraphStyleName`/StyleSheet
/// change). Inline formatting is not represented inside a code block — runs are plain.
@available(iOS 13.0, *)
final class CodeBlockBox {
    let id: BlockID
    var language: String?
    let layout: BlockLayoutEngine
    let mapper: AttributedStringMapper

    var frame: CGRect = .zero
    var globalStart: Int = 0
    static let verticalInset: CGFloat = 8
    static let horizontalPadding: CGFloat = 8       // interior left/right padding inside the fill
    let textInset = CGPoint(x: CodeBlockBox.horizontalPadding, y: CodeBlockBox.verticalInset)
    var topInset: CGFloat = CodeBlockBox.verticalInset
    var bottomInset: CGFloat = CodeBlockBox.verticalInset

    static func codeAttributes() -> [NSAttributedString.Key: Any] {
        let ps = NSMutableParagraphStyle()
        ps.lineBreakMode = .byWordWrapping
        return [.font: UIFont.monospacedSystemFont(ofSize: 16, weight: .regular),
                .paragraphStyle: ps]
    }

    static func attributedString(for code: CodeBlock) -> NSAttributedString {
        NSAttributedString(string: code.text, attributes: codeAttributes())
    }

    init(code: CodeBlock, mapper: AttributedStringMapper, width: CGFloat) {
        self.id = code.id
        self.language = code.language
        self.mapper = mapper
        self.layout = makeBlockLayout(attributedString: CodeBlockBox.attributedString(for: code),
                                      width: max(width - CodeBlockBox.horizontalPadding * 2, 1))
    }

    var length: Int { layout.length }
    var textOrigin: CGPoint { CGPoint(x: frame.minX + textInset.x, y: frame.minY + topInset) }

    private var emptyLineHeight: CGFloat {
        guard layout.length == 0 else { return 0 }
        return ((CodeBlockBox.codeAttributes()[.font] as? UIFont) ?? UIFont.monospacedSystemFont(ofSize: 16, weight: .regular)).lineHeight
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
    var height: CGFloat { max(layout.boundingHeight, emptyLineHeight) + topInset + bottomInset }
    func measuredHeight(forWidth width: CGFloat) -> CGFloat {
        max(layout.boundingHeight(forWidth: max(width - CodeBlockBox.horizontalPadding * 2, 1)), emptyLineHeight) + topInset + bottomInset
    }
    func setWidth(_ width: CGFloat) { layout.setWidth(max(width - CodeBlockBox.horizontalPadding * 2, 1)) }
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
        let fill = mapper.theme.codeBackground
        let bg = UIBezierPath(roundedRect: frame.insetBy(dx: 0, dy: 2), cornerRadius: 6)
        ctx.saveGState(); ctx.addPath(bg.cgPath); ctx.setFillColor(fill.cgColor); ctx.fillPath(); ctx.restoreGState()
        layout.drawText(in: ctx, at: textOrigin)
        if let lang = language, !lang.isEmpty {
            NSAttributedString(string: lang, attributes: [
                .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                .foregroundColor: mapper.theme.placeholder
            ]).draw(at: CGPoint(x: frame.maxX - 8 - 40, y: frame.minY + 2))
        }
    }
}
#endif
