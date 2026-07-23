//
//  JSObject.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 12.09.2025.
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

@dynamicMemberLookup
protocol JSDynamicObject {
    var jsContext: JSContext { get }
    
    subscript<T: JSValueDecodable>(dynamicMember member: String) -> T? { get }
    subscript(dynamicMember member: String) -> any JSDynamicObjectMember { get }
}

@dynamicCallable
protocol JSDynamicObjectMember: JSDynamicObject {
    
    @discardableResult
    func dynamicallyCall(withArguments args: [any JSValueEncodable]) async throws -> JSValue
    func dynamicallyCall<T>(withArguments args: [any JSValueEncodable]) async throws -> T where T: JSValueDecodable
    
    @discardableResult
    func dynamicallyCall(withArguments args: [any JSValueEncodable]) throws -> JSValue
    func dynamicallyCall<T>(withArguments args: [any JSValueEncodable]) throws -> T where T: JSValueDecodable
}

struct JSFunction: JSDynamicObjectMember {
    var jsContext: JSContext { parent.jsContext }
    
    let parent: any JSDynamicObject
    let value: any JSDynamicObject
    
    subscript<T: JSValueDecodable>(dynamicMember member: String) -> T? {
        value[dynamicMember: member]
    }
    
    subscript(dynamicMember member: String) -> any JSDynamicObjectMember {
        value[dynamicMember: member]
    }
    
    @discardableResult
    func dynamicallyCall(withArguments args: [any JSValueEncodable]) async throws -> JSValue {
        try await jsContext.promise(wrap: self, args: args.map { try $0.encode(in: jsContext) }).then()
    }
    
    func dynamicallyCall<T>(withArguments args: [any JSValueEncodable]) async throws -> T where T: JSValueDecodable {
        try await dynamicallyCall(withArguments: args).decode()
    }
    
    @discardableResult
    func dynamicallyCall(withArguments args: [any JSValueEncodable]) throws -> JSValue {
        let value = try jsContext.throwErrorToReturn(wrap: self, args: args.map { try $0.encode(in: jsContext) })
        
        if value.isPromise {
            throw JSError(message: "Unable to call async function of JS Promise in sync context")
        }
        return value
    }
    
    func dynamicallyCall<T>(withArguments args: [any JSValueEncodable]) throws -> T where T: JSValueDecodable {
        try dynamicallyCall(withArguments: args).decode()
    }
}

extension JSValue: JSDynamicObject {
    var jsContext: JSContext { context }
    
    subscript<T: JSValueDecodable>(dynamicMember member: String) -> T? {
        try? T.from(objectForKeyedSubscript(member))
    }
    
    subscript(dynamicMember member: String) -> any JSDynamicObjectMember {
        JSFunction(parent: self, value: objectForKeyedSubscript(member))
    }
}

extension JSContext: JSDynamicObject {
    var jsContext: JSContext { self }
    
    subscript<T: JSValueDecodable>(dynamicMember member: String) -> T? {
        try? T.from(objectForKeyedSubscript(member))
    }
    
    subscript(dynamicMember member: String) -> JSDynamicObjectMember {
        JSFunction(parent: self, value: objectForKeyedSubscript(member))
    }
}

extension JSValue {

    func then(
        _ onResolved: @escaping (JSValue) -> Void,
        _ onRejected: @escaping (JSValue) -> Void,
    ) throws {
        guard self.isPromise else {
            throw JSError(message: "Unable to call 'then' on non-promise JSValue")
        }
        
        let onResolvedWrapper: @convention(block) (JSValue) -> Void = { value in
            onResolved(value)
        }
        
        let onRejectedWrapper: @convention(block) (JSValue) -> Void = { value in
            onRejected(value)
        }
        self.invokeMethod(
            "then",
            withArguments: [
                unsafeBitCast(onResolvedWrapper, to: JSValue.self),
                unsafeBitCast(onRejectedWrapper, to: JSValue.self)
            ]
        )
    }
    
    func then() async throws -> JSValue {
        try await withCheckedThrowingContinuation { continuation in
            do {
                try then(
                    { continuation.resume(returning: $0) },
                    { continuation.resume(throwing: $0.toJSError() ?? JSError(message: $0.toString())) }
                )
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

extension JSContext {
    
    func promise(wrap function: JSFunction, args: [Any]) throws -> JSValue {
        let functionName = "__promiseWrapper"
        
        var promiseWrapper: JSValue? = self[dynamicMember: functionName]
        
        if let promiseWrapper {
            return try call(function: function, args: args, on: promiseWrapper)
        }
        
        let script = """
            function \(functionName)(fn, context = null, ...args) {
                try {
                  const result = fn.apply(context, args);
                  
                  if (result instanceof Promise) {
                    return result;
                  } else {
                    return Promise.resolve(result);
                  }
                } catch (error) {
                    return Promise.reject(error);
                }
            }
        """
        
        evaluateScript(script)
        
        promiseWrapper = self[dynamicMember: functionName]
        
        guard let promiseWrapper else {
            throw JSError(message: "JSFunctionError: No promise wrapper found")
        }
        
        return try call(function: function, args: args, on: promiseWrapper)
    }
    
    func throwErrorToReturn(wrap function: JSFunction, args: [Any]) throws -> JSValue {
        let functionName = "__throwErrorToReturn"
        
        var throwErrorToReturnWrapper: JSValue? = self[dynamicMember: functionName]
        
        if let throwErrorToReturnWrapper {
            return try call(function: function, args: args, on: throwErrorToReturnWrapper)
        }
        
        let script = """
            function \(functionName)(fn, context = null, ...args) {
                try {
                    return fn.apply(context, args);
                } catch (error) {
                    return error;
                }
            }
        """
        
        evaluateScript(script)
        
        throwErrorToReturnWrapper = self[dynamicMember: functionName]
        
        guard let throwErrorToReturnWrapper else {
            throw JSError(message: "JSFunctionError: No error return wrapper found")
        }
        
        return try call(function: function, args: args, on: throwErrorToReturnWrapper)
    }

    func call(function: JSFunction, args: [Any], on wrapper: JSValue) throws -> JSValue {
        let value: JSValue = wrapper.call(withArguments: [function.value, function.parent] + args)
        
        if value.isJSError == true, let error = value.toJSError() {
            throw error
        }
        return value
    }
}
