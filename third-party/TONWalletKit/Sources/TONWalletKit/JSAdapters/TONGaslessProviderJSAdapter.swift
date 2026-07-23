//
//  TONGaslessProviderJSAdapter.swift
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
import JavaScriptCore

class TONGaslessProviderJSAdapter<Provider: TONGaslessProviderProtocol>: NSObject, JSGaslessProvider {
    private weak var context: JSContext?
    private let gaslessProvider: Provider

    var type: String { gaslessProvider.type.rawValue }
    var providerId: String { gaslessProvider.identifier.name }

    init(
        context: JSContext,
        gaslessProvider: Provider
    ) {
        self.context = context
        self.gaslessProvider = gaslessProvider
    }

    @objc(getMetadata) func metadata() -> JSValue {
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
                    let result = try await self.gaslessProvider.metadata()
                    let jsResult = try result.encode(in: context)

                    resolve?.call(withArguments: [jsResult])
                } catch {
                    reject?.call(withArguments: [error.localizedDescription])
                }
            }
        }
    }

    @objc(getSupportedNetworks) func supportedNetworks() -> JSValue {
        guard let context else {
            return JSValue(undefinedIn: JSContext())
        }

        do {
            return JSValue(object: try gaslessProvider.supportedNetworks().encode(in: context), in: context)
        } catch {
            return JSValue(undefinedIn: context)
        }
    }

    @objc(getConfig:) func config(network: JSValue) -> JSValue {
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
                    let network: TONNetwork = try network.decode()
                    let result = try await self.gaslessProvider.config(network: network)
                    let jsResult = try result.encode(in: context)

                    resolve?.call(withArguments: [jsResult])
                } catch {
                    reject?.call(withArguments: [error.localizedDescription])
                }
            }
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
                    let params: TONGaslessQuoteParams = try params.decode()
                    let result = try await self.gaslessProvider.quote(params: params)
                    let jsResult = try result.encode(in: context)

                    resolve?.call(withArguments: [jsResult])
                } catch {
                    reject?.call(withArguments: [error.localizedDescription])
                }
            }
        }
    }

    @objc(sendTransaction:) func sendTransaction(params: JSValue) -> JSValue {
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
                    let params: TONGaslessSendParams = try params.decode()
                    let result = try await self.gaslessProvider.sendTransaction(params: params)
                    let jsResult = try result.encode(in: context)

                    resolve?.call(withArguments: [jsResult])
                } catch {
                    reject?.call(withArguments: [error.localizedDescription])
                }
            }
        }
    }
}

extension TONGaslessProviderJSAdapter: JSValueEncodable {}
