//
//  JSTestConversionContext.swift
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

import Foundation
import JavaScriptCore

class JSTestConversionContext: JSContext {
    
    override init() {
        super.init()
        
        let js = """
            function String() {
                return "String";
            }
            
            function Int() {
                return \(Int.max);
            }
            
            function Int64() {
                return \(Int64.max);
            }
            
            function Int32() {
                return \(Int32.max);
            }
            
            function UInt() {
                return \(UInt.max);
            }
            
            function UInt64() {
                return \(UInt64.max);
            }
            
            function UInt32() {
                return \(UInt32.max);
            }
            
            function Double() {
                return \(Double.greatestFiniteMagnitude);
            }
            
            function Float() {
                return \(Float.greatestFiniteMagnitude);
            }
            
            function Bool() {
                return true;
            }
            
            function DateValue() {
                return new Date("2023-01-01T00:00:00Z");
            }
            
            function Dictionary() {
                return { key: "value" };
            }
            
            function Array() {
                return [1, 2, 3];
            }
            
            function JSTestDecodable() {
                return { test: "testValue" };
            }
            
            function undefinedValue() {
                return undefined;
            }
            
            function nullValue() {
                return null;
            }
            
            function voidValue() {
                return;
            }
             
            function IntInString() {
                return "12345";
            }
            
            function _isString(value) {
                return typeof value === 'string';
            }
            
            function _isNumber(value) {
                return typeof value === 'number';
            }
            
            function _isBoolean(value) {
                return typeof value === 'boolean';
            }
            
            function _isDate(value) {
                return value instanceof Date;
            }
            
            function _isArray(value) {
                return Object.prototype.toString.call(value) === '[object Array]'
            }
            
            function _isNull(value) {
                return value === null;
            }
            
            function _validateJSTestDecodable(value) {
                return typeof value === 'object' && value.hasOwnProperty('test') && typeof value.test === 'string' && value.test === 'testValue';
            }
            
            function _validateMultipleParameters(stringValue, intValue, boolValue) {
                return typeof stringValue === 'string' && stringValue === 'testString' &&
                       typeof intValue === 'number' && intValue === 42 &&
                       typeof boolValue === 'boolean' && boolValue === true;
            }
            """
        evaluateScript(js)
    }
    
    override init!(virtualMachine: JSVirtualMachine!) {
        super.init(virtualMachine: virtualMachine)
    }
}
