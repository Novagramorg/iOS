import Foundation
import SwiftSignalKit
import TelegramCore
import WalletEngineFFI

private let walletMetadataCachedItemLimit = 10
let walletFiatRatesRefreshInterval: TimeInterval = 15 * 60

public final class WalletContext {
    enum PreparedEngineTransfer {
        case send(SendIntent)
        case nft(NftTransferIntent)
    }

    struct PreparedEngineTransferRecord {
        let walletAddress: String
        let transfer: PreparedTransfer
        let request: PreparedEngineTransfer
    }

    let engine: TelegramEngine
    let log: (String) -> Void
    let storage: WalletEngineStorage
    let runtime: WalletEngineRuntime
    let streamingLog: WalletStreamingLogger
    let streamingTransportFactory: any WalletStreamingTransportFactory
    let statePromise: ValuePromise<State>
    let tonConnectPresentationPipe = ValuePipe<TonConnectPresentation>()
    var currentState: State
    var metadata = WalletEngineMetadataRecord()
    var serverWalletState: TelegramCore.WalletState?
    var serverTransactionsNextOffset: String?
    var canSignCurrentWallet = false
    var preparedTransfers: [String: PreparedEngineTransferRecord] = [:]
    var preparedRecoveryPhraseImportRecordId: String?
    var tonConnectCoordinator: WalletTonConnectCoordinator?

    let environmentDisposable = MetaDisposable()
    let walletStateUpdatesDisposable = MetaDisposable()
    let fiatRatesDisposable = MetaDisposable()
    var isApplicationInForeground = false
    var isAccountCurrent = false
    var isNetworkAvailable = false
    var stateSubscriberCount = 0
    var activeOperationCancellation: WalletOperationCancellation?
    var serverStateTask: Task<Void, Never>?
    var activationTask: Task<Void, Never>?
    var synchronizationTask: Task<Void, Never>?
    var synchronizationTaskId: UUID?
    var synchronizationGate = WalletSynchronizationRequestGate()
    var observationTask: Task<Void, Never>?
    var retryTask: Task<Void, Never>?
    var fiatRefreshTask: Task<Void, Never>?
    var metadataWriteTask: Task<Void, Never>?
    var streamingClient: WalletToncenterStreamingClient?
    var streamingTask: Task<Void, Never>?
    var streamingRefreshTask: Task<Void, Never>?
    var streamingRefreshTaskId: UUID?
    var streamingRefreshGate = WalletStreamingRefreshGate()
    var streamingAddress: String?
    var streamingGeneration: UInt64?
    var activationGeneration: UInt64 = 0
    var balanceLastSuccessfulAt: Int32?
    var fiatLastSuccessfulAt: Int32?

    public var state: Signal<State, NoError> {
        Signal { [weak self] subscriber in
            guard let self else {
                subscriber.putCompletion()
                return EmptyDisposable
            }
            self.withMainQueue {
                self.stateSubscriberCount += 1
                self.evaluateRuntimeDemand()
            }
            let disposable = self.statePromise.get().start(next: subscriber.putNext)
            return ActionDisposable { [weak self] in
                disposable.dispose()
                self?.withMainQueue {
                    guard let self else { return }
                    self.stateSubscriberCount = max(0, self.stateSubscriberCount - 1)
                    self.evaluateRuntimeDemand()
                }
            }
        }
    }

    public var stateValue: State {
        assert(Queue.mainQueue().isCurrent())
        return self.currentState
    }

    public var tonConnectPresentations: Signal<TonConnectPresentation, NoError> {
        self.tonConnectPresentationPipe.signal()
    }

