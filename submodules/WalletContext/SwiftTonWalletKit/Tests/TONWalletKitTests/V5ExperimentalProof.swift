import XCTest
import TONCore
import TONCrypto
import TONContracts
import TONToncenter
import TONConnect
@testable import TONWalletKit

/// Settles the `wallet-v5-experimental` contract on testnet.
///
/// Golden vectors prove this kit agrees with the Rust reference about what bytes to
/// produce. They cannot prove the *contract* accepts those bytes — both stacks could be
/// wrong in the same way, and for a wallet fork whose distinguishing feature is a one-shot,
/// irreversible key rotation, agreeing with another implementation is not the same as being
/// right. So this deploys a real wallet, spends from it, rotates its key on chain, spends
/// again with the new key from the same address, and confirms the retired key is dead.
///
/// The run is idempotent. A rotation can only ever happen once per address, so the test
/// reads `get_public_key` first and takes the "already rotated" branch on every subsequent
/// run — still proving every post-rotation property.
///
/// The replacement key is derived from the same mnemonic (`sha256(mnemonic || "|v5x-rotation")`)
/// rather than generated, so a re-run recovers it and the wallet never becomes unsignable.
///
/// Gated behind `RUN_V5X_PROOF=1`.
final class V5ExperimentalProofTests: XCTestCase {
    struct WalletFile: Decodable {
        let mnemonic: String
        let globalId: Int32
    }

    struct Refused: Error, CustomStringConvertible {
        let reason: String
        var description: String { reason }
    }

    private var isEnabled: Bool {
        ProcessInfo.processInfo.environment["RUN_V5X_PROOF"] == "1"
    }

