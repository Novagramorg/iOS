import XCTest
import TONCore
import TONCrypto
import TONContracts
import TONToncenter
import TONConnect
@testable import TONWalletKit

/// End-to-end tests: a fake dApp drives the kit through a stubbed bridge.
///
/// These are the tests that matter most, because every layer below is already covered in
/// isolation. What is only checkable here is whether the pieces are wired to each other
/// correctly — a request that decrypts, parses, and signs perfectly is still broken if the
/// reply goes to the wrong bridge or carries the wrong id.
final class TonWalletKitTests: XCTestCase {
    private let bridge = "https://bridge.example.com/bridge"
    private let mnemonic = """
    dose ice enrich trigger test dove century still betray gas diet dune \
    use other base gym mad law immense village world example praise game
    """.split(separator: " ").map(String.init)

    private var clock: Int64 = 1_700_000_000_000

    override func tearDown() {
        FakeBridgeProtocol.reset()
        super.tearDown()
    }

    /// Reads the next emitted event, failing rather than hanging if none arrives.
    private func nextEvent(_ collector: EventCollector) async throws -> WalletKitEvent {
        let event = await collector.next()
        return try XCTUnwrap(event, "no event was emitted within the timeout")
    }

    // MARK: - Setup helpers

    private func makeKit(
        client: StubApiClient,
        manifests: any ManifestFetching = StubManifestFetcher.serving(domain: "dapp.example.com"),
        configuration: WalletKitConfiguration? = nil
    ) -> TonWalletKit {
        let millis = clock
        return TonWalletKit(
            configuration: configuration ?? WalletKitConfiguration(
                deviceInfo: DeviceInfo(
                    platform: "iphone",
                    appName: "TestWallet",
                    appVersion: "1.0",
                    maxProtocolVersion: 2,
                    features: []
                ),
                defaultBridgeURL: URL(string: bridge)!,
                // Off by default in these tests: emulation needs a scripted result, and most
                // of what is under test here is unrelated to previews.
                emulateBeforeApproval: false
            ),
            storage: InMemoryStorage(),
            clients: [.testnet: client],
            manifests: manifests,
            urlSession: FakeBridgeProtocol.session(),
            now: { millis }
        )
    }

    private func makeWallet() throws -> Wallet {
        try Wallet(
            v5r1: InMemorySigner(mnemonic: mnemonic),
            network: .testnet
        )
    }

