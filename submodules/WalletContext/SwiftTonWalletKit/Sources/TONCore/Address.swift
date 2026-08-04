import Foundation

/// A TON smart-contract address: a workchain id plus a 256-bit account hash.
public struct Address: Hashable, Sendable {
    /// Signed workchain identifier. 0 is basechain, -1 is masterchain.
    public let workchain: Int8

    /// 32-byte account id.
    public let hash: Data

    public init(workchain: Int8, hash: Data) {
        precondition(hash.count == 32, "Address hash must be 32 bytes, got \(hash.count)")
        self.workchain = workchain
        self.hash = hash
    }

    /// Zero address in the given workchain.
    public static func zero(workchain: Int8 = 0) -> Address {
        Address(workchain: workchain, hash: Data(repeating: 0, count: 32))
    }

    // MARK: - Errors

    public enum ParseError: Error, Equatable, CustomStringConvertible {
        case empty
        case malformedRaw(String)
        case invalidWorkchain(String)
        case invalidHashLength(Int)
        case invalidHexDigits
        case invalidBase64
        case invalidFriendlyLength(Int)
        case invalidChecksum(expected: UInt16, actual: UInt16)
        case unknownTag(UInt8)

        public var description: String {
            switch self {
            case .empty:
                return "Address string is empty"
            case .malformedRaw(let s):
                return "Malformed raw address \"\(s)\": expected <workchain>:<64 hex chars>"
            case .invalidWorkchain(let s):
                return "Invalid workchain \"\(s)\""
            case .invalidHashLength(let n):
                return "Address hash must be 32 bytes, got \(n)"
            case .invalidHexDigits:
                return "Address hash contains non-hex characters"
            case .invalidBase64:
                return "Address is not valid base64"
            case .invalidFriendlyLength(let n):
                return "User-friendly address must decode to 36 bytes, got \(n)"
            case .invalidChecksum(let expected, let actual):
                return String(format: "Address checksum mismatch: expected %04X, got %04X", expected, actual)
            case .unknownTag(let tag):
                return String(format: "Unknown address tag 0x%02X", tag)
            }
        }
    }

    // MARK: - Friendly-form flags

    private static let bounceableTag: UInt8 = 0x11
    private static let nonBounceableTag: UInt8 = 0x51
    private static let testFlag: UInt8 = 0x80

    /// Parsed metadata carried only by the user-friendly form.
    public struct Friendly: Hashable, Sendable {
        public let address: Address
        public let isBounceable: Bool
        public let isTestOnly: Bool
    }

    // MARK: - Parsing

    /// Parses either the raw (`0:abc…`) or user-friendly (`EQ…`) form.
    public static func parse(_ string: String) throws -> Address {
        if string.contains(":") {
            return try parseRaw(string)
        }
        return try parseFriendly(string).address
    }

    /// Parses an address and returns one canonical user-friendly representation.
    ///
    /// When `testOnly` is nil, a user-friendly input keeps its test-only flag while a raw
    /// address defaults to mainnet. Supplying `testOnly` explicitly overrides either form.
    /// This is the safe conversion to use at application boundaries: it validates the full
    /// input and its checksum before changing bounceability or base64 alphabet.
    public static func canonicalString(
        _ string: String,
        urlSafe: Bool = true,
        bounceable: Bool = true,
        testOnly: Bool? = nil
    ) throws -> String {
        let address: Address
        let parsedTestOnly: Bool
        if string.contains(":") {
            address = try parseRaw(string)
            parsedTestOnly = false
        } else {
            let friendly = try parseFriendly(string)
            address = friendly.address
            parsedTestOnly = friendly.isTestOnly
        }
        return address.toString(
            urlSafe: urlSafe,
            bounceable: bounceable,
            testOnly: testOnly ?? parsedTestOnly
        )
    }

