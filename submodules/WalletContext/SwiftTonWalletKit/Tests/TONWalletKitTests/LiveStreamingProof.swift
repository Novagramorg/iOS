import XCTest
import TONCore
import TONCrypto
import TONToncenter
import TONConnect
@testable import TONWalletKit

/// Streams from the real Toncenter endpoint while sending a real transfer.
///
/// The scripted-socket tests prove the client's own logic against captured frames. What only
/// the live endpoint can show is whether the subscription is accepted, whether events actually
/// arrive for a watched account, and whether the keepalive holds the socket open — a probe that
/// never pinged was closed with code 1006 after about thirty seconds.
///
/// The transfer is sent through the kit's own send API, so this also ties the two halves
/// together: money leaves via `sendTON` and comes back as a `StreamEvent`.
///
/// Gated behind `RUN_LIVE_STREAMING=1`.
final class LiveStreamingProofTests: XCTestCase {
    struct WalletFile: Decodable {
        let mnemonic: String
        let globalId: Int32
    }

    private var isEnabled: Bool {
        ProcessInfo.processInfo.environment["RUN_LIVE_STREAMING"] == "1"
    }

    private var apiKey: String? {
        ProcessInfo.processInfo.environment["TONCENTER_KEY"]
    }

    /// Buffers events so a test can await with a deadline instead of hanging.
    actor Collector {
        private var events: [StreamEvent] = []
        private var pump: Task<Void, Never>?

        func start(_ stream: AsyncStream<StreamEvent>) {
            pump = Task { [weak self] in
                for await event in stream { await self?.append(event) }
            }
        }
        deinit { pump?.cancel() }
        private func append(_ event: StreamEvent) { events.append(event) }
        func stop() { pump?.cancel(); pump = nil }

        /// Waits for an event matching `predicate`, ignoring the rest.
        func waitFor(
            timeout: TimeInterval,
            _ predicate: @Sendable (StreamEvent) -> Bool
        ) async -> StreamEvent? {
            let deadline = Date().addingTimeInterval(timeout)
            var index = 0
            while Date() < deadline {
                while index < events.count {
                    let event = events[index]
                    index += 1
                    if predicate(event) { return event }
                }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            return nil
        }

        func count() -> Int { events.count }
    }

    private func setUp() async throws -> (TonWalletKit, Wallet, Wallet) {
        let path = ProcessInfo.processInfo.environment["TESTNET_WALLET_FILE"]
            ?? "\(FileManager.default.currentDirectoryPath)/.testnet-wallet.json"
        let file = try JSONDecoder().decode(
            WalletFile.self, from: try Data(contentsOf: URL(fileURLWithPath: path))
        )
        let client = ToncenterClient(network: .testnet, apiKey: apiKey, timeout: 60)
        let kit = TonWalletKit(
            configuration: WalletKitConfiguration(
                deviceInfo: DeviceInfo(
                    platform: "iphone", appName: "LiveStreamingProof", appVersion: "1.0",
                    maxProtocolVersion: 2, features: []
                ),
                emulateBeforeApproval: false
            ),
            storage: InMemoryStorage(),
            clients: [.testnet: client],
            streamingAPIKey: apiKey
        )
        let signer = try InMemorySigner(mnemonic: file.mnemonic.split(separator: " ").map(String.init))
        let v5 = try Wallet(v5r1: signer, network: .testnet)
        let v4 = try Wallet(v4r2: signer, network: .testnet)
        await kit.register(wallet: v5)
        await kit.register(wallet: v4)
        return (kit, v5, v4)
    }

    /// A transfer sent through the kit must come back on the stream.
    func testTransferArrivesOnTheStream() async throws {
        try XCTSkipUnless(isEnabled, "set RUN_LIVE_STREAMING=1 to run the live streaming proof")

        let (kit, v5, v4) = try await setUp()
        let collector = Collector()
        await collector.start(try await kit.updates(for: v5.id))

        // The subscription is established asynchronously; wait for the connection notice so the
        // transfer is not sent before anyone is listening.
        let connected = await collector.waitFor(timeout: 30) { event in
            if case .connectionChanged(let up) = event { return up }
            return false
        }
        XCTAssertNotNil(connected, "the stream never reported connecting")
        print("STREAM  connected")

        let sent = try await kit.sendTON(
            from: v5.id,
            to: v4.address.toString(),
            amount: BigUInt(12_000_000),
            comment: "streaming proof"
        )
        print("STREAM  sent \(sent.normalizedHash)")

        // Matched on the trace hash, not merely "some transactions event for this wallet":
        // `trace_external_hash_norm` is the normalized external hash the send returned, so this
        // proves the stream delivered *this* transfer rather than unrelated traffic that would
        // make the test pass for the wrong reason.
        let expectedTrace = sent.normalizedHash
        let transactionEvent = await collector.waitFor(timeout: 90) { event in
            if case .transactions(let update) = event {
                return update.address == v5.address && update.traceHash == expectedTrace
            }
            return false
        }
        let event = try XCTUnwrap(
            transactionEvent,
            "the stream never delivered the trace \(expectedTrace) we just sent"
        )
        guard case .transactions(let update) = event else { return XCTFail("wrong event kind") }
        print("STREAM  ✓ our trace arrived, finality \(update.finality), \(update.transactions.count) tx")
        XCTAssertEqual(update.traceHash, expectedTrace)
        XCTAssertFalse(update.transactions.isEmpty, "the trace carried no transactions")
        XCTAssertFalse(update.isInvalidated)

        // And the balance change for the same wallet.
        let balanceEvent = await collector.waitFor(timeout: 90) { event in
            if case .balance(let update) = event { return update.address == v5.address }
            return false
        }
        if case .balance(let balance)? = balanceEvent {
            print("STREAM  ✓ balance event, \(balance.balance) at \(balance.finality)")
            XCTAssertGreaterThan(balance.balance, 0)
        } else {
            // Not fatal on its own: the transactions event already proves delivery, and the
            // account-state frame can lag. Saying so beats asserting a flake.
            print("STREAM  ! no balance event within the window; transactions already confirmed delivery")
        }

        await collector.stop()
        await kit.stopStreaming()
    }

    /// The socket must survive longer than the server's idle timeout.
    ///
    /// A probe without a keepalive was closed with 1006 at about thirty seconds. This watches an
    /// idle wallet for longer than that and asserts no disconnect was reported — if the ping
    /// stopped working, the stream would quietly go dead in production and nothing would say so.
    func testConnectionSurvivesTheIdleTimeout() async throws {
        try XCTSkipUnless(isEnabled, "set RUN_LIVE_STREAMING=1 to run the live streaming proof")

        let (kit, _, v4) = try await setUp()
        let collector = Collector()
        // The V4R2 wallet is quiet, so nothing but keepalive traffic should occur.
        await collector.start(try await kit.updates(for: v4.id))

        let connected = await collector.waitFor(timeout: 30) { event in
            if case .connectionChanged(let up) = event { return up }
            return false
        }
        XCTAssertNotNil(connected, "never connected")
        print("STREAM  connected; holding for 45s to outlast the ~30s idle timeout")

        let dropped = await collector.waitFor(timeout: 45) { event in
            if case .connectionChanged(let up) = event { return !up }
            return false
        }
        // Reported before asserting: `XCTAssert` records a failure without stopping, so an
        // unconditional success line would print underneath a failure and contradict it.
        if dropped == nil {
            print("STREAM  ✓ still connected after 45s idle")
        } else {
            print("STREAM  ✗ dropped before 45s — the keepalive is not holding the socket open")
        }
        XCTAssertNil(dropped, "the connection dropped despite the keepalive")

        await collector.stop()
        await kit.stopStreaming()
    }
}
