import Testing
import JavaScriptCore
@testable import TONWalletKit
import _BigInt

@Suite("TONGaslessProvider Tests")
struct TONGaslessProviderTests {

    private func makeSUT(
        identifierName: String = "tonapi"
    ) -> (sut: TONGaslessProvider<TONTonApiGaslessProviderIdentifier>, mock: MockJSDynamicObject) {
        let mock = MockJSDynamicObject()
        let identifier = TONTonApiGaslessProviderIdentifier(name: identifierName)
        let sut = TONGaslessProvider(jsObject: mock, identifier: identifier)
        return (sut, mock)
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

    @Test("type returns gasless")
    func typeReturnsGasless() {
        let (sut, _) = makeSUT()

        #expect(sut.type == .gasless)
    }

    // MARK: - metadata

    @Test("metadata calls getMetadata on jsObject")
    func metadataCallsGetMetadata() async {
        let (sut, mock) = makeSUT()

        _ = try? await sut.metadata()

        #expect(mock.callRecords.first?.path == "getMetadata")
    }

    @Test("metadata throws when jsObject throws")
    func metadataThrowsOnError() async {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        await #expect(throws: (any Error).self) {
            try await sut.metadata()
        }
    }

    @Test("metadata decodes stubbed result")
    func metadataDecodesStubbedResult() async throws {
        let (sut, mock) = makeSUT()
        mock.stubbedResults["getMetadata"] = TONGaslessProviderMetadata(name: "TonAPI", url: "https://tonapi.io")

        let result = try await sut.metadata()

        #expect(result.name == "TonAPI")
        #expect(result.url == "https://tonapi.io")
    }

    // MARK: - supportedNetworks

    @Test("supportedNetworks calls getSupportedNetworks and decodes")
    func supportedNetworksCallsGetSupportedNetworks() throws {
        let (sut, mock) = makeSUT()
        mock.stubbedResults["getSupportedNetworks"] = [TONNetwork.mainnet]

        let result = try sut.supportedNetworks()

        #expect(mock.callRecords.first?.path == "getSupportedNetworks")
        #expect(result == [.mainnet])
    }

