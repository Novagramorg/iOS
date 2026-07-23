//
//  JSSecureRandomBytesPolyfill.swift
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

public class JSSecureRandomBytesPolyfill: JSPolyfill {
    
    public func apply(to context: JSContext) {
        let getSecureRandomBytes: @convention(block) (Int) -> JSValue = { [weak context] length in
            guard let context else {
                return JSValue(undefinedIn: JSContext())
            }
            
            do {
                let randomBytes = try self.generateSecureRandomBytes(count: length)
                let jsArray = JSValue(newArrayIn: context)!
                
                for (index, byte) in randomBytes.enumerated() {
                    jsArray.setObject(NSNumber(value: byte), atIndexedSubscript: index)
                }
                
                return jsArray
            } catch {
                print("❌ Failed to generate secure random bytes: \(error)")
                return JSValue(undefinedIn: context)
            }
        }
        
        context.setObject(getSecureRandomBytes, forKeyedSubscript: "getSecureRandomBytes" as NSString)
    }
    
    @objc
    private func generateSecureRandomBytes(count: Int) throws -> [UInt8] {
        guard count > 0 else {
            throw JSCryptoPolyfillError.nonPositiveByteCount
        }
        
        var randomBytes = [UInt8](repeating: 0, count: count)
        let result = SecRandomCopyBytes(kSecRandomDefault, count, &randomBytes)
        
        guard result == errSecSuccess else {
            throw JSCryptoPolyfillError.randomGenerationFailed(status: result)
        }
        
        return randomBytes
    }
}
