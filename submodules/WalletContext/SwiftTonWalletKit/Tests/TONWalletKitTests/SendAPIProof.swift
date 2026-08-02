import XCTest
import TONCore
import TONCrypto
import TONContracts
import TONToncenter
import TONConnect
@testable import TONWalletKit

/// Exercises the public send API against real testnet contracts.
///
/// The payload builders are covered by golden vectors and the transfers were already proven
/// on chain — but by *test code* that hand-built its bodies. This runs the same journeys
/// through `sendTON` / `sendJetton` / `sendNFT`, so what is proven is the code a host app
/// actually calls rather than a parallel implementation that happens to agree.
///
/// Each transfer toggles direction between the V5R1 and V4R2 wallets of the same key, so
/// re-running is meaningful and nothing ends up somewhere it cannot be signed for.
///
/// Gated behind `RUN_SEND_API=1`.
final class SendAPIProofTests: XCTestCase {
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

    struct JettonFile: Decodable {
        struct Minter: Decodable { let raw: String }
        let minter: Minter
    }

    struct Refused: Error, CustomStringConvertible {
        let reason: String
        var description: String { reason }
    }

    private var isEnabled: Bool {
        ProcessInfo.processInfo.environment["RUN_SEND_API"] == "1"
    }

    private func load<T: Decodable>(_ type: T.Type, _ envKey: String, _ fallback: String) throws -> T {
        let path = ProcessInfo.processInfo.environment[envKey]
            ?? "\(FileManager.default.currentDirectoryPath)/\(fallback)"
        return try JSONDecoder().decode(T.self, from: try Data(contentsOf: URL(fileURLWithPath: path)))
    }

    private func makeKit(client: ToncenterClient) -> TonWalletKit {
        TonWalletKit(
            configuration: WalletKitConfiguration(
                deviceInfo: DeviceInfo(
                    platform: "iphone", appName: "SendAPIProof", appVersion: "1.0",
                    maxProtocolVersion: 2, features: []
                ),
                emulateBeforeApproval: false
            ),
            storage: InMemoryStorage(),
            clients: [.testnet: client],
            manifests: StubManifestFetcher.serving(domain: "example.com")
        )
    }

    private func makeClient() -> ToncenterClient {
        ToncenterClient(
            network: .testnet,
            apiKey: ProcessInfo.processInfo.environment["TONCENTER_KEY"],
            timeout: 60
        )
    }

