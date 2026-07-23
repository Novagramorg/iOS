@testable import TONWalletKit
import _BigInt

struct MockSwapProvider: TONSwapProviderProtocol {
    typealias Identifier = TONOmnistonSwapProviderIdentifier
    typealias QuoteOptions = TONOmnistonProviderOptions
    typealias SwapOptions = AnyCodable

    var type: TONProviderType { .swap }
    var identifier: TONOmnistonSwapProviderIdentifier

    var shouldThrow = false
    var mockMetadata = TONSwapProviderMetadata(name: "Mock", logo: nil, url: nil)
    var mockSupportedNetworks: [TONNetwork] = [.mainnet]

    func metadata() throws -> TONSwapProviderMetadata {
        if shouldThrow { throw "Mock metadata error" }
        return mockMetadata
    }

    func supportedNetworks() throws -> [TONNetwork] {
        if shouldThrow { throw "Mock supportedNetworks error" }
        return mockSupportedNetworks
    }

    func quote(params: TONSwapQuoteParams<TONOmnistonProviderOptions>) async throws -> TONSwapQuote {
        if shouldThrow { throw "Mock quote error" }
        return makeStubQuote()
    }

    func swapTransaction(params: TONSwapParams<AnyCodable>) async throws -> TONTransactionRequest {
        if shouldThrow { throw "Mock swap error" }
        return TONTransactionRequest(messages: [])
    }

    private func makeStubQuote() -> TONSwapQuote {
        let token = TONSwapToken(address: "ton", decimals: 9, name: "TON", symbol: "TON")
        return TONSwapQuote(
            fromToken: token,
            toToken: token,
            rawFromAmount: TONTokenAmount(nanoUnits: BigInt(stringLiteral: "1000000000")),
            rawToAmount: TONTokenAmount(nanoUnits: BigInt(stringLiteral: "1000000")),
            fromAmount: "1",
            toAmount: "1",
            rawMinReceived: TONTokenAmount(nanoUnits: BigInt(stringLiteral: "990000")),
            minReceived: "0.99",
            network: TONNetwork(chainId: "-239"),
            providerId: "omniston"
        )
    }
}
