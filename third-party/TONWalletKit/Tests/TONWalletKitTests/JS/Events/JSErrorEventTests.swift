//
//  JSErrorEventTests.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 16.03.2026.
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

@Suite("JSErrorEvent Tests")
struct JSErrorEventTests {

    private let context: JSContext = {
        let ctx = JSContext()!
        ctx.evaluateScript("""
            function getEventType(event) {
                return event.type;
            }
            function getEventMessage(event) {
                return event.message;
            }
            function getEventFilename(event) {
                return event.filename;
            }
            function getEventLineno(event) {
                return event.lineno;
            }
            function getEventColno(event) {
                return event.colno;
            }
            function getEventErrorMessage(event) {
                return event.error instanceof Error ? event.error.message : null;
            }
            function getEventBubbles(event) {
                return event.bubbles;
            }
            function getEventCancelable(event) {
                return event.cancelable;
            }
            function getEventComposed(event) {
                return event.composed;
            }
        """)
        return ctx
    }()

    @Test("JSErrorEvent encodes type correctly")
    func errorEventEncodesType() throws {
        let event = JSErrorEvent(type: .error)
        let result: String = try context.getEventType(event)
        #expect(JSEventType(rawValue: result) == .error)
    }

    @Test("JSErrorEvent encodes default properties")
    func errorEventEncodesDefaultProperties() throws {
        let event = JSErrorEvent(type: .error)

        let message: String = try context.getEventMessage(event)
        let filename: String = try context.getEventFilename(event)
        let lineno: Int = try context.getEventLineno(event)
        let colno: Int = try context.getEventColno(event)
        let bubbles: Bool = try context.getEventBubbles(event)
        let cancelable: Bool = try context.getEventCancelable(event)
        let composed: Bool = try context.getEventComposed(event)

        #expect(message == "")
        #expect(filename == "")
        #expect(lineno == 0)
        #expect(colno == 0)
        #expect(bubbles == false)
        #expect(cancelable == false)
        #expect(composed == false)
    }

    @Test("JSErrorEvent encodes custom properties")
    func errorEventEncodesCustomProperties() throws {
        let properties = JSErrorEventProperties(
            bubbles: true,
            cancelable: true,
            composed: true,
            message: "Unexpected token",
            filename: "app.js",
            lineno: 42,
            colno: 10,
            error: "SyntaxError: Unexpected token"
        )
        let event = JSErrorEvent(type: .error, properties: properties)

        let message: String = try context.getEventMessage(event)
        let filename: String = try context.getEventFilename(event)
        let lineno: Int = try context.getEventLineno(event)
        let colno: Int = try context.getEventColno(event)
        let bubbles: Bool = try context.getEventBubbles(event)
        let cancelable: Bool = try context.getEventCancelable(event)
        let composed: Bool = try context.getEventComposed(event)

        #expect(message == "Unexpected token")
        #expect(filename == "app.js")
        #expect(lineno == 42)
        #expect(colno == 10)
        #expect(bubbles == true)
        #expect(cancelable == true)
        #expect(composed == true)
    }

    @Test("JSErrorEvent error property is a JS Error instance")
    func errorEventErrorIsJSError() throws {
        let properties = JSErrorEventProperties(error: "Something went wrong")
        let event = JSErrorEvent(type: .error, properties: properties)

        let errorMessage: String = try context.getEventErrorMessage(event)
        #expect(errorMessage == "Something went wrong")
    }

    @Test("JSErrorEvent error falls back to string when context is nil")
    func errorEventErrorFallsBackWhenContextIsNil() throws {
        let properties = JSErrorEventProperties(error: "Connection failed")
        let event = JSErrorEvent(type: .error, properties: properties)

        var ctx: JSContext? = JSContext()
        let export = try event.encode(in: ctx!) as! NSObject
        ctx = nil

        let error = export.value(forKey: "error") as? String
        #expect(error == "Connection failed")
    }
}
