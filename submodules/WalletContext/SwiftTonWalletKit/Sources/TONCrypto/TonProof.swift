import Foundation
import TONCore

/// TON Connect `ton_proof`: the blob a wallet signs to prove address ownership during
/// a dApp connection.
///
/// A remote verifier checks the signature, so every byte and every endianness here is
/// load-bearing — a one-byte deviation makes every proof we issue unverifiable.
public enum TonProof {
    static let itemPrefix = "ton-proof-item-v2/"
    static let connectPrefix = "ton-connect"

    /// The app domain the proof is bound to.
    ///
    /// `lengthBytes` is the UTF-8 **byte** count, not the character count — they differ
    /// for any non-ASCII domain.
    public struct Domain: Hashable, Sendable {
        public let value: String
        public let lengthBytes: UInt32

        public init(value: String) {
            self.value = value
            self.lengthBytes = UInt32(Data(value.utf8).count)
        }

        /// For replaying a domain whose declared length came from the wire.
        public init(value: String, lengthBytes: UInt32) {
            self.value = value
            self.lengthBytes = lengthBytes
        }
    }

    public struct Message: Hashable, Sendable {
        public var workchain: Int32
        public var addressHash: Data
        public var domain: Domain
        public var timestamp: UInt64
        public var payload: String

        public init(
            workchain: Int32,
            addressHash: Data,
            domain: Domain,
            timestamp: UInt64,
            payload: String
        ) {
            self.workchain = workchain
            self.addressHash = addressHash
            self.domain = domain
            self.timestamp = timestamp
            self.payload = payload
        }

        public init(address: Address, domain: Domain, timestamp: UInt64, payload: String) {
            self.init(
                workchain: Int32(address.workchain),
                addressHash: address.hash,
                domain: domain,
                timestamp: timestamp,
                payload: payload
            )
        }
    }

    /// The 32 bytes a wallet signs.
    ///
    /// ```
    /// inner  = "ton-proof-item-v2/"
    ///       ++ workchain   (int32  big-endian, SIGNED)
    ///       ++ addressHash (32 bytes)
    ///       ++ domainLen   (uint32 little-endian)
    ///       ++ domain      (utf8)
    ///       ++ timestamp   (uint64 little-endian)
    ///       ++ payload     (utf8)
    /// result = sha256(0xffff ++ "ton-connect" ++ sha256(inner))
    /// ```
    ///
    /// The mixed endianness is the spec's: `domainLen` and `timestamp` are
    /// little-endian here, while ``SignData`` uses big-endian for the same conceptual
    /// fields. Do not "tidy" one to match the other.
    ///
    /// **Deliberate divergence from walletkit.** `CreateTonProofMessageBytes` writes the
    /// workchain with an *unsigned* int32, so it throws for masterchain (-1) rather than
    /// encoding `0xffffffff`. The TON Connect spec specifies a signed int32, the
    /// documented backend verifier uses one, and walletkit's own signData path uses one.
    /// We follow the spec. Output is byte-identical for workchain 0.
    public static func messageBytes(_ message: Message) -> Data {
        var inner = Data()
        inner.append(Data(itemPrefix.utf8))
        inner.append(bigEndian: UInt32(bitPattern: message.workchain))
        inner.append(message.addressHash)
        inner.append(littleEndian: message.domain.lengthBytes)
        inner.append(Data(message.domain.value.utf8))
        inner.append(littleEndian: message.timestamp)
        inner.append(Data(message.payload.utf8))

        var outer = Data([0xff, 0xff])
        outer.append(Data(connectPrefix.utf8))
        outer.append(Hashing.sha256(inner))

        return Hashing.sha256(outer)
    }

    /// Signs a proof message.
    public static func sign(_ message: Message, secretKey: Data) throws -> Data {
        try Ed25519.sign(messageBytes(message), secretKey: secretKey)
    }

    /// Verifies a proof signature — the check a dApp backend performs.
    public static func verify(_ message: Message, signature: Data, publicKey: Data) throws -> Bool {
        try Ed25519.verify(signature: signature, data: messageBytes(message), publicKey: publicKey)
    }
}

// MARK: - Endian helpers

extension Data {
    mutating func append(bigEndian value: UInt32) {
        for shift in stride(from: 24, through: 0, by: -8) {
            append(UInt8((value >> UInt32(shift)) & 0xff))
        }
    }

    mutating func append(littleEndian value: UInt32) {
        for shift in stride(from: 0, to: 32, by: 8) {
            append(UInt8((value >> UInt32(shift)) & 0xff))
        }
    }

    mutating func append(bigEndian value: UInt64) {
        for shift in stride(from: 56, through: 0, by: -8) {
            append(UInt8((value >> UInt64(shift)) & 0xff))
        }
    }

    mutating func append(littleEndian value: UInt64) {
        for shift in stride(from: 0, to: 64, by: 8) {
            append(UInt8((value >> UInt64(shift)) & 0xff))
        }
    }
}
