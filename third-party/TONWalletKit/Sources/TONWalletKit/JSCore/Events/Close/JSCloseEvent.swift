//
//  JSCloseEvent.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 13.03.2026.
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

final class JSCloseEvent: JSEvent {
    fileprivate let properties: JSCloseEventProperties
    
    init(properties: JSCloseEventProperties = .init()) {
        self.properties = properties
        
        super.init(type: .close, properties: properties)
    }
    
    override func encode(in context: JSContext) throws -> Any {
        JSCloseEventExport(context: context, event: self)
    }
}

@objc private protocol JSCloseEventExportProtocol: JSExport {
    
    var code: Any { get }
    var reason: Any { get }
    var wasClean: Any { get }
}

private final class JSCloseEventExport: JSEventExport, JSCloseEventExportProtocol {
    private weak var context: JSContext?
    private let event: JSCloseEvent
    
    var code: Any {
        event.properties.code
    }
    
    var reason: Any {
        event.properties.reason
    }
    
    var wasClean: Any {
        event.properties.wasClean
    }
    
    init(context: JSContext, event: JSCloseEvent) {
        self.context = context
        self.event = event
        
        super.init(context: context, event: event)
    }
}


