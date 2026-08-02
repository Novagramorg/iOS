import Foundation

/// TL-B `HashmapE`: a patricia trie keyed by fixed-width bit strings.
///
/// Ported from `@ton/core`'s `serializeDict`/`parseDict`. Label encoding has three
/// forms (short, long, same) and the writer picks whichever is shortest, so a
/// divergence here changes the cell hash without changing the logical contents.
public struct TONDictionary<Key: DictionaryKeyCoder, Value: DictionaryValueCoder> {
    /// Entries keyed by the raw integer form of the key.
    private var storage: [BigUInt: Value.Value] = [:]
    private let keyCoder: Key
    private let valueCoder: Value

    public init(key: Key, value: Value) {
        self.keyCoder = key
        self.valueCoder = value
    }

    public var count: Int { storage.count }
    public var isEmpty: Bool { storage.isEmpty }

    public enum DictionaryError: Error, CustomStringConvertible {
        case keyOutOfRange(BigUInt, keyBits: Int)
        case emptySubtree
        case labelTooLong(Int, keyBits: Int)
        case malformed(String)

        public var description: String {
            switch self {
            case .keyOutOfRange(let k, let bits): return "Key \(k) does not fit in \(bits) bits"
            case .emptySubtree: return "Internal inconsistency: empty dictionary subtree"
            case .labelTooLong(let n, let bits): return "Label of \(n) bits exceeds key width \(bits)"
            case .malformed(let m): return "Malformed dictionary: \(m)"
            }
        }
    }

    // MARK: - Access

    public mutating func set(_ key: Key.Key, _ value: Value.Value) throws {
        let raw = try keyCoder.encode(key)
        guard raw.bitWidth <= keyCoder.bits else {
            throw DictionaryError.keyOutOfRange(raw, keyBits: keyCoder.bits)
        }
        storage[raw] = value
    }

    public func get(_ key: Key.Key) throws -> Value.Value? {
        storage[try keyCoder.encode(key)]
    }

    public mutating func remove(_ key: Key.Key) throws {
        storage.removeValue(forKey: try keyCoder.encode(key))
    }

    /// Keys in ascending raw order, which is also serialization order.
    public func keys() throws -> [Key.Key] {
        try storage.keys.sorted().map { try keyCoder.decode($0) }
    }

    public var rawKeys: [BigUInt] { storage.keys.sorted() }

    // MARK: - Serialization

    /// Writes `HashmapE`: a presence bit, then the root as a ref when non-empty.
    public func store(into builder: Builder) throws {
        guard !isEmpty else {
            try builder.storeBit(false)
            return
        }
        try builder.storeBit(true)
        try builder.storeRef(try rootCell())
    }

    /// Writes the trie directly, without the `HashmapE` presence bit.
    ///
    /// This is `storeDictDirect`: used where the schema embeds a `Hashmap` rather
    /// than a `HashmapE`.
    public func storeDirect(into builder: Builder) throws {
        guard !isEmpty else { throw DictionaryError.emptySubtree }
        let root = try rootCell()
        try builder.storeCellInline(root)
    }

    private func rootCell() throws -> Cell {
        // Keys as fixed-width bit strings, which is what the trie is built over.
        var converted: [(key: [Bool], value: Value.Value)] = []
        for raw in storage.keys.sorted() {
            converted.append((bitPattern(raw, width: keyCoder.bits), storage[raw]!))
        }
        let tree = try buildEdge(converted, prefixLength: 0)
        let builder = Builder()
        try writeEdge(tree, keyBits: keyCoder.bits, into: builder)
        return try builder.endCell()
    }

    private func bitPattern(_ value: BigUInt, width: Int) -> [Bool] {
        (0..<width).reversed().map { value.bit(at: $0) }
    }

    // MARK: - Trie construction

    private indirect enum Node {
        case leaf(Value.Value)
        case fork(left: Edge, right: Edge)
    }

