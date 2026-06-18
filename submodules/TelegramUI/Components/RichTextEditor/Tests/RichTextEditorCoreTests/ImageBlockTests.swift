import XCTest
@testable import RichTextEditorCore

final class ImageBlockTests: XCTestCase {
    func test_image_defaultsAndCaptionLength() {
        let img = ImageBlock(
            id: BlockID("img1"),
            assetID: "img1.png",
            naturalSize: Size2D(width: 100, height: 50),
            caption: [TextRun(text: "Fig 1")]
        )
        XCTAssertEqual(img.alignment, .center)
        XCTAssertNil(img.displayWidth)
        XCTAssertEqual(img.captionUTF16Count, 5)
    }

    func test_image_roundTrips() throws {
        let img = ImageBlock(
            id: BlockID("img1"),
            assetID: "img1.png",
            naturalSize: Size2D(width: 100, height: 50),
            displayWidth: 80,
            alignment: .left,
            caption: [TextRun(text: "c")]
        )
        let data = try JSONEncoder().encode(img)
        XCTAssertEqual(try JSONDecoder().decode(ImageBlock.self, from: data), img)
    }
}
