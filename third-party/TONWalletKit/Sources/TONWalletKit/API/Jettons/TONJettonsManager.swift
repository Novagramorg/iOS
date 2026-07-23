//
//  TONJettonsManager.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 16.06.2026.
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
import JavaScriptCore

public protocol TONJettonsManagerProtocol {

    /// Resolve jetton-master metadata by address. Returns `nil` when the master is unknown.
    func jettonInfo(
        address: TONUserFriendlyAddress,
        network: TONNetwork
    ) async throws -> TONJettonInfo?

    /// All jettons held by a user address, paginated.
    func addressJettons(
        userAddress: TONUserFriendlyAddress,
        network: TONNetwork,
        offset: Int,
        limit: Int
    ) async throws -> [TONJetton]

    /// Validate that a string is a well-formed jetton address.
    func validateJettonAddress(_ address: String) throws -> Bool
}

public extension TONJettonsManagerProtocol {

    func addressJettons(
        userAddress: TONUserFriendlyAddress,
        network: TONNetwork
    ) async throws -> [TONJetton] {
        try await addressJettons(userAddress: userAddress, network: network, offset: 0, limit: 20)
    }
}

class TONJettonsManager: TONJettonsManagerProtocol {

    let jsObject: any JSDynamicObject

    required init(jsObject: any JSDynamicObject) {
        self.jsObject = jsObject
    }

    func jettonInfo(
        address: TONUserFriendlyAddress,
        network: TONNetwork
    ) async throws -> TONJettonInfo? {
        try await jsObject.getJettonInfo(address.value, network)
    }

    func addressJettons(
        userAddress: TONUserFriendlyAddress,
        network: TONNetwork,
        offset: Int,
        limit: Int
    ) async throws -> [TONJetton] {
        try await jsObject.getAddressJettons(userAddress.value, network, offset, limit)
    }

    func validateJettonAddress(_ address: String) throws -> Bool {
        try jsObject.validateJettonAddress(address)
    }
}

extension TONJettonsManager: JSValueDecodable {

    static func from(_ value: JSValue) throws -> Self? {
        Self(jsObject: value)
    }
}
