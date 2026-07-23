//
//  TONAPIClientJSAdapterTests.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 08.02.2026.
//
//  Copyright (c) 2026 TON Connect
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import Testing
import JavaScriptCore
@testable import TONWalletKit

@Suite("TONAPIClientJSAdapter Tests")
struct TONAPIClientJSAdapterTests {

    private let context = JSContext()!

    private func makeSUT(
        client: MockAPIClient = MockAPIClient(),
        network: TONNetwork = .mainnet
    ) -> (sut: TONAPIClientJSAdapter, client: MockAPIClient) {
        client.stubbedNetwork = network
        let sut = TONAPIClientJSAdapter(
            context: context,
            apiClient: client
        )
        return (sut, client)
    }

    @Test("getNetwork returns mainnet chainId")
    func getNetworkReturnsMainnetChainId() throws {
        let (sut, _) = makeSUT(network: .mainnet)

        let result: TONNetwork = try sut.getNetwork().decode()

        #expect(result == TONNetwork.mainnet)
    }

    @Test("getNetwork returns testnet chainId")
    func getNetworkReturnsTestnetChainId() throws {
        let (sut, _) = makeSUT(network: .testnet)

        let result: TONNetwork = try sut.getNetwork().decode()

        #expect(result == TONNetwork.testnet)
    }

    @Test("getNetwork returns custom chainId from client")
    func getNetworkReturnsCustomChainId() throws {
        let custom = TONNetwork(chainId: "123456")
        let (sut, _) = makeSUT(network: custom)

        let result: TONNetwork = try sut.getNetwork().decode()

        #expect(result == custom)
    }

    @Test("getNetwork reflects updates to the client's network after init")
    func getNetworkReflectsUpdatedNetwork() throws {
        let (sut, client) = makeSUT(network: .mainnet)

        let initial: TONNetwork = try sut.getNetwork().decode()
        #expect(initial == .mainnet)

        client.stubbedNetwork = .testnet
        let updated: TONNetwork = try sut.getNetwork().decode()
        #expect(updated == .testnet)
    }

