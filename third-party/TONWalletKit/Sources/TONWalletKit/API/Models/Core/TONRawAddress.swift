//
//  TONRawAddress.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 18.11.2025.
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

public struct TONRawAddress: Codable, Hashable {
    public let workchain: Int8
    public let hash: Data

    public var string: String {
        "\(workchain):\(hash.hex)"
    }
    
    public init(workchain: Int8, hash: Data) {
        self.workchain = workchain
        self.hash = hash
    }
    
    public init(string: String) throws {
        let parts = string.split(separator: ":");
        
        guard parts.count == 2 else {
            throw TONRawAddressValidationError.invadidRawAddressFormat
        }
        
        guard let workchain = Int8(parts[0], radix: 10) else {
            throw TONRawAddressValidationError.invalidWorkchain
        }
        
        let hashString = String(parts[1])
        
        guard hashString.count == 64, let hash = Data(hex: hashString) else {
            throw TONRawAddressValidationError.invalidHash
        }
        
        self.workchain = workchain
        self.hash = hash
    }
    
    public func userFriendly(
        isBounceable: Bool,
        isTestnetOnly: Bool = false,
        urlSafe: Bool = true
    ) -> TONUserFriendlyAddress {
        TONUserFriendlyAddress(
            rawAddress: self,
            isBounceable: isBounceable,
            isTestnetOnly: isTestnetOnly,
            urlSafe: urlSafe
        )
    }
}
public enum TONRawAddressValidationError: Error {
    case invadidRawAddressFormat
    case invalidWorkchain
    case invalidHash
}
