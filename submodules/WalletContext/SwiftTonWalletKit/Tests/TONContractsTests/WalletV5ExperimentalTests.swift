import XCTest
import TONCore
import TONCrypto
@testable import TONContracts

/// Golden vectors for the wallet-v5-experimental contract.
///
/// Every expected value here was produced by running the Rust reference implementation
/// (`wallet-engine`'s vendored `ton` crate, `WalletVersion::Wallet`) against a fixed key,
/// then pasted in verbatim — not derived from this Swift code. A test that checks an
/// implementation against itself proves only that it is self-consistent, which is exactly
/// the failure mode that matters here: a wrong-but-consistent data layout derives wrong
/// addresses without ever looking wrong.
///
/// The key is the all-`0x11` seed — a published test value, not a secret.
final class WalletV5ExperimentalTests: XCTestCase {
    private static let seed = Data(repeating: 0x11, count: 32)
    private static let publicKeyHex = "d04ab232742bb4ab3a1368bd4615e4e6d0224ab71a016baf8520a332c9778737"

    private static let mainnetWalletID: UInt32 = 0x7fff_ff11
    private static let testnetWalletID: UInt32 = 0x7fff_fffd

    private func keyPair() throws -> KeyPair {
        try Ed25519.keyPair(fromSeed: Self.seed)
    }

    private func wallet(walletID: UInt32) throws -> WalletV5Experimental {
        WalletV5Experimental(publicKey: try keyPair().publicKey, walletID: walletID)
    }

    func testSeedProducesTheReferenceKey() throws {
        XCTAssertEqual(try keyPair().publicKey.hexString, Self.publicKeyHex)
    }

    // MARK: - Code

    func testCodeHashMatchesTheReference() throws {
        XCTAssertEqual(WalletCode.v5Experimental.hash().hexString, WalletCode.v5ExperimentalCodeHash)
        XCTAssertEqual(WalletCode.v5ExperimentalCodeHash, "99cca09ed5dfc604fbfe67e1d2d69a00ba74852b2365a23b49628b5633797898")
    }

    /// The contract is a fork of V5R1, so a copy-paste slip would be invisible without this.
    func testCodeDiffersFromV5R1() {
        XCTAssertNotEqual(WalletCode.v5ExperimentalCodeHash, WalletCode.v5r1CodeHash)
    }

    // MARK: - State init

    func testMainnetStateInitMatchesTheReference() throws {
        let w = try wallet(walletID: Self.mainnetWalletID)
        XCTAssertEqual(try w.dataCell().toBoc(crc32: false).hexString, "b5ee9c7201010101002b000051800000003fffff88e82559193a15da559d09b45ea30af2736811255b8d00b5d7c290519964bbc39b90")
        XCTAssertEqual(try w.dataCell().hash().hexString, "09045e66a2b8608070508cdf75a409df723d45fe3ff120f6b1a6f2c1b77f9ed4")
        XCTAssertEqual(try w.address().rawString, "0:760f492636c0f0b22474673d362c931b1e1b58ab8bc51b98b9d80baab581bdde")
    }

    func testTestnetStateInitMatchesTheReference() throws {
        let w = try wallet(walletID: Self.testnetWalletID)
        XCTAssertEqual(try w.dataCell().toBoc(crc32: false).hexString, "b5ee9c7201010101002b000051800000003ffffffee82559193a15da559d09b45ea30af2736811255b8d00b5d7c290519964bbc39b90")
        XCTAssertEqual(try w.dataCell().hash().hexString, "bbe29200817667b2ef7c56b341cf91b712068cc7ee5ce12ee28ef3d6cdcb0b43")
        XCTAssertEqual(try w.address().rawString, "0:909fb88fd833fa6f26c15cb48126308e9967077d1c45b483ac7db862e0e468fd")
    }

    /// The trailing `wasKeyChanged` bit is the entire difference in storage, and dropping
    /// it still yields a well-formed cell — just one that names a different account.
    func testDataCellIsV5R1PlusOneBit() throws {
        let publicKey = try keyPair().publicKey
        let experimental = try WalletV5Experimental(
            publicKey: publicKey, walletID: Self.testnetWalletID
        ).dataCell()
        let v5r1 = try WalletV5R1(
            publicKey: publicKey, walletID: Self.testnetWalletID
        ).dataCell()

        XCTAssertEqual(v5r1.bits.length, 322)
        XCTAssertEqual(experimental.bits.length, v5r1.bits.length + 1)
        XCTAssertNotEqual(experimental.hash(), v5r1.hash())
    }

