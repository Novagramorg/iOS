import XCTest
import TONCore
import TONCrypto
import TONContracts
import TONToncenter
import TONConnect
@testable import TONWalletKit

/// Moves real jettons between two wallets on testnet, through the kit's public API.
///
/// The last of the on-chain gaps. Jetton transfers differ from TON and NFT transfers in a way
/// that only a live contract can check: the message goes to the *sender's own jetton wallet*,
/// which then talks to the recipient's — so a correct-looking body sent to the wrong contract
/// fails, and a body with the wrong `response_destination` silently strands value.
///
/// Toggles direction like ``NFTTransferProofTests``, so re-running is meaningful and the
/// balance never ends up somewhere nothing can sign for.
///
/// Gated behind `RUN_JETTON_TRANSFER=1`.
final class JettonTransferProofTests: XCTestCase {
    struct WalletFile: Decodable {
        let mnemonic: String
        let globalId: Int32
    }

    struct JettonFile: Decodable {
        struct Minter: Decodable { let raw: String }
        let minter: Minter
    }

    struct Refused: Error, CustomStringConvertible {
        let reason: String
        var description: String { reason }
    }

    private var isEnabled: Bool {
        ProcessInfo.processInfo.environment["RUN_JETTON_TRANSFER"] == "1"
    }

    /// TEP-74 `transfer`.
    private static let jettonTransferOp: UInt64 = 0x0f8a_7ea5

    /// TON forwarded to the recipient so it can process the `transfer_notification`.
    private static let forwardTONAmount = BigUInt(10_000_000)   // 0.01 TON
    /// Value on the outer message: covers both jetton wallets' gas plus the forward, with the
    /// remainder returned via `response_destination`.
    private static let transferValue = BigUInt(100_000_000)     // 0.1 TON

    private func loadFiles() throws -> (WalletFile, JettonFile) {
        let dir = FileManager.default.currentDirectoryPath
        let walletPath = ProcessInfo.processInfo.environment["TESTNET_WALLET_FILE"]
            ?? "\(dir)/.testnet-wallet.json"
        let jettonPath = ProcessInfo.processInfo.environment["TESTNET_JETTON_FILE"]
            ?? "\(dir)/.testnet-jetton.json"
        return (
            try JSONDecoder().decode(WalletFile.self, from: try Data(contentsOf: URL(fileURLWithPath: walletPath))),
            try JSONDecoder().decode(JettonFile.self, from: try Data(contentsOf: URL(fileURLWithPath: jettonPath)))
        )
    }

    private func makeClient() throws -> ToncenterClient {
        ToncenterClient(
            network: .testnet,
            apiKey: ProcessInfo.processInfo.environment["TONCENTER_KEY"],
            timeout: 60
        )
    }

