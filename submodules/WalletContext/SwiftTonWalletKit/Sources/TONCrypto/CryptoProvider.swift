import Foundation

/// Ed25519 signing and verification.
///
/// A seam rather than a concrete implementation so a host application can supply its
/// own — a BoringSSL-backed one, or a Secure Enclave / Keychain signer — without this
/// module changing. Telegram's Bazel graph selects ``BoringSSLProvider`` while
/// standalone SwiftPM keeps ``TweetNaClProvider`` for reference vectors.
public protocol Ed25519Signing: Sendable {
    /// Expands a 32-byte seed into a key pair.
    func keyPair(fromSeed seed: Data) throws -> KeyPair

    /// Produces a detached 64-byte signature.
    ///
    /// Implementations **should** be deterministic per RFC 8032. A randomized
    /// implementation still yields valid signatures, but forfeits reproducible
    /// emulation and byte-exact parity with the reference — see
    /// `Ed25519.isDeterministic`.
    func sign(_ data: Data, seed: Data) throws -> Data

    func verify(signature: Data, data: Data, publicKey: Data) throws -> Bool
}

/// X25519 key agreement and NaCl `crypto_box`, as TON Connect's session encryption
/// requires.
///
/// `crypto_box` is X25519 + XSalsa20-Poly1305. Neither CryptoKit nor BoringSSL provides
/// XSalsa20, which is the main reason this seam exists separately from the platform's
/// key-agreement API.
public protocol KeyExchanging: Sendable {
    /// Generates an X25519 key pair. Note the secret key is 32 bytes here, unlike the
    /// 64-byte ed25519 secret key.
    func generateKeyPair() throws -> (publicKey: Data, secretKey: Data)

    /// Derives the public key for an X25519 secret key.
    func publicKey(forSecretKey secretKey: Data) throws -> Data

    /// Seals `message` to `theirPublicKey` under a 24-byte nonce.
    func seal(_ message: Data, nonce: Data, theirPublicKey: Data, mySecretKey: Data) throws -> Data

    /// Opens a sealed box. Returns nil when authentication fails — a wrong key or a
    /// tampered ciphertext, which callers must treat as an ordinary outcome rather
    /// than an error worth surfacing verbatim.
    func open(_ box: Data, nonce: Data, theirPublicKey: Data, mySecretKey: Data) throws -> Data?
}

public enum CryptoProviderError: Error, CustomStringConvertible {
    case invalidSeedLength(Int)
    case invalidSecretKeyLength(Int)
    case invalidPublicKeyLength(Int)
    case invalidSignatureLength(Int)
    case invalidNonceLength(Int)
    case boxTooShort(Int)
    case internalFailure(String)

    public var description: String {
        switch self {
        case .invalidSeedLength(let n): return "Seed must be 32 bytes, got \(n)"
        case .invalidSecretKeyLength(let n): return "Secret key length \(n) is invalid"
        case .invalidPublicKeyLength(let n): return "Public key must be 32 bytes, got \(n)"
        case .invalidSignatureLength(let n): return "Signature must be 64 bytes, got \(n)"
        case .invalidNonceLength(let n): return "Nonce must be 24 bytes, got \(n)"
        case .boxTooShort(let n): return "Sealed box of \(n) bytes is too short"
        case .internalFailure(let m): return "Crypto operation failed: \(m)"
        }
    }
}
