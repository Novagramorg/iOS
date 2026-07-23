//
//  TONStreamingManager.swift
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

public protocol TONStreamingManagerProtocol {
    
    func hasProvider(network: TONNetwork) throws -> Bool;

    func register<T: TONStreamingProviderProtocol>(provider: T) throws
    
    func balance(
        network: TONNetwork,
        address: String
    ) -> AnyPublisher<TONBalanceUpdate, any Error>
    
    func transactions(
        network: TONNetwork,
        address: String
    ) -> AnyPublisher<TONTransactionsUpdate, any Error>
    
    func jettons(
        network: TONNetwork,
        address: String
    ) -> AnyPublisher<TONJettonUpdate, any Error>
    
    func updates(
        network: TONNetwork,
        address: String,
        types: [TONStreamingWatchType]
    ) -> AnyPublisher<TONStreamingUpdate, any Error>
    
    func connect() throws
    func disconnect() throws
    
    func connectionChange(network: TONNetwork) -> AnyPublisher<Bool, any Error>
}

class TONStreamingManager: TONStreamingManagerProtocol {
    private let jsObject: any JSDynamicObject
    
    required init(jsObject: any JSDynamicObject) {
        self.jsObject = jsObject
    }
    
    func hasProvider(network: TONNetwork) throws -> Bool {
        try jsObject.hasProvider(network)
    }
    
    func register<T: TONStreamingProviderProtocol>(provider: T) throws {
        try jsObject.registerProvider(TONEncodableStreamingProvider(streamingProvider: provider))
    }
    
    func balance(
        network: TONNetwork,
        address: String
    ) -> AnyPublisher<TONBalanceUpdate, any Error> {
        
        TONStreamingPublisher { [jsObject] handler in
            let handler = jsObject.jsContext.closure(handler)
            let unwatch: JSValue = try jsObject.watchBalance(network, address, handler)
            return { unwatch.call(withArguments: []) }
        }.eraseToAnyPublisher()
    }
    
    func transactions(
        network: TONNetwork,
        address: String
    ) -> AnyPublisher<TONTransactionsUpdate, any Error> {
        
        TONStreamingPublisher { [jsObject] handler in
            let handler = jsObject.jsContext.closure(handler)
            let unwatch: JSValue = try jsObject.watchTransactions(network, address, handler)
            return { unwatch.call(withArguments: []) }
        }.eraseToAnyPublisher()
    }
    
    func jettons(
        network: TONNetwork,
        address: String
    ) -> AnyPublisher<TONJettonUpdate, any Error> {
        
        TONStreamingPublisher { [jsObject] handler in
            let handler = jsObject.jsContext.closure(handler)
            let unwatch: JSValue = try jsObject.watchJettons(network, address, handler)
            return { unwatch.call(withArguments: []) }
        }.eraseToAnyPublisher()
    }
    
    func updates(
        network: TONNetwork,
        address: String,
        types: [TONStreamingWatchType]
    ) -> AnyPublisher<TONStreamingUpdate, any Error> {
        
        TONStreamingPublisher { [jsObject] handler in
            let block: @convention(block) (JSValue, JSValue) -> Void = { _, update in
                let decoded: TONStreamingUpdate? = try? update.decode()
                if let decoded { handler(decoded) }
            }
            let handler = JSValue(object: block, in: jsObject.jsContext)
            let unwatch: JSValue = try jsObject.watch(network, address, types, handler)
            return { unwatch.call(withArguments: []) }
        }.eraseToAnyPublisher()
    }

    func connect() throws {
        try jsObject.connect()
    }
    
    func disconnect() throws {
        try jsObject.disconnect()
    }
    
    func connectionChange(network: TONNetwork) -> AnyPublisher<Bool, any Error> {
        TONStreamingPublisher { [jsObject] handler in
            let handler = jsObject.jsContext.closure(handler)
            let unwatch: JSValue = try jsObject.onConnectionChange(network, handler)
            return { unwatch.call(withArguments: []) }
        }.eraseToAnyPublisher()
    }
}

extension TONStreamingManager: JSValueDecodable {
    
    static func from(_ value: JSValue) throws -> Self? {
        Self(jsObject: value)
    }
}
