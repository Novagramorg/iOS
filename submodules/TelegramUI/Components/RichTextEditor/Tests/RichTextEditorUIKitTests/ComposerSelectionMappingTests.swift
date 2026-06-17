#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// The chat composer addresses text by a flat UTF-16 offset over its paragraphs joined by "\n" (the
/// `ComposerDocumentBridge` representation). `DocumentCanvasView.composerSelectedRange` maps that flat
/// offset to/from the editor's global selection. Without it the host's `selectedRange` is a stub (caret
/// never tracked) — the visible cause of the chat-composer emoji bugs (caret doesn't advance; a re-insert
/// after a delete leaves a stray code unit / "service character").
final class ComposerSelectionMappingTests: XCTestCase {
    private func makeCanvas(_ blocks: [Block]) -> DocumentCanvasView {
        let c = DocumentCanvasView()
        c.setBlocks(blocks, width: 320)
        c.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        c.layoutIfNeeded()
        return c
    }
    private func para(_ s: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID.generate(), runs: s.isEmpty ? [] : [TextRun(text: s)]))
    }

    func test_get_singleParagraph_collapsedCaret() {
        let c = makeCanvas([para("abc")])
        let base = c.boxes[0].textStart
        c.anchor = base + 2; c.head = base + 2
        XCTAssertEqual(c.composerSelectedRange, NSRange(location: 2, length: 0))
    }

    func test_get_multiParagraph_secondParagraphOffsetsAcrossNewline() {
        let c = makeCanvas([para("ab"), para("cd")])   // flat "ab\ncd"
        let p2 = c.boxes[1].textStart
        c.anchor = p2; c.head = p2
        XCTAssertEqual(c.composerSelectedRange.location, 3, "start of paragraph 2 is flat offset 3 (after the \\n)")
        c.anchor = p2 + 2; c.head = p2 + 2
        XCTAssertEqual(c.composerSelectedRange.location, 5, "end of paragraph 2 is flat offset 5")
    }

    func test_get_surrogatePairEmoji_offsetCountsUTF16Units() {
        let c = makeCanvas([para("a\u{1F600}")])   // "a😀" — emoji is 2 UTF-16 units, flat length 3
        let base = c.boxes[0].textStart
        c.anchor = base + 3; c.head = base + 3
        XCTAssertEqual(c.composerSelectedRange, NSRange(location: 3, length: 0), "caret after the emoji is flat offset 3")
    }

    func test_set_movesCaret_intoSecondParagraph_roundTrips() {
        let c = makeCanvas([para("ab"), para("cd")])
        c.composerSelectedRange = NSRange(location: 4, length: 0)   // 2nd char of paragraph 2
        XCTAssertEqual(c.head, c.boxes[1].textStart + 1)
        XCTAssertEqual(c.composerSelectedRange, NSRange(location: 4, length: 0))
    }

    func test_set_selectionSpan() {
        let c = makeCanvas([para("abcd")])
        c.composerSelectedRange = NSRange(location: 1, length: 2)
        XCTAssertEqual(c.selFrom, c.boxes[0].textStart + 1)
        XCTAssertEqual(c.selTo, c.boxes[0].textStart + 3)
    }

    func test_set_paragraphBoundary_endVsStart() {
        let c = makeCanvas([para("ab"), para("cd")])   // flat "ab\ncd"
        c.composerSelectedRange = NSRange(location: 2, length: 0)   // end of paragraph 1 (before the \n)
        XCTAssertEqual(c.head, c.boxes[0].textStart + 2)
        c.composerSelectedRange = NSRange(location: 3, length: 0)   // start of paragraph 2 (after the \n)
        XCTAssertEqual(c.head, c.boxes[1].textStart)
    }

    func test_set_caretAfterEmoji_landsPastBothUnits() {
        let c = makeCanvas([para("a\u{1F600}")])
        c.composerSelectedRange = NSRange(location: 3, length: 0)
        XCTAssertEqual(c.head, c.boxes[0].textStart + 3, "flat offset 3 maps past the whole 2-unit emoji")
    }
}
#endif
