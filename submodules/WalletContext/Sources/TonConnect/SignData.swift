import Foundation
import CryptoKit

public struct TonConnectSignDataPayload: Equatable, Sendable {
    public enum Content: Equatable, Sendable {
        case text(String)
        case binary(Data)
        case cell(schema: String, boc: Data)
    }

    public let content: Content
    let fields: [String: TonConnectJSONValue]

    public var payload: TonConnectJSONValue { .object(self.fields) }

    public init(_ data: Data) throws {
        let fields = try TonConnectWireCodec.object(data)
        guard let type = fields["type"]?.string else { throw TonConnectWireFailure(code: .badRequest) }
        let content: Content
        switch type {
        case "text":
            try TonConnectWireCodec.keys(fields, allowed: ["type", "text", "network", "from"])
            guard let text = fields["text"]?.string else { throw TonConnectWireFailure(code: .badRequest) }
            content = .text(text)
        case "binary":
            try TonConnectWireCodec.keys(fields, allowed: ["type", "bytes", "network", "from"])
            guard let bytes = fields["bytes"]?.string else { throw TonConnectWireFailure(code: .badRequest) }
            content = .binary(try TonConnectWireCodec.canonicalBase64(bytes))
        case "cell":
            try TonConnectWireCodec.keys(fields, allowed: ["type", "schema", "cell", "network", "from"])
            guard let schema = fields["schema"]?.string, let value = fields["cell"]?.string else { throw TonConnectWireFailure(code: .badRequest) }
            let boc = try TonConnectWireCodec.canonicalBase64(value)
            _ = try WalletBoc(boc, maximumBytes: TonConnectWireCodec.maximumPacketBytes)
            content = .cell(schema: schema, boc: boc)
        default: throw TonConnectWireFailure(code: .badRequest)
        }
        _ = try TonConnectWireCodec.optionalString(fields, "from")
        if let network = try TonConnectWireCodec.optionalString(fields, "network") { try TonConnectWireCodec.validateNetwork(network) }
        self.content = content
        self.fields = fields
    }

    /// The address must be the canonical raw account returned by the wallet engine.
    public func digest(address: String, domain: String, timestamp: UInt64) throws -> Data {
        let address = try Self.rawAddress(address)
        guard !domain.isEmpty, domain.utf8.count <= Int(UInt32.max) else { throw TonConnectWireFailure(code: .badRequest) }
        switch self.content {
        case let .text(text): return Self.byteDigest(address: address, domain: domain, timestamp: timestamp, prefix: "txt", bytes: Data(text.utf8))
        case let .binary(bytes): return Self.byteDigest(address: address, domain: domain, timestamp: timestamp, prefix: "bin", bytes: bytes)
        case let .cell(schema, data):
            let boc = try WalletBoc(data, maximumBytes: TonConnectWireCodec.maximumPacketBytes)
            let hashes = boc.hashes()
            let domainBytes = try Self.tep81Domain(domain)
            // TEP-81's 126-byte name encodes to at most 127 bytes: one SnakeData cell.
            let domainCell = WalletBocCell(bytes: Array(domainBytes), bitCount: domainBytes.count * 8, refs: [])
            let children = [domainCell.hash(using: []), hashes[boc.root]]
            var bits = TonConnectSignDataBits()
            bits.append(0x75569022, count: 32)
            bits.append(UInt64(Self.schemaCRC32(schema)), count: 32)
            bits.append(timestamp, count: 64)
            if let workchain = Int8(exactly: address.workchain) {
                bits.append(2, count: 2) // addr_std$10
                bits.append(0, count: 1) // no anycast
                bits.append(UInt64(UInt8(bitPattern: workchain)), count: 8)
            } else {
                bits.append(3, count: 2) // addr_var$11
                bits.append(0, count: 1)
                bits.append(256, count: 9)
                bits.append(UInt64(UInt32(bitPattern: address.workchain)), count: 32)
            }
            for byte in address.hash { bits.append(UInt64(byte), count: 8) }
            return bits.cell(refs: [0, 1]).hash(using: children).hash
        }
    }

    public func response(signature: Data, address: String, domain: String, timestamp: UInt64) throws -> TonConnectJSONValue {
        guard signature.count == 64, !domain.isEmpty else { throw TonConnectWireFailure(code: .badRequest) }
        _ = try Self.rawAddress(address)
        return .object(["signature": .string(signature.base64EncodedString()), "address": .string(address),
            "timestamp": .unsigned(timestamp), "domain": .string(domain), "payload": self.payload])
    }

