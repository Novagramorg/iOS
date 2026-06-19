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
