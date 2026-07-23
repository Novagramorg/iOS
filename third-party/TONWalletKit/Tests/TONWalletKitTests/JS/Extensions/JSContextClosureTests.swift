//
//  JSContextClosureTests.swift
//  TONWalletKit
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

@Suite("JSContext.closure Tests")
struct JSContextClosureTests {

    @Test("closure(_:) is callable from JS when passed as an argument to a JS function")
    func closurePassedAsArgumentIsCallableFromJS() {
        let context = JSContext()!
        context.evaluateScript("""
            globalThis.__closureType = null;
            globalThis.__closureCallCount = 0;
            function takeClosure(fn) {
                globalThis.__closureType = typeof fn;
                fn('hello from js');
                globalThis.__closureCallCount += 1;
            }
        """)

        var received: String?
        let closure = context.closure { (value: String) in
            received = value
        }

        let takeClosure = context.objectForKeyedSubscript("takeClosure")!
        takeClosure.call(withArguments: [closure])

        let typeofResult = context.evaluateScript("globalThis.__closureType")?.toString()
        let callCount = context.evaluateScript("globalThis.__closureCallCount")?.toInt32()

        #expect(typeofResult == "function", "JS must see closure argument as a callable function, got: \(typeofResult ?? "nil")")
        #expect(callCount == 1, "JS should have invoked the closure argument exactly once")
        #expect(received == "hello from js")
    }

    @Test("closure(_:) passed as an argument skips the Swift block when JS argument cannot decode to T")
    func closurePassedAsArgumentSkipsBlockOnDecodeFailure() {
        let context = JSContext()!
        context.evaluateScript("""
            globalThis.__closureType = null;
            globalThis.__closureCallCount = 0;
            function takeClosure(fn) {
                globalThis.__closureType = typeof fn;
                fn(undefined);
                globalThis.__closureCallCount += 1;
                fn(42);
                globalThis.__closureCallCount += 1;
            }
        """)

        var swiftCallCount = 0
        let closure = context.closure { (_: String) in
            swiftCallCount += 1
        }

        let takeClosure = context.objectForKeyedSubscript("takeClosure")!
        takeClosure.call(withArguments: [closure])

        let typeofResult = context.evaluateScript("globalThis.__closureType")?.toString()
        let jsCallCount = context.evaluateScript("globalThis.__closureCallCount")?.toInt32()

        #expect(typeofResult == "function", "JS must see closure argument as a callable function, got: \(typeofResult ?? "nil")")
        #expect(jsCallCount == 2, "JS should have invoked the closure argument twice")
        #expect(swiftCallCount == 0, "Swift block must be skipped when decoding fails")
    }

    @Test("closure(_:) passed as an argument can be invoked multiple times from JS")
    func closurePassedAsArgumentInvokedMultipleTimes() {
        let context = JSContext()!
        context.evaluateScript("""
            globalThis.__closureType = null;
            globalThis.__closureCallCount = 0;
            function takeClosure(fn) {
                globalThis.__closureType = typeof fn;
                fn('first');
                globalThis.__closureCallCount += 1;
                fn('second');
                globalThis.__closureCallCount += 1;
                fn('third');
                globalThis.__closureCallCount += 1;
            }
        """)

        var received: [String] = []
        let closure = context.closure { (value: String) in
            received.append(value)
        }

        let takeClosure = context.objectForKeyedSubscript("takeClosure")!
        takeClosure.call(withArguments: [closure])

        let typeofResult = context.evaluateScript("globalThis.__closureType")?.toString()
        let jsCallCount = context.evaluateScript("globalThis.__closureCallCount")?.toInt32()

        #expect(typeofResult == "function", "JS must see closure argument as a callable function, got: \(typeofResult ?? "nil")")
        #expect(jsCallCount == 3, "JS should have invoked the closure argument three times")
        #expect(received == ["first", "second", "third"])
    }
}
