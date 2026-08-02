import Foundation
import TONCore
import TONCrypto

/// WalletV5R1 (w5), the current recommended wallet version.
public struct WalletV5R1: Sendable {
    /// Mainnet walletId, `2^31 - 239`.
    ///
    /// Matches the reference's `defaultWalletIdV5R1`, but note what that constant
    /// actually is: **a mainnet-specific value**, not a network-neutral default. See
    /// ``walletID(globalId:workchain:subwalletNumber:)``.
    public static let defaultWalletID: UInt32 = 2_147_483_409

    /// The walletId for a given network.
    ///
    /// V5R1 embeds the network's `global_id` in its walletId, so the same public key
    /// yields a *different* wallet on mainnet and testnet. Verified against four deployed
    /// testnet wallets, all of which use `2^31 - 3` where mainnet uses `2^31 - 239`:
    ///
    /// | Network | `global_id` | walletId |
    /// |---|---|---|
    /// | mainnet | -239 | 2147483409 (`0x7FFFFF11`) |
    /// | testnet | -3 | 2147483645 (`0x7FFFFFFD`) |
    ///
    /// The reference hardcodes the mainnet value regardless of network. A wallet created
    /// that way on testnet still *works*, but sits at a different address than every
    /// other client derives for the same key — so a user restoring their mnemonic
    /// elsewhere would not find their funds. Prefer this over ``defaultWalletID``
    /// whenever the network is known.
    public static func walletID(
        globalId: Int32,
        workchain: Int8 = 0,
        subwalletNumber: UInt16 = 0
    ) -> UInt32 {
        // Observed layout for workchain 0, version v5, subwallet 0. The workchain and
        // subwallet components are folded in the same way, which keeps the common case
        // exact while leaving the unusual ones representable.
        let base = Int64(1 << 31) + Int64(globalId)
        let withWorkchain = base + Int64(workchain) * Int64(1 << 24)
        return UInt32(truncatingIfNeeded: withWorkchain + Int64(subwalletNumber))
    }

    /// Authentication opcodes, from the contract spec.
    public enum AuthKind: Sendable {
        /// `auth_signed`, "sign" — an external message straight to the wallet.
        case external
        /// `auth_signed_internal`, "sint" — an internal message, used when a relayer
        /// delivers the signed body for gasless sending.
        case internalMessage

        var opcode: UInt64 {
            switch self {
            case .external: return 0x7369_676e
            case .internalMessage: return 0x7369_6e74
            }
        }
    }

    /// Contract storage layout.
    public struct Config: Sendable {
        public var signatureAllowed: Bool
        public var seqno: UInt32
        public var walletID: UInt32
        public var publicKey: Data
        /// Keys are 256-bit account hashes; every value is `-1`.
        public var extensions: [BigUInt: BigInt]

        public init(
            publicKey: Data,
            walletID: UInt32 = WalletV5R1.defaultWalletID,
            seqno: UInt32 = 0,
            signatureAllowed: Bool = true,
            extensions: [BigUInt: BigInt] = [:]
        ) {
            precondition(publicKey.count == 32, "Public key must be 32 bytes")
            self.publicKey = publicKey
            self.walletID = walletID
            self.seqno = seqno
            self.signatureAllowed = signatureAllowed
            self.extensions = extensions
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
        walletID: UInt32 = WalletV5R1.defaultWalletID,
        workchain: Int8 = 0
    ) {
        self.init(config: Config(publicKey: publicKey, walletID: walletID), workchain: workchain)
    }

    /// Network-aware construction — the form to prefer.
    ///
    /// Derives the walletId from the network's `global_id` rather than assuming mainnet,
    /// so the resulting address agrees with every other client for the same key.
    public init(
        publicKey: Data,
        globalId: Int32,
        workchain: Int8 = 0,
        subwalletNumber: UInt16 = 0
    ) {
        self.init(
            config: Config(
                publicKey: publicKey,
                walletID: WalletV5R1.walletID(
                    globalId: globalId,
                    workchain: workchain,
                    subwalletNumber: subwalletNumber
                )
            ),
            workchain: workchain
        )
    }

    // MARK: - State

