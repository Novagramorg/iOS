import Foundation

func walletEncryptedCommentBoc(_ comment: String) -> String? {
    guard let data = Data(base64Encoded: comment), !data.isEmpty, data.count <= 1024 else {
        return nil
    }
    let bocMagic: [UInt8] = [0xb5, 0xee, 0x9c, 0x72]
    if data.starts(with: bocMagic) {
        return comment
    }

    let opcode: [UInt8] = [0x21, 0x67, 0xda, 0x4b]
    let hasOpcode = data.starts(with: opcode) && data.count % 16 == 4
    let payload = Array(data.dropFirst(hasOpcode ? opcode.count : 0))
    guard payload.count >= 64, (payload.count - 48) % 16 == 0 else {
        return nil
    }

    var chunks: [[UInt8]] = [opcode + Array(payload.prefix(35))]
    for offset in stride(from: 35, to: payload.count, by: 127) {
        chunks.append(Array(payload[offset ..< min(offset + 127, payload.count)]))
    }
    var cells = Data()
    for (index, chunk) in chunks.enumerated() {
        let hasNext = index + 1 < chunks.count
        cells.append(hasNext ? 1 : 0)
        cells.append(UInt8(chunk.count * 2))
        cells.append(contentsOf: chunk)
        if hasNext {
            cells.append(UInt8(index + 1))
        }
    }

    let offsetBytes: UInt8 = cells.count > 255 ? 2 : 1
    var boc = Data(bocMagic + [0x01, offsetBytes, UInt8(chunks.count), 1, 0])
    if offsetBytes == 2 {
        boc.append(UInt8(cells.count >> 8))
    }
    boc.append(UInt8(cells.count & 0xff))
    boc.append(0)
    boc.append(cells)
    return boc.base64EncodedString()
}