    private func waitUntil(
        _ description: String,
        timeout: TimeInterval = 180,
        pollSeconds: UInt64 = 5,
        condition: () async throws -> Bool
    ) async throws -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        var attempt = 0
        while Date() < deadline {
            attempt += 1
            if try await condition() {
                print("JXFER   ✓ \(description) (after \(attempt) poll\(attempt == 1 ? "" : "s"))")
                return true
            }
            try? await Task.sleep(nanoseconds: pollSeconds * 1_000_000_000)
        }
        print("JXFER   ✗ timed out waiting for \(description)")
        return false
    }

    /// The owner's jetton wallet, as the minter computes it.
    private func jettonWallet(
        for owner: Address,
        minter: String,
        client: ToncenterClient
    ) async throws -> Address {
        let ownerCell = try beginCell().storeAddress(owner).endCell()
        var reader = try await client.runGetMethod(
            address: minter,
            method: "get_wallet_address",
            stack: [.slice(ownerCell.toBocBase64())]
        ).reader()
        var slice = try reader.readCell().beginParse()
        return try slice.loadAddress()
    }

    /// Balance held by a jetton wallet, or zero when it has not been deployed yet.
    ///
    /// An undeployed jetton wallet is the normal state for an owner who has never received
    /// the token — treating that as an error would make the first transfer untestable.
    private func balance(of jettonWallet: Address, client: ToncenterClient) async throws -> BigUInt {
        let state = try await client.getAccountState(address: jettonWallet.rawString)
        guard state.isDeployed else { return 0 }
        var reader = try await client.runGetMethod(
            address: jettonWallet.rawString, method: "get_wallet_data", stack: []
        ).reader()
        return BigUInt(try reader.readBigInt())
    }

    /// The TEP-74 transfer body.
    private func transferBody(
        amount: BigUInt,
        newOwner: Address,
        responseTo: Address
    ) throws -> Cell {
        try beginCell()
            .storeUInt(Self.jettonTransferOp, bits: 32)
            .storeUInt(0, bits: 64)          // query_id
            .storeCoins(amount)
            .storeAddress(newOwner)          // the new *owner*, not their jetton wallet
            .storeAddress(responseTo)        // excess TON comes back here
            .storeBit(false)                 // custom_payload: none
            // A notification is sent only when this is non-zero, and the recipient pays gas
            // out of it. One nanoton is enough to *trigger* the notification but not to
            // process it: the recipient's transaction then skips its compute phase for
            // `no_gas` and the notification is lost. Fund it properly or send none at all.
            .storeCoins(Self.forwardTONAmount)
            .storeBit(false)                 // forward_payload: inline, empty
            .endCell()
    }

    private func seqno(for wallet: Wallet, client: ToncenterClient) async throws -> (UInt32, Bool) {
        let state = try await client.getAccountState(address: wallet.address.toString())
        guard state.isDeployed else { return (0, false) }
        var reader = try await client.runGetMethod(
            address: wallet.address.toString(), method: "seqno", stack: []
        ).reader()
        return (UInt32(try reader.readInt()), true)
    }

    func testTransferJettonsBetweenWalletVersions() async throws {
        try XCTSkipUnless(isEnabled, "set RUN_JETTON_TRANSFER=1 to run the jetton transfer proof")

        let (walletFile, jettonFile) = try loadFiles()
        let client = try makeClient()
        let signer = try InMemorySigner(mnemonic: walletFile.mnemonic.split(separator: " ").map(String.init))

        let v5 = try Wallet(v5r1: signer, network: .testnet)
        let v4 = try Wallet(v4r2: signer, network: .testnet)
        let minter = jettonFile.minter.raw

        let v5Wallet = try await jettonWallet(for: v5.address, minter: minter, client: client)
        let v4Wallet = try await jettonWallet(for: v4.address, minter: minter, client: client)
        let v5Balance = try await balance(of: v5Wallet, client: client)
        let v4Balance = try await balance(of: v4Wallet, client: client)

        print("JXFER 0 v5r1 holds \(v5Balance) in \(v5Wallet.rawString.prefix(20))…")
        print("JXFER 0 v4r2 holds \(v4Balance) in \(v4Wallet.rawString.prefix(20))…")

        // Whoever holds more sends, so the test always has something to move.
        let (sender, senderWallet, senderBalance, recipient, recipientWallet, recipientBalance) =
            v5Balance >= v4Balance
                ? (v5, v5Wallet, v5Balance, v4, v4Wallet, v4Balance)
                : (v4, v4Wallet, v4Balance, v5, v5Wallet, v5Balance)

        guard senderBalance > 0 else {
            throw Refused(reason: "neither wallet holds any of this jetton")
        }
        // Three quarters, not a quarter: moving less than half would leave the same wallet
        // holding more every time, so the direction would never actually alternate and the
        // v4r2 side of the transfer would go permanently untested.
        let amount = senderBalance * 3 / 4
        guard amount > 0 else { throw Refused(reason: "balance too small to split") }
        print("JXFER 1 \(sender.version) → \(recipient.version), moving \(amount)")

        // ── 2. Transfer, through the kit's public signing API ──────────────────────
        // Addressed to the *sender's own* jetton wallet, which is the part that trips people
        // up: sending this body to the minter or to the recipient does nothing useful.
        try await send(
            from: sender,
            messages: [
                TransferMessage(
                    address: senderWallet,
                    amount: Self.transferValue,
                    payload: try transferBody(
                        amount: amount,
                        newOwner: recipient.address,
                        responseTo: sender.address
                    )
                )
            ],
            client: client,
            label: "jetton transfer \(sender.version) → \(recipient.version)"
        )

        // ── 3. Both balances must move, and by the same amount ─────────────────────
        let credited = try await waitUntil("recipient balance to grow by \(amount)") {
            try await self.balance(of: recipientWallet, client: client) == recipientBalance + amount
        }
        guard credited else {
            throw Refused(reason: "recipient balance never grew — the transfer body was rejected")
        }

        let senderAfter = try await balance(of: senderWallet, client: client)
        let recipientAfter = try await balance(of: recipientWallet, client: client)

        XCTAssertEqual(senderAfter, senderBalance - amount, "sender was not debited exactly")
        XCTAssertEqual(recipientAfter, recipientBalance + amount, "recipient was not credited exactly")
        // Jettons are not created or destroyed by a transfer.
        XCTAssertEqual(
            senderAfter + recipientAfter, senderBalance + recipientBalance,
            "total across both wallets changed — value was created or lost"
        )
        print("JXFER 3 ✓ \(senderBalance) → \(senderAfter) and \(recipientBalance) → \(recipientAfter)")

        // ── 4. And the indexer, which is what the kit reads ────────────────────────
        let indexed = try await waitUntil("indexer to report the recipient's balance") {
            let page = try await client.getJettons(
                owner: recipient.address.toString(), limit: 50, offset: 0
            )
            return page.jettons.contains {
                (try? Address.parse($0.master)) == (try? Address.parse(minter))
                    && BigUInt($0.balance) == recipientAfter
            }
        }
        print(indexed ? "JXFER 4 ✓ indexer agrees" : "JXFER 4 ! indexer lagging; contracts already confirm")

        print("""
        JXFER   ── summary ─────────────────────────────────────────────
        JXFER   moved \(amount) from \(sender.version) to \(recipient.version)
        JXFER   \(sender.version): \(senderAfter)   \(recipient.version): \(recipientAfter)
        JXFER   ────────────────────────────────────────────────────────
        """)
    }

    /// Signs through the public kit API and broadcasts, emulating first.
    private func send(
        from wallet: Wallet,
        messages: [TransferMessage],
        client: ToncenterClient,
        label: String
    ) async throws {
        let (currentSeqno, isDeployed) = try await seqno(for: wallet, client: client)
        let boc = try await wallet.signedTransfer(
            messages: messages.map { $0.toMessageRelaxed() },
            seqno: currentSeqno,
            isDeployed: isDeployed,
            validUntil: UInt32(Date().timeIntervalSince1970) + 300
        )

        let emulation = try await client.emulate(boc: boc, ignoreSignature: true)
        print("JXFER   [\(label)] \(wallet.version) seqno \(currentSeqno), emulated \(emulation.transactions.count) tx, succeeded=\(emulation.allSucceeded)")
        guard emulation.allSucceeded else {
            for tx in emulation.transactions {
                print("JXFER   [\(label)] tx \(tx.account.prefix(20)) aborted=\(tx.aborted) exit=\(String(describing: tx.exitCode)) skip=\(String(describing: tx.computeSkipReason)) failed=\(tx.isFailed)")
            }
            throw Refused(reason: "\(label): emulation failed, refusing to broadcast")
        }

        let sent = try await client.sendBoc(boc)
        print("JXFER   [\(label)] broadcast → \(sent.messageHash)")
    }
}
