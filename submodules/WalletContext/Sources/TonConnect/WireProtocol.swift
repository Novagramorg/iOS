import Foundation
import TelegramCore
import WalletEngineFFI

@available(macOS 10.15, *)
public struct TonConnectWalletIdentity: Equatable, Sendable {
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
    public let iconUrl: String
    public let domain: String

    init(_ value: WalletTonConnectManifest) {
        self.url = value.url
        self.name = value.name
        self.iconUrl = value.iconUrl
        self.domain = URL(string: value.url)?.host?.lowercased() ?? ""
    }
}

@available(macOS 10.15, *)
public enum TonConnectReturnTarget: Equatable, Sendable {
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

/// JSON values retained without a floating-point round trip for protocol integers.
@available(macOS 10.15, *)
public enum TonConnectJSONValue: Codable, Equatable, Sendable {
    case object([String: TonConnectJSONValue]), array([TonConnectJSONValue]), string(String)
    case integer(Int64), unsigned(UInt64), decimal(Double), bool(Bool), null

    public init(from decoder: Decoder) throws {
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

    public func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case let .object(v): try value.encode(v)
        case let .array(v): try value.encode(v)
        case let .string(v): try value.encode(v)
        case let .integer(v): try value.encode(v)
        case let .unsigned(v): try value.encode(v)
        case let .decimal(v): try value.encode(v)
        case let .bool(v): try value.encode(v)
        case .null: try value.encodeNil()
        }
    }

    var object: [String: Self]? { if case let .object(v) = self { return v }; return nil }
    var string: String? { if case let .string(v) = self { return v }; return nil }
    var array: [Self]? { if case let .array(v) = self { return v }; return nil }
    var uint64: UInt64? {
        switch self {
        case let .integer(v): return UInt64(exactly: v)
        case let .unsigned(v): return v
        default: return nil
        }
    }
}

@available(macOS 10.15, *)
public struct TonConnectRequestId: Equatable, Hashable, Codable, Sendable {
    public let rawValue: String
    public let apiValue: Int64

    public init(_ value: String) throws {
        guard !value.isEmpty, value.utf8.allSatisfy({ (48 ... 57).contains($0) }),
              let apiValue = Int64(value) else { throw TonConnectWireFailure(code: .badRequest) }
        self.rawValue = value
        self.apiValue = apiValue
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
    case signMessage(id: TonConnectRequestId, request: SignMessageRequest)
    case signData(id: TonConnectRequestId, payload: TonConnectSignDataPayload)
    case disconnect(id: TonConnectRequestId)
    case unsupported(id: TonConnectRequestId, method: String)

    public var id: TonConnectRequestId {
        switch self {
        case let .sendTransaction(id, _), let .signMessage(id, _), let .signData(id, _),
             let .disconnect(id), let .unsupported(id, _): return id
        }
    }

    public var validUntil: UInt64? {
        let expiration: SendExpiration
        switch self {
        case let .sendTransaction(_, request): expiration = request.intent.expiration
        case let .signMessage(_, request): expiration = request.intent.expiration
        default: return nil
        }
        if case let .exact(value) = expiration { return value }
        return nil
    }

    var consumesWalletSequenceNumber: Bool {
        switch self {
        case .sendTransaction, .signMessage: return true
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
            default: break
            }
        }
        guard names.contains("ton_addr") else { throw TonConnectWireFailure(code: .badRequest) }
        self.prompt = TonConnectConnectPrompt(manifestUrl: manifest, requestedNetwork: network, proofPayload: proof)
        self.itemNames = names
    }
}

@available(macOS 10.15, *)
public enum TonConnectWireCodec {
    public static let maximumPacketBytes = 1024 * 1024

