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

    private func listItem(_ id: String, _ t: String, style: ParagraphStyleName = .body) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), style: style,
                                  list: ListMembership(marker: .bullet), runs: [TextRun(text: t)]))
    }
    private func code(_ id: String, _ t: String) -> Block {
        .code(CodeBlock(id: BlockID(id), language: nil, runs: [TextRun(text: t)]))
    }

    func test_plainListItem_adjacentToQuotedListItem_reservesFramedSeparation() {
        // A plain list item next to a QUOTED list item (a list inside a quote) must NOT stack tight like
        // two items of the same list: the quote is a separate container, so the plain item reserves the
        // framed neighbor margin (base 8 + framed 8) and there is a visible gap before the quote fill.
        let v = canvas([listItem("l", "plain"), listItem("q", "quoted", style: .quote)])
        let l = v.boxes[0] as! BlockBox
        let q = v.boxes[1] as! BlockBox
        XCTAssertEqual(l.bottomInset, 16, accuracy: 0.01, "plain list item reserves framed margin facing the quote")
        XCTAssertGreaterThan(l.bottomInset + q.topInset, 0, "there must be a visible gap between the list and the quote")
    }

    func test_sameListItems_stillStackTight() {
        // Guard: two items of the SAME list (same container) keep stacking tight (0 facing inset).
        let v = canvas([listItem("a", "one"), listItem("b", "two")])
        let a = v.boxes[0] as! BlockBox
        let b = v.boxes[1] as! BlockBox
        XCTAssertEqual(a.bottomInset, 0, accuracy: 0.01)
        XCTAssertEqual(b.topInset, 0, accuracy: 0.01)
    }

    func test_twoAdjacentCodeBlocks_haveExternalSeparation() {
        // Two code blocks each fill their whole frame, so their internal padding can't separate the two
        // fills — the layout must insert an external gap (base 8 + framed 8) between them.
        let v = canvas([code("c1", "a"), code("c2", "b")])
        let c1 = v.boxes[0], c2 = v.boxes[1]
        XCTAssertEqual(c2.frame.minY - c1.frame.maxY, 16, accuracy: 0.01,
                       "two code-block fills must be separated by the framed neighbor margin")
    }

    func test_codeBlock_adjacentToBody_unchangedSeparation() {
        // Guard: a code block next to body text keeps its existing separation (the body reserves the
        // framed margin; no extra bare gap is inserted, since only the body–code pairing applies).
        let v = canvas([body("a", "x"), code("c", "code"), body("b", "y")])
        let a = v.boxes[0], c = v.boxes[1], b = v.boxes[2]
        XCTAssertEqual(c.frame.minY - a.frame.maxY, 0, accuracy: 0.01, "no bare gap between body and code")
        XCTAssertEqual(b.frame.minY - c.frame.maxY, 0, accuracy: 0.01, "no bare gap between code and body")
    }
}
#endif
