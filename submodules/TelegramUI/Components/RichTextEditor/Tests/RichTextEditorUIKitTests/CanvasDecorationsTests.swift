#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CanvasDecorationsTests: XCTestCase {
    private func canvas(_ blocks: [Block], width: CGFloat = 390) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks(blocks, width: width)
        v.frame = CGRect(x: 0, y: 0, width: width, height: 600); v.layoutIfNeeded()
        return v
    }

    func test_quote_notItalic() {
        XCTAssertFalse(StyleSheet.default.font(for: .quote, attributes: .plain)
            .fontDescriptor.symbolicTraits.contains(.traitItalic))
    }

    func test_blockquoteDecoration_barAndFill() {
        let v = canvas([
            .paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "Body")])),
            .paragraph(ParagraphBlock(id: BlockID("q"), style: .quote, runs: [TextRun(text: "Quote")])),
        ])
        let decs = v.blockquoteDecorations()
        XCTAssertEqual(decs.count, 1)                                  // only the quote block
        XCTAssertEqual(decs[0].bar.minX, CanvasMetrics.pageMargin, accuracy: 0.5)   // bar at the text margin (16)
        XCTAssertEqual(decs[0].bar.width, 3, accuracy: 0.5)
        XCTAssertGreaterThan(decs[0].fill.width, decs[0].bar.width)    // fill spans the block
    }

    func test_consecutiveQuoteBlocks_shareOneBackground() {
        let v = canvas([
            .paragraph(ParagraphBlock(id: BlockID("q1"), style: .quote, runs: [TextRun(text: "First line")])),
            .paragraph(ParagraphBlock(id: BlockID("q2"), style: .quote, runs: [TextRun(text: "Second line")])),
        ])
        let decs = v.blockquoteDecorations()
        XCTAssertEqual(decs.count, 1)                                          // one background for the whole quote
        XCTAssertEqual(decs[0].fill.minY, v.boxes[0].frame.minY, accuracy: 0.5)  // spans from the first block...
        XCTAssertEqual(decs[0].fill.maxY, v.boxes[1].frame.maxY, accuracy: 0.5)  // ...through the last
        XCTAssertEqual(decs[0].bar.height, decs[0].fill.height, accuracy: 0.5)   // one continuous bar
    }

    func test_quoteRunsSeparatedByParagraph_makeSeparateBackgrounds() {
        let v = canvas([
            .paragraph(ParagraphBlock(id: BlockID("q1"), style: .quote, runs: [TextRun(text: "A")])),
            .paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "Body")])),
            .paragraph(ParagraphBlock(id: BlockID("q2"), style: .quote, runs: [TextRun(text: "B")])),
        ])
        XCTAssertEqual(v.blockquoteDecorations().count, 2)                     // two distinct quotes → two backgrounds
    }

    func test_codeBlock_contributesItsOwnBackgroundRun() {
        let v = canvas([
            .paragraph(ParagraphBlock(id: BlockID("q"), style: .quote, runs: [TextRun(text: "Quote")])),
            .code(CodeBlock(id: BlockID("c"), runs: [TextRun(text: "let x = 1")])),
        ])
        let decs = v.blockquoteDecorations()
        XCTAssertEqual(decs.count, 2, "quote run and code run are distinct backgrounds, not merged")
        let codeBox = v.boxes.first(where: { $0 is CodeBlockBox })!
        let codeDec = decs.first(where: { $0.fill == codeBox.frame })!
        XCTAssertEqual(codeDec.fill.minY, codeBox.frame.minY, accuracy: 0.5)   // fill spans the code block
        XCTAssertEqual(codeDec.fill.maxY, codeBox.frame.maxY, accuracy: 0.5)
        XCTAssertEqual(codeDec.bar.minX, codeBox.frame.minX, accuracy: 0.5)     // bar at the block's left edge
        XCTAssertEqual(codeDec.bar.width, v.quoteStyle.barWidth, accuracy: 0.5) // bar width tracks the quote bar
    }

    func test_codeBlockBetweenQuotes_splitsIntoThreeRuns() {
        let v = canvas([
            .paragraph(ParagraphBlock(id: BlockID("q1"), style: .quote, runs: [TextRun(text: "A")])),
            .code(CodeBlock(id: BlockID("c"), runs: [TextRun(text: "code")])),
            .paragraph(ParagraphBlock(id: BlockID("q2"), style: .quote, runs: [TextRun(text: "B")])),
        ])
        XCTAssertEqual(v.blockquoteDecorations().count, 3,
                       "the code block flushes the quote run before and after it")
    }

    func test_typeSomethingPlaceholder_onlyOnLastBlock() {
        // Two empty body paragraphs: the "Type something…" placeholder shows ONLY on the last block.
        let v = canvas([
            .paragraph(ParagraphBlock(id: BlockID("a"), style: .body, runs: [])),
            .paragraph(ParagraphBlock(id: BlockID("b"), style: .body, runs: [])),
        ])
        let draws = v.placeholderDraws()
        XCTAssertEqual(draws.map(\.text), ["Type something…"], "only one placeholder — on the last block")
        // It belongs to the LAST box (box "b"), not the first.
        let lastBox = v.boxes[1]
        XCTAssertEqual(draws.first?.origin.y ?? -1, lastBox.textOrigin.y, accuracy: 8.0,
                       "the placeholder sits on the last block, not the first")
    }

    func test_typeSomethingPlaceholder_notShown_whenEmptyBodyIsNotLast() {
        // An empty body paragraph that is NOT the last block shows no placeholder.
        let v = canvas([
            .paragraph(ParagraphBlock(id: BlockID("a"), style: .body, runs: [])),
            .paragraph(ParagraphBlock(id: BlockID("b"), style: .heading1, runs: [TextRun(text: "Hi")])),
        ])
        XCTAssertTrue(v.placeholderDraws().isEmpty,
                      "a non-last empty body shows no placeholder; the last block has content")
    }

    func test_placeholder_onlyBodyAmongStyles_whenEmpty() {
        let v = canvas([
            .paragraph(ParagraphBlock(id: BlockID("h"), style: .heading1, runs: [])),
            .paragraph(ParagraphBlock(id: BlockID("b"), style: .body, runs: [])),
        ])
        let draws = v.placeholderDraws()
        XCTAssertEqual(draws.map(\.text), ["Type something…"],
                       "only an empty body paragraph shows a placeholder; headings don't")
    }

    func test_placeholder_baselineMatchesRealFirstLineBaseline() {
        // The placeholder must sit on the paragraph's real first-line baseline, not float above it. Real
        // text's first baseline is pushed down by (lineHeightMultiple − 1)·lineHeight (body = 1.10); a
        // placeholder drawn with bare font metrics would be ~2pt high. Assert the draw origin carries that
        // downward shift (and x stays at the text column).
        let v = canvas([.paragraph(ParagraphBlock(id: BlockID("b"), style: .body, runs: []))])
        let box = v.boxes[0] as! BlockBox
        let draw = v.placeholderDraws().first!
        let font = StyleSheet.default.font(for: .body, attributes: .plain)
        let ps = StyleSheet.default.paragraphStyle(for: .body, attributes: ParagraphAttributes(), list: nil)
        let expectedShift = (ps.lineHeightMultiple - 1) * font.lineHeight
        XCTAssertGreaterThan(expectedShift, 1.0)                                  // body shift is ~2pt
        XCTAssertEqual(draw.origin.y, box.textOrigin.y + expectedShift, accuracy: 0.5)
        XCTAssertEqual(draw.origin.x, box.textOrigin.x, accuracy: 0.5)            // horizontal unchanged
    }

    func test_emptyParagraph_caretRectSpansTheLineHeight() {
        // An empty line's caret must span the real line height (font.lineHeight × lineHeightMultiple), not the
        // fixed 20pt fallback BlockLayout returns when there's no laid-out fragment — so it aligns with the
        // placeholder and with a typed line.
        let v = canvas([.paragraph(ParagraphBlock(id: BlockID("b"), style: .body, runs: []))])
        let box = v.boxes[0] as! BlockBox
        let caret = v.caretRect(for: DocumentTextPosition(box.textStart))
        let font = StyleSheet.default.font(for: .body, attributes: .plain)
        let ps = StyleSheet.default.paragraphStyle(for: .body, attributes: ParagraphAttributes(), list: nil)
        let mult = ps.lineHeightMultiple > 0 ? ps.lineHeightMultiple : 1
        XCTAssertEqual(caret.height, font.lineHeight * mult, accuracy: 0.5)
        XCTAssertGreaterThan(caret.height, 20.5)                                  // taller than the fixed-20 fallback
    }

    func test_placeholder_listItem_isInsetByHeadIndent() {
        // An empty list item shows a list-specific hint; it must be inset to the list's text column
        // (aligned with where typed text appears, past the marker), not drawn at the page margin.
        let v = canvas([.paragraph(ParagraphBlock(id: BlockID("li"), style: .body,
                                                  list: ListMembership(marker: .bullet), runs: []))])
        let box = v.boxes[0] as! BlockBox
        let draw = v.placeholderDraws().first { $0.text == "Press return to end the list" }
        XCTAssertNotNil(draw)
        XCTAssertEqual(draw!.origin.x, box.textOrigin.x + StyleSheet.listMarkerSpacing, accuracy: 0.5)
    }

    func test_placeholder_emptyListItem_level0_saysEndTheList() {
        let v = canvas([.paragraph(ParagraphBlock(id: BlockID("li"), style: .body,
                                                  list: ListMembership(marker: .bullet), runs: []))])
        XCTAssertEqual(v.placeholderDraws().first?.text, "Press return to end the list")
    }

    func test_placeholder_emptyNestedListItem_saysOutdent() {
        let v = canvas([.paragraph(ParagraphBlock(id: BlockID("li"), style: .body,
                                                  list: ListMembership(marker: .bullet, level: 1), runs: []))])
        XCTAssertEqual(v.placeholderDraws().first?.text, "Press return to outdent")
    }

    func test_placeholder_emptyOrderedListItem_alsoSaysEndTheList() {
        // The hint is about the list, not the marker style — ordered items get it too.
        let v = canvas([.paragraph(ParagraphBlock(id: BlockID("li"), style: .body,
                                                  list: ListMembership(marker: .ordered), runs: []))])
        XCTAssertEqual(v.placeholderDraws().first?.text, "Press return to end the list")
    }

    func test_placeholders_noneWhenNonEmpty() {
        let v = canvas([.paragraph(ParagraphBlock(id: BlockID("b"), style: .body, runs: [TextRun(text: "Hi")]))])
        XCTAssertTrue(v.placeholderDraws().isEmpty)
    }

    func test_placeholder_isDrawnByBox_onlyForTopLevelEmptyParagraph() {
        let v = DocumentCanvasView()
        v.setParagraphs([ParagraphBlock(id: BlockID("t"), style: .body, runs: [])], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 200); v.layoutIfNeeded()
        let box = v.boxes[0] as! BlockBox
        XCTAssertTrue(box.isTopLevelBlock, "top-level boxes are flagged during layout")
        let d = box.placeholderDraw()!
        let seam = v.placeholderDraws().first!
        XCTAssertEqual(d.text, "Type something…")
        XCTAssertEqual(d.origin.x, seam.origin.x, accuracy: 0.01)
        XCTAssertEqual(d.origin.y, seam.origin.y, accuracy: 0.01)
    }

    func test_blockquoteRun_rendersAsOnePooledImageView_behindParagraphs() {
        let v = DocumentCanvasView()
        v.setParagraphs([
            ParagraphBlock(id: BlockID("q1"), style: .quote, runs: [TextRun(text: "Line one")]),
            ParagraphBlock(id: BlockID("q2"), style: .quote, runs: [TextRun(text: "Line two")]),
            ParagraphBlock(id: BlockID("p"),  style: .body,  runs: [TextRun(text: "Body")]),
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300); v.layoutIfNeeded()
        let run = v.blockquoteDecorations().first!
        let imgViews = v.blockquoteUnderlay.subviews.compactMap { $0 as? UIImageView }
        XCTAssertEqual(imgViews.count, 1, "one stretched image view per quote run")
        XCTAssertEqual(imgViews[0].frame.minY, run.fill.minY, accuracy: 0.5)
        XCTAssertEqual(imgViews[0].frame.height, run.fill.height, accuracy: 0.5)
        XCTAssertNotNil(imgViews[0].image?.capInsets, "uses a resizable (cap-inset) image")
        XCTAssertLessThan(v.subviews.firstIndex(of: v.blockquoteUnderlay)!,
                          v.subviews.firstIndex(of: v.blockViews[BlockID("q1")]!)!)
    }

    func test_blockquoteFill_rebuildsOnAppearanceChange() {
        // BlockquoteUnderlay.fillImage() bakes the dynamic systemBlue into a cached bitmap against the current
        // traits, and the cache is only rebuilt from layoutSubviews (sync). A pure light↔dark appearance switch
        // fires trait callbacks but NOT layoutSubviews, so registerForTraitChanges must invalidate the cache and
        // re-apply the fresh image to the visible pooled views — otherwise the on-screen quote keeps stale colors.
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        window.overrideUserInterfaceStyle = .light
        let v = DocumentCanvasView()
        v.frame = window.bounds
        window.addSubview(v); window.makeKeyAndVisible()
        v.setParagraphs([ParagraphBlock(id: BlockID("q"), style: .quote, runs: [TextRun(text: "Quote")])], width: 300)
        v.layoutIfNeeded()
        let before = v.blockquoteUnderlay.subviews.compactMap { ($0 as? UIImageView)?.image }.first
        XCTAssertNotNil(before, "a visible quote produces a pooled fill image view")

        window.overrideUserInterfaceStyle = .dark
        v.layoutIfNeeded()
        let after = v.blockquoteUnderlay.subviews.compactMap { ($0 as? UIImageView)?.image }.first
        XCTAssertNotNil(after)
        XCTAssertFalse(before === after, "the blockquote fill image is rebuilt for the new appearance")
    }

    func test_emptyCellParagraph_drawsNoPlaceholder() {
        // An empty BODY paragraph inside a table cell would show "Type something…" if it were top-level;
        // the isTopLevelBlock gate must keep cells placeholder-free (parity with pre-refactor behavior).
        let v = DocumentCanvasView()
        let cellPara = ParagraphBlock(id: BlockID("cp"), style: .body, runs: [])
        v.setBlocks([.table(TableBlock(id: BlockID("t"),
            columns: [ColumnSpec(width: 120)],
            rows: [Row(id: BlockID("r0"), cells: [Cell(id: BlockID("c0"), blocks: [.paragraph(cellPara)])])]))],
            width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 200); v.layoutIfNeeded()
        // Find the cell's BlockBox via the table's leaf regions / cell stacks.
        let table = v.boxes[0] as! TableBlockBox
        let cellBox = table.cellStack(containing: table.cellTextStart(row: 0, column: 0)!)!.box as! BlockBox
        XCTAssertFalse(cellBox.isTopLevelBlock, "cell paragraphs are never flagged top-level")
        XCTAssertNil(cellBox.placeholderDraw(), "cell empty paragraph draws no placeholder")
        XCTAssertTrue(v.placeholderDraws().isEmpty, "the canvas placeholder seam excludes cell paragraphs")
    }
}
#endif
