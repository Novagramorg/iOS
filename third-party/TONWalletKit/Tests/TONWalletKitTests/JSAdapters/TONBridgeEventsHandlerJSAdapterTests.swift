//
//  TONBridgeEventsHandlerJSAdapterTests.swift
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

import Testing
import JavaScriptCore
@testable import TONWalletKit

@Suite("TONBridgeEventsHandlerJSAdapter Tests")
struct TONBridgeEventsHandlerJSAdapterTests {

    @Test("isValid returns true when handler and context are alive")
    func isValidWhenBothAlive() {
        let handler = MockTONBridgeEventsHandler()
        let context = MockWalletKitContext()
        let sut = TONBridgeEventsHandlerJSAdapter(handler: handler, context: context)

        #expect(sut.isValid)
    }

    @Test("isValid returns false when handler is deallocated")
    func isValidWhenHandlerDeallocated() {
        var handler: MockTONBridgeEventsHandler? = MockTONBridgeEventsHandler()
        let context = MockWalletKitContext()
        let sut = TONBridgeEventsHandlerJSAdapter(handler: handler!, context: context)

        handler = nil

        #expect(!sut.isValid)
    }

    @Test("isValid returns false when context is deallocated")
    func isValidWhenContextDeallocated() {
        let handler = MockTONBridgeEventsHandler()
        var context: MockWalletKitContext? = MockWalletKitContext()
        let sut = TONBridgeEventsHandlerJSAdapter(handler: handler, context: context!)

        context = nil

        #expect(!sut.isValid)
    }

    @Test("Invalidate makes isValid return false")
    func invalidateSetsToFalse() {
        let handler = MockTONBridgeEventsHandler()
        let context = MockWalletKitContext()
        let sut = TONBridgeEventsHandlerJSAdapter(handler: handler, context: context)

        sut.invalidate()

        #expect(!sut.isValid)
    }

    @Test("Handle throws when handler is nil")
    func handleThrowsWhenHandlerNil() {
        var handler: MockTONBridgeEventsHandler? = MockTONBridgeEventsHandler()
        let context = MockWalletKitContext()
        let sut = TONBridgeEventsHandlerJSAdapter(handler: handler!, context: context)
        handler = nil

        let event = JSWalletKitSwiftBridgeEvent(
            type: .disconnect,
            value: JSValue(undefinedIn: context.jsContext)
        )

        let error = #expect(throws: TONBridgeEventError.self) {
            try sut.handle(event: event)
        }

        guard case .unhandledEvent(let type)? = error else {
            Issue.record("Expected .unhandledEvent, got \(String(describing: error))")
            return
        }
        #expect(type == "disconnect")
    }

    @Test("Handle throws when context is nil")
    func handleThrowsWhenContextNil() {
        let handler = MockTONBridgeEventsHandler()
        var context: MockWalletKitContext? = MockWalletKitContext()
        let sut = TONBridgeEventsHandlerJSAdapter(handler: handler, context: context!)
        context = nil

        let jsContext = JSContext()!
        let event = JSWalletKitSwiftBridgeEvent(
            type: .disconnect,
            value: JSValue(undefinedIn: jsContext)
        )

        let error = #expect(throws: TONBridgeEventError.self) {
            try sut.handle(event: event)
        }

        guard case .unhandledEvent(let type)? = error else {
            Issue.record("Expected .unhandledEvent, got \(String(describing: error))")
            return
        }
        #expect(type == "disconnect")
    }

    @Test("Adapter equals its handler")
    func equalsItsHandler() {
        let handler = MockTONBridgeEventsHandler()
        let context = MockWalletKitContext()
        let sut = TONBridgeEventsHandlerJSAdapter(handler: handler, context: context)

        #expect(sut == handler)
    }

    @Test("Adapter does not equal a different handler")
    func doesNotEqualDifferentHandler() {
        let handler = MockTONBridgeEventsHandler()
        let other = MockTONBridgeEventsHandler()
        let context = MockWalletKitContext()
        let sut = TONBridgeEventsHandlerJSAdapter(handler: handler, context: context)

        #expect(!(sut == other))
    }

    @Test("Adapter does not equal any handler after invalidate")
    func doesNotEqualAfterInvalidate() {
        let handler = MockTONBridgeEventsHandler()
        let context = MockWalletKitContext()
        let sut = TONBridgeEventsHandlerJSAdapter(handler: handler, context: context)

        sut.invalidate()

        #expect(!(sut == handler))
    }
}
