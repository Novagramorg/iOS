import Testing
import Foundation
@testable import TONWalletKit

@Suite("TONWalletSignMessageRequest Tests")
struct TONWalletSignMessageRequestTests {

    private let testAddress: TONUserFriendlyAddress = {
        let hash = Data(repeating: 0xab, count: 32)
        return TONRawAddress(workchain: 0, hash: hash).userFriendly(isBounceable: true)
    }()

    private func makeEvent() -> TONSignMessageRequestEvent {
        TONSignMessageRequestEvent(
            id: "event-1",
            preview: TONSendTransactionRequestEventPreview(),
            request: TONTransactionRequest(messages: [])
        )
    }

    private func makeEmbeddedEvent() -> TONEmbeddedSignMessageRequestEvent {
        TONEmbeddedSignMessageRequestEvent(
            id: "embedded-event-1",
            preview: TONSendTransactionRequestEventPreview(),
            request: TONTransactionRequest(messages: []),
            connectionResult: AnyCodable("connection-token")
        )
    }

    @Test("approve() calls approveSignMessageRequest")
    func approveCallsApprove() async throws {
        let mock = MockJSDynamicObject()
        let event = makeEvent()
        let sut = TONWalletSignMessageRequest(context: mock, event: event)

        _ = try? await sut.approve()

        let paths = mock.callRecords.map(\.path)
        #expect(paths.contains("walletKit.approveSignMessageRequest"))
    }

    @Test("approve() with throwing context throws")
    func approveThrowsOnError() async {
        let mock = MockJSDynamicObject()
        mock.shouldThrowOnCall = true
        let event = makeEvent()
        let sut = TONWalletSignMessageRequest(context: mock, event: event)

        await #expect(throws: (any Error).self) {
            try await sut.approve()
        }
    }

    @Test("reject() calls rejectSignMessageRequest")
    func rejectCallsReject() async throws {
        let mock = MockJSDynamicObject()
        let event = makeEvent()
        let sut = TONWalletSignMessageRequest(context: mock, event: event)

        try await sut.reject()

        let paths = mock.callRecords.map(\.path)
        #expect(paths.contains("walletKit.rejectSignMessageRequest"))
    }

    @Test("reject() with throwing context throws")
    func rejectThrowsOnError() async {
        let mock = MockJSDynamicObject()
        mock.shouldThrowOnCall = true
        let event = makeEvent()
        let sut = TONWalletSignMessageRequest(context: mock, event: event)

        await #expect(throws: (any Error).self) {
            try await sut.reject()
        }
    }

    @Test("init(embeddedEvent:) populates public event from embedded fields")
    func embeddedInitCopiesFields() {
        let mock = MockJSDynamicObject()
        let embedded = makeEmbeddedEvent()
        let sut = TONWalletSignMessageRequest(context: mock, embeddedEvent: embedded)

        #expect(sut.event.id == "embedded-event-1")
    }

    @Test("approve() routes through approveSignMessageRequest whether event or embedded")
    func approveRoutesThroughCorrectMethodForEmbeddedInit() async throws {
        let mock = MockJSDynamicObject()
        let embedded = makeEmbeddedEvent()
        let sut = TONWalletSignMessageRequest(context: mock, embeddedEvent: embedded)

        _ = try? await sut.approve()

        let paths = mock.callRecords.map(\.path)
        #expect(paths.contains("walletKit.approveSignMessageRequest"))
    }

    @Test("reject() forwards embedded event when wrapper was built from one")
    func rejectForwardsEmbeddedEvent() async throws {
        let mock = MockJSDynamicObject()
        let embedded = makeEmbeddedEvent()
        let sut = TONWalletSignMessageRequest(context: mock, embeddedEvent: embedded)

        try await sut.reject(reason: "user rejected")

        let rejectCall = mock.callRecords.first { $0.path == "walletKit.rejectSignMessageRequest" }
        #expect(rejectCall != nil)
        #expect(rejectCall?.args.first is TONEmbeddedSignMessageRequestEvent)
    }

    @Test("reject() forwards plain event when wrapper was built without embedded")
    func rejectForwardsPlainEvent() async throws {
        let mock = MockJSDynamicObject()
        let event = makeEvent()
        let sut = TONWalletSignMessageRequest(context: mock, event: event)

        try await sut.reject(reason: "user rejected")

        let rejectCall = mock.callRecords.first { $0.path == "walletKit.rejectSignMessageRequest" }
        #expect(rejectCall != nil)
        #expect(rejectCall?.args.first is TONSignMessageRequestEvent)
    }
}
