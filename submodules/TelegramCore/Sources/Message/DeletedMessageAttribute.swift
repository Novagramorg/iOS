import Foundation
import Postbox

public class DeletedMessageAttribute: MessageAttribute, Equatable {
    public init() {
    }
    
    required public init(decoder: PostboxDecoder) {
    }
    
    public func encode(_ encoder: PostboxEncoder) {
    }
    
    public static func ==(lhs: DeletedMessageAttribute, rhs: DeletedMessageAttribute) -> Bool {
        return true
    }
}
