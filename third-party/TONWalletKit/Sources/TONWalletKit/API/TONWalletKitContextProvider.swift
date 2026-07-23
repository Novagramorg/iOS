//
//  TONWalletKitContextProvider.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 08.02.2026.
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

protocol TONWalletKitContextProviderProtocol {
    func context(for configuration: TONWalletKitConfiguration) async throws -> any JSWalletKitContextProtocol
}

actor TONWalletKitContextProvider: TONWalletKitContextProviderProtocol {
    private var result: Result<JSWalletKitContext, Error>?
    private var task: Task<JSWalletKitContext, Error>?

    func context(for configuration: TONWalletKitConfiguration) async throws -> any JSWalletKitContextProtocol {
        if let result {
            switch result {
            case .success(let context):
                return context
            case .failure(let error):
                throw error
            }
        } else if let task {
            return try await task.value
        }
        
        let task = Task {
            do {
                let context = JSWalletKitContext()
                try await context.load(script: JSWalletKitScript())
                
                let storage = configuration.storage.jsStorage(context: context.jsContext)
                let sessionManager: any JSValueEncodable = configuration.sessionManager.map {
                    TONConnectSessionsManagerJSAdapter(
                        context: context.jsContext,
                        sessionsManager: $0
                    )
                }
                let apiClients = configuration.networkConfigurations.compactMap { config -> TONAPIClientJSAdapter? in
                    guard let apiClient = config.apiClient else { return nil }
                    
                    switch apiClient {
                    case .custom(let client):
                        return TONAPIClientJSAdapter(
                            context: context.jsContext,
                            apiClient: client
                        )
                    default:
                        return nil
                    }
                }
                
                try await context.initializeWalletKit(
                    configuration: configuration,
                    storage: AnyJSValueEncodable(storage),
                    sessionManager: sessionManager,
                    apiClients: apiClients,
                    fetchManifest: configuration.fetchManifest
                )
                
                self.result = .success(context)
                self.task = nil
                
                return context
            } catch {
                self.result = .failure(error)
                self.task = nil
                
                throw error
            }
        }
        
        self.task = task
        
        return try await task.value
    }
}

private extension TONWalletKitStorageType {

    func jsStorage(context: JSContext) -> (any JSValueEncodable)? {
        switch self {
        case .memory: nil
        case .keychain:
            TONWalletKitStorageJSAdapter(
                context: context,
                storage: TONWalletKitKeychainStorage()
            )
        case .custom(let value):
            TONWalletKitStorageJSAdapter(
                context: context,
                storage: value
            )
        }
    }
}
