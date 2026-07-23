import Testing
import Foundation
import JavaScriptCore
import _BigInt
@testable import TONWalletKit

@Suite("TONWallet Tests")
struct TONWalletTests {

    private let testAddress: TONUserFriendlyAddress = {
        let hash = Data(repeating: 0xab, count: 32)
        return TONRawAddress(workchain: 0, hash: hash)
            .userFriendly(isBounceable: true)
    }()

    private func makeSUT() -> (sut: TONWallet, mock: MockJSDynamicObject) {
        let mock = MockJSDynamicObject()
        let sut = TONWallet(
            jsWallet: mock,
            id: "test-wallet",
            address: testAddress,
            client: MockAPIClient()
        )
        return (sut, mock)
    }

    @Test("init stores id and address")
    func initStoresProperties() {
        let (sut, _) = makeSUT()

        #expect(sut.id == "test-wallet")
        #expect(sut.address == testAddress)
    }

    @Test("balance() calls getBalance")
    func balanceCallsGetBalance() async {
        let (sut, mock) = makeSUT()

        _ = try? await sut.balance()

        #expect(mock.callRecords.first?.path == "getBalance")
    }

    @Test("transferTONTransaction(request:) calls createTransferTonTransaction")
    func transferTONTransactionCallsSingle() async {
        let (sut, mock) = makeSUT()
        let request = TONTransferRequest(
            transferAmount: TONTokenAmount(nanoUnits: BigInt(1_000_000_000)),
            recipientAddress: testAddress
        )

        _ = try? await sut.transferTONTransaction(request: request)

        #expect(mock.callRecords.first?.path == "createTransferTonTransaction")
    }

    @Test("transferTONTransaction(requests:) calls createTransferMultiTonTransaction")
    func transferTONTransactionCallsMulti() async {
        let (sut, mock) = makeSUT()
        let request = TONTransferRequest(
            transferAmount: TONTokenAmount(nanoUnits: BigInt(1_000_000_000)),
            recipientAddress: testAddress
        )

        _ = try? await sut.transferTONTransaction(requests: [request])

        #expect(mock.callRecords.first?.path == "createTransferMultiTonTransaction")
    }

    @Test("send() calls sendTransaction")
    func sendCallsSendTransaction() async {
        let (sut, mock) = makeSUT()
        let request = TONTransactionRequest(messages: [])

        _ = try? await sut.send(transactionRequest: request)

        #expect(mock.callRecords.first?.path == "sendTransaction")
    }

    @Test("send() returns decoded TONSendTransactionResponse")
    func sendReturnsDecodedResponse() async throws {
        let (sut, mock) = makeSUT()
        let stub = TONSendTransactionResponse(
            boc: try TONBase64(base64Encoded: "Ym9j"),
            normalizedBoc: try TONBase64(base64Encoded: "bm9ybWFsaXplZA=="),
            normalizedHash: TONHex(data: Data([0xab, 0xcd]))
        )
        mock.stubbedAsyncResults["sendTransaction"] = stub
        let request = TONTransactionRequest(messages: [])

        let result = try await sut.send(transactionRequest: request)

        #expect(result.boc.value == "Ym9j")
        #expect(result.normalizedBoc.value == "bm9ybWFsaXplZA==")
        #expect(result.normalizedHash.value == TONHex(data: Data([0xab, 0xcd])).value)
    }

    @Test("preview() calls getTransactionPreview")
    func previewCallsGetTransactionPreview() async {
        let (sut, mock) = makeSUT()
        let request = TONTransactionRequest(messages: [])

        _ = try? await sut.preview(transactionRequest: request)

        #expect(mock.callRecords.first?.path == "getTransactionPreview")
    }

    @Test("preview(options:) forwards options to getTransactionPreview")
    func previewForwardsOptions() async {
        let (sut, mock) = makeSUT()
        let request = TONTransactionRequest(messages: [])
        let options = TONTransactionPreviewOptions(mode: .sign)

        _ = try? await sut.preview(transactionRequest: request, options: options)

        #expect(mock.callRecords.first?.path == "getTransactionPreview")
        #expect(mock.callRecords.first?.args.count == 2)
        #expect(mock.callRecords.first?.args[1] is TONTransactionPreviewOptions)
    }

    @Test("preview() without options forwards only the request")
    func previewWithoutOptionsForwardsSingleArg() async {
        let (sut, mock) = makeSUT()
        let request = TONTransactionRequest(messages: [])

        _ = try? await sut.preview(transactionRequest: request)

        #expect(mock.callRecords.first?.args.count == 1)
    }

