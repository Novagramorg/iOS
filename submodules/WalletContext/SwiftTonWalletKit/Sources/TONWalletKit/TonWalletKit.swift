import Foundation
import TONCore
import TONCrypto
import TONContracts
import TONToncenter
import TONConnect

/// The kit's public entry point.
///
/// An actor, so every piece of mutable state — sessions, wallets, the bridge subscription —
/// is serialised without a lock in sight. The reference coordinates the same state across
/// `TonWalletKit`, `EventRouter`, `RequestProcessor`, `BridgeManager`, `WalletManager` and a
/// promise-based lock table; actor isolation replaces all of that coordination.
///
/// ## Key material
///
/// The kit never persists private keys. Wallets are registered by the app at launch via
/// ``register(wallet:)``, backed by whatever ``WalletSigner`` the app chooses. What the kit
/// *does* persist is sessions and pending requests, keyed by ``WalletID`` — those must
/// survive a restart or a dApp waits forever for a reply. A wallet the app forgets to
/// re-register simply has no signer, and its requests are refused rather than mis-signed.
public actor TonWalletKit {
    let configuration: WalletKitConfiguration
    let storage: any WalletKitStorage
    private let sessions: SessionManager
    let eventStore: EventStore
    private let manifests: any ManifestFetching
    /// One API client per network. Supplied by the app so it controls keys and endpoints.
    let clients: [Network: any ApiClient]
    private let now: @Sendable () -> Int64
    let urlSession: URLSession

    /// Registered wallets, by id.
    private var wallets: [WalletID: Wallet] = [:]

    /// One bridge connection per bridge URL, each subscribed to every session on it.
    private var bridges: [URL: BridgeSubscription] = [:]

    /// Jetton metadata cache. Metadata only — balances are always read live.
    let assetCache: AssetCache

    /// One streaming connection per network, created on first subscription.
    var streamingClients: [Network: ToncenterStreaming] = [:]
    /// Key for the streaming endpoint. Separate from the `ApiClient`'s because that one lives
    /// behind the client seam, which a host app may have replaced entirely.
    let streamingAPIKey: String?
    /// Supplies a fresh streaming endpoint when a socket connects or reconnects.
    let streamingURLProvider: (@Sendable (Network) async throws -> URL)?
    let streamingConfiguration: ToncenterStreaming.Configuration
    /// Overrides socket construction, for tests.
    let streamingFactory: (@Sendable (Network) -> any StreamingSocketFactory)?

    private var eventContinuation: AsyncStream<WalletKitEvent>.Continuation?
    private var cachedEventStream: AsyncStream<WalletKitEvent>?

    /// Monotonic connect-event ids, per session.
    ///
    /// The protocol wants a number that increases across a session's lifetime; dApps use it
    /// to discard stale replies. Derived from a counter rather than the clock so it stays
    /// monotonic across a device whose clock moves backwards.
    private var connectEventCounter: UInt64 = 0

    public init(
        configuration: WalletKitConfiguration,
        storage: any WalletKitStorage,
        clients: [Network: any ApiClient],
        manifests: any ManifestFetching = URLSessionManifestFetcher(),
        urlSession: URLSession = .shared,
        streamingAPIKey: String? = nil,
        streamingURLProvider: (@Sendable (Network) async throws -> URL)? = nil,
        streamingConfiguration: ToncenterStreaming.Configuration = .default,
        streamingFactory: (@Sendable (Network) -> any StreamingSocketFactory)? = nil,
        assetCache: AssetCache = AssetCache(),
        now: @Sendable @escaping () -> Int64 = { Int64(Date().timeIntervalSince1970 * 1000) }
    ) {
        self.assetCache = assetCache
        self.streamingAPIKey = streamingAPIKey
        self.streamingURLProvider = streamingURLProvider
        self.streamingConfiguration = streamingConfiguration
        self.streamingFactory = streamingFactory
        self.configuration = configuration
        self.storage = storage
        self.clients = clients
        self.manifests = manifests
        self.urlSession = urlSession
        self.now = now
        self.sessions = SessionManager(storage: storage, now: now)
        self.eventStore = EventStore(storage: storage, now: now)
    }

    // MARK: - Event stream

    /// Requests and notifications for the app to act on.
    ///
    /// A single stream, created lazily and shared. Calling this twice returns the same
    /// stream rather than a second one, because a bridge message can only be delivered once
    /// — two streams would mean each consumer silently sees a fraction of the traffic.
    public func eventStream() -> AsyncStream<WalletKitEvent> {
        if let cachedEventStream { return cachedEventStream }
        var continuation: AsyncStream<WalletKitEvent>.Continuation!
        // Unbounded: dropping a dApp request because the app was slow to read would leave
        // the dApp waiting on a reply that is never coming.
        let stream = AsyncStream<WalletKitEvent>(bufferingPolicy: .unbounded) { continuation = $0 }
        self.eventContinuation = continuation
        self.cachedEventStream = stream
        return stream
    }

    func emit(_ event: WalletKitEvent) {
        eventContinuation?.yield(event)
    }

    // MARK: - Wallets

    /// Makes a wallet available for signing.
    ///
    /// Idempotent, so an app can call it on every launch without tracking what it already
    /// registered.
    public func register(wallet: Wallet) async {
        wallets[wallet.id] = wallet
        await resubscribe()
    }

    /// Forgets a wallet and everything attached to it.
    ///
    /// Sessions go too. Leaving them would keep the bridge delivering requests for a wallet
    /// that can no longer sign, and each would have to be refused.
    public func forget(walletID: WalletID) async {
        wallets[walletID] = nil
        await sessions.removeAll(forWallet: walletID)
        await resubscribe()
    }

    public func registeredWallets() -> [Wallet] {
        wallets.values.sorted { $0.id.value < $1.id.value }
    }

    public func wallet(id: WalletID) -> Wallet? {
        wallets[id]
    }

    func requireWallet(_ id: WalletID) throws -> Wallet {
        guard let wallet = wallets[id] else {
            throw WalletKitError.walletNotFound(id)
        }
        return wallet
    }

    func requireClient(for wallet: Wallet) throws -> any ApiClient {
        guard let client = clients[wallet.network] else {
            throw WalletKitError.noNetworkConfigured(chainID: wallet.network.chainId)
        }
        return client
    }

    /// Current time in Unix milliseconds, from the injected clock so tests need not sleep.
    func currentMillis() -> Int64 { now() }

    // MARK: - Sessions

    public func activeSessions() async -> [TONConnectSession] {
        await sessions.allSessions()
    }

    func requireSession(_ id: String) async throws -> TONConnectSession {
        guard let session = await sessions.session(id: id) else {
            throw WalletKitError.sessionNotFound(id)
        }
        return session
    }

    /// Drops sessions the user has not touched in a long time.
    ///
    /// Exposed rather than run on a timer: the app knows when it is a good moment, and a
    /// background sweep that removes a session mid-request would be worse than a stale one.
    @discardableResult
    public func cleanupInactiveSessions() async -> Int {
        guard let limit = configuration.sessionInactivityLimit else { return 0 }
        let removed = await sessions.cleanupInactive(maxInactivity: limit)
        if removed > 0 { await resubscribe() }
        return removed
    }

    /// Reclaims requests whose handler died, and drops finished ones past retention.
    ///
    /// Returns the recovered requests so the app can re-present them — an app killed while a
    /// confirmation sheet was up should show that sheet again, not leave the dApp waiting.
    @discardableResult
    public func recoverPendingRequests() async -> Int {
        let recovered = await eventStore.recoverStaleEvents()
        _ = await eventStore.cleanupOldEvents()
        return recovered
    }

    public func sessions(forWallet walletID: WalletID) async -> [TONConnectSession] {
        await sessions.sessions(forWallet: walletID)
    }

    /// Ends a connection from the wallet's side and tells the dApp.
    ///
    /// The session is removed even if the notification fails to send. A dApp that never
    /// hears about it will find out on its next request; leaving the session alive because a
    /// network call failed would mean the user pressed disconnect and stayed connected.
    public func disconnect(sessionID: String) async throws {
        guard let session = await sessions.session(id: sessionID) else { return }

        await sessions.remove(id: sessionID)
        await resubscribe()

        connectEventCounter += 1
        do {
            try await send(DisconnectEvent(id: connectEventCounter), to: session)
        } catch {
            throw WalletKitError.bridgeFailure(underlying: error)
        }
    }

    // MARK: - Connect links

    /// Handles a `tc://` or `https://…/ton-connect` link.
    ///
    /// Fetching the manifest is part of this rather than deferred to approval time: the user
    /// must see who is asking *before* deciding, and a dApp whose manifest cannot be fetched
    /// is shown as unverified rather than silently trusted.
    ///
    /// Returns the request, and also emits it on the stream — a caller handling a link it
    /// received directly usually wants it inline, while the stream keeps a single place for
    /// the UI to observe.
    @discardableResult
    public func handle(url: URL) async throws -> ConnectionRequest {
        let parsed: ConnectURL
        do {
            parsed = try ConnectURL.parse(url.absoluteString)
        } catch {
            throw WalletKitError.validationFailed(reason: "Not a TON Connect link: \(error)")
        }

        let manifestURL = parsed.request.manifestUrl
        var manifest: DAppManifest?
        var failure: ManifestFailure?
        switch await manifests.fetch(manifestURL: manifestURL) {
        case .success(let fetched): manifest = fetched
        case .failure(let error): failure = error
        }

        let bridgeURL = parsed.bridgeURL.flatMap(URL.init(string:)) ?? configuration.defaultBridgeURL

        let request = ConnectionRequest(
            id: UUID().uuidString,
            clientID: parsed.clientID,
            bridgeURL: bridgeURL.absoluteString,
            requestedItems: parsed.request.items.map { item in
                switch item.name {
                case ConnectItem.tonAddressName: return .address
                case ConnectItem.tonProofName: return .proof(payload: item.payload ?? "")
                default: return .unknown(name: item.name)
                }
            },
            dApp: DAppPreview(manifestURL: manifestURL, manifest: manifest, manifestFailure: failure),
            returnStrategy: parsed.returnStrategy
        )

        emit(.connectionRequest(request))
        return request
    }

    /// Approves a connect request, creating the session and replying to the dApp.
    ///
    /// The session is created **before** the reply is sent. If the order were reversed, a
    /// reply that succeeded followed by a storage failure would leave the dApp believing it
    /// is connected to a session the wallet has no record of — every later request would then
    /// be undecryptable.
    public func approve(
        _ request: ConnectionRequest,
        with wallet: Wallet,
        proof providedProof: ProvidedProof? = nil
    ) async throws {
        guard wallets[wallet.id] != nil else {
            throw WalletKitError.walletNotFound(wallet.id)
        }
        // A proof binds to a domain. Without a usable manifest there is no domain to bind
        // to, and a proof over an empty domain verifies against nothing.
        if request.requestsProof, providedProof == nil, request.dApp.domain == nil {
            throw WalletKitError.manifestInvalid(
                reason: request.dApp.manifestFailure?.reason ?? "no domain in manifest"
            )
        }

        let crypto: SessionCrypto
        do {
            crypto = try SessionCrypto()
        } catch {
            throw WalletKitError.cryptoFailure(underlying: error)
        }

        let session = await sessions.create(
            id: request.clientID,
            walletID: wallet.id,
            dApp: request.dApp.info,
            crypto: crypto,
            bridgeURL: request.bridgeURL
        )
        await resubscribe()

        connectEventCounter += 1
        var items: [ConnectEventSuccess.Item] = [.address(try wallet.addressReply())]

        if request.requestsProof {
            if let providedProof {
                items.append(.proof(providedProof.reply))
            } else if let domain = request.dApp.domain {
                let reply = try await wallet.signProof(
                    domain: domain,
                    payload: request.proofPayload ?? "",
                    timestamp: UInt64(now() / 1000)
                )
                items.append(.proof(reply))
            }
        }

        do {
            try await send(
                ConnectEventSuccess(
                    id: connectEventCounter,
                    device: configuration.deviceInfo.withFeatures(
                        wallet.supportedFeatures(limitedTo: configuration.advertisedFeatures)
                    ),
                    items: items
                ),
                to: session
            )
        } catch {
            throw WalletKitError.bridgeFailure(underlying: error)
        }
    }

    /// Rejects a connect request.
    ///
    /// Uses a throwaway session keypair, because no session exists to seal with — the dApp
    /// only needs the envelope to decrypt, and it has our ephemeral public key from the
    /// nonce-prefixed payload.
    public func reject(_ request: ConnectionRequest, reason: String? = nil) async throws {
        connectEventCounter += 1
        let response = ConnectEventError(
            id: connectEventCounter,
            code: .userRejects,
            message: reason ?? "User rejected the connection"
        )

        do {
            let crypto = try SessionCrypto()
            guard let peer = Data(hexString: request.clientID) else {
                throw WalletKitError.validationFailed(reason: "Connect clientID is not hex")
            }
            let sealed = try crypto.encryptToBase64(
                String(decoding: try JSONEncoder().encode(response)),
                receiverPublicKey: peer
            )
            let bridge = URL(string: request.bridgeURL) ?? configuration.defaultBridgeURL
            try await BridgeClient(bridgeURL: bridge, clientID: crypto.sessionID, session: urlSession)
                .send(sealed, to: request.clientID, topic: "connect_error")
        } catch let error as WalletKitError {
            throw error
        } catch {
            throw WalletKitError.bridgeFailure(underlying: error)
        }
    }

    // MARK: - Bridge plumbing

    /// Rebuilds bridge connections to match the current session set.
    ///
    /// Only rebuilds a connection whose session list actually changed. Reconnecting
    /// needlessly costs a round trip and a gap during which inbound requests are missed, so
    /// adding a session on bridge A must not disturb bridge B.
    func resubscribe() async {
        // A session whose wallet is not registered has no signer, so listening for its
        // requests would only produce refusals. Skip it rather than hold a connection open.
        let live = await sessions.allSessions().filter { wallets[$0.walletID] != nil }

        var wanted: [URL: [TONConnectSession]] = [:]
        for session in live {
            let url = URL(string: session.bridgeURL) ?? configuration.defaultBridgeURL
            wanted[url, default: []].append(session)
        }

        for (url, subscription) in bridges where wanted[url] == nil {
            subscription.cancel()
            bridges[url] = nil
        }

        for (url, group) in wanted {
            let ids = Set(group.map(\.id))
            if let existing = bridges[url], existing.sessionIDs == ids { continue }
            bridges[url]?.cancel()
            bridges[url] = startBridge(url: url, sessions: group)
        }
    }

    /// Stops listening. The kit can be restarted by registering a wallet or resubscribing.
    public func stop() {
        for subscription in bridges.values { subscription.cancel() }
        bridges.removeAll()
        // Streaming goes too: `stop()` means "stop talking to the network", and leaving a
        // socket open after it would keep the app awake for updates nobody is listening to.
        let clients = streamingClients
        streamingClients.removeAll()
        Task { for client in clients.values { await client.stop() } }
    }

    private func startBridge(url: URL, sessions group: [TONConnectSession]) -> BridgeSubscription? {
        // The bridge takes a comma-separated list of *our* session public keys — the dApp
        // addresses us by the key we gave it on connect, not by its own.
        let clientID = group
            .sorted { $0.id < $1.id }
            .map(\.sessionPublicKey)
            .joined(separator: ",")
        guard !clientID.isEmpty else { return nil }

        let ids = Set(group.map(\.id))
        let client = BridgeClient(
            bridgeURL: url,
            clientID: clientID,
            session: urlSession,
            lastEventIDStore: BridgeCursorStore(storage: storage, bridgeURL: url)
        )

        let task = Task { [weak self] in
            guard let self else { return }
            do {
                for try await message in client.messages() {
                    if Task.isCancelled { break }
                    await self.ingest(message)
                }
            } catch {
                // The client reconnects internally, so reaching here means the stream itself
                // ended. Report it rather than going quiet.
                await self.emitBridgeTrouble(sessionIDs: Array(ids), description: String(describing: error))
            }
        }

        return BridgeSubscription(client: client, task: task, sessionIDs: ids)
    }

    private func emitBridgeTrouble(sessionIDs: [String], description: String) {
        emit(.bridgeTrouble(sessionIDs: sessionIDs, description: description))
    }

    /// Decrypts, parses, persists, and emits one bridge message.
    ///
    /// Persisting before emitting is deliberate: an app killed between the two must find the
    /// request waiting on next launch rather than leaving the dApp unanswered.
    func ingest(_ message: BridgeMessage) async {
        guard let session = await sessions.session(id: message.from) else {
            // A message for a session we do not have. Nothing can be decrypted and no reply
            // can be sealed, so there is nothing to do but note it.
            emit(.malformedRequest(MalformedRequest(
                id: "",
                sessionID: message.from,
                reason: "No session for bridge sender \(message.from)"
            )))
            return
        }
        guard let wallet = wallets[session.walletID] else { return }

        let plaintext: Data
        do {
            let crypto = try session.crypto()
            let decrypted = try crypto.decrypt(
                base64: message.message,
                senderPublicKey: try session.peerPublicKey()
            )
            plaintext = Data(decrypted.utf8)
        } catch {
            emit(.malformedRequest(MalformedRequest(
                id: "",
                sessionID: session.id,
                reason: "Could not decrypt bridge message: \(error)"
            )))
            return
        }

        await sessions.touch(id: session.id)

        let parsed = RequestParser.parse(
            payload: plaintext,
            session: session,
            walletNetwork: wallet.network.chainId
        )

        switch parsed {
        case .sendTransaction(var request):
            await store(request.id, session: session.id, type: .sendTransaction, payload: plaintext)
            if configuration.emulateBeforeApproval {
                request.preview = await emulatePreview(messages: request.messages, wallet: wallet)
            }
            emit(.sendTransactionRequest(request))

        case .signMessage(var request):
            await store(request.id, session: session.id, type: .signMessage, payload: plaintext)
            if configuration.emulateBeforeApproval {
                request.preview = await emulatePreview(messages: request.messages, wallet: wallet)
            }
            emit(.signMessageRequest(request))

        case .signData(let request):
            await store(request.id, session: session.id, type: .signData, payload: plaintext)
            emit(.signDataRequest(request))

        case .disconnect(let request):
            // Remove first, then acknowledge. A dApp that asked to disconnect must not stay
            // connected because the acknowledgement failed to send.
            await sessions.remove(id: session.id)
            await resubscribe()
            _ = try? await send(WalletResponseSuccess(id: request.id, result: ""), to: session)
            emit(.disconnected(request))

        case .unsupported(let id, let method):
            try? await send(
                WalletResponseError(
                    id: id,
                    code: SendTransactionErrorCode.methodNotSupported.rawValue,
                    message: "\(method) is not supported"
                ),
                to: session
            )
            emit(.malformedRequest(MalformedRequest(
                id: id,
                sessionID: session.id,
                reason: "Unsupported method \(method)"
            )))

        case .malformed(let malformed):
            try? await send(
                WalletResponseError(
                    id: malformed.id,
                    code: SendTransactionErrorCode.badRequest.rawValue,
                    message: malformed.reason
                ),
                to: session
            )
            emit(.malformedRequest(malformed))
        }
    }

    private func store(_ id: String, session: String, type: EventType, payload: Data) async {
        // A store failure must not drop the request on the floor: the user can still act on
        // it this run, they just lose it if the app dies first.
        _ = try? await eventStore.store(id: id, sessionID: session, eventType: type, payload: payload)
    }

    /// Seals a response and posts it to the dApp.
    func send(_ response: some Encodable, to session: TONConnectSession) async throws {
        let crypto = try session.crypto()
        let sealed = try crypto.encryptToBase64(
            String(decoding: try JSONEncoder().encode(response)),
            receiverPublicKey: try session.peerPublicKey()
        )
        let url = URL(string: session.bridgeURL) ?? configuration.defaultBridgeURL
        let client = bridges[url]?.client
            ?? BridgeClient(bridgeURL: url, clientID: session.sessionPublicKey, session: urlSession)
        try await client.send(sealed, to: session.id)
    }
}

extension String {
    /// UTF-8 decode that cannot fail, for JSON we just encoded ourselves.
    init(decoding data: Data) {
        self = String(data: data, encoding: .utf8) ?? ""
    }
}
