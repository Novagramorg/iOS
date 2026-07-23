import Testing
import JavaScriptCore
@testable import TONWalletKit
import _BigInt

@Suite("TONStakingProvider Tests")
struct TONStakingProviderTests {

    private func makeSUT(
        identifierName: String = "tonstakers"
    ) -> (sut: TONStakingProvider<TONTonStakersStakingProviderIdentifier>, mock: MockJSDynamicObject) {
        let mock = MockJSDynamicObject()
        let identifier = TONTonStakersStakingProviderIdentifier(name: identifierName)
        let sut = TONStakingProvider(jsObject: mock, identifier: identifier)
        return (sut, mock)
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

    @Test("type returns staking")
    func typeReturnsStaking() {
        let (sut, _) = makeSUT()

        #expect(sut.type == .staking)
    }

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
            try await sut.quote(params: makeQuoteParams())
        }
    }

    @Test("stakeTransaction calls buildStakeTransaction on jsObject")
    func stakeTransactionCallsBuildStakeTransaction() async {
        let (sut, mock) = makeSUT()

        _ = try? await sut.stakeTransaction(params: makeStakeParams())

        #expect(mock.callRecords.first?.path == "buildStakeTransaction")
    }

    @Test("stakeTransaction throws when jsObject throws")
    func stakeTransactionThrowsOnError() async {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        await #expect(throws: (any Error).self) {
            try await sut.stakeTransaction(params: makeStakeParams())
        }
    }

    @Test("stakedBalance calls getStakedBalance on jsObject")
    func stakedBalanceCallsGetStakedBalance() async {
        let (sut, mock) = makeSUT()

        _ = try? await sut.stakedBalance(userAddress: makeAddress(), network: TONNetwork(chainId: "-239"))

        #expect(mock.callRecords.first?.path == "getStakedBalance")
    }

    @Test("stakedBalance throws when jsObject throws")
    func stakedBalanceThrowsOnError() async {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        await #expect(throws: (any Error).self) {
            try await sut.stakedBalance(userAddress: makeAddress(), network: nil)
        }
    }

    @Test("info calls getStakingProviderInfo on jsObject")
    func infoCallsGetStakingProviderInfo() async {
        let (sut, mock) = makeSUT()

        _ = try? await sut.info(network: TONNetwork(chainId: "-239"))

        #expect(mock.callRecords.first?.path == "getStakingProviderInfo")
    }

    @Test("info throws when jsObject throws")
    func infoThrowsOnError() async {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        await #expect(throws: (any Error).self) {
            try await sut.info(network: nil)
        }
    }

    @Test("metadata(network:) calls getStakingProviderMetadata on jsObject")
    func metadataCallsGetStakingProviderMetadata() throws {
        let (sut, mock) = makeSUT()
        let stub = TONStakingProviderMetadata(
            name: "Tonstakers",
            supportedUnstakeModes: [.instant, .roundEnd],
            supportsReversedQuote: true,
            stakeToken: TONStakingTokenInfo(ticker: "TON", decimals: 9, address: "ton")
        )
        mock.stubbedResults["getStakingProviderMetadata"] = stub

        let result = try sut.metadata(network: nil)

        #expect(mock.callRecords.first?.path == "getStakingProviderMetadata")
        #expect(result.name == "Tonstakers")
        #expect(result.supportsReversedQuote == true)
    }

    @Test("metadata(network:) throws when jsObject throws")
    func metadataThrowsOnError() {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        #expect(throws: (any Error).self) {
            try sut.metadata(network: nil)
        }
    }

    @Test("supportedNetworks calls getSupportedNetworks on jsObject")
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

    @Test("supportedUnstakeModes reads from metadata.supportedUnstakeModes")
    func supportedUnstakeModesReadsFromMetadata() throws {
        let (sut, mock) = makeSUT()
        let stub = TONStakingProviderMetadata(
            name: "Tonstakers",
            supportedUnstakeModes: [.whenAvailable, .roundEnd],
            supportsReversedQuote: false,
            stakeToken: TONStakingTokenInfo(ticker: "TON", decimals: 9, address: "ton")
        )
        mock.stubbedResults["getStakingProviderMetadata"] = stub

        let result = try sut.supportedUnstakeModes()

        #expect(mock.callRecords.first?.path == "getStakingProviderMetadata")
        #expect(result == [.whenAvailable, .roundEnd])
    }

    @Test("JSValueDecodable.from returns provider when providerId exists")
    func fromJSValueWithProviderIdReturnsProvider() throws {
        let context = JSContext()!
        context.evaluateScript("var obj = { providerId: 'tonstakers' }")
        let jsValue = context.objectForKeyedSubscript("obj")!

        let result = try TONStakingProvider<TONTonStakersStakingProviderIdentifier>.from(jsValue)

        #expect(result != nil)
        #expect(result?.identifier.name == "tonstakers")
    }

    @Test("JSValueDecodable.from returns nil when providerId is missing")
    func fromJSValueWithoutProviderIdReturnsNil() throws {
        let context = JSContext()!
        context.evaluateScript("var obj = {}")
        let jsValue = context.objectForKeyedSubscript("obj")!

        let result = try TONStakingProvider<TONTonStakersStakingProviderIdentifier>.from(jsValue)

        #expect(result == nil)
    }

    // MARK: - JS interop end-to-end

    @Test("supportedNetworks() decodes real JS array from getSupportedNetworks")
    func supportedNetworksDecodesRealJSArray() throws {
        let context = JSContext()!
        let providerJS = context.evaluateScript(
            """
            ({
                providerId: 'tonstakers',
                getSupportedNetworks: function() {
                    return [{ chainId: '-239' }];
                }
            })
            """
        )!
        let identifier = TONTonStakersStakingProviderIdentifier(name: "tonstakers")
        let sut = TONStakingProvider(jsObject: providerJS, identifier: identifier)

        let result = try sut.supportedNetworks()

        #expect(result == [.mainnet])
    }

    @Test("metadata() decodes real JS object from getStakingProviderMetadata")
    func metadataDecodesRealJSObject() throws {
        let context = JSContext()!
        let providerJS = context.evaluateScript(
            """
            ({
                providerId: 'tonstakers',
                getStakingProviderMetadata: function(network) {
                    return {
                        name: 'Tonstakers',
                        supportedUnstakeModes: ['INSTANT', 'WHEN_AVAILABLE', 'ROUND_END'],
                        supportsReversedQuote: true,
                        stakeToken: { ticker: 'TON', decimals: 9, address: 'ton' }
                    };
                }
            })
            """
        )!
        let identifier = TONTonStakersStakingProviderIdentifier(name: "tonstakers")
        let sut = TONStakingProvider(jsObject: providerJS, identifier: identifier)

        let result = try sut.metadata(network: nil)

        #expect(result.name == "Tonstakers")
        #expect(result.supportsReversedQuote == true)
        #expect(result.supportedUnstakeModes == [.instant, .whenAvailable, .roundEnd])
    }
}
