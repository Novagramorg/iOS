#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CanvasStructuralTests: XCTestCase {
    func makeCanvas(_ paragraphs: [ParagraphBlock]) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setParagraphs(paragraphs, width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300); v.layoutIfNeeded()
        return v
    }
    func caret(_ v: DocumentCanvasView, _ pos: Int) {
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(pos), DocumentTextPosition(pos))
    }

    func test_backspaceAtBlockStart_mergesIntoPrevious() {
        let v = makeCanvas([
            ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Alpha")]),
            ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "Beta")]),
        ])
        caret(v, v.boxes[1].textStart)                 // start of "Beta"
        v.deleteBackward()
        XCTAssertEqual(v.boxes.count, 1)
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "AlphaBeta")
        XCTAssertEqual(v.boxes[0].id, BlockID("a"))      // survivor = previous block
        XCTAssertEqual(v.head, v.boxes[0].textStart + 5)   // caret at the join (after "Alpha")
    }

    func test_backspaceAtVeryStart_isNoOp() {
        let v = makeCanvas([ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Alpha")])])
        caret(v, v.boxes[0].textStart)                 // start of the first block
        v.deleteBackward()
        XCTAssertEqual(v.boxes.count, 1)
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "Alpha")
    }

    func test_backspaceMerge_undoRestoresTwoBlocks() {
        let v = makeCanvas([
            ParagraphBlock(id: BlockID("a"), style: .heading1, runs: [TextRun(text: "Alpha")]),
            ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "Beta")]),
        ])
        let um = UndoManager(); um.groupsByEvent = false
        v.undoManagerOverride = um
        caret(v, v.boxes[1].textStart)
        um.beginUndoGrouping(); v.deleteBackward(); um.endUndoGrouping()
        XCTAssertEqual(v.boxes.count, 1)
        um.undo()
        XCTAssertEqual(v.boxes.count, 2)
        XCTAssertEqual((v.boxes[0] as! BlockBox).style, .heading1)      // style restored
        XCTAssertEqual(v.boxes.map { $0.id }, [BlockID("a"), BlockID("b")])
    }

    func test_enterSplitsParagraph_intoTwoBlocks() {
        let v = makeCanvas([
            ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Alpha")]),
            ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "Beta")]),
        ])
        caret(v, v.boxes[0].textStart + 2)             // after "Al"
        v.insertText("\n")
        XCTAssertEqual(v.boxes.count, 3)
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "Al")
        XCTAssertEqual((v.boxes[1] as! BlockBox).currentParagraph().text, "pha")
        XCTAssertEqual((v.boxes[2] as! BlockBox).currentParagraph().text, "Beta")
        XCTAssertEqual(v.boxes[0].id, BlockID("a"))      // upper keeps the parent id
        XCTAssertNotEqual(v.boxes[1].id, BlockID("a"))   // lower is a fresh id
        XCTAssertEqual(v.head, v.boxes[1].textStart)   // caret at the start of the new block
    }

    func test_enterAtEnd_appendsEmptyParagraph_inheritingList() {
        let v = makeCanvas([
            ParagraphBlock(id: BlockID("a"), list: ListMembership(marker: .bullet),
                           runs: [TextRun(text: "Item")]),
        ])
        caret(v, v.boxes[0].textStart + 4)             // end of "Item"
        v.insertText("\n")
        XCTAssertEqual(v.boxes.count, 2)
        XCTAssertEqual((v.boxes[1] as! BlockBox).currentParagraph().text, "")
        XCTAssertEqual((v.boxes[1] as! BlockBox).listMembership?.marker, .bullet)  // new list item
    }

    func test_enterSplit_undoRestoresSingleBlockWithOriginalID() {
        let v = makeCanvas([ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Alpha")])])
        let um = UndoManager(); um.groupsByEvent = false
        v.undoManagerOverride = um
        caret(v, v.boxes[0].textStart + 2)
        um.beginUndoGrouping(); v.insertText("\n"); um.endUndoGrouping()
        XCTAssertEqual(v.boxes.count, 2)
        um.undo()
        XCTAssertEqual(v.boxes.count, 1)
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "Alpha")
        XCTAssertEqual(v.boxes[0].id, BlockID("a"))      // exact original id restored
    }

    func test_enterOnEmptyListItem_level0_endsList_becomesBodyParagraph() {
        let v = makeCanvas([
            ParagraphBlock(id: BlockID("a"), list: ListMembership(marker: .bullet),
                           runs: [TextRun(text: "Item")]),
            ParagraphBlock(id: BlockID("e"), list: ListMembership(marker: .bullet), runs: []),
        ])
        caret(v, v.boxes[1].textStart)                 // caret in the empty bullet
        v.insertText("\n")
        XCTAssertEqual(v.boxes.count, 2)               // converted in place — no new block
        let empty = v.boxes[1] as! BlockBox
        XCTAssertNil(empty.listMembership)             // list ended
        XCTAssertEqual(empty.style, .body)             // now a body paragraph
        XCTAssertEqual(empty.currentParagraph().text, "")
        XCTAssertEqual(v.head, empty.textStart)        // caret lands in it
    }

    func test_enterOnEmptyNestedListItem_outdentsOneLevel_staysList() {
        let v = makeCanvas([
            ParagraphBlock(id: BlockID("e"), list: ListMembership(marker: .bullet, level: 2), runs: []),
        ])
        caret(v, v.boxes[0].textStart)
        v.insertText("\n")
        XCTAssertEqual(v.boxes.count, 1)               // no new block
        let item = v.boxes[0] as! BlockBox
        XCTAssertEqual(item.listMembership?.marker, .bullet)   // still a list item
        XCTAssertEqual(item.listMembership?.level, 1)          // outdented one level
        XCTAssertEqual(v.head, item.textStart)
    }

    func test_enterOnEmptyListItem_endList_undoRestoresBullet() {
        let v = makeCanvas([ParagraphBlock(id: BlockID("e"),
                                           list: ListMembership(marker: .bullet), runs: [])])
        let um = UndoManager(); um.groupsByEvent = false
        v.undoManagerOverride = um
        caret(v, v.boxes[0].textStart)
        um.beginUndoGrouping(); v.insertText("\n"); um.endUndoGrouping()
        XCTAssertNil((v.boxes[0] as! BlockBox).listMembership)               // ended
        um.undo()
        XCTAssertEqual((v.boxes[0] as! BlockBox).listMembership?.marker, .bullet)   // restored
        XCTAssertEqual((v.boxes[0] as! BlockBox).listMembership?.level, 0)
    }

    func test_enterAtBlockStart_insertsEmptyParagraphAbove() {
        let v = makeCanvas([ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Alpha")])])
        caret(v, v.boxes[0].textStart)                              // caret at start of the block
        v.insertText("\n")
        XCTAssertEqual(v.boxes.count, 2)
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "")        // empty paragraph above
        XCTAssertEqual(v.boxes[0].id, BlockID("a"))                   // upper keeps the original id
        XCTAssertEqual((v.boxes[1] as! BlockBox).currentParagraph().text, "Alpha")  // text pushed into the lower block
        XCTAssertEqual(v.head, v.boxes[1].textStart)               // caret follows the text
    }
}
#endif
