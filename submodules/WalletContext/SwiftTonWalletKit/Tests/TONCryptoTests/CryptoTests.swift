import XCTest
import TONTestVectors
import TONCore
@testable import TONCrypto

/// Verifies hashing, key derivation and signing against golden vectors.
final class HashingTests: XCTestCase {
    struct SHA256Vector: Decodable {
        let input: String
        let inputHex: String
        let sha256: String
    }

    func testSHA256MatchesReference() throws {
        let vectors: [SHA256Vector] = try Vectors.load("sha256.json")
        XCTAssertGreaterThanOrEqual(vectors.count, 4)
        for v in vectors {
            let data = Data(hexString: v.inputHex) ?? Data()
            XCTAssertEqual(Hashing.sha256(data).hexString, v.sha256, "sha256 of \(v.input.prefix(20))")
        }
    }

    /// Published NIST vectors, independent of the generated ones.
    func testSHA256KnownVectors() {
        XCTAssertEqual(
            Hashing.sha256(Data()).hexString,
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        )
        XCTAssertEqual(
            Hashing.sha256(Data("abc".utf8)).hexString,
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
    }

    func testSHA512KnownVector() {
        XCTAssertEqual(
            Hashing.sha512(Data("abc".utf8)).hexString,
            "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a"
                + "2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f"
        )
    }

    /// RFC 4231 test case 1.
    func testHMACSHA512KnownVector() {
        let key = Data(repeating: 0x0b, count: 20)
        let data = Data("Hi There".utf8)
        XCTAssertEqual(
            Hashing.hmacSHA512(key: key, data: data).hexString,
            "87aa7cdea5ef619d4ff0b4241a1d6cb02379f4e2ce4ec2787ad0b30545e17cde"
                + "daa833b7d6b8a702038b274eaea3f4e4be9d914eeb61f1702e696c203a126854"
        )
    }

    /// RFC 6070-style check adapted to SHA-512.
    func testPBKDF2SHA512KnownVector() throws {
        let derived = try Hashing.pbkdf2SHA512(
            password: Data("password".utf8),
            salt: "salt",
            iterations: 1,
            keyLength: 64
        )
        XCTAssertEqual(
            derived.hexString,
            "867f70cf1ade02cff3752599a3a53dc4af34c7a669815ae5d513554e1c8cf252"
                + "c02d470a285a0501bad999bfe943c08f050235d7d68b1da55e63f73b60a57fce"
        )
    }

    func testSecureRandomBytesLength() throws {
        for count in [0, 1, 32, 64, 1000] {
            XCTAssertEqual(try Hashing.secureRandomBytes(count).count, count)
        }
    }

    /// Rejection sampling must stay in range and cover the space.
    func testSecureRandomIntIsInRangeAndSpread() throws {
        var seen = Set<Int>()
        for _ in 0..<500 {
            let value = try Hashing.secureRandomInt(upperBound: 2048)
            XCTAssertTrue(value >= 0 && value < 2048)
            seen.insert(value)
        }
        XCTAssertGreaterThan(seen.count, 200, "distribution looks degenerate")
    }

    func testSecureRandomIntHandlesTrivialBound() throws {
        XCTAssertEqual(try Hashing.secureRandomInt(upperBound: 1), 0)
    }
}

final class Ed25519Tests: XCTestCase {
    struct KeyPairVector: Decodable {
        let seedIndex: Int
        let seed: String
        let publicKey: String
        let secretKey: String
    }

    struct SignatureVector: Decodable {
        let seedIndex: Int
        let publicKey: String
        let message: String
        let messageHex: String
        let signature: String
        let signatureFromSeed: String
        let fakeSignature: String
    }

    func testKeyPairFromSeedMatchesReference() throws {
        let vectors: [KeyPairVector] = try Vectors.load("keypairs.json")
        XCTAssertGreaterThanOrEqual(vectors.count, 10)

        for v in vectors {
            let seed = try XCTUnwrap(Data(hexString: v.seed))
            let pair = try Ed25519.keyPair(fromSeed: seed)
            XCTAssertEqual(pair.publicKey.hexString, v.publicKey, "public key for seed \(v.seedIndex)")
            XCTAssertEqual(pair.secretKey.hexString, v.secretKey, "secret key for seed \(v.seedIndex)")
        }
    }

