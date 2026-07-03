#if canImport(UIKit)
import XCTest
@testable import RichTextEditorUIKit
@testable import RichTextEditorCore

/// Double-return (Enter on an empty line inside a code block) exits the block: trailing/empty line →
/// after, first line → before, wholly-empty → un-code. The triggering empty line is removed.
/// Shift+Return special handling is gone.
@available(iOS 13.0, *)
final class DoubleReturnExitTests: XCTestCase {
    private func makeCanvas(_ blocks: [Block]) -> DocumentCanvasView {
        let c = DocumentCanvasView()
        c.setBlocks(blocks, width: 320)
        return c
    }
    private func style(_ box: CanvasBlock) -> ParagraphStyleName? { (box as? BlockBox)?.style }
    private func bodyListItem(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), style: .body, list: ListMembership(marker: .bullet),
                                  runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }
    private func list(_ box: CanvasBlock) -> ListMembership? { (box as? BlockBox)?.listMembership }

    func test_plainList_emptyItemReturn_endsIntoBodyParagraph_unchanged() {
        // A plain (non-quote) list: an empty item + Return ends into body.
        let canvas = makeCanvas([bodyListItem("l1", "A"), bodyListItem("l2", "")])
        canvas.setCaret(global: canvas.boxes[1].textStart)
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 2)
        XCTAssertEqual(style(canvas.boxes[1]), .body, "a plain empty list item ends into a body paragraph")
        XCTAssertNil(list(canvas.boxes[1]))
    }

    // MARK: Shift+Return removed

    func test_shiftReturn_keyCommandRemoved() {
        let canvas = DocumentCanvasView()
        let hasShiftReturn = (canvas.keyCommands ?? []).contains { $0.input == "\r" && $0.modifierFlags == .shift }
        XCTAssertFalse(hasShiftReturn, "Shift+Return key command is removed")
    }

    // MARK: Code-block double-return

    // Typing two newlines at the BEGINNING of a code block exits before it (the first Enter lands the caret
    // on the content line past the new "\n"; the second Enter at the start-of-content-after-a-leading-blank
    // exits). Reachability of the first-line→before case.
    func test_codeBlock_twoNewlinesAtBeginning_exitsBefore() {
        let canvas = makeCanvas([.code(CodeBlock(id: BlockID("c1"), runs: [TextRun(text: "abc")]))])
        canvas.setCaret(global: canvas.boxes[0].textStart)
        canvas.insertText("\n")
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 2, "the second newline at the beginning exits before the code block")
        XCTAssertEqual(style(canvas.boxes[0]), .body, "an empty body paragraph before the code block")
        guard case let .code(cb) = canvas.boxes[1].currentBlock() else { return XCTFail("expected .code second") }
        XCTAssertEqual(cb.text, "abc", "no stray leading blank lines remain in the code block")
    }

    func test_codeBlock_doubleReturnOnTrailingEmptyLine_exitsAfter() {
        let canvas = makeCanvas([.code(CodeBlock(id: BlockID("c1"), runs: [TextRun(text: "abc\n")]))])
        canvas.setCaret(global: canvas.documentSize - 1)   // the trailing blank line
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 2)
        guard case let .code(cb) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .code first") }
        XCTAssertEqual(cb.text, "abc", "the trailing blank line is removed")
        XCTAssertEqual(style(canvas.boxes[1]), .body, "an empty body paragraph after the code block")
    }

    func test_codeBlock_doubleReturnOnFirstEmptyLine_exitsBefore() {
        let canvas = makeCanvas([.code(CodeBlock(id: BlockID("c1"), runs: [TextRun(text: "\nabc")]))])
        canvas.setCaret(global: canvas.boxes[0].textStart)   // local 0 — the empty first line
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 2)
        XCTAssertEqual(style(canvas.boxes[0]), .body, "an empty body paragraph before the code block")
        guard case let .code(cb) = canvas.boxes[1].currentBlock() else { return XCTFail("expected .code second") }
        XCTAssertEqual(cb.text, "abc", "the empty first line is removed")
        XCTAssertEqual(canvas.head, canvas.boxes[0].textStart, "caret in the new body paragraph")
    }

    // REPRO: two-line code block, caret at the start of the (non-empty) first line, one Return → a leading
    // newline is inserted and the block grows by a line.
    func test_codeBlock_returnAtStartOfNonEmptyFirstLine_insertsLeadingNewline_growsHeight() {
        let canvas = makeCanvas([.code(CodeBlock(id: BlockID("c1"), runs: [TextRun(text: "A\nB")]))])
        canvas.frame = CGRect(x: 0, y: 0, width: 320, height: 600)
        canvas.simulateParentLayout()
        let before = (canvas.boxes[0] as! CodeBlockBox).height
        let beforeFrame = (canvas.boxes[0] as! CodeBlockBox).frame.height
        let beforeMeasured = (canvas.boxes[0] as! CodeBlockBox).measuredHeight(forWidth: 320)
        canvas.setCaret(global: canvas.boxes[0].textStart)      // local 0 — start of the first (non-empty) line
        canvas.insertText("\n")
        guard case let .code(cb) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .code") }
        XCTAssertEqual(cb.text, "\nA\nB", "Return at the line start inserts a leading newline")
        let after = (canvas.boxes[0] as! CodeBlockBox).height
        XCTAssertGreaterThan(after, before, "the code block grows by one line")
        let afterFrame = (canvas.boxes[0] as! CodeBlockBox).frame.height
        XCTAssertGreaterThan(afterFrame, beforeFrame, "the code block laid-out FRAME grows by one line")
        let afterMeasured = (canvas.boxes[0] as! CodeBlockBox).measuredHeight(forWidth: 320)
        XCTAssertGreaterThan(afterMeasured, beforeMeasured, "the code block PURE MEASURE (field-sizing path) grows by one line")
    }

    func test_codeBlock_doubleReturnOnEmptyBlock_uncodes() {
        let canvas = makeCanvas([.code(CodeBlock(id: BlockID("c1"), runs: []))])
        canvas.setCaret(global: 1)
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 1)
        XCTAssertEqual(style(canvas.boxes[0]), .body, "the empty code block becomes a body paragraph")
    }

    func test_codeBlock_returnOnMiddleEmptyLine_insertsNewline() {
        let canvas = makeCanvas([.code(CodeBlock(id: BlockID("c1"), runs: [TextRun(text: "a\n\nb")]))])
        canvas.setCaret(global: canvas.boxes[0].textStart + 2)   // the empty middle line (between the two \n)
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 1, "a middle empty line stays inside the code block")
        guard case let .code(cb) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .code") }
        XCTAssertEqual(cb.text, "a\n\n\nb", "another newline is inserted (no exit)")
    }
}
#endif
