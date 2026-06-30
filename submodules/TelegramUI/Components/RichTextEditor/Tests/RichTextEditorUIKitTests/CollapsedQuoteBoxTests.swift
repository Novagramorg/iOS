#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CollapsedQuoteBoxTests: XCTestCase {
    private func quotePara(_ id: String, _ text: String) -> ParagraphBlock {
        ParagraphBlock(id: BlockID(id), style: .quote, runs: [TextRun(text: text)])
    }
    private func canvas(_ blocks: [Block], width: CGFloat = 300) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks(blocks, width: width)
        v.frame = CGRect(x: 0, y: 0, width: width, height: 600); v.layoutIfNeeded()
        return v
    }

    func test_collapsedQuote_isAtom_zeroTextLength_noLeafRegions() {
        let v = canvas([.collapsedQuote(CollapsedQuote(id: BlockID("q"), paragraphs: [quotePara("a", "hello")]))])
        let box = try! XCTUnwrap(v.boxes.first as? CollapsedQuoteBox)
        XCTAssertEqual(box.nodeSize, 3)
        XCTAssertEqual(box.textLength, 0)
        XCTAssertTrue(box.leafRegions().isEmpty)
        XCTAssertEqual(box.textStart, box.nodeStart)
    }

    func test_collapsedQuote_isNonParagraphAtom() {
        let v = canvas([.collapsedQuote(CollapsedQuote(id: BlockID("q"), paragraphs: [quotePara("a", "hi")]))])
        XCTAssertTrue(v.isNonParagraphAtom(v.boxes[0]))
    }

    func test_collapsedQuote_hasBlockquoteDecorationRun() {
        let v = canvas([.collapsedQuote(CollapsedQuote(id: BlockID("q"), paragraphs: [quotePara("a", "hi")]))])
        let decs = v.blockquoteDecorations()
        XCTAssertEqual(decs.count, 1, "the underlay paints the collapsed quote's bar+fill")
        XCTAssertEqual(decs[0].bar.width, v.quoteStyle.barWidth, accuracy: 0.5)
    }

    func test_collapsedQuote_currentBlock_roundTrips() {
        let cq = CollapsedQuote(id: BlockID("q"), paragraphs: [quotePara("a", "hi")])
        let v = canvas([.collapsedQuote(cq)])
        guard case let .collapsedQuote(back) = v.boxes[0].currentBlock() else { return XCTFail("not a collapsedQuote") }
        XCTAssertEqual(back, cq)
    }
}
#endif
