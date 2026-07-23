import Testing
import Foundation
import _BigInt
@testable import TONWalletKit

private struct MockBigIntTest: Decodable, Equatable {
    let a: BigInt
    let b: BigInt
    let c: BigInt
    let d: BigInt
    let e: BigInt
}

@Suite("BigInt JSON String Decoding Tests")
struct BigIntDecodingTests {

    private func decode(_ json: String) throws -> MockBigIntTest {
        let data = json.data(using: .utf8)!
        return try JSONDecoder().decode(MockBigIntTest.self, from: data)
    }

    private func decode(focus value: String) throws -> MockBigIntTest {
        let json = #"{"a":""# + value + #"","b":"1","c":"-1","d":"1000000000","e":"-1000000000"}"#
        return try decode(json)
    }

    @Test("All fields as positive integer strings")
    func allPositiveStrings() throws {
        let json = #"{"a":"0","b":"1","c":"2","d":"1000000000","e":"9999999999"}"#
        let sut = try decode(json)

        #expect(sut.a == BigInt(0))
        #expect(sut.b == BigInt(1))
        #expect(sut.c == BigInt(2))
        #expect(sut.d == BigInt(1_000_000_000))
        #expect(sut.e == BigInt(9_999_999_999))
    }

    @Test("All fields as negative integer strings")
    func allNegativeStrings() throws {
        let json = #"{"a":"-1","b":"-2","c":"-3","d":"-1000000000","e":"-9999999999"}"#
        let sut = try decode(json)

        #expect(sut.a == BigInt(-1))
        #expect(sut.b == BigInt(-2))
        #expect(sut.c == BigInt(-3))
        #expect(sut.d == BigInt(-1_000_000_000))
        #expect(sut.e == BigInt(-9_999_999_999))
    }

    @Test("Mixed positive and negative integer strings")
    func mixedSignStrings() throws {
        let json = #"{"a":"-100","b":"100","c":"-1","d":"1","e":"0"}"#
        let sut = try decode(json)

        #expect(sut.a == BigInt(-100))
        #expect(sut.b == BigInt(100))
        #expect(sut.c == BigInt(-1))
        #expect(sut.d == BigInt(1))
        #expect(sut.e == BigInt(0))
    }

    @Test("Single-digit string \"5\"")
    func singleDigit() throws {
        let sut = try decode(focus: "5")

        #expect(sut.a == BigInt(5))
    }

    @Test("Zero string \"0\"")
    func zeroString() throws {
        let sut = try decode(focus: "0")

        #expect(sut.a == BigInt(0))
    }

    @Test("Negative zero string \"-0\"")
    func negativeZeroString() throws {
        let sut = try decode(focus: "-0")

        #expect(sut.a == BigInt(0))
    }

    @Test("Leading zeros \"007\"")
    func leadingZerosString() throws {
        let sut = try decode(focus: "007")

        #expect(sut.a == BigInt(7))
    }

    @Test("Int64.max as string")
    func int64MaxString() throws {
        let sut = try decode(focus: "\(Int64.max)")

        #expect(sut.a == BigInt(Int64.max))
    }

    @Test("Int64.min as string")
    func int64MinString() throws {
        let sut = try decode(focus: "\(Int64.min)")

        #expect(sut.a == BigInt(Int64.min))
    }

    @Test("UInt64.max as string")
    func uint64MaxString() throws {
        let sut = try decode(focus: "\(UInt64.max)")

        #expect(sut.a == BigInt(UInt64.max))
    }

    @Test("Value beyond Int64.max as string")
    func beyondInt64MaxString() throws {
        let huge: BigInt = "99999999999999999999999999999999"
        let sut = try decode(focus: "99999999999999999999999999999999")

        #expect(sut.a == huge)
    }

    @Test("Value beyond Int64.min as string")
    func beyondInt64MinString() throws {
        let huge: BigInt = "-99999999999999999999999999999999"
        let sut = try decode(focus: "-99999999999999999999999999999999")

        #expect(sut.a == huge)
    }

    @Test("Value beyond UInt64.max as string")
    func beyondUInt64MaxString() throws {
        let huge: BigInt = "184467440737095516160"
        let sut = try decode(focus: "184467440737095516160")

        #expect(sut.a == huge)
    }

    @Test("Very long 100-digit positive string")
    func hundredDigitPositiveString() throws {
        let digits = String(repeating: "9", count: 100)
        let expected = BigInt(digits)!
        let sut = try decode(focus: digits)

        #expect(sut.a == expected)
    }

