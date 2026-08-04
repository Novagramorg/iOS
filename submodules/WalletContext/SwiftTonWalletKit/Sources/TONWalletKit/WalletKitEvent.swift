import Foundation
import TONConnect

/// Something the app needs to act on or show.
///
/// One stream rather than the reference's six registerable callbacks. That design existed to
/// let the JS bridge enable event types dynamically — `getEnabledEventTypes()` returned only
/// the types with a callback attached, and the bridge subscribed accordingly. With a single
/// consumer there is nothing to enable: the app switches on the case it cares about.
public enum WalletKitEvent: Sendable {
    /// A dApp wants to connect. Nothing has been persisted yet — approving creates the
    /// session, rejecting discards it.
    case connectionRequest(ConnectionRequest)
    case sendTransactionRequest(SendTransactionRequest)
    case signMessageRequest(SignMessageRequest)
    case signDataRequest(SignDataRequest)
    /// A dApp ended the connection. The session is already gone by the time this arrives;
    /// the app only needs to update its UI.
    case disconnected(DisconnectRequest)
    /// A request arrived that could not be parsed. Already rejected back to the dApp — this
    /// is for logging and for showing the user that a dApp is misbehaving.
    case malformedRequest(MalformedRequest)
    /// The bridge connection is having trouble. Not fatal: the client reconnects on its own.
    /// Surfaced so the app can show a "reconnecting" state rather than appearing frozen.
    case bridgeTrouble(sessionIDs: [String], description: String)
}

/// How the kit behaves.
public struct WalletKitConfiguration: Sendable {
    /// What the wallet tells dApps about itself. Shown on their connection screens.
    public let deviceInfo: DeviceInfo
    /// Host-level capability restriction. Nil advertises every feature supported by the
    /// wallet contract; a host can provide a smaller set without risking over-advertising.
    public let advertisedFeatures: [Feature]?
    /// Bridge to use when a connect link does not name one.
    public let defaultBridgeURL: URL
    /// How long a signed transfer stays valid, seconds. Short enough that an unsent
    /// signature expires rather than landing hours later; long enough to survive a slow
    /// network and a user reading the sheet.
    public let transferValidityWindow: UInt32
    /// Drop sessions unused for longer than this. Nil keeps them forever.
    public let sessionInactivityLimit: TimeInterval?
    /// Emulate transfers before showing them. Turning this off means the user approves
    /// without a preview, so it defaults on.
    public let emulateBeforeApproval: Bool
    /// Sign but do not broadcast. For tests and for a host app that broadcasts itself.
    public let skipBroadcast: Bool

    public init(
        deviceInfo: DeviceInfo,
        advertisedFeatures: [Feature]? = nil,
        defaultBridgeURL: URL = URL(string: "https://bridge.tonapi.io/bridge")!,
        transferValidityWindow: UInt32 = 300,
        sessionInactivityLimit: TimeInterval? = nil,
        emulateBeforeApproval: Bool = true,
        skipBroadcast: Bool = false
    ) {
        self.deviceInfo = deviceInfo
        self.advertisedFeatures = advertisedFeatures
        self.defaultBridgeURL = defaultBridgeURL
        self.transferValidityWindow = transferValidityWindow
        self.sessionInactivityLimit = sessionInactivityLimit
        self.emulateBeforeApproval = emulateBeforeApproval
        self.skipBroadcast = skipBroadcast
    }
}

/// What the wallet signs for a TON Proof, when the app supplies it rather than letting the
/// kit sign.
///
/// Exists for wallets whose keys live somewhere the kit cannot reach synchronously — a
/// hardware device, or a flow where the user authenticates separately.
public struct ProvidedProof: Sendable {
    public let timestamp: UInt64
    public let domainLengthBytes: UInt32
    public let domainValue: String
    public let payload: String
    /// Base64.
    public let signature: String

    public init(
        timestamp: UInt64,
        domainLengthBytes: UInt32,
        domainValue: String,
        payload: String,
        signature: String
    ) {
        self.timestamp = timestamp
        self.domainLengthBytes = domainLengthBytes
        self.domainValue = domainValue
        self.payload = payload
        self.signature = signature
    }

    var reply: TonProofItemReply {
        TonProofItemReply(
            proof: .init(
                timestamp: timestamp,
                domain: .init(lengthBytes: domainLengthBytes, value: domainValue),
                payload: payload,
                signature: signature
            )
        )
    }
}
