//
//  JSValueDataTests.swift
//  TONWalletKit
//
//  Created by Claude on 23.03.2026.
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

@Suite("JSValue isUInt8Array Tests")
struct JSValueIsUInt8ArrayTests {

    private let context = JSContext()!

    @Test("Uint8Array is recognized as UInt8Array")
    func uint8ArrayIsRecognized() {
        let value = context.evaluateScript("new Uint8Array([1, 2, 3])")!
        #expect(value.isUInt8Array == true)
    }

    @Test("Empty Uint8Array is recognized")
    func emptyUint8ArrayIsRecognized() {
        let value = context.evaluateScript("new Uint8Array([])")!
        #expect(value.isUInt8Array == true)
    }

    @Test("Uint8Array from ArrayBuffer is recognized")
    func uint8ArrayFromBufferIsRecognized() {
        let value = context.evaluateScript("new Uint8Array(new ArrayBuffer(4))")!
        #expect(value.isUInt8Array == true)
    }

    @Test("Uint8Array subarray is recognized")
    func uint8ArraySubarrayIsRecognized() {
        let value = context.evaluateScript("new Uint8Array([1,2,3,4]).subarray(1,3)")!
        #expect(value.isUInt8Array == true)
    }

    @Test("Int8Array is not UInt8Array")
    func int8ArrayIsNotUint8Array() {
        let value = context.evaluateScript("new Int8Array([1, 2])")!
        #expect(value.isUInt8Array == false)
    }

    @Test("Uint16Array is not UInt8Array")
    func uint16ArrayIsNotUint8Array() {
        let value = context.evaluateScript("new Uint16Array([1])")!
        #expect(value.isUInt8Array == false)
    }

    @Test("Uint32Array is not UInt8Array")
    func uint32ArrayIsNotUint8Array() {
        let value = context.evaluateScript("new Uint32Array([1])")!
        #expect(value.isUInt8Array == false)
    }

    @Test("Int16Array is not UInt8Array")
    func int16ArrayIsNotUint8Array() {
        let value = context.evaluateScript("new Int16Array([1])")!
        #expect(value.isUInt8Array == false)
    }

    @Test("Float32Array is not UInt8Array")
    func float32ArrayIsNotUint8Array() {
        let value = context.evaluateScript("new Float32Array([1.0])")!
        #expect(value.isUInt8Array == false)
    }

    @Test("Float64Array is not UInt8Array")
    func float64ArrayIsNotUint8Array() {
        let value = context.evaluateScript("new Float64Array([1.0])")!
        #expect(value.isUInt8Array == false)
    }

    @Test("Uint8ClampedArray is not UInt8Array")
    func uint8ClampedArrayIsNotUint8Array() {
        let value = context.evaluateScript("new Uint8ClampedArray([1])")!
        #expect(value.isUInt8Array == false)
    }

    @Test("ArrayBuffer is not UInt8Array")
    func arrayBufferIsNotUint8Array() {
        let value = context.evaluateScript("new ArrayBuffer(4)")!
        #expect(value.isUInt8Array == false)
    }

    @Test("DataView is not UInt8Array")
    func dataViewIsNotUint8Array() {
        let value = context.evaluateScript("new DataView(new ArrayBuffer(4))")!
        #expect(value.isUInt8Array == false)
    }

    @Test("JS array is not UInt8Array")
    func jsArrayIsNotUint8Array() {
        let value = context.evaluateScript("[1, 2, 3]")!
        #expect(value.isUInt8Array == false)
    }

    @Test("String is not UInt8Array")
    func stringIsNotUint8Array() {
        let value = JSValue(object: "hello", in: context)!
        #expect(value.isUInt8Array == false)
    }

    @Test("Number is not UInt8Array")
    func numberIsNotUint8Array() {
        let value = JSValue(int32: 42, in: context)!
        #expect(value.isUInt8Array == false)
    }

    @Test("Boolean is not UInt8Array")
    func booleanIsNotUint8Array() {
        let value = JSValue(bool: true, in: context)!
        #expect(value.isUInt8Array == false)
    }

