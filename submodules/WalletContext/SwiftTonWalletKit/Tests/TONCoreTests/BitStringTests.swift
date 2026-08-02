import XCTest
import TONTestVectors
@testable import TONCore

final class BitStringTests: XCTestCase {
    // MARK: - Reading

    func testBitAccessIsMostSignificantFirst() {
        let bits = BitString(Data([0b1010_0000]))
        XCTAssertEqual(bits.length, 8)
        XCTAssertEqual((0..<8).map { bits[$0] }, [true, false, true, false, false, false, false, false])
    }

    func testEmptyBitString() {
        XCTAssertTrue(BitString.empty.isEmpty)
        XCTAssertEqual(BitString.empty.length, 0)
        XCTAssertEqual(BitString.empty.toData(), Data())
    }

    func testSubrangeSharesBackingBufferWithoutRealignment() {
        let bits = BitString(Data([0b1100_1010, 0b0101_0011]))
        let middle = bits.subrange(offset: 4, length: 8)
        XCTAssertEqual(middle.length, 8)
        XCTAssertEqual((0..<8).map { middle[$0] }, [true, false, true, false, false, true, false, true])
        // A shifted view must still serialize to correctly aligned bytes.
        XCTAssertEqual(middle.toData(), Data([0b1010_0101]))
    }

    func testDropFirstAndPrefix() {
        let bits = BitString(Data([0b1111_0000]))
        XCTAssertEqual(bits.dropFirst(4).toData(), Data([0b0000_0000]))
        XCTAssertEqual(bits.dropFirst(4).length, 4)
        XCTAssertEqual(bits.prefix(4).toData(), Data([0b1111_0000]))
        XCTAssertEqual(bits.prefix(4).length, 4)
        XCTAssertEqual(bits.prefix(100).length, 8, "prefix clamps to available length")
    }

    // MARK: - Byte conversion

    /// Unused tail bits must be zeroed so equal bit strings yield equal bytes.
    func testToDataZeroesTailBits() {
        var builder = BitBuilder()
        builder.write(bit: true)
        builder.write(bit: true)
        builder.write(bit: false)
        let bits = builder.build()
        XCTAssertEqual(bits.length, 3)
        XCTAssertEqual(bits.toData(), Data([0b1100_0000]))
    }

    /// The augmented form appends a 1 then zero-pads — this is what hashing consumes.
    func testAugmentedDataAppendsCompletionTag() {
        var builder = BitBuilder()
        builder.write(uint: 0b101, bits: 3)
        XCTAssertEqual(builder.build().toAugmentedData(), Data([0b1011_0000]))
    }

    func testAugmentedDataIsIdentityWhenByteAligned() {
        let bits = BitString(Data([0xab, 0xcd]))
        XCTAssertEqual(bits.toAugmentedData(), Data([0xab, 0xcd]))
    }

    // MARK: - Equality

    func testEqualityIgnoresAlignment() {
        let aligned = BitString(Data([0b1010_0101]))
        // The same 8 bits, but living at bit offset 4 of a wider buffer.
        let unaligned = BitString(bytes: Data([0b0000_1010, 0b0101_0000]), offset: 4, length: 8)
        XCTAssertEqual(aligned, unaligned)
        XCTAssertEqual(aligned.hashValue, unaligned.hashValue)
    }

    func testDifferentLengthsAreNotEqual() {
        XCTAssertNotEqual(BitString(Data([0xff])), BitString(bytes: Data([0xff]), offset: 0, length: 7))
    }

    // MARK: - Description

    struct BitStringVector: Decodable {
        let value: String
        let bitLength: Int
        let mod4: Int
        let mod8: Int
        let rendered: String
    }

    /// `description` across every alignment class, against reference-generated output.
    ///
    /// The rules are unobvious and I got them wrong by hand first: nibble-aligned
    /// strings carry *no* completion marker ("A", "ABC"), only non-nibble-aligned
    /// ones do ("C_", "AC_"). Hence vectors rather than hand-written expectations.
    func testDescriptionMatchesReference() throws {
        let vectors: [BitStringVector] = try Vectors.load("bitstring.json")
        XCTAssertGreaterThanOrEqual(vectors.count, 14, "bitstring.json lost cases")

        for v in vectors {
            var builder = BitBuilder()
            if v.bitLength > 0 {
                builder.write(bigUInt: BigUInt(v.value)!, bits: v.bitLength)
            }
            let bits = builder.build()
            XCTAssertEqual(bits.length, v.bitLength)
            XCTAssertEqual(
                bits.description,
                v.rendered,
                "render of \(v.bitLength) bits (mod4=\(v.mod4), mod8=\(v.mod8))"
            )
        }
    }

