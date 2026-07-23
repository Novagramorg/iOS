import Testing
import Foundation
import Combine
import JavaScriptCore
@testable import TONWalletKit

@Suite("TONStreamingProvider Tests")
struct TONStreamingProviderTests {

    private func makeSUT() -> (sut: TONStreamingProvider, mock: MockJSDynamicObject) {
        let mock = MockJSDynamicObject()
        let sut = TONStreamingProvider(jsObject: mock, identifier: AnyTONProviderIdentifier(name: "test-provider"))
        return (sut, mock)
    }

    @Test("balance calls watchBalance with correct address")
    func balanceCallsWatchBalance() {
        let (sut, mock) = makeSUT()

        let cancellable = sut.balance(address: "test-address").sink(
            receiveCompletion: { _ in },
            receiveValue: { _ in }
        )

        #expect(mock.callRecords.count == 1)
        #expect(mock.callRecords[0].path == "watchBalance")
        #expect(mock.callRecords[0].args[0] as? String == "test-address")
        cancellable.cancel()
    }

    @Test("transactions calls watchTransactions with correct address")
    func transactionsCallsWatchTransactions() {
        let (sut, mock) = makeSUT()

        let cancellable = sut.transactions(address: "test-address").sink(
            receiveCompletion: { _ in },
            receiveValue: { _ in }
        )

        #expect(mock.callRecords.count == 1)
        #expect(mock.callRecords[0].path == "watchTransactions")
        #expect(mock.callRecords[0].args[0] as? String == "test-address")
        cancellable.cancel()
    }

    @Test("jettons calls watchJettons with correct address")
    func jettonsCallsWatchJettons() {
        let (sut, mock) = makeSUT()

        let cancellable = sut.jettons(address: "test-address").sink(
            receiveCompletion: { _ in },
            receiveValue: { _ in }
        )

        #expect(mock.callRecords.count == 1)
        #expect(mock.callRecords[0].path == "watchJettons")
        #expect(mock.callRecords[0].args[0] as? String == "test-address")
        cancellable.cancel()
    }

    @Test("balance delivers values through JS handler")
    func balanceDeliversValues() throws {
        let (sut, mock) = makeSUT()
        let update = MockStreamingData.balanceUpdate(status: .confirmed, balance: "2.5")

        var received: TONBalanceUpdate?
        let cancellable = sut.balance(address: "test-address").sink(
            receiveCompletion: { _ in },
            receiveValue: { received = $0 }
        )

        let handler = mock.callRecords[0].args[1] as! JSValue
        let encoded = try update.encode(in: mock.jsContext)
        handler.call(withArguments: [encoded])

        #expect(received?.status == .confirmed)
        #expect(received?.balance == "2.5")
        cancellable.cancel()
    }

    @Test("transactions delivers values through JS handler")
    func transactionsDeliversValues() throws {
        let (sut, mock) = makeSUT()
        let update = MockStreamingData.transactionsUpdate(status: .finalized)

        var received: TONTransactionsUpdate?
        let cancellable = sut.transactions(address: "test-address").sink(
            receiveCompletion: { _ in },
            receiveValue: { received = $0 }
        )

        let handler = mock.callRecords[0].args[1] as! JSValue
        let encoded = try update.encode(in: mock.jsContext)
        handler.call(withArguments: [encoded])

        #expect(received?.status == .finalized)
        #expect(received?.transactions.count == 1)
        cancellable.cancel()
    }

    @Test("jettons delivers values through JS handler")
    func jettonsDeliversValues() throws {
        let (sut, mock) = makeSUT()
        let update = MockStreamingData.jettonUpdate(status: .pending, balance: "50.0")

        var received: TONJettonUpdate?
        let cancellable = sut.jettons(address: "test-address").sink(
            receiveCompletion: { _ in },
            receiveValue: { received = $0 }
        )

        let handler = mock.callRecords[0].args[1] as! JSValue
        let encoded = try update.encode(in: mock.jsContext)
        handler.call(withArguments: [encoded])

        #expect(received?.status == .pending)
        #expect(received?.balance == "50.0")
        cancellable.cancel()
    }

