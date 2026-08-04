import Foundation
import TONCore
import TONCrypto
import TONToncenter
import TONConnect
@testable import TONWalletKit

/// Intercepts the kit's HTTP so a test can play both the bridge and the dApp.
///
/// A `URLProtocol` rather than a protocol seam on `BridgeClient`, deliberately: this exercises
/// the real client — its SSE framing, its query construction, its reconnection — instead of
/// substituting something simpler that would pass while the real one is broken.
final class FakeBridgeProtocol: URLProtocol {
    /// Handlers keyed by path, set before the test runs.
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (Int, Data, [String: String]))?
    /// Every request the kit made, for assertions about what it sent where.
    nonisolated(unsafe) private static let recordLock = NSLock()
    nonisolated(unsafe) private static var records: [(url: URL, body: Data?)] = []

    static func reset() {
        recordLock.lock()
        records = []
        handler = nil
        recordLock.unlock()
    }

    static func recorded() -> [(url: URL, body: Data?)] {
        recordLock.lock(); defer { recordLock.unlock() }
        return records
    }

    static func record(_ url: URL, _ body: Data?) {
        recordLock.lock(); records.append((url, body)); recordLock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { return }
        // `httpBody` is nil for a stream-uploaded body, which is how URLSession delivers a
        // POST through a protocol stub; read the stream instead of reporting no body.
        let body = request.httpBody ?? request.httpBodyStream.map(Self.drain)
        Self.record(url, body)

        let (status, data, headers) = Self.handler?(request) ?? (404, Data(), [:])
        let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if !data.isEmpty { client?.urlProtocol(self, didLoad: data) }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func drain(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        let size = 4096
        var buffer = [UInt8](repeating: 0, count: size)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: size)
            if read <= 0 { break }
            data.append(contentsOf: buffer[0..<read])
        }
        return data
    }

    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FakeBridgeProtocol.self]
        return URLSession(configuration: config)
    }
}

/// A dApp's half of a TON Connect session, for driving the kit from the outside.
struct FakeDApp {
    let crypto: SessionCrypto
    let manifestURL = "https://dapp.example.com/tonconnect-manifest.json"

    init() throws {
        self.crypto = try SessionCrypto()
    }

    var clientID: String { crypto.sessionID }

    /// The universal link a dApp would show as a QR code.
    func connectLink(bridge: String, items: String) -> URL {
        let request = #"{"manifestUrl":"\#(manifestURL)","items":[\#(items)]}"#
        var components = URLComponents(string: "tc://")!
        components.queryItems = [
            URLQueryItem(name: "v", value: "2"),
            URLQueryItem(name: "id", value: clientID),
            URLQueryItem(name: "r", value: request),
            URLQueryItem(name: "ret", value: "back"),
        ]
        return components.url!
    }

    /// Seals a request the way a dApp would, addressed to the wallet's session key.
    func seal(_ json: String, to walletSessionPublicKey: String) throws -> String {
        guard let key = Data(hexString: walletSessionPublicKey) else {
            throw NSError(domain: "FakeDApp", code: 1)
        }
        return try crypto.encryptToBase64(json, receiverPublicKey: key)
    }

    /// Opens a reply the wallet sealed for us.
    func open(_ sealedBase64: String, from walletSessionPublicKey: String) throws -> String {
        guard let key = Data(hexString: walletSessionPublicKey) else {
            throw NSError(domain: "FakeDApp", code: 1)
        }
        return try crypto.decrypt(base64: sealedBase64, senderPublicKey: key)
    }
}

/// A stand-in ``ManifestFetching`` that answers from memory.
struct StubManifestFetcher: ManifestFetching {
    let result: Result<DAppManifest, ManifestFailure>

    static func serving(domain: String, name: String = "Test dApp") -> StubManifestFetcher {
        StubManifestFetcher(result: .success(DAppManifest(url: "https://\(domain)", name: name)))
    }

    static func failing(_ failure: ManifestFailure = .invalidContent(reason: "stubbed")) -> StubManifestFetcher {
        StubManifestFetcher(result: .failure(failure))
    }

    func fetch(manifestURL: String) async -> Result<DAppManifest, ManifestFailure> {
        result
    }
}

