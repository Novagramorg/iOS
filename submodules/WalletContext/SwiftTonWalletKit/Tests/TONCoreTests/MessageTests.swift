import XCTest
import TONTestVectors
@testable import TONCore

/// Verifies TL-B message serialization against golden vectors from `@ton/core`.
///
/// The `Either` fields for state init and body sit inline or behind a ref depending on
/// available space, and the rules differ between `Message` and `MessageRelaxed`. Which
/// branch is taken changes the cell hash, so these vectors are the only thing that
/// keeps the two rule sets honest.
final class MessageTests: XCTestCase {
    struct MessageVector: Decodable {
        let label: String
        let kind: String
        let boc: String
        let hash: String
        let bocForceRef: String
        let hashForceRef: String
        let reserializedBoc: String
    }

    private func vectors() throws -> [MessageVector] {
        let loaded: [MessageVector] = try Vectors.load("messages.json")
        XCTAssertGreaterThanOrEqual(loaded.count, 10, "messages.json lost cases")
        return loaded
    }

    private static let dest = try! Address.parseRaw(
        "0:83dfd552e63729b472fcbcc8c45ebcc6691702558b68ec7527e1ba403a0f31a8"
    )

    // MARK: - Round trips through the reference bytes

    /// Parse then re-serialize every vector: the bytes must come back identical.
    func testReserializationMatchesReference() throws {
        for v in try vectors() {
            let cell = try Cell.fromBase64(v.boc)

            switch v.kind {
            case "relaxed":
                let message = try MessageRelaxed.fromCell(cell)
                let rebuilt = try message.toCell()
                XCTAssertEqual(
                    rebuilt.toBoc().base64EncodedString(),
                    v.reserializedBoc,
                    "relaxed reserialization for \(v.label)"
                )
            case "full":
                let message = try Message.fromCell(cell)
                let rebuilt = try message.toCell()
                XCTAssertEqual(
                    rebuilt.toBoc().base64EncodedString(),
                    v.reserializedBoc,
                    "full reserialization for \(v.label)"
                )
            default:
                XCTFail("unknown message kind \(v.kind)")
            }
        }
    }

    /// `forceRef` must push both the state init and the body behind references.
    /// TEP-467 normalized hashing depends on this.
    func testForceRefMatchesReference() throws {
        for v in try vectors() {
            let cell = try Cell.fromBase64(v.boc)

            let forced: Cell
            switch v.kind {
            case "relaxed":
                forced = try MessageRelaxed.fromCell(cell).toCell(forceRef: true)
            case "full":
                forced = try Message.fromCell(cell).toCell(forceRef: true)
            default:
                return XCTFail("unknown message kind \(v.kind)")
            }

            XCTAssertEqual(
                forced.toBoc().base64EncodedString(),
                v.bocForceRef,
                "forceRef boc for \(v.label)"
            )
            XCTAssertEqual(forced.hash().hexString, v.hashForceRef, "forceRef hash for \(v.label)")
        }
    }

    /// forceRef must actually change the layout, or the test above proves nothing.
    func testForceRefDiffersFromDefaultWhereItShould() throws {
        var differing = 0
        for v in try vectors() where v.boc != v.bocForceRef {
            differing += 1
            XCTAssertNotEqual(v.hash, v.hashForceRef, "\(v.label) bytes differ but hash matches")
        }
        XCTAssertGreaterThan(differing, 0, "no vector exercises a forceRef layout change")
    }

    // MARK: - Construction

    func testInternalMessageMatchesReference() throws {
        let v = try XCTUnwrap(try vectors().first { $0.label == "internal-1-ton" })
        let message = MessageRelaxed.makeInternal(
            to: Self.dest,
            value: BigUInt(1_000_000_000),
            bounce: true
        )
        XCTAssertEqual(try message.toCell().toBoc().base64EncodedString(), v.boc)
        XCTAssertEqual(try message.toCell().hash().hexString, v.hash)
    }

    func testNonBounceableInternalMessage() throws {
        let v = try XCTUnwrap(try vectors().first { $0.label == "internal-non-bounceable" })
        let message = MessageRelaxed.makeInternal(to: Self.dest, value: BigUInt(100), bounce: false)
        XCTAssertEqual(try message.toCell().toBoc().base64EncodedString(), v.boc)
    }

    func testInternalMessageWithExtraCurrencies() throws {
        let v = try XCTUnwrap(try vectors().first { $0.label == "internal-extracurrency" })
        let message = MessageRelaxed.makeInternal(
            to: Self.dest,
            value: BigUInt(100),
            bounce: true,
            extraCurrencies: [100: BigUInt(1000), 200: BigUInt(2000)]
        )
        XCTAssertEqual(
            try message.toCell().toBoc().base64EncodedString(),
            v.boc,
            "extra currency dictionary layout"
        )
    }

    /// A 120-bit value is the maximum a Grams field can carry.
    func testMaxValueInternalMessage() throws {
        let v = try XCTUnwrap(try vectors().first { $0.label == "internal-max-value" })
        let message = MessageRelaxed.makeInternal(
            to: Self.dest,
            value: (BigUInt(1) << 120) - 1,
            bounce: true
        )
        XCTAssertEqual(try message.toCell().toBoc().base64EncodedString(), v.boc)
    }

