import Testing
import JavaScriptCore
@testable import TONWalletKit
import _BigInt

@Suite("TONStakingManager Tests")
struct TONStakingManagerTests {

    private func makeSUT() -> (sut: TONStakingManager, mock: MockJSDynamicObject) {
        let mock = MockJSDynamicObject()
        let sut = TONStakingManager(jsObject: mock)
        return (sut, mock)
    }

    private func makeProvider() -> TONStakingProvider<TONTonStakersStakingProviderIdentifier> {
        let providerMock = MockJSDynamicObject()
        let identifier = TONTonStakersStakingProviderIdentifier(name: "tonstakers")
        return TONStakingProvider(jsObject: providerMock, identifier: identifier)
    }

    private func makeIdentifier(name: String = "tonstakers") -> TONTonStakersStakingProviderIdentifier {
        TONTonStakersStakingProviderIdentifier(name: name)
    }

    private func makeQuoteParams() -> TONStakingQuoteParams<AnyCodable> {
        TONStakingQuoteParams(
            direction: .stake,
            amount: "1000000000"
        )
    }

    private func makeStakeParams() -> TONStakeParams<AnyCodable> {
        let quote = TONStakingQuote(
            direction: .stake,
            rawAmountIn: TONTokenAmount(nanoUnits: BigInt(stringLiteral: "1000000000")),
            rawAmountOut: TONTokenAmount(nanoUnits: BigInt(stringLiteral: "950000000")),
            amountIn: "1",
            amountOut: "0.95",
            network: TONNetwork(chainId: "-239"),
            providerId: "tonstakers"
        )
        let address = TONRawAddress(workchain: 0, hash: Data(repeating: 0xab, count: 32)).userFriendly(isBounceable: true)
        return TONStakeParams(quote: quote, userAddress: address)
    }

    private func makeAddress() -> TONUserFriendlyAddress {
        TONRawAddress(workchain: 0, hash: Data(repeating: 0xab, count: 32)).userFriendly(isBounceable: true)
    }

