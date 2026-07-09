import Foundation

public struct ColumnSpec: Codable, Equatable {
    public var width: Double
    public init(width: Double) { self.width = width }
}

/// A table cell. In v1 cells contain paragraph and media blocks (no nested tables). `horizontalAlignment`
/// / `verticalAlignment` are per-cell render overrides applied to the cell's paragraphs (not stored on them).
public struct Cell: Codable, Equatable {
    public var id: BlockID
    public var blocks: [Block]
    public var background: RGBAColor?
    public var horizontalAlignment: TextAlignment
    public var verticalAlignment: VerticalAlignment

    public init(id: BlockID, blocks: [Block] = [], background: RGBAColor? = nil,
                horizontalAlignment: TextAlignment = .center, verticalAlignment: VerticalAlignment = .top) {
        self.id = id
        self.blocks = blocks
        self.background = background
        self.horizontalAlignment = horizontalAlignment
        self.verticalAlignment = verticalAlignment
    }

    private enum CodingKeys: String, CodingKey { case id, blocks, background, horizontalAlignment, verticalAlignment }

    // Custom decode so cells written before the alignment fields existed still load (defaults applied).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(BlockID.self, forKey: .id)
        blocks = try c.decodeIfPresent([Block].self, forKey: .blocks) ?? []
        background = try c.decodeIfPresent(RGBAColor.self, forKey: .background)
        horizontalAlignment = try c.decodeIfPresent(TextAlignment.self, forKey: .horizontalAlignment) ?? .center
        verticalAlignment = try c.decodeIfPresent(VerticalAlignment.self, forKey: .verticalAlignment) ?? .top
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
