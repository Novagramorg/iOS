import Testing
import Foundation
@testable import TONWalletKit

@Suite("TONUserFriendlyAddress Tests")
struct TONUserFriendlyAddressTests {

    private let testHash = Data(repeating: 0xab, count: 32)

    private func makeAddress(
        isBounceable: Bool = true,
        isTestnetOnly: Bool = false,
        workchain: Int8 = 0
    ) -> TONUserFriendlyAddress {
        TONRawAddress(workchain: workchain, hash: testHash)
            .userFriendly(isBounceable: isBounceable, isTestnetOnly: isTestnetOnly)
    }

    @Test("init(value:) bounceable address")
    func initValueBounceable() throws {
        let address = makeAddress(isBounceable: true)
        let sut = try TONUserFriendlyAddress(value: address.value)

        #expect(sut.isBounceable == true)
        #expect(sut.workchain == 0)
        #expect(sut.hash == testHash)
    }

    @Test("init(value:) non-bounceable address")
    func initValueNonBounceable() throws {
        let address = makeAddress(isBounceable: false)
        let sut = try TONUserFriendlyAddress(value: address.value)

        #expect(sut.isBounceable == false)
    }

    @Test("init(value:) testnet address")
    func initValueTestnet() throws {
        let address = makeAddress(isTestnetOnly: true)
        let sut = try TONUserFriendlyAddress(value: address.value)

        #expect(sut.isTestnetOnly == true)
    }

    @Test("init(value:) wrong length throws invalidCharactersNumber")
    func initValueWrongLength() {
        #expect(throws: TONUserFriendlyAddressValidationError.invalidCharactersNumber) {
            try TONUserFriendlyAddress(value: "short")
        }
    }

    @Test("init(value:) invalid base64 throws invalidBase64URLEncoding")
    func initValueInvalidBase64() {
        let invalid = String(repeating: "!", count: 48)
        #expect(throws: TONUserFriendlyAddressValidationError.invalidBase64URLEncoding) {
            try TONUserFriendlyAddress(value: invalid)
        }
    }

    @Test("init(value:) wrong CRC throws invalidCRC16Hashsum")
    func initValueWrongCRC() throws {
        let address = makeAddress()
        var chars = Array(address.value)
        let lastChar: Character = chars[chars.count - 1] == "A" ? "B" : "A"
        chars[chars.count - 1] = lastChar
        let modified = String(chars)

        #expect(throws: TONUserFriendlyAddressValidationError.self) {
            try TONUserFriendlyAddress(value: modified)
        }
    }

    @Test("raw address round trip preserves values")
    func rawRoundTrip() throws {
        let raw = TONRawAddress(workchain: 0, hash: testHash)
        let friendly = raw.userFriendly(isBounceable: true)
        let parsed = try TONUserFriendlyAddress(value: friendly.value)

        #expect(parsed.raw.workchain == raw.workchain)
        #expect(parsed.raw.hash == raw.hash)
    }

    @Test("Codable round trip preserves value")
    func codableRoundTrip() throws {
        let original = makeAddress()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TONUserFriendlyAddress.self, from: data)

        #expect(decoded.value == original.value)
    }

    @Test("Equatable compares by raw address")
    func equatable() {
        let a = makeAddress(isBounceable: true)
        let b = makeAddress(isBounceable: false)

        #expect(a == b)
    }

    @Test("nonURLSafeValue replaces URL-safe characters")
    func nonURLSafeValue() {
        let address = makeAddress()
        let nonSafe = address.nonURLSafeValue

        #expect(!nonSafe.contains("-"))
        #expect(!nonSafe.contains("_"))
    }

    @Test("workchain -1 maps correctly")
    func workchainNegativeOne() throws {
        let address = makeAddress(workchain: -1)
        let parsed = try TONUserFriendlyAddress(value: address.value)

        #expect(parsed.workchain == -1)
    }
}
