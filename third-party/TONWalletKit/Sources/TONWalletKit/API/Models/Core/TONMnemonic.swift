//
//  TONMnemonic.swift
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

public struct TONMnemonic {
    public private(set) var value: [String]
    
    public var isFilled: Bool {
        TONMnemonicLength(rawValue: value.count) != nil
            && value.allSatisfy { !$0.isEmpty }
    }
    
    public init() {
        value = Array(repeating: "", count: TONMnemonicLength.max.rawValue)
    }
    
    public init(value: [String]) {
        self.value = value
    }
    
    public init(string: String) {
        self.init(
            value: string
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
        )
    }
    
    public mutating func update(word: String, at index: Int) {
        if value.indices ~= index {
            value[index] = word
        }
    }
}

public enum TONMnemonicLength: Int {
    case bits128 = 12
    case bits256 = 24
    
    public static var max: TONMnemonicLength { .bits256 }
}
