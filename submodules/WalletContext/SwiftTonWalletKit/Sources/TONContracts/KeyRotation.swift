import Foundation
import TONCore
import TONCrypto

/// A one-time public-key rotation for the wallet-v5-experimental contract.
///
/// The contract lets an owner replace the wallet's public key **once**, without moving
/// funds or changing the address. That is the reason the contract exists: a key can be
/// retired after a suspected compromise while the account keeps its identity and history.
/// Because the address is derived from the *original* key, the contract can only afford to
/// allow this a single time — a second rotation would let whoever holds the current key
/// permanently detach the account from the key that named it. The `wasKeyChanged` flag in
/// storage enforces that, and a second attempt fails with exit code 151.
///
/// ## Proof of possession
///
/// `proof` is a signature made by the **new** key over ``proofMessage(workchain:addressHash:)``.
/// Without it, an owner could rotate to a key nobody holds and brick the wallet —
/// irrecoverably, since the rotation cannot be undone. The contract verifies the proof
/// against `newPublicKey`, so a proof made with the old key is rejected (exit code 149).
public struct KeyRotation: Sendable, Equatable {
    /// The 32-byte Ed25519 key that will replace the current one.
    public let newPublicKey: Data
    /// A 64-byte signature by `newPublicKey` over ``proofMessage(workchain:addressHash:)``.
    public let proof: Data

    public init(newPublicKey: Data, proof: Data) {
        precondition(newPublicKey.count == 32, "New public key must be 32 bytes")
        precondition(proof.count == 64, "Proof must be 64 bytes")
        self.newPublicKey = newPublicKey
        self.proof = proof
    }

    /// `"KEY_ROTATION"` as a 96-bit tag, matching the contract's `KeyRotationProofPayload`.
    public static let tag = Data("KEY_ROTATION".utf8)

    /// The exact bytes the new key signs: `tag ‖ int8 workchain ‖ uint256 addressHash`.
    ///
    /// **This is a message, not a digest — do not pre-hash it.** The contract verifies with
    /// `CHKSIGNS`, which feeds the slice's data bytes to Ed25519 directly; Ed25519 does its
    /// own hashing internally. Signing `sha256` of these bytes produces a signature the
    /// contract rejects with exit code 149, and nothing else distinguishes that from a
    /// wrong key. The trap is real because this contract *also* uses `CHKSIGNU` for the
    /// wallet's own transfer signature, where the signed value **is** a hash (the body cell
    /// hash) — so the two signing paths in one contract have opposite conventions. (Older
    /// TVM documentation describes `CHKSIGNS` as reducing the slice with sha256, which
    /// reads as a pre-hash but is not one.)
    ///
    /// The result is 45 bytes; `CHKSIGNS` requires a byte-aligned slice, which this is.
    ///
    /// Binding the wallet's own address into the message is what stops a proof from being
    /// replayed: a signature harvested for one wallet is worthless against another, even
    /// when both are owned by the same person and rotate to the same new key.
    public static func proofMessage(workchain: Int8, addressHash: Data) -> Data {
        precondition(addressHash.count == 32, "Address hash must be 32 bytes")
        var message = tag
        message.append(UInt8(bitPattern: workchain))
        message.append(addressHash)
        return message
    }

    /// The message for a specific wallet address.
    public static func proofMessage(address: Address) -> Data {
        proofMessage(workchain: address.workchain, addressHash: address.hash)
    }

    /// Builds a rotation, signing the proof with the new key.
    ///
    /// Takes the *new* secret key because only its holder can produce a valid proof — that
    /// is the point of the check.
    public static func make(
        address: Address,
        newPublicKey: Data,
        newSecretKey: Data
    ) throws -> KeyRotation {
        KeyRotation(
            newPublicKey: newPublicKey,
            proof: try Ed25519.sign(proofMessage(address: address), secretKey: newSecretKey)
        )
    }

    /// Checks the proof the way the contract does, before it can cost anything.
    ///
    /// A rotation is irreversible and one-shot, so an invalid proof is not a retriable
    /// mistake — verify locally first rather than paying gas to learn it.
    public func isProofValid(for address: Address) throws -> Bool {
        try Ed25519.verify(
            signature: proof,
            data: Self.proofMessage(address: address),
            publicKey: newPublicKey
        )
    }

    /// `newPublicKey:uint256 proof:bits512`, the cell the action references.
    ///
    /// Both fields are inline: the contract reads 256 bits then 512 bits from this one
    /// cell, and putting `proof` in a ref instead makes it fail with a cell underflow.
    public func toCell() throws -> Cell {
        let builder = beginCell()
        try builder.storeBigUInt(BigUInt(newPublicKey), bits: 256)
        try builder.storeBytes(proof)
        return try builder.endCell()
    }
}
