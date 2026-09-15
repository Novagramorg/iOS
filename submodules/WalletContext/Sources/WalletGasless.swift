import Foundation
import SwiftSignalKit
import TelegramCore

extension WalletContextImpl {
    func requestGaslessInfo() {
        guard WalletContext.useWalletTransferApi, self.canUseNetworkRuntime, case .wallet = self.currentState.phase,
              self.gaslessInfoTask == nil else { return }
        let taskId = UUID()
        let generation = self.activationGeneration
        let quotaRevision = self.gaslessQuotaRevision
        self.gaslessInfoTaskId = taskId
        self.replaceGaslessInfo(.loading(previous: self.currentState.gaslessInfo.currentValue))
        self.gaslessInfoTask = Task { [weak self] in
            await self?.fetchGaslessInfo(taskId: taskId, generation: generation, quotaRevision: quotaRevision)
        }
    }

    private func fetchGaslessInfo(taskId: UUID, generation: UInt64, quotaRevision: UInt64) async {
        defer {
            if self.gaslessInfoTaskId == taskId {
                self.gaslessInfoTask = nil
                self.gaslessInfoTaskId = nil
            }
        }
        do {
            let engine = self.engine
            _ = try await withThrowingTaskGroup(of: WalletGaslessInfo.self) { group in
                group.addTask {
                    try await WalletSignalRequestContext<WalletGaslessInfo>().run(engine.wallet.getGaslessInfo())
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 15_000_000_000)
                    throw WalletError.network
                }
                defer { group.cancelAll() }
                guard let value = try await group.next() else { throw WalletError.network }
                return value
            }
            try Task.checkCancellation()
            guard self.activationGeneration == generation, self.gaslessInfoTaskId == taskId else {
                return
            }
        } catch is CancellationError {
        } catch {
            guard self.activationGeneration == generation, self.gaslessInfoTaskId == taskId else {
                return
            }
            guard quotaRevision == self.gaslessQuotaRevision else { return }
            self.logger.error("wallet_gasless_info_failed", error)
            self.replaceGaslessInfo(.stale(previous: self.currentState.gaslessInfo.currentValue, error: synchronizationError(error), lastSuccessfulAt: self.currentState.gaslessInfo.lastSuccessfulAt))
        }
    }

    func cancelGaslessInfoRequest() {
        self.gaslessInfoTask?.cancel()
        self.gaslessInfoTask = nil
        self.gaslessInfoTaskId = nil
        if case let .loading(previous) = self.currentState.gaslessInfo {
            self.replaceGaslessInfo(.stale(previous: previous, error: .network, lastSuccessfulAt: nil))
        }
    }

    func applyGaslessInfo(_ info: WalletGaslessInfo) {
        self.gaslessInfoTask?.cancel()
        self.gaslessInfoTask = nil
        self.gaslessInfoTaskId = nil
        self.gaslessQuotaRevision &+= 1
        self.replaceGaslessInfo(.value(info, updatedAt: currentWalletTimestamp()))
    }

    private func replaceGaslessInfo(_ value: Resource<WalletGaslessInfo>) {
        self.replaceState(
            phase: self.currentState.phase,
            balance: self.currentState.balance,
            transactions: self.currentState.transactions,
            pendingTransfers: self.currentState.pendingTransfers,
            activeOperation: self.currentState.activeOperation,
            gaslessInfo: value
        )
    }

    func restoreTransferReceipts(recordId: String, walletAddress: String, generation: UInt64) async {
        do {
            let receipts = try await self.storage.loadTransferReceipts()
            guard !Task.isCancelled, !self.isShutdown, self.activationGeneration == generation else { return }
            for receipt in receipts where receipt.recordId == recordId && walletEngineAddressesEqual(receipt.walletAddress, walletAddress) {
                let existing = self.currentState.pendingTransfers.first { $0.id == receipt.pendingTransfer.id }
                var source = existing ?? receipt.pendingTransfer
                if source.status != .confirmed, receipt.pendingTransfer.status == .confirmed {
                    source = receipt.pendingTransfer
                }
                if source.streamingData == nil {
                    source.streamingData = receipt.pendingTransfer.streamingData
                }
                guard let recovered = acceptedWalletTransferSubmission(
                    pending: source,
                    messageHash: existing?.normalizedHash ?? receipt.pendingTransfer.normalizedHash,
                    phase: existing?.status == .confirmed ? .confirmed : .submitted,
                    acceptedAt: receipt.receivedAt,
                    sentTransfer: receipt.transfer
                ) else { continue }
                if let reference = recovered.pendingMessage {
                    try await WalletSignalRequestContext<Void>().run(
                        self.engine.wallet.acceptPendingTransferMessage(reference, transfer: receipt.transfer, receivedAt: receipt.receivedAt)
                        |> castError(WalletError.self)
                    )
                    guard !Task.isCancelled, !self.isShutdown, self.activationGeneration == generation else { return }
                }
                let finalTransaction: Transaction?
                if let stored = receipt.transaction {
                    finalTransaction = try await walletTransactions(from: [stored], engine: self.engine).first
                    guard !Task.isCancelled, !self.isShutdown, self.activationGeneration == generation else { return }
                } else {
                    finalTransaction = walletHistoryTransactionForPending(recovered, transactions: self.currentState.transactions.items)
                }
                if let finalTransaction {
                    self.rememberWalletFinalTransaction(finalTransaction, msgHash: receipt.transfer.msgHash)
                    await self.applyWalletFinalTransaction(finalTransaction, pending: recovered, generation: generation)
                    guard !Task.isCancelled, !self.isShutdown, self.activationGeneration == generation else { return }
                    continue
                }
                guard walletPendingTransferUIExpirationTimestamp(from: receipt.receivedAt) > currentWalletTimestamp() else { continue }
                var pending = self.currentState.pendingTransfers.filter { $0.id != recovered.id }
                pending.append(recovered)
                self.trackWalletTransferResolution(recovered, receivedAt: receipt.receivedAt)
                self.resolveStreamingPendingMessage(recovered)
                let reconciliation = self.pendingTransfers(pending, reconcilingWith: self.currentState.transactions.items)
                self.replaceState(
                    phase: self.currentState.phase, balance: self.currentState.balance,
                    transactions: self.currentState.transactions, pendingTransfers: reconciliation.pendingTransfers,
                    activeOperation: self.currentState.activeOperation
                )
            }
        } catch {
            self.logger.error("wallet_transfer_receipts_restore_failed", error)
        }
        guard !Task.isCancelled, !self.isShutdown, self.activationGeneration == generation else { return }
        for transfer in self.currentState.pendingTransfers {
            self.trackWalletTransferResolution(transfer)
        }
    }
}
