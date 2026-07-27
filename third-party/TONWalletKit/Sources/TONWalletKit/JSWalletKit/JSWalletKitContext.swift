//
//  JSWalletKitContext.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 16.10.2025.
//
//  Copyright (c) 2025 TON Connect
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
import Combine
import JavaScriptCore

protocol JSWalletKitContextProtocol: JSDynamicObject, AnyObject {
    var bridgeTransport: JSBridgeTransport { get }

    func initializeWalletKit(
        configuration: any JSValueEncodable,
        storage: any JSValueEncodable,
        sessionManager: any JSValueEncodable,
        apiClients: any JSValueEncodable,
        fetchManifest: TONWalletKitConfiguration.FetchManifest?,
        toncenterRequestHandlers: [TONToncenterRequestHandlerJSAdapter]
    ) async throws

    func add(eventsHandler: any JSBridgeEventsHandler) throws
    func remove(eventsHandler: any JSBridgeEventsHandler) throws
}

class JSWalletKitContext: JSWalletKitContextProtocol {
    private let context: any JSDynamicObject
    private var bridgeEventHandlers: JSBridgeRawEventsHandler?
    
    let bridgeTransport = JSBridgeTransport()
    
    convenience init() {
        self.init(context: JSContext())
        
        self.jsContext.polyfill(with: JSConsoleLogPolyfill())
        self.jsContext.polyfill(with: JSTimerPolyfill())
        self.jsContext.polyfill(with: JSFetchPolyfill())
        self.jsContext.polyfill(with: JSWebSocketPolyfill())
        self.jsContext.polyfill(with: JSWalletKitInitialPolyfill())
    }
    
    private init(context: any JSDynamicObject) {
        self.context = context
    }
    
    func load(script: any JSScript) async throws {
        let code = try await script.load()
        jsContext.evaluateScript(code)
    }
    
    func initializeWalletKit(
        configuration: any JSValueEncodable,
        storage: any JSValueEncodable,
        sessionManager: any JSValueEncodable,
        apiClients: any JSValueEncodable,
        fetchManifest: TONWalletKitConfiguration.FetchManifest? = nil,
        toncenterRequestHandlers: [TONToncenterRequestHandlerJSAdapter] = []
    ) async throws {
        let bridgeTransport: @convention(block) (JSValue) -> Void = { [weak self] response in
            do {
                let response: JSBridgeTransportResponse = try response.decode()
                self?.bridgeTransport.send(response: response)
            } catch {
                debugPrint("Swift Bridge: Failed to decode transport response")
            }
        }

        var jsFetchManifest: JSValue?
        
        if let fetchManifest {
            let fetchManifestBlock: @convention(block) (String) -> JSValue = { [weak self] url in
                guard let context = self?.context.jsContext else {
                    return JSValue(
                        newPromiseRejectedWithReason: "WalletKit context deallocated",
                        in: JSContext()
                    )
                }
                
                return JSValue(newPromiseIn: context) { resolve, reject in
                    Task {
                        do {
                            let result = try await fetchManifest(url)
                            let jsResult = try result.encode(in: context)
                            resolve?.call(withArguments: [jsResult])
                        } catch {
                            reject?.call(withArguments: [error.localizedDescription])
                        }
                    }
                }
            }
            jsFetchManifest = JSValue(object: fetchManifestBlock, in: context.jsContext)
        }

        try await self.initWalletKit(
            configuration,
            storage,
            JSValue(object: bridgeTransport, in: context.jsContext),
            sessionManager,
            apiClients,
            jsFetchManifest,
            toncenterRequestHandlers
        )
    }
    
    func add(eventsHandler: any JSBridgeEventsHandler) throws {
        if let bridgeEventHandlers {
            bridgeEventHandlers.add(handler: eventsHandler)
            return
        }
        
        bridgeEventHandlers = JSBridgeRawEventsHandler(handlers: [eventsHandler])
        
        let callback: @convention(block) (String, JSValue) -> JSValue? = { [weak self] eventType, eventData in
            guard let self else { return nil }
            
            do {
                try self.bridgeEventHandlers?.handle(eventType: eventType, eventData: eventData)
                
                return JSValue(
                    newPromiseResolvedWithResult: JSValue(undefinedIn: self.jsContext),
                    in: self.jsContext
                )
            } catch {
                return JSValue(
                    newPromiseRejectedWithReason: error.localizedDescription,
                    in: self.jsContext
                )
            }
        }
        
        try self.walletKit.setEventsListeners(
            JSValue(
                object: callback,
                in: context.jsContext
            )
        )
    }
    
    func remove(eventsHandler: any JSBridgeEventsHandler) throws {
        bridgeEventHandlers?.remove(handler: eventsHandler)
        
        if bridgeEventHandlers?.isEmpty != false {
            try self.walletKit.removeEventListeners()
        }
    }
}

extension JSWalletKitContext: JSDynamicObject {
    var jsContext: JSContext { context.jsContext }
    
    subscript<T>(dynamicMember member: String) -> T? where T : JSValueDecodable {
        context[dynamicMember: member]
    }
    
    subscript(dynamicMember member: String) -> any JSDynamicObjectMember {
        context[dynamicMember: member]
    }
}
