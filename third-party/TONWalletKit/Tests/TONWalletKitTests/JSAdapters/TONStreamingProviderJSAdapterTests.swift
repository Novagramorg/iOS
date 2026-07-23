import Testing
import JavaScriptCore
import Combine
@testable import TONWalletKit

@Suite("TONStreamingProviderJSAdapter Tests")
struct TONStreamingProviderJSAdapterTests {

    private let context = JSContext()!

    private func makeSUT() -> (
        sut: TONStreamingProviderJSAdapter<MockStreamingProvider>,
        provider: MockStreamingProvider
    ) {
        let provider = MockStreamingProvider()
        let sut = TONStreamingProviderJSAdapter(context: context, streamingProvider: provider)
        return (sut, provider)
    }

    @Test("balance decodes address and subscribes to provider")
    func balanceDecodesAddress() {
        let (sut, provider) = makeSUT()
        let address = JSValue(object: "test-address", in: context)!
        let handler = JSValue(object: { } as @convention(block) () -> Void, in: context)!

        let _ = sut.balance(address: address, handler: handler)

        #expect(provider.balanceCalledWith == "test-address")
    }

    @Test("transactions decodes address and subscribes to provider")
    func transactionsDecodesAddress() {
        let (sut, provider) = makeSUT()
        let address = JSValue(object: "test-address", in: context)!
        let handler = JSValue(object: { } as @convention(block) () -> Void, in: context)!

        let _ = sut.transactions(address: address, handler: handler)

        #expect(provider.transactionsCalledWith == "test-address")
    }

    @Test("jettons decodes address and subscribes to provider")
    func jettonsDecodesAddress() {
        let (sut, provider) = makeSUT()
        let address = JSValue(object: "test-address", in: context)!
        let handler = JSValue(object: { } as @convention(block) () -> Void, in: context)!

        let _ = sut.jettons(address: address, handler: handler)

        #expect(provider.jettonsCalledWith == "test-address")
    }

    @Test("balance calls handler with encoded update")
    func balanceCallsHandler() {
        let (sut, provider) = makeSUT()
        let address = JSValue(object: "test-address", in: context)!
        var receivedValue: JSValue?
        let handler: @convention(block) (JSValue) -> Void = { value in
            receivedValue = value
        }
        let jsHandler = JSValue(object: handler, in: context)!

        let _ = sut.balance(address: address, handler: jsHandler)
        provider.balanceSubject.send(MockStreamingData.balanceUpdate(balance: "5.0"))

        let decoded: TONBalanceUpdate? = try? receivedValue?.decode()
        #expect(decoded?.balance == "5.0")
        #expect(decoded?.status == .confirmed)
    }

    @Test("transactions calls handler with encoded update")
    func transactionsCallsHandler() {
        let (sut, provider) = makeSUT()
        let address = JSValue(object: "test-address", in: context)!
        var receivedValue: JSValue?
        let handler: @convention(block) (JSValue) -> Void = { value in
            receivedValue = value
        }
        let jsHandler = JSValue(object: handler, in: context)!

        let _ = sut.transactions(address: address, handler: jsHandler)
        provider.transactionsSubject.send(MockStreamingData.transactionsUpdate(status: .finalized))

        let decoded: TONTransactionsUpdate? = try? receivedValue?.decode()
        #expect(decoded?.status == .finalized)
        #expect(decoded?.transactions.count == 1)
    }

    @Test("jettons calls handler with encoded update")
    func jettonsCallsHandler() {
        let (sut, provider) = makeSUT()
        let address = JSValue(object: "test-address", in: context)!
        var receivedValue: JSValue?
        let handler: @convention(block) (JSValue) -> Void = { value in
            receivedValue = value
        }
        let jsHandler = JSValue(object: handler, in: context)!

        let _ = sut.jettons(address: address, handler: jsHandler)
        provider.jettonsSubject.send(MockStreamingData.jettonUpdate(balance: "42.0"))

        let decoded: TONJettonUpdate? = try? receivedValue?.decode()
        #expect(decoded?.balance == "42.0")
        #expect(decoded?.status == .confirmed)
    }

