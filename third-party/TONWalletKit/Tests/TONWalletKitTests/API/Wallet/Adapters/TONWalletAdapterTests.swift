import Testing
import Foundation
@testable import TONWalletKit

@Suite("TONWalletAdapter Tests")
struct TONWalletAdapterTests {

    private let testAddress: TONUserFriendlyAddress = {
        let hash = Data(repeating: 0xab, count: 32)
        return TONRawAddress(workchain: 0, hash: hash).userFriendly(isBounceable: true)
    }()

    private func makeSUT() -> (sut: TONWalletAdapter, mock: MockJSDynamicObject) {
        let mock = MockJSDynamicObject()
        let sut = TONWalletAdapter(jsWalletAdapter: mock)
        return (sut, mock)
    }

    @Test("identifier() calls getWalletId")
    func identifierCallsGetWalletId() throws {
        let (sut, mock) = makeSUT()
        mock.stubbedResults["getWalletId"] = "wallet-id" as String

        let result = try sut.identifier()

        #expect(mock.callRecords.first?.path == "getWalletId")
        #expect(result == "wallet-id")
    }

    @Test("identifier() throws when JSDynamic throws")
    func identifierThrowsOnError() {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        #expect(throws: (any Error).self) {
            try sut.identifier()
        }
    }

    @Test("publicKey() calls getPublicKey")
    func publicKeyCallsGetPublicKey() throws {
        let (sut, mock) = makeSUT()
        mock.stubbedResults["getPublicKey"] = "0xabcd" as String

        let result = try sut.publicKey()

        #expect(mock.callRecords.first?.path == "getPublicKey")
        #expect(result.value == "0xabcd")
    }

    @Test("publicKey() throws when JSDynamic throws")
    func publicKeyThrowsOnError() {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        #expect(throws: (any Error).self) {
            try sut.publicKey()
        }
    }

    @Test("network() calls getNetwork")
    func networkCallsGetNetwork() throws {
        let (sut, mock) = makeSUT()
        mock.stubbedResults["getNetwork"] = TONNetwork.mainnet

        let result = try sut.network()

        #expect(mock.callRecords.first?.path == "getNetwork")
        #expect(result == .mainnet)
    }

    @Test("network() throws when JSDynamic throws")
    func networkThrowsOnError() {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        #expect(throws: (any Error).self) {
            try sut.network()
        }
    }

    @Test("address() calls getAddress")
    func addressCallsGetAddress() throws {
        let (sut, mock) = makeSUT()
        mock.stubbedResults["getAddress"] = testAddress

        let result = try sut.address(testnet: false)

        #expect(mock.callRecords.first?.path == "getAddress")
        #expect(result == testAddress)
    }

    @Test("address() throws when JSDynamic throws")
    func addressThrowsOnError() {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        #expect(throws: (any Error).self) {
            try sut.address(testnet: false)
        }
    }

    @Test("stateInit() calls getStateInit")
    func stateInitCallsGetStateInit() async throws {
        let (sut, mock) = makeSUT()
        mock.stubbedAsyncResults["getStateInit"] = "dGVzdA==" as String

        let result = try await sut.stateInit()

        #expect(mock.callRecords.first?.path == "getStateInit")
        #expect(result.value == "dGVzdA==")
    }

    @Test("stateInit() throws when JSDynamic throws")
    func stateInitThrowsOnError() async {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        await #expect(throws: (any Error).self) {
            try await sut.stateInit()
        }
    }

    @Test("signedSendTransaction() calls getSignedSendTransaction")
    func signedSendTransactionCalls() async throws {
        let (sut, mock) = makeSUT()
        mock.stubbedAsyncResults["getSignedSendTransaction"] = "dGVzdA==" as String
        let input = TONTransactionRequest(messages: [])

        let result = try await sut.signedSendTransaction(input: input, options: nil)

        #expect(mock.callRecords.first?.path == "getSignedSendTransaction")
        #expect(result.value == "dGVzdA==")
    }

    @Test("signedSendTransaction() throws when JSDynamic throws")
    func signedSendTransactionThrowsOnError() async {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true
        let input = TONTransactionRequest(messages: [])

        await #expect(throws: (any Error).self) {
            try await sut.signedSendTransaction(input: input, options: nil)
        }
    }

    @Test("signedSignMessage() calls getSignedSignMessage")
    func signedSignMessageCalls() async throws {
        let (sut, mock) = makeSUT()
        mock.stubbedAsyncResults["getSignedSignMessage"] = "dGVzdA==" as String
        let input = TONTransactionRequest(messages: [])

        let result = try await sut.signedSignMessage(input: input, options: nil)

        #expect(mock.callRecords.first?.path == "getSignedSignMessage")
        #expect(result.value == "dGVzdA==")
    }

    @Test("signedSignMessage() throws when JSDynamic throws")
    func signedSignMessageThrowsOnError() async {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true
        let input = TONTransactionRequest(messages: [])

        await #expect(throws: (any Error).self) {
            try await sut.signedSignMessage(input: input, options: nil)
        }
    }

    @Test("signedSignData() calls getSignedSignData")
    func signedSignDataCalls() async throws {
        let (sut, mock) = makeSUT()
        mock.stubbedAsyncResults["getSignedSignData"] = "0xabcd" as String
        let input = TONPreparedSignData(
            address: testAddress,
            timestamp: 123,
            domain: "example.com",
            payload: TONSignDataPayload(
                data: .text(TONSignDataText(content: "test"))
            ),
            hash: TONHex(data: Data([0xab, 0xcd]))
        )

        let result = try await sut.signedSignData(input: input, fakeSignature: nil)

        #expect(mock.callRecords.first?.path == "getSignedSignData")
        #expect(result.value == "0xabcd")
    }

    @Test("signedSignData() throws when JSDynamic throws")
    func signedSignDataThrowsOnError() async {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true
        let input = TONPreparedSignData(
            address: testAddress,
            timestamp: 123,
            domain: "example.com",
            payload: TONSignDataPayload(
                data: .text(TONSignDataText(content: "test"))
            ),
            hash: TONHex(data: Data([0xab, 0xcd]))
        )

        await #expect(throws: (any Error).self) {
            try await sut.signedSignData(input: input, fakeSignature: nil)
        }
    }

    @Test("signedTonProof() calls getSignedTonProof")
    func signedTonProofCalls() async throws {
        let (sut, mock) = makeSUT()
        mock.stubbedAsyncResults["getSignedTonProof"] = "0xef01" as String
        let input = TONProofMessage(
            workchain: 0,
            addressHash: TONHex(data: Data([0xab, 0xcd])),
            timestamp: 1704067200,
            domain: TONProofMessageDomain(lengthBytes: 11, value: "example.com"),
            payload: "test",
            stateInit: TONBase64(string: "test")
        )

        let result = try await sut.signedTonProof(input: input, fakeSignature: nil)

        #expect(mock.callRecords.first?.path == "getSignedTonProof")
        #expect(result.value == "0xef01")
    }

    @Test("signedTonProof() throws when JSDynamic throws")
    func signedTonProofThrowsOnError() async {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true
        let input = TONProofMessage(
            workchain: 0,
            addressHash: TONHex(data: Data([0xab, 0xcd])),
            timestamp: 1704067200,
            domain: TONProofMessageDomain(lengthBytes: 11, value: "example.com"),
            payload: "test",
            stateInit: TONBase64(string: "test")
        )

        await #expect(throws: (any Error).self) {
            try await sut.signedTonProof(input: input, fakeSignature: nil)
        }
    }

    @Test("supportedFeatures() calls getSupportedFeatures and maps typed features")
    func supportedFeaturesCallsGetSupportedFeatures() {
        let (sut, mock) = makeSUT()
        let rawFeatures: [TONRawFeature] = [
            TONSendTransactionFeature(maxMessages: 4, extraCurrencySupported: true).raw,
            TONSignDataFeature(types: [.text, .binary]).raw
        ]
        mock.stubbedResults["getSupportedFeatures"] = rawFeatures

        let result = sut.supportedFeatures()

        #expect(mock.callRecords.first?.path == "getSupportedFeatures")
        #expect(result?.count == 2)
        let sendTx = result?[0] as? TONSendTransactionFeature
        #expect(sendTx?.maxMessages == 4)
        #expect(sendTx?.extraCurrencySupported == true)
        let signData = result?[1] as? TONSignDataFeature
        #expect(signData?.types == [.text, .binary])
    }

    @Test("supportedFeatures() returns nil when JSDynamic throws")
    func supportedFeaturesReturnsNilOnError() {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        let result = sut.supportedFeatures()

        #expect(result == nil)
    }

    @Test("supportedFeatures() filters out features with missing required fields")
    func supportedFeaturesFiltersInvalidFeatures() {
        let (sut, mock) = makeSUT()
        let rawFeatures: [TONRawFeature] = [
            TONRawFeature(name: .sendTransaction),
            TONSendTransactionFeature(maxMessages: 2).raw
        ]
        mock.stubbedResults["getSupportedFeatures"] = rawFeatures

        let result = sut.supportedFeatures()

        #expect(result?.count == 1)
        let sendTx = result?[0] as? TONSendTransactionFeature
        #expect(sendTx?.maxMessages == 2)
    }
}
