import Testing
@testable import TONWalletKit

@Suite("TONStakingProviderIdentifier Tests")
struct TONStakingProviderIdentifierTests {

    @Test("TONTonStakersStakingProviderIdentifier stores name")
    func tonStakersIdentifierStoresName() {
        let sut = TONTonStakersStakingProviderIdentifier(name: "tonstakers")

        #expect(sut.name == "tonstakers")
    }
}
