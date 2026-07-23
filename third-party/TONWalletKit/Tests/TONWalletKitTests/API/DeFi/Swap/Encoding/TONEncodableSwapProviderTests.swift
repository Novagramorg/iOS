import Testing
import JavaScriptCore
@testable import TONWalletKit

@Suite("TONEncodableSwapProvider Tests")
struct TONEncodableSwapProviderTests {

    private let context = JSContext()!

    @Test("encode with JSValueEncodable provider delegates to provider's encode")
    func encodeWithJSValueEncodableProvider() throws {
        let mock = MockJSDynamicObject(jsContext: context)
        let identifier = TONOmnistonSwapProviderIdentifier(name: "omniston")
        let provider = TONSwapProvider(jsObject: mock, identifier: identifier)
        let sut = TONEncodableSwapProvider(swapProvider: provider)

        let result = try sut.encode(in: context)

        #expect(result is MockJSDynamicObject)
    }

    @Test("encode with non-JSValueEncodable provider creates TONSwapProviderJSAdapter")
    func encodeWithNonJSValueEncodableProvider() throws {
        let identifier = TONOmnistonSwapProviderIdentifier(name: "omniston")
        let provider = MockSwapProvider(identifier: identifier)
        let sut = TONEncodableSwapProvider(swapProvider: provider)

        let result = try sut.encode(in: context)

        #expect(result is TONSwapProviderJSAdapter<MockSwapProvider>)
    }
}