    /// Answers bridge POSTs with 200 and holds SSE connections open with no events.
    ///
    /// An SSE handler that returned immediately would make the client reconnect in a tight
    /// loop and flood the recorded requests, drowning the assertions.
    private func acceptEverything() {
        FakeBridgeProtocol.handler = { request in
            if request.url?.path.hasSuffix("/message") == true {
                return (200, Data(#"{"statusCode":200,"ok":true}"#.utf8), ["Content-Type": "application/json"])
            }
            return (200, Data(), ["Content-Type": "text/event-stream"])
        }
    }

    /// The sealed payloads the kit posted to the bridge, in order.
    private func sentEnvelopes() -> [String] {
        FakeBridgeProtocol.recorded()
            .filter { $0.url.path.hasSuffix("/message") }
            .compactMap { $0.body.flatMap { String(data: $0, encoding: .utf8) } }
    }

    // MARK: - Connect

    func testHandleConnectLinkProducesARequest() async throws {
        acceptEverything()
        let kit = makeKit(client: StubApiClient())
        let dApp = try FakeDApp()

        let request = try await kit.handle(
            url: dApp.connectLink(bridge: bridge, items: #"{"name":"ton_addr"}"#)
        )

        XCTAssertEqual(request.clientID, dApp.clientID)
        XCTAssertEqual(request.requestedItems, [.address])
        XCTAssertFalse(request.requestsProof)
        XCTAssertEqual(request.dApp.name, "Test dApp")
        XCTAssertEqual(request.dApp.domain, "dapp.example.com")
        XCTAssertTrue(request.dApp.isVerified)
        XCTAssertEqual(request.returnStrategy, "back")
    }

    /// A dApp whose manifest cannot be fetched must still reach the user — as unverified.
    /// Silently dropping it would make a transient network failure look like the dApp never
    /// asked.
    func testUnfetchableManifestYieldsAnUnverifiedRequest() async throws {
        acceptEverything()
        let kit = makeKit(client: StubApiClient(), manifests: StubManifestFetcher.failing())
        let dApp = try FakeDApp()

        let request = try await kit.handle(
            url: dApp.connectLink(bridge: bridge, items: #"{"name":"ton_addr"}"#)
        )
        XCTAssertFalse(request.dApp.isVerified)
        XCTAssertNil(request.dApp.domain)
        XCTAssertNotNil(request.dApp.manifestFailure)
    }

    func testApprovingConnectCreatesASessionAndRepliesWithTheAddress() async throws {
        acceptEverything()
        let kit = makeKit(client: StubApiClient())
        let wallet = try makeWallet()
        await kit.register(wallet: wallet)
        let dApp = try FakeDApp()

        let request = try await kit.handle(
            url: dApp.connectLink(bridge: bridge, items: #"{"name":"ton_addr"}"#)
        )
        try await kit.approve(request, with: wallet)

        let sessions = await kit.activeSessions()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].id, dApp.clientID)
        XCTAssertEqual(sessions[0].walletID, wallet.id)
        XCTAssertEqual(sessions[0].bridgeURL, bridge)

        // The dApp must be able to open the reply with the key the kit gave it.
        let envelope = try XCTUnwrap(sentEnvelopes().last)
        let plaintext = try dApp.open(envelope, from: sessions[0].sessionPublicKey)
        let json = try JSONSerialization.jsonObject(with: Data(plaintext.utf8)) as? [String: Any]

        XCTAssertEqual(json?["event"] as? String, "connect")
        let payload = json?["payload"] as? [String: Any]
        let items = payload?["items"] as? [[String: Any]]
        XCTAssertEqual(items?.count, 1)
        XCTAssertEqual(items?[0]["name"] as? String, "ton_addr")
        // Raw form, not friendly — a dApp verifying the state init against a friendly
        // address fails.
        XCTAssertEqual(items?[0]["address"] as? String, wallet.address.rawString)
        XCTAssertEqual(items?[0]["network"] as? String, "-3")
        XCTAssertEqual(items?[0]["publicKey"] as? String, wallet.publicKey.hexString)
    }

    /// Features come from the contract, not the app: V5R1 reaches 255 messages while V4R2
    /// caps at 4. Advertising the wrong number makes a dApp build a batch the wallet refuses.
    func testAdvertisedFeaturesComeFromTheWalletContract() async throws {
        acceptEverything()
        let kit = makeKit(client: StubApiClient())
        let v4 = try Wallet(v4r2: InMemorySigner(mnemonic: mnemonic), network: .testnet)
        await kit.register(wallet: v4)
        let dApp = try FakeDApp()

        let request = try await kit.handle(
            url: dApp.connectLink(bridge: bridge, items: #"{"name":"ton_addr"}"#)
        )
        try await kit.approve(request, with: v4)

        let sessions = await kit.activeSessions()
        let envelope = try XCTUnwrap(sentEnvelopes().last)
        let plaintext = try dApp.open(envelope, from: sessions[0].sessionPublicKey)
        let json = try JSONSerialization.jsonObject(with: Data(plaintext.utf8)) as? [String: Any]
        let device = (json?["payload"] as? [String: Any])?["device"] as? [String: Any]
        let features = device?["features"] as? [[String: Any]]

        let sendTransaction = features?.first { $0["name"] as? String == "SendTransaction" }
        XCTAssertEqual(sendTransaction?["maxMessages"] as? Int, 4, "V4R2 caps at 4 message refs")
    }

    func testApprovingConnectWithProofSignsTheManifestDomain() async throws {
        acceptEverything()
        let kit = makeKit(client: StubApiClient())
        let wallet = try makeWallet()
        await kit.register(wallet: wallet)
        let dApp = try FakeDApp()

        let request = try await kit.handle(
            url: dApp.connectLink(
                bridge: bridge,
                items: #"{"name":"ton_addr"},{"name":"ton_proof","payload":"nonce-123"}"#
            )
        )
        XCTAssertTrue(request.requestsProof)
        XCTAssertEqual(request.proofPayload, "nonce-123")

        try await kit.approve(request, with: wallet)

        let sessions = await kit.activeSessions()
        let plaintext = try dApp.open(
            try XCTUnwrap(sentEnvelopes().last),
            from: sessions[0].sessionPublicKey
        )
        let json = try JSONSerialization.jsonObject(with: Data(plaintext.utf8)) as? [String: Any]
        let items = (json?["payload"] as? [String: Any])?["items"] as? [[String: Any]]
        let proofItem = try XCTUnwrap(items?.first { $0["name"] as? String == "ton_proof" })
        let proof = try XCTUnwrap(proofItem["proof"] as? [String: Any])

        XCTAssertEqual(proof["payload"] as? String, "nonce-123")
        let domain = try XCTUnwrap(proof["domain"] as? [String: Any])
        XCTAssertEqual(domain["value"] as? String, "dapp.example.com")
        XCTAssertEqual(domain["lengthBytes"] as? Int, "dapp.example.com".utf8.count)

        // And the signature must actually verify over the message the dApp would rebuild.
        let signature = try XCTUnwrap(Data(base64Encoded: try XCTUnwrap(proof["signature"] as? String)))
        let message = TonProof.Message(
            address: wallet.address,
            domain: TonProof.Domain(value: "dapp.example.com"),
            timestamp: UInt64(try XCTUnwrap(proof["timestamp"] as? Int)),
            payload: "nonce-123"
        )
        XCTAssertTrue(
            try Ed25519.verify(
                signature: signature,
                data: TonProof.messageBytes(message),
                publicKey: wallet.publicKey
            ),
            "the proof must verify against the wallet's public key"
        )
    }

    /// A proof binds to a domain. With no verified manifest there is no domain, so the kit
    /// must refuse rather than sign over an empty one.
    func testProofWithoutAVerifiedDomainIsRefused() async throws {
        acceptEverything()
        let kit = makeKit(client: StubApiClient(), manifests: StubManifestFetcher.failing())
        let wallet = try makeWallet()
        await kit.register(wallet: wallet)
        let dApp = try FakeDApp()

        let request = try await kit.handle(
            url: dApp.connectLink(bridge: bridge, items: #"{"name":"ton_proof","payload":"n"}"#)
        )

        do {
            try await kit.approve(request, with: wallet)
            XCTFail("expected a refusal")
        } catch let error as WalletKitError {
            guard case .manifestInvalid = error else {
                return XCTFail("expected manifestInvalid, got \(error)")
            }
        }
        let count = await kit.activeSessions().count
        XCTAssertEqual(count, 0, "no session may be created when the proof cannot be produced")
    }

    /// An address-only connect works fine without a manifest: nothing is being signed, so
    /// there is no domain to bind. Refusing it would break dApps whose manifest host is
    /// briefly unreachable.
    func testAddressOnlyConnectWorksWithoutAVerifiedManifest() async throws {
        acceptEverything()
        let kit = makeKit(client: StubApiClient(), manifests: StubManifestFetcher.failing())
        let wallet = try makeWallet()
        await kit.register(wallet: wallet)
        let dApp = try FakeDApp()

        let request = try await kit.handle(
            url: dApp.connectLink(bridge: bridge, items: #"{"name":"ton_addr"}"#)
        )
        try await kit.approve(request, with: wallet)

        let count = await kit.activeSessions().count
        XCTAssertEqual(count, 1)
    }

    func testRejectingConnectSendsAnErrorAndCreatesNoSession() async throws {
        acceptEverything()
        let kit = makeKit(client: StubApiClient())
        let wallet = try makeWallet()
        await kit.register(wallet: wallet)
        let dApp = try FakeDApp()

        let request = try await kit.handle(
            url: dApp.connectLink(bridge: bridge, items: #"{"name":"ton_addr"}"#)
        )
        try await kit.reject(request, reason: "Not today")

        let count = await kit.activeSessions().count
        XCTAssertEqual(count, 0)

        // The dApp cannot know our key yet, so the rejection is sealed with an ephemeral one.
        // It is still openable, because the envelope carries the sender's nonce.
        let envelope = try XCTUnwrap(sentEnvelopes().last)
        let ephemeralSender = try XCTUnwrap(
            FakeBridgeProtocol.recorded()
                .last { $0.url.path.hasSuffix("/message") }
                .flatMap { URLComponents(url: $0.url, resolvingAgainstBaseURL: false) }
                .flatMap { $0.queryItems?.first { $0.name == "client_id" }?.value }
        )
        let plaintext = try dApp.open(envelope, from: ephemeralSender)
        let json = try JSONSerialization.jsonObject(with: Data(plaintext.utf8)) as? [String: Any]
        XCTAssertEqual(json?["event"] as? String, "connect_error")
        let payload = json?["payload"] as? [String: Any]
        XCTAssertEqual(payload?["code"] as? Int, ConnectEventErrorCode.userRejects.rawValue)
        XCTAssertEqual(payload?["message"] as? String, "Not today")
    }

    func testConnectingWithAnUnregisteredWalletIsRefused() async throws {
        acceptEverything()
        let kit = makeKit(client: StubApiClient())
        let wallet = try makeWallet()
        // Deliberately not registered.
        let dApp = try FakeDApp()

        let request = try await kit.handle(
            url: dApp.connectLink(bridge: bridge, items: #"{"name":"ton_addr"}"#)
        )
        do {
            try await kit.approve(request, with: wallet)
            XCTFail("expected a refusal")
        } catch let error as WalletKitError {
            guard case .walletNotFound = error else {
                return XCTFail("expected walletNotFound, got \(error)")
            }
        }
    }

    // MARK: - Inbound requests

    /// Establishes a connected session, then feeds the kit a sealed request as the dApp would.
    private func connected(
        client: StubApiClient,
        configuration: WalletKitConfiguration? = nil
    ) async throws -> (kit: TonWalletKit, wallet: Wallet, dApp: FakeDApp, session: TONConnectSession) {
        acceptEverything()
        let kit = makeKit(client: client, configuration: configuration)
        let wallet = try makeWallet()
        await kit.register(wallet: wallet)
        let dApp = try FakeDApp()
        let request = try await kit.handle(
            url: dApp.connectLink(bridge: bridge, items: #"{"name":"ton_addr"}"#)
        )
        try await kit.approve(request, with: wallet)
        let sessions = await kit.activeSessions()
        let session = try XCTUnwrap(sessions.first)
        return (kit, wallet, dApp, session)
    }

    private func deliver(
        _ json: String,
        from dApp: FakeDApp,
        to kit: TonWalletKit,
        session: TONConnectSession
    ) async throws {
        let sealed = try dApp.seal(json, to: session.sessionPublicKey)
        await kit.ingest(BridgeMessage(from: session.id, message: sealed, eventID: "1"))
    }

    private let destination = "0:83dfd552e63729b472fcbcc8c45ebcc6691702558b68ec7527e1ba403a0f31a8"

    func testSendTransactionIsSignedBroadcastAndAcknowledged() async throws {
        let client = StubApiClient(seqno: 7)
        let (kit, _, dApp, session) = try await connected(client: client)

        let events = await EventCollector(kit: kit)
        let params = #"{\"messages\":[{\"address\":\"\#(destination)\",\"amount\":\"1000000000\"}]}"#
        try await deliver(
            #"{"id":"99","method":"sendTransaction","params":["\#(params)"]}"#,
            from: dApp, to: kit, session: session
        )

        guard case .sendTransactionRequest(let request) = try await nextEvent(events) else {
            return XCTFail("expected a sendTransaction event")
        }
        XCTAssertEqual(request.id, "99")
        XCTAssertEqual(request.messages.count, 1)
        XCTAssertEqual(request.messages[0].amount, 1_000_000_000)

        let boc = try await kit.approve(request)

        let sent = await client.sentBocs
        XCTAssertEqual(sent, [boc], "the exact signed BoC must reach the network, once")

        // The dApp's reply must carry its own id and the same BoC.
        let plaintext = try dApp.open(try XCTUnwrap(sentEnvelopes().last), from: session.sessionPublicKey)
        let json = try JSONSerialization.jsonObject(with: Data(plaintext.utf8)) as? [String: Any]
        XCTAssertEqual(json?["id"] as? String, "99")
        XCTAssertEqual(json?["result"] as? String, boc)
    }

    /// Approving the same request twice must not sign it twice — the second attempt loses the
    /// claim. Without this, a double tap on the confirmation sheet sends two transfers.
    func testDoubleApprovalIsRefused() async throws {
        let client = StubApiClient()
        let (kit, _, dApp, session) = try await connected(client: client)
        let events = await EventCollector(kit: kit)

        let params = #"{\"messages\":[{\"address\":\"\#(destination)\",\"amount\":\"1\"}]}"#
        try await deliver(
            #"{"id":"1","method":"sendTransaction","params":["\#(params)"]}"#,
            from: dApp, to: kit, session: session
        )
        guard case .sendTransactionRequest(let request) = try await nextEvent(events) else {
            return XCTFail("expected a sendTransaction event")
        }

        _ = try await kit.approve(request)
        do {
            _ = try await kit.approve(request)
            XCTFail("expected the second approval to be refused")
        } catch let error as WalletKitError {
            guard case .requestAlreadyHandled = error else {
                return XCTFail("expected requestAlreadyHandled, got \(error)")
            }
        }

        let sent = await client.sentBocs
        XCTAssertEqual(sent.count, 1, "only one transfer may be broadcast")
    }

    /// A failed broadcast must not be acknowledged as success, and must leave the request
    /// retryable rather than stuck.
    func testFailedBroadcastIsNotAcknowledged() async throws {
        let client = StubApiClient()
        await client.setSendShouldFail(true)
        let (kit, _, dApp, session) = try await connected(client: client)
        let events = await EventCollector(kit: kit)

        let envelopesBefore = sentEnvelopes().count
        let params = #"{\"messages\":[{\"address\":\"\#(destination)\",\"amount\":\"1\"}]}"#
        try await deliver(
            #"{"id":"1","method":"sendTransaction","params":["\#(params)"]}"#,
            from: dApp, to: kit, session: session
        )
        guard case .sendTransactionRequest(let request) = try await nextEvent(events) else {
            return XCTFail("expected a sendTransaction event")
        }

        do {
            _ = try await kit.approve(request)
            XCTFail("expected the approval to fail")
        } catch let error as WalletKitError {
            guard case .chainFailure = error else {
                return XCTFail("expected chainFailure, got \(error)")
            }
        }

        XCTAssertEqual(
            sentEnvelopes().count, envelopesBefore,
            "no success reply may be sent for a transfer that never left"
        )
        // Released, not completed — so it can be retried rather than lost.
        let storedEvent = await kit.eventStore.event(id: "1")
        let stored = try XCTUnwrap(storedEvent)
        XCTAssertEqual(stored.status, .new)
        XCTAssertEqual(stored.retryCount, 1)
    }

    /// `signMessage` must not broadcast. If it did, the dApp's own broadcast would then fail
    /// on a consumed seqno.
    func testSignMessageDoesNotBroadcast() async throws {
        let client = StubApiClient()
        let (kit, _, dApp, session) = try await connected(client: client)
        let events = await EventCollector(kit: kit)

        let params = #"{\"messages\":[{\"address\":\"\#(destination)\",\"amount\":\"1\"}]}"#
        try await deliver(
            #"{"id":"5","method":"signMessage","params":["\#(params)"]}"#,
            from: dApp, to: kit, session: session
        )
        guard case .signMessageRequest(let request) = try await nextEvent(events) else {
            return XCTFail("expected a signMessage event")
        }

        let boc = try await kit.approve(request)

        let sent = await client.sentBocs
        XCTAssertTrue(sent.isEmpty, "signMessage must never broadcast")

        let plaintext = try dApp.open(try XCTUnwrap(sentEnvelopes().last), from: session.sessionPublicKey)
        let json = try JSONSerialization.jsonObject(with: Data(plaintext.utf8)) as? [String: Any]
        XCTAssertEqual(json?["id"] as? String, "5")
        let result = json?["result"] as? [String: Any]
        XCTAssertEqual(result?["internalBoc"] as? String, boc)
    }

    func testSignDataIsSignedAndVerifiable() async throws {
        let client = StubApiClient()
        let (kit, wallet, dApp, session) = try await connected(client: client)
        let events = await EventCollector(kit: kit)

        let params = #"{\"type\":\"text\",\"text\":\"I agree\"}"#
        try await deliver(
            #"{"id":"11","method":"signData","params":["\#(params)"]}"#,
            from: dApp, to: kit, session: session
        )
        guard case .signDataRequest(let request) = try await nextEvent(events) else {
            return XCTFail("expected a signData event")
        }
        XCTAssertEqual(request.domain, "dapp.example.com")

        _ = try await kit.approve(request)

        let plaintext = try dApp.open(try XCTUnwrap(sentEnvelopes().last), from: session.sessionPublicKey)
        let json = try JSONSerialization.jsonObject(with: Data(plaintext.utf8)) as? [String: Any]
        let result = try XCTUnwrap(json?["result"] as? [String: Any])

        XCTAssertEqual(json?["id"] as? String, "11")
        XCTAssertEqual(result["domain"] as? String, "dapp.example.com")
        XCTAssertEqual(result["address"] as? String, wallet.address.rawString)

        let echo = try XCTUnwrap(result["payload"] as? [String: Any])
        XCTAssertEqual(echo["type"] as? String, "text")
        XCTAssertEqual(echo["text"] as? String, "I agree")

        // The dApp rebuilds the hash from what it received and checks the signature.
        let signature = try XCTUnwrap(Data(base64Encoded: try XCTUnwrap(result["signature"] as? String)))
        let hash = try SignData.hash(
            payload: .text("I agree"),
            address: wallet.address,
            domain: "dapp.example.com",
            timestamp: UInt64(try XCTUnwrap(result["timestamp"] as? Int))
        )
        XCTAssertTrue(
            try Ed25519.verify(signature: signature, data: hash, publicKey: wallet.publicKey)
        )
    }

    /// An expired request must be refused rather than signed. This is the check that the
    /// `valid_until` wire spelling exists to enable.
    func testExpiredTransactionIsRefused() async throws {
        let client = StubApiClient()
        let (kit, _, dApp, session) = try await connected(client: client)
        let events = await EventCollector(kit: kit)

        // One second before the kit's fixed clock.
        let expired = clock / 1000 - 1
        let params = #"{\"valid_until\":\#(expired),\"messages\":[{\"address\":\"\#(destination)\",\"amount\":\"1\"}]}"#
        try await deliver(
            #"{"id":"1","method":"sendTransaction","params":["\#(params)"]}"#,
            from: dApp, to: kit, session: session
        )
        guard case .sendTransactionRequest(let request) = try await nextEvent(events) else {
            return XCTFail("expected a sendTransaction event")
        }
        XCTAssertEqual(request.validUntil, UInt64(expired), "valid_until must have decoded")

        do {
            _ = try await kit.approve(request)
            XCTFail("expected a refusal")
        } catch let error as WalletKitError {
            guard case .requestExpired = error else {
                return XCTFail("expected requestExpired, got \(error)")
            }
        }
        let sent = await client.sentBocs
        XCTAssertTrue(sent.isEmpty)
    }

    func testRejectingATransactionRepliesWithTheUserRejectsCode() async throws {
        let client = StubApiClient()
        let (kit, _, dApp, session) = try await connected(client: client)
        let events = await EventCollector(kit: kit)

        let params = #"{\"messages\":[{\"address\":\"\#(destination)\",\"amount\":\"1\"}]}"#
        try await deliver(
            #"{"id":"77","method":"sendTransaction","params":["\#(params)"]}"#,
            from: dApp, to: kit, session: session
        )
        guard case .sendTransactionRequest(let request) = try await nextEvent(events) else {
            return XCTFail("expected a sendTransaction event")
        }

        try await kit.reject(request, reason: "No thanks")

        let plaintext = try dApp.open(try XCTUnwrap(sentEnvelopes().last), from: session.sessionPublicKey)
        let json = try JSONSerialization.jsonObject(with: Data(plaintext.utf8)) as? [String: Any]
        XCTAssertEqual(json?["id"] as? String, "77")
        let error = try XCTUnwrap(json?["error"] as? [String: Any])
        XCTAssertEqual(error["code"] as? Int, SendTransactionErrorCode.userRejects.rawValue)
        XCTAssertEqual(error["message"] as? String, "No thanks")

        let sent = await client.sentBocs
        XCTAssertTrue(sent.isEmpty)
    }

    /// A malformed request has to be answered, not ignored: the dApp is blocked on a reply.
    func testMalformedRequestIsRejectedBackToTheDApp() async throws {
        let client = StubApiClient()
        let (kit, _, dApp, session) = try await connected(client: client)
        let events = await EventCollector(kit: kit)

        try await deliver(
            #"{"id":"3","method":"sendTransaction","params":["{\"messages\":[]}"]}"#,
            from: dApp, to: kit, session: session
        )
        guard case .malformedRequest(let malformed) = try await nextEvent(events) else {
            return XCTFail("expected a malformedRequest event")
        }
        XCTAssertEqual(malformed.id, "3")

        let plaintext = try dApp.open(try XCTUnwrap(sentEnvelopes().last), from: session.sessionPublicKey)
        let json = try JSONSerialization.jsonObject(with: Data(plaintext.utf8)) as? [String: Any]
        XCTAssertEqual(json?["id"] as? String, "3")
        let error = try XCTUnwrap(json?["error"] as? [String: Any])
        XCTAssertEqual(error["code"] as? Int, SendTransactionErrorCode.badRequest.rawValue)
    }

    func testUnknownMethodGetsMethodNotSupported() async throws {
        let client = StubApiClient()
        let (kit, _, dApp, session) = try await connected(client: client)

        try await deliver(
            #"{"id":"4","method":"levitate","params":[]}"#,
            from: dApp, to: kit, session: session
        )

        let plaintext = try dApp.open(try XCTUnwrap(sentEnvelopes().last), from: session.sessionPublicKey)
        let json = try JSONSerialization.jsonObject(with: Data(plaintext.utf8)) as? [String: Any]
        let error = try XCTUnwrap(json?["error"] as? [String: Any])
        XCTAssertEqual(error["code"] as? Int, SendTransactionErrorCode.methodNotSupported.rawValue)
    }

    /// A message that will not decrypt must not take the session down — the next one might be
    /// fine, and a dApp that can wedge a wallet by sending garbage is a denial of service.
    func testUndecryptableMessageIsSurvivable() async throws {
        let client = StubApiClient()
        let (kit, _, dApp, session) = try await connected(client: client)
        let events = await EventCollector(kit: kit)

        await kit.ingest(BridgeMessage(from: session.id, message: "not-even-base64", eventID: "1"))

        guard case .malformedRequest = try await nextEvent(events) else {
            return XCTFail("expected a malformedRequest event")
        }

        // The session survives and the next request works.
        let params = #"{\"messages\":[{\"address\":\"\#(destination)\",\"amount\":\"1\"}]}"#
        try await deliver(
            #"{"id":"ok","method":"sendTransaction","params":["\#(params)"]}"#,
            from: dApp, to: kit, session: session
        )
        guard case .sendTransactionRequest(let request) = try await nextEvent(events) else {
            return XCTFail("expected a sendTransaction event after the bad one")
        }
        XCTAssertEqual(request.id, "ok")
    }

    // MARK: - Disconnect

    func testDAppInitiatedDisconnectRemovesTheSession() async throws {
        let client = StubApiClient()
        let (kit, _, dApp, session) = try await connected(client: client)
        let events = await EventCollector(kit: kit)

        try await deliver(
            #"{"id":"d1","method":"disconnect","params":[]}"#,
            from: dApp, to: kit, session: session
        )

        guard case .disconnected(let request) = try await nextEvent(events) else {
            return XCTFail("expected a disconnected event")
        }
        XCTAssertEqual(request.id, "d1")

        let count = await kit.activeSessions().count
        XCTAssertEqual(count, 0)
    }

    func testWalletInitiatedDisconnectNotifiesTheDApp() async throws {
        let client = StubApiClient()
        let (kit, _, dApp, session) = try await connected(client: client)

        try await kit.disconnect(sessionID: session.id)

        let count = await kit.activeSessions().count
        XCTAssertEqual(count, 0)

        let plaintext = try dApp.open(try XCTUnwrap(sentEnvelopes().last), from: session.sessionPublicKey)
        let json = try JSONSerialization.jsonObject(with: Data(plaintext.utf8)) as? [String: Any]
        XCTAssertEqual(json?["event"] as? String, "disconnect")
    }

    /// Forgetting a wallet must take its sessions with it, or the bridge keeps delivering
    /// requests nothing can sign.
    func testForgettingAWalletRemovesItsSessions() async throws {
        let client = StubApiClient()
        let (kit, wallet, _, _) = try await connected(client: client)

        await kit.forget(walletID: wallet.id)

        let count = await kit.activeSessions().count
        XCTAssertEqual(count, 0)
        let wallets = await kit.registeredWallets()
        XCTAssertTrue(wallets.isEmpty)
    }

    // MARK: - Persistence

    /// Requests are persisted before being surfaced, so an app killed while a confirmation
    /// sheet is up finds the request waiting rather than leaving the dApp unanswered.
    func testInboundRequestsArePersisted() async throws {
        let client = StubApiClient()
        let (kit, _, dApp, session) = try await connected(client: client)

        let params = #"{\"messages\":[{\"address\":\"\#(destination)\",\"amount\":\"1\"}]}"#
        try await deliver(
            #"{"id":"persisted","method":"sendTransaction","params":["\#(params)"]}"#,
            from: dApp, to: kit, session: session
        )

        let storedEvent = await kit.eventStore.event(id: "persisted")
        let stored = try XCTUnwrap(storedEvent)
        XCTAssertEqual(stored.status, .new)
        XCTAssertEqual(stored.eventType, .sendTransaction)
        XCTAssertEqual(stored.sessionID, session.id)
    }

    /// A bridge message that arrives twice — which happens on a reconnect without a resume
    /// point — must map to one request, not two confirmation sheets.
    func testDuplicateDeliveryProducesOneStoredRequest() async throws {
        let client = StubApiClient()
        let (kit, _, dApp, session) = try await connected(client: client)

        let params = #"{\"messages\":[{\"address\":\"\#(destination)\",\"amount\":\"1\"}]}"#
        let json = #"{"id":"dup","method":"sendTransaction","params":["\#(params)"]}"#
        try await deliver(json, from: dApp, to: kit, session: session)
        try await deliver(json, from: dApp, to: kit, session: session)

        let count = await kit.eventStore.count()
        XCTAssertEqual(count, 1)
    }

    // MARK: - Emulation preview

    func testPreviewIsAttachedWhenEmulationSucceeds() async throws {
        let client = StubApiClient()
        await client.setEmulationResult(
            EmulationResult(mcBlockSeqno: 1, transactions: [], trace: nil, isIncomplete: false)
        )
        let configuration = WalletKitConfiguration(
            deviceInfo: DeviceInfo(
                platform: "iphone", appName: "TestWallet", appVersion: "1.0",
                maxProtocolVersion: 2, features: []
            ),
            defaultBridgeURL: URL(string: bridge)!,
            emulateBeforeApproval: true
        )
        let (kit, _, dApp, session) = try await connected(client: client, configuration: configuration)
        let events = await EventCollector(kit: kit)

        let params = #"{\"messages\":[{\"address\":\"\#(destination)\",\"amount\":\"1\"}]}"#
        try await deliver(
            #"{"id":"1","method":"sendTransaction","params":["\#(params)"]}"#,
            from: dApp, to: kit, session: session
        )
        guard case .sendTransactionRequest(let request) = try await nextEvent(events) else {
            return XCTFail("expected a sendTransaction event")
        }
        XCTAssertNotNil(request.preview)
    }

    /// A preview is an aid, not a gate. Emulation being unavailable must not stop the user
    /// from seeing the request at all.
    func testRequestStillArrivesWhenEmulationFails() async throws {
        let client = StubApiClient()
        // No emulation result scripted, so the stub throws.
        let configuration = WalletKitConfiguration(
            deviceInfo: DeviceInfo(
                platform: "iphone", appName: "TestWallet", appVersion: "1.0",
                maxProtocolVersion: 2, features: []
            ),
            defaultBridgeURL: URL(string: bridge)!,
            emulateBeforeApproval: true
        )
        let (kit, _, dApp, session) = try await connected(client: client, configuration: configuration)
        let events = await EventCollector(kit: kit)

        let params = #"{\"messages\":[{\"address\":\"\#(destination)\",\"amount\":\"1\"}]}"#
        try await deliver(
            #"{"id":"1","method":"sendTransaction","params":["\#(params)"]}"#,
            from: dApp, to: kit, session: session
        )
        guard case .sendTransactionRequest(let request) = try await nextEvent(events) else {
            return XCTFail("expected a sendTransaction event")
        }
        XCTAssertNil(request.preview, "no preview, but the request must still arrive")
    }

    // MARK: - Signing details

    /// An undeployed wallet's first transfer must carry the state init, or the message has no
    /// contract to execute against.
    func testFirstTransferIncludesTheStateInit() async throws {
        let client = StubApiClient(isDeployed: false, seqno: 0)
        let (kit, wallet, dApp, session) = try await connected(client: client)
        let events = await EventCollector(kit: kit)

        let params = #"{\"messages\":[{\"address\":\"\#(destination)\",\"amount\":\"1\"}]}"#
        try await deliver(
            #"{"id":"1","method":"sendTransaction","params":["\#(params)"]}"#,
            from: dApp, to: kit, session: session
        )
        guard case .sendTransactionRequest(let request) = try await nextEvent(events) else {
            return XCTFail("expected a sendTransaction event")
        }

        let boc = try await kit.approve(request)
        var slice = try Cell.fromBase64(boc).beginParse()
        let message = try Message.load(from: &slice)
        let stateInit = try XCTUnwrap(message.stateInit)
        XCTAssertEqual(try stateInit.toCell().hash(), try wallet.stateInit().toCell().hash())
    }

    /// A deployed wallet must not pay to re-include its state init.
    func testLaterTransfersOmitTheStateInit() async throws {
        let client = StubApiClient(isDeployed: true, seqno: 9)
        let (kit, _, dApp, session) = try await connected(client: client)
        let events = await EventCollector(kit: kit)

        let params = #"{\"messages\":[{\"address\":\"\#(destination)\",\"amount\":\"1\"}]}"#
        try await deliver(
            #"{"id":"1","method":"sendTransaction","params":["\#(params)"]}"#,
            from: dApp, to: kit, session: session
        )
        guard case .sendTransactionRequest(let request) = try await nextEvent(events) else {
            return XCTFail("expected a sendTransaction event")
        }

        let boc = try await kit.approve(request)
        var slice = try Cell.fromBase64(boc).beginParse()
        let message = try Message.load(from: &slice)
        XCTAssertNil(message.stateInit)
    }
}
