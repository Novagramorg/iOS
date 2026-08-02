import XCTest
import TONCore
import TONToncenter
import TONConnect
@testable import TONWalletKit

/// Verifies the message bodies a wallet-initiated transfer sends.
///
/// These are checked by round-tripping each body back through a parser, field by field. A body
/// with fields in the wrong order is still a valid cell that signs and broadcasts cleanly — the
/// receiving contract simply does something other than what the user asked, or nothing. Only
/// re-reading the bytes catches that.
///
/// The layouts are the ones the live contracts accepted during the on-chain proofs, so this is
/// a regression net over behaviour already confirmed against real TEP-74 and TEP-62 contracts.
final class TransferPayloadTests: XCTestCase {
    private let alice = try! Address.parse("0:bd0ef4d11b0aae0e8cbba3a8b194fbafc7f1ab453f3531b2f2f5bfe633a9b615")
    private let bob = try! Address.parse("0:83dfd552e63729b472fcbcc8c45ebcc6691702558b68ec7527e1ba403a0f31a8")

    // MARK: - Comments

    func testCommentIsOpZeroThenText() throws {
        let cell = try TransferPayloads.comment("gm")
        var slice = cell.beginParse()

        XCTAssertEqual(try slice.loadUInt(32), 0, "a text comment is op 0")
        XCTAssertEqual(try slice.loadStringTail(), "gm")
    }

    func testEmptyCommentIsStillWellFormed() throws {
        var slice = try TransferPayloads.comment("").beginParse()
        XCTAssertEqual(try slice.loadUInt(32), 0)
        XCTAssertEqual(try slice.loadStringTail(), "")
    }

    /// A comment longer than one cell must spill into refs rather than overflow.
    ///
    /// The text comes from a user, so the length is not something the kit controls; a build-time
    /// failure here would be a crash on ordinary input.
    func testLongCommentSpillsIntoReferences() throws {
        let long = String(repeating: "a", count: 500)
        let cell = try TransferPayloads.comment(long)
        XCTAssertFalse(cell.refs.isEmpty, "500 bytes cannot fit in one cell")

        var slice = cell.beginParse()
        XCTAssertEqual(try slice.loadUInt(32), 0)
        XCTAssertEqual(try slice.loadStringTail(), long)
    }

    func testUnicodeCommentSurvives() throws {
        let text = "спасибо 🙏 — 感谢"
        var slice = try TransferPayloads.comment(text).beginParse()
        _ = try slice.loadUInt(32)
        XCTAssertEqual(try slice.loadStringTail(), text)
    }

    // MARK: - Jetton transfer

    /// Reads a jetton transfer body back, in TEP-74 field order.
    private func parseJetton(_ cell: Cell) throws -> (
        op: UInt64, queryID: UInt64, amount: BigUInt,
        destination: Address, response: Address?,
        customPayload: Cell?, forwardAmount: BigUInt, forwardPayload: Cell?
    ) {
        var s = cell.beginParse()
        return (
            try s.loadUInt(32),
            try s.loadUInt(64),
            try s.loadCoins(),
            try s.loadAddress(),
            try s.loadMaybeAddress(),
            try s.loadMaybeRef(),
            try s.loadCoins(),
            try s.loadMaybeRef()
        )
    }

    func testJettonTransferLayout() throws {
        let body = try TransferPayloads.jettonTransfer(
            amount: 1_000,
            destination: bob,
            responseDestination: alice,
            queryID: 42
        )
        let parsed = try parseJetton(body)

        XCTAssertEqual(parsed.op, TransferPayloads.jettonTransferOp)
        XCTAssertEqual(parsed.op, 0x0f8a_7ea5, "the opcode is fixed by TEP-74")
        XCTAssertEqual(parsed.queryID, 42)
        XCTAssertEqual(parsed.amount, 1_000)
        XCTAssertEqual(parsed.destination, bob)
        XCTAssertEqual(parsed.response, alice)
        XCTAssertNil(parsed.customPayload)
        XCTAssertEqual(parsed.forwardAmount, TransferPayloads.defaultForwardAmount)
        XCTAssertNil(parsed.forwardPayload)
    }