    public static func decodeRequest(_ data: Data, wallet: TonConnectWalletIdentity, now: UInt64, operationId: String) throws -> TonConnectWireRequest {
        let object = try self.object(data)
        guard let rawId = object["id"]?.string else { throw TonConnectWireFailure(code: .badRequest) }
        let id = try TonConnectRequestId(rawId)
        do {
            try self.keys(object, allowed: ["id", "method", "params"])
            guard let method = object["method"]?.string, !method.isEmpty,
                  let params = object["params"]?.array, params.allSatisfy({ $0.string != nil }) else {
                throw TonConnectWireFailure(code: .badRequest)
            }
            switch method {
            case "sendTransaction", "signMessage":
                guard params.count == 1, !operationId.isEmpty else { throw TonConnectWireFailure(code: .badRequest) }
                let payload = try self.object(Data(params[0].string!.utf8))
                let intent = try self.transfer(payload, wallet: wallet, now: now)
                if method == "sendTransaction" { return .sendTransaction(id: id, request: SendRequest(operationId: operationId, force: false, intent: intent)) }
                return .signMessage(id: id, request: SignMessageRequest(operationId: operationId, force: false, intent: intent))
            case "signData":
                guard params.count == 1 else { throw TonConnectWireFailure(code: .badRequest) }
                let payload = try TonConnectSignDataPayload(Data(params[0].string!.utf8))
                try self.validateContext(payload.fields, wallet: wallet)
                return .signData(id: id, payload: payload)
            case "disconnect":
                guard params.isEmpty else { throw TonConnectWireFailure(code: .badRequest) }
                return .disconnect(id: id)
            default: return .unsupported(id: id, method: method)
            }
        } catch let failure as TonConnectWireFailure {
            throw TonConnectWireFailure(requestId: id, code: failure.code, message: failure.message)
        } catch {
            throw TonConnectWireFailure(requestId: id, code: .badRequest)
        }
    }

    public static func successResponse(id: TonConnectRequestId, result: TonConnectJSONValue) throws -> Data {
        try self.encode(.object(["id": .string(id.rawValue), "result": result]))
    }

    public static func errorResponse(id: TonConnectRequestId, code: TonConnectWireErrorCode, message: String? = nil) throws -> Data {
        try self.encode(.object(["id": .string(id.rawValue), "error": self.error(code, message: message)]))
    }

    public static func disconnectEvent(serverEventId: Int64) throws -> Data {
        try self.event("disconnect", id: serverEventId, payload: .object([:]))
    }

    public static func connectErrorEvent(serverEventId: Int64, code: TonConnectWireErrorCode, message: String? = nil) throws -> Data {
        try self.event("connect_error", id: serverEventId, payload: self.error(code, message: message))
    }

