import XCTest
@testable import RichTextEditorCore

final class CollapsedQuoteTests: XCTestCase {
    private func quotePara(_ id: String, _ text: String) -> ParagraphBlock {
        ParagraphBlock(id: BlockID(id), style: .quote, runs: [TextRun(text: text)])
    }

    func test_previewText_joinsFoldedParagraphsWithNewline() {
        let cq = CollapsedQuote(id: BlockID("q"), paragraphs: [quotePara("a", "one"), quotePara("b", "two")])
        XCTAssertEqual(cq.previewText, "one\ntwo")
    }

    func test_block_collapsedQuote_idAndCodableRoundTrip() throws {
        let block = Block.collapsedQuote(CollapsedQuote(id: BlockID("q"), paragraphs: [quotePara("a", "hi")]))
        XCTAssertEqual(block.id, BlockID("q"))
        let back = try JSONDecoder().decode(Block.self, from: JSONEncoder().encode(block))
        XCTAssertEqual(block, back)
    }

    func test_documentTree_collapsedQuote_isCaptionlessAtomSize3() {
        let doc = Document(blocks: [.collapsedQuote(CollapsedQuote(id: BlockID("q"),
                                                                   paragraphs: [quotePara("a", "lots of text here")]))])
        // Atom (1) + wrapper (+2) = 3 — identical to an audio media block; the folded text is display-only.
        XCTAssertEqual(DocumentTree.documentSize(doc), 3)
    }
}
