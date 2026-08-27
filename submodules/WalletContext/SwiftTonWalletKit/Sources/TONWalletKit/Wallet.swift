import Foundation
import TONCore
import TONCrypto
import TONContracts
import TONToncenter
import TONConnect

/// Which wallet contract a wallet uses.
public enum WalletVersion: String, Codable, Sendable {
    case v4r2
    case v5r1
    /// `wallet-v5-experimental` — V5R1 plus one-time public-key rotation.
    ///
    /// Other stacks name it differently; the Rust reference calls this version `Wallet`.
    case v5experimental
}

/// Produces signatures for a wallet.
///
/// The seam that keeps private keys out of this library. A host app can back it with the
/// Keychain, the Secure Enclave, a hardware wallet, or a BoringSSL implementation — the kit
/// only ever asks for a signature over bytes it supplies.
public protocol WalletSigner: Sendable {
    var publicKey: Data { get }
    /// Signs 32 bytes of digest, or whatever the caller supplies.
    func sign(_ data: Data) async throws -> Data
}

/// A signer holding a key in memory.
///
/// Convenient for tests and for wallets restored from a mnemonic at runtime. A production
/// wallet should prefer a Keychain- or enclave-backed signer so the key never sits in the
/// process heap longer than necessary.
public struct InMemorySigner: WalletSigner {
    public let publicKey: Data
    private let secretKey: Data

    public init(keyPair: KeyPair) {
        self.publicKey = keyPair.publicKey
        self.secretKey = keyPair.secretKey
    }

    public init(mnemonic: [String]) throws {
        try self.init(keyPair: Mnemonic.keyPair(from: mnemonic))
    }

    public func sign(_ data: Data) async throws -> Data {
        try Ed25519.sign(data, secretKey: secretKey)
    }
}

/// One wallet the kit manages.
///
/// Wraps a contract version, a signer, and the network it lives on. Signing is delegated,
/// so this type never holds a private key.
public struct Wallet: Sendable {
    public let version: WalletVersion
    public let address: Address
    public let network: Network
    public let publicKey: Data
    /// Contract-level subwallet id, persisted separately from the kit's stable ``id``.
    public let contractWalletID: UInt32
    /// Stable per-network identifier: `base64(sha256("<chainId>:<friendlyAddress>"))`.
    public let id: WalletID

    let signer: any WalletSigner
    let v5: WalletV5R1?
    let v4: WalletV4R2?
    let v5x: WalletV5Experimental?

    /// Builds a V5R1 wallet with the network-aware walletId.
    ///
    /// Uses the network's `global_id` rather than the reference's hardcoded mainnet
    /// constant, so the address agrees with every other client for the same key.
    public init(v5r1 signer: any WalletSigner, network: Network, workchain: Int8 = 0) throws {
        guard let globalId = Int32(network.chainId) else {
            throw WalletKitError.validationFailed(reason: "Network chainId \(network.chainId) is not numeric")
        }
        try self.init(
            v5r1: signer,
            network: network,
            walletID: WalletV5R1.walletID(globalId: globalId, workchain: workchain),
            workchain: workchain
        )
    }

    /// Builds a V5R1 wallet with an explicitly persisted wallet id.
    ///
    /// This form exists for restoring a wallet created by an older implementation. Deriving
    /// a fresh network default in that case can silently change the address for the same key.
    public init(
        v5r1 signer: any WalletSigner,
        network: Network,
        walletID: UInt32,
        workchain: Int8 = 0
    ) throws {
        let wallet = WalletV5R1(publicKey: signer.publicKey, walletID: walletID, workchain: workchain)
        let address = try wallet.address()

        self.version = .v5r1
        self.address = address
        self.network = network
        self.publicKey = signer.publicKey
        self.contractWalletID = walletID
        self.signer = signer
        self.v5 = wallet
        self.v4 = nil
        self.v5x = nil
        self.id = WalletID(
            WalletID_.make(chainId: network.chainId, address: address.toString())
        )
    }

    public init(
        v4r2 signer: any WalletSigner,
        network: Network,
        walletID: UInt32 = WalletV4R2.defaultWalletID,
        workchain: Int8 = 0
    ) throws {
        let wallet = WalletV4R2(publicKey: signer.publicKey, walletID: walletID, workchain: workchain)
        let address = try wallet.address()

        self.version = .v4r2
        self.address = address
        self.network = network
        self.publicKey = signer.publicKey
        self.contractWalletID = walletID
        self.signer = signer
        self.v5 = nil
        self.v4 = wallet
        self.v5x = nil
        self.id = WalletID(
            WalletID_.make(chainId: network.chainId, address: address.toString())
        )
    }

