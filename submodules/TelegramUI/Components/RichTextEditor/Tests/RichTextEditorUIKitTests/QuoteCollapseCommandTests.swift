#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class QuoteCollapseCommandTests: XCTestCase {
    private func canvas(_ blocks: [Block], width: CGFloat = 300) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks(blocks, width: width)
        v.frame = CGRect(x: 0, y: 0, width: width, height: 600); v.layoutIfNeeded()
        return v
    }
    private func quote(_ id: String, _ t: String) -> Block { .paragraph(ParagraphBlock(id: BlockID(id), style: .quote, runs: [TextRun(text: t)])) }
    private func body(_ id: String, _ t: String) -> Block { .paragraph(ParagraphBlock(id: BlockID(id), style: .body, runs: [TextRun(text: t)])) }
    private func blocks(_ v: DocumentCanvasView) -> [Block] { v.boxes.map { $0.currentBlock() } }

    func test_collapseQuoteRun_foldsConsecutiveQuotesIntoOneAtom() {
        let v = canvas([body("t", "x"), quote("q1", "one"), quote("q2", "two"), body("b", "y")])
        v.collapseQuoteRun(atIndex: 1)
        let bs = blocks(v)
        XCTAssertEqual(bs.count, 3)
        guard case let .collapsedQuote(cq) = bs[1] else { return XCTFail("expected a collapsed quote at index 1") }
        XCTAssertEqual(cq.paragraphs.map(\.text), ["one", "two"])
        XCTAssertEqual(bs[0].id, BlockID("t")); XCTAssertEqual(bs[2].id, BlockID("b"))
    }

    func test_expandCollapsedQuote_restoresQuoteParagraphs() {
        let cq = CollapsedQuote(id: BlockID("q"), paragraphs: [
            ParagraphBlock(id: BlockID("q1"), style: .quote, runs: [TextRun(text: "one")]),
            ParagraphBlock(id: BlockID("q2"), style: .quote, runs: [TextRun(text: "two")]),
        ])
        let v = canvas([.collapsedQuote(cq)])
        v.expandCollapsedQuote(atIndex: 0)
        let bs = blocks(v)
        XCTAssertEqual(bs.count, 2)
        for b in bs { guard case let .paragraph(p) = b else { return XCTFail("expected paragraphs") }; XCTAssertEqual(p.style, .quote) }
        XCTAssertEqual(bs.map { (try? XCTUnwrap(($0)).id) }.compactMap { $0 }, [BlockID("q1"), BlockID("q2")])
    }

    func test_collapseThenExpand_roundTripsContentAndStyles() {
        let v = canvas([quote("q1", "one"), quote("q2", "two")])
        v.collapseQuoteRun(atIndex: 0)
        v.expandCollapsedQuote(atIndex: 0)
        let bs = blocks(v)
        // No caret was set (it defaults outside the run), so collapse neither relocates it nor appends a
        // trailing paragraph — the round-trip is the two quotes verbatim.
        XCTAssertEqual(bs.count, 2)
        XCTAssertEqual(bs.compactMap { if case let .paragraph(p) = $0 { return p.text } else { return nil } }, ["one", "two"])
    }

    // MARK: caret placement after collapse (regression: cursor must move OUT of the quote; typing must not
    // land on the collapsed atom's display-only gap, which silently dropped the text / appeared to expand)

    func test_collapse_withFollowingParagraph_caretLandsInIt() {
        let v = canvas([quote("q", "hello world"), body("b", "after")])
        // caret inside the quote before collapsing
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(v.boxes[0].textStart + 3), DocumentTextPosition(v.boxes[0].textStart + 3))
        v.collapseQuoteRun(atIndex: 0)
        let bs = blocks(v)
        XCTAssertEqual(bs.count, 2)
        guard case .collapsedQuote = bs[0] else { return XCTFail("expected collapsed quote at 0") }
        // caret is the start of the following body paragraph (after the collapsed quote), a renderable slot
        let after = v.boxes[1]
        XCTAssertTrue(after is BlockBox)
        XCTAssertEqual(v.head, after.textStart)
        XCTAssertTrue(v.isRenderablePosition(v.head))
    }

    func test_collapse_loneQuote_appendsTrailingParagraphForCaret() {
        let v = canvas([quote("q", "hello world")])
        let off = v.boxes[0].textStart + 2   // caret inside the quote (so it must relocate on collapse)
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(off), DocumentTextPosition(off))
        v.collapseQuoteRun(atIndex: 0)
        let bs = blocks(v)
        XCTAssertEqual(bs.count, 2)
        guard case .collapsedQuote = bs[0] else { return XCTFail("expected collapsed quote at 0") }
        guard case let .paragraph(p) = bs[1] else { return XCTFail("expected trailing body paragraph") }
        XCTAssertEqual(p.style, .body); XCTAssertTrue(p.text.isEmpty)
        XCTAssertEqual(v.head, v.boxes[1].textStart)
        XCTAssertTrue(v.isRenderablePosition(v.head))
    }

    func test_collapse_thenType_insertsAfterQuote_doesNotExpand() {
        let v = canvas([quote("q", "hello world")])
        let off = v.boxes[0].textStart + 2   // caret inside the quote (so it relocates after on collapse)
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(off), DocumentTextPosition(off))
        v.collapseQuoteRun(atIndex: 0)
        v.insertText("X")
        let bs = blocks(v)
        // The quote stays collapsed; the typed text lands in the trailing body paragraph (NOT swallowed by
        // the atom / re-expanded).
        guard case let .collapsedQuote(cq) = bs[0] else { return XCTFail("quote must stay collapsed") }
        XCTAssertEqual(cq.paragraphs.map(\.text), ["hello world"])
        guard case let .paragraph(p) = bs[1] else { return XCTFail("expected trailing body paragraph") }
        XCTAssertEqual(p.text, "X")
    }

    // MARK: caret OUTSIDE the run must NOT be relocated (only an inside caret moves)

    func test_collapse_caretAfterRun_staysInPlace() {
        let v = canvas([quote("q", "hello world"), body("b", "after")])
        // caret two chars into the following body (after the quote)
        let off = v.boxes[1].textStart + 2
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(off), DocumentTextPosition(off))
        v.collapseQuoteRun(atIndex: 0)
        let bs = blocks(v)
        XCTAssertEqual(bs.count, 2, "no trailing paragraph is appended when the caret was outside the run")
        guard case .collapsedQuote = bs[0] else { return XCTFail("expected collapsed quote at 0") }
        // caret is still 2 chars into the following body (same logical place), now after the collapsed quote
        XCTAssertEqual(v.head, v.boxes[1].textStart + 2)
    }

    func test_collapse_caretBeforeRun_staysInPlace() {
        let v = canvas([body("b", "before"), quote("q", "hello world")])
        let off = v.boxes[0].textStart + 3
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(off), DocumentTextPosition(off))
        v.collapseQuoteRun(atIndex: 1)
        let bs = blocks(v)
        XCTAssertEqual(bs.count, 2)
        guard case .collapsedQuote = bs[1] else { return XCTFail("expected collapsed quote at 1") }
        // caret unchanged (positions before the run are untouched)
        XCTAssertEqual(v.head, v.boxes[0].textStart + 3)
    }

    // MARK: expand mirrors collapse — only an on-atom caret lands in the restored quote; an outside caret stays

    private func collapsed(_ id: String, _ text: String) -> Block {
        .collapsedQuote(CollapsedQuote(id: BlockID(id), paragraphs: [ParagraphBlock(id: BlockID(id + "p"), style: .quote, runs: [TextRun(text: text)])]))
    }

    func test_expand_caretOutside_staysInPlace_doesNotEnterQuote() {
        let v = canvas([collapsed("q", "one"), body("b", "after")])
        let off = v.boxes[1].textStart + 2   // caret in the following body, OUTSIDE the collapsed atom
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(off), DocumentTextPosition(off))
        v.expandCollapsedQuote(atIndex: 0)
        let bs = blocks(v)
        // quote restored at 0, body still at 1; caret still 2 chars into the body (NOT inside the quote)
        guard case let .paragraph(p0) = bs[0], p0.style == .quote else { return XCTFail("expected restored quote at 0") }
        XCTAssertEqual(v.head, v.boxes[1].textStart + 2)
    }

    func test_expand_caretOnAtom_landsInRestoredQuote() {
        let v = canvas([collapsed("q", "one"), body("b", "after")])
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(v.boxes[0].nodeStart), DocumentTextPosition(v.boxes[0].nodeStart))
        v.expandCollapsedQuote(atIndex: 0)
        // caret was on the collapsed atom → lands at the start of the restored quote
        guard let q = v.boxes.first as? BlockBox, q.style == .quote else { return XCTFail("expected restored quote at 0") }
        XCTAssertEqual(v.head, q.textStart)
    }

    // MARK: typing on a collapsed quote's gap (reached by arrow-nav) opens a paragraph before it, never
    // corrupting the atom's display-only layout

    func test_typeOnCollapsedQuoteGap_insertsBodyParagraphBefore() {
        let v = canvas([collapsed("q", "one"), body("b", "after")])
        // caret on the collapsed quote's leading gap (where arrow-nav lands)
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(v.boxes[0].nodeStart), DocumentTextPosition(v.boxes[0].nodeStart))
        v.insertText("X")
        let bs = blocks(v)
        XCTAssertEqual(bs.count, 3)
        guard case let .paragraph(p0) = bs[0], p0.style == .body else { return XCTFail("expected body paragraph before the quote") }
        XCTAssertEqual(p0.text, "X")
        guard case let .collapsedQuote(cq) = bs[1] else { return XCTFail("collapsed quote must stay collapsed + intact") }
        XCTAssertEqual(cq.paragraphs.map(\.text), ["one"])
        XCTAssertEqual(v.head, v.boxes[0].textStart + 1)   // caret after the typed "X"
    }
}
#endif
