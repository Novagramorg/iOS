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
}
#endif