    /// The destination is the recipient's *owner* address, never their jetton wallet.
    ///
    /// Encoded as a test because a balance listing shows the jetton wallet, which makes it the
    /// tempting thing to pass — and the resulting transfer is rejected by the contract.
    func testJettonDestinationIsTheOwnerNotAJettonWallet() throws {
        let body = try TransferPayloads.jettonTransfer(
            amount: 1, destination: bob, responseDestination: alice
        )
        XCTAssertEqual(try parseJetton(body).destination, bob)
    }

    /// A comment rides in the forward payload so it reaches the recipient, not the jetton wallet.
    func testJettonCommentTravelsAsForwardPayload() throws {
        let body = try TransferPayloads.jettonTransfer(
            amount: 5, destination: bob, responseDestination: alice, comment: "thanks"
        )
        let parsed = try parseJetton(body)

        var forward = try XCTUnwrap(parsed.forwardPayload).beginParse()
        XCTAssertEqual(try forward.loadUInt(32), 0)
        XCTAssertEqual(try forward.loadStringTail(), "thanks")
    }

    /// An explicit forward payload must win over the comment convenience rather than both being
    /// silently written or the comment overwriting a caller's payload.
    func testExplicitForwardPayloadWinsOverComment() throws {
        let explicit = try beginCell().storeUInt(0xdead_beef, bits: 32).endCell()
        let body = try TransferPayloads.jettonTransfer(
            amount: 5,
            destination: bob,
            responseDestination: alice,
            comment: "ignored",
            forwardPayload: explicit
        )
        let parsed = try parseJetton(body)
        XCTAssertEqual(try XCTUnwrap(parsed.forwardPayload).hash(), explicit.hash())
    }

    /// A nil response destination is legal but forfeits the unspent TON, so the default path
    /// must not produce one by accident.
    func testJettonResponseDestinationCanBeOmittedButIsNotByDefault() throws {
        let withNone = try TransferPayloads.jettonTransfer(
            amount: 1, destination: bob, responseDestination: nil
        )
        XCTAssertNil(try parseJetton(withNone).response, "addr_none must round-trip as nil")

        let withSender = try TransferPayloads.jettonTransfer(
            amount: 1, destination: bob, responseDestination: alice
        )
        XCTAssertEqual(try parseJetton(withSender).response, alice)
    }

    func testJettonCustomPayloadIsCarried() throws {
        let custom = try beginCell().storeUInt(7, bits: 8).endCell()
        let body = try TransferPayloads.jettonTransfer(
            amount: 1, destination: bob, responseDestination: alice, customPayload: custom
        )
        XCTAssertEqual(try XCTUnwrap(try parseJetton(body).customPayload).hash(), custom.hash())
    }

    func testJettonForwardAmountIsConfigurable() throws {
        let body = try TransferPayloads.jettonTransfer(
            amount: 1, destination: bob, responseDestination: alice,
            forwardAmount: BigUInt(10_000_000)
        )
        XCTAssertEqual(try parseJetton(body).forwardAmount, 10_000_000)
    }

    /// Large amounts must survive: jettons commonly use 9 decimals, so realistic supplies
    /// exceed 64 bits.
    func testJettonAmountHandlesLargeValues() throws {
        let huge = BigUInt("123456789012345678901234567890")
        let body = try TransferPayloads.jettonTransfer(
            amount: huge, destination: bob, responseDestination: alice
        )
        XCTAssertEqual(try parseJetton(body).amount, huge)
    }

    // MARK: - NFT transfer

    private func parseNFT(_ cell: Cell) throws -> (
        op: UInt64, queryID: UInt64, newOwner: Address, response: Address?,
        customPayload: Cell?, forwardAmount: BigUInt, forwardPayload: Cell?
    ) {
        var s = cell.beginParse()
        return (
            try s.loadUInt(32),
            try s.loadUInt(64),
            try s.loadAddress(),
            try s.loadMaybeAddress(),
            try s.loadMaybeRef(),
            try s.loadCoins(),
            try s.loadMaybeRef()
        )
    }

