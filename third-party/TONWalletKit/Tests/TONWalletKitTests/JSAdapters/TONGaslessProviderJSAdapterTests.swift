import Testing
import JavaScriptCore
@testable import TONWalletKit
import _BigInt

@Suite("TONGaslessProviderJSAdapter Tests")
struct TONGaslessProviderJSAdapterTests {

    private let context = JSContext()!

    private func makeSUT(identifierName: String = "tonapi") -> TONGaslessProviderJSAdapter<MockGaslessProvider> {
        let provider = MockGaslessProvider(identifier: TONTonApiGaslessProviderIdentifier(name: identifierName))
        return TONGaslessProviderJSAdapter(context: context, gaslessProvider: provider)
    }

    private func makeThrowingSUT() -> TONGaslessProviderJSAdapter<MockGaslessProvider> {
        var provider = MockGaslessProvider(identifier: TONTonApiGaslessProviderIdentifier())
        provider.shouldThrow = true
        return TONGaslessProviderJSAdapter(context: context, gaslessProvider: provider)
    }

    private func makeAddress() -> TONUserFriendlyAddress {
        TONRawAddress(workchain: 0, hash: Data(repeating: 0xab, count: 32)).userFriendly(isBounceable: true)
    }

    private func makeNetworkJS() throws -> JSValue {
        try #require(try TONNetwork.mainnet.encode(in: context) as? JSValue)
    }

    private func makeQuoteParamsJS() throws -> JSValue {
        let params = TONGaslessQuoteParams(
            network: .mainnet,
            feeAsset: makeAddress(),
            walletAddress: makeAddress(),
            walletPublicKey: TONHex(data: Data([0xab, 0xcd])),
            messages: []
        )
        return try #require(try params.encode(in: context) as? JSValue)
    }

    private func makeSendParamsJS() throws -> JSValue {
        let params = TONGaslessSendParams(
            network: .mainnet,
            walletPublicKey: TONHex(data: Data([0xab, 0xcd])),
            internalBoc: TONBase64(string: "boc")
        )
        return try #require(try params.encode(in: context) as? JSValue)
    }

    // MARK: - Properties

    @Test("type returns gasless")
    func typeReturnsGasless() {
        let sut = makeSUT()

        #expect(sut.type == "gasless")
    }

    @Test("providerId returns identifier name")
    func providerIdReturnsIdentifierName() {
        let sut = makeSUT(identifierName: "test-provider")

        #expect(sut.providerId == "test-provider")
    }

    // MARK: - supportedNetworks (synchronous)

    @Test("supportedNetworks returns the encoded networks")
    func supportedNetworksReturnsEncodedValue() throws {
        var provider = MockGaslessProvider(identifier: TONTonApiGaslessProviderIdentifier())
        provider.mockSupportedNetworks = [.mainnet, .testnet]
        let sut = TONGaslessProviderJSAdapter(context: context, gaslessProvider: provider)

        let result = sut.supportedNetworks()

        #expect(result.isArray)
        let networks: [TONNetwork] = try #require(try result.decode())
        #expect(networks == [.mainnet, .testnet])
    }

    @Test("supportedNetworks returns undefined when provider throws")
    func supportedNetworksReturnsUndefinedOnError() {
        let sut = makeThrowingSUT()

        let result = sut.supportedNetworks()

        #expect(result.isUndefined)
    }

    // MARK: - metadata (Promise)

    @Test("metadata resolves with the encoded metadata")
    func metadataResolves() async throws {
        var provider = MockGaslessProvider(identifier: TONTonApiGaslessProviderIdentifier())
        provider.mockMetadata = TONGaslessProviderMetadata(name: "TonAPI", url: "https://tonapi.io")
        let sut = TONGaslessProviderJSAdapter(context: context, gaslessProvider: provider)

        let resolved = try await sut.metadata().then()

        #expect(resolved.forProperty("name")?.toString() == "TonAPI")
    }

