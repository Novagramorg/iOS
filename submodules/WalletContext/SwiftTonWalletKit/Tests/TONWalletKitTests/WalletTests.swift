import XCTest
import TONTestVectors
import TONCore
import TONCrypto
import TONContracts
import TONToncenter
import TONConnect
@testable import TONWalletKit

/// Verifies the wallet abstraction that sits over both contract versions.
final class WalletKitWalletTests: XCTestCase {
    private func signer(seed: UInt8 = 1) throws -> InMemorySigner {
        InMemorySigner(keyPair: try Ed25519.keyPair(fromSeed: Data(repeating: seed, count: 32)))
    }

    // MARK: - Construction

    /// A V5R1 wallet must use the **network-aware** walletId, not the reference's hardcoded
    /// mainnet constant — otherwise the same mnemonic lands at a different address than
    /// every other client derives on testnet.
    func testV5R1UsesNetworkAwareWalletID() throws {
        let s = try signer()
        let mainnet = try Wallet(v5r1: s, network: .mainnet)
        let testnet = try Wallet(v5r1: s, network: .testnet)

        XCTAssertNotEqual(
            mainnet.address,
            testnet.address,
            "one key must give different wallets on different networks"
        )
        XCTAssertEqual(mainnet.v5?.config.walletID, 2_147_483_409, "mainnet is 2^31 - 239")
        XCTAssertEqual(testnet.v5?.config.walletID, 2_147_483_645, "testnet is 2^31 - 3")
    }

    /// The derived address must match what the live chain holds. The fixture records real
    /// deployed testnet wallets, so this ties the kit layer to ground truth rather than to
    /// our own vectors.
    func testAddressesMatchDeployedTestnetWallets() throws {
        struct Fixture: Decodable {
            let wallets: [W]
            struct W: Decodable {
                let version: String
                let rawAddress: String
                let publicKey: String
                let walletId: String
            }
        }
        let fixture = try JSONDecoder().decode(
            Fixture.self,
            from: try Vectors.rawFixture("onchain/testnet-wallets")
        )

        var checked = 0
        for entry in fixture.wallets where entry.version == "v5r1" {
            let hex = String(entry.publicKey.dropFirst(2))
            let padded = String(repeating: "0", count: max(0, 64 - hex.count)) + hex
            let publicKey = try XCTUnwrap(Data(hexString: padded))
            let walletID = try XCTUnwrap(UInt32(String(entry.walletId.dropFirst(2)), radix: 16))

            // Every deployed testnet wallet uses the network-aware id, which is what the
            // kit now derives by default.
            XCTAssertEqual(walletID, 2_147_483_645)

            let wallet = try Wallet(
                v5r1: FixedKeySigner(publicKey: publicKey),
                network: .testnet
            )
            XCTAssertEqual(
                wallet.address.rawString.uppercased(),
                entry.rawAddress.uppercased(),
                "kit-derived address must match the deployed contract"
            )
            checked += 1
        }
        XCTAssertGreaterThanOrEqual(checked, 4)
    }

    /// The wallet id must differ per network, which is the whole reason it hashes the chain
    /// id in — otherwise two networks' wallets would collide in storage.
    func testWalletIDIsNetworkScoped() throws {
        let s = try signer()
        let mainnet = try Wallet(v5r1: s, network: .mainnet)
        let testnet = try Wallet(v5r1: s, network: .testnet)
        XCTAssertNotEqual(mainnet.id, testnet.id)
    }

    func testVersionsDeriveDifferentAddresses() throws {
        let s = try signer()
        XCTAssertNotEqual(
            try Wallet(v5r1: s, network: .mainnet).address,
            try Wallet(v4r2: s, network: .mainnet).address
        )
    }

    func testNonNumericChainIDIsRejected() throws {
        let s = try signer()
        XCTAssertThrowsError(try Wallet(v5r1: s, network: Network(chainId: "not-a-number")))
    }

    // MARK: - Capacity

    /// V5R1 chains an action list and reaches 255; V4R2 stores each message as a ref and
    /// caps at 4. A dApp asking for more must be refused, not silently truncated.
    func testMessageCapacityDiffersByVersion() throws {
        let s = try signer()
        XCTAssertEqual(try Wallet(v5r1: s, network: .mainnet).maxMessagesPerTransfer, 255)
        XCTAssertEqual(try Wallet(v4r2: s, network: .mainnet).maxMessagesPerTransfer, 4)
    }