    public init(
        engine: TelegramEngine,
        storageNamespace: String,
        applicationInForeground: Signal<Bool, NoError>,
        accountIsCurrent: Signal<Bool, NoError>,
        networkAvailable: Signal<Bool, NoError>,
        log: @escaping (String) -> Void = { _ in }
    ) {
        let storage = WalletEngineStorage(namespace: storageNamespace)
        self.engine = engine
        self.log = log
        self.storage = storage
        self.runtime = WalletEngineRuntime(engine: engine, storage: storage)
        let streamingLog = WalletStreamingLogger(log)
        self.streamingLog = streamingLog
        let streamingURLProvider = WalletStreamingURLProvider(engine: engine, log: streamingLog)
        self.streamingTransportFactory = WalletURLSessionStreamingTransportFactory(provider: streamingURLProvider, log: streamingLog)
        let initialState = State(
            phase: .restoring,
            balance: .idle,
            transactions: TransactionsState(items: [], offset: 0, canLoadMore: false, isLoadingMore: false, error: nil),
            pendingTransfers: [],
            activeOperation: nil
        )
        self.currentState = initialState
        self.statePromise = ValuePromise(initialState, ignoreRepeated: true)

        self.walletStateUpdatesDisposable.set((engine.wallet.stateUpdates()
        |> deliverOnMainQueue).start(next: { [weak self] value in
            self?.applyServerWalletState(value)
        }))

        self.environmentDisposable.set(combineLatest(queue: Queue.mainQueue(),
            applicationInForeground |> distinctUntilChanged,
            accountIsCurrent |> distinctUntilChanged,
            networkAvailable |> distinctUntilChanged
        ).start(next: { [weak self] foreground, current, network in
            guard let self else { return }
            self.isApplicationInForeground = foreground
            self.isAccountCurrent = current
            self.isNetworkAvailable = network
            self.evaluateRuntimeDemand()
        }))

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                if let metadata = try await storage.loadMetadata(), metadata.schemaVersion == 2 {
                    let cachedTransactions = try await walletTransactions(
                        from: metadata.transactions,
                        engine: self.engine
                    )
                    self.metadata = metadata
                    self.balanceLastSuccessfulAt = metadata.balanceUpdatedAt
                    self.fiatLastSuccessfulAt = metadata.fiatRatesUpdatedAt
                    if case .restoring = self.currentState.phase {
                        self.replaceState(
                            phase: .restoring,
                            balance: metadata.balance.map { .value($0, updatedAt: metadata.balanceUpdatedAt ?? 0) } ?? .idle,
                            transactions: TransactionsState(
                                items: Array(cachedTransactions.prefix(walletMetadataCachedItemLimit)),
                                offset: cachedTransactions.count,
                                canLoadMore: false,
                                isLoadingMore: false,
                                error: nil
                            ),
                            collectibles: CollectiblesState(
                                items: Array(metadata.collectibles.prefix(walletMetadataCachedItemLimit)),
                                offset: metadata.collectibles.count,
                                canLoadMore: false,
                                isLoadingMore: false,
                                error: nil
                            ),
                            pendingTransfers: metadata.pendingTransfers,
                            activeOperation: nil,
                            fiat: FiatState(
                                selectedCurrency: metadata.selectedFiatCurrency,
                                rates: metadata.fiatRates.map { .value($0, updatedAt: metadata.fiatRatesUpdatedAt ?? 0) } ?? .idle
                            )
                        )
                    }
                }
            } catch let error as WalletEngineStorageError {
                self.replaceState(
                    phase: .failed(Self.storageError(error)),
                    balance: self.currentState.balance,
                    transactions: self.currentState.transactions,
                    pendingTransfers: [],
                    activeOperation: nil
                )
                return
            } catch {
                self.replaceState(
                    phase: .failed(.corrupted),
                    balance: self.currentState.balance,
                    transactions: self.currentState.transactions,
                    pendingTransfers: [],
                    activeOperation: nil
                )
                return
            }
            self.requestServerWalletState()
        }
    }

    deinit {
        self.environmentDisposable.dispose()
        self.walletStateUpdatesDisposable.dispose()
        self.fiatRatesDisposable.dispose()
        self.serverStateTask?.cancel()
        self.activationTask?.cancel()
        self.synchronizationTask?.cancel()
        self.observationTask?.cancel()
        self.retryTask?.cancel()
        self.fiatRefreshTask?.cancel()
        self.streamingTask?.cancel()
        self.streamingRefreshTask?.cancel()
        self.activeOperationCancellation?.cancel()
        let runtime = self.runtime
        let coordinator = self.tonConnectCoordinator
        let streamingClient = self.streamingClient
        Task {
            await streamingClient?.stop()
            await coordinator?.shutdown()
            await runtime.shutdown()
        }
    }

    func evaluateRuntimeDemand() {
        assert(Queue.mainQueue().isCurrent())
        self.evaluateStreamingDemand()
        guard self.canUseNetworkRuntime else {
            self.cancelSynchronization()
            self.retryTask?.cancel()
            self.retryTask = nil
            return
        }
        self.requestServerWalletState()
        if self.stateSubscriberCount > 0 || !self.currentState.pendingTransfers.isEmpty {
            self.requestSynchronization()
        }
        if self.stateSubscriberCount > 0 {
            self.requestFiatRates()
        }
    }

    var canUseNetworkRuntime: Bool {
        self.isApplicationInForeground && self.isAccountCurrent && self.isNetworkAvailable
    }

    func requestServerWalletState() {
        guard self.canUseNetworkRuntime, self.serverStateTask == nil else { return }
        self.serverStateTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.serverStateTask = nil }
            do {
                let value = try await WalletSignalRequestContext<TelegramCore.WalletState>().run(
                    self.engine.wallet.getState()
                )
                try Task.checkCancellation()
                var promotedReplacement = false
                let isMutatingReplacementCandidate = self.preparedRecoveryPhraseImportRecordId != nil
                    || self.currentState.activeOperation == .creating
                    || self.currentState.activeOperation == .importing
                    || self.currentState.activeOperation == .preparingRecoveryPhraseImport
                    || self.currentState.activeOperation == .completingRecoveryPhraseImport
                if !isMutatingReplacementCandidate {
                    if case let .ready(_, _, _, address, publicKey, _) = value {
                        promotedReplacement = try await self.runtime.reconcileReplacementCandidate(
                            serverAddress: address,
                            serverPublicKey: publicKey,
                            discardMismatch: true
                        )
                    } else if case .empty = value {
                        try await self.runtime.discardReplacementAfterAuthoritativeEmptyState()
                    }
                }
                self.applyServerWalletState(value, forceActivation: promotedReplacement)
            } catch is CancellationError {
            } catch {
                self.log("event=wallet_state_failed error=\(type(of: error))")
                self.scheduleRetry()
            }
        }
    }

    func applyServerWalletState(_ value: TelegramCore.WalletState, forceActivation: Bool = false) {
        assert(Queue.mainQueue().isCurrent())
        self.serverWalletState = value
        if self.currentState.activeOperation == .creating
            || self.currentState.activeOperation == .importing
            || self.currentState.activeOperation == .preparingRecoveryPhraseImport
            || self.currentState.activeOperation == .completingRecoveryPhraseImport {
            // replaceWallet also emits updateWalletState. The RPC result owns the
            // staged-secret commit; applying the update here would cancel it.
            return
        }
        if !forceActivation,
           case let .ready(backupEnabled, canExportPhrase, canEnableBackup, address, publicKey, _) = value,
           case let .wallet(currentInfo) = self.currentState.phase,
           walletEngineAddressesEqual(currentInfo.address, address),
           currentInfo.publicKey == publicKey.map({ String(format: "%02x", $0) }).joined() {
            self.replaceState(
                phase: .wallet(WalletInfo(
                    address: currentInfo.address,
                    publicKey: currentInfo.publicKey,
                    backupEnabled: backupEnabled,
                    canExportPhrase: canExportPhrase,
                    canEnableBackup: canEnableBackup,
                    canSign: self.canSignCurrentWallet
                )),
                balance: self.currentState.balance,
                transactions: self.currentState.transactions,
                pendingTransfers: self.currentState.pendingTransfers,
                activeOperation: self.currentState.activeOperation
            )
            self.requestSynchronization()
            return
        }
        self.activationGeneration &+= 1
        self.stopStreaming()
        self.activeOperationCancellation?.cancel()
        self.activeOperationCancellation = nil
        self.preparedTransfers.removeAll()
        let generation = self.activationGeneration
        self.activationTask?.cancel()
        self.activationTask = nil

        switch value {
        case let .empty(provisioning):
            self.canSignCurrentWallet = false
            self.observationTask?.cancel()
            self.observationTask = nil
            self.cancelSynchronization()
            let previousCoordinator = self.tonConnectCoordinator
            self.tonConnectCoordinator = nil
            self.activationTask = Task { [runtime = self.runtime] in
                guard !Task.isCancelled else { return }
                await previousCoordinator?.shutdown()
                guard !Task.isCancelled else { return }
                await runtime.shutdown()
            }
            self.replaceState(
                phase: provisioning ? .provisioning : .empty,
                balance: .idle,
                transactions: TransactionsState(items: [], offset: 0, canLoadMore: false, isLoadingMore: false, error: nil),
                collectibles: .empty,
                pendingTransfers: [],
                activeOperation: nil
            )
        case let .ready(backupEnabled, canExportPhrase, canEnableBackup, address, publicKey, _):
            let isSameCachedIdentity = self.metadata.walletAddress.map {
                walletEngineAddressesEqual($0, address)
            } ?? false
            let previousBalance = isSameCachedIdentity ? self.currentState.balance.currentValue : nil
            let previousCoordinator = self.tonConnectCoordinator
            self.tonConnectCoordinator = nil
            self.observationTask?.cancel()
            self.observationTask = nil
            self.cancelSynchronization()
            self.replaceState(
                phase: .restoring,
                balance: .loading(previous: previousBalance),
                transactions: isSameCachedIdentity
                    ? self.currentState.transactions
                    : TransactionsState(items: [], offset: 0, canLoadMore: false, isLoadingMore: false, error: nil),
                collectibles: isSameCachedIdentity ? self.currentState.collectibles : .empty,
                pendingTransfers: isSameCachedIdentity ? self.currentState.pendingTransfers : [],
                activeOperation: nil
            )
            self.activationTask = Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    await previousCoordinator?.shutdown()
                    let stored = try await self.storage.loadDescriptor()
                    let storedMatchesIdentity = stored.map {
                        $0.schemaVersion == 2
                            && $0.network == "mainnet"
                            && walletEngineAddressesEqual($0.address, address)
                            && $0.publicKey == publicKey
                    } ?? false
                    let hasStoredSecret: Bool
                    if storedMatchesIdentity, let secretRef = stored?.secretRef {
                        hasStoredSecret = try await self.storage.containsProtectedSecret(
                            ProtectedSecretRef(value: secretRef)
                        )
                    } else {
                        hasStoredSecret = false
                    }
                    let needsSecret = !hasStoredSecret
                    var words: [String]?
                    if needsSecret && canExportPhrase {
                        words = try? await exportWalletSecretPhrase(engine: self.engine, password: nil)
                    }
                    let activation: WalletEngineActivation
                    if let words {
                        do {
                            let prepared = try await stageRecoveryPhraseImport(
                                runtime: self.runtime,
                                words: words,
                                sourceAddress: address,
                                sourcePublicKey: publicKey
                            )
                            guard prepared.disposition == .currentWallet else {
                                try? await self.runtime.discardReplacement(recordId: prepared.recordId)
                                throw WalletError.storage(.identityMismatch)
                            }
                            activation = try await self.runtime.commitReplacement(
                                recordId: prepared.recordId,
                                serverAddress: address,
                                serverPublicKey: publicKey
                            )
                        } catch {
                            // Automatic recovery is best-effort. Password, transport,
                            // or invalid backup data leave the wallet read-only.
                            activation = try await self.runtime.activate(
                                serverAddress: address,
                                serverPublicKey: publicKey,
                                exportedWords: nil
                            )
                        }
                    } else {
                        activation = try await self.runtime.activate(
                            serverAddress: address,
                            serverPublicKey: publicKey,
                            exportedWords: nil
                        )
                    }
                    try Task.checkCancellation()
                    guard self.activationGeneration == generation else { return }
                    self.canSignCurrentWallet = activation.canSign
                    let info = WalletInfo(
                        address: address,
                        publicKey: publicKey.map { String(format: "%02x", $0) }.joined(),
                        backupEnabled: backupEnabled,
                        canExportPhrase: canExportPhrase,
                        canEnableBackup: canEnableBackup,
                        canSign: activation.canSign
                    )
                    self.replaceState(
                        phase: .wallet(info),
                        balance: self.currentState.balance,
                        transactions: self.currentState.transactions,
                        pendingTransfers: self.currentState.pendingTransfers,
                        activeOperation: nil
                    )
                    self.beginObserving(snapshot: activation.snapshot, generation: generation)
                    if activation.canSign {
                        let coordinator = WalletTonConnectCoordinator(
                            runtime: self.runtime,
                            storage: self.storage,
                            recordId: activation.snapshot.recordId,
                            event: { [weak self] event in
                                self?.withMainQueue { self?.handleTonConnectEvent(event) }
                            }
                        )
                        self.tonConnectCoordinator = coordinator
                        Task { await coordinator.restore() }
                    }
                    self.requestSynchronization()
                } catch is CancellationError {
                } catch let error as WalletEngineStorageError {
                    self.replaceState(
                        phase: .failed(Self.storageError(error)),
                        balance: self.currentState.balance,
                        transactions: self.currentState.transactions,
                        pendingTransfers: [],
                        activeOperation: nil
                    )
                } catch {
                    self.log("event=wallet_engine_activation_failed error=\(type(of: error))")
                    self.replaceState(
                        phase: .failed(.unsupportedVersion),
                        balance: .idle,
                        transactions: self.currentState.transactions,
                        pendingTransfers: [],
                        activeOperation: nil
                    )
                }
            }
        }
    }

    @MainActor
    func beginObserving(snapshot: WalletSnapshot, generation: UInt64) {
        self.observationTask?.cancel()
        self.applyEngineSnapshot(snapshot)
        self.observationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            var revision = snapshot.revision
            while !Task.isCancelled, self.activationGeneration == generation {
                do {
                    let value = try await self.runtime.waitForChange(afterRevision: revision)
                    guard value.revision > revision else { continue }
                    revision = value.revision
                    guard self.activationGeneration == generation else { return }
                    self.applyEngineSnapshot(value)
                } catch is CancellationError {
                    return
                } catch {
                    guard self.activationGeneration == generation else { return }
                    self.log("event=wallet_engine_observation_failed error=\(type(of: error))")
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
        }
    }

    @MainActor
    func applyEngineSnapshot(_ snapshot: WalletSnapshot) {
        assert(Queue.mainQueue().isCurrent())
        let balance: Resource<Int64>
        if let account = snapshot.account, let value = walletEngineBalance(account.balanceNanograms) {
            let timestamp = currentWalletTimestamp()
            self.balanceLastSuccessfulAt = timestamp
            balance = .value(value, updatedAt: timestamp)
        } else {
            switch snapshot.accountResource.phase {
            case .idle: balance = self.currentState.balance
            case .loading: balance = .loading(previous: self.currentState.balance.currentValue)
            case .ready: balance = .stale(previous: self.currentState.balance.currentValue, error: .invalidData, lastSuccessfulAt: self.balanceLastSuccessfulAt)
            case .failed: balance = .stale(previous: self.currentState.balance.currentValue, error: synchronizationError(snapshot.accountResource.error), lastSuccessfulAt: self.balanceLastSuccessfulAt)
            }
        }
        let pending = self.reconcilePendingTransfers(snapshot.send)
        self.replaceState(
            phase: self.currentState.phase,
            balance: balance,
            transactions: self.currentState.transactions,
            pendingTransfers: pending,
            activeOperation: self.currentState.activeOperation
        )
    }

    func requestSynchronization(force: Bool = false) {
        guard self.canUseNetworkRuntime,
              (force || self.stateSubscriberCount > 0 || !self.currentState.pendingTransfers.isEmpty),
              case .wallet = self.currentState.phase else { return }
        guard self.synchronizationGate.beginOrQueue() else {
            return
        }
        let taskId = UUID()
        self.synchronizationTaskId = taskId
        self.synchronizationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if self.synchronizationTaskId == taskId {
                    self.synchronizationTask = nil
                    self.synchronizationTaskId = nil
                    if self.synchronizationGate.complete() {
                        self.requestSynchronization(force: true)
                    }
                }
            }

            async let engineResult = captureAsync { try await self.runtime.refresh() }
            async let nftResult = captureAsync { try await self.runtime.refreshNfts() }
            async let transactionResult = captureAsync {
                try await WalletSignalRequestContext<TelegramCore.WalletTransactions>().run(
                    self.engine.wallet.getTransactions(
                        inbound: true,
                        outbound: true,
                        offset: "",
                        limit: Int32(walletTransactionFetchLimit)
                    )
                )
            }
            let (engine, nfts, transactions) = await (engineResult, nftResult, transactionResult)
            guard !Task.isCancelled else { return }

            var balance = self.currentState.balance
            var transactionState = self.currentState.transactions
            var collectiblesState = self.currentState.collectibles
            var snapshot: WalletSnapshot?
            var shouldRetry = false

            switch engine {
            case let .success(update):
                snapshot = update.snapshot
                if let account = update.snapshot.account, let value = walletEngineBalance(account.balanceNanograms) {
                    let timestamp = currentWalletTimestamp()
                    self.balanceLastSuccessfulAt = timestamp
                    balance = .value(value, updatedAt: timestamp)
                } else {
                    balance = .stale(previous: balance.currentValue, error: .invalidData, lastSuccessfulAt: self.balanceLastSuccessfulAt)
                }
            case let .failure(error):
                let mappedError = synchronizationError(error)
                balance = .stale(previous: balance.currentValue, error: mappedError, lastSuccessfulAt: self.balanceLastSuccessfulAt)
                shouldRetry = shouldRetry || mappedError.isRetryable
            }

            switch transactions {
            case let .success(response):
                let values = walletTransactions(from: response.items)
                self.serverTransactionsNextOffset = response.nextOffset
                transactionState = TransactionsState(
                    items: values,
                    offset: values.count,
                    canLoadMore: response.nextOffset != nil,
                    isLoadingMore: false,
                    error: nil
                )
            case let .failure(error):
                let mappedError = synchronizationError(error)
                transactionState = TransactionsState(
                    items: transactionState.items,
                    offset: transactionState.offset,
                    canLoadMore: transactionState.canLoadMore,
                    isLoadingMore: false,
                    error: mappedError
                )
                shouldRetry = shouldRetry || mappedError.isRetryable
            }

            switch nfts {
            case let .success(update):
                snapshot = update.snapshot
                let values = await walletCollectibles(from: update.snapshot.nfts.items)
                collectiblesState = CollectiblesState(
                    items: values,
                    offset: values.count,
                    canLoadMore: update.snapshot.nfts.hasMore,
                    isLoadingMore: false,
                    error: nil
                )
            case let .failure(error):
                let mappedError = synchronizationError(error)
                collectiblesState = CollectiblesState(
                    items: collectiblesState.items,
                    offset: collectiblesState.offset,
                    canLoadMore: collectiblesState.canLoadMore,
                    isLoadingMore: false,
                    error: mappedError
                )
                shouldRetry = shouldRetry || mappedError.isRetryable
            }
            let pending = snapshot.map { self.reconcilePendingTransfers($0.send) } ?? self.currentState.pendingTransfers
            self.replaceState(
                phase: self.currentState.phase,
                balance: balance,
                transactions: transactionState,
                collectibles: collectiblesState,
                pendingTransfers: pending,
                activeOperation: self.currentState.activeOperation
            )
            if shouldRetry {
                self.scheduleRetry()
            }
        }
    }

    func cancelSynchronization() {
        self.synchronizationTask?.cancel()
        self.synchronizationTask = nil
        self.synchronizationTaskId = nil
        self.synchronizationGate.cancel()
    }

    func reconcilePendingTransfers(_ send: SendSnapshot) -> [PendingTransfer] {
        guard let id = send.operationId,
              let index = self.currentState.pendingTransfers.firstIndex(where: { $0.id == id }) else {
            return self.currentState.pendingTransfers
        }
        var values = self.currentState.pendingTransfers
        switch send.phase {
        case .submitted, .submissionUnknown, .confirmed:
            let current = values[index]
            values[index] = PendingTransfer(
                id: current.id,
                recipient: current.recipient,
                amount: current.amount,
                comment: current.comment,
                collectibleAddress: current.collectibleAddress,
                normalizedHash: current.normalizedHash,
                createdAt: current.createdAt,
                status: send.phase == .submissionUnknown ? .submissionUnknown : .pending
            )
            if send.phase == .confirmed {
                values.remove(at: index)
                self.requestSynchronization(force: true)
            }
        case .replaced, .sequenceNumberConsumed, .expired, .superseded, .failed, .cancelled:
            values.remove(at: index)
            self.requestSynchronization(force: true)
        case .idle, .validating, .authorizing, .preparing, .persisting, .readyToSubmit, .submitting, .handedOff:
            break
        }
        return values
    }

    func replaceState(
        phase: Phase,
        balance: Resource<Int64>,
        transactions: TransactionsState,
        collectibles: CollectiblesState? = nil,
        pendingTransfers: [PendingTransfer],
        activeOperation: ActiveOperation?,
        fiat: FiatState? = nil
    ) {
        let value = State(
            phase: phase,
            balance: balance,
            transactions: transactions,
            collectibles: collectibles ?? self.currentState.collectibles,
            pendingTransfers: pendingTransfers,
            activeOperation: activeOperation,
            fiat: fiat ?? self.currentState.fiat
        )
        guard value != self.currentState else { return }
        self.currentState = value
        self.statePromise.set(value)
        self.persistMetadata(value)
        self.evaluateStreamingDemand()
    }

    func persistMetadata(_ state: State) {
        self.metadata.walletAddress = {
            if case let .wallet(info) = state.phase { return info.address }
            return self.metadata.walletAddress
        }()
        self.metadata.pendingTransfers = state.pendingTransfers
        self.metadata.balance = state.balance.currentValue
        self.metadata.balanceUpdatedAt = state.balance.lastSuccessfulAt ?? self.balanceLastSuccessfulAt
        self.metadata.fiatRates = state.fiat.rates.currentValue
        self.metadata.fiatRatesUpdatedAt = state.fiat.rates.lastSuccessfulAt ?? self.fiatLastSuccessfulAt
        self.metadata.selectedFiatCurrency = state.fiat.selectedCurrency
        self.metadata.transactions = state.transactions.items
            .prefix(walletMetadataCachedItemLimit)
            .map(WalletStoredTransaction.init)
        self.metadata.collectibles = Array(state.collectibles.items.prefix(walletMetadataCachedItemLimit))
        let metadata = self.metadata
        let storage = self.storage
        let previousWrite = self.metadataWriteTask
        let log = self.log
        self.metadataWriteTask = Task {
            await previousWrite?.value
            do {
                try await storage.saveMetadata(metadata)
            } catch {
                log("event=wallet_metadata_write_failed error=\(type(of: error))")
            }
        }
    }

    func scheduleRetry() {
        guard self.retryTask == nil, self.canUseNetworkRuntime else { return }
        self.retryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard let self, !Task.isCancelled else { return }
            self.retryTask = nil
            self.requestServerWalletState()
            self.requestSynchronization()
        }
    }

    func handleTonConnectEvent(_ event: WalletTonConnectEvent) {
        switch event {
        case let .connect(value): self.tonConnectPresentationPipe.putNext(.request(value))
        case let .operation(value): self.tonConnectPresentationPipe.putNext(.operation(value))
        case let .dismiss(id): self.tonConnectPresentationPipe.putNext(.dismiss(requestId: id))
        case let .error(value): self.tonConnectPresentationPipe.putNext(.error(value))
        }
    }

    func withMainQueue(_ action: @escaping () -> Void) {
        if Queue.mainQueue().isCurrent() { action() } else { Queue.mainQueue().async(action) }
    }

    static func storageError(_ error: WalletEngineStorageError) -> FatalStorageError {
        switch error {
        case let .keychainStatus(status): return .keychainStatus(status)
        case .corrupted: return .corrupted
        }
    }
}

