#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// The selection highlight renders in dedicated overlays ON TOP of content (text/emoji/image atoms),
/// not interleaved with the text drawing — body/caption in the canvas `selectionHighlight`, cells in
/// each table's content-view overlay.
final class SelectionHighlightTests: XCTestCase {
    private func canvas(_ blocks: [Block]) -> DocumentCanvasView {
        let c = DocumentCanvasView()
        c.setBlocks(blocks, width: 320)
        c.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        c.layoutIfNeeded()
        return c
    }

    func test_selectionHighlightOverlay_isAboveEmojiOverlay() {
        let c = canvas([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "ab")]))])
        let subs = c.subviews
        guard let iEmoji = subs.firstIndex(where: { $0 === c.emojiOverlay }),
              let iSel = subs.firstIndex(where: { $0 === c.selectionHighlight }) else {
            return XCTFail("overlays not found")
        }
        XCTAssertLessThan(iEmoji, iSel, "the selection highlight renders above the emoji overlay (on top of emoji)")
    }

    func test_isRegionInTable_classifiesBodyVsCell() {
        let cell = { (id: String) in
            Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: "x")]))]) }
        let table = TableBlock(id: BlockID("t"),
                               columns: [ColumnSpec(width: 1), ColumnSpec(width: 1)],
                               rows: [Row(id: BlockID("r"), cells: [cell("c1"), cell("c2")])])
        let c = canvas([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "ab")])), .table(table)])
        let regions = c.allLeafRegions()
        let body = regions.first { if case .paragraph(let id) = $0.ref { return id == BlockID("p") }; return false }
        let cellR = regions.first { if case .paragraph(let id) = $0.ref { return id == BlockID("c1p") }; return false }
        XCTAssertNotNil(body); XCTAssertNotNil(cellR)
        XCTAssertFalse(c.isRegionInTable(body!), "a body region is not in a table → drawn by the canvas overlay")
        XCTAssertTrue(c.isRegionInTable(cellR!), "a cell region is in a table → drawn by the table's content overlay")
    }

    func test_drawNonTableSelectionHighlight_runsForARangeSelection() {
        // Smoke: with a range selection set, the overlay's draw path executes without crashing and the
        // overlay is wired to the canvas.
        let c = canvas([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hello")]))])
        c.anchor = c.boxes[0].textStart; c.head = c.boxes[0].textStart + 5
        let renderer = UIGraphicsImageRenderer(size: c.bounds.size)
        _ = renderer.image { ctx in c.drawNonTableSelectionHighlight(in: ctx.cgContext) }
    }

    /// The headline fix: rendering the full layer tree (emoji subview + the on-top selection overlay),
    /// selecting a body emoji must CHANGE its rendered pixels — i.e. the wash draws over the emoji, not
    /// behind it (where the opaque emoji view would hide it).
    func test_selectionWash_rendersOverBodyEmoji() {
        func render(selected: Bool) -> [UInt8] {
            let c = DocumentCanvasView()
            c.emojiViewProvider = { _, size in
                let v = UIView(frame: CGRect(origin: .zero, size: size)); v.backgroundColor = .black; return v }
            c.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "ab")]))], width: 320)
            c.frame = CGRect(x: 0, y: 0, width: 320, height: 200); c.layoutIfNeeded()
            c.anchor = c.boxes[0].textStart + 1; c.head = c.anchor
            c.insertEmoji(id: "x", altText: nil)
            c.layoutIfNeeded()
            if selected { c.anchor = c.boxes[0].textStart + 1; c.head = c.boxes[0].textStart + 2 } // cover the emoji
            c.setNeedsDisplay(); c.layoutIfNeeded()
            let fmt = UIGraphicsImageRendererFormat(); fmt.opaque = false; fmt.scale = 1
            let image = UIGraphicsImageRenderer(bounds: c.bounds, format: fmt).image { ctx in
                c.layer.render(in: ctx.cgContext)   // renders the emoji subview + the overlay on top
            }
            return pixels(of: image.cgImage!)
        }
        XCTAssertNotEqual(render(selected: false), render(selected: true),
                          "selecting a body emoji must change its rendered pixels (wash draws over the emoji)")
    }

    func test_handleBoundingFrame_reservesKnobRoom_perEnd() {
        let caret = CGRect(x: 100, y: 50, width: 2, height: 20)
        let r = SelectionHandleView.knobRadius
        let startF = SelectionHandleView(isStart: true).boundingFrame(forCaret: caret)
        XCTAssertEqual(startF.minY, caret.minY - 2 * r, accuracy: 0.01, "START reserves the knob ABOVE the caret")
        XCTAssertEqual(startF.maxY, caret.maxY, accuracy: 0.01)
        XCTAssertEqual(startF.width, 2 * r, accuracy: 0.01)
        let endF = SelectionHandleView(isStart: false).boundingFrame(forCaret: caret)
        XCTAssertEqual(endF.minY, caret.minY, accuracy: 0.01)
        XCTAssertEqual(endF.maxY, caret.maxY + 2 * r, accuracy: 0.01, "END reserves the knob BELOW the caret")
    }

    func test_selectionHandles_shownForRange_hiddenWhenCollapsed() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        let c = DocumentCanvasView()
        c.frame = window.bounds
        window.addSubview(c)
        window.makeKeyAndVisible()
        c.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hello world")]))], width: 320)
        c.layoutIfNeeded()
        guard c.becomeFirstResponder() else { return XCTFail("canvas must become first responder") }
        c.anchor = c.boxes[0].textStart; c.head = c.boxes[0].textStart + 5   // select "hello"
        c.refreshSelectionUI()
        XCTAssertFalse(c.startHandleView.isHidden, "start handle shows for a range")
        XCTAssertFalse(c.endHandleView.isHidden, "end handle shows for a range")
        XCTAssertFalse(c.startHandleView.frame.isEmpty)
        XCTAssertNotEqual(c.startHandleView.frame, c.endHandleView.frame, "the two handles sit at different endpoints")
        c.anchor = c.head; c.refreshSelectionUI()                            // collapse
        XCTAssertTrue(c.startHandleView.isHidden, "handles hide for a collapsed selection")
        XCTAssertTrue(c.endHandleView.isHidden)
    }

    /// Full RGBA8 (premultiplied) pixel buffer of a CGImage.
    private func pixels(of image: CGImage) -> [UInt8] {
        let w = image.width, h = image.height
        var px = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return px
    }
}
#endif