    /// Parses the raw `<workchain>:<64 hex chars>` form.
    public static func parseRaw(_ string: String) throws -> Address {
        guard !string.isEmpty else { throw ParseError.empty }

        let parts = string.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else {
            throw ParseError.malformedRaw(string)
        }
        guard let workchain = Int8(parts[0]) else {
            throw ParseError.invalidWorkchain(String(parts[0]))
        }
        let hexPart = parts[1]
        guard hexPart.count == 64 else {
            throw ParseError.invalidHashLength(hexPart.count / 2)
        }
        guard let hash = Data(hexString: hexPart) else {
            throw ParseError.invalidHexDigits
        }
        return Address(workchain: workchain, hash: hash)
    }

    /// Parses the base64 user-friendly form, verifying the CRC-16 checksum.
    ///
    /// Accepts both standard and URL-safe alphabets, since dApps emit both.
    public static func parseFriendly(_ string: String) throws -> Friendly {
        guard !string.isEmpty else { throw ParseError.empty }

        guard let decoded = Data(anyBase64: string) else { throw ParseError.invalidBase64 }
        guard decoded.count == 36 else { throw ParseError.invalidFriendlyLength(decoded.count) }

        let payload = decoded.prefix(34)
        let checksumBytes = decoded.suffix(2)
        let actual = (UInt16(checksumBytes[checksumBytes.startIndex]) << 8)
            | UInt16(checksumBytes[checksumBytes.startIndex + 1])
        let expected = CRC.crc16XModem(Data(payload))
        guard expected == actual else {
            throw ParseError.invalidChecksum(expected: expected, actual: actual)
        }

        var tag = payload[payload.startIndex]
        let isTestOnly = tag & testFlag != 0
        if isTestOnly { tag ^= testFlag }

        let isBounceable: Bool
        switch tag {
        case bounceableTag: isBounceable = true
        case nonBounceableTag: isBounceable = false
        default: throw ParseError.unknownTag(tag)
        }

        let workchainByte = payload[payload.startIndex + 1]
        let workchain = Int8(bitPattern: workchainByte)
        let hash = Data(payload[(payload.startIndex + 2)...])

        return Friendly(
            address: Address(workchain: workchain, hash: hash),
            isBounceable: isBounceable,
            isTestOnly: isTestOnly
        )
    }

    // MARK: - Formatting

    /// The raw `<workchain>:<hex>` form.
    public var rawString: String {
        "\(workchain):\(hash.hexString)"
    }

    /// The base64 user-friendly form.
    ///
    /// Defaults match the ecosystem convention: bounceable, URL-safe, mainnet.
    public func toString(
        urlSafe: Bool = true,
        bounceable: Bool = true,
        testOnly: Bool = false
    ) -> String {
        var tag = bounceable ? Address.bounceableTag : Address.nonBounceableTag
        if testOnly { tag |= Address.testFlag }

        var payload = Data(capacity: 34)
        payload.append(tag)
        payload.append(UInt8(bitPattern: workchain))
        payload.append(hash)

        let checksum = CRC.crc16XModem(payload)
        payload.append(UInt8(checksum >> 8))
        payload.append(UInt8(checksum & 0xff))

        let base64 = payload.base64EncodedString()
        guard urlSafe else { return base64 }
        return base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
    }
}

extension Address: CustomStringConvertible {
    /// Defaults to the friendly bounceable form, matching `@ton/core`.
    public var description: String { toString() }
}

// MARK: - Hex and base64 conversion

extension Data {
    /// Parses a hex string. Returns nil on odd length or non-hex characters.
    public init?(hexString: some StringProtocol) {
        guard hexString.count % 2 == 0 else { return nil }
        var out = Data(capacity: hexString.count / 2)
        var index = hexString.startIndex
        while index < hexString.endIndex {
            let next = hexString.index(index, offsetBy: 2)
            guard let byte = UInt8(hexString[index..<next], radix: 16) else { return nil }
            out.append(byte)
            index = next
        }
        self = out
    }

    public var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }

    /// Decodes base64 in either the standard or URL-safe alphabet, tolerating
    /// missing padding.
    public init?(anyBase64 string: String) {
        var normalized = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = normalized.count % 4
        if remainder != 0 {
            normalized += String(repeating: "=", count: 4 - remainder)
        }
        guard let data = Data(base64Encoded: normalized) else { return nil }
        self = data
    }
}
