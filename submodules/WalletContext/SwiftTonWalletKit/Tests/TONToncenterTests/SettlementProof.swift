import XCTest
import TONCore
import TONCrypto
import TONContracts
@testable import TONToncenter

/// The settlement proof: deploy a wallet on testnet, send a real signed transfer, and
/// confirm it landed.
///
/// This is the one check that emulation cannot make. Emulation runs with
/// `ignore_chksig`, so it proves the *structure* of a signed message is right while
/// saying nothing about whether the signature actually validates. Here the contract
/// verifies the signature itself, and the chain records the result.
///
/// Gated behind `RUN_SETTLEMENT_PROOF=1` plus a key and a wallet file, because it spends
/// real testnet funds and depends on live network state. Never part of the normal suite.
final class SettlementProofTests: XCTestCase {
    struct WalletFile: Decodable {
        let mnemonic: String
        let walletId: UInt32
        let globalId: Int32
        let addresses: Addresses

        struct Addresses: Decodable {
            let raw: String
            let nonBounceableTestnet: String
        }
    }

    private var isEnabled: Bool {
        ProcessInfo.processInfo.environment["RUN_SETTLEMENT_PROOF"] == "1"
    }

    private func loadWallet() throws -> WalletFile {
        let path = ProcessInfo.processInfo.environment["TESTNET_WALLET_FILE"]
            ?? "\(FileManager.default.currentDirectoryPath)/.testnet-wallet.json"
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try JSONDecoder().decode(WalletFile.self, from: data)
    }

    private func makeClient() throws -> ToncenterClient {
        let key = ProcessInfo.processInfo.environment["TONCENTER_KEY"]
        return ToncenterClient(network: .testnet, apiKey: key, timeout: 60)
    }

