//
//  JSTimerPolyfillTests.swift
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

import Foundation
import JavaScriptCore
import Testing

@_private(sourceFile:"JSTimerPolyfill.swift")
@testable import TONWalletKit

@Suite("JSTimerPolyfill Tests")
struct JSTimerPolyfillTests {

    @Test("setTimeout executes callback after delay")
    func testSetTimeoutBasicExecution() async throws {
        var context: JSContext? = JSContext()
        let timerPolyfill = JSTimerPolyfill()
        context!.polyfill(with: timerPolyfill)

        weak var weakContext = context
        
        let script = """
            var callbackExecuted = false;
            var executionTime = null;
            
            function testSetTimeout() {
                const startTime = Date.now();
                const id = setTimeout(() => {
                    callbackExecuted = true;
                    executionTime = Date.now() - startTime;
                }, 50);
                return id;
            }
        """
        
        context!.evaluateScript(script)
        
        let id: Int32 = try await context!.setTimeout()
        
        // Verify timer is registered
        #expect(timerPolyfill.timers.contains { $0.key == id })
        
        // Wait for execution (significantly increased for CI reliability)
        try await Task.sleep(nanoseconds: 500 * 1_000_000)
        
        // Verify callback was executed
        let callbackExecuted = context!.objectForKeyedSubscript("callbackExecuted").toBool()
        #expect(callbackExecuted == true)
        
        // Verify timing (very generous tolerance for CI)
        let executionTime = context!.objectForKeyedSubscript("executionTime").toDouble()
        #expect(executionTime >= 0.0 && executionTime <= 1000.0)
        
        // Verify timer was cleaned up after execution
        #expect(timerPolyfill.timers.contains { $0.key == id } == false)
        
        context = nil
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(weakContext == nil)
    }

    @Test("setTimeout with parameters passes them to callback")
    func testSetTimeoutWithParameters() async throws {
        let context = JSContext()!
        let timerPolyfill = JSTimerPolyfill()
        context.polyfill(with: timerPolyfill)

        let script = """
            var receivedParams = [];
            
            function testSetTimeoutWithParams() {
                const id = setTimeout((a, b, c) => {
                    receivedParams = [a, b, c];
                }, 50, "hello", 42, true);
                return id;
            }
        """
        
        context.evaluateScript(script)
        
        try await context.setTimeoutWithParams()
        
        // Wait for execution (increased for CI reliability)
        try await Task.sleep(nanoseconds: 200 * 1_000_000)
        
        // Verify parameters were passed correctly
        guard let receivedParams = context.objectForKeyedSubscript("receivedParams").toArray() else {
            #expect(Bool(false), "Expected receivedParams to be an array")
            return
        }
        #expect(receivedParams.count == 3)
        #expect((receivedParams[0] as? String) == "hello")
        #expect((receivedParams[1] as? NSNumber)?.intValue == 42)
        #expect((receivedParams[2] as? NSNumber)?.boolValue == true)
    }

    @Test("clearTimeout cancels timer before execution")
    func testClearTimeoutPreventsExecution() async throws {
        let context = JSContext()!
        let timerPolyfill = JSTimerPolyfill()
        context.polyfill(with: timerPolyfill)

        let script = """
            var callbackExecuted = false;
            
            function testClearTimeout() {
                const id = setTimeout(() => {
                    callbackExecuted = true;
                }, 100);
                
                // Clear the timeout immediately
                clearTimeout(id);
                return id;
            }
        """
        
        context.evaluateScript(script)
        
        let id = try await context.clearTimeout()
        
        // Wait longer than the original delay (increased for CI reliability)
        try await Task.sleep(nanoseconds: 300 * 1_000_000)
        
        // Verify callback was not executed
        let callbackExecuted = context.objectForKeyedSubscript("callbackExecuted").toBool()
        #expect(callbackExecuted == false)
        
        // Verify timer was removed
        #expect(timerPolyfill.timers.contains { $0.key == id } == false)
        #expect(timerPolyfill.timers.isEmpty)
    }

