//
//  MockAPIClient.swift
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

@testable import TONWalletKit

class MockAPIClient: TONAPIClient {
    var sentBoc: TONBase64?
    var shouldThrow = false
    var stubbedNetwork: TONNetwork = .mainnet

    func network() -> TONNetwork {
        stubbedNetwork
    }

    func send(boc: TONBase64) async throws -> String {
        if shouldThrow { throw "Mock API error" }
        sentBoc = boc
        return "ok"
    }

    func runGetMethod(
        address: TONUserFriendlyAddress,
        method: String,
        stack: [TONRawStackItem]?,
        seqno: UInt?
    ) async throws -> TONGetMethodResult {
        throw "Not implemented in mock"
    }

    var stubbedMasterchainInfo: TONMasterchainInfo?

    func masterchainInfo() async throws -> TONMasterchainInfo {
        if shouldThrow { throw "Mock API error" }
        if let stubbedMasterchainInfo { return stubbedMasterchainInfo }
        return try TONMasterchainInfo(
            seqno: 12345,
            shard: "8000000000000000",
            workchain: -1,
            fileHash: TONHex(hexString: "aabb"),
            rootHash: TONHex(hexString: "ccdd")
        )
    }

    var stubbedNFTsResponse: TONNFTsResponse?
    var stubbedEmulationResult: TONEmulationResult?
    var stubbedAccountState: TONAccountState?
    var stubbedAccountStates: [TONUserFriendlyAddress: TONAccountState]?
    var stubbedBalance: TONTokenAmount = TONTokenAmount(nanoUnits: 0)
    var stubbedResolvedDns: String?

    var lastNFTsByAddressRequest: TONNFTsRequest?
    var lastNFTsByOwnerRequest: TONUserNFTsRequest?
    var lastEmulationBoc: TONBase64?
    var lastAccountStatesAddresses: [TONUserFriendlyAddress]?

    func nftItemsByAddress(request: TONNFTsRequest) async throws -> TONNFTsResponse {
        if shouldThrow { throw "Mock API error" }
        lastNFTsByAddressRequest = request
        if let stubbedNFTsResponse { return stubbedNFTsResponse }
        return TONNFTsResponse(nfts: [])
    }

    func nftItemsByOwner(request: TONUserNFTsRequest) async throws -> TONNFTsResponse {
        if shouldThrow { throw "Mock API error" }
        lastNFTsByOwnerRequest = request
        if let stubbedNFTsResponse { return stubbedNFTsResponse }
        return TONNFTsResponse(nfts: [])
    }

    func fetchEmulation(messageBoc: TONBase64, ignoreSignature: Bool?) async throws -> TONEmulationResult {
        if shouldThrow { throw "Mock API error" }
        lastEmulationBoc = messageBoc
        if let stubbedEmulationResult { return stubbedEmulationResult }
        throw "Mock has no stubbed emulation result"
    }

    func accountState(address: TONUserFriendlyAddress, seqno: UInt?) async throws -> TONAccountState {
        if shouldThrow { throw "Mock API error" }
        if let stubbedAccountState { return stubbedAccountState }
        return TONAccountState(
            address: address,
            status: .nonExisting,
            rawBalance: TONTokenAmount(nanoUnits: 0),
            balance: "0",
            extraCurrencies: [:]
        )
    }

    func accountStates(addresses: [TONUserFriendlyAddress]) async throws -> [TONUserFriendlyAddress: TONAccountState] {
        if shouldThrow { throw "Mock API error" }
        lastAccountStatesAddresses = addresses
        if let stubbedAccountStates { return stubbedAccountStates }
        return Dictionary(uniqueKeysWithValues: addresses.map { address in
            (address, TONAccountState(
                address: address,
                status: .nonExisting,
                rawBalance: TONTokenAmount(nanoUnits: 0),
                balance: "0",
                extraCurrencies: [:]
            ))
        })
    }

    func balance(address: TONUserFriendlyAddress, seqno: UInt?) async throws -> TONTokenAmount {
        if shouldThrow { throw "Mock API error" }
        return stubbedBalance
    }

    func resolveDnsWallet(domain: String) async throws -> String? {
        if shouldThrow { throw "Mock API error" }
        return stubbedResolvedDns
    }

    func backResolveDnsWallet(address: TONUserFriendlyAddress) async throws -> String? {
        if shouldThrow { throw "Mock API error" }
        return stubbedResolvedDns
    }
}

