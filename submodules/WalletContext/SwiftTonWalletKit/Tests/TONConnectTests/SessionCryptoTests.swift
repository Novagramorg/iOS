import XCTest
import TONTestVectors
import TONCore
import TONCrypto
@testable import TONConnect

/// Verifies session encryption against vectors generated with `@tonconnect/protocol`.
///
/// Decryption is the direction that matters most: a wallet decrypts every inbound bridge
/// message, and those bytes are attacker-controllable. Encryption uses a random nonce so
/// ciphertexts are not reproducible, but the recorded ones are exact test data for
/// decryption — the harder direction.
final class SessionCryptoTests: XCTestCase {
    struct SessionVector: Decodable {
        let label: String
        let plaintext: String
        let senderPublicKey: String
        let senderSecretKey: String
        let receiverPublicKey: String
        let receiverSecretKey: String
        /// `nonce ‖ box`, base64.
        let envelope: String
        let nonceLength: Int
        let roundTripped: Bool
    }

    private func vectors() throws -> [SessionVector] {
        let loaded: [SessionVector] = try Vectors.load("sessioncrypto.json")
        XCTAssertGreaterThanOrEqual(loaded.count, 6, "sessioncrypto.json lost cases")
        // The generator round-trips each case through the reference; if that failed, the
        // fixture itself is untrustworthy.
        XCTAssertTrue(loaded.allSatisfy(\.roundTripped), "a fixture failed its own round trip")
        return loaded
    }

    private func receiver(_ v: SessionVector) throws -> SessionCrypto {
        try SessionCrypto(publicKeyHex: v.receiverPublicKey, secretKeyHex: v.receiverSecretKey)
    }

    // MARK: - Decryption

    /// The core interop check: we must open envelopes the reference produced.
    func testDecryptsReferenceEnvelopes() throws {
        for v in try vectors() {
            let crypto = try receiver(v)
            let senderPublic = try XCTUnwrap(Data(hexString: v.senderPublicKey))
            let decrypted = try crypto.decrypt(
                base64: v.envelope,
                senderPublicKey: senderPublic
            )
            XCTAssertEqual(decrypted, v.plaintext, "failed to decrypt \(v.label)")
        }
    }

    /// The nonce is **prepended** to the ciphertext, not carried separately. Getting this
    /// wrong produces envelopes no dApp can open.
    func testEnvelopeLayoutIsNoncePrefixed() throws {
        for v in try vectors() {
            let envelope = try XCTUnwrap(Data(anyBase64: v.envelope))
            XCTAssertEqual(v.nonceLength, SessionCrypto.nonceLength)
            // 24-byte nonce + 16-byte authenticator + plaintext.
            let expected = SessionCrypto.nonceLength + 16 + Data(v.plaintext.utf8).count
            XCTAssertEqual(envelope.count, expected, "envelope size for \(v.label)")
        }
    }

    /// Every byte of an envelope must be authenticated — a bridge relays bytes an attacker
    /// can choose.
    func testTamperedEnvelopeIsRejected() throws {
        let v = try XCTUnwrap(try vectors().first { !$0.plaintext.isEmpty })
        let crypto = try receiver(v)
        let senderPublic = try XCTUnwrap(Data(hexString: v.senderPublicKey))
        var envelope = try XCTUnwrap(Data(anyBase64: v.envelope))

        for index in envelope.indices {
            var tampered = envelope
            tampered[index] ^= 0x01
            XCTAssertThrowsError(
                try crypto.decrypt(tampered, senderPublicKey: senderPublic),
                "flipping byte \(index) should fail authentication"
            )
        }

        // Sanity: the untampered envelope still opens.
        XCTAssertNoThrow(try crypto.decrypt(envelope, senderPublicKey: senderPublic))
        envelope = Data()
    }

    /// An envelope from the wrong sender must not open, even with a valid structure.
    func testWrongSenderKeyIsRejected() throws {
        let v = try XCTUnwrap(try vectors().first)
        let crypto = try receiver(v)
        let wrongSender = try KeyExchange.generateKeyPair().publicKey
        let envelope = try XCTUnwrap(Data(anyBase64: v.envelope))

        XCTAssertThrowsError(try crypto.decrypt(envelope, senderPublicKey: wrongSender))
    }

    /// An envelope too short to hold a nonce and authenticator must be rejected up front
    /// rather than producing a confusing crypto failure.
    func testShortEnvelopesAreRejected() throws {
        let v = try XCTUnwrap(try vectors().first)
        let crypto = try receiver(v)
        let sender = try XCTUnwrap(Data(hexString: v.senderPublicKey))

        for length in [0, 1, 23, 24] {
            XCTAssertThrowsError(
                try crypto.decrypt(Data(repeating: 0, count: length), senderPublicKey: sender),
                "an envelope of \(length) bytes must be rejected"
            )
        }
    }