    func testNFTTransferLayout() throws {
        let body = try TransferPayloads.nftTransfer(
            newOwner: bob, responseDestination: alice, queryID: 9
        )
        let parsed = try parseNFT(body)

        XCTAssertEqual(parsed.op, TransferPayloads.nftTransferOp)
        XCTAssertEqual(parsed.op, 0x5fcc_3d14, "the opcode is fixed by TEP-62")
        XCTAssertEqual(parsed.queryID, 9)
        XCTAssertEqual(parsed.newOwner, bob)
        XCTAssertEqual(parsed.response, alice)
        XCTAssertNil(parsed.customPayload)
        XCTAssertEqual(parsed.forwardAmount, TransferPayloads.defaultForwardAmount)
        XCTAssertNil(parsed.forwardPayload)
    }

    func testNFTCommentTravelsAsForwardPayload() throws {
        let body = try TransferPayloads.nftTransfer(
            newOwner: bob, responseDestination: alice, comment: "enjoy"
        )
        var forward = try XCTUnwrap(try parseNFT(body).forwardPayload).beginParse()
        XCTAssertEqual(try forward.loadUInt(32), 0)
        XCTAssertEqual(try forward.loadStringTail(), "enjoy")
    }

    /// The two bodies differ only in opcode and the amount field, which makes confusing them
    /// easy — and a jetton body sent to an NFT item is simply rejected.
    func testJettonAndNFTBodiesAreDistinguishable() throws {
        let jetton = try TransferPayloads.jettonTransfer(
            amount: 1, destination: bob, responseDestination: alice
        )
        let nft = try TransferPayloads.nftTransfer(newOwner: bob, responseDestination: alice)

        var jettonSlice = jetton.beginParse()
        var nftSlice = nft.beginParse()
        XCTAssertNotEqual(try jettonSlice.loadUInt(32), try nftSlice.loadUInt(32))
        XCTAssertNotEqual(jetton.hash(), nft.hash())
    }

    // MARK: - Cross-check against the bodies the live contracts accepted

    /// The on-chain proofs hand-built their bodies; these builders must produce the same bytes.
    ///
    /// Without this the library could drift from what was actually proven to work, and the
    /// proof would be evidence about code no caller runs.
    func testMatchesTheBodyProvenOnChainForNFT() throws {
        // Rebuilt exactly as `NFTTransferProofTests.transferBody` did: no custom payload, no
        // forward payload, and forward amount zero.
        let handBuilt = try beginCell()
            .storeUInt(0x5fcc_3d14, bits: 32)
            .storeUInt(0, bits: 64)
            .storeAddress(bob)
            .storeAddress(alice)
            .storeBit(false)
            .storeCoins(0)
            .storeBit(false)
            .endCell()

        let built = try TransferPayloads.nftTransfer(
            newOwner: bob,
            responseDestination: alice,
            forwardAmount: 0
        )
        XCTAssertEqual(built.hash(), handBuilt.hash(), "builder drifted from the proven body")
    }

    func testMatchesTheBodyProvenOnChainForJetton() throws {
        // As `JettonTransferProofTests` sent it: 0.01 TON forward, no payloads.
        let forward = BigUInt(10_000_000)
        let handBuilt = try beginCell()
            .storeUInt(0x0f8a_7ea5, bits: 32)
            .storeUInt(0, bits: 64)
            .storeCoins(250_000_000_000)
            .storeAddress(bob)
            .storeAddress(alice)
            .storeBit(false)
            .storeCoins(forward)
            .storeBit(false)
            .endCell()

        let built = try TransferPayloads.jettonTransfer(
            amount: 250_000_000_000,
            destination: bob,
            responseDestination: alice,
            forwardAmount: forward
        )
        XCTAssertEqual(built.hash(), handBuilt.hash(), "builder drifted from the proven body")
    }
}

