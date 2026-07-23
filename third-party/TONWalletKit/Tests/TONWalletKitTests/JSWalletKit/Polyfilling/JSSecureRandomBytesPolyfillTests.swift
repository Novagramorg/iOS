//
//  JSSecureRandomBytesPolyfillTests.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 08.02.2026.
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

import Testing
import JavaScriptCore
@_private(sourceFile: "JSSecureRandomBytesPolyfill.swift")
@testable import TONWalletKit

@Suite("JSSecureRandomBytesPolyfill Tests")
struct JSSecureRandomBytesPolyfillTests {

    private let context = JSContext()!
    private let sut = JSSecureRandomBytesPolyfill()

    // MARK: - apply(to:)

    @Test("Apply registers getSecureRandomBytes on context")
    func applyRegistersFunction() {
        sut.apply(to: context)

        let fn = context.objectForKeyedSubscript("getSecureRandomBytes")
        #expect(fn != nil)
        #expect(!fn!.isUndefined)
    }

    // MARK: - generateSecureRandomBytes

    @Test("generateSecureRandomBytes returns array of requested length")
    func generateReturnsCorrectLength() throws {
        let result = try sut.generateSecureRandomBytes(count: 32)
        #expect(result.count == 32)
    }

    @Test("generateSecureRandomBytes returns different values on subsequent calls")
    func generateReturnsDifferentValues() throws {
        let result1 = try sut.generateSecureRandomBytes(count: 32)
        let result2 = try sut.generateSecureRandomBytes(count: 32)
        #expect(result1 != result2)
    }

    @Test("generateSecureRandomBytes throws .nonPositiveByteCount for zero count")
    func generateThrowsForZeroCount() {
        let error = #expect(throws: JSCryptoPolyfillError.self) {
            try sut.generateSecureRandomBytes(count: 0)
        }

        guard case .nonPositiveByteCount? = error else {
            Issue.record("Expected .nonPositiveByteCount, got \(String(describing: error))")
            return
        }
    }

    @Test("generateSecureRandomBytes throws .nonPositiveByteCount for negative count")
    func generateThrowsForNegativeCount() {
        let error = #expect(throws: JSCryptoPolyfillError.self) {
            try sut.generateSecureRandomBytes(count: -1)
        }

        guard case .nonPositiveByteCount? = error else {
            Issue.record("Expected .nonPositiveByteCount, got \(String(describing: error))")
            return
        }
    }

    // MARK: - JS Integration

    @Test("getSecureRandomBytes called from JS returns array of correct length")
    func jsCallReturnsCorrectLength() {
        sut.apply(to: context)

        let result = context.evaluateScript("getSecureRandomBytes(16)")

        #expect(result?.isArray == true)
        #expect(result?.toArray()?.count == 16)
    }

    @Test("getSecureRandomBytes called from JS returns bytes in 0-255 range")
    func jsCallReturnsBytesInRange() throws {
        sut.apply(to: context)

        let result = context.evaluateScript("getSecureRandomBytes(64)")
        let array = try #require(result?.toArray() as? [NSNumber])

        for byte in array {
            #expect(byte.intValue >= 0)
            #expect(byte.intValue <= 255)
        }
    }

    @Test("getSecureRandomBytes called from JS with zero returns undefined")
    func jsCallWithZeroReturnsUndefined() {
        sut.apply(to: context)

        let result = context.evaluateScript("getSecureRandomBytes(0)")

        #expect(result?.isUndefined == true)
    }
}
