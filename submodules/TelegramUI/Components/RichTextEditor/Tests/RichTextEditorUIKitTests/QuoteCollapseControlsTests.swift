#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class QuoteCollapseControlsTests: XCTestCase {
    private func canvas(_ blocks: [Block], width: CGFloat = 300) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks(blocks, width: width)
        v.frame = CGRect(x: 0, y: 0, width: width, height: 2000); v.layoutIfNeeded()
        return v
    }
    private func quote(_ id: String, _ t: String) -> Block { .paragraph(ParagraphBlock(id: BlockID(id), style: .quote, runs: [TextRun(text: t)])) }
    private func body(_ id: String, _ t: String) -> Block { .paragraph(ParagraphBlock(id: BlockID(id), style: .body, runs: [TextRun(text: t)])) }
    private func collapsed(_ id: String) -> Block {
        .collapsedQuote(CollapsedQuote(id: BlockID(id), paragraphs: [ParagraphBlock(id: BlockID(id + "p"), style: .quote, runs: [TextRun(text: "x")])]))
    }

    // MARK: - collapseButtonRuns

    func test_tallExpandedQuoteRun_offersCollapseButton() {
        let long = String(repeating: "wrap this text across many lines ", count: 12)
        let v = canvas([quote("q", long)])
        let runs = v.collapseButtonRuns()
        XCTAssertEqual(runs.count, 1)
        XCTAssertEqual(runs[0].blockIndex, 0)
    }

    func test_shortExpandedQuoteRun_offersNoCollapseButton() {
        let v = canvas([quote("q", "short")])
        XCTAssertTrue(v.collapseButtonRuns().isEmpty)
    }

    func test_collapsedQuote_offersNoCollapseButton() {
        let v = canvas([collapsed("q")])
        XCTAssertTrue(v.collapseButtonRuns().isEmpty)
    }

    // MARK: - tap-to-expand

    func test_tapExpandGlyph_expandsCollapsedQuote() {
        let v = canvas([collapsed("q")])
        let box = try! XCTUnwrap(v.boxes.first as? CollapsedQuoteBox)
        let g = box.expandGlyphRect()
        v.performSingleTapForTesting(at: CGPoint(x: g.midX, y: g.midY))
        XCTAssertTrue(v.boxes.first is BlockBox, "tapping the expand glyph unfolds the collapsed quote")
    }

    func test_tapBodyOfCollapsedQuote_placesCaretAtGap_doesNotExpand() {
        let v = canvas([collapsed("q")])
        let box = try! XCTUnwrap(v.boxes.first as? CollapsedQuoteBox)
        // tap the LEADING edge area (away from the corner expand glyph)
        v.performSingleTapForTesting(at: CGPoint(x: box.frame.minX + 4, y: box.frame.midY))
        XCTAssertTrue(v.boxes.first is CollapsedQuoteBox, "tapping the body must NOT expand")
        XCTAssertEqual(v.head, box.nodeStart, "the caret is placed at the collapsed quote's gap")
        XCTAssertTrue(v.isRenderablePosition(v.head))
    }

    // MARK: - backspace on collapsed-quote atom

    func test_backspaceAtCollapsedQuoteGap_leadingQuote_expandsIt() {
        let v = canvas([collapsed("q")])
        let box = try! XCTUnwrap(v.boxes.first as? CollapsedQuoteBox)
        // Park the caret at the atom's gap (the position a tap/nav lands on). A LEADING collapsed quote has
        // nothing before it to receive the Backspace, so it expands.
        v.anchor = box.nodeStart; v.head = box.nodeStart
        v.deleteBackward()
        XCTAssertTrue(v.boxes.first is BlockBox, "backspace at a leading collapsed-quote gap should expand it")
    }

    func test_backspaceAtCollapsedQuoteGap_withPreviousParagraph_deletesIntoIt_keepsQuoteCollapsed() {
        let v = canvas([body("p", "hello"), collapsed("q")])
        let box = try! XCTUnwrap(v.boxes.last as? CollapsedQuoteBox)
        // Caret at the collapsed quote's leading gap, with a paragraph before it.
        v.anchor = box.nodeStart; v.head = box.nodeStart
        v.deleteBackward()
        // The quote stays collapsed; the PREVIOUS paragraph received the backspace (lost its last char); the
        // caret is now in that paragraph.
        XCTAssertTrue(v.boxes.last is CollapsedQuoteBox, "the collapsed quote must stay collapsed")
        guard case let .paragraph(p) = v.boxes[0].currentBlock() else { return XCTFail("expected the previous paragraph") }
        XCTAssertEqual(p.text, "hell", "the previous paragraph received the backspace")
        XCTAssertEqual(v.head, v.boxes[0].textStart + v.boxes[0].textLength, "caret is at the end of the previous paragraph")
    }

    func test_backspaceAtCollapsedQuoteGap_emptyPreviousParagraph_removesIt_caretStaysOnGap() {
        let v = canvas([body("p", ""), collapsed("q")])   // empty paragraph, then collapsed quote
        let box = try! XCTUnwrap(v.boxes.last as? CollapsedQuoteBox)
        v.anchor = box.nodeStart; v.head = box.nodeStart  // caret on the quote's gap
        v.deleteBackward()
        // The empty paragraph is removed; the collapsed quote remains (now the only/first block); caret on its gap.
        XCTAssertEqual(v.boxes.count, 1, "the empty previous paragraph is removed")
        let cq = try! XCTUnwrap(v.boxes.first as? CollapsedQuoteBox)
        XCTAssertEqual(v.head, cq.nodeStart, "caret stays on the (now-first) collapsed quote's gap")
    }

    func test_backspaceAtCollapsedQuoteGap_emptyMiddleParagraph_removesIt_keepsBlocksBeforeAndQuote() {
        let v = canvas([body("a", "A"), body("e", ""), collapsed("q")])
        let box = try! XCTUnwrap(v.boxes.last as? CollapsedQuoteBox)
        v.anchor = box.nodeStart; v.head = box.nodeStart
        v.deleteBackward()
        XCTAssertEqual(v.boxes.count, 2, "the empty middle paragraph is removed; A + collapsed quote remain")
        XCTAssertTrue(v.boxes[0] is BlockBox && v.boxes[1] is CollapsedQuoteBox)
        let cq = try! XCTUnwrap(v.boxes.last as? CollapsedQuoteBox)
        XCTAssertEqual(v.head, cq.nodeStart, "caret stays on the collapsed quote's gap")
        guard case let .paragraph(p) = v.boxes[0].currentBlock() else { return XCTFail("expected paragraph A") }
        XCTAssertEqual(p.text, "A", "the block before the empty paragraph is untouched")
    }

    /// The ACTUAL runtime trigger (device-log confirmed): iOS overrides the caret-on-gap to an object-replacement
    /// RANGE anchored at the previous block's end (anchor=prevEnd, head=gap) right before Backspace. This must
    /// still act on the previous paragraph, NOT delete the quote (the bug where `applySelectionReplace` removed it).
    func test_backspaceObjectReplacementRangeAtGap_deletesIntoPreviousParagraph_keepsQuoteCollapsed() {
        let v = canvas([body("p", "hello"), collapsed("q")])
        let box = try! XCTUnwrap(v.boxes.last as? CollapsedQuoteBox)
        let prevEnd = v.boxes[0].textStart + v.boxes[0].textLength
        v.anchor = prevEnd; v.head = box.nodeStart    // range [prevEnd, gap] — mirrors the device log (anchor=2 head=4)
        v.deleteBackward()
        XCTAssertTrue(v.boxes.last is CollapsedQuoteBox, "the collapsed quote must stay collapsed (not removed by the range delete)")
        guard case let .paragraph(p) = v.boxes[0].currentBlock() else { return XCTFail("expected the previous paragraph") }
        XCTAssertEqual(p.text, "hell", "the previous paragraph received the backspace, not the quote")
    }

    // MARK: - coverableContentEnd arm

    func test_coverableContentEnd_collapsedQuote_returnsNodeStartPlusOne() {
        let v = canvas([collapsed("q")])
        let box = try! XCTUnwrap(v.boxes.first as? CollapsedQuoteBox)
        XCTAssertEqual(v.coverableContentEnd(box), box.nodeStart + 1,
                       "a collapsed quote's coverable end is nodeStart+1, like an audio atom")
    }

    /// Select-All + Backspace on a [para, collapsed] document removes the collapsed quote.
    /// This exercises the cross-block delete path where the collapsed quote is the trailing endpoint.
    func test_selectAllDelete_removesCollapsedQuoteAtEnd() {
        let v = canvas([body("b", "hello"), collapsed("q")])
        // Select the full document and delete.
        v.anchor = 0; v.head = v.documentSizeValue
        v.deleteBackward()
        // The collapsed quote should be gone; only the (now-empty) para remains.
        XCTAssertEqual(v.boxes.count, 1, "collapsed quote should be removed by the cross-block delete")
        XCTAssertTrue(v.boxes.first is BlockBox)
    }
}
#endif