    private func waitUntil(
        _ description: String,
        timeout: TimeInterval = 180,
        condition: () async throws -> Bool
    ) async throws -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        var attempt = 0
        while Date() < deadline {
            attempt += 1
            if try await condition() {
                print("SEND    ✓ \(description) (after \(attempt) poll\(attempt == 1 ? "" : "s"))")
                return true
            }
            try? await Task.sleep(nanoseconds: 5_000_000_000)
        }
        print("SEND    ✗ timed out waiting for \(description)")
        return false
    }

    /// Registers both wallets and returns the kit.
    private func setUpKit() async throws -> (TonWalletKit, Wallet, Wallet, ToncenterClient) {
        let file = try load(WalletFile.self, "TESTNET_WALLET_FILE", ".testnet-wallet.json")
        let client = makeClient()
        let kit = makeKit(client: client)
        let signer = try InMemorySigner(mnemonic: file.mnemonic.split(separator: " ").map(String.init))
        let v5 = try Wallet(v5r1: signer, network: .testnet)
        let v4 = try Wallet(v4r2: signer, network: .testnet)
        await kit.register(wallet: v5)
        await kit.register(wallet: v4)
        return (kit, v5, v4, client)
    }

    // MARK: - TON

    /// A plain TON transfer with a comment, through `sendTON`.
    func testSendTONWithComment() async throws {
        try XCTSkipUnless(isEnabled, "set RUN_SEND_API=1 to run the send API proof")
        let (kit, v5, v4, client) = try await setUpKit()

        let before = try await client.getAccountState(address: v4.address.toString()).nanoton
        let amount = BigUInt(20_000_000) // 0.02 TON

        let sent = try await kit.sendTON(
            from: v5.id,
            to: v4.address.toString(),
            amount: amount,
            comment: "sendTON proof"
        )
        print("SEND 1  boc \(sent.boc.count) chars, normalized \(sent.normalizedHash)")
        XCTAssertTrue(sent.normalizedHash.hasPrefix("0x"))

        let landed = try await waitUntil("recipient balance to grow") {
            try await client.getAccountState(address: v4.address.toString()).nanoton > before
        }
        XCTAssertTrue(landed, "the transfer never arrived")

        // The normalized hash is what a wallet looks the transaction up by, so it has to
        // actually resolve — a hash that never matches is worse than none.
        let found = try await waitUntil("transaction to be findable by normalized hash") {
            let page = try await client.getTransactionsByMessageHash(sent.normalizedHash)
            return !page.transactions.isEmpty
        }
        XCTAssertTrue(found, "normalized hash \(sent.normalizedHash) matched no transaction")
    }

    /// A comment long enough to spill into a reference chain.
    ///
    /// This is the case that used to throw at build time, so it is worth landing on chain once:
    /// the contract accepting it confirms the spilled layout is what TON expects, not merely
    /// what `@ton/core` also produces.
    func testSendTONWithLongComment() async throws {
        try XCTSkipUnless(isEnabled, "set RUN_SEND_API=1 to run the send API proof")
        let (kit, v5, v4, client) = try await setUpKit()

        let comment = String(repeating: "long comment. ", count: 30) // ~420 bytes
        XCTAssertGreaterThan(comment.utf8.count, 127, "must exceed a single cell")

        let before = try await client.getAccountState(address: v4.address.toString()).nanoton
        let sent = try await kit.sendTON(
            from: v5.id,
            to: v4.address.toString(),
            amount: BigUInt(15_000_000),
            comment: comment
        )
        print("SEND 2  spilled comment, \(comment.utf8.count) bytes, hash \(sent.normalizedHash)")

        let landed = try await waitUntil("long-comment transfer to arrive") {
            try await client.getAccountState(address: v4.address.toString()).nanoton > before
        }
        XCTAssertTrue(landed, "a transfer with a multi-cell comment did not arrive")
    }

    // MARK: - Jettons

    func testSendJetton() async throws {
        try XCTSkipUnless(isEnabled, "set RUN_SEND_API=1 to run the send API proof")
        let (kit, v5, v4, _) = try await setUpKit()
        let jetton = try load(JettonFile.self, "TESTNET_JETTON_FILE", ".testnet-jetton.json")
        let master = jetton.minter.raw

        let v5Before = try await kit.jettonBalance(walletID: v5.id, jettonMaster: master)
        let v4Before = try await kit.jettonBalance(walletID: v4.id, jettonMaster: master)
        print("SEND 3  v5r1 \(v5Before), v4r2 \(v4Before)")

        // Whoever holds more sends three quarters, which flips the balance so the direction
        // alternates across runs and both wallet versions get exercised as sender.
        let (sender, recipient, senderBalance, recipientBalance) =
            v5Before >= v4Before ? (v5, v4, v5Before, v4Before) : (v4, v5, v4Before, v5Before)
        guard senderBalance > 0 else { throw Refused(reason: "neither wallet holds this jetton") }
        let amount = senderBalance * 3 / 4

        let sent = try await kit.sendJetton(
            from: sender.id,
            jettonMaster: master,
            to: recipient.address.toString(),
            amount: amount,
            comment: "sendJetton proof",
            // The default one nanoton triggers a notification the recipient cannot pay to
            // process; funding it keeps the whole trace clean.
            forwardAmount: BigUInt(10_000_000)
        )
        print("SEND 3  \(sender.version) → \(recipient.version), \(amount), hash \(sent.normalizedHash)")

        let credited = try await waitUntil("recipient jetton balance to grow") {
            try await kit.jettonBalance(walletID: recipient.id, jettonMaster: master)
                == recipientBalance + amount
        }
        XCTAssertTrue(credited, "the jetton transfer never credited the recipient")

        let senderAfter = try await kit.jettonBalance(walletID: sender.id, jettonMaster: master)
        let recipientAfter = try await kit.jettonBalance(walletID: recipient.id, jettonMaster: master)
        XCTAssertEqual(senderAfter, senderBalance - amount, "sender debited by the wrong amount")
        XCTAssertEqual(
            senderAfter + recipientAfter, senderBalance + recipientBalance,
            "jettons were created or destroyed"
        )
        print("SEND 3  ✓ \(senderBalance)→\(senderAfter) and \(recipientBalance)→\(recipientAfter)")
    }

    /// The resolved jetton wallet must be the one the chain actually credits.
    func testJettonWalletResolutionMatchesTheChain() async throws {
        try XCTSkipUnless(isEnabled, "set RUN_SEND_API=1 to run the send API proof")
        let (kit, v5, _, client) = try await setUpKit()
        let jetton = try load(JettonFile.self, "TESTNET_JETTON_FILE", ".testnet-jetton.json")

        let resolved = try await kit.jettonWalletAddress(
            walletID: v5.id, jettonMaster: jetton.minter.raw
        )
        // Cross-checked against the indexer, which derives it independently.
        let page = try await client.getJettons(owner: v5.address.toString(), limit: 50, offset: 0)
        let holding = page.jettons.first {
            (try? Address.parse($0.master)) == (try? Address.parse(jetton.minter.raw))
        }
        let indexed = try XCTUnwrap(holding, "the indexer reports no holding for this jetton")
        XCTAssertEqual(
            try Address.parse(indexed.walletAddress), resolved,
            "get_wallet_address and the indexer disagree about our jetton wallet"
        )
    }

    /// An owner with no holding has no jetton wallet deployed; that is zero, not an error.
    func testJettonBalanceOfANonHolderIsZero() async throws {
        try XCTSkipUnless(isEnabled, "set RUN_SEND_API=1 to run the send API proof")
        let (kit, v5, _, _) = try await setUpKit()

        // A real, standard jetton this wallet has never touched.
        let unrelated = "0:007DE2D985BB024799D42EA100F7FD0316ABCB068B63C82B891D765F7A69171B"
        let balance = try await kit.jettonBalance(walletID: v5.id, jettonMaster: unrelated)
        XCTAssertEqual(balance, 0)
    }

    // MARK: - NFTs

    func testSendNFT() async throws {
        try XCTSkipUnless(isEnabled, "set RUN_SEND_API=1 to run the send API proof")
        let (kit, v5, v4, client) = try await setUpKit()
        let nftFile = try load(NFTFile.self, "TESTNET_NFT_FILE", ".testnet-nft.json")
        let item = try XCTUnwrap(nftFile.items.first { $0.purpose.hasPrefix("spend") })

        func owner() async throws -> Address {
            var reader = try await client.runGetMethod(
                address: item.raw, method: "get_nft_data", stack: []
            ).reader()
            _ = try reader.readBigInt()          // init flag
            _ = try reader.readBigInt()          // index
            _ = try reader.readCell()            // collection
            var slice = try reader.readCell().beginParse()
            return try slice.loadAddress()
        }

        let current = try await owner()
        let (sender, recipient): (Wallet, Wallet)
        switch current.rawString {
        case v5.address.rawString: (sender, recipient) = (v5, v4)
        case v4.address.rawString: (sender, recipient) = (v4, v5)
        default: throw Refused(reason: "item is owned by \(current.rawString), not our wallets")
        }
        print("SEND 4  \(sender.version) → \(recipient.version)")

        let sent = try await kit.sendNFT(
            from: sender.id,
            item: item.raw,
            to: recipient.address.toString(),
            comment: "sendNFT proof",
            forwardAmount: BigUInt(10_000_000)
        )
        print("SEND 4  hash \(sent.normalizedHash)")

        let moved = try await waitUntil("NFT owner to change") {
            try await owner().rawString == recipient.address.rawString
        }
        XCTAssertTrue(moved, "the NFT never changed owner")
        print("SEND 4  ✓ item now owned by \(recipient.version)")
    }

    // MARK: - Batching

    /// V5R1 carries many messages under one signature.
    ///
    /// Asserted on the sender's transaction rather than the recipient's balance: the recipient
    /// pays gas on each inbound message, so "balance grew by exactly three times the amount" is
    /// not true even when everything works. The property that matters is that *one* external
    /// message produced three outgoing ones.
    func testBatchedTransfersShareOneExternalMessage() async throws {
        try XCTSkipUnless(isEnabled, "set RUN_SEND_API=1 to run the send API proof")
        let (kit, v5, v4, client) = try await setUpKit()

        let each = BigUInt(5_000_000)
        let messages = (0..<3).map { index in
            TransferMessage(
                address: v4.address,
                amount: each,
                payload: try? TransferPayloads.comment("batch \(index)")
            )
        }

        let sent = try await kit.send(messages: messages, from: v5.id)
        print("SEND 5  batched 3 messages into one signature, hash \(sent.normalizedHash)")

        let settled = try await waitUntil("the batch to settle") {
            let page = try await client.getTransactionsByMessageHash(sent.normalizedHash)
            return !page.transactions.isEmpty
        }
        XCTAssertTrue(settled, "the batch never landed")

        let page = try await client.getTransactionsByMessageHash(sent.normalizedHash)
        let transaction = try XCTUnwrap(page.transactions.first)
        XCTAssertFalse(transaction.isFailed, "the batching transaction failed")
        XCTAssertEqual(
            transaction.outMessages.count, 3,
            "one signature must produce all three outgoing messages"
        )
        for message in transaction.outMessages {
            XCTAssertEqual(message.value.flatMap { BigUInt($0) }, each)
            XCTAssertEqual(
                try? Address.parse(message.destination ?? ""), v4.address,
                "every batched message should reach the intended recipient"
            )
        }
        print("SEND 5  ✓ one external message produced \(transaction.outMessages.count) transfers")
    }

    /// A batch beyond the contract's capacity must be refused before signing, not truncated.
    func testOversizedBatchIsRefused() async throws {
        try XCTSkipUnless(isEnabled, "set RUN_SEND_API=1 to run the send API proof")
        let (kit, _, v4, _) = try await setUpKit()

        // V4R2 stores each message as a ref and so caps at four.
        let messages = (0..<5).map { _ in
            TransferMessage(address: v4.address, amount: BigUInt(1))
        }
        do {
            _ = try await kit.send(messages: messages, from: v4.id)
            XCTFail("expected a refusal")
        } catch let error as WalletKitError {
            guard case .tooManyMessages(let count, let maximum) = error else {
                return XCTFail("expected tooManyMessages, got \(error)")
            }
            XCTAssertEqual(count, 5)
            XCTAssertEqual(maximum, 4)
        }
    }
}

