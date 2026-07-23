import Testing
import JavaScriptCore
@testable import TONWalletKit

@Suite("TONEncodableStakingProvider Tests")
struct TONEncodableStakingProviderTests {

    private let context = JSContext()!

    @Test("encode with JSValueEncodable provider delegates to provider's encode")
    func encodeWithJSValueEncodableProvider() throws {
        let mock = MockJSDynamicObject(jsContext: context)
        let identifier = TONTonStakersStakingProviderIdentifier(name: "tonstakers")
        let provider = TONStakingProvider(jsObject: mock, identifier: identifier)
        let sut = TONEncodableStakingProvider(stakingProvider: provider)

        let result = try sut.encode(in: context)

        #expect(result is MockJSDynamicObject)
    }

    @Test("encode with non-JSValueEncodable provider creates TONStakingProviderJSAdapter")
    func encodeWithNonJSValueEncodableProvider() throws {
        let identifier = TONTonStakersStakingProviderIdentifier(name: "tonstakers")
        let provider = MockStakingProvider(identifier: identifier)
        let sut = TONEncodableStakingProvider(stakingProvider: provider)

        let result = try sut.encode(in: context)

        #expect(result is TONStakingProviderJSAdapter<MockStakingProvider>)
    }
}
