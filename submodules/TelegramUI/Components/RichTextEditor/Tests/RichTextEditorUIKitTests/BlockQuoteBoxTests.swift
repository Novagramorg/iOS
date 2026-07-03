#if canImport(UIKit)
import XCTest
import RichTextEditorCore
@testable import RichTextEditorUIKit

final class BlockQuoteBoxTests: XCTestCase {
    private func canvas(_ blocks: [Block], width: CGFloat = 320) -> DocumentCanvasView {
        let c = DocumentCanvasView()
        c.setBlocks(blocks, width: width)
        c.frame = CGRect(x: 0, y: 0, width: width, height: 600)
        c.layoutIfNeeded()
        c.simulateParentLayout()
        return c
    }

    func test_toggleCollapsed_collapsesExpandedBox() {
        let bq = BlockQuote(id: BlockID("q"), children: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hi there long enough")]))], collapsed: false)
        let c = canvas([.blockQuote(bq)])
        let box = c.boxes.first as! BlockQuoteBox
        c.toggleCollapsed(box: box)
        guard let newBox = c.boxes.first as? BlockQuoteBox else { return XCTFail() }
        XCTAssertEqual(newBox.nodeSize, 3)                       // now folded
        guard case .blockQuote(let m) = newBox.currentBlock() else { return XCTFail() }
        XCTAssertTrue(m.collapsed)
    }

    func test_toggleCollapsed_expandsCollapsedBox_caretIntoFirstChild() {
        let bq = BlockQuote(id: BlockID("q"), children: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hi")]))], collapsed: true)
        let c = canvas([.blockQuote(bq)])
        let box = c.boxes.first as! BlockQuoteBox
        c.anchor = box.nodeStart; c.head = box.nodeStart          // caret on the collapsed atom
        c.toggleCollapsed(box: box)
        guard let newBox = c.boxes.first as? BlockQuoteBox else { return XCTFail() }
        XCTAssertGreaterThan(newBox.nodeSize, 3)                 // expanded
        guard case .blockQuote(let m) = newBox.currentBlock() else { return XCTFail() }
        XCTAssertFalse(m.collapsed)
        // caret landed inside the first child
        XCTAssertEqual(c.head, newBox.children.boxes.first?.leafRegions().first?.globalStart)
    }

    func test_blockQuoteBox_hostsChildren_readback() {
        let bq = BlockQuote(id: BlockID("q"), children: [
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hi")]))], collapsed: false)
        let box = BlockQuoteBox(blockQuote: bq, mapper: AttributedStringMapper(), quoteStyle: .default,
                                pullQuoteStyle: .default, expandImage: nil, width: 320)
        guard case .blockQuote(let out) = box.currentBlock() else { return XCTFail() }
        XCTAssertEqual(out.children.count, 1)
        XCTAssertFalse(out.collapsed)
        // one leaf region (the child paragraph)
        XCTAssertEqual(box.leafRegions().count, 1)
    }
    func test_blockQuoteBox_collapsed_isAtom() {
        let bq = BlockQuote(id: BlockID("q"), children: [
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hi there")]))], collapsed: true)
        let box = BlockQuoteBox(blockQuote: bq, mapper: AttributedStringMapper(), quoteStyle: .default,
                                pullQuoteStyle: .default, expandImage: nil, width: 320)
        XCTAssertEqual(box.nodeSize, 3)                      // folded atom (not Σ+2)
        XCTAssertTrue(box.leafRegions().isEmpty)             // off the editable axis
        guard case .blockQuote(let out) = box.currentBlock() else { return XCTFail() }
        XCTAssertTrue(out.collapsed)                         // collapse flag round-trips
        XCTAssertEqual(out.children.count, 1)                // children preserved (for expand + send)
    }
    func test_blockQuoteBox_expanded_isContainer() {
        let bq = BlockQuote(id: BlockID("q"), children: [
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hi")]))], collapsed: false)
        let box = BlockQuoteBox(blockQuote: bq, mapper: AttributedStringMapper(), quoteStyle: .default,
                                pullQuoteStyle: .default, expandImage: nil, width: 320)
        XCTAssertGreaterThan(box.nodeSize, 3)               // container (Σ+2)
        XCTAssertEqual(box.leafRegions().count, 1)          // child on the axis
    }
    // MARK: - Caret relocation on collapse (Finding 2)

    func test_toggleCollapsed_collapsingWithCaretInside_caretLandsInFollowingParagraph() {
        // A quote followed by a body paragraph; caret is inside the quote.
        // After collapsing, the caret must land in the following paragraph — NOT on the
        // collapsed atom's gap (which would park it on a display-only slot and freeze typing).
        let bq = BlockQuote(id: BlockID("q"), children: [
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "inside text")]))
        ], collapsed: false)
        let after = ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "after")])
        let c = canvas([.blockQuote(bq), .paragraph(after)])
        let box = c.boxes[0] as! BlockQuoteBox
        // Place caret inside the quote's first leaf
        let insidePos = box.children.boxes.first?.leafRegions().first?.globalStart ?? 0
        c.anchor = insidePos; c.head = insidePos
        c.toggleCollapsed(box: box)
        guard let collapsedBox = c.boxes.first as? BlockQuoteBox else { return XCTFail("box should remain a BlockQuoteBox") }
        XCTAssertEqual(collapsedBox.nodeSize, 3, "quote should now be a collapsed atom")
        guard let followBox = (c.boxes.count > 1 ? c.boxes[1] : nil) as? BlockBox else {
            return XCTFail("following body paragraph should still exist")
        }
        // Caret should not be on the atom's gap
        XCTAssertNotEqual(c.head, collapsedBox.nodeStart, "caret must NOT park on the collapsed atom gap")
        XCTAssertEqual(c.head, followBox.textStart, "caret should land at the following paragraph's textStart")
        XCTAssertEqual(c.anchor, c.head, "selection should be collapsed")
    }

    func test_toggleCollapsed_collapsingLastBlock_appendsEmptyBodyParagraphForCaret() {
        // A quote is the LAST block. Collapsing with the caret inside must append an empty body
        // paragraph (so the user has somewhere to type) and land the caret there.
        let bq = BlockQuote(id: BlockID("q"), children: [
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "inside text")]))
        ], collapsed: false)
        let c = canvas([.blockQuote(bq)])      // quote is the ONLY block
        let box = c.boxes[0] as! BlockQuoteBox
        let insidePos = box.children.boxes.first?.leafRegions().first?.globalStart ?? 0
        c.anchor = insidePos; c.head = insidePos
        c.toggleCollapsed(box: box)
        // Must now have 2 blocks: collapsed quote + appended empty body paragraph
        XCTAssertEqual(c.boxes.count, 2, "an empty body paragraph should have been appended")
        guard let collapsedBox = c.boxes.first as? BlockQuoteBox else { return XCTFail("first box should be collapsed BlockQuoteBox") }
        guard let appendedBox = c.boxes[1] as? BlockBox else { return XCTFail("second box should be a BlockBox paragraph") }
        XCTAssertEqual(collapsedBox.nodeSize, 3, "first box should be a collapsed atom")
        XCTAssertNotEqual(c.head, collapsedBox.nodeStart, "caret must NOT park on the collapsed atom gap")
        XCTAssertEqual(c.head, appendedBox.textStart, "caret should land at the appended paragraph's textStart")
        XCTAssertEqual(c.anchor, c.head, "selection should be collapsed")
    }

    // MARK: - Glyph hit walks table cells (Finding 1)

    func test_firstBlockQuoteGlyphHit_findsCollapsedBoxInTableCell() {
        // A collapsed BlockQuoteBox injected into a table cell must be found by firstBlockQuoteGlyphHit.
        // Before the fix the walk only iterated root boxes + BlockQuoteBox.children, silently missing any
        // BlockQuoteBox that lived inside a TableBlockBox cell.
        //
        // NOTE: The v1 TableBlockBox.init only builds paragraph/media boxes for cells (not blockQuote — that
        // is a v1 limitation, not a bug in the walk). We therefore inject the box directly into the cell
        // stack and give it an explicit frame so expandGlyphRect() produces a real canvas-coordinate rect.
        let tbl = TableBlock(id: BlockID("t"),
            columns: [ColumnSpec(width: 280)],
            rows: [Row(id: BlockID("r0"), cells: [
                Cell(id: BlockID("c00"), blocks: [.paragraph(ParagraphBlock(id: BlockID("cp"), runs: [TextRun(text: "cell")]))])
            ])])
        let c = canvas([.table(tbl)])
        guard let tableBox = c.boxes.first as? TableBlockBox else { return XCTFail("need a table box") }
        // Inject a collapsed BlockQuoteBox directly into the cell's stack (bypassing v1 restriction).
        let bq = BlockQuote(id: BlockID("q"), children: [
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "cell quote")]))
        ], collapsed: true)
        let cellQuoteBox = BlockQuoteBox(blockQuote: bq, mapper: AttributedStringMapper(),
                                         quoteStyle: .default, pullQuoteStyle: .default,
                                         expandImage: nil, collapseImage: nil, width: 200)
        // Give it a frame so expandGlyphRect() yields a real canvas-coordinate rect.
        cellQuoteBox.frame = CGRect(x: 10, y: 50, width: 200, height: 40)
        tableBox.cells[0][0].boxes.append(cellQuoteBox)
        // The glyph rect center must fall within the ±12pt inset hit area.
        let glyphRect = cellQuoteBox.expandGlyphRect()
        XCTAssertFalse(glyphRect.isEmpty, "expand glyph rect should be non-empty")
        let hitPoint = CGPoint(x: glyphRect.midX, y: glyphRect.midY)
        let found = c.firstBlockQuoteGlyphHit(at: hitPoint)
        XCTAssertTrue(found === cellQuoteBox,
            "firstBlockQuoteGlyphHit must walk table cells and find the injected BlockQuoteBox")
    }

    /// Bug 3 (refined): the collapse control shows only when the quote's content exceeds the
    /// ≤maxPreviewLines-line preview ("more than 3 body lines"). A SHORT quote is NOT collapsible;
    /// a TALL nested quote (any level) IS — and children-first DFS returns the inner box on its tap.
    func test_collapseGlyph_gatedOnMoreThanThreeLines_anyLevel() {
        // SHORT (one-line) nested quote → not collapsible → no collapse-control hit.
        let shortInner = BlockQuote(id: BlockID("si"), children: [
            .paragraph(ParagraphBlock(id: BlockID("sp"), runs: [TextRun(text: "x")]))
        ], collapsed: false)
        let shortOuter = BlockQuote(id: BlockID("so"), children: [.blockQuote(shortInner)], collapsed: false)
        let cs = canvas([.blockQuote(shortOuter)])
        let soBox = cs.boxes.first as! BlockQuoteBox
        let siBox = soBox.children.boxes.first as! BlockQuoteBox
        XCTAssertFalse(siBox.isCollapsible, "a one-line quote is not collapsible")
        let siRect = siBox.collapseGlyphRect()
        XCTAssertNil(cs.firstBlockQuoteGlyphHit(at: CGPoint(x: siRect.midX, y: siRect.midY)),
                     "a short quote shows no collapse control")

        // TALL (5-line) NESTED quote → collapsible → its glyph tap returns the INNER box (DFS).
        let tallInner = BlockQuote(id: BlockID("ti"), children: (0..<5).map {
            .paragraph(ParagraphBlock(id: BlockID("tp\($0)"), runs: [TextRun(text: "line \($0)")]))
        }, collapsed: false)
        let tallOuter = BlockQuote(id: BlockID("to"), children: [.blockQuote(tallInner)], collapsed: false)
        let ct = canvas([.blockQuote(tallOuter)])
        let toBox = ct.boxes.first as! BlockQuoteBox
        let tiBox = toBox.children.boxes.first as! BlockQuoteBox
        XCTAssertTrue(tiBox.isCollapsible, "a 5-line quote is collapsible")
        let tiRect = tiBox.collapseGlyphRect()
        XCTAssertTrue(ct.firstBlockQuoteGlyphHit(at: CGPoint(x: tiRect.midX, y: tiRect.midY)) === tiBox,
                      "a tall nested quote is collapsible; its glyph tap returns the inner box")
    }

    // MARK: - 15pt body font (render-only)

    /// Block-quote children render at 15pt (bodyBaseSize = 15 via withBodyBaseSize), matching the
    /// old flat `.quote` fixed size. The mapper stored on the child BlockBox carries the 15pt base
    /// so every downstream render path (collapsed preview, child boxes, headings — which are
    /// independent of bodyBaseSize — all stay correct). Headings keep their fixed size.
    func test_blockQuoteBox_childBodyFontIs15pt() {
        let bq = BlockQuote(id: BlockID("q"), children: [
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hello")]))
        ], collapsed: false)
        let box = BlockQuoteBox(blockQuote: bq, mapper: AttributedStringMapper(), quoteStyle: .default,
                                pullQuoteStyle: .default, expandImage: nil, width: 320)
        // The child BlockBox must carry a 15pt-body mapper.
        guard let childBox = box.children.boxes.first as? BlockBox else { return XCTFail("child should be a BlockBox") }
        XCTAssertEqual(childBox.mapper.styleSheet.font(for: .body, attributes: .plain).pointSize, 15,
                       accuracy: 0.5, "block-quote body content renders at 15pt, not the document's 17pt")
        // Headings inside a quote keep their fixed size (they don't use bodyBaseSize).
        XCTAssertGreaterThan(childBox.mapper.styleSheet.font(for: .heading1, attributes: .plain).pointSize, 20,
                             "heading1 inside a quote keeps its fixed large size")
        // currentBlock() round-trips the children's text content (structural integrity).
        guard case .blockQuote(let round) = box.currentBlock() else { return XCTFail("should be blockQuote") }
        XCTAssertEqual(round.children.count, 1, "child count is preserved")
        guard case .paragraph(let p) = round.children.first else { return XCTFail("child should be a paragraph") }
        XCTAssertEqual(p.runs.map(\.text).joined(), "hello", "text content is unchanged by the 15pt mapping")
    }

    /// Nested quotes and quotes-in-cells stay 15pt — withBodyBaseSize(15) on an already-15pt mapper
    /// is idempotent; there is no per-level shrink.
    func test_blockQuoteBox_nestedQuote_staysAt15pt() {
        let inner = BlockQuote(id: BlockID("i"), children: [
            .paragraph(ParagraphBlock(id: BlockID("ip"), runs: [TextRun(text: "inner")]))
        ], collapsed: false)
        let outer = BlockQuote(id: BlockID("o"), children: [.blockQuote(inner)], collapsed: false)
        let box = BlockQuoteBox(blockQuote: outer, mapper: AttributedStringMapper(), quoteStyle: .default,
                                pullQuoteStyle: .default, expandImage: nil, width: 320)
        // The outer box stores a 15pt mapper.
        XCTAssertEqual(box.mapper.styleSheet.font(for: .body, attributes: .plain).pointSize, 15,
                       accuracy: 0.5, "outer quote is 15pt")
        // The inner (nested) BlockQuoteBox also stores a 15pt mapper — no further shrink.
        guard let innerBox = box.children.boxes.first as? BlockQuoteBox else { return XCTFail("inner should be BlockQuoteBox") }
        XCTAssertEqual(innerBox.mapper.styleSheet.font(for: .body, attributes: .plain).pointSize, 15,
                       accuracy: 0.5, "nested quote stays at 15pt (withBodyBaseSize is idempotent)")
    }

    func test_canvasBuildsBlockQuoteBox_recursively() {
        let inner = BlockQuote(id: BlockID("in"), children: [.paragraph(ParagraphBlock(id: BlockID("ip"), runs: [TextRun(text:"x")]))], collapsed: false)
        let outer = BlockQuote(id: BlockID("out"), children: [.blockQuote(inner)], collapsed: false)
        let canvas = DocumentCanvasView(); canvas.frame = CGRect(x:0,y:0,width:320,height:400)
        canvas.setBlocks([.blockQuote(outer)], width: 320)
        canvas.simulateParentLayout()
        guard let outerBox = canvas.boxes.first as? BlockQuoteBox else { return XCTFail("no outer box") }
        // outerBox.nodeStart == 1; inner paragraph's nodeStart == 3 == outerBox.nodeStart + 2
        XCTAssertTrue(outerBox.childStack(containing: outerBox.nodeStart + 2) != nil)   // a position inside the nested quote resolves
        guard case .blockQuote(let round) = outerBox.currentBlock() else { return XCTFail() }
        guard case .blockQuote = round.children.first else { return XCTFail("nested quote lost") }
    }
}
#endif
