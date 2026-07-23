//
//  MockJSDynamicObject.swift
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

class MockJSDynamicObject: JSDynamicObject {
    let jsContext: JSContext
    var callRecords: [(path: String, args: [Any])] = []
    var shouldThrowOnCall: Bool = false
    var stubbedResults: [String: Any] = [:]
    var stubbedAsyncResults: [String: Any] = [:]
    var stubbedProperties: [String: Any] = [:]

    init(jsContext: JSContext = JSContext()!) {
        self.jsContext = jsContext
    }

    subscript<T: JSValueDecodable>(dynamicMember member: String) -> T? {
        stubbedProperties[member] as? T
    }

    subscript(dynamicMember member: String) -> any JSDynamicObjectMember {
        MockJSDynamicObjectMember(root: self, path: member)
    }

    func recordCall(path: String, args: [Any]) {
        callRecords.append((path: path, args: args))
    }
}
