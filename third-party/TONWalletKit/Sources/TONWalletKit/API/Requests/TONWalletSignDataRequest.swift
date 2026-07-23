//
//  TONWalletSignDataRequest.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 02.10.2025.
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

public class TONWalletSignDataRequest {
    private let context: any JSDynamicObject

    public let event: TONSignDataRequestEvent
    private let embeddedEvent: TONEmbeddedSignDataRequestEvent?

    private var targetEvent: any JSValueEncodable {
        embeddedEvent ?? event
    }

    init(
        context: any JSDynamicObject,
        event: TONSignDataRequestEvent
    ) {
        self.context = context
        self.event = event
        self.embeddedEvent = nil
    }

    init(
        context: any JSDynamicObject,
        embeddedEvent: TONEmbeddedSignDataRequestEvent
    ) {
        self.context = context
        self.embeddedEvent = embeddedEvent
        self.event = embeddedEvent.requestEvent
    }

    @discardableResult
    public func approve(response: TONSignDataApprovalResponse? = nil) async throws -> TONSignDataApprovalResponse {
        try await context.walletKit.approveSignDataRequest(targetEvent, response)
    }

    public func reject(reason: String? = nil) async throws {
        try await context.walletKit.rejectSignDataRequest(targetEvent, reason)
    }
}

