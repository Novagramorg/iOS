import Foundation
import Postbox
import TelegramApi

public final class SummarizationMessageAttribute: Equatable, MessageAttribute {
    public struct Summary: Equatable, Codable {
        public let text: String
        public let entities: [MessageTextEntity]
    }
    
    public let fromLang: String
    public let summary: Summary?
    
    public init(
        fromLang: String,
        summary: Summary? = nil
    ) {
        self.fromLang = fromLang
        self.summary = summary
    }
    
    required public init(decoder: PostboxDecoder) {
        self.fromLang = decoder.decodeStringForKey("fl", orElse: "")
        self.summary = decoder.decodeCodable(Summary.self, forKey: "sum")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.fromLang, forKey: "fl")
        encoder.encodeCodable(self.summary, forKey: "sum")
    }
    
    public static func ==(lhs: SummarizationMessageAttribute, rhs: SummarizationMessageAttribute) -> Bool {
        if lhs.fromLang != rhs.fromLang {
            return false
        }
        if lhs.summary != rhs.summary {
            return false
        }
        return true
    }
}
