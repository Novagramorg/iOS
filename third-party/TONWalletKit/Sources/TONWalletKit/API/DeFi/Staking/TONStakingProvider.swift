//
//  TONStakingProvider.swift
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

public protocol TONStakingProviderProtocol: TONProvider {
    associatedtype QuoteOptions: Codable
    associatedtype StakeOptions: Codable

    func metadata(network: TONNetwork?) throws -> TONStakingProviderMetadata
    func supportedNetworks() throws -> [TONNetwork]
    func quote(params: TONStakingQuoteParams<QuoteOptions>) async throws -> TONStakingQuote
    func stakeTransaction(params: TONStakeParams<StakeOptions>) async throws -> TONTransactionRequest
    func stakedBalance(userAddress: TONUserFriendlyAddress, network: TONNetwork?) async throws -> TONStakingBalance
    func info(network: TONNetwork?) async throws -> TONStakingProviderInfo
}

public extension TONStakingProviderProtocol {

    var type: TONProviderType { .staking }

    func supportedUnstakeModes(network: TONNetwork? = nil) throws -> [TONUnstakeMode] {
        try metadata(network: network).supportedUnstakeModes
    }
}

public final class TONStakingProvider<Identifier: TONStakingProviderIdentifier>: TONStakingProviderProtocol {
    public typealias QuoteOptions = Identifier.QuoteOptions
    public typealias StakeOptions = Identifier.StakeOptions
    public typealias Identifier = Identifier

    let jsObject: any JSDynamicObject
    public let identifier: Identifier

    init(jsObject: any JSDynamicObject, identifier: Identifier) {
        self.jsObject = jsObject
        self.identifier = identifier
    }

    public func metadata(network: TONNetwork?) throws -> TONStakingProviderMetadata {
        try jsObject.getStakingProviderMetadata(network)
    }

    public func supportedNetworks() throws -> [TONNetwork] {
        try jsObject.getSupportedNetworks()
    }

    public func quote(params: TONStakingQuoteParams<QuoteOptions>) async throws -> TONStakingQuote {
        try await jsObject.getQuote(params)
    }

    public func stakeTransaction(params: TONStakeParams<StakeOptions>) async throws -> TONTransactionRequest {
        try await jsObject.buildStakeTransaction(params)
    }

    public func stakedBalance(userAddress: TONUserFriendlyAddress, network: TONNetwork?) async throws -> TONStakingBalance {
        try await jsObject.getStakedBalance(userAddress, network)
    }

    public func info(network: TONNetwork?) async throws -> TONStakingProviderInfo {
        try await jsObject.getStakingProviderInfo(network)
    }
}

extension TONStakingProvider: JSValueDecodable {

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
