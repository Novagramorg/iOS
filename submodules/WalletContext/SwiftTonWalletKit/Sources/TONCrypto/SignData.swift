import Foundation
import TONCore

/// TON Connect `signData`: signing arbitrary dApp-supplied payloads.
///
/// Three payload types with two different hashing strategies — text and binary share a
/// flat byte layout, while cell payloads are hashed as a TL-B structure.
public enum SignData {
    static let prefix = "ton-connect/sign-data/"
    /// TL-B prefix for the cell variant.
    static let cellPrefix: UInt64 = 0x7556_9022

    public enum Payload: Hashable, Sendable {
        case text(String)
        /// Raw bytes. On the wire these arrive base64-encoded.
        case binary(Data)
        case cell(schema: String, cell: Cell)
    }

    /// Hash for a text or binary payload.
    ///
    /// ```
    /// message = 0xffff
    ///        ++ "ton-connect/sign-data/"
    ///        ++ workchain   (int32  big-endian, SIGNED)
    ///        ++ addressHash (32 bytes)
    ///        ++ domainLen   (uint32 big-endian)
    ///        ++ domain      (utf8)
    ///        ++ timestamp   (uint64 big-endian)
    ///        ++ "txt" | "bin"
    ///        ++ payloadLen  (uint32 big-endian)
    ///        ++ payload
    /// result  = sha256(message)
    /// ```
    ///
    /// Everything is **big-endian** here, unlike ``TonProof``, which is little-endian
    /// for the equivalent length and timestamp fields. The two live side by side in the
    /// reference and are easy to conflate.
    public static func textBinaryHash(
        payload: Payload,
        address: Address,
        domain: String,
        timestamp: UInt64
    ) throws -> Data {
        let typePrefix: String
        let payloadBytes: Data
        switch payload {
        case .text(let text):
            typePrefix = "txt"
            payloadBytes = Data(text.utf8)
        case .binary(let data):
            typePrefix = "bin"
            payloadBytes = data
        case .cell:
            throw SignDataError.wrongHashFunction
        }

        let domainBytes = Data(domain.utf8)

        var message = Data([0xff, 0xff])
        message.append(Data(prefix.utf8))
        message.append(bigEndian: UInt32(bitPattern: Int32(address.workchain)))
        message.append(address.hash)
        message.append(bigEndian: UInt32(domainBytes.count))
        message.append(domainBytes)
        message.append(bigEndian: timestamp)
        message.append(Data(typePrefix.utf8))
        message.append(bigEndian: UInt32(payloadBytes.count))
        message.append(payloadBytes)

        return Hashing.sha256(message)
    }

    /// Hash for a cell payload: a TL-B structure whose cell hash is the result.
    ///
    /// The domain is encoded per TEP-81: labels reversed, NUL-separated, with a
    /// trailing NUL — so `a.b.c` becomes `c\0b\0a\0`.
    public static func cellHash(
        schema: String,
        cell: Cell,
        address: Address,
        domain: String,
        timestamp: UInt64
    ) throws -> Data {
        let schemaHash = CRC.crc32(Data(schema.utf8))
        let tep81Domain = domain.split(separator: ".", omittingEmptySubsequences: false)
            .reversed()
            .joined(separator: "\0") + "\0"

        let builder = beginCell()
        try builder.storeUInt(cellPrefix, bits: 32)
        try builder.storeUInt(UInt64(schemaHash), bits: 32)
        try builder.storeUInt(timestamp, bits: 64)
        try builder.storeAddress(address)
        try builder.storeStringRefTail(tep81Domain)
        try builder.storeRef(cell)

        return try builder.endCell().hash()
    }

    /// Dispatches to the right hash for the payload type.
    public static func hash(
        payload: Payload,
        address: Address,
        domain: String,
        timestamp: UInt64
    ) throws -> Data {
        switch payload {
        case .text, .binary:
            return try textBinaryHash(
                payload: payload,
                address: address,
                domain: domain,
                timestamp: timestamp
            )
        case .cell(let schema, let cell):
            return try cellHash(
                schema: schema,
                cell: cell,
                address: address,
                domain: domain,
                timestamp: timestamp
            )
        }
    }

    public enum SignDataError: Error, CustomStringConvertible {
        case wrongHashFunction

        public var description: String {
            "Cell payloads must use cellHash, not textBinaryHash"
        }
    }
}

/// A unique per-network wallet identifier: `base64(sha256("<chainId>:<address>"))`.
public enum WalletID {
    public static func make(chainId: String, address: String) -> String {
        Hashing.sha256(Data("\(chainId):\(address)".utf8)).base64EncodedString()
    }
}
