#if canImport(UIKit)
import XCTest
import RichTextEditorCore
@testable import RichTextEditorUIKit

@available(iOS 13.0, *)
final class CanvasPullQuoteEditTests: XCTestCase {
    private func makeCanvas() -> DocumentCanvasView {
        let c = DocumentCanvasView()
        c.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        return c
    }

    private func pullQuoteCanvas(_ text: String = "hi") -> DocumentCanvasView {
        let c = makeCanvas()
        c.setBlocks([.pullQuote(PullQuote(id: BlockID("pq"), runs: text.isEmpty ? [] : [TextRun(text: text)]))],
                    width: 320)
        c.simulateParentLayout()
        return c
    }

    func test_makePullQuote_togglesParagraphsIntoOneBlock_preservingFormatting() {
        let canvas = makeCanvas()
        var bold = CharacterAttributes(); bold.bold = true
        canvas.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("a"), style: .body, runs: [TextRun(text: "one", attributes: bold)])),
            .paragraph(ParagraphBlock(id: BlockID("b"), style: .body, runs: [TextRun(text: "two")])),
        ], width: 320)
        canvas.simulateParentLayout()
        canvas.selectAll(nil)                        // span both paragraphs
        canvas.makePullQuote()
        let blocks = canvas.currentBlocks()          // currentBlocks() mirrors currentDocument().blocks
        XCTAssertEqual(blocks.count, 1)
        guard case .pullQuote(let pq) = blocks[0] else { return XCTFail("not a pull quote") }
        XCTAssertEqual(pq.text, "one\ntwo")
        XCTAssertTrue(pq.runs.contains { $0.attributes.bold })   // formatting preserved (NOT flattened)

        // Toggle back:
        canvas.selectAll(nil)
        canvas.makePullQuote()
        let back = canvas.currentBlocks()
        XCTAssertTrue(back.allSatisfy { if case .paragraph = $0 { return true } else { return false } })
        XCTAssertEqual(back.count, 2)
    }

    // MARK: - Task 13: in-block editing

    // MARK: Enter inserts an interior newline (no paragraph split)

    func test_pullQuote_enterInsertsInteriorNewline() {
        let canvas = pullQuoteCanvas("hi")
        // textStart = 1, so global 3 = after "hi"
        canvas.setCaret(global: canvas.boxes[0].textStart + 2)
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 1, "Enter inside a pull quote must NOT split into two blocks")
        guard case .pullQuote(let pq) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .pullQuote") }
        XCTAssertTrue(pq.text.contains("\n"), "the pull quote text must contain the inserted newline")
    }

    func test_pullQuote_enterAtEnd_insertsNewlineDoesNotSplit() {
        let canvas = pullQuoteCanvas("line1")
        let box = canvas.boxes[0]
        canvas.setCaret(global: box.textStart + box.textLength)   // after "line1"
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 1)
        guard case .pullQuote(let pq) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .pullQuote") }
        XCTAssertEqual(pq.text, "line1\n")
    }

    func test_pullQuote_enterAtStart_insertsNewlineAtFront() {
        let canvas = pullQuoteCanvas("ab")
        canvas.setCaret(global: canvas.boxes[0].textStart)   // before "ab"
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 1)
        guard case .pullQuote(let pq) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .pullQuote") }
        XCTAssertEqual(pq.text, "\nab")
    }

    func test_pullQuote_caretAdvancesAfterNewline() {
        let canvas = pullQuoteCanvas("ab")
        let box = canvas.boxes[0]
        canvas.setCaret(global: box.textStart + 1)   // after "a"
        canvas.insertText("\n")
        XCTAssertEqual(canvas.head, box.textStart + 2, "caret must land after the inserted newline")
    }

    func test_pullQuote_enterReplacesSelectionWithNewline() {
        let canvas = pullQuoteCanvas("abcd")
        let box = canvas.boxes[0]
        canvas.setSelectionAnchor(global: box.textStart + 1)   // after "a"
        canvas.setSelectionHead(global: box.textStart + 3)     // before "d"
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 1)
        guard case .pullQuote(let pq) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .pullQuote") }
        XCTAssertEqual(pq.text, "a\nd")
    }

    // MARK: Double-return exits

    func test_pullQuote_doubleReturnOnTrailingBlankLine_exitsAfter() {
        let canvas = pullQuoteCanvas("abc\n")
        let box = canvas.boxes[0]
        canvas.setCaret(global: box.textStart + box.textLength)   // end of "abc\n"
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 2, "double-return on a trailing blank line exits the pull quote")
        guard case .pullQuote(let pq) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .pullQuote first") }
        XCTAssertEqual(pq.text, "abc", "the trailing blank line is removed")
        guard case .paragraph(let p) = canvas.boxes[1].currentBlock() else { return XCTFail("expected .paragraph second") }
        XCTAssertEqual(p.style, .body, "an empty body paragraph is added after the pull quote")
        XCTAssertEqual(canvas.head, canvas.boxes[1].textStart, "caret in the new body paragraph")
    }

    func test_pullQuote_doubleReturnOnFirstBlankLine_exitsBefore() {
        let canvas = pullQuoteCanvas("\nabc")
        let box = canvas.boxes[0]
        canvas.setCaret(global: box.textStart)   // local 0 — the empty first line
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 2)
        guard case .paragraph(let p) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .paragraph first") }
        XCTAssertEqual(p.style, .body, "an empty body paragraph is inserted before the pull quote")
        guard case .pullQuote(let pq) = canvas.boxes[1].currentBlock() else { return XCTFail("expected .pullQuote second") }
        XCTAssertEqual(pq.text, "abc", "the empty first line is removed")
        XCTAssertEqual(canvas.head, canvas.boxes[0].textStart, "caret in the new body paragraph")
    }

    func test_pullQuote_doubleReturnOnEmptyBlock_unmakes() {
        let canvas = pullQuoteCanvas("")   // wholly-empty pull quote
        let box = canvas.boxes[0]
        canvas.setCaret(global: box.textStart)
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 1)
        guard case .paragraph(let p) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .paragraph") }
        XCTAssertEqual(p.style, .body, "the empty pull quote becomes a body paragraph")
    }

    func test_pullQuote_returnOnMiddleEmptyLine_insertsNewline() {
        let canvas = pullQuoteCanvas("a\n\nb")
        let box = canvas.boxes[0]
        canvas.setCaret(global: box.textStart + 2)   // on the middle empty line
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 1, "a middle empty line stays inside the pull quote")
        guard case .pullQuote(let pq) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .pullQuote") }
        XCTAssertEqual(pq.text, "a\n\n\nb", "another newline is inserted (no exit)")
    }

    // Two newlines at the beginning exits before (the first Enter lands caret after the new "\n" on the
    // content line, so the second is at local 1 — the start-of-content-after-a-leading-blank case).
    func test_pullQuote_twoNewlinesAtBeginning_exitsBefore() {
        let canvas = pullQuoteCanvas("abc")
        let box = canvas.boxes[0]
        canvas.setCaret(global: box.textStart)
        canvas.insertText("\n")
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 2, "the second newline at the beginning exits before the pull quote")
        guard case .paragraph(let p) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .paragraph first") }
        XCTAssertEqual(p.style, .body, "an empty body paragraph before the pull quote")
        guard case .pullQuote(let pq) = canvas.boxes[1].currentBlock() else { return XCTFail("expected .pullQuote second") }
        XCTAssertEqual(pq.text, "abc", "no stray leading blank lines remain")
    }

    // MARK: Backspace in empty pull quote → body paragraph

    func test_pullQuote_backspaceInEmptyConvertsToBody() {
        let canvas = pullQuoteCanvas("")   // wholly-empty pull quote
        let box = canvas.boxes[0]
        canvas.setCaret(global: box.textStart)
        canvas.deleteBackward()
        XCTAssertEqual(canvas.boxes.count, 1)
        guard case .paragraph(let p) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .paragraph") }
        XCTAssertEqual(p.style, .body, "Backspace in an empty pull quote converts it to a body paragraph")
    }

    // MARK: Typing attributes are italic/centered

    func test_pullQuote_emptyTypingAttributesAreItalic() {
        // The pull-quote typing attributes must carry an italic font so the first character typed
        // into an empty pull quote is italic, not body-upright.
        let mapper = AttributedStringMapper()
        let attrs = PullQuoteBox.pullQuoteTypingAttributes(mapper)
        guard let font = attrs[.font] as? UIFont else { return XCTFail("no font in pull-quote typing attributes") }
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitItalic),
                      "the pull-quote typing font must be italic")
    }

    func test_pullQuote_emptyTypingAttributesAreCentered() {
        let mapper = AttributedStringMapper()
        let attrs = PullQuoteBox.pullQuoteTypingAttributes(mapper)
        guard let ps = attrs[.paragraphStyle] as? NSParagraphStyle else {
            return XCTFail("no paragraphStyle in pull-quote typing attributes")
        }
        XCTAssertEqual(ps.alignment, .center, "the pull-quote typing paragraph style must be centered")
    }

    func test_pullQuote_typingAttributesAtGlobal_returnsItalicWhenEmpty() {
        let canvas = pullQuoteCanvas("")
        let box = canvas.boxes[0]
        let attrs = canvas.typingAttributesAtGlobal(box.textStart)
        guard let font = attrs[.font] as? UIFont else { return XCTFail("no font") }
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitItalic),
                      "typing into an empty pull quote via the canvas must return an italic font")
    }
}
#endif
