//
//  TONUserFriendlyAddress.swift
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

private let bounceableTag: UInt8 = 0x11
private let nonBounceableTag: UInt8 = 0x51
private let testFlag: UInt8 = 0x80

public struct TONUserFriendlyAddress: Codable, Hashable {
    public let isTestnetOnly: Bool
    public let isBounceable: Bool
    
    public var workchain: Int8 { raw.workchain }
    public var hash: Data { raw.hash }
    
    public let value: String
    public let raw: TONRawAddress
    
    var nonURLSafeValue: String {
        value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
    }
    
    public init(value: String) throws {
        if value.count != 48 {
            throw TONUserFriendlyAddressValidationError.invalidCharactersNumber
        }
        
        guard let data = Data(base64URLEncoded: value) else {
            throw TONUserFriendlyAddressValidationError.invalidBase64URLEncoding
        }
        
        guard data.count == 36 else {
            throw TONUserFriendlyAddressValidationError.invalidByteLength
        }
        
        let address = data.subdata(in: 0..<34)
        let crc = data.subdata(in: 34..<36)
        
        let calculatedCRC = address.crc16()
        
        guard calculatedCRC.count == 2 else {
            throw TONUserFriendlyAddressValidationError.invalidCRC16Hashsum
        }
        
        guard crc[0] == calculatedCRC[0] && crc[1] == calculatedCRC[1] else {
            throw TONUserFriendlyAddressValidationError.invalidCRC16Hashsum
        }
        
        var tag = address[0]
        
        if tag & testFlag != 0 {
            isTestnetOnly = true
            
            tag = tag ^ testFlag
        } else {
            isTestnetOnly = false
        }
        
        guard tag == bounceableTag || tag == nonBounceableTag else {
            throw TONUserFriendlyAddressValidationError.invalidAddressTag
        }
        
        isBounceable = tag == 0x11

        raw = TONRawAddress(
            workchain: address[1] == 0xff ? -1 : Int8(address[1]),
            hash: address.subdata(in: 2..<34)
        )
        
        self.value = value
    }
    
    init(
        rawAddress: TONRawAddress,
        isBounceable: Bool,
        isTestnetOnly: Bool,
        urlSafe: Bool = true
    ) {
        self.isTestnetOnly = isTestnetOnly
        self.isBounceable = isBounceable
        self.raw = rawAddress
        
        var tag = isBounceable ? bounceableTag : nonBounceableTag
        
        if isTestnetOnly {
            tag |= testFlag
        }
        
        var address = Data(count: 34)
        address[0] = tag
        address[1] = rawAddress.workchain == -1 ? UInt8.max : UInt8(rawAddress.workchain)
        address[2...] = rawAddress.hash
        
        let addressCRC = address.crc16()
        
        var data = Data(count: 36)
        data[0...] = address
        data[34...] = addressCRC
                
        if urlSafe {
            value = data.base64URLEncodedString()
        } else {
            value = data.base64EncodedString()
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        try self.init(value: try container.decode(String.self))
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(raw.hash)
    }
    
    public static func == (lhs: TONUserFriendlyAddress, rhs: TONUserFriendlyAddress) -> Bool {
        return lhs.raw == rhs.raw
    }
}

public enum TONUserFriendlyAddressValidationError: Error {
    case invalidCharactersNumber
    case invalidBase64URLEncoding
    case invalidByteLength
    case invalidCRC16Hashsum
    case invalidAddressTag
}
