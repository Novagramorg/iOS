#if canImport(UIKit)
import XCTest
import RichTextEditorCore
@testable import RichTextEditorUIKit

final class MeasuredContentHeightTests: XCTestCase {
    private func composerConfigure(_ e: RichTextEditorView) {
        e.contentPageMargin = 0.0
        e.minimumContentHeight = 0.0
        e.blockVerticalInset = 0.0
        e.textLayoutMetrics = .compact
    }

    private func liveHeight(lineCount: Int, width: CGFloat) -> CGFloat {
        let e = RichTextEditorView()
        composerConfigure(e)
        e.document = Document(blocks: (0..<lineCount).map { _ in
            Block.paragraph(ParagraphBlock(id: .generate(), style: .body, runs: [TextRun(text: "A")]))
        })
        return e.height(forWidth: width)
    }

    func test_measuredContentHeight_matchesLiveEditor_forThreeBodyLines() {
        let width: CGFloat = 240.0
        let expected = liveHeight(lineCount: 3, width: width)
        let measured = RichTextEditorView.measuredContentHeight(forWidth: width, lineCount: 3, configure: composerConfigure)
        XCTAssertEqual(measured, expected, accuracy: 0.5)
    }

    func test_measuredContentHeight_isMonotonicInLineCount() {
        let width: CGFloat = 240.0
        let h1 = RichTextEditorView.measuredContentHeight(forWidth: width, lineCount: 1, configure: composerConfigure)
        let h3 = RichTextEditorView.measuredContentHeight(forWidth: width, lineCount: 3, configure: composerConfigure)
        XCTAssertGreaterThan(h3, h1)
        // Three lines is about three single lines tall (natural metrics, 0 inter-paragraph gap).
        XCTAssertEqual(h3, h1 * 3.0, accuracy: h1)
    }

    func test_measuredContentHeight_lineCountFloorsAtOne() {
        let width: CGFloat = 240.0
        let h0 = RichTextEditorView.measuredContentHeight(forWidth: width, lineCount: 0, configure: composerConfigure)
        let h1 = RichTextEditorView.measuredContentHeight(forWidth: width, lineCount: 1, configure: composerConfigure)
        XCTAssertEqual(h0, h1, accuracy: 0.5)
    }
}
#endif
