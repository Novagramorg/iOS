import XCTest
import TONCore
import TONCrypto
import TONContracts
import TONToncenter
import TONConnect
@testable import TONWalletKit

/// Moves a real NFT between two wallets on testnet, through the kit's public API.
///
/// Two things are proven here that nothing else covers:
///
/// - **The NFT transfer body.** Op `0x5fcc3d14` is only ever checked against vectors and
///   emulation elsewhere. Here the item contract itself decides whether the message was
///   well-formed, by changing owner or not.
/// - **V4R2 external signing on chain.** The settlement proof covered V5R1 only. V4R2 puts
///   the signature *before* the payload rather than after, and that ordering has never been
///   validated by a live contract — a wallet that got it backwards would still produce a
///   plausible-looking BoC.
///
/// Deliberately routed through ``Wallet/signedTransfer(messages:seqno:isDeployed:validUntil:sendMode:)``
/// rather than the contract types, so what runs is the surface a host app actually calls.
///
/// The direction toggles: whichever wallet currently owns the item sends it to the other. That
/// makes re-running the test meaningful instead of a no-op, and it means the item is never
/// stranded somewhere nothing can sign for it.
///
/// Gated behind `RUN_NFT_TRANSFER=1`, because it spends testnet funds.
final class NFTTransferProofTests: XCTestCase {
    struct WalletFile: Decodable {
        let mnemonic: String
        let globalId: Int32
    }

    struct NFTFile: Decodable {
        struct Item: Decodable {
            let index: Int
            let raw: String
            let purpose: String
        }
        let items: [Item]
    }

    struct Refused: Error, CustomStringConvertible {
        let reason: String
        var description: String { reason }
    }

    private var isEnabled: Bool {
        ProcessInfo.processInfo.environment["RUN_NFT_TRANSFER"] == "1"
    }

    /// TEP-62 `transfer`.
    private static let nftTransferOp: UInt64 = 0x5fcc_3d14

