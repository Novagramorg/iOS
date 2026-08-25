import Foundation
import TONCore
import TONCrypto

/// The wallet-v5-experimental contract — V5R1 plus one-time public-key rotation.
///
/// Built from `tolk-vm/wallet-v5-experimental` at `b420256f`. Other implementations name
/// it differently: the Rust reference calls the version `Wallet`, and its TON Connect
/// layer recognises it under the same name alongside `V3R1`…`V5R1`.
///
/// It is deliberately *almost* V5R1. The message layouts are not merely similar but
/// byte-identical — same `auth_signed` / `auth_signed_internal` opcodes, same action-list
/// encoding, same payload-then-signature ordering — so this type reuses V5R1's body
/// builders rather than restating them, which keeps the two from drifting apart. Only two
/// things differ, and both change the address:
///
/// - the code cell, and
/// - one extra `wasKeyChanged` bit at the tail of the data cell.
///
/// That second difference is easy to miss and impossible to notice late: omit the bit and
/// every derived address is wrong, but plausibly wrong, so the mistake surfaces as funds
/// sent to an account nobody controls. ``dataCell()`` is covered by golden vectors taken
/// from the reference implementation for exactly that reason.
///
/// Everything else — extensions, signature-auth toggling, gasless internal requests —
/// behaves as it does on V5R1.
///
/// The contract adds one action, ``WalletV5Action/changeKey(_:)``, and one storage flag.
/// Everything else — extensions, signature-auth toggling, gasless internal requests —
/// behaves as it does on V5R1.
public struct WalletV5Experimental: Sendable {
    /// Mainnet walletId, `2^31 - 239`. Shared with V5R1.
    public static let defaultWalletID: UInt32 = WalletV5R1.defaultWalletID

    /// The walletId for a given network, using the same derivation as V5R1.
    ///
    /// The reference hardcodes the mainnet constant for both networks. See
    /// ``WalletV5R1/walletID(globalId:workchain:subwalletNumber:)`` for why this is
    /// preferable and what it costs to get wrong.
    public static func walletID(
        globalId: Int32,
        workchain: Int8 = 0,
        subwalletNumber: UInt16 = 0
    ) -> UInt32 {
        WalletV5R1.walletID(
            globalId: globalId,
            workchain: workchain,
            subwalletNumber: subwalletNumber
        )
    }

    /// Authentication opcodes. Identical to V5R1's.
    public typealias AuthKind = WalletV5R1.AuthKind

    /// Contract storage layout.
    ///
    /// `isSignatureAllowed:Bool seqno:uint32 subwalletId:uint32 publicKey:uint256
    ///  extensions:HashmapE wasKeyChanged:Bool`
    public struct Config: Sendable {
        public var signatureAllowed: Bool
        public var seqno: UInt32
        public var walletID: UInt32
        public var publicKey: Data
        /// Keys are 256-bit account hashes; every value is `-1`.
        public var extensions: [BigUInt: BigInt]
        /// Whether the one-time key rotation has already been spent.
        ///
        /// Always false for a wallet being deployed — the address derives from this, so a
        /// wallet created with it set would not be the wallet anyone else computes.
        public var wasKeyChanged: Bool

        public init(
            publicKey: Data,
            walletID: UInt32 = WalletV5Experimental.defaultWalletID,
            seqno: UInt32 = 0,
            signatureAllowed: Bool = true,
            extensions: [BigUInt: BigInt] = [:],
            wasKeyChanged: Bool = false
        ) {
            precondition(publicKey.count == 32, "Public key must be 32 bytes")
            self.publicKey = publicKey
            self.walletID = walletID
            self.seqno = seqno
            self.signatureAllowed = signatureAllowed
            self.extensions = extensions
            self.wasKeyChanged = wasKeyChanged
        }
    }

    public let config: Config
    public let workchain: Int8

    public init(config: Config, workchain: Int8 = 0) {
        self.config = config
        self.workchain = workchain
    }

    public init(
        publicKey: Data,
        walletID: UInt32 = WalletV5Experimental.defaultWalletID,
        workchain: Int8 = 0
    ) {
        self.init(config: Config(publicKey: publicKey, walletID: walletID), workchain: workchain)
    }

    /// Network-aware construction — the form to prefer.
    public init(
        publicKey: Data,
        globalId: Int32,
        workchain: Int8 = 0,
        subwalletNumber: UInt16 = 0
    ) {
        self.init(
            config: Config(
                publicKey: publicKey,
                walletID: Self.walletID(
                    globalId: globalId,
                    workchain: workchain,
                    subwalletNumber: subwalletNumber
                )
            ),
            workchain: workchain
        )
    }

    // MARK: - State

    /// The data cell: V5R1's layout with a trailing `wasKeyChanged` bit.
    public func dataCell() throws -> Cell {
        let builder = beginCell()
        try builder.storeBit(config.signatureAllowed)
        try builder.storeUInt(UInt64(config.seqno), bits: 32)
        try builder.storeUInt(UInt64(config.walletID), bits: 32)
        try builder.storeBigUInt(BigUInt(config.publicKey), bits: 256)

        var dict = TONDictionary(key: BigUIntKey(bits: 256), value: BigIntValue(bits: 1))
        for (key, value) in config.extensions { try dict.set(key, value) }
        try dict.store(into: builder)

        try builder.storeBit(config.wasKeyChanged)

        return try builder.endCell()
    }