    /// DNS wire format (TEP-81), including IDNA ASCII conversion and reversed labels.
    public static func tep81Domain(_ domain: String) throws -> Data {
        if domain == "." { return Data([0]) }
        guard !domain.isEmpty, !domain.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.contains($0) || CharacterSet.controlCharacters.contains($0) }),
              !domain.contains(where: { "/\\:@?#%[]".contains($0) }) else { throw TonConnectWireFailure(code: .badRequest) }
        let trimmed = domain.hasSuffix(".") ? String(domain.dropLast()) : domain
        guard trimmed.utf8.count <= 126,
              let url = URL(string: "https://" + trimmed), let host = url.host?.lowercased(), !host.isEmpty,
              !host.utf8.allSatisfy({ (48 ... 57).contains($0) || $0 == 46 }) else { throw TonConnectWireFailure(code: .badRequest) }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        var result = Data()
        for label in labels.reversed() {
            guard (1 ... 63).contains(label.utf8.count), label.utf8.allSatisfy({ $0 < 128 }) else { throw TonConnectWireFailure(code: .badRequest) }
            result.append(contentsOf: label.utf8)
            result.append(0)
        }
        guard result.count <= 127 else { throw TonConnectWireFailure(code: .badRequest) }
        return result
    }

    private static func rawAddress(_ value: String) throws -> (workchain: Int32, hash: Data) {
        let parts = value.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, let workchain = Int32(parts[0]), String(workchain) == parts[0],
              parts[1].utf8.count == 64, parts[1].utf8.allSatisfy({ (48 ... 57).contains($0) || (97 ... 102).contains($0) }) else {
            throw TonConnectWireFailure(code: .badRequest)
        }
        let hex = Array(parts[1].utf8)
        func nibble(_ v: UInt8) -> UInt8 { v <= 57 ? v - 48 : v - 87 }
        return (workchain, Data(stride(from: 0, to: 64, by: 2).map { nibble(hex[$0]) * 16 + nibble(hex[$0 + 1]) }))
    }

    private static func byteDigest(address: (workchain: Int32, hash: Data), domain: String, timestamp: UInt64, prefix: String, bytes: Data) -> Data {
        var preimage = Data([0xff, 0xff])
        preimage.append(contentsOf: "ton-connect/sign-data/".utf8)
        appendBE(UInt64(UInt32(bitPattern: address.workchain)), bytes: 4, to: &preimage)
        preimage.append(address.hash)
        appendBE(UInt64(domain.utf8.count), bytes: 4, to: &preimage)
        preimage.append(contentsOf: domain.utf8)
        appendBE(timestamp, bytes: 8, to: &preimage)
        preimage.append(contentsOf: prefix.utf8)
        appendBE(UInt64(bytes.count), bytes: 4, to: &preimage)
        preimage.append(bytes)
        return Data(SHA256.hash(data: preimage))
    }

    private static func appendBE(_ value: UInt64, bytes: Int, to data: inout Data) {
        for byte in (0 ..< bytes).reversed() { data.append(UInt8(truncatingIfNeeded: value >> (byte * 8))) }
    }

    private static func schemaCRC32(_ schema: String) -> UInt32 {
        var crc: UInt32 = 0xffffffff
        for byte in schema.utf8 {
            crc ^= UInt32(byte)
            for _ in 0 ..< 8 { crc = (crc >> 1) ^ (crc & 1 == 0 ? 0 : 0xedb88320) }
        }
        return ~crc
    }
}

private struct TonConnectSignDataBits {
    private var bytes: [UInt8] = []
    private var count = 0

    mutating func append(_ value: UInt64, count: Int) {
        for bit in (0 ..< count).reversed() {
            if self.count % 8 == 0 { self.bytes.append(0) }
            self.bytes[self.count / 8] |= UInt8((value >> bit) & 1) << (7 - self.count % 8)
            self.count += 1
        }
    }

    func cell(refs: [Int]) -> WalletBocCell {
        var bytes = self.bytes
        if self.count % 8 != 0 { bytes[bytes.count - 1] |= 1 << (7 - self.count % 8) }
        return WalletBocCell(bytes: bytes, bitCount: self.count, refs: refs)
    }
}