    /// Same key, same walletId, different contract — so different funds.
    func testAddressDiffersFromV5R1ForTheSameKey() throws {
        let publicKey = try keyPair().publicKey
        let experimental = try WalletV5Experimental(
            publicKey: publicKey, walletID: Self.testnetWalletID
        ).address()
        let v5r1 = try WalletV5R1(publicKey: publicKey, walletID: Self.testnetWalletID).address()
        XCTAssertNotEqual(experimental, v5r1)
    }

    func testNetworkAwareWalletIDMatchesTheExplicitOne() throws {
        let publicKey = try keyPair().publicKey
        XCTAssertEqual(
            try WalletV5Experimental(publicKey: publicKey, globalId: -3).address(),
            try WalletV5Experimental(publicKey: publicKey, walletID: Self.testnetWalletID).address()
        )
        XCTAssertEqual(
            try WalletV5Experimental(publicKey: publicKey, globalId: -239).address(),
            try WalletV5Experimental(publicKey: publicKey, walletID: Self.mainnetWalletID).address()
        )
    }

    // MARK: - Message bodies

    /// The reference harness is fed these exact message cells rather than building its
    /// own. The wallet contract only refs them, never parses them, and the two stacks
    /// disagree on an unrelated encoding choice — this Rust crate always stores a message
    /// body as a ref, while @ton/core (which this kit ports) inlines a body that fits.
    /// Both are valid `Either` encodings with different hashes, so using one set of bytes
    /// on both sides keeps the comparison about the wallet layer.
    private func transfer(to tag: UInt8, value: BigUInt, bounce: Bool) -> MessageRelaxed {
        MessageRelaxed.makeInternal(
            to: Address(workchain: 0, hash: Data(repeating: tag, count: 32)),
            value: value,
            bounce: bounce
        )
    }

    private func oneTransferActions() throws -> Cell {
        try ActionList.pack([
            .sendMessage(
                mode: SendMode(rawValue: 3),
                message: transfer(to: 0xaa, value: 1_000_000_000, bounce: false)
            )
        ])
    }

    func testUnsignedExternalBodyMatchesTheReference() throws {
        let body = try wallet(walletID: Self.testnetWalletID).unsignedBody(
            seqno: 5,
            walletID: Self.testnetWalletID,
            actions: try oneTransferActions(),
            validUntil: 1_800_000_000,
            auth: .external
        )
        XCTAssertEqual(body.toBoc(crc32: false).hexString, "b5ee9c720101040100550001217369676e7ffffffd6b49d20000000005a001020a0ec3c86d030203000000684200555555555555555555555555555555555555555555555555555555555555555521dcd6500000000000000000000000000000")
        XCTAssertEqual(body.hash().hexString, "9e5881b5b798d94a8482bc12ea388e39af24cd515a1bb4e89595147ad9b7e4b7")
    }

    /// The bodies are not merely compatible with V5R1's, they are the same bytes.
    /// ``WalletV5Experimental`` relies on that by delegating; this is what holds it true.
    func testBodyIsByteIdenticalToV5R1() throws {
        let actions = try oneTransferActions()
        let publicKey = try keyPair().publicKey
        let a = try WalletV5Experimental(publicKey: publicKey, walletID: Self.testnetWalletID)
            .unsignedBody(seqno: 5, walletID: Self.testnetWalletID, actions: actions,
                          validUntil: 1_800_000_000, auth: .external)
        let b = try WalletV5R1(publicKey: publicKey, walletID: Self.testnetWalletID)
            .unsignedBody(seqno: 5, walletID: Self.testnetWalletID, actions: actions,
                          validUntil: 1_800_000_000, auth: .external)
        XCTAssertEqual(a.hash(), b.hash())
    }

