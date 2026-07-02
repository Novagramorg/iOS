#if canImport(UIKit)
import XCTest
import RichTextEditorCore
@testable import RichTextEditorUIKit

final class PullQuoteBoxTests: XCTestCase {
    func test_currentBlock_preservesRichRuns_stripsItalic() {
        let mapper = AttributedStringMapper()
        var bold = CharacterAttributes(); bold.bold = true
        let pq = PullQuote(id: BlockID("pq"), runs: [TextRun(text: "a", attributes: bold), TextRun(text: "b")])
        let box = PullQuoteBox(pullQuote: pq, mapper: mapper, width: 300)
        guard case .pullQuote(let out) = box.currentBlock() else { return XCTFail() }
        XCTAssertEqual(out.text, "ab")
        XCTAssertTrue(out.runs.contains { $0.attributes.bold })     // bold preserved
        XCTAssertFalse(out.runs.contains { $0.attributes.italic })  // forced italic not stored
    }
    func test_nodeSize_isContentPlusTwo() {
        let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID("x"), runs: [TextRun(text: "abcd")]),
                               mapper: AttributedStringMapper(), width: 300)
        XCTAssertEqual(box.nodeSize, 6)
    }
    func test_canvasBuildsPullQuoteBox() {
        let canvas = DocumentCanvasView()
        canvas.setBlocks([.pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "hi")]))], width: 320)
        XCTAssertTrue(canvas.boxes.contains { $0 is PullQuoteBox })
    }

    func test_emptyPullQuote_showsPlaceholderAndHugsIt() {
        let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID("pq"), runs: []),
                               mapper: AttributedStringMapper(), pullQuoteStyle: .default, width: 320)
        box.placeholders = .default    // pullQuote == "Type a quote here"
        XCTAssertEqual(box.placeholderText, "Type a quote here")
        XCTAssertGreaterThan(box.contentWidth, 0)      // empty pill hugs the placeholder, not zero width
    }

    func test_nonEmptyPullQuote_hasNoPlaceholder() {
        let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID("pq"), runs: [TextRun(text: "hi")]),
                               mapper: AttributedStringMapper(), pullQuoteStyle: .default, width: 320)
        box.placeholders = .default
        XCTAssertNil(box.placeholderText)
    }
}
#endif