    @Test("Null is not UInt8Array")
    func nullIsNotUint8Array() {
        let value = JSValue(nullIn: context)!
        #expect(value.isUInt8Array == false)
    }

    @Test("Undefined is not UInt8Array")
    func undefinedIsNotUint8Array() {
        let value = JSValue(undefinedIn: context)!
        #expect(value.isUInt8Array == false)
    }

    @Test("Plain object is not UInt8Array")
    func plainObjectIsNotUint8Array() {
        let value = context.evaluateScript("({})")!
        #expect(value.isUInt8Array == false)
    }
}

@Suite("JSValue.uint8Array(from:context:) Tests")
struct JSValueUint8ArrayConversionTests {

    private let context = JSContext()!

    // MARK: - Uint8Array passthrough

    @Test("Uint8Array passes through and preserves bytes")
    func uint8ArrayPassthrough() {
        let value = context.evaluateScript("new Uint8Array([10, 20, 30])")!
        let result = JSValue.uint8Array(from: value, context: context)
        #expect(result.isUInt8Array == true)
        #expect(result.objectAtIndexedSubscript(0)?.toInt32() == 10)
        #expect(result.objectAtIndexedSubscript(1)?.toInt32() == 20)
        #expect(result.objectAtIndexedSubscript(2)?.toInt32() == 30)
    }

    @Test("Empty Uint8Array passes through")
    func emptyUint8ArrayPassthrough() {
        let value = context.evaluateScript("new Uint8Array([])")!
        let result = JSValue.uint8Array(from: value, context: context)
        #expect(result.isUInt8Array == true)
        let length: Int32 = result.length ?? 0
        #expect(length == 0)
    }

    @Test("Uint8Array subarray passes through preserving view bounds")
    func uint8ArraySubarrayPassthrough() {
        let value = context.evaluateScript("new Uint8Array([10, 20, 30, 40, 50]).subarray(1, 4)")!
        let result = JSValue.uint8Array(from: value, context: context)
        #expect(result.isUInt8Array == true)
        let length: Int32 = result.length ?? 0
        #expect(length == 3)
        #expect(result.objectAtIndexedSubscript(0)?.toInt32() == 20)
        #expect(result.objectAtIndexedSubscript(1)?.toInt32() == 30)
        #expect(result.objectAtIndexedSubscript(2)?.toInt32() == 40)
    }

    // MARK: - ArrayBuffer

    @Test("ArrayBuffer wraps into Uint8Array")
    func arrayBufferWraps() {
        let value = context.evaluateScript("""
            (function() {
                var buf = new ArrayBuffer(3);
                var v = new Uint8Array(buf);
                v[0] = 0xAA; v[1] = 0xBB; v[2] = 0xCC;
                return buf;
            })()
        """)!
        let result = JSValue.uint8Array(from: value, context: context)
        #expect(result.isUInt8Array == true)
        #expect(result.objectAtIndexedSubscript(0)?.toInt32() == 0xAA)
        #expect(result.objectAtIndexedSubscript(1)?.toInt32() == 0xBB)
        #expect(result.objectAtIndexedSubscript(2)?.toInt32() == 0xCC)
    }

    @Test("Empty ArrayBuffer wraps into empty Uint8Array")
    func emptyArrayBufferWraps() {
        let value = context.evaluateScript("new ArrayBuffer(0)")!
        let result = JSValue.uint8Array(from: value, context: context)
        #expect(result.isUInt8Array == true)
        let length: Int32 = result.length ?? 0
        #expect(length == 0)
    }