    /// Waits for a predicate to hold, polling. Settlement is not instantaneous.
    private func waitUntil(
        _ description: String,
        timeout: TimeInterval = 120,
        pollSeconds: UInt64 = 5,
        condition: () async throws -> Bool
    ) async throws -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        var attempt = 0
        while Date() < deadline {
            attempt += 1
            if try await condition() {
                print("PROOF   ✓ \(description) (after \(attempt) poll\(attempt == 1 ? "" : "s"))")
                return true
            }
            try? await Task.sleep(nanoseconds: pollSeconds * 1_000_000_000)
        }
        print("PROOF   ✗ timed out waiting for \(description)")
        return false
    }

    func testDeployAndTransfer() async throws {
        try XCTSkipUnless(isEnabled, "set RUN_SETTLEMENT_PROOF=1 to run the settlement proof")

        let file = try loadWallet()
        let client = try makeClient()
        let words = file.mnemonic.split(separator: " ").map(String.init)

        // ── 1. Derive, and confirm we derive the address that was actually funded ────
        let keyPair = try Mnemonic.keyPair(from: words)
        let wallet = WalletV5R1(publicKey: keyPair.publicKey, globalId: file.globalId)
        let address = try wallet.address()

        print("PROOF 1 derived address: \(address.rawString)")
        XCTAssertEqual(
            address.rawString.lowercased(),
            file.addresses.raw.lowercased(),
            "derived address must match the funded one"
        )
        XCTAssertEqual(wallet.config.walletID, file.walletId)

        // ── 2. Read the funded state ────────────────────────────────────────────────
        let before = try await client.getAccountState(address: address.rawString)
        print("PROOF 2 balance: \(before.balance) TON, status: \(before.status.rawValue)")
        XCTAssertGreaterThan(before.nanoton, 0, "the wallet needs funds to proceed")

        let startedDeployed = before.isDeployed
        print("PROOF 2 already deployed: \(startedDeployed)")

        // A wallet with no code has no get-methods, so seqno starts at 0.
        var seqno: UInt32 = 0
        if startedDeployed {
            let result = try await client.runGetMethod(address: address.rawString, method: "seqno", stack: [])
            var reader = try result.reader()
            seqno = UInt32(try reader.readInt())
        }
        print("PROOF 2 seqno: \(seqno)")

        // ── 3. Build a real signed transfer ─────────────────────────────────────────
        // Self-transfer: it exercises the whole path without involving anyone else's
        // wallet, and the value returns to us minus fees.
        let amount = BigUInt(10_000_000) // 0.01 TON
        let actions = try ActionList.pack([
            .sendMessage(
                mode: .walletDefault,
                message: MessageRelaxed.makeInternal(to: address, value: amount, bounce: true)
            )
        ])

        let now = UInt32(Date().timeIntervalSince1970)
        let validUntil = ValidUntil.defaultDeadline(now: now)

        let body = try wallet.createSignedBody(
            seqno: seqno,
            actions: actions,
            validUntil: validUntil,
            auth: .external,
            secretKey: keyPair.secretKey
        )
        // The state init is included only while undeployed; sending it afterwards wastes
        // fees.
        let message = try wallet.externalMessage(body: body, includeStateInit: !startedDeployed)
        let boc = try message.toCell().toBoc().base64EncodedString()

        // The hash a wallet reports and later looks the transaction up by.
        let normalized = try NormalizedMessage.normalize(base64: boc)
        print("PROOF 3 signed message: \(boc.count) base64 chars")
        print("PROOF 3 normalized hash: \(normalized.hash)")
        print("PROOF 3 includes state init: \(!startedDeployed)")

        // ── 4. Emulate before sending, as a wallet would ────────────────────────────
        let emulation = try await client.emulate(boc: boc, ignoreSignature: true)
        print("PROOF 4 emulated transactions: \(emulation.transactions.count), succeeded: \(emulation.allSucceeded)")
        XCTAssertTrue(emulation.allSucceeded, "emulation should succeed before we spend anything")
        let flow = emulation.moneyFlow(for: address.rawString)
        print("PROOF 4 money flow: sent=\(flow.sent) received=\(flow.received) fees=\(flow.fees)")

        // ── 5. Broadcast ────────────────────────────────────────────────────────────
        let sent = try await client.sendBoc(boc)
        print("PROOF 5 accepted, message hash: \(sent.messageHash)")

        // ── 6. Confirm settlement ───────────────────────────────────────────────────
        // The contract validated the signature itself; had it been wrong, no transaction
        // would ever appear.
        let landed = try await waitUntil("transaction to appear on chain", timeout: 180) {
            let page = try await client.getTransactions(address: address.rawString, limit: 5, offset: 0)
            return page.transactions.contains { tx in
                tx.inMessage?.normalizedHash?.lowercased() == normalized.hash.lowercased()
                    || tx.inMessage?.hash?.lowercased() == sent.messageHash.lowercased()
            }
        }
        XCTAssertTrue(landed, "the signed transfer should settle")

        // ── 7. Verify the effects ───────────────────────────────────────────────────
        let after = try await client.getAccountState(address: address.rawString)
        print("PROOF 7 status: \(before.status.rawValue) -> \(after.status.rawValue)")
        print("PROOF 7 balance: \(before.balance) -> \(after.balance) TON")
        XCTAssertTrue(after.isDeployed, "the wallet must be deployed after the first message")
        XCTAssertNotNil(after.code, "a deployed wallet has code")

        // seqno must have advanced, which is what prevents replay.
        let seqnoResult = try await client.runGetMethod(
            address: address.rawString,
            method: "seqno",
            stack: []
        )
        var reader = try seqnoResult.reader()
        let newSeqno = UInt32(try reader.readInt())
        print("PROOF 7 seqno: \(seqno) -> \(newSeqno)")
        XCTAssertEqual(newSeqno, seqno + 1, "seqno must increment exactly once")

        // The public key stored on chain must be the one we derived.
        let keyResult = try await client.runGetMethod(
            address: address.rawString,
            method: "get_public_key",
            stack: []
        )
        var keyReader = try keyResult.reader()
        let onChainKey = try keyReader.readBigInt()
        let derivedKey = BigInt(BigUInt(keyPair.publicKey))
        print("PROOF 7 on-chain public key matches: \(onChainKey == derivedKey)")
        XCTAssertEqual(onChainKey, derivedKey, "the deployed contract must hold our public key")

        // And the walletId, which is the network-aware value.
        let idResult = try await client.runGetMethod(
            address: address.rawString,
            method: "get_subwallet_id",
            stack: []
        )
        var idReader = try idResult.reader()
        let onChainID = UInt32(try idReader.readInt())
        print("PROOF 7 on-chain walletId: \(onChainID) (expected \(wallet.config.walletID))")
        XCTAssertEqual(onChainID, wallet.config.walletID)

        print("PROOF ✅ deploy + signed transfer + settlement verified")
    }
}
