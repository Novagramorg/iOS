//
//  JSEvent.swift
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
import JavaScriptCore

class JSEvent: JSValueEncodable {
    let type: JSEventType
    
    fileprivate let properties: (any JSEventProperties)
    
    init(type: JSEventType, properties: (any JSEventProperties)) {
        self.type = type
        self.properties = properties
    }
    
    func encode(in context: JSContext) throws -> Any {
        JSEventExport(context: context, event: self)
    }
}

@objc protocol JSEventExportProtocol: JSExport {
    var type: Any { get }
    
    var bubbles: Any { get }
    var cancelable: Any { get }
    var composed: Any { get }
}

class JSEventExport: NSObject, JSEventExportProtocol {
    private weak var context: JSContext?
    private let event: JSEvent
    
    var type: Any {
        event.type.rawValue
    }
    
    var bubbles: Any {
        event.properties.bubbles
    }
    
    var cancelable: Any {
        event.properties.cancelable
    }
    
    var composed: Any {
        event.properties.composed
    }
    
    init(context: JSContext, event: JSEvent) {
        self.context = context
        self.event = event
        
        super.init()
    }
}
