import Foundation

/// Sequential reader over a ``BitString``.
public struct BitReader: Sendable {
    private let bits: BitString
    private(set) public var offset: Int

    public init(_ bits: BitString, offset: Int = 0) {
        self.bits = bits
        self.offset = offset
    }

    public var remaining: Int { bits.length - offset }

    public enum ReadError: Error, CustomStringConvertible {
        case outOfBounds(requested: Int, remaining: Int)
        case widthOutOfRange(Int)
        case malformedPadding

        public var description: String {
            switch self {
            case .outOfBounds(let requested, let remaining):
                return "Read of \(requested) bits exceeds \(remaining) remaining"
            case .widthOutOfRange(let bits):
                return "Integer width \(bits) out of range"
            case .malformedPadding:
                return "Padded bits contain no completion tag"
            }
        }
    }

    private func check(_ count: Int) throws {
        guard count >= 0 else { throw ReadError.outOfBounds(requested: count, remaining: remaining) }
        guard count <= remaining else {
            throw ReadError.outOfBounds(requested: count, remaining: remaining)
        }
    }

    // MARK: - Bits

    public mutating func skip(_ count: Int) throws {
        try check(count)
        offset += count
    }

    public mutating func loadBit() throws -> Bool {
        try check(1)
        defer { offset += 1 }
        return bits[offset]
    }

    public mutating func loadBits(_ count: Int) throws -> BitString {
        try check(count)
        defer { offset += count }
        return bits.subrange(offset: offset, length: count)
    }

    public func preloadBits(_ count: Int) throws -> BitString {
        try check(count)
        return bits.subrange(offset: offset, length: count)
    }

    /// Reads `count` bits, then strips the TL-B completion tag: everything after the
    /// final set bit is padding, and that bit itself is the tag.
    public mutating func loadPaddedBits(_ count: Int) throws -> BitString {
        try check(count)
        precondition(count % 8 == 0, "Padded reads must be byte-aligned")
        let raw = bits.subrange(offset: offset, length: count)
        offset += count

        let bytes = raw.toData()
        var bitLength = 0
        var found = false
        for index in stride(from: bytes.count - 1, through: 0, by: -1) {
            let byte = bytes[index]
            if byte != 0 {
                // Position of the lowest set bit is where the padding begins.
                bitLength = index * 8 + (7 - byte.trailingZeroBitCount)
                found = true
                break
            }
        }
        // An all-zero buffer means every bit was padding, i.e. an empty payload.
        guard found || bytes.allSatisfy({ $0 == 0 }) else { throw ReadError.malformedPadding }
        return raw.prefix(bitLength)
    }

    // MARK: - Integers

    public mutating func loadUInt(_ width: Int) throws -> UInt64 {
        guard width >= 0 && width <= 64 else { throw ReadError.widthOutOfRange(width) }
        try check(width)
        var value: UInt64 = 0
        for _ in 0..<width {
            value = (value << 1) | (bits[offset] ? 1 : 0)
            offset += 1
        }
        return value
    }

    public func preloadUInt(_ width: Int) throws -> UInt64 {
        var copy = self
        return try copy.loadUInt(width)
    }

    public mutating func loadInt(_ width: Int) throws -> Int64 {
        guard width >= 1 && width <= 64 else { throw ReadError.widthOutOfRange(width) }
        let raw = try loadUInt(width)
        if width == 64 { return Int64(bitPattern: raw) }
        // Sign-extend from the width's top bit.
        let signBit = UInt64(1) << UInt64(width - 1)
        if raw & signBit != 0 {
            return Int64(bitPattern: raw | ~((UInt64(1) << UInt64(width)) - 1))
        }
        return Int64(raw)
    }

    public mutating func loadBigUInt(_ width: Int) throws -> BigUInt {
        try check(width)
        var value = BigUInt(0)
        for _ in 0..<width {
            value <<= 1
            if bits[offset] { value |= 1 }
            offset += 1
        }
        return value
    }

    // MARK: - Bytes

    public mutating func loadBytes(_ count: Int) throws -> Data {
        try check(count * 8)
        let slice = bits.subrange(offset: offset, length: count * 8)
        offset += count * 8
        return slice.toData()
    }
}
