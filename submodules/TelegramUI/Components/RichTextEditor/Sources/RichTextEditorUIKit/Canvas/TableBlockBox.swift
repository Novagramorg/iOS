#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// A table block: a grid of cells, each cell a `BlockStack`. Token size follows the Core model
/// (table = Σrows + 2; row = Σcells + 2; cell = Σblocks + 2). Cells are laid out row-major; the
/// canvas treats the whole table as one `CanvasBlock` and recurses via `leafRegions()`.
@available(iOS 13.0, *)
final class TableBlockBox: CanvasBlock {
    let id: BlockID
    let columns: [ColumnSpec]
    var rowIDs: [BlockID]
    var rowIsHeader: [Bool]
    var rowMinHeights: [CGFloat]
    var cellIDs: [[BlockID]]
    var cellBackgrounds: [[RGBAColor?]]
    var cells: [[BlockStack]]
    let mapper: AttributedStringMapper

    var frame: CGRect = .zero
    var nodeStart: Int = 0
    /// The inner scroll view's current horizontal offset, pushed in by the canvas (`syncBlockViews` /
    /// `scrollViewDidScroll`). 0 unless the table overflows and has been scrolled. All other geometry stays
    /// UNSCROLLED; only `closestPosition` (and the canvas-space consumers) fold this in (Task 3).
    var contentOffsetX: CGFloat = 0
    private(set) var layoutWidth: CGFloat
    var columnWidths: [CGFloat] = []
    var rowHeights: [CGFloat] = []

    /// Interior HORIZONTAL cell padding (each side); also drives content width.
    static let cellPadding: CGFloat = 6
    /// Interior VERTICAL cell padding (top + bottom of a cell's content). Applied at the CELL level
    /// (`recompute` content origin + row-height), exactly like `cellPadding` is for the horizontal axis.
    /// It is intentionally larger than `cellPadding`: it reproduces the cell's long-standing vertical
    /// breathing room, which *used* to come — incorrectly — from the document's 8pt inter-block inset
    /// (`BlockBox.defaultVerticalInset`) leaking into the cell's `BlockStack` ON TOP of `cellPadding`
    /// (6 + 8 = 14). That coupling tied cell padding to the document-body block spacing, so it didn't
    /// scale with the cell and the 15pt cell font looked under-filled / vertically centered. Now it is an
    /// explicit cell metric and the cell `BlockStack` carries NO block inset (`verticalInsetBase = 0`), so
    /// this is the cell's sole vertical padding.
    static let cellVerticalPadding: CGFloat = 14
    static let border: CGFloat = 1
    /// Outer-border corner radius (≈8pt, measured from the reference design).
    static let outerCornerRadius: CGFloat = 8
    /// Space the table reserves below its grid, within its own frame. Doubles as the table's bottom
    /// margin AND the room the ••• column handle needs to stay on-screen/tappable when the table is the
    /// document's last block (the canvas is content-sized to the table's frame). Inter-block separation
    /// from a following block is added on top via `BlockStack.framedNeighborMargin`.
    static let bottomSpacing: CGFloat = 9
    /// Minimum width a column keeps before the table overflows the content strip and scrolls horizontally
    /// (Step 2). Tunable via the demo screenshot. Columns still scale-to-fit while every column stays at or
    /// above this; once one would drop below it, the table keeps its natural width and scrolls.
    static let minColumnWidth: CGFloat = 100
    init(table: TableBlock, mapper: AttributedStringMapper, width: CGFloat) {
        id = table.id
        columns = table.columns
        rowIDs = table.rows.map { $0.id }
        rowIsHeader = table.rows.map { $0.isHeader }
        rowMinHeights = table.rows.map { CGFloat($0.height ?? 0) }
        cellIDs = table.rows.map { $0.cells.map { $0.id } }
        cellBackgrounds = table.rows.map { $0.cells.map { $0.background } }
        // Cells render at a smaller base font than the document body (15 vs 17). Derive a cell-scoped
        // mapper once and store it as this table's `mapper`; every cell box built here, in `appendRow`,
        // and in split/merge replacements (which inherit their source box's `mapper`) shares it.
        let cellMapper = mapper.tableCellVariant()
        self.mapper = cellMapper
        layoutWidth = max(width, 1)
        cells = table.rows.map { row in
            row.cells.map { c in
                let stack = BlockStack(boxes: c.blocks.compactMap { block in
                    switch block {
                    case .paragraph(let p): return BlockBox(paragraph: p, mapper: cellMapper, width: 100)
                    case .media(let img): return MediaBlockBox(media: img, mapper: cellMapper, width: 100)
                    case .table: return nil   // no nested tables in v1
                    case .code: return nil    // no nested code blocks in a table cell in v1
                    }
                })
                // The cell owns its vertical padding (`cellVerticalPadding`), so its stack adds no
                // inter-block inset — otherwise the document's 8pt inset would stack on top.
                stack.verticalInsetBase = 0
                return stack
            }
        }
        applyRenderOverrides()
    }

