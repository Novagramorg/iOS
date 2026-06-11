import Foundation

public struct ColumnSpec: Codable, Equatable {
    public var width: Double
    /// Per-column text alignment (markdown's delimiter-row colons). Applied as a render override to
    /// every cell in the column; never stored on the cells themselves.
    public var alignment: TextAlignment

    public init(width: Double, alignment: TextAlignment = .left) {
        self.width = width
        self.alignment = alignment
    }

    private enum CodingKeys: String, CodingKey { case width, alignment }

    // Custom decode so documents written before `alignment` existed still load (synthesized Codable
    // would throw on the missing key). Encoding stays synthesized via the declared CodingKeys.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        width = try c.decode(Double.self, forKey: .width)
        alignment = try c.decodeIfPresent(TextAlignment.self, forKey: .alignment) ?? .left
    }
}

/// A table cell. In v1 cells contain paragraph and image blocks (no nested tables).
public struct Cell: Codable, Equatable {
    public var id: BlockID
    public var blocks: [Block]
    public var background: RGBAColor?

    public init(id: BlockID, blocks: [Block] = [], background: RGBAColor? = nil) {
        self.id = id
        self.blocks = blocks
        self.background = background
    }
}

public struct Row: Codable, Equatable {
    public var id: BlockID
    public var height: Double?
    public var isHeader: Bool
    public var cells: [Cell]

    public init(id: BlockID, height: Double? = nil, isHeader: Bool = false, cells: [Cell] = []) {
        self.id = id
        self.height = height
        self.isHeader = isHeader
        self.cells = cells
    }
}

public struct TableBlock: Codable, Equatable {
    public var id: BlockID
    public var columns: [ColumnSpec]
    public var rows: [Row]

    public init(id: BlockID, columns: [ColumnSpec] = [], rows: [Row] = []) {
        self.id = id
        self.columns = columns
        self.rows = rows
    }

    public var columnCount: Int { columns.count }
    public var rowCount: Int { rows.count }
}
