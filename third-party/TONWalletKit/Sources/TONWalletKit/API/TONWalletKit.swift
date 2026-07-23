//
//  TONWalletKit.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 12.09.2025.
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

public class TONWalletKit {
    let configuration: TONWalletKitConfiguration
    
    private let contextProvider: any TONWalletKitContextProviderProtocol
    private var context: (any JSWalletKitContextProtocol)? {
        didSet {
            guard let context else { return }
            
            if context !== oldValue {
                addHandlers(to: context)
            }
        }
    }
    
    private var pendingEventHandlers: [any TONBridgeEventsHandler] = []
    private var eventHandlers: [TONBridgeEventsHandlerJSAdapter] = []
    
    public var isInitialized: Bool { context != nil }
    
    deinit {
        eventHandlers.forEach { $0.invalidate() }
    }
    
    public convenience init(configuration: TONWalletKitConfiguration) {
        self.init(
            configuration: configuration,
            contextProvider: TONWalletKitContextProvider()
        )
    }
    
    init(
        configuration: TONWalletKitConfiguration,
        contextProvider: any TONWalletKitContextProviderProtocol
    ) {
        self.configuration = configuration
        self.contextProvider = contextProvider
    }
    
    public func initialize() async throws {
        if isInitialized { return }
        
        self.context = try await contextProvider.context(for: configuration)
    }
    
    public func omnistonSwapProvider(
        config: TONOmnistonSwapProviderConfig?
    ) async throws -> TONOmnistonSwapProvider {
        try await jsWalletKit().createOmnistonSwapProvider(config)
    }

    public func dedustSwapProvider(
        config: TONDeDustSwapProviderConfig?
    ) async throws -> TONDeDustSwapProvider {
        try await jsWalletKit().createDeDustSwapProvider(config)
    }
    
    public func streamingProvider(
        config: TONTonCenterStreamingProviderConfig
    ) async throws -> any TONStreamingProviderProtocol {
        let provider: TONStreamingProvider = try await jsWalletKit().createTonCenterStreamingProvider(config)
        return provider
    }
    
    public func streamingProvider(
        config: TONTonApiStreamingProviderConfig
    ) async throws -> any TONStreamingProviderProtocol {
        let provider: TONStreamingProvider = try await jsWalletKit().createTonApiStreamingProvider(config)
        return provider
    }

    public func stakingProvider(
        config: TONTonStakersProviderConfig
    ) async throws -> TONTonStakersStakingProvider {
        try await jsWalletKit().createTonStakersStakingProvider(config)
    }

    public func tonApiGaslessProvider(
        config: TONTonApiGaslessProviderConfig?
    ) async throws -> TONTonApiGaslessProvider {
        try await jsWalletKit().createTonApiGaslessProvider(config)
    }

    public func swap() async throws -> any TONSwapManagerProtocol {
        let manager: TONSwapManager = try await jsWalletKit().swap()
        return manager
    }
    
	public func streaming() async throws -> any TONStreamingManagerProtocol {
        let manager: TONStreamingManager = try await jsWalletKit().streaming()
        return manager
    }

	public func staking() async throws -> any TONStakingManagerProtocol {
        let manager: TONStakingManager = try await jsWalletKit().staking()
        return manager
    }

	public func gasless() async throws -> any TONGaslessManagerProtocol {
        let manager: TONGaslessManager = try await jsWalletKit().gasless()
        return manager
    }

	public func jettons() async throws -> any TONJettonsManagerProtocol {
        let manager: TONJettonsManager = try await jsWalletKit().jettons()
        return manager
    }

    public func signer(mnemonic: TONMnemonic) async throws -> any TONWalletSignerProtocol {
        guard mnemonic.isFilled else {
            throw TONWalletKitError.invalidMnemonic
        }

        guard try await validateMnemonic(mnemonic) else {
            throw TONWalletKitError.invalidMnemonic
        }

        let signer = try await jsWalletKit().createSignerFromMnemonic(mnemonic.value)

        return TONWalletSigner(jsWalletSigner: signer)
    }
    
    public func signer(privateKey: Data) async throws -> any TONWalletSignerProtocol {
        let data = [UInt8](privateKey)
        let signer = try await jsWalletKit().createSignerFromPrivateKey(data)

        return TONWalletSigner(jsWalletSigner: signer)
    }

    public func containsMnemonicWord(_ word: String) async throws -> Bool {
        return try await jsWalletKit().containsMnemonicWord(word)
    }

    public func generateMnemonic() async throws -> TONMnemonic {
        try await generateMnemonic(length: .bits256)
    }

    public func generateMnemonic(length: TONMnemonicLength) async throws -> TONMnemonic {
        let value: JSValue = try await jsWalletKit().createMnemonic(length.rawValue)
        let words = value.toArray()?.compactMap { $0 as? String } ?? []
        let mnemonic = TONMnemonic(value: words)

        guard mnemonic.value.count == length.rawValue, mnemonic.isFilled else {
            throw TONWalletKitError.invalidMnemonic
        }

        return mnemonic
    }