    var rowCount: Int { cells.count }
    var columnCount: Int { columns.count }

    // MARK: - CanvasBlock view-backed rendering
    /// Tables render via a `BlockBackingView` (not directly by the canvas `draw(_:)`).
    var rendersAsBlockView: Bool { true }
    /// The visible clipping window the table's backing view occupies in canvas space: the content-strip
    /// width (`frame.width`) when the grid overflows, else the exact grid extent. The inner scroll view's
    /// `contentSize.width` is the full `gridWidth` (Task 2); a too-wide grid scrolls inside this window.
    var blockViewFrame: CGRect {
        CGRect(x: frame.minX, y: frame.minY, width: min(gridWidth, frame.width), height: frame.height)
    }

    /// The grid's drawn width = Σ column widths + (columnCount+1) borders. Equals `frame.width` when the
    /// table fits the content strip (scale-to-fit); exceeds it when one or more columns are at
    /// `minColumnWidth` and the table overflows → horizontal scroll.
    var gridWidth: CGFloat {
        if columnWidths.isEmpty { computeColumnWidths() }
        return columnWidths.reduce(0) { $0 + $1 + TableBlockBox.border } + TableBlockBox.border
    }

    // Token size: cell = stack tokens + 2; row = Σcells + 2; table = Σrows + 2.
    var nodeSize: Int {
        var total = 0
        for row in cells {
            var rowTotal = 0
            for stack in row { rowTotal += stackTokens(stack) + 2 }
            total += rowTotal + 2
        }
        return total + 2
    }
    private func stackTokens(_ stack: BlockStack) -> Int { stack.boxes.reduce(0) { $0 + $1.nodeSize } }

    func setWidth(_ width: CGFloat) { layoutWidth = max(width, 1); computeColumnWidths() }

    // Pure column-width computation for an arbitrary total width (no mutation of self.columnWidths).
    // internal (not private): shared by the live height path (computeColumnWidths / rowHeightsComputed)
    // and the stateless measuredHeight, plus TableMeasureTests — keep it non-private.
    func solveColumnWidths(forWidth width: CGFloat) -> [CGFloat] {
        let borders = CGFloat(columnCount + 1) * TableBlockBox.border
        let avail = max(width - borders, CGFloat(columnCount))
        let sum = columns.reduce(0) { $0 + CGFloat($1.width) }
        let fit: [CGFloat]
        if sum <= 0 { fit = Array(repeating: avail / CGFloat(max(columnCount, 1)), count: columnCount) }
        else { let scale = avail / sum; fit = columns.map { CGFloat($0.width) * scale } }
        if fit.allSatisfy({ $0 >= TableBlockBox.minColumnWidth }) { return fit }
        return fit.map { max($0, TableBlockBox.minColumnWidth) }
    }

    func cellContentWidth(_ col: Int, in cols: [CGFloat]) -> CGFloat {
        max(cols[col] - TableBlockBox.border - TableBlockBox.cellPadding * 2, 1)
    }

