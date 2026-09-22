import Foundation
import XCTest
import TelegramCore
@testable import IntentsExtensionLib

/// The intents extension process outlives a single Siri request and keeps the account it
/// opened. When the user switches accounts in the app, that cached account is no longer the
/// current one, and Siri would go on reading the previous account's messages until the
/// process is killed (seen in device logs: the app switched back at 16:01, the extension
/// kept the other account until reinstalled at 16:09).
final class CachedAccountReuseTests: XCTestCase {
    private let first = AccountRecordId(rawValue: -3039772842040732916)
    private let second = AccountRecordId(rawValue: -9214012716347796525)

    func testCachedAccountIsReusedWhileItIsStillCurrent() {
        XCTAssertTrue(cachedAccountIsCurrent(cachedId: first, currentId: first))
    }

    func testCachedAccountIsDroppedWhenTheAppSwitchedAccounts() {
        XCTAssertFalse(cachedAccountIsCurrent(cachedId: first, currentId: second))
    }

    func testNothingIsReusedWithoutACacheOrWithoutACurrentAccount() {
        XCTAssertFalse(cachedAccountIsCurrent(cachedId: nil, currentId: first))
        XCTAssertFalse(cachedAccountIsCurrent(cachedId: first, currentId: nil))
    }
}
