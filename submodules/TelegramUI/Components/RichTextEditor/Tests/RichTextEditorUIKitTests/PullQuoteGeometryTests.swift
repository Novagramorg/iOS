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
}
#endif