    /// Builds a `wallet-v5-experimental` wallet with the network-aware walletId.
    public init(
        v5Experimental signer: any WalletSigner,
        network: Network,
        workchain: Int8 = 0
    ) throws {
        guard let globalId = Int32(network.chainId) else {
            throw WalletKitError.validationFailed(reason: "Network chainId \(network.chainId) is not numeric")
        }
        try self.init(
            v5Experimental: signer,
            network: network,
            walletID: WalletV5Experimental.walletID(globalId: globalId, workchain: workchain),
            workchain: workchain
        )
    }

    /// Builds a `wallet-v5-experimental` wallet with an explicitly persisted wallet id.
    ///
    /// Note what this init cannot express: a wallet whose key has already been rotated.
    /// The address comes from the *deployed* state init, so re-deriving it from a rotated
    /// key would name a different account. Restoring such a wallet means keeping the
    /// address, and the original public key that derives it, alongside the current signer
    /// — see ``rotationBody(to:seqno:validUntil:)``.
    public init(
        v5Experimental signer: any WalletSigner,
        network: Network,
        walletID: UInt32,
        workchain: Int8 = 0
    ) throws {
        let wallet = WalletV5Experimental(
            publicKey: signer.publicKey, walletID: walletID, workchain: workchain
        )
        let address = try wallet.address()

        self.version = .v5experimental
        self.address = address
        self.network = network
        self.publicKey = signer.publicKey
        self.contractWalletID = walletID
        self.signer = signer
        self.v5 = nil
        self.v4 = nil
        self.v5x = wallet
        self.id = WalletID(
            WalletID_.make(chainId: network.chainId, address: address.toString())
        )
    }

    /// Builds a `wallet-v5-experimental` wallet from a rotation mnemonic (TEP-0003 §3.3).
    ///
    /// This is the form to prefer for this contract. The mnemonic already carries both
    /// keys, so the two cases a caller would otherwise have to distinguish — before and
    /// after rotation — collapse into one call: the address always derives from the anchor
    /// half, and signing always uses the signing half. Before rotation those are the same
    /// key, and the user holds a single 12-word phrase.
    ///
    /// Using ``init(v5Experimental:network:workchain:)`` with a raw signer instead is still
    /// correct for a wallet that will never rotate, but it cannot express a rotated one.
    public init(
        v5Experimental mnemonic: RotationMnemonic,
        network: Network,
        workchain: Int8 = 0
    ) throws {
        guard let globalId = Int32(network.chainId) else {
            throw WalletKitError.validationFailed(
                reason: "Network chainId \(network.chainId) is not numeric"
            )
        }
        let walletID = WalletV5Experimental.walletID(globalId: globalId, workchain: workchain)
        let anchorKey: Data
        let signingKeys: KeyPair
        do {
            anchorKey = try mnemonic.anchorKeyPair().publicKey
            signingKeys = try mnemonic.signingKeyPair()
        } catch {
            throw WalletKitError.cryptoFailure(underlying: error)
        }

        try self.init(
            v5ExperimentalRotated: InMemorySigner(keyPair: signingKeys),
            originalPublicKey: anchorKey,
            network: network,
            walletID: walletID,
            workchain: workchain
        )
    }

    /// A wallet whose one-time key rotation has already happened.
    ///
    /// After a rotation the account's address and its signing key no longer agree: the
    /// address is fixed by the state init that was deployed, which embeds the *original*
    /// key, while only the *new* key can authorize anything. Every other initializer here
    /// derives the address from the signer, so none of them can name a rotated wallet —
    /// without this one, rotating would make the account unusable through this kit.
    ///
    /// `originalPublicKey` is what the address derives from and must be the key the wallet
    /// was created with; `signer` holds the key it uses now. Passing the current key as
    /// `originalPublicKey` silently produces a different, non-existent account, so the
    /// caller has to persist the original alongside the wallet.
    ///
    /// One consequence worth knowing: ``stateInit()`` still describes the deployed state,
    /// which advertises the *old* public key. It hashes to the right address, but a TON
    /// Connect peer that cross-checks the advertised key against the state init — as the
    /// Rust reference's `verify_standard_wallet` does — will reject the connection. That
    /// tension is inherent to a contract whose key can change while its address cannot.
    public init(
        v5ExperimentalRotated signer: any WalletSigner,
        originalPublicKey: Data,
        network: Network,
        walletID: UInt32,
        workchain: Int8 = 0
    ) throws {
        // Address from the original key; signing from the new one.
        let wallet = WalletV5Experimental(
            publicKey: originalPublicKey, walletID: walletID, workchain: workchain
        )
        let address = try wallet.address()

        self.version = .v5experimental
        self.address = address
        self.network = network
        self.publicKey = signer.publicKey
        self.contractWalletID = walletID
        self.signer = signer
        self.v5 = nil
        self.v4 = nil
        self.v5x = wallet
        self.id = WalletID(
            WalletID_.make(chainId: network.chainId, address: address.toString())
        )
    }

