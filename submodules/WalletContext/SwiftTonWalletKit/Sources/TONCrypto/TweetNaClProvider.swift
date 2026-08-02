import Foundation
import _TweetNaCl

/// The default crypto provider, backed by vendored TweetNaCl.
///
/// Chosen because it is the same implementation the reference uses — `@ton/crypto`
/// signs with tweetnacl and `@tonconnect/protocol` boxes with it — so signatures and
/// sealed boxes match the golden vectors byte for byte.
public struct TweetNaClProvider: Ed25519Signing, KeyExchanging {
    public init() {}

    // Sizes are fixed by the primitives; spelled out so call sites read clearly.
    static let signatureBytes = 64
    static let signPublicKeyBytes = 32
    static let signSecretKeyBytes = 64
    static let boxPublicKeyBytes = 32
    static let boxSecretKeyBytes = 32
    static let boxNonceBytes = 24
    /// NaCl's `crypto_box` requires the plaintext to be prefixed with 32 zero bytes…
    static let boxZeroBytes = 32
    /// …and produces a ciphertext prefixed with 16 zero bytes. Both are stripped here,
    /// so callers see the conventional compact form that tweetnacl-js exposes.
    static let boxBoxZeroBytes = 16

    // MARK: - Ed25519Signing

    public func keyPair(fromSeed seed: Data) throws -> KeyPair {
        guard seed.count == 32 else { throw CryptoProviderError.invalidSeedLength(seed.count) }

        var publicKey = [UInt8](repeating: 0, count: Self.signPublicKeyBytes)
        var secretKey = [UInt8](repeating: 0, count: Self.signSecretKeyBytes)
        let status = ton_ed25519_seed_keypair(&publicKey, &secretKey, [UInt8](seed))
        guard status == 0 else {
            throw CryptoProviderError.internalFailure("seed keypair derivation returned \(status)")
        }
        return KeyPair(publicKey: Data(publicKey), secretKey: Data(secretKey))
    }

    public func sign(_ data: Data, seed: Data) throws -> Data {
        guard seed.count == 32 else { throw CryptoProviderError.invalidSeedLength(seed.count) }
        let pair = try keyPair(fromSeed: seed)

        var signature = [UInt8](repeating: 0, count: Self.signatureBytes)
        let message = [UInt8](data)
        let status = ton_ed25519_sign_detached(
            &signature,
            message.isEmpty ? nil : message,
            UInt64(message.count),
            [UInt8](pair.secretKey)
        )
        guard status == 0 else {
            throw CryptoProviderError.internalFailure("ed25519 sign returned \(status)")
        }
        return Data(signature)
    }

    public func verify(signature: Data, data: Data, publicKey: Data) throws -> Bool {
        guard signature.count == Self.signatureBytes else {
            throw CryptoProviderError.invalidSignatureLength(signature.count)
        }
        guard publicKey.count == Self.signPublicKeyBytes else {
            throw CryptoProviderError.invalidPublicKeyLength(publicKey.count)
        }

        let message = [UInt8](data)
        // A non-zero status means authentication failed, which is an expected outcome
        // rather than an error.
        return ton_ed25519_verify_detached(
            [UInt8](signature),
            message.isEmpty ? nil : message,
            UInt64(message.count),
            [UInt8](publicKey)
        ) == 0
    }

    // MARK: - KeyExchanging

    public func generateKeyPair() throws -> (publicKey: Data, secretKey: Data) {
        var publicKey = [UInt8](repeating: 0, count: Self.boxPublicKeyBytes)
        var secretKey = [UInt8](repeating: 0, count: Self.boxSecretKeyBytes)
        let status = ton_x25519_keypair(&publicKey, &secretKey)
        guard status == 0 else {
            throw CryptoProviderError.internalFailure("x25519 keypair returned \(status)")
        }
        return (Data(publicKey), Data(secretKey))
    }

    public func publicKey(forSecretKey secretKey: Data) throws -> Data {
        guard secretKey.count == Self.boxSecretKeyBytes else {
            throw CryptoProviderError.invalidSecretKeyLength(secretKey.count)
        }
        var publicKey = [UInt8](repeating: 0, count: Self.boxPublicKeyBytes)
        let sk = [UInt8](secretKey)
        let status = ton_x25519_public_from_secret(&publicKey, sk)
        guard status == 0 else {
            throw CryptoProviderError.internalFailure("x25519 public derivation returned \(status)")
        }
        return Data(publicKey)
    }

    public func seal(
        _ message: Data,
        nonce: Data,
        theirPublicKey: Data,
        mySecretKey: Data
    ) throws -> Data {
        try validateBoxInputs(nonce: nonce, publicKey: theirPublicKey, secretKey: mySecretKey)

        // The shim handles NaCl's zero-padding, so the result is the compact form
        // tweetnacl-js produces: message length plus a 16-byte authenticator.
        var box = [UInt8](repeating: 0, count: message.count + Self.boxBoxZeroBytes)
        let plaintext = [UInt8](message)
        let status = ton_box_seal(
            &box,
            plaintext.isEmpty ? nil : plaintext,
            UInt64(plaintext.count),
            [UInt8](nonce),
            [UInt8](theirPublicKey),
            [UInt8](mySecretKey)
        )
        guard status == 0 else {
            throw CryptoProviderError.internalFailure("box seal returned \(status)")
        }
        return Data(box)
    }

    public func open(
        _ box: Data,
        nonce: Data,
        theirPublicKey: Data,
        mySecretKey: Data
    ) throws -> Data? {
        try validateBoxInputs(nonce: nonce, publicKey: theirPublicKey, secretKey: mySecretKey)
        guard box.count >= Self.boxBoxZeroBytes else {
            throw CryptoProviderError.boxTooShort(box.count)
        }

        // Allocate at least one byte so the buffer pointer is always valid; an empty
        // plaintext is legitimate (a box of exactly 16 bytes authenticates nothing).
        let plaintextCount = box.count - Self.boxBoxZeroBytes
        var plaintext = [UInt8](repeating: 0, count: max(plaintextCount, 1))
        let status = ton_box_open(
            &plaintext,
            [UInt8](box),
            UInt64(box.count),
            [UInt8](nonce),
            [UInt8](theirPublicKey),
            [UInt8](mySecretKey)
        )
        // Authentication failure is a normal outcome, not an error.
        guard status == 0 else { return nil }
        return Data(plaintext.prefix(plaintextCount))
    }

    private func validateBoxInputs(nonce: Data, publicKey: Data, secretKey: Data) throws {
        guard nonce.count == Self.boxNonceBytes else {
            throw CryptoProviderError.invalidNonceLength(nonce.count)
        }
        guard publicKey.count == Self.boxPublicKeyBytes else {
            throw CryptoProviderError.invalidPublicKeyLength(publicKey.count)
        }
        guard secretKey.count == Self.boxSecretKeyBytes else {
            throw CryptoProviderError.invalidSecretKeyLength(secretKey.count)
        }
    }
}
