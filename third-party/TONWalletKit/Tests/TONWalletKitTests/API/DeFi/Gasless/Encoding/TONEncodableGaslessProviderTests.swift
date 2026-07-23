import Testing
import JavaScriptCore
@testable import TONWalletKit

@Suite("TONEncodableGaslessProvider Tests")
struct TONEncodableGaslessProviderTests {

    private let context = JSContext()!

    @Test("encode with JSValueEncodable provider delegates to provider's encode")
    func encodeWithJSValueEncodableProvider() throws {
        let mock = MockJSDynamicObject(jsContext: context)
        let identifier = TONTonApiGaslessProviderIdentifier(name: "tonapi")
        let provider = TONGaslessProvider(jsObject: mock, identifier: identifier)
        let sut = TONEncodableGaslessProvider(gaslessProvider: provider)

        let result = try sut.encode(in: context)

        #expect(result is MockJSDynamicObject)
    }

    @Test("encode with non-JSValueEncodable provider creates TONGaslessProviderJSAdapter")
    func encodeWithNonJSValueEncodableProvider() throws {
        let identifier = TONTonApiGaslessProviderIdentifier(name: "tonapi")
        let provider = MockGaslessProvider(identifier: identifier)
        let sut = TONEncodableGaslessProvider(gaslessProvider: provider)

        let result = try sut.encode(in: context)

        #expect(result is TONGaslessProviderJSAdapter<MockGaslessProvider>)
    }
}
