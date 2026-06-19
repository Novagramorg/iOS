import XCTest
@testable import RichTextEditorCore

final class MediaBlockTests: XCTestCase {
    func test_media_defaultsAndCaptionLength() {
        let img = MediaBlock(
            id: BlockID("img1"),
            mediaID: "img1.png",
            naturalSize: Size2D(width: 100, height: 50),
            caption: [TextRun(text: "Fig 1")]
        )
        XCTAssertEqual(img.alignment, .center)
        XCTAssertNil(img.displayWidth)
        XCTAssertEqual(img.kind, .image)
        XCTAssertEqual(img.captionUTF16Count, 5)
    }

    func test_media_roundTrips() throws {
        let img = MediaBlock(
            id: BlockID("img1"),
            mediaID: "img1.png",
            kind: .image,
            naturalSize: Size2D(width: 100, height: 50),
            displayWidth: 80,
            alignment: .left,
            caption: [TextRun(text: "c")]
        )
        let data = try JSONEncoder().encode(img)
        XCTAssertEqual(try JSONDecoder().decode(MediaBlock.self, from: data), img)
    }
}
