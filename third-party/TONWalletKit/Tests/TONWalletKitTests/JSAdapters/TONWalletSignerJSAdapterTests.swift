//
//  TONWalletSignerJSAdapterTests.swift
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
@testable import TONWalletKit

@Suite("TONWalletSignerJSAdapter Tests")
struct TONWalletSignerJSAdapterTests {

    private let context = JSContext()!

    @Test("publicKey returns the signer's public key as JSValue")
    func publicKeyReturnsCorrectValue() {
        let key = TONHex(data: Data([0xab, 0xcd, 0x12, 0x34]))
        let signer = MockSigner(publicKey: key)
        let sut = TONWalletSignerJSAdapter(context: context, signer: signer)

        let result = sut.publicKey()

        #expect(result.toString() == key.value)
    }

    @Test("sign resolves with signed hex data")
    func signResolvesWithSignedData() async throws {
        let signer = MockSigner()
        let sut = TONWalletSignerJSAdapter(context: context, signer: signer)

        let result = sut.sign(data: [0x01, 0x02, 0x03])
        let resolved = try await result.then()

        #expect(resolved.toString() == TONHex(data: Data([0xab, 0xcd])).value)
    }

    @Test("publicKey returns undefined when context is deallocated")
    func publicKeyReturnsUndefinedWhenDeallocated() {
        let signer = MockSigner()
        var jsContext: JSContext? = JSContext()!
        let sut = TONWalletSignerJSAdapter(context: jsContext!, signer: signer)
        jsContext = nil

        let result = sut.publicKey()

        #expect(result.isUndefined)
    }

    @Test("sign rejects when context is deallocated")
    func signRejectsWhenDeallocated() async {
        let signer = MockSigner()
        var jsContext: JSContext? = JSContext()!
        let sut = TONWalletSignerJSAdapter(context: jsContext!, signer: signer)
        jsContext = nil

        let result = sut.sign(data: [0x01, 0x02, 0x03])

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("sign rejects when signer throws")
    func signRejectsWhenSignerThrows() async {
        let signer = MockSigner()
        signer.shouldThrow = true
        let sut = TONWalletSignerJSAdapter(context: context, signer: signer)

        let result = sut.sign(data: [0x01, 0x02, 0x03])

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("publicKey is callable from JS")
    func publicKeyCallableFromJS() throws {
        let key = TONHex(data: Data([0xab, 0xcd, 0x12, 0x34]))
        let signer = MockSigner(publicKey: key)
        let sut = TONWalletSignerJSAdapter(context: context, signer: signer)
        context.evaluateScript("function callPublicKey(s) { return s.publicKey(); }")

        let result: String? = try context.callPublicKey(sut)

        #expect(result == key.value)
    }

    @Test("sign resolves from JS call")
    func signResolvesFromJS() async throws {
        let signer = MockSigner()
        let sut = TONWalletSignerJSAdapter(context: context, signer: signer)
        context.evaluateScript("function callSign(s, data) { return s.sign(data); }")

        let result: String = try await context.callSign(sut, [0x01, 0x02, 0x03] as [UInt8])

        #expect(result == TONHex(data: Data([0xab, 0xcd])).value)
    }
}
