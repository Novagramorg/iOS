#if canImport(UIKit)
import XCTest
@testable import RichTextEditorUIKit
@testable import RichTextEditorCore

@available(iOS 13.0, *)
final class CodeBlockBoxTests: XCTestCase {
    private func makeBox(_ text: String, language: String? = "swift") -> CodeBlockBox {
        CodeBlockBox(code: CodeBlock(id: BlockID("c1"), language: language, runs: [TextRun(text: text)]),
                     mapper: AttributedStringMapper(), width: 300)
    }

    func test_codeBox_nodeSizeIsLengthPlusTwo() {
        let box = makeBox("a\nbb")                 // 4 UTF-16 units
        XCTAssertEqual(box.nodeSize, 4 + 2)
        XCTAssertEqual(box.textLength, 4)
    }

    func test_codeBox_textRefIsCode() {
        XCTAssertEqual(makeBox("x").textRef, .code(BlockID("c1")))
    }

    func test_codeBox_currentBlockRoundTripsTextAndLanguage() {
        guard case let .code(cb) = makeBox("a\nb", language: "ruby").currentBlock() else {
            return XCTFail("expected .code")
        }
        XCTAssertEqual(cb.text, "a\nb")
        XCTAssertEqual(cb.language, "ruby")
    }

    func test_codeBox_leafRegionsHasOneRegionSpanningText() {
        let box = makeBox("a\nb"); box.globalStart = 5
        let regions = box.leafRegions()
        XCTAssertEqual(regions.count, 1)
        XCTAssertEqual(regions[0].globalStart, 5)
        XCTAssertEqual(regions[0].length, 3)
        XCTAssertEqual(regions[0].ref, .code(BlockID("c1")))
    }

    func test_codeBox_factoryProducesCodeBlockBox() {
        let canvas = DocumentCanvasView()
        canvas.setBlocks([.code(CodeBlock(id: BlockID("c1"), runs: [TextRun(text: "x")]))], width: 300)
        XCTAssertTrue(canvas.boxes.first is CodeBlockBox)
    }

    func test_theme_storesCodeBackground() {
        let theme = RichTextEditorTheme(
            primaryText: .black, secondaryText: .black, placeholder: .placeholderText,
            accent: .link, tableBorder: .gray, tableHeaderBackground: .gray, codeBackground: .red)
        XCTAssertEqual(theme.codeBackground, .red)
    }
}
#endif
