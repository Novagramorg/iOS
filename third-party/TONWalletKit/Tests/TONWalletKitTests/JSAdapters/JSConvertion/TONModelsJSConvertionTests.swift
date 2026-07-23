//
//  TONModelsJSConvertionTests.swift
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

@Suite("TONModelsJSConvertion Tests")
struct TONModelsJSConvertionTests {

    private let context = JSContext()!

    private func makeJSValue(_ value: Any) -> JSValue {
        JSValue(object: value, in: context)
    }

    /// Constructs a valid TON user-friendly address string (bounceable, workchain 0, zero hash).
    private func makeValidAddressString() -> String {
        var address = Data(count: 34)
        address[0] = 0x11 // bounceable tag
        address[1] = 0x00 // workchain 0
        // bytes 2-33 are zero (hash)
        let crc = address.crc16()
        return (address + crc).base64URLEncodedString()
    }

    // MARK: - TONBalance: JSValueDecodable

    @Test("TONBalance.from decodes valid BigInt string")
    func balanceFromValid() throws {
        let jsValue = makeJSValue("1000000000")
        let balance = try #require(try TONBalance.from(jsValue))
        #expect(String(balance.nanoUnits) == "1000000000")
    }

    @Test("TONBalance.from decodes large BigInt string")
    func balanceFromLargeValue() throws {
        let jsValue = makeJSValue("999999999999999999999")
        let balance = try #require(try TONBalance.from(jsValue))
        #expect(String(balance.nanoUnits) == "999999999999999999999")
    }

    @Test("TONBalance.from decodes zero")
    func balanceFromZero() throws {
        let jsValue = makeJSValue("0")
        let balance = try #require(try TONBalance.from(jsValue))
        #expect(String(balance.nanoUnits) == "0")
    }

    @Test("TONBalance.from throws for non-numeric string")
    func balanceFromInvalidString() {
        let jsValue = makeJSValue("not_a_number")
        #expect(throws: (any Error).self) {
            try TONBalance.from(jsValue)
        }
    }

    @Test("TONBalance.from throws for undefined JSValue")
    func balanceFromUndefined() {
        let jsValue = JSValue(undefinedIn: context)!
        #expect(throws: (any Error).self) {
            let _: TONBalance = try jsValue.decode()
        }
    }

    // MARK: - TONBalance: JSValueEncodable

    @Test("TONBalance.encode returns string representation of nanoUnits")
    func balanceEncode() throws {
        let balance = TONBalance(nanoUnits: 1000000000)
        let encoded = try balance.encode(in: context)
        #expect(encoded as? String == "1000000000")
    }

    @Test("TONBalance.encode roundtrips correctly")
    func balanceRoundtrip() throws {
        let original = TONBalance(nanoUnits: 42)
        let encoded = try original.encode(in: context)
        let jsValue = JSValue(object: encoded, in: context)!
        let decoded = try #require(try TONBalance.from(jsValue))
        #expect(String(decoded.nanoUnits) == "42")
    }

    // MARK: - TONUserFriendlyAddress: JSValueDecodable

    @Test("TONUserFriendlyAddress.from decodes valid address string")
    func addressFromValid() throws {
        let addressString = makeValidAddressString()
        let jsValue = makeJSValue(addressString)

        let address = try #require(try TONUserFriendlyAddress.from(jsValue))
        #expect(address.value == addressString)
        #expect(address.isBounceable == true)
        #expect(address.workchain == 0)
    }

    @Test("TONUserFriendlyAddress.from throws for invalid address string")
    func addressFromInvalid() {
        let jsValue = makeJSValue("invalid_address")
        #expect(throws: (any Error).self) {
            try TONUserFriendlyAddress.from(jsValue)
        }
    }

    @Test("TONUserFriendlyAddress.from throws for undefined JSValue")
    func addressFromUndefined() {
        let jsValue = JSValue(undefinedIn: context)!
        #expect(throws: (any Error).self) {
            let _: TONUserFriendlyAddress = try jsValue.decode()
        }
    }

    // MARK: - TONBase64: JSValueDecodable

    @Test("TONBase64.from decodes valid base64 string")
    func base64FromValid() throws {
        let jsValue = makeJSValue("SGVsbG8=") // "Hello"
        let base64 = try #require(try TONBase64.from(jsValue))
        #expect(base64.value == "SGVsbG8=")
        #expect(base64.data == Data("Hello".utf8))
    }

    @Test("TONBase64.from throws for invalid base64 string")
    func base64FromInvalidString() {
        let jsValue = makeJSValue("not_valid_base64!!!")
        #expect(throws: (any Error).self) {
            try TONBase64.from(jsValue)
        }
    }

    @Test("TONBase64.from throws for undefined JSValue")
    func base64FromUndefined() {
        let jsValue = JSValue(undefinedIn: context)!
        #expect(throws: (any Error).self) {
            let _: TONBase64 = try jsValue.decode()
        }
    }
}
