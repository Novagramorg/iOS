//
//  JSValue+ConversionTests.swift
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

@Suite("JSValue To Native Types Conversion Tests")
struct JSValueDecodingTests {
    
    private func conext() -> JSContext {
        JSTestConversionContext()
    }
    
    @Test("String Conversion")
    func testStringConversion() throws {
        let context = self.conext()
        
        try testValueConversion(String.self, context: context, equalTo: "String")
        try testNullConversion(String.self, context: context)
        try testVoidConversion(String.self, context: context)
        try testUndefinedConversion(String.self, context: context)
        
        // Throwing conversions
        try testValueThrowingConversion(String.self, againstType: JSDummyValue.self, context: context)
        try testValueThrowingConversion(String.self, againstType: Int.self, context: context)
        try testValueThrowingConversion(String.self, againstType: Bool.self, context: context)
        try testValueThrowingConversion(String.self, againstType: Array<Int>.self, context: context)
        try testValueThrowingConversion(String.self, againstType: Dictionary<String, String>.self, context: context)
        try testValueThrowingConversion(String.self, againstType: Date.self, context: context)
    }
    
    @Test("JSTestDecodable Conversion")
    func testJSTestDecodableConversion() throws {
        let context = self.conext()
        
        // Basic decodable conversion
        let expected = JSTestDecodable(test: "testValue")
        try testValueConversion(JSTestDecodable.self, context: context, equalTo: expected)
        try testNullConversion(JSTestDecodable.self, context: context)
        try testUndefinedConversion(JSTestDecodable.self, context: context)

        try testValueThrowingConversion(JSTestDecodable.self, againstType: JSDummyValue.self, context: context)
        try testValueThrowingConversion(JSTestDecodable.self, againstType: String.self, context: context)
        try testValueThrowingConversion(JSTestDecodable.self, againstType: Int.self, context: context)
        try testValueThrowingConversion(JSTestDecodable.self, againstType: Bool.self, context: context)
        try testValueThrowingConversion(JSTestDecodable.self, againstType: Array<Int>.self, context: context)
        try testValueThrowingConversion(JSTestDecodable.self, againstType: Date.self, context: context)
    }
    
    @Test("Int Conversion")
    func testIntConversion() throws {
        let context = self.conext()
        
        try testValueConversion(Int.self, context: context, equalTo: Int.max)
        try testNullConversion(Int.self, context: context)
        try testUndefinedConversion(Int.self, context: context)
        
        try testValueThrowingConversion(Int.self, againstType: JSDummyValue.self, context: context)
        try testValueThrowingConversion(Int.self, againstType: String.self, context: context)
        try testValueThrowingConversion(Int.self, againstType: Array<Int>.self, context: context)
        try testValueThrowingConversion(Int.self, againstType: Dictionary<String, String>.self, context: context)
        try testValueThrowingConversion(Int.self, againstType: JSTestDecodable.self, context: context)
        try testValueThrowingConversion(Int.self, againstType: Bool.self, context: context)
        try testValueThrowingConversion(Int.self, againstType: Date.self, context: context)
        
        try testValueThrowingConversion(Int.self, functionName: "IntInString", context: context)
        
        try testValueConversion(Int.self, againstType: Int32.self, context: context, equalTo: Int(Int32.max))
        try testValueConversion(Int.self, againstType: Int64.self, context: context, equalTo: Int(Int64.max))
        
        try testValueConversion(Int.self, againstType: UInt.self, context: context, equalTo: Int.max)
        try testValueConversion(Int.self, againstType: UInt32.self, context: context, equalTo: Int(UInt32.max))
        try testValueConversion(Int.self, againstType: UInt64.self, context: context, equalTo: Int.max)
        
        try testValueConversion(Int.self, againstType: Double.self, context: context, equalTo: Int.max)
        try testValueConversion(Int.self, againstType: Float.self, context: context, equalTo: Int.max)
    }
    
