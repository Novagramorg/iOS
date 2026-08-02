import XCTest
import TONTestVectors
import TONCore
@testable import TONContracts

/// Re-derives the addresses of **real deployed wallets** from data read off the live
/// chain.
///
/// This is the strongest check available on the contract layer, and stronger than any
/// golden vector: the vectors verify we agree with the reference TypeScript, while this
/// verifies we agree with what the TON blockchain actually holds. If the state-init
/// layout, the embedded code cell, or address derivation were wrong, these would not
/// match — no matter how well the vectors passed.
///
/// The public keys and walletIds were read via `runGetMethod` against testnet and frozen
/// into a fixture, so the test needs no network.
final class OnChainDerivationTests: XCTestCase {
    struct OnChainFixture: Decodable {
        let network: String
        let globalId: Int
        let wallets: [Wallet]

        struct Wallet: Decodable {
            let version: String
            let rawAddress: String
            let balance: String
            /// `0x`-prefixed hex, 256-bit.
            let publicKey: String
            /// `0x`-prefixed hex.
            let walletId: String
            let seqno: String
        }
    }

    private func fixture() throws -> OnChainFixture {
        let data = try Vectors.rawFixture("onchain/testnet-wallets")
        let decoded = try JSONDecoder().decode(OnChainFixture.self, from: data)
        XCTAssertGreaterThanOrEqual(decoded.wallets.count, 5, "on-chain fixture lost wallets")
        return decoded
    }

    /// Public keys arrive from the chain as `0x`-hex and may be shorter than 32 bytes
    /// when the leading bytes are zero, because the get-method returns an integer.
    private func publicKey(from hex: String) throws -> Data {
        let stripped = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        let padded = String(repeating: "0", count: max(0, 64 - stripped.count)) + stripped
        return try XCTUnwrap(Data(hexString: padded), "could not parse public key \(hex)")
    }

    private func walletID(from hex: String) throws -> UInt32 {
        let stripped = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        return try XCTUnwrap(UInt32(stripped, radix: 16), "could not parse walletId \(hex)")
    }

    // MARK: - The proof

    func testV5R1AddressesMatchTheLiveChain() throws {
        var checked = 0
        for wallet in try fixture().wallets where wallet.version == "v5r1" {
            let wallet5 = WalletV5R1(
                publicKey: try publicKey(from: wallet.publicKey),
                walletID: try walletID(from: wallet.walletId),
                workchain: 0
            )
            let derived = try wallet5.address()

            XCTAssertEqual(
                derived.rawString.uppercased(),
                wallet.rawAddress.uppercased(),
                """
                Derived address does not match the deployed contract.
                  public key: \(wallet.publicKey)
                  walletId:   \(wallet.walletId)
                  on chain:   \(wallet.rawAddress)
                  derived:    \(derived.rawString)
                """
            )
            checked += 1
        }
        XCTAssertGreaterThanOrEqual(checked, 4, "too few V5R1 wallets verified")
    }

    func testV4R2AddressesMatchTheLiveChain() throws {
        var checked = 0
        for wallet in try fixture().wallets where wallet.version == "v4r2" {
            let wallet4 = WalletV4R2(
                publicKey: try publicKey(from: wallet.publicKey),
                walletID: try walletID(from: wallet.walletId),
                workchain: 0
            )
            let derived = try wallet4.address()

            XCTAssertEqual(
                derived.rawString.uppercased(),
                wallet.rawAddress.uppercased(),
                """
                Derived V4R2 address does not match the deployed contract.
                  public key: \(wallet.publicKey)
                  walletId:   \(wallet.walletId)
                  on chain:   \(wallet.rawAddress)
                  derived:    \(derived.rawString)
                """
            )
            checked += 1
        }
        XCTAssertGreaterThanOrEqual(checked, 1, "no V4R2 wallet verified")
    }

    /// Deriving with the wrong walletId must produce a different address — otherwise the
    /// test above would pass for the wrong reason.
    func testWrongWalletIDDerivesADifferentAddress() throws {
        let wallet = try XCTUnwrap(try fixture().wallets.first { $0.version == "v5r1" })
        let key = try publicKey(from: wallet.publicKey)
        let correct = try walletID(from: wallet.walletId)

        let right = try WalletV5R1(publicKey: key, walletID: correct).address()
        let wrong = try WalletV5R1(publicKey: key, walletID: correct ^ 1).address()
        XCTAssertNotEqual(right, wrong)
        XCTAssertEqual(right.rawString.uppercased(), wallet.rawAddress.uppercased())
    }

    // MARK: - The walletId finding

    /// Every V5R1 wallet observed on testnet uses `2^31 - 3`, and the mainnet default is
    /// `2^31 - 239` — the two networks' `global_id` values.
    ///
    /// So the V5R1 walletId **embeds the network**, and walletkit's hardcoded
    /// `defaultWalletIdV5R1 = 2147483409` is a mainnet-only constant. Using it on testnet
    /// yields a working wallet at a *different* address than every other client derives
    /// for the same key.
    func testObservedWalletIDsEncodeTheNetworkGlobalID() throws {
        let f = try fixture()
        let v5 = f.wallets.filter { $0.version == "v5r1" }
        XCTAssertFalse(v5.isEmpty)

        for wallet in v5 {
            let id = try walletID(from: wallet.walletId)
            XCTAssertEqual(
                Int(id),
                Int(1 << 31) + f.globalId,
                "testnet V5R1 walletId should be 2^31 + globalId (\(f.globalId))"
            )
        }
    }

    /// The computed walletId must reproduce both the observed testnet value and the
    /// documented mainnet default.
    func testWalletIDComputationMatchesBothNetworks() throws {
        XCTAssertEqual(
            WalletV5R1.walletID(globalId: -3),
            2_147_483_645,
            "testnet, as observed on-chain"
        )
        XCTAssertEqual(
            WalletV5R1.walletID(globalId: -239),
            WalletV5R1.defaultWalletID,
            "mainnet, matching the reference's hardcoded default"
        )
        XCTAssertEqual(WalletV5R1.defaultWalletID, 2_147_483_409)
    }

    /// A wallet built for mainnet and one built for testnet must not collide.
    func testNetworkAwareConstructionDivergesByNetwork() throws {
        let key = Data(repeating: 0x42, count: 32)
        let mainnet = try WalletV5R1(publicKey: key, globalId: -239).address()
        let testnet = try WalletV5R1(publicKey: key, globalId: -3).address()
        XCTAssertNotEqual(
            mainnet,
            testnet,
            "the same key must yield different wallets on different networks"
        )
    }

    /// V4R2's walletId is a plain constant with no network component — which is why the
    /// same key gives the same V4R2 address on both networks.
    func testV4R2WalletIDIsNetworkIndependent() throws {
        let wallet = try XCTUnwrap(try fixture().wallets.first { $0.version == "v4r2" })
        XCTAssertEqual(
            try walletID(from: wallet.walletId),
            WalletV4R2.defaultWalletID,
            "the observed V4R2 walletId is the documented default"
        )
    }

    /// Sanity: the fixture holds funded, deployed wallets, so a zero balance would mean
    /// the data went stale in a way that weakens the check.
    func testFixtureWalletsAreFunded() throws {
        for wallet in try fixture().wallets {
            XCTAssertNotEqual(wallet.balance, "0", "\(wallet.rawAddress) is unfunded")
        }
    }
}
