import XCTest
import TONCore
import TONCrypto
import TONToncenter
import TONConnect
@testable import TONWalletKit

/// Drives the kit against a **real** TON Connect bridge.
///
/// The `URLProtocol` stub in ``TonWalletKitTests`` proves the kit's own logic, but it answers
/// instantly, never drops a connection, and never holds a message for a client that is not
/// listening. Everything that only real infrastructure does is therefore untested by it:
///
/// - a genuine long-lived SSE connection, with the bridge's own framing and keep-alives
/// - end-to-end delivery latency, which is where a race in the subscribe path would show
/// - **resume after downtime** — the bridge buffers messages for an absent client and replays
///   them from `Last-Event-ID`. ``BridgeCursorStore`` exists entirely for this, and nothing
///   else exercises it.
///
/// No third-party dApp is needed: the bridge only routes sealed envelopes between client ids,
/// so this test plays the dApp side too, using ``BridgeClient`` in the other direction.
///
/// Gated behind `RUN_LIVE_BRIDGE=1`. Talks to the public bridge, so it is inherently slower and
/// more fragile than the rest of the suite and never runs by default.
final class LiveBridgeProofTests: XCTestCase {
    /// The public TON Connect bridge. Overridable to point at a self-hosted one.
    private var bridgeURL: String {
        ProcessInfo.processInfo.environment["TONCONNECT_BRIDGE"]
            ?? "https://bridge.tonapi.io/bridge"
    }

    private var isEnabled: Bool {
        ProcessInfo.processInfo.environment["RUN_LIVE_BRIDGE"] == "1"
    }

    private let mnemonic = """
    dose ice enrich trigger test dove century still betray gas diet dune \
    use other base gym mad law immense village world example praise game
    """.split(separator: " ").map(String.init)

    struct Refused: Error, CustomStringConvertible {
        let reason: String
        var description: String { reason }
    }