    private struct Edge {
        let label: [Bool]
        let node: Node
    }

    private func buildEdge(
        _ entries: [(key: [Bool], value: Value.Value)],
        prefixLength: Int
    ) throws -> Edge {
        guard !entries.isEmpty else { throw DictionaryError.emptySubtree }
        let label = commonPrefix(entries.map(\.key), from: prefixLength)
        let node = try buildNode(entries, prefixLength: prefixLength + label.count)
        return Edge(label: label, node: node)
    }

    private func buildNode(
        _ entries: [(key: [Bool], value: Value.Value)],
        prefixLength: Int
    ) throws -> Node {
        guard !entries.isEmpty else { throw DictionaryError.emptySubtree }
        if entries.count == 1 { return .leaf(entries[0].value) }

        var left: [(key: [Bool], value: Value.Value)] = []
        var right: [(key: [Bool], value: Value.Value)] = []
        for entry in entries {
            if entry.key[prefixLength] { right.append(entry) } else { left.append(entry) }
        }
        guard !left.isEmpty, !right.isEmpty else {
            throw DictionaryError.malformed("fork with an empty side at bit \(prefixLength)")
        }
        return .fork(
            left: try buildEdge(left, prefixLength: prefixLength + 1),
            right: try buildEdge(right, prefixLength: prefixLength + 1)
        )
    }

    /// Longest shared run of bits across all keys, starting at `from`.
    private func commonPrefix(_ keys: [[Bool]], from: Int) -> [Bool] {
        guard let first = keys.first else { return [] }
        var length = first.count - from
        for key in keys.dropFirst() {
            var shared = 0
            while shared < length && from + shared < key.count && key[from + shared] == first[from + shared] {
                shared += 1
            }
            length = shared
            if length == 0 { break }
        }
        return Array(first[from..<(from + length)])
    }

    // MARK: - Label encoding

    private enum LabelKind { case short, long, same }

    /// Bits needed for a label length field: `ceil(log2(keyBits + 1))`.
    static func lengthFieldWidth(keyBits: Int) -> Int {
        guard keyBits > 0 else { return 0 }
        // ceil(log2(n+1)) == bit width of n
        return Int.bitWidth - (keyBits).leadingZeroBitCount
    }

    private func detectLabelKind(_ label: [Bool], keyBits: Int) -> LabelKind {
        // hml_short: 1 tag bit + unary length + terminator + the bits themselves
        var bestLength = 1 + label.count + 1 + label.count
        var best = LabelKind.short

        // hml_long: 2 tag bits + length field + the bits
        let longLength = 1 + 1 + Self.lengthFieldWidth(keyBits: keyBits) + label.count
        if longLength < bestLength {
            bestLength = longLength
            best = .long
        }

        // hml_same: 3 tag bits + length field, only when every bit is identical
        let allSame = label.count <= 1 || label.allSatisfy { $0 == label[0] }
        if allSame {
            let sameLength = 1 + 1 + 1 + Self.lengthFieldWidth(keyBits: keyBits)
            if sameLength < bestLength {
                best = .same
            }
        }

        return best
    }

    private func writeLabel(_ label: [Bool], keyBits: Int, into builder: Builder) throws {
        switch detectLabelKind(label, keyBits: keyBits) {
        case .short:
            try builder.storeBit(false)
            for _ in 0..<label.count { try builder.storeBit(true) }
            try builder.storeBit(false)
            for bit in label { try builder.storeBit(bit) }
        case .long:
            try builder.storeBit(true)
            try builder.storeBit(false)
            try builder.storeUInt(
                UInt64(label.count),
                bits: Self.lengthFieldWidth(keyBits: keyBits)
            )
            for bit in label { try builder.storeBit(bit) }
        case .same:
            try builder.storeBit(true)
            try builder.storeBit(true)
            try builder.storeBit(label.first ?? false)
            try builder.storeUInt(
                UInt64(label.count),
                bits: Self.lengthFieldWidth(keyBits: keyBits)
            )
        }
    }

