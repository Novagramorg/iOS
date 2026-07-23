//
//  MockSigner.swift
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

class MockSigner: TONWalletSignerProtocol {
    let mockPublicKey: TONHex
    var signedData: Data?
    var shouldThrow = false

    init(publicKey: TONHex = TONHex(data: Data([0xde, 0xad, 0xbe, 0xef]))) {
        self.mockPublicKey = publicKey
    }

    func sign(data: Data) async throws -> TONHex {
        if shouldThrow { throw "Mock sign error" }
        signedData = data
        return TONHex(data: Data([0xab, 0xcd]))
    }

    func publicKey() -> TONHex {
        mockPublicKey
    }
}
