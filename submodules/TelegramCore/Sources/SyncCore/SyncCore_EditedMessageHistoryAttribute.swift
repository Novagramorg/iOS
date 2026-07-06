import Foundation
import Postbox

public struct EditedMessageHistoryEntry: PostboxCoding, Codable, Equatable {
    public let timestamp: Int32
    public let text: String
    public let entities: [MessageTextEntity]
    
    public init(timestamp: Int32, text: String, entities: [MessageTextEntity]) {
        self.timestamp = timestamp
        self.text = text
        self.entities = entities
    }
    
    public init(decoder: PostboxDecoder) {
        self.timestamp = decoder.decodeInt32ForKey("t", orElse: 0)
        self.text = decoder.decodeStringForKey("text", orElse: "")
        self.entities = decoder.decodeObjectArrayWithDecoderForKey("entities")
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        self.timestamp = try container.decode(Int32.self, forKey: "t")
        self.text = try container.decode(String.self, forKey: "text")
        self.entities = try container.decode([MessageTextEntity].self, forKey: "entities")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.timestamp, forKey: "t")
        encoder.encodeString(self.text, forKey: "text")
        encoder.encodeObjectArray(self.entities, forKey: "entities")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try container.encode(self.timestamp, forKey: "t")
        try container.encode(self.text, forKey: "text")
        try container.encode(self.entities, forKey: "entities")
    }
    
    public static func ==(lhs: EditedMessageHistoryEntry, rhs: EditedMessageHistoryEntry) -> Bool {
        return lhs.timestamp == rhs.timestamp && lhs.text == rhs.text && lhs.entities == rhs.entities
    }
}

public class EditedMessageHistoryAttribute: MessageAttribute, Equatable {
    public let history: [EditedMessageHistoryEntry]
    
    public init(history: [EditedMessageHistoryEntry]) {
        self.history = history
    }
    
    required public init(decoder: PostboxDecoder) {
        self.history = decoder.decodeObjectArrayWithDecoderForKey("history")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.history, forKey: "history")
    }
    
    public var associatedPeerIds: [PeerId] {
        var result: [PeerId] = []
        for entry in self.history {
            for entity in entry.entities {
                switch entity.type {
                    case let .TextMention(peerId):
                        result.append(peerId)
                    default:
                        break
                }
            }
        }
        return result
    }
    
    public var associatedMediaIds: [MediaId] {
        var result: [MediaId] = []
        for entry in self.history {
            for entity in entry.entities {
                switch entity.type {
                case let .CustomEmoji(_, fileId):
                    result.append(MediaId(namespace: Namespaces.Media.CloudFile, id: fileId))
                default:
                    break
                }
            }
        }
        if result.isEmpty {
            return result
        } else {
            return Array(Set(result))
        }
    }
    
    public static func ==(lhs: EditedMessageHistoryAttribute, rhs: EditedMessageHistoryAttribute) -> Bool {
        return lhs.history == rhs.history
    }
}
