#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

@available(iOS 17.0, *)
final class MediaItemViewHostingTests: XCTestCase {
    final class StubMediaView: UIView, RichTextMediaItemView {
        let mediaID: String
        var updatedSizes: [CGSize] = []
        init(mediaID: String) { self.mediaID = mediaID; super.init(frame: .zero) }
        required init?(coder: NSCoder) { fatalError() }
        func update(size: CGSize) { updatedSizes.append(size) }
    }

    private func emptyDoc(_ blocks: [Block]) -> Document {
        Document(blocks: blocks)
    }

    func testProviderInvokedOncePerOccurrenceAndViewSized() {
        let editor = RichTextEditorView()
        editor.frame = CGRect(x: 0, y: 0, width: 320, height: 600)
        var requested: [String] = []
        editor.registerMediaViewProvider { mediaID, _ in
            requested.append(mediaID)
            return StubMediaView(mediaID: mediaID)
        }
        editor.document = emptyDoc([.paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "x")]))])
        _ = editor.update(size: editor.frame.size, insets: .zero)
        editor.insertMedia(mediaID: "m1", naturalSize: CGSize(width: 200, height: 100), kind: .image)
        _ = editor.update(size: editor.frame.size, insets: .zero)
        editor.layoutIfNeeded()

        XCTAssertEqual(requested, ["m1"], "provider invoked exactly once for the one media block")
        XCTAssertEqual(editor.hostedMediaCountForTesting, 1)
        let view = editor.hostedMediaViewForTesting(forFirstMediaBlock: editor.document)
        XCTAssertNotNil(view as? StubMediaView)
        XCTAssertFalse((view as! StubMediaView).updatedSizes.isEmpty, "view.update(size:) was called during layout")
    }

    // A document set while the editor is still UNFRAMED (bounds == .zero) — the draft-restore / attachment-init
    // "content applied before layout" case — must NOT trigger a zero-width layout pass. A zero-width layout builds
    // the hosted media view at a 0×0 rect (and binds its fetch) only to redo it the instant the real frame lands.
    // The model is applied immediately (readable via the getter); the host's next framed `update(...)` lays it out.
    // Regression guard for the `document` setter gating its `performLayout` on `bounds.width > 0` (matching every
    // other setter in `RichTextEditorView`).
    func testZeroBoundsDocumentSetDefersMediaViewCreationUntilFramed() {
        let editor = RichTextEditorView()
        var requested: [String] = []
        editor.registerMediaViewProvider { mediaID, _ in
            requested.append(mediaID); return StubMediaView(mediaID: mediaID)
        }
        // Phase 1: set a media document while UNFRAMED (bounds == .zero).
        editor.document = emptyDoc([
            .media(MediaBlock(id: BlockID("m0"), mediaID: "m1", kind: .image,
                              naturalSize: Size2D(width: 200, height: 100)))
        ])
        XCTAssertTrue(requested.isEmpty, "no media view created while unframed (bounds == .zero)")
        XCTAssertEqual(editor.hostedMediaCountForTesting, 0)
        XCTAssertEqual(editor.document.blocks.count, 1, "the model is applied even while unframed")

        // Phase 2: framing lays it out and creates the hosted media view.
        editor.frame = CGRect(x: 0, y: 0, width: 320, height: 600)
        _ = editor.update(size: editor.frame.size, insets: .zero)
        editor.layoutIfNeeded()
        XCTAssertEqual(requested, ["m1"], "media view created on the first framed layout")
        XCTAssertEqual(editor.hostedMediaCountForTesting, 1)
    }

    // A UIKit layout pass (`layoutSubviews`) while the editor is still UNFRAMED must ALSO not build media
    // views — both `RichTextEditorView.layoutSubviews` (→ performLayout) and `DocumentCanvasView.layoutSubviews`
    // (→ layoutContent) gate on `bounds.width > 0`. Without those gates a stray zero-bounds layout pass (before
    // the host frames the view) creates the hosted media view at a 0×0 rect and binds its fetch. Complements the
    // document-setter gate above — this covers the layout-pass entry points.
    func testZeroBoundsLayoutPassDoesNotCreateMediaViews() {
        let editor = RichTextEditorView()
        var requested: [String] = []
        editor.registerMediaViewProvider { mediaID, _ in
            requested.append(mediaID); return StubMediaView(mediaID: mediaID)
        }
        editor.document = emptyDoc([
            .media(MediaBlock(id: BlockID("m0"), mediaID: "m1", kind: .image,
                              naturalSize: Size2D(width: 200, height: 100)))
        ])
        // Force a UIKit layout pass while unframed (bounds == .zero).
        editor.setNeedsLayout()
        editor.layoutIfNeeded()
        XCTAssertTrue(requested.isEmpty, "a zero-bounds layout pass creates no media views")
        XCTAssertEqual(editor.hostedMediaCountForTesting, 0)

        // Framed → the layout pass now builds it.
        editor.frame = CGRect(x: 0, y: 0, width: 320, height: 600)
        editor.setNeedsLayout()
        editor.layoutIfNeeded()
        XCTAssertEqual(requested, ["m1"], "media view created once a framed layout pass runs")
        XCTAssertEqual(editor.hostedMediaCountForTesting, 1)
    }

    func testSameMediaIDInTwoBlocksProducesTwoIndependentViews() {
        let editor = RichTextEditorView()
        editor.frame = CGRect(x: 0, y: 0, width: 320, height: 600)
        var count = 0
        editor.registerMediaViewProvider { mediaID, _ in count += 1; return StubMediaView(mediaID: mediaID) }
        editor.document = emptyDoc([.paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "x")]))])
        _ = editor.update(size: editor.frame.size, insets: .zero)
        editor.insertMedia(mediaID: "dup", naturalSize: CGSize(width: 100, height: 100), kind: .image)
        editor.insertMedia(mediaID: "dup", naturalSize: CGSize(width: 100, height: 100), kind: .image)
        _ = editor.update(size: editor.frame.size, insets: .zero)
        editor.layoutIfNeeded()
        XCTAssertEqual(count, 2, "same mediaID in two blocks -> two independent views")
        XCTAssertEqual(editor.hostedMediaCountForTesting, 2)
    }
}
#endif
