//
//  TONWalletAdapter.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 11.11.2025.
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

class TONWalletAdapter: TONWalletAdapterProtocol {
    let jsWalletAdapter: any JSDynamicObject
    
    init(jsWalletAdapter: any JSDynamicObject) {
        self.jsWalletAdapter = jsWalletAdapter
    }
    
    func identifier() throws -> TONWalletID {
        try jsWalletAdapter.getWalletId()
    }
    
    func publicKey() throws -> TONHex {
        let publicKey: String = try jsWalletAdapter.getPublicKey()
        return try TONHex(hexString: publicKey)
    }
    
    func network() throws -> TONNetwork {
        return try jsWalletAdapter.getNetwork()
    }
    
    func address(testnet: Bool) throws -> TONUserFriendlyAddress {
        try jsWalletAdapter.getAddress(TONGetAddressOptions(testnet: testnet))
    }
    
    func stateInit() async throws -> TONBase64 {
        try TONBase64(base64Encoded: try await jsWalletAdapter.getStateInit())
    }
    
    func signedSendTransaction(input: TONTransactionRequest, options: TONSignedSendTransactionOptions?) async throws -> TONBase64 {
        try TONBase64(
            base64Encoded: try await jsWalletAdapter.getSignedSendTransaction(input, options)
        )
    }

    func signedSignMessage(input: TONTransactionRequest, options: TONSignedSendTransactionOptions?) async throws -> TONBase64 {
        try TONBase64(
            base64Encoded: try await jsWalletAdapter.getSignedSignMessage(input, options)
        )
    }

    func signedSignData(input: TONPreparedSignData, fakeSignature: Bool?) async throws -> TONHex {
        try TONHex(
            hexString: try await jsWalletAdapter.getSignedSignData(
                input,
                TONSignedSendTransactionAllOptions(fakeSignature: fakeSignature)
            )
        )
    }
    
    func signedTonProof(input: TONProofMessage, fakeSignature: Bool?) async throws -> TONHex {
        try TONHex(
            hexString: try await jsWalletAdapter.getSignedTonProof(
                input,
                TONSignedSendTransactionAllOptions(fakeSignature: fakeSignature)
            )
        )
    }
    
    func supportedFeatures() -> [any TONFeature]? {
        do {
            let features: [TONRawFeature] = try jsWalletAdapter.getSupportedFeatures()
            return features.compactMap { $0.typed }
        } catch {
            return nil
        }
    }
}

struct TONSignedSendTransactionAllOptions: Codable, JSValueDecodable, JSValueEncodable {
    let fakeSignature: Bool?
}

struct TONGetAddressOptions: Codable, JSValueDecodable, JSValueEncodable {
    let testnet: Bool?
}
