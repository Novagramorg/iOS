//
//  JSPBKDF2Polyfill.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 11.09.2025.
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
import CommonCrypto

public class JSPBKDF2Polyfill: JSPolyfill {
    
    public func apply(to context: JSContext) {
        let pbkdf2Derive: @convention(block) (
            String,
            String,
            Int,
            Int,
            String
        ) -> JSValue = { [weak context] password, salt, iterations, keySize, hash in
            guard let context else {
                return JSValue(undefinedIn: JSContext())
            }
            
            do {
                let derivedKey = try self.derivePBKDF2(
                    password: password,
                    salt: salt,
                    iterations: iterations,
                    keySize: keySize,
                    hash: hash
                )
                return JSValue(object: derivedKey, in: context)
            } catch {
                print("❌ PBKDF2 derivation failed: \(error)")
                return JSValue(undefinedIn: context)
            }
        }
        context.setObject(pbkdf2Derive, forKeyedSubscript: "nativePbkdf2Derive" as NSString)
    }
    
    @objc
    private func derivePBKDF2(
        password: String,
        salt: String,
        iterations: Int,
        keySize: Int,
        hash: String
    ) throws -> String {
        guard let passwordData = Data(base64Encoded: password),
              let saltData = Data(base64Encoded: salt) else {
            throw JSCryptoPolyfillError.invalidPBKDF2Input
        }

        guard let algorithm = HashAlgorithm(algorithm: hash)?.pbkdf2PseudoRandomAlgorithm else {
            throw JSCryptoPolyfillError.unsupportedHashAlgorithm(hash)
        }
        
        var derivedKey = Data(count: keySize)
        
        let result = derivedKey.withUnsafeMutableBytes { derivedKeyBytes in
            passwordData.withUnsafeBytes { passwordBytes in
                saltData.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.bindMemory(to: Int8.self).baseAddress, passwordData.count,
                        saltBytes.bindMemory(to: UInt8.self).baseAddress, saltData.count,
                        algorithm,
                        UInt32(iterations),
                        derivedKeyBytes.bindMemory(to: UInt8.self).baseAddress, keySize
                    )
                }
            }
        }
        
        guard result == kCCSuccess else {
            throw JSCryptoPolyfillError.pbkdf2DerivationFailed(status: result)
        }
        return derivedKey.map { String(format: "%02x", $0) }.joined()
    }
}

private extension HashAlgorithm {
    
    var pbkdf2PseudoRandomAlgorithm: CCPseudoRandomAlgorithm? {
        switch self {
        case .sha1: CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1)
        case .sha256: CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256)
        case .sha512: CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA512)
        default: nil
        }
    }
}
