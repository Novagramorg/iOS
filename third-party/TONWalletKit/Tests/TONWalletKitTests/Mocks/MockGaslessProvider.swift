@testable import TONWalletKit
import _BigInt

struct MockGaslessProvider: TONGaslessProviderProtocol {
    typealias Identifier = TONTonApiGaslessProviderIdentifier

    var type: TONProviderType { .gasless }
    var identifier: TONTonApiGaslessProviderIdentifier

    var shouldThrow = false
    var mockMetadata = TONGaslessProviderMetadata(
        name: "Mock",
        logo: nil,
        url: "https://mock.io"
    )
    var mockSupportedNetworks: [TONNetwork] = [.mainnet]
    var mockConfig = TONGaslessConfig(
        relayAddress: TONRawAddress(workchain: 0, hash: Data(repeating: 0xab, count: 32)).userFriendly(isBounceable: true),
        supportedAssets: [
            TONGaslessSupportedAsset(
                address: TONRawAddress(workchain: 0, hash: Data(repeating: 0xcd, count: 32)).userFriendly(isBounceable: true)
            )
        ]
    )

    func metadata() async throws -> TONGaslessProviderMetadata {
        if shouldThrow { throw "Mock metadata error" }
        return mockMetadata
    }

    func supportedNetworks() throws -> [TONNetwork] {
        if shouldThrow { throw "Mock supportedNetworks error" }
        return mockSupportedNetworks
    }

    func config(network: TONNetwork) async throws -> TONGaslessConfig {
        if shouldThrow { throw "Mock config error" }
        return mockConfig
    }

    func quote(params: TONGaslessQuoteParams) async throws -> TONGaslessQuote {
        if shouldThrow { throw "Mock quote error" }
        return Self.makeStubQuote()
    }

    func sendTransaction(params: TONGaslessSendParams) async throws -> TONGaslessSendResponse {
        if shouldThrow { throw "Mock send error" }
        return Self.makeStubSendResponse()
    }

    static func makeStubQuote() -> TONGaslessQuote {
        TONGaslessQuote(
            network: TONNetwork(chainId: "-239"),
            messages: [],
            fee: TONTokenAmount(nanoUnits: BigInt(stringLiteral: "1000000")),
            validUntil: 1_900_000_000,
            from: TONRawAddress(workchain: 0, hash: Data(repeating: 0xab, count: 32)).userFriendly(isBounceable: true)
        )
    }

    static func makeStubSendResponse() -> TONGaslessSendResponse {
        TONGaslessSendResponse(
            boc: TONBase64(string: "boc"),
            normalizedBoc: TONBase64(string: "normalizedBoc"),
            normalizedHash: TONHex(data: Data([0xab, 0xcd])),
            internalBoc: TONBase64(string: "internalBoc")
        )
    }
}
