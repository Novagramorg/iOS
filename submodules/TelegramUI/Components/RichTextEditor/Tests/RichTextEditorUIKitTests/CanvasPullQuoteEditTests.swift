#if canImport(UIKit)
import XCTest
import RichTextEditorCore
@testable import RichTextEditorUIKit

@available(iOS 13.0, *)
final class CanvasPullQuoteEditTests: XCTestCase {
    private func makeCanvas() -> DocumentCanvasView {
        let c = DocumentCanvasView()
        c.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        return c
    }

    func test_makePullQuote_togglesParagraphsIntoOneBlock_preservingFormatting() {
        let canvas = makeCanvas()
        var bold = CharacterAttributes(); bold.bold = true
        canvas.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("a"), style: .body, runs: [TextRun(text: "one", attributes: bold)])),
            .paragraph(ParagraphBlock(id: BlockID("b"), style: .body, runs: [TextRun(text: "two")])),
        ], width: 320)
        canvas.simulateParentLayout()
        canvas.selectAll(nil)                        // span both paragraphs
        canvas.makePullQuote()
        let blocks = canvas.currentBlocks()          // currentBlocks() mirrors currentDocument().blocks
        XCTAssertEqual(blocks.count, 1)
        guard case .pullQuote(let pq) = blocks[0] else { return XCTFail("not a pull quote") }
        XCTAssertEqual(pq.text, "one\ntwo")
        XCTAssertTrue(pq.runs.contains { $0.attributes.bold })   // formatting preserved (NOT flattened)

        // Toggle back:
        canvas.selectAll(nil)
        canvas.makePullQuote()
        let back = canvas.currentBlocks()
        XCTAssertTrue(back.allSatisfy { if case .paragraph = $0 { return true } else { return false } })
        XCTAssertEqual(back.count, 2)
    }
}
#endif
