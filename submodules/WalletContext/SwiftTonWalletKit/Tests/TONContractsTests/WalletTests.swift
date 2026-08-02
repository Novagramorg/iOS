import XCTest
import TONTestVectors
import TONCore
import TONCrypto
@testable import TONContracts

/// Verifies wallet state init and address derivation against golden vectors.
///
/// The address is the hash of the state init, so any deviation in the storage layout or
/// code cell derives a *different wallet* — funds sent to it would be unreachable. This
/// is the highest-consequence layer in the port.
final class WalletStateInitTests: XCTestCase {
    struct StateInitVector: Decodable {
        let version: String
        let seedIndex: Int
        let publicKey: String
        let workchain: Int
        let walletId: UInt32
        let dataBoc: String
        let dataHash: String
        let codeHash: String
        let address: String
        let addressBounceable: String
    }

    private func vectors() throws -> [StateInitVector] {
        let loaded: [StateInitVector] = try Vectors.load("stateinit.json")
        XCTAssertGreaterThanOrEqual(loaded.count, 45, "stateinit.json lost cases")
        return loaded
    }

    /// Guards the embedded code constants: a corrupted byte would derive wrong addresses
    /// everywhere while still looking like a valid cell.
    func testCodeHashesMatchPublishedValues() throws {
        XCTAssertEqual(try WalletCode.v5r1.hash().hexString, WalletCode.v5r1CodeHash)
        XCTAssertEqual(try WalletCode.v4r2.hash().hexString, WalletCode.v4r2CodeHash)
        XCTAssertEqual(
            WalletCode.v5r1CodeHash,
            "20834b7b72b112147e1b2fb457b84e74d1a30f04f737d4f62a668e9552d2b72f"
        )
        XCTAssertEqual(
            WalletCode.v4r2CodeHash,
            "feb5ff6820e2ff0d9483e7e0d62c817d846789fb4ae580c878866d959dabd5c0"
        )
    }

    func testV5R1StateInitAndAddressMatchReference() throws {
        var checked = 0
        for v in try vectors() where v.version == "v5r1" {
            let publicKey = try XCTUnwrap(Data(hexString: v.publicKey))
            let wallet = WalletV5R1(
                config: .init(publicKey: publicKey, walletID: v.walletId),
                workchain: Int8(v.workchain)
            )

            XCTAssertEqual(
                try wallet.dataCell().toBoc().base64EncodedString(),
                v.dataBoc,
                "v5r1 data cell for seed \(v.seedIndex) wc \(v.workchain) id \(v.walletId)"
            )
            XCTAssertEqual(try wallet.dataCell().hash().hexString, v.dataHash)
            XCTAssertEqual(try wallet.stateInit().code?.hash().hexString, v.codeHash)
            XCTAssertEqual(
                try wallet.address().rawString,
                v.address,
                "v5r1 address for seed \(v.seedIndex) wc \(v.workchain) id \(v.walletId)"
            )
            XCTAssertEqual(try wallet.address().toString(), v.addressBounceable)
            checked += 1
        }
        XCTAssertGreaterThanOrEqual(checked, 25, "too few v5r1 cases exercised")
    }

    func testV4R2StateInitAndAddressMatchReference() throws {
        var checked = 0
        for v in try vectors() where v.version == "v4r2" {
            let publicKey = try XCTUnwrap(Data(hexString: v.publicKey))
            let wallet = WalletV4R2(
                config: .init(publicKey: publicKey, walletID: v.walletId),
                workchain: Int8(v.workchain)
            )

            XCTAssertEqual(
                try wallet.dataCell().toBoc().base64EncodedString(),
                v.dataBoc,
                "v4r2 data cell for seed \(v.seedIndex) wc \(v.workchain)"
            )
            XCTAssertEqual(try wallet.dataCell().hash().hexString, v.dataHash)
            XCTAssertEqual(try wallet.address().rawString, v.address)
            XCTAssertEqual(try wallet.address().toString(), v.addressBounceable)
            checked += 1
        }
        XCTAssertGreaterThanOrEqual(checked, 20, "too few v4r2 cases exercised")
    }

    /// Masterchain and basechain must derive different addresses from identical state.
    func testWorkchainAffectsAddressNotStateInit() throws {
        let publicKey = Data(repeating: 7, count: 32)
        let base = WalletV5R1(publicKey: publicKey, workchain: 0)
        let master = WalletV5R1(publicKey: publicKey, workchain: -1)

        XCTAssertEqual(try base.dataCell().hash(), try master.dataCell().hash())
        XCTAssertEqual(try base.address().hash, try master.address().hash)
        XCTAssertNotEqual(try base.address(), try master.address())
        XCTAssertEqual(try master.address().workchain, -1)
    }

    /// A different walletId is a different wallet, which is the whole point of the field.
    func testWalletIDAffectsAddress() throws {
        let publicKey = Data(repeating: 7, count: 32)
        let a = WalletV5R1(publicKey: publicKey, walletID: WalletV5R1.defaultWalletID)
        let b = WalletV5R1(publicKey: publicKey, walletID: 0)
        XCTAssertNotEqual(try a.address(), try b.address())
    }

    /// The two versions must never collide for the same key.
    func testV4R2AndV5R1DeriveDifferentAddresses() throws {
        let publicKey = Data(repeating: 7, count: 32)
        XCTAssertNotEqual(
            try WalletV5R1(publicKey: publicKey).address(),
            try WalletV4R2(publicKey: publicKey).address()
        )
    }

    // MARK: - Extensions dictionary

    struct ExtensionVector: Decodable {
        let label: String
        let signatureAllowed: Bool
        let seqno: UInt32
        let entries: [Entry]
        let dataBoc: String
        let dataHash: String

        struct Entry: Decodable {
            let key: String
            let value: String
        }
    }

    func testExtensionsDictionaryMatchesReference() throws {
        let vectors: [ExtensionVector] = try Vectors.load("stateinit-extensions.json")
        XCTAssertGreaterThanOrEqual(vectors.count, 5, "stateinit-extensions.json lost cases")

        // Vectors were generated from seed 0.
        let publicKey = try Ed25519.keyPair(fromSeed: Data(repeating: 0, count: 32)).publicKey

        for v in vectors {
            var extensions: [BigUInt: BigInt] = [:]
            for entry in v.entries {
                extensions[BigUInt(entry.key)!] = BigInt(entry.value)!
            }

            let wallet = WalletV5R1(
                config: .init(
                    publicKey: publicKey,
                    walletID: WalletV5R1.defaultWalletID,
                    seqno: v.seqno,
                    signatureAllowed: v.signatureAllowed,
                    extensions: extensions
                )
            )
            XCTAssertEqual(
                try wallet.dataCell().toBoc().base64EncodedString(),
                v.dataBoc,
                "data cell for \(v.label)"
            )
            XCTAssertEqual(try wallet.dataCell().hash().hexString, v.dataHash, "data hash for \(v.label)")
        }
    }
}