    func testInternalSignedBodyMatchesTheReference() throws {
        let body = try wallet(walletID: Self.testnetWalletID).unsignedBody(
            seqno: 7,
            walletID: Self.testnetWalletID,
            actions: try oneTransferActions(),
            validUntil: 1_800_000_000,
            auth: .internalMessage
        )
        XCTAssertEqual(body.toBoc(crc32: false).hexString, "b5ee9c7201010401005500012173696e747ffffffd6b49d20000000007a001020a0ec3c86d030203000000684200555555555555555555555555555555555555555555555555555555555555555521dcd6500000000000000000000000000000")
        XCTAssertEqual(body.hash().hexString, "71d5f06c5a68e9e388a761263d19fcfc5e7d6690884c1b55f59bba929bfd0e89")
    }

    // MARK: - Signed external messages

    /// The two stacks encode the external-message envelope differently and both are
    /// correct: the body is an `Either X ^X`, this kit inlines it when it fits (@ton/core
    /// semantics, which is what the on-chain proofs in this repo were sent with), and the
    /// Rust crate's `Msg::new` hardcodes the ref form. So the envelope BoCs cannot be
    /// compared directly.
    ///
    /// Two things are compared instead, and between them they pin everything that matters:
    /// the **signed body**, byte for byte — that is the wallet layer's actual output,
    /// signature included — and the **TEP-467 normalized hash**, which is the identity the
    /// network and every explorer use to name this transaction. Normalization forces the
    /// body into a ref and drops src, import fee and state init, so it is exactly the value
    /// that must survive the encoding difference.

    func testSignedDeployBodyMatchesTheReference() throws {
        let keys = try keyPair()
        let w = try wallet(walletID: Self.testnetWalletID)
        let body = try w.createSignedBody(
            seqno: 0,
            actions: try oneTransferActions(),
            validUntil: 1_800_000_000,
            auth: .external,
            secretKey: keys.secretKey
        )
        XCTAssertEqual(body.hash().hexString, "467929c8c4ab9d7f2aab14341efa95c584119c1c24ee1ab7f6b3af568305bd6b")
        // Single-cell-chain case, where cell numbering is unambiguous, so the serialized
        // bytes can be compared too.
        XCTAssertEqual(body.toBoc(crc32: false).hexString, "b5ee9c720101040100950001a17369676e7ffffffd6b49d2000000000094e7bf64257c0b9dc2bac63ade56a14f3c0300a3764447524043917ed3fd038b5b85fade5f04bf56d9f8538bc12a97e6b54a51b58fde9822e48b387ca60e58c0e001020a0ec3c86d030203000000684200555555555555555555555555555555555555555555555555555555555555555521dcd6500000000000000000000000000000")
    }

    func testSignedDeployTransferHasTheReferenceNormalizedHash() throws {
        let keys = try keyPair()
        let w = try wallet(walletID: Self.testnetWalletID)
        let body = try w.createSignedBody(
            seqno: 0,
            actions: try oneTransferActions(),
            validUntil: 1_800_000_000,
            auth: .external,
            secretKey: keys.secretKey
        )
        let external = try w.externalMessage(body: body, includeStateInit: true)
        let normalized = try NormalizedMessage.normalize(boc: external.toCell().toBoc())
        XCTAssertEqual(normalized.hashBytes.hexString, "2984b913cbd152562b5165a9dd12040252247ac2df79ad6f5027034402d3858e")
    }

    private func twoTransferActions() throws -> Cell {
        try ActionList.pack([
            .sendMessage(
                mode: SendMode(rawValue: 3),
                message: transfer(to: 0xaa, value: 1_000_000_000, bounce: false)
            ),
            .sendMessage(
                mode: SendMode(rawValue: 3),
                message: transfer(to: 0xbb, value: 2, bounce: true)
            ),
        ])
    }

    func testSignedTwoMessageBodyMatchesTheReference() throws {
        let keys = try keyPair()
        let w = try wallet(walletID: Self.testnetWalletID)
        let body = try w.createSignedBody(
            seqno: 5,
            actions: try twoTransferActions(),
            validUntil: 1_800_000_000,
            auth: .external,
            secretKey: keys.secretKey
        )
        // Hash only: with two sibling leaves the two BoC writers number cells in a
        // different order, which changes the bytes without changing the DAG. The cell
        // hash is the canonical identity, and it is what the address and the message
        // hash are built from.
        XCTAssertEqual(body.hash().hexString, "b5896fabe9deab8e2397fa0a2ddf88b82a4134ea57dd735dbd5c7ef80ee03baa")
        XCTAssertEqual(
            try Cell.fromBoc(body.toBoc()).hash(),
            body.hash(),
            "our own BoC must round-trip"
        )
    }

