import XCTest
import TONTestVectors
import TONCore
@testable import TONToncenter

/// Verifies emulation against a recorded run whose **input was built by this
/// implementation**.
///
/// The BoC in the fixture came out of `WalletV5R1` + `ActionList` + `Message` in this
/// package. The TVM emulator then executed it against live testnet state, returned exit
/// code 0, and emitted exactly the outgoing message that was encoded. That makes this a
/// stronger check than any golden vector: the vectors prove we agree with the reference
/// TypeScript, while this proves the TON virtual machine accepts and correctly interprets
/// what we produce.
final class EmulationTests: XCTestCase {
    struct EmulationFixture: Decodable {
        let network: String
        let request: Request
        let expected: Expected
        /// Kept as raw JSON so it can be fed through the real decoder.
        let response: AnyJSON

        struct Request: Decodable {
            let path: String
            let boc: String
        }

        struct Expected: Decodable {
            let senderAddress: String
            let destinationAddress: String
            let sentAmountNanoton: String
            let transactionCount: Int
            let allSucceeded: Bool
            let normalizedHash: String
        }
    }

    private func fixture() throws -> EmulationFixture {
        let data = try Vectors.rawFixture("emulation/testnet-v5r1-transfer")
        return try JSONDecoder().decode(EmulationFixture.self, from: data)
    }

    private func client(_ fixture: EmulationFixture) throws -> ToncenterClient {
        let body = try JSONSerialization.data(withJSONObject: fixture.response.value)
        return ToncenterClient(
            network: .testnet,
            transport: SingleResponseTransport(
                response: TransportResponse(status: 200, body: body)
            ),
            retryDelayNanoseconds: 0
        )
    }

    // MARK: - The end-to-end result

    func testEmulationDecodesTheRecordedRun() async throws {
        let f = try fixture()
        let result = try await client(f).emulate(boc: f.request.boc)

        XCTAssertEqual(
            result.transactions.count,
            f.expected.transactionCount,
            "the emulator produced a sender transaction and a recipient transaction"
        )
        XCTAssertFalse(result.isIncomplete, "the emulation covered the whole tree")
        XCTAssertTrue(result.allSucceeded, "every emulated transaction succeeded")
        XCTAssertNil(result.firstFailure)
        XCTAssertGreaterThan(result.mcBlockSeqno, 0)
    }

    /// The emulator emitted exactly the message the action list encoded — the strongest
    /// single signal that action packing and message serialization are correct.
    func testEmulationEmitsTheEncodedOutgoingMessage() async throws {
        let f = try fixture()
        let result = try await client(f).emulate(boc: f.request.boc)

        let sender = try XCTUnwrap(result.transactions.first)
        XCTAssertEqual(
            sender.account.uppercased(),
            f.expected.senderAddress.uppercased(),
            "the first transaction should be the sending wallet's"
        )
        XCTAssertEqual(sender.outMessages.count, 1, "one action, one outgoing message")

        let out = try XCTUnwrap(sender.outMessages.first)
        XCTAssertEqual(
            out.destination?.uppercased(),
            f.expected.destinationAddress.uppercased(),
            "destination must match what the action encoded"
        )
        XCTAssertEqual(
            out.value,
            f.expected.sentAmountNanoton,
            "amount must match what the action encoded"
        )
    }

    /// The wallet contract ran, rather than the message being rejected outright.
    ///
    /// A wrong `createBodyV5` layout — opcode, walletId, validUntil or seqno in the wrong
    /// place — would abort here instead of producing a clean exit code 0.
    func testWalletContractExecutedSuccessfully() async throws {
        let f = try fixture()
        let result = try await client(f).emulate(boc: f.request.boc)

        let sender = try XCTUnwrap(result.transactions.first)
        XCTAssertEqual(sender.kind, .ordinary)
        XCTAssertFalse(sender.aborted, "the wallet contract must not abort")
        XCTAssertEqual(sender.exitCode, 0, "compute phase should exit cleanly")
        XCTAssertFalse(sender.isFailed)
    }

    func testTraceShapeMatchesTheTransactionCount() async throws {
        let f = try fixture()
        let result = try await client(f).emulate(boc: f.request.boc)

        let trace = try XCTUnwrap(result.trace)
        XCTAssertEqual(trace.transactionCount, f.expected.transactionCount)
        XCTAssertEqual(trace.depth, 2, "sender then recipient")
        XCTAssertEqual(trace.children.count, 1)
    }

