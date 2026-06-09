#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// Table structural commands. Each takes the live table via `currentBlock()`, applies a pure
/// `TableBlock` transform (Core), and rebuilds the one `TableBlockBox` inside `editing { }` so undo
/// is the existing whole-document `[Block]` snapshot. The structural commands below no-op when the
/// caret isn't in a table; `insertTable` is the inverse — it no-ops when the caret IS in a table (or
/// on an image/gap).
extension DocumentCanvasView {
    /// The table box containing the caret (`head`), its index in `boxes`, and the caret's (row, col).
    func activeTable() -> (box: TableBlockBox, index: Int, row: Int, col: Int)? {
        for (i, b) in boxes.enumerated() {
            if let t = b as? TableBlockBox, let loc = t.cellLocation(containing: head) {
                return (t, i, loc.row, loc.column)
            }
        }
        return nil
    }

    /// Swaps a freshly-built box for `newTable` at `index`, recomputes spans, and lands the caret in
    /// cell (caretRow, caretCol) clamped to the new geometry. Call inside `editing { … }`.
    func replaceTable(at index: Int, with newTable: TableBlock, caretRow: Int, caretCol: Int) {
        let newBox = TableBlockBox(table: newTable, mapper: mapper, width: effectiveWidth)
        var nb = boxes
        nb[index] = newBox
        boxes = nb
        recomputeSpans()
        let r = min(max(caretRow, 0), max(newBox.rowCount - 1, 0))
        let c = min(max(caretCol, 0), max(newBox.columnCount - 1, 0))
        if let pos = newBox.cellTextStart(row: r, column: c) { anchor = pos; head = pos }
    }

    func insertTableRowAbove() {
        guard let a = activeTable() else { return }
        editing {
            guard case .table(let table) = a.box.currentBlock() else { return }
            let range = structuralRowRange() ?? (a.row...a.row)
            let at = max(range.lowerBound, 1)   // never above the header (row 0)
            replaceTable(at: a.index, with: table.insertingRow(at: at), caretRow: at, caretCol: a.col)
        }
    }

    func insertTableRowBelow() {
        guard let a = activeTable() else { return }
        editing {
            guard case .table(let table) = a.box.currentBlock() else { return }
            let range = structuralRowRange() ?? (a.row...a.row)
            let at = range.upperBound + 1
            replaceTable(at: a.index, with: table.insertingRow(at: at), caretRow: at, caretCol: a.col)
        }
    }

    func deleteTableRow() {
        guard let a = activeTable() else { return }
        guard case .table(let table) = a.box.currentBlock() else { return }
        let range = structuralRowRange() ?? (a.row...a.row)
        guard range.contains(where: { table.rows.indices.contains($0) && !table.rows[$0].isHeader }) else { return }   // header-only range → nothing to delete
        editing {
            replaceTable(at: a.index, with: table.removingRows(in: range),
                         caretRow: range.lowerBound, caretCol: a.col)
        }
    }

    /// Default width for a new column (markdown ignores widths; this keeps proportions sane).
    private func defaultNewColumnWidth(_ table: TableBlock) -> Double {
        guard !table.columns.isEmpty else { return 120 }
        return table.columns.reduce(0) { $0 + $1.width } / Double(table.columns.count)
    }

    func insertTableColumnLeft() {
        guard let a = activeTable() else { return }
        editing {
            guard case .table(let table) = a.box.currentBlock() else { return }
            let range = structuralColumnRange() ?? (a.col...a.col)
            let new = table.insertingColumn(at: range.lowerBound, width: defaultNewColumnWidth(table), alignment: .left)
            replaceTable(at: a.index, with: new, caretRow: a.row, caretCol: range.lowerBound)
        }
    }

    func insertTableColumnRight() {
        guard let a = activeTable() else { return }
        editing {
            guard case .table(let table) = a.box.currentBlock() else { return }
            let range = structuralColumnRange() ?? (a.col...a.col)
            let at = range.upperBound + 1
            let new = table.insertingColumn(at: at, width: defaultNewColumnWidth(table), alignment: .left)
            replaceTable(at: a.index, with: new, caretRow: a.row, caretCol: at)
        }
    }

    func deleteTableColumn() {
        guard let a = activeTable() else { return }
        guard case .table(let table) = a.box.currentBlock() else { return }
        let range = structuralColumnRange() ?? (a.col...a.col)
        let removable = range.filter { table.columns.indices.contains($0) }.count
        guard table.columnCount > removable else { return }   // never delete every column
        editing {
            replaceTable(at: a.index, with: table.removingColumns(in: range),
                         caretRow: a.row, caretCol: range.lowerBound)
        }
    }

    /// The inclusive column range the current selection spans within `box`, or nil if an endpoint
    /// isn't in this table (then the caller falls back to the caret's column).
    private func selectedColumnRange(in box: TableBlockBox) -> ClosedRange<Int>? {
        guard let lo = box.cellLocation(containing: selFrom),
              let hi = box.cellLocation(containing: selTo) else { return nil }
        return min(lo.column, hi.column)...max(lo.column, hi.column)
    }

    func setTableColumnAlignment(_ alignment: TextAlignment) {
        guard let a = activeTable() else { return }
        editing {
            guard case .table(let table) = a.box.currentBlock() else { return }
            let cols = structuralColumnRange() ?? selectedColumnRange(in: a.box) ?? (a.col...a.col)
            var t = table
            for c in cols where t.columns.indices.contains(c) { t = t.settingColumnAlignment(alignment, at: c) }
            replaceTable(at: a.index, with: t, caretRow: a.row, caretCol: a.col)
        }
    }

    /// Creates an empty `rows`×`columns` table (row 0 a header) at the caret, mirroring `insertImage`:
    /// clears any selection, then splits the caret's paragraph if mid-text, else inserts at the block
    /// boundary. No-op unless the caret is in a top-level paragraph (no nested tables; not on an
    /// image/gap) — guarded BEFORE `editing { }` so a no-op registers no undo entry. Caret lands in the
    /// first header cell.
    func insertTable(rows: Int, columns: Int) {
        guard !boxes.isEmpty, !isInsideTable(head),
              let resolved = resolveBox(at: head), resolved.box is BlockBox else { return }
        editing {
            if selFrom != selTo { applySelectionReplace(globalFrom: selFrom, globalTo: selTo, text: "") }
            guard let pos = resolveBox(at: head), let p = pos.box as? BlockBox else { return }
            let tableBox = TableBlockBox(table: TableBlock.empty(rows: rows, columns: columns),
                                         mapper: mapper, width: effectiveWidth)
            var newBoxes = boxes
            if pos.local > 0, pos.local < p.textLength {
                let (upper, lower) = p.currentParagraph().split(at: pos.local, newID: BlockID.generate())
                let upperBox = BlockBox(paragraph: upper, mapper: mapper, width: effectiveWidth)
                let lowerBox = BlockBox(paragraph: lower, mapper: mapper, width: effectiveWidth)
                let replacement: [any CanvasBlock] = [upperBox, tableBox, lowerBox]
                newBoxes.replaceSubrange(pos.index...pos.index, with: replacement)
            } else if pos.local == 0 {
                newBoxes.insert(tableBox, at: pos.index)            // before the caret's block
            } else {
                newBoxes.insert(tableBox, at: pos.index + 1)        // after the caret's block
            }
            boxes = newBoxes
            recomputeSpans()
            if let caret = tableBox.cellTextStart(row: 0, column: 0) { anchor = caret; head = caret }
        }
    }
}
#endif
