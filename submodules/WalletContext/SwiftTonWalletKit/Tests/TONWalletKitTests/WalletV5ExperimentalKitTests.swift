import XCTest
import TONCore
import TONCrypto
import TONContracts
import TONToncenter
import TONConnect
@testable import TONWalletKit

/// Kit-level wiring for `wallet-v5-experimental`.
///
/// The contract itself is covered by golden vectors in `TONContractsTests`. What is at
/// risk here is the plumbing: a new enum case has to be handled everywhere the other two
/// are, and Swift will not warn about a missing branch in an `if let` chain the way it
/// does for a `switch`. A wallet that derives correctly but signs through the wrong
/// contract, or reports V4R2's four-message cap, fails in ways the contract tests cannot see.
final class WalletV5ExperimentalKitTests: XCTestCase {
    private static let seed = Data(repeating: 0x33, count: 32)

    private func signer() throws -> InMemorySigner {
        InMemorySigner(keyPair: try Ed25519.keyPair(fromSeed: Self.seed))
    }

    private func wallet(network: Network = .testnet) throws -> Wallet {
        try Wallet(v5Experimental: signer(), network: network)
    }

    func testVersionAndAddressComeFromTheExperimentalContract() throws {
        let w = try wallet()
        XCTAssertEqual(w.version, .v5experimental)
        XCTAssertEqual(w.version.rawValue, "v5experimental")

        let contract = WalletV5Experimental(
            publicKey: try signer().publicKey,
            globalId: -3
        )
        XCTAssertEqual(w.address, try contract.address())
        XCTAssertEqual(w.contractWalletID, 0x7fff_fffd)
    }

    /// The three versions must not collide for one key — each is a separate account.
    func testEachVersionDerivesItsOwnAddress() throws {
        let s = try signer()
        let addresses = Set([
            try Wallet(v5Experimental: s, network: .testnet).address,
            try Wallet(v5r1: s, network: .testnet).address,
            try Wallet(v4r2: s, network: .testnet).address,
        ])
        XCTAssertEqual(addresses.count, 3)
    }

    func testStateInitIsTheExperimentalOne() throws {
        let w = try wallet()
        let stateInit = try w.stateInit()
        XCTAssertEqual(stateInit.code?.hash(), WalletCode.v5Experimental.hash())
        XCTAssertNotEqual(stateInit.code?.hash(), WalletCode.v5r1.hash())
        // The wallet's address must be the hash of the state init it advertises, or a dApp
        // verifying the connect reply rejects it.
        XCTAssertEqual(
            try contractAddress(workchain: 0, init: stateInit),
            w.address
        )
    }

    /// It chains an action list like V5R1, so it gets V5R1's cap, not V4R2's.
    func testMessageCapMatchesV5R1() throws {
        XCTAssertEqual(try wallet().maxMessagesPerTransfer, 255)
        XCTAssertEqual(
            try Wallet(v5Experimental: signer(), network: .testnet).supportedFeatures
                .first { $0.name == "SendTransaction" }?.maxMessages,
            255
        )
    }

    func testMainnetAndTestnetDeriveDifferentAddresses() throws {
        XCTAssertNotEqual(
            try wallet(network: .mainnet).address,
            try wallet(network: .testnet).address
        )
    }

    private func transfer(to tag: UInt8, value: BigUInt) -> MessageRelaxed {
        MessageRelaxed.makeInternal(
            to: Address(workchain: 0, hash: Data(repeating: tag, count: 32)),
            value: value,
            bounce: false
        )
    }

    /// `signedTransfer` must route through the experimental contract, not fall through to
    /// V5R1 — which would sign a valid message addressed to a different wallet.
    func testSignedTransferUsesTheExperimentalContract() async throws {
        let s = try signer()
        let w = try Wallet(v5Experimental: s, network: .testnet)
        let boc = try await w.signedTransfer(
            messages: [transfer(to: 0xaa, value: 1_000_000)],
            seqno: 3,
            isDeployed: true,
            validUntil: 1_800_000_000,
            sendMode: SendMode(rawValue: 3)
        )

        let contract = WalletV5Experimental(publicKey: s.publicKey, globalId: -3)
        let expected = try contract.externalMessage(
            body: try contract.createSignedBody(
                seqno: 3,
                actions: try ActionList.pack([
                    .sendMessage(mode: SendMode(rawValue: 3), message: transfer(to: 0xaa, value: 1_000_000))
                ]),
                validUntil: 1_800_000_000,
                auth: .external,
                secretKey: try Ed25519.keyPair(fromSeed: Self.seed).secretKey
            ),
            includeStateInit: false
        )
        XCTAssertEqual(boc, try expected.toCell().toBocBase64())

        // And the destination is this wallet, not the V5R1 one for the same key.
        let cell = try Cell.fromBase64(boc)
        var slice = cell.beginParse()
        _ = try slice.loadUInt(2)          // ext_in_msg_info$10
        _ = try slice.loadUInt(2)          // src: addr_none
        XCTAssertEqual(try slice.loadAddress(), w.address)
    }

