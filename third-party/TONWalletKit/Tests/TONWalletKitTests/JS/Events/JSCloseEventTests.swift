//
//  JSCloseEventTests.swift
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

@Suite("JSCloseEvent Tests")
struct JSCloseEventTests {

    private let context: JSContext = {
        let ctx = JSContext()!
        ctx.evaluateScript("""
            function getEventType(event) {
                return event.type;
            }
            function getEventCode(event) {
                return event.code;
            }
            function getEventReason(event) {
                return event.reason;
            }
            function getEventWasClean(event) {
                return event.wasClean;
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

    @Test("JSCloseEvent has close type")
    func closeEventHasCloseType() throws {
        let event = JSCloseEvent()
        let result: String = try context.getEventType(event)
        #expect(JSEventType(rawValue: result) == .close)
    }

    @Test("JSCloseEvent encodes default properties")
    func closeEventEncodesDefaultProperties() throws {
        let event = JSCloseEvent()

        let code: Int = try context.getEventCode(event)
        let reason: String = try context.getEventReason(event)
        let wasClean: Bool = try context.getEventWasClean(event)
        let bubbles: Bool = try context.getEventBubbles(event)
        let cancelable: Bool = try context.getEventCancelable(event)
        let composed: Bool = try context.getEventComposed(event)

        #expect(code == 0)
        #expect(reason == "")
        #expect(wasClean == false)
        #expect(bubbles == false)
        #expect(cancelable == false)
        #expect(composed == false)
    }

    @Test("JSCloseEvent encodes custom properties")
    func closeEventEncodesCustomProperties() throws {
        let properties = JSCloseEventProperties(
            bubbles: true,
            cancelable: true,
            composed: true,
            wasClean: true,
            code: 1000,
            reason: "Normal closure"
        )
        let event = JSCloseEvent(properties: properties)

        let code: Int = try context.getEventCode(event)
        let reason: String = try context.getEventReason(event)
        let wasClean: Bool = try context.getEventWasClean(event)
        let bubbles: Bool = try context.getEventBubbles(event)
        let cancelable: Bool = try context.getEventCancelable(event)
        let composed: Bool = try context.getEventComposed(event)

        #expect(code == 1000)
        #expect(reason == "Normal closure")
        #expect(wasClean == true)
        #expect(bubbles == true)
        #expect(cancelable == true)
        #expect(composed == true)
    }
}
