import Foundation
import _BigInt
@testable import TONWalletKit

enum MockStreamingData {
    static let address = try! TONUserFriendlyAddress(value: "EQCrq6urq6urq6urq6urq6urq6urq6urq6urq6urq6urq8Uk")

    static func balanceUpdate(
        status: TONStreamingUpdateStatus = .confirmed,
        balance: String = "1.0"
    ) -> TONBalanceUpdate {
        TONBalanceUpdate(
            status: status,
            address: address,
            rawBalance: TONTokenAmount(nanoUnits: BigInt(stringLiteral: "1000000000")),
            balance: balance
        )
    }

    static func transactionsUpdate(
        status: TONStreamingUpdateStatus = .confirmed
    ) -> TONTransactionsUpdate {
        TONTransactionsUpdate(
            status: status,
            address: address,
            transactions: [
                TONTransaction(
                    account: address,
                    hash: TONHex(string: "txhash"),
                    logicalTime: "12345",
                    now: 1000,
                    mcBlockSeqno: 1,
                    traceExternalHash: TONHex(string: "tracehash"),
                    outMessages: [],
                    isEmulated: false
                )
            ],
            traceHash: TONHex(string: "tracehash")
        )
    }

    static func jettonUpdate(
        status: TONStreamingUpdateStatus = .confirmed,
        balance: String? = "100.5"
    ) -> TONJettonUpdate {
        TONJettonUpdate(
            status: status,
            masterAddress: address,
            walletAddress: address,
            ownerAddress: address,
            rawBalance: TONTokenAmount(nanoUnits: BigInt(stringLiteral: "100500000000")),
            balance: balance
        )
    }
}
