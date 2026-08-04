import XCTest
import TONCore
import TONToncenter
@testable import TONWalletKit

final class ActivityTests: XCTestCase {
    private let wallet = Address(workchain: 0, hash: Data(repeating: 0x11, count: 32))
    private let alice = Address(workchain: 0, hash: Data(repeating: 0x22, count: 32))
    private let bob = Address(workchain: 0, hash: Data(repeating: 0x33, count: 32))
    private let jettonWallet = Address(workchain: 0, hash: Data(repeating: 0x44, count: 32))
    private let nftItem = Address(workchain: 0, hash: Data(repeating: 0x55, count: 32))

    func testExtractsTonTransfersAndAssignsFeeOnce() throws {
        let transaction = chainTransaction(
            inMessage: ChainMessage(
                hash: "in-message",
                source: alice.toString(),
                destination: wallet.toString(),
                value: "100",
                comment: "hello"
            ),
            outMessages: [ChainMessage(
                hash: "out-message",
                source: wallet.toString(),
                destination: bob.toString(),
                value: "40"
            )],
            fee: "7"
        )
        let page = TracesPage(
            traces: [trace(transactions: [transaction], isIncomplete: true)],
            addressBook: [alice.rawString: "alice.ton"]
        )

        let activities = try WalletActivityExtractor.activities(from: page, walletAddress: wallet)
        XCTAssertEqual(activities.count, 2)

        XCTAssertEqual(activities[0].direction, .incoming)
        XCTAssertEqual(activities[0].asset, .ton)
        XCTAssertEqual(activities[0].amount, 100)
        XCTAssertEqual(activities[0].fee, 7)
        XCTAssertEqual(activities[0].counterparty, alice)
        XCTAssertEqual(activities[0].counterpartyName, "alice.ton")
        XCTAssertEqual(activities[0].comment, "hello")
        XCTAssertEqual(activities[0].status, .pending)

        XCTAssertEqual(activities[1].direction, .outgoing)
        XCTAssertEqual(activities[1].amount, 40)
        XCTAssertEqual(activities[1].fee, 0)
        XCTAssertEqual(activities[1].counterparty, bob)
    }

    func testExtractsJettonInsteadOfServiceTon() throws {
        let payload = try TransferPayloads.jettonTransfer(
            amount: 123,
            destination: bob,
            responseDestination: wallet,
            comment: "jetton"
        )
        let transaction = chainTransaction(
            outMessages: [ChainMessage(
                hash: "jetton-message",
                source: wallet.toString(),
                destination: jettonWallet.toString(),
                value: "50000000",
                bodyBoc: payload.toBoc().base64EncodedString()
            )],
            fee: "9"
        )

        let activities = try WalletActivityExtractor.activities(
            from: [transaction],
            traceID: "trace",
            walletAddress: wallet,
            status: .completed
        )
        XCTAssertEqual(activities.count, 1)
        XCTAssertEqual(activities[0].asset, .jetton(wallet: jettonWallet))
        XCTAssertEqual(activities[0].direction, .outgoing)
        XCTAssertEqual(activities[0].amount, 123)
        XCTAssertEqual(activities[0].fee, 9)
        XCTAssertEqual(activities[0].counterparty, bob)
        XCTAssertEqual(activities[0].comment, "jetton")
    }

    func testExtractsNFTTransfer() throws {
        let payload = try TransferPayloads.nftTransfer(
            newOwner: bob,
            responseDestination: wallet,
            comment: "collectible"
        )
        let transaction = chainTransaction(
            outMessages: [ChainMessage(
                hash: "nft-message",
                source: wallet.toString(),
                destination: nftItem.toString(),
                value: "100000000",
                bodyBoc: payload.toBoc().base64EncodedString()
            )],
            fee: "11"
        )

        let activities = try WalletActivityExtractor.activities(
            from: [transaction],
            traceID: "trace",
            walletAddress: wallet,
            status: .completed
        )
        XCTAssertEqual(activities.count, 1)
        XCTAssertEqual(activities[0].asset, .nft(item: nftItem))
        XCTAssertEqual(activities[0].direction, .outgoing)
        XCTAssertEqual(activities[0].amount, 0)
        XCTAssertEqual(activities[0].counterparty, bob)
        XCTAssertEqual(activities[0].comment, "collectible")
    }

    func testRejectsMalformedFee() throws {
        let transaction = chainTransaction(fee: "not-a-number")
        XCTAssertThrowsError(
            try WalletActivityExtractor.activities(
                from: [transaction],
                traceID: "trace",
                walletAddress: wallet,
                status: .completed
            )
        ) { error in
            XCTAssertEqual(error as? WalletActivityError, .invalidFee("not-a-number"))
        }
    }

    private func chainTransaction(
        inMessage: ChainMessage? = nil,
        outMessages: [ChainMessage] = [],
        fee: String
    ) -> ChainTransaction {
        ChainTransaction(
            account: wallet.toString(),
            hash: "transaction-hash",
            logicalTime: "123456789",
            now: 1_700_000_000,
            kind: .ordinary,
            aborted: false,
            exitCode: 0,
            totalFees: fee,
            previousTransaction: nil,
            traceID: "trace",
            traceExternalHash: nil,
            inMessage: inMessage,
            outMessages: outMessages
        )
    }

    private func trace(
        transactions: [ChainTransaction],
        isIncomplete: Bool = false
    ) -> Trace {
        Trace(
            traceID: "trace",
            externalHash: "external",
            startLogicalTime: transactions.first?.logicalTime,
            endLogicalTime: transactions.last?.logicalTime,
            startTime: transactions.first?.now,
            endTime: transactions.last?.now,
            isIncomplete: isIncomplete,
            info: nil,
            root: nil,
            transactions: transactions
        )
    }
}
