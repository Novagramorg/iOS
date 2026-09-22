import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramCore

/// The notification service extension records which message each delivered notification
/// stands for; the Siri intents extension reads it back to answer an announce-triggered
/// `INSearchForMessagesIntent` with that one message. Both sides go through the shared
/// account postbox, so this exercises the real store.
final class NotificationRequestMessageIdsTests: XCTestCase {
    private var basePath: String!
    private var postbox: Postbox!

    override func setUpWithError() throws {
        try super.setUpWithError()
        self.basePath = NSTemporaryDirectory() + "notification-request-ids-" + UUID().uuidString
        let encryptionParameters = ValueBoxEncryptionParameters(
            forceEncryptionIfNoSet: false,
            key: ValueBoxEncryptionParameters.Key(data: Data(count: 32))!,
            salt: ValueBoxEncryptionParameters.Salt(data: Data(count: 16))!
        )
        let opened = DispatchSemaphore(value: 0)
        var postbox: Postbox?
        let disposable = openPostbox(
            basePath: self.basePath,
            seedConfiguration: telegramPostboxSeedConfiguration,
            encryptionParameters: encryptionParameters,
            timestampForAbsoluteTimeBasedOperations: Int32(Date().timeIntervalSince1970),
            isMainProcess: true,
            isTemporary: true,
            isReadOnly: false,
            useCopy: false,
            useCaches: false,
            removeDatabaseOnError: true
        ).start(next: { result in
            if case let .postbox(value) = result {
                postbox = value
                opened.signal()
            }
        })
        XCTAssertEqual(opened.wait(timeout: .now() + 30.0), .success, "postbox did not open")
        disposable.dispose()
        self.postbox = try XCTUnwrap(postbox)
    }

    override func tearDownWithError() throws {
        self.postbox = nil
        let _ = try? FileManager.default.removeItem(atPath: self.basePath)
        try super.tearDownWithError()
    }

    private func transaction<T>(_ f: @escaping (Transaction) -> T) -> T? {
        let done = DispatchSemaphore(value: 0)
        var result: T?
        let disposable = self.postbox.transaction(f).start(next: { value in
            result = value
            done.signal()
        })
        XCTAssertEqual(done.wait(timeout: .now() + 30.0), .success, "transaction did not finish")
        disposable.dispose()
        return result
    }

    private func messageId(peer: Int64, id: Int32) -> MessageId {
        return MessageId(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(peer)), namespace: Namespaces.Message.Cloud, id: id)
    }

    func testRecordedMessageIdIsReadBackForTheSameRequest() {
        let expected = self.messageId(peer: 1001, id: 42)
        self.transaction { transaction in
            _internal_setNotificationRequestMessageId(transaction: transaction, requestIdentifier: "9C1D-REQUEST", messageId: expected)
        }
        let stored = self.transaction { transaction in
            return _internal_getNotificationRequestMessageId(transaction: transaction, requestIdentifier: "9C1D-REQUEST")
        }
        XCTAssertEqual(stored, expected)
    }

    func testUnknownRequestHasNoMessage() {
        self.transaction { transaction in
            _internal_setNotificationRequestMessageId(transaction: transaction, requestIdentifier: "known", messageId: self.messageId(peer: 1001, id: 1))
        }
        let stored = self.transaction { transaction in
            return _internal_getNotificationRequestMessageId(transaction: transaction, requestIdentifier: "unknown")
        }
        XCTAssertNil(stored ?? nil)
    }

    /// Request identifiers are per-delivery UUIDs that never repeat, so without a bound the
    /// store would grow by one row per notification for the life of the account.
    func testKeepsOnlyTheMostRecentLinks() {
        let limit = _internal_notificationRequestMessageIdsLimit
        self.transaction { transaction in
            for index in 0 ..< (limit + 1) {
                _internal_setNotificationRequestMessageId(transaction: transaction, requestIdentifier: "req-\(index)", messageId: self.messageId(peer: 1001, id: Int32(index)))
            }
        }
        let stored = self.transaction { transaction -> [MessageId?] in
            return [
                _internal_getNotificationRequestMessageId(transaction: transaction, requestIdentifier: "req-0"),
                _internal_getNotificationRequestMessageId(transaction: transaction, requestIdentifier: "req-1"),
                _internal_getNotificationRequestMessageId(transaction: transaction, requestIdentifier: "req-\(limit)"),
            ]
        }
        XCTAssertEqual(stored, [nil, self.messageId(peer: 1001, id: 1), self.messageId(peer: 1001, id: Int32(limit))])
    }

    func testRewritingARequestReplacesItsMessage() {
        self.transaction { transaction in
            _internal_setNotificationRequestMessageId(transaction: transaction, requestIdentifier: "req", messageId: self.messageId(peer: 1001, id: 1))
            _internal_setNotificationRequestMessageId(transaction: transaction, requestIdentifier: "req", messageId: self.messageId(peer: 1001, id: 2))
        }
        let stored = self.transaction { transaction in
            return _internal_getNotificationRequestMessageId(transaction: transaction, requestIdentifier: "req")
        }
        XCTAssertEqual(stored, self.messageId(peer: 1001, id: 2))
    }

    func testEachRequestKeepsItsOwnMessage() {
        let first = self.messageId(peer: 1001, id: 1)
        let second = self.messageId(peer: 2002, id: 7)
        self.transaction { transaction in
            _internal_setNotificationRequestMessageId(transaction: transaction, requestIdentifier: "first", messageId: first)
            _internal_setNotificationRequestMessageId(transaction: transaction, requestIdentifier: "second", messageId: second)
        }
        let stored = self.transaction { transaction -> [MessageId?] in
            return [
                _internal_getNotificationRequestMessageId(transaction: transaction, requestIdentifier: "first"),
                _internal_getNotificationRequestMessageId(transaction: transaction, requestIdentifier: "second"),
            ]
        }
        XCTAssertEqual(stored, [first, second])
    }
}