    /// The contract's initial state, which a dApp uses to verify the address derives from
    /// the public key.
    public func stateInit() throws -> StateInit {
        if let v5 { return try v5.stateInit() }
        if let v4 { return try v4.stateInit() }
        if let v5x { return try v5x.stateInit() }
        throw WalletKitError.validationFailed(reason: "Wallet has no contract")
    }

    public func stateInitBase64() throws -> String {
        try stateInit().toCell().toBocBase64()
    }

    /// How many outgoing messages one transfer can carry.
    ///
    /// V5R1 chains an action list and reaches 255; V4R2 stores each message as a ref and so
    /// caps at 4. A dApp asking for more than the wallet allows must be refused rather than
    /// silently truncated.
    public var maxMessagesPerTransfer: Int {
        switch version {
        case .v5r1, .v5experimental: return ActionList.maxActions
        case .v4r2: return Cell.maxRefs
        }
    }

    /// Capabilities to advertise to a dApp.
    public var supportedFeatures: [Feature] {
        [
            .sendTransaction(maxMessages: maxMessagesPerTransfer),
            .signData(),
        ]
    }

    /// Restricts host-requested capabilities to what this contract can actually execute.
    func supportedFeatures(limitedTo requested: [Feature]?) -> [Feature] {
        guard let requested else { return supportedFeatures }

        return requested.compactMap { feature in
            switch feature.name {
            case "SendTransaction":
                return .sendTransaction(
                    maxMessages: min(feature.maxMessages ?? maxMessagesPerTransfer, maxMessagesPerTransfer),
                    extraCurrency: feature.extraCurrencySupported ?? false
                )
            case "SignData":
                return .signData(types: feature.types ?? ["text", "binary", "cell"])
            default:
                return nil
            }
        }
    }

    // MARK: - Signing

    /// Builds a signed external message for a transfer.
    ///
    /// `seqno` and `isDeployed` come from the chain; the caller fetches them so this stays
    /// free of network access and therefore testable.
    public func signedTransfer(
        messages: [MessageRelaxed],
        seqno: UInt32,
        isDeployed: Bool,
        validUntil: UInt32,
        sendMode: SendMode = .walletDefault
    ) async throws -> String {
        guard messages.count <= maxMessagesPerTransfer else {
            throw WalletKitError.tooManyMessages(
                count: messages.count,
                maximum: maxMessagesPerTransfer
            )
        }

        do {
            if let v5 {
                let actions = try ActionList.pack(
                    messages.map { .sendMessage(mode: sendMode, message: $0) }
                )
                let payload = try v5.unsignedBody(
                    seqno: seqno,
                    walletID: v5.config.walletID,
                    actions: actions,
                    validUntil: validUntil,
                    auth: .external
                )
                let signature = try await signer.sign(payload.hash())
                let body = try WalletV5R1.signedBody(payload: payload, signature: signature)
                let external = try v5.externalMessage(body: body, includeStateInit: !isDeployed)
                return try external.toCell().toBocBase64()
            }

            if let v5x {
                let actions = try ActionList.pack(
                    messages.map { .sendMessage(mode: sendMode, message: $0) }
                )
                let payload = try v5x.unsignedBody(
                    seqno: seqno,
                    walletID: v5x.config.walletID,
                    actions: actions,
                    validUntil: validUntil,
                    auth: .external
                )
                let signature = try await signer.sign(payload.hash())
                let body = try WalletV5Experimental.signedBody(payload: payload, signature: signature)
                let external = try v5x.externalMessage(body: body, includeStateInit: !isDeployed)
                return try external.toCell().toBocBase64()
            }

            if let v4 {
                let payload = try v4.unsignedTransfer(
                    seqno: seqno,
                    validUntil: validUntil,
                    sendMode: sendMode,
                    messages: messages
                )
                let signature = try await signer.sign(payload.hash())
                // V4R2 puts the signature first, unlike V5R1.
                let builder = beginCell()
                try builder.storeBytes(signature)
                try builder.storeCellInline(payload)
                let external = try v4.externalMessage(
                    body: try builder.endCell(),
                    includeStateInit: !isDeployed
                )
                return try external.toCell().toBocBase64()
            }
        } catch let error as WalletKitError {
            throw error
        } catch {
            throw WalletKitError.contractFailure(underlying: error)
        }

        throw WalletKitError.validationFailed(reason: "Wallet has no contract")
    }

