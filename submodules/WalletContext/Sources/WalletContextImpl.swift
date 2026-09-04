import Foundation
import SwiftSignalKit
import TelegramCore
import WalletEngineFFI

private let walletStoredStateCachedItemLimit = 10
let walletFiatRatesRefreshInterval: TimeInterval = 15 * 60

final class WalletContextErrorLogger: @unchecked Sendable {
    private let sink: (String) -> Void

    init(_ sink: @escaping (String) -> Void) {
        self.sink = sink
    }

    func log(_ message: String) {
        self.sink(message)
    }

    func error(_ event: String, _ error: Error, context: String? = nil) {
        var message = "event=\(event) \(walletContextErrorFields(error))"
        if let context, !context.isEmpty {
            message += " \(context)"
        }
        self.sink(message)
    }
}

func walletContextErrorFields(_ error: Error) -> String {
    let nsError = error as NSError
    var result = "error_type=\(String(reflecting: type(of: error))) error_domain=\(nsError.domain) error_code=\(nsError.code)"
    if let kind = walletContextErrorKind(error) {
        result += " error_kind=\(kind)"
    }
    return result
}

private func walletContextErrorKind(_ error: Error) -> String? {
    if error is CancellationError {
        return "cancelled"
    }
    if let error = error as? TelegramCore.WalletOperationError {
        switch error {
        case .generic: return "telegram_generic"
        case .network: return "telegram_network"
        case .requestPassword: return "request_password"
        case .invalidPassword: return "invalid_password"
        case .twoStepAuthMissing: return "two_step_auth_missing"
        case .passwordTooFresh: return "password_too_fresh"
        case .sessionTooFresh: return "session_too_fresh"
        case .backupDisabled: return "backup_disabled"
        case .backupNotAvailable: return "backup_not_available"
        case .replacementInvalid: return "replacement_invalid"
        case .publicKeyInvalid: return "public_key_invalid"
        case .tokenInvalid: return "token_invalid"
        case .tokenExpired: return "token_expired"
        case .clientKeyInvalid: return "client_key_invalid"
        case .partUnavailable: return "part_unavailable"
        case .invalidBackupData: return "invalid_backup_data"
        }
    }
    if let error = error as? WalletEngineStorageError {
        switch error {
        case .keychainStatus: return "keychain_status"
        case .corrupted: return "storage_corrupted"
        }
    }
    if let error = error as? WalletClientError {
        return "wallet_engine_\(walletEngineErrorCaseName(error))"
    }
    if let error = error as? WalletContext.WalletError {
        switch error {
        case .unavailable: return "unavailable"
        case .noWallet: return "no_wallet"
        case .invalidMnemonic: return "invalid_mnemonic"
        case .invalidAddress: return "invalid_address"
        case .invalidAmount: return "invalid_amount"
        case .operationInProgress: return "operation_in_progress"
        case .previewFailed: return "preview_failed"
        case .previewIncomplete: return "preview_incomplete"
        case .preparedTransferExpired: return "prepared_transfer_expired"
        case .preparedTransferNotFound: return "prepared_transfer_not_found"
        case .network: return "network"
        case .requestPassword: return "request_password"
        case .invalidPassword: return "invalid_password"
        case .twoStepAuthMissing: return "two_step_auth_missing"
        case .authorizationCancelled: return "authorization_cancelled"
        case .passwordTooFresh: return "password_too_fresh"
        case .sessionTooFresh: return "session_too_fresh"
        case .backupDisabled: return "backup_disabled"
        case .backupNotAvailable: return "backup_not_available"
        case .replacementInvalid: return "replacement_invalid"
        case .publicKeyInvalid: return "public_key_invalid"
        case .keyRotationFailed: return "key_rotation_failed"
        case .tokenInvalid: return "token_invalid"
        case .tokenExpired: return "token_expired"
        case .clientKeyInvalid: return "client_key_invalid"
        case .partUnavailable: return "part_unavailable"
        case .invalidBackupData: return "invalid_backup_data"
        case .insufficientBalance: return "insufficient_balance"
        case .storage: return "storage"
        case .sdk: return "sdk"
        }
    }
    if let error = error as? TonApiRequestError {
        return "telegram_relay_\(error.code)"
    }
    if let error = error as? URLError {
        return "url_\(error.code.rawValue)"
    }
    return nil
}

private func walletEngineErrorCaseName(_ error: WalletClientError) -> String {
    if case .SendAlreadyInProgress = error {
        return "send_already_in_progress"
    }
    if case .SendPreviewAlreadyInProgress = error {
        return "send_preview_already_in_progress"
    }
    let reflected = String(reflecting: error)
    let withoutPayload = reflected.split(separator: "(", maxSplits: 1).first.map(String.init) ?? reflected
    let name = withoutPayload.split(separator: ".").last.map(String.init) ?? withoutPayload
    var result = ""
    for scalar in name.unicodeScalars {
        if CharacterSet.uppercaseLetters.contains(scalar) {
            if !result.isEmpty {
                result.append("_")
            }
            result.append(String(scalar).lowercased())
        } else if CharacterSet.alphanumerics.contains(scalar) {
            result.append(String(scalar).lowercased())
        } else if result.last != "_" {
            result.append("_")
        }
    }
    return result.isEmpty ? "unknown" : result
}