    /// An undeployed wallet must carry its state init, or the external message is dropped.
    func testUndeployedTransferCarriesStateInit() async throws {
        let w = try wallet()
        let boc = try await w.signedTransfer(
            messages: [transfer(to: 0xaa, value: 1_000_000)],
            seqno: 0,
            isDeployed: false,
            validUntil: 1_800_000_000
        )
        let deployed = try await w.signedTransfer(
            messages: [transfer(to: 0xaa, value: 1_000_000)],
            seqno: 0,
            isDeployed: true,
            validUntil: 1_800_000_000
        )
        XCTAssertGreaterThan(boc.count, deployed.count)
    }

    func testTooManyMessagesIsRefused() async throws {
        let w = try wallet()
        let messages = (0..<256).map { _ in transfer(to: 0xaa, value: 1) }
        do {
            _ = try await w.signedTransfer(
                messages: messages, seqno: 0, isDeployed: true, validUntil: 1_800_000_000
            )
            XCTFail("256 messages should exceed the 255-action cap")
        } catch let error as WalletKitError {
            guard case .tooManyMessages(let count, let maximum) = error else {
                return XCTFail("unexpected error \(error)")
            }
            XCTAssertEqual(count, 256)
            XCTAssertEqual(maximum, 255)
        }
    }

    // MARK: - Key rotation

    private func rotation(for wallet: Wallet) throws -> (KeyRotation, KeyPair) {
        let new = try Ed25519.keyPair(fromSeed: Data(repeating: 0x44, count: 32))
        return (
            try KeyRotation.make(
                address: wallet.address, newPublicKey: new.publicKey, newSecretKey: new.secretKey
            ),
            new
        )
    }

    func testSignedKeyRotationProducesAChangeKeyAction() async throws {
        let w = try wallet()
        let (rotation, new) = try rotation(for: w)

        let boc = try await w.signedKeyRotation(
            rotation, seqno: 4, isDeployed: true, validUntil: 1_800_000_000
        )

        // Walk into the body and confirm it is opcode `sign` carrying a single extended
        // action `0x05` — not a transfer that happens to mention the key somewhere.
        var slice = try Cell.fromBase64(boc).beginParse()
        _ = try slice.loadUInt(2)
        _ = try slice.loadUInt(2)
        XCTAssertEqual(try slice.loadAddress(), w.address)
        _ = try slice.loadCoins()
        XCTAssertFalse(try slice.loadBit(), "a deployed wallet must not resend its state init")

        var body = try slice.loadBit() ? try slice.loadRef().beginParse() : slice
        XCTAssertEqual(try body.loadUInt(32), 0x7369_676e)
        XCTAssertEqual(try body.loadUInt(32), UInt64(w.contractWalletID))
        XCTAssertEqual(try body.loadUInt(32), 1_800_000_000)
        XCTAssertEqual(try body.loadUInt(32), 4)
        XCTAssertFalse(try body.loadBit(), "rotation sends no messages")
        XCTAssertTrue(try body.loadBit(), "rotation is an extended action")
        XCTAssertEqual(try body.loadUInt(8), 0x05)

        var payload = try body.loadRef().beginParse()
        XCTAssertEqual(try payload.loadBigUInt(256), BigUInt(new.publicKey))
    }

    /// Rotation exists on one contract only; the others must refuse rather than sign
    /// something they cannot execute.
    func testRotationIsRefusedByOtherVersions() async throws {
        let s = try signer()
        let (rotation, _) = try rotation(for: try Wallet(v5Experimental: s, network: .testnet))

        for wallet in [
            try Wallet(v5r1: s, network: .testnet),
            try Wallet(v4r2: s, network: .testnet),
        ] {
            do {
                _ = try await wallet.signedKeyRotation(
                    rotation, seqno: 1, isDeployed: true, validUntil: 1_800_000_000
                )
                XCTFail("\(wallet.version) must not sign a key rotation")
            } catch let error as WalletKitError {
                guard case .validationFailed = error else {
                    return XCTFail("unexpected error \(error)")
                }
            }
        }
    }

