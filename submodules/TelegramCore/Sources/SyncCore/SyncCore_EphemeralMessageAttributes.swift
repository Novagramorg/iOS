import Foundation
import Postbox

public final class EphemeralMessageAttribute: MessageAttribute {
    public let receiverId: Int64
    public let isWelcomeTemplate: Bool

    public var associatedPeerIds: [PeerId] {
        if self.receiverId == 0 {
            return []
        }
        return [PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(self.receiverId))]
    }

    public init(receiverId: Int64, isWelcomeTemplate: Bool = false) {
        self.receiverId = receiverId
        self.isWelcomeTemplate = isWelcomeTemplate
    }

    required public init(decoder: PostboxDecoder) {
        self.receiverId = decoder.decodeInt64ForKey("r", orElse: 0)
        self.isWelcomeTemplate = decoder.decodeBoolForKey("w", orElse: false)
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.receiverId, forKey: "r")
        encoder.encodeBool(self.isWelcomeTemplate, forKey: "w")
    }
}

public final class EphemeralOutgoingMessageAttribute: MessageAttribute {
    public enum State: Int32 {
        case sending = 0
        case failed = 1
    }

    public let botPeerId: PeerId
    public let randomId: Int64
    public let state: State
    public let isWelcomeTemplate: Bool

    public var associatedPeerIds: [PeerId] {
        return [self.botPeerId]
    }

    public init(botPeerId: PeerId, randomId: Int64, state: State, isWelcomeTemplate: Bool = false) {
        self.botPeerId = botPeerId
        self.randomId = randomId
        self.state = state
        self.isWelcomeTemplate = isWelcomeTemplate
    }

    required public init(decoder: PostboxDecoder) {
        self.botPeerId = PeerId(decoder.decodeInt64ForKey("b", orElse: 0))
        self.randomId = decoder.decodeInt64ForKey("r", orElse: 0)
        self.state = State(rawValue: decoder.decodeInt32ForKey("s", orElse: State.sending.rawValue)) ?? .sending
        self.isWelcomeTemplate = decoder.decodeBoolForKey("w", orElse: false)
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.botPeerId.toInt64(), forKey: "b")
        encoder.encodeInt64(self.randomId, forKey: "r")
        encoder.encodeInt32(self.state.rawValue, forKey: "s")
        encoder.encodeBool(self.isWelcomeTemplate, forKey: "w")
    }

    public func withUpdatedState(_ state: State) -> EphemeralOutgoingMessageAttribute {
        return EphemeralOutgoingMessageAttribute(botPeerId: self.botPeerId, randomId: self.randomId, state: state, isWelcomeTemplate: self.isWelcomeTemplate)
    }
}
