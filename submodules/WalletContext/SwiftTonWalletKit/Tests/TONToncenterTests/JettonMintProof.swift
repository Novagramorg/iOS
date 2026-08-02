import XCTest
import TONCore
import TONCrypto
import TONContracts
@testable import TONToncenter

/// Deploys a TEP-74 jetton minter on testnet and mints a balance to our wallet.
///
/// The counterpart to the NFT mint: jetton read and transfer paths were the last part of the
/// port with no on-chain material to exercise them.
///
/// Same approach and same hard-won rules as ``NFTMintProofTests``: clone the code from a live
/// standard contract rather than compiling, vet every candidate read-only before spending, and
/// make the emulation check `throw` so it actually stops the send.
///
/// Gated behind `RUN_JETTON_MINT=1`.
final class JettonMintProofTests: XCTestCase {
    struct WalletFile: Decodable {
        let mnemonic: String
        let globalId: Int32
        struct Addresses: Decodable { let raw: String }
        let addresses: Addresses
    }

    struct Refused: Error, CustomStringConvertible {
        let reason: String
        var description: String { reason }
    }

    private var isEnabled: Bool {
        ProcessInfo.processInfo.environment["RUN_JETTON_MINT"] == "1"
    }

    /// One representative per distinct code hash seen on testnet basechain.
    private static let candidateMinters = [
        "0:007DE2D985BB024799D42EA100F7FD0316ABCB068B63C82B891D765F7A69171B",
        "0:007D9A3A605C7B1D912A1B836BCBDA56DF5DAAD54C3CFF69D4778EA2F5F062B1",
        "0:008246647D64558DED07E613E907824A4A25E8AF73AA59650196FB3529CC1BB3",
        "0:00A52CEF219B6CF30DD87B2AFCB5FD8140FDDC000928A7EDDC03DD4688CE4055",
        "0:00969234F35F7D92DEA41DF1EE2A4088EF0D17F52F20249B93C3D3B1268D90A5",
        "0:008AB74055C3E3829263BCF8E1A3B964546815FBA6406F91239DE8BA3B5D7A24",
        "0:004F6D80024A6247D32D1CAD4FE59E88772C39A2875EDD5596B0D1DD45C3B46F",
        "0:0058E9AA6158A366C9D99D8FF8F9C2F145E94EDA748B9C6D22BB7FC4604569BC",
        "0:0073A9E662148F37D8794A3F0A0E09C5F5295F1CF368BC843C42668112E24305",
        "0:007E410303B72CBEFA5F18DDED45CCF81478371C761C9AABD3CC4D48CE43B4E8",
    ]

    private var candidates: [String] {
        if let override = ProcessInfo.processInfo.environment["JETTON_SOURCE_MINTER"] {
            return [override]
        }
        return Self.candidateMinters
    }

    /// TEP-74 opcodes.
    private static let mintOp: UInt64 = 21
    private static let internalTransferOp: UInt64 = 0x178d_4519

    private func loadWallet() throws -> WalletFile {
        let path = ProcessInfo.processInfo.environment["TESTNET_WALLET_FILE"]
            ?? "\(FileManager.default.currentDirectoryPath)/.testnet-wallet.json"
        return try JSONDecoder().decode(
            WalletFile.self,
            from: try Data(contentsOf: URL(fileURLWithPath: path))
        )
    }

    private func makeClient() throws -> ToncenterClient {
        ToncenterClient(
            network: .testnet,
            apiKey: ProcessInfo.processInfo.environment["TONCENTER_KEY"],
            timeout: 60
        )
    }

