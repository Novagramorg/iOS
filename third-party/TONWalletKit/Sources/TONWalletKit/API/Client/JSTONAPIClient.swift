//
//  JSTONAPIClient.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 18.05.2026.
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
import JavaScriptCore

final class JSTONAPIClient: TONAPIClient {
    private let jsClient: any JSDynamicObject

    init(jsClient: any JSDynamicObject) {
        self.jsClient = jsClient
    }

    func network() throws -> TONNetwork {
        try jsClient.getNetwork()
    }

    func send(boc: TONBase64) async throws -> String {
        try await jsClient.sendBoc(boc.value)
    }

    func runGetMethod(
        address: TONUserFriendlyAddress,
        method: String,
        stack: [TONRawStackItem]?,
        seqno: UInt?
    ) async throws -> TONGetMethodResult {
        try await jsClient.runGetMethod(address.value, method, stack, seqno)
    }

    func masterchainInfo() async throws -> TONMasterchainInfo {
        try await jsClient.getMasterchainInfo()
    }

    func nftItemsByAddress(request: TONNFTsRequest) async throws -> TONNFTsResponse {
        try await jsClient.nftItemsByAddress(request)
    }

    func nftItemsByOwner(request: TONUserNFTsRequest) async throws -> TONNFTsResponse {
        try await jsClient.nftItemsByOwner(request)
    }

    func nftTransfers(request: TONNFTTransfersRequest) async throws -> TONNFTTransfersResponse {
        try await jsClient.getNftTransfers(request)
    }

    func fetchEmulation(messageBoc: TONBase64, ignoreSignature: Bool?) async throws -> TONEmulationResult {
        try await jsClient.fetchEmulation(messageBoc.value, ignoreSignature)
    }

    func accountState(address: TONUserFriendlyAddress, seqno: UInt?) async throws -> TONAccountState {
        try await jsClient.getAccountState(address.value, seqno)
    }
    
    func accountStates(addresses: [TONUserFriendlyAddress]) async throws -> [TONUserFriendlyAddress: TONAccountState] {
        let raw: [String: TONAccountState] = try await jsClient.getAccountStates(addresses)
        var result: [TONUserFriendlyAddress: TONAccountState] = [:]
        for (key, value) in raw {
            let address = try TONUserFriendlyAddress(value: key)
            result[address] = value
        }
        return result
    }

    func accountTransactions(
        addresses: [TONUserFriendlyAddress],
        limit: Int?,
        offset: Int?
    ) async throws -> TONTransactionsResponse {
        try await jsClient.getAccountTransactions(
            TONAccountTransactionsRequest(
                address: addresses,
                limit: limit,
                offset: offset
            )
        )
    }

    func accountActions(
        address: TONUserFriendlyAddress,
        limit: Int?,
        offset: Int?
    ) async throws -> TONAccountActionsResponse {
        try await jsClient.getAccountActions(
            TONAccountActionsRequest(
                address: address,
                limit: limit,
                offset: offset
            )
        )
    }

    func balance(address: TONUserFriendlyAddress, seqno: UInt?) async throws -> TONTokenAmount {
        try await jsClient.getBalance(address.value, seqno)
    }

    func resolveDnsWallet(domain: String) async throws -> String? {
        try await jsClient.resolveDnsWallet(domain)
    }

    func backResolveDnsWallet(address: TONUserFriendlyAddress) async throws -> String? {
        try await jsClient.backResolveDnsWallet(address.value)
    }
}
