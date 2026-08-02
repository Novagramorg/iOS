import XCTest
import TONCore
@testable import TONConnect

/// Verifies protocol envelope decoding, link parsing, and reconnect pacing.
final class ProtocolTests: XCTestCase {
    // MARK: - Connect requests

    func testConnectRequestDecodes() throws {
        let json = """
        {"manifestUrl":"https://app.example/tonconnect-manifest.json",
         "items":[{"name":"ton_addr"},{"name":"ton_proof","payload":"challenge-123"}]}
        """
        let request = try JSONDecoder().decode(ConnectRequest.self, from: Data(json.utf8))

        XCTAssertEqual(request.manifestUrl, "https://app.example/tonconnect-manifest.json")
        XCTAssertEqual(request.items.count, 2)
        XCTAssertTrue(request.requestsProof)
        XCTAssertEqual(request.proofPayload, "challenge-123")
    }

    func testConnectRequestWithoutProof() throws {
        let json = #"{"manifestUrl":"https://a.b/m.json","items":[{"name":"ton_addr"}]}"#
        let request = try JSONDecoder().decode(ConnectRequest.self, from: Data(json.utf8))
        XCTAssertFalse(request.requestsProof)
        XCTAssertNil(request.proofPayload)
    }

    /// An unknown item must not fail the whole request — the protocol is open-ended and a
    /// wallet that rejects unfamiliar items breaks against newer dApps.
    func testUnknownConnectItemsAreTolerated() throws {
        let json = """
        {"manifestUrl":"https://a.b/m.json",
         "items":[{"name":"ton_addr"},{"name":"future_item_we_dont_know"}]}
        """
        let request = try JSONDecoder().decode(ConnectRequest.self, from: Data(json.utf8))
        XCTAssertEqual(request.items.count, 2)
        XCTAssertFalse(request.requestsProof)
    }

    // MARK: - RPC requests

    /// The protocol double-encodes parameters: `params` holds JSON *strings*, not objects.
    ///
    /// The field is `valid_until`, snake_case. Reading it as `validUntil` yields nil, which
    /// silently disables the expiry check — an expired request would then be signed. So the
    /// wire spelling is pinned here rather than assumed.
    func testSendTransactionParamsAreDoubleEncoded() throws {
        let inner = """
        {"valid_until":1700000600,"network":"-239","messages":[\
        {"address":"0:83dfd552e63729b472fcbcc8c45ebcc6691702558b68ec7527e1ba403a0f31a8",\
        "amount":"1000000000"}]}
        """
        let request = AppRequest(id: "1", method: "sendTransaction", params: [inner])

        XCTAssertEqual(request.knownMethod, .sendTransaction)
        let params = try request.decodeFirstParam(as: SendTransactionParams.self)
        XCTAssertEqual(params.validUntil, 1_700_000_600)
        XCTAssertEqual(params.network, "-239")
        XCTAssertEqual(params.messages.count, 1)
        XCTAssertEqual(params.messages[0].amount, "1000000000")
    }

    /// `extra_currency` is snake_case while `stateInit` beside it is camelCase. A single
    /// key-decoding strategy cannot satisfy both, so each is spelled out — and checked.
    func testMixedCasingOnTheWire() throws {
        let inner = """
        {"messages":[{\
        "address":"0:83dfd552e63729b472fcbcc8c45ebcc6691702558b68ec7527e1ba403a0f31a8",\
        "amount":"1","stateInit":"te6cckEBAQEAAgAAAEysuc0=","extra_currency":{"239":"100"}}]}
        """
        let request = AppRequest(id: "1", method: "sendTransaction", params: [inner])
        let params = try request.decodeFirstParam(as: SendTransactionParams.self)

        XCTAssertEqual(params.messages[0].extraCurrency, ["239": "100"])
        XCTAssertEqual(params.messages[0].stateInit, "te6cckEBAQEAAgAAAEysuc0=")
    }

    func testSendTransactionWithPayloadAndStateInit() throws {
        let inner = """
        {"messages":[{"address":"0:\(String(repeating: "11", count: 32))","amount":"5",\
        "payload":"te6ccgEBAQEAAgAAAA==","stateInit":"te6ccgEBAQEAAgAAAA=="}]}
        """
        let params = try AppRequest(id: "1", method: "sendTransaction", params: [inner])
            .decodeFirstParam(as: SendTransactionParams.self)
        XCTAssertNotNil(params.messages[0].payload)
        XCTAssertNotNil(params.messages[0].stateInit)
        XCTAssertNil(params.validUntil, "an absent deadline must decode as nil, not zero")
    }

