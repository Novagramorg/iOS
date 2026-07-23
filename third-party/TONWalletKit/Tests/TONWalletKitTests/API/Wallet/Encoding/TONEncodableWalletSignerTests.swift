import Testing
import Foundation
import JavaScriptCore
@testable import TONWalletKit

@Suite("TONEncodableWalletSigner Tests")
struct TONEncodableWalletSignerTests {

    private let context = JSContext()!

    @Test("encode with JSValueEncodable signer delegates to signer's encode")
    func encodeWithJSValueEncodableSigner() throws {
        let mock = MockJSDynamicObject(jsContext: context)
        let signer = TONWalletSigner(jsWalletSigner: mock)
        let sut = TONEncodableWalletSigner(signer: signer)

        let result = try sut.encode(in: context)

        #expect(result is MockJSDynamicObject)
    }

    @Test("encode with non-JSValueEncodable signer creates TONWalletSignerJSAdapter")
    func encodeWithNonJSValueEncodableSigner() throws {
        let signer = MockSigner()
        let sut = TONEncodableWalletSigner(signer: signer)

        let result = try sut.encode(in: context)

        #expect(result is TONWalletSignerJSAdapter)
    }

    @Test("TONWalletSigner.encode returns jsWalletSigner")
    func walletSignerEncodeReturnsJSSigner() throws {
        let mock = MockJSDynamicObject(jsContext: context)
        let sut = TONWalletSigner(jsWalletSigner: mock)

        let result = try sut.encode(in: context)

        #expect(result is MockJSDynamicObject)
    }
}
