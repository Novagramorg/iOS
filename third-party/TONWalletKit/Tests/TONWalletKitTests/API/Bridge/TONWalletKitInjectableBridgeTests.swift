import Testing
import Foundation
import Combine
@testable import TONWalletKit

@Suite("TONWalletKitInjectableBridge Tests")
struct TONWalletKitInjectableBridgeTests {

    @Test("request calls processInjectedBridgeRequest on context")
    func requestCallsProcessInjectedBridgeRequest() async throws {
        let mock = MockJSDynamicObject()
        let transport = JSBridgeTransport()
        let sut = TONWalletKitInjectableBridge(jsWalletKit: mock, bridgeTransport: transport)
        let message = TONBridgeEventMessage(
            messageId: "msg-1",
            tabId: nil,
            domain: nil,
            walletId: "wallet-id"
        )

        try await sut.request(message: message, request: "request-data")

        #expect(mock.callRecords.count == 1)
        #expect(mock.callRecords[0].path == "processInjectedBridgeRequest")
    }

    @Test("request throws when mock throws")
    func requestThrowsOnError() async {
        let mock = MockJSDynamicObject()
        mock.shouldThrowOnCall = true
        let transport = JSBridgeTransport()
        let sut = TONWalletKitInjectableBridge(jsWalletKit: mock, bridgeTransport: transport)
        let message = TONBridgeEventMessage(
            messageId: "msg-1",
            tabId: nil,
            domain: nil,
            walletId: "wallet-id"
        )

        await #expect(throws: (any Error).self) {
            try await sut.request(message: message, request: "data")
        }
    }

    @Test("waitForResponse maps fields from transport response")
    func waitForResponseMapsFields() {
        let mock = MockJSDynamicObject()
        let transport = JSBridgeTransport()
        let sut = TONWalletKitInjectableBridge(jsWalletKit: mock, bridgeTransport: transport)
        var receivedResponse: TONWalletKitInjectableBridge.Response?

        let cancellable = sut.waitForResponse().sink(
            receiveCompletion: { _ in },
            receiveValue: { response in
                receivedResponse = response
            }
        )

        transport.send(response: JSBridgeTransportResponse(
            sessionID: "session-1",
            messageID: "msg-1",
            message: AnyCodable("hello")
        ))

        #expect(receivedResponse?.sessionID == "session-1")
        #expect(receivedResponse?.messageID == "msg-1")
        _ = cancellable
    }

    @Test("waitForResponse passes nil fields")
    func waitForResponseNilFields() {
        let mock = MockJSDynamicObject()
        let transport = JSBridgeTransport()
        let sut = TONWalletKitInjectableBridge(jsWalletKit: mock, bridgeTransport: transport)
        var receivedResponse: TONWalletKitInjectableBridge.Response?

        let cancellable = sut.waitForResponse().sink(
            receiveCompletion: { _ in },
            receiveValue: { response in
                receivedResponse = response
            }
        )

        transport.send(response: JSBridgeTransportResponse(
            sessionID: nil,
            messageID: nil,
            message: nil
        ))

        #expect(receivedResponse?.sessionID == nil)
        #expect(receivedResponse?.messageID == nil)
        #expect(receivedResponse?.message == nil)
        _ = cancellable
    }

    @Test("Response struct stores values")
    func responseStoresValues() {
        let sut = TONWalletKitInjectableBridge.Response(
            sessionID: "s1",
            messageID: "m1",
            message: AnyCodable("test")
        )

        #expect(sut.sessionID == "s1")
        #expect(sut.messageID == "m1")
    }
}
