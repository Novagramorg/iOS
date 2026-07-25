#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

@available(iOS 13.0, *)
final class DetailsBoxFoldTests: XCTestCase {
    private func seeded(_ expanded: Bool) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        let d = DetailsBlock(id: BlockID("d"), title: [TextRun(text: "T")],
                             children: [.paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "body")]))],
                             expanded: expanded)
        v.setBlocks([.details(d)], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        return v
    }
    private func detailsBox(_ v: DocumentCanvasView) -> DetailsBox { v.boxes.first { $0 is DetailsBox } as! DetailsBox }

    func test_toggleFold_preservesBody_flipsExpanded_asOneUndoStep() {
        let v = seeded(true)
        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        um.beginUndoGrouping(); v.toggleDetailsExpanded(box: detailsBox(v)); um.endUndoGrouping()
        guard case .details(let folded) = v.currentBlocks()[0] else { return XCTFail() }
        XCTAssertFalse(folded.expanded)
        XCTAssertEqual(folded.children.count, 1)                          // body preserved when folded
        guard case .paragraph(let p) = folded.children[0] else { return XCTFail() }
        XCTAssertEqual(p.text, "body")
        um.undo()
        guard case .details(let back) = v.currentBlocks()[0] else { return XCTFail() }
        XCTAssertTrue(back.expanded)                                      // single undo restores expanded
    }

    func test_toggleFold_expandsAFoldedBlock() {
        let v = seeded(false)
        XCTAssertEqual(detailsBox(v).children.boxes.count, 1)             // folded → title only (body off-axis)
        v.toggleDetailsExpanded(box: detailsBox(v))
        guard case .details(let d) = v.currentBlocks()[0] else { return XCTFail() }
        XCTAssertTrue(d.expanded)
        XCTAssertEqual(detailsBox(v).children.boxes.count, 2)             // expanded → title + body box realized
    }

    func test_chevronTap_togglesFold() {
        let v = seeded(true)
        v.becomeFirstResponder()
        let box = detailsBox(v)
        let chevron = box.chevronRect()
        v.performSingleTapForTesting(at: CGPoint(x: chevron.midX, y: chevron.midY))
        guard case .details(let d) = v.currentBlocks()[0] else { return XCTFail() }
        XCTAssertFalse(d.expanded)                                        // a chevron tap folded it
    }
}
#endif
