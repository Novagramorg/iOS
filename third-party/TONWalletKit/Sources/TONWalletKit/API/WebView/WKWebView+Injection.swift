//
//  WKWebView+Injection.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 07.11.2025.
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
import WebKit

@available(iOS 14.0, *)
public extension WKWebView {
    
    func inject(
        walletKit: TONWalletKit,
        configuration: TONBridgeInjectionConfiguration? = nil
    ) throws {
        #if DEBUG
        
        #if os(macOS)
        if #available(macOS 13.3, *) {
            self.isInspectable = true
        }
        #endif
        
        #if os(iOS)
        if #available(iOS 16.4, *) {
            self.isInspectable = true
        }
        #endif
        
        #endif
        
        let options = TONBridgeInjectOptions(
            deviceInfo: walletKit.configuration.deviceInfo,
            walletInfo: walletKit.configuration.walletManifest,
            jsBridgeKey: configuration?.key ?? walletKit.configuration.bridge?.webViewInjectionKey,
            injectTonKey: nil,
            isWalletBrowser: true
        )
        
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(options)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        
        let injectionScriptSource = """
            \(try JSWalletKitInjectionScript().load())
            window.injectWalletKit(\(jsonString));
        """
        let injectionScript = WKUserScript(
            source: injectionScriptSource,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false,
        )
        
        let bridge = try walletKit.injectableBridge()
        
        self.configuration.userContentController.addUserScript(injectionScript)
        self.configuration.userContentController.addScriptMessageHandler(
            TONWalletKitInjectionMessagesHandler(
                injectableBridge: bridge,
                walletId: configuration?.walletId
            ),
            contentWorld: .page,
            name: "walletKitInjectionBridge"
        )
    }
}

@available(iOS 14.0, *)
private class TONWalletKitInjectionMessagesHandler: NSObject, WKScriptMessageHandlerWithReply {
    private let injectableBridge: TONWalletKitInjectableBridge
    private let walletId: TONWalletID?
    
    private var subscribers: [String: AnyCancellable] = [:]
    
    private let defaultTimeout: Int = 10000
    
    init(
        injectableBridge: TONWalletKitInjectableBridge,
        walletId: TONWalletID?
    ) {
        self.injectableBridge = injectableBridge
        self.walletId = walletId
    }
    
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage,
        replyHandler: @escaping @MainActor (Any?, String?) -> Void
    ) {
        let domain = message.frameInfo.request.url.flatMap {
            let components = URLComponents(url: $0, resolvingAgainstBaseURL: false)
            var normalizedComponents = URLComponents()
            normalizedComponents.scheme = components?.scheme
            normalizedComponents.host = components?.host
            normalizedComponents.port = components?.port
            return normalizedComponents.url?.absoluteString
        }
        
        let messageID = UUID().uuidString
        let messageDictionary = message.body as? [String: Any]
        
        let eventMessage = TONBridgeEventMessage(
            messageId: messageID,
            tabId: messageDictionary?["frameID"] as? String,
            domain: domain,
            walletId: walletId
        )
        
        let timeout = messageDictionary?["timeout"] as? Int
        
        subscribers[messageID] = injectableBridge.waitForResponse()
            .filter { $0.messageID == messageID }
            .prefix(1)
            .timeout(.milliseconds(timeout ?? defaultTimeout), scheduler: DispatchQueue.main) {
                TONWalletKitError.bridgeRequestTimeout(messageID: messageID)
            }
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    replyHandler(nil, error.localizedDescription)
                }
                self?.subscribers.removeValue(forKey: messageID)
            }, receiveValue: { value in
                replyHandler(value.message?.value, nil)
            })

        Task { @MainActor [weak self] in
            do {
                try await self?.injectableBridge.request(message: eventMessage, request: message.body)
            } catch {
                self?.subscribers.removeValue(forKey: messageID)
                replyHandler(nil, error.localizedDescription)
            }
        }
    }
}
