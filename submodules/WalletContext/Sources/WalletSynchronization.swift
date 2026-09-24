import Foundation
import TelegramCore
import WalletEngineFFI

@available(macOS 10.15, *)
extension WalletContextImpl {
    var activeSynchronizationScope: WalletSynchronizationScope {
        self.synchronizationGate.pendingScope.union(self.collectiblesSynchronizationGate.pendingScope)
    }

    func requestSynchronization(scope: WalletSynchronizationScope, force: Bool = false) {
        guard !self.isShutdown else { return }
        self.removeExpiredPreparedTransfers()
        if force {
            self.deferredSynchronizationScope.formUnion(scope)
        }
        guard self.canUseNetworkRuntime, case .wallet = self.currentState.phase else { return }
        guard force || self.hasActiveWalletRefreshDemand
            || !self.pendingScreenSynchronizationScope.isEmpty
            || !self.deferredSynchronizationScope.isEmpty else { return }
        if self.isTransferFlowBlockingSynchronization {
            self.deferredSynchronizationScope.formUnion(scope.subtracting(self.pendingScreenSynchronizationScope))
            return
        }
        let scope = scope.union(
            self.deferredSynchronizationScope.union(self.pendingScreenSynchronizationScope)
                .subtracting(self.activeSynchronizationScope)
        )
        let coreScope = scope.intersection([.account, .transactions])
        if let coreScope = self.synchronizationGate.beginOrQueue(coreScope) {
            let taskId = UUID()
            self.synchronizationTaskId = taskId
            let generation = self.activationGeneration
            self.synchronizationTask = Task { [weak self] in
                await self?.performSynchronization(taskId: taskId, generation: generation, scope: coreScope)
            }
        }
        if self.collectiblesSynchronizationGate.beginOrQueue(scope.intersection(.nfts)) != nil {
            let taskId = UUID()
            self.collectiblesSynchronizationTaskId = taskId
            let observationId = self.runtimeObservationId
            self.collectiblesSynchronizationTask = Task { [weak self] in
                await self?.performCollectiblesSynchronization(taskId: taskId, observationId: observationId)
            }
        }
    }

    private func completedSynchronizationResource(_ scope: WalletSynchronizationScope, queued: WalletSynchronizationScope) {
        let completed = scope.subtracting(queued)
        self.deferredSynchronizationScope.subtract(completed)
        self.pendingScreenSynchronizationScope.subtract(completed)
        if completed.contains(.account) {
            self.pendingBalanceRequests.removeAll()
        }
    }

    private func performSynchronization(taskId: UUID, generation: UInt64, scope: WalletSynchronizationScope) async {
        guard self.isCurrentSynchronization(taskId, generation: generation) else { return }
        defer {
            if self.synchronizationTaskId == taskId {
                self.synchronizationTask = nil
                self.synchronizationTaskId = nil
                let queued = self.synchronizationGate.complete()
                if !queued.isEmpty {
                    self.requestSynchronization(scope: queued)
                }
            }
        }
        async let account: Void = self.refreshAccountIfRequested(scope,
        taskId: taskId,
        generation: generation)
        async let transactions: Void = self.refreshTransactionsIfRequested(scope,
        taskId: taskId,
        generation: generation)
        _ = await (account, transactions)
    }

    private func isCurrentSynchronization(_ taskId: UUID, generation: UInt64) -> Bool {
        !Task.isCancelled && !self.isShutdown
            && self.synchronizationTaskId == taskId && self.activationGeneration == generation
    }

