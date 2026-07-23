//
//  JSMessageEventTests.swift
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

@Suite("JSMessageEvent Tests")
struct JSMessageEventTests {

    private let context: JSContext = {
        let ctx = JSContext()!
        ctx.evaluateScript("""
            function getEventType(event) {
                return event.type;
            }
            function getEventData(event) {
                return event.data;
            }
            function getEventOrigin(event) {
                return event.origin;
            }
            function getEventLastEventId(event) {
                return event.lastEventId;
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

    @Test("JSMessageEvent encodes type correctly")
    func messageEventEncodesType() throws {
        let event = JSMessageEvent(type: .message)
        let result: String = try context.getEventType(event)
        #expect(JSEventType(rawValue: result) == .message)
    }

    @Test("JSMessageEvent encodes default properties")
    func messageEventEncodesDefaultProperties() throws {
        let event = JSMessageEvent(type: .message)

        let data: JSValue = try context.getEventData(event)
        let origin: String = try context.getEventOrigin(event)
        let lastEventId: String = try context.getEventLastEventId(event)
        let bubbles: Bool = try context.getEventBubbles(event)
        let cancelable: Bool = try context.getEventCancelable(event)
        let composed: Bool = try context.getEventComposed(event)

        #expect(data.isUndefined)
        #expect(origin == "")
        #expect(lastEventId == "")
        #expect(bubbles == false)
        #expect(cancelable == false)
        #expect(composed == false)
    }

    @Test("JSMessageEvent encodes custom properties with string data")
    func messageEventEncodesCustomProperties() throws {
        let jsData = JSValue(object: "hello world", in: context)
        let properties = JSMessageEventProperties(
            bubbles: true,
            cancelable: true,
            composed: true,
            data: jsData,
            origin: "ws://localhost:8080",
            lastEventId: "evt-42"
        )
        let event = JSMessageEvent(type: .message, properties: properties)

        let data: String = try context.getEventData(event)
        let origin: String = try context.getEventOrigin(event)
        let lastEventId: String = try context.getEventLastEventId(event)
        let bubbles: Bool = try context.getEventBubbles(event)
        let cancelable: Bool = try context.getEventCancelable(event)
        let composed: Bool = try context.getEventComposed(event)

        #expect(data == "hello world")
        #expect(origin == "ws://localhost:8080")
        #expect(lastEventId == "evt-42")
        #expect(bubbles == true)
        #expect(cancelable == true)
        #expect(composed == true)
    }

    @Test("JSMessageEvent encodes object data")
    func messageEventEncodesObjectData() throws {
        let jsData = context.evaluateScript("({key: 'value'})")
        let properties = JSMessageEventProperties(data: jsData)
        let event = JSMessageEvent(type: .message, properties: properties)

        let result: JSValue = try context.getEventData(event)
        let key: String? = result.key
        #expect(key == "value")
    }
}
