import Foundation
import Postbox

private let pincodeDefaultsKey = "chat_pincode_map"

public final class ChatPincodeManager {
    public static let shared = ChatPincodeManager()

    private var pincodeMap: [String: String] {
        get {
            return (UserDefaults.standard.dictionary(forKey: pincodeDefaultsKey) as? [String: String]) ?? [:]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: pincodeDefaultsKey)
        }
    }

    private init() {}

    public func getPincode(for peerId: PeerId) -> String? {
        return pincodeMap["\(peerId.toInt64())"]
    }

    public func setPincode(_ code: String, for peerId: PeerId) {
        var map = pincodeMap
        map["\(peerId.toInt64())"] = code
        pincodeMap = map
    }

    public func removePincode(for peerId: PeerId) {
        var map = pincodeMap
        map.removeValue(forKey: "\(peerId.toInt64())")
        pincodeMap = map
    }

    public func isLocked(_ peerId: PeerId) -> Bool {
        return pincodeMap["\(peerId.toInt64())"] != nil
    }

    public func verify(_ code: String, for peerId: PeerId) -> Bool {
        return pincodeMap["\(peerId.toInt64())"] == code
    }
}