    func testSignedTwoMessageTransferHasTheReferenceNormalizedHash() throws {
        let keys = try keyPair()
        let w = try wallet(walletID: Self.testnetWalletID)
        let body = try w.createSignedBody(
            seqno: 5,
            actions: try twoTransferActions(),
            validUntil: 1_800_000_000,
            auth: .external,
            secretKey: keys.secretKey
        )
        let external = try w.externalMessage(body: body, includeStateInit: false)
        let normalized = try NormalizedMessage.normalize(boc: external.toCell().toBoc())
        XCTAssertEqual(normalized.hashBytes.hexString, "594eb8ff899b64243d28091daefaf9d8b446ddb4e497c76757a0e29de4124bf9")
    }

    // MARK: - Key rotation

    private func newKeys() throws -> KeyPair {
        try Ed25519.keyPair(fromSeed: Data(repeating: 0x22, count: 32))
    }

    /// The message is `"KEY_ROTATION" ‖ int8 workchain ‖ uint256 addrHash`, 45 bytes,
    /// spelled out independently here so a change to
    /// ``KeyRotation/proofMessage(workchain:addressHash:)`` cannot quietly redefine what
    /// gets signed.
    func testProofMessageMatchesTheContractPayload() throws {
        let address = try wallet(walletID: Self.testnetWalletID).address()

        var expected = Data("KEY_ROTATION".utf8)
        expected.append(UInt8(bitPattern: address.workchain))
        expected.append(address.hash)
        // 12 + 1 + 32; CHKSIGNS refuses a slice whose bit length is not a multiple of 8.
        XCTAssertEqual(expected.count, 45)

        XCTAssertEqual(KeyRotation.proofMessage(address: address), expected)
    }

    /// The proof signs the message itself, never its hash.
    ///
    /// This is the single most dangerous detail in the contract: `CHKSIGNS` hands the raw
    /// bytes to Ed25519, while the same contract's transfer path uses `CHKSIGNU`, where the
    /// signed value *is* a hash. Signing `sha256` here produces a signature that is
    /// perfectly valid and that the contract rejects with exit code 149 — indistinguishable
    /// from using the wrong key. Verified against the deployed contract on testnet.
    func testProofSignsRawBytesNotTheirHash() throws {
        let address = try wallet(walletID: Self.testnetWalletID).address()
        let new = try newKeys()
        let message = KeyRotation.proofMessage(address: address)

        let rotation = try KeyRotation.make(
            address: address, newPublicKey: new.publicKey, newSecretKey: new.secretKey
        )
        XCTAssertEqual(
            rotation.proof,
            try Ed25519.sign(message, secretKey: new.secretKey),
            "the proof must be a signature over the 45-byte message"
        )
        XCTAssertNotEqual(
            rotation.proof,
            try Ed25519.sign(Hashing.sha256(message), secretKey: new.secretKey),
            "signing sha256 of the message is the failure mode this test exists to catch"
        )
        XCTAssertTrue(try rotation.isProofValid(for: address))
    }

    /// A proof made for one wallet must not authorize a rotation on another.
    func testProofIsBoundToTheWalletAddress() throws {
        let mainnet = try wallet(walletID: Self.mainnetWalletID).address()
        let testnet = try wallet(walletID: Self.testnetWalletID).address()
        XCTAssertNotEqual(
            KeyRotation.proofMessage(address: mainnet),
            KeyRotation.proofMessage(address: testnet)
        )

        let new = try newKeys()
        let rotation = try KeyRotation.make(
            address: testnet, newPublicKey: new.publicKey, newSecretKey: new.secretKey
        )
        XCTAssertTrue(try rotation.isProofValid(for: testnet))
        XCTAssertFalse(try rotation.isProofValid(for: mainnet))
    }

    /// `newPublicKey:uint256 proof:bits512` — 768 bits, no refs. The contract reads both
    /// inline; a `proof` in a ref makes it fail with a cell underflow.
    func testRotationCellLayout() throws {
        let address = try wallet(walletID: Self.testnetWalletID).address()
        let new = try newKeys()
        let rotation = try KeyRotation.make(
            address: address, newPublicKey: new.publicKey, newSecretKey: new.secretKey
        )
        let cell = try rotation.toCell()
        XCTAssertEqual(cell.bits.length, 256 + 512)
        XCTAssertTrue(cell.refs.isEmpty)

        var slice = cell.beginParse()
        XCTAssertEqual(try slice.loadBigUInt(256), BigUInt(new.publicKey))
        XCTAssertEqual(try slice.loadBytes(64), rotation.proof)
    }