    /// Buffers what the dApp receives from the bridge, so a test can await with a deadline
    /// rather than block forever when nothing arrives.
    actor InboxCollector {
        private var messages: [BridgeMessage] = []
        private var pump: Task<Void, Never>?

        func start(client: BridgeClient) {
            pump = Task { [weak self] in
                do {
                    for try await message in client.messages() {
                        await self?.append(message)
                    }
                } catch {
                    // The stream only ends on close or cancellation; nothing to report.
                }
            }
        }

        func stop() { pump?.cancel(); pump = nil }
        private func append(_ message: BridgeMessage) { messages.append(message) }

        /// The next buffered message, or nil once the deadline passes.
        func next(timeout: TimeInterval) async -> BridgeMessage? {
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline {
                if !messages.isEmpty { return messages.removeFirst() }
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
            return messages.isEmpty ? nil : messages.removeFirst()
        }
    }

    private func makeKit(
        storage: any WalletKitStorage,
        clients: [Network: any ApiClient]
    ) -> TonWalletKit {
        TonWalletKit(
            configuration: WalletKitConfiguration(
                deviceInfo: DeviceInfo(
                    platform: "iphone",
                    appName: "TONWalletKit-LiveBridgeProof",
                    appVersion: "1.0",
                    maxProtocolVersion: 2,
                    features: []
                ),
                defaultBridgeURL: URL(string: bridgeURL)!,
                // The point here is transport, not previews; emulation would add network
                // dependencies unrelated to what is being proven.
                emulateBeforeApproval: false
            ),
            storage: storage,
            clients: clients,
            manifests: StubManifestFetcher.serving(domain: "dapp.example.com"),
            urlSession: .shared
        )
    }

    private func transactionRequest(id: String) -> String {
        let params = #"{\"messages\":[{\"address\":\"0:0000000000000000000000000000000000000000000000000000000000000000\",\"amount\":\"1\"}]}"#
        return #"{"id":"\#(id)","method":"sendTransaction","params":["\#(params)"]}"#
    }

    func testLiveBridgeRoundTripAndResume() async throws {
        try XCTSkipUnless(isEnabled, "set RUN_LIVE_BRIDGE=1 to run the live bridge proof")

        let storage = InMemoryStorage()
        let client = StubApiClient()
        let kit = makeKit(storage: storage, clients: [.testnet: client])
        let wallet = try Wallet(v5r1: InMemorySigner(mnemonic: mnemonic), network: .testnet)
        await kit.register(wallet: wallet)

        let dApp = try FakeDApp()

        // The dApp listens first. The bridge holds messages for an absent client, but starting
        // early keeps the happy path from depending on that.
        let dAppClient = BridgeClient(
            bridgeURL: URL(string: bridgeURL)!,
            clientID: dApp.clientID,
            session: .shared
        )
        let inbox = InboxCollector()
        await inbox.start(client: dAppClient)
        defer { dAppClient.close() }

        let events = await EventCollector(kit: kit)

        // ── 1. Connect over the real bridge ────────────────────────────────────────
        print("LIVE 1  bridge: \(bridgeURL)")
        let connect = try await kit.handle(
            url: dApp.connectLink(bridge: bridgeURL, items: #"{"name":"ton_addr"}"#)
        )
        // `handle(url:)` emits the request as well as returning it, so that event is drained
        // here — both to assert it happened and so the buffer holds only bridge traffic below.
        let announcedDelivery = await events.next(timeout: 5)
        let announced = try XCTUnwrap(announcedDelivery, "handle(url:) must emit the request")
        guard case .connectionRequest(let announcedRequest) = announced else {
            return XCTFail("expected a connectionRequest event, got \(announced)")
        }
        XCTAssertEqual(announcedRequest.clientID, connect.clientID)

        try await kit.approve(connect, with: wallet)

        let sessions = await kit.activeSessions()
        let session = try XCTUnwrap(sessions.first)
        print("LIVE 1  session established, wallet key \(session.sessionPublicKey.prefix(16))…")

        // The dApp must actually receive the connect reply through the bridge.
        let connectDelivery = await inbox.next(timeout: 30)
        let connectReply = try XCTUnwrap(
            connectDelivery,
            "the dApp never received the connect reply over the live bridge"
        )
        let connectJSON = try dApp.open(connectReply.message, from: session.sessionPublicKey)
        XCTAssertTrue(connectJSON.contains("\"event\":\"connect\""), connectJSON.prefix(200).description)
        print("LIVE 1  ✓ dApp received the connect reply")

        // ── 2. dApp → wallet, live ─────────────────────────────────────────────────
        try await dAppClient.send(
            try dApp.seal(transactionRequest(id: "live-1"), to: session.sessionPublicKey),
            to: session.sessionPublicKey
        )
        print("LIVE 2  sent request live-1")

        let firstDelivery = await events.next(timeout: 45)
        let firstEvent = try XCTUnwrap(
            firstDelivery,
            "the kit never received the request over the live bridge"
        )
        guard case .sendTransactionRequest(let request) = firstEvent else {
            return XCTFail("expected a sendTransaction event, got \(firstEvent)")
        }
        XCTAssertEqual(request.id, "live-1")
        print("LIVE 2  ✓ kit received live-1 over real SSE")

        // ── 3. wallet → dApp, live ─────────────────────────────────────────────────
        try await kit.reject(request, reason: "live bridge proof")
        let rejectionDelivery = await inbox.next(timeout: 30)
        let rejection = try XCTUnwrap(
            rejectionDelivery,
            "the dApp never received the rejection"
        )
        let rejectionJSON = try dApp.open(rejection.message, from: session.sessionPublicKey)
        XCTAssertTrue(rejectionJSON.contains("live bridge proof"), rejectionJSON.prefix(200).description)
        XCTAssertTrue(rejectionJSON.contains("\"id\":\"live-1\""), "the reply must echo the dApp's id")
        print("LIVE 3  ✓ dApp received the rejection")

        // ── 4. Resume: a message sent while the wallet is offline ──────────────────
        // This is what ``BridgeCursorStore`` exists for. Without a persisted Last-Event-ID the
        // reconnect either misses this message or replays the whole backlog.
        await kit.stop()
        print("LIVE 4  wallet disconnected")
        // Give the bridge a moment to notice the connection is gone, so the next message is
        // genuinely buffered rather than delivered to a socket still being torn down.
        try? await Task.sleep(nanoseconds: 3_000_000_000)

        try await dAppClient.send(
            try dApp.seal(transactionRequest(id: "offline-1"), to: session.sessionPublicKey),
            to: session.sessionPublicKey
        )
        print("LIVE 4  sent offline-1 while the wallet was disconnected")
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        // A fresh kit over the *same* storage: sessions and the bridge cursor are reloaded
        // exactly as they would be after an app restart.
        let restarted = makeKit(storage: storage, clients: [.testnet: client])
        await restarted.register(wallet: wallet)
        let restartedEvents = await EventCollector(kit: restarted)
        defer { Task { await restarted.stop() } }

        let restoredSessions = await restarted.activeSessions()
        XCTAssertEqual(restoredSessions.count, 1, "the session must survive the restart")
        XCTAssertEqual(restoredSessions.first?.id, session.id)
        print("LIVE 5  restarted with \(restoredSessions.count) restored session(s)")

        let resumedDelivery = await restartedEvents.next(timeout: 60)
        let resumed = try XCTUnwrap(
            resumedDelivery,
            "the message sent while offline was never delivered after reconnect"
        )
        guard case .sendTransactionRequest(let offlineRequest) = resumed else {
            return XCTFail("expected a sendTransaction event, got \(resumed)")
        }
        XCTAssertEqual(
            offlineRequest.id, "offline-1",
            "the resumed message must be the one sent during downtime"
        )
        print("LIVE 5  ✓ offline-1 delivered after reconnect — the resume path works")

        // The durable store must hold it too, or an app killed before the user answers loses
        // a request the dApp is still waiting on.
        let stored = await restarted.eventStore.event(id: "offline-1")
        XCTAssertNotNil(stored, "the resumed request must be persisted")

        print("""
        LIVE    ── summary ─────────────────────────────────────────────
        LIVE    live connect reply .... ✓
        LIVE    live dApp → wallet .... ✓
        LIVE    live wallet → dApp .... ✓
        LIVE    resume after downtime . ✓
        LIVE    ────────────────────────────────────────────────────────
        """)
    }
}
