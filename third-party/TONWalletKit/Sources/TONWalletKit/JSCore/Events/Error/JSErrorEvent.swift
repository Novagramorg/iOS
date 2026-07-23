//
//  JSErrorEvent.swift
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

final class JSErrorEvent: JSEvent {
    fileprivate let properties: JSErrorEventProperties

    init(type: JSEventType, properties: JSErrorEventProperties = .init()) {
        self.properties = properties

        super.init(type: type, properties: properties)
    }

    override func encode(in context: JSContext) throws -> Any {
        JSErrorEventExport(context: context, event: self)
    }
}

@objc private protocol JSErrorEventExportProtocol: JSExport {

    var message: Any { get }
    var filename: Any { get }
    var lineno: Any { get }
    var colno: Any { get }
    var error: Any { get }
}

private final class JSErrorEventExport: JSEventExport, JSErrorEventExportProtocol {
    private weak var context: JSContext?
    private let event: JSErrorEvent

    var message: Any {
        event.properties.message
    }

    var filename: Any {
        event.properties.filename
    }

    var lineno: Any {
        event.properties.lineno
    }

    var colno: Any {
        event.properties.colno
    }

    var error: Any {
        guard let context else { return event.properties.error }
        return JSValue(newErrorFromMessage: event.properties.error, in: context) as Any
    }

    init(context: JSContext, event: JSErrorEvent) {
        self.context = context
        self.event = event

        super.init(context: context, event: event)
    }
}
