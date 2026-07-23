//
//  MockSessionsManager.swift
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

import Foundation
@testable import TONWalletKit

class MockSessionsManager: TONConnectSessionsManager {
    var shouldThrow = false
    var mockSession: TONConnectSession = MockSessionsManager.makeSession()
    var createSessionCalls: [TONConnectSessionCreationParameters] = []
    var sessionIdCalls: [TONConnectSessionID] = []
    var sessionsCalls: [TONConnectSessionsFilter?] = []
    var removeAllSessionsCallCount = 0

    func createSession(with parameters: TONConnectSessionCreationParameters) async throws -> TONConnectSession {
        if shouldThrow { throw "Mock sessions manager error" }
        createSessionCalls.append(parameters)
        return mockSession
    }

    func session(id: TONConnectSessionID) async throws -> TONConnectSession? {
        if shouldThrow { throw "Mock sessions manager error" }
        sessionIdCalls.append(id)
        return mockSession
    }

    func sessions(filter: TONConnectSessionsFilter?) async throws -> [TONConnectSession] {
        if shouldThrow { throw "Mock sessions manager error" }
        sessionsCalls.append(filter)
        return [mockSession]
    }

    func removeSession(id: TONConnectSessionID) async throws {
        if shouldThrow { throw "Mock sessions manager error" }
    }

    func removeSessions(filter: TONConnectSessionsFilter?) async throws {
        if shouldThrow { throw "Mock sessions manager error" }
    }

    func removeAllSessions() async throws {
        if shouldThrow { throw "Mock sessions manager error" }
        removeAllSessionsCallCount += 1
    }

    static func makeSession() -> TONConnectSession {
        let address = TONUserFriendlyAddress(
            rawAddress: TONRawAddress(workchain: 0, hash: Data(repeating: 0, count: 32)),
            isBounceable: true,
            isTestnetOnly: false
        )

        return TONConnectSession(
            sessionId: "test-session-id",
            walletId: "-239:0000000000000000000000000000000000000000000000000000000000000000",
            walletAddress: address,
            createdAt: "2026-01-01T00:00:00Z",
            lastActivityAt: "2026-01-01T00:00:00Z",
            privateKey: "private-key",
            publicKey: "public-key",
            domain: "example.com",
            schemaVersion: 1.0
        )
    }
}
