import Foundation
import TONCore

/// Read and write access to the chain.
///
/// A protocol rather than a concrete type so tests can mock it and a host app can point
/// at a self-hosted `ton-http-api`. Only Toncenter is implemented; TonAPI is out of
/// scope.
public protocol ApiClient: Sendable {
    var network: Network { get }

    func getMasterchainInfo() async throws -> MasterchainInfo

    /// State of a single account. Never throws for a non-existent account — it returns
    /// a state with `.nonExisting`.
    func getAccountState(address: String) async throws -> AccountState

    /// Batched account states, keyed by canonical friendly address.
    ///
    /// Guarantees an entry for **every** requested address.
    func getAccountStates(addresses: [String]) async throws -> [String: AccountState]

    /// Balance in nanoton, as a decimal string.
    func getBalance(address: String) async throws -> String

    func runGetMethod(
        address: String,
        method: String,
        stack: [RawStackItem]
    ) async throws -> GetMethodResult

    /// Broadcasts a base64 BoC.
    func sendBoc(_ boc: String) async throws -> SendResult

    func getTransactions(
        address: String,
        limit: Int,
        offset: Int
    ) async throws -> TransactionsPage

    /// Looks up transactions by inbound message hash — how a wallet confirms its own
    /// send landed, paired with TEP-467 normalized hashing.
    func getTransactionsByMessageHash(_ hash: String) async throws -> TransactionsPage

    /// Jetton holdings for an owner, each carrying the jetton wallet address a transfer
    /// must be sent to.
    func getJettons(owner: String, limit: Int, offset: Int) async throws -> JettonsPage

    /// NFT items owned by an address.
    func getNFTs(owner: String, limit: Int, offset: Int) async throws -> NFTsPage

    /// NFT items by their own addresses.
    func getNFTs(addresses: [String]) async throws -> NFTsPage

    /// Resolves a `.ton` domain to a wallet address, or nil when it does not resolve.
    func resolveDNS(domain: String) async throws -> String?

    /// Reverse lookup: the domain pointing at an address, if any.
    func reverseResolveDNS(address: String) async throws -> String?

    /// Emulates a message without sending it — how a wallet previews a transfer.
    func emulate(boc: String, ignoreSignature: Bool) async throws -> EmulationResult

    /// Traces touching an account, newest first.
    func getTraces(account: String, limit: Int, offset: Int) async throws -> [Trace]

    /// One trace by id.
    func getTrace(traceID: String) async throws -> Trace?

    /// Traces for a not-yet-committed external message, so a wallet can show a send as
    /// in-flight.
    func getPendingTraces(externalMessageHash: String) async throws -> [Trace]
}

/// Toncenter v3 implementation.
public struct ToncenterClient: ApiClient {
    public let network: Network
    let transport: any Transport
    let decoder: JSONDecoder
    /// Retry configuration. Exposed so tests can drive the delay to zero rather than
    /// sleeping for real.
    let retryAttempts: Int
    let retryDelayNanoseconds: UInt64

    public init(
        network: Network,
        transport: any Transport,
        retryAttempts: Int = Retry.defaultAttempts,
        retryDelayNanoseconds: UInt64 = Retry.defaultDelayNanoseconds
    ) {
        self.network = network
        self.transport = transport
        self.decoder = JSONDecoder()
        self.retryAttempts = retryAttempts
        self.retryDelayNanoseconds = retryDelayNanoseconds
    }

    /// Convenience initializer over `URLSession`.
    public init(
        network: Network,
        apiKey: String? = nil,
        endpoint: URL? = nil,
        session: URLSession = .shared,
        timeout: TimeInterval = 30
    ) {
        self.init(
            network: network,
            transport: URLSessionTransport(
                endpoint: endpoint ?? network.defaultEndpoint,
                apiKey: apiKey,
                session: session,
                timeout: timeout
            )
        )
    }

    // MARK: - Request plumbing

    private func get<T: Decodable>(
        _ path: String,
        query: [String: [String]] = [:],
        as type: T.Type = T.self
    ) async throws -> T {
        try await perform(TransportRequest(method: .get, path: path, query: query), as: type)
    }

    private func post<T: Decodable>(
        _ path: String,
        body: some Encodable,
        as type: T.Type = T.self
    ) async throws -> T {
        let encoded = try JSONEncoder().encode(body)
        return try await perform(TransportRequest(method: .post, path: path, body: encoded), as: type)
    }

