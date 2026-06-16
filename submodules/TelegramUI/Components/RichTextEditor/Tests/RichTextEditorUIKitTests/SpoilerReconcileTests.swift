#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class SpoilerReconcileTests: XCTestCase {
    /// True iff a display-only clear foreground covers the local offset (i.e. the spoiler text is hidden).
    private func isHiddenClear(_ layout: BlockLayout, atLocal offset: Int) -> Bool {
        var hidden = false
        let docStart = layout.contentStorage.documentRange.location
        layout.layoutManager.enumerateRenderingAttributes(from: docStart, reverse: false) { _, attrs, range in
            guard (attrs[.foregroundColor] as? UIColor) == .clear else { return true }
            let s = layout.contentStorage.offset(from: docStart, to: range.location)
            let e = layout.contentStorage.offset(from: docStart, to: range.endLocation)
            if offset >= s && offset < e { hidden = true; return false }
            return true
        }
        return hidden
    }

    /// Reveal must remove the clear-foreground hide AND bump renderVersion so the backing view repaints the
    /// text (the "text doesn't display on reveal" regression — the dust dissolved to nothing before this).
    func test_reveal_removesHide_andBumpsRenderVersion_soTextRepaints() {
        let c = DocumentCanvasView()
        c.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "open secret end")]))], width: 320)
        c.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        c.layoutIfNeeded()
        c.simulateParentLayout()
        let start = c.boxes[0].textStart
        c.anchor = start + 5; c.head = start + 11      // "secret"
        c.toggleSpoiler()
        c.anchor = start; c.head = start               // caret outside → hidden
        c.layoutIfNeeded()
        let layout = c.boxes[0].textLayout
        XCTAssertTrue(isHiddenClear(layout, atLocal: 7), "hidden spoiler text is drawn clear")
        let beforeReveal = layout.renderVersion
        c.anchor = start + 7; c.head = start + 7       // caret inside → reveal
        c.refreshSelectionUI()
        XCTAssertFalse(isHiddenClear(layout, atLocal: 7), "revealed text is no longer clear → it renders")
        XCTAssertGreaterThan(layout.renderVersion, beforeReveal, "reveal bumps renderVersion → paragraph repaints")
    }

    /// A canvas whose first paragraph is "open secret end" with "secret" marked spoiler, caret parked at 0.
    private func canvasWithSpoiler() -> DocumentCanvasView {
        let c = DocumentCanvasView()
        c.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "open secret end")]))], width: 320)
        c.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        c.layoutIfNeeded()
        c.simulateParentLayout()
        let start = c.boxes[0].textStart
        c.anchor = start + 5; c.head = start + 11      // "secret"
        c.toggleSpoiler()
        c.anchor = start; c.head = start               // caret at the very start (outside the spoiler)
        c.layoutIfNeeded()
        return c
    }

    func test_spoilerHidden_whenCaretOutside_dustRealized() {
        let c = canvasWithSpoiler()
        XCTAssertEqual(c.spoilerRunsForTesting.count, 1)
        XCTAssertTrue(c.spoilerRunsForTesting[0].hidden)
        XCTAssertEqual(c.spoilerDustCountForTesting, 1)
        XCTAssertNotNil(c.firstSpoilerDustForTesting?.superview)
    }

    func test_spoilerRevealed_whenCaretInside_noDust() {
        let c = canvasWithSpoiler()
        let start = c.boxes[0].textStart
        c.anchor = start + 7; c.head = start + 7       // inside "secret"
        c.refreshSelectionUI()
        XCTAssertFalse(c.spoilerRunsForTesting[0].hidden)
        XCTAssertEqual(c.spoilerDustCountForTesting, 0)
    }

    func test_spoilerRevealed_whenSelectionOverlaps() {
        let c = canvasWithSpoiler()
        let start = c.boxes[0].textStart
        c.anchor = start; c.head = start + 7           // selection crosses into "secret"
        c.refreshSelectionUI()
        XCTAssertFalse(c.spoilerRunsForTesting[0].hidden)
    }

    func test_dust_culledWhenOffscreen() {
        let c = canvasWithSpoiler()
        let dust = c.firstSpoilerDustForTesting
        c.cullSpoilerDust(visibleRect: CGRect(x: 0, y: 0, width: 320, height: 8))  // spoiler ~ line 1
        XCTAssertFalse(dust?.isHidden ?? true)
        c.cullSpoilerDust(visibleRect: CGRect(x: 0, y: 5000, width: 320, height: 50))
        XCTAssertTrue(dust?.isHidden ?? false)
    }

    func test_setBlocks_tearsDownDust() {
        let c = canvasWithSpoiler()
        XCTAssertEqual(c.spoilerDustCountForTesting, 1)
        c.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p2"), runs: [TextRun(text: "plain")]))], width: 320)
        c.layoutIfNeeded()
        XCTAssertEqual(c.spoilerDustCountForTesting, 0)
    }

    func test_syncSpoilers_noSpoilerDoc_doesNotBumpAnyRenderVersion_onCaretMove() {
        let c = DocumentCanvasView()
        c.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "plain text here")]))], width: 320)
        c.frame = CGRect(x: 0, y: 0, width: 320, height: 400); c.layoutIfNeeded()
        XCTAssertFalse(c.documentHasSpoilers)
        let before = c.boxes[0].textLayout.renderVersion
        // Simulate caret moves (the per-keystroke/arrow path).
        for i in 0..<5 { c.anchor = c.boxes[0].textStart + i; c.head = c.anchor; c.refreshSelectionUI() }
        XCTAssertEqual(c.boxes[0].textLayout.renderVersion, before, "caret moves in a spoiler-free doc must not bump renderVersion")
    }

    func test_documentHasSpoilers_trueAfterToggle_falseAfterRemoval() {
        let c = DocumentCanvasView()
        c.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "secret")]))], width: 320)
        c.frame = CGRect(x: 0, y: 0, width: 320, height: 400); c.layoutIfNeeded()
        XCTAssertFalse(c.documentHasSpoilers)
        c.anchor = c.boxes[0].textStart; c.head = c.boxes[0].textStart + 6
        c.toggleSpoiler()
        XCTAssertTrue(c.documentHasSpoilers, "flag set after spoilering")
        c.anchor = c.boxes[0].textStart; c.head = c.boxes[0].textStart + 6
        c.toggleSpoiler()
        XCTAssertFalse(c.documentHasSpoilers, "flag cleared after the last spoiler is removed")
        c.layoutIfNeeded()
        XCTAssertEqual(c.spoilerDustCountForTesting, 0, "the residual-clear pass tore down the dust")
    }
}
#endif
