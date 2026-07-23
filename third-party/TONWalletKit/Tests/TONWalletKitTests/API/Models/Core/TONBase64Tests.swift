import Testing
import Foundation
@testable import TONWalletKit

@Suite("TONBase64 Tests")
struct TONBase64Tests {

    @Test("init(base64Encoded:) with valid string")
    func initBase64EncodedValid() throws {
        let sut = try TONBase64(base64Encoded: "dGVzdA==")

        #expect(sut.value == "dGVzdA==")
    }

    @Test("init(base64Encoded:) with invalid string throws .invalidBase64String")
    func initBase64EncodedInvalid() {
        let error = #expect(throws: TONBase64ValidationError.self) {
            try TONBase64(base64Encoded: "!!!")
        }

        guard case .invalidBase64String(let invalid)? = error else {
            Issue.record("Expected .invalidBase64String, got \(String(describing: error))")
            return
        }
        #expect(invalid == "!!!")
    }

    @Test("init(data:) encodes data to base64")
    func initData() {
        let data = Data("test".utf8)
        let sut = TONBase64(data: data)

        #expect(sut.value == "dGVzdA==")
    }

    @Test("init(string:) encodes UTF8 string to base64")
    func initString() {
        let sut = TONBase64(string: "test")

        #expect(sut.value == "dGVzdA==")
    }

    @Test("data property returns decoded data")
    func dataProperty() {
        let sut = TONBase64(data: Data([0x01, 0x02, 0x03]))

        #expect(sut.data == Data([0x01, 0x02, 0x03]))
    }

    @Test("data property returns nil for invalid base64")
    func dataPropertyNilForInvalid() throws {
        let sut = TONBase64(string: "test")

        #expect(sut.data != nil)
    }

    @Test("Codable encodes as single string value")
    func codableEncode() throws {
        let sut = TONBase64(string: "test")
        let data = try JSONEncoder().encode(sut)
        let json = String(data: data, encoding: .utf8)

        #expect(json == "\"dGVzdA==\"")
    }

    @Test("Codable decodes from string")
    func codableDecode() throws {
        let json = "\"dGVzdA==\"".data(using: .utf8)!
        let sut = try JSONDecoder().decode(TONBase64.self, from: json)

        #expect(sut.value == "dGVzdA==")
    }

    @Test("Codable round trip preserves value")
    func codableRoundTrip() throws {
        let original = TONBase64(string: "hello world")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TONBase64.self, from: data)

        #expect(decoded.value == original.value)
    }
}
