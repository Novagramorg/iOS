import Foundation

/// Builds a ``Cell``, enforcing the 1023-bit and 4-ref limits as you write.
///
/// Mirrors `@ton/core`'s `Builder`. Mutating methods are `@discardableResult` and
/// return `self` so chains read like the TypeScript they replace.
public final class Builder {
    private var bits = BitBuilder()
    private var refs: [Cell] = []

    public init() {}

    public var bitCount: Int { bits.length }
    public var refCount: Int { refs.count }
    public var availableBits: Int { Cell.maxBits - bits.length }
    public var availableRefs: Int { Cell.maxRefs - refs.count }

    public enum BuilderError: Error, CustomStringConvertible {
        case bitOverflow(needed: Int, available: Int)
        case refOverflow
        case valueTooLarge(bits: Int)
        case stringTooLong(Int)

        public var description: String {
            switch self {
            case .bitOverflow(let needed, let available):
                return "Writing \(needed) bits exceeds the \(available) remaining in this cell"
            case .refOverflow:
                return "Cell already holds 4 references"
            case .valueTooLarge(let bits):
                return "Value does not fit in \(bits) bits"
            case .stringTooLong(let n):
                return "String of \(n) bytes does not fit"
            }
        }
    }

    private func reserve(_ count: Int) throws {
        guard count <= availableBits else {
            throw BuilderError.bitOverflow(needed: count, available: availableBits)
        }
    }

    // MARK: - Bits

    @discardableResult
    public func storeBit(_ value: Bool) throws -> Builder {
        try reserve(1)
        bits.write(bit: value)
        return self
    }

    @discardableResult
    public func storeBits(_ value: BitString) throws -> Builder {
        try reserve(value.length)
        bits.write(value)
        return self
    }

    // MARK: - Integers

    @discardableResult
    public func storeUInt(_ value: UInt64, bits width: Int) throws -> Builder {
        try reserve(width)
        guard width == 64 || value >> UInt64(width) == 0 else {
            throw BuilderError.valueTooLarge(bits: width)
        }
        bits.write(uint: value, bits: width)
        return self
    }

    @discardableResult
    public func storeInt(_ value: Int64, bits width: Int) throws -> Builder {
        try reserve(width)
        bits.write(int: value, bits: width)
        return self
    }

    @discardableResult
    public func storeBigUInt(_ value: BigUInt, bits width: Int) throws -> Builder {
        try reserve(width)
        guard value.bitWidth <= width else { throw BuilderError.valueTooLarge(bits: width) }
        bits.write(bigUInt: value, bits: width)
        return self
    }

    /// `VarUInteger`: a `lengthBits`-wide byte count, then that many bytes.
    @discardableResult
    public func storeVarUInt(_ value: BigUInt, lengthBits: Int) throws -> Builder {
        let byteCount = value.isZero ? 0 : (value.bitWidth + 7) / 8
        try reserve(lengthBits + byteCount * 8)
        bits.write(varUInt: value, lengthBits: lengthBits)
        return self
    }

    /// Nanoton amount: `VarUInteger 16`, i.e. a 4-bit byte-count prefix.
    @discardableResult
    public func storeCoins(_ value: BigUInt) throws -> Builder {
        try storeVarUInt(value, lengthBits: 4)
    }

    // MARK: - Bytes and strings

    @discardableResult
    public func storeBytes(_ value: Data) throws -> Builder {
        try reserve(value.count * 8)
        bits.write(bytes: value)
        return self
    }

    /// Appends UTF-8 bytes inline.
    @discardableResult
    public func storeStringTail(_ value: String) throws -> Builder {
        try storeSnakeBytes(Data(value.utf8))
    }

