#if canImport(UIKit)
import XCTest
import RichTextEditorCore
@testable import RichTextEditorUIKit

final class PullQuoteGeometryTests: XCTestCase {
    func test_pullQuotePill_isCenteredAndHugsContent() {
        let canvas = DocumentCanvasView()
        canvas.setBlocks([.pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "Hi")]))], width: 320)
        canvas.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        canvas.layoutIfNeeded()
        let pills = canvas.pullQuotePillRects()
        XCTAssertEqual(pills.count, 1)
        XCTAssertGreaterThan(pills[0].width, 0)
        XCTAssertLessThan(pills[0].width, 320)                                 // hugs content, not full width
        XCTAssertEqual(pills[0].midX, canvas.bounds.width / 2, accuracy: 1.0)  // centered in the content column
    }

    func test_pullQuoteMarks_topLeftAndBottomRight() {
        let canvas = DocumentCanvasView()
        canvas.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        canvas.simulateParentLayout()
        canvas.setBlocks([.pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "Hi")]))], width: 320)
        let pill = canvas.pullQuotePillRects()[0]
        let marks = canvas.pullQuoteMarkRects()
        XCTAssertEqual(marks.count, 1)
        XCTAssertEqual(marks[0].open.minX, pill.minX + 6, accuracy: 0.5)          // top-left, inset 6
        XCTAssertEqual(marks[0].open.minY, pill.minY + 6, accuracy: 0.5)
        XCTAssertEqual(marks[0].close.maxX, pill.maxX - 6, accuracy: 0.5)         // bottom-right
        XCTAssertEqual(marks[0].close.maxY, pill.maxY - 6, accuracy: 0.5)
        XCTAssertGreaterThan(marks[0].close.minY, marks[0].open.minY)             // close sits lower than open
    }
}
#endif