    @Test("Int64 Conversion")
    func testInt64Conversion() throws {
        let context = self.conext()
        
        try testValueConversion(Int64.self, context: context, equalTo: Int64.max)
        try testNullConversion(Int64.self, context: context)
        try testUndefinedConversion(Int64.self, context: context)
        
        // Throwing conversions
        try testValueThrowingConversion(Int64.self, againstType: JSDummyValue.self, context: context)
        try testValueThrowingConversion(Int64.self, againstType: String.self, context: context)
        try testValueThrowingConversion(Int64.self, againstType: Array<Int>.self, context: context)
        try testValueThrowingConversion(Int64.self, againstType: Dictionary<String, String>.self, context: context)
        try testValueThrowingConversion(Int64.self, againstType: JSTestDecodable.self, context: context)
        try testValueThrowingConversion(Int64.self, againstType: Bool.self, context: context)
        try testValueThrowingConversion(Int64.self, againstType: Date.self, context: context)
        try testValueThrowingConversion(Int64.self, functionName: "IntInString", context: context)
        
        // Positive cross-type conversions
        try testValueConversion(Int64.self, againstType: Int32.self, context: context, equalTo: Int64(Int32.max))
        try testValueConversion(Int64.self, againstType: UInt32.self, context: context, equalTo: Int64(UInt32.max))
        try testValueConversion(Int64.self, againstType: Int.self, context: context, equalTo: Int64(Int.max))
        try testValueConversion(Int64.self, againstType: UInt.self, context: context, equalTo: Int64.max)
        try testValueConversion(Int64.self, againstType: UInt64.self, context: context, equalTo: Int64.max)
        try testValueConversion(Int64.self, againstType: Double.self, context: context, equalTo: Int64.max)
        try testValueConversion(Int64.self, againstType: Float.self, context: context, equalTo: Int64.max)
    }
    
    @Test("Int32 Conversion")
    func testInt32Conversion() throws {
        let context = self.conext()
        
        try testValueConversion(Int32.self, context: context, equalTo: Int32.max)
        try testNullConversion(Int32.self, context: context)
        try testUndefinedConversion(Int32.self, context: context)
        
        // Throwing conversions
        try testValueThrowingConversion(Int32.self, againstType: JSDummyValue.self, context: context)
        try testValueThrowingConversion(Int32.self, againstType: String.self, context: context)
        try testValueThrowingConversion(Int32.self, againstType: Array<Int>.self, context: context)
        try testValueThrowingConversion(Int32.self, againstType: Dictionary<String, String>.self, context: context)
        try testValueThrowingConversion(Int32.self, againstType: JSTestDecodable.self, context: context)
        try testValueThrowingConversion(Int32.self, againstType: Bool.self, context: context)
        try testValueThrowingConversion(Int32.self, againstType: Date.self, context: context)
        try testValueThrowingConversion(Int32.self, functionName: "IntInString", context: context)
        
        // Positive cross-type conversions (values cap at Int32.max)
        try testValueConversion(Int32.self, againstType: Int.self, context: context, equalTo: -1)
        try testValueConversion(Int32.self, againstType: Int64.self, context: context, equalTo: -1)
        try testValueConversion(Int32.self, againstType: UInt.self, context: context, equalTo: -1)
        try testValueConversion(Int32.self, againstType: UInt64.self, context: context, equalTo: -1)
        try testValueConversion(Int32.self, againstType: UInt32.self, context: context, equalTo: -1)
        try testValueConversion(Int32.self, againstType: Double.self, context: context, equalTo: -1)
        try testValueConversion(Int32.self, againstType: Float.self, context: context, equalTo: -1)
    }
    
