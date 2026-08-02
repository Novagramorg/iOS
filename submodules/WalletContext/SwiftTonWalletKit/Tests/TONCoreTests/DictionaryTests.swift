import XCTest
import TONTestVectors
@testable import TONCore

/// Verifies `HashmapE` serialization against golden vectors from `@ton/core`.
///
/// Label encoding picks the shortest of three forms, so a divergence changes the
/// cell hash without changing the logical contents — exactly the class of bug that
/// only surfaces later as a rejected signature.
final class DictionaryTests: XCTestCase {
    struct DictVector: Decodable {
        let label: String
        let boc: String
        let hash: String
    }

    private func vectors() throws -> [DictVector] {
        let loaded: [DictVector] = try Vectors.load("dictionary.json")
        XCTAssertGreaterThanOrEqual(loaded.count, 8, "dictionary.json lost cases")
        return loaded
    }

    private func vector(_ label: String) throws -> DictVector {
        try XCTUnwrap(try vectors().first { $0.label == label }, "missing vector \(label)")
    }

    private func assertMatches(_ builder: Builder, _ label: String) throws {
        let cell = try builder.endCell()
        let expected = try vector(label)
        XCTAssertEqual(cell.toBoc().base64EncodedString(), expected.boc, "boc for \(label)")
        XCTAssertEqual(cell.hash().hexString, expected.hash, "hash for \(label)")
    }

    // MARK: - The V5R1 extensions shape: BigUint(256) -> BigInt(1)

    private func extensionsDict() -> TONDictionary<BigUIntKey, BigIntValue> {
        TONDictionary(key: BigUIntKey(bits: 256), value: BigIntValue(bits: 1))
    }

    func testEmptyExtensionsDict() throws {
        let dict = extensionsDict()
        let builder = Builder()
        try dict.store(into: builder)
        // HashmapE nothing$0 — a single zero bit.
        XCTAssertEqual(builder.bitCount, 1)
        try assertMatches(builder, "ext-empty")
    }

    func testSingleEntryExtensionsDict() throws {
        var dict = extensionsDict()
        try dict.set(BigUInt(1), BigInt(-1))
        let builder = Builder()
        try dict.store(into: builder)
        try assertMatches(builder, "ext-one-entry")
    }

    /// Three keys spread across the range, which forces forks and a mix of label forms.
    func testThreeEntryExtensionsDict() throws {
        var dict = extensionsDict()
        try dict.set(BigUInt(1), BigInt(-1))
        try dict.set(BigUInt(1) << 255, BigInt(-1))
        try dict.set(BigUInt(0xdeadbeef), BigInt(-1))
        let builder = Builder()
        try dict.store(into: builder)
        try assertMatches(builder, "ext-three-entries")
    }

    // MARK: - Narrow keys

    private func u8CellDict() -> TONDictionary<UIntKey, CellValue> {
        TONDictionary(key: UIntKey(bits: 8), value: CellValue())
    }

    func testEmptyU8Dict() throws {
        let dict = u8CellDict()
        let builder = Builder()
        try dict.store(into: builder)
        try assertMatches(builder, "u8-to-cell-empty")
    }

    /// Keys 0 and 255 share no bits, so the root label is empty and both branches
    /// use the "same" label form.
    func testSparseU8Dict() throws {
        var dict = u8CellDict()
        try dict.set(0, try beginCell().storeUInt(0, bits: 8).endCell())
        try dict.set(255, try beginCell().storeUInt(255, bits: 8).endCell())
        let builder = Builder()
        try dict.store(into: builder)
        try assertMatches(builder, "u8-to-cell-sparse")
    }

    /// 100 dense keys produce a deep trie exercising every label form.
    func testDenseU8Dict() throws {
        var dict = u8CellDict()
        for i in 0..<100 {
            try dict.set(UInt64(i), try beginCell().storeUInt(UInt64(i), bits: 8).endCell())
        }
        let builder = Builder()
        try dict.store(into: builder)
        try assertMatches(builder, "u8-to-cell-dense-100")
    }

    func testU32ToBigUInt64Dict() throws {
        var dict = TONDictionary(key: UIntKey(bits: 32), value: BigUIntValue(bits: 64))
        try dict.set(1, BigUInt(1))
        try dict.set(0xffff_ffff, (BigUInt(1) << 64) - 1)
        try dict.set(1000, BigUInt("12345678901234567890"))
        let builder = Builder()
        try dict.store(into: builder)
        try assertMatches(builder, "u32-to-biguint64")
    }

