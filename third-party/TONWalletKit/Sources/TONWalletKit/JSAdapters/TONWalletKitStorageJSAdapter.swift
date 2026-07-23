//
//  TONWalletKitStorageAdapter.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 09.10.2025.
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

class TONWalletKitStorageJSAdapter: NSObject, JSWalletKitStorage {
    private weak var context: JSContext?
    private let storage: any TONWalletKitStorage
    
    init(
        context: JSContext,
        storage: any TONWalletKitStorage
    ) {
        self.context = context
        self.storage = storage
    }
    
    @objc(set::) func set(key: String, value: String) -> JSValue {
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
                    try await self.storage.set(key: key, value: value)
                    resolve?.call(withArguments: [JSValue(undefinedIn: context)])
                } catch {
                    reject?.call(withArguments: [error.localizedDescription])
                }
            }
        }
    }

    @objc(get:) func get(key: String) -> JSValue {
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
                    if let value = try await self.storage.get(key: key) {
                        resolve?.call(withArguments: [value])
                    } else {
                        resolve?.call(withArguments: [JSValue(nullIn: context)])
                    }
                } catch {
                    reject?.call(withArguments: [error.localizedDescription])
                }
            }
        }
    }

    @objc(remove:) func remove(key: String) -> JSValue {
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
                    try await self.storage.remove(key: key)
                    resolve?.call(withArguments: [JSValue(undefinedIn: context)])
                } catch {
                    reject?.call(withArguments: [error.localizedDescription])
                }
            }
        }
    }

    @objc func clear() -> JSValue {
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
                    try await self.storage.clear()
                    resolve?.call(withArguments: [JSValue(undefinedIn: context)])
                } catch {
                    reject?.call(withArguments: [error.localizedDescription])
                }
            }
        }
    }
}

extension TONWalletKitStorageJSAdapter: JSValueEncodable {}
