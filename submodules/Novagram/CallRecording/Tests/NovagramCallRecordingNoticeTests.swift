import XCTest
@testable import NovagramCallRecording

final class NovagramCallRecordingNoticeLedgerTests: XCTestCase {
    func testSentOncePerCall() {
        var ledger = NovagramCallRecordingNoticeLedger()
        let callId = UUID()
        XCTAssertTrue(ledger.beginSending(callId: callId))
        // Stop, then Record again while the notice is still on its way.
        XCTAssertFalse(ledger.beginSending(callId: callId))
        ledger.markEnqueued(callId: callId)
        // Stop, then Record again after it was enqueued.
        XCTAssertFalse(ledger.beginSending(callId: callId))
        XCTAssertEqual(ledger.status(callId: callId), .enqueued)
    }

    func testEachCallGetsItsOwnNotice() {
        var ledger = NovagramCallRecordingNoticeLedger()
        let first = UUID()
        let second = UUID()
        XCTAssertTrue(ledger.beginSending(callId: first))
        XCTAssertTrue(ledger.beginSending(callId: second))
        XCTAssertFalse(ledger.beginSending(callId: first))
    }

    func testFailedNoticeIsSentAgainOnTheNextRecord() {
        var ledger = NovagramCallRecordingNoticeLedger()
        let callId = UUID()
        XCTAssertTrue(ledger.beginSending(callId: callId))
        ledger.markFailed(callId: callId)
        XCTAssertEqual(ledger.status(callId: callId), .failed)
        XCTAssertTrue(ledger.beginSending(callId: callId))
        XCTAssertEqual(ledger.status(callId: callId), .sending)
    }

    func testForgetClearsTheCall() {
        var ledger = NovagramCallRecordingNoticeLedger()
        let callId = UUID()
        XCTAssertTrue(ledger.beginSending(callId: callId))
        ledger.forget(callId: callId)
        XCTAssertNil(ledger.status(callId: callId))
    }
}
