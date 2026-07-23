//
//  JSBridgeRawEventsHandler.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 15.10.2025.
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
import JavaScriptCore

class JSBridgeRawEventsHandler {
    private var handlers: [any JSBridgeEventsHandler] = []
    
    var isEmpty: Bool { handlers.isEmpty }
    
    init(handlers: [any JSBridgeEventsHandler]) {
        self.handlers = handlers
    }
    
    func handle(eventType: String, eventData: JSValue) throws {
        clean()
        
        guard let eventType = JSWalletKitSwiftBridgeEventType(rawValue: eventType) else {
            throw TONBridgeEventError.unknownEventType(eventType)
        }
        
        let event = JSWalletKitSwiftBridgeEvent(type: eventType, value: eventData)
        
        if handlers.isEmpty {
            throw TONBridgeEventError.noHandlerRegistered(eventType: "\(eventType)")
        }
        
        let errors: [Error] = handlers.compactMap {
            do {
                try $0.handle(event: event)
                return nil
            } catch {
                return error
            }
        }
        
        if errors.count == handlers.count, let error = errors.first {
            throw error
        }
    }
    
    func add(handler: any JSBridgeEventsHandler) {
        clean()
        
        if !handlers.contains(where: { $0 === handler }) {
            handlers.append(handler)
        }
    }
    
    func remove(handler: any JSBridgeEventsHandler) {
        clean()
        
        handlers.removeAll { $0 === handler }
    }
    
    private func clean() {
        handlers.removeAll { !$0.isValid }
    }
}

struct JSWalletKitSwiftBridgeEvent {
    let type: JSWalletKitSwiftBridgeEventType
    let value: JSValue
}

enum JSWalletKitSwiftBridgeEventType: String {
    case connectRequest
    case transactionRequest
    case signMessageRequest
    case signDataRequest
    case disconnect
}