    @Test("ArrayBuffer.slice wraps correctly")
    func arrayBufferSliceWraps() {
        let value = context.evaluateScript("""
            (function() {
                var buf = new ArrayBuffer(5);
                var v = new Uint8Array(buf);
                v[0] = 10; v[1] = 20; v[2] = 30; v[3] = 40; v[4] = 50;
                return buf.slice(1, 4);
            })()
        """)!
        let result = JSValue.uint8Array(from: value, context: context)
        #expect(result.isUInt8Array == true)
        let length: Int32 = result.length ?? 0
        #expect(length == 3)
        #expect(result.objectAtIndexedSubscript(0)?.toInt32() == 20)
        #expect(result.objectAtIndexedSubscript(1)?.toInt32() == 30)
        #expect(result.objectAtIndexedSubscript(2)?.toInt32() == 40)
    }

    @Test("ArrayBuffer.slice from offset to end wraps correctly")
    func arrayBufferSliceFromOffset() {
        let value = context.evaluateScript("""
            (function() {
                var buf = new ArrayBuffer(5);
                var v = new Uint8Array(buf);
                v[0] = 10; v[1] = 20; v[2] = 30; v[3] = 40; v[4] = 50;
                return buf.slice(3);
            })()
        """)!
        let result = JSValue.uint8Array(from: value, context: context)
        #expect(result.isUInt8Array == true)
        let length: Int32 = result.length ?? 0
        #expect(length == 2)
        #expect(result.objectAtIndexedSubscript(0)?.toInt32() == 40)
        #expect(result.objectAtIndexedSubscript(1)?.toInt32() == 50)
    }

    @Test("ArrayBuffer.slice with negative index wraps correctly")
    func arrayBufferSliceNegativeIndex() {
        let value = context.evaluateScript("""
            (function() {
                var buf = new ArrayBuffer(5);
                var v = new Uint8Array(buf);
                v[0] = 10; v[1] = 20; v[2] = 30; v[3] = 40; v[4] = 50;
                return buf.slice(-2);
            })()
        """)!
        let result = JSValue.uint8Array(from: value, context: context)
        #expect(result.isUInt8Array == true)
        let length: Int32 = result.length ?? 0
        #expect(length == 2)
        #expect(result.objectAtIndexedSubscript(0)?.toInt32() == 40)
        #expect(result.objectAtIndexedSubscript(1)?.toInt32() == 50)
    }

    @Test("ArrayBuffer.slice(0, 0) produces empty Uint8Array")
    func arrayBufferSliceEmpty() {
        let value = context.evaluateScript("""
            (function() {
                var buf = new ArrayBuffer(4);
                var v = new Uint8Array(buf);
                v[0] = 0xFF; v[1] = 0xFF; v[2] = 0xFF; v[3] = 0xFF;
                return buf.slice(0, 0);
            })()
        """)!
        let result = JSValue.uint8Array(from: value, context: context)
        #expect(result.isUInt8Array == true)
        let length: Int32 = result.length ?? 0
        #expect(length == 0)
    }

    @Test("ArrayBuffer.slice with negative start and end wraps correctly")
    func arrayBufferSliceNegativeRange() {
        let value = context.evaluateScript("""
            (function() {
                var buf = new ArrayBuffer(6);
                var v = new Uint8Array(buf);
                v[0] = 1; v[1] = 2; v[2] = 3; v[3] = 4; v[4] = 5; v[5] = 6;
                return buf.slice(-4, -1);
            })()
        """)!
        let result = JSValue.uint8Array(from: value, context: context)
        #expect(result.isUInt8Array == true)
        let length: Int32 = result.length ?? 0
        #expect(length == 3)
        #expect(result.objectAtIndexedSubscript(0)?.toInt32() == 3)
        #expect(result.objectAtIndexedSubscript(1)?.toInt32() == 4)
        #expect(result.objectAtIndexedSubscript(2)?.toInt32() == 5)
    }

    @Test("ArrayBuffer.slice single byte in the middle")
    func arrayBufferSliceSingleByte() {
        let value = context.evaluateScript("""
            (function() {
                var buf = new ArrayBuffer(4);
                var v = new Uint8Array(buf);
                v[0] = 0xAA; v[1] = 0xBB; v[2] = 0xCC; v[3] = 0xDD;
                return buf.slice(2, 3);
            })()
        """)!
        let result = JSValue.uint8Array(from: value, context: context)
        #expect(result.isUInt8Array == true)
        let length: Int32 = result.length ?? 0
        #expect(length == 1)
        #expect(result.objectAtIndexedSubscript(0)?.toInt32() == 0xCC)
    }