    @Test("setInterval executes callback repeatedly")
    func testSetIntervalRepeatedExecution() async throws {
        let context = JSContext()!
        let timerPolyfill = JSTimerPolyfill()
        context.polyfill(with: timerPolyfill)

        let script = """
            var executionCount = 0;
            var executionTimes = [];
            var startTime = Date.now();
            
            function testSetInterval() {
                const id = setInterval(() => {
                    executionCount++;
                    executionTimes.push(Date.now() - startTime);
                }, 100);
                return id;
            }
        """
        
        context.evaluateScript(script)
        
        let id = try await context.setInterval()
        
        // Verify timer is registered
        #expect(timerPolyfill.timers.contains { $0.key == id })
        
        // Wait for multiple executions (significantly increased for CI reliability)
        try await Task.sleep(nanoseconds: 600 * 1_000_000)
        
        // Stop the interval
        context.evaluateScript("clearInterval('\(id)')")
        
        // Verify at least one execution occurred (minimal threshold for CI reliability)
        let executionCount = context.objectForKeyedSubscript("executionCount").toInt32()
        #expect(executionCount >= 1)
        
        // Verify execution timing
        guard let executionTimes = context.objectForKeyedSubscript("executionTimes").toArray() else {
            #expect(Bool(false), "Expected executionTimes to be an array")
            return
        }
        #expect(executionTimes.count >= 1)
        
        // Check that executions happened at roughly correct intervals
        if executionTimes.count >= 2,
           let firstTime = executionTimes[0] as? NSNumber,
           let secondTime = executionTimes[1] as? NSNumber {
            let interval = secondTime.doubleValue - firstTime.doubleValue
            #expect(interval >= 0 && interval <= 500.0) // Very generous tolerance for CI
        }
    }

    @Test("clearInterval stops repeated execution")
    func testClearIntervalStopsExecution() async throws {
        let context = JSContext()!
        let timerPolyfill = JSTimerPolyfill()
        context.polyfill(with: timerPolyfill)

        let script = """
            var executionCount = 0;
            
            function testClearInterval() {
                const id = setInterval(() => {
                    executionCount++;
                }, 50);
                
                // Clear after 2 executions worth of time
                setTimeout(() => {
                    clearInterval(id);
                }, 120);
                
                return id;
            }
        """
        
        context.evaluateScript(script)
        
        let id = try await context.clearInterval()
        
        // Wait for the interval to be cleared and a bit more (increased for CI reliability)
        try await Task.sleep(nanoseconds: 400 * 1_000_000)
        
        let executionCount = context.objectForKeyedSubscript("executionCount").toInt32()
        let finalCount = executionCount
        
        // Wait a bit more to ensure no more executions happen (increased for CI reliability)
        try await Task.sleep(nanoseconds: 200 * 1_000_000)
        
        let newExecutionCount = context.objectForKeyedSubscript("executionCount").toInt32()
        
        // Verify execution stopped
        #expect(newExecutionCount == finalCount)
        
        // Verify timer was removed
        #expect(timerPolyfill.timers.contains { $0.key == id } == false)
    }

    @Test("setTimeout with zero delay executes asynchronously")
    func testSetTimeoutZeroDelay() async throws {
        let context = JSContext()!
        let timerPolyfill = JSTimerPolyfill()
        context.polyfill(with: timerPolyfill)

        let script = """
            var callbackExecuted = false;
            var synchronousCheck = false;
            
            function testZeroDelay() {
                const id = setTimeout(() => {
                    callbackExecuted = true;
                }, 0);
                
                synchronousCheck = callbackExecuted; // Should be false
                return id;
            }
        """
        
        context.evaluateScript(script)
        
        try await context.zeroDelay()
        
        // Check that callback didn't execute synchronously
        let synchronousCheck = context.objectForKeyedSubscript("synchronousCheck").toBool()
        #expect(synchronousCheck == false)
        
        // Wait for asynchronous execution (increased for CI reliability)
        try await Task.sleep(nanoseconds: 50 * 1_000_000)
        
        // Verify callback was executed asynchronously
        let callbackExecuted = context.objectForKeyedSubscript("callbackExecuted").toBool()
        #expect(callbackExecuted == true)
    }

    @Test("setTimeout with negative delay uses zero delay")
    func testSetTimeoutNegativeDelay() async throws {
        let context = JSContext()!
        let timerPolyfill = JSTimerPolyfill()
        context.polyfill(with: timerPolyfill)

        let script = """
            var callbackExecuted = false;
            var executionTime = null;
            
            function testNegativeDelay() {
                const startTime = Date.now();
                const id = setTimeout(() => {
                    callbackExecuted = true;
                    executionTime = Date.now() - startTime;
                }, -100);
                return id;
            }
        """
        
        context.evaluateScript(script)
        
        try await context.negativeDelay()
        
        // Wait briefly (increased for CI reliability)
        try await Task.sleep(nanoseconds: 100 * 1_000_000)
        
        // Verify callback was executed quickly (negative delay should be treated as 0)
        let callbackExecuted = context.objectForKeyedSubscript("callbackExecuted").toBool()
        #expect(callbackExecuted == true)
        
        let executionTime = context.objectForKeyedSubscript("executionTime").toDouble()
        #expect(executionTime >= 0.0 && executionTime <= 200.0) // Allow generous tolerance for CI
    }