actor WalletContextImpl {
    typealias FiatCurrency = WalletContext.FiatCurrency
    typealias FiatRate = WalletContext.FiatRate
    typealias FiatState = WalletContext.FiatState
    typealias WalletInfo = WalletContext.WalletInfo
    typealias TonConnectPermission = WalletContext.TonConnectPermission
    typealias TonConnectRequest = WalletContext.TonConnectRequest
    typealias TonConnectOperationRequest = WalletContext.TonConnectOperationRequest
    typealias TonConnectPresentation = WalletContext.TonConnectPresentation
    typealias FatalStorageError = WalletContext.FatalStorageError
    typealias SynchronizationError = WalletContext.SynchronizationError
    typealias Resource<Value: Equatable & Sendable> = WalletContext.Resource<Value>
    typealias Transaction = WalletContext.Transaction
    typealias TransactionsState = WalletContext.TransactionsState
    typealias Collectible = WalletContext.Collectible
    typealias CollectiblesState = WalletContext.CollectiblesState
    typealias PendingTransfer = WalletContext.PendingTransfer
    typealias PreparedBackupDisable = WalletContext.PreparedBackupDisable
    typealias PreparedRecoveryPhraseImport = WalletContext.PreparedRecoveryPhraseImport
    typealias ActiveOperation = WalletContext.ActiveOperation
    typealias Phase = WalletContext.Phase
    typealias State = WalletContext.State
    typealias WalletError = WalletContext.WalletError
    typealias ResolvedTransferRecipient = WalletContext.ResolvedTransferRecipient
    typealias CreatedWallet = WalletContext.CreatedWallet
    typealias PreparedTransfer = WalletContext.PreparedTransfer
    typealias SubmittedTransfer = WalletContext.SubmittedTransfer

    enum PreparedEngineTransfer {
        case send(SendIntent)
        case nft(NftTransferIntent)
    }

    struct PreparedEngineTransferRecord {
        let walletAddress: String
        let transfer: PreparedTransfer
        let request: PreparedEngineTransfer
    }

    struct PendingTransferHistoryReconciliation {
        let pendingTransfers: [PendingTransfer]
        let resolvedStreamingTraceIds: Set<String>
        let removedPendingCount: Int
    }

    struct OutgoingTransactionPresentationIdentity {
        let presentationId: String
        var normalizedHash: String?
        var transactionHash: String?
    }

    let engine: TelegramEngine
    let errorLogger: WalletContextErrorLogger
    let storage: WalletEngineStorage
    let runtime: WalletEngineRuntime
    let streamingLog: WalletStreamingLogger
    let streamingTransportFactory: any WalletStreamingTransportFactory
    let storedStateWriter: WalletStoredStateWriter
    let output: WalletContextOutput
    var currentState: State
    var storedState = WalletStoredState()
    var serverWalletState: TelegramCore.WalletState?
    var pendingInitialServerWalletState: (state: TelegramCore.WalletState, refreshIfStreamingUnavailable: Bool)?
    var deferredServerWalletState: (state: TelegramCore.WalletState, refreshIfStreamingUnavailable: Bool)?
    var serverStateRefreshRequested = false
    var serverTransactionsNextOffset: String?
    var preparedTransfers: [String: PreparedEngineTransferRecord] = [:]
    var deferredSynchronizationScope: WalletSynchronizationScope = []
    var preparedRecoveryPhraseImportRecordId: String?
    var tonConnectCoordinator: WalletTonConnectCoordinator?
    var peerByWalletAddress: [String: EnginePeer] = [:]
    var outgoingTransactionPresentationIdentities: [String: OutgoingTransactionPresentationIdentity] = [:]

    let fiatRatesDisposable = MetaDisposable()
    var isStoredStateRestored = false
    var isApplicationInForeground = false
    var isAccountCurrent = false
    var isNetworkAvailable = false
    var stateSubscriberCount = 0
    var walletScreenCount = 0
    var latestEnvironmentRevision: UInt64 = 0
    var latestWalletStateRevision: UInt64 = 0
    var latestSubscriberDemandRevision: UInt64 = 0
    var latestWalletScreenDemandRevision: UInt64 = 0
    var latestFiatCurrencyRevision: UInt64 = 0
    var activeOperationId: UUID?
    var isShutdown = false
    var serverStateTask: Task<Void, Never>?
    var activationTask: Task<Void, Never>?
    var synchronizationTask: Task<Void, Never>?
    var synchronizationTaskId: UUID?
    var synchronizationGate = WalletSynchronizationRequestGate()
    var observationTask: Task<Void, Never>?
    var serverStateRetryTask: Task<Void, Never>?
    var pollingTask: Task<Void, Never>?
    var pollingTaskId: UUID?
    var walletStateFallbackRefreshTask: Task<Void, Never>?
    var walletStateFallbackRefreshTaskId: UUID?
    var fiatRefreshTask: Task<Void, Never>?
    var streamingClient: WalletToncenterStreamingClient?
    var streamingTask: Task<Void, Never>?
    var streamingRefreshTask: Task<Void, Never>?
    var streamingRefreshTaskId: UUID?
    var streamingRefreshGate = WalletStreamingRefreshGate()
    var streamingAddress: String?
    var streamingGeneration: UInt64?
    var streamingConnectionState: WalletStreamingConnectionState = .inactive
    var streamingHasSubscribed = false
    var streamingPresentationOverlay = WalletStreamingPresentationOverlay()
    var activationGeneration: UInt64 = 0
    var balanceLastSuccessfulAt: Int32?
    var fiatLastSuccessfulAt: Int32?
    var storedStateMutationRevision: UInt64 = 0

    init(
        engine: TelegramEngine,
        storageNamespace: String,
        initialState: State,
        output: WalletContextOutput,
        errorLogger: WalletContextErrorLogger,
        log: @escaping (String) -> Void
    ) {
        let storage = WalletEngineStorage(namespace: storageNamespace)
        self.engine = engine
        self.errorLogger = errorLogger
        self.storage = storage
        self.output = output
        self.runtime = WalletEngineRuntime(engine: engine, storage: storage, errorLogger: errorLogger)
        self.storedStateWriter = WalletStoredStateWriter(engine: engine)
        let streamingLog = WalletStreamingLogger(log)
        self.streamingLog = streamingLog
        let streamingURLProvider = WalletStreamingURLProvider(engine: engine, log: streamingLog)
        self.streamingTransportFactory = WalletURLSessionStreamingTransportFactory(provider: streamingURLProvider, log: streamingLog)
        self.currentState = initialState
    }

    func shutdown() async {
        guard !self.isShutdown else { return }
        self.isShutdown = true
        self.activationGeneration &+= 1
        if let activeOperationId = self.activeOperationId {
            self.output.cancelOperation(id: activeOperationId)
            self.activeOperationId = nil
        }
        self.stateSubscriberCount = 0
        self.walletScreenCount = 0
        self.fiatRatesDisposable.dispose()
        self.serverStateTask?.cancel()
        self.activationTask?.cancel()
        self.synchronizationTask?.cancel()
        self.observationTask?.cancel()
        self.serverStateRetryTask?.cancel()
        self.pollingTask?.cancel()
        self.walletStateFallbackRefreshTask?.cancel()
        self.fiatRefreshTask?.cancel()
        self.streamingTask?.cancel()
        self.streamingRefreshTask?.cancel()
        await self.streamingClient?.stop()
        await self.tonConnectCoordinator?.shutdown()
        await self.storedStateWriter.shutdown()
        await self.runtime.shutdown()
    }

    func updateEnvironment(
        foreground: Bool,
        accountIsCurrent: Bool,
        networkAvailable: Bool,
        revision: UInt64
    ) {
        guard !self.isShutdown else { return }
        guard revision > self.latestEnvironmentRevision else { return }
        let wasPollingEligible = self.isPollingEligible
        self.latestEnvironmentRevision = revision
        self.isApplicationInForeground = foreground
        self.isAccountCurrent = accountIsCurrent
        self.isNetworkAvailable = networkAvailable
        self.evaluateRuntimeDemand(refreshIfPollingBecomesActive: !wasPollingEligible)
    }

    func receiveServerWalletState(_ value: TelegramCore.WalletState, revision: UInt64) {
        guard !self.isShutdown else { return }
        guard revision > self.latestWalletStateRevision else { return }
        self.latestWalletStateRevision = revision
        guard self.isStoredStateRestored else {
            self.pendingInitialServerWalletState = (value, true)
            return
        }
        self.applyServerWalletState(value, refreshIfStreamingUnavailable: true)
    }

    func updateStateSubscriberDemand(count: Int, revision: UInt64) {
        guard !self.isShutdown else { return }
        guard revision > self.latestSubscriberDemandRevision else { return }
        self.latestSubscriberDemandRevision = revision
        self.stateSubscriberCount = max(0, count)
        self.evaluateRuntimeDemand()
    }

    func updateWalletScreenDemand(count: Int, revision: UInt64, refreshOnOpen: Bool) {
        guard !self.isShutdown else { return }
        guard revision > self.latestWalletScreenDemandRevision else { return }
        self.latestWalletScreenDemandRevision = revision
        self.walletScreenCount = max(0, count)
        self.evaluateRuntimeDemand()
        if refreshOnOpen, self.walletScreenCount > 0 {
            self.requestServerWalletState(forceRefreshAfterCurrent: self.serverWalletState != nil)
            self.requestSynchronization(scope: .all, force: true)
        }
    }

    func restoreStoredState(_ storedState: WalletStoredState?, removeInvalidEntry: Bool) async {
        guard !self.isShutdown else { return }
        if removeInvalidEntry {
            self.errorLogger.log("event=wallet_stored_state_invalid")
            self.storedStateMutationRevision &+= 1
            await self.storedStateWriter.remove(revision: self.storedStateMutationRevision)
        }
        guard let storedState else {
            self.completeStoredStateRestore()
            return
        }
        let cachedTransactions: [Transaction]
        do {
            cachedTransactions = try await walletTransactions(
                from: storedState.transactions,
                engine: self.engine
            )
        } catch is CancellationError {
            return
        } catch {
            self.errorLogger.error("wallet_stored_state_peer_restore_failed", error)
            cachedTransactions = storedState.transactions.map { $0.transaction(peers: [:]) }
        }
        guard !Task.isCancelled, !self.isShutdown else {
            return
        }
        self.storedState = storedState
        self.balanceLastSuccessfulAt = storedState.balanceUpdatedAt
        self.fiatLastSuccessfulAt = storedState.fiatRatesUpdatedAt
        guard case .restoring = self.currentState.phase else {
            self.completeStoredStateRestore()
            return
        }
        self.replaceState(
            phase: .restoring,
            balance: storedState.balance.map { .value($0, updatedAt: storedState.balanceUpdatedAt ?? 0) } ?? .idle,
            transactions: TransactionsState(
                items: Array(cachedTransactions.prefix(walletStoredStateCachedItemLimit)),
                offset: cachedTransactions.count,
                canLoadMore: false,
                isLoadingMore: false,
                error: nil
            ),
            collectibles: CollectiblesState(
                items: Array(storedState.collectibles.prefix(walletStoredStateCachedItemLimit)),
                offset: storedState.collectibles.count,
                canLoadMore: false,
                isLoadingMore: false,
                error: nil
            ),
            pendingTransfers: storedState.pendingTransfers,
            activeOperation: nil,
            fiat: FiatState(
                selectedCurrency: storedState.selectedFiatCurrency,
                rates: storedState.fiatRates.map { .value($0, updatedAt: storedState.fiatRatesUpdatedAt ?? 0) } ?? .idle
            )
        )
        self.completeStoredStateRestore()
    }

    private func completeStoredStateRestore() {
        self.isStoredStateRestored = true
        if let pendingInitialServerWalletState = self.pendingInitialServerWalletState {
            self.pendingInitialServerWalletState = nil
            self.applyServerWalletState(
                pendingInitialServerWalletState.state,
                refreshIfStreamingUnavailable: pendingInitialServerWalletState.refreshIfStreamingUnavailable
            )
        }
        self.evaluateRuntimeDemand(refreshIfPollingBecomesActive: true)
    }

    func evaluateRuntimeDemand(refreshIfPollingBecomesActive: Bool = false) {
        self.evaluateStreamingDemand()
        self.evaluatePollingDemand(refreshIfBecomingActive: refreshIfPollingBecomesActive)
        guard self.canUseNetworkRuntime else {
            self.cancelSynchronization()
            self.serverStateRetryTask?.cancel()
            self.serverStateRetryTask = nil
            self.cancelWalletStateFallbackRefresh()
            return
        }
        if self.serverWalletState == nil {
            self.requestServerWalletState()
        }
        if self.stateSubscriberCount > 0 {
            self.requestFiatRates()
        }
    }

    var canUseNetworkRuntime: Bool {
        !self.isShutdown
            && self.isStoredStateRestored
            && self.isApplicationInForeground
            && self.isAccountCurrent
            && self.isNetworkAvailable
    }

    func requestServerWalletState(forceRefreshAfterCurrent: Bool = false) {
        guard self.canUseNetworkRuntime else { return }
        if self.serverStateTask != nil {
            if forceRefreshAfterCurrent {
                self.serverStateRefreshRequested = true
            }
            return
        }
        self.serverStateTask = Task { [weak self] in
            await self?.performServerWalletStateRequest()
        }
    }

    private func performServerWalletStateRequest() async {
        defer {
            self.serverStateTask = nil
            if self.serverStateRefreshRequested {
                self.serverStateRefreshRequested = false
                self.requestServerWalletState()
            }
        }
        do {
            let value = try await WalletSignalRequestContext<TelegramCore.WalletState>().run(
                self.engine.wallet.getState()
            )
            try Task.checkCancellation()
            var promotedReplacement = false
            let isMutatingReplacementCandidate = self.preparedRecoveryPhraseImportRecordId != nil
                || self.currentState.activeOperation?.defersServerWalletState == true
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
            self.serverStateRetryTask?.cancel()
            self.serverStateRetryTask = nil
            self.applyServerWalletState(value, forceActivation: promotedReplacement)
        } catch is CancellationError {
        } catch {
            self.errorLogger.error("wallet_state_failed", error)
            if self.serverWalletState == nil {
                self.scheduleServerStateRetry()
            }
        }
    }

    func applyServerWalletState(
        _ value: TelegramCore.WalletState,
        forceActivation: Bool = false,
        refreshIfStreamingUnavailable: Bool = false
    ) {
        if self.currentState.activeOperation?.defersServerWalletState == true {
            let shouldRefreshIfStreamingUnavailable = refreshIfStreamingUnavailable
                || (self.deferredServerWalletState?.refreshIfStreamingUnavailable ?? false)
            self.deferredServerWalletState = (value, shouldRefreshIfStreamingUnavailable)
            return
        }
        self.deferredServerWalletState = nil
        self.serverStateRetryTask?.cancel()
        self.serverStateRetryTask = nil
        self.serverWalletState = value
        if case let .ready(backupEnabled, _, _, address, publicKey, _) = value, !backupEnabled {
            self.completeAppliedKeyRotationIfBackupDisabled(address: address, publicKey: publicKey)
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
                    canSign: currentInfo.canSign
                )),
                balance: self.currentState.balance,
                transactions: self.currentState.transactions,
                pendingTransfers: self.currentState.pendingTransfers,
                activeOperation: self.currentState.activeOperation
            )
            if refreshIfStreamingUnavailable {
                self.scheduleWalletStateFallbackRefreshIfNeeded()
            }
            return
        }
        _ = self.streamingPresentationOverlay.removeAll()
        self.outgoingTransactionPresentationIdentities.removeAll()
        self.activationGeneration &+= 1
        self.stopStreaming()
        self.cancelWalletStateFallbackRefresh()
        if let activeOperationId = self.activeOperationId {
            self.output.cancelOperation(id: activeOperationId)
            self.activeOperationId = nil
        }
        self.preparedTransfers.removeAll()
        self.deferredSynchronizationScope = []
        let generation = self.activationGeneration
        self.activationTask?.cancel()
        self.activationTask = nil

        switch value {
        case let .empty(creating):
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
                phase: creating ? .creating : .empty,
                balance: .idle,
                transactions: TransactionsState(items: [], offset: 0, canLoadMore: false, isLoadingMore: false, error: nil),
                collectibles: .empty,
                pendingTransfers: [],
                activeOperation: nil
            )
        case let .ready(backupEnabled, canExportPhrase, canEnableBackup, address, publicKey, _):
            let isSameCachedIdentity = self.storedState.walletAddress.map {
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
            self.activationTask = Task { [weak self] in
                await self?.activateWallet(
                    backupEnabled: backupEnabled,
                    canExportPhrase: canExportPhrase,
                    canEnableBackup: canEnableBackup,
                    address: address,
                    publicKey: publicKey,
                    previousCoordinator: previousCoordinator,
                    generation: generation
                )
            }
        }
    }

    private func activateWallet(
        backupEnabled: Bool,
        canExportPhrase: Bool,
        canEnableBackup: Bool,
        address: String,
        publicKey: Data,
        previousCoordinator: WalletTonConnectCoordinator?,
        generation: UInt64
    ) async {
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
                do {
                    words = try await exportWalletSecretPhrase(
                        engine: self.engine,
                        password: nil,
                        expectedPublicKey: publicKey
                    )
                } catch {
                    self.errorLogger.error("wallet_automatic_phrase_export_failed", error)
                }
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
                        await self.discardReplacementForCleanup(recordId: prepared.recordId)
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
                    self.errorLogger.error("wallet_automatic_phrase_install_failed", error)
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
                    errorLogger: self.errorLogger,
                    recordId: activation.snapshot.recordId,
                    event: { [weak self] event in
                        await self?.handleTonConnectEvent(event)
                    }
                )
                self.tonConnectCoordinator = coordinator
                Task { await coordinator.restore() }
            }
            self.requestSynchronization()
        } catch is CancellationError {
        } catch let error as WalletEngineStorageError {
            guard !self.isShutdown, self.activationGeneration == generation else { return }
            self.errorLogger.error("wallet_engine_activation_failed", error)
            self.replaceState(
                phase: .failed(Self.storageError(error)),
                balance: self.currentState.balance,
                transactions: self.currentState.transactions,
                pendingTransfers: [],
                activeOperation: nil
            )
        } catch {
            guard !self.isShutdown, self.activationGeneration == generation else { return }
            self.errorLogger.error("wallet_engine_activation_failed", error)
            self.replaceState(
                phase: .failed(.unsupportedVersion),
                balance: .idle,
                transactions: self.currentState.transactions,
                pendingTransfers: [],
                activeOperation: nil
            )
        }
    }

    func applyCompatibleDeferredServerWalletState() {
        guard let deferred = self.deferredServerWalletState else { return }
        let value = deferred.state

        let isCompatible: Bool
        switch (self.currentState.phase, value) {
        case let (.wallet(info), .ready(_, _, _, address, publicKey, _)):
            isCompatible = walletEngineAddressesEqual(info.address, address)
                && info.publicKey == publicKey.map { String(format: "%02x", $0) }.joined()
        case (.empty, .empty), (.creating, .empty):
            isCompatible = true
        case (.restoring, _), (.failed, _), (.empty, .ready), (.creating, .ready),
             (.wallet, .empty):
            isCompatible = false
        }
        guard isCompatible else { return }
        self.applyServerWalletState(
            value,
            refreshIfStreamingUnavailable: deferred.refreshIfStreamingUnavailable
        )
    }

    func beginObserving(snapshot: WalletSnapshot, generation: UInt64) {
        self.observationTask?.cancel()
        self.applyEngineSnapshot(snapshot)
        self.observationTask = Task { [weak self] in
            await self?.observeWallet(snapshot: snapshot, generation: generation)
        }
    }

    private func observeWallet(snapshot: WalletSnapshot, generation: UInt64) async {
        var revision = snapshot.revision
        while !Task.isCancelled, !self.isShutdown, self.activationGeneration == generation {
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
                self.errorLogger.error("wallet_engine_observation_failed", error)
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    func applyEngineSnapshot(_ snapshot: WalletSnapshot) {
        let balance: Resource<Int64>
        if let account = snapshot.account, let value = walletEngineBalance(account.balanceNanograms) {
            let timestamp = currentWalletTimestamp()
            self.balanceLastSuccessfulAt = timestamp
            balance = .value(value, updatedAt: timestamp)
        } else {
            switch snapshot.accountResource.phase {
            case .idle: balance = self.currentState.balance
            case .loading: balance = .loading(previous: self.currentState.balance.currentValue)
            case .ready:
                self.errorLogger.log("event=wallet_engine_balance_invalid")
                balance = .stale(previous: self.currentState.balance.currentValue, error: .invalidData, lastSuccessfulAt: self.balanceLastSuccessfulAt)
            case .failed:
                self.errorLogger.log("event=wallet_engine_account_resource_failed has_diagnostic=\(snapshot.accountResource.error == nil ? 0 : 1)")
                balance = .stale(previous: self.currentState.balance.currentValue, error: synchronizationError(snapshot.accountResource.error), lastSuccessfulAt: self.balanceLastSuccessfulAt)
            }
        }
        self.reconcileKeyRotation(snapshot.send)
        let reconciledPending = self.reconcilePendingTransfers(snapshot.send)
        let historyReconciliation = self.pendingTransfers(
            reconciledPending,
            reconcilingWith: self.currentState.transactions.items
        )
        let removedStreamingTraceCount = self.streamingPresentationOverlay.clearTransactions(
            through: self.streamingPresentationOverlay.revision,
            presentIn: self.currentState.transactions.items,
            resolvedTraceIds: historyReconciliation.resolvedStreamingTraceIds
        )
        self.logPendingTransferHistoryReconciliation(
            historyReconciliation,
            removedStreamingTraceCount: removedStreamingTraceCount
        )
        let previousState = self.currentState
        self.replaceState(
            phase: self.currentState.phase,
            balance: balance,
            transactions: self.currentState.transactions,
            pendingTransfers: historyReconciliation.pendingTransfers,
            activeOperation: self.currentState.activeOperation
        )
        if removedStreamingTraceCount != 0 && self.currentState == previousState {
            self.publishPresentationState()
        }
    }

    func requestSynchronization(
        scope requestedScope: WalletSynchronizationScope = .all,
        force: Bool = false
    ) {
        self.removeExpiredPreparedTransfers()
        var scope = requestedScope
        scope.formUnion(self.deferredSynchronizationScope)
        let effectiveForce = force || !self.deferredSynchronizationScope.isEmpty
        guard self.canUseNetworkRuntime,
              !scope.isEmpty,
              (effectiveForce || self.walletScreenCount > 0 || !self.currentState.pendingTransfers.isEmpty),
              case .wallet = self.currentState.phase else { return }
        if self.isTransferFlowBlockingSynchronization {
            self.deferredSynchronizationScope.formUnion(scope)
            return
        }
        self.deferredSynchronizationScope = []
        guard let scope = self.synchronizationGate.beginOrQueue(scope) else {
            return
        }
        let taskId = UUID()
        self.synchronizationTaskId = taskId
        self.synchronizationTask = Task { [weak self] in
            await self?.performSynchronization(taskId: taskId, scope: scope)
        }
    }

    private func performSynchronization(
        taskId: UUID,
        scope: WalletSynchronizationScope
    ) async {
        let streamingOverlayWatermark = self.streamingPresentationOverlay.revision
        defer {
            if self.synchronizationTaskId == taskId {
                self.synchronizationTask = nil
                self.synchronizationTaskId = nil
                let queuedScope = self.synchronizationGate.complete()
                if !queuedScope.isEmpty {
                    self.requestSynchronization(scope: queuedScope, force: true)
                }
            }
        }

        let runtime = self.runtime
        let engine = self.engine
        async let engineResult = scope.contains(.account)
            ? captureAsync { try await runtime.refresh() }
            : nil
        async let nftResult = scope.contains(.nfts)
            ? captureAsync { try await runtime.refreshNfts() }
            : nil
        async let transactionResult = scope.contains(.transactions)
            ? captureAsync {
                try await WalletSignalRequestContext<TelegramCore.WalletTransactions>().run(
                    engine.wallet.getTransactions(
                        inbound: true,
                        outbound: true,
                        offset: "",
                        limit: Int32(walletTransactionFetchLimit)
                    )
                )
            }
            : nil
        let (engineResultValue, nfts, transactions) = await (engineResult, nftResult, transactionResult)
        guard !Task.isCancelled, !self.isShutdown else { return }

        var balance = self.currentState.balance
        var transactionState = self.currentState.transactions
        var collectiblesState = self.currentState.collectibles
        var snapshot: WalletSnapshot?
        var engineBalanceRefreshApplied = false
        var refreshedTransactions: [Transaction]?

        if let engineResultValue {
            switch engineResultValue {
            case let .success(update):
                snapshot = newestWalletSnapshot(snapshot, update.snapshot)
                if let account = update.snapshot.account, let value = walletEngineBalance(account.balanceNanograms) {
                    engineBalanceRefreshApplied = true
                    let timestamp = currentWalletTimestamp()
                    self.balanceLastSuccessfulAt = timestamp
                    balance = .value(value, updatedAt: timestamp)
                } else {
                    balance = .stale(previous: balance.currentValue, error: .invalidData, lastSuccessfulAt: self.balanceLastSuccessfulAt)
                }
            case let .failure(error):
                self.errorLogger.error("wallet_engine_refresh_failed", error)
                let mappedError = synchronizationError(error)
                balance = .stale(previous: balance.currentValue, error: mappedError, lastSuccessfulAt: self.balanceLastSuccessfulAt)
            }
        }

        if let transactions {
            switch transactions {
            case let .success(response):
                let values = walletTransactions(from: response.items)
                refreshedTransactions = values
                self.serverTransactionsNextOffset = response.nextOffset
                transactionState = TransactionsState(
                    items: values,
                    offset: values.count,
                    canLoadMore: response.nextOffset != nil,
                    isLoadingMore: false,
                    error: nil
                )
            case let .failure(error):
                self.errorLogger.error("wallet_transactions_refresh_failed", error)
                let mappedError = synchronizationError(error)
                transactionState = TransactionsState(
                    items: transactionState.items,
                    offset: transactionState.offset,
                    canLoadMore: transactionState.canLoadMore,
                    isLoadingMore: false,
                    error: mappedError
                )
            }
        }

        if let nfts {
            switch nfts {
            case let .success(update):
                snapshot = newestWalletSnapshot(snapshot, update.snapshot)
                let values = await walletCollectibles(
                    from: update.snapshot.nfts.items,
                    errorLogger: self.errorLogger
                )
                collectiblesState = CollectiblesState(
                    items: values,
                    offset: values.count,
                    canLoadMore: update.snapshot.nfts.hasMore,
                    isLoadingMore: false,
                    error: nil
                )
            case let .failure(error):
                self.errorLogger.error("wallet_nfts_refresh_failed", error)
                let mappedError = synchronizationError(error)
                collectiblesState = CollectiblesState(
                    items: collectiblesState.items,
                    offset: collectiblesState.offset,
                    canLoadMore: collectiblesState.canLoadMore,
                    isLoadingMore: false,
                    error: mappedError
                )
            }
        }
        var pending: [PendingTransfer]
        if let snapshot {
            pending = self.reconcilePendingTransfers(snapshot.send)
        } else {
            pending = self.currentState.pendingTransfers
        }
        var streamingOverlayChanged = false
        if engineBalanceRefreshApplied {
            streamingOverlayChanged = self.streamingPresentationOverlay.clearBalance(
                through: streamingOverlayWatermark
            ) || streamingOverlayChanged
        }
        if let refreshedTransactions {
            let historyReconciliation = self.pendingTransfers(
                pending,
                reconcilingWith: refreshedTransactions
            )
            pending = historyReconciliation.pendingTransfers
            let removedStreamingTraceCount = self.streamingPresentationOverlay.clearTransactions(
                through: streamingOverlayWatermark,
                presentIn: refreshedTransactions,
                resolvedTraceIds: historyReconciliation.resolvedStreamingTraceIds
            )
            streamingOverlayChanged = removedStreamingTraceCount != 0 || streamingOverlayChanged
            self.logPendingTransferHistoryReconciliation(
                historyReconciliation,
                removedStreamingTraceCount: removedStreamingTraceCount
            )
        }
        let previousState = self.currentState
        self.replaceState(
            phase: self.currentState.phase,
            balance: balance,
            transactions: transactionState,
            collectibles: collectiblesState,
            pendingTransfers: pending,
            activeOperation: self.currentState.activeOperation
        )
        if streamingOverlayChanged && self.currentState == previousState {
            self.publishPresentationState()
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
            let status: PendingTransfer.Status
            switch send.phase {
            case .submissionUnknown:
                status = .submissionUnknown
            case .confirmed:
                status = .confirmed
            case .submitted:
                status = .pending
            default:
                preconditionFailure()
            }
            let updated = PendingTransfer(
                id: current.id,
                recipient: current.recipient,
                amount: current.amount,
                comment: current.comment,
                collectibleAddress: current.collectibleAddress,
                normalizedHash: current.normalizedHash,
                fee: current.fee,
                transactionHash: send.phase == .confirmed
                    ? (send.resolution?.transactionHash ?? current.transactionHash)
                    : current.transactionHash,
                transactionLt: send.phase == .confirmed
                    ? (send.resolution?.transactionLt ?? current.transactionLt)
                    : current.transactionLt,
                createdAt: current.createdAt,
                status: status
            )
            values[index] = updated
            if send.phase == .confirmed, updated != current {
                self.requestSynchronization(force: true)
            }
        case .replaced, .sequenceNumberConsumed, .expired, .superseded, .failed, .cancelled:
            self.errorLogger.log("event=wallet_pending_transfer_terminal_failure phase=\(send.phase)")
            values.remove(at: index)
            self.requestSynchronization(force: true)
        case .idle, .validating, .authorizing, .preparing, .persisting, .readyToSubmit, .submitting, .handedOff:
            break
        }
        return values
    }

    func pendingTransfers(
        _ pendingTransfers: [PendingTransfer],
        reconcilingWith transactions: [Transaction]
    ) -> PendingTransferHistoryReconciliation {
        self.rememberOutgoingTransactionPresentationIdentities(pendingTransfers)
        let authoritativeHashes = Set(transactions.compactMap(\.transactionHash))
        guard !authoritativeHashes.isEmpty else {
            return PendingTransferHistoryReconciliation(
                pendingTransfers: pendingTransfers,
                resolvedStreamingTraceIds: [],
                removedPendingCount: 0
            )
        }
        var remaining: [PendingTransfer] = []
        remaining.reserveCapacity(pendingTransfers.count)
        var resolvedStreamingTraceIds = Set<String>()
        for pending in pendingTransfers {
            if let transactionHash = pending.transactionHash,
               authoritativeHashes.contains(transactionHash) {
                if let normalizedHash = pending.normalizedHash {
                    resolvedStreamingTraceIds.insert(normalizedHash)
                }
                continue
            }
            guard let normalizedHash = pending.normalizedHash,
                  let streamingHashes = self.streamingPresentationOverlay.transactionHashes(
                    forTraceId: normalizedHash
                  ) else {
                remaining.append(pending)
                continue
            }
            if streamingHashes.allSatisfy(authoritativeHashes.contains) {
                resolvedStreamingTraceIds.insert(normalizedHash)
            } else {
                remaining.append(pending)
            }
        }
        return PendingTransferHistoryReconciliation(
            pendingTransfers: remaining,
            resolvedStreamingTraceIds: resolvedStreamingTraceIds,
            removedPendingCount: pendingTransfers.count - remaining.count
        )
    }

    func logPendingTransferHistoryReconciliation(
        _ reconciliation: PendingTransferHistoryReconciliation,
        removedStreamingTraceCount: Int
    ) {
        guard reconciliation.removedPendingCount != 0 || removedStreamingTraceCount != 0 else {
            return
        }
        self.errorLogger.log(
            "event=wallet_pending_history_reconciled pending_removed=\(reconciliation.removedPendingCount) trace_removed=\(removedStreamingTraceCount)"
        )
    }

    func reconcileKeyRotation(_ send: SendSnapshot) {
        switch send.phase {
        case .confirmed, .replaced, .sequenceNumberConsumed, .expired, .superseded, .failed, .cancelled:
            let generation = self.activationGeneration
            Task { [weak self] in
                await self?.performKeyRotationReconciliation(send: send, generation: generation)
            }
        case .idle, .validating, .authorizing, .preparing, .persisting, .readyToSubmit,
             .submitting, .submissionUnknown, .submitted, .handedOff:
            break
        }
    }

    private func performKeyRotationReconciliation(send: SendSnapshot, generation: UInt64) async {
        guard !self.isShutdown else { return }
        do {
            let result = try await self.runtime.reconcileKeyRotation(send: send)
            guard self.activationGeneration == generation else { return }
            switch result {
            case let .confirmed(operationId):
                if case let .wallet(info) = self.currentState.phase, !info.backupEnabled {
                    do {
                        try await self.runtime.completeKeyRotationAfterBackupDisabled(operationId: operationId)
                    } catch {
                        self.errorLogger.error("wallet_key_rotation_completion_failed", error)
                    }
                }
                self.requestSynchronization(force: true)
            case .rolledBack:
                self.requestSynchronization(force: true)
            case .none, .pending:
                break
            }
        } catch {
            self.errorLogger.error("wallet_key_rotation_reconciliation_failed", error)
        }
    }

    func completeAppliedKeyRotationIfBackupDisabled(address: String, publicKey: Data) {
        Task { [runtime = self.runtime, errorLogger = self.errorLogger] in
            do {
                guard let record = try await runtime.keyRotationRecord(),
                      (record.phase == .chainApplied || record.phase == .backupDisabled),
                      walletEngineAddressesEqual(record.walletAddress, address),
                      record.walletPublicKey == publicKey else {
                    return
                }
                try await runtime.completeKeyRotationAfterBackupDisabled(operationId: record.operationId)
            } catch {
                errorLogger.error("wallet_applied_key_rotation_cleanup_failed", error)
            }
        }
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
        let presentationIdentitiesChanged = self.rememberOutgoingTransactionPresentationIdentities(
            pendingTransfers
        )
        let value = State(
            phase: phase,
            balance: balance,
            transactions: transactions,
            collectibles: collectibles ?? self.currentState.collectibles,
            pendingTransfers: pendingTransfers,
            activeOperation: activeOperation,
            fiat: fiat ?? self.currentState.fiat
        )
        let peerMappingsChanged = self.rememberWalletPeers(in: value.transactions.items)
        let presentationIdentitiesPruned = self.pruneOutgoingTransactionPresentationIdentities(
            state: value
        )
        guard value != self.currentState else {
            if peerMappingsChanged || presentationIdentitiesChanged || presentationIdentitiesPruned {
                self.publishPresentationState()
            }
            return
        }
        self.currentState = value
        self.publishPresentationState()
        self.persistStoredState(value)
        self.evaluateStreamingDemand()
        self.evaluatePollingDemand()
    }

    func publishPresentationState() {
        _ = self.pruneOutgoingTransactionPresentationIdentities(state: self.currentState)
        let presentationIds = self.outgoingTransactionPresentationIds()
        self.output.publish(state: self.streamingPresentationOverlay.applying(
            to: self.currentState,
            peerByAddress: self.peerByWalletAddress,
            presentationIdByTraceId: presentationIds.byTraceId,
            presentationIdByTransactionHash: presentationIds.byTransactionHash
        ))
    }

    @discardableResult
    private func rememberOutgoingTransactionPresentationIdentities(
        _ pendingTransfers: [PendingTransfer]
    ) -> Bool {
        var changed = false
        for pending in pendingTransfers where pending.collectibleAddress == nil && pending.amount > 0 {
            let current = self.outgoingTransactionPresentationIdentities[pending.id]
            let updated = OutgoingTransactionPresentationIdentity(
                presentationId: current?.presentationId ?? "pending:\(pending.id)",
                normalizedHash: pending.normalizedHash ?? current?.normalizedHash,
                transactionHash: pending.transactionHash ?? current?.transactionHash
            )
            if current?.presentationId != updated.presentationId
                || current?.normalizedHash != updated.normalizedHash
                || current?.transactionHash != updated.transactionHash {
                self.outgoingTransactionPresentationIdentities[pending.id] = updated
                changed = true
            }
        }
        return changed
    }

    @discardableResult
    private func pruneOutgoingTransactionPresentationIdentities(state: State) -> Bool {
        let pendingOperationIds = Set(state.pendingTransfers.map(\.id))
        let authoritativeTransactionHashes = Set(state.transactions.items.compactMap(\.transactionHash))
        let previousCount = self.outgoingTransactionPresentationIdentities.count
        self.outgoingTransactionPresentationIdentities = self.outgoingTransactionPresentationIdentities.filter { operationId, identity in
            if pendingOperationIds.contains(operationId) {
                return true
            }
            if let normalizedHash = identity.normalizedHash,
               self.streamingPresentationOverlay.containsTrace(normalizedHash) {
                return true
            }
            if let transactionHash = identity.transactionHash,
               authoritativeTransactionHashes.contains(transactionHash) {
                return true
            }
            return false
        }
        return self.outgoingTransactionPresentationIdentities.count != previousCount
    }

    private func outgoingTransactionPresentationIds() -> (
        byTraceId: [String: String],
        byTransactionHash: [String: String]
    ) {
        var byTraceId: [String: String] = [:]
        var byTransactionHash: [String: String] = [:]
        for identity in self.outgoingTransactionPresentationIdentities.values {
            if let normalizedHash = identity.normalizedHash {
                byTraceId[normalizedHash] = identity.presentationId
            }
            if let transactionHash = identity.transactionHash {
                byTransactionHash[transactionHash] = identity.presentationId
            }
        }
        return (byTraceId, byTransactionHash)
    }

    func rememberWalletPeer(_ mapping: WalletPeerAddressMapping) {
        guard let key = walletAddressMappingKey(mapping.address) else {
            return
        }
        let changed = self.peerByWalletAddress[key] != mapping.peer
        self.peerByWalletAddress[key] = mapping.peer
        if changed {
            self.publishPresentationState()
        }
    }

    private func rememberWalletPeers(in transactions: [Transaction]) -> Bool {
        var changed = false
        for transaction in transactions {
            guard case let .user(peer, address, _) = transaction.peer,
                  let key = walletAddressMappingKey(address) else {
                continue
            }
            if self.peerByWalletAddress[key] != peer {
                self.peerByWalletAddress[key] = peer
                changed = true
            }
        }
        return changed
    }

    @discardableResult
    func clearStreamingPresentationOverlay() -> Bool {
        guard self.streamingPresentationOverlay.removeAll() else {
            return false
        }
        self.publishPresentationState()
        return true
    }

    private func persistStoredState(_ state: State) {
        var storedState = WalletStoredState()
        storedState.walletAddress = {
            if case let .wallet(info) = state.phase { return info.address }
            return self.storedState.walletAddress
        }()
        storedState.pendingTransfers = state.pendingTransfers
        storedState.balance = state.balance.currentValue
        storedState.balanceUpdatedAt = state.balance.lastSuccessfulAt ?? self.balanceLastSuccessfulAt
        storedState.fiatRates = state.fiat.rates.currentValue
        storedState.fiatRatesUpdatedAt = state.fiat.rates.lastSuccessfulAt ?? self.fiatLastSuccessfulAt
        storedState.selectedFiatCurrency = state.fiat.selectedCurrency
        storedState.transactions = state.transactions.items
            .prefix(walletStoredStateCachedItemLimit)
            .map(WalletStoredTransaction.init)
        storedState.collectibles = Array(state.collectibles.items.prefix(walletStoredStateCachedItemLimit))
        guard storedState != self.storedState else {
            return
        }
        self.storedState = storedState
        self.storedStateMutationRevision &+= 1
        let revision = self.storedStateMutationRevision
        let storedStateWriter = self.storedStateWriter
        Task {
            await storedStateWriter.enqueue(storedState, revision: revision)
        }
    }

    func scheduleServerStateRetry() {
        guard self.serverStateRetryTask == nil,
              self.canUseNetworkRuntime,
              self.serverWalletState == nil else {
            return
        }
        self.serverStateRetryTask = Task { [weak self] in
            await self?.performServerStateRetryDelay()
        }
    }

    private func performServerStateRetryDelay() async {
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        guard !Task.isCancelled,
              !self.isShutdown,
              self.serverWalletState == nil else {
            return
        }
        self.serverStateRetryTask = nil
        self.requestServerWalletState()
    }

    var hasActiveWalletRefreshDemand: Bool {
        self.walletScreenCount > 0 || !self.currentState.pendingTransfers.isEmpty
    }

    var isPollingEligible: Bool {
        guard self.canUseNetworkRuntime,
              self.hasActiveWalletRefreshDemand,
              case .wallet = self.currentState.phase else {
            return false
        }
        return true
    }

    func evaluatePollingDemand(refreshIfBecomingActive: Bool = false) {
        guard self.isPollingEligible else {
            self.pollingTask?.cancel()
            self.pollingTask = nil
            self.pollingTaskId = nil
            if !self.hasActiveWalletRefreshDemand || !self.canUseNetworkRuntime {
                self.cancelWalletStateFallbackRefresh()
            }
            return
        }
        let wasRunning = self.pollingTask != nil
        if !wasRunning {
            let taskId = UUID()
            self.pollingTaskId = taskId
            self.pollingTask = Task { [weak self] in
                await self?.runPolling(taskId: taskId)
            }
        }
        if refreshIfBecomingActive && !wasRunning {
            self.requestSynchronization(scope: .all, force: true)
        }
    }

    private func runPolling(taskId: UUID) async {
        defer {
            if self.pollingTaskId == taskId {
                self.pollingTask = nil
                self.pollingTaskId = nil
            }
        }
        while !Task.isCancelled,
              !self.isShutdown,
              self.pollingTaskId == taskId,
              self.isPollingEligible {
            let jitter = Double.random(in: 0.0 ... 0.2)
            let interval = 60.0 * (1.0 + jitter)
            do {
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000.0))
            } catch {
                return
            }
            guard !Task.isCancelled,
                  !self.isShutdown,
                  self.pollingTaskId == taskId,
                  self.isPollingEligible else {
                return
            }
            self.errorLogger.log("event=wallet_polling_refresh_requested")
            self.requestSynchronization(scope: .all, force: true)
        }
    }

    func scheduleWalletStateFallbackRefreshIfNeeded() {
        guard self.canUseNetworkRuntime,
              self.hasActiveWalletRefreshDemand,
              self.streamingConnectionState != .subscribed,
              case .wallet = self.currentState.phase,
              self.walletStateFallbackRefreshTask == nil else {
            return
        }
        let taskId = UUID()
        self.errorLogger.log("event=wallet_state_fallback_refresh_scheduled")
        self.walletStateFallbackRefreshTaskId = taskId
        self.walletStateFallbackRefreshTask = Task { [weak self] in
            await self?.runWalletStateFallbackRefreshDelay(taskId: taskId)
        }
    }

    private func runWalletStateFallbackRefreshDelay(taskId: UUID) async {
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000)
        } catch {
            return
        }
        guard !self.isShutdown,
              self.walletStateFallbackRefreshTaskId == taskId else {
            return
        }
        self.walletStateFallbackRefreshTask = nil
        self.walletStateFallbackRefreshTaskId = nil
        guard self.canUseNetworkRuntime,
              self.hasActiveWalletRefreshDemand,
              self.streamingConnectionState != .subscribed,
              case .wallet = self.currentState.phase else {
            return
        }
        self.errorLogger.log("event=wallet_state_fallback_refresh_requested")
        self.requestSynchronization(scope: [.account, .transactions], force: true)
    }

    func cancelWalletStateFallbackRefresh() {
        self.walletStateFallbackRefreshTask?.cancel()
        self.walletStateFallbackRefreshTask = nil
        self.walletStateFallbackRefreshTaskId = nil
    }

    func handleTonConnectEvent(_ event: WalletTonConnectEvent) {
        switch event {
        case let .connect(value): self.output.publish(presentation: .request(value))
        case let .operation(value): self.output.publish(presentation: .operation(value))
        case let .dismiss(id): self.output.publish(presentation: .dismiss(requestId: id))
        case let .error(value): self.output.publish(presentation: .error(value))
        }
    }

    static func storageError(_ error: WalletEngineStorageError) -> FatalStorageError {
        switch error {
        case let .keychainStatus(status): return .keychainStatus(status)
        case .corrupted: return .corrupted
        }
    }
}

private func newestWalletSnapshot(_ current: WalletSnapshot?, _ candidate: WalletSnapshot) -> WalletSnapshot {
    guard let current, current.revision >= candidate.revision else {
        return candidate
    }
    return current
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
