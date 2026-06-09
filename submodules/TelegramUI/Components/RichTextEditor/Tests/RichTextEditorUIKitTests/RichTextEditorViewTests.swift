#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class RichTextEditorViewTests: XCTestCase {
    private func meta() -> DocumentMetadata {
        DocumentMetadata(title: "", createdAt: Date(timeIntervalSince1970: 0), modifiedAt: Date(timeIntervalSince1970: 0))
    }

    // A content-height change after an edit re-flows the host layout (canvas frame), not only on the
    // next external layout pass (e.g. a rotation). Pre-fix the edit never marked the host dirty, so a
    // normal layout pass left the canvas at its old height.
    func test_editGrowingContent_reflowsCanvasHeight() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        editor.document = Document(metadata: meta(),
                                   blocks: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hello")]))])
        editor.layoutIfNeeded()
        let before = editor.canvas.frame.height
        // Add a paragraph at the end (Enter) → taller content.
        editor.canvas.selectedTextRange = DocumentTextRange(DocumentTextPosition(editor.canvas.documentSizeValue),
                                                            DocumentTextPosition(editor.canvas.documentSizeValue))
        editor.canvas.insertText("\n")
        editor.layoutIfNeeded()   // a normal layout pass — the edit must have marked the host dirty
        XCTAssertGreaterThan(editor.canvas.frame.height, before,
                             "host re-sizes the canvas when content height grows after an edit")
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
        let meta = DocumentMetadata(title: "", createdAt: Date(timeIntervalSince1970: 0),
                                    modifiedAt: Date(timeIntervalSince1970: 0))
        e.document = Document(metadata: meta, blocks: [
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
}
#endif