    func measuredHeight(forWidth width: CGFloat) -> CGFloat {
        let cols = solveColumnWidths(forWidth: max(width, 1))
        var rows: CGFloat = 0
        for (r, row) in cells.enumerated() {
            var maxH: CGFloat = 0
            for (c, stack) in row.enumerated() {
                maxH = max(maxH, stack.measuredHeight(forWidth: cellContentWidth(c, in: cols)))
            }
            rows += max(maxH + TableBlockBox.cellVerticalPadding * 2, rowMinHeights[r]) + TableBlockBox.border
        }
        return TableBlockBox.border + rows + TableBlockBox.bottomSpacing
    }

    private func computeColumnWidths() { columnWidths = solveColumnWidths(forWidth: layoutWidth) }

    /// Cell content width (column width minus the left border and horizontal padding).
    private func cellContentWidth(_ col: Int) -> CGFloat { max(columnWidths[col] - TableBlockBox.border - TableBlockBox.cellPadding * 2, 1) }

    var height: CGFloat {
        if columnWidths.isEmpty { computeColumnWidths() }
        // Grid + a reserved strip below it (bottomSpacing) so the column handle stays on-screen for a
        // trailing table; the gap to the block ABOVE comes from that block's facing inset.
        return TableBlockBox.border + rowHeightsComputed().reduce(0) { $0 + $1 + TableBlockBox.border } + TableBlockBox.bottomSpacing
    }

    /// Row heights = max cell content height in the row + padding, clamped to the model minimum.
    /// Non-mutating: cell layout is owned by `recompute()`, not by reading height.
    private func rowHeightsComputed() -> [CGFloat] {
        let cols = columnWidths.isEmpty ? solveColumnWidths(forWidth: layoutWidth) : columnWidths
        var heights: [CGFloat] = []
        for (r, row) in cells.enumerated() {
            var maxH: CGFloat = 0
            for (c, stack) in row.enumerated() {
                maxH = max(maxH, stack.measuredHeight(forWidth: cellContentWidth(c, in: cols)))
            }
            heights.append(max(maxH + TableBlockBox.cellVerticalPadding * 2, rowMinHeights[r]))
        }
        return heights
    }

    // CanvasBlock
    func currentBlock() -> Block {
        var rows: [Row] = []
        for (r, row) in cells.enumerated() {
            var outCells: [Cell] = []
            for (c, stack) in row.enumerated() {
                var blocks = stack.boxes.map { $0.currentBlock() }
                if r == 0 { blocks = blocks.map { TableBlockBox.strippingBold($0) } }
                outCells.append(Cell(id: cellIDs[r][c], blocks: blocks, background: cellBackgrounds[r][c]))
            }
            rows.append(Row(id: rowIDs[r], height: rowMinHeights[r] > 0 ? Double(rowMinHeights[r]) : nil,
                            isHeader: rowIsHeader[r], cells: outCells))
        }
        return .table(TableBlock(id: id, columns: columns, rows: rows))
    }

    /// Re-applies the render-only overrides to every cell's display layout: per-column alignment and,
    /// for the first row (r == 0, the header), bold. Idempotent; called at build and on each recompute so it survives edits.
    private func applyRenderOverrides() {
        for (r, row) in cells.enumerated() {
            for (c, stack) in row.enumerated() {
                let alignment = columns.indices.contains(c) ? columns[c].alignment : .left
                for box in stack.boxes {
                    (box as? BlockBox)?.applyDisplayOverride(alignment: alignment, forceBold: r == 0, mapper: mapper)
                }
            }
        }
    }

    /// Clears the bold trait from a paragraph block's runs (the header row's bold is a render override).
    private static func strippingBold(_ block: Block) -> Block {
        guard case .paragraph(var p) = block else { return block }
        p.runs = p.runs.map { run in var r = run; r.attributes.bold = false; return r }
        return .paragraph(p)
    }

