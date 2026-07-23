//
//  TONStreamingProviderJSAdapter.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 02.04.2026.
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
import JavaScriptCore

class TONStreamingProviderJSAdapter<Provider: TONStreamingProviderProtocol>: NSObject, JSStreamingProvider {
    private weak var context: JSContext?
    private let streamingProvider: Provider
    
    var type: String { streamingProvider.type.rawValue }
    var providerId: String { streamingProvider.identifier.name }
    
    var network: JSValue {
        guard let context else {
            return JSValue(undefinedIn: JSContext())
        }
        
        do {
            return JSValue(object: try streamingProvider.network.encode(in: context), in: context)
        } catch {
            return JSValue(undefinedIn: context)
        }
    }
    
    init(
        context: JSContext,
        streamingProvider: Provider
    ) {
        self.context = context
        self.streamingProvider = streamingProvider
    }
    
    private func wrap<T: JSValueEncodable>(
        handler: JSValue,
        with publisher: AnyPublisher<T, any Error>
    ) -> JSValue {
        guard let context else {
            return JSValue(undefinedIn: JSContext())
        }
        
        let watcher = publisher
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { update in
                    do {
                        let value = try update.encode(in: context)
                        handler.call(withArguments: [value])
                    } catch {
                        debugPrint("TON streaming provider operation failed")
                    }
                }
            )
        
        let unwatch: @convention(block) () -> Void = {
            watcher.cancel()
        }
        return JSValue(object: unwatch, in: context)
    }
    
    @objc(watchBalance::) func balance(address: JSValue, handler: JSValue) -> JSValue {
        do {
            let address: String = try address.decode()
            
            return wrap(
                handler: handler,
                with: streamingProvider.balance(address: address)
            )
        } catch {
            return JSValue(undefinedIn: JSContext())
        }
    }
    
    @objc(watchTransactions::) func transactions(address: JSValue, handler: JSValue) -> JSValue {
        do {
            let address: String = try address.decode()
            
            return wrap(
                handler: handler,
                with: streamingProvider.transactions(address: address)
            )
        } catch {
            return JSValue(undefinedIn: JSContext())
        }
    }
    
    @objc(watchJettons::) func jettons(address: JSValue, handler: JSValue) -> JSValue {
        do {
            let address: String = try address.decode()
            
            return wrap(
                handler: handler,
                with: streamingProvider.jettons(address: address)
            )
        } catch {
            return JSValue(undefinedIn: JSContext())
        }
    }
    
    @objc(connect) func connect() {
        try? streamingProvider.connect()
    }
    
    @objc(disconnect) func disconnect() {
        try? streamingProvider.disconnect()
    }
    
    @objc(onConnectionChange:) func connectionChange(handler: JSValue) -> JSValue {
        return wrap(
            handler: handler,
            with: streamingProvider.connectionChange()
        )
    }
}

extension TONStreamingProviderJSAdapter: JSValueEncodable {}
