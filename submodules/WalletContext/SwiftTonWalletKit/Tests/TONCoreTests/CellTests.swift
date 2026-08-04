import XCTest
import TONTestVectors
@testable import TONCore

/// Verifies Cell hashing and BoC serialization against golden vectors generated
/// from `@ton/core`.
final class CellTests: XCTestCase {
    struct CellVector: Decodable {
        let label: String
        let boc: String
        let bocPlain: String?
        let bocIdxCrc32: String?
        let hash: String
        let depth: Int
        let level: Int
        let isExotic: Bool
        let bitsLength: Int
        let bitsHex: String
        let refCount: Int
        /// Exotic vectors record whether @ton/core accepted the construction.
        let supported: Bool?
        let reason: String?
    }

    private func loadVectors(_ file: String, minimum: Int) throws -> [CellVector] {
        let loaded: [CellVector] = try Vectors.load(file)
        XCTAssertGreaterThanOrEqual(loaded.count, minimum, "\(file) lost cases")
        return loaded
    }

    // MARK: - Hashing

    func testCellHashesMatchReference() throws {
        for v in try loadVectors("boc.json", minimum: 13) {
            let data = try XCTUnwrap(Data(anyBase64: v.boc), v.label)
            let cell = try Cell.fromBoc(data)
            XCTAssertEqual(cell.hash().hexString, v.hash, "hash for \(v.label)")
        }
    }

    func testCellDepthsAndLevelsMatchReference() throws {
        for v in try loadVectors("boc.json", minimum: 13) {
            let cell = try Cell.fromBase64(v.boc)
            XCTAssertEqual(cell.depth(), v.depth, "depth for \(v.label)")
            XCTAssertEqual(cell.level(), v.level, "level for \(v.label)")
            XCTAssertEqual(cell.isExotic, v.isExotic, "isExotic for \(v.label)")
        }
    }

    func testCellPayloadMatchesReference() throws {
        for v in try loadVectors("boc.json", minimum: 13) {
            let cell = try Cell.fromBase64(v.boc)
            XCTAssertEqual(cell.bits.length, v.bitsLength, "bit length for \(v.label)")
            XCTAssertEqual(cell.bits.description, v.bitsHex, "bits for \(v.label)")
            XCTAssertEqual(cell.refs.count, v.refCount, "ref count for \(v.label)")
        }
    }

    /// The canonical empty-cell hash, independent of any vector file.
    func testEmptyCellKnownHash() throws {
        XCTAssertEqual(
            Cell.empty.hash().hexString,
            "96a296d224f285c67bee93c30f8a309157f0daa35dc5b87e410b78630a09cfc7"
        )
        XCTAssertEqual(Cell.empty.depth(), 0)
        XCTAssertEqual(Cell.empty.level(), 0)
    }

    /// The published WalletV5R1 code hash, independent of any vector file.
    func testWalletV5R1CodeHash() throws {
        let v = try loadVectors("boc.json", minimum: 13).first { $0.label == "wallet-v5r1-code" }
        let cell = try Cell.fromBase64(try XCTUnwrap(v).boc)
        XCTAssertEqual(
            cell.hash().hexString,
            "20834b7b72b112147e1b2fb457b84e74d1a30f04f737d4f62a668e9552d2b72f"
        )
    }

    // MARK: - Descriptors

    func testBitsDescriptorEncodesPartialFinalByte() {
        // Byte-aligned payloads produce an even descriptor, partial ones an odd descriptor.
        XCTAssertEqual(Cell.bitsDescriptor(bitLength: 0), 0)
        XCTAssertEqual(Cell.bitsDescriptor(bitLength: 8), 2)
        XCTAssertEqual(Cell.bitsDescriptor(bitLength: 16), 4)
        XCTAssertEqual(Cell.bitsDescriptor(bitLength: 1), 1)
        XCTAssertEqual(Cell.bitsDescriptor(bitLength: 7), 1)
        XCTAssertEqual(Cell.bitsDescriptor(bitLength: 9), 3)
        XCTAssertEqual(Cell.bitsDescriptor(bitLength: 1023), 255)
    }

    func testRefsDescriptorEncodesExoticAndLevel() {
        XCTAssertEqual(Cell.refsDescriptor(refCount: 0, levelMask: 0, type: .ordinary), 0)
        XCTAssertEqual(Cell.refsDescriptor(refCount: 4, levelMask: 0, type: .ordinary), 4)
        // Exotic sets bit 3.
        XCTAssertEqual(Cell.refsDescriptor(refCount: 0, levelMask: 0, type: .library), 8)
        // The level mask occupies the top three bits.
        XCTAssertEqual(Cell.refsDescriptor(refCount: 0, levelMask: 1, type: .ordinary), 32)
        XCTAssertEqual(Cell.refsDescriptor(refCount: 1, levelMask: 1, type: .prunedBranch), 1 + 8 + 32)
    }

