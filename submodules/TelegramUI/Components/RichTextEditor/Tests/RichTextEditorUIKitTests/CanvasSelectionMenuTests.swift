#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CanvasSelectionMenuTests: XCTestCase {
    func cell(_ id: String, _ t: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: t)]))])
    }
    /// [ paragraph "Hello world", table( "Alpha" | "Beta" ) ]
    func canvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("h"), runs: [TextRun(text: "Hello world")])),
            .table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
                rows: [Row(id: BlockID("r0"), cells: [cell("a", "Alpha"), cell("b", "Beta")])])),
        ], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        return v
    }
    func region(_ v: DocumentCanvasView, _ id: String) -> LeafTextRegion {
        v.allLeafRegions().first { $0.ref == .paragraph(BlockID(id)) }!
    }

    func test_tapOutcome_onCaret_togglesMenu() {
        let v = canvas()
        let r = region(v, "h"); v.anchor = r.globalStart + 3; v.head = r.globalStart + 3
        XCTAssertEqual(v.tapOutcome(forResolvedPosition: r.globalStart + 3), .toggleMenu)
    }
    func test_tapOutcome_elsewhere_movesCaret() {
        let v = canvas()
        let r = region(v, "h"); v.anchor = r.globalStart + 3; v.head = r.globalStart + 3
        XCTAssertEqual(v.tapOutcome(forResolvedPosition: r.globalStart + 6), .setCaret(r.globalStart + 6))
    }
    func test_tapOutcome_insideSelection_togglesMenu() {
        let v = canvas()
        let r = region(v, "h"); v.anchor = r.globalStart; v.head = r.globalStart + 5   // "Hello" selected
        // A tap INSIDE the selection toggles the menu and KEEPS the selection (does not collapse).
        XCTAssertEqual(v.tapOutcome(forResolvedPosition: r.globalStart + 2), .toggleMenu)
    }
    func test_tapOutcome_outsideSelection_setsCaret() {
        let v = canvas()
        let r = region(v, "h"); v.anchor = r.globalStart; v.head = r.globalStart + 3   // "Hel" selected
        // A tap OUTSIDE the selection collapses to a caret there.
        XCTAssertEqual(v.tapOutcome(forResolvedPosition: r.globalStart + 6), .setCaret(r.globalStart + 6))
    }
    /// Repro for the reported bug: tapping the MIDPOINT of the selection's highlight must NOT collapse it.
    /// Exercises the full single-tap handler (closestGlobalPosition → tapOutcome → toggle/setCaret), not
    /// just the pure tapOutcome. If this passes but the live app still collapses, the cause is the
    /// framework calling our selectedTextRange setter (not our handler).
    func test_performSingleTap_insideSelection_keepsSelection() {
        let v = canvas()
        let r = region(v, "h"); v.anchor = r.globalStart; v.head = r.globalStart + 5   // "Hello" selected
        let rects = v.selectionRects(globalFrom: v.selFrom, globalTo: v.selTo)
        XCTAssertFalse(rects.isEmpty, "selection should have a highlight rect")
        let mid = CGPoint(x: rects[0].midX, y: rects[0].midY)
        v.performSingleTap(at: mid)
        XCTAssertEqual(v.selFrom, r.globalStart, "tap inside the selection must keep it (not collapse)")
        XCTAssertEqual(v.selTo, r.globalStart + 5)
    }
    /// Flicker fix: a toggle-tap presents only when the menu is neither showing nor just-dismissed. The
    /// system auto-dismisses the menu on the tap (willDismiss → justDismissed) before our delayed handler
    /// runs, so `(menuVisible:false, justDismissed:true)` MUST dismiss (not re-present = the flicker).
    func test_menuToggleAction_suppressesRepresentRightAfterDismiss() {
        let v = canvas()
        XCTAssertEqual(v.menuToggleAction(menuVisible: false, justDismissed: false), .present)  // caret, no menu → show
        XCTAssertEqual(v.menuToggleAction(menuVisible: true,  justDismissed: false), .dismiss)  // menu up → hide
        XCTAssertEqual(v.menuToggleAction(menuVisible: false, justDismissed: true),  .dismiss)  // this tap closed it → don't reopen
        XCTAssertEqual(v.menuToggleAction(menuVisible: true,  justDismissed: true),  .dismiss)
    }
    func test_selectWord_atCaret_selectsWord() {
        let v = canvas()
        let r = region(v, "h"); v.selectWord(at: r.globalStart + 2)   // inside "Hello"
        XCTAssertEqual(v.selFrom, r.globalStart + 0)
        XCTAssertEqual(v.selTo, r.globalStart + 5)
    }
    func test_selectWord_insideCell() {
        let v = canvas()
        let a = region(v, "ap")
        v.selectWord(at: a.globalStart + 1)   // inside "Alpha"
        XCTAssertEqual(v.selFrom, a.globalStart)
        XCTAssertEqual(v.selTo, a.globalStart + 5)
    }
    func test_selectParagraph_selectsWholeRegion() {
        let v = canvas()
        let r = region(v, "h"); v.selectParagraph(at: r.globalStart + 4)
        XCTAssertEqual(v.selFrom, r.globalStart)
        XCTAssertEqual(v.selTo, r.globalStart + r.length)   // "Hello world"
    }

    // MARK: Tap latency fix — manual multi-tap escalation (no `require(toFail:)` gate → instant caret).
    // handleTap counts taps itself with an injected timestamp, so caret/word/paragraph is deterministic.
    private func tapPoint(_ v: DocumentCanvasView, _ r: LeafTextRegion, offset: Int) -> CGPoint {
        let caret = v.caretRect(for: DocumentTextPosition(r.globalStart + offset))
        return CGPoint(x: caret.midX, y: caret.midY)
    }
    func test_handleTap_singleTap_placesCollapsedCaret() {
        let v = canvas()
        let r = region(v, "h")
        v.handleTap(at: tapPoint(v, r, offset: 2), time: 100)
        XCTAssertEqual(v.selFrom, v.selTo, "a single tap is a collapsed caret")
        XCTAssertGreaterThanOrEqual(v.selFrom, r.globalStart)
        XCTAssertLessThanOrEqual(v.selFrom, r.globalStart + r.length)
    }
    func test_handleTap_quickSecondTap_selectsWord() {
        let v = canvas()
        let r = region(v, "h")
        let p = tapPoint(v, r, offset: 2)
        v.handleTap(at: p, time: 100)
        v.handleTap(at: p, time: 100.1)   // within multiTapWindow, same point → escalate to word
        XCTAssertEqual(v.selFrom, r.globalStart, "the quick second tap selects the word 'Hello'")
        XCTAssertEqual(v.selTo, r.globalStart + 5)
    }
    func test_handleTap_slowSecondTap_isFreshCaretNotWord() {
        let v = canvas()
        let r = region(v, "h")
        let p = tapPoint(v, r, offset: 2)
        v.handleTap(at: p, time: 100)
        v.handleTap(at: p, time: 100 + DocumentCanvasView.multiTapWindow + 0.5)   // past the window
        XCTAssertEqual(v.selFrom, v.selTo, "a tap past the multi-tap window is a fresh caret, not a word")
    }
    func test_handleTap_tripleTap_selectsParagraph() {
        let v = canvas()
        let r = region(v, "h")
        let p = tapPoint(v, r, offset: 4)
        v.handleTap(at: p, time: 100)
        v.handleTap(at: p, time: 100.1)
        v.handleTap(at: p, time: 100.2)   // third quick tap → whole paragraph
        XCTAssertEqual(v.selFrom, r.globalStart)
        XCTAssertEqual(v.selTo, r.globalStart + r.length)
    }
    func test_selectAllText_selectsRenderableBounds() {
        let v = canvas()
        v.selectAllText()
        XCTAssertEqual(v.selFrom, (v.beginningOfDocument as! DocumentTextPosition).offset)
        XCTAssertEqual(v.selTo, (v.endOfDocument as! DocumentTextPosition).offset)
        XCTAssertLessThan(v.selFrom, v.selTo)
    }
    func test_selectWordParagraph_atImageGap_isNoOp() {
        let v = DocumentCanvasView()
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hi")])),
            .image(ImageBlock(id: BlockID("img"), assetID: "x", naturalSize: Size2D(width: 40, height: 40))),
        ], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        let gap = v.boxes.first { $0 is ImageBlockBox }!.nodeStart
        v.anchor = gap; v.head = gap
        v.selectWord(at: gap)
        XCTAssertEqual(v.selFrom, gap); XCTAssertEqual(v.selTo, gap)   // no word at a structural gap → unchanged
        v.selectParagraph(at: gap)
        XCTAssertEqual(v.selFrom, gap); XCTAssertEqual(v.selTo, gap)
    }

    func test_canPerformAction_select_onlyWhenCollapsedWithText() {
        let v = canvas()
        let r = region(v, "h"); v.anchor = r.globalStart + 2; v.head = r.globalStart + 2   // collapsed
        XCTAssertTrue(v.canPerformAction(#selector(UIResponderStandardEditActions.select(_:)), withSender: nil))
        v.anchor = r.globalStart; v.head = r.globalStart + 5                                 // selection
        XCTAssertFalse(v.canPerformAction(#selector(UIResponderStandardEditActions.select(_:)), withSender: nil))
    }
    func test_canPerformAction_select_disabledOnImageGap() {
        let v = DocumentCanvasView()
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hi")])),
            .image(ImageBlock(id: BlockID("img"), assetID: "x", naturalSize: Size2D(width: 40, height: 40))),
        ], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        let gap = v.boxes.first { $0 is ImageBlockBox }!.nodeStart
        v.anchor = gap; v.head = gap
        XCTAssertFalse(v.canPerformAction(#selector(UIResponderStandardEditActions.select(_:)), withSender: nil),
                       "Select is meaningless at an image gap (no word)")
    }
    func test_canPerformAction_selectAll_whenNotAllSelected() {
        let v = canvas()
        let r = region(v, "h"); v.anchor = r.globalStart; v.head = r.globalStart + 2
        XCTAssertTrue(v.canPerformAction(#selector(UIResponderStandardEditActions.selectAll(_:)), withSender: nil))
        v.selectAllText()
        XCTAssertFalse(v.canPerformAction(#selector(UIResponderStandardEditActions.selectAll(_:)), withSender: nil))
    }
    func test_selectAction_selectsWordAtCaret() {
        let v = canvas()
        let r = region(v, "h"); v.anchor = r.globalStart + 8; v.head = r.globalStart + 8   // inside "world"
        v.select(nil)
        XCTAssertEqual(v.selFrom, r.globalStart + 6)   // "world" starts after "Hello "
        XCTAssertEqual(v.selTo, r.globalStart + 11)
    }
    func test_selectAllText_emptyDocument_doesNotCrashAndCollapses() {
        let v = DocumentCanvasView()
        v.setBlocks([], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        v.selectAllText()
        XCTAssertEqual(v.selFrom, v.selTo)   // nothing renderable to select
    }

    func test_nearerSelectionEndpoint_picksByDistance() {
        let v = canvas()
        let r = region(v, "h"); v.anchor = r.globalStart + 2; v.head = r.globalStart + 8
        XCTAssertEqual(v.nearerSelectionEndpoint(toGlobal: r.globalStart + 7), .head)
        XCTAssertEqual(v.nearerSelectionEndpoint(toGlobal: r.globalStart + 3), .anchor)
    }
    func test_nearerSelectionEndpoint_nilWhenCollapsed() {
        let v = canvas()
        let r = region(v, "h"); v.anchor = r.globalStart + 4; v.head = r.globalStart + 4
        XCTAssertNil(v.nearerSelectionEndpoint(toGlobal: r.globalStart + 4))
    }
}
#endif
