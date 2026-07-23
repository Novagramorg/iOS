import Testing
import Foundation
@testable import TONWalletKit

@Suite("TONWalletSigner Tests")
struct TONWalletSignerTests {

    private func makeSUT() -> (sut: TONWalletSigner, mock: MockJSDynamicObject) {
        let mock = MockJSDynamicObject()
        let sut = TONWalletSigner(jsWalletSigner: mock)
        return (sut, mock)
    }

    @Test("sign() calls sign on jsWalletSigner")
    func signCallsJSSigner() async throws {
        let (sut, mock) = makeSUT()
        mock.stubbedAsyncResults["sign"] = "0xabcd" as String

        let result = try await sut.sign(data: Data([0x01, 0x02, 0x03]))

        #expect(mock.callRecords.first?.path == "sign")
        #expect(result.value == "0xabcd")
    }

    @Test("sign() throws when JSDynamic throws")
    func signThrowsOnError() async {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        await #expect(throws: (any Error).self) {
            try await sut.sign(data: Data([0x01]))
        }
    }

    @Test("publicKey() returns hex from jsWalletSigner property")
    func publicKeyReturnsHex() {
        let (sut, mock) = makeSUT()
        mock.stubbedProperties["publicKey"] = "0xabcd" as String

        let result = sut.publicKey()

        #expect(result.value == "0xabcd")
    }

    @Test("publicKey() returns empty hex when property is nil")
    func publicKeyReturnsEmptyWhenNil() {
        let (sut, _) = makeSUT()

        let result = sut.publicKey()

        #expect(result.data == Data())
    }
}
