import XCTest
import TONCore
@testable import TONCrypto

/// BIP-39 and the TEP-0003 §3.3 rotation mnemonic.
///
/// Every expected value here comes from outside this codebase: the official BIP-39 English
/// test vectors, and the derived keys pinned in `wallet-engine`'s own test suite
/// (`src/wallet/crypto.rs::rotation_keys_match_the_reference_derivation`). Checking a
/// mnemonic implementation against itself proves nothing — the failure that matters is a
/// scheme that is self-consistent and disagrees with every other wallet, which shows up as
/// a user's phrase importing to the wrong address.
final class RotationMnemonicTests: XCTestCase {
    // MARK: - Word list

    /// BIP-39 indices are positions in this list, so a re-ordered or edited list silently
    /// shifts every word by some amount. `wallet-engine` pins the same digest.
    func testWordlistIsTheCanonicalBIP39EnglishList() {
        XCTAssertEqual(MnemonicWordlist.words.count, 2048)
        XCTAssertEqual(MnemonicWordlist.words, MnemonicWordlist.words.sorted())

        let joined = MnemonicWordlist.words.map { $0 + "\n" }.joined()
        XCTAssertEqual(
            Hashing.sha256(Data(joined.utf8)).hexString,
            "2f5eed53a4727b4bf8880d8f3f199efc90e58503646d9ff8eff3a2ed3b24dbda"
        )
    }

    // MARK: - BIP-39 checksum and seeds

    /// The three canonical vectors, entropy ↔ words ↔ seed (passphrase `"TREZOR"`).
    func testOfficialBIP39Vectors() throws {
        let vectors: [(entropy: String, words: String, seed: String)] = [
            ("00000000000000000000000000000000",
             "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about",
             "c55257c360c07c72029aebc1b53c05ed0362ada38ead3e3e9efa3708e53495531f09a6987599d18264c1e1c92f2cf141630c7a3c4ab7c81b2f001698e7463b04"),
            ("7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f",
             "legal winner thank year wave sausage worth useful legal winner thank yellow",
             "2e8905819b8723fe2c1d161860e5ee1830318dbf49a83bd451cfb8440c28bd6fa457fe1296106559a3c80937a1c1069be3a3a5bd381ee6260e8d9739fce1f607"),
            ("80808080808080808080808080808080",
             "letter advice cage absurd amount doctor acoustic avoid letter advice cage above",
             "d71de856f81a8acc65e6fc851a38d4d7ec216fd0796d0a6827a3ad6ed5511a30fa280f12eb2e47ed2ac03b5c462a0358d18d69fe4f985ec81778c1b370b652a8"),
        ]

        for v in vectors {
            let words = v.words.split(separator: " ").map(String.init)
            let entropy = try XCTUnwrap(Data(hexString: v.entropy))

            XCTAssertEqual(try BIP39.entropy(from: words), entropy, v.words)
            XCTAssertEqual(try BIP39.mnemonic(fromEntropy: entropy), words, v.words)
            XCTAssertEqual(
                try BIP39.seed(from: words, passphrase: "TREZOR").hexString, v.seed, v.words
            )
        }
    }

    /// The rotation scheme uses no passphrase, which is a different seed entirely.
    func testPassphraselessSeedDiffersFromTheTrezorVector() throws {
        let words = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
            .split(separator: " ").map(String.init)
        XCTAssertNotEqual(
            try BIP39.seed(from: words).hexString,
            try BIP39.seed(from: words, passphrase: "TREZOR").hexString
        )
    }

    func testRejectsBadChecksumsLengthsAndWords() {
        // `about` -> `abandon` in the last position breaks only the checksum.
        let bad = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon"
        XCTAssertFalse(BIP39.validate(bad.split(separator: " ").map(String.init)))
        XCTAssertFalse(BIP39.validate(Array(repeating: "abandon", count: 11)))
        XCTAssertFalse(BIP39.validate(["notaword"] + Array(repeating: "abandon", count: 11)))
    }

    // MARK: - Rotation mnemonic

    /// Two official vectors as the two halves. Keys pinned from `wallet-engine`.
    private static let rotationPhrase =
        "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about "
      + "zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong"

