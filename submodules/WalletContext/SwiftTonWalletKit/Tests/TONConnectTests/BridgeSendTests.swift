import XCTest
@testable import TONConnect

/// Verifies how a bridge send behaves when the server pushes back.
///
/// This path matters more than its size suggests: the caller is a user who just tapped approve
/// or reject. Giving up on a transient failure means the reply is generated, discarded, and the
/// dApp waits forever — the user believes they answered and the dApp believes they never did.
///
/// Public bridges really do rate-limit; a live run against `bridge.tonapi.io` returned
/// `429 {"message":"too many push operations"}` and the send failed outright, which is what
/// prompted the retry this file covers.
final class BridgeSendTests: XCTestCase {
    /// Scripts a sequence of responses and counts attempts.
    final class ScriptedProtocol: URLProtocol {
        struct Response: Sendable {
            let status: Int
            let headers: [String: String]
            init(_ status: Int, headers: [String: String] = [:]) {
                self.status = status
                self.headers = headers
            }
        }

        nonisolated(unsafe) private static let lock = NSLock()
        nonisolated(unsafe) private static var script: [Response] = []
        nonisolated(unsafe) private static var attempts = 0

        static func reset(_ responses: [Response]) {
            lock.lock(); script = responses; attempts = 0; lock.unlock()
        }

        static var attemptCount: Int {
            lock.lock(); defer { lock.unlock() }
            return attempts
        }

        private static func next() -> Response {
            lock.lock(); defer { lock.unlock() }
            let index = min(attempts, script.count - 1)
            attempts += 1
            return script.isEmpty ? Response(200) : script[index]
        }

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            let scripted = Self.next()
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: scripted.status,
                httpVersion: "HTTP/1.1",
                headerFields: scripted.headers
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(#"{"message":"scripted"}"#.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}

        static func session() -> URLSession {
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [ScriptedProtocol.self]
            return URLSession(configuration: config)
        }
    }

    private func makeClient() -> BridgeClient {
        BridgeClient(
            bridgeURL: URL(string: "https://bridge.example.com/bridge")!,
            clientID: "aa",
            session: ScriptedProtocol.session(),
            // No waiting, so the test measures the retry policy rather than the clock.
            backoff: .immediate
        )
    }

    func testSucceedsOnTheFirstTry() async throws {
        ScriptedProtocol.reset([.init(200)])
        try await makeClient().send("sealed", to: "bb")
        XCTAssertEqual(ScriptedProtocol.attemptCount, 1, "a success must not be retried")
    }

    /// The case that prompted all of this.
    func testRetriesAfterRateLimiting() async throws {
        ScriptedProtocol.reset([.init(429), .init(429), .init(200)])
        try await makeClient().send("sealed", to: "bb")
        XCTAssertEqual(ScriptedProtocol.attemptCount, 3, "should have retried twice then succeeded")
    }

    func testRetriesServerErrors() async throws {
        ScriptedProtocol.reset([.init(502), .init(200)])
        try await makeClient().send("sealed", to: "bb")
        XCTAssertEqual(ScriptedProtocol.attemptCount, 2)
    }

    /// A malformed request will fail identically every time, so retrying only delays telling
    /// the user.
    func testDoesNotRetryClientErrors() async {
        ScriptedProtocol.reset([.init(400)])
        do {
            try await makeClient().send("sealed", to: "bb")
            XCTFail("expected a failure")
        } catch {
            XCTAssertEqual(ScriptedProtocol.attemptCount, 1, "a 400 must not be retried")
        }
    }

    /// Retrying must be bounded — an app cannot hang forever on a bridge that is down.
    func testGivesUpAfterTheAttemptLimit() async {
        ScriptedProtocol.reset([.init(429)])
        do {
            try await makeClient().send("sealed", to: "bb")
            XCTFail("expected a failure")
        } catch {
            XCTAssertEqual(ScriptedProtocol.attemptCount, BridgeClient.sendAttempts)
            // And the failure must still say what happened, so the app can tell the user.
            XCTAssertTrue("\(error)".contains("429"), "\(error)")
        }
    }

    /// The first retry must actually wait.
    ///
    /// `BackoffPolicy.delay(forAttempt: 0)` is zero, so an off-by-one in the retry loop makes
    /// the first retry immediate — the worst possible response to a rate limiter, because it
    /// spends an attempt instantly and, on bridges that count every request, extends the ban.
    /// The live bridge exposed this: three attempts inside three seconds all hit the same 429.
    func testFirstRetryWaits() async throws {
        ScriptedProtocol.reset([.init(429), .init(200)])
        let client = BridgeClient(
            bridgeURL: URL(string: "https://bridge.example.com/bridge")!,
            clientID: "aa",
            session: ScriptedProtocol.session(),
            // A measurable, jitter-free delay so the assertion is about the schedule.
            backoff: BackoffPolicy(initialDelay: 0.4, maxDelay: 10, multiplier: 2, jitter: 0)
        )

        let started = Date()
        try await client.send("sealed", to: "bb")
        let elapsed = Date().timeIntervalSince(started)

        XCTAssertEqual(ScriptedProtocol.attemptCount, 2)
        XCTAssertGreaterThanOrEqual(
            elapsed, 0.35,
            "the first retry fired immediately instead of waiting out the backoff"
        )
    }

