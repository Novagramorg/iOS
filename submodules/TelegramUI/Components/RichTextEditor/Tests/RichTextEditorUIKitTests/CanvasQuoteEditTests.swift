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

    // MARK: A — Backspace in an empty quote un-quotes it

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

    // MARK: C — Shift+Return exits a quote (above when on its first visual line, else below)

    func test_shiftReturnOnFirstLineOfQuote_addsBodyParagraphAbove() {
        let v = canvas([quote("q", "Quote")])           // single line → first line
        caret(v, v.boxes[0].textStart + 5)
        v.performShiftReturn()
        XCTAssertEqual(v.boxes.count, 2)
        XCTAssertEqual(style(v, 0), .body, "a new empty body paragraph is inserted ABOVE the quote")
        XCTAssertEqual((v.boxes[0] as! BlockBox).textLength, 0)
        XCTAssertEqual(style(v, 1), .quote, "the quote moves down, text unchanged")
        XCTAssertEqual((v.boxes[1] as! BlockBox).currentParagraph().text, "Quote")
        XCTAssertEqual(v.head, v.boxes[0].textStart, "caret moves into the new paragraph above")
    }

    func test_shiftReturnInEmptyQuote_addsBodyParagraphAbove() {
        let v = canvas([quote("q")])
        caret(v, v.boxes[0].textStart)
        v.performShiftReturn()
        XCTAssertEqual(v.boxes.count, 2)
        XCTAssertEqual(style(v, 0), .body, "an empty quote's caret is on its first line → body paragraph above")
        XCTAssertEqual(style(v, 1), .quote)
        XCTAssertEqual(v.head, v.boxes[0].textStart)
    }

    func test_shiftReturnOnLaterLineOfQuote_addsBodyParagraphBelow() {
        let long = "Lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore"
        let v = canvas([quote("q", long)])
        let box = v.boxes[0] as! BlockBox
        XCTAssertGreaterThan(box.textLayout.caretRect(atOffset: box.textLength).minY,
                             box.textLayout.caretRect(atOffset: 0).minY + 1,
                             "precondition: the quote wraps onto more than one visual line")
        caret(v, box.textStart + box.textLength)        // caret on the LAST visual line
        v.performShiftReturn()
        XCTAssertEqual(v.boxes.count, 2)
        XCTAssertEqual(style(v, 0), .quote, "the quote stays first")
        XCTAssertEqual(style(v, 1), .body, "a body paragraph is inserted BELOW the quote")
        XCTAssertEqual((v.boxes[1] as! BlockBox).textLength, 0)
        XCTAssertEqual(v.head, v.boxes[1].textStart, "caret moves into the new paragraph below")
    }

    func test_shiftReturnOutsideQuote_isNormalParagraphBreak() {
        let v = canvas([body("b", "Hello")])
        caret(v, v.boxes[0].textStart + 5)
        v.performShiftReturn()
        XCTAssertEqual(v.boxes.count, 2, "outside a quote, Shift+Return splits like a normal Return")
        XCTAssertEqual(style(v, 1), .body)
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

    func test_tapBelowTrailingBody_placesCaret_noNewParagraph() {
        let v = canvas([body("b", "Hello")])
        let lastMaxY = v.boxes[0].frame.maxY
        v.performSingleTap(at: CGPoint(x: 20, y: lastMaxY + 40))
        XCTAssertEqual(v.boxes.count, 1, "below a trailing BODY block, a tap just places the caret (no new block)")
    }

    func test_tapOnQuoteBody_placesCaret_noNewParagraph() {
        let v = canvas([quote("q", "Quote")])
        let f = v.boxes[0].frame
        v.performSingleTap(at: CGPoint(x: 20, y: f.midY))
        XCTAssertEqual(v.boxes.count, 1, "tapping ON the quote places a caret inside it, not a new block")
    }
}
#endif
