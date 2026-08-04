import Foundation

/// An immutable sequence of bits, the payload of every ``Cell``.
///
/// Backed by a byte buffer plus an explicit bit offset and length, so slicing is
/// O(1) and does not require re-aligning the underlying bytes.
public struct BitString: Hashable, Sendable {
    /// The maximum payload a single cell can hold.
    public static let maxCellBits = 1023

    public static let empty = BitString(bytes: Data(), offset: 0, length: 0)

    @usableFromInline let bytes: Data
    @usableFromInline let offset: Int

    /// Number of bits in the string.
    public let length: Int

    @inlinable public var isEmpty: Bool { length == 0 }

    public init(bytes: Data, offset: Int = 0, length: Int) {
        precondition(offset >= 0, "BitString offset must be non-negative")
        precondition(length >= 0, "BitString length must be non-negative")
        precondition(offset + length <= bytes.count * 8, "BitString range exceeds backing buffer")
        self.bytes = bytes
        self.offset = offset
        self.length = length
    }

    /// Creates a bit string covering all bits of `data`.
    public init(_ data: Data) {
        self.init(bytes: data, offset: 0, length: data.count * 8)
    }

    // MARK: - Access

    /// The bit at `index`, where 0 is the most significant bit of the first byte.
    @inlinable
    public func bit(at index: Int) -> Bool {
        precondition(index >= 0 && index < length, "Bit index \(index) out of range (length \(length))")
        let absolute = offset + index
        let byte = bytes[bytes.startIndex + (absolute / 8)]
        return (byte >> (7 - UInt8(absolute % 8))) & 1 == 1
    }

    @inlinable
    public subscript(index: Int) -> Bool { bit(at: index) }

    /// A view over `length` bits starting at `offset`, sharing the backing buffer.
    public func subrange(offset subOffset: Int, length subLength: Int) -> BitString {
        precondition(subOffset >= 0 && subLength >= 0, "Subrange bounds must be non-negative")
        precondition(subOffset + subLength <= length, "Subrange exceeds bit string length")
        return BitString(bytes: bytes, offset: offset + subOffset, length: subLength)
    }

    /// Drops the first `count` bits.
    public func dropFirst(_ count: Int) -> BitString {
        subrange(offset: count, length: length - count)
    }

    /// Keeps only the first `count` bits.
    public func prefix(_ count: Int) -> BitString {
        subrange(offset: 0, length: min(count, length))
    }

    // MARK: - Byte conversion

    /// Copies the bits into a byte-aligned buffer, zero-padding the final byte.
    ///
    /// Fast path: when already byte-aligned this is a plain range copy.
    public func toData() -> Data {
        guard length > 0 else { return Data() }
        let byteCount = (length + 7) / 8

        if offset % 8 == 0 {
            let start = bytes.startIndex + offset / 8
            var out = Data(bytes[start..<min(start + byteCount, bytes.endIndex)])
            // Zero the unused tail bits so equal bit strings produce equal bytes.
            if length % 8 != 0, let last = out.last {
                let keep = length % 8
                out[out.index(before: out.endIndex)] = last & (0xff << (8 - UInt8(keep)))
            }
            while out.count < byteCount { out.append(0) }
            return out
        }

        var out = Data(repeating: 0, count: byteCount)
        for i in 0..<length where bit(at: i) {
            out[i / 8] |= 1 << (7 - UInt8(i % 8))
        }
        return out
    }

    /// The TL-B "augmented" byte form: if the bit count is not a multiple of 8, a
    /// single `1` bit is appended and the rest of the byte is zero-filled. This is
    /// what cell serialization and hashing operate on.
    public func toAugmentedData() -> Data {
        if length % 8 == 0 { return toData() }
        var builder = BitBuilder(capacity: length + 8)
        builder.write(self)
        builder.write(bit: true)
        while builder.length % 8 != 0 { builder.write(bit: false) }
        return builder.build().toData()
    }

    // MARK: - Equality

    /// Bitwise equality, independent of backing-buffer alignment.
    public static func == (lhs: BitString, rhs: BitString) -> Bool {
        guard lhs.length == rhs.length else { return false }
        if lhs.offset % 8 == 0 && rhs.offset % 8 == 0 {
            return lhs.toData() == rhs.toData()
        }
        for i in 0..<lhs.length where lhs.bit(at: i) != rhs.bit(at: i) {
            return false
        }
        return true
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(length)
        hasher.combine(toData())
    }
}

// MARK: - Description

extension BitString: CustomStringConvertible {
    /// Hex form matching `@ton/core`'s `BitString.toString()`, so vector comparison
    /// is direct.
    ///
    /// Always computed over the *augmented* bytes. Nibble-aligned strings render as
    /// plain hex with no marker (4 bits of `0xA` is `"A"`, 12 bits of `0xABC` is
    /// `"ABC"`); only non-nibble-aligned ones carry the trailing `_`
    /// (1 bit set is `"C_"`). Verified against the reference, not assumed.
    public var description: String {
        let hex = toAugmentedData().map { String(format: "%02X", $0) }.joined()

        if length % 4 == 0 {
            let s = String(hex.prefix(((length + 7) / 8) * 2))
            return length % 8 == 0 ? s : String(s.dropLast())
        }
        return length % 8 <= 4 ? String(hex.dropLast()) + "_" : hex + "_"
    }
}