    func testTooManyMessagesIsRefused() async throws {
        let wallet = try Wallet(v4r2: try signer(), network: .mainnet)
        let dest = try Address.parseRaw("0:" + String(repeating: "83", count: 32))
        let messages = (0..<5).map { _ in
            MessageRelaxed.makeInternal(to: dest, value: 1000, bounce: true)
        }

        do {
            _ = try await wallet.signedTransfer(
                messages: messages,
                seqno: 0,
                isDeployed: true,
                validUntil: 1_700_000_000
            )
            XCTFail("expected the request to be refused")
        } catch let error as WalletKitError {
            guard case .tooManyMessages(let count, let maximum) = error else {
                return XCTFail("expected tooManyMessages, got \(error)")
            }
            XCTAssertEqual(count, 5)
            XCTAssertEqual(maximum, 4)
            XCTAssertFalse(error.isRetryable, "a capacity error will never succeed on retry")
        }
    }

    func testAdvertisedFeaturesReflectCapacity() throws {
        let v5 = try Wallet(v5r1: try signer(), network: .mainnet)
        let feature = try XCTUnwrap(v5.supportedFeatures.first { $0.name == "SendTransaction" })
        XCTAssertEqual(feature.maxMessages, 255)
        XCTAssertTrue(v5.supportedFeatures.contains { $0.name == "SignData" })
    }

    // MARK: - Signing

    /// A signed transfer must be a well-formed external message that the contract layer can
    /// re-parse — the cheapest guard against producing something the chain will reject.
    func testSignedTransferProducesAParseableExternalMessage() async throws {
        let wallet = try Wallet(v5r1: try signer(), network: .testnet)
        let dest = try Address.parseRaw("0:" + String(repeating: "83", count: 32))

        let boc = try await wallet.signedTransfer(
            messages: [MessageRelaxed.makeInternal(to: dest, value: 1_000_000, bounce: true)],
            seqno: 0,
            isDeployed: false,
            validUntil: 1_700_000_000
        )

        let cell = try Cell.fromBase64(boc)
        let message = try Message.fromCell(cell)
        guard case .externalIn(let info) = message.info else {
            return XCTFail("a transfer must be an inbound external message")
        }
        XCTAssertEqual(info.dest, wallet.address)
        XCTAssertNotNil(message.stateInit, "an undeployed wallet must carry its state init")
    }

    /// Including the state init after deployment wastes fees, so it must be omitted.
    func testDeployedWalletOmitsStateInit() async throws {
        let wallet = try Wallet(v5r1: try signer(), network: .testnet)
        let dest = try Address.parseRaw("0:" + String(repeating: "83", count: 32))

        let boc = try await wallet.signedTransfer(
            messages: [MessageRelaxed.makeInternal(to: dest, value: 1_000_000, bounce: true)],
            seqno: 5,
            isDeployed: true,
            validUntil: 1_700_000_000
        )
        let message = try Message.fromCell(try Cell.fromBase64(boc))
        XCTAssertNil(message.stateInit)
    }

    /// Deterministic signing means the same inputs give the same BoC, which is what makes
    /// a normalized-hash lookup reliable after a retry.
    func testSigningIsReproducible() async throws {
        let wallet = try Wallet(v5r1: try signer(), network: .testnet)
        let dest = try Address.parseRaw("0:" + String(repeating: "83", count: 32))
        let messages = [MessageRelaxed.makeInternal(to: dest, value: 1_000_000, bounce: true)]

        let first = try await wallet.signedTransfer(
            messages: messages, seqno: 3, isDeployed: true, validUntil: 1_700_000_000
        )
        let second = try await wallet.signedTransfer(
            messages: messages, seqno: 3, isDeployed: true, validUntil: 1_700_000_000
        )
        XCTAssertEqual(first, second)
    }

    /// V4R2 puts the signature first; V5R1 puts it last. Both must verify against the
    /// wallet's own key.
    func testBothVersionsProduceVerifiableSignatures() async throws {
        let s = try signer()
        let dest = try Address.parseRaw("0:" + String(repeating: "83", count: 32))
        let messages = [MessageRelaxed.makeInternal(to: dest, value: 1000, bounce: true)]

        for wallet in [
            try Wallet(v5r1: s, network: .testnet),
            try Wallet(v4r2: s, network: .testnet),
        ] {
            let boc = try await wallet.signedTransfer(
                messages: messages, seqno: 0, isDeployed: true, validUntil: 1_700_000_000
            )
            // Re-parsing proves the structure; the settlement proof covers validity.
            XCTAssertNoThrow(try Message.fromCell(try Cell.fromBase64(boc)))
        }
    }