    /// The NaCl secret-key layout is `seed ‖ publicKey`, so it round-trips.
    func testKeyPairFromSecretKeyRecoversSeed() throws {
        let vectors: [KeyPairVector] = try Vectors.load("keypairs.json")
        for v in vectors {
            let secretKey = try XCTUnwrap(Data(hexString: v.secretKey))
            let pair = try Ed25519.keyPair(fromSecretKey: secretKey)
            XCTAssertEqual(pair.seed.hexString, v.seed)
            XCTAssertEqual(pair.publicKey.hexString, v.publicKey)
        }
    }

    /// Signatures must match the reference **byte for byte**.
    ///
    /// Achievable because the default provider is vendored TweetNaCl — the same
    /// implementation `@ton/crypto` uses — which is RFC 8032 deterministic. CryptoKit
    /// was rejected for this role precisely because its signing is randomized.
    ///
    /// Vectors carry walletkit's `Hex` type, which is `0x`-prefixed, so comparisons go
    /// through `Data.fromVectorHex` rather than string equality.
    func testSignaturesMatchReference() throws {
        let vectors: [SignatureVector] = try Vectors.load("signatures.json")
        let keypairs: [KeyPairVector] = try Vectors.load("keypairs.json")
        XCTAssertGreaterThanOrEqual(vectors.count, 9)

        for v in vectors {
            let data = Data(hexString: v.messageHex) ?? Data()
            let keypair = try XCTUnwrap(
                keypairs.first { $0.seedIndex == v.seedIndex },
                "no keypair for seed index \(v.seedIndex)"
            )
            let secretKey = try XCTUnwrap(Data(hexString: keypair.secretKey))
            let label = "\(v.message.isEmpty ? "<empty>" : String(v.message.prefix(16)))/seed\(v.seedIndex)"

            XCTAssertEqual(
                try Ed25519.sign(data, secretKey: secretKey),
                Data.fromVectorHex(v.signature),
                "signature for \(label)"
            )

            // Signing with the bare 32-byte seed must give the same result, because a
            // NaCl secret key is seed ‖ publicKey.
            XCTAssertEqual(
                try Ed25519.sign(data, secretKey: Data(secretKey.prefix(32))),
                Data.fromVectorHex(v.signatureFromSeed),
                "seed-signed signature for \(label)"
            )

            XCTAssertEqual(
                try Ed25519.fakeSignature(data),
                Data.fromVectorHex(v.fakeSignature),
                "fake signature for \(label)"
            )
        }
    }

    /// Reference signatures must also verify under our verifier — the other direction.
    func testReferenceSignaturesVerify() throws {
        let vectors: [SignatureVector] = try Vectors.load("signatures.json")
        for v in vectors {
            let data = Data(hexString: v.messageHex) ?? Data()
            let publicKey = try XCTUnwrap(Data.fromVectorHex(v.publicKey))
            let signature = try XCTUnwrap(Data.fromVectorHex(v.signature))
            XCTAssertTrue(
                try Ed25519.verify(signature: signature, data: data, publicKey: publicKey),
                "reference signature rejected for seed \(v.seedIndex)"
            )
        }
    }

    /// The property the whole provider seam exists to guarantee. If this fails, the
    /// active provider is randomized and reproducible emulation is broken.
    func testSigningIsDeterministic() throws {
        XCTAssertTrue(try Ed25519.isDeterministic())

        let seed = Data(repeating: 3, count: 32)
        let message = Data("determinism probe".utf8)
        var signatures = Set<Data>()
        for _ in 0..<5 {
            signatures.insert(try Ed25519.sign(message, secretKey: seed))
        }
        XCTAssertEqual(signatures.count, 1, "signing is not deterministic")
    }

    func testVerifyRejectsTamperedSignature() throws {
        let pair = try Ed25519.keyPair(fromSeed: Data(repeating: 7, count: 32))
        let data = Data("hello".utf8)
        var signature = try Ed25519.sign(data, secretKey: pair.secretKey)
        signature[0] ^= 0xff
        XCTAssertFalse(try Ed25519.verify(signature: signature, data: data, publicKey: pair.publicKey))
    }