    @Test("balance returns unwatch that stops delivery")
    func balanceUnwatchStopsDelivery() {
        let (sut, provider) = makeSUT()
        let address = JSValue(object: "test-address", in: context)!
        var callCount = 0
        let handler: @convention(block) (JSValue) -> Void = { _ in
            callCount += 1
        }
        let jsHandler = JSValue(object: handler, in: context)!

        let unwatch = sut.balance(address: address, handler: jsHandler)
        provider.balanceSubject.send(MockStreamingData.balanceUpdate())
        #expect(callCount == 1)

        unwatch.call(withArguments: [])
        provider.balanceSubject.send(MockStreamingData.balanceUpdate())
        #expect(callCount == 1)
    }

    @Test("transactions returns unwatch that stops delivery")
    func transactionsUnwatchStopsDelivery() {
        let (sut, provider) = makeSUT()
        let address = JSValue(object: "test-address", in: context)!
        var callCount = 0
        let handler: @convention(block) (JSValue) -> Void = { _ in
            callCount += 1
        }
        let jsHandler = JSValue(object: handler, in: context)!

        let unwatch = sut.transactions(address: address, handler: jsHandler)
        provider.transactionsSubject.send(MockStreamingData.transactionsUpdate())
        #expect(callCount == 1)

        unwatch.call(withArguments: [])
        provider.transactionsSubject.send(MockStreamingData.transactionsUpdate())
        #expect(callCount == 1)
    }

    @Test("jettons returns unwatch that stops delivery")
    func jettonsUnwatchStopsDelivery() {
        let (sut, provider) = makeSUT()
        let address = JSValue(object: "test-address", in: context)!
        var callCount = 0
        let handler: @convention(block) (JSValue) -> Void = { _ in
            callCount += 1
        }
        let jsHandler = JSValue(object: handler, in: context)!

        let unwatch = sut.jettons(address: address, handler: jsHandler)
        provider.jettonsSubject.send(MockStreamingData.jettonUpdate())
        #expect(callCount == 1)

        unwatch.call(withArguments: [])
        provider.jettonsSubject.send(MockStreamingData.jettonUpdate())
        #expect(callCount == 1)
    }

    @Test("balance returns undefined when address is invalid")
    func balanceReturnsUndefinedForInvalidAddress() {
        let (sut, _) = makeSUT()
        let address = JSValue(undefinedIn: context)!
        let handler = JSValue(object: { } as @convention(block) () -> Void, in: context)!

        let result = sut.balance(address: address, handler: handler)

        #expect(result.isUndefined)
    }

    @Test("transactions returns undefined when address is invalid")
    func transactionsReturnsUndefinedForInvalidAddress() {
        let (sut, _) = makeSUT()
        let address = JSValue(undefinedIn: context)!
        let handler = JSValue(object: { } as @convention(block) () -> Void, in: context)!

        let result = sut.transactions(address: address, handler: handler)

        #expect(result.isUndefined)
    }

    @Test("jettons returns undefined when address is invalid")
    func jettonsReturnsUndefinedForInvalidAddress() {
        let (sut, _) = makeSUT()
        let address = JSValue(undefinedIn: context)!
        let handler = JSValue(object: { } as @convention(block) () -> Void, in: context)!

        let result = sut.jettons(address: address, handler: handler)

        #expect(result.isUndefined)
    }

    @Test("balance returns undefined when context is deallocated")
    func balanceReturnsUndefinedWhenDeallocated() {
        var jsContext: JSContext? = JSContext()!
        let provider = MockStreamingProvider()
        let sut = TONStreamingProviderJSAdapter(context: jsContext!, streamingProvider: provider)
        jsContext = nil

        let address = JSValue(object: "test-address", in: context)!
        let handler = JSValue(object: { } as @convention(block) () -> Void, in: context)!

        let result = sut.balance(address: address, handler: handler)

        #expect(result.isUndefined)
    }

    @Test("balance round-trip: JS function receives adapter and gets updates")
    func balanceRoundTrip() throws {
        let (sut, provider) = makeSUT()

        context.evaluateScript("""
            var balanceResult = null;
            function startWatchingBalance(provider) {
                return provider.watchBalance("test-address", function(update) {
                    balanceResult = update;
                });
            }
        """)

        try context.startWatchingBalance(sut)
        provider.balanceSubject.send(MockStreamingData.balanceUpdate(status: .confirmed, balance: "7.77"))

        let result: TONBalanceUpdate? = context.balanceResult
        #expect(result?.status == .confirmed)
        #expect(result?.balance == "7.77")
        #expect(provider.balanceCalledWith == "test-address")
    }

