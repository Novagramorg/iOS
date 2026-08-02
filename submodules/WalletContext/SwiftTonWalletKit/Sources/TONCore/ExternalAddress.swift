import Foundation

/// `addr_extern$01 len:(## 9) external_address:(bits len)`
///
/// Appears as the source of an inbound external message and the destination of an
/// outbound one. Not a contract address — it carries no workchain.
public struct ExternalAddress: Hashable, Sendable {
    public let value: BigUInt
    public let bitLength: Int

    public init(value: BigUInt, bitLength: Int) {
        precondition(bitLength >= 0 && bitLength < 512, "External address length out of range")
        self.value = value
        self.bitLength = bitLength
    }
}

extension ExternalAddress: CustomStringConvertible {
    public var description: String {
        "External<\(bitLength):\(String(value, radix: 16))>"
    }
}

extension Builder {
    /// Stores `addr_extern`, or `addr_none` for nil.
    @discardableResult
    public func storeExternalAddress(_ address: ExternalAddress?) throws -> Builder {
        guard let address else { return try storeUInt(0, bits: 2) }
        try storeUInt(0b01, bits: 2)
        try storeUInt(UInt64(address.bitLength), bits: 9)
        try storeBigUInt(address.value, bits: address.bitLength)
        return self
    }
}

extension Slice {
    /// Loads `addr_extern`, or nil for `addr_none`.
    public mutating func loadMaybeExternalAddress() throws -> ExternalAddress? {
        let tag = try loadUInt(2)
        switch tag {
        case 0b00:
            return nil
        case 0b01:
            let bitLength = Int(try loadUInt(9))
            let value = try loadBigUInt(bitLength)
            return ExternalAddress(value: value, bitLength: bitLength)
        default:
            throw SliceError.unexpectedAddressTag(tag)
        }
    }
}
