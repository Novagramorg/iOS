//
//  TONWalletAdapterJSAdapterTests.swift
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
import Foundation
import JavaScriptCore
@testable import TONWalletKit

@Suite("TONWalletAdapterJSAdapter Tests")
struct TONWalletAdapterJSAdapterTests {
    private let context = JSContext()!

    @Test("publicKey returns the wallet's public key")
    func publicKeyReturnsValue() {
        let wallet = MockWalletAdapter()
        let key = TONHex(data: Data([0xab, 0xc1, 0x23]))
        wallet.mockPublicKey = key
        let sut = TONWalletAdapterJSAdapter(context: context, walletAdapter: wallet)

        let result = sut.publicKey()

        #expect(result.toString() == key.value)
    }

    @Test("publicKey returns undefined when wallet throws")
    func publicKeyReturnsUndefinedOnError() {
        let wallet = MockWalletAdapter()
        wallet.shouldThrow = true
        let sut = TONWalletAdapterJSAdapter(context: context, walletAdapter: wallet)

        let result = sut.publicKey()

        #expect(result.isUndefined)
    }

    @Test("Identifier returns the wallet ID")
    func identifierReturnsValue() {
        let wallet = MockWalletAdapter()
        wallet.mockIdentifier = "my-wallet-id"
        let sut = TONWalletAdapterJSAdapter(context: context, walletAdapter: wallet)

        let result = sut.identifier()

        #expect(result.toString() == "my-wallet-id")
    }

    @Test("Identifier returns undefined when wallet throws")
    func identifierReturnsUndefinedOnError() {
        let wallet = MockWalletAdapter()
        wallet.shouldThrow = true
        let sut = TONWalletAdapterJSAdapter(context: context, walletAdapter: wallet)

        let result = sut.identifier()

        #expect(result.isUndefined)
    }

    @Test("publicKey returns undefined when context is deallocated")
    func publicKeyReturnsUndefinedWhenDeallocated() {
        let wallet = MockWalletAdapter()
        var jsContext: JSContext? = JSContext()!
        let sut = TONWalletAdapterJSAdapter(context: jsContext!, walletAdapter: wallet)
        jsContext = nil

        let result = sut.publicKey()

        #expect(result.isUndefined)
    }

    @Test("identifier returns undefined when context is deallocated")
    func identifierReturnsUndefinedWhenDeallocated() {
        let wallet = MockWalletAdapter()
        var jsContext: JSContext? = JSContext()!
        let sut = TONWalletAdapterJSAdapter(context: jsContext!, walletAdapter: wallet)
        jsContext = nil

        let result = sut.identifier()

        #expect(result.isUndefined)
    }

    @Test("Network returns encoded mainnet")
    func networkReturnsMainnet() throws {
        let wallet = MockWalletAdapter()
        wallet.mockNetwork = .mainnet
        let sut = TONWalletAdapterJSAdapter(context: context, walletAdapter: wallet)

        let result: TONNetwork = try sut.network().decode()

        #expect(result == .mainnet)
    }

    @Test("Network returns encoded testnet")
    func networkReturnsTestnet() throws {
        let wallet = MockWalletAdapter()
        wallet.mockNetwork = .testnet
        let sut = TONWalletAdapterJSAdapter(context: context, walletAdapter: wallet)

        let result: TONNetwork = try sut.network().decode()

        #expect(result == .testnet)
    }