    /// Assigns nodeStarts to every cell stack row-major, matching the Core token walk, and lays out
    /// cell frames. Returns nothing; the canvas reads `nodeSize`/`leafRegions` afterward.
    func recompute() {
        applyRenderOverrides()
        if columnWidths.isEmpty { computeColumnWidths() }
        rowHeights = rowHeightsComputed()
        // Token base: this table's content starts at nodeStart + 1 (the table open token).
        var pos = nodeStart + 1
        var y = frame.minY + TableBlockBox.border
        for (r, row) in cells.enumerated() {
            pos += 1                                   // row open token
            var x = frame.minX + TableBlockBox.border
            for (c, stack) in row.enumerated() {
                pos += 1                               // cell open token
                let cw = columnWidths[c]
                let contentOrigin = CGPoint(x: x + TableBlockBox.cellPadding, y: y + TableBlockBox.cellVerticalPadding)
                _ = stack.recompute(baseOffset: pos - 1)   // cell content begins at (cell open) → baseOffset
                _ = stack.layout(origin: contentOrigin, width: cellContentWidth(c))
                pos += stackTokens(stack)
                pos += 1                               // cell close token
                x += cw + TableBlockBox.border
            }
            pos += 1                                   // row close token
            y += rowHeights[r] + TableBlockBox.border
        }
    }

    func leafRegions() -> [LeafTextRegion] { cells.flatMap { $0.flatMap { $0.leafRegions() } } }

    /// Every cell paragraph box paired with its canvas-coordinate frame, for view hosting. (Cell IMAGES are
    /// excluded — they still draw in place via `draw`; only paragraphs become view-backed.)
    func cellParagraphBoxes() -> [(box: BlockBox, frame: CGRect)] {
        cells.flatMap { row in row.flatMap { $0.boxes.compactMap { b in (b as? BlockBox).map { ($0, $0.frame) } } } }
    }

    /// The cell `BlockStack` that owns global position `pos`, with the box + local offset + index
    /// within that stack. Mirrors `leafRegions()`'s recursion, for the editing engine.
    func cellStack(containing pos: Int) -> (stack: BlockStack, box: CanvasBlock, local: Int, index: Int)? {
        for row in cells {
            for stack in row {
                for (i, b) in stack.boxes.enumerated() {
                    if let first = b.leafRegions().first,
                       pos >= first.globalStart, pos <= first.globalStart + first.length {
                        return (stack, b, pos - first.globalStart, i)
                    }
                }
            }
        }
        return nil
    }

    /// (row, column) of the cell whose stack owns `pos`, or nil.
    func cellLocation(containing pos: Int) -> (row: Int, column: Int)? {
        for (r, row) in cells.enumerated() {
            for (c, stack) in row.enumerated() {
                for b in stack.boxes {
                    if let first = b.leafRegions().first, pos >= first.globalStart, pos <= first.globalStart + first.length {
                        return (r, c)
                    }
                }
            }
        }
        return nil
    }

    /// The global text start of cell (row, column)'s first leaf region (where Tab places the caret).
    func cellTextStart(row: Int, column: Int) -> Int? {
        guard cells.indices.contains(row), cells[row].indices.contains(column) else { return nil }
        return cells[row][column].leafRegions().first?.globalStart
    }

    /// The canvas-coordinate rect of cell (row, column), from cached grid geometry (matches `draw` /
    /// `closestPosition`). Used by vertical caret nav to snap into the same-column neighbor cell.
    func cellRect(row: Int, column: Int) -> CGRect? {
        guard cells.indices.contains(row), cells[row].indices.contains(column),
              rowHeights.indices.contains(row), columnWidths.indices.contains(column) else { return nil }
        var y = frame.minY + TableBlockBox.border
        for r in 0..<row { y += rowHeights[r] + TableBlockBox.border }
        var x = frame.minX + TableBlockBox.border
        for c in 0..<column { x += columnWidths[c] + TableBlockBox.border }
        return CGRect(x: x, y: y, width: columnWidths[column], height: rowHeights[row])
    }

