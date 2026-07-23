import Testing
import JavaScriptCore
@testable import TONWalletKit
import _BigInt

@Suite("TONGaslessManager Tests")
struct TONGaslessManagerTests {

    private func makeSUT() -> (sut: TONGaslessManager, mock: MockJSDynamicObject) {
        let mock = MockJSDynamicObject()
        let sut = TONGaslessManager(jsObject: mock)
        return (sut, mock)
    }

    private func makeProvider() -> TONGaslessProvider<TONTonApiGaslessProviderIdentifier> {
        let providerMock = MockJSDynamicObject()
        let identifier = TONTonApiGaslessProviderIdentifier(name: "tonapi")
        return TONGaslessProvider(jsObject: providerMock, identifier: identifier)
    }

    private func makeIdentifier(name: String = "tonapi") -> TONTonApiGaslessProviderIdentifier {
        TONTonApiGaslessProviderIdentifier(name: name)
    }

    private func makeAddress() -> TONUserFriendlyAddress {
        TONRawAddress(workchain: 0, hash: Data(repeating: 0xab, count: 32)).userFriendly(isBounceable: true)
    }

    private func makeQuoteParams() -> TONGaslessQuoteParams {
        TONGaslessQuoteParams(
            network: .mainnet,
            feeAsset: makeAddress(),
            walletAddress: makeAddress(),
            walletPublicKey: TONHex(data: Data([0xab, 0xcd])),
            messages: []
        )
    }

    private func makeSendParams() -> TONGaslessSendParams {
        TONGaslessSendParams(
            network: .mainnet,
            walletPublicKey: TONHex(data: Data([0xab, 0xcd])),
            internalBoc: TONBase64(string: "boc")
        )
    }

    // MARK: - Provider management

    @Test("register calls registerProvider on jsObject")
    func registerCallsRegisterProvider() throws {
        let (sut, mock) = makeSUT()

        try sut.register(provider: makeProvider())

        #expect(mock.callRecords.first?.path == "registerProvider")
    }

    @Test("remove(provider:) calls removeProvider on jsObject")
    func removeCallsRemoveProvider() throws {
        let (sut, mock) = makeSUT()

        try sut.remove(provider: makeProvider())

        #expect(mock.callRecords.first?.path == "removeProvider")
    }

    @Test("set(defaultProviderId:) calls setDefaultProvider on jsObject")
    func setDefaultProviderIdCallsSetDefaultProvider() throws {
        let (sut, mock) = makeSUT()

        try sut.set(defaultProviderId: makeIdentifier())

        #expect(mock.callRecords.first?.path == "setDefaultProvider")
    }

    @Test("provider(with:) calls getProvider on jsObject")
    func providerWithIdCallsGetProvider() throws {
        let (sut, mock) = makeSUT()

        _ = try sut.provider(with: makeIdentifier())

        #expect(mock.callRecords.first?.path == "getProvider")
    }

    @Test("providers() calls getProviders and decodes each")
    func providersCallsGetProviders() throws {
        let (sut, mock) = makeSUT()
        let context = mock.jsContext
        let arrayValue = context.evaluateScript(
            "[{ providerId: 'tonapi' }, { providerId: 'other' }]"
        )!
        mock.stubbedResults["getProviders"] = arrayValue

        let result = try sut.providers()

        #expect(mock.callRecords.first?.path == "getProviders")
        #expect(result.map { $0.identifier.name } == ["tonapi", "other"])
    }

    @Test("hasProvider(with:) calls hasProvider on jsObject")
    func hasProviderCallsHasProvider() throws {
        let (sut, mock) = makeSUT()
        mock.stubbedResults["hasProvider"] = true

        let result = try sut.hasProvider(with: makeIdentifier())

        #expect(mock.callRecords.first?.path == "hasProvider")
        #expect(result == true)
    }

    // MARK: - Operations

    @Test("metadata(identifier:) calls getMetadata with identifier name")
    func metadataWithIdentifierCallsGetMetadata() async {
        let (sut, mock) = makeSUT()

        _ = try? await sut.metadata(identifier: makeIdentifier())

        #expect(mock.callRecords.first?.path == "getMetadata")
        #expect(mock.callRecords.first?.args.count == 1)
    }

    @Test("metadata() with nil identifier calls getMetadata")
    func metadataWithNilIdentifierCallsGetMetadata() async {
        let (sut, mock) = makeSUT()

        _ = try? await sut.metadata()

        #expect(mock.callRecords.first?.path == "getMetadata")
    }

    @Test("metadata decodes stubbed result")
    func metadataDecodesStubbedResult() async throws {
        let (sut, mock) = makeSUT()
        mock.stubbedResults["getMetadata"] = TONGaslessProviderMetadata(name: "TonAPI", url: "https://tonapi.io")

        let result = try await sut.metadata(identifier: makeIdentifier())

        #expect(result.name == "TonAPI")
    }

    @Test("config(network:identifier:) calls getConfig with network and identifier name")
    func configWithIdentifierCallsGetConfig() async {
        let (sut, mock) = makeSUT()

        _ = try? await sut.config(network: .mainnet, identifier: makeIdentifier())

        #expect(mock.callRecords.first?.path == "getConfig")
        #expect(mock.callRecords.first?.args.count == 2)
    }

    @Test("config() with defaults calls getConfig")
    func configWithDefaultsCallsGetConfig() async {
        let (sut, mock) = makeSUT()

        _ = try? await sut.config()

        #expect(mock.callRecords.first?.path == "getConfig")
    }

