//
//  JSCryptoPolyfillError.swift
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

/// Errors raised by the JS crypto polyfills (secure random bytes, PBKDF2).
enum JSCryptoPolyfillError: LocalizedError {
    /// Requested random byte count was not positive.
    case nonPositiveByteCount
    /// `SecRandomCopyBytes` failed with the given status.
    case randomGenerationFailed(status: Int32)
    /// Password/salt could not be decoded into data.
    case invalidPBKDF2Input
    /// The requested hash algorithm is not supported.
    case unsupportedHashAlgorithm(String)
    /// `CCKeyDerivationPBKDF` failed with the given status.
    case pbkdf2DerivationFailed(status: Int32)

    var errorDescription: String? {
        switch self {
        case .nonPositiveByteCount:
            return "Random bytes count must be positive"
        case .randomGenerationFailed(let status):
            return "Failed to generate secure random bytes: \(status)"
        case .invalidPBKDF2Input:
            return "Failed to convert password or salt to data"
        case .unsupportedHashAlgorithm(let hash):
            return "Unsupported hash algorithm: \(hash)"
        case .pbkdf2DerivationFailed(let status):
            return "PBKDF2 derivation failed with error: \(status)"
        }
    }
}
