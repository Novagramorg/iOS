#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CanvasQuoteGeometryTests: XCTestCase {
    private let longQuote = "This is a fairly long single quoted paragraph that will wrap across multiple lines when the text container is narrowed by a large trailing inset value."

    private func canvasWithTrailing(_ trailing: CGFloat, width: CGFloat = 200) -> DocumentCanvasView {
        var qs = QuoteStyle.default; qs.trailingInset = trailing
        return canvas([.paragraph(ParagraphBlock(id: BlockID("q"), style: .quote, runs: [TextRun(text: longQuote)]))],
                      quoteStyle: qs, width: width)
    }

    private func canvas(_ blocks: [Block], quoteStyle: QuoteStyle = .default, width: CGFloat = 390) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.applyQuoteStyle(quoteStyle)
        v.setBlocks(blocks, width: width)
        v.frame = CGRect(x: 0, y: 0, width: width, height: 600); v.layoutIfNeeded()
        return v
    }

    func test_trailingInset_narrowsText_increasingHeight() {
        let tall = canvasWithTrailing(120).boxes[0].frame.height
        let base = canvasWithTrailing(0).boxes[0].frame.height
        XCTAssertGreaterThan(tall, base, "a large trailing inset narrows the quote text container, forcing more wrapped lines")
    }

    func test_barWidth_isConfigurable_inDecorations() {
        var qs = QuoteStyle.default
        qs.barWidth = 6
        let v = canvas([.paragraph(ParagraphBlock(id: BlockID("q"), style: .quote, runs: [TextRun(text: "Quote")]))], quoteStyle: qs)
        let decs = v.blockquoteDecorations()
        XCTAssertEqual(decs.count, 1)
        XCTAssertEqual(decs[0].bar.width, 6, accuracy: 0.5)
    }

    func test_default_barWidth_unchanged() {
        let v = canvas([.paragraph(ParagraphBlock(id: BlockID("q"), style: .quote, runs: [TextRun(text: "Quote")]))])
        XCTAssertEqual(v.blockquoteDecorations()[0].bar.width, 3, accuracy: 0.5)
    }

    func test_applyQuoteStyle_preservesTheme() {
        let v = DocumentCanvasView()
        var theme = RichTextEditorTheme.default
        theme.accent = .magenta
        v.applyTheme(theme)
        v.applyQuoteStyle(.default)   // must NOT reset the theme
        XCTAssertEqual(v.mapper.theme.accent, .magenta)
    }

    func test_facade_quoteStyle_roundTrips() {
        let view = RichTextEditorView(frame: .zero)
        var qs = QuoteStyle.default
        qs.leadingInset = 9
        view.quoteStyle = qs
        XCTAssertEqual(view.quoteStyle.leadingInset, 9, accuracy: 0.01)
    }
}
#endif