    @Test("transferNFTTransaction() calls createTransferNftTransaction")
    func transferNFTTransactionCalls() async {
        let (sut, mock) = makeSUT()
        let request = TONNFTTransferRequest(
            nftAddress: testAddress,
            recipientAddress: testAddress
        )

        _ = try? await sut.transferNFTTransaction(request: request)

        #expect(mock.callRecords.first?.path == "createTransferNftTransaction")
    }

    @Test("nfts() calls getNfts")
    func nftsCallsGetNfts() async {
        let (sut, mock) = makeSUT()
        let request = TONNFTsRequest()

        _ = try? await sut.nfts(request: request)

        #expect(mock.callRecords.first?.path == "getNfts")
    }

    @Test("jettonBalance() calls getJettonBalance")
    func jettonBalanceCallsGetJettonBalance() async {
        let (sut, mock) = makeSUT()

        _ = try? await sut.jettonBalance(jettonAddress: testAddress)

        #expect(mock.callRecords.first?.path == "getJettonBalance")
    }

    @Test("transferJettonTransaction() calls createTransferJettonTransaction")
    func transferJettonTransactionCalls() async {
        let (sut, mock) = makeSUT()
        let request = TONJettonsTransferRequest(
            jettonAddress: testAddress,
            transferAmount: TONTokenAmount(nanoUnits: BigInt(1_000_000)),
            recipientAddress: testAddress
        )

        _ = try? await sut.transferJettonTransaction(request: request)

        #expect(mock.callRecords.first?.path == "createTransferJettonTransaction")
    }

    @Test("transferNFTTransaction(raw request) calls createTransferNftRawTransaction")
    func transferNFTRawTransactionCalls() async {
        let (sut, mock) = makeSUT()
        let message = TONNFTRawTransferRequestMessage(
            queryId: BigInt(1),
            newOwner: testAddress,
            forwardAmount: BigInt(0)
        )
        let request = TONNFTRawTransferRequest(
            nftAddress: testAddress,
            transferAmount: TONTokenAmount(nanoUnits: BigInt(50_000_000)),
            message: message
        )

        _ = try? await sut.transferNFTTransaction(request: request)

        #expect(mock.callRecords.first?.path == "createTransferNftRawTransaction")
    }

    @Test("nft(address:) calls getNft")
    func nftCallsGetNft() async {
        let (sut, mock) = makeSUT()

        _ = try? await sut.nft(address: testAddress)

        #expect(mock.callRecords.first?.path == "getNft")
    }

    @Test("jettonWalletAddress() calls getJettonWalletAddress")
    func jettonWalletAddressCallsGetJettonWalletAddress() async {
        let (sut, mock) = makeSUT()

        _ = try? await sut.jettonWalletAddress(jettonAddress: testAddress)

        #expect(mock.callRecords.first?.path == "getJettonWalletAddress")
    }

    @Test("jettons() calls getJettons")
    func jettonsCallsGetJettons() async {
        let (sut, mock) = makeSUT()
        let request = TONJettonsRequest(pagination: TONPagination(limit: 10))

        _ = try? await sut.jettons(request: request)

        #expect(mock.callRecords.first?.path == "getJettons")
    }

    @Test("init stores client")
    func initStoresClient() throws {
        let mock = MockJSDynamicObject()
        let client = MockAPIClient()
        client.stubbedNetwork = .testnet
        let sut = TONWallet(
            jsWallet: mock,
            id: "test-wallet",
            address: testAddress,
            client: client
        )

        #expect(try sut.client.network() == .testnet)
    }

    @Test("from(_:) wraps JS getClient() result in JSTONAPIClient")
    func fromDecodesClientFromJS() throws {
        let context = JSContext()!
        let addressValue = testAddress.value
        context.evaluateScript(
            """
            var stubWallet = {
                getWalletId: function() { return "decoded-wallet-id"; },
                getAddress: function() { return "\(addressValue)"; },
                getClient: function() {
                    return {
                        getNetwork: function() { return { chainId: "-3" }; }
                    };
                }
            };
            """
        )
        let jsValue = context.objectForKeyedSubscript("stubWallet")!

        let wallet = try #require(try TONWallet.from(jsValue))

        #expect(wallet.id == "decoded-wallet-id")
        #expect(wallet.address == testAddress)
        #expect(wallet.client is JSTONAPIClient)
        #expect(try wallet.client.network() == .testnet)
    }
}