    // MARK: - BoC round trips

    /// Re-serializing must reproduce the reference bytes exactly, for all three
    /// flag combinations.
    func testBocSerializationMatchesReferenceBytes() throws {
        for v in try loadVectors("boc.json", minimum: 13) {
            let cell = try Cell.fromBase64(v.boc)

            XCTAssertEqual(
                cell.toBoc(idx: false, crc32: true).base64EncodedString(),
                v.boc,
                "default boc for \(v.label)"
            )
            if let plain = v.bocPlain {
                XCTAssertEqual(
                    cell.toBoc(idx: false, crc32: false).base64EncodedString(),
                    plain,
                    "plain boc for \(v.label)"
                )
            }
            if let idxCrc = v.bocIdxCrc32 {
                XCTAssertEqual(
                    cell.toBoc(idx: true, crc32: true).base64EncodedString(),
                    idxCrc,
                    "idx+crc32 boc for \(v.label)"
                )
            }
        }
    }

    /// Every encoding variant must parse back to the same cell.
    func testAllBocVariantsParseToSameCell() throws {
        for v in try loadVectors("boc.json", minimum: 13) {
            let fromDefault = try Cell.fromBase64(v.boc)
            if let plain = v.bocPlain {
                XCTAssertEqual(try Cell.fromBase64(plain).hash(), fromDefault.hash(), v.label)
            }
            if let idxCrc = v.bocIdxCrc32 {
                XCTAssertEqual(try Cell.fromBase64(idxCrc).hash(), fromDefault.hash(), v.label)
            }
        }
    }

    /// A shared subtree must be emitted once, not duplicated.
    func testSharedSubtreeIsDeduplicated() throws {
        let v = try loadVectors("boc.json", minimum: 13).first { $0.label == "shared-subtree" }
        let cell = try Cell.fromBase64(try XCTUnwrap(v).boc)
        XCTAssertEqual(cell.refs.count, 2)
        XCTAssertEqual(cell.refs[0].hash(), cell.refs[1].hash())
        // Root plus one deduplicated child.
        XCTAssertEqual(BoC.topologicalSort(cell).count, 2)
    }

    func testCrcMismatchIsRejected() throws {
        let v = try loadVectors("boc.json", minimum: 13).first { $0.label == "four-refs" }
        var data = try XCTUnwrap(Data(anyBase64: try XCTUnwrap(v).boc))
        // Corrupt the CRC-32C trailer.
        data[data.count - 1] ^= 0xff
        XCTAssertThrowsError(try Cell.fromBoc(data)) { error in
            guard case BoC.BoCError.crcMismatch = error else {
                return XCTFail("expected crcMismatch, got \(error)")
            }
        }
    }

    func testInvalidMagicIsRejected() {
        let data = Data([0xde, 0xad, 0xbe, 0xef, 0x00, 0x00])
        XCTAssertThrowsError(try Cell.fromBoc(data)) { error in
            guard case BoC.BoCError.invalidMagic = error else {
                return XCTFail("expected invalidMagic, got \(error)")
            }
        }
    }

    func testTruncatedBocIsRejected() throws {
        let v = try loadVectors("boc.json", minimum: 13).first { $0.label == "depth-10-chain" }
        let data = try XCTUnwrap(Data(anyBase64: try XCTUnwrap(v).boc))
        // Every proper prefix must fail rather than yield a partial cell.
        for cut in 1..<data.count {
            XCTAssertThrowsError(try Cell.fromBoc(data.prefix(cut)), "prefix of length \(cut)")
        }
    }

    // MARK: - Exotic cells

    /// Pruned branches, library cells and merkle proofs all appear in real data, so
    /// level-mask handling has to be right, not just ordinary cells.
    func testExoticCellsMatchReference() throws {
        let vectors = try loadVectors("boc-exotic.json", minimum: 6)
        var checked = 0
        for v in vectors where v.supported == true {
            let cell = try Cell.fromBase64(v.boc)
            XCTAssertEqual(cell.isExotic, v.isExotic, "isExotic for \(v.label)")
            XCTAssertEqual(cell.hash().hexString, v.hash, "hash for \(v.label)")
            XCTAssertEqual(cell.depth(), v.depth, "depth for \(v.label)")
            XCTAssertEqual(cell.level(), v.level, "level for \(v.label)")
            XCTAssertEqual(
                cell.toBoc().base64EncodedString(),
                v.boc,
                "re-serialization for \(v.label)"
            )
            checked += 1
        }
        XCTAssertEqual(checked, 6, "every exotic case should be exercised")
    }