    @Test("UInt Conversion")
    func testUIntConversion() throws {
        let context = self.conext()
        
        try testValueConversion(UInt.self, context: context, equalTo: 0)
        try testNullConversion(UInt.self, context: context)
        try testUndefinedConversion(UInt.self, context: context)
        
        // Throwing conversions
        try testValueThrowingConversion(UInt.self, againstType: JSDummyValue.self, context: context)
        try testValueThrowingConversion(UInt.self, againstType: String.self, context: context)
        try testValueThrowingConversion(UInt.self, againstType: Array<Int>.self, context: context)
        try testValueThrowingConversion(UInt.self, againstType: Dictionary<String, String>.self, context: context)
        try testValueThrowingConversion(UInt.self, againstType: JSTestDecodable.self, context: context)
        try testValueThrowingConversion(UInt.self, againstType: Bool.self, context: context)
        try testValueThrowingConversion(UInt.self, againstType: Date.self, context: context)
        try testValueThrowingConversion(UInt.self, functionName: "IntInString", context: context)
        
        // Positive cross-type conversions
        try testValueConversion(UInt.self, againstType: UInt32.self, context: context, equalTo: UInt(UInt32.max))
        try testValueConversion(UInt.self, againstType: Int32.self, context: context, equalTo: UInt(Int32.max))
        try testValueConversion(UInt.self, againstType: UInt64.self, context: context, equalTo: 0)
        try testValueConversion(UInt.self, againstType: Double.self, context: context, equalTo: UInt.max)
        try testValueConversion(UInt.self, againstType: Float.self, context: context, equalTo: UInt.max)
    }
    
    @Test("UInt64 Conversion")
    func testUInt64Conversion() throws {
        let context = self.conext()
        
        try testValueConversion(UInt64.self, context: context, equalTo: 0)
        try testNullConversion(UInt64.self, context: context)
        try testUndefinedConversion(UInt64.self, context: context)
        
        // Throwing conversions
        try testValueThrowingConversion(UInt64.self, againstType: JSDummyValue.self, context: context)
        try testValueThrowingConversion(UInt64.self, againstType: String.self, context: context)
        try testValueThrowingConversion(UInt64.self, againstType: Array<Int>.self, context: context)
        try testValueThrowingConversion(UInt64.self, againstType: Dictionary<String, String>.self, context: context)
        try testValueThrowingConversion(UInt64.self, againstType: JSTestDecodable.self, context: context)
        try testValueThrowingConversion(UInt64.self, againstType: Bool.self, context: context)
        try testValueThrowingConversion(UInt64.self, againstType: Date.self, context: context)
        try testValueThrowingConversion(UInt64.self, functionName: "IntInString", context: context)
        
        // Positive cross-type conversions
        try testValueConversion(UInt64.self, againstType: UInt32.self, context: context, equalTo: UInt64(UInt32.max))
        try testValueConversion(UInt64.self, againstType: Int32.self, context: context, equalTo: UInt64(Int32.max))
        try testValueConversion(UInt64.self, againstType: Int.self, context: context, equalTo: UInt64(Int.max) + 1)
        try testValueConversion(UInt64.self, againstType: Int64.self, context: context, equalTo: UInt64(Int64.max) + 1)
        try testValueConversion(UInt64.self, againstType: Double.self, context: context, equalTo: UInt64.max)
        try testValueConversion(UInt64.self, againstType: Float.self, context: context, equalTo: UInt64.max)
    }
    
