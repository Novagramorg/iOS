import Foundation

public enum Block: Equatable {
    case paragraph(ParagraphBlock)
    case media(MediaBlock)
    case table(TableBlock)
    case code(CodeBlock)

    public var id: BlockID {
        switch self {
        case .paragraph(let p): return p.id
        case .media(let m): return m.id
        case .table(let t): return t.id
        case .code(let c): return c.id
        }
    }
}

extension Block: Codable {
    private enum Kind: String, Codable { case paragraph, media, table, code }
    private enum CodingKeys: String, CodingKey { case type, value }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .type) {
        case .paragraph: self = .paragraph(try c.decode(ParagraphBlock.self, forKey: .value))
        case .media:     self = .media(try c.decode(MediaBlock.self, forKey: .value))
        case .table:     self = .table(try c.decode(TableBlock.self, forKey: .value))
        case .code:      self = .code(try c.decode(CodeBlock.self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .paragraph(let p):
            try c.encode(Kind.paragraph, forKey: .type)
            try c.encode(p, forKey: .value)
        case .media(let i):
            try c.encode(Kind.media, forKey: .type)
            try c.encode(i, forKey: .value)
        case .table(let t):
            try c.encode(Kind.table, forKey: .type)
            try c.encode(t, forKey: .value)
        case .code(let code):
            try c.encode(Kind.code, forKey: .type)
            try c.encode(code, forKey: .value)
        }
    }
}
