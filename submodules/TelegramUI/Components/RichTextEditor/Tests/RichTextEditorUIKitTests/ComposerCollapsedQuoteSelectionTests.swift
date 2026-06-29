#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// A `CollapsedQuoteBox` is an off-the-editable-axis ATOM (`leafRegions() == []`), yet on the chat
/// composer's flat UTF-16 axis it MUST contribute exactly ONE placeholder char so the editor's flat
/// space stays 1:1 with `ChatInputContent.collapsedQuote` (where `blockFlatLength == 1`, `plainText`
/// emits `" "`). Without it the composer caret drifts past a collapsed quote. These tests pin the
/// flat-axis contribution (`composerSelectedRange`) and the caret mapping on BOTH sides of the atom.
final class ComposerCollapsedQuoteSelectionTests: XCTestCase {
    private func canvas(_ blocks: [Block], width: CGFloat = 300) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks(blocks, width: width)
        v.frame = CGRect(x: 0, y: 0, width: width, height: 600); v.layoutIfNeeded()
        return v
    }
    private func body(_ id: String, _ t: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), style: .body, runs: [TextRun(text: t)]))
    }
    private func collapsed(_ id: String) -> Block {
        .collapsedQuote(CollapsedQuote(id: BlockID(id),
                                       paragraphs: [ParagraphBlock(id: BlockID(id + "p"),
                                                                   style: .quote,
                                                                   runs: [TextRun(text: "folded")])]))
    }

    // Flat layout: "ab" + "\n" + " "(collapsed) + "\n" + "cd"  →  total length 2 + 1 + 1 + 1 + 2 = 7.
    func test_collapsedQuote_contributesExactlyOneFlatChar() {
        let v = canvas([body("a", "ab"), collapsed("q"), body("c", "cd")])
        // Select the whole flat document (begin..end of document, snapped to renderable).
        v.selectAllText()
        XCTAssertEqual(v.composerSelectedRange.length, 7,
                       "ab(2) + '\\n'(1) + collapsed(1) + '\\n'(1) + cd(2) = 7 flat chars")
    }

    // A caret at the START of the paragraph AFTER the collapsed quote must map past it: flat offset 5
    // (= "ab"(2) + '\n'(1) + collapsed(1) + '\n'(1)). With a length-0 collapsed segment the getter does
    // NOT mis-claim this real renderable caret — the regression the brief warned about.
    func test_caretAfterCollapsedQuote_mapsToCorrectFlatOffset() {
        let v = canvas([body("a", "ab"), collapsed("q"), body("c", "cd")])
        v.anchor = v.boxes[2].textStart
        v.head   = v.boxes[2].textStart
        XCTAssertEqual(v.composerSelectedRange.location, 5,
                       "caret at start of 'cd' (after the collapsed quote) is flat offset 5")
    }

    // A caret at the END of the paragraph BEFORE the collapsed quote maps to flat offset 2 (still inside
    // the "ab" segment — the collapsed segment, anchored later on the global axis, must not steal it).
    func test_caretBeforeCollapsedQuote_mapsToCorrectFlatOffset() {
        let v = canvas([body("a", "ab"), collapsed("q"), body("c", "cd")])
        v.anchor = v.boxes[0].textStart + v.boxes[0].textLength
        v.head   = v.boxes[0].textStart + v.boxes[0].textLength
        XCTAssertEqual(v.composerSelectedRange.location, 2,
                       "caret at end of 'ab' (before the collapsed quote) is flat offset 2")
    }

    // Fix 1 regression guard: setting the composer selection to flat offset 4 — the "\n" character
    // immediately AFTER the collapsed quote — formerly mapped to global nodeStart+1 inside the atom
    // (non-renderable), causing the getter to fall through to end-of-document (flat 7). After the fix
    // the setter snaps forward via snapToRenderable(_:forward:true) to boxes[2].textStart (start of
    // "cd"), which the getter reports back as flat 5.
    func test_setNonRenderableFlatOffset_snapsToNextRenderable() {
        let v = canvas([body("a", "ab"), collapsed("q"), body("c", "cd")])
        v.composerSelectedRange = NSRange(location: 4, length: 0)   // "\n" just after the collapsed quote
        XCTAssertEqual(v.composerSelectedRange.location, 5,
                       "flat 4 (non-renderable) must snap forward to flat 5 (start of 'cd'), not end-of-document (7)")
        XCTAssertNotEqual(v.composerSelectedRange.location, 7,
                          "getter must not fall through to end-of-document after snap")
        XCTAssertEqual(v.head, v.boxes[2].textStart,
                       "head must land at boxes[2].textStart (start of 'cd') after forward snap")
    }

    // Set→get round-trips for the renderable carets on either side of the collapsed quote.
    func test_setCaret_eitherSideOfCollapsedQuote_roundTrips() {
        let v = canvas([body("a", "ab"), collapsed("q"), body("c", "cd")])
        v.composerSelectedRange = NSRange(location: 2, length: 0)   // end of "ab", before collapsed
        XCTAssertEqual(v.head, v.boxes[0].textStart + v.boxes[0].textLength)
        XCTAssertEqual(v.composerSelectedRange, NSRange(location: 2, length: 0))

        v.composerSelectedRange = NSRange(location: 5, length: 0)   // start of "cd", after collapsed
        XCTAssertEqual(v.head, v.boxes[2].textStart)
        XCTAssertEqual(v.composerSelectedRange, NSRange(location: 5, length: 0))
    }
}
#endif
