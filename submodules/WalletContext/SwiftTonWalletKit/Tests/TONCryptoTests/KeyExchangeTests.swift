import XCTest
import TONTestVectors
import TONCore
@testable import TONCrypto

/// Verifies X25519 + XSalsa20-Poly1305 against vectors generated with tweetnacl — the
/// same library `@tonconnect/protocol`'s `SessionCrypto` uses.
///
/// This is the one primitive with no platform implementation available: CryptoKit has
/// no XSalsa20, and BoringSSL ships ChaCha20 instead of Salsa20. Every TON Connect
/// bridge message is encrypted with it.
final class KeyExchangeTests: XCTestCase {
    struct BoxVector: Decodable {
        let label: String
        let secretA: String
        let publicA: String
        let secretB: String
        let publicB: String
        let nonce: String
        let message: String
        let box: String
    }

    struct X25519Vector: Decodable {
        let secretKey: String
        let publicKey: String
    }

    private func boxVectors() throws -> [BoxVector] {
        let loaded: [BoxVector] = try Vectors.load("nacl-box.json")
        XCTAssertGreaterThanOrEqual(loaded.count, 12, "nacl-box.json lost cases")
        return loaded
    }

    // MARK: - X25519

    func testPublicKeyDerivationMatchesReference() throws {
        let vectors: [X25519Vector] = try Vectors.load("x25519.json")
        XCTAssertGreaterThanOrEqual(vectors.count, 5)

        for v in vectors {
            let secret = try XCTUnwrap(Data(hexString: v.secretKey))
            XCTAssertEqual(
                try KeyExchange.publicKey(forSecretKey: secret).hexString,
                v.publicKey,
                "public key for secret \(v.secretKey.prefix(8))"
            )
        }
    }

    func testGeneratedKeyPairIsSelfConsistent() throws {
        for _ in 0..<5 {
            let pair = try KeyExchange.generateKeyPair()
            XCTAssertEqual(pair.publicKey.count, 32)
            XCTAssertEqual(pair.secretKey.count, 32)
            XCTAssertEqual(try KeyExchange.publicKey(forSecretKey: pair.secretKey), pair.publicKey)
        }
    }

    func testGeneratedKeysAreDistinct() throws {
        var seen = Set<Data>()
        for _ in 0..<10 { seen.insert(try KeyExchange.generateKeyPair().secretKey) }
        XCTAssertEqual(seen.count, 10, "key generation is not producing fresh keys")
    }

    // MARK: - Sealing

    /// Byte-exact against tweetnacl, including the compact-form padding convention.
    func testSealMatchesReference() throws {
        for v in try boxVectors() {
            let message = try XCTUnwrap(Data(hexString: v.message))
            let nonce = try XCTUnwrap(Data(hexString: v.nonce))
            let theirPublic = try XCTUnwrap(Data(hexString: v.publicB))
            let mySecret = try XCTUnwrap(Data(hexString: v.secretA))

            let box = try KeyExchange.seal(
                message,
                nonce: nonce,
                theirPublicKey: theirPublic,
                mySecretKey: mySecret
            )
            XCTAssertEqual(box.hexString, v.box, "sealed box for \(v.label)")
            // Compact form: plaintext length plus a 16-byte authenticator.
            XCTAssertEqual(box.count, message.count + 16, "box length for \(v.label)")
        }
    }

    func testOpenRecoversReferenceBoxes() throws {
        for v in try boxVectors() {
            let box = try XCTUnwrap(Data(hexString: v.box))
            let nonce = try XCTUnwrap(Data(hexString: v.nonce))
            let expected = try XCTUnwrap(Data(hexString: v.message))

            // B opens what A sealed.
            let opened = try KeyExchange.open(
                box,
                nonce: nonce,
                theirPublicKey: try XCTUnwrap(Data(hexString: v.publicA)),
                mySecretKey: try XCTUnwrap(Data(hexString: v.secretB))
            )
            XCTAssertEqual(opened, expected, "opened plaintext for \(v.label)")
        }
    }