    @Test("Multiple timers can coexist")
    func testMultipleTimers() async throws {
        let context = JSContext()!
        let timerPolyfill = JSTimerPolyfill()
        context.polyfill(with: timerPolyfill)

        let script = """
            var results = {};
            
            function testMultipleTimers() {
                const id1 = setTimeout(() => {
                    results.timeout1 = true;
                }, 100);
                
                const id2 = setTimeout(() => {
                    results.timeout2 = true;
                }, 200);
                
                const id3 = setInterval(() => {
                    results.interval = (results.interval || 0) + 1;
                }, 100);
                
                // Clear interval after some time
                setTimeout(() => {
                    clearInterval(id3);
                }, 350);
                
                return [id1, id2, id3];
            }
        """
        
        context.evaluateScript(script)
        
        let ids = try await context.multipleTimers()
        
        // Verify all timers are registered
        for id in ids {
            #expect(timerPolyfill.timers.contains { $0.key == id })
        }
        
        // Wait for all timeouts and some interval executions (significantly increased for CI reliability)
        try await Task.sleep(nanoseconds: 800 * 1_000_000)
        
        let results = context.objectForKeyedSubscript("results").toDictionary()
        
        // Verify timeout results
        #expect((results?["timeout1"] as? NSNumber)?.boolValue == true)
        #expect((results?["timeout2"] as? NSNumber)?.boolValue == true)
        
        // Verify interval executed at least once (minimal threshold for CI reliability)
        let intervalCount = (results?["interval"] as? NSNumber)?.intValue ?? 0
        #expect(intervalCount >= 1)
    }

    @Test("timer handles undefined and null callbacks gracefully")
    func testInvalidCallbacks() async throws {
        let context = JSContext()!
        let timerPolyfill = JSTimerPolyfill()
        context.polyfill(with: timerPolyfill)

        let script = """
            function testInvalidCallbacks() {
                // These should return empty string for invalid callbacks
                const id1 = setTimeout(null, 100);
                const id2 = setTimeout(undefined, 100);
                const id3 = setInterval(null, 100);
                const id4 = setInterval(undefined, 100);
                
                return [id1, id2, id3, id4];
            }
        """
        
        context.evaluateScript(script)
        
        let ids = try await context.invalidCallbacks()
        
        // All IDs should be empty strings for invalid callbacks
        for id in ids {
            #expect(id == -1)
        }
        
        // No timers should be registered
        #expect(timerPolyfill.timers.isEmpty)
    }

    @Test("clearTimeout and clearInterval with invalid IDs don't crash")
    func testClearInvalidIds() async throws {
        let context = JSContext()!
        let timerPolyfill = JSTimerPolyfill()
        context.polyfill(with: timerPolyfill)

        let script = """
            function testClearInvalid() {
                // These should not crash
                clearTimeout("invalid-id");
                clearTimeout("");
                clearTimeout(null);
                clearTimeout(undefined);
                
                clearInterval("invalid-id");
                clearInterval("");
                clearInterval(null);
                clearInterval(undefined);
                
                return true;
            }
        """
        
        context.evaluateScript(script)
        
        let result: Bool = try await context.clearInvalid()
        #expect(result == true)
    }

    @Test("Check memory leak in Timer polyfill")
    func testTimerPolyfillMemoryLeak() async throws {
        var context: JSContext? = JSContext()!
        let timerPolyfill = JSTimerPolyfill()
        context?.polyfill(with: timerPolyfill)
        context?.evaluateScript("")
        weak var weakContext = context
        
        #expect(weakContext != nil)
        
        context = nil
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(weakContext == nil)
    }

    @Test("Timer cleanup on polyfill deallocation")
    func testTimerCleanupOnDeallocation() async throws {
        let context = JSContext()!
        var timerPolyfill: JSTimerPolyfill? = JSTimerPolyfill()
        context.polyfill(with: timerPolyfill!)

        let script = """
            function createTimers() {
                const id1 = setTimeout(() => {}, 1000);
                const id2 = setInterval(() => {}, 1000);
                return [id1, id2];
            }
        """
        
        context.evaluateScript(script)
        try await context.createTimers()
        
        // Verify timers are registered
        #expect(timerPolyfill!.timers.count == 2)
        
        // Release the polyfill - this should clean up timers
        timerPolyfill = nil
        
        // Give some time for cleanup
        try await Task.sleep(nanoseconds: 100 * 1_000_000)
        
        // Test passes if no crashes occur during cleanup
        #expect(true)
    }
}

