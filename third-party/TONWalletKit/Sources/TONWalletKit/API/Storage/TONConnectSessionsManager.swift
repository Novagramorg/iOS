//
//  TONConnectSessionsManager.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 20.01.2026.
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

public typealias TONConnectSessionID = String

public struct TONConnectSessionCreationParameters {
    public var sessionId: TONConnectSessionID
    public var wallet: TONWalletProtocol
    public var dAppInfo: TONDAppInfo
    public var isJsBridge: Bool
}

public struct TONConnectSessionsFilter: Codable {
    public var walletId: TONWalletID?
    public var domain: String?
    public var isJsBridge: Bool?
}

public protocol TONConnectSessionsManager: AnyObject {
    func createSession(with parameters: TONConnectSessionCreationParameters) async throws -> TONConnectSession
    
    func session(id: TONConnectSessionID) async throws -> TONConnectSession?
    func sessions(filter: TONConnectSessionsFilter?) async throws -> [TONConnectSession]
    
    func removeSession(id: TONConnectSessionID) async throws
    func removeSessions(filter: TONConnectSessionsFilter?) async throws
    
    func removeAllSessions() async throws
}
