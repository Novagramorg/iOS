import XCTest
import TONTestVectors
import TONCore
@testable import TONCrypto

/// Verifies the two hashing schemes whose byte layouts disagree with each other.
///
/// `tonProof` uses little-endian for domain length and timestamp; `signData` uses
/// big-endian for the same conceptual fields. Both are hash-only, so unlike signing
/// these are exactly byte-comparable against the reference.
final class TonProofTests: XCTestCase {
    struct ProofVector: Decodable {
        let label: String
        let workchain: Int32
        let addressHash: String
        let domain: DomainVector
        let payload: String
        let timestamp: UInt64
        let messageHash: String
        let signature: String
        let derivedFrom: String
        let referenceThrows: Bool

        struct DomainVector: Decodable {
            let lengthBytes: UInt32
            let value: String
        }
    }

    private func vectors() throws -> [ProofVector] {
        let loaded: [ProofVector] = try Vectors.load("tonproof.json")
        XCTAssertGreaterThanOrEqual(loaded.count, 4, "tonproof.json lost cases")
        return loaded
    }

    private func message(from v: ProofVector) throws -> TonProof.Message {
        TonProof.Message(
            workchain: v.workchain,
            addressHash: try XCTUnwrap(Data.fromVectorHex(v.addressHash)),
            domain: TonProof.Domain(value: v.domain.value, lengthBytes: v.domain.lengthBytes),
            timestamp: v.timestamp,
            payload: v.payload
        )
    }

    func testMessageBytesMatchReference() throws {
        for v in try vectors() {
            let computed = TonProof.messageBytes(try message(from: v))
            XCTAssertEqual(
                computed.hexString,
                v.messageHash,
                "proof message for \(v.label) (derivedFrom: \(v.derivedFrom))"
            )
        }
    }

    /// Masterchain is the deliberate divergence: the reference throws there, we follow
    /// the spec and encode a signed int32. Both must be represented.
    func testCoversBothProvenanceKinds() throws {
        let all = try vectors()
        let agreeing = all.filter { $0.derivedFrom == "reference-and-spec-agree" }
        let specOnly = all.filter { $0.derivedFrom == "spec-only" }

        XCTAssertGreaterThanOrEqual(agreeing.count, 3, "no cases cross-checked against the reference")
        XCTAssertEqual(specOnly.count, 1, "expected exactly the masterchain case to be spec-only")
        XCTAssertTrue(specOnly.allSatisfy { $0.referenceThrows })
        XCTAssertTrue(agreeing.allSatisfy { !$0.referenceThrows })
    }

    /// The whole point of the divergence: masterchain must produce a proof, not throw.
    func testMasterchainProducesAProof() throws {
        let v = try XCTUnwrap(try vectors().first { $0.workchain == -1 })
        let bytes = TonProof.messageBytes(try message(from: v))
        XCTAssertEqual(bytes.count, 32)
        XCTAssertEqual(bytes.hexString, v.messageHash)
    }

    /// Workchain 0 encodes identically signed or unsigned, which is why the divergence
    /// is safe for every real wallet.
    func testWorkchainZeroIsUnaffectedBySignedness() throws {
        let base = try XCTUnwrap(try vectors().first { $0.workchain == 0 })
        var msg = try message(from: base)
        msg.workchain = 0
        XCTAssertEqual(TonProof.messageBytes(msg).hexString, base.messageHash)
    }

    /// `lengthBytes` is a UTF-8 byte count, which differs from character count for
    /// any non-ASCII domain.
    func testUnicodeDomainLengthIsByteCount() throws {
        let domain = TonProof.Domain(value: "пример.рф")
        XCTAssertEqual(domain.lengthBytes, UInt32(Data("пример.рф".utf8).count))
        XCTAssertNotEqual(Int(domain.lengthBytes), "пример.рф".count, "byte and character counts must differ here")
    }

