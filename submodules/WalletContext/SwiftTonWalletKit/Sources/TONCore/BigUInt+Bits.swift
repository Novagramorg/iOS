import Foundation
@_exported import _BigInt

/// Bit-level accessors the cell serializer needs, which attaswift/BigInt does not
/// expose directly.
extension BigUInt {
    /// The bit at `index`, counting from the least significant bit.
    @inlinable
    public func bit(at index: Int) -> Bool {
        precondition(index >= 0, "Bit index must be non-negative")
        let wordIndex = index / Word.bitWidth
        guard wordIndex < words.count else { return false }
        return (words[wordIndex] >> UInt(index % Word.bitWidth)) & 1 == 1
    }

    /// Minimum number of bits needed to represent this value; 0 for zero.
    ///
    /// `BigUInt.bitWidth` already has these semantics, but naming it explicitly keeps
    /// call sites unambiguous against `FixedWidthInteger.bitWidth`, which is a
    /// constant rather than a magnitude.
    @inlinable
    public var significantBits: Int { bitWidth }
}

extension BigInt {
    /// The bit at `index` of the two's-complement representation, counting from the
    /// least significant bit. Negative values are treated as infinitely
    /// sign-extended, which is what fixed-width serialization expects.
    @inlinable
    public func twosComplementBit(at index: Int, width: Int) -> Bool {
        precondition(index >= 0 && index < width, "Bit index out of range")
        if sign == .plus { return magnitude.bit(at: index) }
        // -v == ~(v - 1), so bit i of the negative is the inverse of bit i of (|v| - 1).
        let adjusted = magnitude - 1
        return !adjusted.bit(at: index)
    }
}
