import Foundation

func canonicalNonBounceableTonAddress(_ address: String) -> String? {
    var payload: [UInt8]
    let isTestOnly: Bool
    if let friendlyAddress = decodeFriendlyTonAddress(address) {
        payload = Array(friendlyAddress.prefix(34))
        isTestOnly = (friendlyAddress[0] & 0x80) != 0
    } else if let rawAddress = decodeRawTonAddress(address) {
        payload = rawAddress
        isTestOnly = false
    } else {
        return nil
    }

    payload[0] = 0x51 | (isTestOnly ? 0x80 : 0x00)
    let checksum = tonAddressCrc16(payload)
    payload.append(UInt8(checksum >> 8))
    payload.append(UInt8(checksum & 0xff))

    return Data(payload).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

private func decodeFriendlyTonAddress(_ address: String) -> [UInt8]? {
    guard address.utf8.count == 48 else {
        return nil
    }
    let base64 = address
        .replacingOccurrences(of: "-", with: "+")
        .replacingOccurrences(of: "_", with: "/")
    guard let data = Data(base64Encoded: base64), data.count == 36 else {
        return nil
    }
    let bytes = [UInt8](data)
    guard (bytes[0] & 0x3f) == 0x11 else {
        return nil
    }
    let checksum = tonAddressCrc16(Array(bytes.prefix(34)))
    guard bytes[34] == UInt8(checksum >> 8), bytes[35] == UInt8(checksum & 0xff) else {
        return nil
    }
    return bytes
}

private func decodeRawTonAddress(_ address: String) -> [UInt8]? {
    let components = address.split(separator: ":", omittingEmptySubsequences: false)
    guard components.count == 2,
          let workchainValue = Int16(String(components[0])),
          workchainValue >= Int16(Int8.min),
          workchainValue <= Int16(Int8.max) else {
        return nil
    }
    let accountId = Array(components[1].utf8)
    guard accountId.count == 64 else {
        return nil
    }
    var payload: [UInt8] = [0x51, UInt8(bitPattern: Int8(workchainValue))]
    payload.reserveCapacity(34)
    for index in stride(from: 0, to: accountId.count, by: 2) {
        guard let high = tonHexValue(accountId[index]), let low = tonHexValue(accountId[index + 1]) else {
            return nil
        }
        payload.append((high << 4) | low)
    }
    return payload
}

private func tonHexValue(_ value: UInt8) -> UInt8? {
    switch value {
    case 48 ... 57:
        return value - 48
    case 65 ... 70:
        return value - 65 + 10
    case 97 ... 102:
        return value - 97 + 10
    default:
        return nil
    }
}

private func tonAddressCrc16(_ bytes: [UInt8]) -> UInt16 {
    var result: UInt32 = 0
    for byte in bytes {
        result ^= UInt32(byte) << 8
        for _ in 0 ..< 8 {
            if (result & 0x8000) != 0 {
                result = ((result << 1) ^ 0x1021) & 0xffff
            } else {
                result = (result << 1) & 0xffff
            }
        }
    }
    return UInt16(result)
}