    private func writeEdge(_ edge: Edge, keyBits: Int, into builder: Builder) throws {
        try writeLabel(edge.label, keyBits: keyBits, into: builder)
        try writeNode(edge.node, keyBits: keyBits - edge.label.count, into: builder)
    }

    private func writeNode(_ node: Node, keyBits: Int, into builder: Builder) throws {
        switch node {
        case .leaf(let value):
            try valueCoder.store(value, into: builder)
        case .fork(let left, let right):
            let leftBuilder = Builder()
            let rightBuilder = Builder()
            try writeEdge(left, keyBits: keyBits - 1, into: leftBuilder)
            try writeEdge(right, keyBits: keyBits - 1, into: rightBuilder)
            try builder.storeRef(try leftBuilder.endCell())
            try builder.storeRef(try rightBuilder.endCell())
        }
    }

    // MARK: - Deserialization

    /// Reads `HashmapE` from a slice: a presence bit, then the root ref.
    public static func load(
        key: Key,
        value: Value,
        from slice: inout Slice
    ) throws -> TONDictionary<Key, Value> {
        var dict = TONDictionary(key: key, value: value)
        guard try slice.loadBit() else { return dict }
        let root = try slice.loadRef()
        var rootSlice = root.asSlice()
        try dict.parse(&rootSlice, prefix: [], remainingBits: key.bits)
        return dict
    }

    /// Reads a bare `Hashmap` (no presence bit) from a slice.
    public static func loadDirect(
        key: Key,
        value: Value,
        from slice: inout Slice
    ) throws -> TONDictionary<Key, Value> {
        var dict = TONDictionary(key: key, value: value)
        try dict.parse(&slice, prefix: [], remainingBits: key.bits)
        return dict
    }

    private mutating func parse(_ slice: inout Slice, prefix: [Bool], remainingBits: Int) throws {
        var pp = prefix
        var labelLength = 0

        if try slice.loadBit() == false {
            // hml_short: unary length, then the bits.
            while try slice.loadBit() { labelLength += 1 }
            for _ in 0..<labelLength { pp.append(try slice.loadBit()) }
        } else if try slice.loadBit() == false {
            // hml_long: explicit length, then the bits.
            labelLength = Int(try slice.loadUInt(Self.lengthFieldWidth(keyBits: remainingBits)))
            for _ in 0..<labelLength { pp.append(try slice.loadBit()) }
        } else {
            // hml_same: one repeated bit.
            let bit = try slice.loadBit()
            labelLength = Int(try slice.loadUInt(Self.lengthFieldWidth(keyBits: remainingBits)))
            for _ in 0..<labelLength { pp.append(bit) }
        }

        guard labelLength <= remainingBits else {
            throw DictionaryError.labelTooLong(labelLength, keyBits: remainingBits)
        }

        if remainingBits - labelLength == 0 {
            var raw = BigUInt(0)
            for bit in pp {
                raw <<= 1
                if bit { raw |= 1 }
            }
            storage[raw] = try valueCoder.load(from: &slice)
            return
        }

        let left = try slice.loadRef()
        let right = try slice.loadRef()
        // Pruned children appear in merkle proofs; skip rather than fail, matching
        // the reference, so a partial proof still yields the keys it does carry.
        if !left.isExotic {
            var s = left.asSlice()
            try parse(&s, prefix: pp + [false], remainingBits: remainingBits - labelLength - 1)
        }
        if !right.isExotic {
            var s = right.asSlice()
            try parse(&s, prefix: pp + [true], remainingBits: remainingBits - labelLength - 1)
        }
    }
}

// MARK: - Key coders

public protocol DictionaryKeyCoder {
    associatedtype Key: Hashable
    /// Fixed key width in bits.
    var bits: Int { get }
    func encode(_ key: Key) throws -> BigUInt
    func decode(_ raw: BigUInt) throws -> Key
}

