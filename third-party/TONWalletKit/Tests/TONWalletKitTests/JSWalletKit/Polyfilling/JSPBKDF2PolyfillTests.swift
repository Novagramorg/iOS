//
//  JSPBKDF2PolyfillTests.swift
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
@_private(sourceFile: "JSPBKDF2Polyfill.swift")
@testable import TONWalletKit

@Suite("JSPBKDF2Polyfill Tests")
struct JSPBKDF2PolyfillTests {

    private let context = JSContext()!
    private let sut = JSPBKDF2Polyfill()

    // Base64 encoded "password" and "salt"
    private let passwordB64 = "cGFzc3dvcmQ="
    private let saltB64 = "c2FsdA=="

    // MARK: - apply(to:)

    @Test("Apply registers nativePbkdf2Derive on context")
    func applyRegistersFunction() {
        sut.apply(to: context)

        let fn = context.objectForKeyedSubscript("nativePbkdf2Derive")
        #expect(fn != nil)
        #expect(!fn!.isUndefined)
    }

    // MARK: - derivePBKDF2

    @Test("derivePBKDF2 with SHA-1 matches RFC 6070 vector (c=1)")
    func deriveSHA1SingleIteration() throws {
        let result = try sut.derivePBKDF2(
            password: passwordB64,
            salt: saltB64,
            iterations: 1,
            keySize: 20,
            hash: "SHA-1"
        )
        #expect(result == "0c60c80f961f0e71f3a9b524af6012062fe037a6")
    }

    @Test("derivePBKDF2 with SHA-1 matches RFC 6070 vector (c=4096)")
    func deriveSHA1MultipleIterations() throws {
        let result = try sut.derivePBKDF2(
            password: passwordB64,
            salt: saltB64,
            iterations: 4096,
            keySize: 20,
            hash: "SHA-1"
        )
        #expect(result == "4b007901b765489abead49d926f721d065a429c1")
    }

    @Test("derivePBKDF2 with SHA-256 returns correct key")
    func deriveSHA256() throws {
        let result = try sut.derivePBKDF2(
            password: passwordB64,
            salt: saltB64,
            iterations: 1,
            keySize: 32,
            hash: "SHA-256"
        )
        #expect(result == "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b")
    }

    @Test("derivePBKDF2 with SHA-512 returns correct key length")
    func deriveSHA512() throws {
        let result = try sut.derivePBKDF2(
            password: passwordB64,
            salt: saltB64,
            iterations: 1,
            keySize: 64,
            hash: "SHA-512"
        )
        // 64 bytes = 128 hex characters
        #expect(result.count == 128)
    }

    @Test("derivePBKDF2 throws .invalidPBKDF2Input for invalid base64 password")
    func deriveInvalidPassword() {
        let error = #expect(throws: JSCryptoPolyfillError.self) {
            try sut.derivePBKDF2(
                password: "%%%invalid%%%",
                salt: saltB64,
                iterations: 1,
                keySize: 20,
                hash: "SHA-1"
            )
        }

        guard case .invalidPBKDF2Input? = error else {
            Issue.record("Expected .invalidPBKDF2Input, got \(String(describing: error))")
            return
        }
    }

    @Test("derivePBKDF2 throws .invalidPBKDF2Input for invalid base64 salt")
    func deriveInvalidSalt() {
        let error = #expect(throws: JSCryptoPolyfillError.self) {
            try sut.derivePBKDF2(
                password: passwordB64,
                salt: "%%%invalid%%%",
                iterations: 1,
                keySize: 20,
                hash: "SHA-1"
            )
        }

        guard case .invalidPBKDF2Input? = error else {
            Issue.record("Expected .invalidPBKDF2Input, got \(String(describing: error))")
            return
        }
    }

    @Test("derivePBKDF2 throws .unsupportedHashAlgorithm for unsupported hash algorithm")
    func deriveUnsupportedAlgorithm() {
        let error = #expect(throws: JSCryptoPolyfillError.self) {
            try sut.derivePBKDF2(
                password: passwordB64,
                salt: saltB64,
                iterations: 1,
                keySize: 20,
                hash: "MD5"
            )
        }

        guard case .unsupportedHashAlgorithm(let hash)? = error else {
            Issue.record("Expected .unsupportedHashAlgorithm, got \(String(describing: error))")
            return
        }
        #expect(hash == "MD5")
    }

    @Test("derivePBKDF2 throws .unsupportedHashAlgorithm for unknown hash algorithm")
    func deriveUnknownAlgorithm() {
        let error = #expect(throws: JSCryptoPolyfillError.self) {
            try sut.derivePBKDF2(
                password: passwordB64,
                salt: saltB64,
                iterations: 1,
                keySize: 20,
                hash: "INVALID"
            )
        }

        guard case .unsupportedHashAlgorithm(let hash)? = error else {
            Issue.record("Expected .unsupportedHashAlgorithm, got \(String(describing: error))")
            return
        }
        #expect(hash == "INVALID")
    }

    // MARK: - JS Integration

    @Test("nativePbkdf2Derive called from JS returns correct hex string")
    func jsCallReturnsCorrectResult() {
        sut.apply(to: context)

        let result = context.evaluateScript(
            "nativePbkdf2Derive('cGFzc3dvcmQ=', 'c2FsdA==', 1, 20, 'SHA-1')"
        )

        #expect(result?.toString() == "0c60c80f961f0e71f3a9b524af6012062fe037a6")
    }

    @Test("nativePbkdf2Derive called from JS with invalid base64 returns undefined")
    func jsCallInvalidInputReturnsUndefined() {
        sut.apply(to: context)

        let result = context.evaluateScript(
            "nativePbkdf2Derive('%%%invalid%%%', 'c2FsdA==', 1, 20, 'SHA-1')"
        )

        #expect(result?.isUndefined == true)
    }

    @Test("nativePbkdf2Derive called from JS with unsupported algorithm returns undefined")
    func jsCallUnsupportedAlgorithmReturnsUndefined() {
        sut.apply(to: context)

        let result = context.evaluateScript(
            "nativePbkdf2Derive('cGFzc3dvcmQ=', 'c2FsdA==', 1, 20, 'MD5')"
        )

        #expect(result?.isUndefined == true)
    }
}
