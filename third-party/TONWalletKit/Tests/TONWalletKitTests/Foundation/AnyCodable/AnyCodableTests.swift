//
//  AnyCodableTests.swift
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

@Suite("AnyCodable Tests")
struct AnyCodableTests {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Encoding

    @Test("Encodes string value")
    func encodeString() throws {
        let value = AnyCodable("hello")
        let json = try encoder.encode(value)
        #expect(String(data: json, encoding: .utf8) == "\"hello\"")
    }

    @Test("Encodes integer value")
    func encodeInt() throws {
        let value = AnyCodable(42)
        let json = try encoder.encode(value)
        #expect(String(data: json, encoding: .utf8) == "42")
    }

    @Test("Encodes boolean value")
    func encodeBool() throws {
        let value = AnyCodable(true)
        let json = try encoder.encode(value)
        #expect(String(data: json, encoding: .utf8) == "true")
    }

    @Test("Encodes nil as null")
    func encodeNil() throws {
        let value: AnyCodable = nil
        let json = try encoder.encode(value)
        #expect(String(data: json, encoding: .utf8) == "null")
    }

    @Test("Encodes double value")
    func encodeDouble() throws {
        let value = AnyCodable(3.14)
        let json = try encoder.encode(value)
        let decoded = try decoder.decode(Double.self, from: json)
        #expect(decoded == 3.14)
    }

    // MARK: - Decoding

    @Test("Decodes string from JSON")
    func decodeString() throws {
        let json = Data("\"hello\"".utf8)
        let value = try decoder.decode(AnyCodable.self, from: json)
        #expect(value.value as? String == "hello")
    }

    @Test("Decodes integer from JSON")
    func decodeInt() throws {
        let json = Data("42".utf8)
        let value = try decoder.decode(AnyCodable.self, from: json)
        #expect(value.value as? Int == 42)
    }

    @Test("Decodes boolean from JSON")
    func decodeBool() throws {
        let json = Data("true".utf8)
        let value = try decoder.decode(AnyCodable.self, from: json)
        #expect(value.value as? Bool == true)
    }

    @Test("Decodes null from JSON")
    func decodeNull() throws {
        let json = Data("null".utf8)
        let value = try decoder.decode(AnyCodable.self, from: json)
        #expect(value.value is NSNull)
    }

    @Test("Decodes array from JSON")
    func decodeArray() throws {
        let json = Data("[1,2,3]".utf8)
        let value = try decoder.decode(AnyCodable.self, from: json)
        let array = try #require(value.value as? [Any])
        #expect(array.count == 3)
    }

    @Test("Decodes dictionary from JSON")
    func decodeDictionary() throws {
        let json = Data("{\"key\":\"value\"}".utf8)
        let value = try decoder.decode(AnyCodable.self, from: json)
        let dict = try #require(value.value as? [String: Any])
        #expect(dict["key"] as? String == "value")
    }

    // MARK: - Roundtrip

    @Test("Roundtrip encode/decode preserves nested structure")
    func roundtripNested() throws {
        let json = Data("{\"name\":\"test\",\"count\":42,\"active\":true}".utf8)
        let decoded = try decoder.decode(AnyCodable.self, from: json)
        let reencoded = try encoder.encode(decoded)
        let redecoded = try decoder.decode(AnyCodable.self, from: reencoded)
        #expect(decoded == redecoded)
    }

    // MARK: - Equatable

    @Test("Equal values are equal")
    func equalValues() {
        #expect(AnyCodable("hello") == AnyCodable("hello"))
        #expect(AnyCodable(42) == AnyCodable(42))
        #expect(AnyCodable(true) == AnyCodable(true))
    }

    @Test("Different values are not equal")
    func differentValues() {
        #expect(AnyCodable("hello") != AnyCodable("world"))
        #expect(AnyCodable(42) != AnyCodable(99))
    }

    @Test("Nil values are equal")
    func nilEquality() {
        let a: AnyCodable = nil
        let b: AnyCodable = nil
        #expect(a == b)
    }

    // MARK: - ExpressibleByLiteral

    @Test("ExpressibleByStringLiteral")
    func stringLiteral() {
        let value: AnyCodable = "hello"
        #expect(value.value as? String == "hello")
    }

    @Test("ExpressibleByIntegerLiteral")
    func integerLiteral() {
        let value: AnyCodable = 42
        #expect(value.value as? Int == 42)
    }

    @Test("ExpressibleByBooleanLiteral")
    func booleanLiteral() {
        let value: AnyCodable = true
        #expect(value.value as? Bool == true)
    }

    @Test("ExpressibleByFloatLiteral")
    func floatLiteral() {
        let value: AnyCodable = 3.14
        #expect(value.value as? Double == 3.14)
    }

    @Test("ExpressibleByNilLiteral")
    func nilLiteral() {
        let value: AnyCodable = nil
        #expect(value.value is Void)
    }

    @Test("ExpressibleByArrayLiteral")
    func arrayLiteral() {
        let value: AnyCodable = [1, "two", true]
        #expect(value.value is [Any])
    }

    @Test("ExpressibleByDictionaryLiteral")
    func dictionaryLiteral() {
        let value: AnyCodable = ["key": "value"]
        #expect(value.value is [AnyHashable: Any])
    }

    // MARK: - Description

    @Test("Description returns string representation")
    func descriptionTest() {
        #expect(AnyCodable("hello").description == "hello")
        #expect(AnyCodable(42).description == "42")
    }

    @Test("DebugDescription wraps in AnyCodable()")
    func debugDescriptionTest() {
        let value = AnyCodable("hello")
        #expect(value.debugDescription.contains("AnyCodable"))
    }
}