    @Test("transactions round-trip: JS function receives adapter and gets updates")
    func transactionsRoundTrip() throws {
        let (sut, provider) = makeSUT()

        context.evaluateScript("""
            var txResult = null;
            function startWatchingTx(provider) {
                return provider.watchTransactions("test-address", function(update) {
                    txResult = update;
                });
            }
        """)

        try context.startWatchingTx(sut)
        provider.transactionsSubject.send(MockStreamingData.transactionsUpdate(status: .finalized))

        let result: TONTransactionsUpdate? = context.txResult
        #expect(result?.status == .finalized)
        #expect(result?.transactions.count == 1)
    }

    @Test("jettons round-trip: JS function receives adapter and gets updates")
    func jettonsRoundTrip() throws {
        let (sut, provider) = makeSUT()

        context.evaluateScript("""
            var jettonResult = null;
            function startWatchingJettons(provider) {
                return provider.watchJettons("test-address", function(update) {
                    jettonResult = update;
                });
            }
        """)

        try context.startWatchingJettons(sut)
        provider.jettonsSubject.send(MockStreamingData.jettonUpdate(status: .pending, balance: "123.4"))

        let result: TONJettonUpdate? = context.jettonResult
        #expect(result?.status == .pending)
        #expect(result?.balance == "123.4")
    }

    @Test("round-trip: JS unwatch stops delivery")
    func roundTripUnwatch() throws {
        let (sut, provider) = makeSUT()

        context.evaluateScript("""
            var rtCallCount = 0;
            function startAndWatch(provider) {
                return provider.watchBalance("test-address", function(update) {
                    rtCallCount++;
                });
            }
        """)

        let unwatch: JSValue = try context.startAndWatch(sut)

        provider.balanceSubject.send(MockStreamingData.balanceUpdate())
        let count1: Int? = context.rtCallCount
        #expect(count1 == 1)

        unwatch.call(withArguments: [])

        provider.balanceSubject.send(MockStreamingData.balanceUpdate())
        let count2: Int? = context.rtCallCount
        #expect(count2 == 1)
    }

    @Test("type returns streaming")
    func typeReturnsStreaming() {
        let (sut, _) = makeSUT()

        #expect(sut.type == "streaming")
    }

    @Test("providerId returns provider identifier name")
    func providerIdReturnsName() {
        let (sut, provider) = makeSUT()

        #expect(sut.providerId == provider.identifier.name)
    }

    @Test("network returns encoded network from provider")
    func networkReturnsEncodedValue() {
        let (sut, _) = makeSUT()

        let network = sut.network

        #expect(!network.isUndefined)
    }

    @Test("connect calls connect on provider")
    func connectCallsProvider() {
        let (sut, provider) = makeSUT()

        sut.connect()

        #expect(provider.connectCalled == true)
    }

    @Test("disconnect calls disconnect on provider")
    func disconnectCallsProvider() {
        let (sut, provider) = makeSUT()

        sut.disconnect()

        #expect(provider.disconnectCalled == true)
    }

    @Test("connectionChange calls handler with connection status")
    func connectionChangeCallsHandler() {
        let (sut, provider) = makeSUT()
        var receivedValue: JSValue?
        let handler: @convention(block) (JSValue) -> Void = { value in
            receivedValue = value
        }
        let jsHandler = JSValue(object: handler, in: context)!

        let _ = sut.connectionChange(handler: jsHandler)
        provider.connectionChangeSubject.send(true)

        #expect(receivedValue?.toBool() == true)
    }

    @Test("connectionChange returns unwatch that stops delivery")
    func connectionChangeUnwatchStopsDelivery() {
        let (sut, provider) = makeSUT()
        var callCount = 0
        let handler: @convention(block) (JSValue) -> Void = { _ in
            callCount += 1
        }
        let jsHandler = JSValue(object: handler, in: context)!

        let unwatch = sut.connectionChange(handler: jsHandler)
        provider.connectionChangeSubject.send(true)
        #expect(callCount == 1)

        unwatch.call(withArguments: [])
        provider.connectionChangeSubject.send(false)
        #expect(callCount == 1)
    }

