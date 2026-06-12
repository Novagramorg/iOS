#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CanvasClipboardTests: XCTestCase {
    final class FakePasteboard: TextPasteboard {
        var string: String?
        var hasStrings: Bool { !(string ?? "").isEmpty }
    }
    func cell(_ id: String, _ t: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: t)]))])
    }
    func canvas() -> (DocumentCanvasView, FakePasteboard) {
        let v = DocumentCanvasView()
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("h"), runs: [TextRun(text: "Hello world")])),
            .table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
                rows: [Row(id: BlockID("r0"), cells: [cell("a", "Alpha"), cell("b", "Beta")])])),
        ], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        let pb = FakePasteboard(); v.pasteboard = pb
        return (v, pb)
    }
    func region(_ v: DocumentCanvasView, _ id: String) -> LeafTextRegion {
        v.allLeafRegions().first { $0.ref == .paragraph(BlockID(id)) }!
    }
    func text(_ v: DocumentCanvasView, _ id: String) -> String {
        for b in v.currentBlocks() { if case .paragraph(let p) = b, p.id == BlockID(id) { return p.text } }
        return ""
    }

    func test_copy_putsSelectionTextOnPasteboard() {
        let (v, pb) = canvas()
        let r = region(v, "h"); v.anchor = r.globalStart; v.head = r.globalStart + 5   // "Hello"
        pb.string = "stale"
        v.copy(nil)
        XCTAssertEqual(pb.string, "Hello")
    }
    func test_cut_copiesAndDeletes_andUndoes() {
        let (v, pb) = canvas()
        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        let r = region(v, "h"); v.anchor = r.globalStart; v.head = r.globalStart + 6   // "Hello "
        um.beginUndoGrouping(); v.cut(nil); um.endUndoGrouping()
        XCTAssertEqual(pb.string, "Hello ")
        XCTAssertEqual(text(v, "h"), "world")
        um.undo()
        XCTAssertEqual(text(v, "h"), "Hello world")
    }
    func test_paste_insertsStringAtSelection_andUndoes() {
        let (v, pb) = canvas()
        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        let r = region(v, "h"); v.anchor = r.globalStart; v.head = r.globalStart + 5   // replace "Hello"
        pb.string = "Howdy"
        um.beginUndoGrouping(); v.paste(nil); um.endUndoGrouping()
        XCTAssertEqual(text(v, "h"), "Howdy world")
        um.undo()
        XCTAssertEqual(text(v, "h"), "Hello world")
    }
    func test_paste_flattensNewlinesToSpaces() {
        let (v, pb) = canvas()
        let r = region(v, "h"); v.anchor = r.globalStart + 5; v.head = r.globalStart + 5   // caret after "Hello"
        pb.string = "a\nb"
        v.paste(nil)
        XCTAssertEqual(text(v, "h"), "Helloa b world")
    }
    func test_copy_acrossCells_concatenatesCellText() {
        let (v, pb) = canvas()
        let a = region(v, "ap"); let b = region(v, "bp")
        v.anchor = a.globalStart; v.head = b.globalStart + b.length   // "Alpha" … "Beta"
        v.copy(nil)
        XCTAssertEqual(pb.string, "AlphaBeta")
    }
    func test_paste_normalizesCRLFToSingleSpace() {
        let (v, pb) = canvas()
        let r = region(v, "h"); v.anchor = r.globalStart + 5; v.head = r.globalStart + 5   // caret after "Hello"
        pb.string = "a\r\nb"
        v.paste(nil)
        XCTAssertEqual(text(v, "h"), "Helloa b world")   // CRLF → ONE space, not two
    }
    func test_paste_emptyClipboard_isNoOp() {
        let (v, pb) = canvas()
        let r = region(v, "h"); v.anchor = r.globalStart; v.head = r.globalStart + 5
        pb.string = nil
        v.paste(nil)
        XCTAssertEqual(text(v, "h"), "Hello world")   // nothing on the clipboard → no change
    }
    func test_copyCut_collapsedSelection_isNoOp() {
        let (v, pb) = canvas()
        let r = region(v, "h"); v.anchor = r.globalStart + 3; v.head = r.globalStart + 3   // collapsed
        pb.string = "orig"
        v.copy(nil)
        XCTAssertEqual(pb.string, "orig")             // copy no-ops on a collapsed selection
        v.cut(nil)
        XCTAssertEqual(pb.string, "orig")             // cut no-ops too
        XCTAssertEqual(text(v, "h"), "Hello world")   // and the text is unchanged
    }
    func test_canPerformAction_copyCutPaste() {
        let (v, pb) = canvas()
        let r = region(v, "h")
        v.anchor = r.globalStart; v.head = r.globalStart + 5
        XCTAssertTrue(v.canPerformAction(#selector(UIResponderStandardEditActions.copy(_:)), withSender: nil))
        XCTAssertTrue(v.canPerformAction(#selector(UIResponderStandardEditActions.cut(_:)), withSender: nil))
        v.anchor = r.globalStart + 2; v.head = r.globalStart + 2   // collapsed → no copy/cut
        XCTAssertFalse(v.canPerformAction(#selector(UIResponderStandardEditActions.copy(_:)), withSender: nil))
        pb.string = "x"
        XCTAssertTrue(v.canPerformAction(#selector(UIResponderStandardEditActions.paste(_:)), withSender: nil))
    }
}
#endif