    func testSignAndVerifyRoundTrip() throws {
        let v = try XCTUnwrap(try vectors().first)
        let msg = try message(from: v)
        let pair = try Ed25519.keyPair(fromSeed: Data(repeating: 0, count: 32))

        let signature = try TonProof.sign(msg, secretKey: pair.secretKey)
        XCTAssertTrue(try TonProof.verify(msg, signature: signature, publicKey: pair.publicKey))

        // A different payload must not verify under the same signature.
        var tampered = msg
        tampered.payload += "!"
        XCTAssertFalse(try TonProof.verify(tampered, signature: signature, publicKey: pair.publicKey))
    }

    /// The reference's signature (made with the deterministic signer) must still
    /// verify under our verifier — which proves our message bytes are right even
    /// though we cannot reproduce its signature bytes.
    func testReferenceSignatureVerifies() throws {
        let pair = try Ed25519.keyPair(fromSeed: Data(repeating: 0, count: 32))
        for v in try vectors() {
            let signature = try XCTUnwrap(Data.fromVectorHex(v.signature))
            XCTAssertTrue(
                try TonProof.verify(try message(from: v), signature: signature, publicKey: pair.publicKey),
                "reference proof signature rejected for \(v.label)"
            )
        }
    }
}

final class SignDataTests: XCTestCase {
    struct SignDataVectors: Decodable {
        let textBinary: [TextBinary]
        let cell: [CellCase]

        struct TextBinary: Decodable {
            let label: String
            let payloadType: String
            let content: String
            let address: String
            let workchain: Int
            let domain: String
            let timestamp: UInt64
            let hash: String
        }

        struct CellCase: Decodable {
            let label: String
            let schema: String
            let schemaCrc32: UInt32
            let payloadBoc: String
            let address: String
            let domain: String
            let tep81Domain: String
            let timestamp: UInt64
            let hash: String
        }
    }

    private func vectors() throws -> SignDataVectors {
        let loaded: SignDataVectors = try Vectors.load("signdata.json")
        XCTAssertGreaterThanOrEqual(loaded.textBinary.count, 7, "signdata.json lost text/binary cases")
        XCTAssertGreaterThanOrEqual(loaded.cell.count, 4, "signdata.json lost cell cases")
        return loaded
    }

    func testTextAndBinaryHashesMatchReference() throws {
        for v in try vectors().textBinary {
            let address = try Address.parseRaw(v.address)
            let payload: SignData.Payload = v.payloadType == "text"
                ? .text(v.content)
                : .binary(Data(anyBase64: v.content) ?? Data())

            let hash = try SignData.textBinaryHash(
                payload: payload,
                address: address,
                domain: v.domain,
                timestamp: v.timestamp
            )
            XCTAssertEqual(hash.hexString, v.hash, "hash for \(v.label)")
        }
    }

    func testCellHashesMatchReference() throws {
        for v in try vectors().cell {
            let address = try Address.parseRaw(v.address)
            let cell = try Cell.fromBase64(v.payloadBoc)

            let hash = try SignData.cellHash(
                schema: v.schema,
                cell: cell,
                address: address,
                domain: v.domain,
                timestamp: v.timestamp
            )
            XCTAssertEqual(hash.hexString, v.hash, "cell hash for \(v.label)")
        }
    }

    /// The schema string is hashed with crc32, not sha256.
    func testSchemaCRC32MatchesReference() throws {
        for v in try vectors().cell {
            XCTAssertEqual(
                CRC.crc32(Data(v.schema.utf8)),
                v.schemaCrc32,
                "schema crc32 for \(v.label)"
            )
        }
    }

    /// TEP-81: labels reversed, NUL-separated, trailing NUL. So `a.b.c` -> `c\0b\0a\0`.
    func testTEP81DomainEncodingMatchesReference() throws {
        for v in try vectors().cell {
            let encoded = v.domain.split(separator: ".", omittingEmptySubsequences: false)
                .reversed()
                .joined(separator: "\0") + "\0"
            XCTAssertEqual(
                Data(encoded.utf8).hexString,
                v.tep81Domain,
                "TEP-81 domain for \(v.label)"
            )
        }
    }

