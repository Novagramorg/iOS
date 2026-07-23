//
//  WeakValueWrapperTests.swift
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

@Suite("WeakValueWrapper Tests")
struct WeakValueWrapperTests {

    private class TestObject {}

    // MARK: - AnyWeakValueWrapper

    @Test("AnyWeakValueWrapper holds reference to live object")
    func anyWrapperHoldsReference() {
        let object = TestObject()
        let wrapper = AnyWeakValueWrapper(value: object)
        #expect(wrapper.value === object)
    }

    @Test("AnyWeakValueWrapper becomes nil when object is deallocated")
    func anyWrapperBecomesNil() {
        var object: TestObject? = TestObject()
        let wrapper = AnyWeakValueWrapper(value: object!)
        object = nil
        #expect(wrapper.value == nil)
    }

    // MARK: - WeakValueWrapper

    @Test("WeakValueWrapper holds reference to live object")
    func typedWrapperHoldsReference() {
        let object = TestObject()
        let wrapper = WeakValueWrapper(value: object)
        #expect(wrapper.value === object)
    }

    @Test("WeakValueWrapper becomes nil when object is deallocated")
    func typedWrapperBecomesNil() {
        var object: TestObject? = TestObject()
        let wrapper = WeakValueWrapper(value: object!)
        object = nil
        #expect(wrapper.value == nil)
    }
}
