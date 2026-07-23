//
//  TONWalletAdapterJSAdapter.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 17.10.2025.
//
//  Copyright (c) 2025 TON Connect
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

class TONWalletAdapterJSAdapter: NSObject, JSWalletAdapter {
    private weak var context: JSContext?
    private let walletAdapter: any TONWalletAdapterProtocol
    
    init(
        context: JSContext,
        walletAdapter: any TONWalletAdapterProtocol
    ) {
        self.context = context
        self.walletAdapter = walletAdapter
    }
    
    @objc(getPublicKey) func publicKey() -> JSValue {
        guard let context else {
            return JSValue(undefinedIn: JSContext())
        }
        
        do {
            return JSValue(object: try walletAdapter.publicKey().value, in: context)
        } catch {
            return JSValue(undefinedIn: context)
        }
    }
    
    @objc(getWalletId) func identifier() -> JSValue {
        guard let context else {
            return JSValue(undefinedIn: JSContext())
        }
        
        do {
            return JSValue(object: try walletAdapter.identifier(), in: context)
        } catch {
            return JSValue(undefinedIn: context)
        }
    }
    
    @objc(getNetwork) func network() -> JSValue {
        guard let context else {
            return JSValue(undefinedIn: JSContext())
        }
        
        do {
            return JSValue(object: try walletAdapter.network().encode(in: context), in: context)
        } catch {
            return JSValue(undefinedIn: context)
        }
    }
    
    @objc(getAddress:) func address(options: JSValue) -> JSValue {
        guard let context else {
            return JSValue(undefinedIn: JSContext())
        }
        
        let options: TONGetAddressOptions? = try? options.decode()
        
        do {
            let address = try walletAdapter.address(testnet: options?.testnet == true)
            return JSValue(object: address.value, in: context)
        } catch {
            return JSValue(undefinedIn: context)
        }
    }
    
    @objc(getStateInit) func stateInit() -> JSValue {
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
                    let value = try await self.walletAdapter.stateInit().value
                    
                    resolve?.call(withArguments: [value])
                } catch {
                    reject?.call(withArguments: [error.localizedDescription])
                }
            }
        }
    }
    
    @objc(getSignedSendTransaction::) func signedSendTransaction(input: JSValue, options: JSValue) -> JSValue {
        guard let context else {
            return JSValue(
                newPromiseRejectedWithReason: "No context exists to perform \(#function)",
                in: JSContext()
            )
        }

        do {
            let options: TONSignedSendTransactionOptions? = try options.decode()
            let input: TONTransactionRequest = try input.decode()

            return JSValue(newPromiseIn: context) { [weak self] resolve, reject in
                Task {
                    guard let self else { return }

                    do {
                        let value = try await self.walletAdapter.signedSendTransaction(
                            input: input,
                            options: options
                        ).value

                        resolve?.call(withArguments: [value])
                    } catch {
                        reject?.call(withArguments: [error.localizedDescription])
                    }
                }
            }
        } catch {
            return JSValue(newPromiseRejectedWithReason: error.localizedDescription, in: context)
        }
    }

    @objc(getSignedSignMessage::) func signedSignMessage(input: JSValue, options: JSValue) -> JSValue {
        guard let context else {
            return JSValue(
                newPromiseRejectedWithReason: "No context exists to perform \(#function)",
                in: JSContext()
            )
        }

        do {
            let options: TONSignedSendTransactionOptions? = try options.decode()
            let input: TONTransactionRequest = try input.decode()

            return JSValue(newPromiseIn: context) { [weak self] resolve, reject in
                Task {
                    guard let self else { return }

                    do {
                        let value = try await self.walletAdapter.signedSignMessage(
                            input: input,
                            options: options
                        ).value

                        resolve?.call(withArguments: [value])
                    } catch {
                        reject?.call(withArguments: [error.localizedDescription])
                    }
                }
            }
        } catch {
            return JSValue(newPromiseRejectedWithReason: error.localizedDescription, in: context)
        }
    }

    @objc(getSignedSignData::) func signedSignData(input: JSValue, options: JSValue) -> JSValue {
        guard let context else {
            return JSValue(
                newPromiseRejectedWithReason: "No context exists to perform \(#function)",
                in: JSContext()
            )
        }

        do {
            let options: TONSignedSendTransactionAllOptions? = try options.decode()
            let input: TONPreparedSignData = try input.decode()

            return JSValue(newPromiseIn: context) { [weak self] resolve, reject in
                Task {
                    guard let self else { return }

                    do {
                        let value = try await self.walletAdapter.signedSignData(
                            input: input,
                            fakeSignature: options?.fakeSignature
                        ).value

                        resolve?.call(withArguments: [value])
                    } catch {
                        reject?.call(withArguments: [error.localizedDescription])
                    }
                }
            }
        } catch {
            return JSValue(newPromiseRejectedWithReason: error.localizedDescription, in: context)
        }
    }

    @objc(getSignedTonProof::) func signedTonProof(input: JSValue, options: JSValue) -> JSValue {
        guard let context else {
            return JSValue(
                newPromiseRejectedWithReason: "No context exists to perform \(#function)",
                in: JSContext()
            )
        }

        do {
            let options: TONSignedSendTransactionAllOptions? = try options.decode()
            let input: TONProofMessage = try input.decode()

            return JSValue(newPromiseIn: context) { [weak self] resolve, reject in
                Task {
                    guard let self else { return }

                    do {
                        let value = try await self.walletAdapter.signedTonProof(
                            input: input,
                            fakeSignature: options?.fakeSignature
                        ).value

                        resolve?.call(withArguments: [value])
                    } catch {
                        reject?.call(withArguments: [error.localizedDescription])
                    }
                }
            }
        } catch {
            return JSValue(newPromiseRejectedWithReason: error.localizedDescription, in: context)
        }
    }
    
    @objc(getSupportedFeatures) func supportedFeatures() -> JSValue {
        guard let context else {
            return JSValue(undefinedIn: JSContext())
        }
        
        guard let features = walletAdapter.supportedFeatures() else {
            return JSValue(undefinedIn: context)
        }
        
        let rawFeatures = features.map { $0.raw }
        
        guard let encodedFeatures = try? rawFeatures.encode(in: context) else {
            return JSValue(undefinedIn: context)
        }
        
        return JSValue(object: encodedFeatures, in: context)
    }
}

extension TONWalletAdapterJSAdapter: JSValueEncodable {}
