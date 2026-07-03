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

    func test_toggleCollapsed_collapsingWithFollowingParagraph_caretFocusesQuoteGap() {
        // A quote followed by a body paragraph; caret inside the quote. After collapsing, the caret FOCUSES
        // the collapsed quote's own leading gap (its cursor slot) — it does NOT jump into the following
        // paragraph, and no block is added or removed.
        let bq = BlockQuote(id: BlockID("q"), children: [
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "inside text")]))
        ], collapsed: false)
        let after = ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "after")])
        let c = canvas([.blockQuote(bq), .paragraph(after)])
        let box = c.boxes[0] as! BlockQuoteBox
        let insidePos = box.children.boxes.first?.leafRegions().first?.globalStart ?? 0
        c.anchor = insidePos; c.head = insidePos
        c.toggleCollapsed(box: box)
        XCTAssertEqual(c.boxes.count, 2, "no block added/removed (quote + the existing following paragraph)")
        guard let collapsedBox = c.boxes.first as? BlockQuoteBox else { return XCTFail("box should remain a BlockQuoteBox") }
        XCTAssertEqual(collapsedBox.nodeSize, 3, "quote should now be a collapsed atom")
        XCTAssertEqual(c.head, collapsedBox.nodeStart, "caret focuses the collapsed quote's leading gap")
        XCTAssertEqual(c.anchor, c.head, "selection collapsed")
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

    func test_emptyBlockQuote_showsPlaceholder() {
        let bq = BlockQuote(id: BlockID("q"), children: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: []))], collapsed: false)
        let box = canvas([.blockQuote(bq)]).boxes.first as! BlockQuoteBox
        XCTAssertEqual(box.placeholderText, "Type a quote here")
    }
    func test_nonEmptyBlockQuote_noPlaceholder() {
        let bq = BlockQuote(id: BlockID("q"), children: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hi")]))], collapsed: false)
        let box = canvas([.blockQuote(bq)]).boxes.first as! BlockQuoteBox
        XCTAssertNil(box.placeholderText)
    }
    func test_blockQuote_placeholdersStampedFromCanvas_suppressed() {
        let c = DocumentCanvasView()
        c.placeholders = RichTextEditorPlaceholders(body: "", listEnd: "", listOutdent: "", pullQuote: "", blockQuote: "", codeBlock: "")
        c.setBlocks([.blockQuote(BlockQuote(id: BlockID("q"), children: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: []))]))], width: 320)
        c.frame = CGRect(x: 0, y: 0, width: 320, height: 600); c.layoutIfNeeded(); c.simulateParentLayout()
        let box = c.boxes.first as! BlockQuoteBox
        XCTAssertNil(box.placeholderText)   // canvas placeholders (empty blockQuote) stamped onto the box
    }

    func test_collapse_focusesQuoteGap_noTrailingParagraph() {
        let bq = BlockQuote(id: BlockID("q"), children: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hi there long enough")]))], collapsed: false)
        let c = canvas([.blockQuote(bq)])
        let box = c.boxes.first as! BlockQuoteBox
        c.setCaret(global: box.nodeStart + 1)          // caret inside the (expanded) quote
        c.toggleCollapsed(box: box)
        XCTAssertEqual(c.boxes.count, 1, "collapse adds no trailing body paragraph")
        let newBox = c.boxes.first as! BlockQuoteBox
        XCTAssertTrue(newBox.collapsed)
        XCTAssertEqual(c.head, newBox.nodeStart, "caret focuses the collapsed quote's leading gap")
        let caret = c.caretRect(for: DocumentTextPosition(c.head))
        XCTAssertGreaterThan(caret.height, 0, "a visible caret renders on the collapsed quote (not .zero)")
        XCTAssertGreaterThanOrEqual(caret.minX, newBox.frame.minX, "caret is within the folded quote")
        XCTAssertLessThan(caret.minX, newBox.frame.maxX, "caret sits near the quote's leading edge")
    }

    // REPRO of the REAL app bug: iOS delivers backspace at an empty quote's start as an object-replacement
    // RANGE anchored in the previous block (the atom pattern), NOT a collapsed caret. A direct-caret test
    // misses it. Desired: delete the quote → empty body paragraph in place (NOT merge into the previous block).
    func test_backspace_emptyBlockQuote_deliveredAsOSRange_replacesWithBodyParagraph() {
        let prev = ParagraphBlock(id: BlockID("prev"), runs: [TextRun(text: "hello")])
        let bq = BlockQuote(id: BlockID("q"), children: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: []))], collapsed: false)
        let c = canvas([.paragraph(prev), .blockQuote(bq)])
        let box = c.boxes[1] as! BlockQuoteBox
        let childStart = box.children.boxes.first?.leafRegions().first?.globalStart ?? 0
        let prevEnd = c.prevTextPosition(before: childStart)
        c.anchor = prevEnd; c.head = childStart          // the OS-delivered object-replacement range
        c.deleteBackward()
        XCTAssertFalse(c.boxes.contains { $0 is BlockQuoteBox }, "quote deleted, not merged into the previous block")
        XCTAssertEqual(c.boxes.count, 2, "hello paragraph + empty body paragraph in the quote's place")
        guard case let .paragraph(h) = c.boxes[0].currentBlock() else { return XCTFail("1st block paragraph") }
        XCTAssertEqual(h.runs.map(\.text).joined(), "hello", "previous block preserved")
        guard case let .paragraph(e) = c.boxes[1].currentBlock() else { return XCTFail("2nd block paragraph") }
        XCTAssertEqual(e.style, .body); XCTAssertTrue(e.runs.isEmpty, "quote replaced by an empty body paragraph")
    }

    func test_backspace_emptyCodeBlock_deliveredAsOSRange_replacesWithBodyParagraph() {
        let prev = ParagraphBlock(id: BlockID("prev"), runs: [TextRun(text: "hello")])
        let c = canvas([.paragraph(prev), .code(CodeBlock(id: BlockID("c"), runs: []))])
        let codeStart = c.boxes[1].textStart
        c.anchor = c.prevTextPosition(before: codeStart); c.head = codeStart   // OS object-replacement range
        c.deleteBackward()
        XCTAssertFalse(c.boxes.contains { $0 is CodeBlockBox }, "code block deleted, not merged into the previous block")
        guard case let .paragraph(e) = c.boxes[1].currentBlock() else { return XCTFail("2nd block paragraph") }
        XCTAssertEqual(e.style, .body); XCTAssertTrue(e.runs.isEmpty)
    }
    func test_backspace_emptyPullQuote_deliveredAsOSRange_replacesWithBodyParagraph() {
        let prev = ParagraphBlock(id: BlockID("prev"), runs: [TextRun(text: "hello")])
        let c = canvas([.paragraph(prev), .pullQuote(PullQuote(id: BlockID("pq"), runs: []))])
        let pqStart = c.boxes[1].textStart
        c.anchor = c.prevTextPosition(before: pqStart); c.head = pqStart       // OS object-replacement range
        c.deleteBackward()
        XCTAssertFalse(c.boxes.contains { $0 is PullQuoteBox }, "pull quote deleted, not merged into the previous block")
        guard case let .paragraph(e) = c.boxes[1].currentBlock() else { return XCTFail("2nd block paragraph") }
        XCTAssertEqual(e.style, .body); XCTAssertTrue(e.runs.isEmpty)
    }

    // REPRO of the app bug: an empty quote with a PREVIOUS block. Backspace at its start should still delete
    // the quote → empty body paragraph in place (NOT move the caret into the previous block leaving the quote).
    func test_backspace_emptyBlockQuote_withPreviousBlock_replacesWithBodyParagraph() {
        let prev = ParagraphBlock(id: BlockID("prev"), runs: [TextRun(text: "hello")])
        let bq = BlockQuote(id: BlockID("q"), children: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: []))], collapsed: false)
        let c = canvas([.paragraph(prev), .blockQuote(bq)])
        let box = c.boxes[1] as! BlockQuoteBox
        let childStart = box.children.boxes.first?.leafRegions().first?.globalStart ?? 0
        c.setCaret(global: childStart)
        c.deleteBackward()
        XCTAssertFalse(c.boxes.contains { $0 is BlockQuoteBox }, "quote deleted even with a previous block")
        XCTAssertEqual(c.boxes.count, 2, "prev paragraph + a new empty body paragraph in the quote's place")
        guard case let .paragraph(p) = c.boxes[1].currentBlock() else { return XCTFail("2nd block is a paragraph") }
        XCTAssertEqual(p.style, .body); XCTAssertTrue(p.runs.isEmpty)
    }

    // REPRO: backspace at the start of an EMPTY container should delete it and leave a single empty BODY paragraph.
    func test_backspace_emptyBlockQuote_replacesWithBodyParagraph() {
        let bq = BlockQuote(id: BlockID("q"), children: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: []))], collapsed: false)
        let c = canvas([.blockQuote(bq)])
        let box = c.boxes.first as! BlockQuoteBox
        let childStart = box.children.boxes.first?.leafRegions().first?.globalStart ?? 0
        c.setCaret(global: childStart)
        c.deleteBackward()
        XCTAssertFalse(c.boxes.contains { $0 is BlockQuoteBox }, "the quote is deleted")
        XCTAssertEqual(c.boxes.count, 1, "single block remains")
        guard case let .paragraph(p) = c.boxes[0].currentBlock() else { return XCTFail("should be a paragraph") }
        XCTAssertEqual(p.style, .body, "empty BODY paragraph"); XCTAssertTrue(p.runs.isEmpty)
    }
    func test_backspace_emptyCodeBlock_replacesWithBodyParagraph() {
        let c = canvas([.code(CodeBlock(id: BlockID("c"), runs: []))])
        c.setCaret(global: c.boxes[0].textStart)
        c.deleteBackward()
        XCTAssertFalse(c.boxes.contains { $0 is CodeBlockBox }, "the code block is deleted")
        guard case let .paragraph(p) = c.boxes[0].currentBlock() else { return XCTFail("should be a paragraph") }
        XCTAssertEqual(p.style, .body)
    }
    func test_backspace_emptyPullQuote_replacesWithBodyParagraph() {
        let c = canvas([.pullQuote(PullQuote(id: BlockID("pq"), runs: []))])
        c.setCaret(global: c.boxes[0].textStart)
        c.deleteBackward()
        XCTAssertFalse(c.boxes.contains { $0 is PullQuoteBox }, "the pull quote is deleted")
        guard case let .paragraph(p) = c.boxes[0].currentBlock() else { return XCTFail("should be a paragraph") }
        XCTAssertEqual(p.style, .body)
    }

    func test_collapse_thenTypeChar_opensBodyParagraphBeforeQuote() {
        // Focused on a collapsed quote, typing lazily opens a body paragraph BEFORE it carrying the character
        // (the folded atom holds no text) — mirroring typing on a media atom's gap. No paragraph on collapse.
        let bq = BlockQuote(id: BlockID("q"), children: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hi there long enough")]))], collapsed: false)
        let c = canvas([.blockQuote(bq)])
        let box = c.boxes.first as! BlockQuoteBox
        c.setCaret(global: box.nodeStart + 1)
        c.toggleCollapsed(box: box)                       // caret focuses the collapsed quote's gap
        c.insertText("x")
        XCTAssertEqual(c.boxes.count, 2, "typing opens a body paragraph before the folded quote")
        guard case let .paragraph(p) = c.boxes[0].currentBlock() else { return XCTFail("first block is a paragraph") }
        XCTAssertEqual(p.runs.map(\.text).joined(), "x", "the character lands in the new paragraph")
        XCTAssertTrue(c.boxes[1] is BlockQuoteBox, "the collapsed quote follows it")
        XCTAssertEqual(c.head, c.boxes[0].textStart + 1, "caret sits after the typed character")
    }

}
#endif
