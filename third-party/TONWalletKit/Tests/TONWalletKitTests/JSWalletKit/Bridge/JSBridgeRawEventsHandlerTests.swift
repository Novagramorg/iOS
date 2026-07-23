//
//  JSBridgeRawEventsHandlerTests.swift
//  TONWalletKit
//
//  Created by Claude on 08.02.2026.
//

import Testing
import JavaScriptCore
@_private(sourceFile: "JSBridgeRawEventsHandler.swift")
@testable import TONWalletKit

@Suite("JSBridgeRawEventsHandler Tests")
struct JSBridgeRawEventsHandlerTests {

    private let context = JSContext()!

    private func makeJSValue(_ value: Any? = nil) -> JSValue {
        if let value {
            return JSValue(object: value, in: context)
        }
        return JSValue(undefinedIn: context)
    }

    @Test("isEmpty returns true when initialized with empty array")
    func isEmptyWithNoHandlers() {
        let sut = JSBridgeRawEventsHandler(handlers: [])
        #expect(sut.isEmpty)
    }

    @Test("isEmpty returns false when initialized with handlers")
    func isNotEmptyWithHandlers() {
        let handler = MockJSBridgeEventsHandler()
        let sut = JSBridgeRawEventsHandler(handlers: [handler])
        #expect(!sut.isEmpty)
    }

    @Test("Add appends a new handler")
    func addHandler() {
        let sut = JSBridgeRawEventsHandler(handlers: [])
        let handler = MockJSBridgeEventsHandler()

        sut.add(handler: handler)

        #expect(!sut.isEmpty)
        #expect(sut.handlers.count == 1)
    }

    @Test("Add does not duplicate the same handler instance")
    func addDuplicateHandler() {
        let handler = MockJSBridgeEventsHandler()
        let sut = JSBridgeRawEventsHandler(handlers: [handler])

        sut.add(handler: handler)

        #expect(sut.handlers.count == 1)
    }

    @Test("Add allows different handler instances")
    func addDifferentHandlers() {
        let sut = JSBridgeRawEventsHandler(handlers: [])
        let handler1 = MockJSBridgeEventsHandler()
        let handler2 = MockJSBridgeEventsHandler()

        sut.add(handler: handler1)
        sut.add(handler: handler2)

        #expect(sut.handlers.count == 2)
    }

    @Test("Add cleans invalid handlers")
    func addCleansInvalid() {
        let invalid = MockJSBridgeEventsHandler()
        invalid.isValid = false
        let sut = JSBridgeRawEventsHandler(handlers: [invalid])

        let valid = MockJSBridgeEventsHandler()
        sut.add(handler: valid)

        #expect(sut.handlers.count == 1)
        #expect(sut.handlers.first === valid)
    }

    // MARK: - remove(handler:)

    @Test("Remove removes the specified handler")
    func removeHandler() {
        let handler = MockJSBridgeEventsHandler()
        let sut = JSBridgeRawEventsHandler(handlers: [handler])

        sut.remove(handler: handler)

        #expect(sut.isEmpty)
    }

    @Test("Remove does nothing for unknown handler")
    func removeUnknownHandler() {
        let handler1 = MockJSBridgeEventsHandler()
        let handler2 = MockJSBridgeEventsHandler()
        let sut = JSBridgeRawEventsHandler(handlers: [handler1])

        sut.remove(handler: handler2)

        #expect(sut.handlers.count == 1)
    }

    @Test("Remove cleans invalid handlers")
    func removeCleansInvalid() {
        let invalid = MockJSBridgeEventsHandler()
        invalid.isValid = false
        let valid = MockJSBridgeEventsHandler()
        let sut = JSBridgeRawEventsHandler(handlers: [invalid, valid])

        let other = MockJSBridgeEventsHandler()
        sut.remove(handler: other)

        #expect(sut.handlers.count == 1)
        #expect(sut.handlers.first === valid)
    }

    // MARK: - handle(eventType:eventData:)

    @Test("Handle throws .unknownEventType for unknown event type")
    func handleUnknownEventType() {
        let handler = MockJSBridgeEventsHandler()
        let sut = JSBridgeRawEventsHandler(handlers: [handler])

        let error = #expect(throws: TONBridgeEventError.self) {
            try sut.handle(eventType: "unknownEvent", eventData: makeJSValue())
        }

