import Testing
import JavaScriptCore
@testable import TONWalletKit

@Suite("TONSwapProviderJSAdapter Tests")
struct TONSwapProviderJSAdapterTests {

    private let context = JSContext()!

    private func makeSUT(
        identifierName: String = "omniston"
    ) -> TONSwapProviderJSAdapter<MockSwapProvider> {
        let provider = MockSwapProvider(
            identifier: TONOmnistonSwapProviderIdentifier(name: identifierName)
        )
        return TONSwapProviderJSAdapter(context: context, swapProvider: provider)
    }

    @Test("type returns swap")
    func typeReturnsSwap() {
        let sut = makeSUT()

        #expect(sut.type == "swap")
    }

    @Test("providerId returns identifier name")
    func providerIdReturnsIdentifierName() {
        let sut = makeSUT(identifierName: "test-provider")

        #expect(sut.providerId == "test-provider")
    }

    @Test("metadata returns the encoded provider metadata")
    func metadataReturnsEncodedValue() throws {
        var provider = MockSwapProvider(
            identifier: TONOmnistonSwapProviderIdentifier(name: "omniston")
        )
        provider.mockMetadata = TONSwapProviderMetadata(name: "Mock", logo: "logo.png", url: "https://example.com")
        let sut = TONSwapProviderJSAdapter(context: context, swapProvider: provider)

        let result = sut.metadata()

        #expect(result.forProperty("name")?.toString() == "Mock")
        #expect(result.forProperty("logo")?.toString() == "logo.png")
        #expect(result.forProperty("url")?.toString() == "https://example.com")
    }

    @Test("metadata returns undefined when provider throws")
    func metadataReturnsUndefinedOnError() {
        var provider = MockSwapProvider(
            identifier: TONOmnistonSwapProviderIdentifier(name: "omniston")
        )
        provider.shouldThrow = true
        let sut = TONSwapProviderJSAdapter(context: context, swapProvider: provider)

        let result = sut.metadata()

        #expect(result.isUndefined)
    }

    @Test("supportedNetworks returns the encoded networks")
    func supportedNetworksReturnsEncodedValue() throws {
        var provider = MockSwapProvider(
            identifier: TONOmnistonSwapProviderIdentifier(name: "omniston")
        )
        provider.mockSupportedNetworks = [.mainnet, .testnet]
        let sut = TONSwapProviderJSAdapter(context: context, swapProvider: provider)

        let result = sut.supportedNetworks()

        #expect(result.isArray)
        let networks: [TONNetwork] = try result.decode()
        #expect(networks == [.mainnet, .testnet])
    }

    @Test("supportedNetworks returns undefined when provider throws")
    func supportedNetworksReturnsUndefinedOnError() {
        var provider = MockSwapProvider(
            identifier: TONOmnistonSwapProviderIdentifier(name: "omniston")
        )
        provider.shouldThrow = true
        let sut = TONSwapProviderJSAdapter(context: context, swapProvider: provider)

        let result = sut.supportedNetworks()

        #expect(result.isUndefined)
    }

