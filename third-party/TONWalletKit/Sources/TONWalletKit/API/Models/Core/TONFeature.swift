//
//  TONFeature.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 26.02.2026.
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

import Foundation

enum TONFeatureName: String, Codable {
    case sendTransaction = "SendTransaction"
    case signData = "SignData"
    case signMessage = "SignMessage"
    case embeddedRequest = "EmbeddedRequest"
}

public struct TONRawFeature: Codable, Hashable {
    let name: TONFeatureName

    private(set) var types: [TONSignDataType]?

    private(set) var maxMessages: Int?
    private(set) var extraCurrencySupported: Bool?
    private(set) var itemTypes: [TONStructuredItemType]?

    var typed: (any TONFeature)? {
        switch name {
        case .sendTransaction:
            guard let maxMessages else {
                return nil
            }
            return TONSendTransactionFeature(maxMessages: maxMessages, extraCurrencySupported: extraCurrencySupported)
        case .signData:
            guard let types else {
                return nil
            }
            return TONSignDataFeature(types: types)
        case .signMessage:
            guard let maxMessages else {
                return nil
            }
            return TONSignMessageFeature(
                maxMessages: maxMessages,
                extraCurrencySupported: extraCurrencySupported,
                itemTypes: itemTypes
            )
        case .embeddedRequest:
            return TONEmbeddedRequestFeature()
        }
    }
}

public protocol TONFeature {
    var raw: TONRawFeature { get }
}

public struct TONSendTransactionFeature: TONFeature {
    let maxMessages: Int
    let extraCurrencySupported: Bool?
    let itemTypes: [TONStructuredItemType]?
    
    public var raw: TONRawFeature {
        TONRawFeature(
            name: .sendTransaction,
            maxMessages: maxMessages,
            extraCurrencySupported: extraCurrencySupported
        )
    }
    
    public init(
        maxMessages: Int,
        extraCurrencySupported: Bool? = nil,
        itemTypes: [TONStructuredItemType]? = nil
    ) {
        self.maxMessages = maxMessages
        self.extraCurrencySupported = extraCurrencySupported
        self.itemTypes = itemTypes
    }
}

public struct TONSignDataFeature: TONFeature {
    let types: [TONSignDataType]

    public var raw: TONRawFeature {
        TONRawFeature(
            name: .signData,
            types: types
        )
    }

    public init(types: [TONSignDataType]) {
        self.types = types
    }
}

public struct TONSignMessageFeature: TONFeature {
    let maxMessages: Int
    let extraCurrencySupported: Bool?
    let itemTypes: [TONStructuredItemType]?

    public var raw: TONRawFeature {
        TONRawFeature(
            name: .signMessage,
            maxMessages: maxMessages,
            extraCurrencySupported: extraCurrencySupported,
            itemTypes: itemTypes
        )
    }

    public init(
        maxMessages: Int,
        extraCurrencySupported: Bool? = nil,
        itemTypes: [TONStructuredItemType]? = nil
    ) {
        self.maxMessages = maxMessages
        self.extraCurrencySupported = extraCurrencySupported
        self.itemTypes = itemTypes
    }
}

public struct TONEmbeddedRequestFeature: TONFeature {
    public var raw: TONRawFeature {
        TONRawFeature(name: .embeddedRequest)
    }

    public init() {}
}
