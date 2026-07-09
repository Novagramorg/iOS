import Foundation

public struct TableRect: Equatable {
    public let top: Int
    public let left: Int
    public let bottom: Int
    public let right: Int
    public init(top: Int, left: Int, bottom: Int, right: Int) {
        self.top = top; self.left = left; self.bottom = bottom; self.right = right
    }
}

/// A row/column map for a table. v1 assumes a regular grid (no merged cells).
public struct TableMap {
    public let tableID: BlockID
    public let rowCount: Int
    public let columnCount: Int

    public init(_ table: TableBlock) {
        tableID = table.id
        rowCount = table.rowCount
        columnCount = table.columnCount
    }

    /// Bounding rectangle (inclusive) of two cell corners.
    public func rectBetween(_ a: CellPath, _ b: CellPath) -> TableRect {
        TableRect(top: min(a.row, b.row), left: min(a.column, b.column),
                  bottom: max(a.row, b.row), right: max(a.column, b.column))
    }

    /// Cells covered by a rectangle, in row-major order.
    public func cellsInRect(_ rect: TableRect) -> [CellPath] {
        var out: [CellPath] = []
        for r in rect.top...rect.bottom {
            for c in rect.left...rect.right {
                out.append(CellPath(tableID: tableID, row: r, column: c))
            }
        }
        return out
    }
}
