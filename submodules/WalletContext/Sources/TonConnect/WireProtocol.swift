import Foundation
import TelegramCore
import WalletEngineFFI

@available(macOS 10.15, *)
public struct TonConnectWalletIdentity: Equatable, Codable, Sendable {
    public let recordId: String
    public let address: String
    public let network: String
    public let publicKey: Data

    public init(recordId: String, address: String, network: String, publicKey: Data) {
        self.recordId = recordId
        self.address = address
        self.network = network
        self.publicKey = publicKey
    }
}

@available(macOS 10.15, *)
public enum TonConnectFailure: Error, Equatable, Sendable {
    case unavailable, invalidLink, conflictingLink
    case invalidManifest, wrongNetwork
    case bridgeUnavailable, outcomeUnknown
    case keyMismatch, expired, handledElsewhere

    public var message: String {
        switch self {
        case .unavailable: return "This TON Connect request is no longer available."
        case .invalidLink: return "This TON Connect link is invalid."
        case .conflictingLink: return "This app is already using a different connection request. Reconnect from the app."
        case .invalidManifest: return "Unable to load a valid manifest for this app."
        case .wrongNetwork: return "This app requested a different wallet network."
        case .bridgeUnavailable: return "The TON Connect response is waiting for network delivery."
        case .outcomeUnknown: return "This operation may already have been signed or sent. It will not be signed again. Check the wallet history."
        case .keyMismatch: return "This connection belongs to a different wallet key."
        case .expired: return "This TON Connect request has expired."
        case .handledElsewhere: return "This request was handled on another device."
        }
    }
}

@available(macOS 10.15, *)
public struct TonConnectManifestInfo: Equatable, Sendable {
    public let url: String
    public let name: String
    public let icon: WalletTonConnectIcon?
    public let domain: String

    init(_ value: WalletTonConnectManifest) {
        self.url = value.url
        self.name = value.name
        self.icon = value.icon
        if let url = URLComponents(string: value.url), let host = url.url?.host?.lowercased() {
            let defaultPort: Int? = url.scheme?.lowercased() == "https" ? 443 : (url.scheme?.lowercased() == "http" ? 80 : nil)
            if let port = url.port, port != defaultPort {
                self.domain = "\(host):\(port)"
            } else {
                self.domain = host
            }
        } else {
            self.domain = ""
        }
    }
}

@available(macOS 10.15, *)
public enum TonConnectReturnTarget: Equatable, Codable, Sendable {
    case back, none, url(String)
}

@available(macOS 10.15, *)
public struct TonConnectDecision: Equatable, Sendable {
    public let approved: Bool
    public let failure: TonConnectFailure?
    public let returnTarget: TonConnectReturnTarget
}

@available(macOS 10.15, *)
public struct TonConnectSessionInfo: Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        case connecting, connected, disconnecting
    }
    public let id: Int64
    public let manifest: TonConnectManifestInfo?
    public let status: Status
    public let error: TonConnectFailure?
}

@available(macOS 10.15, *)
public enum TonConnectRequestStatus: Equatable, Sendable {
    case ready, processing, completed(TonConnectDecision), invalidated
}

@available(macOS 10.15, *)
public struct TonConnectDiagnostic: Equatable, Sendable {
    public let id: UUID
    public let failure: TonConnectFailure
    public let requestId: String?
    public init(id: UUID, failure: TonConnectFailure, requestId: String? = nil) {
        self.id = id
        self.failure = failure
        self.requestId = requestId
    }
}

@available(macOS 10.15, *)
enum TonConnectJSONValue: Decodable {
    case object([String: TonConnectJSONValue]), array([TonConnectJSONValue]), string(String)
    case integer(Int64), unsigned(UInt64), decimal(Double), bool(Bool), null

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() { self = .null }
        else if let v = try? value.decode(Bool.self) { self = .bool(v) }
        else if let v = try? value.decode(String.self) { self = .string(v) }
        else if let v = try? value.decode(Int64.self) { self = .integer(v) }
        else if let v = try? value.decode(UInt64.self) { self = .unsigned(v) }
        else if let v = try? value.decode(Double.self) { self = .decimal(v) }
        else if let v = try? value.decode([String: Self].self) { self = .object(v) }
        else { self = .array(try value.decode([Self].self)) }
    }

    var object: [String: Self]? { if case let .object(v) = self { return v }; return nil }
    var string: String? { if case let .string(v) = self { return v }; return nil }
    var array: [Self]? { if case let .array(v) = self { return v }; return nil }
}