    @Test("supportedNetworks throws when jsObject throws")
    func supportedNetworksThrowsOnError() {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        #expect(throws: (any Error).self) {
            try sut.supportedNetworks()
        }
    }

    // MARK: - config

    @Test("config calls getConfig on jsObject")
    func configCallsGetConfig() async {
        let (sut, mock) = makeSUT()

        _ = try? await sut.config(network: .mainnet)

        #expect(mock.callRecords.first?.path == "getConfig")
    }

    @Test("config throws when jsObject throws")
    func configThrowsOnError() async {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        await #expect(throws: (any Error).self) {
            _ = try await sut.config(network: .mainnet)
        }
    }

    @Test("config decodes stubbed result")
    func configDecodesStubbedResult() async throws {
        let (sut, mock) = makeSUT()
        mock.stubbedResults["getConfig"] = TONGaslessConfig(
            relayAddress: makeAddress(),
            supportedAssets: [TONGaslessSupportedAsset(address: makeAddress())]
        )

        let result = try await sut.config(network: .mainnet)

        #expect(result.supportedAssets.count == 1)
    }

    // MARK: - quote

    @Test("quote calls getQuote on jsObject")
    func quoteCallsGetQuote() async {
        let (sut, mock) = makeSUT()

        _ = try? await sut.quote(params: makeQuoteParams())

        #expect(mock.callRecords.first?.path == "getQuote")
    }

    @Test("quote throws when jsObject throws")
    func quoteThrowsOnError() async {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        await #expect(throws: (any Error).self) {
            _ = try await sut.quote(params: makeQuoteParams())
        }
    }

    @Test("quote decodes stubbed result")
    func quoteDecodesStubbedResult() async throws {
        let (sut, mock) = makeSUT()
        mock.stubbedResults["getQuote"] = MockGaslessProvider.makeStubQuote()

        let result = try await sut.quote(params: makeQuoteParams())

        #expect(String(result.fee.nanoUnits) == "1000000")
    }

    // MARK: - sendTransaction

    @Test("sendTransaction calls sendTransaction on jsObject")
    func sendTransactionCallsSendTransaction() async {
        let (sut, mock) = makeSUT()

        _ = try? await sut.sendTransaction(params: makeSendParams())

        #expect(mock.callRecords.first?.path == "sendTransaction")
    }

    @Test("sendTransaction throws when jsObject throws")
    func sendTransactionThrowsOnError() async {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        await #expect(throws: (any Error).self) {
            _ = try await sut.sendTransaction(params: makeSendParams())
        }
    }

    @Test("sendTransaction decodes stubbed result")
    func sendTransactionDecodesStubbedResult() async throws {
        let (sut, mock) = makeSUT()
        mock.stubbedResults["sendTransaction"] = MockGaslessProvider.makeStubSendResponse()

        let result = try await sut.sendTransaction(params: makeSendParams())

        #expect(result.normalizedHash.value == "0xabcd")
    }

    // MARK: - JSValueDecodable.from

    @Test("JSValueDecodable.from returns provider when providerId exists")
    func fromJSValueWithProviderIdReturnsProvider() throws {
        let context = JSContext()!
        context.evaluateScript("var obj = { providerId: 'tonapi' }")
        let jsValue = context.objectForKeyedSubscript("obj")!

        let result = try TONGaslessProvider<TONTonApiGaslessProviderIdentifier>.from(jsValue)

        #expect(result != nil)
        #expect(result?.identifier.name == "tonapi")
    }

    @Test("JSValueDecodable.from returns nil when providerId is missing")
    func fromJSValueWithoutProviderIdReturnsNil() throws {
        let context = JSContext()!
        context.evaluateScript("var obj = {}")
        let jsValue = context.objectForKeyedSubscript("obj")!

        let result = try TONGaslessProvider<TONTonApiGaslessProviderIdentifier>.from(jsValue)

        #expect(result == nil)
    }

    // MARK: - JS interop end-to-end

    @Test("supportedNetworks() decodes real JS array from getSupportedNetworks")
    func supportedNetworksDecodesRealJSArray() throws {
        let context = JSContext()!
        let providerJS = context.evaluateScript(
            """
            ({
                providerId: 'tonapi',
                getSupportedNetworks: function() { return [{ chainId: '-239' }]; }
            })
            """
        )!
        let sut = TONGaslessProvider(jsObject: providerJS, identifier: TONTonApiGaslessProviderIdentifier())

        let result = try sut.supportedNetworks()

        #expect(result == [.mainnet])
    }

    @Test("metadata() decodes real JS object from getMetadata")
    func metadataDecodesRealJSObject() async throws {
        let context = JSContext()!
        let providerJS = context.evaluateScript(
            """
            ({
                providerId: 'tonapi',
                getMetadata: function() { return { name: 'TonAPI', url: 'https://tonapi.io' }; }
            })
            """
        )!
        let sut = TONGaslessProvider(jsObject: providerJS, identifier: TONTonApiGaslessProviderIdentifier())

        let result = try await sut.metadata()

        #expect(result.name == "TonAPI")
        #expect(result.url == "https://tonapi.io")
    }

    @Test("config() decodes real JS object from getConfig")
    func configDecodesRealJSObject() async throws {
        let context = JSContext()!
        let providerJS = context.evaluateScript(
            """
            ({
                providerId: 'tonapi',
                getConfig: function(network) {
                    return {
                        relayAddress: 'EQCrq6urq6urq6urq6urq6urq6urq6urq6urq6urq6urq8Uk',
                        supportedAssets: [{ address: 'EQCrq6urq6urq6urq6urq6urq6urq6urq6urq6urq6urq8Uk' }]
                    };
                }
            })
            """
        )!
        let sut = TONGaslessProvider(jsObject: providerJS, identifier: TONTonApiGaslessProviderIdentifier())

        let result = try await sut.config(network: .mainnet)

        #expect(result.supportedAssets.count == 1)
    }
}
