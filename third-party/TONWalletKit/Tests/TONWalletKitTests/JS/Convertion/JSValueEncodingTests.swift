//
//  JSValueEncodingTests.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 23.10.2025.
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

@Suite("Navive Types To JSValue Conversion Tests")
struct JSValueEncodingTests {
    
    @Test("Check correctness of converted types")
    func testNativeTypesToJSValueConversion() throws {
        let context = JSTestConversionContext()
        
        try checkBoolResult(functionName: "_isString", with: [String()], in: context)
        
        let isNumber = "_isNumber"
        
        try checkBoolResult(functionName: isNumber, with: [Int()], in: context)
        try checkBoolResult(functionName: isNumber, with: [Int32()], in: context)
        try checkBoolResult(functionName: isNumber, with: [Int64()], in: context)
        try checkBoolResult(functionName: isNumber, with: [UInt()], in: context)
        try checkBoolResult(functionName: isNumber, with: [UInt32()], in: context)
        try checkBoolResult(functionName: isNumber, with: [UInt64()], in: context)
        try checkBoolResult(functionName: isNumber, with: [Float()], in: context)
        try checkBoolResult(functionName: isNumber, with: [Double()], in: context)
        
        try checkBoolResult(functionName: "_isBoolean", with: [true], in: context)
        
        try checkBoolResult(functionName: "_isDate", with: [Date()], in: context)
        
        try checkBoolResult(functionName: "_isNull", with: [NSNull()], in: context)
        
        try checkBoolResult(functionName: "_validateJSTestDecodable", with: [JSTestDecodable(test: "testValue")], in: context)
        
        try checkBoolResult(functionName: "_isArray", with: [[1, 2, 3]], in: context)
        
        try checkBoolResult(
            functionName: "_validateMultipleParameters",
            with: [
                "testString",
                42,
                true
            ],
            in: context
        )
    }
    
    private func checkBoolResult(
        functionName: String,
        with arguments: [any JSValueEncodable],
        in context: JSContext
    ) throws {
        #expect(try context[dynamicMember: functionName].dynamicallyCall(withArguments: arguments) == true)
    }
}
