import XCTest
@testable import TONCore

final class TransferURLTests: XCTestCase {
    private let address = Address(workchain: 0, hash: Data(repeating: 0x42, count: 32))

    func testParsesBareRawAndFriendlyAddresses() throws {
        let raw = try TransferURL.parse(address.rawString)
        XCTAssertEqual(raw.address, address)
        XCTAssertFalse(raw.isTestOnly)
        XCTAssertNil(raw.amount)
        XCTAssertNil(raw.text)

        let testOnlyString = address.toString(bounceable: true, testOnly: true)
        let friendly = try TransferURL.parse(testOnlyString)
        XCTAssertEqual(friendly.address, address)
        XCTAssertTrue(friendly.isTestOnly)
        XCTAssertEqual(friendly.addressString(), address.toString(bounceable: false, testOnly: true))
    }

    func testParsesTransferLinkParameters() throws {
        let friendly = address.toString(bounceable: true)
        let transfer = try TransferURL.parse(
            "  ton://transfer/\(friendly)?amount=1234567890&text=Hello%20TON  "
        )
        XCTAssertEqual(transfer.address, address)
        XCTAssertEqual(transfer.amount, BigUInt(1_234_567_890))
        XCTAssertEqual(transfer.text, "Hello TON")
        XCTAssertFalse(transfer.isTestOnly)
    }

    func testRejectsInvalidLinks() throws {
        XCTAssertThrowsError(try TransferURL.parse(""))
        XCTAssertThrowsError(try TransferURL.parse("ton://connect/example"))
        XCTAssertThrowsError(try TransferURL.parse("ton://transfer/"))
        XCTAssertThrowsError(
            try TransferURL.parse("ton://transfer/\(address.toString())?amount=-1")
        )
        XCTAssertThrowsError(
            try TransferURL.parse("ton://transfer/not-an-address")
        )
    }
}