    @Test("UInt32 Conversion")
    func testUInt32Conversion() throws {
        let context = self.conext()
        
        try testValueConversion(UInt32.self, context: context, equalTo: UInt32.max)
        try testNullConversion(UInt32.self, context: context)
        try testUndefinedConversion(UInt32.self, context: context)
        
        // Throwing conversions
        try testValueThrowingConversion(UInt32.self, againstType: JSDummyValue.self, context: context)
        try testValueThrowingConversion(UInt32.self, againstType: String.self, context: context)
        try testValueThrowingConversion(UInt32.self, againstType: Array<Int>.self, context: context)
        try testValueThrowingConversion(UInt32.self, againstType: Dictionary<String, String>.self, context: context)
        try testValueThrowingConversion(UInt32.self, againstType: JSTestDecodable.self, context: context)
        try testValueThrowingConversion(UInt32.self, againstType: Bool.self, context: context)
        try testValueThrowingConversion(UInt32.self, againstType: Date.self, context: context)
        try testValueThrowingConversion(UInt32.self, functionName: "IntInString", context: context)
        
        // Positive cross-type conversions (values cap at UInt32.max when larger)
        try testValueConversion(UInt32.self, againstType: Int32.self, context: context, equalTo: UInt32(Int32.max))
        try testValueConversion(UInt32.self, againstType: UInt.self, context: context, equalTo: UInt32.max)
        try testValueConversion(UInt32.self, againstType: UInt64.self, context: context, equalTo: UInt32.max)
        try testValueConversion(UInt32.self, againstType: Int.self, context: context, equalTo: UInt32.max)
        try testValueConversion(UInt32.self, againstType: Double.self, context: context, equalTo: UInt32.max)
        try testValueConversion(UInt32.self, againstType: Float.self, context: context, equalTo: UInt32.max)
    }
    
    @Test("Double Conversion")
    func testDoubleConversion() throws {
        let context = self.conext()
        
        try testValueConversion(Double.self, context: context, equalTo: Double.greatestFiniteMagnitude)
        try testNullConversion(Double.self, context: context)
        try testUndefinedConversion(Double.self, context: context)
        
        // Throwing conversions
        try testValueThrowingConversion(Double.self, againstType: JSDummyValue.self, context: context)
        try testValueThrowingConversion(Double.self, againstType: String.self, context: context)
        try testValueThrowingConversion(Double.self, againstType: Array<Int>.self, context: context)
        try testValueThrowingConversion(Double.self, againstType: Dictionary<String, String>.self, context: context)
        try testValueThrowingConversion(Double.self, againstType: JSTestDecodable.self, context: context)
        try testValueThrowingConversion(Double.self, againstType: Bool.self, context: context)
        try testValueThrowingConversion(Double.self, againstType: Date.self, context: context)
        
        // Positive cross-type conversions
        try testValueConversion(Double.self, againstType: Int.self, context: context, equalTo: Double(Int.max))
        try testValueConversion(Double.self, againstType: Float.self, context: context, equalTo: 3.4028235e+38)
    }
    
    @Test("Float Conversion")
    func testFloatConversion() throws {
        let context = self.conext()
        
        try testValueConversion(Float.self, context: context, equalTo: Float.greatestFiniteMagnitude)
        try testNullConversion(Float.self, context: context)
        try testUndefinedConversion(Float.self, context: context)
        
        // Throwing conversions
        try testValueThrowingConversion(Float.self, againstType: JSDummyValue.self, context: context)
        try testValueThrowingConversion(Float.self, againstType: String.self, context: context)
        try testValueThrowingConversion(Float.self, againstType: Array<Int>.self, context: context)
        try testValueThrowingConversion(Float.self, againstType: Dictionary<String, String>.self, context: context)
        try testValueThrowingConversion(Float.self, againstType: JSTestDecodable.self, context: context)
        try testValueThrowingConversion(Float.self, againstType: Bool.self, context: context)
        try testValueThrowingConversion(Float.self, againstType: Date.self, context: context)
        
        // Positive cross-type conversions
        try testValueConversion(Float.self, againstType: Int32.self, context: context, equalTo: Float(Int32.max))
        try testValueConversion(Float.self, againstType: Double.self, context: context, equalTo: .infinity)
    }
    