    // MARK: - DataView

    @Test("DataView converts using buffer, byteOffset, byteLength")
    func dataViewConverts() {
        let value = context.evaluateScript("""
            (function() {
                var buf = new ArrayBuffer(4);
                var v = new Uint8Array(buf);
                v[0] = 0xDE; v[1] = 0xAD; v[2] = 0xBE; v[3] = 0xEF;
                return new DataView(buf);
            })()
        """)!
        let result = JSValue.uint8Array(from: value, context: context)
        #expect(result.isUInt8Array == true)
        let length: Int32 = result.length ?? 0
        #expect(length == 4)
        #expect(result.objectAtIndexedSubscript(0)?.toInt32() == 0xDE)
        #expect(result.objectAtIndexedSubscript(1)?.toInt32() == 0xAD)
        #expect(result.objectAtIndexedSubscript(2)?.toInt32() == 0xBE)
        #expect(result.objectAtIndexedSubscript(3)?.toInt32() == 0xEF)
    }

    @Test("DataView with offset converts correctly")
    func dataViewWithOffsetConverts() {
        let value = context.evaluateScript("""
            (function() {
                var buf = new ArrayBuffer(6);
                var v = new Uint8Array(buf);
                v[0] = 1; v[1] = 2; v[2] = 3; v[3] = 4; v[4] = 5; v[5] = 6;
                return new DataView(buf, 2, 3);
            })()
        """)!
        let result = JSValue.uint8Array(from: value, context: context)
        #expect(result.isUInt8Array == true)
        let length: Int32 = result.length ?? 0
        #expect(length == 3)
        #expect(result.objectAtIndexedSubscript(0)?.toInt32() == 3)
        #expect(result.objectAtIndexedSubscript(1)?.toInt32() == 4)
        #expect(result.objectAtIndexedSubscript(2)?.toInt32() == 5)
    }

    @Test("Empty DataView converts to empty Uint8Array")
    func emptyDataViewConverts() {
        let value = context.evaluateScript("new DataView(new ArrayBuffer(0))")!
        let result = JSValue.uint8Array(from: value, context: context)
        #expect(result.isUInt8Array == true)
        let length: Int32 = result.length ?? 0
        #expect(length == 0)
    }

    // MARK: - Other TypedArrays (via buffer property)

    @Test("Int8Array converts via buffer")
    func int8ArrayConvertsViaBuffer() {
        let value = context.evaluateScript("new Int8Array([-1, 0, 127])")!
        let result = JSValue.uint8Array(from: value, context: context)
        #expect(result.isUInt8Array == true)
        let length: Int32 = result.length ?? 0
        #expect(length == 3)
        #expect(result.objectAtIndexedSubscript(0)?.toInt32() == 255)
        #expect(result.objectAtIndexedSubscript(1)?.toInt32() == 0)
        #expect(result.objectAtIndexedSubscript(2)?.toInt32() == 127)
    }

    @Test("Uint16Array converts via buffer — reads raw bytes")
    func uint16ArrayConvertsViaBuffer() {
        let value = context.evaluateScript("new Uint16Array([0x0102])")!
        let result = JSValue.uint8Array(from: value, context: context)
        #expect(result.isUInt8Array == true)
        let length: Int32 = result.length ?? 0
        #expect(length == 2)
    }

    @Test("Int16Array converts via buffer")
    func int16ArrayConvertsViaBuffer() {
        let value = context.evaluateScript("new Int16Array([256])")!
        let result = JSValue.uint8Array(from: value, context: context)
        #expect(result.isUInt8Array == true)
        let length: Int32 = result.length ?? 0
        #expect(length == 2)
    }