    public func validateMnemonic(_ mnemonic: TONMnemonic) async throws -> Bool {
        guard mnemonic.isFilled else {
            return false
        }

        return try await jsWalletKit().validateMnemonic(mnemonic.value)
    }

    public func createWallet(
        parameters: TONV5R1WalletParameters
    ) async throws -> TONWalletCreationResult {
        try await createWallet(parameters: parameters, mnemonicLength: .bits256)
    }

    public func createWallet(
        parameters: TONV5R1WalletParameters,
        mnemonicLength: TONMnemonicLength
    ) async throws -> TONWalletCreationResult {
        let mnemonic = try await generateMnemonic(length: mnemonicLength)
        let signer = try await signer(mnemonic: mnemonic)
        let adapter = try await walletV5R1Adapter(signer: signer, parameters: parameters)

        return TONWalletCreationResult(mnemonic: mnemonic, walletAdapter: adapter)
    }

    public func walletV4R2Adapter(
        signer: any TONWalletSignerProtocol,
        parameters: TONV4R2WalletParameters
    ) async throws -> any TONWalletAdapterProtocol {
        let signer = TONEncodableWalletSigner(signer: signer)
        let adapter = try await jsWalletKit().createV4R2WalletAdapter(signer, parameters)
        
        return TONWalletAdapter(jsWalletAdapter: adapter)
    }
    
    public func walletV5R1Adapter(
        signer: any TONWalletSignerProtocol,
        parameters: TONV5R1WalletParameters
    ) async throws -> any TONWalletAdapterProtocol {
        let signer = TONEncodableWalletSigner(signer: signer)
        let adapter = try await jsWalletKit().createV5R1WalletAdapter(signer, parameters)
        
        return TONWalletAdapter(jsWalletAdapter: adapter)
    }

    public func add(walletAdapter: any TONWalletAdapterProtocol) async throws -> any TONWalletProtocol {
        let walletAdapter = TONEncodableWalletAdapter(walletAdapter: walletAdapter)
        let wallet: TONWallet = try await jsWalletKit().addWallet(walletAdapter)

        return wallet
    }

    public func wallet(id: TONWalletID) async throws -> any TONWalletProtocol {
        let wallet: TONWallet = try await jsWalletKit().getWallet(id)

        return wallet
    }

    public func wallets() async throws -> [any TONWalletProtocol] {
        let value: JSValue = try await jsWalletKit().getWallets()
        let jsWallets = value.toObjectsArray()

        return try jsWallets.map {
            let wallet: TONWallet = try $0.decode()
            return wallet
        }
    }

    public func send(
        transaction: TONTransactionRequest,
        from wallet: any TONWalletProtocol
    ) async throws {
        try await jsWalletKit().sendTransaction(TONEncodableWallet(wallet: wallet), transaction)
    }
        
    public func connect(url: String) async throws {
        var components = URLComponents(string: url)
        
        if components?.scheme == nil {
            components?.scheme = "tc"
        }
        try await jsWalletKit().handleTonConnectUrl(components?.url?.absoluteString ?? url)
    }
      
    public func remove(walletId: TONWalletID) async throws {
        try await jsWalletKit().removeWallet(walletId)
    }
    
    public func add(eventsHandler: any TONBridgeEventsHandler) throws {
        if pendingEventHandlers.contains(where: { $0 === eventsHandler }) {
            return
        }
        
        if eventHandlers.contains(where: { $0 == eventsHandler }) {
            return
        }
        
        guard let context else {
            pendingEventHandlers.append(eventsHandler)
            return
        }
        
        let adapter = TONBridgeEventsHandlerJSAdapter(handler: eventsHandler, context: context)
        
        try context.add(eventsHandler: adapter)
        
        eventHandlers.append(adapter)
    }
    
    public func remove(eventsHandler: any TONBridgeEventsHandler) throws {
        pendingEventHandlers.removeAll { $0 === eventsHandler }
        
        if let adapter = eventHandlers.first(where: { $0 == eventsHandler }) {
            try context?.remove(eventsHandler: adapter)
        }
        
        eventHandlers.removeAll { $0 == eventsHandler }
    }
    
    private func addHandlers(to context: any JSWalletKitContextProtocol) {
        if pendingEventHandlers.isEmpty {
            return
        }
        
        for handler in pendingEventHandlers {
            let adapter = TONBridgeEventsHandlerJSAdapter(handler: handler, context: context)
            
            do {
                try context.add(eventsHandler: adapter)
                eventHandlers.append(adapter)
            } catch {
                debugPrint("Unable to add WalletKit event handler")
            }
        }
        
        pendingEventHandlers.removeAll()
    }
    
    func injectableBridge() throws -> TONWalletKitInjectableBridge {
        guard let context else {
            throw TONWalletKitError.bridgeUnavailable
        }
        
        return TONWalletKitInjectableBridge(
            jsWalletKit: context.walletKit,
            bridgeTransport: context.bridgeTransport
        )
    }
    
    func jsWalletKit() async throws -> JSDynamicObject {
        if let context {
            return context.walletKit
        }
        
        try await initialize()
        
        if let context {
            return context.walletKit
        } else {
            throw TONWalletKitError.notInitialized
        }
    }
}
