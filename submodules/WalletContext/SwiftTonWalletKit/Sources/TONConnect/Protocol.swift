import Foundation
import TONCore

// MARK: - Connect

/// What a dApp asks for when it initiates a connection.
public struct ConnectRequest: Codable, Sendable {
    /// URL of the dApp's `tonconnect-manifest.json`, which the wallet fetches to learn who
    /// is asking.
    public let manifestUrl: String
    public let items: [ConnectItem]

    public init(manifestUrl: String, items: [ConnectItem]) {
        self.manifestUrl = manifestUrl
        self.items = items
    }

    /// Whether the dApp asked for proof of address ownership.
    public var requestsProof: Bool {
        items.contains { $0.name == ConnectItem.tonProofName }
    }

    /// The proof challenge the dApp supplied, which must be signed verbatim.
    public var proofPayload: String? {
        items.first { $0.name == ConnectItem.tonProofName }?.payload
    }
}

/// One item in a connect request.
///
/// Modelled as a single struct with an optional payload rather than an enum, because the
/// protocol is open-ended: a wallet must tolerate item names it does not know rather than
/// failing the whole request.
public struct ConnectItem: Codable, Sendable {
    public static let tonAddressName = "ton_addr"
    public static let tonProofName = "ton_proof"

    public let name: String
    /// Present for `ton_proof`.
    public let payload: String?

    public init(name: String, payload: String? = nil) {
        self.name = name
        self.payload = payload
    }

    public static let tonAddress = ConnectItem(name: tonAddressName)
    public static func tonProof(payload: String) -> ConnectItem {
        ConnectItem(name: tonProofName, payload: payload)
    }
}

/// The wallet's self-description, returned on a successful connect.
public struct DeviceInfo: Codable, Sendable {
    public let platform: String
    public let appName: String
    public let appVersion: String
    public let maxProtocolVersion: Int
    /// Capabilities. Encoded as opaque JSON because the shape is a mix of bare strings and
    /// objects, and it grows over time.
    public let features: [Feature]

    public init(
        platform: String,
        appName: String,
        appVersion: String,
        maxProtocolVersion: Int = 2,
        features: [Feature]
    ) {
        self.platform = platform
        self.appName = appName
        self.appVersion = appVersion
        self.maxProtocolVersion = maxProtocolVersion
        self.features = features
    }
}

/// A capability the wallet advertises.
public struct Feature: Codable, Sendable {
    public let name: String
    public let maxMessages: Int?
    public let extraCurrencySupported: Bool?
    /// For `SignData`: which payload types are accepted.
    public let types: [String]?

    public init(
        name: String,
        maxMessages: Int? = nil,
        extraCurrencySupported: Bool? = nil,
        types: [String]? = nil
    ) {
        self.name = name
        self.maxMessages = maxMessages
        self.extraCurrencySupported = extraCurrencySupported
        self.types = types
    }

    public static func sendTransaction(maxMessages: Int, extraCurrency: Bool = true) -> Feature {
        Feature(name: "SendTransaction", maxMessages: maxMessages, extraCurrencySupported: extraCurrency)
    }

    public static func signData(types: [String] = ["text", "binary", "cell"]) -> Feature {
        Feature(name: "SignData", types: types)
    }
}

/// The account details a wallet returns on connect.
public struct TonAddressItemReply: Codable, Sendable {
    public let name: String
    /// Raw form, `workchain:hex` — the protocol specifies raw here, not friendly.
    public let address: String
    /// The network's `global_id` as a string.
    public let network: String
    public let publicKey: String
    /// Base64 state init, so a dApp can verify the address derives from the key.
    public let walletStateInit: String

    public init(address: String, network: String, publicKey: String, walletStateInit: String) {
        self.name = ConnectItem.tonAddressName
        self.address = address
        self.network = network
        self.publicKey = publicKey
        self.walletStateInit = walletStateInit
    }
}

/// A signed proof of address ownership.
public struct TonProofItemReply: Codable, Sendable {
    public struct Proof: Codable, Sendable {
        public let timestamp: UInt64
        public let domain: Domain
        public let payload: String
        /// Base64 ed25519 signature.
        public let signature: String

        public struct Domain: Codable, Sendable {
            public let lengthBytes: UInt32
            public let value: String

            public init(lengthBytes: UInt32, value: String) {
                self.lengthBytes = lengthBytes
                self.value = value
            }
        }

        public init(timestamp: UInt64, domain: Domain, payload: String, signature: String) {
            self.timestamp = timestamp
            self.domain = domain
            self.payload = payload
            self.signature = signature
        }
    }

    public let name: String
    public let proof: Proof

    public init(proof: Proof) {
        self.name = ConnectItem.tonProofName
        self.proof = proof
    }
}

// MARK: - RPC requests

/// A method call from a dApp over the bridge.
public struct AppRequest: Codable, Sendable {
    public let id: String
    public let method: String
    /// Each entry is a JSON string, which the protocol double-encodes.
    public let params: [String]

    public init(id: String, method: String, params: [String]) {
        self.id = id
        self.method = method
        self.params = params
    }

    public enum Method: String, Sendable {
        case sendTransaction
        case signData
        case signMessage
        case disconnect
    }

    public var knownMethod: Method? { Method(rawValue: method) }