    @Test("Bool Conversion")
    func testBoolConversion() throws {
        let context = self.conext()
        
        try testValueConversion(Bool.self, context: context, equalTo: true)
        try testNullConversion(Bool.self, context: context)
        try testUndefinedConversion(Bool.self, context: context)
        
        // Throwing conversions
        try testValueThrowingConversion(Bool.self, againstType: JSDummyValue.self, context: context)
        try testValueThrowingConversion(Bool.self, againstType: String.self, context: context)
        try testValueThrowingConversion(Bool.self, againstType: Array<Int>.self, context: context)
        try testValueThrowingConversion(Bool.self, againstType: Dictionary<String, String>.self, context: context)
        try testValueThrowingConversion(Bool.self, againstType: JSTestDecodable.self, context: context)
        try testValueThrowingConversion(Bool.self, againstType: Date.self, context: context)
        try testValueThrowingConversion(Bool.self, againstType: Int.self, context: context)
    }
    
    @Test("Date Conversion")
    func testDateConversion() throws {
        let context = self.conext()
        let expectedDate = Date(timeIntervalSince1970: 1_672_531_200) // 2023-01-01T00:00:00Z
        
        try testValueConversion(Date.self, context: context, equalTo: expectedDate)
        try testNullConversion(Date.self, context: context)
        try testUndefinedConversion(Date.self, context: context)
        
        // Throwing conversions
        try testValueThrowingConversion(Date.self, againstType: JSDummyValue.self, context: context)
        try testValueThrowingConversion(Date.self, againstType: String.self, context: context)
        try testValueThrowingConversion(Date.self, againstType: Array<Int>.self, context: context)
        try testValueThrowingConversion(Date.self, againstType: Dictionary<String, String>.self, context: context)
        try testValueThrowingConversion(Date.self, againstType: JSTestDecodable.self, context: context)
        try testValueThrowingConversion(Date.self, againstType: Bool.self, context: context)
        try testValueThrowingConversion(Date.self, againstType: Int.self, context: context)
    }
    
    @Test("Array<Int> Conversion")
    func testArrayConversion() throws {
        let context = self.conext()
        
        try testValueConversion(Array<Int>.self, context: context, equalTo: [1, 2, 3])
        try testNullConversion(Array<Int>.self, context: context)
        try testUndefinedConversion(Array<Int>.self, context: context)
        
        // Throwing conversions
        try testValueThrowingConversion(Array<Int>.self, againstType: JSDummyValue.self, context: context)
        try testValueThrowingConversion(Array<Int>.self, againstType: String.self, context: context)
        try testValueThrowingConversion(Array<Int>.self, againstType: Dictionary<String, String>.self, context: context)
        try testValueThrowingConversion(Array<Int>.self, againstType: JSTestDecodable.self, context: context)
        try testValueThrowingConversion(Array<Int>.self, againstType: Bool.self, context: context)
        try testValueThrowingConversion(Array<Int>.self, againstType: Date.self, context: context)
        try testValueThrowingConversion(Array<Int>.self, againstType: Int.self, context: context)
    }
    
    @Test("Dictionary<String,String> Conversion")
    func testDictionaryConversion() throws {
        let context = self.conext()
        
        try testValueConversion(Dictionary<String, String>.self, context: context, equalTo: ["key": "value"])
        try testNullConversion(Dictionary<String, String>.self, context: context)
        try testUndefinedConversion(Dictionary<String, String>.self, context: context)
        
        try testValueConversion(Dictionary<String, String>.self, againstType: JSTestDecodable.self, context: context, equalTo: ["test": "testValue"])
        
        // Throwing conversions
        try testValueThrowingConversion(Dictionary<String, String>.self, againstType: JSDummyValue.self, context: context)
        try testValueThrowingConversion(Dictionary<String, String>.self, againstType: String.self, context: context)
        try testValueThrowingConversion(Dictionary<String, String>.self, againstType: Array<Int>.self, context: context)
        try testValueThrowingConversion(Dictionary<String, String>.self, againstType: Bool.self, context: context)
        try testValueThrowingConversion(Dictionary<String, String>.self, againstType: Date.self, context: context)
        try testValueThrowingConversion(Dictionary<String, String>.self, againstType: Int.self, context: context)
    }
}