    private func refreshAccountIfRequested(_ scope: WalletSynchronizationScope, taskId: UUID, generation: UInt64) async {
        guard scope.contains(.account), self.isCurrentSynchronization(taskId,
        generation: generation) else { return }
        let watermark = self.streamingPresentationOverlay.revision
        self.balanceTracker.beginRefresh(id: taskId)
        let result = await captureAsync { try await self.runtime.refresh() }
        guard self.isCurrentSynchronization(taskId, generation: generation) else { return }
        var balance = self.currentState.balance
        var overlayChanged = false
        switch result {
        case let .success(update):
            let result = self.balanceTracker.completeRefresh(
                id: taskId, update: update, current: balance,
                lastSuccessfulAt: self.balanceLastSuccessfulAt, now: currentWalletTimestamp()
            )
            balance = result.balance
            if result.refreshed {
                overlayChanged = self.streamingPresentationOverlay.clearBalance(through: watermark)
            }
            if case let .stale(_, error, _) = balance {
                self.logger.error("wallet_engine_refresh_failed", error)
            }
        case let .failure(error):
            if !(error is CancellationError) {
                self.logger.error("wallet_engine_refresh_failed", error)
            }
            balance = self.balanceTracker.failRefresh(
                id: taskId, error: error, current: balance, lastSuccessfulAt: self.balanceLastSuccessfulAt
            )
        }
        self.synchronizationGate.completedResource(.account)
        self.completedSynchronizationResource(.account, queued: self.synchronizationGate.queuedScope)
        self.recordBalanceTimestamp(balance)
        let previousState = self.currentState
        self.replaceState(
            phase: self.currentState.phase, balance: balance,
            transactions: self.currentState.transactions,
            pendingTransfers: self.currentState.pendingTransfers,
            activeOperation: self.currentState.activeOperation
        )
        if overlayChanged && previousState == self.currentState {
            self.publishPresentationState()
        }
        if case .stale = balance {
            self.retryStreamingSynchronizationIfNeeded(scope: .account)
        }
    }

    private func refreshTransactionsIfRequested(_ scope: WalletSynchronizationScope, taskId: UUID, generation: UInt64) async {
        guard scope.contains(.transactions), self.isCurrentSynchronization(taskId,
        generation: generation) else { return }
        let watermark = self.streamingPresentationOverlay.revision
        let result = await captureAsync {
            try await WalletSignalRequestContext<TelegramCore.WalletTransactions>().run(
                self.engine.wallet.getTransactions(inbound: true,
                outbound: true,
                offset: "",
                limit: Int32(walletTransactionFetchLimit))
            )
        }
        guard self.isCurrentSynchronization(taskId, generation: generation) else { return }
        var transactions = self.currentState.transactions
        var pending = self.currentState.pendingTransfers
        var overlayChanged = false
        switch result {
        case let .success(response):
            transactions = self.transactionHistory.applyRefresh(
                WalletTransactionHistory.Page(items: walletTransactions(from: response.items),
                nextOffset: response.nextOffset),
                previous: transactions,
                log: self.logger.log
            )
            let reconciliation = self.pendingTransfers(pending, reconcilingWith: transactions.items)
            if pending.contains(where: { value in
                value.collectibleAddress != nil && !reconciliation.pendingTransfers.contains(where: { $0.id == value.id })
            }) {
                self.requestSynchronization(scope: .nfts, force: true)
            }
            pending = reconciliation.pendingTransfers
            let removedCount = self.streamingPresentationOverlay.clearTransactions(
                through: watermark,
                presentIn: transactions.items,
                resolvedTraceIds: reconciliation.resolvedStreamingTraceIds
            )
            overlayChanged = removedCount != 0
            self.logPendingTransferHistoryReconciliation(reconciliation,
            removedStreamingTraceCount: removedCount)
        case let .failure(error):
            if !(error is CancellationError) {
                self.logger.error("wallet_transactions_refresh_failed", error)
            }
            transactions = self.transactionHistory.failed(error, previous: transactions, pagination: false)
        }
        self.synchronizationGate.completedResource(.transactions)
        self.completedSynchronizationResource(.transactions, queued: self.synchronizationGate.queuedScope)
        let previousState = self.currentState
        self.replaceState(
            phase: self.currentState.phase, balance: self.currentState.balance, transactions: transactions,
            pendingTransfers: pending, activeOperation: self.currentState.activeOperation
        )
        if overlayChanged && previousState == self.currentState {
            self.publishPresentationState()
        }
        if transactions.error != nil || self.streamingPresentationOverlay.hasFinalizedTransactions
            || pending.contains(where: { $0.sentTransfer != nil }) {
            self.retryStreamingSynchronizationIfNeeded(scope: .transactions)
        }
    }

