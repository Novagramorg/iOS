//
//  MockWalletAdapter.swift
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

class MockWalletAdapter: TONWalletAdapterProtocol {
    var mockPublicKey = TONHex(data: Data([0xab, 0xcd]))
    var mockIdentifier: TONWalletID = "wallet-123"
    var mockNetwork = TONNetwork.mainnet
    var mockAddress: TONUserFriendlyAddress
    var mockSupportedFeatures: [any TONFeature]? = nil
    var shouldThrow = false

    init() {
        // Construct a valid address: bounceable, workchain 0, zero hash
        var addressData = Data(count: 34)
        addressData[0] = 0x11
        addressData[1] = 0x00
        let crc = addressData.crc16()
        let addressString = (addressData + crc).base64URLEncodedString()
        self.mockAddress = try! TONUserFriendlyAddress(value: addressString)
    }

    func identifier() throws -> TONWalletID {
        if shouldThrow { throw "Mock error" }
        return mockIdentifier
    }

    func publicKey() throws -> TONHex {
        if shouldThrow { throw "Mock error" }
        return mockPublicKey
    }

    func network() throws -> TONNetwork {
        if shouldThrow { throw "Mock error" }
        return mockNetwork
    }

    func address(testnet: Bool) throws -> TONUserFriendlyAddress {
        if shouldThrow { throw "Mock error" }
        return mockAddress
    }

    func stateInit() async throws -> TONBase64 {
        if shouldThrow { throw "Mock error" }
        return TONBase64(string: "stateInit")
    }

    func signedSendTransaction(input: TONTransactionRequest, options: TONSignedSendTransactionOptions?) async throws -> TONBase64 {
        if shouldThrow { throw "Mock error" }
        return TONBase64(string: "signed")
    }

    func signedSignMessage(input: TONTransactionRequest, options: TONSignedSendTransactionOptions?) async throws -> TONBase64 {
        if shouldThrow { throw "Mock error" }
        return TONBase64(string: "signedMessage")
    }

    func signedSignData(input: TONPreparedSignData, fakeSignature: Bool?) async throws -> TONHex {
        if shouldThrow { throw "Mock error" }
        return TONHex(data: Data([0xab, 0xcd]))
    }

    func signedTonProof(input: TONProofMessage, fakeSignature: Bool?) async throws -> TONHex {
        if shouldThrow { throw "Mock error" }
        return TONHex(data: Data([0xef, 0x01]))
    }

    func supportedFeatures() -> [any TONFeature]? {
        return mockSupportedFeatures
    }
}
