import XCTest
import TONCore
@testable import TONToncenter

/// Verifies the streaming client against a scripted socket.
///
/// The frames here are copied from a live capture against `testnet.toncenter.com`, so the
/// decoding is checked against what the server really sends rather than against the schema.
/// The behaviours that only appear over time — reconnect, resubscribe, keepalive, and dropping
/// a stale lower-finality frame — are driven deterministically rather than by waiting.
final class StreamingTests: XCTestCase {
    private let wallet = try! Address.parse(
        "0:bd0ef4d11b0aae0e8cbba3a8b194fbafc7f1ab453f3531b2f2f5bfe633a9b615"
    )

    // MARK: - Scripted socket

    /// A socket that replays scripted frames and records what was sent.
    ///
    /// Each connection consumes the next script. `nil` in a script means "the connection ends
    /// here", which is how a drop is simulated without any real networking.
    actor ScriptedSocket: StreamingSocket {
        private var frames: [String]
        private var sent: [String] = []
        private var closed = false
        private let recorder: Recorder

        init(frames: [String], recorder: Recorder) {
            self.frames = frames
            self.recorder = recorder
        }

        func connect() async throws { await recorder.noteConnect() }

        /// Put this in a script where the connection should drop.
        ///
        /// Explicit rather than implicit-on-exhaustion: a socket that dies the moment it runs
        /// out of frames can never stay open long enough to be pinged, which silently made the
        /// keepalive test unable to observe anything.
        static let dropMarker = "__DROP__"

        func receive() async throws -> String {
            while true {
                if closed { throw StreamingError.notConnected }
                if frames.isEmpty {
                    // Healthy but idle: park until the client closes us.
                    try await Task.sleep(nanoseconds: 5_000_000)
                    continue
                }
                let frame = frames.removeFirst()
                if frame == Self.dropMarker {
                    closed = true
                    throw StreamingError.notConnected
                }
                return frame
            }
        }

        func send(_ text: String) async throws {
            sent.append(text)
            await recorder.noteSent(text)
        }

        func close() async { closed = true }
    }