    @Test("getNetwork throws when context is deallocated")
    func getNetworkThrowsWhenDeallocated() {
        let client = MockAPIClient()
        var jsContext: JSContext? = JSContext()!
        let sut = TONAPIClientJSAdapter(
            context: jsContext!,
            apiClient: client
        )
        jsContext = nil

        #expect(throws: (any Error).self) {
            let _: TONNetwork = try sut.getNetwork().decode()
        }
    }

    @Test("Send resolves with result from API client")
    func sendResolvesWithResult() async throws {
        let (sut, _) = makeSUT()
        let boc = JSValue(object: "dGVzdA==", in: context)!

        let result = sut.send(boc: boc)
        let resolved = try await result.then()

        #expect(resolved.toString() == "ok")
    }

    @Test("Send rejects promise for invalid boc")
    func sendRejectsPromiseForInvalidBoc() async {
        let (sut, _) = makeSUT()
        let boc = JSValue(undefinedIn: context)!

        let result = sut.send(boc: boc)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("Send rejects when API client throws")
    func sendRejectsWhenAPIClientThrows() async {
        let client = MockAPIClient()
        client.shouldThrow = true
        let (sut, _) = makeSUT(client: client)
        let boc = JSValue(object: "dGVzdA==", in: context)!

        let result = sut.send(boc: boc)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("send rejects when context is deallocated")
    func sendRejectsWhenDeallocated() async {
        let client = MockAPIClient()
        var jsContext: JSContext? = JSContext()!
        let sut = TONAPIClientJSAdapter(context: jsContext!, apiClient: client)
        let boc = JSValue(object: "dGVzdA==", in: context)!
        jsContext = nil

        let result = sut.send(boc: boc)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("runGetMethod rejects when context is deallocated")
    func runGetMethodRejectsWhenDeallocated() async {
        let client = MockAPIClient()
        var jsContext: JSContext? = JSContext()!
        let sut = TONAPIClientJSAdapter(context: jsContext!, apiClient: client)
        let address = JSValue(undefinedIn: context)!
        let method = JSValue(undefinedIn: context)!
        let stack = JSValue(undefinedIn: context)!
        let seqno = JSValue(undefinedIn: context)!
        jsContext = nil

        let result = sut.runGetMethod(address: address, method: method, stack: stack, seqno: seqno)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("runGetMethod rejects promise for invalid input")
    func runGetMethodRejectsPromiseForInvalidInput() async {
        let (sut, _) = makeSUT()
        let address = JSValue(undefinedIn: context)!
        let method = JSValue(undefinedIn: context)!
        let stack = JSValue(undefinedIn: context)!
        let seqno = JSValue(undefinedIn: context)!

        let result = sut.runGetMethod(
            address: address,
            method: method,
            stack: stack,
            seqno: seqno
        )

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("masterchainInfo resolves with result from API client")
    func masterchainInfoResolvesWithResult() async throws {
        let (sut, _) = makeSUT()

        let result = sut.masterchainInfo()
        let resolved = try await result.then()
        let decoded: TONMasterchainInfo = try resolved.decode()

        #expect(decoded.seqno == 12345)
        #expect(decoded.shard == "8000000000000000")
        #expect(decoded.workchain == -1)
    }

    @Test("masterchainInfo rejects when API client throws")
    func masterchainInfoRejectsWhenAPIClientThrows() async {
        let client = MockAPIClient()
        client.shouldThrow = true
        let (sut, _) = makeSUT(client: client)

        let result = sut.masterchainInfo()

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("masterchainInfo rejects when context is deallocated")
    func masterchainInfoRejectsWhenDeallocated() async {
        let client = MockAPIClient()
        var jsContext: JSContext? = JSContext()!
        let sut = TONAPIClientJSAdapter(context: jsContext!, apiClient: client)
        jsContext = nil

        let result = sut.masterchainInfo()

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("getNetwork is callable from JS")
    func getNetworkCallableFromJS() throws {
        let (sut, _) = makeSUT(network: .mainnet)
        context.evaluateScript("function callGetNetwork(client) { return client.getNetwork(); }")

        let result: JSValue = try context.callGetNetwork(sut)

        #expect(result.forProperty("chainId")?.toString() == "-239")
    }

    @Test("getNetwork from JS returns testnet chainId")
    func getNetworkFromJSReturnsTestnetChainId() throws {
        let (sut, _) = makeSUT(network: .testnet)
        context.evaluateScript("function callGetNetwork(client) { return client.getNetwork(); }")

        let result: JSValue = try context.callGetNetwork(sut)

        #expect(result.forProperty("chainId")?.toString() == "-3")
    }

    @Test("getNetwork from JS returns a plain object, not a Promise")
    func getNetworkFromJSIsSynchronous() throws {
        let (sut, _) = makeSUT(network: .mainnet)
        context.evaluateScript(
            "function isPromiseFromGetNetwork(client) { return client.getNetwork() instanceof Promise; }"
        )

        let isPromise: Bool = try context.isPromiseFromGetNetwork(sut)

        #expect(isPromise == false)
    }

    @Test("masterchainInfo resolves from JS call")
    func masterchainInfoResolvesFromJS() async throws {
        let (sut, _) = makeSUT()
        context.evaluateScript("function callMasterchainInfo(client) { return client.getMasterchainInfo(); }")

        let result: TONMasterchainInfo = try await context.callMasterchainInfo(sut)

        #expect(result.seqno == 12345)
    }

    // MARK: - NFT

    @Test("nftItemsByAddress resolves from JS with the wallet's response")
    func nftItemsByAddressResolvesFromJS() async throws {
        let (sut, client) = makeSUT()
        client.stubbedNFTsResponse = TONNFTsResponse(nfts: [])
        context.evaluateScript("function callNftItemsByAddress(c) { return c.nftItemsByAddress({}); }")

        let result: TONNFTsResponse = try await context.callNftItemsByAddress(sut)

        #expect(result.nfts.isEmpty)
    }

    @Test("nftItemsByAddress rejects when wallet throws")
    func nftItemsByAddressRejectsWhenWalletThrows() async {
        let (sut, client) = makeSUT()
        client.shouldThrow = true
        context.evaluateScript("function callNftItemsByAddress(c) { return c.nftItemsByAddress({}); }")

        await #expect(throws: (any Error).self) {
            let _: TONNFTsResponse = try await context.callNftItemsByAddress(sut)
        }
    }

    @Test("nftItemsByOwner resolves from JS with the wallet's response")
    func nftItemsByOwnerResolvesFromJS() async throws {
        let (sut, client) = makeSUT()
        client.stubbedNFTsResponse = TONNFTsResponse(nfts: [])
        let address = client.stubbedNetwork.chainId
        _ = address
        context.evaluateScript(
            "function callNftItemsByOwner(c) { return c.nftItemsByOwner({ ownerAddress: 'EQCrq6urq6urq6urq6urq6urq6urq6urq6urq6urq6urq8Uk' }); }"
        )

        let result: TONNFTsResponse = try await context.callNftItemsByOwner(sut)

        #expect(result.nfts.isEmpty)
    }

    @Test("nftItemsByOwner rejects when wallet throws")
    func nftItemsByOwnerRejectsWhenWalletThrows() async {
        let (sut, client) = makeSUT()
        client.shouldThrow = true
        context.evaluateScript(
            "function callNftItemsByOwner(c) { return c.nftItemsByOwner({ ownerAddress: 'EQCrq6urq6urq6urq6urq6urq6urq6urq6urq6urq6urq8Uk' }); }"
        )

        await #expect(throws: (any Error).self) {
            let _: TONNFTsResponse = try await context.callNftItemsByOwner(sut)
        }
    }

    // MARK: - Emulation

    @Test("fetchEmulation resolves from JS with the wallet's response")
    func fetchEmulationResolvesFromJS() async throws {
        let (sut, client) = makeSUT()
        client.stubbedEmulationResult = .error(emulationError: TONEmulationError(code: 7, message: "boom"))
        context.evaluateScript("function callFetchEmulation(c) { return c.fetchEmulation('dGVzdA==', true); }")

        let result: TONEmulationResult = try await context.callFetchEmulation(sut)

        if case .error(let e) = result {
            #expect(e.code == 7)
        } else {
            Issue.record("Expected .error")
        }
    }

    @Test("fetchEmulation rejects when wallet throws")
    func fetchEmulationRejectsWhenWalletThrows() async {
        let (sut, client) = makeSUT()
        client.shouldThrow = true
        context.evaluateScript("function callFetchEmulation(c) { return c.fetchEmulation('dGVzdA==', true); }")

        await #expect(throws: (any Error).self) {
            let _: TONEmulationResult = try await context.callFetchEmulation(sut)
        }
    }

    // MARK: - Account state / balance

    @Test("getAccountState resolves from JS with the wallet's response")
    func getAccountStateResolvesFromJS() async throws {
        let (sut, client) = makeSUT()
        let address = try TONUserFriendlyAddress(value: "EQCrq6urq6urq6urq6urq6urq6urq6urq6urq6urq6urq8Uk")
        client.stubbedAccountState = TONAccountState(
            address: address,
            status: .active,
            rawBalance: TONTokenAmount(nanoUnits: 100),
            balance: "0.0000001",
            extraCurrencies: [:]
        )
        context.evaluateScript(
            "function callGetAccountState(c) { return c.getAccountState('EQCrq6urq6urq6urq6urq6urq6urq6urq6urq6urq6urq8Uk', null); }"
        )

        let result: TONAccountState = try await context.callGetAccountState(sut)

        #expect(result.rawBalance.nanoUnits == 100)
        #expect(result.status == .active)
    }

    @Test("getAccountState rejects when wallet throws")
    func getAccountStateRejectsWhenWalletThrows() async {
        let (sut, client) = makeSUT()
        client.shouldThrow = true
        context.evaluateScript(
            "function callGetAccountState(c) { return c.getAccountState('EQCrq6urq6urq6urq6urq6urq6urq6urq6urq6urq6urq8Uk', null); }"
        )

        await #expect(throws: (any Error).self) {
            let _: TONAccountState = try await context.callGetAccountState(sut)
        }
    }

    @Test("getBalance resolves from JS with the wallet's response")
    func getBalanceResolvesFromJS() async throws {
        let (sut, client) = makeSUT()
        client.stubbedBalance = TONTokenAmount(nanoUnits: 42)
        context.evaluateScript(
            "function callGetBalance(c) { return c.getBalance('EQCrq6urq6urq6urq6urq6urq6urq6urq6urq6urq6urq8Uk', null); }"
        )

        let result: TONTokenAmount = try await context.callGetBalance(sut)

        #expect(result.nanoUnits == 42)
    }

    @Test("getBalance rejects when wallet throws")
    func getBalanceRejectsWhenWalletThrows() async {
        let (sut, client) = makeSUT()
        client.shouldThrow = true
        context.evaluateScript(
            "function callGetBalance(c) { return c.getBalance('EQCrq6urq6urq6urq6urq6urq6urq6urq6urq6urq6urq8Uk', null); }"
        )

        await #expect(throws: (any Error).self) {
            let _: TONTokenAmount = try await context.callGetBalance(sut)
        }
    }

    @Test("getAccountStates resolves from JS with a map of address-keyed states")
    func getAccountStatesResolvesFromJS() async throws {
        let (sut, client) = makeSUT()
        let addressA = try TONUserFriendlyAddress(value: "EQCrq6urq6urq6urq6urq6urq6urq6urq6urq6urq6urq8Uk")
        let addressB = try TONUserFriendlyAddress(value: "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c")
        client.stubbedAccountStates = [
            addressA: TONAccountState(
                address: addressA,
                status: .active,
                rawBalance: TONTokenAmount(nanoUnits: 100),
                balance: "0.0000001",
                extraCurrencies: [:]
            ),
            addressB: TONAccountState(
                address: addressB,
                status: .nonExisting,
                rawBalance: TONTokenAmount(nanoUnits: 0),
                balance: "0",
                extraCurrencies: [:]
            ),
        ]
        context.evaluateScript(
            """
            function callGetAccountStates(c) {
                return c.getAccountStates([
                    'EQCrq6urq6urq6urq6urq6urq6urq6urq6urq6urq6urq8Uk',
                    'EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c'
                ]);
            }
            """
        )

        let result: [String: TONAccountState] = try await context.callGetAccountStates(sut)

        #expect(result.count == 2)
        #expect(result[addressA.value]?.rawBalance.nanoUnits == 100)
        #expect(result[addressA.value]?.status == .active)
        #expect(result[addressB.value]?.status == .nonExisting)
        #expect(client.lastAccountStatesAddresses == [addressA, addressB])
    }

    @Test("getAccountStates forwards Swift's typed map back through a JS round-trip")
    func getAccountStatesRoundTripThroughJS() async throws {
        let (sut, client) = makeSUT()
        let addressA = try TONUserFriendlyAddress(value: "EQCrq6urq6urq6urq6urq6urq6urq6urq6urq6urq6urq8Uk")
        client.stubbedAccountStates = [
            addressA: TONAccountState(
                address: addressA,
                status: .active,
                rawBalance: TONTokenAmount(nanoUnits: 999_000_000_000),
                balance: "999",
                extraCurrencies: ["100": "42"]
            )
        ]

        // Real JS code that consumes the dictionary and reshapes it like a
        // walletkit consumer would: pull out the entry, read selected fields,
        // and return them as a JSON-serializable shape we can decode back.
        context.evaluateScript(
            """
            async function callGetAccountStatesRoundTrip(c, address) {
                const states = await c.getAccountStates([address]);
                const entry = states[address];
                if (!entry) {
                    throw new Error('missing entry for ' + address);
                }
                return {
                    address: entry.address,
                    status: entry.status,
                    rawBalance: entry.rawBalance,
                    balance: entry.balance,
                    extraCurrencies: entry.extraCurrencies,
                };
            }
            """
        )

        struct RoundTrip: Decodable, JSValueDecodable {
            let address: String
            let status: String
            let rawBalance: String
            let balance: String
            let extraCurrencies: [String: String]
        }

        let result: RoundTrip = try await context.callGetAccountStatesRoundTrip(sut, addressA.value)

        #expect(result.address == addressA.value)
        #expect(result.status == "active")
        #expect(result.rawBalance == "999000000000")
        #expect(result.balance == "999")
        #expect(result.extraCurrencies == ["100": "42"])
    }

    @Test("getAccountStates rejects when wallet throws")
    func getAccountStatesRejectsWhenWalletThrows() async {
        let (sut, client) = makeSUT()
        client.shouldThrow = true
        context.evaluateScript(
            "function callGetAccountStates(c) { return c.getAccountStates(['EQCrq6urq6urq6urq6urq6urq6urq6urq6urq6urq6urq8Uk']); }"
        )

        await #expect(throws: (any Error).self) {
            let _: [String: TONAccountState] = try await context.callGetAccountStates(sut)
        }
    }

    @Test("getAccountStates rejects when the JS argument is not a valid address array")
    func getAccountStatesRejectsOnInvalidArgument() async {
        let (sut, _) = makeSUT()
        context.evaluateScript(
            "function callGetAccountStatesBad(c) { return c.getAccountStates('not-an-array'); }"
        )

        await #expect(throws: (any Error).self) {
            let _: [String: TONAccountState] = try await context.callGetAccountStatesBad(sut)
        }
    }

    // MARK: - DNS

    @Test("resolveDnsWallet resolves from JS with the wallet's response")
    func resolveDnsWalletResolvesFromJS() async throws {
        let (sut, client) = makeSUT()
        client.stubbedResolvedDns = "wallet-address"
        context.evaluateScript("function callResolveDnsWallet(c) { return c.resolveDnsWallet('foo.ton'); }")

        let result: String = try await context.callResolveDnsWallet(sut)

        #expect(result == "wallet-address")
    }

    @Test("resolveDnsWallet rejects when wallet throws")
    func resolveDnsWalletRejectsWhenWalletThrows() async {
        let (sut, client) = makeSUT()
        client.shouldThrow = true
        context.evaluateScript("function callResolveDnsWallet(c) { return c.resolveDnsWallet('foo.ton'); }")

        await #expect(throws: (any Error).self) {
            let _: String = try await context.callResolveDnsWallet(sut)
        }
    }

    @Test("backResolveDnsWallet resolves from JS with the wallet's response")
    func backResolveDnsWalletResolvesFromJS() async throws {
        let (sut, client) = makeSUT()
        client.stubbedResolvedDns = "foo.ton"
        context.evaluateScript(
            "function callBackResolveDnsWallet(c) { return c.backResolveDnsWallet('EQCrq6urq6urq6urq6urq6urq6urq6urq6urq6urq6urq8Uk'); }"
        )

        let result: String = try await context.callBackResolveDnsWallet(sut)

        #expect(result == "foo.ton")
    }

    @Test("backResolveDnsWallet rejects when wallet throws")
    func backResolveDnsWalletRejectsWhenWalletThrows() async {
        let (sut, client) = makeSUT()
        client.shouldThrow = true
        context.evaluateScript(
            "function callBackResolveDnsWallet(c) { return c.backResolveDnsWallet('EQCrq6urq6urq6urq6urq6urq6urq6urq6urq6urq6urq8Uk'); }"
        )

        await #expect(throws: (any Error).self) {
            let _: String = try await context.callBackResolveDnsWallet(sut)
        }
    }

}