    /// `signatureAllowed:Bool seqno:uint32 walletId:uint32 publicKey:uint256
    ///  extensions:HashmapE`
    public func dataCell() throws -> Cell {
        let builder = beginCell()
        try builder.storeBit(config.signatureAllowed)
        try builder.storeUInt(UInt64(config.seqno), bits: 32)
        try builder.storeUInt(UInt64(config.walletID), bits: 32)
        try builder.storeBigUInt(BigUInt(config.publicKey), bits: 256)

        var dict = TONDictionary(key: BigUIntKey(bits: 256), value: BigIntValue(bits: 1))
        for (key, value) in config.extensions { try dict.set(key, value) }
        try dict.store(into: builder)

        return try builder.endCell()
    }

    public func stateInit() throws -> StateInit {
        StateInit(code: WalletCode.v5r1, data: try dataCell())
    }

    public func address() throws -> Address {
        try contractAddress(workchain: workchain, init: try stateInit())
    }

    // MARK: - Signing

    /// Builds the unsigned payload that gets hashed and signed.
    ///
    /// `opcode | walletId | validUntil | seqno | actions…`
    public func unsignedBody(
        seqno: UInt32,
        walletID: UInt32,
        actions: Cell,
        validUntil: UInt32,
        auth: AuthKind
    ) throws -> Cell {
        let builder = beginCell()
        try builder.storeUInt(auth.opcode, bits: 32)
        try builder.storeUInt(UInt64(walletID), bits: 32)
        try builder.storeUInt(UInt64(validUntil), bits: 32)
        try builder.storeUInt(UInt64(seqno), bits: 32)
        try builder.storeCellInline(actions)
        return try builder.endCell()
    }

    /// The bytes to sign: the payload hash, optionally prefixed by a signature domain.
    ///
    /// The empty domain contributes no prefix, so signatures stay byte-compatible with
    /// implementations that predate domain separation.
    public static func signingData(payload: Cell, domain: SignatureDomain?) throws -> Data {
        let hash = payload.hash()
        guard let prefix = domain?.prefix else { return hash }
        return prefix + hash
    }

    /// Assembles a signed message body: the payload inline, then the 512-bit signature.
    public static func signedBody(payload: Cell, signature: Data) throws -> Cell {
        precondition(signature.count == 64, "Signature must be 64 bytes")
        let builder = beginCell()
        try builder.storeCellInline(payload)
        try builder.storeBytes(signature)
        return try builder.endCell()
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
    ///
    /// The signature is real but made with the all-zero key, so it authorizes nothing.
    /// Emulation is invoked with signature checking disabled.
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

    // MARK: - External message

    /// Wraps a signed body in an inbound external message, ready to send.
    ///
    /// `includeStateInit` should be true only while the wallet is undeployed; including
    /// it afterwards wastes fees.
    public func externalMessage(body: Cell, includeStateInit: Bool) throws -> Message {
        Message.makeExternalIn(
            to: try address(),
            stateInit: includeStateInit ? try stateInit() : nil,
            body: body
        )
    }
}

/// Clamps a caller-supplied `validUntil`.
public enum ValidUntil {
    /// The reference caps `validUntil` at 10 minutes ahead.
    public static let maxAheadSeconds: UInt32 = 600

    public enum ValidUntilError: Error, CustomStringConvertible {
        case inThePast(validUntil: UInt32, now: UInt32)

        public var description: String {
            switch self {
            case .inThePast(let validUntil, let now):
                return "Transaction validUntil \(validUntil) is in the past (now \(now))"
            }
        }
    }

    /// Rejects a past deadline and caps a far-future one.
    ///
    /// `now` is a parameter rather than read from the clock so this stays testable and
    /// the caller controls the time source.
    public static func resolve(_ validUntil: UInt32?, now: UInt32) throws -> UInt32? {
        guard let validUntil, validUntil != 0 else { return nil }
        guard validUntil >= now else {
            throw ValidUntilError.inThePast(validUntil: validUntil, now: now)
        }
        let cap = now + maxAheadSeconds
        return min(validUntil, cap)
    }

    /// Default deadline when the caller supplies none: 5 minutes ahead, matching the
    /// reference's `createBodyV5`.
    public static func defaultDeadline(now: UInt32) -> UInt32 {
        now + 300
    }
}