    /// Shared record across reconnects, since each attempt builds a fresh socket.
    actor Recorder {
        private(set) var connects = 0
        private(set) var sent: [String] = []

        func noteConnect() { connects += 1 }
        func noteSent(_ text: String) { sent.append(text) }

        func subscribeFrames() -> [String] { sent.filter { $0.contains("\"subscribe\"") } }
        func pingFrames() -> [String] { sent.filter { $0.contains("\"ping\"") } }

        /// Waits for at least `count` frames matching `substring`, so tests need no fixed sleeps.
        func waitForSent(containing substring: String, count: Int = 1, timeout: TimeInterval = 5) async -> Bool {
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline {
                if sent.filter({ $0.contains(substring) }).count >= count { return true }
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
            return sent.filter { $0.contains(substring) }.count >= count
        }
    }

    struct ScriptedFactory: StreamingSocketFactory {
        let scripts: [[String]]
        let recorder: Recorder
        let counter: Counter

        final class Counter: @unchecked Sendable {
            private let lock = NSLock()
            private var value = 0
            func next() -> Int { lock.lock(); defer { lock.unlock() }; value += 1; return value - 1 }
        }

        func makeSocket() -> any StreamingSocket {
            let index = counter.next()
            let frames = index < scripts.count ? scripts[index] : []
            return ScriptedSocket(frames: frames, recorder: recorder)
        }
    }

    private func makeClient(
        scripts: [[String]],
        pingInterval: TimeInterval = 3600
    ) -> (ToncenterStreaming, Recorder) {
        let recorder = Recorder()
        let factory = ScriptedFactory(
            scripts: scripts,
            recorder: recorder,
            counter: ScriptedFactory.Counter()
        )
        let client = ToncenterStreaming(
            factory: factory,
            configuration: .init(
                pingInterval: pingInterval,
                backoff: .immediate,
                minFinality: .pending
            )
        )
        return (client, recorder)
    }

    // MARK: - Captured frames

    private let subscribedAck = #"{"id":"sync-1","status":"subscribed"}"#

    private func balanceFrame(
        balance: String = "1268095327",
        finality: String = "confirmed"
    ) -> String {
        """
        {"type":"account_state_change","finality":"\(finality)",
         "account":"0:BD0EF4D11B0AAE0E8CBBA3A8B194FBAFC7F1AB453F3531B2F2F5BFE633A9B615",
         "state":{"hash":"Q1trY0fXtzQU2ti/P+tXlo9ZpAdaegFmV2b/dclbKNQ=","balance":"\(balance)",
         "extra_currencies":null,"account_status":"active","frozen_hash":null,
         "data_hash":"eT6ryVa61rhDATiC1jPlY1ItqMEg9Zmba3K0V4e0qao=",
         "code_hash":"IINLe3KxEhR+Gy+0V7hOdNGjDwT3N9T2KmaOlVLSty8="}}
        """
    }

    private func transactionsFrame(
        finality: String = "pending",
        traceHash: String = "U0quRm916Jef4tJh/vgLd64knzTm4beGqn9Pjpuy2DY="
    ) -> String {
        """
        {"type":"transactions","finality":"\(finality)","trace_external_hash_norm":"\(traceHash)",
         "transactions":[{"account":"0:BD0EF4D11B0AAE0E8CBBA3A8B194FBAFC7F1AB453F3531B2F2F5BFE633A9B615",
         "hash":"fWxquKo7We+xjC1xmHkGDiz1pM3uvu3IZ4xLC6f4H8I=","lt":"86711284000000",
         "now":1785482308,"total_fees":"477625","description":{"type":"ordinary","aborted":false},
         "out_msgs":[]}],"metadata":{}}
        """
    }

    /// Buffers stream events on its own task so a test can await with a deadline.
    ///
    /// Awaiting `AsyncStream.Iterator.next()` directly blocks forever when the expected event
    /// never arrives, and a deadline loop wrapped *around* that await never gets to re-check
    /// its deadline — the whole suite hangs instead of failing. The collector owns the iterator
    /// and hands out what it has already received.
    actor StreamCollector {
        private var buffer: [StreamEvent] = []
        private var pump: Task<Void, Never>?

        init(_ stream: AsyncStream<StreamEvent>) {
            // Started separately: an actor's `deinit` may touch isolated state, but its
            // initializer may not, so the pump is attached right after construction.
            self.stream = stream
        }

        private let stream: AsyncStream<StreamEvent>

        /// Begins buffering. Called by ``collect(_:)``.
        func start() {
            guard pump == nil else { return }
            pump = Task { [weak self] in
                guard let self else { return }
                for await event in await self.stream { await self.append(event) }
            }
        }

        deinit { pump?.cancel() }
        private func append(_ event: StreamEvent) { buffer.append(event) }

        /// Next event, skipping connection notices unless asked for them.
        func next(
            includingConnectionEvents: Bool = false,
            timeout: TimeInterval = 5
        ) async -> StreamEvent? {
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline {
                while !buffer.isEmpty {
                    let event = buffer.removeFirst()
                    if !includingConnectionEvents, case .connectionChanged = event { continue }
                    return event
                }
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
            return nil
        }

        /// Whether both a connect and a disconnect were observed.
        func sawConnectionCycle(timeout: TimeInterval = 10) async -> (up: Bool, down: Bool) {
            var up = false
            var down = false
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline, !(up && down) {
                while !buffer.isEmpty {
                    if case .connectionChanged(let isConnected) = buffer.removeFirst() {
                        if isConnected { up = true } else { down = true }
                    }
                }
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
            return (up, down)
        }
    }

    /// Builds a collector already pumping the stream.
    private func collect(_ stream: AsyncStream<StreamEvent>) async -> StreamCollector {
        let collector = StreamCollector(stream)
        await collector.start()
        return collector
    }

    /// Reads the next event, failing rather than returning nil.
    private func require(
        _ collector: StreamCollector,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws -> StreamEvent {
        let event = await collector.next(timeout: timeout)
        return try XCTUnwrap(event, "no event arrived within \(timeout)s", file: file, line: line)
    }

    // MARK: - Decoding

    func testBalanceFrameDecodes() async throws {
        let (client, _) = makeClient(scripts: [[subscribedAck, balanceFrame()]])
        let stream = await client.events(for: [wallet])
        let events = await collect(stream)

        let event = await events.next()
        guard case .balance(let update) = try XCTUnwrap(event) else {
            return XCTFail("expected a balance event, got \(String(describing: event))")
        }
        XCTAssertEqual(update.address, wallet)
        XCTAssertEqual(update.balance, 1_268_095_327)
        XCTAssertEqual(update.status, .active)
        XCTAssertEqual(update.finality, .confirmed)
        XCTAssertEqual(update.stateHash, "Q1trY0fXtzQU2ti/P+tXlo9ZpAdaegFmV2b/dclbKNQ=")
        await client.stop()
    }

    func testTransactionsFrameDecodes() async throws {
        let (client, _) = makeClient(scripts: [[subscribedAck, transactionsFrame()]])
        let stream = await client.events(for: [wallet])
        let events = await collect(stream)

        let event = await events.next()
        guard case .transactions(let update) = try XCTUnwrap(event) else {
            return XCTFail("expected a transactions event, got \(String(describing: event))")
        }
        XCTAssertEqual(update.address, wallet)
        XCTAssertEqual(update.transactions.count, 1)
        XCTAssertEqual(update.finality, .pending)
        XCTAssertTrue(update.traceHash.hasPrefix("0x"), "trace hash should be hex: \(update.traceHash)")
        XCTAssertFalse(update.isInvalidated)
        await client.stop()
    }

    /// Acknowledgements carry no payload and must not surface as events.
    func testAcksAreNotDelivered() async throws {
        let (client, _) = makeClient(scripts: [[
            subscribedAck,
            #"{"id":"ping-1","status":"pong"}"#,
            balanceFrame(),
        ]])
        let stream = await client.events(for: [wallet])
        let events = await collect(stream)

        // The first payload event must be the balance, not either ack.
        guard case .balance = try await require(events) else {
            return XCTFail("an acknowledgement leaked into the stream")
        }
        await client.stop()
    }

    /// An unrecognised frame must be skipped, not kill the connection.
    ///
    /// The server can add notification types; a client that treated one as fatal would stop
    /// receiving the types it does understand.
    func testUnknownFramesAreSkipped() async throws {
        let (client, _) = makeClient(scripts: [[
            subscribedAck,
            #"{"type":"something_new_from_the_future","payload":{"a":1}}"#,
            "not json at all",
            balanceFrame(),
        ]])
        let stream = await client.events(for: [wallet])
        let events = await collect(stream)

        guard case .balance = try await require(events) else {
            return XCTFail("an unknown frame stopped the stream")
        }
        await client.stop()
    }

    // MARK: - Filtering

    /// Events for accounts nobody watches must not be delivered.
    ///
    /// The subscription is a union across watchers, so one watcher's addresses arrive on
    /// everyone's socket; without filtering, a wallet would see another wallet's balance.
    func testEventsForUnwatchedAccountsAreDropped() async throws {
        let other = try Address.parse(
            "0:83dfd552e63729b472fcbcc8c45ebcc6691702558b68ec7527e1ba403a0f31a8"
        )
        let (client, _) = makeClient(scripts: [[subscribedAck, balanceFrame()]])
        // Watching a different address than the frame names.
        let stream = await client.events(for: [other])
        let events = await collect(stream)

        let event = await events.next(timeout: 1)
        XCTAssertNil(event, "an event for an unwatched account was delivered: \(String(describing: event))")
        await client.stop()
    }

    /// Watching only balances must not deliver transactions.
    func testEventTypeFilteringIsHonoured() async throws {
        let (client, _) = makeClient(scripts: [[subscribedAck, transactionsFrame(), balanceFrame()]])
        let stream = await client.events(for: [wallet], types: [.accountState])
        let events = await collect(stream)

        guard case .balance = try await require(events) else {
            return XCTFail("a transactions event was delivered to a balance-only watcher")
        }
        await client.stop()
    }

    // MARK: - Finality

    /// A `pending` frame arriving after `confirmed` for the same trace is stale reordering, not
    /// a reversal, and must not overwrite the better state.
    func testStalePendingAfterConfirmedIsDropped() async throws {
        let (client, _) = makeClient(scripts: [[
            subscribedAck,
            transactionsFrame(finality: "confirmed"),
            transactionsFrame(finality: "pending"),
        ]])
        let stream = await client.events(for: [wallet])
        let events = await collect(stream)

        guard case .transactions(let first) = try await require(events) else {
            return XCTFail("expected the confirmed event")
        }
        XCTAssertEqual(first.finality, .confirmed)

        let second = await events.next(timeout: 1)
        XCTAssertNil(second, "a stale pending frame was delivered after confirmed")
        await client.stop()
    }

    /// Settling further must still be delivered.
    func testProgressingFinalityIsDelivered() async throws {
        let (client, _) = makeClient(scripts: [[
            subscribedAck,
            transactionsFrame(finality: "pending"),
            transactionsFrame(finality: "finalized"),
        ]])
        let stream = await client.events(for: [wallet])
        let events = await collect(stream)

        guard case .transactions(let first) = try await require(events) else {
            return XCTFail("expected the pending event")
        }
        XCTAssertEqual(first.finality, .pending)

        guard case .transactions(let second) = try await require(events) else {
            return XCTFail("the finalized event was dropped")
        }
        XCTAssertEqual(second.finality, .finalized)
        await client.stop()
    }

    /// A different trace at lower finality must not be suppressed by an unrelated one.
    func testFinalityIsTrackedPerTrace() async throws {
        let (client, _) = makeClient(scripts: [[
            subscribedAck,
            transactionsFrame(finality: "finalized", traceHash: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="),
            transactionsFrame(finality: "pending", traceHash: "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="),
        ]])
        let stream = await client.events(for: [wallet])
        let events = await collect(stream)

        _ = try await require(events)
        guard case .transactions(let second) = try await require(events) else {
            return XCTFail("a second trace was suppressed by the first trace's finality")
        }
        XCTAssertEqual(second.finality, .pending)
        await client.stop()
    }

    /// An invalidated trace must reach whoever saw it, even though the frame names no account.
    func testTraceInvalidationIsRoutedToTheAccountsThatSawIt() async throws {
        let trace = "U0quRm916Jef4tJh/vgLd64knzTm4beGqn9Pjpuy2DY="
        let (client, _) = makeClient(scripts: [[
            subscribedAck,
            transactionsFrame(finality: "pending", traceHash: trace),
            #"{"type":"trace_invalidated","trace_external_hash_norm":"\#(trace)"}"#,
        ]])
        let stream = await client.events(for: [wallet])
        let events = await collect(stream)

        _ = try await require(events)
        guard case .transactions(let invalidation) = try await require(events) else {
            return XCTFail("the invalidation never arrived")
        }
        XCTAssertTrue(invalidation.isInvalidated)
        XCTAssertEqual(invalidation.address, wallet, "routed to the account that saw the trace")
        XCTAssertTrue(invalidation.transactions.isEmpty)
        await client.stop()
    }

    /// An invalidation for a trace nobody saw must be dropped rather than delivered with a
    /// placeholder address.
    func testInvalidationForAnUnknownTraceIsDropped() async throws {
        let (client, _) = makeClient(scripts: [[
            subscribedAck,
            #"{"type":"trace_invalidated","trace_external_hash_norm":"Q0NDQ0NDQ0NDQ0NDQ0NDQ0NDQ0NDQ0NDQ0NDQ0NDQ0M="}"#,
            balanceFrame(),
        ]])
        let stream = await client.events(for: [wallet])
        let events = await collect(stream)

        guard case .balance = try await require(events) else {
            return XCTFail("an invalidation for an unseen trace was delivered")
        }
        await client.stop()
    }

    // MARK: - Subscription wire format

    func testSubscribeFrameMatchesTheProtocol() async throws {
        let (client, recorder) = makeClient(scripts: [[subscribedAck, balanceFrame()]])
        let stream = await client.events(for: [wallet], types: [.accountState, .transactions])
        let events = await collect(stream)
        _ = await events.next()

        let frames = await recorder.subscribeFrames()
        let frame = try XCTUnwrap(frames.first)
        let json = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(frame.utf8)) as? [String: Any]
        )

        XCTAssertEqual(json["operation"] as? String, "subscribe")
        XCTAssertEqual(json["min_finality"] as? String, "pending")
        XCTAssertEqual(json["include_metadata"] as? Bool, true)
        XCTAssertEqual(json["addresses"] as? [String], [wallet.rawString])
        XCTAssertEqual(
            (json["types"] as? [String]).map(Set.init),
            ["account_state_change", "transactions"],
            "the wire names are the protocol's, not our enum's Swift names"
        )
        await client.stop()
    }

    // MARK: - Reconnect

    /// A dropped connection must be retried and the subscription re-sent.
    ///
    /// The server replaces the whole subscription per `subscribe`, so a reconnect that forgot to
    /// resubscribe would hold an open socket that never delivers anything — the worst failure
    /// shape, because it looks healthy.
    func testReconnectResubscribes() async throws {
        let (client, recorder) = makeClient(scripts: [
            [subscribedAck, balanceFrame(balance: "1"), ScriptedSocket.dropMarker],
            [subscribedAck, balanceFrame(balance: "2")],
        ])
        let stream = await client.events(for: [wallet])
        let events = await collect(stream)

        guard case .balance(let first) = try await require(events) else {
            return XCTFail("expected the first balance")
        }
        XCTAssertEqual(first.balance, 1)

        guard case .balance(let second) = try await require(events, timeout: 10) else {
            return XCTFail("nothing arrived after the reconnect")
        }
        XCTAssertEqual(second.balance, 2, "the second connection's frame was not delivered")

        let connects = await recorder.connects
        XCTAssertGreaterThanOrEqual(connects, 2, "the client did not reconnect")
        let subscribes = await recorder.subscribeFrames()
        XCTAssertGreaterThanOrEqual(
            subscribes.count, 2,
            "the subscription was not re-sent after reconnecting"
        )
        await client.stop()
    }

    /// The app must be able to tell the user the stream is down.
    func testConnectionChangesAreReported() async throws {
        let (client, _) = makeClient(scripts: [
            [subscribedAck, balanceFrame(), ScriptedSocket.dropMarker],
            [subscribedAck],
        ])
        let stream = await client.events(for: [wallet])
        let events = await collect(stream)

        let cycle = await events.sawConnectionCycle(timeout: 10)
        let sawConnected = cycle.up
        let sawDisconnected = cycle.down
        XCTAssertTrue(sawConnected, "never reported connecting")
        XCTAssertTrue(sawDisconnected, "never reported the drop")
        await client.stop()
    }

    // MARK: - Keepalive

    /// The server closes an idle socket at roughly thirty seconds, so the ping is not optional:
    /// without it the stream goes quiet and nothing reports a problem. Observed live — a probe
    /// that never pinged was closed with code 1006.
    func testPingsAreSent() async throws {
        let (client, recorder) = makeClient(
            scripts: [[subscribedAck, balanceFrame()]],
            pingInterval: 0.05
        )
        let stream = await client.events(for: [wallet])
        let events = await collect(stream)
        _ = await events.next()

        let pinged = await recorder.waitForSent(containing: "\"ping\"", timeout: 5)
        XCTAssertTrue(pinged, "no keepalive ping was sent")
        await client.stop()
    }

    // MARK: - Endpoint

    func testEndpointsAreCorrectPerNetwork() {
        let mainnet = ToncenterStreaming.endpoint(network: .mainnet, apiKey: nil)
        XCTAssertEqual(mainnet.absoluteString, "wss://toncenter.com/api/streaming/v2/ws")

        let testnet = ToncenterStreaming.endpoint(network: .testnet, apiKey: nil)
        XCTAssertEqual(testnet.absoluteString, "wss://testnet.toncenter.com/api/streaming/v2/ws")

        let keyed = ToncenterStreaming.endpoint(network: .testnet, apiKey: "abc+def")
        XCTAssertTrue(keyed.absoluteString.contains("api_key=abc%2Bdef"), keyed.absoluteString)
    }
}
