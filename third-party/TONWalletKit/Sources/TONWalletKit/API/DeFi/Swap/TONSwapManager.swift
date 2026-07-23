//
//  TONSwapManager.swift
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

public protocol TONSwapManagerProtocol {

    func register<Provider: TONSwapProviderProtocol>(provider: Provider) throws
    func remove<Provider: TONSwapProviderProtocol>(provider: Provider) throws
    func set<Identifier: TONSwapProviderIdentifier>(defaultProviderId: Identifier) throws

    func provider<Identifier: TONSwapProviderIdentifier>(
        with id: Identifier
    ) throws -> TONSwapProvider<Identifier>?

    func providers() throws -> [TONSwapProvider<AnyTONSwapProviderIdentifier>]

    func hasProvider<Identifier: TONSwapProviderIdentifier>(
        with id: Identifier
    ) throws -> Bool

    func quote<Identifier: TONSwapProviderIdentifier>(
        params: TONSwapQuoteParams<Identifier.QuoteOptions>,
        identifier: Identifier
    ) async throws -> TONSwapQuote

    func quote(
        params: TONSwapQuoteParams<AnyCodable>
    ) async throws -> TONSwapQuote

    func swapTransaction<QuoteOptions: Codable>(
        params: TONSwapParams<QuoteOptions>
    ) async throws -> TONTransactionRequest
}

class TONSwapManager: TONSwapManagerProtocol {
    let jsObject: any JSDynamicObject
    
    required init(jsObject: any JSDynamicObject) {
        self.jsObject = jsObject
    }
    
    func register<Provider: TONSwapProviderProtocol>(provider: Provider) throws {
        try jsObject.registerProvider(TONEncodableSwapProvider(swapProvider: provider))
    }

    func remove<Provider: TONSwapProviderProtocol>(provider: Provider) throws {
        try jsObject.removeProvider(TONEncodableSwapProvider(swapProvider: provider))
    }

    func set<Identifier: TONSwapProviderIdentifier>(defaultProviderId: Identifier) throws {
        try jsObject.setDefaultProvider(defaultProviderId.name)
    }

    func provider<Identifier: TONSwapProviderIdentifier>(
        with id: Identifier
    ) throws -> TONSwapProvider<Identifier>? {
        let jsObject: JSValue = try self.jsObject.getProvider(id.name)
        return TONSwapProvider<Identifier>(jsObject: jsObject, identifier: id)
    }

    func providers() throws -> [TONSwapProvider<AnyTONSwapProviderIdentifier>] {
        let value: JSValue = try jsObject.getProviders()
        return try value.toObjectsArray().compactMap {
            try TONSwapProvider<AnyTONSwapProviderIdentifier>.from($0)
        }
    }

    func hasProvider<Identifier: TONSwapProviderIdentifier>(
        with id: Identifier
    ) throws -> Bool {
        try jsObject.hasProvider(id.name)
    }
    
    func quote<Identifier: TONSwapProviderIdentifier>(
        params: TONSwapQuoteParams<Identifier.QuoteOptions>,
        identifier: Identifier
    ) async throws -> TONSwapQuote {
        try await jsObject.getQuote(params, identifier.name)
    }
    
    func quote(
        params: TONSwapQuoteParams<AnyCodable>
    ) async throws -> TONSwapQuote {
        try await jsObject.getQuote(params)
    }
    
    func swapTransaction<QuoteOptions: Codable>(params: TONSwapParams<QuoteOptions>) async throws -> TONTransactionRequest {
        try await jsObject.buildSwapTransaction(params)
    }
}

extension TONSwapManager: JSValueDecodable {
    
    static func from(_ value: JSValue) throws -> Self? {
        Self(jsObject: value)
    }
}
