@testable import TONWalletKit
import _BigInt

struct MockStakingProvider: TONStakingProviderProtocol {
    typealias Identifier = TONTonStakersStakingProviderIdentifier
    typealias QuoteOptions = AnyCodable
    typealias StakeOptions = AnyCodable

    var type: TONProviderType { .staking }
    var identifier: TONTonStakersStakingProviderIdentifier

    var shouldThrow = false
    var mockMetadata = TONStakingProviderMetadata(
        name: "Mock",
        supportedUnstakeModes: [.instant, .whenAvailable, .roundEnd],
        supportsReversedQuote: false,
        stakeToken: TONStakingTokenInfo(ticker: "TON", decimals: 9, address: "ton"),
        receiveToken: nil,
        contractAddress: nil
    )
    var mockSupportedNetworks: [TONNetwork] = [.mainnet]

    func metadata(network: TONNetwork?) throws -> TONStakingProviderMetadata {
        if shouldThrow { throw "Mock metadata error" }
        return mockMetadata
    }

    func supportedNetworks() throws -> [TONNetwork] {
        if shouldThrow { throw "Mock supportedNetworks error" }
        return mockSupportedNetworks
    }

    func quote(params: TONStakingQuoteParams<AnyCodable>) async throws -> TONStakingQuote {
        if shouldThrow { throw "Mock quote error" }
        return makeStubQuote()
    }

    func stakeTransaction(params: TONStakeParams<AnyCodable>) async throws -> TONTransactionRequest {
        if shouldThrow { throw "Mock stake error" }
        return TONTransactionRequest(messages: [])
    }

    func stakedBalance(userAddress: TONUserFriendlyAddress, network: TONNetwork?) async throws -> TONStakingBalance {
        if shouldThrow { throw "Mock balance error" }
        return makeStubBalance()
    }

    func info(network: TONNetwork?) async throws -> TONStakingProviderInfo {
        if shouldThrow { throw "Mock info error" }
        return makeStubProviderInfo()
    }

    private func makeStubQuote() -> TONStakingQuote {
        TONStakingQuote(
            direction: .stake,
            rawAmountIn: TONTokenAmount(nanoUnits: BigInt(stringLiteral: "1000000000")),
            rawAmountOut: TONTokenAmount(nanoUnits: BigInt(stringLiteral: "950000000")),
            amountIn: "1",
            amountOut: "0.95",
            network: TONNetwork(chainId: "-239"),
            providerId: "tonstakers"
        )
    }

    private func makeStubBalance() -> TONStakingBalance {
        TONStakingBalance(
            rawStakedBalance: TONTokenAmount(nanoUnits: BigInt(stringLiteral: "5000000000")),
            stakedBalance: "5",
            rawInstantUnstakeAvailable: TONTokenAmount(nanoUnits: BigInt(stringLiteral: "1000000000")),
            instantUnstakeAvailable: "1",
            providerId: "tonstakers"
        )
    }

    private func makeStubProviderInfo() -> TONStakingProviderInfo {
        TONStakingProviderInfo(
            apy: 500
        )
    }
}