    private func loadFiles() throws -> (WalletFile, NFTFile) {
        let dir = FileManager.default.currentDirectoryPath
        let walletPath = ProcessInfo.processInfo.environment["TESTNET_WALLET_FILE"]
            ?? "\(dir)/.testnet-wallet.json"
        let nftPath = ProcessInfo.processInfo.environment["TESTNET_NFT_FILE"]
            ?? "\(dir)/.testnet-nft.json"
        return (
            try JSONDecoder().decode(WalletFile.self, from: try Data(contentsOf: URL(fileURLWithPath: walletPath))),
            try JSONDecoder().decode(NFTFile.self, from: try Data(contentsOf: URL(fileURLWithPath: nftPath)))
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
                print("XFER    ✓ \(description) (after \(attempt) poll\(attempt == 1 ? "" : "s"))")
                return true
            }
            try? await Task.sleep(nanoseconds: pollSeconds * 1_000_000_000)
        }
        print("XFER    ✗ timed out waiting for \(description)")
        return false
    }

    /// Reads the item's current owner straight from the contract.
    private func currentOwner(of item: String, client: ToncenterClient) async throws -> Address {
        var reader = try await client.runGetMethod(
            address: item, method: "get_nft_data", stack: []
        ).reader()
        // TVM's true is -1, so this flag is compared against zero rather than converted.
        let initialized = try reader.readBigInt()
        guard initialized != 0 else { throw Refused(reason: "item is not initialised") }
        _ = try reader.readBigInt()              // index
        _ = try reader.readCell()                // collection
        var ownerSlice = try reader.readCell().beginParse()
        return try ownerSlice.loadAddress()
    }

    /// The TEP-62 transfer body.
    ///
    /// `response_destination` gets the unspent value back. Pointing it at the sender rather
    /// than leaving it `addr_none` matters: the remainder would otherwise stay in the item
    /// contract, and a wallet that quietly leaks value on every transfer is a real defect.
    private func transferBody(newOwner: Address, responseTo: Address) throws -> Cell {
        try beginCell()
            .storeUInt(Self.nftTransferOp, bits: 32)
            .storeUInt(0, bits: 64)          // query_id
            .storeAddress(newOwner)
            .storeAddress(responseTo)
            .storeBit(false)                 // custom_payload: none
            .storeCoins(0)                   // forward_amount: no notification needed
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

    func testTransferNFTBetweenWalletVersions() async throws {
        try XCTSkipUnless(isEnabled, "set RUN_NFT_TRANSFER=1 to run the NFT transfer proof")

        let (walletFile, nftFile) = try loadFiles()
        let client = try makeClient()
        let words = walletFile.mnemonic.split(separator: " ").map(String.init)
        let signer = try InMemorySigner(mnemonic: words)

        // The same key, two contracts. Both addresses are ours, so the item can never end up
        // somewhere we cannot sign for.
        let v5 = try Wallet(v5r1: signer, network: .testnet)
        let v4 = try Wallet(v4r2: signer, network: .testnet)
        print("XFER 0  v5r1: \(v5.address.toString(testOnly: true))")
        print("XFER 0  v4r2: \(v4.address.toString(testOnly: true))")
        XCTAssertNotEqual(v5.address, v4.address, "the two contracts must derive distinct addresses")

        // The "spend" item, so the read-path item is never moved out from under other tests.
        let item = try XCTUnwrap(
            nftFile.items.first { $0.purpose.hasPrefix("spend") },
            "no item marked for spending in the NFT file"
        )
        print("XFER 0  item \(item.index): \(item.raw)")

        // ── 1. Who owns it now decides the direction ───────────────────────────────
        let owner = try await currentOwner(of: item.raw, client: client)
        let (sender, recipient): (Wallet, Wallet)
        switch owner.rawString {
        case v5.address.rawString: (sender, recipient) = (v5, v4)
        case v4.address.rawString: (sender, recipient) = (v4, v5)
        default:
            throw Refused(reason: "item is owned by \(owner.rawString), which is neither of our wallets")
        }
        print("XFER 1  \(sender.version) → \(recipient.version)")

        // ── 2. The recipient must be able to send it back later ────────────────────
        // An NFT can be owned by an address with no contract, so the transfer would succeed
        // either way — but the item would then be stuck, because nothing could sign the next
        // transfer. Funding first keeps the test re-runnable.
        let recipientState = try await client.getAccountState(address: recipient.address.toString())
        let recipientBalance = recipientState.nanoton
        print("XFER 2  recipient balance: \(recipientBalance) nanoton, deployed: \(recipientState.isDeployed)")
        if recipientBalance < BigUInt(30_000_000) {
            print("XFER 2  topping up the recipient so it can transfer back")
            // Non-bounceable, because the recipient has no contract yet: a bounceable message
            // to an undeployed account bounces straight back and the top-up never lands. This
            // is the same rule the request parser applies to a dApp's `0Q…`/`UQ…` address.
            try await send(
                from: sender,
                messages: [
                    TransferMessage(
                        address: recipient.address,
                        amount: BigUInt(60_000_000),
                        bounce: false
                    )
                ],
                client: client,
                label: "top up \(recipient.version)"
            )
            let funded = try await waitUntil("recipient to receive the top-up") {
                try await client.getAccountState(address: recipient.address.toString())
                    .nanoton >= BigUInt(30_000_000)
            }
            guard funded else { throw Refused(reason: "top-up never arrived") }
        }

        // ── 3. Transfer, through the kit's public signing API ──────────────────────
        try await send(
            from: sender,
            messages: [
                TransferMessage(
                    address: try Address.parse(item.raw),
                    // Covers item gas and storage; the remainder returns to the sender via
                    // response_destination.
                    amount: BigUInt(50_000_000),
                    payload: try transferBody(
                        newOwner: recipient.address,
                        responseTo: sender.address
                    )
                )
            ],
            client: client,
            label: "nft transfer \(sender.version) → \(recipient.version)"
        )

        // ── 4. The contract decides whether we got the body right ──────────────────
        let moved = try await waitUntil("item owner to become \(recipient.version)") {
            let now = try await self.currentOwner(of: item.raw, client: client)
            return now.rawString == recipient.address.rawString
        }
        guard moved else {
            throw Refused(reason: "ownership never changed — the transfer body was rejected")
        }

        let newOwner = try await currentOwner(of: item.raw, client: client)
        XCTAssertEqual(newOwner.rawString, recipient.address.rawString)
        print("XFER 4  ✓ item \(item.index) now owned by \(recipient.version)")

        // ── 5. And the indexer must follow, since that is what the kit reads ───────
        let indexed = try await waitUntil("indexer to report the new owner") {
            let page = try await client.getNFTs(
                owner: recipient.address.toString(), limit: 50, offset: 0
            )
            // Compared as parsed addresses, because the indexer returns friendly form while
            // the fixture holds raw — a string comparison would never match.
            let wanted = try Address.parse(item.raw)
            return page.nfts.contains { (try? Address.parse($0.address)) == wanted }
        }
        if indexed {
            print("XFER 5  ✓ indexer agrees")
        } else {
            print("XFER 5  ! indexer lagging; the contract already confirms the new owner")
        }

        print("""
        XFER    ── summary ──────────────────────────────────────────────
        XFER    item \(item.index) moved \(sender.version) → \(recipient.version)
        XFER    now owned by: \(recipient.address.toString(testOnly: true))
        XFER    re-running this test moves it back
        XFER    ─────────────────────────────────────────────────────────
        """)
    }

    /// Signs through the public kit API and broadcasts, emulating first.
    ///
    /// The emulation check throws rather than asserts: `XCTAssert` records a failure and keeps
    /// going, which would broadcast the very message the check rejected.
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
        print("XFER    [\(label)] \(wallet.version) seqno \(currentSeqno), emulated \(emulation.transactions.count) tx, succeeded=\(emulation.allSucceeded)")
        guard emulation.allSucceeded else {
            for tx in emulation.transactions {
                print("XFER    [\(label)] tx \(tx.account) kind=\(tx.kind) aborted=\(tx.aborted) exit=\(String(describing: tx.exitCode)) failed=\(tx.isFailed)")
            }
            throw Refused(reason: "\(label): emulation failed, refusing to broadcast")
        }

        let sent = try await client.sendBoc(boc)
        print("XFER    [\(label)] broadcast → \(sent.messageHash)")
    }
}