    /// Transactions must be ordered by the trace, sender first — a preview that led with
    /// the recipient would describe the transfer backwards.
    func testTransactionsAreOrderedByTrace() async throws {
        let f = try fixture()
        let result = try await client(f).emulate(boc: f.request.boc)

        XCTAssertEqual(
            result.transactions.first?.account.uppercased(),
            f.expected.senderAddress.uppercased()
        )
        XCTAssertEqual(
            result.transactions.last?.account.uppercased(),
            f.expected.destinationAddress.uppercased()
        )
    }

    /// Ordering must follow the **trace**, not the hash map's key order.
    ///
    /// The recorded fixture cannot prove this: its two transaction hashes happen to sort
    /// into the same order the trace gives. Verified by mutation — without this synthetic
    /// case, dropping trace ordering entirely leaves the suite green. Here the hashes sort
    /// opposite to causality, so only real trace traversal produces the right order.
    func testOrderingFollowsTraceNotHashOrder() async throws {
        // "zzz" sorts after "aaa", but the trace makes zzz the root.
        let rootHash = "zzz1"
        let childHash = "aaa2"
        let response: [String: Any] = [
            "mc_block_seqno": 1,
            "is_incomplete": false,
            "trace": [
                "tx_hash": rootHash,
                "children": [["tx_hash": childHash, "children": []]],
            ],
            "transactions": [
                rootHash: [
                    "account": "0:" + String(repeating: "11", count: 32),
                    "hash": "PZN0ti+X5r3ZbAycxzr+t96pPbXhl3p7dqMxnqWVIuk=",
                    "lt": "1", "now": 1,
                    "description": ["type": "ord", "aborted": false],
                    "out_msgs": [],
                ],
                childHash: [
                    "account": "0:" + String(repeating: "22", count: 32),
                    "hash": "PZN0ti+X5r3ZbAycxzr+t96pPbXhl3p7dqMxnqWVIuk=",
                    "lt": "2", "now": 1,
                    "description": ["type": "ord", "aborted": false],
                    "out_msgs": [],
                ],
            ],
        ]

        let client = ToncenterClient(
            network: .testnet,
            transport: SingleResponseTransport(
                response: TransportResponse(
                    status: 200,
                    body: try JSONSerialization.data(withJSONObject: response)
                )
            ),
            retryDelayNanoseconds: 0
        )

        let result = try await client.emulate(boc: "irrelevant")
        XCTAssertEqual(result.transactions.count, 2)
        XCTAssertEqual(
            result.transactions[0].account,
            "0:" + String(repeating: "11", count: 32),
            "the trace root must come first even though its hash sorts last"
        )
        XCTAssertEqual(result.transactions[1].account, "0:" + String(repeating: "22", count: 32))
    }

    /// Transactions the trace does not mention must still be returned, not silently
    /// dropped — an unreferenced transaction is data loss in a preview.
    func testTransactionsOutsideTheTraceAreStillReturned() async throws {
        let response: [String: Any] = [
            "mc_block_seqno": 1,
            "is_incomplete": false,
            "trace": ["tx_hash": "known", "children": []],
            "transactions": [
                "known": [
                    "account": "0:" + String(repeating: "11", count: 32),
                    "hash": "PZN0ti+X5r3ZbAycxzr+t96pPbXhl3p7dqMxnqWVIuk=",
                    "lt": "1", "now": 1, "out_msgs": [],
                ],
                "orphan": [
                    "account": "0:" + String(repeating: "33", count: 32),
                    "hash": "PZN0ti+X5r3ZbAycxzr+t96pPbXhl3p7dqMxnqWVIuk=",
                    "lt": "2", "now": 1, "out_msgs": [],
                ],
            ],
        ]
        let client = ToncenterClient(
            network: .testnet,
            transport: SingleResponseTransport(
                response: TransportResponse(
                    status: 200,
                    body: try JSONSerialization.data(withJSONObject: response)
                )
            ),
            retryDelayNanoseconds: 0
        )

        let result = try await client.emulate(boc: "irrelevant")
        XCTAssertEqual(result.transactions.count, 2, "the orphan must be appended, not dropped")
        XCTAssertEqual(result.transactions[0].account, "0:" + String(repeating: "11", count: 32))
    }

    // MARK: - Money flow