    public static func connectEvent(serverEventId: Int64, request: TonConnectConnectRequest, account: TonConnectAccountInfo,
                                    domain: String, timestamp: UInt64, proof: TonConnectProofSignature?, appName: String, appVersion: String, platform: String = "iphone") throws -> Data {
        guard account.publicKey.count == 32, !appName.isEmpty, !appVersion.isEmpty,
              request.prompt.requestedNetwork == nil || request.prompt.requestedNetwork == account.network else { throw TonConnectWireFailure(code: .badRequest) }
        let rawAddress = try parseTonAddress(value: account.address).raw
        try self.validateNetwork(account.network)
        _ = try self.canonicalBoc(account.walletStateInit)
        var items: [TonConnectJSONValue] = []
        for name in request.itemNames {
            switch name {
            case "ton_addr":
                items.append(.object(["name": .string(name), "address": .string(rawAddress), "network": .string(account.network),
                    "walletStateInit": .string(account.walletStateInit), "publicKey": .string(account.publicKey.map { String(format: "%02x", $0) }.joined())]))
            case "ton_proof":
                guard let proof, proof.signature.count == 64, let payload = request.prompt.proofPayload else { throw TonConnectWireFailure(code: .badRequest) }
                items.append(.object(["name": .string(name), "proof": .object([
                    "timestamp": .string(String(timestamp)), "domain": .object(["lengthBytes": .unsigned(UInt64(domain.utf8.count)), "value": .string(domain)]),
                    "payload": .string(payload), "signature": .string(proof.signature.base64EncodedString())])]))
            default: items.append(.object(["name": .string(name), "error": self.error(.methodNotSupported)]))
            }
        }
        let features: [TonConnectJSONValue] = [
            .object(["name": .string("SendTransaction"), "maxMessages": .integer(255), "extraCurrencySupported": .bool(false)]),
            .object(["name": .string("SignMessage"), "maxMessages": .integer(255), "extraCurrencySupported": .bool(false)]),
            .object(["name": .string("SignData"), "types": .array([.string("text"), .string("binary"), .string("cell")])])
        ]
        return try self.event("connect", id: serverEventId, payload: .object(["items": .array(items), "device": .object([
            "platform": .string(platform), "appName": .string(appName), "appVersion": .string(appVersion),
            "maxProtocolVersion": .integer(2), "features": .array(features)])]))
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

    static func encode(_ value: TonConnectJSONValue) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(value)
        guard data.count <= self.maximumPacketBytes else { throw TonConnectWireFailure(code: .badRequest) }
        return data
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

    static func validateContext(_ object: [String: TonConnectJSONValue], wallet: TonConnectWalletIdentity) throws {
        if let network = try self.optionalString(object, "network") {
            try self.validateNetwork(network)
            guard network == wallet.network else { throw TonConnectWireFailure(code: .badRequest, message: "Network differs from the connected wallet") }
        }
        if let from = try self.optionalString(object, "from") {
            guard try parseTonAddress(value: from).raw == parseTonAddress(value: wallet.address).raw else {
                throw TonConnectWireFailure(code: .badRequest, message: "Sender differs from the connected wallet")
            }
        }
    }

    static func canonicalBase64(_ value: String) throws -> Data {
        guard let data = Data(base64Encoded: value), data.base64EncodedString() == value else { throw TonConnectWireFailure(code: .badRequest) }
        return data
    }

    static func canonicalBoc(_ value: String) throws -> Data {
        let data = try self.canonicalBase64(value)
        _ = try WalletBoc(data)
        return data
    }

    private static func transfer(_ object: [String: TonConnectJSONValue], wallet: TonConnectWalletIdentity, now: UInt64) throws -> SendIntent {
        try self.keys(object, allowed: ["valid_until", "network", "from", "messages"])
        try self.validateContext(object, wallet: wallet)
        var expiration: SendExpiration = .engineDefault
        if let value = object["valid_until"] {
            guard let timestamp = value.uint64, timestamp > now else { throw TonConnectWireFailure(code: .badRequest, message: "Request has expired or has an invalid expiration") }
            expiration = .exact(unixTimestamp: timestamp)
        }
        guard let messages = object["messages"]?.array, (1 ... 255).contains(messages.count) else { throw TonConnectWireFailure(code: .badRequest) }
        let outgoing = try messages.map { value -> SendMessage in
            guard let item = value.object else { throw TonConnectWireFailure(code: .badRequest) }
            try self.keys(item, allowed: ["address", "amount", "payload", "stateInit"])
            guard let address = item["address"]?.string, let amount = item["amount"]?.string,
                  !amount.isEmpty, amount.utf8.allSatisfy({ (48 ... 57).contains($0) }),
                  amount == "0" || amount.first != "0" else { throw TonConnectWireFailure(code: .badRequest) }
            let parsed = try parseTonAddress(value: address)
            guard case let .userFriendly(bounceable, testnet) = parsed.format, !testnet || wallet.network != "-239" else { throw TonConnectWireFailure(code: .badRequest) }
            let payload = try self.optionalString(item, "payload")
            let stateInit = try self.optionalString(item, "stateInit")
            if let payload { _ = try self.canonicalBoc(payload) }
            if let stateInit { _ = try self.canonicalBoc(stateInit) }
            return SendMessage(destination: address, amount: .exact(nanograms: amount), body: payload.map { .rawPayload(boc: $0) } ?? .empty, bounce: bounceable, stateInit: stateInit)
        }
        return SendIntent(expiration: expiration, messages: outgoing)
    }

    private static func error(_ code: TonConnectWireErrorCode, message: String? = nil) -> TonConnectJSONValue {
        .object(["code": .integer(Int64(code.rawValue)), "message": .string(message ?? code.message)])
    }

    private static func event(_ name: String, id: Int64, payload: TonConnectJSONValue) throws -> Data {
        guard id >= 0 else { throw TonConnectWireFailure(code: .badRequest) }
        return try self.encode(.object(["event": .string(name), "id": .integer(id), "payload": payload]))
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
            // JSONDecoder subsequently validates scalar spelling and numeric range.
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
