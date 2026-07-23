import Testing
import Foundation
import _BigInt
@testable import TONWalletKit

@Suite("TONTokenAmountFormatter Tests")
struct TONTokenAmountFormatterTests {

    private func makeSUT(
        decimals: Int = 9,
        trailingZeroes: Bool = false
    ) -> TONTokenAmountFormatter {
        let formatter = TONTokenAmountFormatter()
        formatter.nanoUnitDecimalsNumber = decimals
        formatter.allowFractionalTrailingZeroes = trailingZeroes
        return formatter
    }

    @Test("string: 1 TON")
    func string1TON() {
        let sut = makeSUT()
        let result = sut.string(from: TONTokenAmount(nanoUnits: BigInt(1_000_000_000)))

        #expect(result == "1")
    }

    @Test("string: 0")
    func stringZero() {
        let sut = makeSUT()
        let result = sut.string(from: TONTokenAmount(nanoUnits: BigInt(0)))

        #expect(result == "0")
    }

    @Test("string: 0.5 TON")
    func stringHalfTON() {
        let sut = makeSUT()
        let result = sut.string(from: TONTokenAmount(nanoUnits: BigInt(500_000_000)))

        #expect(result == "0.5")
    }

    @Test("string: smallest unit 0.000000001")
    func stringSmallestUnit() {
        let sut = makeSUT()
        let result = sut.string(from: TONTokenAmount(nanoUnits: BigInt(1)))

        #expect(result == "0.000000001")
    }

    @Test("string: large number")
    func stringLargeNumber() {
        let sut = makeSUT()
        let result = sut.string(from: TONTokenAmount(nanoUnits: BigInt(123_456_789_000_000_000)))

        #expect(result == "123456789")
    }

    @Test("string: negative value")
    func stringNegative() {
        let sut = makeSUT()
        let result = sut.string(from: TONTokenAmount(nanoUnits: BigInt(-1_500_000_000)))

        #expect(result == "-1.5")
    }

    @Test("string: negative decimals returns nil")
    func stringNegativeDecimals() {
        let sut = makeSUT(decimals: -1)
        let result = sut.string(from: TONTokenAmount(nanoUnits: BigInt(100)))

        #expect(result == nil)
    }

    @Test("string: trailing zeros enabled")
    func stringTrailingZerosEnabled() {
        let sut = makeSUT(trailingZeroes: true)
        let result = sut.string(from: TONTokenAmount(nanoUnits: BigInt(100_000_000)))

        #expect(result == "0.100000000")
    }

    @Test("string: trailing zeros disabled")
    func stringTrailingZerosDisabled() {
        let sut = makeSUT(trailingZeroes: false)
        let result = sut.string(from: TONTokenAmount(nanoUnits: BigInt(100_000_000)))

        #expect(result == "0.1")
    }

    @Test("string: custom decimals")
    func stringCustomDecimals() {
        let sut = makeSUT(decimals: 2)
        let result = sut.string(from: TONTokenAmount(nanoUnits: BigInt(150)))

        #expect(result == "1.5")
    }

    @Test("amount: whole number")
    func amountWholeNumber() {
        let sut = makeSUT()
        let result = sut.amount(from: "1")

        #expect(result?.nanoUnits == BigInt(1_000_000_000))
    }

    @Test("amount: decimal number")
    func amountDecimal() {
        let sut = makeSUT()
        let result = sut.amount(from: "1.5")

        #expect(result?.nanoUnits == BigInt(1_500_000_000))
    }

    @Test("amount: smallest unit")
    func amountSmallestUnit() {
        let sut = makeSUT()
        let result = sut.amount(from: "0.000000001")

        #expect(result?.nanoUnits == BigInt(1))
    }

    @Test("amount: empty string returns nil")
    func amountEmpty() {
        let sut = makeSUT()
        let result = sut.amount(from: "")

        #expect(result == nil)
    }

    @Test("amount: invalid string returns nil")
    func amountInvalid() {
        let sut = makeSUT()
        let result = sut.amount(from: "abc")

        #expect(result == nil)
    }

    @Test("amount: too many dots returns nil")
    func amountTooManyDots() {
        let sut = makeSUT()
        let result = sut.amount(from: "1.2.3")

        #expect(result == nil)
    }

    @Test("amount: negative number")
    func amountNegative() {
        let sut = makeSUT()
        let result = sut.amount(from: "-1.5")

        #expect(result?.nanoUnits == BigInt(-1_500_000_000))
    }

    @Test("amount: truncates excess decimals")
    func amountTruncatesExcessDecimals() {
        let sut = makeSUT()
        let result = sut.amount(from: "1.1234567891")

        #expect(result?.nanoUnits == BigInt(1_123_456_789))
    }
}
