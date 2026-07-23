//
//  DataTests.swift
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
@testable import TONWalletKit

@Suite("Data Extensions Tests")
struct DataExtensionsTests {

    // MARK: - hex

    @Test("hex returns lowercase hex string")
    func hexString() {
        let data = Data([0xde, 0xad, 0xbe, 0xef])
        #expect(data.hex == "deadbeef")
    }

    @Test("hex returns empty string for empty data")
    func hexEmpty() {
        #expect(Data().hex == "")
    }

    @Test("hex pads single-digit bytes with zero")
    func hexPadding() {
        let data = Data([0x00, 0x01, 0x0f])
        #expect(data.hex == "00010f")
    }

    // MARK: - hexWithPrefix

    @Test("hexWithPrefix prepends 0x")
    func hexWithPrefix() {
        let data = Data([0xca, 0xfe])
        #expect(data.hexWithPrefix == "0xcafe")
    }

    @Test("hexWithPrefix returns 0x for empty data")
    func hexWithPrefixEmpty() {
        #expect(Data().hexWithPrefix == "0x")
    }

    // MARK: - init(hex:)

    @Test("init(hex:) parses valid hex string")
    func initHexValid() throws {
        let data = try #require(Data(hex: "deadbeef"))
        #expect(data == Data([0xde, 0xad, 0xbe, 0xef]))
    }

    @Test("init(hex:) parses hex string with 0x prefix")
    func initHexWithPrefix() throws {
        let data = try #require(Data(hex: "0xcafe"))
        #expect(data == Data([0xca, 0xfe]))
    }

    @Test("init(hex:) returns nil for odd-length string")
    func initHexOddLength() {
        #expect(Data(hex: "abc") == nil)
    }

    @Test("init(hex:) returns nil for invalid hex characters")
    func initHexInvalidChars() {
        #expect(Data(hex: "zzzz") == nil)
    }

    @Test("init(hex:) returns empty data for empty string")
    func initHexEmpty() throws {
        let data = try #require(Data(hex: ""))
        #expect(data.isEmpty)
    }

    @Test("init(hex:) roundtrips with hex property")
    func initHexRoundtrip() throws {
        let original = Data([0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef])
        let roundtripped = try #require(Data(hex: original.hex))
        #expect(roundtripped == original)
    }

    // MARK: - base64URL

    @Test("init(base64URLEncoded:) decodes URL-safe base64")
    func initBase64URLValid() throws {
        // Standard base64: "a+b/c==" -> URL-safe: "a-b_c=="
        let standard = Data(base64Encoded: "a+b/cw==")!
        let urlSafe = try #require(Data(base64URLEncoded: "a-b_cw=="))
        #expect(urlSafe == standard)
    }

    @Test("init(base64URLEncoded:) returns nil for invalid input")
    func initBase64URLInvalid() {
        #expect(Data(base64URLEncoded: "%%%") == nil)
    }

    @Test("base64URLEncodedString replaces + and / with URL-safe chars")
    func base64URLEncodedString() {
        let data = Data(base64Encoded: "a+b/cw==")!
        let urlSafe = data.base64URLEncodedString()
        #expect(!urlSafe.contains("+"))
        #expect(!urlSafe.contains("/"))
        #expect(urlSafe == "a-b_cw==")
    }

    @Test("base64URL roundtrips correctly")
    func base64URLRoundtrip() throws {
        let original = Data([0x6b, 0xe6, 0xbf, 0x73])
        let encoded = original.base64URLEncodedString()
        let decoded = try #require(Data(base64URLEncoded: encoded))
        #expect(decoded == original)
    }
}
