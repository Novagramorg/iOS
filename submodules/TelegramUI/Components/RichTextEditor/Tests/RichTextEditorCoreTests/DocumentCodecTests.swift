import XCTest
@testable import RichTextEditorCore

final class DocumentCodecTests: XCTestCase {
    private func sampleDoc() -> Document {
        Document(
            blocks: [.paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "x")]))]
        )
    }

    func test_codec_roundTrips() throws {
        let doc = sampleDoc()
        XCTAssertEqual(try DocumentCodec.decode(DocumentCodec.encode(doc)), doc)
    }

    func test_codec_emitsNoMetadataKey() throws {
        // A Document is just { schemaVersion, blocks } — there is no metadata wrapper, so the encoded
        // JSON must not carry a "metadata" key.
        let json = String(data: try DocumentCodec.encode(sampleDoc()), encoding: .utf8)!
        XCTAssertFalse(json.contains("metadata"), json)
    }

    func test_codec_keysAreSortedForStableDiffs() throws {
        let json = String(data: try DocumentCodec.encode(sampleDoc()), encoding: .utf8)!
        // "blocks" sorts before "schemaVersion"
        let iBlocks = json.range(of: "\"blocks\"")!.lowerBound
        let iSchema = json.range(of: "\"schemaVersion\"")!.lowerBound
        XCTAssertTrue(iBlocks < iSchema, json)
    }
}
