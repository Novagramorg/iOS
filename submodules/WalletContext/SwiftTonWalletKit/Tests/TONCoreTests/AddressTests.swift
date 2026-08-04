import XCTest
import TONTestVectors
@testable import TONCore

/// Verifies `Address` against golden vectors generated from `@ton/core`.
final class AddressTests: XCTestCase {
    struct AddressVectors: Decodable {
        let valid: [Valid]
        let invalid: [Invalid]

        struct Valid: Decodable {
            let raw: String
            let workchain: Int
            let hash: String
            let bounceable: String
            let nonBounceable: String
            let bounceableTestnet: String
            let nonBounceableTestnet: String
            let bounceableNonUrlSafe: String
            let reparsedRaw: String
        }

        struct Invalid: Decodable {
            let label: String
            let input: String
            let message: String
        }
    }

    /// Loads the vectors and asserts they are populated, so an empty or truncated
    /// vector file fails loudly instead of letting every loop pass vacuously.
    private func vectors() throws -> AddressVectors {
        let loaded: AddressVectors = try Vectors.load("address.json")
        XCTAssertGreaterThanOrEqual(loaded.valid.count, 6, "address.json lost valid cases")
        XCTAssertGreaterThanOrEqual(loaded.invalid.count, 8, "address.json lost invalid cases")
        return loaded
    }

    func testParsesRawForm() throws {
        for v in try vectors().valid {
            let address = try Address.parseRaw(v.raw)
            XCTAssertEqual(Int(address.workchain), v.workchain, "workchain for \(v.raw)")
            XCTAssertEqual(address.hash.hexString, v.hash, "hash for \(v.raw)")
            XCTAssertEqual(address.rawString, v.raw, "raw round-trip for \(v.raw)")
        }
    }

    func testFormatsAllFriendlyVariants() throws {
        for v in try vectors().valid {
            let address = try Address.parseRaw(v.raw)

            XCTAssertEqual(
                address.toString(urlSafe: true, bounceable: true, testOnly: false),
                v.bounceable,
                "bounceable for \(v.raw)"
            )
            XCTAssertEqual(
                address.toString(urlSafe: true, bounceable: false, testOnly: false),
                v.nonBounceable,
                "non-bounceable for \(v.raw)"
            )
            XCTAssertEqual(
                address.toString(urlSafe: true, bounceable: true, testOnly: true),
                v.bounceableTestnet,
                "bounceable testnet for \(v.raw)"
            )
            XCTAssertEqual(
                address.toString(urlSafe: true, bounceable: false, testOnly: true),
                v.nonBounceableTestnet,
                "non-bounceable testnet for \(v.raw)"
            )
            XCTAssertEqual(
                address.toString(urlSafe: false, bounceable: true, testOnly: false),
                v.bounceableNonUrlSafe,
                "non-url-safe for \(v.raw)"
            )
        }
    }

    func testParsesFriendlyFormAndRecoversFlags() throws {
        for v in try vectors().valid {
            let bounceable = try Address.parseFriendly(v.bounceable)
            XCTAssertEqual(bounceable.address.rawString, v.reparsedRaw)
            XCTAssertTrue(bounceable.isBounceable, "bounceable flag for \(v.raw)")
            XCTAssertFalse(bounceable.isTestOnly, "testnet flag for \(v.raw)")

            let nonBounceable = try Address.parseFriendly(v.nonBounceable)
            XCTAssertFalse(nonBounceable.isBounceable, "non-bounceable flag for \(v.raw)")
            XCTAssertFalse(nonBounceable.isTestOnly)

            let testnet = try Address.parseFriendly(v.bounceableTestnet)
            XCTAssertTrue(testnet.isBounceable)
            XCTAssertTrue(testnet.isTestOnly, "testnet flag for \(v.raw)")

            let nonBounceableTestnet = try Address.parseFriendly(v.nonBounceableTestnet)
            XCTAssertFalse(nonBounceableTestnet.isBounceable)
            XCTAssertTrue(nonBounceableTestnet.isTestOnly)
        }
    }

    /// Both base64 alphabets must decode to the same address.
    func testAcceptsBothBase64Alphabets() throws {
        for v in try vectors().valid {
            let urlSafe = try Address.parseFriendly(v.bounceable).address
            let standard = try Address.parseFriendly(v.bounceableNonUrlSafe).address
            XCTAssertEqual(urlSafe, standard, "alphabet equivalence for \(v.raw)")
        }
    }

    /// Malformed input must be rejected, never silently coerced.
    func testRejectsInvalidAddresses() throws {
        for v in try vectors().invalid {
            XCTAssertThrowsError(
                try Address.parse(v.input),
                "expected \(v.label) (\"\(v.input)\") to be rejected"
            )
        }
    }

    /// A single flipped character must fail the CRC-16 check rather than parse.
    func testRejectsCorruptedChecksum() throws {
        let valid = try vectors().valid[2].bounceable
        var corrupted = Array(valid)
        corrupted[5] = corrupted[5] == "A" ? "B" : "A"
        XCTAssertThrowsError(try Address.parseFriendly(String(corrupted)))
    }

    func testDescriptionIsFriendlyBounceable() throws {
        for v in try vectors().valid {
            let address = try Address.parseRaw(v.raw)
            XCTAssertEqual(address.description, v.bounceable)
        }
    }

    func testCanonicalStringChangesPresentationWithoutLosingTestFlag() throws {
        for v in try vectors().valid {
            XCTAssertEqual(
                try Address.canonicalString(v.bounceable, bounceable: false),
                v.nonBounceable
            )
            XCTAssertEqual(
                try Address.canonicalString(v.bounceableTestnet, bounceable: false),
                v.nonBounceableTestnet
            )
            XCTAssertEqual(
                try Address.canonicalString(v.raw, bounceable: false),
                v.nonBounceable
            )
            XCTAssertEqual(
                try Address.canonicalString(v.bounceableTestnet, bounceable: false, testOnly: false),
                v.nonBounceable
            )
        }
    }
}
