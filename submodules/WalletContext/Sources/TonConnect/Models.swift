import Foundation
import WalletEngineFFI

@available(macOS 10.15, *)
public struct TonConnectWalletIdentity: Codable, Equatable, Sendable {
    public let recordId: String
    public let address: String
    public let network: String

    public init(recordId: String, address: String, network: String) {
        self.recordId = recordId
        self.address = address
        self.network = network
    }
}

@available(macOS 10.15, *)
public enum TonConnectFailure: Error, Equatable, Sendable {
    case unavailable, invalidLink, conflictingLink, capacityExceeded
    case invalidResponse, responseTooLarge, invalidManifest, wrongNetwork
    case storageUnavailable, bridgeUnavailable, previewFailed, outcomeUnknown, walletBusy

    public var message: String {
        switch self {
        case .unavailable: return "This TON Connect request is no longer available."
        case .invalidLink: return "This TON Connect link is invalid."
        case .conflictingLink: return "This app is already using a different connection request. Reconnect from the app."
        case .capacityExceeded: return "Too many TON Connect requests are waiting."
        case .invalidResponse: return "The TON Connect server returned an invalid response."
        case .responseTooLarge: return "The TON Connect server exceeded the response size limit."
        case .invalidManifest: return "Unable to load a valid manifest for this app."
        case .wrongNetwork: return "This app requested a different wallet network."
        case .storageUnavailable: return "The TON Connect response is waiting for secure storage."
        case .bridgeUnavailable: return "The TON Connect response is waiting for network delivery."
        case .previewFailed: return "Unable to preview this TON Connect request."
        case .outcomeUnknown: return "This operation may already have been signed or sent. It will not be signed again. Check the wallet history."
        case .walletBusy: return "Another wallet operation is still pending."
        }
    }
}

@available(macOS 10.15, *)
public struct TonConnectManifestInfo: Codable, Equatable, Sendable {
    public let url: String
    public let name: String
    public let iconUrl: String
    public let domain: String

    init(_ value: TonConnectManifest) {
        self.url = value.url
        self.name = value.name
        self.iconUrl = value.iconUrl
        self.domain = value.domain
    }
}

@available(macOS 10.15, *)
public enum TonConnectReturnTarget: Codable, Equatable, Sendable {
    case back, none, url(String)
}

/// Only routing metadata is decoded here. Rust validates the complete connect request.
@available(macOS 10.15, *)
public struct TonConnectLink: Equatable, Sendable {
    public let value: String
    public let peerId: String
    public let request: String?
    public let returnTarget: TonConnectReturnTarget

    public init(_ value: String) throws {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.utf8.count <= 256 * 1024,
              let url = URLComponents(string: value),
              let scheme = url.scheme?.lowercased(),
              url.user == nil, url.password == nil, url.fragment == nil,
              scheme == "tc" || (scheme == "tg" && url.host?.lowercased() == "ton-connect")
                || (scheme == "https" && url.path.lowercased().split(separator: "/").last == "ton-connect") else {
            throw TonConnectFailure.invalidLink
        }
        var routingURL = url
        routingURL.percentEncodedQuery = url.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%20")
        var fields: [String: String] = [:]
        for item in routingURL.queryItems ?? [] where ["id", "v", "r", "ret", "e", "trace_id"].contains(item.name) {
            guard fields[item.name] == nil, let value = item.value else { throw TonConnectFailure.invalidLink }
            fields[item.name] = value
        }
        guard let peer = fields["id"], peer.utf8.count == 64,
              peer.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }),
              fields["v"] == nil || fields["v"] == "2" else { throw TonConnectFailure.invalidLink }
        if let request = fields["r"] {
            guard !request.isEmpty, fields["v"] == "2" else { throw TonConnectFailure.invalidLink }
        } else if fields["e"] != nil {
            throw TonConnectFailure.invalidLink
        }
        let target: TonConnectReturnTarget
        switch fields["ret"] {
        case nil, "back": target = .back
        case "none": target = .none
        case let .some(value):
            guard let targetURL = URL(string: value), let targetScheme = targetURL.scheme?.lowercased(),
                  !["file", "data", "javascript"].contains(targetScheme) else { throw TonConnectFailure.invalidLink }
            target = .url(value)
        }
        self.value = value
        self.peerId = peer.lowercased()
        self.request = fields["r"]
        self.returnTarget = target
    }
}

@available(macOS 10.15, *)
public enum TonConnectPreview: Sendable {
    case send(SendPreview)
    case sign(SignMessagePreview)
}