    /// An expired request must be refused rather than signed.
    func testExpiryCheck() {
        let expired = SendTransactionParams(validUntil: 1000, messages: [])
        XCTAssertTrue(expired.isExpired(now: 1001))
        XCTAssertFalse(expired.isExpired(now: 1000))
        XCTAssertFalse(expired.isExpired(now: 999))

        // No deadline means no expiry.
        XCTAssertFalse(SendTransactionParams(messages: []).isExpired(now: .max))
    }

    func testMissingParameterIsReported() {
        let request = AppRequest(id: "1", method: "sendTransaction", params: [])
        XCTAssertThrowsError(try request.decodeFirstParam(as: SendTransactionParams.self)) { error in
            guard case ProtocolError.missingParameter = error else {
                return XCTFail("expected missingParameter, got \(error)")
            }
        }
    }

    func testMalformedParameterIsReported() {
        let request = AppRequest(id: "1", method: "sendTransaction", params: ["not json"])
        XCTAssertThrowsError(try request.decodeFirstParam(as: SendTransactionParams.self)) { error in
            guard case ProtocolError.parameterDecodingFailed = error else {
                return XCTFail("expected parameterDecodingFailed, got \(error)")
            }
        }
    }

    func testUnknownMethodIsNotAKnownMethod() {
        XCTAssertNil(AppRequest(id: "1", method: "futureMethod", params: []).knownMethod)
        XCTAssertEqual(AppRequest(id: "1", method: "signData", params: []).knownMethod, .signData)
        XCTAssertEqual(AppRequest(id: "1", method: "disconnect", params: []).knownMethod, .disconnect)
    }

    // MARK: - Responses

    func testSuccessResponseEncodes() throws {
        let response = WalletResponseSuccess(id: "7", result: "te6ccgEBAQEAAgAAAA==")
        let json = try JSONSerialization.jsonObject(
            with: try JSONEncoder().encode(response)
        ) as? [String: Any]
        XCTAssertEqual(json?["id"] as? String, "7")
        XCTAssertEqual(json?["result"] as? String, "te6ccgEBAQEAAgAAAA==")
    }

    func testErrorResponseEncodesNestedCode() throws {
        let response = WalletResponseError(
            id: "7",
            code: SendTransactionErrorCode.userRejects.rawValue,
            message: "declined"
        )
        let json = try JSONSerialization.jsonObject(
            with: try JSONEncoder().encode(response)
        ) as? [String: Any]
        let error = json?["error"] as? [String: Any]
        XCTAssertEqual(error?["code"] as? Int, 300)
        XCTAssertEqual(error?["message"] as? String, "declined")
    }

    /// The spec's numeric values, which dApps switch on.
    func testErrorCodeValues() {
        XCTAssertEqual(ConnectEventErrorCode.userRejects.rawValue, 300)
        XCTAssertEqual(ConnectEventErrorCode.manifestNotFound.rawValue, 2)
        XCTAssertEqual(ConnectEventErrorCode.manifestContent.rawValue, 3)
        XCTAssertEqual(ConnectEventErrorCode.methodNotSupported.rawValue, 400)
        XCTAssertEqual(SendTransactionErrorCode.badRequest.rawValue, 1)
        XCTAssertEqual(SendTransactionErrorCode.unknownApp.rawValue, 100)
        XCTAssertEqual(SignDataErrorCode.userRejects.rawValue, 300)
        XCTAssertEqual(DisconnectErrorCode.methodNotSupported.rawValue, 400)
    }

    /// The address in a connect reply is the **raw** form, per the spec — not friendly.
    func testAddressReplyUsesRawForm() throws {
        let reply = TonAddressItemReply(
            address: "0:" + String(repeating: "83", count: 32),
            network: "-239",
            publicKey: String(repeating: "ab", count: 32),
            walletStateInit: "te6ccgEBAQEAAgAAAA=="
        )
        XCTAssertTrue(reply.address.contains(":"), "the protocol specifies the raw form here")
        XCTAssertEqual(reply.name, "ton_addr")
    }
}

