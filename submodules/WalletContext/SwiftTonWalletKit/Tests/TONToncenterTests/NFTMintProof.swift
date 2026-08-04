import XCTest
import TONCore
import TONCrypto
import TONContracts
@testable import TONToncenter

/// Deploys a TEP-62 NFT collection on testnet and mints an item to our wallet.
///
/// Exists because jetton and NFT flows were the one part of the port with no on-chain
/// evidence: the test wallet held neither, so every NFT code path was verified only against
/// vectors and emulation. Owning a real item makes the transfer path testable end to end.
///
/// The contract code is **copied from an already-deployed standard collection** rather than
/// compiled. There is no FunC toolchain here, and hand-writing the code cell would be worse:
/// this way the bytecode is provably the same as what other testnet collections run.
///
/// Two properties of the source code are checked before anything is spent, because both were
/// learned the expensive way:
///
/// - **Workchain.** `workchain()` is a compile-time constant in the standard contract, so a
///   collection compiled for masterchain puts every item on masterchain regardless of where
///   the collection itself sits. The first attempt cloned such a variant and minted an item
///   into workchain -1, where the forwarded value was too small for masterchain gas.
/// - **Code identity.** The hash observed during inspection is asserted again at mint time,
///   so the source contract cannot change between the two steps.
///
/// Gated behind `RUN_NFT_MINT=1`, because it spends testnet funds and deploys contracts.
final class NFTMintProofTests: XCTestCase {
    struct WalletFile: Decodable {
        let mnemonic: String
        let globalId: Int32
        struct Addresses: Decodable { let raw: String }
        let addresses: Addresses
    }

    /// A gating failure. Thrown rather than asserted, because `XCTAssert` records a failure
    /// and *keeps going* — which is how the first run broadcast a mint whose emulation had
    /// already failed. A gate has to stop the test, so it throws.
    struct Refused: Error, CustomStringConvertible {
        let reason: String
        var description: String { reason }
    }

    private var isEnabled: Bool {
        ProcessInfo.processInfo.environment["RUN_NFT_MINT"] == "1"
    }

    /// Collections to consider cloning, one per distinct code hash seen on testnet basechain.
    ///
    /// A list rather than a single address because "standard TEP-62" is not one contract in
    /// practice: the deployed population includes masterchain builds, marketplace forks with
    /// different content layouts, and the plain reference contract. Which is which is not
    /// visible from the outside, so the vetting below decides instead of a guess.
    private static let candidateCollections = [
        "0:01C0F792063D4A175F718EBC9904F16C7264799AE8921D66AE93D0CC0585EAF4",
        "0:01C54113F84CBB3E62D9C1E8C400463F08566F4590FDE7745AB3162D754D7F31",
        "0:0006DBAC66F651A2DFC0DE94F8415B6A9F31160A28678F6300955C680F49C765",
        "0:00FF2C9DE66541051BFD1DDF1AEB6089F3959DB4724BFDA0A10B32DD5A3554D8",
        "0:01DC12642A77F0D3A08F11443432F58A81784987F7AAA54F94CE25C5C79803BB",
        "0:01E15AE8F3CDA1C1F6619D0665601978AE95E2F93FF8024672FFD2B405867974",
        "0:023295217A7CBDDB408BFAD346AF134381D541823C233115ABB064F9607BE34A",
        "0:024E51DCB69B202D6D6C1BA92E9ABD2BEFBA80F95B53BF8881DE6DCA2AEC16EF",
        "0:01E840A2414C5877771DD930D5184536DDEB788A264EA00A556C0AB670161834",
        "0:01F5BD2B340F2269D8BE76D9DE0800B23916BBA96DE4B7A33E6159232FD09E6C",
        "0:009522F86C8AB5A631AC0FE76EED19BF51E9D9B60F6929AFA8D5F212229531C1",
        "0:002D8A5BFF4BAE8A448263DD5FBC1DB0807212E337035617393824E279284B24",
        "0:016407E0A2EC44BCBECA7ED74AFA481BF129E2DAF9CA6373D982BDA14C39F0BD",
        "0:01C652C3658383809D72C8F2A6AB027A66244E923DF960F67A9CC1D3E027C35B",
    ]

