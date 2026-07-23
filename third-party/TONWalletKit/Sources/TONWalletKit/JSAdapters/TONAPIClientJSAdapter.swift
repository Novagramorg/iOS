//
//  TONAPIClientJSAdapter.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 20.01.2026.
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

class TONAPIClientJSAdapter: NSObject, JSAPIClient {
    private weak var context: JSContext?
    private let apiClient: any TONAPIClient

    init(
        context: JSContext,
        apiClient: any TONAPIClient
    ) {
        self.context = context
        self.apiClient = apiClient
    }

    @objc(getNetwork) func getNetwork() -> JSValue {
        guard let context else {
            return JSValue(undefinedIn: JSContext())
        }
        do {
            return JSValue(object: try apiClient.network().encode(in: context), in: context)
        } catch {
            return JSValue(undefinedIn: context)
        }
    }
    
    @objc(sendBoc:) func send(boc: JSValue) -> JSValue {
        guard let context else {
            return JSValue(
                newPromiseRejectedWithReason: "No context exists to perform \(#function)",
                in: JSContext()
            )
        }
        
        do {
            let boc: TONBase64 = try boc.decode()
            
            return JSValue(newPromiseIn: context) { [weak self] resolve, reject in
                Task {
                    guard let self else { return }
                    
                    do {
                        let result = try await self.apiClient.send(boc: boc)
                        resolve?.call(withArguments: [result])
                    } catch {
                        reject?.call(withArguments: [error.localizedDescription])
                    }
                }
            }
        } catch {
            return JSValue(newPromiseRejectedWithReason: error.localizedDescription, in: context)
        }
    }
    
    @objc(runGetMethod::::) func runGetMethod(
        address: JSValue,
        method: JSValue,
        stack: JSValue,
        seqno: JSValue
    ) -> JSValue {
        guard let context else {
            return JSValue(
                newPromiseRejectedWithReason: "No context exists to perform \(#function)",
                in: JSContext()
            )
        }
        
        do {
            let address: TONUserFriendlyAddress = try address.decode()
            let method: String = try method.decode()
            let stack: [TONRawStackItem]? = try stack.decode()
            let seqno: UInt? = try seqno.decode()
            
            return JSValue(newPromiseIn: context) { [weak self] resolve, reject in
                Task {
                    guard let self, let context = self.context else { return }
                    
                    do {
                        let result = try await self.apiClient.runGetMethod(
                            address: address,
                            method: method,
                            stack: stack,
                            seqno: seqno
                        )
                        let jsResult = try result.encode(in: context)
                        resolve?.call(withArguments: [jsResult])
                    } catch {
                        reject?.call(withArguments: [error.localizedDescription])
                    }
                }
            }
        } catch {
            return JSValue(newPromiseRejectedWithReason: error.localizedDescription, in: context)
        }
    }
    