    @Test("Uint32Array converts via buffer — 4 bytes per element")
    func uint32ArrayConvertsViaBuffer() {
        let value = context.evaluateScript("new Uint32Array([1])")!
        let result = JSValue.uint8Array(from: value, context: context)
        #expect(result.isUInt8Array == true)
        let length: Int32 = result.length ?? 0
        #expect(length == 4)
    }

    @Test("Float32Array converts via buffer — 4 bytes per element")
    func float32ArrayConvertsViaBuffer() {
        let value = context.evaluateScript("new Float32Array([1.0])")!
        let result = JSValue.uint8Array(from: value, context: context)
        #expect(result.isUInt8Array == true)
        let length: Int32 = result.length ?? 0
        #expect(length == 4)
    }

    @Test("Float64Array converts via buffer — 8 bytes per element")
    func float64ArrayConvertsViaBuffer() {
        let value = context.evaluateScript("new Float64Array([1.0])")!
        let result = JSValue.uint8Array(from: value, context: context)
        #expect(result.isUInt8Array == true)
        let length: Int32 = result.length ?? 0
        #expect(length == 8)
    }

    @Test("Uint8ClampedArray converts via buffer")
    func uint8ClampedArrayConvertsViaBuffer() {
        let value = context.evaluateScript("new Uint8ClampedArray([0, 128, 255])")!
        let result = JSValue.uint8Array(from: value, context: context)
        #expect(result.isUInt8Array == true)
        let length: Int32 = result.length ?? 0
        #expect(length == 3)
        #expect(result.objectAtIndexedSubscript(0)?.toInt32() == 0)
        #expect(result.objectAtIndexedSubscript(1)?.toInt32() == 128)
        #expect(result.objectAtIndexedSubscript(2)?.toInt32() == 255)
    }

    // MARK: - TypedArray subarrays (respect byteOffset/byteLength)

    @Test("Uint16Array subarray converts only the viewed portion")
    func uint16ArraySubarrayConverts() {
        let value = context.evaluateScript("new Uint16Array([1, 2, 3, 4]).subarray(1, 3)")!
        let result = JSValue.uint8Array(from: value, context: context)
        #expect(result.isUInt8Array == true)
        let length: Int32 = result.length ?? 0
        #expect(length == 4)
        #expect(result.objectAtIndexedSubscript(0)?.toInt32() == 2)
        #expect(result.objectAtIndexedSubscript(1)?.toInt32() == 0)
        #expect(result.objectAtIndexedSubscript(2)?.toInt32() == 3)
        #expect(result.objectAtIndexedSubscript(3)?.toInt32() == 0)
    }

    @Test("Uint32Array subarray converts only the viewed portion")
    func uint32ArraySubarrayConverts() {
        let value = context.evaluateScript("new Uint32Array([1, 2, 3]).subarray(0, 2)")!
        let result = JSValue.uint8Array(from: value, context: context)
        #expect(result.isUInt8Array == true)
        let length: Int32 = result.length ?? 0
        #expect(length == 8)
    }

    @Test("Float64Array subarray converts only the viewed portion")
    func float64ArraySubarrayConverts() {
        let value = context.evaluateScript("new Float64Array([1.0, 2.0, 3.0]).subarray(1, 2)")!
        let result = JSValue.uint8Array(from: value, context: context)
        #expect(result.isUInt8Array == true)
        let length: Int32 = result.length ?? 0
        #expect(length == 8)
    }

    @Test("Int8Array subarray converts only the viewed portion")
    func int8ArraySubarrayConverts() {
        let value = context.evaluateScript("new Int8Array([-1, 0, 1, 2, 3]).subarray(1, 4)")!
        let result = JSValue.uint8Array(from: value, context: context)
        #expect(result.isUInt8Array == true)
        let length: Int32 = result.length ?? 0
        #expect(length == 3)
        #expect(result.objectAtIndexedSubscript(0)?.toInt32() == 0)
        #expect(result.objectAtIndexedSubscript(1)?.toInt32() == 1)
        #expect(result.objectAtIndexedSubscript(2)?.toInt32() == 2)
    }

    // MARK: - Fallback (non-binary types)