/// Verifies the guard against underfunding an asset transfer.
///
/// A jetton or NFT contract pays the forward amount *out of* the value attached to the message.
/// Attaching too little makes it abort with exit code 709 (`not_enough_tons`) — nothing moves,
/// and the send reports success because the external message was accepted by the network. That
/// is the worst shape of failure: silent, and only visible by re-reading the balance.
///
/// Found by raising `forwardAmount` on a live transfer without raising the attached value.
final class AttachedValueGuardTests: XCTestCase {
    let mnemonic = """
    dose ice enrich trigger test dove century still betray gas diet dune \
    use other base gym mad law immense village world example praise game
    """.split(separator: " ").map(String.init)

    func makeKit() async throws -> (TonWalletKit, Wallet) {
        let kit = TonWalletKit(
            configuration: WalletKitConfiguration(
                deviceInfo: DeviceInfo(
                    platform: "test", appName: "test", appVersion: "1",
                    maxProtocolVersion: 2, features: []
                ),
                emulateBeforeApproval: false,
                // Nothing should reach the network: every case here must be refused first.
                skipBroadcast: true
            ),
            storage: InMemoryStorage(),
            clients: [.testnet: StubApiClient()]
        )
        let wallet = try Wallet(v5r1: InMemorySigner(mnemonic: mnemonic), network: .testnet)
        await kit.register(wallet: wallet)
        return (kit, wallet)
    }

    let recipient = "0:83dfd552e63729b472fcbcc8c45ebcc6691702558b68ec7527e1ba403a0f31a8"
    let master = "0:10b3bb6ad6e55b650001a06d86359c9a40ffa55416b6c234ab13eed4ffeded3e"

    func testAttachingLessThanTheForwardIsRefused() async throws {
        let (kit, wallet) = try await makeKit()
        do {
            _ = try await kit.sendJetton(
                from: wallet.id,
                jettonMaster: master,
                to: recipient,
                amount: 100,
                forwardAmount: BigUInt(50_000_000),
                attachedTON: BigUInt(10_000_000)   // less than the forward
            )
            XCTFail("expected a refusal")
        } catch let error as WalletKitError {
            guard case .validationFailed(let reason) = error else {
                return XCTFail("expected validationFailed, got \(error)")
            }
            XCTAssertTrue(reason.contains("709"), reason)
        }
    }

    /// Enough to cover the forward but nothing left for gas is still doomed.
    func testAttachingTooLittleGasIsRefused() async throws {
        let (kit, wallet) = try await makeKit()
        do {
            _ = try await kit.sendJetton(
                from: wallet.id,
                jettonMaster: master,
                to: recipient,
                amount: 100,
                forwardAmount: BigUInt(10_000_000),
                attachedTON: BigUInt(10_000_001)   // one nanoton of gas
            )
            XCTFail("expected a refusal")
        } catch let error as WalletKitError {
            guard case .validationFailed(let reason) = error else {
                return XCTFail("expected validationFailed, got \(error)")
            }
            XCTAssertTrue(reason.contains("gas"), reason)
        }
    }

    /// The default must scale with the forward amount, or the convenient call is the broken one.
    ///
    /// This is the case that actually failed on chain: a caller who raises `forwardAmount` and
    /// leaves the attached value alone.
    func testDefaultAttachedValueScalesWithTheForward() async throws {
        let (kit, wallet) = try await makeKit()
        // No attachedTON given, and a forward far above the flat default that used to be used.
        let sent = try await kit.sendJetton(
            from: wallet.id,
            jettonMaster: master,
            to: recipient,
            amount: 100,
            forwardAmount: BigUInt(200_000_000)
        )

        // Read the attached value back out of the signed message.
        let attached = try Self.firstOutgoingValue(inSignedBoc: sent.boc)
        XCTAssertGreaterThan(
            attached, BigUInt(200_000_000),
            "the attached value must exceed the forward, or the contract aborts with 709"
        )
        XCTAssertGreaterThanOrEqual(
            attached - BigUInt(200_000_000), TransferPayloads.defaultJettonGas,
            "gas headroom must survive a large forward"
        )
    }

