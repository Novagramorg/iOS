//
//  TONSwapProvider.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 16.03.2026.
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

public protocol TONSwapProviderProtocol: TONProvider {
    associatedtype QuoteOptions: Codable
    associatedtype SwapOptions: Codable

    func metadata() throws -> TONSwapProviderMetadata
    func supportedNetworks() throws -> [TONNetwork]
    func quote(params: TONSwapQuoteParams<QuoteOptions>) async throws -> TONSwapQuote
    func swapTransaction(params: TONSwapParams<SwapOptions>) async throws -> TONTransactionRequest
}

public extension TONSwapProviderProtocol {
    
    var type: TONProviderType { .swap }
}

public final class TONSwapProvider<Identifier: TONSwapProviderIdentifier>: TONSwapProviderProtocol {
    public typealias QuoteOptions = Identifier.QuoteOptions
    public typealias SwapOptions = Identifier.SwapOptions
    public typealias Identifier = Identifier

    let jsObject: any JSDynamicObject
    public let identifier: Identifier

    init(jsObject: any JSDynamicObject, identifier: Identifier) {
        self.jsObject = jsObject
        self.identifier = identifier
    }

    public func metadata() throws -> TONSwapProviderMetadata {
        try jsObject.getMetadata()
    }

    public func supportedNetworks() throws -> [TONNetwork] {
        try jsObject.getSupportedNetworks()
    }

    public func quote(params: TONSwapQuoteParams<QuoteOptions>) async throws -> TONSwapQuote {
        try await jsObject.getQuote(params)
    }

    public func swapTransaction(params: TONSwapParams<SwapOptions>) async throws -> TONTransactionRequest {
        try await jsObject.buildSwapTransaction(params)
    }
}

extension TONSwapProvider: JSValueDecodable {
    
    static func from(_ value: JSValue) throws -> Self? {
        let identifier: String? = value.providerId
        
        guard let identifier else {
            return nil
        }
        
        return Self(
            jsObject: value,
            identifier: Identifier(name: identifier)
        )
    }
}