    @Test("JS array falls back to Uint8Array constructor")
    func jsArrayFallback() {
        let value = context.evaluateScript("[10, 20, 30]")!
        let result = JSValue.uint8Array(from: value, context: context)
        #expect(result.isUInt8Array == true)
        #expect(result.objectAtIndexedSubscript(0)?.toInt32() == 10)
        #expect(result.objectAtIndexedSubscript(1)?.toInt32() == 20)
        #expect(result.objectAtIndexedSubscript(2)?.toInt32() == 30)
    }

    @Test("Number falls back — creates Uint8Array of that length")
    func numberFallback() {
        let value = JSValue(int32: 5, in: context)!
        let result = JSValue.uint8Array(from: value, context: context)
        #expect(result.isUInt8Array == true)
        let length: Int32 = result.length ?? 0
        #expect(length == 5)
    }

    @Test("Boolean true falls back — creates Uint8Array of length 1")
    func booleanTrueFallback() {
        let value = JSValue(bool: true, in: context)!
        let result = JSValue.uint8Array(from: value, context: context)
        #expect(result.isUInt8Array == true)
        let length: Int32 = result.length ?? 0
        #expect(length == 1)
    }

    @Test("Boolean false falls back — creates Uint8Array of length 0")
    func booleanFalseFallback() {
        let value = JSValue(bool: false, in: context)!
        let result = JSValue.uint8Array(from: value, context: context)
        #expect(result.isUInt8Array == true)
        let length: Int32 = result.length ?? 0
        #expect(length == 0)
    }

    @Test("Plain object falls back — creates empty Uint8Array")
    func plainObjectFallback() {
        let value = context.evaluateScript("({})")!
        let result = JSValue.uint8Array(from: value, context: context)
        #expect(result.isUInt8Array == true)
        let length: Int32 = result.length ?? 0
        #expect(length == 0)
    }

    @Test("String falls back — creates empty Uint8Array")
    func stringFallback() {
        let value = JSValue(object: "hello", in: context)!
        let result = JSValue.uint8Array(from: value, context: context)
        #expect(result.isUInt8Array == true)
        let length: Int32 = result.length ?? 0
        #expect(length == 0)
    }
}

@Suite("Data(uint8Array:) Tests")
struct DataFromUint8ArrayTests {

    private let context = JSContext()!

    @Test("Initializes from Uint8Array with correct bytes")
    func initFromUint8Array() {
        let value = context.evaluateScript("new Uint8Array([1, 2, 3])")!
        let data = Data(uint8Array: value)
        #expect(data == Data([1, 2, 3]))
    }

    @Test("Initializes from empty Uint8Array")
    func initFromEmptyUint8Array() {
        let value = context.evaluateScript("new Uint8Array([])")!
        let data = Data(uint8Array: value)
        #expect(data == Data())
    }

    @Test("Preserves all 256 byte values")
    func preservesAll256Values() {
        let value = context.evaluateScript("""
            (function() {
                var arr = new Uint8Array(256);
                for (var i = 0; i < 256; i++) arr[i] = i;
                return arr;
            })()
        """)!
        let data = Data(uint8Array: value)
        let expected = Data((0...255).map { UInt8($0) })
        #expect(data == expected)
    }

    @Test("Handles large Uint8Array")
    func handlesLargeArray() {
        let value = context.evaluateScript("""
            (function() {
                var arr = new Uint8Array(1024);
                for (var i = 0; i < 1024; i++) arr[i] = i % 256;
                return arr;
            })()
        """)!
        let data = Data(uint8Array: value)
        #expect(data?.count == 1024)
        for i in 0..<1024 {
            #expect(data?[i] == UInt8(i % 256))
        }
    }

    @Test("Handles Uint8Array with boundary values")
    func handlesBoundaryValues() {
        let value = context.evaluateScript("new Uint8Array([0, 1, 254, 255])")!
        let data = Data(uint8Array: value)
        #expect(data == Data([0, 1, 254, 255]))
    }

