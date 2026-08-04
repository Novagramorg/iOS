import XCTest
import TONTestVectors
@testable import TONCore

/// Verifies TVM stack parsing against golden vectors from walletkit's `ParseStack`.
final class TupleTests: XCTestCase {
    struct TupleVector: Decodable {
        let label: String
        let input: [RawStackItem]
        let parsed: [ParsedItem]

        /// The generator's structural description of each parsed item.
        struct ParsedItem: Decodable {
            let type: String
            let value: String?
            let hash: String?
            let items: [ParsedItem]?
        }
    }

    private func vectors() throws -> [TupleVector] {
        let loaded: [TupleVector] = try Vectors.load("tuples.json")
        XCTAssertGreaterThanOrEqual(loaded.count, 12, "tuples.json lost cases")
        return loaded
    }

    /// Compares a parsed item against the generator's description.
    private func assertMatches(_ item: TupleItem, _ expected: TupleVector.ParsedItem, _ context: String) {
        switch (item, expected.type) {
        case (.int(let value), "int"):
            XCTAssertEqual(String(value), expected.value, "int value at \(context)")
        case (.null, "null"):
            break
        case (.cell(let cell), "cell"):
            XCTAssertEqual(cell.hash().hexString, expected.hash, "cell hash at \(context)")
        case (.slice(let cell), "slice"):
            XCTAssertEqual(cell.hash().hexString, expected.hash, "slice hash at \(context)")
        case (.tuple(let items), "tuple"):
            let expectedItems = expected.items ?? []
            XCTAssertEqual(items.count, expectedItems.count, "tuple arity at \(context)")
            for (i, sub) in zip(items, expectedItems).enumerated() {
                assertMatches(sub.0, sub.1, "\(context)[\(i)]")
            }
        default:
            XCTFail("type mismatch at \(context): got \(item), expected \(expected.type)")
        }
    }

    func testParseStackMatchesReference() throws {
        for v in try vectors() {
            let parsed = try parseStack(v.input)
            XCTAssertEqual(parsed.count, v.parsed.count, "stack depth for \(v.label)")
            for (i, pair) in zip(parsed, v.parsed).enumerated() {
                assertMatches(pair.0, pair.1, "\(v.label)[\(i)]")
            }
        }
    }

    // MARK: - Number parsing

    func testParsesDecimalAndHex() throws {
        XCTAssertEqual(try parseStackNumber("42"), BigInt(42))
        XCTAssertEqual(try parseStackNumber("0x2a"), BigInt(42))
        XCTAssertEqual(try parseStackNumber("0X2A"), BigInt(42))
        XCTAssertEqual(try parseStackNumber("0"), BigInt(0))
    }

    /// The reference encodes negatives as a leading `-` on the magnitude, not as
    /// two's complement.
    func testParsesNegativeNumbers() throws {
        XCTAssertEqual(try parseStackNumber("-42"), BigInt(-42))
        XCTAssertEqual(try parseStackNumber("-0x2a"), BigInt(-42))
    }

    func testParses256BitNumber() throws {
        let value = try parseStackNumber("0x" + String(repeating: "f", count: 64))
        XCTAssertEqual(value, BigInt((BigUInt(1) << 256) - 1))
    }

    func testRejectsMalformedNumbers() {
        XCTAssertThrowsError(try parseStackNumber(""))
        XCTAssertThrowsError(try parseStackNumber("not-a-number"))
        XCTAssertThrowsError(try parseStackNumber("0xzz"))
    }

    /// An empty tuple or list collapses to null — reference behaviour, easy to miss.
    func testEmptyTupleBecomesNull() throws {
        XCTAssertEqual(try parseStack([.tuple([])]), [.null])
        XCTAssertEqual(try parseStack([.list([])]), [.null])
    }

    func testNestedTuplesPreserveStructure() throws {
        let parsed = try parseStack([
            .tuple([.num("1"), .tuple([.num("2"), .num("3")])])
        ])
        guard case .tuple(let outer) = parsed[0] else { return XCTFail("expected a tuple") }
        XCTAssertEqual(outer.count, 2)
        XCTAssertEqual(outer[0], .int(BigInt(1)))
        guard case .tuple(let inner) = outer[1] else { return XCTFail("expected a nested tuple") }
        XCTAssertEqual(inner, [.int(BigInt(2)), .int(BigInt(3))])
    }

    // MARK: - Serialization

    func testSerializeRoundTripsNumbers() throws {
        let items: [TupleItem] = [.int(BigInt(42)), .int(BigInt(-42)), .int(BigInt(0))]
        let raw = try serializeStack(items)
        XCTAssertEqual(try parseStack(raw), items)
    }

    /// The reference's serializer supports only int/cell/slice/builder.
    func testSerializeRejectsUnsupportedTypes() {
        XCTAssertThrowsError(try serializeStack([.null]))
        XCTAssertThrowsError(try serializeStack([.tuple([.int(BigInt(1))])]))
        XCTAssertThrowsError(try serializeStack([.nan]))
    }

    // MARK: - TupleReader