    func testVerifyRejectsTamperedMessage() throws {
        let pair = try Ed25519.keyPair(fromSeed: Data(repeating: 7, count: 32))
        let signature = try Ed25519.sign(Data("hello".utf8), secretKey: pair.secretKey)
        XCTAssertFalse(
            try Ed25519.verify(signature: signature, data: Data("hellp".utf8), publicKey: pair.publicKey)
        )
    }

    func testRejectsMalformedKeyLengths() {
        XCTAssertThrowsError(try Ed25519.keyPair(fromSeed: Data(repeating: 0, count: 31)))
        XCTAssertThrowsError(try Ed25519.keyPair(fromSecretKey: Data(repeating: 0, count: 63)))
        XCTAssertThrowsError(try Ed25519.sign(Data(), secretKey: Data(repeating: 0, count: 33)))
    }
}

final class MnemonicTests: XCTestCase {
    struct MnemonicVector: Decodable {
        let scheme: String
        let wordCount: Int
        let mnemonic: String
        let publicKey: String
        let secretKey: String
        let derivationPath: [UInt32]?
    }

    private func vectors() throws -> [MnemonicVector] {
        let loaded: [MnemonicVector] = try Vectors.load("mnemonic.json")
        XCTAssertGreaterThanOrEqual(loaded.count, 7, "mnemonic.json lost cases")
        return loaded
    }

    func testTONMnemonicDerivationMatchesReference() throws {
        let ton = try vectors().filter { $0.scheme == "ton" }
        XCTAssertGreaterThanOrEqual(ton.count, 4)

        for v in ton {
            let pair = try Mnemonic.keyPair(from: v.mnemonic.split(separator: " ").map(String.init))
            XCTAssertEqual(pair.publicKey.hexString, v.publicKey, "public key for \(v.mnemonic.prefix(24))")
            XCTAssertEqual(pair.secretKey.hexString, v.secretKey, "secret key for \(v.mnemonic.prefix(24))")
        }
    }

    func testBIP39DerivationMatchesReference() throws {
        let bip39 = try vectors().filter { $0.scheme == "bip39" }
        XCTAssertGreaterThanOrEqual(bip39.count, 3)

        for v in bip39 {
            XCTAssertEqual(v.derivationPath, [44, 607, 0], "unexpected derivation path")
            let pair = try BIP39.keyPair(from: v.mnemonic.split(separator: " ").map(String.init))
            XCTAssertEqual(pair.publicKey.hexString, v.publicKey, "public key for \(v.mnemonic.prefix(24))")
            XCTAssertEqual(pair.secretKey.hexString, v.secretKey, "secret key for \(v.mnemonic.prefix(24))")
        }
    }

    /// The two schemes must not be interchangeable — that would be a silent
    /// wrong-wallet bug.
    func testTONAndBIP39DeriveDifferentKeys() throws {
        let words = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
            .split(separator: " ").map(String.init)
        let ton = try Mnemonic.keyPair(from: words)
        let bip39 = try BIP39.keyPair(from: words)
        XCTAssertNotEqual(ton.publicKey, bip39.publicKey)
    }

    func testWordlistIsIntact() {
        XCTAssertEqual(MnemonicWordlist.words.count, 2048)
        XCTAssertEqual(MnemonicWordlist.words.first, "abandon")
        XCTAssertEqual(MnemonicWordlist.words.last, "zoo")
        XCTAssertEqual(MnemonicWordlist.index(of: "abandon"), 0)
        XCTAssertNil(MnemonicWordlist.index(of: "notaword"))
        // Sorted, so the list can be binary-searched and diffed reliably.
        XCTAssertEqual(MnemonicWordlist.words, MnemonicWordlist.words.sorted())
    }

    func testRejectsWrongWordCount() {
        XCTAssertThrowsError(try Mnemonic.keyPair(from: ["abandon"]))
        XCTAssertThrowsError(try Mnemonic.keyPair(from: Array(repeating: "abandon", count: 13)))
    }

    func testNormalizationIsCaseAndWhitespaceInsensitive() throws {
        let v = try XCTUnwrap(try vectors().first { $0.scheme == "ton" })
        let words = v.mnemonic.split(separator: " ").map(String.init)
        let messy = words.enumerated().map { i, w in i % 2 == 0 ? "  \(w.uppercased()) " : w }
        XCTAssertEqual(
            try Mnemonic.keyPair(from: messy).publicKey.hexString,
            v.publicKey
        )
    }

