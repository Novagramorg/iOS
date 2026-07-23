//
//  TONWalletSigner.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 12.11.2025.
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

class TONWalletSigner: TONWalletSignerProtocol {
    let jsWalletSigner: any JSDynamicObject
    
    init(jsWalletSigner: any JSDynamicObject) {
        self.jsWalletSigner = jsWalletSigner
    }
    
    func sign(data: Data) async throws -> TONHex {
        try TONHex(hexString: try await jsWalletSigner.sign([UInt8](data)))
    }
    
    func publicKey() -> TONHex {
        let result: String? = jsWalletSigner.publicKey
        return result.flatMap { try? TONHex(hexString: $0) } ?? TONHex(string: "")
    }
}
