//
//  ArrayTests.swift
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

@Suite("Array Safe Subscript Tests")
struct ArraySafeSubscriptTests {

    private let array = ["a", "b", "c"]

    @Test("Safe Int subscript returns element for valid index")
    func safeIntValid() {
        #expect(array[safe: 0] == "a")
        #expect(array[safe: 1] == "b")
        #expect(array[safe: 2] == "c")
    }

    @Test("Safe Int subscript returns nil for out-of-bounds index")
    func safeIntOutOfBounds() {
        #expect(array[safe: 3] == nil)
        #expect(array[safe: 100] == nil)
    }

    @Test("Safe Int subscript returns nil for negative index")
    func safeIntNegative() {
        #expect(array[safe: -1] == nil)
    }

    @Test("Safe Int subscript returns nil for empty array")
    func safeIntEmptyArray() {
        let empty: [Int] = []
        #expect(empty[safe: 0] == nil)
    }

    @Test("Safe UInt subscript returns element for valid index")
    func safeUIntValid() {
        #expect(array[safe: UInt(0)] == "a")
        #expect(array[safe: UInt(2)] == "c")
    }

    @Test("Safe UInt subscript returns nil for out-of-bounds index")
    func safeUIntOutOfBounds() {
        #expect(array[safe: UInt(3)] == nil)
        #expect(array[safe: UInt(100)] == nil)
    }

    @Test("Safe UInt subscript returns nil for empty array")
    func safeUIntEmptyArray() {
        let empty: [Int] = []
        #expect(empty[safe: UInt(0)] == nil)
    }
}
