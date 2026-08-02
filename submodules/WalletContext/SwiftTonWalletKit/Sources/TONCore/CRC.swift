import Foundation

/// Checksums TON uses on the wire.
public enum CRC {
    // MARK: - CRC-16/XMODEM

    /// CRC-16/XMODEM: poly 0x1021, init 0x0000, no reflection, no final xor.
    /// Used for the 2-byte checksum on user-friendly addresses.
    public static func crc16XModem(_ data: Data) -> UInt16 {
        var crc: UInt16 = 0
        for byte in data {
            crc ^= UInt16(byte) << 8
            for _ in 0..<8 {
                if crc & 0x8000 != 0 {
                    crc = (crc << 1) ^ 0x1021
                } else {
                    crc <<= 1
                }
            }
        }
        return crc
    }

    // MARK: - CRC-32 (IEEE, reflected)

    /// Reflected CRC-32 with poly 0xEDB88320, init 0xFFFFFFFF, final xor 0xFFFFFFFF.
    ///
    /// This is the checksum `signData`'s cell path applies to the TL-B schema string.
    /// The reference implementation is SheetJS's crc32.js, whose `crc32_buf` returns a
    /// *signed* result; walletkit coerces it with `>>> 0`, so we return the unsigned
    /// value directly.
    public static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xffff_ffff
        for byte in data {
            crc = (crc >> 8) ^ crc32Table[Int((crc ^ UInt32(byte)) & 0xff)]
        }
        return crc ^ 0xffff_ffff
    }

    private static let crc32Table: [UInt32] = {
        (0..<256).map { n -> UInt32 in
            var c = UInt32(n)
            for _ in 0..<8 {
                c = (c & 1 != 0) ? (0xedb8_8320 ^ (c >> 1)) : (c >> 1)
            }
            return c
        }
    }()

    // MARK: - CRC-32C (Castagnoli, reflected)

    /// Reflected CRC-32C with poly 0x82F63B78. Used by the BoC `has_crc32c` variant.
    public static func crc32c(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xffff_ffff
        for byte in data {
            crc = (crc >> 8) ^ crc32cTable[Int((crc ^ UInt32(byte)) & 0xff)]
        }
        return crc ^ 0xffff_ffff
    }

    private static let crc32cTable: [UInt32] = {
        (0..<256).map { n -> UInt32 in
            var c = UInt32(n)
            for _ in 0..<8 {
                c = (c & 1 != 0) ? (0x82f6_3b78 ^ (c >> 1)) : (c >> 1)
            }
            return c
        }
    }()
}