    @Test("Very long 100-digit negative string")
    func hundredDigitNegativeString() throws {
        let digits = "-" + String(repeating: "9", count: 100)
        let expected = BigInt(digits)!
        let sut = try decode(focus: digits)

        #expect(sut.a == expected)
    }

    @Test("Empty string \"\" throws DecodingError")
    func emptyString() {
        #expect(throws: DecodingError.self) {
            try decode(focus: "")
        }
    }

    @Test("Non-numeric string \"abc\" throws DecodingError")
    func nonNumericString() {
        #expect(throws: DecodingError.self) {
            try decode(focus: "abc")
        }
    }

    @Test("Alphanumeric string \"123abc\" throws DecodingError")
    func alphanumericString() {
        #expect(throws: DecodingError.self) {
            try decode(focus: "123abc")
        }
    }

    @Test("Floating-point string \"1.5\" throws DecodingError")
    func floatString() {
        #expect(throws: DecodingError.self) {
            try decode(focus: "1.5")
        }
    }

    @Test("Scientific notation string \"1e10\" throws DecodingError")
    func scientificNotationString() {
        #expect(throws: DecodingError.self) {
            try decode(focus: "1e10")
        }
    }

    @Test("Hex prefix string \"0x10\" decodes as 16")
    func hexPrefixString() throws {
        let sut = try decode(focus: "0x10")

        #expect(sut.a == BigInt(16))
    }

    @Test("Leading-plus string \"+42\" decodes as 42")
    func leadingPlusString() throws {
        let sut = try decode(focus: "+42")

        #expect(sut.a == BigInt(42))
    }

    @Test("Leading whitespace string \" 42\" throws DecodingError")
    func leadingWhitespaceString() {
        #expect(throws: DecodingError.self) {
            try decode(focus: " 42")
        }
    }

    @Test("Trailing whitespace string \"42 \" throws DecodingError")
    func trailingWhitespaceString() {
        #expect(throws: DecodingError.self) {
            try decode(focus: "42 ")
        }
    }

    @Test("Whitespace-only string \"   \" throws DecodingError")
    func whitespaceOnlyString() {
        #expect(throws: DecodingError.self) {
            try decode(focus: "   ")
        }
    }

    @Test("Just a minus sign \"-\" throws DecodingError")
    func justMinusString() {
        #expect(throws: DecodingError.self) {
            try decode(focus: "-")
        }
    }

    @Test("Double-minus string \"--5\" throws DecodingError")
    func doubleMinusString() {
        #expect(throws: DecodingError.self) {
            try decode(focus: "--5")
        }
    }

    @Test("Comma-grouped string \"1,000\" throws DecodingError")
    func commaGroupedString() {
        #expect(throws: DecodingError.self) {
            try decode(focus: "1,000")
        }
    }

    @Test("Underscore-grouped string \"1_000\" throws DecodingError")
    func underscoreGroupedString() {
        #expect(throws: DecodingError.self) {
            try decode(focus: "1_000")
        }
    }

    @Test("Internal-space string \"1 000\" throws DecodingError")
    func internalSpaceString() {
        #expect(throws: DecodingError.self) {
            try decode(focus: "1 000")
        }
    }

    @Test("Trailing dot string \"42.\" throws DecodingError")
    func trailingDotString() {
        #expect(throws: DecodingError.self) {
            try decode(focus: "42.")
        }
    }

    @Test("Leading dot string \".5\" throws DecodingError")
    func leadingDotString() {
        #expect(throws: DecodingError.self) {
            try decode(focus: ".5")
        }
    }

    @Test("Tab-padded string \"\\t42\\t\" throws DecodingError")
    func tabPaddedString() {
        #expect(throws: DecodingError.self) {
            try decode(focus: "\\t42\\t")
        }
    }

    @Test("Newline-padded string throws DecodingError")
    func newlinePaddedString() {
        #expect(throws: DecodingError.self) {
            try decode(focus: "\\n42\\n")
        }
    }

    @Test("All fields with very large string values")
    func allLargeStrings() throws {
        let big: BigInt = "12345678901234567890123456789012345678901234567890"
        let neg: BigInt = "-98765432109876543210987654321098765432109876543210"
        let json = #"{"a":"12345678901234567890123456789012345678901234567890","b":"-98765432109876543210987654321098765432109876543210","c":"1","d":"-1","e":"0"}"#
        let sut = try decode(json)

        #expect(sut.a == big)
        #expect(sut.b == neg)
        #expect(sut.c == BigInt(1))
        #expect(sut.d == BigInt(-1))
        #expect(sut.e == BigInt(0))
    }
}
