import Foundation
import Postbox

public struct EditedMessageHistoryEntry: PostboxCoding, Codable, Equatable {
    public let timestamp: Int32
    public let text: String
    public let entities: [MessageTextEntity]
    // Fenixuz v2: previous media of the edited message (photos/videos/files).
    // Encoded via the Postbox generic-object path only; entries stored before
    // this field existed decode to an empty array (missing key -> []).
    public let media: [Media]
    
    public init(timestamp: Int32, text: String, entities: [MessageTextEntity], media: [Media] = []) {
        self.timestamp = timestamp
        self.text = text
        self.entities = entities
        self.media = media
    }
    
    public init(decoder: PostboxDecoder) {
        self.timestamp = decoder.decodeInt32ForKey("t", orElse: 0)
        self.text = decoder.decodeStringForKey("text", orElse: "")
        self.entities = decoder.decodeObjectArrayWithDecoderForKey("entities")
        let mediaObjects: [PostboxCoding] = decoder.decodeObjectArrayForKey("media")
        self.media = mediaObjects.compactMap { $0 as? Media }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        self.timestamp = try container.decode(Int32.self, forKey: "t")
        self.text = try container.decode(String.self, forKey: "text")
        self.entities = try container.decode([MessageTextEntity].self, forKey: "entities")
        // Media is not representable through the Codable path; persistence goes
        // through PostboxCoding above, so this path intentionally drops media.
        self.media = []
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.timestamp, forKey: "t")
        encoder.encodeString(self.text, forKey: "text")
        encoder.encodeObjectArray(self.entities, forKey: "entities")
        encoder.encodeGenericObjectArray(self.media.map { $0 as PostboxCoding }, forKey: "media")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try container.encode(self.timestamp, forKey: "t")
        try container.encode(self.text, forKey: "text")
        try container.encode(self.entities, forKey: "entities")
    }
    
    public static func ==(lhs: EditedMessageHistoryEntry, rhs: EditedMessageHistoryEntry) -> Bool {
        return lhs.timestamp == rhs.timestamp && lhs.text == rhs.text && lhs.entities == rhs.entities && lhs.media.map { $0.id } == rhs.media.map { $0.id }
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
            for media in entry.media {
                if let id = media.id {
                    result.append(id)
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