    /// The only case that exercises the merkle child-level bump
    /// (`ref.hash(level + 1)` rather than `ref.hash(level)`).
    ///
    /// With a level-0 subtree all four stored hashes coincide and the bump is
    /// invisible — verified by mutation: removing it left a level-0-only suite green.
    func testMerkleProofOverPrunedSubtreeExercisesChildLevelBump() throws {
        let v = try loadVectors("boc-exotic.json", minimum: 6)
            .first { $0.label == "merkle-proof-over-pruned" }
        let unwrapped = try XCTUnwrap(v)
        let cell = try Cell.fromBase64(unwrapped.boc)

        XCTAssertEqual(cell.type, .merkleProof)
        XCTAssertEqual(cell.hash().hexString, unwrapped.hash)

        // The proved subtree must genuinely have level > 0, otherwise this test is
        // no stronger than the plain merkle-proof case.
        let proved = cell.refs[0]
        XCTAssertEqual(proved.level(), 1, "proved subtree must be level 1")
        XCTAssertNotEqual(
            proved.hash(level: 0),
            proved.hash(level: 1),
            "level 0 and 1 hashes must differ for the bump to be observable"
        )
    }

    func testOrdinaryCellInheritsLevelFromPrunedChild() throws {
        let v = try loadVectors("boc-exotic.json", minimum: 6)
            .first { $0.label == "ordinary-with-pruned-child" }
        let cell = try Cell.fromBase64(try XCTUnwrap(v).boc)
        // Not exotic itself, but the level mask propagates up from the pruned child.
        XCTAssertFalse(cell.isExotic)
        XCTAssertEqual(cell.level(), 1)
        XCTAssertEqual(cell.refs[0].type, .prunedBranch)
    }

    func testMerkleUpdateValidatesBothRefs() throws {
        let v = try loadVectors("boc-exotic.json", minimum: 6).first { $0.label == "merkle-update" }
        let cell = try Cell.fromBase64(try XCTUnwrap(v).boc)
        XCTAssertEqual(cell.type, .merkleUpdate)
        XCTAssertEqual(cell.refs.count, 2)

        // Swapping the two refs invalidates both recorded hashes.
        XCTAssertThrowsError(
            try Cell(bits: cell.bits, refs: [cell.refs[1], cell.refs[0]], exotic: true)
        )
    }

    func testPrunedBranchCarriesHigherLevelHashes() throws {
        let v = try loadVectors("boc-exotic.json", minimum: 3)
            .first { $0.label == "pruned-branch-level-1" }
        let cell = try Cell.fromBase64(try XCTUnwrap(v).boc)
        XCTAssertEqual(cell.type, .prunedBranch)
        XCTAssertEqual(cell.level(), 1)
        // Level 0 is the cell's own representation hash; level 1 comes from the payload.
        XCTAssertNotEqual(cell.hash(level: 0), cell.hash(level: 1))
    }

    func testMerkleProofValidatesAgainstItsRef() throws {
        let v = try loadVectors("boc-exotic.json", minimum: 3).first { $0.label == "merkle-proof" }
        let cell = try Cell.fromBase64(try XCTUnwrap(v).boc)
        XCTAssertEqual(cell.type, .merkleProof)
        XCTAssertEqual(cell.refs.count, 1)

        // Swapping in a different ref must fail validation rather than hash silently.
        let wrongRef = try Cell(bits: BitString(Data([0x00])))
        XCTAssertThrowsError(try Cell(bits: cell.bits, refs: [wrongRef], exotic: true))
    }

    func testUnknownExoticTypeIsRejected() throws {
        var builder = BitBuilder()
        builder.write(uint: 99, bits: 8)
        builder.write(bytes: Data(repeating: 0, count: 32))
        XCTAssertThrowsError(try Cell(bits: builder.build(), exotic: true)) { error in
            guard case Cell.CellError.unknownExoticType(99) = error else {
                return XCTFail("expected unknownExoticType(99), got \(error)")
            }
        }
    }

    // MARK: - Limits

    func testRejectsOversizedPayload() {
        var builder = BitBuilder(capacity: 1100)
        for _ in 0..<1024 { builder.write(bit: true) }
        XCTAssertThrowsError(try Cell(bits: builder.build())) { error in
            guard case Cell.CellError.tooManyBits(1024) = error else {
                return XCTFail("expected tooManyBits(1024), got \(error)")
            }
        }
    }

    func testRejectsTooManyRefs() throws {
        let child = Cell.empty
        XCTAssertThrowsError(try Cell(refs: Array(repeating: child, count: 5))) { error in
            guard case Cell.CellError.tooManyRefs(5) = error else {
                return XCTFail("expected tooManyRefs(5), got \(error)")
            }
        }
    }

    func testAcceptsExactlyMaxBitsAndRefs() throws {
        var builder = BitBuilder(capacity: 1023)
        for _ in 0..<1023 { builder.write(bit: true) }
        let cell = try Cell(bits: builder.build(), refs: Array(repeating: Cell.empty, count: 4))
        XCTAssertEqual(cell.bits.length, 1023)
        XCTAssertEqual(cell.refs.count, 4)
    }
}
