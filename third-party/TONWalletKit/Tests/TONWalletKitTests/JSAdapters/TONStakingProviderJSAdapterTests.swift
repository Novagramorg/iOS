import Testing
import JavaScriptCore
@testable import TONWalletKit

@Suite("TONStakingProviderJSAdapter Tests")
struct TONStakingProviderJSAdapterTests {

    private let context = JSContext()!

    private func makeSUT(
        identifierName: String = "tonstakers"
    ) -> TONStakingProviderJSAdapter<MockStakingProvider> {
        let provider = MockStakingProvider(
            identifier: TONTonStakersStakingProviderIdentifier(name: identifierName)
        )
        return TONStakingProviderJSAdapter(context: context, stakingProvider: provider)
    }

    @Test("type returns staking")
    func typeReturnsStaking() {
        let sut = makeSUT()

        #expect(sut.type == "staking")
    }

    @Test("providerId returns identifier name")
    func providerIdReturnsIdentifierName() {
        let sut = makeSUT(identifierName: "test-provider")

        #expect(sut.providerId == "test-provider")
    }

    @Test("quote rejects when context is deallocated")
    func quoteRejectsWhenDeallocated() async {
        var jsContext: JSContext? = JSContext()!
        let provider = MockStakingProvider(
            identifier: TONTonStakersStakingProviderIdentifier(name: "tonstakers")
        )
        let sut = TONStakingProviderJSAdapter(context: jsContext!, stakingProvider: provider)
        jsContext = nil

        let result = sut.quote(params: JSValue(undefinedIn: context)!)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("stakeTransaction rejects when context is deallocated")
    func stakeTransactionRejectsWhenDeallocated() async {
        var jsContext: JSContext? = JSContext()!
        let provider = MockStakingProvider(
            identifier: TONTonStakersStakingProviderIdentifier(name: "tonstakers")
        )
        let sut = TONStakingProviderJSAdapter(context: jsContext!, stakingProvider: provider)
        jsContext = nil

        let result = sut.stakeTransaction(params: JSValue(undefinedIn: context)!)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("stakedBalance rejects when context is deallocated")
    func stakedBalanceRejectsWhenDeallocated() async {
        var jsContext: JSContext? = JSContext()!
        let provider = MockStakingProvider(
            identifier: TONTonStakersStakingProviderIdentifier(name: "tonstakers")
        )
        let sut = TONStakingProviderJSAdapter(context: jsContext!, stakingProvider: provider)
        jsContext = nil

        let result = sut.stakedBalance(
            userAddress: JSValue(undefinedIn: context)!,
            network: JSValue(undefinedIn: context)!
        )

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("info rejects when context is deallocated")
    func infoRejectsWhenDeallocated() async {
        var jsContext: JSContext? = JSContext()!
        let provider = MockStakingProvider(
            identifier: TONTonStakersStakingProviderIdentifier(name: "tonstakers")
        )
        let sut = TONStakingProviderJSAdapter(context: jsContext!, stakingProvider: provider)
        jsContext = nil

        let result = sut.info(network: JSValue(undefinedIn: context)!)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("metadata returns the encoded provider metadata")
    func metadataReturnsEncodedValue() throws {
        var provider = MockStakingProvider(
            identifier: TONTonStakersStakingProviderIdentifier(name: "tonstakers")
        )
        provider.mockMetadata = TONStakingProviderMetadata(
            name: "Tonstakers",
            supportedUnstakeModes: [.instant, .roundEnd],
            supportsReversedQuote: true,
            stakeToken: TONStakingTokenInfo(ticker: "TON", decimals: 9, address: "ton")
        )
        let sut = TONStakingProviderJSAdapter(context: context, stakingProvider: provider)

        let result = sut.metadata(network: JSValue(undefinedIn: context)!)

        #expect(result.forProperty("name")?.toString() == "Tonstakers")
        #expect(result.forProperty("supportsReversedQuote")?.toBool() == true)
    }

    @Test("metadata returns undefined when provider throws")
    func metadataReturnsUndefinedOnError() {
        var provider = MockStakingProvider(
            identifier: TONTonStakersStakingProviderIdentifier(name: "tonstakers")
        )
        provider.shouldThrow = true
        let sut = TONStakingProviderJSAdapter(context: context, stakingProvider: provider)

        let result = sut.metadata(network: JSValue(undefinedIn: context)!)

        #expect(result.isUndefined)
    }

    @Test("supportedNetworks returns the encoded networks")
    func supportedNetworksReturnsEncodedValue() throws {
        var provider = MockStakingProvider(
            identifier: TONTonStakersStakingProviderIdentifier(name: "tonstakers")
        )
        provider.mockSupportedNetworks = [.mainnet, .testnet]
        let sut = TONStakingProviderJSAdapter(context: context, stakingProvider: provider)

        let result = sut.supportedNetworks()

        #expect(result.isArray)
        let networks: [TONNetwork] = try #require(try result.decode())
        #expect(networks == [.mainnet, .testnet])
    }

    @Test("supportedNetworks returns undefined when provider throws")
    func supportedNetworksReturnsUndefinedOnError() {
        var provider = MockStakingProvider(
            identifier: TONTonStakersStakingProviderIdentifier(name: "tonstakers")
        )
        provider.shouldThrow = true
        let sut = TONStakingProviderJSAdapter(context: context, stakingProvider: provider)

        let result = sut.supportedNetworks()

        #expect(result.isUndefined)
    }

    @Test("type is accessible from JS")
    func typeAccessibleFromJS() {
        let sut = makeSUT()
        context.evaluateScript("function getType(p) { return p.type; }")

        let result: String? = try? context.getType(sut)

        #expect(result == "staking")
    }

    @Test("providerId is accessible from JS")
    func providerIdAccessibleFromJS() {
        let sut = makeSUT(identifierName: "test-provider")
        context.evaluateScript("function getProviderId(p) { return p.providerId; }")

        let result: String? = try? context.getProviderId(sut)

        #expect(result == "test-provider")
    }

    @Test("quote resolves from JS call")
    func quoteResolvesFromJS() async throws {
        let sut = makeSUT()

        context.evaluateScript("""
        function callGetQuote(adapter) {
            return adapter.getQuote({
                direction: "stake",
                amount: "1000000000"
            });
        }
        """)

        let result: JSValue = try await context.callGetQuote(sut)
        let providerId: String? = result.providerId
        #expect(providerId == "tonstakers")
    }

    @Test("stakeTransaction resolves from JS call")
    func stakeTransactionResolvesFromJS() async throws {
        let sut = makeSUT()

        context.evaluateScript("""
        function callBuildStakeTransaction(adapter) {
            return adapter.buildStakeTransaction({
                quote: {
                    direction: "stake",
                    rawAmountIn: "1000000000",
                    rawAmountOut: "950000000",
                    amountIn: "1",
                    amountOut: "0.95",
                    network: { chainId: "-239" },
                    providerId: "tonstakers"
                },
                userAddress: "EQCrq6urq6urq6urq6urq6urq6urq6urq6urq6urq6urq8Uk"
            });
        }
        """)

        let result: JSValue = try await context.callBuildStakeTransaction(sut)
        let messages: JSValue? = result.messages
        #expect(messages?.isArray == true)
    }

    @Test("stakedBalance resolves from JS call")
    func stakedBalanceResolvesFromJS() async throws {
        let sut = makeSUT()

        context.evaluateScript("""
        function callGetStakedBalance(adapter) {
            return adapter.getStakedBalance(
                "EQCrq6urq6urq6urq6urq6urq6urq6urq6urq6urq6urq8Uk",
                { chainId: "-239" }
            );
        }
        """)

        let result: JSValue = try await context.callGetStakedBalance(sut)
        let providerId: String? = result.providerId
        #expect(providerId == "tonstakers")
    }

    @Test("info resolves from JS call")
    func infoResolvesFromJS() async throws {
        let sut = makeSUT()

        context.evaluateScript("""
        function callGetStakingProviderInfo(adapter) {
            return adapter.getStakingProviderInfo({ chainId: "-239" });
        }
        """)

        let result: JSValue = try await context.callGetStakingProviderInfo(sut)
        let apy: Int? = result.apy
        #expect(apy == 500)
    }

    @Test("getMetadata is callable from JS and returns encoded object")
    func metadataCallableFromJS() throws {
        var provider = MockStakingProvider(
            identifier: TONTonStakersStakingProviderIdentifier(name: "tonstakers")
        )
        provider.mockMetadata = TONStakingProviderMetadata(
            name: "Tonstakers",
            supportedUnstakeModes: [.instant, .whenAvailable, .roundEnd],
            supportsReversedQuote: true,
            stakeToken: TONStakingTokenInfo(ticker: "TON", decimals: 9, address: "ton")
        )
        let sut = TONStakingProviderJSAdapter(context: context, stakingProvider: provider)
        context.setObject(sut, forKeyedSubscript: "adapter" as NSString)

        let result = context.evaluateScript("adapter.getStakingProviderMetadata()")

        #expect(result?.forProperty("name")?.toString() == "Tonstakers")
        #expect(result?.forProperty("supportedUnstakeModes")?.isArray == true)
    }

    @Test("getSupportedNetworks is callable from JS and returns encoded networks")
    func supportedNetworksCallableFromJS() throws {
        var provider = MockStakingProvider(
            identifier: TONTonStakersStakingProviderIdentifier(name: "tonstakers")
        )
        provider.mockSupportedNetworks = [.mainnet]
        let sut = TONStakingProviderJSAdapter(context: context, stakingProvider: provider)
        context.setObject(sut, forKeyedSubscript: "adapter" as NSString)

        let result = context.evaluateScript("adapter.getSupportedNetworks()")

        #expect(result?.isArray == true)
        let networks: [TONNetwork] = try #require(try result?.decode())
        #expect(networks == [.mainnet])
    }

    @Test("getSupportedNetworks from JS returns a plain array, not a Promise")
    func supportedNetworksFromJSIsSynchronous() {
        let sut = makeSUT()
        context.setObject(sut, forKeyedSubscript: "adapter" as NSString)

        let isPromise = context.evaluateScript("adapter.getSupportedNetworks() instanceof Promise")

        #expect(isPromise?.toBool() == false)
    }

    @Test("adapter works as JS function argument")
    func adapterWorksAsJSFunctionArgument() throws {
        let sut = makeSUT(identifierName: "test-provider")
        context.evaluateScript("function getProviderType(provider) { return provider.type; }")

        let result: String? = try context.getProviderType(sut)

        #expect(result == "staking")
    }
}