    /// Builds the rotation that replaces this wallet's signing key with `newSigning`'s.
    ///
    /// The replacement is a fresh 12-word BIP-39 half; the user's new 24-word phrase is
    /// their existing anchor half followed by it — see ``RotationMnemonic/rotated(to:)``.
    /// Deriving the key here rather than accepting a raw key pair is what keeps a rotated
    /// wallet recoverable from a phrase: a rotation to some ad-hoc key succeeds on chain
    /// and leaves the account unrecoverable from any mnemonic.
    public func keyRotation(to newSigning: RotationMnemonic) throws -> KeyRotation {
        do {
            let keys = try newSigning.signingKeyPair()
            return try KeyRotation.make(
                address: address,
                newPublicKey: keys.publicKey,
                newSecretKey: keys.secretKey
            )
        } catch {
            throw WalletKitError.cryptoFailure(underlying: error)
        }
    }

    /// Signs a one-time public-key rotation, without broadcasting it.
    ///
    /// Only `wallet-v5-experimental` supports this; every other version throws.
    ///
    /// The returned BoC is deliberately *not* sent here. Rotation is irreversible and
    /// available once per wallet, so the decision to broadcast belongs to the caller, who
    /// should have confirmed with the user and — critically — verified that the new key is
    /// backed up. A rotation to a key whose secret is lost cannot be undone, and the funds
    /// go with it. The signature is made with the wallet's **current** key, because the
    /// contract treats rotation as an owner action; the proof inside `rotation` is what
    /// establishes that someone holds the new key.
    ///
    /// The caller must update its stored signer and mark the rotation spent only after the
    /// transaction settles — see ``WalletV5Experimental/rotated(to:)``. Note that the
    /// address cannot be re-derived from the new key afterwards; it stays as deployed.
    public func signedKeyRotation(
        _ rotation: KeyRotation,
        seqno: UInt32,
        isDeployed: Bool,
        validUntil: UInt32
    ) async throws -> String {
        guard let v5x else {
            throw WalletKitError.validationFailed(
                reason: "Key rotation requires wallet-v5-experimental, not \(version.rawValue)"
            )
        }
        guard isDeployed else {
            throw WalletKitError.validationFailed(
                reason: "Cannot rotate the key of an undeployed wallet"
            )
        }

        do {
            let actions = try v5x.changeKeyActions(rotation)
            let payload = try v5x.unsignedBody(
                seqno: seqno,
                walletID: v5x.config.walletID,
                actions: actions,
                validUntil: validUntil,
                auth: .external
            )
            let signature = try await signer.sign(payload.hash())
            let body = try WalletV5Experimental.signedBody(payload: payload, signature: signature)
            let external = try v5x.externalMessage(body: body, includeStateInit: false)
            return try external.toCell().toBocBase64()
        } catch let error as WalletKitError {
            throw error
        } catch {
            throw WalletKitError.contractFailure(underlying: error)
        }
    }

    /// Signs a `signData` request, which is a hash rather than a transaction.
    public func signData(hash: Data) async throws -> Data {
        do {
            return try await signer.sign(hash)
        } catch {
            throw WalletKitError.cryptoFailure(underlying: error)
        }
    }

    /// Signs a TON Proof for a connect request.
    public func signProof(
        domain: String,
        payload: String,
        timestamp: UInt64
    ) async throws -> TonProofItemReply {
        let message = TonProof.Message(
            address: address,
            domain: TonProof.Domain(value: domain),
            timestamp: timestamp,
            payload: payload
        )
        do {
            let signature = try await signer.sign(TonProof.messageBytes(message))
            return TonProofItemReply(
                proof: .init(
                    timestamp: timestamp,
                    domain: .init(
                        lengthBytes: message.domain.lengthBytes,
                        value: message.domain.value
                    ),
                    payload: payload,
                    signature: signature.base64EncodedString()
                )
            )
        } catch {
            throw WalletKitError.cryptoFailure(underlying: error)
        }
    }

    /// The account details a dApp receives on connect.
    ///
    /// The address here is the **raw** form, which is what the protocol specifies — a
    /// friendly address in this field fails dApp-side verification.
    public func addressReply() throws -> TonAddressItemReply {
        TonAddressItemReply(
            address: address.rawString,
            network: network.chainId,
            publicKey: publicKey.hexString,
            walletStateInit: try stateInitBase64()
        )
    }
}

/// Internal alias so the wallet-id helper does not collide with the ``WalletID`` type.
private enum WalletID_ {
    static func make(chainId: String, address: String) -> String {
        TONCrypto.WalletID.make(chainId: chainId, address: address)
    }
}