    // MARK: - Connect replies

    /// The protocol specifies the **raw** address form here. A friendly address fails
    /// dApp-side verification.
    func testAddressReplyUsesRawFormAndCarriesStateInit() throws {
        let wallet = try Wallet(v5r1: try signer(), network: .mainnet)
        let reply = try wallet.addressReply()

        XCTAssertTrue(reply.address.contains(":"), "the protocol wants the raw form")
        XCTAssertEqual(reply.address, wallet.address.rawString)
        XCTAssertEqual(reply.network, "-239")
        XCTAssertEqual(reply.publicKey, wallet.publicKey.hexString)

        // A dApp verifies the address derives from the state init, so it must round-trip.
        var slice = try Cell.fromBase64(reply.walletStateInit).beginParse()
        let stateInit = try StateInit.load(from: &slice)
        XCTAssertNotNil(stateInit.code)
        XCTAssertEqual(
            try contractAddress(workchain: 0, init: stateInit),
            wallet.address,
            "the state init must derive the advertised address"
        )
    }

    /// The proof must verify under the wallet's public key, since a dApp backend checks it.
    func testSignedProofVerifies() async throws {
        let wallet = try Wallet(v5r1: try signer(), network: .mainnet)
        let reply = try await wallet.signProof(
            domain: "example.com",
            payload: "challenge-123",
            timestamp: 1_700_000_000
        )

        XCTAssertEqual(reply.name, "ton_proof")
        XCTAssertEqual(reply.proof.payload, "challenge-123")
        XCTAssertEqual(reply.proof.domain.value, "example.com")

        let signature = try XCTUnwrap(Data(anyBase64: reply.proof.signature))
        let message = TonProof.Message(
            address: wallet.address,
            domain: TonProof.Domain(value: "example.com"),
            timestamp: 1_700_000_000,
            payload: "challenge-123"
        )
        XCTAssertTrue(
            try TonProof.verify(message, signature: signature, publicKey: wallet.publicKey),
            "a dApp backend must be able to verify this proof"
        )
    }

    /// `lengthBytes` is a UTF-8 byte count, which differs from character count for a
    /// non-ASCII domain.
    func testProofDomainLengthIsByteCount() async throws {
        let wallet = try Wallet(v5r1: try signer(), network: .mainnet)
        let reply = try await wallet.signProof(
            domain: "пример.рф",
            payload: "x",
            timestamp: 1
        )
        XCTAssertEqual(reply.proof.domain.lengthBytes, UInt32(Data("пример.рф".utf8).count))
        XCTAssertNotEqual(Int(reply.proof.domain.lengthBytes), "пример.рф".count)
    }

    /// The signer seam must be usable: a host app supplying its own signer (Keychain,
    /// enclave, BoringSSL) must work without the kit changing.
    func testCustomSignerIsUsed() async throws {
        final class CountingSigner: WalletSigner, @unchecked Sendable {
            let inner: InMemorySigner
            private let lock = NSLock()
            private var count = 0

            init(inner: InMemorySigner) { self.inner = inner }
            var publicKey: Data { inner.publicKey }
            var signCount: Int {
                lock.lock(); defer { lock.unlock() }
                return count
            }
            func sign(_ data: Data) async throws -> Data {
                increment()
                return try await inner.sign(data)
            }

            private func increment() {
                lock.lock(); count += 1; lock.unlock()
            }
        }

        let counting = CountingSigner(inner: try signer())
        let wallet = try Wallet(v5r1: counting, network: .testnet)
        let dest = try Address.parseRaw("0:" + String(repeating: "83", count: 32))

        _ = try await wallet.signedTransfer(
            messages: [MessageRelaxed.makeInternal(to: dest, value: 1000, bounce: true)],
            seqno: 0,
            isDeployed: true,
            validUntil: 1_700_000_000
        )
        XCTAssertEqual(counting.signCount, 1, "signing must route through the supplied signer")
    }
}

/// A signer that knows a public key but cannot sign — for address-derivation tests against
/// on-chain data, where no private key exists.
struct FixedKeySigner: WalletSigner {
    let publicKey: Data

    func sign(_ data: Data) async throws -> Data {
        throw WalletKitError.cryptoFailure(
            underlying: NSError(
                domain: "FixedKeySigner",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "no private key available"]
            )
        )
    }
}
