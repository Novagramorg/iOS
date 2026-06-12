import XCTest
@testable import RichTextEditorCore

final class PositionMapTests: XCTestCase {
    // Fixture: paragraph "One" (3), then an image with caption "Hi" (atom 1 + caption para 4).
    // Map: 0 <p> 1 'O' 2 'n' 3 'e' 4 </p> 5 <imgBlock> 6 <imgAtom> 7 <capP> 8 'H' 9 'i' 10 </capP> 11 </imgBlock> 12
    private func fixture() -> Document {
        Document(
            metadata: .init(title: "", createdAt: Date(timeIntervalSince1970: 0),
                            modifiedAt: Date(timeIntervalSince1970: 0)),
            blocks: [
                .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "One")])),
                .image(ImageBlock(id: BlockID("i1"), assetID: "a",
                                  naturalSize: Size2D(width: 1, height: 1),
                                  caption: [TextRun(text: "Hi")])),
            ])
    }

    func test_documentSize_matchesHandComputedMap() {
        // paragraph 5 + imageBlock (atom 1 + caption(2+2=4) = 5, +2 = 7) = 12
        XCTAssertEqual(DocumentTree.documentSize(fixture()), 12)
    }
}