    @Test("Handles single-element Uint8Array")
    func handlesSingleElement() {
        let value = context.evaluateScript("new Uint8Array([42])")!
        let data = Data(uint8Array: value)
        #expect(data == Data([42]))
    }

    @Test("Handles Uint8Array subarray")
    func handlesSubarray() {
        let value = context.evaluateScript("new Uint8Array([10, 20, 30, 40, 50]).subarray(1, 4)")!
        let data = Data(uint8Array: value)
        #expect(data == Data([20, 30, 40]))
    }

    @Test("Returns nil for undefined")
    func returnsNilForUndefined() {
        let value = JSValue(undefinedIn: context)!
        let data = Data(uint8Array: value)
        #expect(data == nil)
    }

    @Test("Returns nil for null")
    func returnsNilForNull() {
        let value = JSValue(nullIn: context)!
        let data = Data(uint8Array: value)
        #expect(data == nil)
    }

    @Test("Returns nil for Int8Array")
    func returnsNilForInt8Array() {
        let value = context.evaluateScript("new Int8Array([1, 2])")!
        let data = Data(uint8Array: value)
        #expect(data == nil)
    }

    @Test("Returns nil for Uint16Array")
    func returnsNilForUint16Array() {
        let value = context.evaluateScript("new Uint16Array([1])")!
        let data = Data(uint8Array: value)
        #expect(data == nil)
    }

    @Test("Returns nil for Uint32Array")
    func returnsNilForUint32Array() {
        let value = context.evaluateScript("new Uint32Array([1])")!
        let data = Data(uint8Array: value)
        #expect(data == nil)
    }

    @Test("Returns nil for Float32Array")
    func returnsNilForFloat32Array() {
        let value = context.evaluateScript("new Float32Array([1.0])")!
        let data = Data(uint8Array: value)
        #expect(data == nil)
    }

    @Test("Returns nil for Float64Array")
    func returnsNilForFloat64Array() {
        let value = context.evaluateScript("new Float64Array([1.0])")!
        let data = Data(uint8Array: value)
        #expect(data == nil)
    }

    @Test("Returns nil for Uint8ClampedArray")
    func returnsNilForUint8ClampedArray() {
        let value = context.evaluateScript("new Uint8ClampedArray([1])")!
        let data = Data(uint8Array: value)
        #expect(data == nil)
    }

    @Test("Returns nil for ArrayBuffer")
    func returnsNilForArrayBuffer() {
        let value = context.evaluateScript("new ArrayBuffer(4)")!
        let data = Data(uint8Array: value)
        #expect(data == nil)
    }

    @Test("Returns nil for DataView")
    func returnsNilForDataView() {
        let value = context.evaluateScript("new DataView(new ArrayBuffer(4))")!
        let data = Data(uint8Array: value)
        #expect(data == nil)
    }

    @Test("Returns nil for plain JS object")
    func returnsNilForPlainObject() {
        let value = context.evaluateScript("({})")!
        let data = Data(uint8Array: value)
        #expect(data == nil)
    }

    @Test("Returns nil for JS array")
    func returnsNilForJSArray() {
        let value = context.evaluateScript("[1, 2, 3]")!
        let data = Data(uint8Array: value)
        #expect(data == nil)
    }

    @Test("Returns nil for string")
    func returnsNilForString() {
        let value = JSValue(object: "hello", in: context)!
        let data = Data(uint8Array: value)
        #expect(data == nil)
    }

    @Test("Returns nil for number")
    func returnsNilForNumber() {
        let value = JSValue(int32: 42, in: context)!
        let data = Data(uint8Array: value)
        #expect(data == nil)
    }

    @Test("Returns nil for boolean")
    func returnsNilForBoolean() {
        let value = JSValue(bool: true, in: context)!
        let data = Data(uint8Array: value)
        #expect(data == nil)
    }
}

@Suite("JSValue bytesNumber Tests")
struct JSValueBytesNumberTests {

    private let context: JSContext = {
        let ctx = JSContext()!
        try! ctx.install([.blob])
        return ctx
    }()

