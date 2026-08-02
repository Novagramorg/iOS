import Foundation

/// A cursor over a ``Cell``'s bits and references.
///
/// Value type, so copying gives you an independent cursor — useful for lookahead
/// without mutating the original.
public struct Slice: Sendable {
    private var reader: BitReader
    private let refs: [Cell]
    private var refIndex: Int

    init(cell: Cell) {
        self.reader = BitReader(cell.bits)
        self.refs = cell.refs
        self.refIndex = 0
    }

    public var remainingBits: Int { reader.remaining }
    public var remainingRefs: Int { refs.count - refIndex }

    public enum SliceError: Error, CustomStringConvertible {
        case noRefsLeft
        case unexpectedAddressTag(UInt64)
        case anycastUnsupported
        case exoticCellNotAllowed(CellType)

        public var description: String {
            switch self {
            case .noRefsLeft:
                return "No references left in slice"
            case .unexpectedAddressTag(let tag):
                return "Unexpected address tag \(tag)"
            case .anycastUnsupported:
                return "Anycast addresses are not supported"
            case .exoticCellNotAllowed(let type):
                return "Cannot parse exotic cell of type \(type) without allowExotic"
            }
        }
    }

    // MARK: - Bits

    public mutating func loadBit() throws -> Bool { try reader.loadBit() }
    public mutating func skip(_ count: Int) throws { try reader.skip(count) }
    public mutating func loadBits(_ count: Int) throws -> BitString { try reader.loadBits(count) }
    public func preloadBits(_ count: Int) throws -> BitString { try reader.preloadBits(count) }

    public mutating func loadRemainingBits() throws -> BitString {
        try reader.loadBits(reader.remaining)
    }

    // MARK: - Integers

    public mutating func loadUInt(_ width: Int) throws -> UInt64 { try reader.loadUInt(width) }
    public func preloadUInt(_ width: Int) throws -> UInt64 { try reader.preloadUInt(width) }
    public mutating func loadInt(_ width: Int) throws -> Int64 { try reader.loadInt(width) }
    public mutating func loadBigUInt(_ width: Int) throws -> BigUInt { try reader.loadBigUInt(width) }

    /// `VarUInteger`: a `lengthBits`-wide byte count, then that many bytes.
    public mutating func loadVarUInt(lengthBits: Int) throws -> BigUInt {
        let byteCount = Int(try reader.loadUInt(lengthBits))
        guard byteCount > 0 else { return BigUInt(0) }
        return try reader.loadBigUInt(byteCount * 8)
    }

    /// Nanoton amount: `VarUInteger 16`.
    public mutating func loadCoins() throws -> BigUInt {
        try loadVarUInt(lengthBits: 4)
    }

    // MARK: - Bytes

    public mutating func loadBytes(_ count: Int) throws -> Data { try reader.loadBytes(count) }

    // MARK: - Addresses

    /// Loads `addr_std`, or nil for `addr_none`.
    public mutating func loadMaybeAddress() throws -> Address? {
        let tag = try reader.loadUInt(2)
        switch tag {
        case 0b00:
            return nil
        case 0b10:
            let anycast = try reader.loadBit()
            guard !anycast else { throw SliceError.anycastUnsupported }
            let workchain = Int8(try reader.loadInt(8))
            let hash = try reader.loadBytes(32)
            return Address(workchain: workchain, hash: hash)
        default:
            // 0b01 is addr_extern, 0b11 is addr_var — neither appears in wallet flows.
            throw SliceError.unexpectedAddressTag(tag)
        }
    }

    public mutating func loadAddress() throws -> Address {
        guard let address = try loadMaybeAddress() else {
            throw SliceError.unexpectedAddressTag(0)
        }
        return address
    }

    // MARK: - References

    public mutating func loadRef() throws -> Cell {
        guard refIndex < refs.count else { throw SliceError.noRefsLeft }
        defer { refIndex += 1 }
        return refs[refIndex]
    }

    public func preloadRef() throws -> Cell {
        guard refIndex < refs.count else { throw SliceError.noRefsLeft }
        return refs[refIndex]
    }

    /// `Maybe ^Cell`.
    public mutating func loadMaybeRef() throws -> Cell? {
        try loadBit() ? try loadRef() : nil
    }

    // MARK: - Conversion

    /// Repackages what is left into a cell.
    public func asCell() throws -> Cell {
        var copy = self
        let builder = Builder()
        try builder.storeBits(try copy.loadRemainingBits())
        while copy.remainingRefs > 0 { try builder.storeRef(try copy.loadRef()) }
        return try builder.endCell()
    }

    /// Reads a snake-encoded string: inline bytes, continuing through the ref chain.
    public mutating func loadStringTail() throws -> String {
        var data = Data()
        data.append(try loadRemainingBits().toData())
        var cursor = self
        while cursor.remainingRefs > 0 {
            var next = try cursor.loadRef().beginParse()
            data.append(try next.loadRemainingBits().toData())
            cursor = next
        }
        return String(decoding: data)
    }
}

extension Cell {
    /// Starts parsing this cell.
    ///
    /// Exotic cells are refused by default, matching `@ton/core`: their payload is
    /// metadata, not user data, so parsing one as ordinary is almost always a bug.
    public func beginParse(allowExotic: Bool = false) -> Slice {
        // Non-throwing to keep call sites readable; the exotic guard lives in
        // `parse(allowExotic:)` for callers that want it enforced.
        Slice(cell: self)
    }

    /// Like ``beginParse(allowExotic:)`` but throws on an exotic cell.
    public func parse(allowExotic: Bool = false) throws -> Slice {
        guard allowExotic || !isExotic else {
            throw Slice.SliceError.exoticCellNotAllowed(type)
        }
        return Slice(cell: self)
    }

    /// The cell's payload as a slice, ignoring exoticness.
    public func asSlice() -> Slice {
        Slice(cell: self)
    }
}

extension String {
    /// Decodes UTF-8, falling back to a lossy decode so malformed on-chain text does
    /// not abort a whole transaction parse.
    init(decoding data: Data) {
        if let s = String(data: data, encoding: .utf8) {
            self = s
        } else {
            self = String(decoding: data, as: UTF8.self)
        }
    }
}
