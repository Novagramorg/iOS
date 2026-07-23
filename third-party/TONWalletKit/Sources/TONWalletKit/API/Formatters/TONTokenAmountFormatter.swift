//
//  TONBalanceFormatter.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 31.10.2025.
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
import _BigInt

open class TONTokenAmountFormatter: Formatter {
    // Defaults to 9, as TON uses nano units (1 TON = 10^9 nanoTON)
    open var nanoUnitDecimalsNumber: Int = 9
    open var allowFractionalTrailingZeroes = false
    
    open func string(from balance: TONTokenAmount) -> String? {
        if nanoUnitDecimalsNumber < 0 {
            return nil
        }
        
        var string = String(balance.nanoUnits)
        
        let negative = string.hasPrefix("-")
        
        if negative {
            string = String(string.dropFirst())
        }
        
        if string.count < nanoUnitDecimalsNumber {
            let paddingCount = nanoUnitDecimalsNumber - string.count
            string = String(repeating: "0", count: paddingCount) + string
        }
        
        let splitIndex = string.count - nanoUnitDecimalsNumber
        let integer = splitIndex > 0 ? String(string.prefix(splitIndex)) : ""
        var fraction = String(string.suffix(nanoUnitDecimalsNumber))
        
        if !allowFractionalTrailingZeroes {
            fraction = fraction.replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
        }
        
        let negativePrefix = negative ? "-" : ""
        let integerPart = integer.isEmpty ? "0" : integer
        let fractionPart = fraction.isEmpty ? "" : ".\(fraction)"
        
        return "\(negativePrefix)\(integerPart)\(fractionPart)"
    }
    
    open func amount(from string: String) -> TONTokenAmount? {
        let cleanInput = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanInput.isEmpty else { return nil }
        
        let parts = cleanInput.components(separatedBy: ".")
        guard parts.count <= 2 else { return nil }
        
        let integerPart = parts[0]
        let fractionalPart = parts.count == 2 ? parts[1] : ""
        
        guard let integerValue = BigInt(integerPart) else { return nil }
        
        let multiplier = BigInt(10).power(nanoUnitDecimalsNumber)
        var result = integerValue * multiplier
        
        if !fractionalPart.isEmpty {
            let normalizedFraction = fractionalPart.count > nanoUnitDecimalsNumber ?
                String(fractionalPart.prefix(nanoUnitDecimalsNumber)) :
                fractionalPart.padding(toLength: nanoUnitDecimalsNumber, withPad: "0", startingAt: 0)
            
            guard let fractionValue = BigInt(normalizedFraction) else { return nil }
            
            if integerValue.sign == .minus {
                result -= fractionValue
            } else {
                result += fractionValue
            }
        }
        
        return TONBalance(nanoUnits: result)
    }
}
