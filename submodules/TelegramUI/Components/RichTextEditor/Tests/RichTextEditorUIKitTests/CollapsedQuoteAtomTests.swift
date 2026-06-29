#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// A collapsed quote should behave like an image block for caret + selection: arrow-nav stops on its leading
/// gap (not skipping it), the caret there is drawable at the left edge (not hidden), and a range selection
/// covers it.
final class CollapsedQuoteAtomTests: XCTestCase {
    private func canvas(_ blocks: [Block], width: CGFloat = 300) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks(blocks, width: width)
        v.frame = CGRect(x: 0, y: 0, width: width, height: 600); v.layoutIfNeeded()
        v.simulateParentLayout()
        return v
    }
    private func collapsed(_ id: String, _ t: String) -> Block {
        .collapsedQuote(CollapsedQuote(id: BlockID(id), paragraphs: [ParagraphBlock(id: BlockID(id + "p"), style: .quote, runs: [TextRun(text: t)])]))
    }
    private func body(_ id: String, _ t: String) -> Block { .paragraph(ParagraphBlock(id: BlockID(id), style: .body, runs: [TextRun(text: t)])) }

    func test_arrowNav_stopsOnCollapsedGap_bothDirections() {
        let v = canvas([body("a", "A"), collapsed("q", "one"), body("b", "B")])
        let gap = v.boxes[1].nodeStart
        let aEnd = v.boxes[0].textStart + v.boxes[0].textLength
        let bStart = v.boxes[2].textStart
        // RIGHT: end of "A" → gap → start of "B"
        XCTAssertEqual(v.nextTextPosition(after: aEnd), gap)
        XCTAssertEqual(v.nextTextPosition(after: gap), bStart)
        // LEFT: start of "B" → gap → end of "A"
        XCTAssertEqual(v.prevTextPosition(before: bStart), gap)
        XCTAssertEqual(v.prevTextPosition(before: gap), aEnd)
    }

    func test_caretOnGap_isDrawableAtLeftEdge_notHidden() {
        let v = canvas([body("a", "A"), collapsed("q", "one")])
        let cq = v.boxes[1]
        let placement = v.caretHostPlacement(forGlobal: cq.nodeStart)
        XCTAssertNotNil(placement, "caret on the collapsed gap must have a placement (not hidden)")
        if let p = placement {
            XCTAssertEqual(p.frame.minX, cq.frame.minX, accuracy: 0.5, "caret bar sits at the quote's left edge")
            XCTAssertTrue(p.frame.height > 0)
        }
        // caretRect agrees (feeds the OS caret / loupe)
        let rect = v.caretRect(for: DocumentTextPosition(cq.nodeStart))
        XCTAssertEqual(rect.minX, cq.frame.minX, accuracy: 0.5)
        XCTAssertTrue(rect.height > 0)
    }

    // Vertical nav must be able to step THROUGH the collapsed quote's gap. The gap owns no leaf region, so
    // `verticalPosition` used to return it unchanged — a 2-line move stalled on the gap (offset:2 == offset:1),
    // the OS read "no progress" and fell back to its own geometry, skipping the quote (the intermittent
    // "Up/Down jumps over the collapsed quote" bug, device-log confirmed).
    func test_verticalNav_stepsThroughCollapsedGap_notStuck() {
        let v = canvas([body("a", "A"), collapsed("q", "one"), body("b", "B")])
        let gap = v.boxes[1].nodeStart
        let aEnd = v.boxes[0].textStart + v.boxes[0].textLength
        let bStart = v.boxes[2].textStart
        let bEnd = v.boxes[2].textStart + v.boxes[2].textLength
        // From the gap itself, vertical nav must step OFF it (not return the gap unchanged).
        XCTAssertEqual(v.verticalPosition(from: gap, down: true), bStart, "Down from the gap → start of the block after")
        XCTAssertEqual(v.verticalPosition(from: gap, down: false), aEnd, "Up from the gap → end of the block above")
        // A 2-line move across the gap (the OS's offset:2 probe) must reach the far block, not stall on the gap.
        let up2 = (v.position(from: DocumentTextPosition(bEnd), in: .up, offset: 2) as? DocumentTextPosition)?.offset
        XCTAssertNotEqual(up2, gap, "Up 2 lines from the block below must move PAST the gap, not stall on it")
        let down2 = (v.position(from: DocumentTextPosition(v.boxes[0].textStart), in: .down, offset: 2) as? DocumentTextPosition)?.offset
        XCTAssertNotEqual(down2, gap, "Down 2 lines from the block above must move PAST the gap, not stall on it")
    }

    func test_rangeSelection_coversCollapsedQuote() {
        let v = canvas([body("a", "A"), collapsed("q", "one"), body("b", "B")])
        let cq = v.boxes[1]
        // select from the start of "A" to the end of "B" (covers the whole document incl. the collapsed quote)
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(v.boxes[0].textStart),
                                                DocumentTextPosition(v.boxes[2].textStart + v.boxes[2].textLength))
        // the collapsed quote falls inside the covered range → it is washed (same predicate the highlight draw uses)
        XCTAssertLessThanOrEqual(v.selFrom, cq.nodeStart)
        XCTAssertGreaterThanOrEqual(v.selTo, v.coverableContentEnd(cq))
    }
}
#endif
