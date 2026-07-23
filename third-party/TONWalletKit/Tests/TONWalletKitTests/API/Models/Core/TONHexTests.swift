import Testing
import Foundation
@testable import TONWalletKit

@Suite("TONHex Tests")
struct TONHexTests {

    @Test("init(hexString:) with 0x prefix")
    func initHexStringWithPrefix() throws {
        let sut = try TONHex(hexString: "0xabcd")

        #expect(sut.value == "0xabcd")
    }

    @Test("init(hexString:) without prefix")
    func initHexStringWithoutPrefix() throws {
        let sut = try TONHex(hexString: "abcd")

        #expect(sut.value == "abcd")
    }

    @Test("init(hexString:) invalid characters throws .invalidHexString")
    func initHexStringInvalid() {
        let error = #expect(throws: TONHexValidationError.self) {
            try TONHex(hexString: "xyz")
        }

        guard case .invalidHexString(let invalid)? = error else {
            Issue.record("Expected .invalidHexString, got \(String(describing: error))")
            return
        }
        #expect(invalid == "xyz")
    }

    @Test("init(hexString:) odd length throws .invalidHexString")
    func initHexStringOddLength() {
        let error = #expect(throws: TONHexValidationError.self) {
            try TONHex(hexString: "abc")
        }

        guard case .invalidHexString(let invalid)? = error else {
            Issue.record("Expected .invalidHexString, got \(String(describing: error))")
            return
        }
        #expect(invalid == "abc")
    }

    @Test("init(data:) creates hex with 0x prefix")
    func initData() {
        let sut = TONHex(data: Data([0xab, 0xcd]))

        #expect(sut.value == "0xabcd")
    }

    @Test("init(string:) converts UTF8 bytes to hex")
    func initString() {
        let sut = TONHex(string: "A")

        #expect(sut.value == "0x41")
    }

    @Test("data property round trips correctly")
    func dataRoundTrip() {
        let original = Data([0xab, 0xcd, 0xef])
        let sut = TONHex(data: original)

        #expect(sut.data == original)
    }

    @Test("Codable encodes as single string value")
    func codableEncode() throws {
        let sut = TONHex(data: Data([0xab]))
        let data = try JSONEncoder().encode(sut)
        let json = String(data: data, encoding: .utf8)

        #expect(json == "\"0xab\"")
    }

    @Test("Codable decodes from string")
    func codableDecode() throws {
        let json = "\"0xab\"".data(using: .utf8)!
        let sut = try JSONDecoder().decode(TONHex.self, from: json)

        #expect(sut.value == "0xab")
    }

    @Test("Codable round trip preserves value")
    func codableRoundTrip() throws {
        let original = TONHex(data: Data([0x01, 0x23, 0x45]))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TONHex.self, from: data)

        #expect(decoded.value == original.value)
    }
}