    private func performCollectiblesSynchronization(taskId: UUID, observationId: UUID) async {
        guard self.isCurrentCollectiblesSynchronization(taskId, observationId: observationId) else { return }
        let previousRevision = self.collectiblesRevision.latest
        var resultRevision: UInt64?
        do {
            let update = try await self.runtime.refreshNfts()
            resultRevision = update.snapshot.revision
            let values = try await walletEngineCollectibles(update, pagination: false) { items in
                try await walletCollectibles(from: items, logger: self.logger)
            }
            guard self.isCurrentCollectiblesSynchronization(taskId,
            observationId: observationId) else { return }
            if let values, self.collectiblesRevision.accept(update.snapshot.revision) {
                self.replaceCollectibles(walletEngineCollectiblesState(
                    previous: self.currentState.collectibles, items: values,
                    hasMore: update.snapshot.nfts.hasMore, pagination: false
                ))
            }
        } catch {
            guard self.isCurrentCollectiblesSynchronization(taskId,
            observationId: observationId) else { return }
            if !(error is CancellationError) {
                self.logger.error("wallet_nfts_refresh_failed", error)
            }
            if resultRevision.map({ self.collectiblesRevision.isCurrent($0) }) ?? (self.collectiblesRevision.latest == previousRevision) {
                self.replaceCollectibles(walletEngineCollectiblesState(
                    previous: self.currentState.collectibles, failure: error, pagination: false
                ))
            }
        }
        self.collectiblesSynchronizationTask = nil
        self.collectiblesSynchronizationTaskId = nil
        let queued = self.collectiblesSynchronizationGate.complete()
        self.completedSynchronizationResource(.nfts, queued: queued)
        if !queued.isEmpty {
            self.requestSynchronization(scope: queued)
        }
    }

    private func isCurrentCollectiblesSynchronization(_ taskId: UUID, observationId: UUID) -> Bool {
        !Task.isCancelled && !self.isShutdown && self.collectiblesSynchronizationTaskId == taskId
            && self.runtimeObservationId == observationId
    }

    func replaceCollectibles(_ collectibles: CollectiblesState) {
        self.replaceState(
            phase: self.currentState.phase, balance: self.currentState.balance,
            transactions: self.currentState.transactions, collectibles: collectibles,
            pendingTransfers: self.currentState.pendingTransfers,
            activeOperation: self.currentState.activeOperation
        )
    }

    func cancelSynchronization() {
        let taskId = self.synchronizationTaskId
        self.synchronizationTask?.cancel()
        self.synchronizationTask = nil
        self.synchronizationTaskId = nil
        self.synchronizationGate.cancel()
        self.collectiblesSynchronizationTask?.cancel()
        self.collectiblesSynchronizationTask = nil
        self.collectiblesSynchronizationTaskId = nil
        self.collectiblesSynchronizationGate.cancel()
        if let taskId {
            let balance = self.balanceTracker.failRefresh(
                id: taskId, error: CancellationError(), current: self.currentState.balance,
                lastSuccessfulAt: self.balanceLastSuccessfulAt
            )
            self.recordBalanceTimestamp(balance)
            if balance != self.currentState.balance {
                self.replaceState(
                    phase: self.currentState.phase,
                    balance: balance,
                    transactions: self.currentState.transactions,
                    pendingTransfers: self.currentState.pendingTransfers,
                    activeOperation: self.currentState.activeOperation
                )
            }
        }
    }
}
