//
//  JSMessageEvent.swift
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

final class JSMessageEvent: JSEvent {
    fileprivate let properties: JSMessageEventProperties

    init(type: JSEventType, properties: JSMessageEventProperties = .init()) {
        self.properties = properties

        super.init(type: type, properties: properties)
    }

    override func encode(in context: JSContext) throws -> Any {
        JSMessageEventExport(context: context, event: self)
    }
}

@objc private protocol JSMessageEventExportProtocol: JSExport {

    var data: JSValue? { get }
    var origin: Any { get }
    var lastEventId: Any { get }
}

private final class JSMessageEventExport: JSEventExport, JSMessageEventExportProtocol {
    private weak var context: JSContext?
    private let event: JSMessageEvent

    var data: JSValue? {
        event.properties.data
    }

    var origin: Any {
        event.properties.origin
    }

    var lastEventId: Any {
        event.properties.lastEventId
    }

    init(context: JSContext, event: JSMessageEvent) {
        self.context = context
        self.event = event

        super.init(context: context, event: event)
    }
}
