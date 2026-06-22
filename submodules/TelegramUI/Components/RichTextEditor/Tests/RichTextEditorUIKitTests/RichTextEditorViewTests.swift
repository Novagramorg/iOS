#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class RichTextEditorViewTests: XCTestCase {
    // The façade surfaces first-responder transitions so a host can react (show/hide a panel). Each
    // callback fires ONCE on the genuine transition — gaining focus, then losing it — and NOT on a
    // redundant becomeFirstResponder() while already focused (the canvas calls that on every tap).
    func test_firstResponderCallbacks_fireOnceOnTransition_notWhenAlreadyFocused() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let editor = RichTextEditorView(frame: window.bounds)
        window.addSubview(editor)
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hi")]))])
        editor.layoutIfNeeded()

        var becameCount = 0, resignedCount = 0
        editor.onBecameFirstResponder = { becameCount += 1 }
        editor.onResignedFirstResponder = { resignedCount += 1 }

        XCTAssertTrue(editor.becomeFirstResponder())
        XCTAssertEqual(becameCount, 1, "fires when the editor gains focus")
        XCTAssertEqual(resignedCount, 0)

        _ = editor.becomeFirstResponder()                       // already focused → no real transition
        XCTAssertEqual(becameCount, 1, "does not re-fire while already first responder")

        XCTAssertTrue(editor.canvas.resignFirstResponder())
        XCTAssertEqual(resignedCount, 1, "fires when the editor loses focus")
        XCTAssertEqual(becameCount, 1, "losing focus does not fire the became callback")
    }

    // A content-height change after an edit re-flows the host layout (canvas frame), not only on the
    // next external layout pass (e.g. a rotation). Pre-fix the edit never marked the host dirty, so a
    // normal layout pass left the canvas at its old height. (The canvas also fills at least the viewport
    // for hit-testing, so this uses a minimal-height editor — there the canvas tracks the content height.)
    func test_editGrowingContent_reflowsCanvasHeight() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hello")]))])
        editor.layoutIfNeeded()
        let before = editor.canvas.frame.height
        // Simulate the host: re-run layout via update() whenever the editor reports a change. The editor no
        // longer self-schedules layout — it notifies (onChange) and the host (parent) drives layout.
        editor.onChange = { [weak editor] in guard let editor else { return }; _ = editor.update(size: editor.bounds.size, insets: .zero) }
        // Add a paragraph at the end (Enter) → taller content; the edit's onChange drives the host re-layout.
        editor.canvas.selectedTextRange = DocumentTextRange(DocumentTextPosition(editor.canvas.documentSizeValue),
                                                            DocumentTextPosition(editor.canvas.documentSizeValue))
        editor.canvas.insertText("\n")
        XCTAssertGreaterThan(editor.canvas.frame.height, before,
                             "host re-sizes the canvas when content height grows after an edit")
    }

    func test_tapsInEmptyAreaBelowContent_landOnTheCanvas() {
        // The tap/long-press/loupe recognizers live on the canvas, so the canvas must cover the whole
        // viewport — otherwise a tap in the empty area below a short document reaches the inert scroll view
        // and nothing happens (no caret, no loupe). Regression: the canvas used to hug the content height,
        // so only taps ON the text (the short content rect) registered.
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hi")]))])
        editor.layoutIfNeeded()
        XCTAssertLessThan(editor.canvas.intrinsicContentSize.height, 200,
                          "precondition: the content is much shorter than the 400pt editor")
        // The canvas (which owns the gesture recognizers) fills at least the viewport.
        XCTAssertGreaterThanOrEqual(editor.canvas.frame.height, editor.bounds.height,
                                    "canvas fills the viewport so taps below the content still reach its recognizers")
        // A point in the empty area far below the text hit-tests into the canvas, not the inert scroll view.
        let emptyPoint = CGPoint(x: 20, y: 360)
        let hit = editor.hitTest(emptyPoint, with: nil)
        XCTAssertTrue(hit === editor.canvas || (hit?.isDescendant(of: editor.canvas) ?? false),
                      "a tap far below the text lands on the canvas (the gesture target), not the scroll view")
    }

    func test_shortContent_scrollContentFillsVisibleArea_notFullFrame_underInsets() {
        // With a short document the canvas fills the viewport (for hit-testing), but it must fill the
        // VISIBLE area (frame − top − bottom inset), not the full frame — otherwise the scroll content is
        // top+bottom too tall and the view scrolls/bounces over empty space. It must also track inset changes.
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hi")]))])
        let insets = UIEdgeInsets(top: 40, left: 0, bottom: 100, right: 0)
        _ = editor.update(size: CGSize(width: 320, height: 480), insets: insets)
        XCTAssertEqual(editor.scrollContentHeightForTesting, 480 - 40 - 100, accuracy: 0.5,
                       "scroll content fills the visible area (frame − insets), so a short doc doesn't over-scroll")
        XCTAssertEqual(editor.canvas.frame.height, 480 - 40 - 100, accuracy: 0.5)
        // Updating the insets re-flows the content size (the reported 'doesn't update on inset change').
        _ = editor.update(size: CGSize(width: 320, height: 480), insets: .zero)
        XCTAssertEqual(editor.scrollContentHeightForTesting, 480, accuracy: 0.5,
                       "with no insets the visible area is the full frame")
    }

    func test_update_returnsMeasuredContentHeight() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hello")]))])
        // No layoutIfNeeded needed: update(size:insets:) drives its own layout pass via performLayout.
        let oneLine = editor.update(size: CGSize(width: 320, height: 400), insets: .zero)
        XCTAssertGreaterThan(oneLine, 0, "update returns the measured content height")
        // Growing the content increases the returned height.
        editor.canvas.selectedTextRange = DocumentTextRange(DocumentTextPosition(editor.canvas.documentSizeValue),
                                                            DocumentTextPosition(editor.canvas.documentSizeValue))
        editor.canvas.insertText("\nA second line")
        let twoLines = editor.update(size: CGSize(width: 320, height: 400), insets: .zero)
        XCTAssertGreaterThan(twoLines, oneLine, "more content → taller measured height")
    }

    func test_update_appliesBottomInset() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hi")]))])
        _ = editor.update(size: CGSize(width: 320, height: 400),
                          insets: UIEdgeInsets(top: 0, left: 0, bottom: 250, right: 0))
        XCTAssertEqual(editor.bottomContentInsetForTesting, 250, "update applies insets.bottom to the scroll view")
        _ = editor.update(size: CGSize(width: 320, height: 400), insets: .zero)
        XCTAssertEqual(editor.bottomContentInsetForTesting, 0, "zero insets clear the bottom inset")
    }

    func test_onChange_firesOnEdit() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hi")]))])
        editor.layoutIfNeeded()
        let end = DocumentTextPosition(editor.canvas.documentSizeValue)
        editor.canvas.selectedTextRange = DocumentTextRange(end, end)
        var fired = false
        editor.onChange = { fired = true }
        editor.canvas.insertText("X")
        XCTAssertTrue(fired, "a content edit fires onChange")
    }

    func test_onChange_firesOnSelectionMove() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hello")]))])
        editor.layoutIfNeeded()
        var fired = false
        editor.onChange = { fired = true }
        editor.canvas.selectedTextRange = DocumentTextRange(DocumentTextPosition(1), DocumentTextPosition(1))
        XCTAssertTrue(fired, "a caret/selection move fires onChange")
    }

    func test_onChange_firesOnFormattingToggle() {
        // Render-only formatting changes neither text length nor selection, but routes through editing { },
        // which fires onSelectionChange → onChange.
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hello")]))])
        editor.layoutIfNeeded()
        editor.canvas.selectedTextRange = DocumentTextRange(DocumentTextPosition(0),
                                                            DocumentTextPosition(editor.canvas.documentSizeValue))
        var fired = false
        editor.onChange = { fired = true }
        editor.toggleBold()
        XCTAssertTrue(fired, "a formatting toggle fires onChange")
    }

    // Loop-termination invariant: update(size:insets:) must NOT synchronously fire onChange. A host calls
    // update() from its onChange handler; if update re-fired onChange synchronously it would recurse.
    func test_update_doesNotSynchronouslyFireOnChange() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hello")]))])
        editor.layoutIfNeeded()   // settle layout so update() is a no-op resize, not a first layout
        var fired = false
        editor.onChange = { fired = true }
        _ = editor.update(size: CGSize(width: 320, height: 400), insets: .zero)
        XCTAssertFalse(fired, "update(size:insets:) must not synchronously fire onChange (else the host recurses)")
    }

    // Inset-ownership invariant: a plain layoutSubviews pass preserves the parent-applied inset (performLayout
    // sizes only; only update(size:insets:) writes insets).
    func test_layoutSubviews_preservesParentInset() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hi")]))])
        _ = editor.update(size: CGSize(width: 320, height: 400),
                          insets: UIEdgeInsets(top: 0, left: 0, bottom: 120, right: 0))
        XCTAssertEqual(editor.bottomContentInsetForTesting, 120)
        editor.setNeedsLayout(); editor.layoutIfNeeded()   // a system layout pass must not reset the inset
        XCTAssertEqual(editor.bottomContentInsetForTesting, 120, "layoutSubviews must preserve the parent inset")
    }

    // The canvas notifies its host whenever it invalidates its intrinsic content size.
    func test_canvas_notifiesHostOnContentSizeChange() {
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hi")]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 200); v.layoutIfNeeded()
        var fired = false
        v.onContentSizeChange = { fired = true }
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(v.documentSizeValue),
                                                DocumentTextPosition(v.documentSizeValue))
        v.insertText("\n")
        XCTAssertTrue(fired, "a height-changing edit notifies the host to re-layout")
    }
}