    @Test("metadata rejects when provider throws")
    func metadataRejectsOnError() async {
        let sut = makeThrowingSUT()

        let result = sut.metadata()

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("metadata rejects when context is deallocated")
    func metadataRejectsWhenDeallocated() async {
        var jsContext: JSContext? = JSContext()!
        let provider = MockGaslessProvider(identifier: TONTonApiGaslessProviderIdentifier())
        let sut = TONGaslessProviderJSAdapter(context: jsContext!, gaslessProvider: provider)
        jsContext = nil

        let result = sut.metadata()

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    // MARK: - config (Promise)

    @Test("config resolves with the encoded config")
    func configResolves() async throws {
        let sut = makeSUT()
        let networkJS = try makeNetworkJS()

        let resolved = try await sut.config(network: networkJS).then()

        #expect(resolved.forProperty("relayAddress")?.isString == true)
        #expect(resolved.forProperty("supportedAssets")?.isArray == true)
    }

    @Test("config rejects when provider throws")
    func configRejectsOnError() async throws {
        let sut = makeThrowingSUT()
        let networkJS = try makeNetworkJS()

        let result = sut.config(network: networkJS)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("config rejects when context is deallocated")
    func configRejectsWhenDeallocated() async {
        var jsContext: JSContext? = JSContext()!
        let provider = MockGaslessProvider(identifier: TONTonApiGaslessProviderIdentifier())
        let sut = TONGaslessProviderJSAdapter(context: jsContext!, gaslessProvider: provider)
        jsContext = nil

        let result = sut.config(network: JSValue(undefinedIn: context)!)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    // MARK: - quote (Promise)

    @Test("quote resolves with the encoded quote")
    func quoteResolves() async throws {
        let sut = makeSUT()
        let paramsJS = try makeQuoteParamsJS()

        let resolved = try await sut.quote(params: paramsJS).then()

        #expect(resolved.forProperty("fee")?.toString() == "1000000")
    }

    @Test("quote rejects when provider throws")
    func quoteRejectsOnError() async throws {
        let sut = makeThrowingSUT()
        let paramsJS = try makeQuoteParamsJS()

        let result = sut.quote(params: paramsJS)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("quote rejects when context is deallocated")
    func quoteRejectsWhenDeallocated() async {
        var jsContext: JSContext? = JSContext()!
        let provider = MockGaslessProvider(identifier: TONTonApiGaslessProviderIdentifier())
        let sut = TONGaslessProviderJSAdapter(context: jsContext!, gaslessProvider: provider)
        jsContext = nil

        let result = sut.quote(params: JSValue(undefinedIn: context)!)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    // MARK: - sendTransaction (Promise)

    @Test("sendTransaction resolves with the encoded response")
    func sendTransactionResolves() async throws {
        let sut = makeSUT()
        let paramsJS = try makeSendParamsJS()

        let resolved = try await sut.sendTransaction(params: paramsJS).then()

        #expect(resolved.forProperty("normalizedHash")?.toString() == "0xabcd")
    }

    @Test("sendTransaction rejects when provider throws")
    func sendTransactionRejectsOnError() async throws {
        let sut = makeThrowingSUT()
        let paramsJS = try makeSendParamsJS()

        let result = sut.sendTransaction(params: paramsJS)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("sendTransaction rejects when context is deallocated")
    func sendTransactionRejectsWhenDeallocated() async {
        var jsContext: JSContext? = JSContext()!
        let provider = MockGaslessProvider(identifier: TONTonApiGaslessProviderIdentifier())
        let sut = TONGaslessProviderJSAdapter(context: jsContext!, gaslessProvider: provider)
        jsContext = nil

        let result = sut.sendTransaction(params: JSValue(undefinedIn: context)!)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    // MARK: - JS interop

    @Test("type is accessible from JS")
    func typeAccessibleFromJS() {
        let sut = makeSUT()
        context.setObject(sut, forKeyedSubscript: "adapter" as NSString)

        let result = context.evaluateScript("adapter.type")

        #expect(result?.toString() == "gasless")
    }

    @Test("providerId is accessible from JS")
    func providerIdAccessibleFromJS() {
        let sut = makeSUT(identifierName: "test-provider")
        context.setObject(sut, forKeyedSubscript: "adapter" as NSString)

        let result = context.evaluateScript("adapter.providerId")

        #expect(result?.toString() == "test-provider")
    }

    @Test("getSupportedNetworks is callable from JS and returns a plain array")
    func supportedNetworksCallableFromJS() throws {
        var provider = MockGaslessProvider(identifier: TONTonApiGaslessProviderIdentifier())
        provider.mockSupportedNetworks = [.mainnet]
        let sut = TONGaslessProviderJSAdapter(context: context, gaslessProvider: provider)
        context.setObject(sut, forKeyedSubscript: "adapter" as NSString)

        let result = context.evaluateScript("adapter.getSupportedNetworks()")

        #expect(result?.isArray == true)
        let networks: [TONNetwork] = try #require(try result?.decode())
        #expect(networks == [.mainnet])
    }

    @Test("getSupportedNetworks from JS is synchronous, not a Promise")
    func supportedNetworksFromJSIsSynchronous() {
        let sut = makeSUT()
        context.setObject(sut, forKeyedSubscript: "adapter" as NSString)

        let isPromise = context.evaluateScript("adapter.getSupportedNetworks() instanceof Promise")

        #expect(isPromise?.toBool() == false)
    }

    @Test("getMetadata from JS returns a Promise")
    func metadataFromJSIsPromise() {
        let sut = makeSUT()
        context.setObject(sut, forKeyedSubscript: "adapter" as NSString)

        let isPromise = context.evaluateScript("adapter.getMetadata() instanceof Promise")

        #expect(isPromise?.toBool() == true)
    }

    @Test("getMetadata resolves when called from JS")
    func metadataResolvesFromJS() async throws {
        let sut = makeSUT()
        context.setObject(sut, forKeyedSubscript: "adapter" as NSString)

        let promise = try #require(context.evaluateScript("adapter.getMetadata()"))
        let resolved = try await promise.then()

        #expect(resolved.forProperty("name")?.toString() == "Mock")
    }

    @Test("sendTransaction is callable from JS and resolves")
    func sendTransactionCallableFromJS() async throws {
        let sut = makeSUT()
        context.setObject(sut, forKeyedSubscript: "adapter" as NSString)
        let paramsJS = try makeSendParamsJS()
        context.setObject(paramsJS, forKeyedSubscript: "params" as NSString)

        let promise = try #require(context.evaluateScript("adapter.sendTransaction(params)"))
        let resolved = try await promise.then()

        #expect(resolved.forProperty("normalizedHash")?.toString() == "0xabcd")
    }
}
