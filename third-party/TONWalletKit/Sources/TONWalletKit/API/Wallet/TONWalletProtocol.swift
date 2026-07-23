//
//  TONWallet.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 12.09.2025.
//
//  Copyright (c) 2025 TON Connect
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

public protocol TONWalletAdapterProtocol: AnyObject {

    func identifier() throws -> TONWalletID
    func publicKey() throws -> TONHex
    func network() throws -> TONNetwork
    func address(testnet: Bool) throws -> TONUserFriendlyAddress
    func stateInit() async throws -> TONBase64
    func signedSendTransaction(input: TONTransactionRequest, options: TONSignedSendTransactionOptions?) async throws -> TONBase64
    func signedSignMessage(input: TONTransactionRequest, options: TONSignedSendTransactionOptions?) async throws -> TONBase64
    func signedSignData(input: TONPreparedSignData, fakeSignature: Bool?) async throws -> TONHex
    func signedTonProof(input: TONProofMessage, fakeSignature: Bool?) async throws -> TONHex
    func supportedFeatures() -> [any TONFeature]?
}

public protocol TONWalletProtocol: TONWalletAdapterProtocol {
    var id: TONWalletID { get }
    var address: TONUserFriendlyAddress { get }
    var client: any TONAPIClient { get }

    func balance() async throws -> TONBalance

    func transferTONTransaction(request: TONTransferRequest) async throws -> TONTransactionRequest
    func transferTONTransaction(requests: [TONTransferRequest]) async throws -> TONTransactionRequest

    func send(transactionRequest: TONTransactionRequest) async throws -> TONSendTransactionResponse
    func preview(transactionRequest: TONTransactionRequest, options: TONTransactionPreviewOptions?) async throws -> TONTransactionEmulatedPreview

    func transferNFTTransaction(request: TONNFTTransferRequest) async throws -> TONTransactionRequest
    func transferNFTTransaction(request: TONNFTRawTransferRequest) async throws -> TONTransactionRequest

    func nfts(request: TONNFTsRequest) async throws -> TONNFTsResponse
    func nft(address: TONUserFriendlyAddress) async throws -> TONNFT

    func jettonBalance(jettonAddress: TONUserFriendlyAddress) async throws -> TONBalance
    func jettonWalletAddress(jettonAddress: TONUserFriendlyAddress) async throws -> TONUserFriendlyAddress

    func transferJettonTransaction(request: TONJettonsTransferRequest) async throws -> TONTransactionRequest
    func jettons(request: TONJettonsRequest) async throws -> TONJettonsResponse
}

public extension TONWalletProtocol {

    func preview(transactionRequest: TONTransactionRequest) async throws -> TONTransactionEmulatedPreview {
        try await preview(transactionRequest: transactionRequest, options: nil)
    }

    func nfts(limit: Int) async throws -> TONNFTsResponse {
        let request = TONNFTsRequest(pagination: TONPagination(limit: limit))
        return try await nfts(request: request)
    }

    func jettons(limit: Int) async throws -> TONJettonsResponse {
        let request = TONJettonsRequest(pagination: TONPagination(limit: limit))
        return try await jettons(request: request)
    }
}