    private func perform<T: Decodable>(
        _ request: TransportRequest,
        as type: T.Type
    ) async throws -> T {
        try await Retry.callForSuccess(
            attempts: retryAttempts,
            delayNanoseconds: retryDelayNanoseconds
        ) {
            let response = try await transport.send(request)
            guard response.isSuccess else {
                throw ToncenterError.from(status: response.status, body: response.body)
            }
            do {
                return try decoder.decode(T.self, from: response.body)
            } catch {
                throw ToncenterError.decodingFailed(endpoint: request.path, underlying: error)
            }
        }
    }

    // MARK: - Endpoints

    public func getMasterchainInfo() async throws -> MasterchainInfo {
        let wire: Wire.MasterchainInfoResponse = try await get("/api/v3/masterchainInfo")
        return Mappers.masterchainInfo(wire)
    }

    public func getAccountState(address: String) async throws -> AccountState {
        // Normalize before the call so a malformed address fails locally rather than as
        // an opaque HTTP 422.
        let canonical = try Mappers.canonical(address: address)
        let wire: Wire.AddressInformation = try await get(
            "/api/v3/addressInformation",
            query: ["address": [canonical]]
        )
        return try Mappers.accountState(wire, address: canonical)
    }

    public func getAccountStates(addresses: [String]) async throws -> [String: AccountState] {
        guard !addresses.isEmpty else { return [:] }

        // Validate every address up front: one bad entry should not produce a partial
        // result that silently omits it.
        let canonical = try addresses.map { try Mappers.canonical(address: $0) }

        // Toncenter caps a batch at 100 addresses.
        var combined: [String: AccountState] = [:]
        for chunk in canonical.chunked(into: 100) {
            let wire: Wire.AccountStatesResponse = try await get(
                "/api/v3/accountStates",
                query: ["address": chunk]
            )
            let mapped = try Mappers.accountStates(wire, requested: chunk)
            combined.merge(mapped) { current, _ in current }
        }
        return combined
    }

    public func getBalance(address: String) async throws -> String {
        (try await getAccountState(address: address)).rawBalance
    }

    public func runGetMethod(
        address: String,
        method: String,
        stack: [RawStackItem] = []
    ) async throws -> GetMethodResult {
        struct Request: Encodable {
            let address: String
            let method: String
            let stack: [RawStackItem]
        }
        let canonical = try Mappers.canonical(address: address)
        let wire: Wire.RunGetMethodResponse = try await post(
            "/api/v3/runGetMethod",
            body: Request(address: canonical, method: method, stack: stack)
        )
        return Mappers.getMethodResult(wire)
    }

    public func sendBoc(_ boc: String) async throws -> SendResult {
        struct Request: Encodable {
            let boc: String
        }
        let wire: Wire.SendMessageResponse = try await post(
            "/api/v3/message",
            body: Request(boc: boc)
        )
        guard let hash = Mappers.hexHash(fromBase64: wire.messageHash) else {
            // Toncenter accepted the BoC but told us nothing useful about it; surface
            // that rather than inventing a hash.
            throw ToncenterError.unexpectedResponse("send returned no message hash")
        }
        return SendResult(messageHash: hash)
    }

    public func getTransactions(
        address: String,
        limit: Int = 10,
        offset: Int = 0
    ) async throws -> TransactionsPage {
        let canonical = try Mappers.canonical(address: address)
        let wire: Wire.TransactionsResponse = try await get(
            "/api/v3/transactions",
            query: [
                "account": [canonical],
                "limit": [String(limit)],
                "offset": [String(offset)],
            ]
        )
        return Mappers.transactions(wire)
    }

    public func getTransactionsByMessageHash(_ hash: String) async throws -> TransactionsPage {
        // Toncenter wants base64 here, but callers hold `0x`-prefixed hex from
        // normalized hashing, so accept both.
        let wireHash = Self.toBase64Hash(hash)
        let wire: Wire.TransactionsResponse = try await get(
            "/api/v3/transactionsByMessage",
            query: ["msg_hash": [wireHash]]
        )
        return Mappers.transactions(wire)
    }

    // MARK: - Assets