    func testMalformedBase64IsRejected() throws {
        let v = try XCTUnwrap(try vectors().first)
        let crypto = try receiver(v)
        let sender = try XCTUnwrap(Data(hexString: v.senderPublicKey))
        XCTAssertThrowsError(try crypto.decrypt(base64: "not!base64!", senderPublicKey: sender))
    }

    // MARK: - Round trips

    /// Both directions must work: a wallet encrypts responses as well as decrypting
    /// requests.
    func testRoundTripBothDirections() throws {
        let wallet = try SessionCrypto()
        let app = try SessionCrypto()
        let messages = [
            "",
            "hello",
            #"{"id":"1","method":"sendTransaction","params":["{}"]}"#,
            "unicode ✅ Привет 🌍",
            String(repeating: "x", count: 5000),
        ]

        for message in messages {
            let toWallet = try app.encrypt(message, receiverPublicKey: wallet.publicKey)
            XCTAssertEqual(
                try wallet.decrypt(toWallet, senderPublicKey: app.publicKey),
                message
            )

            let toApp = try wallet.encrypt(message, receiverPublicKey: app.publicKey)
            XCTAssertEqual(
                try app.decrypt(toApp, senderPublicKey: wallet.publicKey),
                message
            )
        }
    }

    /// A fresh nonce per message means the same plaintext encrypts differently each time —
    /// which is required, not a defect.
    func testEncryptionIsNonDeterministic() throws {
        let wallet = try SessionCrypto()
        let app = try SessionCrypto()
        var seen = Set<Data>()
        for _ in 0..<10 {
            seen.insert(try app.encrypt("same message", receiverPublicKey: wallet.publicKey))
        }
        XCTAssertEqual(seen.count, 10, "each encryption must use a fresh nonce")

        // All of them must still decrypt.
        for envelope in seen {
            XCTAssertEqual(
                try wallet.decrypt(envelope, senderPublicKey: app.publicKey),
                "same message"
            )
        }
    }

    // MARK: - Session identity

    struct SessionIDVector: Decodable {
        let secretKey: String
        let publicKey: String
        let sessionId: String
    }

    /// `sessionID` is the hex public key — it is what the bridge routes on, so a different
    /// encoding would make the wallet unreachable.
    func testSessionIDMatchesReference() throws {
        let vectors: [SessionIDVector] = try Vectors.load("sessionid.json")
        XCTAssertGreaterThanOrEqual(vectors.count, 4)

        for v in vectors {
            let crypto = try SessionCrypto(publicKeyHex: v.publicKey, secretKeyHex: v.secretKey)
            XCTAssertEqual(crypto.sessionID, v.sessionId)
            XCTAssertEqual(crypto.sessionID, v.publicKey, "the session id is the hex public key")
        }
    }

    // MARK: - Persistence

    /// A session must survive an app restart, or every pending dApp request would be lost.
    func testSessionRestoresFromStoredKeys() throws {
        let original = try SessionCrypto()
        let stored = original.storedKeys

        let restored = try SessionCrypto(
            publicKeyHex: stored.publicKey,
            secretKeyHex: stored.secretKey
        )
        XCTAssertEqual(restored.publicKey, original.publicKey)
        XCTAssertEqual(restored.sessionID, original.sessionID)

        // And it can still open messages addressed to the original.
        let app = try SessionCrypto()
        let envelope = try app.encrypt("after restart", receiverPublicKey: original.publicKey)
        XCTAssertEqual(
            try restored.decrypt(envelope, senderPublicKey: app.publicKey),
            "after restart"
        )
    }

    /// A mismatched keypair must be rejected at construction rather than silently
    /// producing ciphertext nobody can open.
    func testMismatchedKeyPairIsRejected() throws {
        let a = try KeyExchange.generateKeyPair()
        let b = try KeyExchange.generateKeyPair()
        XCTAssertThrowsError(
            try SessionCrypto(publicKey: a.publicKey, secretKey: b.secretKey)
        ) { error in
            guard case SessionCryptoError.keyPairMismatch = error else {
                return XCTFail("expected keyPairMismatch, got \(error)")
            }
        }
    }

    func testMalformedKeysAreRejected() {
        XCTAssertThrowsError(try SessionCrypto(publicKeyHex: "zz", secretKeyHex: "zz"))
        XCTAssertThrowsError(
            try SessionCrypto(
                publicKey: Data(repeating: 1, count: 31),
                secretKey: Data(repeating: 1, count: 32)
            )
        )
    }

    func testGeneratedSessionsAreDistinct() throws {
        var ids = Set<String>()
        for _ in 0..<10 { ids.insert(try SessionCrypto().sessionID) }
        XCTAssertEqual(ids.count, 10)
    }
}