    @Test("quote rejects when context is deallocated")
    func quoteRejectsWhenDeallocated() async {
        var jsContext: JSContext? = JSContext()!
        let provider = MockSwapProvider(
            identifier: TONOmnistonSwapProviderIdentifier(name: "omniston")
        )
        let sut = TONSwapProviderJSAdapter(context: jsContext!, swapProvider: provider)
        jsContext = nil

        let result = sut.quote(params: JSValue(undefinedIn: context)!)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("swapTransaction rejects when context is deallocated")
    func swapTransactionRejectsWhenDeallocated() async {
        var jsContext: JSContext? = JSContext()!
        let provider = MockSwapProvider(
            identifier: TONOmnistonSwapProviderIdentifier(name: "omniston")
        )
        let sut = TONSwapProviderJSAdapter(context: jsContext!, swapProvider: provider)
        jsContext = nil

        let result = sut.swapTransaction(params: JSValue(undefinedIn: context)!)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("type is accessible from JS")
    func typeAccessibleFromJS() {
        let sut = makeSUT()
        context.setObject(sut, forKeyedSubscript: "adapter" as NSString)

        let result = context.evaluateScript("adapter.type")

        #expect(result?.toString() == "swap")
    }

    @Test("providerId is accessible from JS")
    func providerIdAccessibleFromJS() {
        let sut = makeSUT(identifierName: "test-provider")
        context.setObject(sut, forKeyedSubscript: "adapter" as NSString)

        let result = context.evaluateScript("adapter.providerId")

        #expect(result?.toString() == "test-provider")
    }

    @Test("quote resolves from JS call")
    func quoteResolvesFromJS() async throws {
        let sut = makeSUT()
        context.setObject(sut, forKeyedSubscript: "adapter" as NSString)

        let promise = context.evaluateScript("""
        adapter.getQuote({
            amount: "1000000000",
            from: { address: "ton", decimals: 9 },
            to: { address: "ton", decimals: 9 },
            network: { chainId: "-239" }
        })
        """)!

        let result = try await promise.then()
        #expect(result.forProperty("providerId")?.toString() == "omniston")
    }

    @Test("adapter works as JS function argument")
    func adapterWorksAsJSFunctionArgument() throws {
        let sut = makeSUT(identifierName: "test-provider")
        context.evaluateScript("function getProviderType(provider) { return provider.type; }")

        let result: String? = try context.getProviderType(sut)

        #expect(result == "swap")
    }

    @Test("getMetadata is callable from JS and returns the encoded object")
    func metadataCallableFromJS() throws {
        var provider = MockSwapProvider(
            identifier: TONOmnistonSwapProviderIdentifier(name: "omniston")
        )
        provider.mockMetadata = TONSwapProviderMetadata(name: "Mock", logo: "logo.png", url: "https://example.com")
        let sut = TONSwapProviderJSAdapter(context: context, swapProvider: provider)
        context.setObject(sut, forKeyedSubscript: "adapter" as NSString)

        let result = context.evaluateScript("adapter.getMetadata()")

        #expect(result?.forProperty("name")?.toString() == "Mock")
        #expect(result?.forProperty("logo")?.toString() == "logo.png")
        #expect(result?.forProperty("url")?.toString() == "https://example.com")
    }

    @Test("getSupportedNetworks is callable from JS and returns the encoded networks")
    func supportedNetworksCallableFromJS() throws {
        var provider = MockSwapProvider(
            identifier: TONOmnistonSwapProviderIdentifier(name: "omniston")
        )
        provider.mockSupportedNetworks = [.mainnet, .testnet]
        let sut = TONSwapProviderJSAdapter(context: context, swapProvider: provider)
        context.setObject(sut, forKeyedSubscript: "adapter" as NSString)

        let result = context.evaluateScript("adapter.getSupportedNetworks()")

        #expect(result?.isArray == true)
        let networks: [TONNetwork] = try #require(try result?.decode())
        #expect(networks == [.mainnet, .testnet])
    }

    @Test("getSupportedNetworks from JS returns a plain array, not a Promise")
    func supportedNetworksFromJSIsSynchronous() {
        let sut = makeSUT()
        context.setObject(sut, forKeyedSubscript: "adapter" as NSString)

        let isPromise = context.evaluateScript("adapter.getSupportedNetworks() instanceof Promise")

        #expect(isPromise?.toBool() == false)
    }

    @Test("swapTransaction resolves from JS call")
    func swapTransactionResolvesFromJS() async throws {
        let sut = makeSUT()
        context.setObject(sut, forKeyedSubscript: "adapter" as NSString)

        let promise = context.evaluateScript("""
        adapter.buildSwapTransaction({
            quote: {
                fromToken: { address: "ton", decimals: 9 },
                toToken: { address: "ton", decimals: 9 },
                rawFromAmount: "1000000000",
                rawToAmount: "1000000",
                fromAmount: "1",
                toAmount: "1",
                rawMinReceived: "990000",
                minReceived: "0.99",
                network: { chainId: "-239" },
                providerId: "omniston"
            },
            userAddress: "EQCrq6urq6urq6urq6urq6urq6urq6urq6urq6urq6urq8Uk"
        })
        """)!

        let result = try await promise.then()
        #expect(result.forProperty("messages")?.isArray == true)
    }
}
