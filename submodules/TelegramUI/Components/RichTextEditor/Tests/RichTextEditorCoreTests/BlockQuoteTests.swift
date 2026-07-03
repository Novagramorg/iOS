import XCTest
@testable import RichTextEditorCore
final class BlockQuoteTests: XCTestCase {
    func test_blockQuote_recursiveCodableRoundTrip() throws {
        let inner = BlockQuote(id: BlockID("inner"), children: [.paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "hi")]))], collapsed: false)
        let outer = Block.blockQuote(BlockQuote(id: BlockID("outer"), children: [.blockQuote(inner)], collapsed: true))
        let data = try JSONEncoder().encode(outer)
        XCTAssertEqual(try JSONDecoder().decode(Block.self, from: data), outer)   // nesting + collapsed survive
    }

    func test_documentTree_blockQuoteNodeSize_expandedVsCollapsed() {
        // expanded quote holding one paragraph "ab" (utf16 2): text 2 + paragraph wrapper 2 = 4; quote wrapper +2 = 6.
        let bq = BlockQuote(id: BlockID("q"), children: [.paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "ab")]))], collapsed: false)
        XCTAssertEqual(DocumentTree.documentSize(Document(blocks: [.blockQuote(bq)])), 6)
        var c = bq; c.collapsed = true
        XCTAssertEqual(DocumentTree.documentSize(Document(blocks: [.blockQuote(c)])), 3)   // folded → atom
    }

    func test_fragment_blockQuote_notInlineMergeable_plainText_regenId() {
        let bq = BlockQuote(id: BlockID("q"), children: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hi")]))], collapsed: false)
        XCTAssertFalse(isInlineMergeable(.blockQuote(bq)))
        XCTAssertEqual(blockPlainText(.blockQuote(bq)), "hi")
        let regen = Document(blocks: [.blockQuote(bq)]).regeneratingTopLevelIDs()
        guard case .blockQuote(let r) = regen.blocks[0] else { return XCTFail() }
        XCTAssertNotEqual(r.id, bq.id)                                   // top-level id regenerated
        guard case .paragraph(let rp) = r.children[0] else { return XCTFail() }
        XCTAssertNotEqual(rp.id, BlockID("p"))                           // child ids regenerated too (no collisions on paste)
        XCTAssertEqual(rp.text, "hi")
    }
}