    public func getJettons(
        owner: String,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> JettonsPage {
        let canonical = try Mappers.canonical(address: owner)
        let wire: Wire.JettonWalletsResponse = try await get(
            "/api/v3/jetton/wallets",
            query: [
                "owner_address": [canonical],
                "limit": [String(limit)],
                "offset": [String(offset)],
            ]
        )
        return try Mappers.jettons(wire)
    }

    public func getNFTs(
        owner: String,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> NFTsPage {
        let canonical = try Mappers.canonical(address: owner)
        let wire: Wire.NFTItemsResponse = try await get(
            "/api/v3/nft/items",
            query: [
                "owner_address": [canonical],
                "limit": [String(limit)],
                "offset": [String(offset)],
            ]
        )
        return try Mappers.nfts(wire)
    }

    public func getNFTs(addresses: [String]) async throws -> NFTsPage {
        guard !addresses.isEmpty else { return NFTsPage(nfts: []) }
        let canonical = try addresses.map { try Mappers.canonical(address: $0) }
        let wire: Wire.NFTItemsResponse = try await get(
            "/api/v3/nft/items",
            query: ["address": canonical]
        )
        return try Mappers.nfts(wire)
    }

    // MARK: - Traces

    /// Traces touching an account.
    ///
    /// Unlike the reference, this honours the account argument and issues **one** request.
    /// `getTrace` there ignores `request.account` entirely and fans out three parallel
    /// lookups keyed on `tx_hash`, `trace_id` and `msg_hash`, tripling load for one
    /// logical query.
    public func getTraces(account: String, limit: Int = 10, offset: Int = 0) async throws -> [Trace] {
        (try await getTracesPage(account: account, limit: limit, offset: offset)).traces
    }

    public func getTracesPage(account: String, limit: Int = 10, offset: Int = 0) async throws -> TracesPage {
        let canonical = try Mappers.canonical(address: account)
        let wire: Wire.TracesResponse = try await get(
            "/api/v3/traces",
            query: [
                "account": [canonical],
                "limit": [String(limit)],
                "offset": [String(offset)],
            ]
        )
        return Mappers.tracesPage(wire)
    }

    /// One trace by id. Returns nil when it does not exist — an ordinary outcome for a
    /// hash that has not been indexed yet.
    public func getTrace(traceID: String) async throws -> Trace? {
        let wire: Wire.TracesResponse = try await get(
            "/api/v3/traces",
            query: ["trace_id": [Self.toBase64Hash(traceID)]]
        )
        return Mappers.traces(wire).first
    }

    /// Pending traces for an external message.
    ///
    /// Returns an empty array when nothing is pending. The reference throws in that case,
    /// even though the endpoint answers `200` with an empty list — "nothing in flight" is
    /// not an error.
    public func getPendingTraces(externalMessageHash: String) async throws -> [Trace] {
        let wire: Wire.TracesResponse = try await get(
            "/api/v3/pendingTraces",
            query: ["ext_msg_hash": [Self.toBase64Hash(externalMessageHash)]]
        )
        return Mappers.traces(wire)
    }

    // MARK: - Emulation

    /// Emulates a message against current chain state.
    ///
    /// `ignoreSignature` maps to the API's `ignore_chksig`, which is what a wallet needs
    /// when previewing a transaction the user has not approved yet: the body carries a
    /// placeholder signature, so signature checking must be skipped or every preview
    /// would fail.
    public func emulate(boc: String, ignoreSignature: Bool = true) async throws -> EmulationResult {
        struct Request: Encodable {
            let boc: String
            let ignoreChksig: Bool

            enum CodingKeys: String, CodingKey {
                case boc
                case ignoreChksig = "ignore_chksig"
            }
        }
        let wire: Wire.EmulateTraceResponse = try await post(
            "/api/emulate/v1/emulateTrace",
            body: Request(boc: boc, ignoreChksig: ignoreSignature)
        )
        return Mappers.emulation(wire)
    }

    // MARK: - DNS

    public func resolveDNS(domain: String) async throws -> String? {
        let wire: Wire.DNSRecordsResponse = try await get(
            "/api/v3/dns/records",
            query: ["domain": [domain]]
        )
        return try Mappers.dnsWallet(wire)
    }

    public func reverseResolveDNS(address: String) async throws -> String? {
        let canonical = try Mappers.canonical(address: address)
        let wire: Wire.DNSRecordsResponse = try await get(
            "/api/v3/dns/records",
            query: ["wallet": [canonical]]
        )
        return Mappers.dnsDomain(wire)
    }

    /// Converts a `0x`-prefixed hex hash to base64, passing through anything already
    /// base64.
    static func toBase64Hash(_ hash: String) -> String {
        if hash.hasPrefix("0x") || hash.count == 64,
           let data = Data(hexString: hash.hasPrefix("0x") ? String(hash.dropFirst(2)) : hash) {
            return data.base64EncodedString()
        }
        return hash
    }
}

extension Array {
    /// Splits into fixed-size chunks, for endpoints with batch limits.
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
