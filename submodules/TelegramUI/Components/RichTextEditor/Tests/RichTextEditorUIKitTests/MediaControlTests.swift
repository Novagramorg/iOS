#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class MediaControlTests: XCTestCase {
    /// Two media blocks sharing one `mediaID` but distinct `BlockID`s — deleting one occurrence must NOT
    /// touch the other (the mediaID-is-not-unique guard).
    func test_deleteMediaBlock_removesOnlyTheGivenOccurrence() {
        let v = DocumentCanvasView()
        v.mediaViewProvider = { _, _ in nil }
        v.setBlocks([
            .media(MediaBlock(id: BlockID("img1"), mediaID: "x",
                              naturalSize: Size2D(width: 100, height: 60), caption: [])),
            .media(MediaBlock(id: BlockID("img2"), mediaID: "x",
                              naturalSize: Size2D(width: 100, height: 60), caption: [])),
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "End")])),
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400); v.layoutIfNeeded()

        v.deleteMediaBlock(id: BlockID("img2"))

        let mediaIDs = v.boxes.compactMap { ($0 as? MediaBlockBox)?.id }
        XCTAssertTrue(mediaIDs.contains(BlockID("img1")), "the untouched occurrence survives")
        XCTAssertFalse(mediaIDs.contains(BlockID("img2")), "only the targeted occurrence is removed")
    }
}

extension MediaControlTests {
    private final class StubMediaView: UIView, RichTextMediaItemView {
        func update(size: CGSize) {}
        var onControlTapped: ((RichTextMediaControlKind, UIView, CGRect) -> Void)?
    }

    /// The editor installs `onControlTapped` on the hosted view; firing it emits a request with the right
    /// control/mediaID, and the request's `delete()` removes that block.
    func test_moreControlTap_emitsRequest_andDeletes() {
        let v = DocumentCanvasView()
        v.mediaViewProvider = { _, _ in StubMediaView() }
        v.setBlocks([
            .media(MediaBlock(id: BlockID("img"), mediaID: "x",
                              naturalSize: Size2D(width: 100, height: 60), caption: [])),
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "End")])),
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400)
        v.setNeedsLayout(); v.layoutIfNeeded()

        var received: MediaControlRequest?
        v.onRequestMediaControl = { received = $0 }

        let hosted = v.hostedMediaViewForTesting(BlockID("img"))
        XCTAssertNotNil(hosted?.onControlTapped, "editor installed the control-tap hook on the media view")
        let anchor = UIView()
        hosted?.onControlTapped?(.more, anchor, CGRect(x: 0, y: 0, width: 36, height: 36))

        XCTAssertEqual(received?.control, .more)
        XCTAssertEqual(received?.mediaID, "x")
        XCTAssertTrue(received?.view === anchor, "the request anchors on the tapped control's view")

        received?.delete()
        XCTAssertFalse(v.boxes.contains { ($0 as? MediaBlockBox)?.id == BlockID("img") },
                       "the request's delete removes the media block")
    }
}
#endif
