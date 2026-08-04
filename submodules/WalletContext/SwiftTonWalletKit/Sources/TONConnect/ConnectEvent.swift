import Foundation

/// The wallet's reply to a connect request.
///
/// Separate from ``WalletResponseSuccess`` because connect uses an *event* envelope —
/// `{event, id, payload}` — while RPC methods use `{id, result}`. A dApp receiving the wrong
/// shape treats the connection as failed, so the two must not be conflated.
public struct ConnectEventSuccess: Sendable {
    /// Heterogeneous connect items: an address, optionally a proof.
    public enum Item: Sendable {
        case address(TonAddressItemReply)
        case proof(TonProofItemReply)
    }

    /// Monotonic per-session counter. The protocol carries it as a number, and dApps use it
    /// to discard replies older than one they already processed.
    public let id: UInt64
    public let device: DeviceInfo
    public let items: [Item]

    public init(id: UInt64, device: DeviceInfo, items: [Item]) {
        self.id = id
        self.device = device
        self.items = items
    }
}

extension ConnectEventSuccess: Encodable {
    private enum CodingKeys: String, CodingKey {
        case event, id, payload
    }

    private enum PayloadKeys: String, CodingKey {
        case device, items
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("connect", forKey: .event)
        try container.encode(id, forKey: .id)

        var payload = container.nestedContainer(keyedBy: PayloadKeys.self, forKey: .payload)
        try payload.encode(device, forKey: .device)

        var itemsArray = payload.nestedUnkeyedContainer(forKey: .items)
        for item in items {
            switch item {
            case .address(let reply): try itemsArray.encode(reply)
            case .proof(let reply): try itemsArray.encode(reply)
            }
        }
    }
}

/// The wallet's refusal of a connect request.
public struct ConnectEventError: Encodable, Sendable {
    public struct Payload: Encodable, Sendable {
        public let code: Int
        public let message: String

        public init(code: Int, message: String) {
            self.code = code
            self.message = message
        }
    }

    public let event = "connect_error"
    public let id: UInt64
    public let payload: Payload

    public init(id: UInt64, code: ConnectEventErrorCode, message: String) {
        self.id = id
        self.payload = Payload(code: code.rawValue, message: message)
    }
}

/// The wallet telling a dApp the connection ended from the wallet's side.
///
/// Sent when the *user* disconnects. A dApp-initiated disconnect gets an ordinary RPC reply
/// instead, because the dApp is waiting on the id it sent.
public struct DisconnectEvent: Encodable, Sendable {
    public let event = "disconnect"
    public let id: UInt64
    /// The protocol requires the key with an empty object.
    public let payload: [String: String]

    public init(id: UInt64) {
        self.id = id
        self.payload = [:]
    }
}

/// A `signData` reply.
///
/// The `address` here is **raw** form, matching the connect reply. Sending friendly form
/// fails dApp-side verification, since the dApp reconstructs the signed message from it.
public struct SignDataResponseSuccess: Encodable, Sendable {
    public struct Result: Encodable, Sendable {
        /// Base64 signature.
        public let signature: String
        public let address: String
        public let timestamp: UInt64
        public let domain: String
        /// Echo of the payload that was signed, so the dApp verifies against what the
        /// wallet actually hashed rather than what it believes it sent.
        public let payload: SignDataPayloadEcho

        public init(
            signature: String,
            address: String,
            timestamp: UInt64,
            domain: String,
            payload: SignDataPayloadEcho
        ) {
            self.signature = signature
            self.address = address
            self.timestamp = timestamp
            self.domain = domain
            self.payload = payload
        }
    }

    public let id: String
    public let result: Result

    public init(id: String, result: Result) {
        self.id = id
        self.result = result
    }
}

/// The payload echo in a `signData` reply, in the protocol's tagged-union shape.
public struct SignDataPayloadEcho: Encodable, Sendable {
    public let type: String
    public let text: String?
    public let bytes: String?
    public let cell: String?
    public let schema: String?
    public let network: String?
    public let from: String?

    public static func text(_ value: String, network: String?, from: String?) -> SignDataPayloadEcho {
        SignDataPayloadEcho(type: "text", text: value, bytes: nil, cell: nil, schema: nil, network: network, from: from)
    }

    public static func binary(base64: String, network: String?, from: String?) -> SignDataPayloadEcho {
        SignDataPayloadEcho(type: "binary", text: nil, bytes: base64, cell: nil, schema: nil, network: network, from: from)
    }

    public static func cell(base64: String, schema: String, network: String?, from: String?) -> SignDataPayloadEcho {
        SignDataPayloadEcho(type: "cell", text: nil, bytes: nil, cell: base64, schema: schema, network: network, from: from)
    }
}

/// A `signMessage` reply, which returns a body rather than a broadcast transaction.
public struct SignMessageResponseSuccess: Encodable, Sendable {
    public struct Result: Encodable, Sendable {
        public let internalBoc: String

        public init(internalBoc: String) {
            self.internalBoc = internalBoc
        }
    }

    public let id: String
    public let result: Result

    public init(id: String, internalBoc: String) {
        self.id = id
        self.result = Result(internalBoc: internalBoc)
    }
}
