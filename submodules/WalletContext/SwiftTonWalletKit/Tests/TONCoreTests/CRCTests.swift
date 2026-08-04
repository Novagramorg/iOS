import XCTest
import TONTestVectors
@testable import TONCore

/// Verifies the checksums against golden vectors plus published reference values.
final class CRCTests: XCTestCase {
    struct CRC32Vector: Decodable {
        let input: String
        let inputHex: String
        let crc32: UInt32
    }

    /// crc32 over the same inputs the reference SheetJS implementation was run on.
    func testCRC32MatchesReference() throws {
        let vectors: [CRC32Vector] = try Vectors.load("crc32.json")
        XCTAssertFalse(vectors.isEmpty)

        for v in vectors {
            let data = Data(hexString: v.inputHex) ?? Data()
            XCTAssertEqual(
                CRC.crc32(data),
                v.crc32,
                "crc32 of \"\(v.input.prefix(32))\" (\(data.count) bytes)"
            )
        }
    }

    /// Published CRC-32/ISO-HDLC check value: crc32("123456789") == 0xCBF43926.
    func testCRC32KnownCheckValue() {
        XCTAssertEqual(CRC.crc32(Data("123456789".utf8)), 0xcbf4_3926)
    }

    /// Published CRC-16/XMODEM check value: crc16("123456789") == 0x31C3.
    func testCRC16XModemKnownCheckValue() {
        XCTAssertEqual(CRC.crc16XModem(Data("123456789".utf8)), 0x31c3)
    }

    /// Published CRC-32C check value: crc32c("123456789") == 0xE3069283.
    func testCRC32CKnownCheckValue() {
        XCTAssertEqual(CRC.crc32c(Data("123456789".utf8)), 0xe306_9283)
    }

    func testEmptyInputs() {
        XCTAssertEqual(CRC.crc16XModem(Data()), 0)
        XCTAssertEqual(CRC.crc32(Data()), 0)
        XCTAssertEqual(CRC.crc32c(Data()), 0)
    }
}
