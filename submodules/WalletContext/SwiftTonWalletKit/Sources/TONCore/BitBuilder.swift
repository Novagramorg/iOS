import Foundation

/// Accumulates bits into a ``BitString``.
///
/// Unbounded by default; ``Builder`` enforces the 1023-bit cell limit on top.
public struct BitBuilder: Sendable {
    private var buffer: Data
    private(set) public var length: Int

    public init(capacity: Int = 1023) {
        buffer = Data(repeating: 0, count: (max(capacity, 0) + 7) / 8)
        length = 0
    }

    public var isEmpty: Bool { length == 0 }

    private mutating func ensure(_ additionalBits: Int) {
        let needed = (length + additionalBits + 7) / 8
        if buffer.count < needed {
            buffer.append(Data(repeating: 0, count: needed - buffer.count))
        }
    }

    // MARK: - Bits

    public mutating func write(bit: Bool) {
        ensure(1)
        if bit {
            buffer[length / 8] |= 1 << (7 - UInt8(length % 8))
        }
        length += 1
    }

    public mutating func write(bits: [Bool]) {
        ensure(bits.count)
        for b in bits { write(bit: b) }
    }

    /// Appends another bit string. Uses a byte-wise copy when both sides are aligned.
    public mutating func write(_ other: BitString) {
        guard other.length > 0 else { return }
        ensure(other.length)

        if length % 8 == 0 {
            let src = other.toData()
            let fullBytes = other.length / 8
            for i in 0..<fullBytes {
                buffer[length / 8 + i] = src[i]
            }
            length += fullBytes * 8
            let remainder = other.length % 8
            if remainder > 0 {
                for i in 0..<remainder {
                    write(bit: other.bit(at: fullBytes * 8 + i))
                }
            }
            return
        }

        for i in 0..<other.length { write(bit: other.bit(at: i)) }
    }

    // MARK: - Bytes

    public mutating func write(bytes: Data) {
        guard !bytes.isEmpty else { return }
        ensure(bytes.count * 8)
        if length % 8 == 0 {
            let start = length / 8
            for (i, byte) in bytes.enumerated() { buffer[start + i] = byte }
            length += bytes.count * 8
            return
        }
        for byte in bytes { write(uint: UInt64(byte), bits: 8) }
    }

    // MARK: - Integers

    /// Writes the low `bits` bits of `value`, most significant first.
    public mutating func write(uint value: UInt64, bits: Int) {
        precondition(bits >= 0 && bits <= 64, "uint width must be 0...64, got \(bits)")
        guard bits > 0 else { return }
        if bits < 64 {
            precondition(value >> UInt64(bits) == 0, "Value \(value) does not fit in \(bits) bits")
        }
        ensure(bits)
        var i = bits - 1
        while i >= 0 {
            write(bit: (value >> UInt64(i)) & 1 == 1)
            i -= 1
        }
    }

    /// Writes a big unsigned integer in `bits` bits, most significant first.
    public mutating func write(bigUInt value: BigUInt, bits: Int) {
        precondition(bits >= 0, "uint width must be non-negative")
        guard bits > 0 else { return }
        precondition(value.bitWidth <= bits, "Value does not fit in \(bits) bits")
        ensure(bits)
        var i = bits - 1
        while i >= 0 {
            write(bit: value.bit(at: i))
            i -= 1
        }
    }

    /// Writes a two's-complement signed integer in `bits` bits.
    public mutating func write(int value: Int64, bits: Int) {
        precondition(bits >= 1 && bits <= 64, "int width must be 1...64, got \(bits)")
        if bits < 64 {
            let limit = Int64(1) << Int64(bits - 1)
            precondition(value >= -limit && value < limit, "Value \(value) does not fit in \(bits) signed bits")
        }
        let masked = bits == 64
            ? UInt64(bitPattern: value)
            : UInt64(bitPattern: value) & ((UInt64(1) << UInt64(bits)) - 1)
        write(uint: masked, bits: bits)
    }

    /// Writes a variable-width unsigned integer: a length prefix of `lengthBits`
    /// giving the byte count, then that many bytes. This is the `VarUInteger`
    /// encoding used by `Grams`/`coins` with `lengthBits == 4`.
    public mutating func write(varUInt value: BigUInt, lengthBits: Int) {
        if value.isZero {
            write(uint: 0, bits: lengthBits)
            return
        }
        let byteCount = (value.bitWidth + 7) / 8
        write(uint: UInt64(byteCount), bits: lengthBits)
        write(bigUInt: value, bits: byteCount * 8)
    }

    /// Nanoton amounts: `VarUInteger 16`, i.e. a 4-bit byte-count prefix.
    public mutating func write(coins value: BigUInt) {
        write(varUInt: value, lengthBits: 4)
    }

    // MARK: - Result

    public func build() -> BitString {
        BitString(bytes: buffer, offset: 0, length: length)
    }
}