    static func artifact(_ name: String) -> String {
        "\(FileManager.default.currentDirectoryPath)/.jetton-artifacts-\(name)"
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
                print("JMINT   ✓ \(description) (after \(attempt) poll\(attempt == 1 ? "" : "s"))")
                return true
            }
            try? await Task.sleep(nanoseconds: pollSeconds * 1_000_000_000)
        }
        print("JMINT   ✗ timed out waiting for \(description)")
        return false
    }

    // MARK: - Step 1: vet and stash

    private struct Vetted {
        let address: String
        let codeBase64: String
        let codeHash: String
        let walletCode: Cell
    }

    /// Read-only vetting. Nothing here spends anything.
    private func vet(_ address: String, client: ToncenterClient) async -> Vetted? {
        func reject(_ why: String) -> Vetted? {
            print("JMINT   ✗ \(address.prefix(18))… \(why)")
            return nil
        }

        do {
            let state = try await client.getAccountState(address: address)
            guard let codeBase64 = state.code, let dataBase64 = state.data else {
                return reject("no code or data")
            }
            let code = try Cell.fromBase64(codeBase64)

            // TEP-74 jetton-minter storage:
            //   total_supply:Coins admin_address:MsgAddress
            //   content:^Cell jetton_wallet_code:^Cell
            var slice = try Cell.fromBase64(dataBase64).beginParse()
            let totalSupply = try slice.loadCoins()
            let admin = try slice.loadAddress()
            _ = try slice.loadRef()                  // content
            let walletCode = try slice.loadRef()

            // The get-method must agree with the parse, which is what shows the field order is
            // right rather than coincidentally parseable.
            var reader = try await client.runGetMethod(
                address: address, method: "get_jetton_data", stack: []
            ).reader()
            let methodSupply = try reader.readBigInt()
            _ = try reader.readBigInt()              // mintable
            var adminSlice = try reader.readCell().beginParse()
            guard BigUInt(methodSupply) == totalSupply else {
                return reject("total_supply disagrees with get_jetton_data")
            }
            guard try adminSlice.loadAddress().rawString == admin.rawString else {
                return reject("admin disagrees with get_jetton_data")
            }

            // Same trap as the NFT collection: the workchain is baked into the compiled code,
            // so a masterchain build would put every jetton wallet there.
            let derived = try await jettonWalletAddress(
                client: client,
                minter: address,
                owner: "0:0000000000000000000000000000000000000000000000000000000000000000"
            )
            guard derived.workchain == 0 else {
                return reject("compiled for workchain \(derived.workchain)")
            }

            print("JMINT   ✓ \(address.prefix(18))… standard, basechain, supply \(totalSupply)")
            return Vetted(
                address: address,
                codeBase64: codeBase64,
                codeHash: code.hash().base64EncodedString(),
                walletCode: walletCode
            )
        } catch {
            return reject("vetting threw: \(error)")
        }
    }

    func testInspectStandardMinter() async throws {
        try XCTSkipUnless(isEnabled, "set RUN_JETTON_MINT=1 to run the jetton mint")

        let client = try makeClient()
        var chosen: Vetted?
        for candidate in candidates {
            if let vetted = await vet(candidate, client: client) {
                chosen = vetted
                break
            }
        }

        let source = try XCTUnwrap(chosen, "no candidate minter passed vetting")
        print("JMINT   chose \(source.address)")
        print("JMINT   minter code hash: \(source.codeHash)")
        print("JMINT   wallet code hash: \(source.walletCode.hash().base64EncodedString())")

        try source.codeBase64.write(toFile: Self.artifact("minter-code.b64"), atomically: true, encoding: .utf8)
        try source.walletCode.toBocBase64().write(toFile: Self.artifact("wallet-code.b64"), atomically: true, encoding: .utf8)
        try source.codeHash.write(toFile: Self.artifact("minter-code-hash.txt"), atomically: true, encoding: .utf8)
        print("JMINT   stashed code cells")
    }

    // MARK: - Step 2: deploy and mint

    private let metadataURI = "https://example.invalid/walletkit-testnet/jetton.json"

    /// TEP-64 offchain content: the 0x01 tag then the URI.
    private func content() throws -> Cell {
        try beginCell()
            .storeUInt(0x01, bits: 8)
            .storeStringTail(metadataURI)
            .endCell()
    }

    func testDeployMinterAndMint() async throws {
        try XCTSkipUnless(isEnabled, "set RUN_JETTON_MINT=1 to run the jetton mint")

        let file = try loadWallet()
        let client = try makeClient()
        let words = file.mnemonic.split(separator: " ").map(String.init)
        let keyPair = try Mnemonic.keyPair(from: words)
        let wallet = WalletV5R1(publicKey: keyPair.publicKey, globalId: file.globalId)
        let walletAddress = try wallet.address()
        print("JMINT 0 wallet: \(walletAddress.rawString)")

        // ── 1. Code, cloned and re-verified ────────────────────────────────────────
        let minterCode = try Cell.fromBase64(
            try String(contentsOfFile: Self.artifact("minter-code.b64"), encoding: .utf8)
        )
        let jettonWalletCode = try Cell.fromBase64(
            try String(contentsOfFile: Self.artifact("wallet-code.b64"), encoding: .utf8)
        )
        let expectedHash = try String(
            contentsOfFile: Self.artifact("minter-code-hash.txt"), encoding: .utf8
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        guard minterCode.hash().base64EncodedString() == expectedHash else {
            throw Refused(reason: "stashed minter code does not match the inspected hash")
        }
        print("JMINT 1 code hash verified: \(expectedHash)")

        // ── 2. Minter state init ───────────────────────────────────────────────────
        let minterData = try beginCell()
            .storeCoins(0)                 // total_supply
            .storeAddress(walletAddress)   // admin — us, so we can mint
            .storeRef(try content())
            .storeRef(jettonWalletCode)
            .endCell()

        let minterInit = StateInit(code: minterCode, data: minterData)
        let minter = Address(workchain: 0, hash: try minterInit.toCell().hash())
        print("JMINT 2 minter: \(minter.toString(testOnly: true))")

        let minterState = try await client.getAccountState(address: minter.rawString)
        if !minterState.isDeployed {
            try await send(
                messages: [
                    MessageRelaxed.makeInternal(
                        to: minter,
                        value: BigUInt(50_000_000),
                        bounce: false,           // a deploy must not bounce, or the init is lost
                        stateInit: minterInit
                    )
                ],
                wallet: wallet, keyPair: keyPair, client: client, label: "minter deploy"
            )
            let live = try await waitUntil("minter to become active") {
                try await client.getAccountState(address: minter.rawString).isDeployed
            }
            guard live else { throw Refused(reason: "minter never deployed") }
        } else {
            print("JMINT 2 already deployed")
        }

        var dataReader = try await client.runGetMethod(
            address: minter.rawString, method: "get_jetton_data", stack: []
        ).reader()
        let supplyBefore = try dataReader.readBigInt()
        print("JMINT 3 total supply before: \(supplyBefore)")

        // ── 4. Where our jetton wallet will live, per the minter itself ────────────
        let jettonWallet = try await jettonWalletAddress(
            client: client, minter: minter.rawString, owner: walletAddress.rawString
        )
        print("JMINT 4 our jetton wallet: \(jettonWallet.rawString)")
        guard jettonWallet.workchain == walletAddress.workchain else {
            throw Refused(reason: "jetton wallet would land in workchain \(jettonWallet.workchain)")
        }

        // ── 5. Mint ────────────────────────────────────────────────────────────────
        // Two nested bodies: the minter takes op=21, and forwards `master_msg` to the jetton
        // wallet as an `internal_transfer`. Getting the inner one wrong fails at the wallet,
        // not the minter, which is why emulation covers all three transactions.
        let mintAmount = BigUInt(1_000_000_000_000)   // 1000 units at 9 decimals
        let masterMessage = try beginCell()
            .storeUInt(Self.internalTransferOp, bits: 32)
            .storeUInt(0, bits: 64)              // query_id
            .storeCoins(mintAmount)              // jetton amount
            .storeAddress(nil)                   // from_address: the minter itself
            .storeAddress(walletAddress)         // response_address — excess comes back to us
            .storeCoins(0)                       // forward_ton_amount
            .storeBit(false)                     // forward_payload: inline, empty
            .endCell()

        let mintBody = try beginCell()
            .storeUInt(Self.mintOp, bits: 32)
            .storeUInt(0, bits: 64)              // query_id
            .storeAddress(walletAddress)         // to_address — the new holder
            .storeCoins(BigUInt(30_000_000))     // TON forwarded to the jetton wallet
            .storeRef(masterMessage)
            .endCell()

        try await send(
            messages: [
                MessageRelaxed.makeInternal(
                    to: minter,
                    value: BigUInt(70_000_000),
                    bounce: true,                // a rejected mint should return the value
                    body: mintBody
                )
            ],
            wallet: wallet, keyPair: keyPair, client: client, label: "mint \(mintAmount)"
        )

        let live = try await waitUntil("jetton wallet to become active") {
            try await client.getAccountState(address: jettonWallet.rawString).isDeployed
        }
        guard live else { throw Refused(reason: "jetton wallet never deployed") }

        // ── 6. The jetton wallet must report our balance ───────────────────────────
        var walletReader = try await client.runGetMethod(
            address: jettonWallet.rawString, method: "get_wallet_data", stack: []
        ).reader()
        let balance = try walletReader.readBigInt()
        var ownerSlice = try walletReader.readCell().beginParse()
        var masterSlice = try walletReader.readCell().beginParse()

        XCTAssertEqual(BigUInt(balance), mintAmount, "minted balance mismatch")
        XCTAssertEqual(
            try ownerSlice.loadAddress().rawString, walletAddress.rawString,
            "jetton wallet is owned by someone else"
        )
        XCTAssertEqual(
            try masterSlice.loadAddress().rawString, minter.rawString,
            "jetton wallet points at a different minter"
        )
        print("JMINT 6 ✓ balance \(balance) owned by us")

        // Supply must have grown by exactly what we minted.
        var afterReader = try await client.runGetMethod(
            address: minter.rawString, method: "get_jetton_data", stack: []
        ).reader()
        let supplyAfter = try afterReader.readBigInt()
        XCTAssertEqual(
            BigUInt(supplyAfter), BigUInt(supplyBefore) + mintAmount,
            "total supply did not grow by the minted amount"
        )

        // ── 7. And the indexer, which is what the kit reads ────────────────────────
        let indexed = try await waitUntil("indexer to report our jetton balance") {
            let page = try await client.getJettons(
                owner: walletAddress.rawString, limit: 50, offset: 0
            )
            return page.jettons.contains {
                (try? Address.parse($0.master)) == minter
            }
        }
        if indexed {
            let page = try await client.getJettons(owner: walletAddress.rawString, limit: 50, offset: 0)
            for holding in page.jettons {
                print("JMINT 7   \(holding.master) wallet=\(holding.walletAddress) balance=\(holding.balance)")
            }
        } else {
            print("JMINT 7 ! indexer lagging; the contract already confirms the balance")
        }

        print("""
        JMINT   ── summary ─────────────────────────────────────────────
        JMINT   minter        : \(minter.toString(testOnly: true))
        JMINT   our jetton wal: \(jettonWallet.toString(testOnly: true))
        JMINT   balance       : \(balance)
        JMINT   ────────────────────────────────────────────────────────
        """)
    }

    /// Asks the minter where an owner's jetton wallet lives.
    ///
    /// Computed by the contract, not by us: the address depends on the wallet code the minter
    /// stores and the workchain baked into it, so an independent derivation would be a second
    /// implementation that could quietly disagree.
    private func jettonWalletAddress(
        client: ToncenterClient,
        minter: String,
        owner: String
    ) async throws -> Address {
        let ownerCell = try beginCell().storeAddress(try Address.parse(owner)).endCell()
        var reader = try await client.runGetMethod(
            address: minter,
            method: "get_wallet_address",
            stack: [.slice(ownerCell.toBocBase64())]
        ).reader()
        var slice = try reader.readCell().beginParse()
        return try slice.loadAddress()
    }

    private func send(
        messages: [MessageRelaxed],
        wallet: WalletV5R1,
        keyPair: KeyPair,
        client: ToncenterClient,
        label: String
    ) async throws {
        let address = try wallet.address().rawString
        let state = try await client.getAccountState(address: address)
        var seqno: UInt32 = 0
        if state.isDeployed {
            var reader = try await client.runGetMethod(
                address: address, method: "seqno", stack: []
            ).reader()
            seqno = UInt32(try reader.readInt())
        }

        let actions = try ActionList.pack(
            messages.map { .sendMessage(mode: .walletDefault, message: $0) }
        )
        let body = try wallet.createSignedBody(
            seqno: seqno,
            actions: actions,
            validUntil: ValidUntil.defaultDeadline(now: UInt32(Date().timeIntervalSince1970)),
            auth: .external,
            secretKey: keyPair.secretKey
        )
        let message = try wallet.externalMessage(body: body, includeStateInit: !state.isDeployed)
        let boc = try message.toCell().toBoc().base64EncodedString()

        let emulation = try await client.emulate(boc: boc, ignoreSignature: true)
        print("JMINT   [\(label)] emulated \(emulation.transactions.count) tx, succeeded=\(emulation.allSucceeded)")
        guard emulation.allSucceeded else {
            for tx in emulation.transactions {
                print("JMINT   [\(label)] tx \(tx.account.prefix(20)) aborted=\(tx.aborted) exit=\(String(describing: tx.exitCode)) failed=\(tx.isFailed)")
            }
            throw Refused(reason: "\(label): emulation failed, refusing to broadcast")
        }

        let sent = try await client.sendBoc(boc)
        print("JMINT   [\(label)] broadcast → \(sent.messageHash)")
    }
}