    @Test("ASCII string returns UTF-8 byte count")
    func asciiString() {
        let value = JSValue(object: "hello", in: context)!
        #expect(value.bytesNumber == 5)
    }

    @Test("Empty string returns zero")
    func emptyString() {
        let value = JSValue(object: "", in: context)!
        #expect(value.bytesNumber == 0)
    }

    @Test("Multi-byte UTF-8 string returns correct byte count")
    func multiByteString() {
        let value = JSValue(object: "héllo", in: context)!
        #expect(value.bytesNumber == 6)
    }

    @Test("Emoji string returns 4 bytes per emoji")
    func emojiString() {
        let value = JSValue(object: "😀", in: context)!
        #expect(value.bytesNumber == 4)
    }

    @Test("Blob returns size")
    func blobReturnsSize() {
        let blob = context.evaluateScript("new Blob(['hello world'])")!
        #expect(blob.bytesNumber == 11)
    }

    @Test("Empty Blob returns zero")
    func emptyBlob() {
        let blob = context.evaluateScript("new Blob([])")!
        #expect(blob.bytesNumber == 0)
    }

    @Test("Uint8Array returns byteLength")
    func uint8Array() {
        let value = context.evaluateScript("new Uint8Array([1, 2, 3])")!
        #expect(value.bytesNumber == 3)
    }

    @Test("Uint16Array returns byteLength")
    func uint16Array() {
        let value = context.evaluateScript("new Uint16Array([1, 2])")!
        #expect(value.bytesNumber == 4)
    }

    @Test("Uint32Array returns byteLength")
    func uint32Array() {
        let value = context.evaluateScript("new Uint32Array([1])")!
        #expect(value.bytesNumber == 4)
    }

    @Test("Float64Array returns byteLength")
    func float64Array() {
        let value = context.evaluateScript("new Float64Array([1.0, 2.0])")!
        #expect(value.bytesNumber == 16)
    }

    @Test("ArrayBuffer returns byteLength")
    func arrayBuffer() {
        let value = context.evaluateScript("new ArrayBuffer(10)")!
        #expect(value.bytesNumber == 10)
    }

    @Test("Empty ArrayBuffer returns zero")
    func emptyArrayBuffer() {
        let value = context.evaluateScript("new ArrayBuffer(0)")!
        #expect(value.bytesNumber == 0)
    }

    @Test("DataView returns byteLength of the view")
    func dataView() {
        let value = context.evaluateScript("new DataView(new ArrayBuffer(8), 2, 4)")!
        #expect(value.bytesNumber == 4)
    }

    @Test("TypedArray subarray returns subarray byteLength")
    func typedArraySubarray() {
        let value = context.evaluateScript("new Uint16Array([1, 2, 3, 4]).subarray(1, 3)")!
        #expect(value.bytesNumber == 4)
    }

    @Test("Uint8Array subarray returns subarray byteLength")
    func uint8ArraySubarray() {
        let value = context.evaluateScript("new Uint8Array([1, 2, 3, 4, 5]).subarray(1, 4)")!
        #expect(value.bytesNumber == 3)
    }

    @Test("Number returns zero")
    func numberReturnsZero() {
        let value = JSValue(int32: 42, in: context)!
        #expect(value.bytesNumber == 0)
    }

    @Test("Null returns zero")
    func nullReturnsZero() {
        let value = JSValue(nullIn: context)!
        #expect(value.bytesNumber == 0)
    }

    @Test("Undefined returns zero")
    func undefinedReturnsZero() {
        let value = JSValue(undefinedIn: context)!
        #expect(value.bytesNumber == 0)
    }

    @Test("Boolean returns zero")
    func booleanReturnsZero() {
        let value = JSValue(bool: true, in: context)!
        #expect(value.bytesNumber == 0)
    }

    @Test("Plain object returns zero")
    func plainObjectReturnsZero() {
        let value = context.evaluateScript("({})")!
        #expect(value.bytesNumber == 0)
    }
}