    /// Sealing is symmetric: either side can seal to the other.
    func testSealAndOpenBothDirections() throws {
        let a = try KeyExchange.generateKeyPair()
        let b = try KeyExchange.generateKeyPair()
        let nonce = try KeyExchange.randomNonce()
        let message = Data("bridge payload".utf8)

        let aToB = try KeyExchange.seal(message, nonce: nonce, theirPublicKey: b.publicKey, mySecretKey: a.secretKey)
        XCTAssertEqual(
            try KeyExchange.open(aToB, nonce: nonce, theirPublicKey: a.publicKey, mySecretKey: b.secretKey),
            message
        )

        let bToA = try KeyExchange.seal(message, nonce: nonce, theirPublicKey: a.publicKey, mySecretKey: b.secretKey)
        XCTAssertEqual(
            try KeyExchange.open(bToA, nonce: nonce, theirPublicKey: b.publicKey, mySecretKey: a.secretKey),
            message
        )
    }

    // MARK: - Authentication failures

    /// A tampered ciphertext must return nil, not throw and not yield garbage. A bridge
    /// receives attacker-controlled bytes, so this is the security-relevant path.
    func testTamperedBoxFailsAuthentication() throws {
        let a = try KeyExchange.generateKeyPair()
        let b = try KeyExchange.generateKeyPair()
        let nonce = try KeyExchange.randomNonce()
        let box = try KeyExchange.seal(
            Data("secret".utf8),
            nonce: nonce,
            theirPublicKey: b.publicKey,
            mySecretKey: a.secretKey
        )

        for index in box.indices {
            var tampered = box
            tampered[index] ^= 0x01
            XCTAssertNil(
                try KeyExchange.open(tampered, nonce: nonce, theirPublicKey: a.publicKey, mySecretKey: b.secretKey),
                "flipping byte \(index) should fail authentication"
            )
        }

        // Sanity: the untampered box still opens.
        XCTAssertNotNil(
            try KeyExchange.open(box, nonce: nonce, theirPublicKey: a.publicKey, mySecretKey: b.secretKey)
        )
    }

    func testWrongNonceFailsAuthentication() throws {
        let a = try KeyExchange.generateKeyPair()
        let b = try KeyExchange.generateKeyPair()
        let nonce = try KeyExchange.randomNonce()
        let box = try KeyExchange.seal(
            Data("secret".utf8),
            nonce: nonce,
            theirPublicKey: b.publicKey,
            mySecretKey: a.secretKey
        )

        var wrongNonce = nonce
        wrongNonce[0] ^= 0xff
        XCTAssertNil(
            try KeyExchange.open(box, nonce: wrongNonce, theirPublicKey: a.publicKey, mySecretKey: b.secretKey)
        )
    }

    func testWrongKeyFailsAuthentication() throws {
        let a = try KeyExchange.generateKeyPair()
        let b = try KeyExchange.generateKeyPair()
        let c = try KeyExchange.generateKeyPair()
        let nonce = try KeyExchange.randomNonce()
        let box = try KeyExchange.seal(
            Data("secret".utf8),
            nonce: nonce,
            theirPublicKey: b.publicKey,
            mySecretKey: a.secretKey
        )

        // C is not the intended recipient.
        XCTAssertNil(
            try KeyExchange.open(box, nonce: nonce, theirPublicKey: a.publicKey, mySecretKey: c.secretKey)
        )
    }

    func testEmptyMessageRoundTrips() throws {
        let a = try KeyExchange.generateKeyPair()
        let b = try KeyExchange.generateKeyPair()
        let nonce = try KeyExchange.randomNonce()

        let box = try KeyExchange.seal(Data(), nonce: nonce, theirPublicKey: b.publicKey, mySecretKey: a.secretKey)
        XCTAssertEqual(box.count, 16, "an empty message seals to just the authenticator")
        XCTAssertEqual(
            try KeyExchange.open(box, nonce: nonce, theirPublicKey: a.publicKey, mySecretKey: b.secretKey),
            Data()
        )
    }