    /// Successive retries must back off further, not repeat the same short delay.
    func testBackoffGrowsBetweenRetries() async throws {
        ScriptedProtocol.reset([.init(429), .init(429), .init(200)])
        let client = BridgeClient(
            bridgeURL: URL(string: "https://bridge.example.com/bridge")!,
            clientID: "aa",
            session: ScriptedProtocol.session(),
            backoff: BackoffPolicy(initialDelay: 0.3, maxDelay: 10, multiplier: 2, jitter: 0)
        )

        let started = Date()
        try await client.send("sealed", to: "bb")
        let elapsed = Date().timeIntervalSince(started)

        XCTAssertEqual(ScriptedProtocol.attemptCount, 3)
        // 0.3 then 0.6; a flat schedule would total only 0.6.
        XCTAssertGreaterThanOrEqual(elapsed, 0.85, "delays did not grow between retries")
    }

    // MARK: - Retry-After

    func testRetryAfterIsParsed() throws {
        let response = HTTPURLResponse(
            url: URL(string: "https://bridge.example.com")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": "7"]
        )!
        XCTAssertEqual(BridgeClient.retryAfterSeconds(response), 7)
    }

    /// A date-form or nonsense `Retry-After` must fall back to the backoff rather than
    /// producing a garbage delay.
    func testUnparseableRetryAfterIsIgnored() throws {
        for value in ["Wed, 21 Oct 2015 07:28:00 GMT", "soon", "", "-5"] {
            let response = HTTPURLResponse(
                url: URL(string: "https://bridge.example.com")!,
                statusCode: 429,
                httpVersion: nil,
                headerFields: ["Retry-After": value]
            )!
            XCTAssertNil(BridgeClient.retryAfterSeconds(response), value)
        }
    }

    func testMissingRetryAfterIsNil() throws {
        let response = HTTPURLResponse(
            url: URL(string: "https://bridge.example.com")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: [:]
        )!
        XCTAssertNil(BridgeClient.retryAfterSeconds(response))
    }

    /// A bridge asking for an unreasonable wait must not park the user's reply for minutes.
    ///
    /// Raced against a deadline rather than simply awaited: an uncapped implementation would
    /// honour the full hour and *hang* the suite instead of failing it, which is worse than a
    /// red test and makes the mutation unverifiable.
    func testRetryAfterIsCappedByTheBackoffMaximum() async throws {
        ScriptedProtocol.reset([.init(429, headers: ["Retry-After": "3600"]), .init(200)])
        let client = BridgeClient(
            bridgeURL: URL(string: "https://bridge.example.com/bridge")!,
            clientID: "aa",
            session: ScriptedProtocol.session(),
            // A cap of zero means the honoured delay is also zero.
            backoff: .immediate
        )

        let finished = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                (try? await client.send("sealed", to: "bb")) != nil
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                return false
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }

        XCTAssertTrue(finished, "the send did not honour the cap and was still waiting after 5s")
        XCTAssertEqual(ScriptedProtocol.attemptCount, 2)
    }

    /// `Retry-After` must actually govern the wait, not merely be parsed.
    ///
    /// A surviving mutation exposed this gap: ignoring the header entirely and falling back to
    /// the backoff passed every other test here. It matters because a bridge that says "wait
    /// half a second" and gets hit immediately has its limit re-triggered — which is how the
    /// live run burned all four attempts inside three seconds.
    func testRetryAfterOverridesTheBackoff() async throws {
        ScriptedProtocol.reset([.init(429, headers: ["Retry-After": "1"]), .init(200)])
        let client = BridgeClient(
            bridgeURL: URL(string: "https://bridge.example.com/bridge")!,
            clientID: "aa",
            session: ScriptedProtocol.session(),
            // Far shorter than the header asks for, so honouring it is distinguishable from
            // falling back: backoff alone would finish in ~10ms.
            backoff: BackoffPolicy(initialDelay: 0.01, maxDelay: 30, multiplier: 2, jitter: 0)
        )

        let started = Date()
        try await client.send("sealed", to: "bb")
        let elapsed = Date().timeIntervalSince(started)

        XCTAssertEqual(ScriptedProtocol.attemptCount, 2)
        XCTAssertGreaterThanOrEqual(
            elapsed, 0.9,
            "waited \(elapsed)s; the server asked for 1s and was ignored in favour of the backoff"
        )
    }

    // MARK: - Classification

    func testRetryableClassification() {
        XCTAssertTrue(BridgeError.sendFailed(status: 429, body: "").isRetryable)
        XCTAssertTrue(BridgeError.sendFailed(status: 500, body: "").isRetryable)
        XCTAssertTrue(BridgeError.sendFailed(status: 503, body: "").isRetryable)
        XCTAssertTrue(BridgeError.nonHTTPResponse.isRetryable)

        XCTAssertFalse(BridgeError.sendFailed(status: 400, body: "").isRetryable)
        XCTAssertFalse(BridgeError.sendFailed(status: 403, body: "").isRetryable)
        XCTAssertFalse(BridgeError.sendFailed(status: 404, body: "").isRetryable)
        XCTAssertFalse(BridgeError.malformedURL("x").isRetryable)
    }
}