    func testDescriptionByteAligned() {
        XCTAssertEqual(BitString(Data([0xab, 0xcd])).description, "ABCD")
        XCTAssertEqual(BitString.empty.description, "")
    }

    // MARK: - Builder

    func testBuilderWritesUnsignedIntegers() {
        var builder = BitBuilder()
        builder.write(uint: 0xdead_beef, bits: 32)
        XCTAssertEqual(builder.length, 32)
        XCTAssertEqual(builder.build().toData(), Data([0xde, 0xad, 0xbe, 0xef]))
    }

    func testBuilderWritesSignedIntegers() {
        var negative = BitBuilder()
        negative.write(int: -1, bits: 32)
        XCTAssertEqual(negative.build().toData(), Data([0xff, 0xff, 0xff, 0xff]))

        var minimal = BitBuilder()
        minimal.write(int: -1, bits: 8)
        XCTAssertEqual(minimal.build().toData(), Data([0xff]))

        var positive = BitBuilder()
        positive.write(int: 127, bits: 8)
        XCTAssertEqual(positive.build().toData(), Data([0x7f]))
    }

    /// Masterchain is workchain -1, so signed narrow writes must sign-extend correctly.
    func testBuilderWritesNegativeWorkchainAsInt8() {
        var builder = BitBuilder()
        builder.write(int: -1, bits: 8)
        XCTAssertEqual(builder.build().toData(), Data([0xff]))
    }

    func testBuilderConcatenatesUnalignedBitStrings() {
        var builder = BitBuilder()
        builder.write(uint: 0b101, bits: 3)
        builder.write(uint: 0b11, bits: 2)
        builder.write(uint: 0b0001, bits: 4)
        XCTAssertEqual(builder.length, 9)
        let bits = builder.build()
        XCTAssertEqual((0..<9).map { bits[$0] }, [true, false, true, true, true, false, false, false, true])
    }

    func testBuilderWritesBigUInt() {
        var builder = BitBuilder()
        builder.write(bigUInt: BigUInt(0xdead_beef), bits: 32)
        XCTAssertEqual(builder.build().toData(), Data([0xde, 0xad, 0xbe, 0xef]))
    }

    func testBuilderWrites256BitValue() {
        let value = BigUInt(1) << 255
        var builder = BitBuilder()
        builder.write(bigUInt: value, bits: 256)
        var expected = Data([0x80])
        expected.append(Data(repeating: 0, count: 31))
        XCTAssertEqual(builder.build().toData(), expected)
    }

    /// Nanoton amounts use VarUInteger 16: a 4-bit byte-count prefix, then the bytes.
    func testBuilderWritesCoins() {
        var zero = BitBuilder()
        zero.write(coins: BigUInt(0))
        XCTAssertEqual(zero.length, 4, "zero coins is just a zero length prefix")

        var oneTon = BitBuilder()
        oneTon.write(coins: BigUInt(1_000_000_000))
        // 1e9 needs 4 bytes: 4-bit prefix + 32 bits.
        XCTAssertEqual(oneTon.length, 36)
    }

    func testBuilderWritesRawBytesUnaligned() {
        var builder = BitBuilder()
        builder.write(bit: true)
        builder.write(bytes: Data([0xff, 0x00]))
        XCTAssertEqual(builder.length, 17)
        let bits = builder.build()
        XCTAssertTrue(bits[0])
        XCTAssertEqual((1..<9).map { bits[$0] }, Array(repeating: true, count: 8))
        XCTAssertEqual((9..<17).map { bits[$0] }, Array(repeating: false, count: 8))
    }

    func testBuilderGrowsBeyondInitialCapacity() {
        var builder = BitBuilder(capacity: 8)
        for _ in 0..<200 { builder.write(uint: 0xff, bits: 8) }
        XCTAssertEqual(builder.length, 1600)
        XCTAssertEqual(builder.build().toData(), Data(repeating: 0xff, count: 200))
    }

    // MARK: - BigUInt bit access

    func testBigUIntBitAccessIsLeastSignificantFirst() {
        let value = BigUInt(0b1010)
        XCTAssertFalse(value.bit(at: 0))
        XCTAssertTrue(value.bit(at: 1))
        XCTAssertFalse(value.bit(at: 2))
        XCTAssertTrue(value.bit(at: 3))
        XCTAssertFalse(value.bit(at: 999), "bits past the value read as zero")
    }
}