    /// signData is big-endian where tonProof is little-endian. If the two ever
    /// converge, one of them is wrong.
    func testSignDataAndTonProofDisagreeOnEndianness() throws {
        let address = try Address.parseRaw(
            "0:83dfd552e63729b472fcbcc8c45ebcc6691702558b68ec7527e1ba403a0f31a8"
        )
        let domain = "example.com"
        let timestamp: UInt64 = 1_700_000_000

        let signDataHash = try SignData.textBinaryHash(
            payload: .text(""),
            address: address,
            domain: domain,
            timestamp: timestamp
        )
        let proofHash = TonProof.messageBytes(
            TonProof.Message(
                address: address,
                domain: TonProof.Domain(value: domain),
                timestamp: timestamp,
                payload: ""
            )
        )
        XCTAssertNotEqual(signDataHash, proofHash, "the two schemes must not coincide")
    }

    /// Masterchain has a negative workchain, which signData writes as a *signed*
    /// int32 — unlike the reference's tonProof path.
    func testMasterchainSignDataUsesSignedWorkchain() throws {
        let v = try XCTUnwrap(
            try vectors().textBinary.first { $0.workchain == -1 },
            "no masterchain signData vector"
        )
        let address = try Address.parseRaw(v.address)
        let hash = try SignData.textBinaryHash(
            payload: .text(v.content),
            address: address,
            domain: v.domain,
            timestamp: v.timestamp
        )
        XCTAssertEqual(hash.hexString, v.hash)
    }

    func testDispatchingHashMatchesDirectCalls() throws {
        let all = try vectors()
        for v in all.textBinary {
            let address = try Address.parseRaw(v.address)
            let payload: SignData.Payload = v.payloadType == "text"
                ? .text(v.content)
                : .binary(Data(anyBase64: v.content) ?? Data())
            let dispatched = try SignData.hash(
                payload: payload,
                address: address,
                domain: v.domain,
                timestamp: v.timestamp
            )
            XCTAssertEqual(dispatched.hexString, v.hash, "dispatched hash for \(v.label)")
        }
        for v in all.cell {
            let address = try Address.parseRaw(v.address)
            let dispatched = try SignData.hash(
                payload: .cell(schema: v.schema, cell: try Cell.fromBase64(v.payloadBoc)),
                address: address,
                domain: v.domain,
                timestamp: v.timestamp
            )
            XCTAssertEqual(dispatched.hexString, v.hash, "dispatched cell hash for \(v.label)")
        }
    }

    func testCellPayloadRejectsTextBinaryHash() throws {
        XCTAssertThrowsError(
            try SignData.textBinaryHash(
                payload: .cell(schema: "x#_ = X;", cell: Cell.empty),
                address: Address.zero(),
                domain: "a.b",
                timestamp: 0
            )
        )
    }
}

final class WalletIDTests: XCTestCase {
    struct WalletIDVector: Decodable {
        let chainId: String
        let address: String
        let preimage: String
        let walletId: String
    }

    func testWalletIDMatchesReference() throws {
        let vectors: [WalletIDVector] = try Vectors.load("walletid.json")
        XCTAssertGreaterThanOrEqual(vectors.count, 9)

        for v in vectors {
            XCTAssertEqual(v.preimage, "\(v.chainId):\(v.address)", "preimage shape")
            XCTAssertEqual(
                WalletID.make(chainId: v.chainId, address: v.address),
                v.walletId,
                "wallet id for \(v.chainId)/\(v.address.prefix(12))"
            )
        }
    }

    /// The same address on two networks must not collide — that is the whole purpose.
    func testDifferentNetworksProduceDifferentIDs() {
        let address = "EQCD39VS5jcptHL8vMjEXrzGaRcCVYto7HUn4bpAOg8xqB2N"
        XCTAssertNotEqual(
            WalletID.make(chainId: "-239", address: address),
            WalletID.make(chainId: "-3", address: address)
        )
    }
}