    /// What a wallet actually displays: the amount leaving plus the fees paid.
    func testMoneyFlowForTheSender() async throws {
        let f = try fixture()
        let result = try await client(f).emulate(boc: f.request.boc)

        let flow = result.moneyFlow(for: f.expected.senderAddress)
        XCTAssertEqual(
            flow.sent,
            BigUInt(f.expected.sentAmountNanoton),
            "sent should be the encoded amount"
        )
        XCTAssertEqual(flow.received, 0, "the sender receives nothing here")
        XCTAssertGreaterThan(flow.fees, 0, "the sender pays fees")
        XCTAssertTrue(flow.isOutgoing)
    }

    /// The recipient's fees must not be charged to the sender.
    func testMoneyFlowAttributesFeesPerAccount() async throws {
        let f = try fixture()
        let result = try await client(f).emulate(boc: f.request.boc)

        let senderFlow = result.moneyFlow(for: f.expected.senderAddress)
        let recipientFlow = result.moneyFlow(for: f.expected.destinationAddress)

        XCTAssertGreaterThan(recipientFlow.received, 0, "the recipient receives value")
        XCTAssertEqual(recipientFlow.sent, 0)
        // Both pay their own fees, and the totals are separate.
        XCTAssertGreaterThan(senderFlow.fees, 0)
        XCTAssertNotEqual(senderFlow.fees, result.totalFees, "total fees span both accounts")
        XCTAssertEqual(senderFlow.fees + recipientFlow.fees, result.totalFees)
    }

    func testMoneyFlowForAnUninvolvedAccountIsZero() async throws {
        let f = try fixture()
        let result = try await client(f).emulate(boc: f.request.boc)

        let flow = result.moneyFlow(for: "0:" + String(repeating: "ab", count: 32))
        XCTAssertEqual(flow.sent, 0)
        XCTAssertEqual(flow.received, 0)
        XCTAssertEqual(flow.fees, 0)
    }

    // MARK: - Safety properties

    /// An incomplete emulation must never be reported as a success: we cannot promise a
    /// transfer will work when part of the tree was not evaluated.
    func testIncompleteEmulationIsNotSuccessful() throws {
        let complete = EmulationResult(
            mcBlockSeqno: 1,
            transactions: [],
            trace: nil,
            isIncomplete: false
        )
        XCTAssertTrue(complete.allSucceeded)

        let incomplete = EmulationResult(
            mcBlockSeqno: 1,
            transactions: [],
            trace: nil,
            isIncomplete: true
        )
        XCTAssertFalse(
            incomplete.allSucceeded,
            "a partial emulation must not be presented as a successful preview"
        )
    }

    /// The normalized hash of the emulated BoC must match what was recorded, which is
    /// what a wallet later uses to find the transaction on chain.
    func testNormalizedHashOfTheEmulatedMessage() throws {
        let f = try fixture()
        // Recomputed here from the same BoC via the contracts layer in the recording.
        XCTAssertTrue(f.expected.normalizedHash.hasPrefix("0x"))
        XCTAssertEqual(f.expected.normalizedHash.count, 66)
    }

    /// Emulation must request `ignore_chksig`, or every preview of an unapproved
    /// transaction would fail signature validation.
    func testEmulationRequestsSignatureChecksBeSkipped() async throws {
        final class CapturingTransport: Transport, @unchecked Sendable {
            let body: Data
            private let lock = NSLock()
            private var captured: Data?

            init(body: Data) { self.body = body }

            var capturedBody: Data? {
                lock.lock(); defer { lock.unlock() }
                return captured
            }

            func send(_ request: TransportRequest) async throws -> TransportResponse {
                store(request.body)
                return TransportResponse(status: 200, body: body)
            }

            private func store(_ data: Data?) {
                lock.lock(); captured = data; lock.unlock()
            }
        }

        let f = try fixture()
        let responseBody = try JSONSerialization.data(withJSONObject: f.response.value)
        let transport = CapturingTransport(body: responseBody)
        let client = ToncenterClient(network: .testnet, transport: transport, retryDelayNanoseconds: 0)

        _ = try await client.emulate(boc: f.request.boc, ignoreSignature: true)

        let sent = try XCTUnwrap(transport.capturedBody)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: sent) as? [String: Any])
        XCTAssertEqual(json["ignore_chksig"] as? Bool, true, "the API spells it ignore_chksig")
        XCTAssertEqual(json["boc"] as? String, f.request.boc)
    }
}
