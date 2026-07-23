import Testing
import Foundation
@testable import TONWalletKit

@Suite("TONWalletSendTransactionRequest Tests")
struct TONWalletSendTransactionRequestTests {

    private func makeEvent() -> TONSendTransactionRequestEvent {
        TONSendTransactionRequestEvent(
            id: "event-1",
            preview: TONSendTransactionRequestEventPreview(),
            request: TONTransactionRequest(messages: [])
        )
    }

    @Test("approve() calls approveTransactionRequest")
    func approveCallsApprove() async throws {
        let mock = MockJSDynamicObject()
        let event = makeEvent()
        let sut = TONWalletSendTransactionRequest(context: mock, event: event)

        _ = try? await sut.approve()

        let paths = mock.callRecords.map(\.path)
        #expect(paths.contains("walletKit.approveTransactionRequest"))
    }

    @Test("approve() with throwing context throws")
    func approveThrowsOnError() async {
        let mock = MockJSDynamicObject()
        mock.shouldThrowOnCall = true
        let event = makeEvent()
        let sut = TONWalletSendTransactionRequest(context: mock, event: event)

        await #expect(throws: (any Error).self) {
            try await sut.approve()
        }
    }

    @Test("reject() calls rejectTransactionRequest")
    func rejectCallsReject() async throws {
        let mock = MockJSDynamicObject()
        let event = makeEvent()
        let sut = TONWalletSendTransactionRequest(context: mock, event: event)

        try await sut.reject()

        let paths = mock.callRecords.map(\.path)
        #expect(paths.contains("walletKit.rejectTransactionRequest"))
    }

    @Test("reject() with throwing context throws")
    func rejectThrowsOnError() async {
        let mock = MockJSDynamicObject()
        mock.shouldThrowOnCall = true
        let event = makeEvent()
        let sut = TONWalletSendTransactionRequest(context: mock, event: event)

        await #expect(throws: (any Error).self) {
            try await sut.reject()
        }
    }
}
