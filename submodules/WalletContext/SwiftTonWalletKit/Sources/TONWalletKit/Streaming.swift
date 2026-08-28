import Foundation
import TONCore
import TONToncenter

extension TonWalletKit {
    /// Live updates for a wallet.
    ///
    /// One socket per network underneath, shared by every wallet on it: subscribing to three
    /// wallets opens one connection, not three. The stream reconnects on its own and reports
    /// ``StreamEvent/connectionChanged(isConnected:)`` so an app can show that state rather
    /// than appearing frozen.
    ///
    /// Ending the loop — breaking out of `for await` — unsubscribes.
    ///
    /// ```swift
    /// for await event in await kit.updates(for: wallet.id) {
    ///     switch event {
    ///     case .balance(let update): show(update.balance)
    ///     case .transactions(let update) where !update.isInvalidated: refresh()
    ///     default: break
    ///     }
    /// }
    /// ```
    public func updates(
        for walletID: WalletID,
        types: Set<StreamEventType> = Set(StreamEventType.allCases)
    ) throws -> AsyncStream<StreamEvent> {
        let wallet = try requireWallet(walletID)
        let streaming = streamingClient(for: wallet.network)
        let address = wallet.address

        // Bridged through a second stream so the subscription can be established
        // asynchronously without making the caller await twice.
        return AsyncStream<StreamEvent>(bufferingPolicy: .unbounded) { continuation in
            let task = Task {
                for await event in await streaming.events(for: [address], types: types) {
                    continuation.yield(event)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Balance updates only, which is the common case for a wallet header.
    public func balanceUpdates(for walletID: WalletID) throws -> AsyncStream<BalanceUpdate> {
        let source = try updates(for: walletID, types: [.accountState])
        return AsyncStream(bufferingPolicy: .unbounded) { continuation in
            let task = Task {
                for await event in source {
                    if case .balance(let update) = event { continuation.yield(update) }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Transaction updates only.
    public func transactionUpdates(for walletID: WalletID) throws -> AsyncStream<TransactionUpdate> {
        let source = try updates(for: walletID, types: [.transactions])
        return AsyncStream(bufferingPolicy: .unbounded) { continuation in
            let task = Task {
                for await event in source {
                    if case .transactions(let update) = event { continuation.yield(update) }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Jetton balance updates only.
    public func jettonUpdates(for walletID: WalletID) throws -> AsyncStream<JettonUpdate> {
        let source = try updates(for: walletID, types: [.jettons])
        return AsyncStream(bufferingPolicy: .unbounded) { continuation in
            let task = Task {
                for await event in source {
                    if case .jettons(let update) = event { continuation.yield(update) }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Closes every streaming connection.
    ///
    /// Separate from ``stop()``, which ends bridge sessions: an app backgrounding might drop
    /// streaming while keeping TON Connect alive, since a missed balance update is recoverable
    /// by refreshing while a missed dApp request is not.
    public func stopStreaming() async {
        for client in streamingClients.values { await client.stop() }
        streamingClients.removeAll()
    }

    /// The streaming client for a network, created on first use.
    private func streamingClient(for network: Network) -> ToncenterStreaming {
        if let existing = streamingClients[network] { return existing }
        let factory: any StreamingSocketFactory
        if let streamingFactory {
            factory = streamingFactory(network)
        } else if let streamingURLProvider {
            factory = URLSessionStreamingSocketFactory(
                urlProvider: {
                    return try await streamingURLProvider(network)
                },
                session: urlSession
            )
        } else {
            factory = URLSessionStreamingSocketFactory(
                url: ToncenterStreaming.endpoint(
                    network: network,
                    apiKey: streamingAPIKey
                ),
                session: urlSession
            )
        }
        let client = ToncenterStreaming(
            factory: factory,
            configuration: streamingConfiguration
        )
        streamingClients[network] = client
        return client
    }
}
