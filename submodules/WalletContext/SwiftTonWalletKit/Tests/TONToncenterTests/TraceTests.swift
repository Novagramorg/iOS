import XCTest
import TONTestVectors
import TONCore
@testable import TONToncenter

/// Verifies trace decoding against a recorded multi-transaction mainnet trace.
///
/// Traces are how a wallet explains a transfer: a single jetton send fans out across the
/// sender, both jetton wallets, and a notification, and only the tree shows which caused
/// which.
///
/// Expected sizes are read from the fixture rather than hard-coded. An earlier version
/// asserted a literal seven, which broke the moment the fixtures were re-recorded against a
/// different trace — the count was never the property under test. ``assertNonTrivial`` keeps
/// that flexibility from quietly weakening the suite: a degenerate single-transaction
/// recording fails loudly instead of making every assertion below vacuous.
final class TraceTests: XCTestCase {
    /// Pulls the recorded body that actually contains a populated trace — the fixture's
    /// first request returned none, because `getTrace` fans out several lookups and only
    /// some hit.
    private func populatedTraceBody() throws -> Data {
        let raw = try Vectors.rawFixture("toncenter/mainnet/traces")
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: raw) as? [String: Any])
        let fixtures = try XCTUnwrap(root["fixtures"] as? [[String: Any]])

        for fixture in fixtures {
            for request in (fixture["requests"] as? [[String: Any]]) ?? [] {
                guard let body = request["body"] as? [String: Any],
                      let traces = body["traces"] as? [[String: Any]],
                      !traces.isEmpty
                else { continue }
                return try JSONSerialization.data(withJSONObject: body)
            }
        }
        XCTFail("no populated trace in the fixture")
        return Data()
    }

    private func decodedTrace() throws -> Trace {
        let wire = try JSONDecoder().decode(
            Wire.TracesResponse.self,
            from: try populatedTraceBody()
        )
        return try XCTUnwrap(Mappers.traces(wire).first)
    }

    func testTraceMetadataDecodes() throws {
        let trace = try decodedTrace()

        XCTAssertTrue(trace.traceID.hasPrefix("0x"), "trace id should be hex")
        XCTAssertEqual(trace.traceID.count, 66)
        XCTAssertNotNil(trace.externalHash, "an externally-triggered trace has an external hash")
        XCTAssertFalse(trace.isIncomplete)
        XCTAssertNotNil(trace.startLogicalTime)
        XCTAssertNotNil(trace.startTime)
    }

    /// The recorded trace must be big enough for the structural assertions to mean anything.
    private func assertNonTrivial(_ trace: Trace, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertGreaterThan(
            trace.transactions.count, 2,
            "the recorded trace has \(trace.transactions.count) transactions; re-record against "
                + "a trace that actually fans out or these tests prove nothing",
            file: file, line: line
        )
    }

    func testTraceInfoDecodes() throws {
        let trace = try decodedTrace()
        let info = try XCTUnwrap(trace.info)
        assertNonTrivial(trace)

        XCTAssertEqual(info.state, "complete")
        XCTAssertEqual(info.pendingMessageCount, 0)
        // The counts the server reports must match what we actually decoded, which is the
        // real invariant — not any particular number.
        XCTAssertEqual(info.transactionCount, trace.transactions.count)
        XCTAssertGreaterThanOrEqual(info.messageCount, info.transactionCount)
    }

    /// The tree must be reconstructed, not flattened away.
    func testTraceTreeStructure() throws {
        let trace = try decodedTrace()
        assertNonTrivial(trace)
        let root = try XCTUnwrap(trace.root)

        XCTAssertEqual(
            root.transactionCount, trace.transactions.count,
            "the tree must hold every transaction in the trace"
        )
        XCTAssertGreaterThan(root.depth, 1, "a fan-out trace is deeper than one level")
        XCTAssertFalse(root.children.isEmpty)
        XCTAssertNotNil(root.inMessageHash, "each node records the message that caused it")
    }

    /// The mapper's transaction order must match the **tree's** order, not the hash map's.
    ///
    /// An earlier version of this test only checked that the tree was internally
    /// consistent, which is trivially true and proved nothing about the mapper. Mutation
    /// exposed that: disabling tree-based ordering entirely left it green. It now compares
    /// the emitted order against the tree walk.
    func testTransactionOrderFollowsTheTree() throws {
        let trace = try decodedTrace()
        let root = try XCTUnwrap(trace.root)

        assertNonTrivial(trace)

        // Tree order, converted to the hex form the mapped transactions carry.
        let expected = root.flattened().compactMap { Mappers.hexHash(fromBase64: $0.transactionHash) }
        XCTAssertEqual(
            expected.count, trace.transactions.count,
            "every tree node should convert to a hex hash"
        )

        let actual = trace.transactions.map(\.hash)
        XCTAssertEqual(
            actual,
            expected,
            "transactions must be emitted in tree order, not hash-map order"
        )
    }

    /// Independently: every parent must precede its children in the emitted order.
    func testParentsPrecedeChildrenInEmittedOrder() throws {
        let trace = try decodedTrace()
        let root = try XCTUnwrap(trace.root)
        let order = trace.transactions.map(\.hash)

        func index(of node: TraceNode) -> Int? {
            Mappers.hexHash(fromBase64: node.transactionHash).flatMap { order.firstIndex(of: $0) }
        }

        func check(_ node: TraceNode) {
            guard let parentIndex = index(of: node) else {
                return XCTFail("node \(node.transactionHash) missing from the emitted order")
            }
            for child in node.children {
                guard let childIndex = index(of: child) else {
                    return XCTFail("child \(child.transactionHash) missing from the emitted order")
                }
                XCTAssertGreaterThan(childIndex, parentIndex, "a child must follow its parent")
                check(child)
            }
        }
        check(root)
    }

    func testTraceAggregates() throws {
        let trace = try decodedTrace()
        XCTAssertGreaterThan(trace.totalFees, 0, "a seven-transaction trace incurs fees")
        XCTAssertFalse(trace.isPending, "a complete trace with no pending messages is settled")
    }

    /// An incomplete trace must not be reported as successful: transactions we have not
    /// seen may have failed.
    func testIncompleteTraceIsNotSuccessful() {
        let incomplete = Trace(
            traceID: "0xabc",
            externalHash: nil,
            startLogicalTime: nil,
            endLogicalTime: nil,
            startTime: nil,
            endTime: nil,
            isIncomplete: true,
            info: nil,
            root: nil,
            transactions: []
        )
        XCTAssertFalse(incomplete.allSucceeded)
        XCTAssertTrue(incomplete.isPending)
    }

    /// Pending messages mean the trace is still in flight even when marked complete.
    func testPendingMessagesMarkTheTraceInFlight() {
        let trace = Trace(
            traceID: "0xabc",
            externalHash: nil,
            startLogicalTime: nil,
            endLogicalTime: nil,
            startTime: nil,
            endTime: nil,
            isIncomplete: false,
            info: TraceInfo(
                state: "pending",
                messageCount: 3,
                transactionCount: 2,
                pendingMessageCount: 1,
                classificationState: nil
            ),
            root: nil,
            transactions: []
        )
        XCTAssertTrue(trace.isPending)
    }

    /// Transactions the tree omits must still be returned rather than silently dropped.
    func testTransactionsOutsideTheTreeAreRetained() throws {
        let json: [String: Any] = [
            "traces": [[
                "trace_id": "KqHyu/2L2d5PjG9kgTfAaM7F1a9x3/tg6ZL6Nis4sY8=",
                "is_incomplete": false,
                "trace": ["tx_hash": "known", "in_msg_hash": "m1", "children": []],
                "transactions": [
                    "known": [
                        "account": "0:" + String(repeating: "11", count: 32),
                        "hash": "PZN0ti+X5r3ZbAycxzr+t96pPbXhl3p7dqMxnqWVIuk=",
                        "lt": "1", "now": 1, "out_msgs": [],
                    ],
                    "orphan": [
                        "account": "0:" + String(repeating: "22", count: 32),
                        "hash": "PZN0ti+X5r3ZbAycxzr+t96pPbXhl3p7dqMxnqWVIuk=",
                        "lt": "2", "now": 1, "out_msgs": [],
                    ],
                ],
            ]]
        ]
        let wire = try JSONDecoder().decode(
            Wire.TracesResponse.self,
            from: try JSONSerialization.data(withJSONObject: json)
        )
        let trace = try XCTUnwrap(Mappers.traces(wire).first)
        XCTAssertEqual(trace.transactions.count, 2, "the orphan must be appended")
        XCTAssertEqual(trace.transactions[0].account, "0:" + String(repeating: "11", count: 32))
    }

    /// No pending traces is an ordinary outcome, so it yields an empty array. The
    /// reference throws here even though the endpoint answers `200` with an empty list.
    func testEmptyPendingTracesYieldsEmptyArray() async throws {
        let client = ToncenterClient(
            network: .mainnet,
            transport: SingleResponseTransport(
                response: TransportResponse(
                    status: 200,
                    body: Data(#"{"traces":[],"address_book":{},"metadata":{}}"#.utf8)
                )
            ),
            retryDelayNanoseconds: 0
        )
        let traces = try await client.getPendingTraces(externalMessageHash: "0x" + String(repeating: "00", count: 32))
        XCTAssertTrue(traces.isEmpty, "nothing in flight is not an error")
    }

    func testMissingTraceYieldsNil() async throws {
        let client = ToncenterClient(
            network: .mainnet,
            transport: SingleResponseTransport(
                response: TransportResponse(status: 200, body: Data(#"{"traces":[]}"#.utf8))
            ),
            retryDelayNanoseconds: 0
        )
        let trace = try await client.getTrace(traceID: "0x" + String(repeating: "ab", count: 32))
        XCTAssertNil(trace)
    }
}

/// Verifies message classification, which turns raw messages into something a wallet can
/// describe to a user.
final class MessageClassificationTests: XCTestCase {
    private func message(opcode: String?, comment: String? = nil, body: String? = nil) -> ChainMessage {
        ChainMessage(
            hash: "0xabc",
            source: "0:" + String(repeating: "11", count: 32),
            destination: "0:" + String(repeating: "22", count: 32),
            value: "1000000000",
            opcode: opcode,
            bodyBoc: body,
            comment: comment
        )
    }

    func testStandardOpcodesAreRecognised() {
        XCTAssertEqual(message(opcode: "0x0f8a7ea5").kind, .jettonTransfer)
        XCTAssertEqual(message(opcode: "0x178d4519").kind, .jettonInternalTransfer)
        XCTAssertEqual(message(opcode: "0x7362d09c").kind, .jettonNotify)
        XCTAssertEqual(message(opcode: "0x595f07bc").kind, .jettonBurn)
        XCTAssertEqual(message(opcode: "0x5fcc3d14").kind, .nftTransfer)
        XCTAssertEqual(message(opcode: "0x05138d91").kind, .nftOwnershipAssigned)
        XCTAssertEqual(message(opcode: "0x7bdd97de").kind, .nftOwnerChanged)
        XCTAssertEqual(message(opcode: "0xd53276db").kind, .excess)
    }

    /// Opcode 0 is the comment convention — a plain transfer carrying text, not a
    /// contract call.
    func testZeroOpcodeIsATransferNotAContractCall() {
        XCTAssertEqual(message(opcode: "0x0").kind, .tonTransfer)
        XCTAssertEqual(message(opcode: "0x00000000").kind, .tonTransfer)
    }

    func testAbsentOpcodeIsABareTransfer() {
        XCTAssertEqual(message(opcode: nil).kind, .tonTransfer)
    }

    func testUnknownOpcodeIsAContractCall() {
        XCTAssertEqual(message(opcode: "0xdeadbeef").kind, .contractExec)
    }

    /// A state init means deploy, but only when no recognised opcode claims the message
    /// first.
    func testStateInitMeansDeployOnlyWithoutAnOpcode() {
        XCTAssertEqual(
            MessageClassifier.classify(message(opcode: nil), hasStateInit: true),
            .contractDeploy
        )
        XCTAssertEqual(
            MessageClassifier.classify(message(opcode: "0x0f8a7ea5"), hasStateInit: true),
            .jettonTransfer,
            "a recognised opcode wins over the presence of a state init"
        )
    }

    /// Notifications and excess refunds are consequences of a transfer, not transfers.
    /// Counting them would double-count the amount shown to the user.
    func testOnlyRealTransfersAreUserFacing() {
        XCTAssertTrue(MessageKind.tonTransfer.isUserFacingTransfer)
        XCTAssertTrue(MessageKind.jettonTransfer.isUserFacingTransfer)
        XCTAssertTrue(MessageKind.nftTransfer.isUserFacingTransfer)

        XCTAssertFalse(MessageKind.jettonNotify.isUserFacingTransfer)
        XCTAssertFalse(MessageKind.jettonInternalTransfer.isUserFacingTransfer)
        XCTAssertFalse(MessageKind.excess.isUserFacingTransfer)
        XCTAssertFalse(MessageKind.contractExec.isUserFacingTransfer)
    }

    func testOpCodeParsesBothHexForms() {
        XCTAssertEqual(OpCode(hexString: "0x0f8a7ea5"), .jettonTransfer)
        XCTAssertEqual(OpCode(hexString: "0f8a7ea5"), .jettonTransfer)
        XCTAssertEqual(OpCode(hexString: "0X0F8A7EA5"), .jettonTransfer)
        XCTAssertNil(OpCode(hexString: "0xnothex"))
        XCTAssertNil(OpCode(hexString: "0xdeadbeef"), "an unknown opcode is not an OpCode case")
    }

    // MARK: - Comments

    func testDecodedCommentIsPreferred() {
        let m = message(opcode: "0x0", comment: "thanks!")
        XCTAssertEqual(m.textComment, "thanks!")
    }

    /// When Toncenter has not decoded the comment, it must be read from the body: a
    /// 32-bit zero opcode followed by UTF-8 text.
    func testCommentIsDecodedFromTheBodyWhenAbsent() throws {
        let cell = try beginCell()
            .storeUInt(0, bits: 32)
            .storeStringTail("hello chain")
            .endCell()
        let m = message(opcode: "0x0", comment: nil, body: cell.toBocBase64())
        XCTAssertEqual(m.textComment, "hello chain")
    }

    /// A body whose leading 32 bits are not zero is not a comment, and must not be
    /// misread as one.
    func testNonZeroOpcodeBodyIsNotReadAsAComment() throws {
        let cell = try beginCell()
            .storeUInt(0x0f8a_7ea5, bits: 32)
            .storeStringTail("not a comment")
            .endCell()
        let m = message(opcode: "0x0f8a7ea5", comment: nil, body: cell.toBocBase64())
        XCTAssertNil(m.textComment)
    }

    func testEmptyBodyHasNoComment() {
        XCTAssertNil(message(opcode: nil).textComment)
    }

    func testMalformedBodyDoesNotCrash() {
        let m = message(opcode: "0x0", comment: nil, body: "not-a-valid-boc")
        XCTAssertNil(m.textComment)
    }
}