func captureAsync<Value>(_ operation: () async throws -> Value) async -> Result<Value, Error> {
    do { return .success(try await operation()) } catch { return .failure(error) }
}

func currentWalletTimestamp() -> Int32 {
    Int32(clamping: Int64(Date().timeIntervalSince1970))
}

func walletEngineBalance(_ nanograms: String) -> Int64? {
    Int64(nanograms)
}

func walletEngineAcceptsSubmission(_ phase: SendPhase) -> Bool {
    phase == .submitted || phase == .submissionUnknown || phase == .confirmed
}

func walletEngineAcceptsSignHandoff(_ phase: SendPhase) -> Bool {
    phase == .handedOff
}

func synchronizationError(_ error: DomainError?) -> WalletContext.SynchronizationError {
    guard let error else { return .sdk }
    switch error.code {
    case .invalidProviderResponse, .responseTooLarge, .hostPolicyViolation:
        return .invalidData
    case .hostCancelled:
        return .unavailable
    case .rateLimited:
        return .http(statusCode: error.providerStatus.map { Int($0) } ?? 429)
    case .httpRejected:
        return error.providerStatus.map { .http(statusCode: Int($0)) } ?? .network
    case .transportFailed:
        return error.hostKind == .timeout ? .timeout : .network
    }
}