extension SendAPIProofTests {
    /// The portfolio API against the wallet's real testnet holdings.
    ///
    /// The wallet holds TON, a minted jetton, and two NFTs, so every branch has something real
    /// to return — an empty result here would pass a weaker test while proving nothing.
    func testPortfolioReflectsRealHoldings() async throws {
        try XCTSkipUnless(isEnabled, "set RUN_SEND_API=1 to run the send API proof")
        let (kit, v5, v4, _) = try await setUpKit()
        let jetton = try load(JettonFile.self, "TESTNET_JETTON_FILE", ".testnet-jetton.json")

        let portfolio = try await kit.portfolio(of: v5.id)
        print("SEND 6  ton=\(portfolio.ton) jettons=\(portfolio.jettons.count) nfts=\(portfolio.nfts.count)")

        XCTAssertGreaterThan(portfolio.ton, 0, "the funded wallet should hold TON")

        // Holdings across both wallets must include the jetton we minted.
        let v4Portfolio = try await kit.portfolio(of: v4.id)
        let masters = (portfolio.jettons + v4Portfolio.jettons).compactMap {
            try? Address.parse($0.master)
        }
        let minted = try Address.parse(jetton.minter.raw)
        XCTAssertTrue(masters.contains(minted), "the minted jetton is missing from both portfolios")

        // And the NFTs we minted, wherever the transfer proofs last left them.
        let nfts = portfolio.nfts + v4Portfolio.nfts
        XCTAssertGreaterThanOrEqual(nfts.count, 2, "expected the two minted NFT items")
        for item in nfts {
            XCTAssertTrue(item.isInited, "a minted item reports itself uninitialised")
        }
    }

