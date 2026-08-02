#if canImport(_TONCryptoBoringSSL)
import Foundation
import _TONCryptoBoringSSL

/// Production crypto provider for Telegram's Bazel build.
///
/// Ed25519, X25519 and Poly1305 come from the repository's BoringSSL. The C shim
/// supplies only the Salsa20/HSalsa20 composition required by TON Connect's
/// NaCl-compatible `crypto_box` wire format.
public struct BoringSSLProvider: Ed25519Signing, KeyExchanging {
    public init() {}

    private static let signatureBytes = 64
    private static let signPublicKeyBytes = 32
    private static let signSecretKeyBytes = 64
    private static let boxPublicKeyBytes = 32
    private static let boxSecretKeyBytes = 32
    private static let boxNonceBytes = 24
    private static let boxTagBytes = 16

    public func keyPair(fromSeed seed: Data) throws -> KeyPair {
        guard seed.count == 32 else {
            throw CryptoProviderError.invalidSeedLength(seed.count)
        }
        var publicKey = [UInt8](repeating: 0, count: Self.signPublicKeyBytes)
        var secretKey = [UInt8](repeating: 0, count: Self.signSecretKeyBytes)
        guard ton_bssl_ed25519_keypair_from_seed(&publicKey, &secretKey, [UInt8](seed)) == 1 else {
            throw CryptoProviderError.internalFailure("BoringSSL ed25519 key derivation failed")
        }
        return KeyPair(publicKey: Data(publicKey), secretKey: Data(secretKey))
    }

    public func sign(_ data: Data, seed: Data) throws -> Data {
        let pair = try keyPair(fromSeed: seed)
        var signature = [UInt8](repeating: 0, count: Self.signatureBytes)
        let message = [UInt8](data)
        guard ton_bssl_ed25519_sign(
            &signature,
            message.isEmpty ? nil : message,
            message.count,
            [UInt8](pair.secretKey)
        ) == 1 else {
            throw CryptoProviderError.internalFailure("BoringSSL ed25519 signing failed")
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
        return ton_bssl_ed25519_verify(
            [UInt8](signature),
            message.isEmpty ? nil : message,
            message.count,
            [UInt8](publicKey)
        ) == 1
    }

    public func generateKeyPair() throws -> (publicKey: Data, secretKey: Data) {
        var publicKey = [UInt8](repeating: 0, count: Self.boxPublicKeyBytes)
        var secretKey = [UInt8](repeating: 0, count: Self.boxSecretKeyBytes)
        guard ton_bssl_x25519_keypair(&publicKey, &secretKey) == 1 else {
            throw CryptoProviderError.internalFailure("BoringSSL x25519 key generation failed")
        }
        return (Data(publicKey), Data(secretKey))
    }

    public func publicKey(forSecretKey secretKey: Data) throws -> Data {
        guard secretKey.count == Self.boxSecretKeyBytes else {
            throw CryptoProviderError.invalidSecretKeyLength(secretKey.count)
        }
        var publicKey = [UInt8](repeating: 0, count: Self.boxPublicKeyBytes)
        guard ton_bssl_x25519_public_from_private(&publicKey, [UInt8](secretKey)) == 1 else {
            throw CryptoProviderError.internalFailure("BoringSSL x25519 public-key derivation failed")
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
        var box = [UInt8](repeating: 0, count: message.count + Self.boxTagBytes)
        let plaintext = [UInt8](message)
        guard ton_bssl_box_seal(
            &box,
            plaintext.isEmpty ? nil : plaintext,
            plaintext.count,
            [UInt8](nonce),
            [UInt8](theirPublicKey),
            [UInt8](mySecretKey)
        ) == 1 else {
            throw CryptoProviderError.internalFailure("BoringSSL NaCl box sealing failed")
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
        guard box.count >= Self.boxTagBytes else {
            throw CryptoProviderError.boxTooShort(box.count)
        }
        let plaintextCount = box.count - Self.boxTagBytes
        var plaintext = [UInt8](repeating: 0, count: max(plaintextCount, 1))
        guard ton_bssl_box_open(
            &plaintext,
            [UInt8](box),
            box.count,
            [UInt8](nonce),
            [UInt8](theirPublicKey),
            [UInt8](mySecretKey)
        ) == 1 else {
            return nil
        }
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
#endif
