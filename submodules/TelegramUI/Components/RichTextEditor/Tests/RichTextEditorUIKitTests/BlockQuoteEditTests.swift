#if canImport(UIKit)
import XCTest
import RichTextEditorCore
@testable import RichTextEditorUIKit
final class BlockQuoteEditTests: XCTestCase {
    private func canvas(_ blocks: [Block]) -> DocumentCanvasView {
        let c = DocumentCanvasView(); c.frame = CGRect(x:0,y:0,width:320,height:400)
        c.setBlocks(blocks, width: 320); c.simulateParentLayout(); return c
    }

    func test_wrapInBlockQuote_wrapsTwoParagraphs() {
        let c = canvas([
            .paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "aa")])),
            .paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "bb")]))])
        // Select across both paragraphs using anchor/head seam (same idiom as other UIKit tests)
        c.anchor = 0; c.head = c.documentSizeValue
        c.wrapInBlockQuote()
        let blocks = c.currentBlocks()
        XCTAssertEqual(blocks.count, 1, "both paragraphs should be wrapped into one block quote")
        guard case .blockQuote(let q) = blocks[0] else { return XCTFail("not wrapped in a block quote") }
        XCTAssertEqual(q.children.count, 2, "both paragraphs preserved as children")
        XCTAssertFalse(q.collapsed, "new block quote is expanded")
    }

    func test_wrapInBlockQuote_nestsWhenAlreadyInsideQuote() {
        let inner = BlockQuote(id: BlockID("q"), children: [
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hi")]))], collapsed: false)
        let c = canvas([.blockQuote(inner)])
        // Place caret inside the quote's child paragraph using the anchor/head seam
        let box = c.boxes.first as! BlockQuoteBox
        let pos = box.children.boxes[0].leafRegions().first!.globalStart + 1
        c.anchor = pos; c.head = pos
        c.wrapInBlockQuote()
        let blocks = c.currentBlocks()
        guard case .blockQuote(let outer) = blocks[0] else { return XCTFail("outer block quote missing") }
        guard case .blockQuote = outer.children.first else {
            return XCTFail("did not nest — expected a block quote inside the block quote")
        }
    }

    func test_unwrapBlockQuoteLevel_level1_childrenBecomeTopLevel() {
        let bq = BlockQuote(id: BlockID("q"), children: [
            .paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "aa")])),
            .paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "bb")]))], collapsed: false)
        let c = canvas([.blockQuote(bq)])
        let box = c.boxes.first as! BlockQuoteBox
        let pos = box.children.boxes[0].leafRegions().first!.globalStart + 1
        c.anchor = pos; c.head = pos
        c.unwrapBlockQuoteLevel()
        let blocks = c.currentBlocks()
        XCTAssertEqual(blocks.count, 2)                                  // children spliced to top level
        for b in blocks { if case .blockQuote = b { XCTFail("still wrapped") } }
    }

    func test_unwrapBlockQuoteLevel_nested_removesOneLevel() {
        let inner = BlockQuote(id: BlockID("in"), children: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hi")]))], collapsed: false)
        let outer = BlockQuote(id: BlockID("out"), children: [.blockQuote(inner)], collapsed: false)
        let c = canvas([.blockQuote(outer)])
        let outerBox = c.boxes.first as! BlockQuoteBox
        let innerBox = outerBox.children.boxes.compactMap { $0 as? BlockQuoteBox }.first!
        let pos = innerBox.children.boxes[0].leafRegions().first!.globalStart + 1
        c.anchor = pos; c.head = pos
        c.unwrapBlockQuoteLevel()                                           // removes the INNER level only
        let blocks = c.currentBlocks()
        guard case .blockQuote(let stillOuter) = blocks[0] else { return XCTFail("outer quote gone") }
        // inner removed → outer now directly holds the paragraph
        guard case .paragraph = stillOuter.children.first else { return XCTFail("inner level not removed") }
    }

    func test_enter_insideQuote_addsChildParagraph() {
        let bq = BlockQuote(id: BlockID("q"), children: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hi")]))], collapsed: false)
        let c = canvas([.blockQuote(bq)])
        let box = c.boxes.first as! BlockQuoteBox
        let endOfChild = box.children.boxes[0].leafRegions().first!.globalStart + 2   // after "hi"
        c.anchor = endOfChild; c.head = endOfChild
        c.insertText("\n")                                   // Enter (use the same seam the other Enter tests use)
        guard case .blockQuote(let q) = c.currentBlocks()[0] else { return XCTFail() }
        XCTAssertEqual(q.children.count, 2)                         // Enter added a child paragraph (still inside the quote)
    }

    func test_doubleReturn_emptyTrailingChild_exitsAfterQuote() {
        let bq = BlockQuote(id: BlockID("q"), children: [
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hi")])),
            .paragraph(ParagraphBlock(id: BlockID("e"), runs: []))], collapsed: false)   // empty trailing child
        let c = canvas([.blockQuote(bq)])
        let box = c.boxes.first as! BlockQuoteBox
        let pos = box.children.boxes[1].leafRegions().first!.globalStart      // caret on the empty trailing child
        c.anchor = pos; c.head = pos
        c.insertText("\n")
        let doc = c.currentBlocks()
        XCTAssertEqual(doc.count, 2)                        // quote + a body paragraph after it
        guard case .blockQuote(let q) = doc[0] else { return XCTFail() }
        XCTAssertEqual(q.children.count, 1)                        // empty trailing child consumed
        guard case .paragraph(let after) = doc[1], after.style == .body else { return XCTFail("no body after") }
    }

    func test_backspace_emptyLoneChild_unquotes() {
        let bq = BlockQuote(id: BlockID("q"), children: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: []))], collapsed: false)
        let c = canvas([.blockQuote(bq)])
        let box = c.boxes.first as! BlockQuoteBox
        let pos = box.children.boxes[0].leafRegions().first!.globalStart
        c.anchor = pos; c.head = pos
        c.deleteBackward()                                  // Backspace (same seam as other backspace tests)
        let doc = c.currentBlocks()
        for b in doc { if case .blockQuote = b { return XCTFail("still quoted") } }   // un-quoted to a plain paragraph
    }

    /// Bug 1 regression: a LONE child with CONTENT at local 0 must also un-quote on Backspace.
    /// Before the fix the branch required `child.textLength == 0`, so a lone child with content
    /// would fall through and do a normal character delete instead of removing the quote wrapper.
    func test_backspace_nonEmptyLoneChild_atStart_unquotes_preservingContent() {
        let bq = BlockQuote(id: BlockID("q"), children: [
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hello")]))], collapsed: false)
        let c = canvas([.blockQuote(bq)])
        let box = c.boxes.first as! BlockQuoteBox
        // Caret at local 0 (the very start of the child, before the "h")
        let pos = box.children.boxes[0].leafRegions().first!.globalStart
        c.anchor = pos; c.head = pos
        c.deleteBackward()
        let doc = c.currentBlocks()
        // The quote wrapper is gone — children are spliced to the parent
        for b in doc { if case .blockQuote = b { return XCTFail("quote wrapper should have been removed") } }
        // Content is preserved (the text "hello" was NOT deleted)
        guard case .paragraph(let p) = doc.first else { return XCTFail("expected a body paragraph") }
        XCTAssertEqual(p.text, "hello", "content must be preserved after un-quoting the lone child")
    }

    func test_wrapInBlockQuote_insideTableCell_isNoOp() {
        // A table with one cell containing "Hello". Position the caret inside the cell and attempt to
        // wrap in a block quote — this should be a no-op (a table cellStack can't host a BlockQuoteBox).
        let cell = Cell(id: BlockID("c"), blocks: [
            .paragraph(ParagraphBlock(id: BlockID("cp"), runs: [TextRun(text: "Hello")]))])
        let table = TableBlock(id: BlockID("t"),
                               columns: [ColumnSpec(width: 300)],
                               rows: [Row(id: BlockID("r"), cells: [cell])])
        let c = canvas([.table(table)])
        // Find the cell paragraph's leaf region and place the caret inside it.
        guard let cellRegion = c.allLeafRegions().first(where: { $0.ref == .paragraph(BlockID("cp")) }) else {
            return XCTFail("cell region not found")
        }
        let pos = cellRegion.globalStart + 2
        c.anchor = pos; c.head = pos
        let blocksBefore = c.currentBlocks()
        c.wrapInBlockQuote()
        // The document must be byte-identical to before — no block quote was created.
        XCTAssertEqual(c.currentBlocks().count, blocksBefore.count, "no new top-level block should appear")
        guard case .table(let outTable) = c.currentBlocks()[0] else { return XCTFail("table disappeared") }
        guard case .paragraph(let cellPara) = outTable.rows[0].cells[0].blocks[0] else {
            return XCTFail("cell content changed")
        }
        XCTAssertEqual(cellPara.text, "Hello", "cell content must be unchanged")
        for b in c.currentBlocks() { if case .blockQuote = b { XCTFail("block quote was created inside a table") } }
    }

    func test_editorState_blockQuoteDepth() {
        let inner = BlockQuote(id: BlockID("in"), children: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hi")]))], collapsed: false)
        let outer = BlockQuote(id: BlockID("out"), children: [.blockQuote(inner)], collapsed: false)
        let c = canvas([.paragraph(ParagraphBlock(id: BlockID("top"), runs: [TextRun(text: "x")])), .blockQuote(outer)])
        // caret in the top-level paragraph → depth 0
        let topPos = c.boxes[0].leafRegions().first!.globalStart
        c.anchor = topPos; c.head = topPos
        XCTAssertEqual(c.blockQuoteDepth(at: c.head), 0)
        // caret inside the doubly-nested paragraph → depth 2
        let outerBox = c.boxes[1] as! BlockQuoteBox
        let innerBox = outerBox.children.boxes.compactMap { $0 as? BlockQuoteBox }.first!
        let deep = innerBox.children.boxes[0].leafRegions().first!.globalStart + 1
        c.anchor = deep; c.head = deep
        XCTAssertEqual(c.blockQuoteDepth(at: c.head), 2)
    }
}
#endif
