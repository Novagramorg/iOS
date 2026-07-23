//
//  TONGaslessManager.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 15.06.2026.
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

public protocol TONGaslessManagerProtocol {

    func register<Provider: TONGaslessProviderProtocol>(provider: Provider) throws
    func remove<Provider: TONGaslessProviderProtocol>(provider: Provider) throws
    func set<Identifier: TONGaslessProviderIdentifier>(defaultProviderId: Identifier) throws

    func provider<Identifier: TONGaslessProviderIdentifier>(
        with id: Identifier
    ) throws -> TONGaslessProvider<Identifier>?

    func providers() throws -> [TONGaslessProvider<AnyTONGaslessProviderIdentifier>]

    func hasProvider<Identifier: TONGaslessProviderIdentifier>(
        with id: Identifier
    ) throws -> Bool

    func metadata(
        identifier: (any TONGaslessProviderIdentifier)?
    ) async throws -> TONGaslessProviderMetadata

    func config(
        network: TONNetwork?,
        identifier: (any TONGaslessProviderIdentifier)?
    ) async throws -> TONGaslessConfig

    func quote(
        params: TONGaslessQuoteParams,
        identifier: (any TONGaslessProviderIdentifier)?
    ) async throws -> TONGaslessQuote

    func sendTransaction(
        params: TONGaslessSendParams,
        identifier: (any TONGaslessProviderIdentifier)?
    ) async throws -> TONGaslessSendResponse
}

public extension TONGaslessManagerProtocol {

    func metadata() async throws -> TONGaslessProviderMetadata {
        try await metadata(identifier: nil)
    }

    func config(network: TONNetwork? = nil) async throws -> TONGaslessConfig {
        try await config(network: network, identifier: nil)
    }

    func quote(params: TONGaslessQuoteParams) async throws -> TONGaslessQuote {
        try await quote(params: params, identifier: nil)
    }

    func sendTransaction(params: TONGaslessSendParams) async throws -> TONGaslessSendResponse {
        try await sendTransaction(params: params, identifier: nil)
    }
}

class TONGaslessManager: TONGaslessManagerProtocol {

    let jsObject: any JSDynamicObject

    required init(jsObject: any JSDynamicObject) {
        self.jsObject = jsObject
    }

    func register<Provider: TONGaslessProviderProtocol>(provider: Provider) throws {
        try jsObject.registerProvider(TONEncodableGaslessProvider(gaslessProvider: provider))
    }

    func remove<Provider: TONGaslessProviderProtocol>(provider: Provider) throws {
        try jsObject.removeProvider(TONEncodableGaslessProvider(gaslessProvider: provider))
    }

    func set<Identifier: TONGaslessProviderIdentifier>(defaultProviderId: Identifier) throws {
        try jsObject.setDefaultProvider(defaultProviderId.name)
    }

    func provider<Identifier: TONGaslessProviderIdentifier>(
        with id: Identifier
    ) throws -> TONGaslessProvider<Identifier>? {
        let jsObject: JSValue = try self.jsObject.getProvider(id.name)
        return TONGaslessProvider<Identifier>(jsObject: jsObject, identifier: id)
    }

    func providers() throws -> [TONGaslessProvider<AnyTONGaslessProviderIdentifier>] {
        let value: JSValue = try jsObject.getProviders()
        return try value.toObjectsArray().compactMap {
            try TONGaslessProvider<AnyTONGaslessProviderIdentifier>.from($0)
        }
    }

    func hasProvider<Identifier: TONGaslessProviderIdentifier>(
        with id: Identifier
    ) throws -> Bool {
        try jsObject.hasProvider(id.name)
    }

    func metadata(
        identifier: (any TONGaslessProviderIdentifier)?
    ) async throws -> TONGaslessProviderMetadata {
        try await jsObject.getMetadata(identifier?.name)
    }

    func config(
        network: TONNetwork?,
        identifier: (any TONGaslessProviderIdentifier)?
    ) async throws -> TONGaslessConfig {
        try await jsObject.getConfig(network, identifier?.name)
    }

    func quote(
        params: TONGaslessQuoteParams,
        identifier: (any TONGaslessProviderIdentifier)?
    ) async throws -> TONGaslessQuote {
        try await jsObject.getQuote(params, identifier?.name)
    }

    func sendTransaction(
        params: TONGaslessSendParams,
        identifier: (any TONGaslessProviderIdentifier)?
    ) async throws -> TONGaslessSendResponse {
        try await jsObject.sendTransaction(params, identifier?.name)
    }
}

extension TONGaslessManager: JSValueDecodable {

    static func from(_ value: JSValue) throws -> Self? {
        Self(jsObject: value)
    }
}