    private var candidates: [String] {
        if let override = ProcessInfo.processInfo.environment["NFT_SOURCE_COLLECTION"] {
            return [override]
        }
        return Self.candidateCollections
    }

    /// Everything a candidate must satisfy before its code is worth cloning.
    private struct Vetted {
        let address: String
        let codeBase64: String
        let codeHash: String
        let itemCode: Cell
    }

    /// Checks one candidate, returning nil with a printed reason when it fails.
    ///
    /// Read-only: nothing here spends anything, which is the point — every disqualifying
    /// property is detectable before a transaction exists.
    private func vet(_ address: String, client: ToncenterClient) async -> Vetted? {
        func reject(_ why: String) -> Vetted? {
            print("MINT    ✗ \(address.prefix(18))… \(why)")
            return nil
        }

        do {
            let state = try await client.getAccountState(address: address)
            guard let codeBase64 = state.code, let dataBase64 = state.data else {
                return reject("no code or data")
            }
            let code = try Cell.fromBase64(codeBase64)

            // TEP-62 nft-collection storage:
            //   owner_address:MsgAddress next_item_index:uint64
            //   content:^Cell nft_item_code:^Cell royalty_params:^Cell
            var slice = try Cell.fromBase64(dataBase64).beginParse()
            let owner = try slice.loadAddress()
            let nextIndex = try slice.loadUInt(64)
            let content = try slice.loadRef()
            let itemCode = try slice.loadRef()
            let royalty = try slice.loadRef()

            // Two refs means collection metadata plus the common prefix items build on. A
            // fork that stores content differently would need a different builder, and
            // guessing at one is how the previous attempt wasted a mint.
            guard content.refs.count == 2 else {
                return reject("content holds \(content.refs.count) refs, expected 2 (nonstandard fork)")
            }

            var royaltySlice = royalty.beginParse()
            _ = try royaltySlice.loadUInt(16)
            let denominator = try royaltySlice.loadUInt(16)
            _ = try royaltySlice.loadAddress()
            guard denominator > 0 else { return reject("royalty denominator is zero") }

            // The get-method must agree with the parse, which is what shows the field order is
            // right rather than coincidentally parseable.
            var reader = try await client.runGetMethod(
                address: address, method: "get_collection_data", stack: []
            ).reader()
            let methodNextIndex = try reader.readBigInt()
            _ = try reader.readCell()
            var ownerSlice = try reader.readCell().beginParse()
            guard BigUInt(nextIndex) == BigUInt(methodNextIndex) else {
                return reject("next_item_index disagrees with get_collection_data")
            }
            guard try ownerSlice.loadAddress().rawString == owner.rawString else {
                return reject("owner disagrees with get_collection_data")
            }

            // `workchain()` is a compile-time constant in the standard contract, so a build
            // for masterchain puts every item there no matter where the collection sits.
            let derived = try await nftAddress(client: client, collection: address, index: 0)
            guard derived.workchain == 0 else {
                return reject("compiled for workchain \(derived.workchain), items would land there")
            }

            print("MINT    ✓ \(address.prefix(18))… standard, basechain, \(nextIndex) items minted")
            return Vetted(
                address: address,
                codeBase64: codeBase64,
                codeHash: code.hash().base64EncodedString(),
                itemCode: itemCode
            )
        } catch {
            return reject("vetting threw: \(error)")
        }
    }

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
        "\(FileManager.default.currentDirectoryPath)/.nft-artifacts-\(name)"
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
                print("MINT    ✓ \(description) (after \(attempt) poll\(attempt == 1 ? "" : "s"))")
                return true
            }
            try? await Task.sleep(nanoseconds: pollSeconds * 1_000_000_000)
        }
        print("MINT    ✗ timed out waiting for \(description)")
        return false
    }

    // MARK: - Step 1: vet and stash the source code

    /// Picks the first candidate that passes every check and stashes its code.
    func testInspectStandardCollection() async throws {
        try XCTSkipUnless(isEnabled, "set RUN_NFT_MINT=1 to run the NFT mint")

        let client = try makeClient()
        var chosen: Vetted?
        for candidate in candidates {
            if let vetted = await vet(candidate, client: client) {
                chosen = vetted
                break
            }
        }

        let source = try XCTUnwrap(
            chosen,
            "no candidate collection passed vetting; none is the plain standard basechain contract"
        )
        print("MINT    chose \(source.address)")
        print("MINT    collection code hash: \(source.codeHash)")
        print("MINT    item code hash: \(source.itemCode.hash().base64EncodedString())")

        try source.codeBase64.write(toFile: Self.artifact("collection-code.b64"), atomically: true, encoding: .utf8)
        try source.itemCode.toBocBase64().write(toFile: Self.artifact("item-code.b64"), atomically: true, encoding: .utf8)
        try source.codeHash.write(toFile: Self.artifact("collection-code-hash.txt"), atomically: true, encoding: .utf8)
        print("MINT    stashed code cells")
    }

    // MARK: - Step 2: deploy and mint

    /// Base URI for metadata. A placeholder: nothing is hosted there, because what is being
    /// proven is ownership and the transfer path, not metadata rendering.
    private let baseURI = "https://example.invalid/walletkit-testnet/"

    /// Builds the TEP-64 offchain content pair the standard collection expects.
    ///
    /// `collection_content` carries the 0x01 offchain tag; `common_content` does not, because
    /// the item's `get_nft_content` concatenates it with the item suffix and adds the tag
    /// itself. Tagging both would embed the marker byte mid-URI.
    private func collectionContent() throws -> Cell {
        let collectionMeta = try beginCell()
            .storeUInt(0x01, bits: 8)
            .storeStringTail("\(baseURI)collection.json")
            .endCell()
        let commonPrefix = try beginCell()
            .storeStringTail(baseURI)
            .endCell()
        return try beginCell()
            .storeRef(collectionMeta)
            .storeRef(commonPrefix)
            .endCell()
    }

    private func royaltyParams(destination: Address) throws -> Cell {
        try beginCell()
            .storeUInt(0, bits: 16)      // numerator — no royalty on a test collection
            .storeUInt(1000, bits: 16)   // denominator, non-zero or the contract divides by 0
            .storeAddress(destination)
            .endCell()
    }

    func testDeployCollectionAndMintItem() async throws {
        try XCTSkipUnless(isEnabled, "set RUN_NFT_MINT=1 to run the NFT mint")

        let file = try loadWallet()
        let client = try makeClient()
        let words = file.mnemonic.split(separator: " ").map(String.init)
        let keyPair = try Mnemonic.keyPair(from: words)
        let wallet = WalletV5R1(publicKey: keyPair.publicKey, globalId: file.globalId)
        let walletAddress = try wallet.address()

        XCTAssertEqual(walletAddress.rawString, file.addresses.raw, "derived a different wallet")
        print("MINT 0  wallet: \(walletAddress.rawString)")

        // ── 1. Contract code, cloned and re-verified ────────────────────────────────
        let collectionCode = try Cell.fromBase64(
            try String(contentsOfFile: Self.artifact("collection-code.b64"), encoding: .utf8)
        )
        let itemCode = try Cell.fromBase64(
            try String(contentsOfFile: Self.artifact("item-code.b64"), encoding: .utf8)
        )
        let expectedHash = try String(
            contentsOfFile: Self.artifact("collection-code-hash.txt"),
            encoding: .utf8
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        guard collectionCode.hash().base64EncodedString() == expectedHash else {
            throw Refused(reason: "stashed collection code does not match the inspected hash")
        }
        print("MINT 1  code hash verified: \(expectedHash)")

        // ── 2. Collection state init, in the order the live contract's storage proved ──
        let collectionData = try beginCell()
            .storeAddress(walletAddress)   // owner_address — us, so we can mint
            .storeUInt(0, bits: 64)        // next_item_index
            .storeRef(try collectionContent())
            .storeRef(itemCode)
            .storeRef(try royaltyParams(destination: walletAddress))
            .endCell()

        let collectionInit = StateInit(code: collectionCode, data: collectionData)
        let collectionAddress = Address(workchain: 0, hash: try collectionInit.toCell().hash())
        print("MINT 2  collection: \(collectionAddress.rawString)")
        print("MINT 2  collection (friendly): \(collectionAddress.toString(testOnly: true))")

        let collectionState = try await client.getAccountState(address: collectionAddress.rawString)
        print("MINT 2  already deployed: \(collectionState.isDeployed)")

        // ── 3. Deploy the collection, unless a previous run already did ─────────────
        if !collectionState.isDeployed {
            try await send(
                messages: [
                    MessageRelaxed.makeInternal(
                        to: collectionAddress,
                        value: BigUInt(50_000_000), // 0.05 TON — deploy plus storage runway
                        // Non-bounceable: a deploy must not come back, or the state init is
                        // lost with it.
                        bounce: false,
                        stateInit: collectionInit
                    )
                ],
                wallet: wallet, keyPair: keyPair, client: client, label: "collection deploy"
            )

            let live = try await waitUntil("collection to become active") {
                try await client.getAccountState(address: collectionAddress.rawString).isDeployed
            }
            guard live else { throw Refused(reason: "collection never deployed") }
        }

        // The contract answering its own get-method is what proves the data cell was built in
        // an order the code can read.
        var infoReader = try await client.runGetMethod(
            address: collectionAddress.rawString,
            method: "get_collection_data",
            stack: []
        ).reader()
        let nextIndexBefore = try infoReader.readBigInt()
        print("MINT 3  get_collection_data next_item_index=\(nextIndexBefore)")

        // ── 4. Where item 0 will live, per the contract itself ─────────────────────
        let itemIndex = UInt64(exactly: nextIndexBefore) ?? 0
        let itemAddress = try await nftAddress(
            client: client,
            collection: collectionAddress.rawString,
            index: itemIndex
        )
        print("MINT 4  item \(itemIndex) address: \(itemAddress.rawString)")

        // The gate that the first attempt was missing. Refuse before spending, not after.
        guard itemAddress.workchain == walletAddress.workchain else {
            throw Refused(reason: """
                item would land in workchain \(itemAddress.workchain) but the wallet is in \
                \(walletAddress.workchain); this collection code is compiled for a different \
                workchain and masterchain gas would exceed the forwarded value
                """)
        }

        // ── 5. Mint ────────────────────────────────────────────────────────────────
        // Body: op=1 (deploy_new_nft), query_id, item_index, forward amount, content ref.
        // The content ref is the *init message* the collection relays to the item, so its
        // shape is the item's: owner first, then individual metadata as a ref.
        let itemInitBody = try beginCell()
            .storeAddress(walletAddress)   // the item's owner — us
            .storeRef(try beginCell().storeStringTail("\(itemIndex).json").endCell())
            .endCell()

        let mintBody = try beginCell()
            .storeUInt(1, bits: 32)                  // op: deploy_new_nft
            .storeUInt(0, bits: 64)                  // query_id
            .storeUInt(itemIndex, bits: 64)
            .storeCoins(BigUInt(20_000_000))         // 0.02 TON forwarded to the new item
            .storeRef(itemInitBody)
            .endCell()

        try await send(
            messages: [
                MessageRelaxed.makeInternal(
                    to: collectionAddress,
                    value: BigUInt(60_000_000), // covers the forward plus both hops' fees
                    bounce: true,               // a rejected mint should return the value
                    body: mintBody
                )
            ],
            wallet: wallet, keyPair: keyPair, client: client, label: "mint item \(itemIndex)"
        )

        let itemLive = try await waitUntil("item \(itemIndex) to become active") {
            try await client.getAccountState(address: itemAddress.rawString).isDeployed
        }
        guard itemLive else { throw Refused(reason: "item never deployed") }

        // ── 6. The item must say we own it ─────────────────────────────────────────
        var itemReader = try await client.runGetMethod(
            address: itemAddress.rawString,
            method: "get_nft_data",
            stack: []
        ).reader()
        let initialized = try itemReader.readBigInt()
        let reportedIndex = try itemReader.readBigInt()
        var collectionSlice = try itemReader.readCell().beginParse()
        var ownerSlice = try itemReader.readCell().beginParse()

        // TVM's `true` is **-1**, not 1. Converting it to `BigUInt` traps, so the flag is
        // compared against zero instead — and the comparison below stays in `BigInt` for the
        // same reason.
        XCTAssertNotEqual(initialized, 0, "item reports itself uninitialised")
        XCTAssertEqual(reportedIndex, BigInt(itemIndex))
        XCTAssertEqual(
            try collectionSlice.loadAddress().rawString, collectionAddress.rawString,
            "item points at a different collection"
        )
        let owner = try ownerSlice.loadAddress()
        XCTAssertEqual(
            owner.rawString, walletAddress.rawString,
            "the minted item is not owned by our wallet"
        )
        print("MINT 6  ✓ item \(itemIndex) owned by \(owner.rawString)")

        // ── 7. And the indexer must agree, which is what the kit reads ─────────────
        let indexed = try await waitUntil("indexer to report the item under our wallet") {
            let page = try await client.getNFTs(owner: walletAddress.rawString, limit: 50, offset: 0)
            return page.nfts.contains {
                (try? Mappers.canonical(address: $0.address))
                    == (try? Mappers.canonical(address: itemAddress.rawString))
            }
        }
        if indexed {
            let page = try await client.getNFTs(owner: walletAddress.rawString, limit: 50, offset: 0)
            print("MINT 7  ✓ indexer reports \(page.nfts.count) NFT(s) for our wallet")
            for nft in page.nfts {
                print("MINT 7    \(nft.address) index=\(String(describing: nft.index))")
            }
        } else {
            // Not a failure of the mint: the chain already confirmed ownership above. The
            // indexer lags, and saying so beats pretending the mint failed.
            print("MINT 7  ! indexer had not caught up; on-chain ownership is already proven")
        }

        print("""
        MINT    ── summary ──────────────────────────────────────────────
        MINT    collection : \(collectionAddress.toString(testOnly: true))
        MINT    item \(itemIndex)     : \(itemAddress.toString(testOnly: true))
        MINT    owner      : \(walletAddress.toString(testOnly: true))
        MINT    ─────────────────────────────────────────────────────────
        """)
    }

    /// Asks the collection where an item index lives.
    ///
    /// Computed by the contract rather than by us: the item's state init depends on the code
    /// the collection stores *and* on the workchain constant baked into that code, so
    /// deriving it independently would be a second implementation that could disagree —
    /// exactly the disagreement that would go unnoticed.
    private func nftAddress(
        client: ToncenterClient,
        collection: String,
        index: UInt64
    ) async throws -> Address {
        var reader = try await client.runGetMethod(
            address: collection,
            method: "get_nft_address_by_index",
            stack: [.num(String(index))]
        ).reader()
        var slice = try reader.readCell().beginParse()
        return try slice.loadAddress()
    }

    /// Signs and broadcasts a wallet transfer, emulating first.
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

        // Emulating first means a mistake costs nothing — provided the gate actually stops
        // the send, which is why this throws rather than asserting.
        let emulation = try await client.emulate(boc: boc, ignoreSignature: true)
        print("MINT    [\(label)] emulated \(emulation.transactions.count) tx, succeeded=\(emulation.allSucceeded)")
        guard emulation.allSucceeded else {
            for tx in emulation.transactions where tx.isFailed {
                print("MINT    [\(label)] failing tx on \(tx.account) exitCode=\(String(describing: tx.exitCode))")
            }
            throw Refused(reason: "\(label): emulation failed, refusing to broadcast")
        }

        let sent = try await client.sendBoc(boc)
        print("MINT    [\(label)] broadcast, seqno \(seqno) → hash \(sent.messageHash)")
    }
}
