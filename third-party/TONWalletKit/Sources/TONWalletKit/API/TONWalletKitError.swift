//
//  TONWalletKitError.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 19.06.2026.
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

/// Top-level errors raised by `TONWalletKit` for SDK lifecycle / operation failures.
public enum TONWalletKitError: LocalizedError {
    /// The WalletKit JS instance has not been initialized yet.
    case notInitialized
    /// The injectable bridge could not be resolved (WalletKit is not initialized).
    case bridgeUnavailable
    /// A streaming provider did not expose a network.
    case streamingNetworkUnavailable
    /// An injected bridge request timed out before a response arrived.
    case bridgeRequestTimeout(messageID: String)
    /// The mnemonic must contain exactly 12 or 24 non-empty TON words.
    case invalidMnemonic
    /// The selected API client does not implement an optional SDK operation.
    case unsupportedAPIClientOperation(String)

    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Unable to resolve initialized WalletKit instance."
        case .bridgeUnavailable:
            return "Unable to resolve bridge for injection. WalletKit is not initialized."
        case .streamingNetworkUnavailable:
            return "Unable to get network from streaming provider."
        case .bridgeRequestTimeout(let messageID):
            return "Timeout waiting for response for message with ID \(messageID)"
        case .invalidMnemonic:
            return "A TON mnemonic must contain exactly 12 or 24 non-empty words."
        case .unsupportedAPIClientOperation(let operation):
            return "The configured API client does not support \(operation)."
        }
    }
}
