//
//  TONSwapProviderJSAdapter.swift
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
import JavaScriptCore

class TONSwapProviderJSAdapter<Provider: TONSwapProviderProtocol>: NSObject, JSSwapProvider {
    private weak var context: JSContext?
    private let swapProvider: Provider
    
    var type: String { swapProvider.type.rawValue }
    var providerId: String { swapProvider.identifier.name }
    
    init(
        context: JSContext,
        swapProvider: Provider
    ) {
        self.context = context
        self.swapProvider = swapProvider
    }
    
    @objc(getMetadata) func metadata() -> JSValue {
        guard let context else {
            return JSValue(undefinedIn: JSContext())
        }

        do {
            return JSValue(object: try swapProvider.metadata().encode(in: context), in: context)
        } catch {
            return JSValue(undefinedIn: context)
        }
    }

    @objc(getSupportedNetworks) func supportedNetworks() -> JSValue {
        guard let context else {
            return JSValue(undefinedIn: JSContext())
        }

        do {
            return JSValue(object: try swapProvider.supportedNetworks().encode(in: context), in: context)
        } catch {
            return JSValue(undefinedIn: context)
        }
    }

    @objc(getQuote:) func quote(params: JSValue) -> JSValue {
        guard let context else {
            return JSValue(
                newPromiseRejectedWithReason: "No context exists to perform \(#function)",
                in: JSContext()
            )
        }
        
        return JSValue(newPromiseIn: context) { [weak self] resolve, reject in
            Task {
                guard let self else { return }
                
                do {
                    let params: TONSwapQuoteParams<Provider.QuoteOptions> = try params.decode()
                    let result = try await self.swapProvider.quote(params: params)
                    let jsResult = try result.encode(in: context)
                    
                    resolve?.call(withArguments: [jsResult])
                } catch {
                    reject?.call(withArguments: [error.localizedDescription])
                }
            }
        }
    }
    
    @objc(buildSwapTransaction:) func swapTransaction(params: JSValue) -> JSValue {
        guard let context else {
            return JSValue(
                newPromiseRejectedWithReason: "No context exists to perform \(#function)",
                in: JSContext()
            )
        }
        
        return JSValue(newPromiseIn: context) { [weak self] resolve, reject in
            Task {
                guard let self else { return }
                
                do {
                    let params: TONSwapParams<Provider.SwapOptions> = try params.decode()
                    let result = try await self.swapProvider.swapTransaction(params: params)
                    let jsResult = try result.encode(in: context)
                    
                    resolve?.call(withArguments: [jsResult])
                } catch {
                    reject?.call(withArguments: [error.localizedDescription])
                }
            }
        }
    }
    
}

extension TONSwapProviderJSAdapter: JSValueEncodable {}
