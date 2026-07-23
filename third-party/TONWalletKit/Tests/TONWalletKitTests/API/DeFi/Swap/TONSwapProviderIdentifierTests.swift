import Testing
@testable import TONWalletKit

@Suite("TONSwapProviderIdentifier Tests")
struct TONSwapProviderIdentifierTests {

    @Test("TONOmnistonSwapProviderIdentifier stores name")
    func omnistonIdentifierStoresName() {
        let sut = TONOmnistonSwapProviderIdentifier(name: "omniston")

        #expect(sut.name == "omniston")
    }

    @Test("TONDeDustSwapProviderIdentifier stores name")
    func deDustIdentifierStoresName() {
        let sut = TONDeDustSwapProviderIdentifier(name: "dedust")

        #expect(sut.name == "dedust")
    }
}
