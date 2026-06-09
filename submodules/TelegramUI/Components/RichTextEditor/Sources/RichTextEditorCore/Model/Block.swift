import Foundation

public enum Block: Equatable {
    case paragraph(ParagraphBlock)
    case image(ImageBlock)
    case table(TableBlock)

    public var id: BlockID {
        switch self {
        case .paragraph(let p): return p.id
        case .image(let i): return i.id
        case .table(let t): return t.id
        }
    }
}

extension Block: Codable {
    private enum Kind: String, Codable { case paragraph, image, table }
    private enum CodingKeys: String, CodingKey { case type, value }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .type) {
        case .paragraph: self = .paragraph(try c.decode(ParagraphBlock.self, forKey: .value))
        case .image:     self = .image(try c.decode(ImageBlock.self, forKey: .value))
        case .table:     self = .table(try c.decode(TableBlock.self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .paragraph(let p):
            try c.encode(Kind.paragraph, forKey: .type)
            try c.encode(p, forKey: .value)
        case .image(let i):
            try c.encode(Kind.image, forKey: .type)
            try c.encode(i, forKey: .value)
        case .table(let t):
            try c.encode(Kind.table, forKey: .type)
            try c.encode(t, forKey: .value)
        }
    }
}
