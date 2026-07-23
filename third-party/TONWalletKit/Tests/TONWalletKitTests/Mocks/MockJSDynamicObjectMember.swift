//
//  MockJSDynamicObjectMember.swift
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

import JavaScriptCore
@testable import TONWalletKit

struct MockJSDynamicObjectMember: JSDynamicObjectMember {
    let root: MockJSDynamicObject
    let path: String

    var jsContext: JSContext { root.jsContext }

    subscript<T: JSValueDecodable>(dynamicMember member: String) -> T? {
        nil
    }

    subscript(dynamicMember member: String) -> any JSDynamicObjectMember {
        MockJSDynamicObjectMember(root: root, path: "\(path).\(member)")
    }

    @discardableResult
    func dynamicallyCall(withArguments args: [any JSValueEncodable]) async throws -> JSValue {
        root.recordCall(path: path, args: args)
        if root.shouldThrowOnCall { throw "Mock call error" }
        if let result = root.stubbedAsyncResults[path] as? JSValue {
            return result
        }
        if let result = root.stubbedResults[path] as? JSValue {
            return result
        }
        return JSValue(undefinedIn: jsContext)
    }

    func dynamicallyCall<T>(withArguments args: [any JSValueEncodable]) async throws -> T where T: JSValueDecodable {
        _ = try await dynamicallyCall(withArguments: args) as JSValue
        if let result = root.stubbedAsyncResults[path] as? T {
            return result
        }
        if let result = root.stubbedResults[path] as? T {
            return result
        }
        throw "Mock: cannot decode to \(T.self)"
    }

    @discardableResult
    func dynamicallyCall(withArguments args: [any JSValueEncodable]) throws -> JSValue {
        root.recordCall(path: path, args: args)
        if root.shouldThrowOnCall { throw "Mock call error" }
        if let result = root.stubbedResults[path] as? JSValue {
            return result
        }
        return JSValue(undefinedIn: jsContext)
    }

    func dynamicallyCall<T>(withArguments args: [any JSValueEncodable]) throws -> T where T: JSValueDecodable {
        _ = try dynamicallyCall(withArguments: args) as JSValue
        if let result = root.stubbedResults[path] as? T {
            return result
        }
        throw "Mock: cannot decode to \(T.self)"
    }
}
