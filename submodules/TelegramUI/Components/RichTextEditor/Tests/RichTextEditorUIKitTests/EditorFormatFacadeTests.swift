#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class EditorFormatFacadeTests: XCTestCase {
    func editor() -> RichTextEditorView {
        let e = RichTextEditorView()
        e.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
        e.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hello")]))])
        e.layoutIfNeeded()
        return e
    }
    func runs(_ e: RichTextEditorView) -> [TextRun] {
        for b in e.document.blocks { if case .paragraph(let p) = b { return p.runs } }
        return []
    }

    func test_facade_toggleItalic_reflectsInDocument() {
        let e = editor()
        e.selectAll(); e.toggleItalic()
        XCTAssertEqual(runs(e).map { $0.text }.joined(), "Hello")
        XCTAssertTrue(runs(e).allSatisfy { $0.attributes.italic })
    }
    func test_facade_setParagraphStyle_reflectsInDocument() {
        let e = editor()
        e.selectAll(); e.setParagraphStyle(.heading1)
        guard case .paragraph(let p)? = e.document.blocks.first else { return XCTFail("expected paragraph") }
        XCTAssertEqual(p.style, .heading1)
    }
    func test_facade_undo_revertsFormatting() {
        let e = editor()
        let um = UndoManager(); um.groupsByEvent = false; e.canvas.undoManagerOverride = um
        e.selectAll()
        um.beginUndoGrouping(); e.toggleBold(); um.endUndoGrouping()
        XCTAssertTrue(runs(e).allSatisfy { $0.attributes.bold })
        e.undo()
        XCTAssertTrue(runs(e).allSatisfy { !$0.attributes.bold }, "facade undo reverts bold")
    }

    func test_facade_selectedGlobalRange_nilWhenCollapsed() {
        let e = editor()
        e.canvas.anchor = 3; e.canvas.head = 3
        XCTAssertNil(e.selectedGlobalRange(), "a collapsed selection has no range")
    }
    func test_facade_selectedGlobalRange_reportsOffsets() {
        let e = editor()
        e.canvas.anchor = 1; e.canvas.head = 4
        let r = e.selectedGlobalRange()
        XCTAssertEqual(r?.from, 1); XCTAssertEqual(r?.to, 4)
    }
    func test_facade_selectedGlobalRange_ordersEndpoints() {
        let e = editor()
        e.canvas.anchor = 4; e.canvas.head = 1   // dragged backwards
        let r = e.selectedGlobalRange()
        XCTAssertEqual(r?.from, 1); XCTAssertEqual(r?.to, 4)
    }
    func test_facade_replaceRange_replacesAndCollapses() {
        let e = editor()   // "Hello" → text global 1..6
        e.replaceRange(from: 1, to: 6, with: Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("n"), runs: [TextRun(text: "Bye")]))]))
        guard case .paragraph(let p)? = e.document.blocks.first else { return XCTFail("expected paragraph") }
        XCTAssertEqual(p.text, "Bye")
    }
}
#endif
