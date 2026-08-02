import Foundation
import CryptoKit

/// Domain separation for wallet signatures, so a signature made for one chain cannot
/// be replayed on another.
public enum SignatureDomain: Hashable, Sendable {
    case empty
    case l2(globalId: Int32)

    /// TL constructor tags, little-endian in the hashed preimage.
    static let emptyTag: Int32 = 236_803_867
    static let l2Tag: Int32 = 1_907_576_545

    /// `sha256` over the TL-serialized domain.
    public var hash: Data {
        switch self {
        case .empty:
            var preimage = Data(capacity: 4)
            preimage.append(littleEndian: SignatureDomain.emptyTag)
            return Data(SHA256.hash(data: preimage))
        case .l2(let globalId):
            var preimage = Data(capacity: 8)
            preimage.append(littleEndian: SignatureDomain.l2Tag)
            preimage.append(littleEndian: globalId)
            return Data(SHA256.hash(data: preimage))
        }
    }

    /// The prefix prepended to signing data, or nil when no separation applies.
    ///
    /// The empty domain deliberately yields nil rather than its hash, so signatures in
    /// the default domain stay byte-compatible with implementations that predate
    /// domain separation.
    public var prefix: Data? {
        let h = hash
        return h == SignatureDomain.empty.hash ? nil : h
    }

    /// Prepends the domain prefix to `data`, if any.
    public func dataToSign(_ data: Data) -> Data {
        guard let prefix else { return data }
        return prefix + data
    }
}

extension Data {
    fileprivate mutating func append(littleEndian value: Int32) {
        let bits = UInt32(bitPattern: value)
        for shift in stride(from: 0, to: 32, by: 8) {
            append(UInt8((bits >> UInt32(shift)) & 0xff))
        }
    }
}
