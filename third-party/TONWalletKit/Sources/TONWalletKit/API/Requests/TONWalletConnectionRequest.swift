//
//  TONWalletConnectionRequest.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 01.10.2025.
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

public class TONWalletConnectionRequest {
    let context: any JSDynamicObject
    
    public let event: TONConnectionRequestEvent

    init(
        context: any JSDynamicObject,
        event: TONConnectionRequestEvent
    ) {
        self.context = context
        self.event = event
    }
    
    @discardableResult
    public func approve(
        walletId: TONWalletID,
        response: TONConnectionApprovalResponse? = nil
    ) async throws -> TONWalletKitEvent? {
        let wallet: TONWallet = try await context.walletKit.getWallet(walletId)

        return try await approve(wallet: wallet, response: response)
    }

    @discardableResult
    public func approve(
        wallet: any TONWalletProtocol,
        response: TONConnectionApprovalResponse? = nil
    ) async throws -> TONWalletKitEvent? {
        var event = self.event
        event.walletId = wallet.id
        event.walletAddress = wallet.address

        let embedded: TONEmbeddedRequestEvent? = try await context.walletKit.approveConnectRequest(event, response)
        guard let embedded else { return nil }

        switch embedded {
        case .sendTransaction(let event):
            return .transactionRequest(
                TONWalletSendTransactionRequest(
                    context: context,
                    embeddedEvent: event
                )
            )
        case .signMessage(let event):
            return .signMessageRequest(
                TONWalletSignMessageRequest(
                    context: context,
                    embeddedEvent: event
                )
            )
        case .signData(let event):
            return .signDataRequest(
                TONWalletSignDataRequest(
                    context: context,
                    embeddedEvent: event
                )
            )
        }
    }

    public func reject(reason: String? = nil) async throws {
        try await context.walletKit.rejectConnectRequest(event, reason)
    }
}
