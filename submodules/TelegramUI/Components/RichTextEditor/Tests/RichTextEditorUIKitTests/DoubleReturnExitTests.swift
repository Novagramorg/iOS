#if canImport(UIKit)
import XCTest
@testable import RichTextEditorUIKit
@testable import RichTextEditorCore

/// Double-return (Enter on an empty line inside a quote/code block) exits the block: trailing/empty line →
/// after, first line → before, middle empty line → normal Enter. The triggering empty line is removed.
/// Shift+Return special handling is gone.
@available(iOS 13.0, *)
final class DoubleReturnExitTests: XCTestCase {
    private func makeCanvas(_ blocks: [Block]) -> DocumentCanvasView {
        let c = DocumentCanvasView()
        c.setBlocks(blocks, width: 320)
        return c
    }
    private func quote(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), style: .quote, runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }
    private func style(_ box: CanvasBlock) -> ParagraphStyleName? { (box as? BlockBox)?.style }

    // MARK: Shift+Return removed

    func test_shiftReturn_keyCommandRemoved() {
        let canvas = DocumentCanvasView()
        let hasShiftReturn = (canvas.keyCommands ?? []).contains { $0.input == "\r" && $0.modifierFlags == .shift }
        XCTAssertFalse(hasShiftReturn, "Shift+Return key command is removed")
    }

    // MARK: Quote double-return

    func test_quote_doubleReturnOnTrailingEmptyLine_exitsAfter() {
        let canvas = makeCanvas([quote("q1", "abc"), quote("q2", "")])   // trailing empty quote line
        canvas.setCaret(global: canvas.boxes[1].textStart)
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 2, "the empty quote line becomes the escape body paragraph")
        XCTAssertEqual(style(canvas.boxes[0]), .quote, "the quote content remains")
        XCTAssertEqual(style(canvas.boxes[1]), .body, "an empty body paragraph after the quote")
        XCTAssertEqual(canvas.head, canvas.boxes[1].textStart, "caret in the new body paragraph")
    }

    func test_quote_doubleReturnOnFirstEmptyLine_exitsBefore() {
        let canvas = makeCanvas([quote("q1", ""), quote("q2", "abc")])   // leading empty quote line
        canvas.setCaret(global: canvas.boxes[0].textStart)
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 2)
        XCTAssertEqual(style(canvas.boxes[0]), .body, "an empty body paragraph before the quote")
        XCTAssertEqual(style(canvas.boxes[1]), .quote, "the quote content remains")
        XCTAssertEqual(canvas.head, canvas.boxes[0].textStart, "caret in the new body paragraph")
    }

    func test_quote_doubleReturnOnEmptyBlock_unquotes() {
        let canvas = makeCanvas([quote("q1", "")])   // a lone empty quote
        canvas.setCaret(global: canvas.boxes[0].textStart)
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 1)
        XCTAssertEqual(style(canvas.boxes[0]), .body, "the empty quote becomes a body paragraph")
    }

    func test_quote_returnOnMiddleEmptyLine_isNormalSplit() {
        let canvas = makeCanvas([quote("a", "A"), quote("m", ""), quote("b", "B")])   // empty line BETWEEN quotes
        canvas.setCaret(global: canvas.boxes[1].textStart)
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 4, "a middle empty quote line splits normally (no exit)")
        XCTAssertTrue(canvas.boxes.allSatisfy { style($0) == .quote }, "still all quote paragraphs")
    }

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

    func test_quote_twoNewlinesAtBeginning_exitsBefore() {
        let canvas = makeCanvas([quote("q", "abc")])
        canvas.setCaret(global: canvas.boxes[0].textStart)
        canvas.insertText("\n")
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 2, "the second newline at the beginning exits before the quote")
        XCTAssertEqual(style(canvas.boxes[0]), .body, "an empty body paragraph before the quote")
        XCTAssertEqual(style(canvas.boxes[1]), .quote, "the quote content remains")
        XCTAssertEqual((canvas.boxes[1] as! BlockBox).currentParagraph().text, "abc")
    }

    // MARK: Code-block double-return

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