    @Test("register calls registerProvider on jsObject")
    func registerCallsRegisterProvider() throws {
        let (sut, mock) = makeSUT()

        try sut.register(provider: makeProvider())

        #expect(mock.callRecords.first?.path == "registerProvider")
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

    @Test("remove(provider:) calls removeProvider on jsObject")
    func removeCallsRemoveProvider() throws {
        let (sut, mock) = makeSUT()

        try sut.remove(provider: makeProvider())

        #expect(mock.callRecords.first?.path == "removeProvider")
    }

    @Test("providers() calls getProviders and decodes each")
    func providersCallsGetProviders() throws {
        let (sut, mock) = makeSUT()
        let context = mock.jsContext
        let arrayValue = context.evaluateScript(
            "[{ providerId: 'tonstakers' }, { providerId: 'other' }]"
        )!
        mock.stubbedResults["getProviders"] = arrayValue

        let result = try sut.providers()

        #expect(mock.callRecords.first?.path == "getProviders")
        #expect(result.map { $0.identifier.name } == ["tonstakers", "other"])
    }

    @Test("metadata(network:identifier:) calls getStakingProviderMetadata on jsObject")
    func metadataCallsGetStakingProviderMetadata() throws {
        let (sut, mock) = makeSUT()
        let stub = TONStakingProviderMetadata(
            name: "Tonstakers",
            supportedUnstakeModes: [.instant],
            supportsReversedQuote: false,
            stakeToken: TONStakingTokenInfo(ticker: "TON", decimals: 9, address: "ton")
        )
        mock.stubbedResults["getStakingProviderMetadata"] = stub

        let result = try sut.metadata(network: nil, identifier: makeIdentifier())

        #expect(mock.callRecords.first?.path == "getStakingProviderMetadata")
        #expect(result.name == "Tonstakers")
    }

    @Test("hasProvider(with:) calls hasProvider on jsObject")
    func hasProviderCallsHasProvider() throws {
        let (sut, mock) = makeSUT()
        mock.stubbedResults["hasProvider"] = true

        let result = try sut.hasProvider(with: makeIdentifier())

        #expect(mock.callRecords.first?.path == "hasProvider")
        #expect(result == true)
    }

    @Test("quote(params:identifier:) calls getQuote with params and identifier name")
    func quoteWithIdentifierCallsGetQuote() async {
        let (sut, mock) = makeSUT()

        _ = try? await sut.quote(params: makeQuoteParams(), identifier: makeIdentifier())

        #expect(mock.callRecords.first?.path == "getQuote")
        #expect(mock.callRecords.first?.args.count == 2)
    }

    @Test("quote(params:) calls getQuote with params only")
    func quoteWithoutIdentifierCallsGetQuote() async {
        let (sut, mock) = makeSUT()

        _ = try? await sut.quote(params: makeQuoteParams())

        #expect(mock.callRecords.first?.path == "getQuote")
        #expect(mock.callRecords.first?.args.count == 1)
    }

    @Test("stakeTransaction(params:identifier:) calls buildStakeTransaction with params and identifier name")
    func stakeTransactionWithIdentifierCallsBuildStakeTransaction() async {
        let (sut, mock) = makeSUT()

        _ = try? await sut.stakeTransaction(params: makeStakeParams(), identifier: makeIdentifier())

        #expect(mock.callRecords.first?.path == "buildStakeTransaction")
        #expect(mock.callRecords.first?.args.count == 2)
    }

    @Test("stakeTransaction(params:) calls buildStakeTransaction with params only")
    func stakeTransactionWithoutIdentifierCallsBuildStakeTransaction() async {
        let (sut, mock) = makeSUT()

        _ = try? await sut.stakeTransaction(params: makeStakeParams())

        #expect(mock.callRecords.first?.path == "buildStakeTransaction")
        #expect(mock.callRecords.first?.args.count == 1)
    }

    @Test("stakedBalance calls getStakedBalance with address, network and identifier name")
    func stakedBalanceWithIdentifierCallsGetStakedBalance() async {
        let (sut, mock) = makeSUT()

        _ = try? await sut.stakedBalance(
            userAddress: makeAddress(),
            network: TONNetwork(chainId: "-239"),
            identifier: makeIdentifier()
        )

        #expect(mock.callRecords.first?.path == "getStakedBalance")
        #expect(mock.callRecords.first?.args.count == 3)
    }

    @Test("stakedBalance with nil identifier passes nil")
    func stakedBalanceWithNilIdentifierPassesNil() async {
        let (sut, mock) = makeSUT()

        _ = try? await sut.stakedBalance(
            userAddress: makeAddress(),
            network: nil,
            identifier: nil
        )

        #expect(mock.callRecords.first?.path == "getStakedBalance")
    }

    @Test("info calls getStakingProviderInfo with network and identifier name")
    func infoWithIdentifierCallsGetStakingProviderInfo() async {
        let (sut, mock) = makeSUT()

        _ = try? await sut.info(
            network: TONNetwork(chainId: "-239"),
            identifier: makeIdentifier()
        )

        #expect(mock.callRecords.first?.path == "getStakingProviderInfo")
    }

    @Test("supportedUnstakeModes reads from metadata.supportedUnstakeModes")
    func supportedUnstakeModesReadsFromMetadata() throws {
        let (sut, mock) = makeSUT()
        let stub = TONStakingProviderMetadata(
            name: "Tonstakers",
            supportedUnstakeModes: [.instant, .roundEnd],
            supportsReversedQuote: false,
            stakeToken: TONStakingTokenInfo(ticker: "TON", decimals: 9, address: "ton")
        )
        mock.stubbedResults["getStakingProviderMetadata"] = stub

        let result = try sut.supportedUnstakeModes(network: nil, identifier: makeIdentifier())

        #expect(mock.callRecords.first?.path == "getStakingProviderMetadata")
        #expect(result == [.instant, .roundEnd])
    }

    @Test("JSValueDecodable.from returns manager")
    func fromJSValueReturnsManager() throws {
        let context = JSContext()!
        let jsValue = JSValue(object: [:], in: context)!

        let result = try TONStakingManager.from(jsValue)

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
        let sut = TONStakingManager(jsObject: managerJS)

        let providerJS = context.evaluateScript("({ providerId: 'tonstakers' })")!
        let identifier = TONTonStakersStakingProviderIdentifier(name: "tonstakers")
        let provider = TONStakingProvider(jsObject: providerJS, identifier: identifier)

        try sut.remove(provider: provider)

        let recordedId = context.objectForKeyedSubscript("lastRemovedProviderId")?.toString()
        #expect(recordedId == "tonstakers")
    }

    @Test("providers() decodes real JS array returned by getProviders")
    func providersDecodesRealJSArray() throws {
        let context = JSContext()!
        context.evaluateScript(
            """
            var manager = {
                getProviders: function() {
                    return [{ providerId: 'tonstakers' }, { providerId: 'other' }];
                }
            };
            """
        )
        let managerJS = context.objectForKeyedSubscript("manager")!
        let sut = TONStakingManager(jsObject: managerJS)

        let result = try sut.providers()

        #expect(result.map { $0.identifier.name } == ["tonstakers", "other"])
    }

    @Test("metadata(network:identifier:) decodes real JS metadata object")
    func metadataDecodesRealJSObject() throws {
        let context = JSContext()!
        context.evaluateScript(
            """
            var manager = {
                getStakingProviderMetadata: function(network, providerId) {
                    return {
                        name: 'Tonstakers',
                        supportedUnstakeModes: ['INSTANT', 'ROUND_END'],
                        supportsReversedQuote: true,
                        stakeToken: { ticker: 'TON', decimals: 9, address: 'ton' }
                    };
                }
            };
            """
        )
        let managerJS = context.objectForKeyedSubscript("manager")!
        let sut = TONStakingManager(jsObject: managerJS)

        let result = try sut.metadata(network: nil, identifier: makeIdentifier())

        #expect(result.name == "Tonstakers")
        #expect(result.supportedUnstakeModes == [.instant, .roundEnd])
    }
}
