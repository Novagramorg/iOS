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
}
