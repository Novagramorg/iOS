#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CanvasImageEditTests: XCTestCase {
    private func canvas(_ texts: [String]) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.imageProvider = { _ in UIGraphicsImageRenderer(size: CGSize(width: 60, height: 40)).image { c in
            UIColor.systemPink.setFill(); c.fill(CGRect(x: 0, y: 0, width: 60, height: 40)) } }
        v.setBlocks(texts.enumerated().map { .paragraph(ParagraphBlock(id: BlockID("p\($0.offset)"), runs: [TextRun(text: $0.element)])) },
                    width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400); v.layoutIfNeeded()
        return v
    }
    private func caret(_ v: DocumentCanvasView, _ pos: Int) {
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(pos), DocumentTextPosition(pos))
    }
    /// The medium's natural size. (The editor no longer CPU-draws a UIImage — media is a host-supplied
    /// view keyed by `mediaID`; these edit/undo/structure tests need only the block's natural size.)
    private func imgSize() -> CGSize { CGSize(width: 60, height: 40) }

    func test_insertImage_atEndOfParagraph_addsImageBlockAfter() {
        let v = canvas(["Alpha"])
        caret(v, v.boxes[0].textStart + 5)               // end of "Alpha"
        let size = imgSize()
        v.insertMedia(mediaID: "k1", naturalSize: size, kind: .image)
        XCTAssertEqual(v.boxes.count, 2)
        XCTAssertTrue(v.boxes[1] is MediaBlockBox)
        XCTAssertEqual(v.head, v.boxes[1].textStart)     // caret in the caption
    }

    func test_typingIntoEmptyCaption_staysCentered() {
        let v = canvas(["Alpha"])
        caret(v, v.boxes[0].textStart + 5)               // end of "Alpha"
        let size = imgSize()
        v.insertMedia(mediaID: "kc", naturalSize: size, kind: .image)
        let imgBox = v.boxes[1] as! MediaBlockBox
        caret(v, imgBox.textStart)                       // start of the EMPTY caption
        // The caption is render-only centered; typing into an empty caption must carry that centering,
        // not fall back to left-aligned. (Before the fix, the empty-region typing path used .body/.default
        // = left, because a caption's ref is .caption(id), not .paragraph(id).)
        XCTAssertEqual((v.typingAttributesAtGlobal(imgBox.textStart)[.paragraphStyle] as? NSParagraphStyle)?.alignment,
                       .center)
        v.insertText("Hi")
        XCTAssertEqual(imgBox.caption.attributedString.string, "Hi")
        let ps = imgBox.caption.attributedString.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(ps?.alignment, .center)           // typed text is centered, like the placeholder
    }

    func test_insertImage_onEmptyParagraph_replacesParagraph() {
        let v = canvas([""])                             // a single empty paragraph
        caret(v, v.boxes[0].textStart)
        v.insertMedia(mediaID: "ke", naturalSize: imgSize(), kind: .image)
        XCTAssertEqual(v.boxes.count, 1, "the empty paragraph is replaced by the image, not left beside it")
        XCTAssertTrue(v.boxes[0] is MediaBlockBox)
        XCTAssertEqual(v.head, v.boxes[0].textStart, "caret lands in the image's caption")
    }

    func test_insertImage_onEmptyParagraphBetweenContent_replacesIt() {
        let v = canvas(["A", "", "B"])                   // A, empty middle paragraph, B
        caret(v, v.boxes[1].textStart)
        v.insertMedia(mediaID: "km", naturalSize: imgSize(), kind: .image)
        XCTAssertEqual(v.boxes.count, 3, "A | image | B — the empty paragraph is replaced, not split into two empties")
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "A")
        XCTAssertTrue(v.boxes[1] is MediaBlockBox)
        XCTAssertEqual((v.boxes[2] as! BlockBox).currentParagraph().text, "B")
    }

    func test_insertImage_midParagraph_splitsAroundImage() {
        let v = canvas(["Alpha"])
        caret(v, v.boxes[0].textStart + 2)               // after "Al"
        let size = imgSize()
        v.insertMedia(mediaID: "k2", naturalSize: size, kind: .image)
        XCTAssertEqual(v.boxes.count, 3)
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "Al")
        XCTAssertTrue(v.boxes[1] is MediaBlockBox)
        XCTAssertEqual((v.boxes[2] as! BlockBox).currentParagraph().text, "pha")
    }

    func test_insertImage_isUndoable() {
        let v = canvas(["Alpha"])
        let um = UndoManager(); um.groupsByEvent = false
        v.undoManagerOverride = um
        caret(v, v.boxes[0].textStart + 5)
        let size = imgSize()
        um.beginUndoGrouping(); v.insertMedia(mediaID: "k3", naturalSize: size, kind: .image); um.endUndoGrouping()
        XCTAssertEqual(v.boxes.count, 2)
        um.undo()
        XCTAssertEqual(v.boxes.count, 1)
        XCTAssertFalse(v.boxes.contains { $0 is MediaBlockBox })
    }

    private func docWithImage() -> DocumentCanvasView {
        let v = canvas(["Above", "Below"])
        caret(v, v.boxes[0].textStart + 5)
        let size = imgSize()
        v.insertMedia(mediaID: "k", naturalSize: size, kind: .image)   // → ["Above", image, "Below"]
        return v
    }

    func test_backspaceAtGapBeforeImage_nonEmptyPrev_movesToEndOfPrev_keepsImage() {
        // Backspace at the media's leading gap must NOT delete the media. With a non-empty previous
        // paragraph, it just moves the caret to the end of that paragraph (no deletion).
        let v = docWithImage()                          // ["Above", image, "Below"]
        caret(v, v.boxes[1].nodeStart)                  // gap before the image
        v.deleteBackward()
        XCTAssertEqual(v.boxes.count, 3, "the media block is kept")
        XCTAssertTrue(v.boxes[1] is MediaBlockBox)
        XCTAssertEqual(v.head, v.boxes[0].textStart + v.boxes[0].textLength, "caret moved to the end of 'Above'")
        XCTAssertEqual(v.head, v.anchor, "collapsed caret")
    }

    func test_backspaceAtGapBeforeImage_emptyPrev_deletesEmptyParagraph_keepsImage() {
        // With an EMPTY previous paragraph, backspace at the gap deletes that paragraph (not the media);
        // the caret stays at the media's gap.
        let v = docWithImage()                          // ["Above", image, "Below"]
        caret(v, v.boxes[1].nodeStart)
        v.insertText("\n")                              // Enter at gap → ["Above", "", image, "Below"]
        XCTAssertEqual((v.boxes[1] as? BlockBox)?.textLength, 0, "precondition: empty paragraph before the image")
        let imageBox = v.boxes.first { $0 is MediaBlockBox }!
        caret(v, imageBox.nodeStart)                    // back on the gap before the image
        v.deleteBackward()
        XCTAssertEqual(v.boxes.count, 3, "the empty paragraph is removed (4 → 3); media kept")
        XCTAssertTrue(v.boxes[1] is MediaBlockBox, "media now sits directly after 'Above'")
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "Above", "previous paragraph intact")
        XCTAssertEqual(v.head, (v.boxes[1] as! MediaBlockBox).nodeStart, "caret stays at the media gap")
    }

    func test_backspaceAtCaptionStart_deletesImage() {
        let v = docWithImage()
        caret(v, v.boxes[1].textStart)                  // start of the EMPTY caption
        v.deleteBackward()
        XCTAssertFalse(v.boxes.contains { $0 is MediaBlockBox })
    }

    func test_backspaceOnEmptyCaption_whenImageIsOnlyBlock_leavesEmptyParagraph() {
        // Deleting the document's only block must never leave a zero-block document — it leaves a single
        // empty paragraph. (A lone [image] is reachable since inserting on an empty paragraph replaces it.)
        let v = canvas([""])                            // single empty paragraph
        caret(v, v.boxes[0].textStart)
        v.insertMedia(mediaID: "ko", naturalSize: imgSize(), kind: .image)   // replaces the empty para → [image]
        XCTAssertEqual(v.boxes.count, 1)
        XCTAssertTrue(v.boxes[0] is MediaBlockBox)
        caret(v, v.boxes[0].textStart)                  // caret in the empty caption
        v.deleteBackward()
        XCTAssertFalse(v.boxes.contains { $0 is MediaBlockBox }, "the image is deleted")
        XCTAssertEqual(v.boxes.count, 1, "the document keeps a single empty paragraph — never zero blocks")
        XCTAssertTrue(v.boxes[0] is BlockBox)
        XCTAssertEqual(v.boxes[0].textLength, 0)
    }

    func test_backspaceWithSelectionCoveringImageNode_deletesImage() {
        // Tapping an empty image caption places a collapsed caret at the caption, but UIKit then EXPANDS it
        // (via the selectedTextRange setter) into a selection covering the whole image node [nodeStart,
        // captionEnd] — the "object replacement" atom. Backspace over that selection must delete the image
        // (it previously resolved both endpoints to the same media box and no-op'd → "backspace does nothing").
        let v = docWithImage()                           // ["Above", image, "Below"]
        let im = v.boxes[1] as! MediaBlockBox
        // Reproduce the OS expansion exactly: anchor at the image's gap, head at the (empty) caption start.
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(im.nodeStart), DocumentTextPosition(im.textStart))
        XCTAssertNotEqual(v.selFrom, v.selTo, "precondition: a real selection spanning the image node")
        v.deleteBackward()
        XCTAssertFalse(v.boxes.contains { $0 is MediaBlockBox }, "the image is deleted")
        XCTAssertEqual((v.boxes.map { ($0 as? BlockBox)?.currentParagraph().text }), ["Above", "Below"])
    }

    func test_backspaceAtStartOfNonEmptyCaption_keepsImageAndCaption_movesCaretToGap() {
        // Backspace at the START of a NON-empty caption must NOT destroy the image and its caption text —
        // the image-delete is gated on the caption being EMPTY. The caret steps back to the image's gap.
        let v = docWithImage()                          // ["Above", image, "Below"]
        let im = v.boxes[1] as! MediaBlockBox
        caret(v, im.textStart)
        v.insertText("Cap")                             // caption is now "Cap"
        caret(v, im.textStart)                          // caret back to the caption START
        v.deleteBackward()
        XCTAssertTrue(v.boxes.contains { $0 is MediaBlockBox }, "non-empty caption: the image is kept")
        XCTAssertEqual((v.boxes[1] as! MediaBlockBox).caption.attributedString.string, "Cap", "caption text intact")
        XCTAssertEqual(v.head, v.boxes[1].nodeStart, "caret steps back to the image's gap (no delete)")
    }

    private func imageThenEmptyParagraph() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.imageProvider = { _ in UIGraphicsImageRenderer(size: CGSize(width: 60, height: 40)).image { c in
            UIColor.systemPink.setFill(); c.fill(CGRect(x: 0, y: 0, width: 60, height: 40)) } }
        v.setBlocks([
            .media(MediaBlock(id: BlockID("img"), mediaID: "k", naturalSize: Size2D(width: 60, height: 40))),
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: []))   // empty paragraph after the image
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400); v.layoutIfNeeded()
        return v
    }

    func test_backspaceAtStartOfEmptyParagraphAfterImage_removesParagraph_keepsImage() {
        // The reported bug: caret at the start of an EMPTY paragraph directly below an image. Backspace
        // must remove the empty PARAGRAPH (not the image), parking the caret at the image's caption end.
        let v = imageThenEmptyParagraph()               // [image, ""]
        XCTAssertEqual(v.boxes.count, 2)
        caret(v, v.boxes[1].textStart)                  // start of the empty paragraph
        v.deleteBackward()
        XCTAssertEqual(v.boxes.count, 1, "the empty paragraph is removed; the image is NOT deleted")
        XCTAssertTrue(v.boxes[0] is MediaBlockBox, "the image is kept")
        XCTAssertEqual(v.head, v.boxes[0].textStart + v.boxes[0].textLength, "caret parks at the image's caption end")
        XCTAssertEqual(v.head, v.anchor, "collapsed caret")
    }

    func test_backspaceAtStartOfEmptyParagraphAfterImage_isUndoable() {
        let v = imageThenEmptyParagraph()               // [image, ""]
        let um = UndoManager(); um.groupsByEvent = false
        v.undoManagerOverride = um
        caret(v, v.boxes[1].textStart)
        um.beginUndoGrouping(); v.deleteBackward(); um.endUndoGrouping()
        XCTAssertEqual(v.boxes.count, 1, "empty paragraph removed")
        XCTAssertTrue(v.boxes.contains { $0 is MediaBlockBox }, "image kept")
        um.undo()
        XCTAssertEqual(v.boxes.count, 2, "undo restores the empty paragraph")
        XCTAssertTrue(v.boxes[0] is MediaBlockBox)
        XCTAssertEqual((v.boxes[1] as? BlockBox)?.textLength, 0)
    }

    func test_backspaceAtStartOfNonEmptyParagraphAfterImage_keepsImageAndText_movesCaretIntoCaption() {
        // Backspace at the start of a NON-EMPTY paragraph below an image must NOT delete the image and
        // must NOT delete the paragraph's text — it just steps the caret back to the image's caption end.
        let v = docWithImage()                          // ["Above", image, "Below"]
        caret(v, v.boxes[2].textStart)                  // start of "Below" (box after the image)
        v.deleteBackward()
        XCTAssertEqual(v.boxes.count, 3, "nothing is deleted")
        XCTAssertTrue(v.boxes[1] is MediaBlockBox, "the image is kept")
        XCTAssertEqual((v.boxes[2] as! BlockBox).currentParagraph().text, "Below", "the paragraph text is intact")
        XCTAssertEqual(v.head, v.boxes[1].textStart + v.boxes[1].textLength, "caret moved to the image's caption end")
        XCTAssertEqual(v.head, v.anchor, "collapsed caret")
    }

    func test_backspaceAtGapDeletingEmptyParagraph_isUndoable() {
        let v = docWithImage()                          // ["Above", image, "Below"]
        caret(v, v.boxes[1].nodeStart)
        v.insertText("\n")                              // ["Above", "", image, "Below"]
        let imageBox = v.boxes.first { $0 is MediaBlockBox }!
        let um = UndoManager(); um.groupsByEvent = false
        v.undoManagerOverride = um
        caret(v, imageBox.nodeStart)
        um.beginUndoGrouping(); v.deleteBackward(); um.endUndoGrouping()
        XCTAssertEqual(v.boxes.count, 3, "empty paragraph removed")
        XCTAssertTrue(v.boxes.contains { $0 is MediaBlockBox }, "the media is kept (the empty paragraph was deleted, not the image)")
        um.undo()
        XCTAssertEqual(v.boxes.count, 4, "undo restores the empty paragraph")
        XCTAssertEqual((v.boxes[1] as? BlockBox)?.textLength, 0)
    }

    func test_typingAtGapBeforeImage_insertsParagraphBeforeImage() {
        let v = docWithImage()                          // ["Above", image, "Below"]
        caret(v, v.boxes[1].nodeStart)                  // gap before the image
        v.insertText("Hi")
        XCTAssertEqual(v.boxes.count, 4)
        XCTAssertEqual((v.boxes[1] as! BlockBox).currentParagraph().text, "Hi")  // new paragraph before image
        XCTAssertTrue(v.boxes[2] is MediaBlockBox)
        XCTAssertEqual(v.head, v.boxes[1].textStart + 2)                         // caret at end of "Hi"
        guard case .media(let out) = v.boxes[2].currentBlock() else { return XCTFail() }
        XCTAssertEqual(out.caption.map(\.text).joined(), "")                     // caption untouched
    }

    func test_enterAtGapBeforeImage_insertsEmptyParagraphBeforeImage() {
        let v = docWithImage()
        caret(v, v.boxes[1].nodeStart)
        v.insertText("\n")
        XCTAssertEqual(v.boxes.count, 4)
        XCTAssertEqual((v.boxes[1] as! BlockBox).currentParagraph().text, "")    // empty paragraph before image
        XCTAssertTrue(v.boxes[2] is MediaBlockBox)
        XCTAssertEqual(v.head, v.boxes[1].textStart)                            // caret in the empty paragraph
    }

    func test_typingAtGapBeforeImage_isUndoable() {
        let v = docWithImage()
        let um = UndoManager(); um.groupsByEvent = false
        v.undoManagerOverride = um
        caret(v, v.boxes[1].nodeStart)
        um.beginUndoGrouping(); v.insertText("Hi"); um.endUndoGrouping()
        XCTAssertEqual(v.boxes.count, 4)
        um.undo()
        XCTAssertEqual(v.boxes.count, 3)
        XCTAssertFalse(v.boxes.contains { ($0 as? BlockBox)?.currentParagraph().text == "Hi" })
    }

    func test_typingAtGapBeforeLeadingImage_insertsParagraphAtDocumentStart() {
        let v = canvas(["Below"])
        caret(v, v.boxes[0].textStart)                  // start of "Below"
        let size = imgSize()
        v.insertMedia(mediaID: "k0", naturalSize: size, kind: .image)  // → [image, "Below"]
        caret(v, v.boxes[0].nodeStart)                  // gap before the leading image
        v.insertText("Top")
        XCTAssertEqual(v.boxes.count, 3)
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "Top")  // new first block
        XCTAssertTrue(v.boxes[1] is MediaBlockBox)
        XCTAssertEqual(v.head, v.boxes[0].textStart + 3)
    }

    // MARK: - Select All + backspace removes a covered image (regardless of its position)

    private func leadingImage() -> DocumentCanvasView {
        let v = canvas(["Below"])
        caret(v, v.boxes[0].textStart)
        v.insertMedia(mediaID: "kl", naturalSize: imgSize(), kind: .image)   // → [image, "Below"]
        return v
    }
    private func trailingImage() -> DocumentCanvasView {
        let v = canvas(["Above"])
        caret(v, v.boxes[0].textStart + 5)
        v.insertMedia(mediaID: "kt", naturalSize: imgSize(), kind: .image)   // → ["Above", image]
        return v
    }

    func test_selectAll_thenBackspace_removesMiddleImage() {
        let v = docWithImage()                           // ["Above", image, "Below"]
        v.selectAllText()
        v.deleteBackward()
        XCTAssertFalse(v.boxes.contains { $0 is MediaBlockBox }, "Select All + backspace removes the image")
        XCTAssertEqual(v.boxes.count, 1, "the document collapses to one empty paragraph")
        XCTAssertEqual(v.boxes[0].textLength, 0)
    }

    func test_selectAll_thenBackspace_removesTrailingImage() {
        let v = trailingImage()                          // ["Above", image]
        v.selectAllText()
        v.deleteBackward()
        XCTAssertFalse(v.boxes.contains { $0 is MediaBlockBox }, "Select All + backspace removes a trailing image")
        XCTAssertEqual(v.boxes.count, 1)
        XCTAssertEqual(v.boxes[0].textLength, 0)
    }

    func test_selectAll_thenBackspace_removesLeadingImage() {
        let v = leadingImage()                           // [image, "Below"]
        v.selectAllText()
        v.deleteBackward()
        XCTAssertFalse(v.boxes.contains { $0 is MediaBlockBox }, "Select All + backspace removes a leading image")
        XCTAssertEqual(v.boxes.count, 1)
        XCTAssertEqual(v.boxes[0].textLength, 0)
    }
}
#endif
