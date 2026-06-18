#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class TableBlockBoxTests: XCTestCase {
    private func cell(_ id: String, _ text: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: text)]))])
    }
    private func table2x2() -> TableBlock {
        TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
                   rows: [Row(id: BlockID("r0"), cells: [cell("a", "A"), cell("b", "B")]),
                          Row(id: BlockID("r1"), cells: [cell("c", "C"), cell("d", "D")])])
    }

    func test_mixedDoc_spansMatchCorePositionModel() {
        let v = DocumentCanvasView()
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("top"), runs: [TextRun(text: "Top")])),
            .table(table2x2()),
            .paragraph(ParagraphBlock(id: BlockID("bot"), runs: [TextRun(text: "Bot")])),
        ], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        let doc = Document(metadata: DocumentMetadata(title: "", createdAt: Date(timeIntervalSince1970: 0),
                                                      modifiedAt: Date(timeIntervalSince1970: 0)),
                           blocks: v.currentBlocks())
        let tree = DocumentTree.build(from: doc)
        XCTAssertEqual(v.documentSizeValue, DocumentTree.documentSize(doc))
        // Each cell's paragraph text node global start matches Core.
        for id in ["ap", "bp", "cp", "dp"] {
            let core = PositionResolver.globalPosition(of: .paragraph(BlockID(id)), offset: 0, in: tree)
            let region = v.allLeafRegions().first { $0.ref == .paragraph(BlockID(id)) }
            XCTAssertNotNil(region)
            XCTAssertEqual(region?.globalStart, core, "cell \(id)")
        }
    }

    func test_tableRoundTripsThroughCurrentBlocks() {
        let v = DocumentCanvasView()
        v.setBlocks([.table(table2x2())], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 400); v.layoutIfNeeded()
        guard case .table(let out) = v.currentBlocks()[0] else { return XCTFail("expected table") }
        XCTAssertEqual(out.rowCount, 2); XCTAssertEqual(out.columnCount, 2)
        XCTAssertEqual(out.rows[1].cells[1].blocks.count, 1)
    }

    func test_tableRendersNonBlank() {
        let v = DocumentCanvasView()
        v.setBlocks([.table(table2x2())], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 400); v.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(bounds: v.bounds).image { _ in v.drawHierarchy(in: v.bounds, afterScreenUpdates: true) }
        XCTAssertNotNil(image.cgImage)
    }

    // An EMPTY cell reserves one line of its font's height (so its row doesn't collapse to the insets),
    // matching a single-line filled cell in the same row.
    func test_emptyCellReservesLineHeight() {
        let v = DocumentCanvasView()
        let empty = Cell(id: BlockID("a"), blocks: [.paragraph(ParagraphBlock(id: BlockID("ap"), runs: []))])
        let filled = Cell(id: BlockID("b"), blocks: [.paragraph(ParagraphBlock(id: BlockID("bp"), runs: [TextRun(text: "Beta")]))])
        v.setBlocks([.table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
            rows: [Row(id: BlockID("r0"), cells: [empty, filled])]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 300); v.layoutIfNeeded()
        let table = v.boxes.first as! TableBlockBox
        let emptyBox = table.cells[0][0].boxes[0]
        let filledBox = table.cells[0][1].boxes[0]
        XCTAssertEqual(emptyBox.height, filledBox.height, accuracy: 1.0,
                       "an empty cell reserves a real line, matching a single-line filled cell")
        XCTAssertGreaterThan(emptyBox.height, 20, "not collapsed to just the insets")
    }

    // A wholly-empty row keeps a real line's height (≈ a filled row), not just topInset+bottomInset.
    func test_emptyRowDoesNotCollapse() {
        let v = DocumentCanvasView()
        v.setBlocks([.table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
            rows: [
                Row(id: BlockID("r0"), cells: [cell("a", "Alpha"), cell("b", "Beta")]),
                Row(id: BlockID("r1"), cells: [
                    Cell(id: BlockID("c"), blocks: [.paragraph(ParagraphBlock(id: BlockID("cp"), runs: []))]),
                    Cell(id: BlockID("d"), blocks: [.paragraph(ParagraphBlock(id: BlockID("dp"), runs: []))]),
                ]),
            ]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 400); v.layoutIfNeeded()
        // The empty row's cells lay out at the same height as the filled row's cells.
        let table = v.boxes.first as! TableBlockBox
        let filledRowBox = table.cells[0][0].boxes[0]
        let emptyRowBox = table.cells[1][0].boxes[0]
        XCTAssertEqual(emptyRowBox.height, filledRowBox.height, accuracy: 1.0,
                       "an empty row keeps a real line's height")
    }
}

extension TableBlockBoxTests {
    private func headerTable() -> TableBlock {
        TableBlock(id: BlockID("t"),
                   columns: [ColumnSpec(width: 120), ColumnSpec(width: 120, alignment: .center)],
                   rows: [
                       Row(id: BlockID("r0"), isHeader: true, cells: [cell("a", "Name"), cell("b", "Role")]),
                       Row(id: BlockID("r1"), cells: [cell("c", "Ada"), cell("d", "Eng")]),
                   ])
    }
    private func box(_ v: DocumentCanvasView) -> TableBlockBox { v.boxes.first as! TableBlockBox }
    private func cellFont(_ t: TableBlockBox, _ r: Int, _ c: Int) -> UIFont {
        let b = t.cells[r][c].boxes[0] as! BlockBox
        return b.layout.attributedString.attribute(.font, at: 0, effectiveRange: nil) as! UIFont
    }
    private func cellAlignment(_ t: TableBlockBox, _ r: Int, _ c: Int) -> NSTextAlignment {
        let b = t.cells[r][c].boxes[0] as! BlockBox
        let ps = b.layout.attributedString.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        return ps?.alignment ?? .natural
    }

    func test_firstRowRendersBold_otherRowsDoNot() {
        let v = DocumentCanvasView()
        v.setBlocks([.table(headerTable())], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 400); v.layoutIfNeeded()
        let t = box(v)
        // The header row (row 0) renders bold in every column; body rows do not.
        XCTAssertTrue(cellFont(t, 0, 0).fontDescriptor.symbolicTraits.contains(.traitBold), "header row col 0 bold")
        XCTAssertTrue(cellFont(t, 0, 1).fontDescriptor.symbolicTraits.contains(.traitBold), "header row col 1 bold")
        XCTAssertFalse(cellFont(t, 1, 0).fontDescriptor.symbolicTraits.contains(.traitBold), "body row col 0 not bold")
        XCTAssertFalse(cellFont(t, 1, 1).fontDescriptor.symbolicTraits.contains(.traitBold), "body row col 1 not bold")
    }

    func test_headerRowBackground_coversFirstRowOnly_withGrayTint() {
        let v = DocumentCanvasView()
        v.setBlocks([.table(headerTable())], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 400); v.layoutIfNeeded()
        let t = box(v)
        let rect = t.headerRowBackgroundRect()!
        let header = t.cellRect(row: 0, column: 1)!, body = t.cellRect(row: 1, column: 0)!
        XCTAssertEqual(rect.minY, t.frame.minY, accuracy: 0.5)                       // starts at the table top
        XCTAssertTrue(rect.contains(CGPoint(x: header.midX, y: header.midY)))        // covers the header row
        XCTAssertFalse(rect.contains(CGPoint(x: body.midX, y: body.midY)))           // not the body row
        XCTAssertGreaterThan(rect.width, t.cellRect(row: 0, column: 0)!.width)       // spans the full table width
        var alpha: CGFloat = 1
        TableBlockBox.headerRowBackground.getWhite(nil, alpha: &alpha)
        XCTAssertLessThan(alpha, 1)                                                  // a translucent gray tint
    }

    func test_headerBold_isStrippedFromModelOnExtraction() {
        let v = DocumentCanvasView()
        v.setBlocks([.table(headerTable())], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 400); v.layoutIfNeeded()
        guard case .table(let out) = v.currentBlocks()[0] else { return XCTFail("expected table") }
        // Header cell runs are NOT bold in the model (render-only; markdown-clean).
        guard case .paragraph(let p) = out.rows[0].cells[0].blocks[0] else { return XCTFail() }
        XCTAssertFalse(p.runs.first?.attributes.bold ?? true)
    }

    func test_columnAlignment_rendersAndRoundTripsClean() {
        let v = DocumentCanvasView()
        v.setBlocks([.table(headerTable())], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 400); v.layoutIfNeeded()
        let t = box(v)
        XCTAssertEqual(cellAlignment(t, 1, 1), .center, "column 1 renders centered")
        XCTAssertEqual(cellAlignment(t, 1, 0), .left, "column 0 stays left")
        guard case .table(let out) = v.currentBlocks()[0] else { return XCTFail("expected table") }
        XCTAssertEqual(out.columns[1].alignment, .center, "alignment lives in ColumnSpec")
        guard case .paragraph(let p) = out.rows[1].cells[1].blocks[0] else { return XCTFail() }
        XCTAssertEqual(p.paragraph.alignment, .left, "the cell's own alignment is untouched")
    }

    // A table whose columns all scale to >= minColumnWidth fits: scale-to-fit, no overflow (today's behavior).
    func test_widthPolicy_fittingTable_scalesToFit_noOverflow() {
        let v = DocumentCanvasView()
        v.setBlocks([.table(TableBlock(id: BlockID("t"),
            columns: [ColumnSpec(width: 120), ColumnSpec(width: 120), ColumnSpec(width: 120)],
            rows: [Row(id: BlockID("r0"), cells: [cell("a", "A"), cell("b", "B"), cell("c", "C")])]))], width: 390)
        v.frame = CGRect(x: 0, y: 0, width: 390, height: 300); v.layoutIfNeeded()
        let t = v.boxes[0] as! TableBlockBox
        XCTAssertEqual(t.gridWidth, t.frame.width, accuracy: 0.5, "fitting table grid == content strip")
        XCTAssertEqual(t.blockViewFrame.width, t.gridWidth, accuracy: 0.5, "view frame == grid width when it fits")
    }

    // A table with more columns than fit at minColumnWidth overflows and keeps each column at the minimum.
    func test_widthPolicy_wideTable_overflows_atMinColumnWidth() {
        let v = DocumentCanvasView()
        let cols = (0..<6).map { _ in ColumnSpec(width: 100) }
        let cells = (0..<6).map { i in cell("c\(i)", "C\(i)") }
        v.setBlocks([.table(TableBlock(id: BlockID("t"), columns: cols,
            rows: [Row(id: BlockID("r0"), cells: cells)]))], width: 390)
        v.frame = CGRect(x: 0, y: 0, width: 390, height: 300); v.layoutIfNeeded()
        let t = v.boxes[0] as! TableBlockBox
        XCTAssertTrue(t.columnWidths.allSatisfy { $0 >= TableBlockBox.minColumnWidth - 0.01 },
                      "every column is at least the minimum")
        XCTAssertGreaterThan(t.gridWidth, t.frame.width, "wide table overflows the content strip")
        XCTAssertEqual(t.blockViewFrame.width, t.frame.width, accuracy: 0.5,
                       "view frame is the visible clipping window, not the full grid")
    }

    // A table that scales to exactly minColumnWidth per column still takes the fit branch (>= is inclusive).
    func test_widthPolicy_exactBoundary_noOverflow() {
        // n=3, border=1: avail = layoutWidth - 4; for fit == 100 we need avail = 300 → layoutWidth = 304.
        let v = DocumentCanvasView()
        v.setBlocks([.table(TableBlock(id: BlockID("t"),
            columns: [ColumnSpec(width: 100), ColumnSpec(width: 100), ColumnSpec(width: 100)],
            rows: [Row(id: BlockID("r0"), cells: [cell("a","A"), cell("b","B"), cell("c","C")])]))], width: 304 + 2*16)
        v.frame = CGRect(x: 0, y: 0, width: 304 + 2*16, height: 200); v.layoutIfNeeded()
        let t = v.boxes[0] as! TableBlockBox
        XCTAssertEqual(t.gridWidth, t.frame.width, accuracy: 0.5, "table at exact min still fits — no scroll")
    }

    // A wide, scrolled table: caretRect for a cell shifts left by the offset; a tap at the shifted
    // location still resolves to the same global position (round-trip through the seam).
    func test_seam_caretAndHitTest_foldInContentOffset() {
        let v = DocumentCanvasView()
        let cols = (0..<6).map { _ in ColumnSpec(width: 100) }
        let cells = (0..<6).map { i in cell("c\(i)", "Cell\(i)") }
        v.setBlocks([.table(TableBlock(id: BlockID("t"), columns: cols,
            rows: [Row(id: BlockID("r0"), cells: cells)]))], width: 390)
        v.frame = CGRect(x: 0, y: 0, width: 390, height: 300); v.layoutIfNeeded()
        let t = v.boxes[0] as! TableBlockBox
        let pos = t.cellTextStart(row: 0, column: 4)!
        let unscrolled = v.caretRect(for: DocumentTextPosition(pos))
        t.contentOffsetX = 150
        let scrolled = v.caretRect(for: DocumentTextPosition(pos))
        XCTAssertEqual(scrolled.minX, unscrolled.minX - 150, accuracy: 0.5, "caret shifts left by the offset")
        XCTAssertEqual(scrolled.minY, unscrolled.minY, accuracy: 0.5, "y unchanged by horizontal scroll")
        let hit = v.closestGlobalPosition(to: CGPoint(x: scrolled.midX, y: scrolled.midY))
        XCTAssertEqual(hit, pos, "hit-test folds the offset back in")
    }

    func test_seam_selectionRects_foldInContentOffset() {
        let v = DocumentCanvasView()
        let cols = (0..<6).map { _ in ColumnSpec(width: 100) }
        let cells = (0..<6).map { i in cell("c\(i)", "Cell\(i)") }
        v.setBlocks([.table(TableBlock(id: BlockID("t"), columns: cols,
            rows: [Row(id: BlockID("r0"), cells: cells)]))], width: 390)
        v.frame = CGRect(x: 0, y: 0, width: 390, height: 300); v.layoutIfNeeded()
        let t = v.boxes[0] as! TableBlockBox
        let from = t.cellTextStart(row: 0, column: 4)!
        let rectsUnscrolled = v.selectionRects(globalFrom: from, globalTo: from + 2)
        t.contentOffsetX = 150
        let rectsScrolled = v.selectionRects(globalFrom: from, globalTo: from + 2)
        XCTAssertEqual(rectsUnscrolled.count, rectsScrolled.count)
        XCTAssertFalse(rectsScrolled.isEmpty)
        XCTAssertEqual(rectsScrolled[0].minX, rectsUnscrolled[0].minX - 150, accuracy: 0.5)
    }

    func test_autoScrollToCaret_revealsOffscreenCell() {
        let v = DocumentCanvasView()
        let cols = (0..<6).map { _ in ColumnSpec(width: 100) }
        let cells = (0..<6).map { i in cell("c\(i)", "Cell\(i)") }
        v.setBlocks([.table(TableBlock(id: BlockID("t"), columns: cols,
            rows: [Row(id: BlockID("r0"), cells: cells)]))], width: 390)
        v.frame = CGRect(x: 0, y: 0, width: 390, height: 300); v.layoutIfNeeded()
        let t = v.boxes[0] as! TableBlockBox
        let tv = v.blockViews[BlockID("t")] as! TableBackingView
        tv.layoutIfNeeded()
        XCTAssertEqual(tv.scroll.contentOffset.x, 0, accuracy: 0.5)
        let pos = t.cellTextStart(row: 0, column: 5)!
        v.setCaret(global: pos)
        tv.layoutIfNeeded()
        XCTAssertGreaterThan(tv.scroll.contentOffset.x, 0, "the last column is scrolled into view")
        let cellRect = t.cellRect(row: 0, column: 5)!
        let contentX = cellRect.minX - t.frame.minX
        XCTAssertLessThanOrEqual(contentX, tv.scroll.contentOffset.x + tv.bounds.width + 0.5)
        XCTAssertGreaterThanOrEqual(contentX + cellRect.width, tv.scroll.contentOffset.x - 0.5)
    }

    func test_dragAutoScroll_advancesOffsetTowardRightEdge() {
        let v = DocumentCanvasView()
        let cols = (0..<6).map { _ in ColumnSpec(width: 100) }
        let cells = (0..<6).map { i in cell("c\(i)", "Cell\(i)") }
        v.setBlocks([.table(TableBlock(id: BlockID("t"), columns: cols,
            rows: [Row(id: BlockID("r0"), cells: cells)]))], width: 390)
        v.frame = CGRect(x: 0, y: 0, width: 390, height: 300); v.layoutIfNeeded()
        let t = v.boxes[0] as! TableBlockBox
        let tv = v.blockViews[BlockID("t")] as! TableBackingView
        tv.layoutIfNeeded()
        // Non-collapsed selection with the head inside the table.
        v.anchor = t.cellTextStart(row: 0, column: 0)!
        v.head = t.cellTextStart(row: 0, column: 1)!
        let before = tv.scroll.contentOffset.x
        let rightEdge = CGPoint(x: t.frame.minX + tv.bounds.width - 4, y: t.frame.minY + 10)
        v.updateDragAutoScroll(point: rightEdge, headInTable: true)
        for _ in 0..<5 { v.dragAutoScrollTick() }
        XCTAssertGreaterThan(tv.scroll.contentOffset.x, before, "auto-scroll advances toward the right edge")
        v.stopDragAutoScroll()
        XCTAssertLessThanOrEqual(tv.scroll.contentOffset.x, tv.scroll.contentSize.width - tv.bounds.width + 0.5, "clamped to max")
    }
}
#endif
