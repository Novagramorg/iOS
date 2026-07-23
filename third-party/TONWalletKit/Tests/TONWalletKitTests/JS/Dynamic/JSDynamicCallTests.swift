//
//  JSDynamicCallTests.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 24.10.2025.
//
//  Copyright (c) 2025 TON Connect
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

@Suite("JSContext function calls wrappers tests")
struct JSDynamicCallTests {
    
    private func context() -> JSContext {
        let context = JSContext()!
        
        let script = """
        
        function _testPromiseFunctionSuccess(value) {
            return new Promise((resolve, reject) => {
                resolve(value);
            });
        }
        
        function _testPromiseFunctionFailure(errorMessage) {
            return new Promise((resolve, reject) => {
                reject(new Error(errorMessage));
            });
        }
        
        function _testPromiseFunctionNativeSuccess(value) {
            return value;
        }
        
        function _testPromiseFunctionNativeFailure(errorMessage) {
            throw new Error(errorMessage);
        }
        
        """
        
        context.evaluateScript(script)
        return context
    }
    
    @Test("Check Promise Wrapper")
    func testFunctionsCorrectlyWrappedToPromise() async throws {
        let context = self.context()
        
        let testPromiseFunctionSuccess = JSFunction(
            parent: context,
            value: context.objectForKeyedSubscript("_testPromiseFunctionSuccess")
        )
        let testPromiseFunctionFailure = JSFunction(
            parent: context,
            value: context.objectForKeyedSubscript("_testPromiseFunctionFailure")
        )
        let testPromiseFunctionNativeSuccess = JSFunction(
            parent: context,
            value: context.objectForKeyedSubscript("_testPromiseFunctionNativeSuccess")
        )
        let testPromiseFunctionNativeFailure = JSFunction(
            parent: context,
            value: context.objectForKeyedSubscript("_testPromiseFunctionNativeFailure")
        )
        
        let testPromiseFunctionSuccessResult = try context.promise(wrap: testPromiseFunctionSuccess, args: ["success"])
        let testPromiseFunctionFailureResult = try context.promise(wrap: testPromiseFunctionFailure, args: ["failure"])
        let testPromiseFunctionNativeSuccessResult = try context.promise(wrap: testPromiseFunctionNativeSuccess, args: ["native success"])
        let testPromiseFunctionNativeFailureResult = try context.promise(wrap: testPromiseFunctionNativeFailure, args: ["native failure"])
    
        #expect(testPromiseFunctionSuccessResult.isPromise == true)
        #expect(testPromiseFunctionFailureResult.isPromise == true)
        #expect(testPromiseFunctionNativeSuccessResult.isPromise == true)
        #expect(testPromiseFunctionNativeFailureResult.isPromise == true)
        #expect(try await testPromiseFunctionSuccessResult.then().toString() == "success")
        await #expect(throws: JSError.self) {
            try await testPromiseFunctionFailureResult.then()
        }
        #expect(try await testPromiseFunctionNativeSuccessResult.then().toString() == "native success")
        await #expect(throws: JSError.self) {
            try await testPromiseFunctionNativeFailureResult.then()
        }
    }
    
    @Test("Check Error Throw Wrapper")
    func testFunctionsCorrectlyWrappedErrorThrow() async throws {
        let context = self.context()
        
        let testPromiseFunctionSuccess = JSFunction(
            parent: context,
            value: context.objectForKeyedSubscript("_testPromiseFunctionSuccess")
        )
        let testPromiseFunctionFailure = JSFunction(
            parent: context,
            value: context.objectForKeyedSubscript("_testPromiseFunctionFailure")
        )
        let testPromiseFunctionNativeSuccess = JSFunction(
            parent: context,
            value: context.objectForKeyedSubscript("_testPromiseFunctionNativeSuccess")
        )
        let testPromiseFunctionNativeFailure = JSFunction(
            parent: context,
            value: context.objectForKeyedSubscript("_testPromiseFunctionNativeFailure")
        )
        
        let testPromiseFunctionSuccessResult = try context.throwErrorToReturn(wrap: testPromiseFunctionSuccess, args: ["success"])
        let testPromiseFunctionFailureResult = try context.throwErrorToReturn(wrap: testPromiseFunctionFailure, args: ["failure"])
        let testPromiseFunctionNativeSuccessResult = try context.throwErrorToReturn(wrap: testPromiseFunctionNativeSuccess, args: ["native success"])
    
        #expect(testPromiseFunctionSuccessResult.isPromise == true)
        #expect(testPromiseFunctionFailureResult.isPromise == true)
        #expect(testPromiseFunctionNativeSuccessResult.isPromise == false)
        
        #expect(try await testPromiseFunctionSuccessResult.then().toString() == "success")
        await #expect(throws: JSError.self) {
            try await testPromiseFunctionFailureResult.then()
        }
        #expect(testPromiseFunctionNativeSuccessResult.toString() == "native success")
        #expect(throws: JSError.self) {
            try context.throwErrorToReturn(wrap: testPromiseFunctionNativeFailure, args: ["native failure"])
        }
    }
    
    @Test("Check synchronous dynamic calls")
    func testSyncDynamicCall() throws {
        let context = self.context()
        
        #expect(throws: JSError.self) {
            try context._testPromiseFunctionSuccess("value")
        }
        
        #expect(throws: JSError.self) {
            try context._testPromiseFunctionFailure("value")
        }
        
        #expect(throws: JSError.self) {
            let _: String = try context._testPromiseFunctionSuccess("value")
        }
        
        #expect(throws: JSError.self) {
            let _: String = try context._testPromiseFunctionFailure("value")
        }
        
        #expect(try context._testPromiseFunctionNativeSuccess("value") == "value")
        
        #expect(throws: JSError.self) {
            let _: String = try context._testPromiseFunctionNativeFailure("value")
        }
    }
    
    @Test("Check asynchronous dynamic calls")
    func testAsyncDynamicCall() async throws {
        let context = self.context()
        
        #expect(try await context._testPromiseFunctionSuccess("value") == "value")

        await #expect(throws: JSError.self) {
            try await context._testPromiseFunctionFailure("value")
        }
        
        await #expect(throws: JSError.self) {
            let _: String = try await context._testPromiseFunctionFailure("value")
        }
        
        #expect(try await context._testPromiseFunctionNativeSuccess("value") == "value")
        
        await #expect(throws: JSError.self) {
            try await context._testPromiseFunctionNativeFailure("value")
        }
        
        #expect(throws: JSError.self) {
            let _: String = try context._testPromiseFunctionNativeFailure("value")
        }
    }
}