    public func stateInit() throws -> StateInit {
        StateInit(code: WalletCode.v5Experimental, data: try dataCell())
    }

    public func address() throws -> Address {
        try contractAddress(workchain: workchain, init: try stateInit())
    }

    // MARK: - Signing

    /// Builds the unsigned payload that gets hashed and signed.
    ///
    /// `opcode | walletId | validUntil | seqno | actions…` — the same bytes V5R1 produces.
    public func unsignedBody(
        seqno: UInt32,
        walletID: UInt32,
        actions: Cell,
        validUntil: UInt32,
        auth: AuthKind
    ) throws -> Cell {
        try WalletV5R1.unsignedBody(
            seqno: seqno,
            walletID: walletID,
            actions: actions,
            validUntil: validUntil,
            auth: auth
        )
    }

    /// The bytes to sign: the payload hash, optionally prefixed by a signature domain.
    public static func signingData(payload: Cell, domain: SignatureDomain?) throws -> Data {
        try WalletV5R1.signingData(payload: payload, domain: domain)
    }

    /// Assembles a signed message body: the payload inline, then the 512-bit signature.
    public static func signedBody(payload: Cell, signature: Data) throws -> Cell {
        try WalletV5R1.signedBody(payload: payload, signature: signature)
    }

    /// Builds and signs a body in one step.
    public func createSignedBody(
        seqno: UInt32,
        actions: Cell,
        validUntil: UInt32,
        auth: AuthKind,
        secretKey: Data,
        domain: SignatureDomain? = nil
    ) throws -> Cell {
        let payload = try unsignedBody(
            seqno: seqno,
            walletID: config.walletID,
            actions: actions,
            validUntil: validUntil,
            auth: auth
        )
        let signature = try Ed25519.sign(
            try Self.signingData(payload: payload, domain: domain),
            secretKey: secretKey
        )
        return try Self.signedBody(payload: payload, signature: signature)
    }

    /// Builds a body with a placeholder signature, for emulating an unapproved
    /// transaction.
    public func createFakeSignedBody(
        seqno: UInt32,
        actions: Cell,
        validUntil: UInt32,
        auth: AuthKind,
        domain: SignatureDomain? = nil
    ) throws -> Cell {
        let payload = try unsignedBody(
            seqno: seqno,
            walletID: config.walletID,
            actions: actions,
            validUntil: validUntil,
            auth: auth
        )
        let signature = try Ed25519.fakeSignature(
            try Self.signingData(payload: payload, domain: domain)
        )
        return try Self.signedBody(payload: payload, signature: signature)
    }

    // MARK: - Key rotation

    public enum KeyRotationError: Error, CustomStringConvertible {
        case alreadyRotated
        case sameKey
        case invalidProof

        public var description: String {
            switch self {
            case .alreadyRotated:
                return "This wallet has already used its one-time key rotation (exit code 151)"
            case .sameKey:
                return "The new public key must differ from the current one (exit code 148)"
            case .invalidProof:
                return "The rotation proof is not a valid signature by the new key (exit code 149)"
            }
        }
    }

    /// Builds the action list for a key rotation, refusing one the contract would reject.
    ///
    /// The three checks here mirror the contract's own and run before anything is signed or
    /// broadcast. That ordering matters more than usual: the rotation is one-shot, so
    /// discovering a bad proof from an exit code wastes the gas, and a *good* proof for a
    /// key nobody holds loses the wallet. What this cannot check is whether anyone actually
    /// holds the new key — the proof establishes that, which is why
    /// ``KeyRotation/make(address:newPublicKey:newSecretKey:)`` needs the new secret rather
    /// than just the new public key.
    ///
    /// The caller still signs the resulting body with the **current** key: rotation is an
    /// owner-authorized action, and the contract refuses it from an extension (exit code 150).
    public func changeKeyActions(_ rotation: KeyRotation) throws -> Cell {
        guard !config.wasKeyChanged else { throw KeyRotationError.alreadyRotated }
        guard rotation.newPublicKey != config.publicKey else { throw KeyRotationError.sameKey }
        guard try rotation.isProofValid(for: try address()) else {
            throw KeyRotationError.invalidProof
        }
        return try ActionList.pack([.changeKey(rotation)])
    }

    /// The wallet as it will be after a successful rotation.
    ///
    /// The address does not change — it is fixed by the deployed state init, not the
    /// current config — so this is only for tracking local state, never for re-deriving an
    /// address.
    public func rotated(to newPublicKey: Data) -> WalletV5Experimental {
        var updated = config
        updated.publicKey = newPublicKey
        updated.wasKeyChanged = true
        return WalletV5Experimental(config: updated, workchain: workchain)
    }

    // MARK: - External message

    /// Wraps a signed body in an inbound external message, ready to send.
    public func externalMessage(body: Cell, includeStateInit: Bool) throws -> Message {
        Message.makeExternalIn(
            to: try address(),
            stateInit: includeStateInit ? try stateInit() : nil,
            body: body
        )
    }
}