    @objc(getMasterchainInfo) func masterchainInfo() -> JSValue {
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
                    let result = try await self.apiClient.masterchainInfo()
                    let jsResult = try result.encode(in: context)
                    resolve?.call(withArguments: [jsResult])
                } catch {
                    reject?.call(withArguments: [error.localizedDescription])
                }
            }
        }
    }

    @objc(nftItemsByAddress:) func nftItemsByAddress(request: JSValue) -> JSValue {
        guard let context else {
            return JSValue(newPromiseRejectedWithReason: "No context exists to perform \(#function)", in: JSContext())
        }
        do {
            let request: TONNFTsRequest = try request.decode()
            return JSValue(newPromiseIn: context) { [weak self] resolve, reject in
                Task {
                    guard let self, let context = self.context else { return }
                    do {
                        let result = try await self.apiClient.nftItemsByAddress(request: request)
                        resolve?.call(withArguments: [try result.encode(in: context)])
                    } catch {
                        reject?.call(withArguments: [error.localizedDescription])
                    }
                }
            }
        } catch {
            return JSValue(newPromiseRejectedWithReason: error.localizedDescription, in: context)
        }
    }

    @objc(nftItemsByOwner:) func nftItemsByOwner(request: JSValue) -> JSValue {
        guard let context else {
            return JSValue(newPromiseRejectedWithReason: "No context exists to perform \(#function)", in: JSContext())
        }
        do {
            let request: TONUserNFTsRequest = try request.decode()
            return JSValue(newPromiseIn: context) { [weak self] resolve, reject in
                Task {
                    guard let self, let context = self.context else { return }
                    do {
                        let result = try await self.apiClient.nftItemsByOwner(request: request)
                        resolve?.call(withArguments: [try result.encode(in: context)])
                    } catch {
                        reject?.call(withArguments: [error.localizedDescription])
                    }
                }
            }
        } catch {
            return JSValue(newPromiseRejectedWithReason: error.localizedDescription, in: context)
        }
    }

    @objc(getNftTransfers:) func getNftTransfers(request: JSValue) -> JSValue {
        guard let context else {
            return JSValue(newPromiseRejectedWithReason: "No context exists to perform \(#function)", in: JSContext())
        }
        do {
            let request: TONNFTTransfersRequest = try request.decode()
            return JSValue(newPromiseIn: context) { [weak self] resolve, reject in
                Task {
                    guard let self, let context = self.context else { return }
                    do {
                        let result = try await self.apiClient.nftTransfers(request: request)
                        resolve?.call(withArguments: [try result.encode(in: context)])
                    } catch {
                        reject?.call(withArguments: [error.localizedDescription])
                    }
                }
            }
        } catch {
            return JSValue(newPromiseRejectedWithReason: error.localizedDescription, in: context)
        }
    }

    @objc(fetchEmulation::) func fetchEmulation(messageBoc: JSValue, ignoreSignature: JSValue) -> JSValue {
        guard let context else {
            return JSValue(newPromiseRejectedWithReason: "No context exists to perform \(#function)", in: JSContext())
        }
        do {
            let boc: TONBase64 = try messageBoc.decode()
            let ignore: Bool? = try ignoreSignature.decode()
            return JSValue(newPromiseIn: context) { [weak self] resolve, reject in
                Task {
                    guard let self, let context = self.context else { return }
                    do {
                        let result = try await self.apiClient.fetchEmulation(messageBoc: boc, ignoreSignature: ignore)
                        resolve?.call(withArguments: [try result.encode(in: context)])
                    } catch {
                        reject?.call(withArguments: [error.localizedDescription])
                    }
                }
            }
        } catch {
            return JSValue(newPromiseRejectedWithReason: error.localizedDescription, in: context)
        }
    }

    @objc(getAccountState::) func getAccountState(address: JSValue, seqno: JSValue) -> JSValue {
        guard let context else {
            return JSValue(newPromiseRejectedWithReason: "No context exists to perform \(#function)", in: JSContext())
        }
        do {
            let address: TONUserFriendlyAddress = try address.decode()
            let seqno: UInt? = try seqno.decode()
            return JSValue(newPromiseIn: context) { [weak self] resolve, reject in
                Task {
                    guard let self, let context = self.context else { return }
                    do {
                        let result = try await self.apiClient.accountState(address: address, seqno: seqno)
                        resolve?.call(withArguments: [try result.encode(in: context)])
                    } catch {
                        reject?.call(withArguments: [error.localizedDescription])
                    }
                }
            }
        } catch {
            return JSValue(newPromiseRejectedWithReason: error.localizedDescription, in: context)
        }
    }

    @objc(getAccountStates:) func getAccountStates(addresses: JSValue) -> JSValue {
        guard let context else {
            return JSValue(newPromiseRejectedWithReason: "No context exists to perform \(#function)", in: JSContext())
        }
        do {
            let addresses: [TONUserFriendlyAddress] = try addresses.decode()
            
            return JSValue(newPromiseIn: context) { [weak self] resolve, reject in
                Task {
                    guard let self, let context = self.context else { return }
                    
                    do {
                        let result = try await self.apiClient.accountStates(addresses: addresses)
                        
                        let stringKeyed = Dictionary(uniqueKeysWithValues: result.map { ($0.key.value, $0.value) })
                        resolve?.call(withArguments: [try stringKeyed.encode(in: context)])
                    } catch {
                        reject?.call(withArguments: [error.localizedDescription])
                    }
                }
            }
        } catch {
            return JSValue(newPromiseRejectedWithReason: error.localizedDescription, in: context)
        }
    }

    @objc(getAccountTransactions:) func getAccountTransactions(request: JSValue) -> JSValue {
        guard let context else {
            return JSValue(newPromiseRejectedWithReason: "No context exists to perform \(#function)", in: JSContext())
        }

        do {
            let request: TONAccountTransactionsRequest = try request.decode()

            return JSValue(newPromiseIn: context) { [weak self] resolve, reject in
                Task {
                    guard let self, let context = self.context else { return }

                    do {
                        let result = try await self.apiClient.accountTransactions(
                            addresses: request.address,
                            limit: request.limit,
                            offset: request.offset
                        )
                        resolve?.call(withArguments: [try result.encode(in: context)])
                    } catch {
                        reject?.call(withArguments: [error.localizedDescription])
                    }
                }
            }
        } catch {
            return JSValue(newPromiseRejectedWithReason: error.localizedDescription, in: context)
        }
    }

    @objc(getBalance::) func getBalance(address: JSValue, seqno: JSValue) -> JSValue {
        guard let context else {
            return JSValue(newPromiseRejectedWithReason: "No context exists to perform \(#function)", in: JSContext())
        }
        do {
            let address: TONUserFriendlyAddress = try address.decode()
            let seqno: UInt? = try seqno.decode()
            return JSValue(newPromiseIn: context) { [weak self] resolve, reject in
                Task {
                    guard let self, let context = self.context else { return }
                    do {
                        let result = try await self.apiClient.balance(address: address, seqno: seqno)
                        resolve?.call(withArguments: [try result.encode(in: context)])
                    } catch {
                        reject?.call(withArguments: [error.localizedDescription])
                    }
                }
            }
        } catch {
            return JSValue(newPromiseRejectedWithReason: error.localizedDescription, in: context)
        }
    }

    @objc(resolveDnsWallet:) func resolveDnsWallet(domain: JSValue) -> JSValue {
        guard let context else {
            return JSValue(newPromiseRejectedWithReason: "No context exists to perform \(#function)", in: JSContext())
        }
        do {
            let domain: String = try domain.decode()
            return JSValue(newPromiseIn: context) { [weak self] resolve, reject in
                Task {
                    guard let self, let context = self.context else { return }
                    do {
                        let result = try await self.apiClient.resolveDnsWallet(domain: domain)
                        if let result {
                            resolve?.call(withArguments: [result])
                        } else {
                            resolve?.call(withArguments: [JSValue(undefinedIn: context) as Any])
                        }
                    } catch {
                        reject?.call(withArguments: [error.localizedDescription])
                    }
                }
            }
        } catch {
            return JSValue(newPromiseRejectedWithReason: error.localizedDescription, in: context)
        }
    }

    @objc(backResolveDnsWallet:) func backResolveDnsWallet(address: JSValue) -> JSValue {
        guard let context else {
            return JSValue(newPromiseRejectedWithReason: "No context exists to perform \(#function)", in: JSContext())
        }
        do {
            let address: TONUserFriendlyAddress = try address.decode()
            return JSValue(newPromiseIn: context) { [weak self] resolve, reject in
                Task {
                    guard let self, let context = self.context else { return }
                    do {
                        let result = try await self.apiClient.backResolveDnsWallet(address: address)
                        if let result {
                            resolve?.call(withArguments: [result])
                        } else {
                            resolve?.call(withArguments: [JSValue(undefinedIn: context) as Any])
                        }
                    } catch {
                        reject?.call(withArguments: [error.localizedDescription])
                    }
                }
            }
        } catch {
            return JSValue(newPromiseRejectedWithReason: error.localizedDescription, in: context)
        }
    }

}

extension TONAPIClientJSAdapter: JSValueEncodable {}
