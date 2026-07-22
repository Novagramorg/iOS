import Foundation
import Postbox

public class DeletedMessageAttribute: MessageAttribute, Equatable {
    public let timestamp: Int32

    public init(timestamp: Int32) {
        self.timestamp = timestamp
    }

    public convenience init() {
        self.init(timestamp: 0)
    }

    required public init(decoder: PostboxDecoder) {
        self.timestamp = decoder.decodeInt32ForKey("t", orElse: 0)
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.timestamp, forKey: "t")
    }

    public static func == (lhs: DeletedMessageAttribute, rhs: DeletedMessageAttribute) -> Bool {
        return lhs.timestamp == rhs.timestamp
    }
}