    /// The row index whose vertical band contains canvas-y `y`, clamped to `0..<rowCount`. The inverse
    /// of `cellRect`'s y math (sum of `rowHeights` + `border`, from `frame.minY + border`). A point in a
    /// border slot resolves to the row above it (half-border slack).
    func rowIndex(atY y: CGFloat) -> Int {
        guard !rowHeights.isEmpty else { return 0 }
        var top = frame.minY + TableBlockBox.border
        for r in 0..<rowHeights.count {
            let bottom = top + rowHeights[r]
            if y < bottom + TableBlockBox.border / 2 { return r }
            top = bottom + TableBlockBox.border
        }
        return rowHeights.count - 1
    }

    /// The column index whose horizontal band contains canvas-x `x`, clamped to `0..<columnCount`.
    func columnIndex(atX x: CGFloat) -> Int {
        guard !columnWidths.isEmpty else { return 0 }
        var left = frame.minX + TableBlockBox.border
        for c in 0..<columnWidths.count {
            let right = left + columnWidths[c]
            if x < right + TableBlockBox.border / 2 { return c }
            left = right + TableBlockBox.border
        }
        return columnWidths.count - 1
    }

    /// The canvas-coordinate band tinted with the header background (row 0): full table width, from the
    /// table top through the divider below row 0. `nil` if the table is empty. `draw` fills it clipped to
    /// the rounded outer border so the top corners stay rounded.
    func headerRowBackgroundRect() -> CGRect? {
        guard rowCount > 0, !rowHeights.isEmpty else { return nil }
        let totalW = columnWidths.reduce(0) { $0 + $1 + TableBlockBox.border } + TableBlockBox.border
        let height = TableBlockBox.border + rowHeights[0] + TableBlockBox.border
        return CGRect(x: frame.minX, y: frame.minY, width: totalW, height: height)
    }

    /// Appends a row of `columnCount` empty single-paragraph cells (fresh ids). Caller recomputes + undo.
    func appendRow() {
        let n = max(columnCount, 1)
        var rowStacks: [BlockStack] = []
        var ids: [BlockID] = []
        var bgs: [RGBAColor?] = []
        for _ in 0..<n {
            let para = ParagraphBlock(id: BlockID.generate())
            let stack = BlockStack(boxes: [BlockBox(paragraph: para, mapper: mapper, width: 100)])
            stack.verticalInsetBase = 0   // cell owns its vertical padding (see cellVerticalPadding)
            rowStacks.append(stack)
            ids.append(BlockID.generate()); bgs.append(nil)
        }
        cells.append(rowStacks); cellIDs.append(ids); cellBackgrounds.append(bgs)
        rowIDs.append(BlockID.generate()); rowIsHeader.append(false); rowMinHeights.append(0)
    }

    /// Whether row `r` is a header row.
    func isHeaderRow(_ r: Int) -> Bool { rowIsHeader.indices.contains(r) && rowIsHeader[r] }

