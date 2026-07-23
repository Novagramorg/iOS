//
//  TONV5R1Wallet.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 16.10.2025.
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
import JavaScriptCore
import _BigInt

class TONWallet: TONWalletAdapter, TONWalletProtocol {
    let id: TONWalletID
    let address: TONUserFriendlyAddress
    let client: any TONAPIClient

    let jsWallet: any JSDynamicObject

    required init(
        jsWallet: any JSDynamicObject,
        id: TONWalletID,
        address: TONUserFriendlyAddress,
        client: any TONAPIClient
    ) {
        self.jsWallet = jsWallet
        self.id = id
        self.address = address
        self.client = client

        super.init(jsWalletAdapter: jsWallet)
    }

    func balance() async throws -> TONBalance {
        try await jsWallet.getBalance()
    }

    func transferTONTransaction(request: TONTransferRequest) async throws -> TONTransactionRequest {
        try await jsWallet.createTransferTonTransaction(request)
    }

    public func transferTONTransaction(requests: [TONTransferRequest]) async throws -> TONTransactionRequest {
        try await jsWallet.createTransferMultiTonTransaction(requests)
    }

    func send(transactionRequest: TONTransactionRequest) async throws -> TONSendTransactionResponse {
        try await jsWallet.sendTransaction(transactionRequest)
    }

    func preview(
        transactionRequest: TONTransactionRequest,
        options: TONTransactionPreviewOptions?
    ) async throws -> TONTransactionEmulatedPreview {
        if let options {
            return try await jsWallet.getTransactionPreview(transactionRequest, options)
        } else {
            return try await jsWallet.getTransactionPreview(transactionRequest)
        }
    }
    
    func transferNFTTransaction(request: TONNFTTransferRequest) async throws -> TONTransactionRequest {
        try await jsWallet.createTransferNftTransaction(request)
    }
    
    func transferNFTTransaction(request: TONNFTRawTransferRequest) async throws -> TONTransactionRequest {
        try await jsWallet.createTransferNftRawTransaction(request)
    }
    
    func nfts(request: TONNFTsRequest) async throws -> TONNFTsResponse {
        try await jsWallet.getNfts(request)
    }
    
    func nft(address: TONUserFriendlyAddress) async throws -> TONNFT{
        try await jsWallet.getNft(address.value)
    }
    
    func jettonBalance(jettonAddress: TONUserFriendlyAddress) async throws -> TONBalance {
        try await jsWallet.getJettonBalance(jettonAddress.value)
    }
    
    func jettonWalletAddress(jettonAddress: TONUserFriendlyAddress) async throws -> TONUserFriendlyAddress {
        try await jsWallet.getJettonWalletAddress(jettonAddress.value)
    }
    
    func transferJettonTransaction(request: TONJettonsTransferRequest) async throws -> TONTransactionRequest {
        try await jsWallet.createTransferJettonTransaction(request)
    }

    func jettons(request: TONJettonsRequest) async throws -> TONJettonsResponse {
        try await jsWallet.getJettons(request)
    }
}

extension TONWallet: JSValueDecodable {

    static func from(_ value: JSValue) throws -> Self? {
        let id: TONWalletID = try value.getWalletId()
        let address: TONUserFriendlyAddress = try value.getAddress()
        let jsClient: JSValue = try value.getClient()

        return Self(
            jsWallet: value,
            id: id,
            address: address,
            client: JSTONAPIClient(jsClient: jsClient)
        )
    }
}