/// Verifies link parsing across the shapes wallets actually receive.
final class ConnectURLTests: XCTestCase {
    private let clientID = String(repeating: "ab", count: 32)
    private var request: String {
        #"{"manifestUrl":"https://a.b/m.json","items":[{"name":"ton_addr"}]}"#
    }

    private func encoded(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? s
    }

    func testDeepLink() throws {
        let link = "tc://?v=2&id=\(clientID)&r=\(encoded(request))"
        let parsed = try ConnectURL.parse(link)
        XCTAssertEqual(parsed.clientID, clientID)
        XCTAssertEqual(parsed.version, "2")
        XCTAssertEqual(parsed.request.manifestUrl, "https://a.b/m.json")
    }

    /// The form a wallet receives from an iOS universal link.
    func testUniversalLink() throws {
        let link = "https://app.tonkeeper.com/ton-connect?v=2&id=\(clientID)&r=\(encoded(request))"
        let parsed = try ConnectURL.parse(link)
        XCTAssertEqual(parsed.clientID, clientID)
        XCTAssertEqual(parsed.request.items.count, 1)
    }

    /// A scheme-less string defaults to `tc://`, matching the existing wrapper's behaviour.
    func testSchemelessQueryDefaultsToTC() throws {
        let parsed = try ConnectURL.parse("?v=2&id=\(clientID)&r=\(encoded(request))")
        XCTAssertEqual(parsed.clientID, clientID)
    }

    func testBareQueryWithoutQuestionMark() throws {
        let parsed = try ConnectURL.parse("v=2&id=\(clientID)&r=\(encoded(request))")
        XCTAssertEqual(parsed.clientID, clientID)
    }

    /// `tc:` with no authority, which some QR encoders emit.
    func testSchemeWithoutAuthority() throws {
        let parsed = try ConnectURL.parse("tc:?v=2&id=\(clientID)&r=\(encoded(request))")
        XCTAssertEqual(parsed.clientID, clientID)
    }

    func testBridgeURLIsCaptured() throws {
        let link = "tc://?id=\(clientID)&r=\(encoded(request))&bridge=https://bridge.example"
        XCTAssertEqual(try ConnectURL.parse(link).bridgeURL, "https://bridge.example")
    }

    func testReturnStrategyIsCaptured() throws {
        let link = "tc://?id=\(clientID)&r=\(encoded(request))&ret=back"
        XCTAssertEqual(try ConnectURL.parse(link).returnStrategy, "back")
    }

    // MARK: - Rejection

    func testMissingClientIDIsRejected() {
        XCTAssertThrowsError(try ConnectURL.parse("tc://?v=2&r=\(encoded(request))")) { error in
            guard case ConnectURLError.missingClientID = error else {
                return XCTFail("expected missingClientID, got \(error)")
            }
        }
    }

    func testMissingRequestIsRejected() {
        XCTAssertThrowsError(try ConnectURL.parse("tc://?v=2&id=\(clientID)")) { error in
            guard case ConnectURLError.missingRequest = error else {
                return XCTFail("expected missingRequest, got \(error)")
            }
        }
    }

    /// A malformed client id must fail here, not when the first sealed message cannot be
    /// routed.
    func testMalformedClientIDIsRejected() {
        for bad in ["tooshort", String(repeating: "zz", count: 32), String(repeating: "ab", count: 31)] {
            XCTAssertThrowsError(
                try ConnectURL.parse("tc://?id=\(bad)&r=\(encoded(request))"),
                "client id \"\(bad)\" should be rejected"
            )
        }
    }

    func testMalformedRequestJSONIsRejected() {
        XCTAssertThrowsError(
            try ConnectURL.parse("tc://?id=\(clientID)&r=\(encoded("{not json"))")
        ) { error in
            guard case ConnectURLError.malformedRequest = error else {
                return XCTFail("expected malformedRequest, got \(error)")
            }
        }
    }

    func testLinkDetection() {
        XCTAssertTrue(ConnectURL.looksLikeConnectLink("tc://?id=x&r=y"))
        XCTAssertTrue(ConnectURL.looksLikeConnectLink("https://app.tonkeeper.com/ton-connect?id=x&r=y"))
        XCTAssertFalse(ConnectURL.looksLikeConnectLink("https://example.com"))
        XCTAssertFalse(ConnectURL.looksLikeConnectLink("ton://transfer/EQ..."))
        XCTAssertFalse(ConnectURL.looksLikeConnectLink(""))
    }
}

/// Verifies reconnect pacing, which decides whether a wallet survives a bridge restart or
/// helps knock it over.
final class BackoffTests: XCTestCase {
    func testFirstAttemptIsImmediate() {
        XCTAssertEqual(BackoffPolicy.default.delay(forAttempt: 0), 0)
    }