    func draw(in ctx: CGContext, imageProvider: (String) -> UIImage?) {
        let totalW = columnWidths.reduce(0) { $0 + $1 + TableBlockBox.border } + TableBlockBox.border
        let totalH = TableBlockBox.border + rowHeights.reduce(0) { $0 + $1 + TableBlockBox.border }
        // Rounded outer border path (also the clip for fills so corners stay rounded). CG centers
        // strokes, so inset by half the border so the 1pt stroke fills its slot flush with the frame edge.
        let half = TableBlockBox.border / 2
        let outer = UIBezierPath(roundedRect: CGRect(x: frame.minX + half, y: frame.minY + half,
                                                     width: totalW - TableBlockBox.border,
                                                     height: totalH - TableBlockBox.border),
                                 cornerRadius: TableBlockBox.outerCornerRadius - half)
        // Header-row tint, clipped to the rounded border so the top corners round with the table.
        if let headerRect = headerRowBackgroundRect() {
            ctx.saveGState(); outer.addClip()
            mapper.theme.tableHeaderBackground.setFill(); ctx.fill(headerRect)
            ctx.restoreGState()
        }
        var y = frame.minY + TableBlockBox.border
        for (r, row) in cells.enumerated() {
            var x = frame.minX + TableBlockBox.border
            for (c, stack) in row.enumerated() {
                let cellRect = CGRect(x: x, y: y, width: columnWidths[c], height: rowHeights[r])
                if let bg = cellBackgrounds[r][c] { bg.uiColor.setFill(); ctx.fill(cellRect) }
                // Cell PARAGRAPHS render via their own backing views (hosted in the table's content view so
                // they ride horizontal scroll); only non-paragraph boxes (cell images — rare) draw in place.
                for box in stack.boxes where !(box is BlockBox) {
                    box.draw(in: ctx, imageProvider: imageProvider)
                }
                x += columnWidths[c] + TableBlockBox.border
            }
            y += rowHeights[r] + TableBlockBox.border
        }
        // grid lines (interior dividers + outer border), using cached geometry
        mapper.theme.tableBorder.setStroke()
        ctx.setLineWidth(TableBlockBox.border)
        if columnWidths.count > 1 {
            var cx = frame.minX + TableBlockBox.border
            for w in columnWidths.dropLast() {
                cx += w
                ctx.move(to: CGPoint(x: cx + TableBlockBox.border / 2, y: frame.minY))
                ctx.addLine(to: CGPoint(x: cx + TableBlockBox.border / 2, y: frame.minY + totalH))
                cx += TableBlockBox.border
            }
        }
        if rowHeights.count > 1 {
            var ry = frame.minY + TableBlockBox.border
            for h in rowHeights.dropLast() {
                ry += h
                ctx.move(to: CGPoint(x: frame.minX, y: ry + TableBlockBox.border / 2))
                ctx.addLine(to: CGPoint(x: frame.minX + totalW, y: ry + TableBlockBox.border / 2))
                ry += TableBlockBox.border
            }
        }
        ctx.strokePath()
        // Rounded outer border (path built up front, also used to clip the header tint).
        outer.lineWidth = TableBlockBox.border
        outer.stroke()
    }

    func closestPosition(toCanvasPoint point: CGPoint) -> Int {
        guard rowCount > 0, columnCount > 0 else { return nodeStart + 1 }
        // The incoming point is a VISIBLE canvas touch; the cell walk below is unscrolled, so add the offset.
        let point = CGPoint(x: point.x + contentOffsetX, y: point.y)
        // Find the cell whose rect contains the point (or the nearest), then recurse.
        var y = frame.minY + TableBlockBox.border
        for (r, row) in cells.enumerated() {
            var x = frame.minX + TableBlockBox.border
            for (c, stack) in row.enumerated() {
                let cellRect = CGRect(x: x, y: y, width: columnWidths[c], height: rowHeights[r])
                if cellRect.contains(point) || (point.y >= cellRect.minY && point.y < cellRect.maxY && c == row.count - 1) {
                    return stack.closestPosition(toCanvasPoint: point)
                }
                x += columnWidths[c] + TableBlockBox.border
            }
            y += rowHeights[r] + TableBlockBox.border
        }
        // Fallback: last cell's closest position.
        if let lastStack = cells.last?.last { return lastStack.closestPosition(toCanvasPoint: point) }
        return nodeStart + 1
    }

    // Degenerate single-text-region conformance (unused: the canvas uses leafRegions() for tables).
    // Per-instance (not static): the canvas never edits through a table's `textLayout` — a collapsed
    // caret resting on a table boundary is snapped into a cell first (see `caretSnappedIntoCell`) — but
    // keeping this per-instance contains any future accidental write to one table rather than leaking
    // it into a process-wide shared layout.
    private let emptyLayout = makeBlockLayout(attributedString: NSAttributedString(string: ""), width: 1)
    var textLayout: BlockLayoutEngine { emptyLayout }
    var textStart: Int { nodeStart }
    var textLength: Int { 0 }
    var textRef: TextNodeRef { .paragraph(id) }
    var textOrigin: CGPoint { frame.origin }
}
#endif
