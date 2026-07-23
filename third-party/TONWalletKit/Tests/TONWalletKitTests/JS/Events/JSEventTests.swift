//
//  JSEventTests.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 15.03.2026.
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

private struct MockEventProperties: JSEventProperties {
    var bubbles: Bool
    var cancelable: Bool
    var composed: Bool

    init(bubbles: Bool = false, cancelable: Bool = false, composed: Bool = false) {
        self.bubbles = bubbles
        self.cancelable = cancelable
        self.composed = composed
    }
}

@Suite("JSEvent Tests")
struct JSEventTests {

    private let context: JSContext = {
        let ctx = JSContext()!
        ctx.evaluateScript("""
            function getEventType(event) {
                return event.type;
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

    @Test("JSEvent encodes type correctly", arguments: [
        JSEventType.open,
        JSEventType.close,
        JSEventType.error,
        JSEventType.message
    ])
    func eventEncodesType(_ eventType: JSEventType) throws {
        let event = JSEvent(type: eventType, properties: MockEventProperties())
        let result: String = try context.getEventType(event)
        #expect(result == eventType.rawValue)
    }

    @Test("JSEvent encodes default properties")
    func eventEncodesDefaultProperties() throws {
        let event = JSEvent(type: .open, properties: MockEventProperties())

        let bubbles: Bool = try context.getEventBubbles(event)
        let cancelable: Bool = try context.getEventCancelable(event)
        let composed: Bool = try context.getEventComposed(event)

        #expect(bubbles == false)
        #expect(cancelable == false)
        #expect(composed == false)
    }

    @Test("JSEvent encodes custom properties")
    func eventEncodesCustomProperties() throws {
        let properties = MockEventProperties(bubbles: true, cancelable: true, composed: true)
        let event = JSEvent(type: .message, properties: properties)

        let bubbles: Bool = try context.getEventBubbles(event)
        let cancelable: Bool = try context.getEventCancelable(event)
        let composed: Bool = try context.getEventComposed(event)

        #expect(bubbles == true)
        #expect(cancelable == true)
        #expect(composed == true)
    }
}