/// A scripted ``ApiClient``.
///
/// Records what it was asked to broadcast, so a test can assert the exact BoC that would have
/// reached the network — and can assert that nothing was broadcast when it should not have been.
actor StubApiClient: ApiClient {
    nonisolated let network: Network
    /// Address returned for `get_wallet_address`.
    nonisolated let jettonWalletStandIn = try! Address.parse(
        "0:1111111111111111111111111111111111111111111111111111111111111111"
    )
    var jettonBalance: Int64 = 0
    var accountState: AccountState
    var seqno: Int64
    var sentBocs: [String] = []
    var sendShouldFail = false
    var emulationResult: EmulationResult?

    init(
        network: Network = .testnet,
        isDeployed: Bool = true,
        balance: String = "10000000000",
        seqno: Int64 = 5
    ) {
        self.network = network
        self.accountState = AccountState(
            address: "0:0",
            status: isDeployed ? .active : .uninitialized,
            rawBalance: balance,
            balance: balance,
            extraCurrencies: [:],
            code: nil,
            data: nil,
            lastTransaction: nil
        )
        self.seqno = seqno
    }

    func setSendShouldFail(_ value: Bool) { sendShouldFail = value }
    func setJettonBalance(_ value: Int64) { jettonBalance = value }
    func setEmulationResult(_ value: EmulationResult?) { emulationResult = value }
    func setDeployed(_ value: Bool) {
        accountState = AccountState(
            address: accountState.address,
            status: value ? .active : .uninitialized,
            rawBalance: accountState.rawBalance,
            balance: accountState.balance,
            extraCurrencies: [:],
            code: nil,
            data: nil,
            lastTransaction: nil
        )
    }

    func getMasterchainInfo() async throws -> MasterchainInfo {
        MasterchainInfo(workchain: -1, seqno: 100, shard: "", rootHash: "0x00", fileHash: "0x00")
    }

    func getAccountState(address: String) async throws -> AccountState { accountState }

    func getAccountStates(addresses: [String]) async throws -> [String: AccountState] {
        Dictionary(uniqueKeysWithValues: addresses.map { ($0, accountState) })
    }

    func getBalance(address: String) async throws -> String { accountState.balance }

    func runGetMethod(
        address: String,
        method: String,
        stack: [RawStackItem]
    ) async throws -> GetMethodResult {
        switch method {
        case "seqno":
            return GetMethodResult(
                exitCode: 0,
                gasUsed: 100,
                stack: [.num("0x" + String(seqno, radix: 16))]
            )

        case "get_wallet_address":
            // A deterministic stand-in. The real address comes from the minter's stored wallet
            // code, which no stub can reproduce — but callers only need *an* address to build
            // and inspect the message.
            let cell = try beginCell().storeAddress(jettonWalletStandIn).endCell()
            return GetMethodResult(exitCode: 0, gasUsed: 100, stack: [.cell(cell.toBocBase64())])

        case "get_wallet_data":
            return GetMethodResult(
                exitCode: 0,
                gasUsed: 100,
                stack: [
                    .num("0x" + String(jettonBalance, radix: 16)),
                    .cell(try beginCell().storeAddress(jettonWalletStandIn).endCell().toBocBase64()),
                    .cell(try beginCell().storeAddress(jettonWalletStandIn).endCell().toBocBase64()),
                    .null,
                ]
            )

        default:
            throw ToncenterError.unexpectedResponse("StubApiClient does not implement \(method)")
        }
    }

    func sendBoc(_ boc: String) async throws -> SendResult {
        if sendShouldFail {
            throw ToncenterError.unexpectedResponse("stubbed send failure")
        }
        sentBocs.append(boc)
        return SendResult(messageHash: "0x" + String(repeating: "ab", count: 32))
    }

    func getTransactions(
        address: String,
        limit: Int,
        offset: Int
    ) async throws -> TransactionsPage {
        TransactionsPage(transactions: [])
    }

    func getTransactionsByMessageHash(_ hash: String) async throws -> TransactionsPage {
        TransactionsPage(transactions: [])
    }

    func getJettons(owner: String, limit: Int, offset: Int) async throws -> JettonsPage {
        JettonsPage(jettons: [])
    }

    func getNFTs(owner: String, limit: Int, offset: Int) async throws -> NFTsPage {
        NFTsPage(nfts: [])
    }

    func getNFTs(addresses: [String]) async throws -> NFTsPage {
        NFTsPage(nfts: [])
    }

    func resolveDNS(domain: String) async throws -> String? { nil }
    func reverseResolveDNS(address: String) async throws -> String? { nil }

    func emulate(boc: String, ignoreSignature: Bool) async throws -> EmulationResult {
        guard let emulationResult else {
            throw ToncenterError.unexpectedResponse("no emulation scripted")
        }
        return emulationResult
    }

    func getTraces(account: String, limit: Int, offset: Int) async throws -> [Trace] { [] }
    func getTrace(traceID: String) async throws -> Trace? { nil }
    func getPendingTraces(externalMessageHash: String) async throws -> [Trace] { [] }
}

/// Buffers everything the kit emits, so a test can wait for an event with a deadline.
///
/// Awaiting `AsyncStream.Iterator.next()` directly blocks forever when the expected event
/// never arrives — a test that should fail instead hangs, which is worse in CI and makes the
/// suite impossible to mutation-test. The collector owns the iterator on its own task and
/// hands out buffered events with a timeout.
actor EventCollector {
    private var buffer: [WalletKitEvent] = []
    private var pumpTask: Task<Void, Never>?

    init(kit: TonWalletKit) async {
        let stream = await kit.eventStream()
        pumpTask = Task { [weak self] in
            for await event in stream {
                await self?.append(event)
            }
        }
        // Let the pump attach before the first event is emitted. Without this the stream's
        // unbounded buffer still holds them, but the ordering is clearer with the pump live.
        await Task.yield()
    }

    deinit { pumpTask?.cancel() }

    private func append(_ event: WalletKitEvent) { buffer.append(event) }

    /// The next buffered event, or nil once the deadline passes.
    func next(timeout: TimeInterval = 2) async -> WalletKitEvent? {
        let deadline = ContinuousClock.now.advanced(by: .milliseconds(Int(timeout * 1000)))
        while ContinuousClock.now < deadline {
            if !buffer.isEmpty { return buffer.removeFirst() }
            try? await Task.sleep(nanoseconds: 2_000_000)
        }
        return buffer.isEmpty ? nil : buffer.removeFirst()
    }

    /// How many events are waiting, for asserting that nothing extra was emitted.
    func pending() -> Int { buffer.count }
}
