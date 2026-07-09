import Foundation

/// Pure structural transforms on a `TableBlock`. Each returns a new value that preserves the grid
/// invariant (`columnCount` == every row's `cells.count`), generates fresh `BlockID`s for new
/// rows/cells, and gives each new cell one empty paragraph. New rows are body rows. The UIKit
/// command layer applies these then rebuilds the `TableBlockBox`.
extension TableBlock {
    /// A fresh body row of `n` empty single-paragraph cells.
    private static func emptyRow(columnCount n: Int) -> Row {
        Row(id: BlockID.generate(), isHeader: false,
            cells: (0..<max(n, 1)).map { _ in TableBlock.emptyCell() })
    }

    private static func emptyCell() -> Cell {
        Cell(id: BlockID.generate(), blocks: [.paragraph(ParagraphBlock(id: BlockID.generate()))])
    }

    /// A fresh empty table: `rows`×`columns` (each clamped to ≥1), row 0 a mandatory header, the rest
    /// body rows, every cell one empty paragraph, equal column widths. The insert-table command builds
    /// this then wraps it in a `TableBlockBox`.
    public static func empty(rows: Int, columns: Int) -> TableBlock {
        let nCols = max(columns, 1)
        let nRows = max(rows, 1)
        let cols = (0..<nCols).map { _ in ColumnSpec(width: 100) }
        let rowsArr: [Row] = (0..<nRows).map { r in
            Row(id: BlockID.generate(), isHeader: r == 0,
                cells: (0..<nCols).map { _ in TableBlock.emptyCell() })
        }
        return TableBlock(id: BlockID.generate(), columns: cols, rows: rowsArr)
    }

    public func insertingRow(at index: Int) -> TableBlock {
        var t = self
        let i = min(max(index, 0), t.rows.count)
        t.rows.insert(TableBlock.emptyRow(columnCount: columnCount), at: i)
        return t
    }

    public func removingRow(at index: Int) -> TableBlock {
        guard rows.indices.contains(index) else { return self }
        var t = self
        t.rows.remove(at: index)
        return t
    }

    public func insertingColumn(at index: Int, width: Double) -> TableBlock {
        var t = self
        let ci = min(max(index, 0), t.columns.count)
        t.columns.insert(ColumnSpec(width: width), at: ci)
        for r in t.rows.indices {
            let i = min(max(index, 0), t.rows[r].cells.count)
            t.rows[r].cells.insert(TableBlock.emptyCell(), at: i)
        }
        return t
    }

    public func removingColumn(at index: Int) -> TableBlock {
        guard columns.indices.contains(index) else { return self }
        var t = self
        t.columns.remove(at: index)
        for r in t.rows.indices where t.rows[r].cells.indices.contains(index) {
            t.rows[r].cells.remove(at: index)
        }
        return t
    }

    /// Removes every **body** row in `range` (header rows are skipped — never removed). Removes
    /// high-index → low so earlier indices don't shift. A no-op if no body row is covered.
    public func removingRows(in range: ClosedRange<Int>) -> TableBlock {
        var t = self
        let victims = range.filter { t.rows.indices.contains($0) && !t.rows[$0].isHeader }.sorted(by: >)
        for i in victims { t.rows.remove(at: i) }
        return t
    }

    /// Removes every column in `range`, high-index → low. Always leaves at least one column (a table
    /// with no columns is invalid); if `range` would empty the table the lowest-indexed covered column is kept.
    public func removingColumns(in range: ClosedRange<Int>) -> TableBlock {
        var t = self
        let victims = range.filter { t.columns.indices.contains($0) }.sorted(by: >)
        for i in victims {
            guard t.columns.count > 1 else { break }
            t = t.removingColumn(at: i)
        }
        return t
    }
}