    /// The action is tag `0x05` with the rotation in a ref, and it is an *extended* action —
    /// so it must land in the extended slot of the list, not among out-actions.
    func testChangeKeyActionEncoding() throws {
        let address = try wallet(walletID: Self.testnetWalletID).address()
        let new = try newKeys()
        let rotation = try KeyRotation.make(
            address: address, newPublicKey: new.publicKey, newSecretKey: new.secretKey
        )
        let action = WalletV5Action.changeKey(rotation)
        XCTAssertTrue(action.isExtended)

        let cell = try action.serialize()
        var slice = cell.beginParse()
        XCTAssertEqual(try slice.loadUInt(8), 0x05)
        XCTAssertEqual(try slice.loadRef().hash(), try rotation.toCell().hash())

        let list = try wallet(walletID: Self.testnetWalletID).changeKeyActions(rotation)
        var listSlice = list.beginParse()
        XCTAssertFalse(try listSlice.loadBit(), "out-actions must be absent")
        XCTAssertTrue(try listSlice.loadBit(), "extended action must be present")
        XCTAssertEqual(try listSlice.loadUInt(8), 0x05)
    }

    /// Each guard mirrors a contract check, and each one costs gas and a seqno if it is
    /// left to the contract to catch.
    func testRotationGuardsRefuseWhatTheContractWouldReject() throws {
        let keys = try keyPair()
        let w = try wallet(walletID: Self.testnetWalletID)
        let address = try w.address()
        let new = try newKeys()

        // Rotating to the key already in storage — exit code 148.
        let sameKey = try KeyRotation.make(
            address: address, newPublicKey: keys.publicKey, newSecretKey: keys.secretKey
        )
        XCTAssertThrowsError(try w.changeKeyActions(sameKey)) {
            XCTAssertEqual($0 as? WalletV5Experimental.KeyRotationError, .sameKey)
        }

        // A proof signed by the old key rather than the new one — exit code 149.
        let wrongSigner = KeyRotation(
            newPublicKey: new.publicKey,
            proof: try Ed25519.sign(
                KeyRotation.proofMessage(address: address), secretKey: keys.secretKey
            )
        )
        XCTAssertThrowsError(try w.changeKeyActions(wrongSigner)) {
            XCTAssertEqual($0 as? WalletV5Experimental.KeyRotationError, .invalidProof)
        }

        // A proof over the hash instead of the message — the mistake that cost this port
        // a day. Locally indistinguishable from a wrong key, so the guard must catch it.
        let preHashed = KeyRotation(
            newPublicKey: new.publicKey,
            proof: try Ed25519.sign(
                Hashing.sha256(KeyRotation.proofMessage(address: address)),
                secretKey: new.secretKey
            )
        )
        XCTAssertThrowsError(try w.changeKeyActions(preHashed)) {
            XCTAssertEqual($0 as? WalletV5Experimental.KeyRotationError, .invalidProof)
        }

        let valid = try KeyRotation.make(
            address: address, newPublicKey: new.publicKey, newSecretKey: new.secretKey
        )
        XCTAssertNoThrow(try w.changeKeyActions(valid))

        // A second rotation — exit code 151.
        XCTAssertThrowsError(try w.rotated(to: new.publicKey).changeKeyActions(valid)) {
            XCTAssertEqual($0 as? WalletV5Experimental.KeyRotationError, .alreadyRotated)
        }
    }

    /// Rotation changes the key, not the account: the address is fixed by the deployed
    /// state init, so re-deriving it from the new key would point at a different wallet.
    func testRotatedWalletKeepsItsIdentityButNotItsDerivation() throws {
        let w = try wallet(walletID: Self.testnetWalletID)
        let new = try newKeys()
        let rotated = w.rotated(to: new.publicKey)

        XCTAssertEqual(rotated.config.publicKey, new.publicKey)
        XCTAssertTrue(rotated.config.wasKeyChanged)
        XCTAssertEqual(rotated.config.walletID, w.config.walletID)
        XCTAssertNotEqual(try rotated.address(), try w.address())
    }
}
