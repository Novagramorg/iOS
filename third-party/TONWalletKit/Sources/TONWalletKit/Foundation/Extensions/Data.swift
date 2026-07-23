//
//  Data.swift
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

extension Data {
    
    var hex: String {
        return map { String(format: "%02x", $0) }.joined()
    }
    
    var hexWithPrefix: String {
        return "0x" + hex
    }
    
    init?(hex: String) {
        let hexString = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        
        guard hexString.count % 2 == 0 else { return nil }
        
        var data = Data(capacity: hexString.count / 2)
        
        var index = hexString.startIndex
        
        while index < hexString.endIndex {
            let nextIndex = hexString.index(index, offsetBy: 2)
            let byteString = hexString[index..<nextIndex]
            
            guard let byte = UInt8(byteString, radix: 16) else {
                return nil
            }
            
            data.append(byte)
            index = nextIndex
        }
        
        self = data
    }
    
    init?(base64URLEncoded: String) {
        self.init(base64Encoded: base64URLEncoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        )
    }
    
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
    }
}