    @Test("Network throws when wallet throws")
    func networkThrowsOnError() {
        let wallet = MockWalletAdapter()
        wallet.shouldThrow = true
        let sut = TONWalletAdapterJSAdapter(context: context, walletAdapter: wallet)

        #expect(throws: (any Error).self) {
            let _: TONNetwork = try sut.network().decode()
        }
    }

    @Test("network throws when context is deallocated")
    func NetworkThrowsWhenDeallocated() {
        let wallet = MockWalletAdapter()
        var jsContext: JSContext? = JSContext()!
        let sut = TONWalletAdapterJSAdapter(context: jsContext!, walletAdapter: wallet)
        jsContext = nil

        #expect(throws: (any Error).self) {
            let _: TONNetwork = try sut.network().decode()
        }
    }

    @Test("Address returns the wallet address value")
    func addressReturnsValue() {
        let wallet = MockWalletAdapter()
        let sut = TONWalletAdapterJSAdapter(context: context, walletAdapter: wallet)
        let options = JSValue(undefinedIn: context)!

        let result = sut.address(options: options)

        #expect(result.isString)
        #expect(result.toString() == wallet.mockAddress.value)
    }

    @Test("Address returns undefined when wallet throws")
    func addressReturnsUndefinedOnError() {
        let wallet = MockWalletAdapter()
        wallet.shouldThrow = true
        let sut = TONWalletAdapterJSAdapter(context: context, walletAdapter: wallet)
        let options = JSValue(undefinedIn: context)!

        let result = sut.address(options: options)

        #expect(result.isUndefined)
    }

    @Test("address returns undefined when context is deallocated")
    func addressReturnsUndefinedWhenDeallocated() {
        let wallet = MockWalletAdapter()
        var jsContext: JSContext? = JSContext()!
        let sut = TONWalletAdapterJSAdapter(context: jsContext!, walletAdapter: wallet)
        let options = JSValue(undefinedIn: context)!
        jsContext = nil

        let result = sut.address(options: options)

        #expect(result.isUndefined)
    }

    @Test("stateInit rejects when context is deallocated")
    func stateInitRejectsWhenDeallocated() async {
        let wallet = MockWalletAdapter()
        var jsContext: JSContext? = JSContext()!
        let sut = TONWalletAdapterJSAdapter(context: jsContext!, walletAdapter: wallet)
        jsContext = nil

        let result = sut.stateInit()

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("stateInit resolves with base64 encoded value")
    func stateInitResolvesWithValue() async throws {
        let wallet = MockWalletAdapter()
        let sut = TONWalletAdapterJSAdapter(context: context, walletAdapter: wallet)

        let result = sut.stateInit()
        let resolved = try await result.then()

        #expect(resolved.toString() == TONBase64(string: "stateInit").value)
    }

    @Test("stateInit rejects when wallet throws")
    func stateInitRejectsWhenWalletThrows() async {
        let wallet = MockWalletAdapter()
        wallet.shouldThrow = true
        let sut = TONWalletAdapterJSAdapter(context: context, walletAdapter: wallet)

        let result = sut.stateInit()

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("signedSendTransaction resolves with signed base64")
    func signedSendTransactionResolvesWithValue() async throws {
        let wallet = MockWalletAdapter()
        let sut = TONWalletAdapterJSAdapter(context: context, walletAdapter: wallet)
        let input = context.evaluateScript(
            "JSON.parse('{\"messages\":[{\"address\":\"test-address\",\"amount\":\"1000000000\"}]}')"
        )!
        let options = JSValue(undefinedIn: context)!

        let result = sut.signedSendTransaction(input: input, options: options)
        let resolved = try await result.then()

        #expect(resolved.toString() == TONBase64(string: "signed").value)
    }

    @Test("signedSendTransaction rejects for invalid input")
    func signedSendTransactionRejectsForInvalidInput() async {
        let wallet = MockWalletAdapter()
        let sut = TONWalletAdapterJSAdapter(context: context, walletAdapter: wallet)
        let input = JSValue(undefinedIn: context)!
        let options = JSValue(undefinedIn: context)!

        let result = sut.signedSendTransaction(input: input, options: options)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("signedSendTransaction rejects for malformed options")
    func signedSendTransactionRejectsForMalformedOptions() async {
        let wallet = MockWalletAdapter()
        let sut = TONWalletAdapterJSAdapter(context: context, walletAdapter: wallet)
        let input = context.evaluateScript(
            "JSON.parse('{\"messages\":[{\"address\":\"test-address\",\"amount\":\"1000000000\"}]}')"
        )!
        let options = context.evaluateScript("JSON.parse('{\"fakeSignature\":\"not-a-bool\"}')")!

        let result = sut.signedSendTransaction(input: input, options: options)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("signedSendTransaction rejects when wallet throws")
    func signedSendTransactionRejectsWhenWalletThrows() async {
        let wallet = MockWalletAdapter()
        wallet.shouldThrow = true
        let sut = TONWalletAdapterJSAdapter(context: context, walletAdapter: wallet)
        let input = context.evaluateScript(
            "JSON.parse('{\"messages\":[{\"address\":\"test-address\",\"amount\":\"1000000000\"}]}')"
        )!
        let options = JSValue(undefinedIn: context)!

        let result = sut.signedSendTransaction(input: input, options: options)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("signedSignMessage resolves with signed base64")
    func signedSignMessageResolvesWithValue() async throws {
        let wallet = MockWalletAdapter()
        let sut = TONWalletAdapterJSAdapter(context: context, walletAdapter: wallet)
        let input = context.evaluateScript(
            "JSON.parse('{\"messages\":[{\"address\":\"test-address\",\"amount\":\"1000000000\"}]}')"
        )!
        let options = JSValue(undefinedIn: context)!

        let result = sut.signedSignMessage(input: input, options: options)
        let resolved = try await result.then()

        #expect(resolved.toString() == TONBase64(string: "signedMessage").value)
    }

    @Test("signedSignMessage rejects for invalid input")
    func signedSignMessageRejectsForInvalidInput() async {
        let wallet = MockWalletAdapter()
        let sut = TONWalletAdapterJSAdapter(context: context, walletAdapter: wallet)
        let input = JSValue(undefinedIn: context)!
        let options = JSValue(undefinedIn: context)!

        let result = sut.signedSignMessage(input: input, options: options)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("signedSignMessage rejects for malformed options")
    func signedSignMessageRejectsForMalformedOptions() async {
        let wallet = MockWalletAdapter()
        let sut = TONWalletAdapterJSAdapter(context: context, walletAdapter: wallet)
        let input = context.evaluateScript(
            "JSON.parse('{\"messages\":[{\"address\":\"test-address\",\"amount\":\"1000000000\"}]}')"
        )!
        let options = context.evaluateScript("JSON.parse('{\"fakeSignature\":\"not-a-bool\"}')")!

        let result = sut.signedSignMessage(input: input, options: options)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("signedSignMessage rejects when wallet throws")
    func signedSignMessageRejectsWhenWalletThrows() async {
        let wallet = MockWalletAdapter()
        wallet.shouldThrow = true
        let sut = TONWalletAdapterJSAdapter(context: context, walletAdapter: wallet)
        let input = context.evaluateScript(
            "JSON.parse('{\"messages\":[{\"address\":\"test-address\",\"amount\":\"1000000000\"}]}')"
        )!
        let options = JSValue(undefinedIn: context)!

        let result = sut.signedSignMessage(input: input, options: options)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("signedSignData resolves with signed hex")
    func signedSignDataResolvesWithValue() async throws {
        let wallet = MockWalletAdapter()
        let sut = TONWalletAdapterJSAdapter(context: context, walletAdapter: wallet)
        let addressValue = wallet.mockAddress.value
        let json = """
        {"address":"\(addressValue)","timestamp":1704067200,"domain":"example.com","payload":{"data":{"type":"text","value":{"content":"test"}}},"hash":"abcd"}
        """
        let input = context.evaluateScript("JSON.parse('\(json)')")!
        let options = JSValue(undefinedIn: context)!

        let result = sut.signedSignData(input: input, options: options)
        let resolved = try await result.then()

        #expect(resolved.toString() == TONHex(data: Data([0xab, 0xcd])).value)
    }

    @Test("signedSignData rejects for invalid input")
    func signedSignDataRejectsForInvalidInput() async {
        let wallet = MockWalletAdapter()
        let sut = TONWalletAdapterJSAdapter(context: context, walletAdapter: wallet)
        let input = JSValue(undefinedIn: context)!
        let options = JSValue(undefinedIn: context)!

        let result = sut.signedSignData(input: input, options: options)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("signedSignData rejects for malformed options")
    func signedSignDataRejectsForMalformedOptions() async {
        let wallet = MockWalletAdapter()
        let sut = TONWalletAdapterJSAdapter(context: context, walletAdapter: wallet)
        let addressValue = wallet.mockAddress.value
        let json = """
        {"address":"\(addressValue)","timestamp":1704067200,"domain":"example.com","payload":{"data":{"type":"text","value":{"content":"test"}}},"hash":"abcd"}
        """
        let input = context.evaluateScript("JSON.parse('\(json)')")!
        let options = context.evaluateScript("JSON.parse('{\"fakeSignature\":\"not-a-bool\"}')")!

        let result = sut.signedSignData(input: input, options: options)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("signedSignData rejects when wallet throws")
    func signedSignDataRejectsWhenWalletThrows() async {
        let wallet = MockWalletAdapter()
        wallet.shouldThrow = true
        let sut = TONWalletAdapterJSAdapter(context: context, walletAdapter: wallet)
        let addressValue = wallet.mockAddress.value
        let json = """
        {"address":"\(addressValue)","timestamp":1704067200,"domain":"example.com","payload":{"data":{"type":"text","value":{"content":"test"}}},"hash":"abcd"}
        """
        let input = context.evaluateScript("JSON.parse('\(json)')")!
        let options = JSValue(undefinedIn: context)!

        let result = sut.signedSignData(input: input, options: options)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("signedTonProof resolves with signed hex")
    func signedTonProofResolvesWithValue() async throws {
        let wallet = MockWalletAdapter()
        let sut = TONWalletAdapterJSAdapter(context: context, walletAdapter: wallet)
        let json = """
        {"workchain":0,"addressHash":"abcd","timestamp":1704067200,"domain":{"lengthBytes":11,"value":"example.com"},"payload":"test","stateInit":"dGVzdA=="}
        """
        let input = context.evaluateScript("JSON.parse('\(json)')")!
        let options = JSValue(undefinedIn: context)!

        let result = sut.signedTonProof(input: input, options: options)
        let resolved = try await result.then()

        #expect(resolved.toString() == TONHex(data: Data([0xef, 0x01])).value)
    }

    @Test("signedTonProof rejects for malformed options")
    func signedTonProofRejectsForMalformedOptions() async {
        let wallet = MockWalletAdapter()
        let sut = TONWalletAdapterJSAdapter(context: context, walletAdapter: wallet)
        let json = """
        {"workchain":0,"addressHash":"abcd","timestamp":1704067200,"domain":{"lengthBytes":11,"value":"example.com"},"payload":"test","stateInit":"dGVzdA=="}
        """
        let input = context.evaluateScript("JSON.parse('\(json)')")!
        let options = context.evaluateScript("JSON.parse('{\"fakeSignature\":\"not-a-bool\"}')")!

        let result = sut.signedTonProof(input: input, options: options)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("signedTonProof rejects for invalid input")
    func signedTonProofRejectsForInvalidInput() async {
        let wallet = MockWalletAdapter()
        let sut = TONWalletAdapterJSAdapter(context: context, walletAdapter: wallet)
        let input = JSValue(undefinedIn: context)!
        let options = JSValue(undefinedIn: context)!

        let result = sut.signedTonProof(input: input, options: options)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("signedSendTransaction rejects when context is deallocated")
    func signedSendTransactionRejectsWhenDeallocated() async {
        let wallet = MockWalletAdapter()
        var jsContext: JSContext? = JSContext()!
        let sut = TONWalletAdapterJSAdapter(context: jsContext!, walletAdapter: wallet)
        let input = JSValue(undefinedIn: context)!
        let options = JSValue(undefinedIn: context)!
        jsContext = nil

        let result = sut.signedSendTransaction(input: input, options: options)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("signedSignData rejects when context is deallocated")
    func signedSignDataRejectsWhenDeallocated() async {
        let wallet = MockWalletAdapter()
        var jsContext: JSContext? = JSContext()!
        let sut = TONWalletAdapterJSAdapter(context: jsContext!, walletAdapter: wallet)
        let input = JSValue(undefinedIn: context)!
        let options = JSValue(undefinedIn: context)!
        jsContext = nil

        let result = sut.signedSignData(input: input, options: options)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("signedTonProof rejects when context is deallocated")
    func signedTonProofRejectsWhenDeallocated() async {
        let wallet = MockWalletAdapter()
        var jsContext: JSContext? = JSContext()!
        let sut = TONWalletAdapterJSAdapter(context: jsContext!, walletAdapter: wallet)
        let input = JSValue(undefinedIn: context)!
        let options = JSValue(undefinedIn: context)!
        jsContext = nil

        let result = sut.signedTonProof(input: input, options: options)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("signedTonProof rejects when wallet throws")
    func signedTonProofRejectsWhenWalletThrows() async {
        let wallet = MockWalletAdapter()
        wallet.shouldThrow = true
        let sut = TONWalletAdapterJSAdapter(context: context, walletAdapter: wallet)
        let json = """
        {"workchain":0,"addressHash":"abcd","timestamp":1704067200,"domain":{"lengthBytes":11,"value":"example.com"},"payload":"test","stateInit":"dGVzdA=="}
        """
        let input = context.evaluateScript("JSON.parse('\(json)')")!
        let options = JSValue(undefinedIn: context)!

        let result = sut.signedTonProof(input: input, options: options)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("supportedFeatures returns encoded features array")
    func supportedFeaturesReturnsEncodedArray() {
        let wallet = MockWalletAdapter()
        wallet.mockSupportedFeatures = [
            TONSendTransactionFeature(maxMessages: 4, extraCurrencySupported: true),
            TONSignDataFeature(types: [.text, .binary])
        ]
        let sut = TONWalletAdapterJSAdapter(context: context, walletAdapter: wallet)

        let result = sut.supportedFeatures()

        #expect(result.isArray)
        #expect(result.toArray()?.count == 2)
    }

    @Test("supportedFeatures returns undefined when wallet returns nil")
    func supportedFeaturesReturnsUndefinedWhenNil() {
        let wallet = MockWalletAdapter()
        wallet.mockSupportedFeatures = nil
        let sut = TONWalletAdapterJSAdapter(context: context, walletAdapter: wallet)

        let result = sut.supportedFeatures()

        #expect(result.isUndefined)
    }

    @Test("supportedFeatures returns undefined when context is deallocated")
    func supportedFeaturesReturnsUndefinedWhenDeallocated() {
        let wallet = MockWalletAdapter()
        wallet.mockSupportedFeatures = [
            TONSendTransactionFeature(maxMessages: 4)
        ]
        var jsContext: JSContext? = JSContext()!
        let sut = TONWalletAdapterJSAdapter(context: jsContext!, walletAdapter: wallet)
        jsContext = nil

        let result = sut.supportedFeatures()

        #expect(result.isUndefined)
    }

    @Test("identifier is callable from JS")
    func identifierCallableFromJS() throws {
        let wallet = MockWalletAdapter()
        wallet.mockIdentifier = "my-wallet-id"
        let sut = TONWalletAdapterJSAdapter(context: context, walletAdapter: wallet)
        context.evaluateScript("function callIdentifier(w) { return w.getWalletId(); }")

        let result: String? = try context.callIdentifier(sut)

        #expect(result == "my-wallet-id")
    }
}
