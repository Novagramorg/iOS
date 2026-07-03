import XCTest
@testable import RichTextEditorCore

final class PullQuoteTests: XCTestCase {
    func test_block_pullQuote_codableRoundTrip() throws {
        let pq = PullQuote(id: BlockID("pq1"), runs: [TextRun(text: "line1\nline2")])
        let block = Block.pullQuote(pq)
        let data = try JSONEncoder().encode(block)
        let decoded = try JSONDecoder().decode(Block.self, from: data)
        XCTAssertEqual(decoded, block)
        XCTAssertEqual(decoded.id, pq.id)
    }

    func test_pullQuote_utf16Count() {
        let pq = PullQuote(id: BlockID("x"), runs: [TextRun(text: "ab"), TextRun(text: "c")])
        XCTAssertEqual(pq.utf16Count, 3)
        XCTAssertEqual(pq.text, "abc")
    }

    func test_documentTree_pullQuoteNodeSize() {
        // content(4) + 2 wrapper tokens == 6, exactly like a paragraph / code block.
        let doc = Document(blocks: [.pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "abcd")]))])
        XCTAssertEqual(DocumentTree.documentSize(doc), 6)
    }

    func test_fragment_pullQuoteNotInlineMergeable() {
        XCTAssertFalse(isInlineMergeable(.pullQuote(PullQuote(id: BlockID("p"), runs: []))))
    }

    func test_fragment_blockPlainText_pullQuote() {
        XCTAssertEqual(blockPlainText(.pullQuote(PullQuote(id: BlockID("p"), runs: [TextRun(text: "hi\nyo")]))), "hi\nyo")
    }

    func test_fragment_extractAndRegenerate_capturesPullQuote() {
        // A document with a single pull quote "abcd"; extract the whole block; assert a .pullQuote fragment
        // comes out with the covered runs, and regeneratingTopLevelIDs gives it a FRESH id.
        let pq = PullQuote(id: BlockID("orig"), runs: [TextRun(text: "abcd")])
        let doc = Document(blocks: [.pullQuote(pq)])
        // global text of the single block spans [1, 1+4]; extract [1, 5) covers all of it.
        let frag = doc.extractFragment(globalFrom: 1, globalTo: 5)
        guard case .pullQuote(let got)? = frag.blocks.first else { return XCTFail("no pull quote captured") }
        XCTAssertEqual(got.text, "abcd")
        let regen = frag.regeneratingTopLevelIDs()
        guard case .pullQuote(let r)? = regen.blocks.first else { return XCTFail() }
        XCTAssertNotEqual(r.id, got.id)      // fresh id
        XCTAssertEqual(r.text, "abcd")       // runs preserved
    }
}