    func testDelaysGrowExponentially() {
        let policy = BackoffPolicy(initialDelay: 1, maxDelay: 60, multiplier: 2, jitter: 0)
        XCTAssertEqual(policy.delay(forAttempt: 1), 1)
        XCTAssertEqual(policy.delay(forAttempt: 2), 2)
        XCTAssertEqual(policy.delay(forAttempt: 3), 4)
        XCTAssertEqual(policy.delay(forAttempt: 4), 8)
    }

    func testDelaysAreCapped() {
        let policy = BackoffPolicy(initialDelay: 1, maxDelay: 10, multiplier: 2, jitter: 0)
        XCTAssertEqual(policy.delay(forAttempt: 20), 10, "growth must stop at the cap")
    }

    /// Jitter must actually vary the delay, or every wallet reconnects in lockstep after a
    /// bridge restart and immediately overwhelms it again.
    func testJitterSpreadsRetries() {
        let policy = BackoffPolicy(initialDelay: 10, maxDelay: 60, multiplier: 2, jitter: 0.3)
        var delays = Set<TimeInterval>()
        for _ in 0..<50 { delays.insert(policy.delay(forAttempt: 3)) }
        XCTAssertGreaterThan(delays.count, 10, "jittered delays should be spread out")

        // And stay in the intended band.
        for delay in delays {
            XCTAssertGreaterThanOrEqual(delay, 0)
            XCTAssertLessThanOrEqual(delay, 40 * 1.3 + 0.001)
        }
    }

    func testNeverNegative() {
        let policy = BackoffPolicy(initialDelay: 1, maxDelay: 5, multiplier: 2, jitter: 1.0)
        for attempt in 1...10 {
            XCTAssertGreaterThanOrEqual(policy.delay(forAttempt: attempt), 0)
        }
    }

    func testImmediatePolicyNeverWaits() {
        for attempt in 0...10 {
            XCTAssertEqual(BackoffPolicy.immediate.delay(forAttempt: attempt), 0)
        }
    }
}

/// Verifies the bridge frame decoding and last-event-id handling.
final class BridgeFrameTests: XCTestCase {
    func testValidFrameDecodes() {
        let event = SSEEvent(
            event: "message",
            data: #"{"from":"aabbcc","message":"BASE64=="}"#,
            id: "1712345678"
        )
        let message = SSEStreamDelegate.bridgeMessage(from: event)
        XCTAssertEqual(message?.from, "aabbcc")
        XCTAssertEqual(message?.message, "BASE64==")
        XCTAssertEqual(message?.eventID, "1712345678")
    }

    /// The bridge sends frames of its own — heartbeats and notices without a `from`/`message`
    /// pair. Those must be skipped, not treated as errors that break the stream.
    func testNonMessageFramesAreSkipped() {
        XCTAssertNil(SSEStreamDelegate.bridgeMessage(from: SSEEvent(data: "")))
        XCTAssertNil(SSEStreamDelegate.bridgeMessage(from: SSEEvent(data: "heartbeat")))
        XCTAssertNil(SSEStreamDelegate.bridgeMessage(from: SSEEvent(data: #"{"other":"shape"}"#)))
        XCTAssertNil(SSEStreamDelegate.bridgeMessage(from: SSEEvent(data: #"{"from":"a"}"#)))
    }

    func testLastEventIDStoreRoundTrips() async {
        let store = InMemoryLastEventIDStore()
        // Bind first: XCTAssert autoclosures cannot contain `await`.
        let initial = await store.load()
        XCTAssertNil(initial)

        await store.save("42")
        let first = await store.load()
        XCTAssertEqual(first, "42")

        await store.save("43")
        let second = await store.load()
        XCTAssertEqual(second, "43")
    }

    func testLastEventIDStoreCanSeedFromPersistedValue() async {
        let store = InMemoryLastEventIDStore(initial: "restored-id")
        let loaded = await store.load()
        XCTAssertEqual(
            loaded,
            "restored-id",
            "a wallet relaunched after being killed must resume, not replay"
        )
    }
}
