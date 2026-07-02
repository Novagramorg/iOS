#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// Quote-block escape/delete affordances. A quote is a `BlockBox` with `style == .quote`; with no
/// special handling an empty quote (especially as the first block) can't be removed, and a quote that
/// ends the document has nothing below it to start a normal paragraph from. Three behaviors:
///  A. Backspace in an EMPTY quote un-quotes it (→ body paragraph).
///  B. Tapping BELOW a trailing quote starts a new empty body paragraph after it.
///  C. Shift+Return inside a quote does the same (exits to a new body paragraph after it).
final class CanvasQuoteEditTests: XCTestCase {
    private func canvas(_ blocks: [Block]) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks(blocks, width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 600)
        v.layoutIfNeeded()
        return v
    }
    private func caret(_ v: DocumentCanvasView, _ pos: Int) {
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(pos), DocumentTextPosition(pos))
    }
    private func quote(_ id: String, _ text: String = "") -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), style: .quote, runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }
    private func body(_ id: String, _ text: String = "") -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), style: .body, runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }
    private func style(_ v: DocumentCanvasView, _ i: Int) -> ParagraphStyleName { (v.boxes[i] as! BlockBox).style }
    private func quoteListItem(_ id: String, _ text: String = "") -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), style: .quote, list: ListMembership(marker: .bullet),
                                  runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }
    private func listOf(_ v: DocumentCanvasView, _ i: Int) -> ListMembership? { (v.boxes[i] as! BlockBox).listMembership }

    // MARK: A — Backspace in an empty quote un-quotes it

    func test_backspaceAtStartOfNonEmptyQuotedListItem_breaksToBodyParagraph() {
        // Backspace at the START of a level-0 quoted list item breaks out to a body paragraph (keeping the
        // contents) — consistent with the empty-item case and with un-quoting via backspace being one-step.
        let v = canvas([quoteListItem("q1", "A"), quoteListItem("q2", "B")])
        caret(v, v.boxes[0].textStart)          // start of the first quoted list item "A"
        v.deleteBackward()
        let a = v.boxes[0] as! BlockBox
        XCTAssertEqual(a.style, .body, "breaks out to a body paragraph (un-quotes)")
        XCTAssertNil(a.listMembership, "and drops the list marker")
        XCTAssertEqual(a.currentParagraph().text, "A", "contents preserved")
        XCTAssertEqual(style(v, 1), .quote, "the rest of the quoted list is unchanged")
        XCTAssertEqual(listOf(v, 1)?.marker, .bullet)
    }

    func test_backspaceInEmptyQuotedListItem_replacesWithEmptyParagraph() {
        // Backspace on the empty (first) line of a list inside a quote must become a plain empty PARAGRAPH
        // — clearing BOTH the quote AND the list marker — not a body list item with a stray marker.
        let v = canvas([quoteListItem("q1"), quoteListItem("q2", "B")])
        caret(v, v.boxes[0].textStart)
        v.deleteBackward()
        XCTAssertEqual(style(v, 0), .body, "the empty quoted list item un-quotes to a body paragraph")
        XCTAssertNil(listOf(v, 0), "and the list marker is cleared too — it's a plain paragraph")
        XCTAssertEqual(style(v, 1), .quote, "the rest of the quoted list is unchanged")
        XCTAssertEqual(listOf(v, 1)?.marker, .bullet)
    }

    func test_backspaceInEmptyQuote_firstBlock_convertsToBody() {
        let v = canvas([quote("q")])
        caret(v, v.boxes[0].textStart)
        v.deleteBackward()
        XCTAssertEqual(v.boxes.count, 1)
        XCTAssertEqual(style(v, 0), .body, "the otherwise-undeletable first-block empty quote becomes a body paragraph")
    }

    func test_backspaceInEmptyQuote_afterText_convertsToBody() {
        let v = canvas([body("b", "Hello"), quote("q")])
        caret(v, v.boxes[1].textStart)
        v.deleteBackward()
        XCTAssertEqual(v.boxes.count, 2, "the quote is un-quoted in place (a second backspace would then merge)")
        XCTAssertEqual(style(v, 1), .body)
    }

    func test_backspaceInNonEmptyQuote_deletesChar_staysQuote() {
        let v = canvas([quote("q", "Hi")])
        caret(v, v.boxes[0].textStart + 2)
        v.deleteBackward()
        XCTAssertEqual(style(v, 0), .quote, "a non-empty quote keeps its style; backspace just deletes a char")
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "H")
    }

    // MARK: B — Tap below a trailing quote adds a body paragraph

    func test_tapBelowTrailingQuote_addsBodyParagraph() {
        let v = canvas([body("b", "Hello"), quote("q", "Quote")])
        let lastMaxY = v.boxes[1].frame.maxY
        XCTAssertGreaterThan(lastMaxY, 0, "precondition: the quote box is laid out")
        v.performSingleTap(at: CGPoint(x: 20, y: lastMaxY + 40))
        XCTAssertEqual(v.boxes.count, 3)
        XCTAssertEqual(style(v, 2), .body, "tapping below the trailing quote starts a body paragraph after it")
        XCTAssertEqual((v.boxes[2] as! BlockBox).textLength, 0)
        XCTAssertEqual(v.head, v.boxes[2].textStart, "caret moves into the new paragraph")
    }

    func test_tapBelowTrailingNonEmptyBody_addsBodyParagraph() {
        // Tapping below the document's last block always starts a new empty body paragraph there — even
        // when that last block is a (non-empty) body paragraph.
        let v = canvas([body("b", "Hello")])
        let lastMaxY = v.boxes[0].frame.maxY
        v.performSingleTap(at: CGPoint(x: 20, y: lastMaxY + 40))
        XCTAssertEqual(v.boxes.count, 2, "below a trailing non-empty body block, a tap starts a new empty body paragraph")
        XCTAssertEqual(style(v, 1), .body)
        XCTAssertEqual((v.boxes[1] as! BlockBox).textLength, 0)
        XCTAssertEqual(v.head, v.boxes[1].textStart, "caret moves into the new paragraph")
    }

    func test_tapBelowTrailingEmptyBody_placesCaret_noNewParagraph() {
        // The one exception: when the last block is ALREADY an empty body paragraph, a tap below it must
        // NOT stack a redundant empty paragraph — it just places the caret in the existing one.
        let v = canvas([body("b", "Hello"), body("e", "")])
        let lastMaxY = v.boxes[1].frame.maxY
        v.performSingleTap(at: CGPoint(x: 20, y: lastMaxY + 40))
        XCTAssertEqual(v.boxes.count, 2, "below an already-empty body paragraph, a tap just places the caret (no new block)")
        XCTAssertEqual(v.head, v.boxes[1].textStart, "caret lands in the existing empty paragraph")
    }

    func test_tapOnQuoteBody_placesCaret_noNewParagraph() {
        let v = canvas([quote("q", "Quote")])
        let f = v.boxes[0].frame
        v.performSingleTap(at: CGPoint(x: 20, y: f.midY))
        XCTAssertEqual(v.boxes.count, 1, "tapping ON the quote places a caret inside it, not a new block")
    }
}
#endif