    func testNFTDefaultAlsoScales() async throws {
        let (kit, wallet) = try await makeKit()
        let sent = try await kit.sendNFT(
            from: wallet.id,
            item: master,
            to: recipient,
            forwardAmount: BigUInt(200_000_000)
        )
        let attached = try Self.firstOutgoingValue(inSignedBoc: sent.boc)
        XCTAssertGreaterThanOrEqual(
            attached - BigUInt(200_000_000), TransferPayloads.defaultNFTGas
        )
    }

    /// With the conventional one-nanoton forward, the default must stay at the reference's
    /// 0.05 TON rather than drifting upward and overcharging every transfer.
    func testDefaultMatchesTheReferenceForTheUsualForward() async throws {
        let (kit, wallet) = try await makeKit()
        let sent = try await kit.sendJetton(
            from: wallet.id, jettonMaster: master, to: recipient, amount: 100
        )
        let attached = try Self.firstOutgoingValue(inSignedBoc: sent.boc)
        XCTAssertEqual(
            attached,
            TransferPayloads.defaultJettonGas + TransferPayloads.defaultForwardAmount,
            "0.05 TON plus one nanoton is what the reference attaches"
        )
    }

    /// Digs the outgoing message's value out of a signed V5R1 external message.
    ///
    /// Body: `opcode(32) walletId(32) validUntil(32) seqno(32)` then the action list inline.
    /// The list is a maybe-ref to the out-actions chain; each link stores the *next* link as a
    /// plain ref first, then its own `action_send_msg` inline with the message as a ref.
    private static func firstOutgoingValue(inSignedBoc boc: String) throws -> BigUInt {
        var slice = try Cell.fromBase64(boc).beginParse()
        let message = try Message.load(from: &slice)

        var body = message.body.beginParse()
        _ = try body.loadUInt(32)          // auth opcode
        _ = try body.loadUInt(32)          // wallet id
        _ = try body.loadUInt(32)          // valid until
        _ = try body.loadUInt(32)          // seqno

        let outActions = try XCTUnwrap(try body.loadMaybeRef(), "no out-actions in the body")
        var action = outActions.beginParse()
        _ = try action.loadRef()           // the next link in the chain
        _ = try action.loadUInt(32)        // action_send_msg tag
        _ = try action.loadUInt(8)         // send mode
        var out = try action.loadRef().beginParse()

        guard case .internalMessage(let info) = try MessageRelaxed.load(from: &out).info else {
            throw NSError(domain: "not an internal message", code: 1)
        }
        return info.value.coins
    }
}

extension AttachedValueGuardTests {
    /// Underfunding must throw, never trap.
    ///
    /// The guard's arithmetic is deliberately addition-only: `attached - forwardAmount` traps on
    /// `BigUInt` underflow, so an implementation that subtracts first crashes the process on a
    /// caller's bad input instead of returning an error. A mutation confirmed that — it took the
    /// whole test binary down with `_BigInt/Subtraction.swift: Precondition failed` rather than
    /// failing an assertion.
    func testExtremeUnderfundingThrowsRatherThanTrapping() async throws {
        let (kit, wallet) = try await makeKit()

        // Forward vastly exceeding the attached value: the subtraction order that would trap.
        for (attached, forward) in [
            (BigUInt(0), BigUInt(1)),
            (BigUInt(1), BigUInt(1_000_000_000_000)),
            (BigUInt(0), BigUInt(0)),
        ] {
            do {
                _ = try await kit.sendJetton(
                    from: wallet.id,
                    jettonMaster: master,
                    to: recipient,
                    amount: 1,
                    forwardAmount: forward,
                    attachedTON: attached
                )
                XCTFail("expected a refusal for attached=\(attached) forward=\(forward)")
            } catch is WalletKitError {
                // Reaching here at all is the assertion: a trap would have killed the process.
            }
        }
    }
}