public struct UIntKey: DictionaryKeyCoder {
    public typealias Key = UInt64
    public let bits: Int
    public init(bits: Int) { self.bits = bits }
    public func encode(_ key: UInt64) throws -> BigUInt { BigUInt(key) }
    public func decode(_ raw: BigUInt) throws -> UInt64 { UInt64(raw) }
}

public struct BigUIntKey: DictionaryKeyCoder {
    public typealias Key = BigUInt
    public let bits: Int
    public init(bits: Int) { self.bits = bits }
    public func encode(_ key: BigUInt) throws -> BigUInt { key }
    public func decode(_ raw: BigUInt) throws -> BigUInt { raw }
}

/// Address-keyed dictionaries key on the **whole serialized `addr_std`**, not just the
/// account hash: 2 tag bits + 1 anycast bit + 8 workchain bits + 256 hash bits = 267.
///
/// Keying on the hash alone would collide across workchains and produce different cell
/// hashes from the reference.
public struct AddressKey: DictionaryKeyCoder {
    public typealias Key = Address
    public let bits = 267

    public init() {}

    public func encode(_ key: Address) throws -> BigUInt {
        var slice = try beginCell().storeAddress(key).endCell().beginParse()
        return try slice.loadBigUInt(bits)
    }

    public func decode(_ raw: BigUInt) throws -> Address {
        var slice = try beginCell().storeBigUInt(raw, bits: bits).endCell().beginParse()
        return try slice.loadAddress()
    }
}

// MARK: - Value coders

public protocol DictionaryValueCoder {
    associatedtype Value
    func store(_ value: Value, into builder: Builder) throws
    func load(from slice: inout Slice) throws -> Value
}

/// Values stored as a reference to a whole cell.
public struct CellValue: DictionaryValueCoder {
    public typealias Value = Cell
    public init() {}
    public func store(_ value: Cell, into builder: Builder) throws {
        try builder.storeRef(value)
    }
    public func load(from slice: inout Slice) throws -> Cell {
        try slice.loadRef()
    }
}

/// Values stored inline as the remaining slice, repackaged into a cell.
public struct SliceValue: DictionaryValueCoder {
    public typealias Value = Cell
    public init() {}
    public func store(_ value: Cell, into builder: Builder) throws {
        try builder.storeCellInline(value)
    }
    public func load(from slice: inout Slice) throws -> Cell {
        try slice.asCell()
    }
}

public struct BigUIntValue: DictionaryValueCoder {
    public typealias Value = BigUInt
    public let bits: Int
    public init(bits: Int) { self.bits = bits }
    public func store(_ value: BigUInt, into builder: Builder) throws {
        try builder.storeBigUInt(value, bits: bits)
    }
    public func load(from slice: inout Slice) throws -> BigUInt {
        try slice.loadBigUInt(bits)
    }
}

/// Signed values. `BigIntValue(bits: 1)` is the V5R1 extensions-dictionary shape,
/// where the only stored value is `-1`.
public struct BigIntValue: DictionaryValueCoder {
    public typealias Value = BigInt
    public let bits: Int
    public init(bits: Int) { self.bits = bits }

    public func store(_ value: BigInt, into builder: Builder) throws {
        // Two's complement, most significant bit first.
        var bitsOut: [Bool] = []
        for i in (0..<bits).reversed() {
            bitsOut.append(value.twosComplementBit(at: i, width: bits))
        }
        for bit in bitsOut { try builder.storeBit(bit) }
    }

    public func load(from slice: inout Slice) throws -> BigInt {
        guard bits <= 64 else {
            // Wider signed values do not occur in the schemas we handle.
            throw TONDictionary<UIntKey, BigIntValue>.DictionaryError
                .malformed("signed values wider than 64 bits are unsupported")
        }
        return BigInt(try slice.loadInt(bits))
    }
}