    func testReaderReadsInOrder() throws {
        let cell = try beginCell().storeUInt(0xcafe, bits: 16).endCell()
        var reader = TupleReader([.int(BigInt(7)), .cell(cell), .null])

        XCTAssertEqual(try reader.readInt(), 7)
        XCTAssertEqual(try reader.readCell().hash(), cell.hash())
        XCTAssertNil(try reader.readCellOptional())
        XCTAssertEqual(reader.remaining, 0)
    }

    func testReaderThrowsWhenExhausted() {
        var reader = TupleReader([])
        XCTAssertThrowsError(try reader.readInt())
    }

    func testReaderRejectsTypeMismatch() throws {
        var reader = TupleReader([.null])
        XCTAssertThrowsError(try reader.readCell())
    }

    func testReaderReadsBool() throws {
        var reader = TupleReader([.int(BigInt(0)), .int(BigInt(1)), .int(BigInt(-1))])
        XCTAssertFalse(try reader.readBool())
        XCTAssertTrue(try reader.readBool())
        XCTAssertTrue(try reader.readBool(), "any non-zero is true")
    }

    func testReaderReadsNestedTuple() throws {
        var reader = TupleReader([.tuple([.int(BigInt(1)), .int(BigInt(2))])])
        var nested = try reader.readTuple()
        XCTAssertEqual(try nested.readInt(), 1)
        XCTAssertEqual(try nested.readInt(), 2)
    }

    /// Get-method results routinely exceed Int64; readBigInt must not lose them.
    func testReaderRejectsOverflowingInt() throws {
        let huge = BigInt((BigUInt(1) << 200))
        var reader = TupleReader([.int(huge)])
        XCTAssertThrowsError(try reader.readInt())

        var reader2 = TupleReader([.int(huge)])
        XCTAssertEqual(try reader2.readBigInt(), huge)
    }

    // MARK: - Codable

    func testRawStackItemRoundTripsThroughJSON() throws {
        let items: [RawStackItem] = [
            .null,
            .num("0x2a"),
            .cell("te6cckEBAQEAAgAAAEysuc0="),
            .tuple([.num("1"), .null]),
        ]
        let encoded = try JSONEncoder().encode(items)
        let decoded = try JSONDecoder().decode([RawStackItem].self, from: encoded)
        XCTAssertEqual(decoded, items)
    }

    func testRawStackItemRejectsUnknownType() throws {
        let json = Data(#"[{"type":"quaternion","value":"1"}]"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode([RawStackItem].self, from: json))
    }
}

/// Unit conversion is string-based on purpose: 1 TON is 10^9 nanoton and jettons run
/// to 18 decimals, so floating point would lose value silently.
final class UnitsTests: XCTestCase {
    func testFromNano() {
        XCTAssertEqual(Units.fromNano(BigUInt(1_000_000_000)), "1")
        XCTAssertEqual(Units.fromNano(BigUInt(1_500_000_000)), "1.5")
        XCTAssertEqual(Units.fromNano(BigUInt(1)), "0.000000001")
        XCTAssertEqual(Units.fromNano(BigUInt(0)), "0")
        XCTAssertEqual(Units.fromNano(BigUInt(1_000_000_001)), "1.000000001")
        XCTAssertEqual(Units.fromNano(BigUInt(999_999_999)), "0.999999999")
    }

    func testToNano() throws {
        XCTAssertEqual(try Units.toNano("1"), BigUInt(1_000_000_000))
        XCTAssertEqual(try Units.toNano("1.5"), BigUInt(1_500_000_000))
        XCTAssertEqual(try Units.toNano("0.000000001"), BigUInt(1))
        XCTAssertEqual(try Units.toNano("0"), BigUInt(0))
        XCTAssertEqual(try Units.toNano(".5"), BigUInt(500_000_000))
        XCTAssertEqual(try Units.toNano("1."), BigUInt(1_000_000_000))
    }

    func testRoundTripPreservesLargeValues() throws {
        // Larger than Double can represent exactly.
        let huge = BigUInt("123456789012345678901234567890")
        XCTAssertEqual(try Units.toNano(Units.fromNano(huge)), huge)
    }

    func testRejectsExcessPrecision() {
        XCTAssertThrowsError(try Units.toNano("0.0000000001"), "10 decimals exceeds 9")
    }

    func testRejectsMalformedInput() {
        XCTAssertThrowsError(try Units.toNano(""))
        XCTAssertThrowsError(try Units.toNano("abc"))
        XCTAssertThrowsError(try Units.toNano("1.2.3"))
        XCTAssertThrowsError(try Units.toNano("-1"), "negative amounts are rejected")
    }

    func testJettonDecimals() throws {
        // 18 decimals, the widest in common use.
        XCTAssertEqual(try Units.parseUnits("1.5", decimals: 18), BigUInt("1500000000000000000"))
        XCTAssertEqual(Units.formatUnits(BigUInt("1500000000000000000"), decimals: 18), "1.5")
        // 0 decimals means base units are whole units.
        XCTAssertEqual(Units.formatUnits(BigUInt(42), decimals: 0), "42")
    }
}
