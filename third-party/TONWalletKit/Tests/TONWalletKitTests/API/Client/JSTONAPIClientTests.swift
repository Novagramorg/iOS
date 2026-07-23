import Testing
import Foundation
import JavaScriptCore
@testable import TONWalletKit

@Suite("JSTONAPIClient Tests")
struct JSTONAPIClientTests {

    private let testAddress: TONUserFriendlyAddress = {
        let hash = Data(repeating: 0xab, count: 32)
        return TONRawAddress(workchain: 0, hash: hash).userFriendly(isBounceable: true)
    }()

    private func makeSUT() -> (sut: JSTONAPIClient, mock: MockJSDynamicObject) {
        let mock = MockJSDynamicObject()
        let sut = JSTONAPIClient(jsClient: mock)
        return (sut, mock)
    }

    @Test("network() calls getNetwork and returns stubbed value")
    func networkCallsGetNetwork() throws {
        let (sut, mock) = makeSUT()
        mock.stubbedResults["getNetwork"] = TONNetwork.testnet

        let result = try sut.network()

        #expect(mock.callRecords.first?.path == "getNetwork")
        #expect(result == .testnet)
    }

    @Test("network() throws when JSDynamic throws")
    func networkThrowsOnError() {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        #expect(throws: (any Error).self) {
            try sut.network()
        }
    }

    @Test("send(boc:) calls sendBoc with the boc value")
    func sendCallsSendBoc() async throws {
        let (sut, mock) = makeSUT()
        mock.stubbedAsyncResults["sendBoc"] = "ok" as String
        let boc = try TONBase64(base64Encoded: "dGVzdA==")

        let result = try await sut.send(boc: boc)

        #expect(mock.callRecords.first?.path == "sendBoc")
        #expect(mock.callRecords.first?.args.first as? String == "dGVzdA==")
        #expect(result == "ok")
    }

    @Test("send(boc:) throws when JSDynamic throws")
    func sendThrowsOnError() async throws {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true
        let boc = try TONBase64(base64Encoded: "dGVzdA==")

        await #expect(throws: (any Error).self) {
            try await sut.send(boc: boc)
        }
    }

    @Test("runGetMethod() calls runGetMethod and returns stubbed result")
    func runGetMethodCallsRunGetMethod() async throws {
        let (sut, mock) = makeSUT()
        let stub = TONGetMethodResult(gasUsed: 1, stack: [], exitCode: 0)
        mock.stubbedAsyncResults["runGetMethod"] = stub

        let result = try await sut.runGetMethod(
            address: testAddress,
            method: "seqno",
            stack: nil,
            seqno: nil
        )

        #expect(mock.callRecords.first?.path == "runGetMethod")
        #expect(result.gasUsed == stub.gasUsed)
        #expect(result.exitCode == stub.exitCode)
    }

    @Test("runGetMethod() throws when JSDynamic throws")
    func runGetMethodThrowsOnError() async {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        await #expect(throws: (any Error).self) {
            try await sut.runGetMethod(
                address: testAddress,
                method: "seqno",
                stack: nil,
                seqno: nil
            )
        }
    }

    @Test("masterchainInfo() calls getMasterchainInfo")
    func masterchainInfoCallsGetMasterchainInfo() async throws {
        let (sut, mock) = makeSUT()
        let stub = try TONMasterchainInfo(
            seqno: 42,
            shard: "8000000000000000",
            workchain: -1,
            fileHash: TONHex(hexString: "aabb"),
            rootHash: TONHex(hexString: "ccdd")
        )
        mock.stubbedAsyncResults["getMasterchainInfo"] = stub

        let result = try await sut.masterchainInfo()

        #expect(mock.callRecords.first?.path == "getMasterchainInfo")
        #expect(result.seqno == 42)
    }

    @Test("masterchainInfo() throws when JSDynamic throws")
    func masterchainInfoThrowsOnError() async {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        await #expect(throws: (any Error).self) {
            try await sut.masterchainInfo()
        }
    }

    // MARK: - NFT

    @Test("nftItemsByAddress calls nftItemsByAddress")
    func nftItemsByAddressCallsNftItemsByAddress() async throws {
        let (sut, mock) = makeSUT()
        mock.stubbedAsyncResults["nftItemsByAddress"] = TONNFTsResponse(nfts: [])

        _ = try await sut.nftItemsByAddress(request: TONNFTsRequest())

        #expect(mock.callRecords.first?.path == "nftItemsByAddress")
    }

    @Test("nftItemsByAddress throws when JSDynamic throws")
    func nftItemsByAddressThrowsOnError() async {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        await #expect(throws: (any Error).self) {
            try await sut.nftItemsByAddress(request: TONNFTsRequest())
        }
    }

    @Test("nftItemsByOwner calls nftItemsByOwner")
    func nftItemsByOwnerCallsNftItemsByOwner() async throws {
        let (sut, mock) = makeSUT()
        mock.stubbedAsyncResults["nftItemsByOwner"] = TONNFTsResponse(nfts: [])

        _ = try await sut.nftItemsByOwner(request: TONUserNFTsRequest(ownerAddress: testAddress))

        #expect(mock.callRecords.first?.path == "nftItemsByOwner")
    }

    @Test("nftItemsByOwner throws when JSDynamic throws")
    func nftItemsByOwnerThrowsOnError() async {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        await #expect(throws: (any Error).self) {
            try await sut.nftItemsByOwner(request: TONUserNFTsRequest(ownerAddress: testAddress))
        }
    }

    @Test("nftTransfers forwards filters and pagination")
    func nftTransfersForwardsRequest() async throws {
        let (sut, mock) = makeSUT()
        mock.stubbedAsyncResults["getNftTransfers"] = TONNFTTransfersResponse(transfers: [])
        let request = TONNFTTransfersRequest(
            ownerAddresses: [testAddress],
            itemAddresses: [testAddress],
            direction: .incoming,
            pagination: TONPagination(limit: 1000, offset: 0)
        )

        let result = try await sut.nftTransfers(request: request)

        let forwarded = mock.callRecords.first?.args.first as? TONNFTTransfersRequest
        #expect(mock.callRecords.first?.path == "getNftTransfers")
        #expect(forwarded?.ownerAddresses == [testAddress])
        #expect(forwarded?.itemAddresses == [testAddress])
        #expect(forwarded?.direction == .incoming)
        #expect(forwarded?.pagination?.limit == 1000)
        #expect(forwarded?.pagination?.offset == 0)
        #expect(result.transfers.isEmpty)
    }

    @Test("nftTransfers encodes filters and decodes transfers for a real JS client")
    func nftTransfersRealJSRoundTrip() async throws {
        let context = JSContext()!
        context.evaluateScript(
            """
            var observedNftTransfersRequest = null;
            var jsClient = {
                getNftTransfers: function(request) {
                    observedNftTransfersRequest = request;
                    return Promise.resolve({
                        transfers: [{
                            nftAddress: '\(testAddress.value)',
                            oldOwner: null,
                            newOwner: '\(testAddress.value)',
                            transactionNow: 1784730600,
                            transactionAborted: false
                        }]
                    });
                }
            };
            """
        )
        let sut = JSTONAPIClient(jsClient: context.objectForKeyedSubscript("jsClient")!)

        let result = try await sut.nftTransfers(request: TONNFTTransfersRequest(
            ownerAddresses: [testAddress],
            itemAddresses: [testAddress],
            direction: .incoming,
            pagination: TONPagination(limit: 1000, offset: 0)
        ))
        let observed = context.objectForKeyedSubscript("observedNftTransfersRequest")!

        #expect(observed.forProperty("ownerAddresses")?.atIndex(0)?.toString() == testAddress.value)
        #expect(observed.forProperty("itemAddresses")?.atIndex(0)?.toString() == testAddress.value)
        #expect(observed.forProperty("direction")?.toString() == "in")
        #expect(observed.forProperty("pagination")?.forProperty("limit")?.toInt32() == 1000)
        #expect(observed.forProperty("pagination")?.forProperty("offset")?.toInt32() == 0)
        #expect(result.transfers.count == 1)
        #expect(result.transfers[0].nftAddress == testAddress)
        #expect(result.transfers[0].newOwner == testAddress)
        #expect(result.transfers[0].transactionNow == 1784730600)
        #expect(result.transfers[0].transactionAborted == false)
    }

    // MARK: - Emulation

    @Test("fetchEmulation calls fetchEmulation with messageBoc + ignoreSignature")
    func fetchEmulationCallsFetchEmulation() async throws {
        let (sut, mock) = makeSUT()
        let boc = try TONBase64(base64Encoded: "dGVzdA==")
        mock.stubbedAsyncResults["fetchEmulation"] = TONEmulationResult.error(emulationError: TONEmulationError(code: 0, message: "stub"))

        _ = try await sut.fetchEmulation(messageBoc: boc, ignoreSignature: true)

        #expect(mock.callRecords.first?.path == "fetchEmulation")
        #expect(mock.callRecords.first?.args.first as? String == "dGVzdA==")
    }

    @Test("fetchEmulation throws when JSDynamic throws")
    func fetchEmulationThrowsOnError() async throws {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true
        let boc = try TONBase64(base64Encoded: "dGVzdA==")

        await #expect(throws: (any Error).self) {
            try await sut.fetchEmulation(messageBoc: boc, ignoreSignature: nil)
        }
    }

    // MARK: - Account state / balance

    @Test("accountState calls getAccountState")
    func accountStateCallsGetAccountState() async throws {
        let (sut, mock) = makeSUT()
        mock.stubbedAsyncResults["getAccountState"] = TONAccountState(
            address: testAddress,
            status: .nonExisting,
            rawBalance: TONTokenAmount(nanoUnits: 0),
            balance: "0",
            extraCurrencies: [:]
        )

        _ = try await sut.accountState(address: testAddress, seqno: nil)

        #expect(mock.callRecords.first?.path == "getAccountState")
    }

    @Test("accountState throws when JSDynamic throws")
    func accountStateThrowsOnError() async {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        await #expect(throws: (any Error).self) {
            try await sut.accountState(address: testAddress, seqno: nil)
        }
    }

    @Test("accountStates calls getAccountStates and converts string keys back to TONUserFriendlyAddress")
    func accountStatesCallsGetAccountStates() async throws {
        let (sut, mock) = makeSUT()
        let state = TONAccountState(
            address: testAddress,
            status: .active,
            rawBalance: TONTokenAmount(nanoUnits: 7),
            balance: "0.000000007",
            extraCurrencies: [:]
        )
        mock.stubbedAsyncResults["getAccountStates"] = [testAddress.value: state]

        let result = try await sut.accountStates(addresses: [testAddress])

        #expect(mock.callRecords.first?.path == "getAccountStates")
        #expect((mock.callRecords.first?.args.first as? [TONUserFriendlyAddress])?.first == testAddress)
        #expect(result.count == 1)
        #expect(result[testAddress]?.rawBalance.nanoUnits == 7)
    }

    @Test("accountStates throws when JSDynamic throws")
    func accountStatesThrowsOnError() async {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        await #expect(throws: (any Error).self) {
            try await sut.accountStates(addresses: [testAddress])
        }
    }

    @Test("accountStates throws when JS returns a key that is not a valid address")
    func accountStatesThrowsOnInvalidAddressKey() async {
        let (sut, mock) = makeSUT()
        let state = TONAccountState(
            address: testAddress,
            status: .nonExisting,
            rawBalance: TONTokenAmount(nanoUnits: 0),
            balance: "0",
            extraCurrencies: [:]
        )
        mock.stubbedAsyncResults["getAccountStates"] = ["not-a-valid-address": state]

        await #expect(throws: (any Error).self) {
            _ = try await sut.accountStates(addresses: [testAddress])
        }
    }

    @Test("accountTransactions forwards address and pagination")
    func accountTransactionsForwardsRequest() async throws {
        let (sut, mock) = makeSUT()
        mock.stubbedAsyncResults["getAccountTransactions"] = TONTransactionsResponse(
            transactions: [],
            addressBook: [:]
        )

        let result = try await sut.accountTransactions(
            addresses: [testAddress],
            limit: 30,
            offset: 60
        )

        let request = mock.callRecords.first?.args.first as? TONAccountTransactionsRequest
        #expect(mock.callRecords.first?.path == "getAccountTransactions")
        #expect(request?.address == [testAddress])
        #expect(request?.limit == 30)
        #expect(request?.offset == 60)
        #expect(result.transactions.isEmpty)
    }

    @Test("accountTransactions encodes request for a real JS client")
    func accountTransactionsRealJSRoundTrip() async throws {
        let context = JSContext()!
        context.evaluateScript(
            """
            var observedTransactionsRequest = null;
            var jsClient = {
                getAccountTransactions: function(request) {
                    observedTransactionsRequest = request;
                    return Promise.resolve({ transactions: [], addressBook: {} });
                }
            };
            """
        )
        let sut = JSTONAPIClient(jsClient: context.objectForKeyedSubscript("jsClient")!)

        let result = try await sut.accountTransactions(
            addresses: [testAddress],
            limit: 30,
            offset: 60
        )
        let observed = context.objectForKeyedSubscript("observedTransactionsRequest")!

        #expect(result.transactions.isEmpty)
        #expect(observed.forProperty("address")?.atIndex(0)?.toString() == testAddress.value)
        #expect(observed.forProperty("limit")?.toInt32() == 30)
        #expect(observed.forProperty("offset")?.toInt32() == 60)
    }

    @Test("accountStates decodes a real JS Promise<Record<address, AccountState>> end-to-end")
    func accountStatesRealJSRoundTrip() async throws {
        let context = JSContext()!
        let addressA = try TONUserFriendlyAddress(value: "EQCrq6urq6urq6urq6urq6urq6urq6urq6urq6urq6urq8Uk")
        let addressB = try TONUserFriendlyAddress(value: "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c")

        context.evaluateScript(
            """
            var jsClient = {
                getAccountStates: function(addresses) {
                    return new Promise(function(resolve) {
                        var result = {};
                        for (var i = 0; i < addresses.length; i++) {
                            var addr = addresses[i];
                            result[addr] = {
                                address: addr,
                                status: i === 0 ? 'active' : 'non-existing',
                                rawBalance: i === 0 ? '500' : '0',
                                balance: i === 0 ? '0.0000005' : '0',
                                extraCurrencies: {}
                            };
                        }
                        resolve(result);
                    });
                }
            };
            """
        )
        let jsClient = context.objectForKeyedSubscript("jsClient")!
        let sut = JSTONAPIClient(jsClient: jsClient)

        let result = try await sut.accountStates(addresses: [addressA, addressB])

        #expect(result.count == 2)
        #expect(result[addressA]?.status == .active)
        #expect(result[addressA]?.rawBalance.nanoUnits == 500)
        #expect(result[addressA]?.address == addressA)
        #expect(result[addressB]?.status == .nonExisting)
        #expect(result[addressB]?.rawBalance.nanoUnits == 0)
    }

    @Test("accountStates surfaces real JS Promise rejections")
    func accountStatesRealJSRejection() async throws {
        let context = JSContext()!
        context.evaluateScript(
            """
            var jsClient = {
                getAccountStates: function(addresses) {
                    return Promise.reject(new Error('boom'));
                }
            };
            """
        )
        let jsClient = context.objectForKeyedSubscript("jsClient")!
        let sut = JSTONAPIClient(jsClient: jsClient)

        await #expect(throws: (any Error).self) {
            _ = try await sut.accountStates(addresses: [testAddress])
        }
    }

    @Test("balance calls getBalance")
    func balanceCallsGetBalance() async throws {
        let (sut, mock) = makeSUT()
        mock.stubbedAsyncResults["getBalance"] = TONTokenAmount(nanoUnits: 42)

        let result = try await sut.balance(address: testAddress, seqno: nil)

        #expect(mock.callRecords.first?.path == "getBalance")
        #expect(result.nanoUnits == 42)
    }

    @Test("balance throws when JSDynamic throws")
    func balanceThrowsOnError() async {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        await #expect(throws: (any Error).self) {
            try await sut.balance(address: testAddress, seqno: nil)
        }
    }

    // MARK: - DNS

    @Test("resolveDnsWallet calls resolveDnsWallet")
    func resolveDnsWalletCallsResolveDnsWallet() async throws {
        let (sut, mock) = makeSUT()
        mock.stubbedAsyncResults["resolveDnsWallet"] = "wallet-address" as String

        let result = try await sut.resolveDnsWallet(domain: "foo.ton")

        #expect(mock.callRecords.first?.path == "resolveDnsWallet")
        #expect(result == "wallet-address")
    }

    @Test("resolveDnsWallet throws when JSDynamic throws")
    func resolveDnsWalletThrowsOnError() async {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        await #expect(throws: (any Error).self) {
            try await sut.resolveDnsWallet(domain: "foo.ton")
        }
    }

    @Test("backResolveDnsWallet calls backResolveDnsWallet")
    func backResolveDnsWalletCallsBackResolveDnsWallet() async throws {
        let (sut, mock) = makeSUT()
        mock.stubbedAsyncResults["backResolveDnsWallet"] = "foo.ton" as String

        let result = try await sut.backResolveDnsWallet(address: testAddress)

        #expect(mock.callRecords.first?.path == "backResolveDnsWallet")
        #expect(result == "foo.ton")
    }

    @Test("backResolveDnsWallet throws when JSDynamic throws")
    func backResolveDnsWalletThrowsOnError() async {
        let (sut, mock) = makeSUT()
        mock.shouldThrowOnCall = true

        await #expect(throws: (any Error).self) {
            try await sut.backResolveDnsWallet(address: testAddress)
        }
    }

}