extension RichTextEditorViewTests {
    private func editorWithTable() -> RichTextEditorView {
        let e = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 600))
        e.document = Document(blocks: [
            .table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
                rows: [Row(id: BlockID("r0"), isHeader: true,
                           cells: [Cell(id: BlockID("a"), blocks: [.paragraph(ParagraphBlock(id: BlockID("ap"), runs: [TextRun(text: "Name")]))]),
                                   Cell(id: BlockID("b"), blocks: [.paragraph(ParagraphBlock(id: BlockID("bp"), runs: [TextRun(text: "Role")]))])]),
                       Row(id: BlockID("r1"),
                           cells: [Cell(id: BlockID("c"), blocks: [.paragraph(ParagraphBlock(id: BlockID("cp"), runs: [TextRun(text: "Ada")]))]),
                                   Cell(id: BlockID("d"), blocks: [.paragraph(ParagraphBlock(id: BlockID("dp"), runs: [TextRun(text: "Eng")]))])])])),
        ])
        e.layoutIfNeeded()
        return e
    }

    func test_facadeInsertTableRow_delegatesToCanvas() {
        let e = editorWithTable()
        let t = e.canvas.boxes.first as! TableBlockBox
        let pos = t.cellTextStart(row: 1, column: 0)!
        e.canvas.selectedTextRange = DocumentTextRange(DocumentTextPosition(pos), DocumentTextPosition(pos))
        e.insertTableRowBelow()
        e.layoutIfNeeded()
        XCTAssertEqual((e.canvas.boxes.first as! TableBlockBox).rowCount, 3)
    }

    func test_facadeSetColumnAlignment_delegatesToCanvas() {
        let e = editorWithTable()
        let t = e.canvas.boxes.first as! TableBlockBox
        let pos = t.cellTextStart(row: 1, column: 1)!
        e.canvas.selectedTextRange = DocumentTextRange(DocumentTextPosition(pos), DocumentTextPosition(pos))
        e.setTableColumnAlignment(.center)
        e.layoutIfNeeded()
        guard case .table(let out) = e.document.blocks.first(where: { if case .table = $0 { return true } else { return false } }) else { return XCTFail() }
        XCTAssertEqual(out.columns[1].alignment, .center)
    }

    func test_facadeDeleteTable_onlyBlock_leavesEmptyParagraph() {
        let e = editorWithTable()   // sole block is a table
        let t = e.canvas.boxes.first as! TableBlockBox
        let pos = t.cellTextStart(row: 1, column: 0)!
        e.canvas.selectedTextRange = DocumentTextRange(DocumentTextPosition(pos), DocumentTextPosition(pos))
        e.deleteTable()
        e.layoutIfNeeded()
        XCTAssertFalse(e.canvas.boxes.contains { $0 is TableBlockBox }, "the table is removed")
        XCTAssertEqual(e.canvas.boxes.count, 1, "a single (empty paragraph) block remains")
        XCTAssertFalse(e.currentState().isInTable, "caret is no longer in a table")
    }

    func test_facadeDeleteTable_surroundedByParagraphs_removesOnlyTheTable() {
        let e = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 600))
        e.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "Before")])),
            .table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
                rows: [Row(id: BlockID("r0"), isHeader: true,
                           cells: [Cell(id: BlockID("a"), blocks: [.paragraph(ParagraphBlock(id: BlockID("ap"), runs: [TextRun(text: "A")]))]),
                                   Cell(id: BlockID("b"), blocks: [.paragraph(ParagraphBlock(id: BlockID("bp"), runs: [TextRun(text: "B")]))])])])),
            .paragraph(ParagraphBlock(id: BlockID("p2"), runs: [TextRun(text: "After")])),
        ])
        e.layoutIfNeeded()
        let t = e.canvas.boxes[1] as! TableBlockBox
        let pos = t.cellTextStart(row: 0, column: 0)!
        e.canvas.selectedTextRange = DocumentTextRange(DocumentTextPosition(pos), DocumentTextPosition(pos))
        e.deleteTable()
        e.layoutIfNeeded()
        XCTAssertFalse(e.canvas.boxes.contains { $0 is TableBlockBox }, "the table is removed")
        XCTAssertEqual(e.canvas.boxes.count, 2, "the two surrounding paragraphs remain")
        XCTAssertFalse(e.currentState().isInTable, "caret moved out of the (deleted) table")
    }

    func test_facadeDeleteTable_noTableAtCaret_isNoOp() {
        let e = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        e.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hi")]))])
        e.layoutIfNeeded()
        let before = e.canvas.boxes.count
        e.deleteTable()
        XCTAssertEqual(e.canvas.boxes.count, before, "no-op when the caret isn't in a table")
    }

    // height(forWidth:) equals what update(...) returns for the same width — measure == commit.
    func test_heightForWidth_matchesUpdate() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"),
            runs: [TextRun(text: "A long enough paragraph to wrap differently at 300 versus 140 points wide.")]))])
        let committed = editor.update(size: CGSize(width: 300, height: 200), insets: .zero)
        XCTAssertEqual(editor.height(forWidth: 300), committed, accuracy: 0.5)

        let other = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 140, height: 200))
        other.document = editor.document
        let committed140 = other.update(size: CGSize(width: 140, height: 200), insets: .zero)
        XCTAssertEqual(editor.height(forWidth: 140), committed140, accuracy: 0.5)
    }

    // The headline guarantee: measuring at another width changes nothing observable.
    func test_heightForWidth_doesNotMutateLiveLayout() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"),
            runs: [TextRun(text: "A long enough paragraph to wrap differently at narrow widths and grow taller.")]))])
        _ = editor.update(size: CGSize(width: 300, height: 200), insets: .zero)
        let canvasFrame = editor.canvas.frame
        let scrollContent = editor.scrollContentHeightForTesting
        var changes = 0
        editor.onChange = { changes += 1 }
        _ = editor.height(forWidth: 120)
        XCTAssertEqual(editor.canvas.frame, canvasFrame, "measure must not move the canvas")
        XCTAssertEqual(editor.scrollContentHeightForTesting, scrollContent, accuracy: 0.001)
        XCTAssertEqual(changes, 0, "measure must not fire onChange")
    }
}
#endif