    @Test("config decodes stubbed result")
    func configDecodesStubbedResult() async throws {
        let (sut, mock) = makeSUT()
        mock.stubbedResults["getConfig"] = TONGaslessConfig(
            relayAddress: makeAddress(),
            supportedAssets: [TONGaslessSupportedAsset(address: makeAddress())]
        )

        let result = try await sut.config(network: .mainnet, identifier: makeIdentifier())

        #expect(result.supportedAssets.count == 1)
    }

    @Test("quote(params:identifier:) calls getQuote with params and identifier name")
    func quoteWithIdentifierCallsGetQuote() async {
        let (sut, mock) = makeSUT()

        _ = try? await sut.quote(params: makeQuoteParams(), identifier: makeIdentifier())

        #expect(mock.callRecords.first?.path == "getQuote")
        #expect(mock.callRecords.first?.args.count == 2)
    }

    @Test("quote(params:) with default identifier calls getQuote")
    func quoteWithoutIdentifierCallsGetQuote() async {
        let (sut, mock) = makeSUT()

        _ = try? await sut.quote(params: makeQuoteParams())

        #expect(mock.callRecords.first?.path == "getQuote")
    }

    @Test("sendTransaction(params:identifier:) calls sendTransaction with params and identifier name")
    func sendTransactionWithIdentifierCallsSendTransaction() async {
        let (sut, mock) = makeSUT()

        _ = try? await sut.sendTransaction(params: makeSendParams(), identifier: makeIdentifier())

        #expect(mock.callRecords.first?.path == "sendTransaction")
        #expect(mock.callRecords.first?.args.count == 2)
    }

    @Test("sendTransaction(params:) with default identifier calls sendTransaction")
    func sendTransactionWithoutIdentifierCallsSendTransaction() async {
        let (sut, mock) = makeSUT()

        _ = try? await sut.sendTransaction(params: makeSendParams())

        #expect(mock.callRecords.first?.path == "sendTransaction")
    }

    @Test("JSValueDecodable.from returns manager")
    func fromJSValueReturnsManager() throws {
        let context = JSContext()!
        let jsValue = JSValue(object: [:], in: context)!

        let result = try TONGaslessManager.from(jsValue)

        #expect(result != nil)
    }

    // MARK: - JS interop end-to-end

    @Test("remove(provider:) routes through real JS removeProvider with provider object")
    func removeRoutesThroughJS() throws {
        let context = JSContext()!
        context.evaluateScript(
            """
            var lastRemovedProviderId = null;
            var manager = {
                removeProvider: function(p) { lastRemovedProviderId = p.providerId; }
            };
            """
        )
        let managerJS = context.objectForKeyedSubscript("manager")!
        let sut = TONGaslessManager(jsObject: managerJS)

        let providerJS = context.evaluateScript("({ providerId: 'tonapi' })")!
        let provider = TONGaslessProvider(jsObject: providerJS, identifier: TONTonApiGaslessProviderIdentifier())

        try sut.remove(provider: provider)

        let recordedId = context.objectForKeyedSubscript("lastRemovedProviderId")?.toString()
        #expect(recordedId == "tonapi")
    }

    @Test("providers() decodes real JS array returned by getProviders")
    func providersDecodesRealJSArray() throws {
        let context = JSContext()!
        context.evaluateScript(
            """
            var manager = {
                getProviders: function() {
                    return [{ providerId: 'tonapi' }, { providerId: 'other' }];
                }
            };
            """
        )
        let managerJS = context.objectForKeyedSubscript("manager")!
        let sut = TONGaslessManager(jsObject: managerJS)

        let result = try sut.providers()

        #expect(result.map { $0.identifier.name } == ["tonapi", "other"])
    }

    @Test("metadata decodes real JS object returned by getMetadata")
    func metadataDecodesRealJSObject() async throws {
        let context = JSContext()!
        context.evaluateScript(
            """
            var manager = {
                getMetadata: function(providerId) {
                    return { name: 'TonAPI', url: 'https://tonapi.io' };
                }
            };
            """
        )
        let managerJS = context.objectForKeyedSubscript("manager")!
        let sut = TONGaslessManager(jsObject: managerJS)

        let result = try await sut.metadata(identifier: nil)

        #expect(result.name == "TonAPI")
        #expect(result.url == "https://tonapi.io")
    }

    @Test("config decodes real JS object returned by getConfig")
    func configDecodesRealJSObject() async throws {
        let context = JSContext()!
        context.evaluateScript(
            """
            var manager = {
                getConfig: function(network, providerId) {
                    return {
                        relayAddress: 'EQCrq6urq6urq6urq6urq6urq6urq6urq6urq6urq6urq8Uk',
                        supportedAssets: [{ address: 'EQCrq6urq6urq6urq6urq6urq6urq6urq6urq6urq6urq8Uk' }]
                    };
                }
            };
            """
        )
        let managerJS = context.objectForKeyedSubscript("manager")!
        let sut = TONGaslessManager(jsObject: managerJS)

        let result = try await sut.config(network: .mainnet, identifier: nil)

        #expect(result.supportedAssets.count == 1)
    }

    @Test("sendTransaction decodes real JS object returned by sendTransaction")
    func sendTransactionDecodesRealJSObject() async throws {
        let context = JSContext()!
        context.evaluateScript(
            """
            var manager = {
                sendTransaction: function(params, providerId) {
                    return {
                        boc: 'Ym9j',
                        normalizedBoc: 'Ym9j',
                        normalizedHash: 'abcd',
                        internalBoc: 'Ym9j'
                    };
                }
            };
            """
        )
        let managerJS = context.objectForKeyedSubscript("manager")!
        let sut = TONGaslessManager(jsObject: managerJS)

        let result = try await sut.sendTransaction(params: makeSendParams(), identifier: nil)

        #expect(result.normalizedHash.value == "abcd")
    }
}