    func testAddressKeyedDict() throws {
        var dict = TONDictionary(key: AddressKey(), value: CellValue())
        let raws = [
            "0:0000000000000000000000000000000000000000000000000000000000000000",
            "0:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
            "0:83dfd552e63729b472fcbcc8c45ebcc6691702558b68ec7527e1ba403a0f31a8",
        ]
        for raw in raws {
            try dict.set(try Address.parseRaw(raw), try beginCell().storeUInt(1, bits: 8).endCell())
        }
        let builder = Builder()
        try dict.store(into: builder)
        try assertMatches(builder, "address-to-cell")
    }

    // MARK: - Round trips

    func testRoundTripPreservesEntries() throws {
        var dict = u8CellDict()
        let keys: [UInt64] = [0, 1, 7, 42, 128, 200, 255]
        for k in keys {
            try dict.set(k, try beginCell().storeUInt(k, bits: 8).endCell())
        }

        let builder = Builder()
        try dict.store(into: builder)
        var slice = try builder.endCell().beginParse()

        let parsed = try TONDictionary.load(key: UIntKey(bits: 8), value: CellValue(), from: &slice)
        XCTAssertEqual(parsed.count, keys.count)
        for k in keys {
            let cell = try XCTUnwrap(try parsed.get(k), "key \(k) missing after round trip")
            var s = cell.beginParse()
            XCTAssertEqual(try s.loadUInt(8), k)
        }
    }

    func testRoundTripEmptyDict() throws {
        let dict = u8CellDict()
        let builder = Builder()
        try dict.store(into: builder)
        var slice = try builder.endCell().beginParse()
        let parsed = try TONDictionary.load(key: UIntKey(bits: 8), value: CellValue(), from: &slice)
        XCTAssertTrue(parsed.isEmpty)
    }

    func testRoundTripWideKeys() throws {
        var dict = extensionsDict()
        let keys = [BigUInt(0), BigUInt(1), BigUInt(1) << 255, BigUInt(0xdeadbeef)]
        for k in keys { try dict.set(k, BigInt(-1)) }

        let builder = Builder()
        try dict.store(into: builder)
        var slice = try builder.endCell().beginParse()

        let parsed = try TONDictionary.load(
            key: BigUIntKey(bits: 256),
            value: BigIntValue(bits: 1),
            from: &slice
        )
        XCTAssertEqual(parsed.count, keys.count)
        for k in keys {
            XCTAssertEqual(try parsed.get(k), BigInt(-1), "key \(k) missing")
        }
    }

    /// Serialization order must be key order, not insertion order, or the hash
    /// would depend on how the dictionary was built.
    func testSerializationIsInsertionOrderIndependent() throws {
        var ascending = u8CellDict()
        for i in [1, 5, 9, 200] as [UInt64] {
            try ascending.set(i, try beginCell().storeUInt(i, bits: 8).endCell())
        }
        var descending = u8CellDict()
        for i in [200, 9, 5, 1] as [UInt64] {
            try descending.set(i, try beginCell().storeUInt(i, bits: 8).endCell())
        }

        let a = Builder(), b = Builder()
        try ascending.store(into: a)
        try descending.store(into: b)
        XCTAssertEqual(try a.endCell().hash(), try b.endCell().hash())
    }

    // MARK: - Label length field

    /// `ceil(log2(keyBits + 1))`, the width of the explicit label-length field.
    func testLengthFieldWidth() {
        typealias D = TONDictionary<UIntKey, CellValue>
        XCTAssertEqual(D.lengthFieldWidth(keyBits: 1), 1)
        XCTAssertEqual(D.lengthFieldWidth(keyBits: 2), 2)
        XCTAssertEqual(D.lengthFieldWidth(keyBits: 3), 2)
        XCTAssertEqual(D.lengthFieldWidth(keyBits: 4), 3)
        XCTAssertEqual(D.lengthFieldWidth(keyBits: 7), 3)
        XCTAssertEqual(D.lengthFieldWidth(keyBits: 8), 4)
        XCTAssertEqual(D.lengthFieldWidth(keyBits: 255), 8)
        XCTAssertEqual(D.lengthFieldWidth(keyBits: 256), 9)
    }

    // MARK: - Rejection

    func testKeyExceedingWidthIsRejected() throws {
        var dict = TONDictionary(key: BigUIntKey(bits: 8), value: CellValue())
        XCTAssertThrowsError(try dict.set(BigUInt(256), Cell.empty))
    }
}
