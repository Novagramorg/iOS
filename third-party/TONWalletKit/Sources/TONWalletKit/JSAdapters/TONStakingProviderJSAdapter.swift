//
//  TONStakingProviderJSAdapter.swift
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
import JavaScriptCore

class TONStakingProviderJSAdapter<Provider: TONStakingProviderProtocol>: NSObject, JSStakingProvider {
    private weak var context: JSContext?
    private let stakingProvider: Provider

    var type: String { stakingProvider.type.rawValue }
    var providerId: String { stakingProvider.identifier.name }

    init(
        context: JSContext,
        stakingProvider: Provider
    ) {
        self.context = context
        self.stakingProvider = stakingProvider
    }

    @objc(getStakingProviderMetadata:) func metadata(network: JSValue) -> JSValue {
        guard let context else {
            return JSValue(undefinedIn: JSContext())
        }

        do {
            let network: TONNetwork? = try network.decode()
            let result = try stakingProvider.metadata(network: network)
            return JSValue(object: try result.encode(in: context), in: context)
        } catch {
            return JSValue(undefinedIn: context)
        }
    }

    @objc(getSupportedNetworks) func supportedNetworks() -> JSValue {
        guard let context else {
            return JSValue(undefinedIn: JSContext())
        }

        do {
            return JSValue(object: try stakingProvider.supportedNetworks().encode(in: context), in: context)
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
                    let params: TONStakingQuoteParams<Provider.QuoteOptions> = try params.decode()
                    let result = try await self.stakingProvider.quote(params: params)
                    let jsResult = try result.encode(in: context)

                    resolve?.call(withArguments: [jsResult])
                } catch {
                    reject?.call(withArguments: [error.localizedDescription])
                }
            }
        }
    }

    @objc(buildStakeTransaction:) func stakeTransaction(params: JSValue) -> JSValue {
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
                    let params: TONStakeParams<Provider.StakeOptions> = try params.decode()
                    let result = try await self.stakingProvider.stakeTransaction(params: params)
                    let jsResult = try result.encode(in: context)

                    resolve?.call(withArguments: [jsResult])
                } catch {
                    reject?.call(withArguments: [error.localizedDescription])
                }
            }
        }
    }

    @objc(getStakedBalance::) func stakedBalance(userAddress: JSValue, network: JSValue) -> JSValue {
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
                    let userAddress: TONUserFriendlyAddress = try userAddress.decode()
                    let network: TONNetwork? = try network.decode()
                    let result = try await self.stakingProvider.stakedBalance(userAddress: userAddress, network: network)
                    let jsResult = try result.encode(in: context)

                    resolve?.call(withArguments: [jsResult])
                } catch {
                    reject?.call(withArguments: [error.localizedDescription])
                }
            }
        }
    }

    @objc(getStakingProviderInfo:) func info(network: JSValue) -> JSValue {
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
                    let network: TONNetwork? = try network.decode()
                    let result = try await self.stakingProvider.info(network: network)
                    let jsResult = try result.encode(in: context)

                    resolve?.call(withArguments: [jsResult])
                } catch {
                    reject?.call(withArguments: [error.localizedDescription])
                }
            }
        }
    }

}

extension TONStakingProviderJSAdapter: JSValueEncodable {}
