import Testing
import Foundation
import JavaScriptCore
@testable import TONWalletKit

@Suite("TONEncodableWalletAdapter Tests")
struct TONEncodableWalletAdapterTests {

    private let context = JSContext()!

    @Test("encode with JSValueEncodable adapter delegates to adapter's encode")
    func encodeWithJSValueEncodableAdapter() throws {
        let mock = MockJSDynamicObject(jsContext: context)
        let adapter = TONWalletAdapter(jsWalletAdapter: mock)
        let sut = TONEncodableWalletAdapter(walletAdapter: adapter)

        let result = try sut.encode(in: context)

        #expect(result is MockJSDynamicObject)
    }

    @Test("encode with non-JSValueEncodable adapter creates TONWalletAdapterJSAdapter")
    func encodeWithNonJSValueEncodableAdapter() throws {
        let adapter = MockWalletAdapter()
        let sut = TONEncodableWalletAdapter(walletAdapter: adapter)

        let result = try sut.encode(in: context)

        #expect(result is TONWalletAdapterJSAdapter)
    }

    @Test("TONWalletAdapter.encode returns jsWalletAdapter")
    func walletAdapterEncodeReturnsJSAdapter() throws {
        let mock = MockJSDynamicObject(jsContext: context)
        let sut = TONWalletAdapter(jsWalletAdapter: mock)

        let result = try sut.encode(in: context)

        #expect(result is MockJSDynamicObject)
    }
}
