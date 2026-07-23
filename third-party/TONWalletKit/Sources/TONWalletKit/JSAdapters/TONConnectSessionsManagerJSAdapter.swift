//
//  TONConnectSessionsManagerJSAdapter.swift
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
import JavaScriptCore

class TONConnectSessionsManagerJSAdapter: NSObject, JSTONConnectSessionsManager {
    private weak var context: JSContext?
    private let sessionsManager: any TONConnectSessionsManager
    
    init(context: JSContext, sessionsManager: any TONConnectSessionsManager) {
        self.context = context
        self.sessionsManager = sessionsManager
    }
    
    @objc(createSession::::) func createSession(
        sessionId: JSValue,
        dAppInfo: JSValue,
        wallet: JSValue,
        isJsBridge: JSValue
    ) -> JSValue {
        guard let context else {
            return JSValue(
                newPromiseRejectedWithReason: "No context exists to perform \(#function)",
                in: JSContext()
            )
        }
        
        do {
            let wallet: TONWallet = try wallet.decode()
            
            let parameters = TONConnectSessionCreationParameters(
                sessionId: try sessionId.decode(),
                wallet: wallet,
                dAppInfo: try dAppInfo.decode(),
                isJsBridge: try isJsBridge.decode()
            )
            
            return JSValue(newPromiseIn: context) { [weak self] resolve, reject in
                Task {
                    guard let self else { return }
                    
                    do {
                        let session = try await self.sessionsManager.createSession(with: parameters)
                        let encodedSession = try session.encode(in: context)
                        
                        resolve?.call(withArguments: [encodedSession])
                    } catch {
                        reject?.call(withArguments: [error.localizedDescription])
                    }
                }
            }
        } catch {
            return JSValue(newPromiseRejectedWithReason: error.localizedDescription, in: context)
        }
    }
    
    @objc(getSessions:) func sessions(filter: JSValue) -> JSValue {
        guard let context else {
            return JSValue(
                newPromiseRejectedWithReason: "No context exists to perform \(#function)",
                in: JSContext()
            )
        }
        
        var sessionFilter: TONConnectSessionsFilter?
        
        do {
            sessionFilter = try filter.decode()
        } catch {
            return JSValue(newPromiseRejectedWithReason: error.localizedDescription, in: context)
        }
        
        return JSValue(newPromiseIn: context) { [weak self] resolve, reject in
            Task {
                guard let self else { return }
                
                do {
                    let sessions = try await self.sessionsManager.sessions(filter: sessionFilter)
                    
                    let encodedSessions = try sessions.encode(in: context)
                    resolve?.call(withArguments: [encodedSessions])
                } catch {
                    reject?.call(withArguments: [error.localizedDescription])
                }
            }
        }
    }
    
    @objc(getSession:) func session(sessionId: JSValue) -> JSValue {
        guard let context else {
            return JSValue(
                newPromiseRejectedWithReason: "No context exists to perform \(#function)",
                in: JSContext()
            )
        }
        
        do {
            let sessionId: TONConnectSessionID = try sessionId.decode()
            
            return JSValue(newPromiseIn: context) { [weak self] resolve, reject in
                Task {
                    guard let self else { return }
                    
                    do {
                        let session = try await self.sessionsManager.session(id: sessionId)
                        
                        if let session {
                            let encodedSession = try session.encode(in: context)
                            resolve?.call(withArguments: [encodedSession])
                        } else {
                            resolve?.call(withArguments: [JSValue(undefinedIn: context)])
                        }
                    } catch {
                        reject?.call(withArguments: [error.localizedDescription])
                    }
                }
            }
        } catch {
            return JSValue(newPromiseRejectedWithReason: error.localizedDescription, in: context)
        }
    }
    
    @objc(removeSession:) func removeSession(sessionId: JSValue) -> JSValue {
        guard let context else {
            return JSValue(
                newPromiseRejectedWithReason: "No context exists to perform \(#function)",
                in: JSContext()
            )
        }
        
        do {
            let sessionId: TONConnectSessionID = try sessionId.decode()
            
            return JSValue(newPromiseIn: context) { [weak self] resolve, reject in
                Task {
                    guard let self else { return }
                    
                    do {
                        try await self.sessionsManager.removeSession(id: sessionId)
                        
                        resolve?.call(withArguments: [JSValue(undefinedIn: context)])
                    } catch {
                        reject?.call(withArguments: [error.localizedDescription])
                    }
                }
            }
        } catch {
            return JSValue(newPromiseRejectedWithReason: error.localizedDescription, in: context)
        }
    }
    
    @objc(removeSessions:) func removeSessions(filter: JSValue) -> JSValue {
        guard let context else {
            return JSValue(
                newPromiseRejectedWithReason: "No context exists to perform \(#function)",
                in: JSContext()
            )
        }
        
        var sessionFilter: TONConnectSessionsFilter?
        
        do {
            sessionFilter = try filter.decode()
        } catch {
            return JSValue(newPromiseRejectedWithReason: error.localizedDescription, in: context)
        }
        
        return JSValue(newPromiseIn: context) { [weak self] resolve, reject in
            Task {
                guard let self else { return }
                
                do {
                    try await self.sessionsManager.removeSessions(filter: sessionFilter)
                    resolve?.call(withArguments: [JSValue(undefinedIn: context)])
                } catch {
                    reject?.call(withArguments: [error.localizedDescription])
                }
            }
        }
    }
    
    @objc(clearSessions) func clearSessions() -> JSValue {
        guard let context else {
            return JSValue(
                newPromiseRejectedWithReason: "No context exists to perform \(#function)",
                in: JSContext()
            )
        }
        
        return JSValue(newPromiseIn: context) { [weak self] resolve, reject in
            Task {
                guard let self else { return }
                
                do {
                    try await self.sessionsManager.removeAllSessions()
                    resolve?.call(withArguments: [])
                } catch {
                    reject?.call(withArguments: [error.localizedDescription])
                }
            }
        }
    }
}

extension TONConnectSessionsManagerJSAdapter: JSValueEncodable {}