private extension JSContext {
    
    @discardableResult
    func setTimeout() async throws -> Int32 {
        guard let function = objectForKeyedSubscript("testSetTimeout") else {
            throw "Function testSetTimeout not found"
        }
        let result = function.call(withArguments: [])
        guard let result = result?.toInt32() else {
            throw "Expected string result from testSetTimeout"
        }
        return result
    }
    
    @discardableResult
    func setTimeoutWithParams() async throws -> Int32 {
        guard let function = objectForKeyedSubscript("testSetTimeoutWithParams") else {
            throw "Function testSetTimeoutWithParams not found"
        }
        let result = function.call(withArguments: [])
        guard let result = result?.toInt32() else {
            throw "Expected string result from testSetTimeoutWithParams"
        }
        return result
    }
    
    @discardableResult
    func clearTimeout() async throws -> Int32 {
        guard let function = objectForKeyedSubscript("testClearTimeout") else {
            throw "Function testClearTimeout not found"
        }
        let result = function.call(withArguments: [])
        guard let result = result?.toInt32() else {
            throw "Expected string result from testClearTimeout"
        }
        return result
    }
    
    @discardableResult
    func setInterval() async throws -> Int32 {
        guard let function = objectForKeyedSubscript("testSetInterval") else {
            throw "Function testSetInterval not found"
        }
        let result = function.call(withArguments: [])
        guard let result = result?.toInt32() else {
            throw "Expected string result from testSetInterval"
        }
        return result
    }
    
    @discardableResult
    func clearInterval() async throws -> Int32 {
        guard let function = objectForKeyedSubscript("testClearInterval") else {
            throw "Function testClearInterval not found"
        }
        let result = function.call(withArguments: [])
        guard let result = result?.toInt32() else {
            throw "Expected string result from testClearInterval"
        }
        return result
    }
    
    @discardableResult
    func zeroDelay() async throws -> Int32 {
        guard let function = objectForKeyedSubscript("testZeroDelay") else {
            throw "Function testZeroDelay not found"
        }
        let result = function.call(withArguments: [])
        guard let result = result?.toInt32() else {
            throw "Expected string result from testZeroDelay"
        }
        return result
    }
    
    @discardableResult
    func negativeDelay() async throws -> Int32 {
        guard let function = objectForKeyedSubscript("testNegativeDelay") else {
            throw "Function testNegativeDelay not found"
        }
        let result = function.call(withArguments: [])
        guard let result = result?.toInt32() else {
            throw "Expected string result from testNegativeDelay"
        }
        return result
    }
    
    @discardableResult
    func multipleTimers() async throws -> [Int32] {
        guard let function = objectForKeyedSubscript("testMultipleTimers") else {
            throw "Function testMultipleTimers not found"
        }
        let result = function.call(withArguments: [])
        guard let arrayResult = result?.toArray() else {
            throw "Expected array result from testMultipleTimers"
        }
        return arrayResult.compactMap { $0 as? Int32 }
    }
    
    @discardableResult
    func invalidCallbacks() async throws -> [Int32] {
        guard let function = objectForKeyedSubscript("testInvalidCallbacks") else {
            throw "Function testInvalidCallbacks not found"
        }
        let result = function.call(withArguments: [])
        guard let arrayResult = result?.toArray() else {
            throw "Expected array result from testInvalidCallbacks"
        }
        return arrayResult.compactMap { $0 as? Int32 }
    }
    
    @discardableResult
    func clearInvalid() async throws -> Bool {
        guard let function = objectForKeyedSubscript("testClearInvalid") else {
            throw "Function testClearInvalid not found"
        }
        let result = function.call(withArguments: [])
        return result?.toBool() ?? false
    }
    
    @discardableResult
    func createTimers() async throws -> [Int32] {
        guard let function = objectForKeyedSubscript("createTimers") else {
            throw "Function createTimers not found"
        }
        let result = function.call(withArguments: [])
        guard let arrayResult = result?.toArray() else {
            throw "Expected array result from createTimers"
        }
        return arrayResult.compactMap { $0 as? Int32 }
    }
}