@available(macOS 10.15, *)
public struct TonConnectRequestId: Equatable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init(_ value: String) throws {
        guard (1 ... 100).contains(value.utf8.count), value.utf8.allSatisfy({ (0x20 ... 0x7e).contains($0) }) else { throw TonConnectWireFailure(code: .badRequest) }
        self.rawValue = value
    }

    public init(from decoder: Decoder) throws { try self.init(decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

@available(macOS 10.15, *)
public enum TonConnectWireErrorCode: Int, Codable, Sendable {
    case unknown = 0, badRequest = 1, manifestNotFound = 2, invalidManifest = 3, unknownApp = 100, userDeclined = 300, methodNotSupported = 400

    init(_ code: TonConnectRpcErrorCode) {
        switch code {
        case .unknown: self = .unknown
        case .badRequest: self = .badRequest
        case .unknownApp: self = .unknownApp
        case .userDeclined: self = .userDeclined
        case .methodNotSupported: self = .methodNotSupported
        }
    }

    var engineCode: TonConnectRpcErrorCode {
        get throws {
            switch self {
            case .unknown: return .unknown
            case .badRequest: return .badRequest
            case .unknownApp: return .unknownApp
            case .userDeclined: return .userDeclined
            case .methodNotSupported: return .methodNotSupported
            case .manifestNotFound, .invalidManifest: throw TonConnectFailure.invalidLink
            }
        }
    }

    public var message: String {
        switch self {
        case .unknown: return "Unknown error"
        case .badRequest: return "Bad request"
        case .manifestNotFound: return "Manifest not found"
        case .invalidManifest: return "Invalid manifest"
        case .unknownApp: return "Unknown app"
        case .userDeclined: return "User declined the request"
        case .methodNotSupported: return "Method not supported"
        }
    }
}

@available(macOS 10.15, *)
public struct TonConnectWireFailure: Error, Equatable, Sendable {
    public let requestId: TonConnectRequestId?
    public let code: TonConnectWireErrorCode
    public let message: String

    public init(requestId: TonConnectRequestId? = nil, code: TonConnectWireErrorCode, message: String? = nil) {
        self.requestId = requestId
        self.code = code
        self.message = message ?? code.message
    }
}

@available(macOS 10.15, *)
public enum TonConnectWireRequest: Sendable {
    case sendTransaction(id: TonConnectRequestId, request: SendRequest)
    case signData(id: TonConnectRequestId, payload: TonConnectSignDataPayload)
    case disconnect(id: TonConnectRequestId)

    public var id: TonConnectRequestId {
        switch self {
        case let .sendTransaction(id, _), let .signData(id, _), let .disconnect(id): return id
        }
    }

    public var validUntil: UInt64? {
        let expiration: SendExpiration
        switch self {
        case let .sendTransaction(_, request): expiration = request.intent.expiration
        default: return nil
        }
        if case let .exact(value) = expiration { return value }
        return nil
    }

    var consumesWalletSequenceNumber: Bool {
        switch self {
        case .sendTransaction: return true
        default: return false
        }
    }
}

@available(macOS 10.15, *)
public struct TonConnectConnectRequest: Equatable, Sendable {
    public let prompt: TonConnectConnectPrompt
    public let itemNames: [String]

    public init(_ data: Data) throws {
        let object = try TonConnectWireCodec.object(data)
        try TonConnectWireCodec.keys(object, allowed: ["manifestUrl", "items"])
        guard let manifest = object["manifestUrl"]?.string, let url = URLComponents(string: manifest),
              url.scheme?.lowercased() == "https", url.host?.isEmpty == false,
              url.user == nil, url.password == nil, url.fragment == nil,
              let items = object["items"]?.array, !items.isEmpty else { throw TonConnectWireFailure(code: .badRequest) }
        var network: String?
        var proof: String?
        var names: [String] = []
        for item in items {
            guard let item = item.object, let name = item["name"]?.string, !name.isEmpty,
                  !names.contains(name) else { throw TonConnectWireFailure(code: .badRequest) }
            names.append(name)
            switch name {
            case "ton_addr":
                try TonConnectWireCodec.keys(item, allowed: ["name", "network"])
                network = try TonConnectWireCodec.optionalString(item, "network")
                if let network { try TonConnectWireCodec.validateNetwork(network) }
            case "ton_proof":
                try TonConnectWireCodec.keys(item, allowed: ["name", "payload"])
                guard let payload = item["payload"]?.string else { throw TonConnectWireFailure(code: .badRequest) }
                proof = payload
            default: throw TonConnectFailure.invalidLink
            }
        }
        guard names.contains("ton_addr") else { throw TonConnectWireFailure(code: .badRequest) }
        if proof != nil { _ = try TonConnectWireCodec.proofDomain(manifestUrl: manifest) }
        self.prompt = TonConnectConnectPrompt(manifestUrl: manifest, requestedNetwork: network, proofPayload: proof)
        self.itemNames = names
    }
}

@available(macOS 10.15, *)
public enum TonConnectWireCodec {
    public static let maximumPacketBytes = 1024 * 1024

    static func proofDomain(manifestUrl: String) throws -> String {
        guard let url = URLComponents(string: manifestUrl), url.scheme?.lowercased() == "https",
              let host = url.url?.host?.lowercased(), !host.isEmpty,
              url.user == nil, url.password == nil, url.fragment == nil else { throw TonConnectFailure.invalidLink }
        let domain = host.replacingOccurrences(of: "\\.+$", with: "", options: .regularExpression)
        guard !domain.isEmpty, domain != "telegram.org" else { throw TonConnectFailure.invalidLink }
        return domain
    }

    static func object(_ data: Data) throws -> [String: TonConnectJSONValue] {
        guard !data.isEmpty, data.count <= self.maximumPacketBytes else { throw TonConnectWireFailure(code: .badRequest) }
        var structure = TonConnectJSONStructure(data)
        try structure.validate()
        guard
              let value = try? JSONDecoder().decode(TonConnectJSONValue.self, from: data), let object = value.object else {
            throw TonConnectWireFailure(code: .badRequest)
        }
        return object
    }

    static func keys(_ object: [String: TonConnectJSONValue], allowed: Set<String>) throws {
        guard Set(object.keys).isSubset(of: allowed) else { throw TonConnectWireFailure(code: .badRequest) }
    }

    static func optionalString(_ object: [String: TonConnectJSONValue], _ key: String) throws -> String? {
        guard let value = object[key] else { return nil }
        guard let string = value.string else { throw TonConnectWireFailure(code: .badRequest) }
        return string
    }

    static func validateNetwork(_ value: String) throws {
        guard let network = Int32(value), String(network) == value else { throw TonConnectWireFailure(code: .badRequest) }
    }
}

/// Reject duplicate keys (including escaped aliases) before JSONDecoder discards them.
@available(macOS 10.15, *)
private struct TonConnectJSONStructure {
    private let bytes: [UInt8]
    private var offset = 0

    init(_ data: Data) { self.bytes = Array(data) }

    mutating func validate() throws {
        try self.value(depth: 0)
        self.whitespace()
        guard self.offset == self.bytes.count else { throw TonConnectWireFailure(code: .badRequest) }
    }

    private mutating func value(depth: Int) throws {
        self.whitespace()
        guard depth <= 64, self.offset < self.bytes.count else { throw TonConnectWireFailure(code: .badRequest) }
        switch self.bytes[self.offset] {
        case 123: // object
            self.offset += 1
            self.whitespace()
            if self.consume(125) { return }
            var keys = Set<String>()
            while true {
                self.whitespace()
                let key = try self.string()
                guard keys.insert(key).inserted else { throw TonConnectWireFailure(code: .badRequest) }
                self.whitespace()
                guard self.consume(58) else { throw TonConnectWireFailure(code: .badRequest) }
                try self.value(depth: depth + 1)
                self.whitespace()
                if self.consume(125) { return }
                guard self.consume(44) else { throw TonConnectWireFailure(code: .badRequest) }
            }
        case 91: // array
            self.offset += 1
            self.whitespace()
            if self.consume(93) { return }
            while true {
                try self.value(depth: depth + 1)
                self.whitespace()
                if self.consume(93) { return }
                guard self.consume(44) else { throw TonConnectWireFailure(code: .badRequest) }
            }
        case 34: _ = try self.string()
        default:
            let start = self.offset
            while self.offset < self.bytes.count, ![9, 10, 13, 32, 44, 93, 125].contains(self.bytes[self.offset]) { self.offset += 1 }
            guard self.offset > start else { throw TonConnectWireFailure(code: .badRequest) }
        }
    }

    private mutating func string() throws -> String {
        let start = self.offset
        guard self.consume(34) else { throw TonConnectWireFailure(code: .badRequest) }
        while self.offset < self.bytes.count {
            let byte = self.bytes[self.offset]
            self.offset += 1
            if byte == 92 {
                guard self.offset < self.bytes.count else { throw TonConnectWireFailure(code: .badRequest) }
                self.offset += 1
            } else if byte == 34 {
                guard let value = try? JSONDecoder().decode(String.self, from: Data(self.bytes[start ..< self.offset])) else { throw TonConnectWireFailure(code: .badRequest) }
                return value
            }
        }
        throw TonConnectWireFailure(code: .badRequest)
    }

    private mutating func whitespace() {
        while self.offset < self.bytes.count, [9, 10, 13, 32].contains(self.bytes[self.offset]) { self.offset += 1 }
    }

    private mutating func consume(_ byte: UInt8) -> Bool {
        guard self.offset < self.bytes.count, self.bytes[self.offset] == byte else { return false }
        self.offset += 1
        return true
    }
}
