#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CanvasTextInputTests: XCTestCase {
    private func canvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setParagraphs([
            ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Alpha")]),
            ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "Beta")]),
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 200); v.layoutIfNeeded()
        return v
    }

    func test_insertText_editsCaretBlock_andShiftsLaterSpans() {
        let v = canvas()
        let bStartBefore = v.boxes[1].textStart
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(v.boxes[0].textStart + 5),
                                                DocumentTextPosition(v.boxes[0].textStart + 5)) // end of "Alpha"
        v.insertText("!")
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().runs.map(\.text).joined(), "Alpha!")
        XCTAssertEqual(v.boxes[1].textStart, bStartBefore + 1) // later block shifted by +1
    }

    func test_textInRange_concatenatesAcrossBlocks() {
        let v = canvas()
        let r = DocumentTextRange(DocumentTextPosition(v.boxes[0].textStart + 4),  // "a" of Alpha
                                  DocumentTextPosition(v.boxes[1].textStart + 1))  // "B" of Beta
        XCTAssertEqual(v.text(in: r), "aB")
    }

    func test_caretRectInSecondBlock_isBelowFirst() {
        let v = canvas()
        let r0 = v.caretRect(for: DocumentTextPosition(v.boxes[0].textStart))
        let r1 = v.caretRect(for: DocumentTextPosition(v.boxes[1].textStart))
        XCTAssertGreaterThan(r1.minY, r0.minY)
    }
}
#endif
