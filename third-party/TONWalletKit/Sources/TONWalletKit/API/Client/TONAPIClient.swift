//
//  TONAPIClient.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 20.01.2026.
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

import Foundation

public protocol TONAPIClient: AnyObject {
    func network() throws -> TONNetwork

    func send(boc: TONBase64) async throws -> String

    func runGetMethod(
        address: TONUserFriendlyAddress,
        method: String,
        stack: [TONRawStackItem]?,
        seqno: UInt?
    ) async throws -> TONGetMethodResult

    func masterchainInfo() async throws -> TONMasterchainInfo

    func nftItemsByAddress(request: TONNFTsRequest) async throws -> TONNFTsResponse
    func nftItemsByOwner(request: TONUserNFTsRequest) async throws -> TONNFTsResponse
    func nftTransfers(request: TONNFTTransfersRequest) async throws -> TONNFTTransfersResponse

    func fetchEmulation(
        messageBoc: TONBase64,
        ignoreSignature: Bool?
    ) async throws -> TONEmulationResult

    func accountState(
        address: TONUserFriendlyAddress,
        seqno: UInt?
    ) async throws -> TONAccountState
    
    func accountStates(addresses: [TONUserFriendlyAddress]) async throws -> [TONUserFriendlyAddress: TONAccountState]

    func accountTransactions(
        addresses: [TONUserFriendlyAddress],
        limit: Int?,
        offset: Int?
    ) async throws -> TONTransactionsResponse

    func balance(
        address: TONUserFriendlyAddress,
        seqno: UInt?
    ) async throws -> TONTokenAmount

    func resolveDnsWallet(domain: String) async throws -> String?
    func backResolveDnsWallet(address: TONUserFriendlyAddress) async throws -> String?
}

public extension TONAPIClient {
    func nftTransfers(request: TONNFTTransfersRequest) async throws -> TONNFTTransfersResponse {
        throw TONWalletKitError.unsupportedAPIClientOperation("nftTransfers")
    }

    func accountTransactions(
        addresses: [TONUserFriendlyAddress],
        limit: Int? = nil,
        offset: Int? = nil
    ) async throws -> TONTransactionsResponse {
        throw TONWalletKitError.unsupportedAPIClientOperation("accountTransactions")
    }
}

struct TONAccountTransactionsRequest: Codable {
    let address: [TONUserFriendlyAddress]
    let limit: Int?
    let offset: Int?
}

extension TONAccountTransactionsRequest: JSValueCodable {}
