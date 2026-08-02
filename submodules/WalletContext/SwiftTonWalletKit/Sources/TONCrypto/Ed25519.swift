import Foundation

/// An ed25519 key pair in the NaCl layout the TON ecosystem uses.
public struct KeyPair: Hashable, Sendable {
    /// 32 bytes.
    public let publicKey: Data
    /// 64 bytes: the 32-byte seed followed by the 32-byte public key.
    public let secretKey: Data

    public init(publicKey: Data, secretKey: Data) {
        precondition(publicKey.count == 32, "Public key must be 32 bytes")
        precondition(secretKey.count == 64, "Secret key must be 64 bytes")
        self.publicKey = publicKey
        self.secretKey = secretKey
    }

    /// The 32-byte seed the key pair was derived from.
    public var seed: Data { secretKey.prefix(32) }
}

/// ed25519 signing, routed through a swappable provider.
///
/// Defaults to the build's native provider. Telegram's Bazel build uses BoringSSL;
/// standalone SwiftPM keeps TweetNaCl as a reference fallback. A host application can install
/// its own (BoringSSL-backed, Secure Enclave, Keychain) via ``use(_:)``.
///
/// Deliberately **not** CryptoKit: its Ed25519 signing is randomized rather than
/// RFC 8032 deterministic, which would forfeit reproducible emulation and byte parity.
/// CryptoKit is still used for hashing, where it is both correct and fast.
public enum Ed25519 {
    /// The active provider. Replace at startup, before any signing happens.
    nonisolated(unsafe) private static var provider: any Ed25519Signing = DefaultCryptoProvider.signing()

    /// Installs a different provider.
    ///
    /// Not synchronised: call once during setup, never concurrently with signing.
    public static func use(_ newProvider: any Ed25519Signing) {
        provider = newProvider
    }

    /// Restores the build's default provider.
    public static func useDefaultProvider() {
        provider = DefaultCryptoProvider.signing()
    }

    public typealias Ed25519Error = CryptoProviderError

    /// Expands a 32-byte seed into a key pair.
    ///
    /// The NaCl secret-key layout is `seed ‖ publicKey`, which is why a 64-byte secret
    /// key can be truncated back to its seed.
    public static func keyPair(fromSeed seed: Data) throws -> KeyPair {
        try provider.keyPair(fromSeed: seed)
    }

    /// Rebuilds a key pair from a 64-byte NaCl secret key.
    public static func keyPair(fromSecretKey secretKey: Data) throws -> KeyPair {
        guard secretKey.count == 64 else {
            throw CryptoProviderError.invalidSecretKeyLength(secretKey.count)
        }
        return try keyPair(fromSeed: Data(secretKey.prefix(32)))
    }

    /// Signs `data`, accepting either a 32-byte seed or a 64-byte NaCl secret key.
    ///
    /// Tolerating both matters because walletkit's `DefaultSignature` does the same:
    /// callers pass whichever form they hold.
    public static func sign(_ data: Data, secretKey: Data) throws -> Data {
        let seed: Data
        switch secretKey.count {
        case 32: seed = secretKey
        case 64: seed = Data(secretKey.prefix(32))
        default: throw CryptoProviderError.invalidSecretKeyLength(secretKey.count)
        }
        return try provider.sign(data, seed: seed)
    }

    public static func verify(signature: Data, data: Data, publicKey: Data) throws -> Bool {
        try provider.verify(signature: signature, data: data, publicKey: publicKey)
    }

    /// A signature from the all-zero seed, used to fill a signature slot when emulating
    /// a transaction that has not been signed yet.
    ///
    /// Not a security primitive: it exists so emulation sees a correctly sized
    /// signature. Never treat one as authorization. Reproducible only if the active
    /// provider is deterministic — see ``isDeterministic()``.
    public static func fakeSignature(_ data: Data) throws -> Data {
        try sign(data, secretKey: Data(repeating: 0, count: 32))
    }

    /// Whether the active provider signs deterministically, per RFC 8032.
    ///
    /// Callers that depend on reproducible output — emulation caches, byte-exact
    /// message hashes — should assert this at startup rather than discovering the
    /// answer from mismatched hashes later.
    public static func isDeterministic() throws -> Bool {
        let seed = Data(repeating: 0x5a, count: 32)
        let probe = Data("determinism probe".utf8)
        return try sign(probe, secretKey: seed) == (try sign(probe, secretKey: seed))
    }
}

/// X25519 key agreement and NaCl `crypto_box`, routed through a swappable provider.
///
/// TON Connect's `SessionCrypto` encrypts every bridge message with this, so it is on
/// the critical path for dApp communication.
public enum KeyExchange {
    nonisolated(unsafe) private static var provider: any KeyExchanging = DefaultCryptoProvider.keyExchange()

    public static func use(_ newProvider: any KeyExchanging) {
        provider = newProvider
    }

    public static func useDefaultProvider() {
        provider = DefaultCryptoProvider.keyExchange()
    }

    /// Nonce width for `crypto_box`.
    public static let nonceBytes = 24

    public static func generateKeyPair() throws -> (publicKey: Data, secretKey: Data) {
        try provider.generateKeyPair()
    }

    public static func publicKey(forSecretKey secretKey: Data) throws -> Data {
        try provider.publicKey(forSecretKey: secretKey)
    }

    public static func seal(
        _ message: Data,
        nonce: Data,
        theirPublicKey: Data,
        mySecretKey: Data
    ) throws -> Data {
        try provider.seal(message, nonce: nonce, theirPublicKey: theirPublicKey, mySecretKey: mySecretKey)
    }

    /// Returns nil when authentication fails — a wrong key or tampered ciphertext.
    public static func open(
        _ box: Data,
        nonce: Data,
        theirPublicKey: Data,
        mySecretKey: Data
    ) throws -> Data? {
        try provider.open(box, nonce: nonce, theirPublicKey: theirPublicKey, mySecretKey: mySecretKey)
    }

    /// A fresh random nonce.
    public static func randomNonce() throws -> Data {
        try Hashing.secureRandomBytes(nonceBytes)
    }
}
