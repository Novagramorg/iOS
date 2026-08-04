import Foundation
import TONCore
import TONCrypto

/// End-to-end encryption for one TON Connect session.
///
/// Every bridge message is sealed with X25519 + XSalsa20-Poly1305, so the bridge server
/// relays ciphertext it cannot read. The wallet and the dApp each hold a session keypair
/// and identify each other by public key.
public struct SessionCrypto: Sendable {
    /// 24 bytes, prepended to every ciphertext.
    public static let nonceLength = 24

    public let publicKey: Data
    private let secretKey: Data

    /// Hex-encoded public key. This is the identifier the bridge routes on.
    public var sessionID: String { publicKey.hexString }

    /// Generates a fresh session keypair.
    public init() throws {
        let pair = try KeyExchange.generateKeyPair()
        self.publicKey = pair.publicKey
        self.secretKey = pair.secretKey
    }

    /// Restores a session from stored keys, so a session survives an app restart.
    public init(publicKey: Data, secretKey: Data) throws {
        guard publicKey.count == 32 else {
            throw SessionCryptoError.invalidKeyLength(publicKey.count)
        }
        guard secretKey.count == 32 else {
            throw SessionCryptoError.invalidKeyLength(secretKey.count)
        }
        // Guard against a mismatched pair, which would produce ciphertext nobody can open.
        let derived = try KeyExchange.publicKey(forSecretKey: secretKey)
        guard derived == publicKey else {
            throw SessionCryptoError.keyPairMismatch
        }
        self.publicKey = publicKey
        self.secretKey = secretKey
    }

    /// Restores from hex, the form the reference stores.
    public init(publicKeyHex: String, secretKeyHex: String) throws {
        guard let publicKey = Data(hexString: publicKeyHex),
              let secretKey = Data(hexString: secretKeyHex)
        else { throw SessionCryptoError.malformedHexKey }
        try self.init(publicKey: publicKey, secretKey: secretKey)
    }

    /// Hex keys, for persisting a session.
    public var storedKeys: (publicKey: String, secretKey: String) {
        (publicKey.hexString, secretKey.hexString)
    }

    // MARK: - Sealing

    /// Encrypts a message for `receiverPublicKey`.
    ///
    /// Returns `nonce ‖ box` — the 24-byte nonce is **prepended to the ciphertext**, not
    /// carried alongside it. That layout is the interop contract with every dApp; a
    /// separate nonce field would produce ciphertext nothing can open.
    public func encrypt(_ message: String, receiverPublicKey: Data) throws -> Data {
        let nonce = try KeyExchange.randomNonce()
        let box = try KeyExchange.seal(
            Data(message.utf8),
            nonce: nonce,
            theirPublicKey: receiverPublicKey,
            mySecretKey: secretKey
        )
        return nonce + box
    }

    /// Decrypts a `nonce ‖ box` envelope from `senderPublicKey`.
    ///
    /// Throws on authentication failure. A bridge relays attacker-controllable bytes, so
    /// this is a security boundary: a forged or tampered envelope must be rejected, never
    /// partially decoded.
    public func decrypt(_ envelope: Data, senderPublicKey: Data) throws -> String {
        guard envelope.count > Self.nonceLength else {
            throw SessionCryptoError.envelopeTooShort(envelope.count)
        }
        let nonce = envelope.prefix(Self.nonceLength)
        let box = envelope.dropFirst(Self.nonceLength)

        guard let plaintext = try KeyExchange.open(
            Data(box),
            nonce: Data(nonce),
            theirPublicKey: senderPublicKey,
            mySecretKey: secretKey
        ) else {
            throw SessionCryptoError.authenticationFailed
        }

        guard let text = String(data: plaintext, encoding: .utf8) else {
            throw SessionCryptoError.notUTF8
        }
        return text
    }

    /// Convenience for the base64 form the bridge carries.
    public func decrypt(base64 envelope: String, senderPublicKey: Data) throws -> String {
        guard let data = Data(anyBase64: envelope) else {
            throw SessionCryptoError.malformedBase64
        }
        return try decrypt(data, senderPublicKey: senderPublicKey)
    }

    public func encryptToBase64(_ message: String, receiverPublicKey: Data) throws -> String {
        try encrypt(message, receiverPublicKey: receiverPublicKey).base64EncodedString()
    }
}

public enum SessionCryptoError: Error, CustomStringConvertible {
    case invalidKeyLength(Int)
    case keyPairMismatch
    case malformedHexKey
    case malformedBase64
    case envelopeTooShort(Int)
    case authenticationFailed
    case notUTF8

    public var description: String {
        switch self {
        case .invalidKeyLength(let n):
            return "Session keys must be 32 bytes, got \(n)"
        case .keyPairMismatch:
            return "The secret key does not derive the given public key"
        case .malformedHexKey:
            return "Session key is not valid hex"
        case .malformedBase64:
            return "Envelope is not valid base64"
        case .envelopeTooShort(let n):
            return "Envelope of \(n) bytes cannot hold a 24-byte nonce and an authenticator"
        case .authenticationFailed:
            return "Envelope failed authentication — wrong key or tampered ciphertext"
        case .notUTF8:
            return "Decrypted payload is not valid UTF-8"
        }
    }
}
