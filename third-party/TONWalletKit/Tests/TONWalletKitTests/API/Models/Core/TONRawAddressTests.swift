import Testing
import Foundation
@testable import TONWalletKit

@Suite("TONRawAddress Tests")
struct TONRawAddressTests {

    private let validHash = String(repeating: "ab", count: 32)

    @Test("init(workchain:hash:) stores values correctly")
    func initComponents() {
        let hash = Data(repeating: 0xab, count: 32)
        let sut = TONRawAddress(workchain: 0, hash: hash)

        #expect(sut.workchain == 0)
        #expect(sut.hash == hash)
    }

    @Test("string property returns workchain:hex format")
    func stringProperty() {
        let hash = Data(repeating: 0xab, count: 32)
        let sut = TONRawAddress(workchain: 0, hash: hash)

        #expect(sut.string == "0:\(validHash)")
    }

    @Test("init(string:) parses valid address")
    func initStringValid() throws {
        let sut = try TONRawAddress(string: "0:\(validHash)")

        #expect(sut.workchain == 0)
        #expect(sut.hash == Data(repeating: 0xab, count: 32))
    }

    @Test("init(string:) with negative workchain")
    func initStringNegativeWorkchain() throws {
        let sut = try TONRawAddress(string: "-1:\(validHash)")

        #expect(sut.workchain == -1)
    }

    @Test("init(string:) no colon throws invadidRawAddressFormat")
    func initStringNoColon() {
        #expect(throws: TONRawAddressValidationError.invadidRawAddressFormat) {
            try TONRawAddress(string: "0\(validHash)")
        }
    }

    @Test("init(string:) invalid workchain throws")
    func initStringInvalidWorkchain() {
        #expect(throws: TONRawAddressValidationError.invalidWorkchain) {
            try TONRawAddress(string: "abc:\(validHash)")
        }
    }

    @Test("init(string:) hash wrong length throws invalidHash")
    func initStringHashWrongLength() {
        #expect(throws: TONRawAddressValidationError.invalidHash) {
            try TONRawAddress(string: "0:abcd")
        }
    }

    @Test("init(string:) hash not hex throws invalidHash")
    func initStringHashNotHex() {
        let invalidHash = String(repeating: "zz", count: 32)
        #expect(throws: TONRawAddressValidationError.invalidHash) {
            try TONRawAddress(string: "0:\(invalidHash)")
        }
    }

    @Test("userFriendly() bounceable returns address with isBounceable true")
    func userFriendlyBounceable() {
        let hash = Data(repeating: 0xab, count: 32)
        let sut = TONRawAddress(workchain: 0, hash: hash)
        let friendly = sut.userFriendly(isBounceable: true)

        #expect(friendly.isBounceable == true)
        #expect(friendly.workchain == 0)
        #expect(friendly.hash == hash)
    }

    @Test("userFriendly() non-bounceable returns address with isBounceable false")
    func userFriendlyNonBounceable() {
        let hash = Data(repeating: 0xab, count: 32)
        let sut = TONRawAddress(workchain: 0, hash: hash)
        let friendly = sut.userFriendly(isBounceable: false)

        #expect(friendly.isBounceable == false)
    }

    @Test("Codable round trip preserves values")
    func codableRoundTrip() throws {
        let original = try TONRawAddress(string: "0:\(validHash)")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TONRawAddress.self, from: data)

        #expect(decoded.workchain == original.workchain)
        #expect(decoded.hash == original.hash)
    }
}
