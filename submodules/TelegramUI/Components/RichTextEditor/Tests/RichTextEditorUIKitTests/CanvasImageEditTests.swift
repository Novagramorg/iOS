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
    private func img() -> (UIImage, CGSize) {
        let s = CGSize(width: 60, height: 40)
        return (UIGraphicsImageRenderer(size: s).image { c in UIColor.systemPink.setFill(); c.fill(CGRect(origin: .zero, size: s)) }, s)
    }

    func test_insertImage_atEndOfParagraph_addsImageBlockAfter() {
        let v = canvas(["Alpha"])
        caret(v, v.boxes[0].textStart + 5)               // end of "Alpha"
        let (image, size) = img()
        v.insertImage(image, naturalSize: size, assetID: "k1")
        XCTAssertEqual(v.boxes.count, 2)
        XCTAssertTrue(v.boxes[1] is ImageBlockBox)
        XCTAssertEqual(v.head, v.boxes[1].textStart)     // caret in the caption
    }

    func test_typingIntoEmptyCaption_staysCentered() {
        let v = canvas(["Alpha"])
        caret(v, v.boxes[0].textStart + 5)               // end of "Alpha"
        let (image, size) = img()
        v.insertImage(image, naturalSize: size, assetID: "kc")
        let imgBox = v.boxes[1] as! ImageBlockBox
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

    func test_insertImage_midParagraph_splitsAroundImage() {
        let v = canvas(["Alpha"])
        caret(v, v.boxes[0].textStart + 2)               // after "Al"
        let (image, size) = img()
        v.insertImage(image, naturalSize: size, assetID: "k2")
        XCTAssertEqual(v.boxes.count, 3)
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "Al")
        XCTAssertTrue(v.boxes[1] is ImageBlockBox)
        XCTAssertEqual((v.boxes[2] as! BlockBox).currentParagraph().text, "pha")
    }

    func test_insertImage_isUndoable() {
        let v = canvas(["Alpha"])
        let um = UndoManager(); um.groupsByEvent = false
        v.undoManagerOverride = um
        caret(v, v.boxes[0].textStart + 5)
        let (image, size) = img()
        um.beginUndoGrouping(); v.insertImage(image, naturalSize: size, assetID: "k3"); um.endUndoGrouping()
        XCTAssertEqual(v.boxes.count, 2)
        um.undo()
        XCTAssertEqual(v.boxes.count, 1)
        XCTAssertFalse(v.boxes.contains { $0 is ImageBlockBox })
    }

    private func docWithImage() -> DocumentCanvasView {
        let v = canvas(["Above", "Below"])
        caret(v, v.boxes[0].textStart + 5)
        let (image, size) = img()
        v.insertImage(image, naturalSize: size, assetID: "k")   // → ["Above", image, "Below"]
        return v
    }

    func test_backspaceAtGapBeforeImage_deletesImage() {
        let v = docWithImage()
        caret(v, v.boxes[1].nodeStart)                  // gap before the image
        v.deleteBackward()
        XCTAssertEqual(v.boxes.count, 2)
        XCTAssertFalse(v.boxes.contains { $0 is ImageBlockBox })
    }

    func test_backspaceAtCaptionStart_deletesImage() {
        let v = docWithImage()
        caret(v, v.boxes[1].textStart)                  // start of the caption
        v.deleteBackward()
        XCTAssertFalse(v.boxes.contains { $0 is ImageBlockBox })
    }

    func test_backspaceAtStartOfParagraphAfterImage_deletesImage() {
        let v = docWithImage()
        caret(v, v.boxes[2].textStart)                  // start of "Below" (box after the image)
        v.deleteBackward()
        XCTAssertFalse(v.boxes.contains { $0 is ImageBlockBox })
        XCTAssertEqual((v.boxes.last as! BlockBox).currentParagraph().text, "Below")
    }

    func test_deleteImage_isUndoable() {
        let v = docWithImage()
        let um = UndoManager(); um.groupsByEvent = false
        v.undoManagerOverride = um
        caret(v, v.boxes[1].nodeStart)
        um.beginUndoGrouping(); v.deleteBackward(); um.endUndoGrouping()
        XCTAssertFalse(v.boxes.contains { $0 is ImageBlockBox })
        um.undo()
        XCTAssertTrue(v.boxes.contains { $0 is ImageBlockBox })
    }

    func test_typingAtGapBeforeImage_insertsParagraphBeforeImage() {
        let v = docWithImage()                          // ["Above", image, "Below"]
        caret(v, v.boxes[1].nodeStart)                  // gap before the image
        v.insertText("Hi")
        XCTAssertEqual(v.boxes.count, 4)
        XCTAssertEqual((v.boxes[1] as! BlockBox).currentParagraph().text, "Hi")  // new paragraph before image
        XCTAssertTrue(v.boxes[2] is ImageBlockBox)
        XCTAssertEqual(v.head, v.boxes[1].textStart + 2)                         // caret at end of "Hi"
        guard case .image(let out) = v.boxes[2].currentBlock() else { return XCTFail() }
        XCTAssertEqual(out.caption.map(\.text).joined(), "")                     // caption untouched
    }

    func test_enterAtGapBeforeImage_insertsEmptyParagraphBeforeImage() {
        let v = docWithImage()
        caret(v, v.boxes[1].nodeStart)
        v.insertText("\n")
        XCTAssertEqual(v.boxes.count, 4)
        XCTAssertEqual((v.boxes[1] as! BlockBox).currentParagraph().text, "")    // empty paragraph before image
        XCTAssertTrue(v.boxes[2] is ImageBlockBox)
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
        let (image, size) = img()
        v.insertImage(image, naturalSize: size, assetID: "k0")  // → [image, "Below"]
        caret(v, v.boxes[0].nodeStart)                  // gap before the leading image
        v.insertText("Top")
        XCTAssertEqual(v.boxes.count, 3)
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "Top")  // new first block
        XCTAssertTrue(v.boxes[1] is ImageBlockBox)
        XCTAssertEqual(v.head, v.boxes[0].textStart + 3)
    }
}
#endif
