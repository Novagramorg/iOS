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
    func test_pullQuote_emptyHeight_matchesSingleLineTextHeight() {
        let mapper = AttributedStringMapper()
        let empty = PullQuoteBox(pullQuote: PullQuote(id: BlockID("e"), runs: []),
                                 mapper: mapper, pullQuoteStyle: .default, width: 300)
        let oneLine = PullQuoteBox(pullQuote: PullQuote(id: BlockID("t"), runs: [TextRun(text: "Hi")]),
                                   mapper: mapper, pullQuoteStyle: .default, width: 300)
        // An empty pull quote must be exactly as tall as a one-line one — the empty-line fallback must apply the
        // same lineHeightMultiple TextKit applies to a laid-out line.
        XCTAssertEqual(empty.height, oneLine.height, accuracy: 0.5)
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

    func test_pullQuote_emptyPlaceholderStringSuppresses() {
        let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID("pq"), runs: []),
                               mapper: AttributedStringMapper(), pullQuoteStyle: .default, width: 320)
        box.placeholders = RichTextEditorPlaceholders(body: "", listEnd: "", listOutdent: "", pullQuote: "")
        XCTAssertNil(box.placeholderText)
        XCTAssertEqual(box.contentWidth, 0)
    }

    func test_pullQuoteStyle_customInsets_propagateToBox() {
        var style = PullQuoteStyle.default; style.topInset = 30; style.bottomInset = 10
        let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID("pq"), runs: [TextRun(text: "hi")]),
                               mapper: AttributedStringMapper(), pullQuoteStyle: style, width: 320)
        XCTAssertEqual(box.topInset, 30, accuracy: 0.001)
        XCTAssertEqual(box.bottomInset, 10, accuracy: 0.001)
    }

    func test_emptyPullQuote_caretIndent_atPlaceholderStart() {
        let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID("pq"), runs: []),
                               mapper: AttributedStringMapper(), pullQuoteStyle: .default, width: 320)
        box.placeholders = .default   // pullQuote == "Type a quote here"
        box.frame = CGRect(x: 0, y: 0, width: 320, height: box.height)
        let containerWidth = box.frame.width - box.leftInset - box.rightInset
        let indent = box.leafRegions().first!.emptyLineLeadingIndent
        XCTAssertEqual(indent, (containerWidth - box.contentWidth) / 2, accuracy: 0.5)  // placeholder leading edge
        XCTAssertGreaterThan(indent, 0)                        // not the strip's left edge (the bug)
        XCTAssertLessThan(indent, containerWidth / 2)          // left of center (the placeholder has width)
    }

    func test_emptyPullQuote_noPlaceholder_caretIndent_atCenter() {
        let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID("pq"), runs: []),
                               mapper: AttributedStringMapper(), pullQuoteStyle: .default, width: 320)
        box.placeholders = RichTextEditorPlaceholders(body: "", listEnd: "", listOutdent: "", pullQuote: "")
        box.frame = CGRect(x: 0, y: 0, width: 320, height: box.height)
        let containerWidth = box.frame.width - box.leftInset - box.rightInset
        XCTAssertEqual(box.leafRegions().first!.emptyLineLeadingIndent, containerWidth / 2, accuracy: 0.5)
    }

    func test_nonEmptyPullQuote_caretIndent_isZero() {
        let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID("pq"), runs: [TextRun(text: "hi")]),
                               mapper: AttributedStringMapper(), pullQuoteStyle: .default, width: 320)
        box.frame = CGRect(x: 0, y: 0, width: 320, height: box.height)
        XCTAssertEqual(box.leafRegions().first!.emptyLineLeadingIndent, 0, accuracy: 0.001)
    }

    func test_emptyPullQuote_caretIndent_isFrameIndependent() {
        let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID("pq"), runs: []),
                               mapper: AttributedStringMapper(), pullQuoteStyle: .default, width: 320)
        box.placeholders = .default
        // Deliberately do NOT set box.frame (it stays .zero). The empty-caret indent must still
        // reflect the construction-time configured width, not the not-yet-assigned frame.
        let containerWidth = box.layoutWidth - box.leftInset - box.rightInset
        let indent = box.leafRegions().first!.emptyLineLeadingIndent
        XCTAssertEqual(indent, (containerWidth - box.contentWidth) / 2, accuracy: 0.5)  // placeholder start
        XCTAssertGreaterThan(indent, 0)   // NOT the left-edge fallback, despite frame == .zero
    }
}
#endif
