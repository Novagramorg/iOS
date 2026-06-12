import XCTest
@testable import RichTextEditorCore

final class DocumentCodecTests: XCTestCase {
    private func sampleDoc() -> Document {
        Document(
            metadata: DocumentMetadata(title: "T",
                                       createdAt: Date(timeIntervalSince1970: 0),
                                       modifiedAt: Date(timeIntervalSince1970: 0)),
            blocks: [.paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "x")]))]
        )
    }

    func test_codec_roundTrips() throws {
        let doc = sampleDoc()
        XCTAssertEqual(try DocumentCodec.decode(DocumentCodec.encode(doc)), doc)
    }

    func test_codec_encodesDatesAsISO8601() throws {
        let json = String(data: try DocumentCodec.encode(sampleDoc()), encoding: .utf8)!
        XCTAssertTrue(json.contains("1970-01-01T00:00:00Z"), json)
    }

    func test_codec_keysAreSortedForStableDiffs() throws {
        let json = String(data: try DocumentCodec.encode(sampleDoc()), encoding: .utf8)!
        // "blocks" sorts before "metadata" sorts before "schemaVersion"
        let iBlocks = json.range(of: "\"blocks\"")!.lowerBound
        let iMeta = json.range(of: "\"metadata\"")!.lowerBound
        let iSchema = json.range(of: "\"schemaVersion\"")!.lowerBound
        XCTAssertTrue(iBlocks < iMeta && iMeta < iSchema, json)
    }
}
