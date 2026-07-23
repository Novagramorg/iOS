import Testing
import Foundation
@testable import TONWalletKit

@Suite("TONWalletSignDataRequest Tests")
struct TONWalletSignDataRequestTests {

    private let testAddress: TONUserFriendlyAddress = {
        let hash = Data(repeating: 0xab, count: 32)
        return TONRawAddress(workchain: 0, hash: hash).userFriendly(isBounceable: true)
    }()

    private func makeEvent() -> TONSignDataRequestEvent {
        TONSignDataRequestEvent(
            id: "event-1",
            payload: TONSignDataPayload(
                data: .text(TONSignDataText(content: "test"))
            ),
            preview: TONSignDataRequestEventPreview(
                data: .text(TONSignDataPreviewText(content: "test"))
            )
        )
    }

    @Test("approve() calls approveSignDataRequest")
    func approveCallsApprove() async throws {
        let mock = MockJSDynamicObject()
        let event = makeEvent()
        let sut = TONWalletSignDataRequest(context: mock, event: event)

        _ = try? await sut.approve()

        let paths = mock.callRecords.map(\.path)
        #expect(paths.contains("walletKit.approveSignDataRequest"))
    }

    @Test("approve() with throwing context throws")
    func approveThrowsOnError() async {
        let mock = MockJSDynamicObject()
        mock.shouldThrowOnCall = true
        let event = makeEvent()
        let sut = TONWalletSignDataRequest(context: mock, event: event)

        await #expect(throws: (any Error).self) {
            try await sut.approve()
        }
    }

    @Test("reject() calls rejectSignDataRequest")
    func rejectCallsReject() async throws {
        let mock = MockJSDynamicObject()
        let event = makeEvent()
        let sut = TONWalletSignDataRequest(context: mock, event: event)

        try await sut.reject()

        let paths = mock.callRecords.map(\.path)
        #expect(paths.contains("walletKit.rejectSignDataRequest"))
    }

    @Test("reject() with throwing context throws")
    func rejectThrowsOnError() async {
        let mock = MockJSDynamicObject()
        mock.shouldThrowOnCall = true
        let event = makeEvent()
        let sut = TONWalletSignDataRequest(context: mock, event: event)

        await #expect(throws: (any Error).self) {
            try await sut.reject()
        }
    }
}
