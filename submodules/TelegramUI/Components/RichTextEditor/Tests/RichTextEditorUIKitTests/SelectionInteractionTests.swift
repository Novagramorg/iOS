#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class SelectionInteractionTests: XCTestCase {
    /// Keeps the test window alive for the duration of a test (a view only becomes first responder once it's
    /// in a window). Recreated per test via `setUp`.
    private var window: UIWindow!

    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        window.makeKeyAndVisible()
    }
    override func tearDown() {
        window.isHidden = true
        window = nil
        super.tearDown()
    }

    /// Adds `v` to the key window (so `becomeFirstResponder` can succeed) and lays it out.
    private func hostInWindow(_ v: DocumentCanvasView) {
        window.addSubview(v)
        v.layoutIfNeeded()
    }

    private func canvasWithInteraction() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hello world")]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 200)
        v.installSelectionInteractions()
        hostInWindow(v)
        return v
    }

    /// A canvas with a leading paragraph + a wide (horizontally-scrollable) table, sized so the table
    /// overflows the canvas width (7 columns × 100pt grid columns in a 390pt-wide canvas → scrolls).
    private func canvasWithWideTable() -> (canvas: DocumentCanvasView, table: TableBlockBox) {
        func cell(_ id: String, _ text: String) -> Cell {
            Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID("\(id)p"), runs: [TextRun(text: text)]))])
        }
        let cols = (0..<7).map { _ in ColumnSpec(width: 100) }
        let header = Row(id: BlockID("hr"), isHeader: true, cells: (0..<7).map { cell("h\($0)", "H\($0)") })
        let body = Row(id: BlockID("br"), cells: (0..<7).map { cell("b\($0)", "B\($0)") })
        let table = TableBlock(id: BlockID("wt"), columns: cols, rows: [header, body])
        let v = DocumentCanvasView()
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Lead paragraph")])),
            .table(table),
        ], width: 390)
        v.frame = CGRect(x: 0, y: 0, width: 390, height: 600)
        v.installSelectionInteractions()
        hostInWindow(v)
        let box = v.boxes.compactMap { $0 as? TableBlockBox }.first { $0.id == BlockID("wt") }!
        return (v, box)
    }

    // MARK: - No OS selection-display interaction (app draws everything itself)

    func test_noSelectionDisplayInteraction_isInstalled() {
        // The canvas owns every selection visual (caret/wash/handles), so it must NOT attach a
        // `UITextSelectionDisplayInteraction`. On iOS 18+ that interaction installs its own default selection
        // chrome (`_UITextSelectionLollipopView`/highlight/cursor) that custom no-draw replacement views no
        // longer suppress — the default lollipops leak at the container origin (handle knobs at ~CGPoint.zero).
        let v = canvasWithInteraction()
        if #available(iOS 17.0, *) {   // the type itself is iOS 17+ (it's what we assert we DON'T install)
            XCTAssertFalse(v.interactions.contains { $0 is UITextSelectionDisplayInteraction },
                           "no UITextSelectionDisplayInteraction (its default handle chrome would leak at the origin)")
        }
    }

    func test_appDrawsItsOwnHandles_forARangedSelection() {
        // The app draws handles itself so they ride a table's horizontal scroll/overscroll. With no OS
        // interaction, these own-drawn `SelectionHandleView`s are the ONLY handles.
        let v = canvasWithInteraction()
        _ = v.becomeFirstResponder()
        v.anchor = v.boxes[0].textStart; v.setSelectionHead(global: v.boxes[0].textStart + 5)
        XCTAssertFalse(v.startHandleView.isHidden, "the app's own start handle shows for a range")
        XCTAssertFalse(v.endHandleView.isHidden, "the app's own end handle shows for a range")
    }

    // MARK: - Own-drawn caret

    func test_appDrawsItsOwnCaret_forACollapsedSelection() {
        // We draw the caret ourselves (a `CaretView`) so it rides a table's horizontal scroll/overscroll;
        // there is no OS cursor view to compete with it.
        let v = canvasWithInteraction()
        _ = v.becomeFirstResponder()
        v.setCaret(global: v.boxes[0].textStart + 2)
        XCTAssertFalse(v.caretView.isHidden, "the app's own caret shows for a collapsed selection")
        XCTAssertTrue(v.caretView.superview === v, "a paragraph caret is hosted on the canvas")
    }

    func test_caretInWideTableCell_isHostedInsideTheTableContentView_andBlinks() {
        let (v, table) = canvasWithWideTable()
        _ = v.becomeFirstResponder()
        let target = table.cellTextStart(row: 1, column: 0)!
        v.setCaret(global: target)

        // The caret view rides the scroll: it lives inside the table's scrolling content view.
        XCTAssertTrue(v.caretView.superview is TableContentView,
                      "a caret inside a table cell is hosted in the table's scrolling content view")

        // Its frame ≈ the cell caret in content-local coords (unscrolled canvas − table.frame.origin).
        let (region, local) = v.leafRegion(containingGlobal: target)!
        let expected = region.layout.caretRect(atOffset: local)
            .offsetBy(dx: region.canvasOrigin.x - table.frame.minX,
                      dy: region.canvasOrigin.y - table.frame.minY)
        XCTAssertEqual(v.caretView.frame.minX, expected.minX, accuracy: 0.5)
        XCTAssertEqual(v.caretView.frame.minY, expected.minY, accuracy: 0.5)
        XCTAssertEqual(v.caretView.frame.height, expected.height, accuracy: 0.5)

        // A blink animation is running.
        XCTAssertFalse(v.caretView.layer.animationKeys()?.isEmpty ?? true,
                       "the caret view blinks (has a running opacity animation)")
    }

    func test_caretInParagraph_isHostedOnTheCanvas() {
        let (v, _) = canvasWithWideTable()
        _ = v.becomeFirstResponder()
        v.setCaret(global: v.boxes[0].textStart + 2)   // inside the lead paragraph

        XCTAssertTrue(v.caretView.superview === v, "a paragraph caret is hosted directly on the canvas")
        let (region, local) = v.leafRegion(containingGlobal: v.head)!
        let expected = region.layout.caretRect(atOffset: local)
            .offsetBy(dx: region.canvasOrigin.x, dy: region.canvasOrigin.y)
        XCTAssertEqual(v.caretView.frame.minX, expected.minX, accuracy: 0.5)
        XCTAssertEqual(v.caretView.frame.minY, expected.minY, accuracy: 0.5)
    }

    func test_caretHidden_whenRangedSelection() {
        let (v, _) = canvasWithWideTable()
        _ = v.becomeFirstResponder()
        v.anchor = v.boxes[0].textStart
        v.setSelectionHead(global: v.boxes[0].textStart + 4)   // a ranged (non-collapsed) selection
        XCTAssertTrue(v.caretView.isHidden || v.caretView.superview == nil,
                      "no blinking caret while a range is selected")
    }

    func test_caretHidden_whenStructuralTableSelection() {
        let (v, _) = canvasWithWideTable()
        _ = v.becomeFirstResponder()
        v.selectTableColumns(0...0)   // structural row/column selection → outline is the indicator, no caret
        XCTAssertTrue(v.caretView.isHidden || v.caretView.superview == nil,
                      "no blinking caret while a table row/column is structurally selected")
    }

    func test_updateCaretView_isIdempotent_doesNotRestartBlinkOnNoOp() {
        // Re-running updateCaretView with the SAME caret (e.g. on a scroll tick) must NOT restart the
        // blink — otherwise the caret would never finish a blink cycle while the table scrolls.
        let (v, table) = canvasWithWideTable()
        _ = v.becomeFirstResponder()
        v.setCaret(global: table.cellTextStart(row: 1, column: 0)!)
        let resetsAfterFirst = v.caretView.blinkResetCount
        v.updateCaretView()
        v.updateCaretView()
        XCTAssertEqual(v.caretView.blinkResetCount, resetsAfterFirst,
                       "a no-op updateCaretView (same container + frame) does not restart the blink")
    }

    // MARK: - Selection-handle drag auto-scrolls the document vertically near the viewport edge

    /// Tall content inside a short scroll view so a selection-handle drag has vertical room to scroll.
    private func tallCanvasInScroll() -> (canvas: DocumentCanvasView, scroll: UIScrollView) {
        let scroll = UIScrollView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        let v = DocumentCanvasView()
        v.setBlocks((0..<40).map {
            .paragraph(ParagraphBlock(id: BlockID("p\($0)"), runs: [TextRun(text: "Line \($0)")]))
        }, width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 1600)
        scroll.addSubview(v); scroll.contentSize = v.frame.size; v.layoutIfNeeded()
        return (v, scroll)
    }

    func test_dragAutoScroll_scrollsDocumentDown_whenHandleNearsBottomEdge() {
        let (v, scroll) = tallCanvasInScroll()
        // A non-collapsed selection whose HEAD we drag toward the bottom edge (no table involved).
        v.anchor = v.boxes[0].textStart
        v.head = v.boxes[1].textStart
        let beforeY = scroll.contentOffset.y
        let beforeHead = v.head

        // A drag point in the viewport's bottom band (band = 60 of the 200pt viewport), in canvas coords.
        let bottomBand = CGPoint(x: 40, y: scroll.contentOffset.y + 190)
        v.updateDragAutoScroll(point: bottomBand, headInTable: false)
        for _ in 0..<5 { v.dragAutoScrollTick() }

        XCTAssertGreaterThan(scroll.contentOffset.y, beforeY,
                             "dragging a selection handle near the bottom edge scrolls the document down")
        XCTAssertNotEqual(v.head, beforeHead,
                          "the selection head re-extends to the content under the finger as it scrolls")
        v.stopDragAutoScroll()
        let maxY = scroll.contentSize.height - scroll.bounds.height
        XCTAssertLessThanOrEqual(scroll.contentOffset.y, maxY + 0.5, "clamped to the max content offset")
    }

    func test_dragAutoScroll_scrollsDocumentUp_whenHandleNearsTopEdge() {
        let (v, scroll) = tallCanvasInScroll()
        scroll.contentOffset.y = 800   // scrolled into the middle so there is room to scroll UP
        v.anchor = v.boxes[20].textStart
        v.head = v.boxes[20].textStart + 1
        let beforeY = scroll.contentOffset.y

        // A drag point in the viewport's top band, in canvas coords.
        let topBand = CGPoint(x: 40, y: scroll.contentOffset.y + 10)
        v.updateDragAutoScroll(point: topBand, headInTable: false)
        for _ in 0..<5 { v.dragAutoScrollTick() }

        XCTAssertLessThan(scroll.contentOffset.y, beforeY,
                          "dragging a selection handle near the top edge scrolls the document up")
        v.stopDragAutoScroll()
        XCTAssertGreaterThanOrEqual(scroll.contentOffset.y, -0.5, "clamped to zero")
    }

    func test_dragAutoScroll_reextendsTheDraggedAnchor_notTheHead() {
        let (v, scroll) = tallCanvasInScroll()
        // A range selection, then grab the ANCHOR (start) handle and drag it toward the bottom edge. The
        // auto-scroller must re-extend the endpoint being dragged (the anchor), leaving the head put.
        v.anchor = v.boxes[2].textStart
        v.head = v.boxes[1].textStart
        v.draggingEndpoint = .anchor
        let headBefore = v.head
        let anchorBefore = v.anchor

        let bottomBand = CGPoint(x: 40, y: scroll.contentOffset.y + 190)
        v.updateDragAutoScroll(point: bottomBand, headInTable: false)
        for _ in 0..<5 { v.dragAutoScrollTick() }

        XCTAssertGreaterThan(scroll.contentOffset.y, 0, "the document scrolls while dragging the anchor near the edge")
        XCTAssertNotEqual(v.anchor, anchorBefore, "the dragged ANCHOR re-extends as the document scrolls")
        XCTAssertEqual(v.head, headBefore, "the head (the endpoint NOT being dragged) stays put")
        v.stopDragAutoScroll()
        v.draggingEndpoint = nil
    }

    func test_dragAutoScroll_doesNotScroll_whenHandleInViewportMiddle() {
        let (v, scroll) = tallCanvasInScroll()
        v.anchor = v.boxes[0].textStart
        v.head = v.boxes[1].textStart
        let beforeY = scroll.contentOffset.y

        // A point in the middle of the viewport must not start the auto-scroller.
        v.updateDragAutoScroll(point: CGPoint(x: 40, y: scroll.contentOffset.y + 100), headInTable: false)
        XCTAssertNil(v.dragAutoScrollLink, "no auto-scroll link starts for a mid-viewport handle")
        for _ in 0..<5 { v.dragAutoScrollTick() }
        XCTAssertEqual(scroll.contentOffset.y, beforeY, accuracy: 0.5, "no scroll when the handle is mid-viewport")
        v.stopDragAutoScroll()
    }
}
#endif