func synchronizationError(_ error: Error?) -> WalletContext.SynchronizationError {
    guard let error else { return .sdk }
    if let error = error as? WalletContext.WalletError {
        switch error {
        case .unavailable: return .unavailable
        case .network: return .network
        case .invalidAddress, .invalidAmount, .invalidMnemonic, .previewIncomplete, .previewFailed: return .invalidData
        default: return .sdk
        }
    }
    if let error = error as? URLError {
        return error.code == .timedOut ? .timeout : .network
    }
    return .sdk
}

func walletError(_ error: Error) -> WalletContext.WalletError {
    if let value = error as? WalletContext.WalletError { return value }
    if let value = error as? TelegramCore.WalletOperationError {
        switch value {
        case .generic: return .unavailable
        case .network: return .network
        case .requestPassword: return .requestPassword
        case .invalidPassword: return .invalidPassword
        case .twoStepAuthMissing: return .twoStepAuthMissing
        case let .passwordTooFresh(timeout): return .passwordTooFresh(timeout)
        case let .sessionTooFresh(timeout): return .sessionTooFresh(timeout)
        case .backupDisabled: return .backupDisabled
        case .backupNotAvailable: return .backupNotAvailable
        case .replacementInvalid: return .replacementInvalid
        case .publicKeyInvalid: return .publicKeyInvalid
        case .tokenInvalid: return .tokenInvalid
        case .tokenExpired: return .tokenExpired
        case .clientKeyInvalid: return .clientKeyInvalid
        case .partUnavailable: return .partUnavailable
        case .invalidBackupData: return .invalidBackupData
        }
    }
    if error is URLError || error is TonApiRequestError { return .network }
    return .sdk(sanitizedWalletEngineDiagnostic(String(describing: error)))
}

final class WalletOperationCancellation {
    private let lock = NSLock()
    private var task: Task<Void, Never>?
    private var cancelled = false
    func setTask(_ value: Task<Void, Never>) {
        self.lock.lock()
        if self.cancelled {
            self.lock.unlock()
            value.cancel()
        } else {
            self.task = value
            self.lock.unlock()
        }
    }
    func cancel() {
        self.lock.lock()
        self.cancelled = true
        let task = self.task
        self.task = nil
        self.lock.unlock()
        task?.cancel()
    }
}
