//
//  TONStreamingProvider.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 31.03.2026.
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
import Combine

public protocol TONStreamingProviderProtocol: TONProvider {
    var network: TONNetwork { get throws }
    
    func balance(address: String) -> AnyPublisher<TONBalanceUpdate, any Error>
    
    func transactions(address: String) -> AnyPublisher<TONTransactionsUpdate, any Error>
    
    func jettons(address: String) -> AnyPublisher<TONJettonUpdate, any Error>
    
    func connect() throws
    func disconnect() throws
    
    func connectionChange() -> AnyPublisher<Bool, any Error>
}

public extension TONStreamingProviderProtocol {
    
    var type: TONProviderType { .streaming }
}

final class TONStreamingProvider: TONStreamingProviderProtocol {
    let jsObject: JSDynamicObject
    
    var network: TONNetwork {
        get throws {
            let network: TONNetwork? = jsObject.network
            
            guard let network else {
                throw TONWalletKitError.streamingNetworkUnavailable
            }
            return network
        }
    }
    
    var identifier: AnyTONProviderIdentifier
    
    init(jsObject: JSDynamicObject, identifier: AnyTONProviderIdentifier) {
        self.jsObject = jsObject
        self.identifier = identifier
    }
    
    func balance(address: String) -> AnyPublisher<TONBalanceUpdate, any Error> {
        TONStreamingPublisher { [jsObject] handler in
            let handler = jsObject.jsContext.closure(handler)
            let unwatch: JSValue = try jsObject.watchBalance(address, handler)
            return { unwatch.call(withArguments: []) }
        }.eraseToAnyPublisher()
    }
    
    func transactions(address: String) -> AnyPublisher<TONTransactionsUpdate, any Error> {
        TONStreamingPublisher { [jsObject] handler in
            let handler = jsObject.jsContext.closure(handler)
            let unwatch: JSValue = try jsObject.watchTransactions(address, handler)
            return { unwatch.call(withArguments: []) }
        }.eraseToAnyPublisher()
    }
    
    func jettons(address: String) -> AnyPublisher<TONJettonUpdate, any Error> {
        TONStreamingPublisher { [jsObject] handler in
            let handler = jsObject.jsContext.closure(handler)
            let unwatch: JSValue = try jsObject.watchJettons(address, handler)
            return { unwatch.call(withArguments: []) }
        }.eraseToAnyPublisher()
    }
    
    func connect() throws {
        try jsObject.connect()
    }
    
    func disconnect() throws {
        try jsObject.disconnect()
    }
    
    func connectionChange() -> AnyPublisher<Bool, any Error> {
        TONStreamingPublisher { [jsObject] handler in
            let handler = jsObject.jsContext.closure(handler)
            let unwatch: JSValue = try jsObject.onConnectionChange(handler)
            return { unwatch.call(withArguments: []) }
        }.eraseToAnyPublisher()
    }
}

extension TONStreamingProvider: JSValueDecodable {
    
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