    private func loadWallet() throws -> WalletFile {
        let path = ProcessInfo.processInfo.environment["TESTNET_WALLET_FILE"]
            ?? "\(FileManager.default.currentDirectoryPath)/.testnet-wallet.json"
        return try JSONDecoder().decode(
            WalletFile.self, from: try Data(contentsOf: URL(fileURLWithPath: path))
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
        timeout: TimeInterval = 240,
        condition: () async throws -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        var attempt = 0
        while Date() < deadline {
            attempt += 1
            if try await condition() {
                print("V5X  ✓ \(description) (after \(attempt) poll\(attempt == 1 ? "" : "s"))")
                return
            }
            try? await Task.sleep(nanoseconds: 5_000_000_000)
        }
        // Throwing, not asserting: everything downstream depends on this having happened,
        // and a soft failure would broadcast the next step against stale state.
        throw Refused(reason: "timed out waiting for \(description)")
    }

    private func publicKey(of address: Address, client: ToncenterClient) async throws -> Data {
        let result = try await client.runGetMethod(
            address: address.toString(), method: "get_public_key", stack: []
        )
        var reader = try result.reader()
        let value = try reader.readBigInt()
        guard value >= 0 else { throw Refused(reason: "get_public_key returned \(value)") }
        let bytes = BigUInt(value).serialize()
        guard bytes.count <= 32 else { throw Refused(reason: "public key is \(bytes.count) bytes") }
        // Left-pad: a key with leading zero bytes comes back short.
        return Data(repeating: 0, count: 32 - bytes.count) + bytes
    }

    private func seqno(of address: Address, client: ToncenterClient) async throws -> UInt32 {
        let result = try await client.runGetMethod(
            address: address.toString(), method: "seqno", stack: []
        )
        var reader = try result.reader()
        return UInt32(try reader.readBigInt())
    }

    func testDeploySpendRotateAndSpendAgain() async throws {
        try XCTSkipUnless(isEnabled, "set RUN_V5X_PROOF=1 to run the v5-experimental proof")

        let file = try loadWallet()
        let words = file.mnemonic.split(separator: " ").map(String.init)
        let client = makeClient()

        let ownerKeys = try Mnemonic.keyPair(from: words)
        let owner = InMemorySigner(keyPair: ownerKeys)
        let newKeys = try Ed25519.keyPair(
            fromSeed: Hashing.sha256(Data((file.mnemonic + "|v5x-rotation").utf8))
        )

        let funder = try Wallet(v5r1: owner, network: .testnet)
        let v5x = try Wallet(v5Experimental: owner, network: .testnet)

        print("V5X  funder  \(funder.address.toString())")
        print("V5X  wallet  \(v5x.address.toString())  (\(v5x.address.rawString))")
        print("V5X  code    \(WalletCode.v5ExperimentalCodeHash)")
        print("V5X  old key \(ownerKeys.publicKey.hexString)")
        print("V5X  new key \(newKeys.publicKey.hexString)")

        // The point of the fork: the same key, on the same network, is a different account
        // than V5R1. If these ever collided the funding step would be a no-op.
        XCTAssertNotEqual(v5x.address, funder.address)

        let kit = TonWalletKit(
            configuration: WalletKitConfiguration(
                deviceInfo: DeviceInfo(
                    platform: "iphone", appName: "V5XProof", appVersion: "1.0",
                    maxProtocolVersion: 2, features: []
                ),
                emulateBeforeApproval: false
            ),
            storage: InMemoryStorage(),
            clients: [.testnet: client],
            manifests: StubManifestFetcher.serving(domain: "example.com")
        )
        await kit.register(wallet: funder)

        // MARK: 1 — fund

        let funding = BigUInt(200_000_000) // 0.2 TON
        if try await client.getAccountState(address: v5x.address.toString()).nanoton < funding / 2 {
            guard try await client.getAccountState(address: funder.address.toString()).nanoton
                > funding + 50_000_000 else {
                throw Refused(reason: "funder is too low to run the proof")
            }
            // Non-bounceable: the wallet is not deployed yet, and a bounceable message to
            // an uninitialised account comes straight back.
            _ = try await kit.sendTON(
                from: funder.id,
                to: v5x.address.toString(bounceable: false, testOnly: true),
                amount: funding,
                comment: "v5x proof funding"
            )
            try await waitUntil("funding to arrive") {
                try await client.getAccountState(address: v5x.address.toString()).nanoton > 0
            }
        } else {
            print("V5X  – already funded, skipping")
        }

        // MARK: 2 — deploy by spending, with the original key

        if !(try await client.getAccountState(address: v5x.address.toString()).isDeployed) {
            await kit.register(wallet: v5x)
            let sent = try await kit.sendTON(
                from: v5x.id,
                to: funder.address.toString(),
                amount: BigUInt(20_000_000),
                comment: "v5x deploy + first spend"
            )
            print("V5X  deploy normalized \(sent.normalizedHash)")
            try await waitUntil("the wallet to become active") {
                try await client.getAccountState(address: v5x.address.toString()).isDeployed
            }
        } else {
            print("V5X  – already deployed, skipping")
        }

        let state = try await client.getAccountState(address: v5x.address.toString())
        XCTAssertTrue(state.isDeployed)

        // The deployed code must be the experimental contract, not V5R1 — the check that
        // would catch the whole port pointing at the wrong code cell.
        let deployedCode = try Cell.fromBase64(
            try XCTUnwrap(state.code, "deployed account has no code")
        )
        XCTAssertEqual(deployedCode.hash().hexString, WalletCode.v5ExperimentalCodeHash)

        // MARK: 3 — rotate the key on chain

        let onChainKey = try await publicKey(of: v5x.address, client: client)
        XCTAssertTrue(
            onChainKey == ownerKeys.publicKey || onChainKey == newKeys.publicKey,
            "the wallet holds a key that is neither the original nor the derived replacement"
        )

        if onChainKey == ownerKeys.publicKey {
            print("V5X  rotating \(ownerKeys.publicKey.hexString) -> \(newKeys.publicKey.hexString)")

            let rotation = try KeyRotation.make(
                address: v5x.address,
                newPublicKey: newKeys.publicKey,
                newSecretKey: newKeys.secretKey
            )
            guard try rotation.isProofValid(for: v5x.address) else {
                throw Refused(reason: "refusing to broadcast an unverifiable rotation")
            }

            let seqnoBefore = try await seqno(of: v5x.address, client: client)
            let boc = try await v5x.signedKeyRotation(
                rotation,
                seqno: seqnoBefore,
                isDeployed: true,
                validUntil: UInt32(Date().timeIntervalSince1970) + 300
            )

            // Emulate before broadcasting. The rotation is irreversible, so a dry run is
            // the last point at which a mistake is still free.
            for tx in (try await client.emulate(boc: boc, ignoreSignature: false)).transactions
            where tx.isFailed {
                throw Refused(
                    reason: "rotation emulation failed: exit \(String(describing: tx.exitCode))"
                )
            }
            print("V5X  rotation emulated clean, broadcasting")

            _ = try await client.sendBoc(boc)
            try await waitUntil("the on-chain public key to change") {
                try await self.publicKey(of: v5x.address, client: client) == newKeys.publicKey
            }

            // Rotation must not reset the counter — a reset seqno would make previously
            // signed-but-unsent messages replayable.
            let seqnoAfter = try await seqno(of: v5x.address, client: client)
            XCTAssertEqual(seqnoAfter, seqnoBefore + 1, "seqno must advance by exactly one")
        } else {
            print("V5X  – already rotated, skipping")
        }

        let settled = try await publicKey(of: v5x.address, client: client)
        XCTAssertEqual(settled.hexString, newKeys.publicKey.hexString)

        // MARK: 4 — spend with the new key, from the same address

        // Re-deriving from the new key names a *different*, non-existent account. That is
        // the trap `Wallet(v5ExperimentalRotated:)` exists to avoid.
        XCTAssertNotEqual(
            try WalletV5Experimental(
                publicKey: newKeys.publicKey, walletID: v5x.contractWalletID
            ).address(),
            v5x.address,
            "re-deriving from the new key must NOT reproduce the address"
        )

        let rotated = try Wallet(
            v5ExperimentalRotated: InMemorySigner(keyPair: newKeys),
            originalPublicKey: ownerKeys.publicKey,
            network: .testnet,
            walletID: v5x.contractWalletID
        )
        XCTAssertEqual(rotated.address, v5x.address, "a rotated wallet keeps its address")
        XCTAssertEqual(rotated.publicKey, newKeys.publicKey, "and reports its current key")
        await kit.register(wallet: rotated)

        let before = try await client.getAccountState(address: funder.address.toString()).nanoton
        let spend = try await kit.sendTON(
            from: rotated.id,
            to: funder.address.toString(),
            amount: BigUInt(10_000_000),
            comment: "v5x post-rotation spend"
        )
        print("V5X  post-rotation spend normalized \(spend.normalizedHash)")
        try await waitUntil("the post-rotation transfer to land") {
            try await client.getAccountState(address: funder.address.toString()).nanoton > before
        }
        try await waitUntil("it to be findable by normalized hash") {
            !(try await client.getTransactionsByMessageHash(spend.normalizedHash)).transactions.isEmpty
        }

        // MARK: 5 — the retired key must be dead

        let staleBody = try WalletV5Experimental(
            publicKey: ownerKeys.publicKey, walletID: v5x.contractWalletID
        ).createSignedBody(
            seqno: try await seqno(of: v5x.address, client: client),
            actions: try ActionList.pack([
                .sendMessage(
                    mode: SendMode(rawValue: 3),
                    message: MessageRelaxed.makeInternal(
                        to: funder.address, value: BigUInt(1_000_000), bounce: false
                    )
                )
            ]),
            validUntil: UInt32(Date().timeIntervalSince1970) + 300,
            auth: .external,
            secretKey: ownerKeys.secretKey
        )
        let staleBoc = try Message.makeExternalIn(
            to: v5x.address, stateInit: nil, body: staleBody
        ).toCell().toBocBase64()

        // Emulated rather than broadcast: an external the contract refuses is dropped by
        // the network, so "nothing happened" would be indistinguishable from a transport
        // failure.
        //
        // The refusal happens *before* `accept_message`, so no transaction is produced at
        // all and the emulator reports it as a transport-level error rather than as a
        // failed transaction — 135 is the contract's `InvalidSignature`. Both shapes count
        // as a rejection; what must never happen is a clean emulation.
        do {
            let stale = try await client.emulate(boc: staleBoc, ignoreSignature: false)
            XCTAssertTrue(
                stale.transactions.isEmpty || stale.transactions.contains { $0.isFailed },
                "the retired key must no longer authorize a transfer"
            )
        } catch {
            let text = String(describing: error)
            XCTAssertTrue(
                text.contains("NotAccepted") || text.contains("not accepted") || text.contains("135"),
                "expected the retired key to be refused, got: \(text)"
            )
            print("V5X  ✓ retired key refused before acceptance")
        }

        print("V5X  ✓ deployed, spent, rotated, spent again at \(v5x.address.toString())")
    }
}
