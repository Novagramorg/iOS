import Testing
import Foundation
import JavaScriptCore
import _BigInt
@testable import TONWalletKit

private class NonEncodableWallet: TONWalletProtocol {
    let id: TONWalletID = "non-encodable"
    let address: TONUserFriendlyAddress
    let client: any TONAPIClient

    init(address: TONUserFriendlyAddress) {
        self.address = address
        self.client = MockAPIClient()
    }

    func identifier() throws -> TONWalletID { id }
    func publicKey() throws -> TONHex { TONHex(data: Data([0x00])) }
    func network() throws -> TONNetwork { .mainnet }
    func address(testnet: Bool) throws -> TONUserFriendlyAddress { address }
    func stateInit() async throws -> TONBase64 { TONBase64(string: "test") }
    func signedSendTransaction(input: TONTransactionRequest, options: TONSignedSendTransactionOptions?) async throws -> TONBase64 { TONBase64(string: "test") }
    func signedSignMessage(input: TONTransactionRequest, options: TONSignedSendTransactionOptions?) async throws -> TONBase64 { TONBase64(string: "test") }
    func signedSignData(input: TONPreparedSignData, fakeSignature: Bool?) async throws -> TONHex { TONHex(data: Data([0x00])) }
    func signedTonProof(input: TONProofMessage, fakeSignature: Bool?) async throws -> TONHex { TONHex(data: Data([0x00])) }
    func supportedFeatures() -> [any TONFeature]? { nil }
    func balance() async throws -> TONBalance { TONTokenAmount(nanoUnits: BigInt(0)) }
    func transferTONTransaction(request: TONTransferRequest) async throws -> TONTransactionRequest { TONTransactionRequest(messages: []) }
    func transferTONTransaction(requests: [TONTransferRequest]) async throws -> TONTransactionRequest { TONTransactionRequest(messages: []) }
    func send(transactionRequest: TONTransactionRequest) async throws -> TONSendTransactionResponse {
        TONSendTransactionResponse(
            boc: TONBase64(string: "boc"),
            normalizedBoc: TONBase64(string: "normalizedBoc"),
            normalizedHash: TONHex(data: Data([0x00]))
        )
    }
    func preview(transactionRequest: TONTransactionRequest, options: TONTransactionPreviewOptions?) async throws -> TONTransactionEmulatedPreview { fatalError() }
    func transferNFTTransaction(request: TONNFTTransferRequest) async throws -> TONTransactionRequest { TONTransactionRequest(messages: []) }
    func transferNFTTransaction(request: TONNFTRawTransferRequest) async throws -> TONTransactionRequest { TONTransactionRequest(messages: []) }
    func nfts(request: TONNFTsRequest) async throws -> TONNFTsResponse { fatalError() }
    func nft(address: TONUserFriendlyAddress) async throws -> TONNFT { fatalError() }
    func jettonBalance(jettonAddress: TONUserFriendlyAddress) async throws -> TONBalance { TONTokenAmount(nanoUnits: BigInt(0)) }
    func jettonWalletAddress(jettonAddress: TONUserFriendlyAddress) async throws -> TONUserFriendlyAddress { fatalError() }
    func transferJettonTransaction(request: TONJettonsTransferRequest) async throws -> TONTransactionRequest { TONTransactionRequest(messages: []) }
    func jettons(request: TONJettonsRequest) async throws -> TONJettonsResponse { fatalError() }
}

@Suite("TONEncodableWallet Tests")
struct TONEncodableWalletTests {

    private let context = JSContext()!

    private let testAddress: TONUserFriendlyAddress = {
        let hash = Data(repeating: 0xab, count: 32)
        return TONRawAddress(workchain: 0, hash: hash).userFriendly(isBounceable: true)
    }()

    @Test("encode with JSValueEncodable wallet delegates to wallet's encode")
    func encodeWithJSValueEncodableWallet() throws {
        let mock = MockJSDynamicObject(jsContext: context)
        let wallet = TONWallet(jsWallet: mock, id: "w1", address: testAddress, client: MockAPIClient())
        let sut = TONEncodableWallet(wallet: wallet)

        let result = try sut.encode(in: context)

        #expect(result is MockJSDynamicObject)
    }

    @Test("encode with non-JSValueEncodable wallet throws .unableToEncode with wallet type")
    func encodeWithNonJSValueEncodableWallet() {
        let nonEncodable = NonEncodableWallet(address: testAddress)
        let sut = TONEncodableWallet(wallet: nonEncodable)

        let error = #expect(throws: JSValueConversionError.self) {
            try sut.encode(in: context)
        }

        guard case .unableToEncode(let type)? = error else {
            Issue.record("Expected .unableToEncode, got \(String(describing: error))")
            return
        }
        #expect(type == NonEncodableWallet.self)
    }

    @Test("stores wallet reference")
    func storesWalletReference() {
        let mock = MockJSDynamicObject(jsContext: context)
        let wallet = TONWallet(jsWallet: mock, id: "w1", address: testAddress, client: MockAPIClient())
        let sut = TONEncodableWallet(wallet: wallet)

        #expect(sut.wallet.id == "w1")
    }
}
