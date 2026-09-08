import Foundation
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
            let info = try await withThrowingTaskGroup(of: WalletGaslessInfo.self) { group in
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
            guard self.activationGeneration == generation, self.gaslessInfoTaskId == taskId else { return }
            let value: WalletGaslessInfo
            if quotaRevision != self.gaslessQuotaRevision, let quota = self.latestGaslessQuota {
                value = WalletGaslessInfo(available: info.available, left: quota.left, resetAt: quota.resetAt, minAmount: info.minAmount, relayerAddress: info.relayerAddress)
            } else {
                value = info
            }
            self.replaceGaslessInfo(.value(value, updatedAt: currentWalletTimestamp()))
        } catch is CancellationError {
        } catch {
            guard self.activationGeneration == generation, self.gaslessInfoTaskId == taskId else { return }
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

    func applyGaslessQuota(_ transfer: WalletSentTransfer, receivedAt: Int32) {
        if let quota = self.latestGaslessQuota, quota.receivedAt > receivedAt { return }
        if let updatedAt = self.currentState.gaslessInfo.lastSuccessfulAt, updatedAt > receivedAt { return }
        self.gaslessQuotaRevision &+= 1
        self.latestGaslessQuota = (transfer.gaslessLeft, transfer.gaslessResetAt, receivedAt)
        if let info = self.currentState.gaslessInfo.currentValue {
            self.replaceGaslessInfo(.value(WalletGaslessInfo(
                available: info.available,
                left: transfer.gaslessLeft,
                resetAt: transfer.gaslessResetAt,
                minAmount: info.minAmount,
                relayerAddress: info.relayerAddress
            ), updatedAt: receivedAt))
        }
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
            var pending = self.currentState.pendingTransfers
            for receipt in receipts where receipt.recordId == recordId && walletEngineAddressesEqual(receipt.walletAddress, walletAddress) {
                self.applyGaslessQuota(receipt.transfer, receivedAt: receipt.receivedAt)
                guard walletPendingTransferUIExpirationTimestamp(from: receipt.receivedAt) > currentWalletTimestamp() else { continue }
                let existing = pending.first { $0.id == receipt.pendingTransfer.id }
                guard let recovered = acceptedWalletEngineSubmission(
                    pending: existing ?? receipt.pendingTransfer,
                    messageHash: existing?.normalizedHash,
                    phase: existing?.status == .confirmed ? .confirmed : .submitted,
                    acceptedAt: receipt.receivedAt,
                    sentTransfer: receipt.transfer
                ) else { continue }
                pending.removeAll { $0.id == recovered.id }
                pending.append(recovered)
            }
            let reconciliation = self.pendingTransfers(pending, reconcilingWith: self.currentState.transactions.items)
            self.replaceState(
                phase: self.currentState.phase,
                balance: self.currentState.balance,
                transactions: self.currentState.transactions,
                pendingTransfers: reconciliation.pendingTransfers,
                activeOperation: self.currentState.activeOperation
            )
        } catch {
            self.logger.error("wallet_transfer_receipts_restore_failed", error)
        }
    }
}
