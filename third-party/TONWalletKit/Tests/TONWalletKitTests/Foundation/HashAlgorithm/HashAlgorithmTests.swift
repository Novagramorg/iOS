//
//  HashAlgorithmTests.swift
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
@testable import TONWalletKit

@Suite("HashAlgorithm Tests")
struct HashAlgorithmTests {

    @Test("Raw values match expected strings",
          arguments: [
            ("MD5", HashAlgorithm.md5),
            ("SHA1", HashAlgorithm.sha1),
            ("SHA224", HashAlgorithm.sha224),
            ("SHA256", HashAlgorithm.sha256),
            ("SHA384", HashAlgorithm.sha384),
            ("SHA512", HashAlgorithm.sha512)
          ])
    func rawValues(rawValue: String, expected: HashAlgorithm) {
        #expect(HashAlgorithm(rawValue: rawValue) == expected)
    }

    @Test("init(algorithm:) parses hyphenated names",
          arguments: [
            ("SHA-1", HashAlgorithm.sha1),
            ("SHA-256", HashAlgorithm.sha256),
            ("SHA-384", HashAlgorithm.sha384),
            ("SHA-512", HashAlgorithm.sha512)
          ])
    func initWithHyphenatedNames(input: String, expected: HashAlgorithm) {
        #expect(HashAlgorithm(algorithm: input) == expected)
    }

    @Test("init(algorithm:) is case insensitive",
          arguments: ["sha-256", "Sha-256", "SHA-256", "sha256"])
    func initCaseInsensitive(input: String) {
        #expect(HashAlgorithm(algorithm: input) == .sha256)
    }

    @Test("init(algorithm:) returns nil for unknown algorithm")
    func initUnknown() {
        #expect(HashAlgorithm(algorithm: "UNKNOWN") == nil)
    }
}
