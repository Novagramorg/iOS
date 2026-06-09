import XCTest
@testable import RichTextEditorCore

final class DocNodeTests: XCTestCase {
    func test_textNode_sizeIsTextLength() {
        XCTAssertEqual(DocNode.text(length: 4, ref: .paragraph(BlockID("p"))).nodeSize, 4)
    }

    func test_paragraphNode_sizeIsTextPlusTwo() {
        let p = DocumentTree.build(from: Document(
            metadata: .init(title: "", createdAt: Date(timeIntervalSince1970: 0),
                            modifiedAt: Date(timeIntervalSince1970: 0)),
            blocks: [.paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "Hi!")]))]))
        // doc content = one paragraph of "Hi!" (3) → paragraph size 5, doc size 5
        XCTAssertEqual(p.nodeSize, 5)               // doc content size (no +2 on doc)
        XCTAssertEqual(p.children.count, 1)
        XCTAssertEqual(p.children[0].nodeSize, 5)   // the paragraph node
    }

    func test_imageBlock_sizeIsAtomPlusCaptionParagraphPlusTwo() {
        // image atom (1) + caption paragraph("ab" → 2 → +2 = 4) = content 5 → imageBlock 7
        let doc = Document(
            metadata: .init(title: "", createdAt: Date(timeIntervalSince1970: 0),
                            modifiedAt: Date(timeIntervalSince1970: 0)),
            blocks: [.image(ImageBlock(id: BlockID("i1"), assetID: "a",
                                       naturalSize: Size2D(width: 1, height: 1),
                                       caption: [TextRun(text: "ab")]))])
        let root = DocumentTree.build(from: doc)
        XCTAssertEqual(root.nodeSize, 7)            // doc content
        XCTAssertEqual(root.children[0].nodeSize, 7)
    }

    func test_table_walksRowMajor_andSizesNest() {
        // 1x2 table; each cell has an empty paragraph (size 2).
        // cell = content(2) + 2 = 4; row = (4+4) + 2 = 10; table = 10 + 2 = 12
        let cell = { (id: String) in
            Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p")))]) }
        let doc = Document(
            metadata: .init(title: "", createdAt: Date(timeIntervalSince1970: 0),
                            modifiedAt: Date(timeIntervalSince1970: 0)),
            blocks: [.table(TableBlock(id: BlockID("t1"),
                columns: [ColumnSpec(width: 1), ColumnSpec(width: 1)],
                rows: [Row(id: BlockID("r1"), cells: [cell("c1"), cell("c2")])]))])
        let root = DocumentTree.build(from: doc)
        XCTAssertEqual(root.children[0].nodeSize, 12)
    }
}
