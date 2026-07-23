import Testing
import Foundation
import Combine
import JavaScriptCore
@testable import TONWalletKit

@Suite("TONStreamingManager Tests")
struct TONStreamingManagerTests {

    private let network = TONNetwork(chainId: "-239")

    private func makeSUT() -> (sut: TONStreamingManager, mock: MockJSDynamicObject) {
        let mock = MockJSDynamicObject()
        let sut = TONStreamingManager(jsObject: mock)
        return (sut, mock)
    }

    @Test("hasProvider calls hasProvider on jsObject")
    func hasProviderCallsJS() throws {
        let (sut, mock) = makeSUT()
        mock.stubbedResults["hasProvider"] = true

        let result = try sut.hasProvider(network: network)

        #expect(mock.callRecords.count == 1)
        #expect(mock.callRecords[0].path == "hasProvider")
        #expect(result == true)
    }

    @Test("hasProvider throws when jsObject throws")
    func hasProviderThrows() {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        #expect(throws: (any Error).self) {
            try sut.hasProvider(network: network)
        }
    }

    @Test("balance calls watchBalance with network and address")
    func balanceCallsWatchBalance() {
        let (sut, mock) = makeSUT()

        let cancellable = sut.balance(network: network, address: "test-address").sink(
            receiveCompletion: { _ in },
            receiveValue: { _ in }
        )

        #expect(mock.callRecords.count == 1)
        #expect(mock.callRecords[0].path == "watchBalance")
        cancellable.cancel()
    }

    @Test("transactions calls watchTransactions with network and address")
    func transactionsCallsWatchTransactions() {
        let (sut, mock) = makeSUT()

        let cancellable = sut.transactions(network: network, address: "test-address").sink(
            receiveCompletion: { _ in },
            receiveValue: { _ in }
        )

        #expect(mock.callRecords.count == 1)
        #expect(mock.callRecords[0].path == "watchTransactions")
        cancellable.cancel()
    }

    @Test("jettons calls watchJettons with network and address")
    func jettonsCallsWatchJettons() {
        let (sut, mock) = makeSUT()

        let cancellable = sut.jettons(network: network, address: "test-address").sink(
            receiveCompletion: { _ in },
            receiveValue: { _ in }
        )

        #expect(mock.callRecords.count == 1)
        #expect(mock.callRecords[0].path == "watchJettons")
        cancellable.cancel()
    }

    @Test("updates calls watch with network, address and types")
    func updatesCallsWatch() {
        let (sut, mock) = makeSUT()

        let cancellable = sut.updates(
            network: network,
            address: "test-address",
            types: [.balance, .transactions]
        ).sink(
            receiveCompletion: { _ in },
            receiveValue: { _ in }
        )

        #expect(mock.callRecords.count == 1)
        #expect(mock.callRecords[0].path == "watch")
        cancellable.cancel()
    }

    @Test("balance delivers values through JS handler")
    func balanceDeliversValues() throws {
        let (sut, mock) = makeSUT()
        let update = MockStreamingData.balanceUpdate(status: .confirmed, balance: "3.0")

        var received: TONBalanceUpdate?
        let cancellable = sut.balance(network: network, address: "test-address").sink(
            receiveCompletion: { _ in },
            receiveValue: { received = $0 }
        )

        let handler = mock.callRecords[0].args[2] as! JSValue
        let encoded = try update.encode(in: mock.jsContext)
        handler.call(withArguments: [encoded])

        #expect(received?.status == .confirmed)
        #expect(received?.balance == "3.0")
        cancellable.cancel()
    }

    @Test("transactions delivers values through JS handler")
    func transactionsDeliversValues() throws {
        let (sut, mock) = makeSUT()
        let update = MockStreamingData.transactionsUpdate(status: .finalized)

        var received: TONTransactionsUpdate?
        let cancellable = sut.transactions(network: network, address: "test-address").sink(
            receiveCompletion: { _ in },
            receiveValue: { received = $0 }
        )

        let handler = mock.callRecords[0].args[2] as! JSValue
        let encoded = try update.encode(in: mock.jsContext)
        handler.call(withArguments: [encoded])

        #expect(received?.status == .finalized)
        #expect(received?.transactions.count == 1)
        cancellable.cancel()
    }

    @Test("jettons delivers values through JS handler")
    func jettonsDeliversValues() throws {
        let (sut, mock) = makeSUT()
        let update = MockStreamingData.jettonUpdate(status: .pending, balance: "99.9")

        var received: TONJettonUpdate?
        let cancellable = sut.jettons(network: network, address: "test-address").sink(
            receiveCompletion: { _ in },
            receiveValue: { received = $0 }
        )

        let handler = mock.callRecords[0].args[2] as! JSValue
        let encoded = try update.encode(in: mock.jsContext)
        handler.call(withArguments: [encoded])

        #expect(received?.status == .pending)
        #expect(received?.balance == "99.9")
        cancellable.cancel()
    }

    @Test("updates delivers balance update through JS handler")
    func updatesDeliversBalanceUpdate() throws {
        let (sut, mock) = makeSUT()
        let balanceUpdate = MockStreamingData.balanceUpdate(status: .confirmed)

        var received: TONStreamingUpdate?
        let cancellable = sut.updates(
            network: network,
            address: "test-address",
            types: [.balance]
        ).sink(
            receiveCompletion: { _ in },
            receiveValue: { received = $0 }
        )

        let handler = mock.callRecords[0].args[3] as! JSValue
        let encoded = try balanceUpdate.encode(in: mock.jsContext) as! JSValue
        handler.call(withArguments: [JSValue(undefinedIn: mock.jsContext)!, encoded])

        if case .balance(let update) = received {
            #expect(update.status == .confirmed)
        } else {
            #expect(Bool(false), "Expected .balance update")
        }
        cancellable.cancel()
    }

    @Test("balance sends failure when watch throws")
    func balanceSendsFailureOnThrow() {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        var completionError: (any Error)?
        let cancellable = sut.balance(network: network, address: "test-address").sink(
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
        let cancellable = sut.transactions(network: network, address: "test-address").sink(
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
        let cancellable = sut.jettons(network: network, address: "test-address").sink(
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

    @Test("updates sends failure when watch throws")
    func updatesSendsFailureOnThrow() {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        var completionError: (any Error)?
        let cancellable = sut.updates(
            network: network,
            address: "test-address",
            types: [.balance]
        ).sink(
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
        let cancellable = sut.balance(network: network, address: "test-address").sink(
            receiveCompletion: { _ in },
            receiveValue: { _ in receivedCount += 1 }
        )

        let handler = mock.callRecords[0].args[2] as! JSValue
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
        let cancellable = sut.transactions(network: network, address: "test-address").sink(
            receiveCompletion: { _ in },
            receiveValue: { _ in receivedCount += 1 }
        )

        let handler = mock.callRecords[0].args[2] as! JSValue
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
        let cancellable = sut.jettons(network: network, address: "test-address").sink(
            receiveCompletion: { _ in },
            receiveValue: { _ in receivedCount += 1 }
        )

        let handler = mock.callRecords[0].args[2] as! JSValue
        let encoded = try update.encode(in: mock.jsContext)

        handler.call(withArguments: [encoded])
        #expect(receivedCount == 1)

        cancellable.cancel()

        handler.call(withArguments: [encoded])
        #expect(receivedCount == 1)
    }

    @Test("updates cancel stops delivering values")
    func updatesCancelStopsDelivery() throws {
        let (sut, mock) = makeSUT()
        let update = MockStreamingData.balanceUpdate()

        var receivedCount = 0
        let cancellable = sut.updates(
            network: network,
            address: "test-address",
            types: [.balance]
        ).sink(
            receiveCompletion: { _ in },
            receiveValue: { _ in receivedCount += 1 }
        )

        let handler = mock.callRecords[0].args[3] as! JSValue
        let encoded = try update.encode(in: mock.jsContext) as! JSValue

        handler.call(withArguments: [JSValue(undefinedIn: mock.jsContext)!, encoded])
        #expect(receivedCount == 1)

        cancellable.cancel()

        handler.call(withArguments: [JSValue(undefinedIn: mock.jsContext)!, encoded])
        #expect(receivedCount == 1)
    }

    @Test("connect calls connect on jsObject")
    func connectCallsJS() throws {
        let (sut, mock) = makeSUT()

        try sut.connect()

        #expect(mock.callRecords.count == 1)
        #expect(mock.callRecords[0].path == "connect")
    }

    @Test("connect throws when jsObject throws")
    func connectThrowsOnError() {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        #expect(throws: (any Error).self) {
            try sut.connect()
        }
    }

    @Test("disconnect calls disconnect on jsObject")
    func disconnectCallsJS() throws {
        let (sut, mock) = makeSUT()

        try sut.disconnect()

        #expect(mock.callRecords.count == 1)
        #expect(mock.callRecords[0].path == "disconnect")
    }

    @Test("disconnect throws when jsObject throws")
    func disconnectThrowsOnError() {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        #expect(throws: (any Error).self) {
            try sut.disconnect()
        }
    }

    @Test("connectionChange calls onConnectionChange with network")
    func connectionChangeCallsJS() {
        let (sut, mock) = makeSUT()

        let cancellable = sut.connectionChange(network: network).sink(
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
        let cancellable = sut.connectionChange(network: network).sink(
            receiveCompletion: { _ in },
            receiveValue: { received = $0 }
        )

        let handler = mock.callRecords[0].args[1] as! JSValue
        handler.call(withArguments: [true])

        #expect(received == true)
        cancellable.cancel()
    }

    @Test("connectionChange sends failure when watch throws")
    func connectionChangeSendsFailureOnThrow() {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        var completionError: (any Error)?
        let cancellable = sut.connectionChange(network: network).sink(
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
        let cancellable = sut.connectionChange(network: network).sink(
            receiveCompletion: { _ in },
            receiveValue: { _ in receivedCount += 1 }
        )

        let handler = mock.callRecords[0].args[1] as! JSValue

        handler.call(withArguments: [true])
        #expect(receivedCount == 1)

        cancellable.cancel()

        handler.call(withArguments: [false])
        #expect(receivedCount == 1)
    }

    // MARK: - JS-bridge tests
    //
    // Each test drives `TONStreamingManager` against a real `JSContext` and asserts:
    //  - the handler the manager passed into JS shows up as `typeof === 'function'`
    //  - the JS-side invocation actually crossed the bridge back into Swift
    //  - the unwatch JSValue returned to JS is itself `typeof === 'function'`
    //    and runs when called from JS.

    @Test("balance: handler and unwatch are callable from JS")
    func balanceHandlerCallableFromJS() throws {
        let context = JSContext()!
        let update = MockStreamingData.balanceUpdate(status: .confirmed, balance: "5.0")
        context.setObject(try update.encode(in: context), forKeyedSubscript: "__update" as NSString)
        context.evaluateScript("""
            globalThis.__handlerType = null;
            globalThis.__unwatchCallCount = 0;
            function watchBalance(network, address, handler) {
                globalThis.__handlerType = typeof handler;
                handler(globalThis.__update);
                return function unwatch() { globalThis.__unwatchCallCount += 1; };
            }
        """)
        let sut = TONStreamingManager(jsObject: context)

        var received: TONBalanceUpdate?
        let cancellable = sut.balance(network: network, address: "addr").sink(
            receiveCompletion: { _ in },
            receiveValue: { received = $0 }
        )

        #expect(context.evaluateScript("globalThis.__handlerType")?.toString() == "function")
        #expect(received?.balance == "5.0")

        cancellable.cancel()
        #expect(context.evaluateScript("globalThis.__unwatchCallCount")?.toInt32() == 1)
    }

    @Test("transactions: handler and unwatch are callable from JS")
    func transactionsHandlerCallableFromJS() throws {
        let context = JSContext()!
        let update = MockStreamingData.transactionsUpdate(status: .finalized)
        context.setObject(try update.encode(in: context), forKeyedSubscript: "__update" as NSString)
        context.evaluateScript("""
            globalThis.__handlerType = null;
            globalThis.__unwatchCallCount = 0;
            function watchTransactions(network, address, handler) {
                globalThis.__handlerType = typeof handler;
                handler(globalThis.__update);
                return function unwatch() { globalThis.__unwatchCallCount += 1; };
            }
        """)
        let sut = TONStreamingManager(jsObject: context)

        var received: TONTransactionsUpdate?
        let cancellable = sut.transactions(network: network, address: "addr").sink(
            receiveCompletion: { _ in },
            receiveValue: { received = $0 }
        )

        #expect(context.evaluateScript("globalThis.__handlerType")?.toString() == "function")
        #expect(received?.status == .finalized)

        cancellable.cancel()
        #expect(context.evaluateScript("globalThis.__unwatchCallCount")?.toInt32() == 1)
    }

    @Test("jettons: handler and unwatch are callable from JS")
    func jettonsHandlerCallableFromJS() throws {
        let context = JSContext()!
        let update = MockStreamingData.jettonUpdate(balance: "42.0")
        context.setObject(try update.encode(in: context), forKeyedSubscript: "__update" as NSString)
        context.evaluateScript("""
            globalThis.__handlerType = null;
            globalThis.__unwatchCallCount = 0;
            function watchJettons(network, address, handler) {
                globalThis.__handlerType = typeof handler;
                handler(globalThis.__update);
                return function unwatch() { globalThis.__unwatchCallCount += 1; };
            }
        """)
        let sut = TONStreamingManager(jsObject: context)

        var received: TONJettonUpdate?
        let cancellable = sut.jettons(network: network, address: "addr").sink(
            receiveCompletion: { _ in },
            receiveValue: { received = $0 }
        )

        #expect(context.evaluateScript("globalThis.__handlerType")?.toString() == "function")
        #expect(received?.balance == "42.0")

        cancellable.cancel()
        #expect(context.evaluateScript("globalThis.__unwatchCallCount")?.toInt32() == 1)
    }

    @Test("updates: handler and unwatch are callable from JS")
    func updatesHandlerCallableFromJS() throws {
        let context = JSContext()!
        let update = TONStreamingUpdate.balance(MockStreamingData.balanceUpdate(balance: "3.0"))
        context.setObject(try update.encode(in: context), forKeyedSubscript: "__update" as NSString)
        context.evaluateScript("""
            globalThis.__handlerType = null;
            globalThis.__unwatchCallCount = 0;
            function watch(network, address, types, handler) {
                globalThis.__handlerType = typeof handler;
                handler('balance', globalThis.__update);
                return function unwatch() { globalThis.__unwatchCallCount += 1; };
            }
        """)
        let sut = TONStreamingManager(jsObject: context)

        var received: TONStreamingUpdate?
        let cancellable = sut.updates(
            network: network,
            address: "addr",
            types: [.balance]
        ).sink(
            receiveCompletion: { _ in },
            receiveValue: { received = $0 }
        )

        #expect(context.evaluateScript("globalThis.__handlerType")?.toString() == "function")
        if case .balance(let balance) = received {
            #expect(balance.balance == "3.0")
        } else {
            #expect(Bool(false), "expected .balance update")
        }

        cancellable.cancel()
        #expect(context.evaluateScript("globalThis.__unwatchCallCount")?.toInt32() == 1)
    }

    @Test("connectionChange: handler and unwatch are callable from JS")
    func connectionChangeHandlerCallableFromJS() {
        let context = JSContext()!
        context.evaluateScript("""
            globalThis.__handlerType = null;
            globalThis.__unwatchCallCount = 0;
            function onConnectionChange(network, handler) {
                globalThis.__handlerType = typeof handler;
                handler(true);
                return function unwatch() { globalThis.__unwatchCallCount += 1; };
            }
        """)
        let sut = TONStreamingManager(jsObject: context)

        var received: Bool?
        let cancellable = sut.connectionChange(network: network).sink(
            receiveCompletion: { _ in },
            receiveValue: { received = $0 }
        )

        #expect(context.evaluateScript("globalThis.__handlerType")?.toString() == "function")
        #expect(received == true)

        cancellable.cancel()
        #expect(context.evaluateScript("globalThis.__unwatchCallCount")?.toInt32() == 1)
    }
}