@available(macOS 10.15, *)
public struct TonConnectInteraction: Sendable {
    public enum Content: Sendable {
        case connect(TonConnectConnectPrompt)
        case operation(TonConnectIncomingRequest, TonConnectPreview)
    }
    public let id: String
    public let sessionId: String
    public let manifest: TonConnectManifestInfo
    public let content: Content
}

@available(macOS 10.15, *)
public struct TonConnectDecision: Equatable, Sendable {
    public let approved: Bool
    public let deliveryPending: Bool
    public let failure: TonConnectFailure?
    public let returnTarget: TonConnectReturnTarget
}

@available(macOS 10.15, *)
public struct TonConnectSessionInfo: Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        case connecting, connected, disconnecting
    }
    public let id: String
    public let manifest: TonConnectManifestInfo?
    public let status: Status
    public let deliveryPending: Bool
    public let error: TonConnectFailure?
}

@available(macOS 10.15, *)
public struct TonConnectActiveInteraction: Sendable {
    public enum Status: Equatable, Sendable {
        case ready, processing, completed(TonConnectDecision), invalidated
    }
    public let interaction: TonConnectInteraction
    public var status: Status
}

@available(macOS 10.15, *)
public struct TonConnectServiceState: Sendable {
    public let revision: UInt64
    public let sessions: [TonConnectSessionInfo]
    public let active: TonConnectActiveInteraction?
    public let presentationEnabled: Bool
    public let diagnostic: TonConnectDiagnostic?
}

@available(macOS 10.15, *)
public struct TonConnectDiagnostic: Equatable, Sendable {
    public let id: UUID
    public let failure: TonConnectFailure
    public init(id: UUID, failure: TonConnectFailure) { self.id = id; self.failure = failure }
}

@available(macOS 10.15, *)
public struct TonConnectStoredSession: Codable, Sendable {
    public let version: Int
    public let id: String
    public let wallet: TonConnectWalletIdentity
    public let peerId: String
    public let connectRequest: String
    public var returnTarget: TonConnectReturnTarget
    public var manifest: TonConnectManifestInfo?
    public var rustSession: String
    public var requestOrder: [String]
    public var executingRequestId: String?
    public var disconnectRequested: Bool

    init(id: String, wallet: TonConnectWalletIdentity, link: TonConnectLink, rustSession: String) {
        self.version = 1
        self.id = id
        self.wallet = wallet
        self.peerId = link.peerId
        self.connectRequest = link.request ?? ""
        self.returnTarget = link.returnTarget
        self.rustSession = rustSession
        self.requestOrder = []
        self.disconnectRequested = false
    }
}

@available(macOS 10.15, *)
public protocol TonConnectSessionStorage: Sendable {
    func loadSessions(recordId: String) async throws -> [Data]
    func saveSession(_ data: Data, recordId: String, sessionId: String) async throws
    func removeSession(recordId: String, sessionId: String) async throws
}

@available(macOS 10.15, *)
public protocol TonConnectWalletExecutor: Sendable {
    func account(for wallet: TonConnectWalletIdentity) async throws -> TonConnectAccountInfo
    func signProof(wallet: TonConnectWalletIdentity, domain: String, timestamp: UInt64, payload: String) async throws -> TonConnectProofSignature
    func preview(wallet: TonConnectWalletIdentity, request: TonConnectIncomingRequest) async throws -> TonConnectPreview
    /// Returns only accepted engine outcomes. Implementations must retain the original request and force=false.
    func execute(wallet: TonConnectWalletIdentity, request: TonConnectIncomingRequest) async throws -> TonConnectSignedResult
}

@available(macOS 10.15, *)
public enum TonConnectSignedResult: Sendable {
    case send(String)
    case sign(String)
}

@available(macOS 10.15, *)
public protocol TonConnectTransport: Sendable {
    func loadManifest(from url: String) async throws -> String
    func post(_ post: TonConnectPreparedPost) async throws
    func stream(from url: String, onChunk: @escaping @Sendable (Data) async throws -> Void) async throws
}

@available(macOS 10.15, *)
public protocol TonConnectClock: Sendable {
    var now: UInt64 { get }
    func sleep(seconds: Double) async throws
}

@available(macOS 10.15, *)
public struct TonConnectSystemClock: TonConnectClock {
    public init() {}
    public var now: UInt64 { UInt64(max(0, Date().timeIntervalSince1970)) }
    public func sleep(seconds: Double) async throws {
        try await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
    }
}

@available(macOS 10.15, *)
extension TonConnectIncomingRequest {
    var requestId: String {
        switch self {
        case let .sendTransaction(id, _, _), let .signMessage(id, _, _),
             let .disconnect(id, _), let .unsupported(id, _, _, _): return id
        }
    }
}