    @Test("balance sends failure when watch throws")
    func balanceSendsFailureOnThrow() {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        var completionError: (any Error)?
        let cancellable = sut.balance(address: "test-address").sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    completionError = error
                }
            },
            receiveValue: { _ in }
        )

        #expect(completionError != nil)
        cancellable.cancel()
    }

    @Test("transactions sends failure when watch throws")
    func transactionsSendsFailureOnThrow() {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        var completionError: (any Error)?
        let cancellable = sut.transactions(address: "test-address").sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    completionError = error
                }
            },
            receiveValue: { _ in }
        )

        #expect(completionError != nil)
        cancellable.cancel()
    }

    @Test("jettons sends failure when watch throws")
    func jettonsSendsFailureOnThrow() {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        var completionError: (any Error)?
        let cancellable = sut.jettons(address: "test-address").sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    completionError = error
                }
            },
            receiveValue: { _ in }
        )

        #expect(completionError != nil)
        cancellable.cancel()
    }

    @Test("balance cancel stops delivering values")
    func balanceCancelStopsDelivery() throws {
        let (sut, mock) = makeSUT()
        let update = MockStreamingData.balanceUpdate()

        var receivedCount = 0
        let cancellable = sut.balance(address: "test-address").sink(
            receiveCompletion: { _ in },
            receiveValue: { _ in receivedCount += 1 }
        )

        let handler = mock.callRecords[0].args[1] as! JSValue
        let encoded = try update.encode(in: mock.jsContext)

        handler.call(withArguments: [encoded])
        #expect(receivedCount == 1)

        cancellable.cancel()

        handler.call(withArguments: [encoded])
        #expect(receivedCount == 1)
    }

    @Test("transactions cancel stops delivering values")
    func transactionsCancelStopsDelivery() throws {
        let (sut, mock) = makeSUT()
        let update = MockStreamingData.transactionsUpdate()

        var receivedCount = 0
        let cancellable = sut.transactions(address: "test-address").sink(
            receiveCompletion: { _ in },
            receiveValue: { _ in receivedCount += 1 }
        )

        let handler = mock.callRecords[0].args[1] as! JSValue
        let encoded = try update.encode(in: mock.jsContext)

        handler.call(withArguments: [encoded])
        #expect(receivedCount == 1)

        cancellable.cancel()

        handler.call(withArguments: [encoded])
        #expect(receivedCount == 1)
    }

    @Test("jettons cancel stops delivering values")
    func jettonsCancelStopsDelivery() throws {
        let (sut, mock) = makeSUT()
        let update = MockStreamingData.jettonUpdate()

        var receivedCount = 0
        let cancellable = sut.jettons(address: "test-address").sink(
            receiveCompletion: { _ in },
            receiveValue: { _ in receivedCount += 1 }
        )

        let handler = mock.callRecords[0].args[1] as! JSValue
        let encoded = try update.encode(in: mock.jsContext)

        handler.call(withArguments: [encoded])
        #expect(receivedCount == 1)

        cancellable.cancel()

        handler.call(withArguments: [encoded])
        #expect(receivedCount == 1)
    }

    @Test("identifier returns the identifier passed at init")
    func identifierReturnsValue() {
        let (sut, _) = makeSUT()

        #expect(sut.identifier.name == "test-provider")
    }

    @Test("type returns streaming")
    func typeReturnsStreaming() {
        let (sut, _) = makeSUT()

        #expect(sut.type == .streaming)
    }

    @Test("network reads network from jsObject")
    func networkReadsFromJS() throws {
        let (sut, mock) = makeSUT()
        mock.stubbedProperties["network"] = TONNetwork(chainId: "-239")

        let network = try sut.network

        #expect(network.chainId == "-239")
    }

    @Test("network throws .streamingNetworkUnavailable when jsObject has no network")
    func networkThrowsWhenMissing() {
        let (sut, _) = makeSUT()

        let error = #expect(throws: TONWalletKitError.self) {
            try sut.network
        }

        guard case .streamingNetworkUnavailable? = error else {
            Issue.record("Expected .streamingNetworkUnavailable, got \(String(describing: error))")
            return
        }
    }

    @Test("connect calls connect on jsObject")
    func connectCallsJS() throws {
        let (sut, mock) = makeSUT()

        try sut.connect()

        #expect(mock.callRecords.count == 1)
        #expect(mock.callRecords[0].path == "connect")
    }

    @Test("disconnect calls disconnect on jsObject")
    func disconnectCallsJS() throws {
        let (sut, mock) = makeSUT()

        try sut.disconnect()

        #expect(mock.callRecords.count == 1)
        #expect(mock.callRecords[0].path == "disconnect")
    }

    @Test("connect throws when jsObject throws")
    func connectThrowsOnError() {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        #expect(throws: (any Error).self) {
            try sut.connect()
        }
    }

    @Test("disconnect throws when jsObject throws")
    func disconnectThrowsOnError() {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        #expect(throws: (any Error).self) {
            try sut.disconnect()
        }
    }

    @Test("connectionChange calls onConnectionChange on jsObject")
    func connectionChangeCallsJS() {
        let (sut, mock) = makeSUT()

        let cancellable = sut.connectionChange().sink(
            receiveCompletion: { _ in },
            receiveValue: { _ in }
        )

        #expect(mock.callRecords.count == 1)
        #expect(mock.callRecords[0].path == "onConnectionChange")
        cancellable.cancel()
    }

    @Test("connectionChange delivers values through JS handler")
    func connectionChangeDeliversValues() throws {
        let (sut, mock) = makeSUT()

        var received: Bool?
        let cancellable = sut.connectionChange().sink(
            receiveCompletion: { _ in },
            receiveValue: { received = $0 }
        )

        let handler = mock.callRecords[0].args[0] as! JSValue
        handler.call(withArguments: [true])

        #expect(received == true)
        cancellable.cancel()
    }

    @Test("connectionChange sends failure when watch throws")
    func connectionChangeSendsFailureOnThrow() {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        var completionError: (any Error)?
        let cancellable = sut.connectionChange().sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    completionError = error
                }
            },
            receiveValue: { _ in }
        )

        #expect(completionError != nil)
        cancellable.cancel()
    }

    @Test("connectionChange cancel stops delivering values")
    func connectionChangeCancelStopsDelivery() throws {
        let (sut, mock) = makeSUT()

        var receivedCount = 0
        let cancellable = sut.connectionChange().sink(
            receiveCompletion: { _ in },
            receiveValue: { _ in receivedCount += 1 }
        )

        let handler = mock.callRecords[0].args[0] as! JSValue

        handler.call(withArguments: [true])
        #expect(receivedCount == 1)

        cancellable.cancel()

        handler.call(withArguments: [false])
        #expect(receivedCount == 1)
    }
}