    func testLargeMessageRoundTrips() throws {
        let a = try KeyExchange.generateKeyPair()
        let b = try KeyExchange.generateKeyPair()
        let nonce = try KeyExchange.randomNonce()
        let message = Data((0 ..< 1024 * 1024).map { UInt8(truncatingIfNeeded: $0) })
        let box = try KeyExchange.seal(
            message,
            nonce: nonce,
            theirPublicKey: b.publicKey,
            mySecretKey: a.secretKey
        )
        XCTAssertEqual(
            try KeyExchange.open(box, nonce: nonce, theirPublicKey: a.publicKey, mySecretKey: b.secretKey),
            message
        )
    }

    #if canImport(_TONCryptoBoringSSL)
    func testBoringSSLRejectsLowOrderPublicKey() throws {
        let provider = BoringSSLProvider()
        let secret = Data(repeating: 7, count: 32)
        let lowOrderPublicKey = Data(repeating: 0, count: 32)
        let nonce = Data(repeating: 0, count: 24)

        XCTAssertThrowsError(
            try provider.seal(
                Data("message".utf8),
                nonce: nonce,
                theirPublicKey: lowOrderPublicKey,
                mySecretKey: secret
            )
        )
        XCTAssertNil(
            try provider.open(
                Data(repeating: 0, count: 16),
                nonce: nonce,
                theirPublicKey: lowOrderPublicKey,
                mySecretKey: secret
            )
        )
    }
    #endif

    // MARK: - Input validation

    func testRejectsMalformedLengths() throws {
        let key = Data(repeating: 1, count: 32)
        let shortNonce = Data(repeating: 0, count: 23)

        XCTAssertThrowsError(
            try KeyExchange.seal(Data(), nonce: shortNonce, theirPublicKey: key, mySecretKey: key)
        )
        XCTAssertThrowsError(
            try KeyExchange.seal(
                Data(),
                nonce: Data(repeating: 0, count: 24),
                theirPublicKey: Data(repeating: 1, count: 31),
                mySecretKey: key
            )
        )
        XCTAssertThrowsError(
            try KeyExchange.open(
                Data(repeating: 0, count: 8),
                nonce: Data(repeating: 0, count: 24),
                theirPublicKey: key,
                mySecretKey: key
            ),
            "a box shorter than the authenticator must be rejected"
        )
    }
}

/// Verifies the provider seam itself: a host application can substitute its own
/// implementation, which is how a BoringSSL-backed signer would be installed.
final class ProviderSeamTests: XCTestCase {
    /// Records what it was asked to do and delegates, so the test can prove the seam is
    /// actually consulted rather than bypassed.
    final class SpyProvider: Ed25519Signing, @unchecked Sendable {
        let inner = TweetNaClProvider()
        var signCallCount = 0
        var verifyCallCount = 0

        func keyPair(fromSeed seed: Data) throws -> KeyPair {
            try inner.keyPair(fromSeed: seed)
        }
        func sign(_ data: Data, seed: Data) throws -> Data {
            signCallCount += 1
            return try inner.sign(data, seed: seed)
        }
        func verify(signature: Data, data: Data, publicKey: Data) throws -> Bool {
            verifyCallCount += 1
            return try inner.verify(signature: signature, data: data, publicKey: publicKey)
        }
    }

    override func tearDown() {
        Ed25519.useDefaultProvider()
        super.tearDown()
    }

    func testInstalledProviderIsUsed() throws {
        let spy = SpyProvider()
        Ed25519.use(spy)

        let seed = Data(repeating: 9, count: 32)
        let signature = try Ed25519.sign(Data("payload".utf8), secretKey: seed)
        let publicKey = try Ed25519.keyPair(fromSeed: seed).publicKey
        _ = try Ed25519.verify(signature: signature, data: Data("payload".utf8), publicKey: publicKey)

        XCTAssertEqual(spy.signCallCount, 1, "signing did not route through the installed provider")
        XCTAssertEqual(spy.verifyCallCount, 1, "verification did not route through the installed provider")
    }

    func testDefaultProviderIsRestored() throws {
        Ed25519.use(SpyProvider())
        Ed25519.useDefaultProvider()
        // The default must be deterministic, which is the point of not using CryptoKit.
        XCTAssertTrue(try Ed25519.isDeterministic())
    }
}
