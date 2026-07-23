//
//  TONConnectSessionsManagerJSAdapterTests.swift
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

@Suite("TONConnectSessionsManagerJSAdapter Tests")
struct TONConnectSessionsManagerJSAdapterTests {

    private let context = JSContext()!

    private func makeSUT(
        manager: MockSessionsManager = MockSessionsManager()
    ) -> (sut: TONConnectSessionsManagerJSAdapter, manager: MockSessionsManager) {
        let sut = TONConnectSessionsManagerJSAdapter(
            context: context,
            sessionsManager: manager
        )
        return (sut, manager)
    }

    @Test("createSession rejects for invalid input")
    func createSessionRejectsForInvalidInput() async {
        let (sut, _) = makeSUT()
        let sessionId = JSValue(object: "session-123", in: context)!
        let dAppInfo = JSValue(undefinedIn: context)!
        let wallet = JSValue(undefinedIn: context)!
        let isJsBridge = JSValue(bool: false, in: context)!

        let result = sut.createSession(
            sessionId: sessionId,
            dAppInfo: dAppInfo,
            wallet: wallet,
            isJsBridge: isJsBridge
        )

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("createSession rejects when context is deallocated")
    func createSessionRejectsWhenDeallocated() async {
        let manager = MockSessionsManager()
        var jsContext: JSContext? = JSContext()!
        let sut = TONConnectSessionsManagerJSAdapter(
            context: jsContext!,
            sessionsManager: manager
        )
        let sessionId = JSValue(object: "session-123", in: context)!
        let dAppInfo = JSValue(undefinedIn: context)!
        let wallet = JSValue(undefinedIn: context)!
        let isJsBridge = JSValue(bool: false, in: context)!
        jsContext = nil

        let result = sut.createSession(
            sessionId: sessionId,
            dAppInfo: dAppInfo,
            wallet: wallet,
            isJsBridge: isJsBridge
        )

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("Sessions resolves with session data")
    func sessionsResolvesWithData() async throws {
        let (sut, _) = makeSUT()
        let filter = JSValue(undefinedIn: context)!

        let result = sut.sessions(filter: filter)
        let resolved = try await result.then()
        let sessions: [TONConnectSession] = try resolved.decode()

        #expect(sessions.count == 1)
        #expect(sessions.first?.sessionId == "test-session-id")
        #expect(sessions.first?.domain == "example.com")
    }

    @Test("Sessions rejects when context is deallocated")
    func sessionsRejectsWhenDeallocated() async {
        let manager = MockSessionsManager()
        var jsContext: JSContext? = JSContext()!
        let sut = TONConnectSessionsManagerJSAdapter(
            context: jsContext!,
            sessionsManager: manager
        )
        let filter = JSValue(undefinedIn: context)!
        jsContext = nil

        let result = sut.sessions(filter: filter)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("Ssessions rejects when manager throws")
    func sessionsRejectsWhenManagerThrows() async {
        let manager = MockSessionsManager()
        manager.shouldThrow = true
        let (sut, _) = makeSUT(manager: manager)
        let filter = JSValue(undefinedIn: context)!

        let result = sut.sessions(filter: filter)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("Session resolves with session data")
    func sessionResolvesWithSessionData() async throws {
        let (sut, _) = makeSUT()
        let sessionId = JSValue(object: "session-123", in: context)!

        let result = sut.session(sessionId: sessionId)
        let resolved = try await result.then()
        let session: TONConnectSession = try resolved.decode()

        #expect(session.sessionId == "test-session-id")
        #expect(session.domain == "example.com")
    }

    @Test("Session rejects when context is deallocated")
    func sessionRejectsWhenDeallocated() async {
        let manager = MockSessionsManager()
        var jsContext: JSContext? = JSContext()!
        let sut = TONConnectSessionsManagerJSAdapter(
            context: jsContext!,
            sessionsManager: manager
        )
        let sessionId = JSValue(object: "session-123", in: context)!
        jsContext = nil

        let result = sut.session(sessionId: sessionId)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("Session rejects when manager throws")
    func sessionRejectsWhenManagerThrows() async {
        let manager = MockSessionsManager()
        manager.shouldThrow = true
        let (sut, _) = makeSUT(manager: manager)
        let sessionId = JSValue(object: "session-123", in: context)!

        let result = sut.session(sessionId: sessionId)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("removeSession resolves with removed session data")
    func removeSessionResolvesWithSessionData() async throws {
        let (sut, _) = makeSUT()
        let sessionId = JSValue(object: "session-123", in: context)!

        let result = sut.removeSession(sessionId: sessionId)
        let resolved = try await result.then()

        #expect(resolved.isUndefined)
    }

    @Test("removeSession rejects when context is deallocated")
    func removeSessionRejectsWhenDeallocated() async {
        let manager = MockSessionsManager()
        var jsContext: JSContext? = JSContext()!
        let sut = TONConnectSessionsManagerJSAdapter(
            context: jsContext!,
            sessionsManager: manager
        )
        let sessionId = JSValue(object: "session-123", in: context)!
        jsContext = nil

        let result = sut.removeSession(sessionId: sessionId)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("removeSession rejects when manager throws")
    func removeSessionRejectsWhenManagerThrows() async {
        let manager = MockSessionsManager()
        manager.shouldThrow = true
        let (sut, _) = makeSUT(manager: manager)
        let sessionId = JSValue(object: "session-123", in: context)!

        let result = sut.removeSession(sessionId: sessionId)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("removeSessions resolves with removed sessions data")
    func removeSessionsResolvesWithData() async throws {
        let (sut, _) = makeSUT()
        let filter = JSValue(undefinedIn: context)!

        let result = sut.removeSessions(filter: filter)
        let resolved = try await result.then()

        #expect(resolved.isUndefined)
    }

    @Test("removeSessions rejects when context is deallocated")
    func removeSessionsRejectsWhenDeallocated() async {
        let manager = MockSessionsManager()
        var jsContext: JSContext? = JSContext()!
        let sut = TONConnectSessionsManagerJSAdapter(
            context: jsContext!,
            sessionsManager: manager
        )
        let filter = JSValue(undefinedIn: context)!
        jsContext = nil

        let result = sut.removeSessions(filter: filter)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("removeSessions rejects when manager throws")
    func removeSessionsRejectsWhenManagerThrows() async {
        let manager = MockSessionsManager()
        manager.shouldThrow = true
        let (sut, _) = makeSUT(manager: manager)
        let filter = JSValue(undefinedIn: context)!

        let result = sut.removeSessions(filter: filter)

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("clearSessions resolves and delegates to manager")
    func clearSessionsResolvesAndDelegatesToManager() async throws {
        let (sut, manager) = makeSUT()

        let result = sut.clearSessions()
        _ = try await result.then()

        #expect(manager.removeAllSessionsCallCount == 1)
    }

    @Test("clearSessions rejects when context is deallocated")
    func clearSessionsRejectsWhenDeallocated() async {
        let manager = MockSessionsManager()
        var jsContext: JSContext? = JSContext()!
        let sut = TONConnectSessionsManagerJSAdapter(
            context: jsContext!,
            sessionsManager: manager
        )
        jsContext = nil

        let result = sut.clearSessions()

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("clearSessions rejects when manager throws")
    func clearSessionsRejectsWhenManagerThrows() async {
        let manager = MockSessionsManager()
        manager.shouldThrow = true
        let (sut, _) = makeSUT(manager: manager)

        let result = sut.clearSessions()

        await #expect(throws: (any Error).self) {
            try await result.then()
        }
    }

    @Test("sessions resolves from JS call")
    func sessionsResolvesFromJS() async throws {
        let (sut, _) = makeSUT()
        context.evaluateScript("function callSessions(m) { return m.getSessions(undefined); }")

        let result: JSValue = try await context.callSessions(sut)

        #expect(result.isArray)
    }

    @Test("clearSessions resolves from JS call")
    func clearSessionsResolvesFromJS() async throws {
        let (sut, manager) = makeSUT()
        context.evaluateScript("function callClear(m) { return m.clearSessions(); }")

        let _: JSValue = try await context.callClear(sut)

        #expect(manager.removeAllSessionsCallCount == 1)
    }
}
