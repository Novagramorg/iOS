#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class QuoteCollapseIconsTests: XCTestCase {
    private let collapseImg = UIImage(systemName: "minus")!
    private let expandImg = UIImage(systemName: "plus")!

    private func quote(_ id: String, _ t: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), style: .quote, runs: [TextRun(text: t)]))
    }
    private let longQuote = String(repeating: "wrap this text across many lines ", count: 12)

    /// A canvas with a tall quote run, optionally injected icons + trailing inset, laid out at 2000pt tall.
    private func tallQuoteCanvas(icons: RichTextEditorQuoteCollapseIcons? = nil,
                                 trailingInset: CGFloat = 0, width: CGFloat = 300) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.applyQuoteCollapseIcons(icons)
        if trailingInset != 0 { v.applyQuoteStyle(QuoteStyle(trailingInset: trailingInset)) }
        v.setBlocks([quote("q", longQuote)], width: width)
        v.frame = CGRect(x: 0, y: 0, width: width, height: 2000); v.layoutIfNeeded()
        return v
    }
    private func visibleCollapseButtons(_ v: DocumentCanvasView) -> [UIButton] {
        v.quoteCollapseControls.subviews.compactMap { $0 as? UIButton }.filter { !$0.isHidden }
    }

    func test_iconsStruct_storesNonOptionalImages() {
        let icons = RichTextEditorQuoteCollapseIcons(collapse: collapseImg, expand: expandImg)
        XCTAssertTrue(icons.collapse === collapseImg)
        XCTAssertTrue(icons.expand === expandImg)
    }

    func test_applyQuoteCollapseIcons_setsControlsCollapseImage() {
        let v = DocumentCanvasView()
        v.applyQuoteCollapseIcons(RichTextEditorQuoteCollapseIcons(collapse: collapseImg, expand: expandImg))
        XCTAssertTrue(v.quoteCollapseControls.collapseImage === collapseImg)
    }

    func test_tallQuote_withIcons_showsOneCollapseButton() {
        let v = tallQuoteCanvas(icons: RichTextEditorQuoteCollapseIcons(collapse: collapseImg, expand: expandImg))
        XCTAssertEqual(visibleCollapseButtons(v).count, 1)
    }

    func test_tallQuote_withoutIcons_showsNoCollapseButton() {
        let v = tallQuoteCanvas(icons: nil)
        XCTAssertEqual(visibleCollapseButtons(v).count, 0, "no injected icon ⇒ no button (no SF-Symbol fallback)")
    }

    func test_collapseButtonRect_anchoredToFillEdge_independentOfTrailingInset() {
        let v = tallQuoteCanvas(icons: RichTextEditorQuoteCollapseIcons(collapse: collapseImg, expand: expandImg),
                                trailingInset: 40)
        let run = v.collapseButtonRuns().first!
        let fillMaxX = v.boxes[0].frame.maxX
        XCTAssertEqual(run.rect.width, 18, accuracy: 0.5)
        XCTAssertEqual(run.rect.maxX, fillMaxX - 2, accuracy: 0.5, "2pt from the fill edge, ignoring trailingInset")
        XCTAssertEqual(run.rect.minY, v.boxes[0].frame.minY + 2, accuracy: 0.5)
    }

    // MARK: collapsed-quote expand glyph

    private func collapsed(_ id: String) -> Block {
        .collapsedQuote(CollapsedQuote(id: BlockID(id), paragraphs: [
            ParagraphBlock(id: BlockID(id + "p"), style: .quote, runs: [TextRun(text: "x")])]))
    }
    private func collapsedCanvas(icons: RichTextEditorQuoteCollapseIcons?, width: CGFloat = 300) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.applyQuoteCollapseIcons(icons)
        v.setBlocks([collapsed("q")], width: width)
        v.frame = CGRect(x: 0, y: 0, width: width, height: 600); v.layoutIfNeeded()
        return v
    }

    func test_collapsedBox_storesInjectedExpandImage() {
        let v = collapsedCanvas(icons: RichTextEditorQuoteCollapseIcons(collapse: collapseImg, expand: expandImg))
        let box = v.boxes.first as! CollapsedQuoteBox
        XCTAssertTrue(box.expandImage === expandImg)
    }

    func test_collapsedBox_withoutIcons_hasNilExpandImage() {
        let v = collapsedCanvas(icons: nil)
        let box = v.boxes.first as! CollapsedQuoteBox
        XCTAssertNil(box.expandImage)
    }

    func test_expandGlyphRect_is18ptAnchoredTopRight() {
        let v = collapsedCanvas(icons: RichTextEditorQuoteCollapseIcons(collapse: collapseImg, expand: expandImg))
        let box = v.boxes.first as! CollapsedQuoteBox
        let r = box.expandGlyphRect()
        XCTAssertEqual(r.width, 18, accuracy: 0.5)
        XCTAssertEqual(r.height, 18, accuracy: 0.5)
        XCTAssertEqual(r.maxX, box.frame.maxX - 4, accuracy: 0.5)
        XCTAssertEqual(r.minY, box.frame.minY + 4, accuracy: 0.5)
    }
}
#endif