    func testRotationKeysMatchTheReferenceDerivation() throws {
        let m = try RotationMnemonic.parse(Self.rotationPhrase)
        XCTAssertFalse(m.isPreRotation)

        let anchor = try m.anchorKeyPair()
        let signing = try m.signingKeyPair()

        // `SigningKey::as_bytes()` in the reference is the SLIP-0010 derived private key.
        XCTAssertEqual(anchor.secretKey.prefix(32).hexString,
                       "b477ef5ed17fb8a2b8faddd7a9835a227243a82c70b190c7af4896155aa7df9f")
        XCTAssertEqual(anchor.publicKey.hexString,
                       "7952e94118f34607c75e23258dd9220d66ccac5a3ee074125c25068e8107bfbf")
        XCTAssertEqual(signing.secretKey.prefix(32).hexString,
                       "a7e4e571135b501905f0be50d4bbd7a407e194cc23b1573c0be8a769aef43333")
        XCTAssertEqual(signing.publicKey.hexString,
                       "5d6320a0546c2df0908f0477e1ade79226faf854d041548f846b58872de5213e")
    }

    /// Before rotation the user holds one 12-word phrase and the engine expands it.
    func testTwelveWordPhraseExpandsToIdenticalHalves() throws {
        let half = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        let m = try RotationMnemonic.parse(half)

        XCTAssertTrue(m.isPreRotation)
        XCTAssertEqual(m.anchor, m.signing)
        XCTAssertEqual(m.words.count, 24)
        XCTAssertEqual(try m.anchorKeyPair().publicKey, try m.signingKeyPair().publicKey)

        // Writing the half out twice must parse to the same thing.
        XCTAssertEqual(try RotationMnemonic.parse("\(half) \(half)"), m)
    }

    /// The halves are independent BIP-39 mnemonics, not one 24-word mnemonic. Decoding a
    /// rotation phrase as a single BIP-39 phrase gives a different key and no error.
    func testHalvesDecodeIndependentlyAndAreNotA24WordMnemonic() throws {
        let m = try RotationMnemonic.parse(Self.rotationPhrase)
        XCTAssertNotEqual(try BIP39.entropy(from: m.anchor), try BIP39.entropy(from: m.signing))

        // The same 24 words read as one BIP-39 mnemonic fail their own checksum here,
        // which is luck rather than protection — hence the separate type.
        XCTAssertFalse(BIP39.validate(m.words))
    }

    func testRejectsMalformedRotationPhrases() {
        for count in [0, 1, 11, 13, 23, 25] {
            XCTAssertThrowsError(
                try RotationMnemonic(words: Array(repeating: "abandon", count: count)),
                "\(count) words must be refused"
            )
        }
        // 24 words, valid list, but neither half checksums.
        XCTAssertThrowsError(try RotationMnemonic(words: Array(repeating: "abandon", count: 24)))
    }

    func testNormalizesCaseAndWhitespace() throws {
        let messy = "  ABANDON abandon  Abandon abandon abandon abandon "
                  + "abandon abandon abandon abandon abandon ABOUT  "
        let m = try RotationMnemonic.parse(messy)
        XCTAssertEqual(m.anchor.first, "abandon")
        XCTAssertEqual(m.anchor.last, "about")
    }

    /// Rotation keeps the anchor half — that is what keeps the address.
    func testRotatedKeepsTheAnchorHalf() throws {
        let original = try RotationMnemonic.parse(
            "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about")
        let replacement = try RotationMnemonic.parse(
            "zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong")

        let after = original.rotated(to: replacement)
        XCTAssertEqual(after.anchor, original.anchor)
        XCTAssertEqual(after.signing, replacement.anchor)
        XCTAssertFalse(after.isPreRotation)
        XCTAssertEqual(try after.anchorKeyPair().publicKey, try original.anchorKeyPair().publicKey)
        XCTAssertEqual(try after.signingKeyPair().publicKey, try replacement.anchorKeyPair().publicKey)
    }

    func testGeneratedPhrasesRoundTrip() throws {
        for _ in 0..<20 {
            let m = try RotationMnemonic.generate()
            XCTAssertTrue(m.isPreRotation)
            XCTAssertEqual(m.anchor.count, 12)
            XCTAssertTrue(BIP39.validate(m.anchor))
            XCTAssertEqual(try RotationMnemonic(words: m.anchor), m)
        }
    }

    /// The two schemes disagree, and a host app must not try both.
    func testTONAndBIP39SchemesDisagree() throws {
        let bip39 = "antenna diesel run dawn leisure popular manage brown convince consider silver have"
            .split(separator: " ").map(String.init)
        XCTAssertTrue(BIP39.validate(bip39))
        XCTAssertNoThrow(try RotationMnemonic(words: bip39))
        XCTAssertFalse(try Mnemonic.validate(bip39), "not a TON-scheme mnemonic")

        let ton = try Mnemonic.generate()
        XCTAssertTrue(try Mnemonic.validate(ton))
        XCTAssertFalse(BIP39.validate(ton), "24-word TON phrases are not BIP-39 phrases")
    }
}