    /// Decodes the first parameter, which the protocol carries as a JSON *string* rather
    /// than a nested object.
    public func decodeFirstParam<T: Decodable>(as type: T.Type) throws -> T {
        guard let first = params.first else {
            throw ProtocolError.missingParameter(method: method)
        }
        guard let data = first.data(using: .utf8) else {
            throw ProtocolError.malformedParameter(method: method)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw ProtocolError.parameterDecodingFailed(method: method, underlying: error)
        }
    }
}

/// The `sendTransaction` payload.
public struct SendTransactionParams: Codable, Sendable {
    /// Unix seconds. A request past its deadline must be refused.
    public let validUntil: UInt64?
    /// The dApp's expected network, as a `global_id` string. When present and it disagrees
    /// with the wallet's, the request must be refused rather than signed on the wrong chain.
    public let network: String?
    public let from: String?
    public let messages: [OutgoingMessage]

    public struct OutgoingMessage: Codable, Sendable {
        public let address: String
        /// Nanoton, as a decimal string.
        public let amount: String
        public let payload: String?
        public let stateInit: String?
        public let extraCurrency: [String: String]?

        /// The protocol mixes casing: `extra_currency` is snake_case while `stateInit` is
        /// camelCase. Spelled out rather than left to a key-decoding strategy, which would
        /// get `stateInit` wrong.
        enum CodingKeys: String, CodingKey {
            case address, amount, payload, stateInit
            case extraCurrency = "extra_currency"
        }

        public init(
            address: String,
            amount: String,
            payload: String? = nil,
            stateInit: String? = nil,
            extraCurrency: [String: String]? = nil
        ) {
            self.address = address
            self.amount = amount
            self.payload = payload
            self.stateInit = stateInit
            self.extraCurrency = extraCurrency
        }
    }

    /// `valid_until` is snake_case on the wire. Decoding it as `validUntil` silently yields
    /// nil, which disables the expiry check entirely — an expired request would then be
    /// signed as though it were fresh.
    enum CodingKeys: String, CodingKey {
        case network, from, messages
        case validUntil = "valid_until"
    }

    public init(
        validUntil: UInt64? = nil,
        network: String? = nil,
        from: String? = nil,
        messages: [OutgoingMessage]
    ) {
        self.validUntil = validUntil
        self.network = network
        self.from = from
        self.messages = messages
    }

    /// Whether the request has already expired.
    public func isExpired(now: UInt64) -> Bool {
        guard let validUntil else { return false }
        return validUntil < now
    }
}

// MARK: - Wallet responses

/// A successful RPC reply.
public struct WalletResponseSuccess: Codable, Sendable {
    public let id: String
    public let result: String

    public init(id: String, result: String) {
        self.id = id
        self.result = result
    }
}

/// A failed RPC reply.
public struct WalletResponseError: Codable, Sendable {
    public struct Payload: Codable, Sendable {
        public let code: Int
        public let message: String

        public init(code: Int, message: String) {
            self.code = code
            self.message = message
        }
    }

    public let id: String
    public let error: Payload

    public init(id: String, code: Int, message: String) {
        self.id = id
        self.error = Payload(code: code, message: message)
    }
}

// MARK: - Error codes

/// Errors a wallet may return from a connect request.
public enum ConnectEventErrorCode: Int, Sendable {
    case unknownError = 0
    case badRequest = 1
    case manifestNotFound = 2
    case manifestContent = 3
    case unknownApp = 100
    case userRejects = 300
    case methodNotSupported = 400
}

/// Errors a wallet may return from `sendTransaction`.
public enum SendTransactionErrorCode: Int, Sendable {
    case unknownError = 0
    case badRequest = 1
    case unknownApp = 100
    case userRejects = 300
    case methodNotSupported = 400
}

/// Errors a wallet may return from `signData`.
public enum SignDataErrorCode: Int, Sendable {
    case unknownError = 0
    case badRequest = 1
    case unknownApp = 100
    case userRejects = 300
    case methodNotSupported = 400
}

/// Errors a wallet may return from `disconnect`.
public enum DisconnectErrorCode: Int, Sendable {
    case unknownError = 0
    case badRequest = 1
    case unknownApp = 100
    case methodNotSupported = 400
}

public enum ProtocolError: Error, CustomStringConvertible {
    case missingParameter(method: String)
    case malformedParameter(method: String)
    case parameterDecodingFailed(method: String, underlying: Error)

    public var description: String {
        switch self {
        case .missingParameter(let method):
            return "\(method) request carried no parameters"
        case .malformedParameter(let method):
            return "\(method) parameter is not valid UTF-8"
        case .parameterDecodingFailed(let method, let underlying):
            return "\(method) parameter failed to decode: \(underlying)"
        }
    }
}

extension DeviceInfo {
    /// The same device, advertising a specific wallet's capabilities.
    ///
    /// Features depend on the *contract*, not the app: a V4R2 wallet caps at 4 messages per
    /// transfer while V5R1 reaches 255. Advertising the app-wide value would have a dApp
    /// build a batch the wallet then has to refuse.
    public func withFeatures(_ features: [Feature]) -> DeviceInfo {
        DeviceInfo(
            platform: platform,
            appName: appName,
            appVersion: appVersion,
            maxProtocolVersion: maxProtocolVersion,
            features: features
        )
    }
}