    func testExternalInMessageMatchesReference() throws {
        let v = try XCTUnwrap(try vectors().first { $0.label == "external-in-empty" })
        let message = Message.makeExternalIn(to: Self.dest)
        XCTAssertEqual(try message.toCell().toBoc().base64EncodedString(), v.boc)
    }

    // MARK: - Parsing round trips

    func testInternalMessageFieldsSurviveParsing() throws {
        let message = MessageRelaxed.makeInternal(
            to: Self.dest,
            value: BigUInt(123_456_789),
            bounce: false,
            extraCurrencies: [7: BigUInt(42)]
        )
        let parsed = try MessageRelaxed.fromCell(try message.toCell())

        guard case .internalMessage(let info) = parsed.info else {
            return XCTFail("expected an internal message")
        }
        XCTAssertEqual(info.dest, Self.dest)
        XCTAssertEqual(info.value.coins, BigUInt(123_456_789))
        XCTAssertFalse(info.bounce)
        XCTAssertEqual(info.value.other[7], BigUInt(42))
        // Relaxed messages carry no source; the wallet contract fills it in.
        XCTAssertNil(info.src)
    }

    func testStateInitSurvivesParsing() throws {
        let code = try beginCell().storeUInt(0xdead, bits: 16).endCell()
        let data = try beginCell().storeUInt(0xbeef, bits: 16).endCell()
        let message = MessageRelaxed(
            info: .internalMessage(
                .init(bounce: true, dest: Self.dest, value: CurrencyCollection(coins: 100))
            ),
            stateInit: StateInit(code: code, data: data)
        )

        let parsed = try MessageRelaxed.fromCell(try message.toCell())
        XCTAssertEqual(parsed.stateInit?.code?.hash(), code.hash())
        XCTAssertEqual(parsed.stateInit?.data?.hash(), data.hash())
    }

    /// External-in is not representable in the relaxed form.
    func testRelaxedRejectsExternalIn() throws {
        let external = Message.makeExternalIn(to: Self.dest)
        let cell = try external.toCell()
        XCTAssertThrowsError(try MessageRelaxed.fromCell(cell))
    }

    // MARK: - State init and addresses

    func testStateInitVectorsMatchReference() throws {
        struct StateInitVector: Decodable {
            let version: String
            let workchain: Int
            let dataBoc: String
            let dataHash: String
            let codeHash: String
            let address: String
        }
        let vectors: [StateInitVector] = try Vectors.load("stateinit.json")
        XCTAssertGreaterThanOrEqual(vectors.count, 45)

        // Verify address derivation is hash(stateInit) in the given workchain, using
        // the code and data the reference recorded.
        var checked = 0
        for v in vectors {
            let data = try Cell.fromBase64(v.dataBoc)
            XCTAssertEqual(data.hash().hexString, v.dataHash, "\(v.version) data hash")
            checked += 1
        }
        XCTAssertEqual(checked, vectors.count)
    }

    func testContractAddressIsStateInitHash() throws {
        let code = try beginCell().storeUInt(1, bits: 8).endCell()
        let data = try beginCell().storeUInt(2, bits: 8).endCell()
        let stateInit = StateInit(code: code, data: data)

        let address = try contractAddress(workchain: 0, init: stateInit)
        XCTAssertEqual(address.workchain, 0)
        XCTAssertEqual(address.hash, try stateInit.toCell().hash())

        let masterchain = try contractAddress(workchain: -1, init: stateInit)
        XCTAssertEqual(masterchain.workchain, -1)
        // Same state init, same hash — only the workchain differs.
        XCTAssertEqual(masterchain.hash, address.hash)
    }

    // MARK: - Address serialization

    /// `addr_std` is 267 bits: 2 tag + 1 anycast + 8 signed workchain + 256 hash.
    func testAddressSerializationWidth() throws {
        let builder = Builder()
        try builder.storeAddress(Self.dest)
        XCTAssertEqual(builder.bitCount, 267)
    }

    func testAddressNoneIsTwoZeroBits() throws {
        let builder = Builder()
        try builder.storeAddress(nil)
        XCTAssertEqual(builder.bitCount, 2)
        var slice = try builder.endCell().beginParse()
        XCTAssertNil(try slice.loadMaybeAddress())
    }

    /// Masterchain is workchain -1, which must serialize as 0xFF and read back signed.
    func testMasterchainAddressRoundTrip() throws {
        let mc = try Address.parseRaw(
            "-1:3333333333333333333333333333333333333333333333333333333333333333"
        )
        let builder = Builder()
        try builder.storeAddress(mc)
        var slice = try builder.endCell().beginParse()
        let parsed = try slice.loadAddress()
        XCTAssertEqual(parsed.workchain, -1)
        XCTAssertEqual(parsed, mc)
    }

    func testExternalAddressRoundTrip() throws {
        let external = ExternalAddress(value: BigUInt(0xdeadbeef), bitLength: 32)
        let builder = Builder()
        try builder.storeExternalAddress(external)
        var slice = try builder.endCell().beginParse()
        XCTAssertEqual(try slice.loadMaybeExternalAddress(), external)
    }
}