    /// A repeated metadata lookup must be served from the cache rather than the network.
    func testJettonMetadataIsCachedAfterTheFirstLookup() async throws {
        try XCTSkipUnless(isEnabled, "set RUN_SEND_API=1 to run the send API proof")
        let (kit, v5, v4, _) = try await setUpKit()
        let jetton = try load(JettonFile.self, "TESTNET_JETTON_FILE", ".testnet-jetton.json")

        // Whichever wallet currently holds the token — the transfer proofs move it around.
        let v5Balance = try await kit.jettonBalance(walletID: v5.id, jettonMaster: jetton.minter.raw)
        let holder = v5Balance > 0 ? v5 : v4

        await kit.clearAssetCache()
        _ = try await kit.jettonInfo(master: jetton.minter.raw, for: holder.id)
        let afterFirst = await kit.assetCacheStatistics()

        _ = try await kit.jettonInfo(master: jetton.minter.raw, for: holder.id)
        let afterSecond = await kit.assetCacheStatistics()

        XCTAssertEqual(
            afterSecond.hits, afterFirst.hits + 1,
            "the second lookup went back to the network instead of the cache"
        )
        print("SEND 7  cache hits \(afterSecond.hits), misses \(afterSecond.misses), entries \(afterSecond.entries)")
    }
}
