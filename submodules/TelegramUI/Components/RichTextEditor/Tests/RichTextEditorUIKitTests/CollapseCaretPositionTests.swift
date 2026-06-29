#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// After collapsing a quote run, the caret must land on a RENDERABLE position (the collapsed quote is a
/// media-style gap atom) and the composer flat offset must be consistent (round-trips). Regression for the
/// bug where `collapseQuoteRun` parked the caret on the atom's `nodeStart`, which `isGapPosition` /
/// `snapToRenderable` / `caretRect` only recognized for `MediaBlockBox` — leaving the caret non-renderable
/// and the composer selection offset wrong.
final class CollapseCaretPositionTests: XCTestCase {
    private func canvas(_ blocks: [Block], width: CGFloat = 300) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks(blocks, width: width)
        v.frame = CGRect(x: 0, y: 0, width: width, height: 600); v.layoutIfNeeded()
        // Behave like the real parent: re-lay-out on a content-size change, so the post-collapse box gets a
        // frame (production only NOTIFIES; the parent drives layoutContent). Needed for caretRect geometry.
        v.simulateParentLayout()
        return v
    }
    private func quote(_ id: String, _ t: String) -> Block { .paragraph(ParagraphBlock(id: BlockID(id), style: .quote, runs: [TextRun(text: t)])) }
    private func body(_ id: String, _ t: String) -> Block { .paragraph(ParagraphBlock(id: BlockID(id), style: .body, runs: [TextRun(text: t)])) }

    /// The caret after collapse is renderable, sits at the collapsed quote's flat position, draws a finite
    /// caret rect, and round-trips through `composerSelectedRange` (getter → setter → getter stable).
    private func assertCollapseCaret(_ v: DocumentCanvasView, collapseAt index: Int, expectedFlat: Int,
                                     file: StaticString = #file, line: UInt = #line) {
        // Caret INSIDE the quote being collapsed — that text is folded away, so the caret must relocate to a
        // renderable slot after the collapsed quote (the case these assertions pin).
        let qBox = v.boxes[index]
        let inside = qBox.textStart + min(2, qBox.textLength)
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(inside), DocumentTextPosition(inside))
        v.collapseQuoteRun(atIndex: index)
        XCTAssertTrue(v.isRenderablePosition(v.head), "post-collapse caret must be renderable", file: file, line: line)
        XCTAssertEqual(v.composerSelectedRange, NSRange(location: expectedFlat, length: 0), file: file, line: line)
        // caretRect must be finite (not .zero / NaN) so the OS caret + loupe + scroll-follow work.
        let rect = v.caretRect(for: DocumentTextPosition(v.head))
        XCTAssertTrue(rect.origin.x.isFinite && rect.height > 0, "post-collapse caret rect must be drawable", file: file, line: line)
        // Round-trip: re-applying the reported range keeps the same renderable caret.
        let reported = v.composerSelectedRange
        v.composerSelectedRange = reported
        XCTAssertEqual(v.composerSelectedRange, reported, "composer selection must round-trip", file: file, line: line)
        XCTAssertTrue(v.isRenderablePosition(v.head), file: file, line: line)
    }

    // The caret lands in a real text block AFTER the collapsed quote (collapseQuoteRun), never on the atom
    // gap — so these assert the post-collapse caret is renderable, drawable, and round-trips at that position.

    func test_collapse_bodyThenQuote_caretAfterIsRenderable() {
        // [body"ab", quote] → [body"ab", collapsed, body""(trailing)]. flat: "ab"(0..2) "\n" placeholder(3)
        // "\n" trailing(5). Caret in the appended trailing body → flat 5.
        assertCollapseCaret(canvas([body("a", "ab"), quote("q", "hello")]), collapseAt: 1, expectedFlat: 5)
    }

    func test_collapse_quoteOnly_caretAfterIsRenderable() {
        // Lone quote → [collapsed, body""(trailing)]. flat: placeholder(0) "\n" trailing(2). Caret in the
        // appended trailing body → flat 2.
        assertCollapseCaret(canvas([quote("q", "hello")]), collapseAt: 0, expectedFlat: 2)
    }

    func test_collapse_quoteThenBody_caretAfterIsRenderable() {
        // [quote, body"cd"] → [collapsed, body"cd"]. flat: placeholder(0) "\n" "cd"(2). Caret at the start of
        // the existing following body → flat 2.
        assertCollapseCaret(canvas([quote("q", "hello"), body("b", "cd")]), collapseAt: 0, expectedFlat: 2)
    }
}
#endif
