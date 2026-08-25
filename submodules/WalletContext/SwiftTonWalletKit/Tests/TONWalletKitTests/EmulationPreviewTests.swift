import Foundation
import XCTest
import TONCore
import TONToncenter
@testable import TONWalletKit

final class EmulationPreviewTests: XCTestCase {
    func testSkipsExternalWalletRootAndKeepsStateInitCommentAsOutgoingTransfer() {
        let walletAddress = address(0x22)
        let recipientAddress = address(0x11)
        let transfer = message(
            source: walletAddress,
            destination: recipientAddress,
            value: "5000000",
            opcode: "0x0",
            comment: "Hello!",
            hasStateInit: true
        )
        let walletRoot = transaction(
            hash: "wallet-root",
            account: walletAddress,
            inMessage: message(
                source: nil,
                destination: walletAddress,
                value: nil,
                opcode: "0x7369676e"
            ),
            outMessages: [transfer]
        )
        let recipient = transaction(
            hash: "recipient",
            account: recipientAddress,
            inMessage: transfer
        )

        let preview = EmulationPreview(
            emulation: EmulationResult(
                mcBlockSeqno: 1,
                transactions: [walletRoot, recipient],
                trace: nil,
                isIncomplete: false
            ),
            walletAddress: address(0x22, bounceable: false)
        )

        XCTAssertEqual(transfer.kind, .tonTransfer)
        XCTAssertEqual(preview.operations.count, 1)
        XCTAssertEqual(preview.operations[0].kind, .transfer)
        XCTAssertEqual(preview.operations[0].direction, .outgoing)
        XCTAssertEqual(preview.operations[0].address, recipientAddress)
        XCTAssertEqual(preview.operations[0].amount, BigUInt(5_000_000))
        XCTAssertEqual(preview.operations[0].comment, "Hello!")
    }

    func testBuildsEveryPreviewOperationInCausalOrderRelativeToWallet() {
        let walletAddress = address(0x22)
        let call = transaction(
            hash: "call",
            account: address(0x33),
            inMessage: message(
                source: walletAddress,
                destination: address(0x33),
                value: "60000000",
                opcode: "0xdeadbeef"
            )
        )
        let indirectCall = transaction(
            hash: "indirect-call",
            account: address(0x44),
            inMessage: message(
                source: address(0x33),
                destination: address(0x44),
                value: "10000000",
                opcode: "0xdeadbeef"
            )
        )
        let deploy = transaction(
            hash: "deploy",
            account: address(0x55),
            inMessage: message(
                source: address(0x44),
                destination: address(0x55),
                value: "1000000",
                opcode: nil,
                hasStateInit: true
            )
        )
        let incomingTransfer = transaction(
            hash: "incoming-transfer",
            account: walletAddress,
            inMessage: message(
                source: address(0x66),
                destination: walletAddress,
                value: "59000000",
                opcode: "0x0",
                comment: "Test payment."
            )
        )
        let excess = transaction(
            hash: "excess",
            account: walletAddress,
            inMessage: message(
                source: address(0x33),
                destination: walletAddress,
                value: "59000000",
                opcode: "0xd53276db"
            )
        )
        let unknown = transaction(
            hash: "unknown",
            account: address(0x44),
            inMessage: nil
        )

        let preview = EmulationPreview(
            emulation: EmulationResult(
                mcBlockSeqno: 1,
                transactions: [call, indirectCall, deploy, incomingTransfer, excess, unknown],
                trace: nil,
                isIncomplete: false
            ),
            walletAddress: address(0x22, bounceable: false)
        )

        XCTAssertEqual(preview.operations.map(\.kind), [
            .callContract,
            .callContract,
            .deployContract,
            .transfer,
            .excess,
            .unknown,
        ])
        XCTAssertEqual(preview.operations[0].direction, .outgoing)
        XCTAssertEqual(preview.operations[0].amount, BigUInt(60_000_000))
        XCTAssertNil(preview.operations[1].direction)
        XCTAssertEqual(preview.operations[1].amount, BigUInt(10_000_000))
        XCTAssertNil(preview.operations[2].amount)
        XCTAssertEqual(deploy.inMessage?.kind, .contractDeploy)
        XCTAssertEqual(preview.operations[3].direction, .incoming)
        XCTAssertEqual(preview.operations[3].address, address(0x66))
        XCTAssertEqual(preview.operations[3].amount, BigUInt(59_000_000))
        XCTAssertEqual(preview.operations[3].comment, "Test payment.")
        XCTAssertEqual(preview.operations[4].direction, .incoming)
        XCTAssertEqual(preview.operations[4].amount, BigUInt(59_000_000))
        XCTAssertNil(preview.operations[5].direction)
        XCTAssertNil(preview.operations[5].amount)
    }

    private func transaction(
        hash: String,
        account: String,
        inMessage: ChainMessage?,
        outMessages: [ChainMessage] = []
    ) -> ChainTransaction {
        return ChainTransaction(
            account: account,
            hash: hash,
            logicalTime: hash,
            now: 1,
            kind: .ordinary,
            aborted: false,
            exitCode: 0,
            totalFees: "0",
            previousTransaction: nil,
            traceID: nil,
            traceExternalHash: nil,
            inMessage: inMessage,
            outMessages: outMessages
        )
    }

    private func message(
        source: String?,
        destination: String?,
        value: String?,
        opcode: String?,
        comment: String? = nil,
        hasStateInit: Bool = false
    ) -> ChainMessage {
        return ChainMessage(
            hash: UUID().uuidString,
            source: source,
            destination: destination,
            value: value,
            opcode: opcode,
            comment: comment,
            hasStateInit: hasStateInit
        )
    }

    private func address(_ byte: UInt8, bounceable: Bool = true) -> String {
        return Address(
            workchain: 0,
            hash: Data(repeating: byte, count: 32)
        ).toString(bounceable: bounceable)
    }
}
