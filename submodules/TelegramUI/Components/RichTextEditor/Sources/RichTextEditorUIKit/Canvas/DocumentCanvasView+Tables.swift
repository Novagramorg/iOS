#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// Table structural commands. Each takes the live table via `currentBlock()`, applies a pure
/// `TableBlock` transform (Core), and rebuilds the one `TableBlockBox` inside `editing { }` so undo
/// is the existing whole-document `[Block]` snapshot. The structural commands below no-op when the
/// caret isn't in a table; `insertTable` is the inverse — it no-ops when the caret IS in a table (or
/// on an image/gap).
@available(iOS 13.0, *)
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
            let new = table.insertingColumn(at: range.lowerBound, width: defaultNewColumnWidth(table))
            replaceTable(at: a.index, with: new, caretRow: a.row, caretCol: range.lowerBound)
        }
    }

    func insertTableColumnRight() {
        guard let a = activeTable() else { return }
        editing {
            guard case .table(let table) = a.box.currentBlock() else { return }
            let range = structuralColumnRange() ?? (a.col...a.col)
            let at = range.upperBound + 1
            let new = table.insertingColumn(at: at, width: defaultNewColumnWidth(table))
            replaceTable(at: a.index, with: new, caretRow: a.row, caretCol: at)
        }
    }

    /// Removes the table the caret is in (one undo step). The caret lands at the start of the block that
    /// took the table's place — the block after it, or the previous block if the table was last, or a fresh
    /// empty paragraph if the table was the document's only block. No-op when the caret isn't in a table.
    func deleteTable() {
        guard let a = activeTable() else { return }
        editing {
            var nb = boxes
            nb.remove(at: a.index)
            if nb.isEmpty {
                nb.append(BlockBox(paragraph: ParagraphBlock(id: BlockID.generate()), mapper: mapper, width: effectiveWidth))
            }
            boxes = nb
            recomputeSpans()
            let targetIndex = min(a.index, boxes.count - 1)
            let caret = snapToRenderable(boxes[targetIndex].textStart, forward: true)
            anchor = caret; head = caret
        }
    }

    /// Copies the caret's current table to the pasteboard as if it were a document containing ONLY that table:
    /// the app fragment (JSON — pastes back as a real table), an RTF table, and a plain-text flatten (one line
    /// per row, cells space-joined). No-op when the caret isn't in a table.
    func copyCurrentTable() {
        guard let a = activeTable() else { return }
        let model = currentBlocks()
        guard model.indices.contains(a.index), case .table(let table) = model[a.index] else { return }
        let document = Document(blocks: [.table(table)])
        let plain = tableFlattenedText(table).joined(separator: "\n")
        pasteboard.setItems([RichTextEditorClipboard.pasteboardItem(for: document, plain: plain)], options: [:])
    }

    /// Replaces the caret's current table IN PLACE with body paragraphs — one per row, the row's cells joined
    /// by " " (see `tableFlattenedText`). One undo step; the caret lands at the start of the first paragraph.
    /// No-op when the caret isn't in a table.
    func convertCurrentTableToText() {
        guard let a = activeTable() else { return }
        let model = currentBlocks()
        guard model.indices.contains(a.index), case .table(let table) = model[a.index] else { return }
        editing {
            var replacement: [CanvasBlock] = tableFlattenedText(table).map { line in
                BlockBox(paragraph: ParagraphBlock(id: BlockID.generate(), style: .body,
                                                   runs: line.isEmpty ? [] : [TextRun(text: line)]),
                         mapper: mapper, width: effectiveWidth)
            }
            if replacement.isEmpty {
                replacement = [BlockBox(paragraph: ParagraphBlock(id: BlockID.generate()), mapper: mapper, width: effectiveWidth)]
            }
            var nb = boxes
            nb.replaceSubrange(a.index...a.index, with: replacement)
            boxes = nb
            recomputeSpans()
            let caret = snapToRenderable(boxes[a.index].textStart, forward: true)
            anchor = caret; head = caret
        }
    }

    /// Backspace with a table structural (row/column) selection active. Deletes the selected rows or
    /// columns (via the existing `deleteTableRow`/`deleteTableColumn`, which read the structural range).
    /// When the selection covers EVERY row or EVERY column — which would empty the table — it removes the
    /// whole table block instead, replacing it IN PLACE with an empty body paragraph (caret there). The
    /// structural selection is cleared afterward (mirrors the structural menu's run-then-clear-selection
    /// behavior). No-op-safe when there is no live structural selection.
    func deleteTableStructuralSelection() {
        guard let sel = tableSelection, let a = activeTable(), a.box.id == sel.table else {
            clearTableSelection(); return
        }
        let coversWholeTable: Bool
        switch sel.kind {
        case .rows(let range):    coversWholeTable = range.lowerBound <= 0 && range.upperBound >= a.box.rowCount - 1
        case .columns(let range): coversWholeTable = range.lowerBound <= 0 && range.upperBound >= a.box.columnCount - 1
        }
        if coversWholeTable {
            editing {
                let para = BlockBox(paragraph: ParagraphBlock(id: BlockID.generate(), style: .body, runs: []),
                                    mapper: mapper, width: effectiveWidth)
                var nb = boxes
                nb[a.index] = para
                boxes = nb
                recomputeSpans()
                anchor = para.textStart; head = para.textStart
            }
        } else {
            switch sel.kind {
            case .rows:    deleteTableRow()      // reads structuralRowRange(); self-wraps in editing { }
            case .columns: deleteTableColumn()   // reads structuralColumnRange()
            }
        }
        clearTableSelection()
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

    /// The cells covered by the current structural selection (a row-range's cells, or a column-range's cells),
    /// as (row, column) coords in `box`. Falls back to the caret's single cell when no structural selection.
    func selectedCellCoords(in box: TableBlockBox) -> [(row: Int, column: Int)] {
        let rowCount = box.rowCount, colCount = box.columnCount
        if let rows = structuralRowRange() {
            return rows.filter { (0..<rowCount).contains($0) }.flatMap { r in (0..<colCount).map { (r, $0) } }
        }
        if let cols = structuralColumnRange() {
            return cols.filter { (0..<colCount).contains($0) }.flatMap { c in (0..<rowCount).map { ($0, c) } }
        }
        if let a = activeTable(), a.box.id == box.id { return [(a.row, a.col)] }
        return []
    }

    func setSelectionHorizontalAlignment(_ alignment: TextAlignment) {
        setSelectionAlignment(horizontal: alignment, vertical: nil)
    }
    func setSelectionVerticalAlignment(_ alignment: VerticalAlignment) {
        setSelectionAlignment(horizontal: nil, vertical: alignment)
    }

    /// Sets horizontal and/or vertical alignment on every cell of the current structural selection. A nil axis
    /// is left unchanged (partial apply — the "mixed" case). One undo step; preserves the structural selection.
    /// Internal (NOT private): the descriptor builder in `+TableControls.swift` calls it, and Swift `private`
    /// is file-scoped.
    func setSelectionAlignment(horizontal: TextAlignment?, vertical: VerticalAlignment?) {
        guard let a = activeTable(), horizontal != nil || vertical != nil else { return }
        editing {
            guard case .table(var t) = a.box.currentBlock() else { return }
            for (r, c) in selectedCellCoords(in: a.box) where t.rows.indices.contains(r) && t.rows[r].cells.indices.contains(c) {
                if let h = horizontal { t.rows[r].cells[c].horizontalAlignment = h }
                if let v = vertical { t.rows[r].cells[c].verticalAlignment = v }
            }
            replaceTable(at: a.index, with: t, caretRow: a.row, caretCol: a.col)
        }
    }

    /// Creates an empty `rows`×`columns` table (row 0 a header) at the caret, mirroring `insertMedia`:
    /// clears any selection, then splits the caret's paragraph if mid-text, else inserts at the block
    /// boundary. No-op unless the caret is in a top-level paragraph (no nested tables; not on an
    /// image/gap) — guarded BEFORE `editing { }` so a no-op registers no undo entry. Caret lands in the
    /// first header cell.
    func insertTable(rows: Int, columns: Int) {
        // `!isInsideBlockQuote(head)` is load-bearing: a caret inside a quote has no degenerate-container-safe
        // resolveBox, so `resolveBox(at: head)` below mis-resolves to the FOLLOWING top-level block and the table
        // would be inserted there. Tables aren't supported inside quotes (v1) → no-op, like the in-table guard.
        guard !boxes.isEmpty, !isInsideTable(head), !isInsideBlockQuote(head),
              let resolved = resolveBox(at: head), resolved.box is BlockBox else { return }
        editing {
            if selFrom != selTo { applySelectionReplace(globalFrom: selFrom, globalTo: selTo, text: "") }
            guard let pos = resolveBox(at: head), let p = pos.box as? BlockBox else { return }
            let tableBox = TableBlockBox(table: TableBlock.empty(rows: rows, columns: columns),
                                         mapper: mapper, width: effectiveWidth)
            var newBoxes = boxes
            if p.textLength == 0 {
                newBoxes.replaceSubrange(pos.index...pos.index, with: [tableBox])   // empty paragraph → replace it
            } else if pos.local > 0, pos.local < p.textLength {
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
