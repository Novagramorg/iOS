//
//  TONStakingManager.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 06.04.2026.
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

public protocol TONStakingManagerProtocol {

    func register<Provider: TONStakingProviderProtocol>(provider: Provider) throws
    func remove<Provider: TONStakingProviderProtocol>(provider: Provider) throws
    func set<Identifier: TONStakingProviderIdentifier>(defaultProviderId: Identifier) throws

    func provider<Identifier: TONStakingProviderIdentifier>(
        with id: Identifier
    ) throws -> TONStakingProvider<Identifier>?

    func providers() throws -> [TONStakingProvider<AnyTONStakingProviderIdentifier>]

    func hasProvider<Identifier: TONStakingProviderIdentifier>(
        with id: Identifier
    ) throws -> Bool

    func metadata(
        network: TONNetwork?,
        identifier: (any TONStakingProviderIdentifier)?
    ) throws -> TONStakingProviderMetadata

    func quote<Identifier: TONStakingProviderIdentifier>(
        params: TONStakingQuoteParams<Identifier.QuoteOptions>,
        identifier: Identifier
    ) async throws -> TONStakingQuote

    func quote(params: TONStakingQuoteParams<AnyCodable>) async throws -> TONStakingQuote

    func stakeTransaction<Identifier: TONStakingProviderIdentifier>(
        params: TONStakeParams<Identifier.StakeOptions>,
        identifier: Identifier
    ) async throws -> TONTransactionRequest

    func stakeTransaction(params: TONStakeParams<AnyCodable>) async throws -> TONTransactionRequest

    func stakedBalance(
        userAddress: TONUserFriendlyAddress,
        network: TONNetwork?,
        identifier: (any TONStakingProviderIdentifier)?
    ) async throws -> TONStakingBalance

    func info(
        network: TONNetwork?,
        identifier: (any TONStakingProviderIdentifier)?
    ) async throws -> TONStakingProviderInfo
}

public extension TONStakingManagerProtocol {

    func stakedBalance(
        userAddress: TONUserFriendlyAddress,
        network: TONNetwork?,
    ) async throws -> TONStakingBalance {
        try await stakedBalance(
            userAddress: userAddress,
            network: network,
            identifier: nil
        )
    }

    func info(
        network: TONNetwork?
    ) async throws -> TONStakingProviderInfo {
        try await info(
            network: network,
            identifier: nil
        )
    }

    func metadata(network: TONNetwork? = nil) throws -> TONStakingProviderMetadata {
        try metadata(network: network, identifier: nil)
    }

    func supportedUnstakeModes(
        network: TONNetwork? = nil,
        identifier: (any TONStakingProviderIdentifier)? = nil
    ) throws -> [TONUnstakeMode] {
        try metadata(network: network, identifier: identifier).supportedUnstakeModes
    }
}

class TONStakingManager: TONStakingManagerProtocol {

    let jsObject: any JSDynamicObject

    required init(jsObject: any JSDynamicObject) {
        self.jsObject = jsObject
    }

    func register<Provider: TONStakingProviderProtocol>(provider: Provider) throws {
        try jsObject.registerProvider(TONEncodableStakingProvider(stakingProvider: provider))
    }

    func remove<Provider: TONStakingProviderProtocol>(provider: Provider) throws {
        try jsObject.removeProvider(TONEncodableStakingProvider(stakingProvider: provider))
    }

    func set<Identifier: TONStakingProviderIdentifier>(defaultProviderId: Identifier) throws {
        try jsObject.setDefaultProvider(defaultProviderId.name)
    }

    func provider<Identifier: TONStakingProviderIdentifier>(
        with id: Identifier
    ) throws -> TONStakingProvider<Identifier>? {
        let jsObject: JSValue = try self.jsObject.getProvider(id.name)
        return TONStakingProvider<Identifier>(jsObject: jsObject, identifier: id)
    }

    func providers() throws -> [TONStakingProvider<AnyTONStakingProviderIdentifier>] {
        let value: JSValue = try jsObject.getProviders()
        return try value.toObjectsArray().compactMap {
            try TONStakingProvider<AnyTONStakingProviderIdentifier>.from($0)
        }
    }

    func hasProvider<Identifier: TONStakingProviderIdentifier>(
        with id: Identifier
    ) throws -> Bool {
        try jsObject.hasProvider(id.name)
    }

    func metadata(
        network: TONNetwork?,
        identifier: (any TONStakingProviderIdentifier)?
    ) throws -> TONStakingProviderMetadata {
        try jsObject.getStakingProviderMetadata(network, identifier?.name)
    }

    func quote<Identifier: TONStakingProviderIdentifier>(
        params: TONStakingQuoteParams<Identifier.QuoteOptions>,
        identifier: Identifier
    ) async throws -> TONStakingQuote {
        try await jsObject.getQuote(params, identifier.name)
    }
    
    func quote(params: TONStakingQuoteParams<AnyCodable>) async throws -> TONStakingQuote {
        try await jsObject.getQuote(params)
    }

    func stakeTransaction<Identifier: TONStakingProviderIdentifier>(
        params: TONStakeParams<Identifier.StakeOptions>,
        identifier: Identifier
    ) async throws -> TONTransactionRequest {
        try await jsObject.buildStakeTransaction(params, identifier.name)
    }
    
    func stakeTransaction(params: TONStakeParams<AnyCodable>) async throws -> TONTransactionRequest {
        try await jsObject.buildStakeTransaction(params)
    }
    
    func stakedBalance(
        userAddress: TONUserFriendlyAddress,
        network: TONNetwork?,
        identifier: (any TONStakingProviderIdentifier)?
    ) async throws -> TONStakingBalance {
        try await jsObject.getStakedBalance(userAddress, network, identifier?.name)
    }

    func info(
        network: TONNetwork?,
        identifier: (any TONStakingProviderIdentifier)?
    ) async throws -> TONStakingProviderInfo {
        try await jsObject.getStakingProviderInfo(network, identifier?.name)
    }

}

extension TONStakingManager: JSValueDecodable {

    static func from(_ value: JSValue) throws -> Self? {
        Self(jsObject: value)
    }
}