    /// An undeployed wallet has no published key to rotate yet.
    func testRotationIsRefusedBeforeDeployment() async throws {
        let w = try wallet()
        let (rotation, _) = try rotation(for: w)
        do {
            _ = try await w.signedKeyRotation(
                rotation, seqno: 0, isDeployed: false, validUntil: 1_800_000_000
            )
            XCTFail("an undeployed wallet must not rotate")
        } catch let error as WalletKitError {
            guard case .validationFailed = error else {
                return XCTFail("unexpected error \(error)")
            }
        }
    }

    /// A proof built for a different address must not be signed, even though it is a
    /// perfectly valid signature.
    func testRotationWithAForeignProofIsRefused() async throws {
        let w = try wallet()
        let other = try Wallet(v5Experimental: signer(), network: .mainnet)
        let new = try Ed25519.keyPair(fromSeed: Data(repeating: 0x44, count: 32))
        let foreign = try KeyRotation.make(
            address: other.address, newPublicKey: new.publicKey, newSecretKey: new.secretKey
        )
        do {
            _ = try await w.signedKeyRotation(
                foreign, seqno: 1, isDeployed: true, validUntil: 1_800_000_000
            )
            XCTFail("a proof bound to another address must be refused")
        } catch let error as WalletKitError {
            guard case .contractFailure = error else {
                return XCTFail("unexpected error \(error)")
            }
        }
    }

    // MARK: - Rotation mnemonics (TEP-0003 §3.3)

    private static let anchorHalf =
        "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    private static let signingHalf = "zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong"

    /// Before rotation the user holds one 12-word phrase, and both keys are the same.
    func testWalletFromPreRotationMnemonic() throws {
        let m = try RotationMnemonic.parse(Self.anchorHalf)
        let w = try Wallet(v5Experimental: m, network: .testnet)

        XCTAssertEqual(w.version, .v5experimental)
        XCTAssertEqual(w.publicKey, try m.anchorKeyPair().publicKey)

        // Identical to building it from the anchor key directly.
        let direct = try Wallet(
            v5Experimental: InMemorySigner(keyPair: try m.anchorKeyPair()), network: .testnet
        )
        XCTAssertEqual(w.address, direct.address)
    }

    /// After rotation the address still comes from the anchor half, the signature from the
    /// signing half. Getting this backwards names an account that does not exist.
    func testWalletFromRotatedMnemonicKeepsTheAnchorAddress() throws {
        let before = try RotationMnemonic.parse(Self.anchorHalf)
        let after = try RotationMnemonic.parse("\(Self.anchorHalf) \(Self.signingHalf)")

        let w0 = try Wallet(v5Experimental: before, network: .testnet)
        let w1 = try Wallet(v5Experimental: after, network: .testnet)

        XCTAssertEqual(w1.address, w0.address, "rotation must not move the wallet")
        XCTAssertEqual(w1.publicKey, try after.signingKeyPair().publicKey)
        XCTAssertNotEqual(w1.publicKey, w0.publicKey)

        // The signing half alone would name a different, non-existent account.
        let wrong = try Wallet(
            v5Experimental: try RotationMnemonic.parse(Self.signingHalf), network: .testnet
        )
        XCTAssertNotEqual(wrong.address, w1.address)
    }

    /// A rotation built from a phrase must match one built from the raw derived key.
    func testKeyRotationFromMnemonicMatchesTheDerivedKey() async throws {
        let w = try Wallet(v5Experimental: try RotationMnemonic.parse(Self.anchorHalf),
                           network: .testnet)
        let replacement = try RotationMnemonic.parse(Self.signingHalf)

        let rotation = try w.keyRotation(to: replacement)
        XCTAssertEqual(rotation.newPublicKey, try replacement.signingKeyPair().publicKey)
        XCTAssertTrue(try rotation.isProofValid(for: w.address))

        // And the contract-level guard accepts it.
        let boc = try await w.signedKeyRotation(
            rotation, seqno: 3, isDeployed: true, validUntil: 1_800_000_000)
        XCTAssertFalse(boc.isEmpty)
    }

    /// After the rotation settles, the post-rotation phrase reproduces the same wallet.
    func testPostRotationPhraseReproducesTheWallet() throws {
        let before = try RotationMnemonic.parse(Self.anchorHalf)
        let replacement = try RotationMnemonic.parse(Self.signingHalf)
        let after = before.rotated(to: replacement)

        let w = try Wallet(v5Experimental: after, network: .testnet)
        XCTAssertEqual(w.address, try Wallet(v5Experimental: before, network: .testnet).address)
        XCTAssertEqual(w.publicKey, try replacement.signingKeyPair().publicKey)
        XCTAssertEqual(after.words.count, 24)
    }

}
