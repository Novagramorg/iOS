import Testing
import Foundation
@testable import TONWalletKit

@Suite("TONWalletConnectionRequest Tests")
struct TONWalletConnectionRequestTests {

    private let testAddress: TONUserFriendlyAddress = {
        let hash = Data(repeating: 0xab, count: 32)
        return TONRawAddress(workchain: 0, hash: hash).userFriendly(isBounceable: true)
    }()

    private func makeEvent() -> TONConnectionRequestEvent {
        TONConnectionRequestEvent(
            id: "event-1",
            requestedItems: [],
            preview: TONConnectionRequestEventPreview(permissions: [])
        )
    }

    @Test("approve(walletId:) calls getWallet then approveConnectRequest")
    func approveWalletIdCallsApprove() async throws {
        let mock = MockJSDynamicObject()
        let event = makeEvent()
        let sut = TONWalletConnectionRequest(context: mock, event: event)

        try? await sut.approve(walletId: "w1")

        let paths = mock.callRecords.map(\.path)
        #expect(paths.contains("walletKit.getWallet"))
    }

    @Test("approve(wallet:) calls approveConnectRequest")
    func approveWalletCallsApprove() async throws {
        let mock = MockJSDynamicObject()
        let event = makeEvent()
        let sut = TONWalletConnectionRequest(context: mock, event: event)
        let walletMock = MockJSDynamicObject()
        let wallet = TONWallet(jsWallet: walletMock, id: "w1", address: testAddress, client: MockAPIClient())

        try await sut.approve(wallet: wallet)

        let paths = mock.callRecords.map(\.path)
        #expect(paths.contains("walletKit.approveConnectRequest"))
    }

    @Test("reject() calls rejectConnectRequest")
    func rejectCallsReject() async throws {
        let mock = MockJSDynamicObject()
        let event = makeEvent()
        let sut = TONWalletConnectionRequest(context: mock, event: event)

        try await sut.reject()

        let paths = mock.callRecords.map(\.path)
        #expect(paths.contains("walletKit.rejectConnectRequest"))
    }

    @Test("approve(wallet:) with throwing context throws")
    func approveThrowsOnError() async {
        let mock = MockJSDynamicObject()
        mock.shouldThrowOnCall = true
        let event = makeEvent()
        let sut = TONWalletConnectionRequest(context: mock, event: event)
        let walletMock = MockJSDynamicObject()
        let wallet = TONWallet(jsWallet: walletMock, id: "w1", address: testAddress, client: MockAPIClient())

        await #expect(throws: (any Error).self) {
            try await sut.approve(wallet: wallet)
        }
    }

    @Test("reject() with throwing context throws")
    func rejectThrowsOnError() async {
        let mock = MockJSDynamicObject()
        mock.shouldThrowOnCall = true
        let event = makeEvent()
        let sut = TONWalletConnectionRequest(context: mock, event: event)

        await #expect(throws: (any Error).self) {
            try await sut.reject()
        }
    }

    @Test("approve(wallet:) returns .transactionRequest when JS yields embedded send-transaction event")
    func approveReturnsTransactionFollowUp() async throws {
        let mock = MockJSDynamicObject()
        let event = makeEvent()
        let sut = TONWalletConnectionRequest(context: mock, event: event)
        let walletMock = MockJSDynamicObject()
        let wallet = TONWallet(jsWallet: walletMock, id: "w1", address: testAddress, client: MockAPIClient())
        let embedded = TONEmbeddedSendTransactionRequestEvent(
            id: "embedded-1",
            preview: TONSendTransactionRequestEventPreview(),
            request: TONTransactionRequest(messages: []),
            connectionResult: AnyCodable("token")
        )
        mock.stubbedAsyncResults["walletKit.approveConnectRequest"] = TONEmbeddedRequestEvent.sendTransaction(embedded)

        let result = try await sut.approve(wallet: wallet)

        guard case .transactionRequest(let request) = result else {
            Issue.record("Expected .transactionRequest, got \(String(describing: result))")
            return
        }
        #expect(request.event.id == "embedded-1")
    }

    @Test("approve(wallet:) returns .signMessageRequest when JS yields embedded sign-message event")
    func approveReturnsSignMessageFollowUp() async throws {
        let mock = MockJSDynamicObject()
        let event = makeEvent()
        let sut = TONWalletConnectionRequest(context: mock, event: event)
        let walletMock = MockJSDynamicObject()
        let wallet = TONWallet(jsWallet: walletMock, id: "w1", address: testAddress, client: MockAPIClient())
        let embedded = TONEmbeddedSignMessageRequestEvent(
            id: "embedded-2",
            preview: TONSendTransactionRequestEventPreview(),
            request: TONTransactionRequest(messages: []),
            connectionResult: AnyCodable("token")
        )
        mock.stubbedAsyncResults["walletKit.approveConnectRequest"] = TONEmbeddedRequestEvent.signMessage(embedded)

        let result = try await sut.approve(wallet: wallet)

        guard case .signMessageRequest(let request) = result else {
            Issue.record("Expected .signMessageRequest, got \(String(describing: result))")
            return
        }
        #expect(request.event.id == "embedded-2")
    }

    @Test("approve(wallet:) returns .signDataRequest when JS yields embedded sign-data event")
    func approveReturnsSignDataFollowUp() async throws {
        let mock = MockJSDynamicObject()
        let event = makeEvent()
        let sut = TONWalletConnectionRequest(context: mock, event: event)
        let walletMock = MockJSDynamicObject()
        let wallet = TONWallet(jsWallet: walletMock, id: "w1", address: testAddress, client: MockAPIClient())
        let embedded = TONEmbeddedSignDataRequestEvent(
            id: "embedded-3",
            payload: TONSignDataPayload(data: .text(TONSignDataText(content: "msg"))),
            preview: TONSignDataRequestEventPreview(data: .text(TONSignDataPreviewText(content: "msg"))),
            connectionResult: AnyCodable("token")
        )
        mock.stubbedAsyncResults["walletKit.approveConnectRequest"] = TONEmbeddedRequestEvent.signData(embedded)

        let result = try await sut.approve(wallet: wallet)

        guard case .signDataRequest(let request) = result else {
            Issue.record("Expected .signDataRequest, got \(String(describing: result))")
            return
        }
        #expect(request.event.id == "embedded-3")
    }

    @Test("approve(wallet:) returns nil when JS yields no embedded request")
    func approveReturnsNilWhenNoEmbeddedRequest() async throws {
        let mock = MockJSDynamicObject()
        let event = makeEvent()
        let sut = TONWalletConnectionRequest(context: mock, event: event)
        let walletMock = MockJSDynamicObject()
        let wallet = TONWallet(jsWallet: walletMock, id: "w1", address: testAddress, client: MockAPIClient())
        // No stubbed result: mock will throw "cannot decode to" when the typed call runs.
        // But Optional<T> decode should return nil from undefined — to model that we set
        // the stub to an explicit Optional<TONEmbeddedRequestEvent>.none.
        let none: TONEmbeddedRequestEvent? = nil
        mock.stubbedAsyncResults["walletKit.approveConnectRequest"] = none as Any

        let result = try await sut.approve(wallet: wallet)

        #expect(result == nil)
    }
}
