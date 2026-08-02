import Foundation

/// A TVM stack entry, as returned by a get-method.
public indirect enum TupleItem: Hashable, Sendable {
    case int(BigInt)
    case cell(Cell)
    case slice(Cell)
    case builder(Cell)
    case tuple([TupleItem])
    case null
    case nan
}

/// The wire form of a stack entry in Toncenter's `runGetMethod` response.
public enum RawStackItem: Hashable, Sendable {
    case null
    /// Decimal or `0x`-prefixed hex, optionally negative.
    case num(String)
    /// Base64 BoC.
    case cell(String)
    case slice(String)
    case builder(String)
    case tuple([RawStackItem])
    case list([RawStackItem])
}

extension RawStackItem: Codable {
    private enum CodingKeys: String, CodingKey { case type, value }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "null":
            self = .null
        case "num":
            self = .num(try container.decode(String.self, forKey: .value))
        case "cell":
            self = .cell(try container.decode(String.self, forKey: .value))
        case "slice":
            self = .slice(try container.decode(String.self, forKey: .value))
        case "builder":
            self = .builder(try container.decode(String.self, forKey: .value))
        case "tuple":
            self = .tuple(try container.decode([RawStackItem].self, forKey: .value))
        case "list":
            self = .list(try container.decode([RawStackItem].self, forKey: .value))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unsupported stack item type \"\(type)\""
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .null:
            try container.encode("null", forKey: .type)
        case .num(let v):
            try container.encode("num", forKey: .type)
            try container.encode(v, forKey: .value)
        case .cell(let v):
            try container.encode("cell", forKey: .type)
            try container.encode(v, forKey: .value)
        case .slice(let v):
            try container.encode("slice", forKey: .type)
            try container.encode(v, forKey: .value)
        case .builder(let v):
            try container.encode("builder", forKey: .type)
            try container.encode(v, forKey: .value)
        case .tuple(let v):
            try container.encode("tuple", forKey: .type)
            try container.encode(v, forKey: .value)
        case .list(let v):
            try container.encode("list", forKey: .type)
            try container.encode(v, forKey: .value)
        }
    }
}

public enum StackError: Error, CustomStringConvertible {
    case malformedNumber(String)
    case unsupportedItem(String)
    case typeMismatch(expected: String, actual: String)
    case stackExhausted

    public var description: String {
        switch self {
        case .malformedNumber(let s): return "Malformed stack number \"\(s)\""
        case .unsupportedItem(let t): return "Unsupported stack item type \"\(t)\""
        case .typeMismatch(let expected, let actual):
            return "Expected \(expected) on the stack, found \(actual)"
        case .stackExhausted: return "Stack exhausted"
        }
    }
}

/// Converts wire stack entries into `TupleItem`s.
///
/// Note the reference behaviour, preserved here: an **empty** tuple or list becomes
/// `null` rather than an empty tuple.
public func parseStack(_ items: [RawStackItem]) throws -> [TupleItem] {
    try items.map(parseStackItem)
}

func parseStackItem(_ item: RawStackItem) throws -> TupleItem {
    switch item {
    case .null:
        return .null
    case .num(let text):
        return .int(try parseStackNumber(text))
    case .cell(let boc):
        return .cell(try Cell.fromBase64(boc))
    case .slice(let boc):
        return .slice(try Cell.fromBase64(boc))
    case .builder(let boc):
        return .builder(try Cell.fromBase64(boc))
    case .tuple(let items), .list(let items):
        // Empty collapses to null, matching the reference.
        if items.isEmpty { return .null }
        return .tuple(try items.map(parseStackItem))
    }
}

/// Parses a stack number: decimal or `0x` hex, with an optional leading `-`.
func parseStackNumber(_ text: String) throws -> BigInt {
    var body = Substring(text)
    var negative = false
    if body.hasPrefix("-") {
        negative = true
        body = body.dropFirst()
    }

    let magnitude: BigUInt
    if body.hasPrefix("0x") || body.hasPrefix("0X") {
        guard let value = BigUInt(String(body.dropFirst(2)), radix: 16) else {
            throw StackError.malformedNumber(text)
        }
        magnitude = value
    } else {
        guard let value = BigUInt(String(body), radix: 10) else {
            throw StackError.malformedNumber(text)
        }
        magnitude = value
    }

    return negative ? -BigInt(magnitude) : BigInt(magnitude)
}

/// Serializes `TupleItem`s back to the wire form.
///
/// Only the types the reference supports are encodable: `null`, `tuple` and `nan`
/// throw, matching `SerializeStackItem`.
public func serializeStack(_ items: [TupleItem]) throws -> [RawStackItem] {
    try items.map { item in
        switch item {
        case .int(let value):
            let magnitude = value < 0 ? -value : value
            let prefix = value < 0 ? "-" : ""
            return .num("\(prefix)0x\(String(magnitude.magnitude, radix: 16))")
        case .cell(let cell):
            return .cell(cell.toBocBase64())
        case .slice(let cell):
            return .slice(cell.toBocBase64())
        case .builder(let cell):
            return .builder(cell.toBocBase64())
        case .null:
            throw StackError.unsupportedItem("null")
        case .tuple:
            throw StackError.unsupportedItem("tuple")
        case .nan:
            throw StackError.unsupportedItem("nan")
        }
    }
}

/// Sequential reader over a TVM stack, for decoding get-method results.
public struct TupleReader {
    private var items: [TupleItem]

    public init(_ items: [TupleItem]) {
        self.items = items
    }

    public var remaining: Int { items.count }

    private mutating func pop() throws -> TupleItem {
        guard !items.isEmpty else { throw StackError.stackExhausted }
        return items.removeFirst()
    }

    private func typeName(_ item: TupleItem) -> String {
        switch item {
        case .int: return "int"
        case .cell: return "cell"
        case .slice: return "slice"
        case .builder: return "builder"
        case .tuple: return "tuple"
        case .null: return "null"
        case .nan: return "nan"
        }
    }

    public mutating func readBigInt() throws -> BigInt {
        let item = try pop()
        guard case .int(let value) = item else {
            throw StackError.typeMismatch(expected: "int", actual: typeName(item))
        }
        return value
    }

    public mutating func readInt() throws -> Int64 {
        let value = try readBigInt()
        guard let narrowed = Int64(exactly: value) else {
            throw StackError.malformedNumber("\(value) does not fit in Int64")
        }
        return narrowed
    }

    public mutating func readBool() throws -> Bool {
        try readBigInt() != 0
    }

    public mutating func readCell() throws -> Cell {
        let item = try pop()
        switch item {
        case .cell(let cell), .slice(let cell), .builder(let cell):
            return cell
        default:
            throw StackError.typeMismatch(expected: "cell", actual: typeName(item))
        }
    }

    public mutating func readCellOptional() throws -> Cell? {
        let item = try pop()
        switch item {
        case .null: return nil
        case .cell(let cell), .slice(let cell), .builder(let cell): return cell
        default: throw StackError.typeMismatch(expected: "cell or null", actual: typeName(item))
        }
    }

    public mutating func readTuple() throws -> TupleReader {
        let item = try pop()
        guard case .tuple(let nested) = item else {
            throw StackError.typeMismatch(expected: "tuple", actual: typeName(item))
        }
        return TupleReader(nested)
    }

    public mutating func skip(_ count: Int = 1) throws {
        for _ in 0..<count { _ = try pop() }
    }
}