    /// Validation is stricter than a wordlist check: entropy must pass the basic-seed
    /// test, which is what separates a TON mnemonic from arbitrary wordlist words.
    func testValidationRejectsWordlistWordsThatAreNotATONMnemonic() throws {
        XCTAssertFalse(try Mnemonic.validate(Array(repeating: "abandon", count: 24)))
    }

    func testValidationRejectsUnknownWords() throws {
        var words = Array(repeating: "abandon", count: 23)
        words.append("notaword")
        XCTAssertFalse(try Mnemonic.validate(words))
    }

    /// Generation is rejection-sampled, so this is deliberately expensive. Kept to a
    /// single round-trip: it proves generate → validate → derive is self-consistent.
    func testGenerationProducesValidMnemonic() throws {
        let words = try Mnemonic.generate(wordCount: 24)
        XCTAssertEqual(words.count, 24)
        XCTAssertTrue(words.allSatisfy(MnemonicWordlist.contains), "generated a non-wordlist word")
        XCTAssertTrue(try Mnemonic.validate(words), "generated mnemonic failed validation")

        // Deriving twice must give the same key.
        let a = try Mnemonic.keyPair(from: words)
        let b = try Mnemonic.keyPair(from: words)
        XCTAssertEqual(a.publicKey, b.publicKey)
    }

    func testGenerationRejectsBadWordCount() {
        XCTAssertThrowsError(try Mnemonic.generate(wordCount: 15))
    }

    /// Guards the performance claim in the plan: mnemonic generation must stay within
    /// a few seconds even on slower hardware.
    func testGenerationPerformanceIsAcceptable() throws {
        let start = Date()
        _ = try Mnemonic.generate(wordCount: 24)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 20.0, "generation took \(elapsed)s — investigate PBKDF2 path")
    }
}

final class SLIP10Tests: XCTestCase {
    /// SLIP-0010 test vector 1 for ed25519.
    func testMasterKeyKnownVector() throws {
        let seed = try XCTUnwrap(Data(hexString: "000102030405060708090a0b0c0d0e0f"))
        let master = SLIP10.masterKey(fromSeed: seed)
        XCTAssertEqual(
            master.key.hexString,
            "2b4be7f19ee27bbf30c667b642d5f4aa69fd169872f8fc3059c08ebae2eb19e7"
        )
        XCTAssertEqual(
            master.chainCode.hexString,
            "90046a93de5380a72b5e45010748567d5ea02bbf6522f979e05c0d8d8ca9fffb"
        )
    }

    /// SLIP-0010 ed25519, chain m/0'.
    func testHardenedDerivationKnownVector() throws {
        let seed = try XCTUnwrap(Data(hexString: "000102030405060708090a0b0c0d0e0f"))
        let derived = try SLIP10.deriveEd25519Path(seed: seed, path: [0])
        XCTAssertEqual(
            derived.key.hexString,
            "68e0fe46dfb67e368c75379acec591dad19df3cde26e63b93a8e704f1dade7a3"
        )
        XCTAssertEqual(
            derived.chainCode.hexString,
            "8b59aa11380b624e81507a27fedda59fea6d0b779a778918a2fd3590e16e9c69"
        )
    }

    /// Only hardened derivation exists for ed25519, so the offset is applied for the
    /// caller and an already-hardened index is a caller error.
    func testRejectsPreHardenedIndex() {
        let master = SLIP10.masterKey(fromSeed: Data(repeating: 1, count: 32))
        XCTAssertThrowsError(try SLIP10.deriveHardened(master, index: 0x8000_0000))
    }

    func testDerivationIsDeterministic() throws {
        let seed = Data(repeating: 42, count: 64)
        let a = try SLIP10.deriveEd25519Path(seed: seed, path: BIP39.tonDerivationPath)
        let b = try SLIP10.deriveEd25519Path(seed: seed, path: BIP39.tonDerivationPath)
        XCTAssertEqual(a, b)
    }

    func testDifferentPathsDiverge() throws {
        let seed = Data(repeating: 42, count: 64)
        let ton = try SLIP10.deriveEd25519Path(seed: seed, path: [44, 607, 0])
        let other = try SLIP10.deriveEd25519Path(seed: seed, path: [44, 607, 1])
        XCTAssertNotEqual(ton.key, other.key)
    }
}
