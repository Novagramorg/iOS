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

    // MARK: - Task 14: editing AROUND a pull quote (framed-atom integration)

    // A canvas laid out with real frames (needed for tap-below to get a meaningful frame.maxY).
    private func laidOutCanvas(_ blocks: [Block]) -> DocumentCanvasView {
        let c = DocumentCanvasView()
        c.setBlocks(blocks, width: 320)
        c.frame = CGRect(x: 0, y: 0, width: 320, height: 600)
        c.layoutIfNeeded()
        return c
    }

    // MARK: Backspace after a pull quote

    /// Backspace at the start of an EMPTY body paragraph that follows a pull quote must remove the empty
    /// paragraph and park the caret at the pull quote's text end — not delete the pull quote itself.
    /// (Mirrors `test_backspaceAtStartOfEmptyParagraphAfterCode_removesParagraph_keepsCode` in
    /// `CanvasTrailingParagraphTests`.)
    func test_backspaceAtStartOfEmptyParagraphAfterPullQuote_removesParagraph_keepsPullQuote() {
        let pq = Block.pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "quote text")]))
        let v = laidOutCanvas([pq, .paragraph(ParagraphBlock(id: BlockID("p"), runs: []))])
        v.setCaret(global: v.boxes[1].textStart)
        v.deleteBackward()
        XCTAssertEqual(v.boxes.count, 1, "the empty paragraph is removed; the pull quote is kept")
        XCTAssertTrue(v.boxes[0] is PullQuoteBox)
        XCTAssertEqual(v.head, v.boxes[0].textStart + v.boxes[0].textLength,
                       "caret parks at the pull quote's text end")
    }

    /// Backspace at the start of a NON-EMPTY body paragraph after a pull quote must keep both blocks
    /// and step the caret back into the pull quote's text end (not merge or drop either block).
    func test_backspaceAtStartOfNonEmptyParagraphAfterPullQuote_keepsBoth_movesIntoQuote() {
        let pq = Block.pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "quote text")]))
        let v = laidOutCanvas([pq, .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "body")]))])
        v.setCaret(global: v.boxes[1].textStart)
        v.deleteBackward()
        XCTAssertEqual(v.boxes.count, 2, "nothing deleted — the paragraph is non-empty")
        XCTAssertEqual((v.boxes[1] as! BlockBox).currentParagraph().text, "body")
        XCTAssertEqual(v.head, v.boxes[0].textStart + v.boxes[0].textLength,
                       "caret moved to the pull quote's text end")
    }

    // MARK: Select-all delete (cross-block endpoint)

    /// Select-All + Backspace on [pullQuote, paragraph]: the pull quote is a fully-covered cross-block
    /// endpoint and is dropped, leaving one empty body paragraph.
    /// (Mirrors `test_crossBlockDelete_fullyCoveredCodeBlockIsDropped` in `CodeBlockEditingTests`.)
    func test_selectAll_delete_pullQuoteAndParagraph_leavesEmptyDocument() {
        let pq = Block.pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "quote text")]))
        let v = laidOutCanvas([pq, .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "body")]))])
        v.selectAll(nil)
        v.deleteBackward()
        XCTAssertFalse(v.boxes.contains { $0 is PullQuoteBox },
                       "the fully-covered pull quote is dropped by the cross-block delete")
        XCTAssertEqual(v.boxes.count, 1, "exactly one block remains (an empty body paragraph)")
    }

    // MARK: Framed spacing (isFramedAtom / facingInset)

    /// Body paragraphs adjacent to a pull quote must reserve the extra external margin on the
    /// pull-quote-facing side — matching the code-block / table / collapsed-quote neighbor behavior.
    /// (Mirrors `test_codeBlockNeighbors_reserveExtraExternalMargin` in `BlockStackTests`.)
    func test_pullQuoteNeighbors_reserveExtraExternalMargin() {
        let mapper = AttributedStringMapper()
        func body(_ id: String) -> BlockBox {
            BlockBox(paragraph: ParagraphBlock(id: BlockID(id), runs: [TextRun(text: "x")]),
                     mapper: mapper, width: 300)
        }
        let pq = PullQuoteBox(pullQuote: PullQuote(id: BlockID("pq"), runs: [TextRun(text: "quote")]),
                              mapper: mapper, width: 300)
        let above = body("above"), below = body("below")
        BlockStack(boxes: [above, pq, below]).layout(origin: .zero, width: 300)
        // A pull quote draws its own bounded fill, so neighbors reserve the extra external margin —
        // exactly like a code block sitting the SAME distance from its neighbors as a quote.
        XCTAssertGreaterThan(above.bottomInset, BlockBox.defaultVerticalInset,
                             "block above the pull quote must reserve the extra framed-neighbor margin")
        XCTAssertGreaterThan(below.topInset, BlockBox.defaultVerticalInset,
                             "block below the pull quote must reserve the extra framed-neighbor margin")
        XCTAssertEqual(above.topInset, BlockBox.defaultVerticalInset, accuracy: 0.5,
                       "far side (away from the pull quote) must be unaffected")
    }

    // MARK: Tap-below affordance

    /// A tap below a trailing pull quote appends a new empty body paragraph.
    /// (Mirrors `test_tapBelowTrailingCodeBlock_addsBodyParagraph` in `CodeBlockEditingTests`.)
    func test_tapBelowTrailingPullQuote_addsBodyParagraph() {
        let pq = Block.pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "quote")]))
        let v = laidOutCanvas([pq])
        let lastMaxY = v.boxes[0].frame.maxY
        XCTAssertGreaterThan(lastMaxY, 0, "precondition: the pull quote box is laid out")
        v.performSingleTap(at: CGPoint(x: 20, y: lastMaxY + 40))
        XCTAssertEqual(v.boxes.count, 2)
        guard case let .paragraph(p) = v.boxes[1].currentBlock() else {
            return XCTFail("expected a .paragraph block after the pull quote")
        }
        XCTAssertEqual(p.style, .body,
                       "tapping below the trailing pull quote starts a body paragraph after it")
        XCTAssertEqual(v.head, v.boxes[1].textStart, "caret moves into the new paragraph")
    }
}
#endif