    /// Writes bytes, spilling into a reference chain when they do not fit.
    ///
    /// The TL-B "snake" layout: fill the current cell, then hand the remainder to a child cell
    /// stored as a reference. Without the spill this throws on any string longer than the
    /// remaining space — which for a user-typed transfer comment is roughly 120 characters, so
    /// an ordinary message would fail to build rather than simply occupying two cells.
    @discardableResult
    public func storeSnakeBytes(_ data: Data) throws -> Builder {
        guard !data.isEmpty else { return self }

        let capacity = availableBits / 8
        guard data.count > capacity else {
            return try storeBytes(data)
        }

        try storeBytes(data.prefix(capacity))
        let continuation = Builder()
        try continuation.storeSnakeBytes(Data(data.dropFirst(capacity)))
        return try storeRef(continuation.endCell())
    }

    /// Stores a string as a chain of refs, 127 bytes per cell — the TL-B "snake"
    /// layout used for text that will not fit inline.
    @discardableResult
    public func storeStringRefTail(_ value: String) throws -> Builder {
        try storeRef(Builder.snakeCell(Data(value.utf8)))
    }

    /// Packs `data` into a chain of cells, 127 bytes each.
    static func snakeCell(_ data: Data) throws -> Cell {
        let chunkSize = 127
        var chunks: [Data] = []
        var index = data.startIndex
        while index < data.endIndex {
            let end = data.index(index, offsetBy: min(chunkSize, data.distance(from: index, to: data.endIndex)))
            chunks.append(Data(data[index..<end]))
            index = end
        }
        if chunks.isEmpty { chunks = [Data()] }

        // Build from the tail so each cell can reference the next.
        var current: Cell?
        for chunk in chunks.reversed() {
            let builder = Builder()
            try builder.storeBytes(chunk)
            if let next = current { try builder.storeRef(next) }
            current = try builder.endCell()
        }
        return current ?? Cell.empty
    }

    // MARK: - Addresses

    /// Stores `addr_std` (or `addr_none` for nil).
    ///
    /// `addr_std$10 anycast:(Maybe Anycast) workchain_id:int8 address:bits256`
    /// — note the workchain is *signed*, so masterchain is `0xFF`.
    @discardableResult
    public func storeAddress(_ address: Address?) throws -> Builder {
        guard let address else {
            // addr_none$00
            return try storeUInt(0, bits: 2)
        }
        try reserve(2 + 1 + 8 + 256)
        try storeUInt(0b10, bits: 2)
        try storeBit(false) // no anycast
        try storeInt(Int64(address.workchain), bits: 8)
        try storeBytes(address.hash)
        return self
    }

    // MARK: - References

    @discardableResult
    public func storeRef(_ cell: Cell) throws -> Builder {
        guard availableRefs > 0 else { throw BuilderError.refOverflow }
        refs.append(cell)
        return self
    }

    @discardableResult
    public func storeRef(_ builder: Builder) throws -> Builder {
        try storeRef(try builder.endCell())
    }

    /// `Maybe ^Cell`: a presence bit followed by the ref when present.
    @discardableResult
    public func storeMaybeRef(_ cell: Cell?) throws -> Builder {
        guard let cell else { return try storeBit(false) }
        try storeBit(true)
        return try storeRef(cell)
    }

    /// Appends a slice's remaining bits and refs inline.
    @discardableResult
    public func storeSlice(_ slice: Slice) throws -> Builder {
        var copy = slice
        try storeBits(copy.loadRemainingBits())
        while copy.remainingRefs > 0 {
            try storeRef(try copy.loadRef())
        }
        return self
    }

    /// Appends a cell's payload and refs inline (not as a reference).
    @discardableResult
    public func storeCellInline(_ cell: Cell) throws -> Builder {
        try storeSlice(cell.beginParse(allowExotic: true))
    }

    // MARK: - Result

    public func endCell(exotic: Bool = false) throws -> Cell {
        try Cell(bits: bits.build(), refs: refs, exotic: exotic)
    }

    /// The cell's payload so far, without finalizing.
    public func buildBits() -> BitString {
        bits.build()
    }
}

/// Starts a new cell, mirroring `@ton/core`'s `beginCell()`.
public func beginCell() -> Builder {
    Builder()
}