    @Test("connectionChange round-trip: JS function receives adapter and gets updates")
    func connectionChangeRoundTrip() throws {
        let (sut, provider) = makeSUT()

        context.evaluateScript("""
            var connResult = null;
            function startWatchingConnection(provider) {
                return provider.onConnectionChange(function(status) {
                    connResult = status;
                });
            }
        """)

        try context.startWatchingConnection(sut)
        provider.connectionChangeSubject.send(true)

        let result: Bool? = context.connResult
        #expect(result == true)
    }

    // MARK: - JS-bridge tests for the unwatch JSValue
    //
    // The adapter's watch* methods return a JSValue produced from a Swift block via
    // `JSValue(object: unwatch, in: context)`. These tests assert that, from JS's
    // perspective, that returned value is `typeof === 'function'` and that invoking
    // it from JS reaches the Swift block and cancels the subscription.

    @Test("balance unwatch is callable from JS")
    func balanceUnwatchCallableFromJS() {
        let (sut, provider) = makeSUT()
        let address = JSValue(object: "test-address", in: context)!
        var callCount = 0
        let handler: @convention(block) (JSValue) -> Void = { _ in callCount += 1 }
        let jsHandler = JSValue(object: handler, in: context)!

        let unwatch = sut.balance(address: address, handler: jsHandler)
        context.setObject(unwatch, forKeyedSubscript: "__unwatch" as NSString)
        let typeofResult = context.evaluateScript("typeof __unwatch")?.toString()

        provider.balanceSubject.send(MockStreamingData.balanceUpdate())
        #expect(callCount == 1)

        context.evaluateScript("__unwatch()")
        provider.balanceSubject.send(MockStreamingData.balanceUpdate())

        #expect(typeofResult == "function", "JS must see unwatch as a callable function, got: \(typeofResult ?? "nil")")
        #expect(callCount == 1)
    }

    @Test("transactions unwatch is callable from JS")
    func transactionsUnwatchCallableFromJS() {
        let (sut, provider) = makeSUT()
        let address = JSValue(object: "test-address", in: context)!
        var callCount = 0
        let handler: @convention(block) (JSValue) -> Void = { _ in callCount += 1 }
        let jsHandler = JSValue(object: handler, in: context)!

        let unwatch = sut.transactions(address: address, handler: jsHandler)
        context.setObject(unwatch, forKeyedSubscript: "__unwatch" as NSString)
        let typeofResult = context.evaluateScript("typeof __unwatch")?.toString()

        provider.transactionsSubject.send(MockStreamingData.transactionsUpdate())
        #expect(callCount == 1)

        context.evaluateScript("__unwatch()")
        provider.transactionsSubject.send(MockStreamingData.transactionsUpdate())

        #expect(typeofResult == "function")
        #expect(callCount == 1)
    }

    @Test("jettons unwatch is callable from JS")
    func jettonsUnwatchCallableFromJS() {
        let (sut, provider) = makeSUT()
        let address = JSValue(object: "test-address", in: context)!
        var callCount = 0
        let handler: @convention(block) (JSValue) -> Void = { _ in callCount += 1 }
        let jsHandler = JSValue(object: handler, in: context)!

        let unwatch = sut.jettons(address: address, handler: jsHandler)
        context.setObject(unwatch, forKeyedSubscript: "__unwatch" as NSString)
        let typeofResult = context.evaluateScript("typeof __unwatch")?.toString()

        provider.jettonsSubject.send(MockStreamingData.jettonUpdate())
        #expect(callCount == 1)

        context.evaluateScript("__unwatch()")
        provider.jettonsSubject.send(MockStreamingData.jettonUpdate())

        #expect(typeofResult == "function")
        #expect(callCount == 1)
    }

    @Test("connectionChange unwatch is callable from JS")
    func connectionChangeUnwatchCallableFromJS() {
        let (sut, provider) = makeSUT()
        var callCount = 0
        let handler: @convention(block) (JSValue) -> Void = { _ in callCount += 1 }
        let jsHandler = JSValue(object: handler, in: context)!

        let unwatch = sut.connectionChange(handler: jsHandler)
        context.setObject(unwatch, forKeyedSubscript: "__unwatch" as NSString)
        let typeofResult = context.evaluateScript("typeof __unwatch")?.toString()

        provider.connectionChangeSubject.send(true)
        #expect(callCount == 1)

        context.evaluateScript("__unwatch()")
        provider.connectionChangeSubject.send(false)

        #expect(typeofResult == "function")
        #expect(callCount == 1)
    }
}