        guard case .unknownEventType(let type)? = error else {
            Issue.record("Expected .unknownEventType, got \(String(describing: error))")
            return
        }
        #expect(type == "unknownEvent")
    }

    @Test("Handle throws .noHandlerRegistered when no handlers remain after clean")
    func handleNoHandlersAfterClean() {
        let invalid = MockJSBridgeEventsHandler()
        invalid.isValid = false
        let sut = JSBridgeRawEventsHandler(handlers: [invalid])

        let error = #expect(throws: TONBridgeEventError.self) {
            try sut.handle(eventType: "connectRequest", eventData: makeJSValue())
        }

        guard case .noHandlerRegistered(let eventType)? = error else {
            Issue.record("Expected .noHandlerRegistered, got \(String(describing: error))")
            return
        }
        #expect(eventType == "connectRequest")
    }

    @Test("Handle dispatches event to handler",
          arguments: [
            "connectRequest",
            "transactionRequest",
            "signDataRequest",
            "disconnect"
          ])
    func handleDispatchesEvent(eventType: String) throws {
        let handler = MockJSBridgeEventsHandler()
        let sut = JSBridgeRawEventsHandler(handlers: [handler])

        try sut.handle(eventType: eventType, eventData: makeJSValue())

        #expect(handler.handledEvents.count == 1)
        #expect(handler.handledEvents.first?.type == JSWalletKitSwiftBridgeEventType(rawValue: eventType))
    }

    @Test("Handle dispatches event to multiple handlers")
    func handleMultipleHandlers() throws {
        let handler1 = MockJSBridgeEventsHandler()
        let handler2 = MockJSBridgeEventsHandler()
        let sut = JSBridgeRawEventsHandler(handlers: [handler1, handler2])

        try sut.handle(eventType: "disconnect", eventData: makeJSValue())

        #expect(handler1.handledEvents.count == 1)
        #expect(handler2.handledEvents.count == 1)
    }

    @Test("Handle succeeds when at least one handler succeeds")
    func handlePartialSuccess() throws {
        let failing = MockJSBridgeEventsHandler()
        failing.shouldThrow = true
        let succeeding = MockJSBridgeEventsHandler()
        let sut = JSBridgeRawEventsHandler(handlers: [failing, succeeding])

        try sut.handle(eventType: "connectRequest", eventData: makeJSValue())

        #expect(succeeding.handledEvents.count == 1)
    }

    @Test("Handle throws when all handlers fail")
    func handleAllHandlersFail() {
        let handler1 = MockJSBridgeEventsHandler()
        handler1.shouldThrow = true
        handler1.throwError = "Error from handler 1"
        let handler2 = MockJSBridgeEventsHandler()
        handler2.shouldThrow = true
        handler2.throwError = "Error from handler 2"
        let sut = JSBridgeRawEventsHandler(handlers: [handler1, handler2])

        #expect(throws: (any Error).self) {
            try sut.handle(eventType: "connectRequest", eventData: makeJSValue())
        }
    }

    @Test("Handle throws first error when all handlers fail")
    func handleThrowsFirstError() {
        let handler1 = MockJSBridgeEventsHandler()
        handler1.shouldThrow = true
        handler1.throwError = "First error"
        let handler2 = MockJSBridgeEventsHandler()
        handler2.shouldThrow = true
        handler2.throwError = "Second error"
        let sut = JSBridgeRawEventsHandler(handlers: [handler1, handler2])

        do {
            try sut.handle(eventType: "disconnect", eventData: makeJSValue())
            Issue.record("Expected error to be thrown")
        } catch {
            #expect(error.localizedDescription == "First error")
        }
    }

    @Test("Handle cleans invalid handlers before processing")
    func handleCleansInvalid() {
        let invalid = MockJSBridgeEventsHandler()
        invalid.isValid = false
        let sut = JSBridgeRawEventsHandler(handlers: [invalid])

        let error = #expect(throws: TONBridgeEventError.self) {
            try sut.handle(eventType: "connectRequest", eventData: makeJSValue())
        }

        guard case .noHandlerRegistered? = error else {
            Issue.record("Expected .noHandlerRegistered, got \(String(describing: error))")
            return
        }
        #expect(sut.handlers.isEmpty)
    }

    @Test("Handle passes JSValue in the event")
    func handlePassesJSValue() throws {
        let handler = MockJSBridgeEventsHandler()
        let sut = JSBridgeRawEventsHandler(handlers: [handler])
        let jsValue = makeJSValue("testPayload")

        try sut.handle(eventType: "connectRequest", eventData: jsValue)

        let receivedValue = try #require(handler.handledEvents.first?.value)
        #expect(receivedValue.toString() == "testPayload")
    }
}
