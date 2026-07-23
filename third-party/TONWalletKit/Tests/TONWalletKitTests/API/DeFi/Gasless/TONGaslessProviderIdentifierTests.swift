import Testing
@testable import TONWalletKit

@Suite("TONGaslessProviderIdentifier Tests")
struct TONGaslessProviderIdentifierTests {

    @Test("TONTonApiGaslessProviderIdentifier defaults to tonapi")
    func tonApiIdentifierDefaultsToTonapi() {
        let sut = TONTonApiGaslessProviderIdentifier()

        #expect(sut.name == "tonapi")
    }

    @Test("TONTonApiGaslessProviderIdentifier stores custom name")
    func tonApiIdentifierStoresCustomName() {
        let sut = TONTonApiGaslessProviderIdentifier(name: "custom")

        #expect(sut.name == "custom")
    }

    @Test("AnyTONGaslessProviderIdentifier stores name")
    func anyIdentifierStoresName() {
        let sut = AnyTONGaslessProviderIdentifier(name: "any-provider")

        #expect(sut.name == "any-provider")
    }

    @Test("eraseToAnyIdentifier preserves name")
    func eraseToAnyIdentifierPreservesName() {
        let sut = TONTonApiGaslessProviderIdentifier(name: "tonapi")

        let erased = sut.eraseToAnyIdentifier()

        #expect(erased.name == "tonapi")
    }
}
