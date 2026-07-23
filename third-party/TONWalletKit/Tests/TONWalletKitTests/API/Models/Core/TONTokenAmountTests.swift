import Testing
import Foundation
import _BigInt
@testable import TONWalletKit

@Suite("TONTokenAmount Tests")
struct TONTokenAmountTests {

    @Test("init(nanoUnits: BigInt) stores value")
    func initBigInt() {
        let sut = TONTokenAmount(nanoUnits: BigInt(1_000_000_000))

        #expect(sut.nanoUnits == BigInt(1_000_000_000))
    }

    @Test("init(nanoUnits: String) valid string")
    func initStringValid() {
        let sut = TONTokenAmount(nanoUnits: "1000000000")

        #expect(sut?.nanoUnits == BigInt(1_000_000_000))
    }

    @Test("init(nanoUnits: String) invalid string returns nil")
    func initStringInvalid() {
        let sut = TONTokenAmount(nanoUnits: "abc")

        #expect(sut == nil)
    }

    @Test("init(nanoUnits: String) empty string returns zero")
    func initStringEmpty() {
        let sut = TONTokenAmount(nanoUnits: "")

        #expect(sut?.nanoUnits == BigInt(0))
    }

    @Test("Codable encodes as string")
    func codableEncode() throws {
        let sut = TONTokenAmount(nanoUnits: BigInt(123))
        let data = try JSONEncoder().encode(sut)
        let json = String(data: data, encoding: .utf8)

        #expect(json == "\"123\"")
    }

    @Test("Codable decodes valid string")
    func codableDecodeValid() throws {
        let json = "\"123\"".data(using: .utf8)!
        let sut = try JSONDecoder().decode(TONTokenAmount.self, from: json)

        #expect(sut.nanoUnits == BigInt(123))
    }

    @Test("Codable decode invalid string throws DecodingError")
    func codableDecodeInvalid() {
        let json = "\"abc\"".data(using: .utf8)!

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(TONTokenAmount.self, from: json)
        }
    }

    @Test("Codable round trip with large number")
    func codableRoundTrip() throws {
        let original = TONTokenAmount(nanoUnits: BigInt(stringLiteral: "999999999999999999999"))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TONTokenAmount.self, from: data)

        #expect(decoded.nanoUnits == original.nanoUnits)
    }
}
