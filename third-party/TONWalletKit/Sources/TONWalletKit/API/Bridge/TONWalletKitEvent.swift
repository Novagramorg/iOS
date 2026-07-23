//
//  WalletKitEvent.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 11.09.2025.
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

public enum TONWalletKitEvent {
    case connectRequest(TONWalletConnectionRequest)
    case transactionRequest(TONWalletSendTransactionRequest)
    case signMessageRequest(TONWalletSignMessageRequest)
    case signDataRequest(TONWalletSignDataRequest)
    case disconnect(TONDisconnectionEvent)

    init(bridgeEvent: JSWalletKitSwiftBridgeEvent, context: any JSDynamicObject) throws {
        switch bridgeEvent.type {
        case .connectRequest:
            let event: TONConnectionRequestEvent = try bridgeEvent.value.decode()
            self = .connectRequest(TONWalletConnectionRequest(context: context, event: event))
        case .transactionRequest:
            let event: TONSendTransactionRequestEvent = try bridgeEvent.value.decode()
            self = .transactionRequest(TONWalletSendTransactionRequest(context: context, event: event))
        case .signMessageRequest:
            let event: TONSignMessageRequestEvent = try bridgeEvent.value.decode()
            self = .signMessageRequest(TONWalletSignMessageRequest(context: context, event: event))
        case .signDataRequest:
            let event: TONSignDataRequestEvent = try bridgeEvent.value.decode()
            self = .signDataRequest(TONWalletSignDataRequest(context: context, event: event))
        case .disconnect:
            let event: TONDisconnectionEvent = try bridgeEvent.value.decode()
            self = .disconnect(event)
        }
    }
}

public extension TONWalletKitEvent {

    var isJsBridge: Bool {
        switch self {
        case .connectRequest(let request):
            return request.event.isJsBridge == true
        case .transactionRequest(let request):
            return request.event.isJsBridge == true
        case .signMessageRequest(let request):
            return request.event.isJsBridge == true
        case .signDataRequest(let request):
            return request.event.isJsBridge == true
        case .disconnect(let event):
            return event.isJsBridge == true
        }
    }
}
