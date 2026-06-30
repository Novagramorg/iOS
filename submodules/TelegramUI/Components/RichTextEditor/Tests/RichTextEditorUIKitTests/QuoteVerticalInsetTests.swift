#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class QuoteVerticalInsetTests: XCTestCase {
    func test_quoteStyle_verticalInsets_defaultNil() {
        XCTAssertNil(QuoteStyle.default.topInset)
        XCTAssertNil(QuoteStyle.default.bottomInset)
        XCTAssertNil(StyleSheet().quoteTopInset)
        XCTAssertNil(StyleSheet().quoteBottomInset)
    }

    func test_applyQuoteStyle_mapsVerticalInsetsIntoStylesheet() {
        let v = DocumentCanvasView()
        v.applyQuoteStyle(QuoteStyle(topInset: 5, bottomInset: 7))
        XCTAssertEqual(v.mapper.styleSheet.quoteTopInset, 5)
        XCTAssertEqual(v.mapper.styleSheet.quoteBottomInset, 7)
    }

    // MARK: BlockStack layout override

    private func canvas(_ blocks: [Block], quoteStyle: QuoteStyle = .default,
                        width: CGFloat = 300) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.applyQuoteStyle(quoteStyle)               // set the mapper BEFORE seeding so boxes carry it
        v.setBlocks(blocks, width: width)
        v.frame = CGRect(x: 0, y: 0, width: width, height: 600)
        v.layoutIfNeeded()
        return v
    }
    private func quote(_ id: String, _ t: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), style: .quote, runs: [TextRun(text: t)]))
    }
    private func body(_ id: String, _ t: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), style: .body, runs: [TextRun(text: t)]))
    }

    func test_topLevelQuote_appliesVerticalInsetOverride() {
        let v = canvas([body("a", "x"), quote("q", "hi"), body("b", "y")],
                       quoteStyle: QuoteStyle(topInset: 10, bottomInset: 12))
        let q = v.boxes[1] as! BlockBox
        XCTAssertEqual(q.topInset, 10, accuracy: 0.01)
        XCTAssertEqual(q.bottomInset, 12, accuracy: 0.01)
        // The body above keeps its facingInset-derived inset (base + framedNeighborMargin facing a quote).
        let a = v.boxes[0] as! BlockBox
        XCTAssertEqual(a.bottomInset, 16, accuracy: 0.01)
    }

    func test_quote_nilVerticalInset_keepsBlockInsetBehavior() {
        let v = canvas([body("a", "x"), quote("q", "hi"), body("b", "y")])   // default: nil insets
        let q = v.boxes[1] as! BlockBox
        XCTAssertEqual(q.topInset, 8, accuracy: 0.01, "nil → facingInset base (verticalInsetBase 8)")
        XCTAssertEqual(q.bottomInset, 8, accuracy: 0.01)
    }

    func test_quoteRun_overrideAppliesOnlyAtRunBoundaries() {
        let v = canvas([quote("q1", "one"), quote("q2", "two")],
                       quoteStyle: QuoteStyle(topInset: 10, bottomInset: 12))
        let q1 = v.boxes[0] as! BlockBox
        let q2 = v.boxes[1] as! BlockBox
        XCTAssertEqual(q1.topInset, 10, accuracy: 0.01, "run top gets the override")
        XCTAssertEqual(q2.bottomInset, 12, accuracy: 0.01, "run bottom gets the override")
        XCTAssertEqual(q1.bottomInset, 8, accuracy: 0.01, "interior quote↔quote keeps base")
        XCTAssertEqual(q2.topInset, 8, accuracy: 0.01, "interior quote↔quote keeps base")
    }
}
#endif
