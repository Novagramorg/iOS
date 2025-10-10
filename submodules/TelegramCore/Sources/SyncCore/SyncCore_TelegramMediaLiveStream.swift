import Foundation
import Postbox

public final class TelegramMediaLiveStream: Media, Equatable {
    public let peerIds: [PeerId] = []

    public var id: MediaId? {
        return nil
    }

    public let call: GroupCallReference
        
    public init(call: GroupCallReference) {
        self.call = call
    }
    
    public init(decoder: PostboxDecoder) {
        self.call = decoder.decodeCodable(GroupCallReference.self, forKey: "call")!
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeCodable(self.call, forKey: "call")
    }
    
    public static func ==(lhs: TelegramMediaLiveStream, rhs: TelegramMediaLiveStream) -> Bool {
        return lhs.isEqual(to: rhs)
    }
    
    public func isEqual(to other: Media) -> Bool {
        guard let other = other as? TelegramMediaLiveStream else {
            return false
        }
        
        if self.call != other.call {
            return false
        }
        
        return true
    }
    
    public func isSemanticallyEqual(to other: Media) -> Bool {
        return self.isEqual(to: other)
    }
}
