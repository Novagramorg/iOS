import Foundation
import SwiftSignalKit
import TelegramCore
import WalletEngineFFI

private let walletTransferResolutionInterval: Int32 = 15

private struct WalletTransferData: Sendable {
    let normal: Data
    let gasless: Data?

    init(prepared: WalletEngineFFI.PreparedTransfer, includeInternalBoc: Bool) throws {
        self.normal = try Self.decodeBoc(prepared.externalBoc)
        self.gasless = includeInternalBoc ? try Self.decodeBoc(prepared.internalBoc) : nil
    }

    func streamingData(operationId: String, logger: WalletLogger) -> WalletContext.PendingTransfer.StreamingData {
        func bodyHash(_ data: Data, kind: WalletBocMessageKind) -> String? {
            do {
                return try walletBocBodyHash(data, kind: kind)
            } catch {
                let reason = (error as? WalletBocError)?.rawValue ?? "unknown"
                logger.log("event=wallet_transfer_boc_hash_failed operation_id=\(operationId) kind=\(kind == .external ? "normal" : "gasless") reason=\(reason)")
                return nil
            }
        }
        return WalletContext.PendingTransfer.StreamingData(
            normalBodyHash: bodyHash(self.normal, kind: .external),
            gaslessBodyHash: self.gasless.flatMap { bodyHash($0, kind: .internalMessage) }
        )
    }

    private static func decodeBoc(_ value: String) throws -> Data {
        guard value.utf8.count <= ((16 * 1024 + 2) / 3) * 4,
              let data = Data(base64Encoded: value),
              !data.isEmpty, data.count <= 16 * 1024 else {
            throw WalletSendTransferError.invalidData
        }
        return data
    }
}

private struct WalletTransferSubmissionResult: Sendable {
    let pendingTransfer: WalletContext.PendingTransfer
    let receipt: WalletEngineTransferReceipt?
}

func walletPendingTransferAfterRestart(_ pending: WalletContext.PendingTransfer) -> WalletContext.PendingTransfer {
    guard pending.status == .broadcasting, pending.streamingData != nil else { return pending }
    return acceptedWalletTransferSubmission(
        pending: pending, messageHash: nil, phase: .submissionUnknown, acceptedAt: pending.createdAt
    ) ?? pending
}

struct WalletTransferResolution {
    let pending: WalletContext.PendingTransfer
    let expiresAt: Int32
    var nextAttemptAt: Int32
}

private func walletTransferResolutionCandidate(_ pending: WalletContext.PendingTransfer, transactions: [WalletContext.Transaction]) -> WalletContext.Transaction? {
    let matches = transactions.filter {
        $0.direction == .outgoing
            && $0.peer.address.map { walletEngineAddressesEqual($0, pending.recipient) } == true
    }
    guard matches.count == 1, let transaction = matches.first, !transaction.id.isEmpty,
          transaction.status == .failed || (transaction.status == .completed && transaction.transactionHash != nil) else { return nil }
    return transaction
}

private func walletTransferConfirmed(_ pending: WalletContext.PendingTransfer, transaction: WalletContext.Transaction) -> WalletContext.PendingTransfer {
    WalletContext.PendingTransfer(
        id: pending.id, recipient: pending.recipient, amount: pending.amount,
        comment: pending.comment, commentEncrypted: pending.commentEncrypted,
        collectibleAddress: pending.collectibleAddress, normalizedHash: pending.normalizedHash,
        sentTransfer: pending.sentTransfer, pendingMessage: pending.pendingMessage,
        streamingData: pending.streamingData, fee: pending.fee,
        transactionHash: transaction.transactionHash, transactionLt: transaction.logicalTime,
        uiExpiresAt: pending.uiExpiresAt, createdAt: pending.createdAt, status: .confirmed
    )
}

extension WalletContextImpl {
    func submitTransferThroughWalletApi(
        prepared: PreparedTransfer,
        intent: SendIntent,
        pending: PendingTransfer,
        walletAddress: String,
        generation: UInt64
    ) async throws -> PendingTransfer {
        let result: WalletTransferSubmissionResult
        do {
            let preparedData = try await self.runtime.prepareTransfer(
                operationId: prepared.id,
                intent: intent
            )
            try Task.checkCancellation()
            guard !self.isShutdown, self.activationGeneration == generation,
                  case let .wallet(info) = self.currentState.phase,
                  walletEngineAddressesEqual(info.address, walletAddress),
                  preparedData.data.operationId == pending.id else {
                throw WalletError.unavailable
            }
            guard preparedData.data.validUntil > UInt64(max(0, currentWalletTimestamp())) else {
                throw WalletError.preparedTransferExpired
            }
            let data = try WalletTransferData(
                prepared: preparedData.data,
                includeInternalBoc: prepared.amount >= self.transferGaslessMinAmount
            )
            result = try await self.submitTransferData(
                data,
                recordId: preparedData.recordId,
                walletAddress: walletAddress,
                pending: pending,
                validUntil: preparedData.data.validUntil,
                generation: generation
            )
        } catch {
            self.logger.error("wallet_transfer_api_failed", error)
            if self.activationGeneration == generation {
                self.preparedTransfers[prepared.id] = nil
                self.replaceState(
                    phase: self.currentState.phase,
                    balance: self.currentState.balance,
                    transactions: self.currentState.transactions,
                    pendingTransfers: self.currentState.pendingTransfers.filter { $0.id != pending.id },
                    activeOperation: self.currentState.activeOperation
                )
            }
            if let pendingMessage = pending.pendingMessage {
                let _ = self.engine.wallet.removePendingTransferMessage(pendingMessage).start()
            }
            throw error
        }
        guard !self.isShutdown, self.activationGeneration == generation else {
            throw WalletError.unavailable
        }
        let accepted = acceptedWalletTransferSubmission(
            pending: self.latestPendingTransfer(result.pendingTransfer),
            messageHash: nil,
            phase: result.receipt == nil ? .submissionUnknown : .submitted,
            acceptedAt: result.receipt?.receivedAt ?? currentWalletTimestamp(),
            sentTransfer: result.receipt?.transfer
        ) ?? result.pendingTransfer
        self.preparedTransfers[prepared.id] = nil
        if let receipt = result.receipt {
            self.applyGaslessQuota(receipt.transfer, receivedAt: receipt.receivedAt)
            self.trackWalletTransferResolution(accepted, receivedAt: receipt.receivedAt)
        }
        var values = self.currentState.pendingTransfers.filter { $0.id != accepted.id }
        values.append(accepted)
        self.resolveStreamingPendingMessage(accepted)
        let reconciliation = self.pendingTransfers(values, reconcilingWith: self.currentState.transactions.items)
        self.replaceState(
            phase: self.currentState.phase,
            balance: self.currentState.balance,
            transactions: self.currentState.transactions,
            pendingTransfers: reconciliation.pendingTransfers,
            activeOperation: self.currentState.activeOperation
        )
        if result.receipt == nil || self.streamingConnectionState != .subscribed {
            self.requestSynchronization(scope: [.account, .transactions], force: true)
        }
        return accepted
    }

    private func submitTransferData(
        _ data: WalletTransferData,
        recordId: String,
        walletAddress: String,
        pending: PendingTransfer,
        validUntil: UInt64,
        generation: UInt64
    ) async throws -> WalletTransferSubmissionResult {
        try Task.checkCancellation()
        var pending = pending
        pending.streamingData = data.streamingData(operationId: pending.id, logger: self.logger)
        try await self.persistPendingTransferBeforeSend(pending, generation: generation)
        guard validUntil > UInt64(max(0, currentWalletTimestamp())) else {
            throw WalletError.preparedTransferExpired
        }
        try Task.checkCancellation()
        let engine = self.engine
        let pendingMessage = pending.pendingMessage
        let transfer: WalletSentTransfer?
        do {
            transfer = try await withThrowingTaskGroup(of: WalletSentTransfer.self) { group in
                group.addTask {
                    try await WalletSignalRequestContext<WalletSentTransfer>().run(
                        engine.wallet.sendTransfer(dataNormal: data.normal, dataGasless: data.gasless, pendingMessage: pendingMessage)
                    )
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 15_000_000_000)
                    throw WalletSendTransferError.network
                }
                defer { group.cancelAll() }
                guard let result = try await group.next() else {
                    throw WalletSendTransferError.network
                }
                return result
            }
        } catch let error as WalletSendTransferError where error == .invalidData || error == .sendFailed {
            throw error
        } catch {
            transfer = nil
        }
        if let transfer {
            self.logger.log("event=wallet_transfer_receipt operation_id=\(pending.id) msg_hash=\(transfer.msgHash) gasless=\(transfer.gasless ? 1 : 0)")
        }
        let receivedAt = currentWalletTimestamp()
        guard let accepted = acceptedWalletTransferSubmission(
            pending: self.activationGeneration == generation ? self.latestPendingTransfer(pending) : pending,
            messageHash: nil,
            phase: transfer == nil ? .submissionUnknown : .submitted,
            acceptedAt: receivedAt,
            sentTransfer: transfer
        ) else {
            throw WalletContext.WalletError.unavailable
        }
        let receipt = transfer.map {
            WalletEngineTransferReceipt(
                recordId: recordId,
                walletAddress: walletAddress,
                pendingTransfer: accepted,
                receivedAt: receivedAt,
                transfer: $0
            )
        }
        if let receipt {
            do {
                try await self.storage.saveTransferReceipt(receipt)
            } catch {
                self.logger.error("wallet_transfer_receipt_save_failed", error)
            }
        }
        return WalletTransferSubmissionResult(pendingTransfer: accepted, receipt: receipt)
    }

    func trackWalletTransferResolution(_ pending: PendingTransfer, receivedAt: Int32? = nil) {
        guard self.walletTransferResolutions[pending.id] == nil,
              let sent = pending.sentTransfer, !sent.msgHash.isEmpty, pending.collectibleAddress == nil else { return }
        let acceptedAt = receivedAt ?? pending.uiExpiresAt.map {
            Int32(clamping: Int64($0) - Int64(walletPendingTransferUILifetime))
        } ?? pending.createdAt
        let expiresAt = walletPendingTransferUIExpirationTimestamp(from: acceptedAt)
        guard expiresAt > currentWalletTimestamp() else { return }
        self.walletTransferResolutions[pending.id] = WalletTransferResolution(
            pending: pending, expiresAt: expiresAt,
            nextAttemptAt: Int32(clamping: Int64(acceptedAt) + Int64(walletTransferResolutionInterval))
        )
    }

    func cancelWalletTransferResolution() {
        // Do not start another request until the cancelled task has unwound.
        self.walletTransferResolutionTask?.cancel()
    }

    func evaluateWalletTransferResolution() {
        let now = currentWalletTimestamp()
        self.walletTransferResolutions = self.walletTransferResolutions.filter { $0.value.expiresAt > now }
        guard self.canUseNetworkRuntime, case .wallet = self.currentState.phase,
              let deadline = self.walletTransferResolutions.values.map(\.nextAttemptAt).min() else {
            self.cancelWalletTransferResolution()
            return
        }
        if self.walletTransferResolutionTask != nil {
            if let scheduled = self.walletTransferResolutionScheduledAt, deadline < scheduled {
                self.cancelWalletTransferResolution()
            }
            return
        }
        let generation = self.activationGeneration
        self.walletTransferResolutionScheduledAt = deadline
        self.walletTransferResolutionTask = Task { [weak self] in
            await self?.runWalletTransferResolution(generation: generation, deadline: deadline)
        }
    }

    private func isCurrentWalletTransferResolution(_ generation: UInt64) -> Bool {
        !Task.isCancelled && self.canUseNetworkRuntime && self.activationGeneration == generation
    }

    private func pendingWalletTransferResolution(_ operationId: String) -> PendingTransfer? {
        guard let resolution = self.walletTransferResolutions[operationId],
              resolution.expiresAt > currentWalletTimestamp() else { return nil }
        return self.latestPendingTransfer(resolution.pending)
    }

    private func runWalletTransferResolution(generation: UInt64, deadline: Int32) async {
        var attemptedHash: String?
        defer {
            if let attemptedHash, self.isCurrentWalletTransferResolution(generation) {
                let nextAttemptAt = Int32(clamping: Int64(currentWalletTimestamp()) + Int64(walletTransferResolutionInterval))
                for id in Array(self.walletTransferResolutions.keys) where self.walletTransferResolutions[id]?.pending.sentTransfer?.msgHash == attemptedHash {
                    self.walletTransferResolutions[id]?.nextAttemptAt = nextAttemptAt
                }
            }
            self.walletTransferResolutionTask = nil
            self.walletTransferResolutionScheduledAt = nil
            self.evaluateWalletTransferResolution()
        }
        do {
            let delay = max(0, Double(deadline) - Date().timeIntervalSince1970)
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard self.isCurrentWalletTransferResolution(generation) else { return }
            self.walletTransferResolutionScheduledAt = nil
            let now = currentWalletTimestamp()
            let due = self.walletTransferResolutions.values.filter {
                $0.expiresAt > now && $0.nextAttemptAt <= now
            }.sorted {
                $0.nextAttemptAt == $1.nextAttemptAt ? $0.pending.id < $1.pending.id : $0.nextAttemptAt < $1.nextAttemptAt
            }
            guard let hash = due.first?.pending.sentTransfer?.msgHash else { return }
            attemptedHash = hash
            var unresolvedIds: [String] = []
            for resolution in due where resolution.pending.sentTransfer?.msgHash == hash {
                let id = resolution.pending.id
                guard self.isCurrentWalletTransferResolution(generation),
                      let pending = self.pendingWalletTransferResolution(id) else { continue }
                if let transaction = walletHistoryTransactionForPending(pending, transactions: self.currentState.transactions.items) {
                    if try await self.applyWalletTransferResolution(operationId: id, transaction: transaction, generation: generation) {
                        self.walletTransferResolutions[id] = nil
                        continue
                    }
                } else if pending.transactionHash != nil {
                    let unresolved: Bool
                    if let reference = pending.pendingMessage {
                        unresolved = try await WalletSignalRequestContext<Bool>().run(
                            self.engine.wallet.hasUnresolvedPendingTransferMessage(reference) |> castError(WalletError.self)
                        )
                    } else {
                        unresolved = false
                    }
                    guard self.isCurrentWalletTransferResolution(generation) else { return }
                    if !unresolved {
                        self.walletTransferResolutions[id] = nil
                        continue
                    }
                }
                unresolvedIds.append(id)
            }
            guard self.isCurrentWalletTransferResolution(generation),
                  let expiresAt = unresolvedIds.compactMap({ self.walletTransferResolutions[$0]?.expiresAt }).max(),
                  expiresAt > currentWalletTimestamp() else { return }
            self.logger.log("event=wallet_transfer_fallback_requested operation_count=\(unresolvedIds.count)")
            let transactions = try await WalletSignalRequestContext<[Transaction]>().run(
                self.engine.wallet.getTransactionsByMsgHash(msgHash: [hash])
                |> timeout(min(Double(walletTransferResolutionInterval), Double(expiresAt) - Date().timeIntervalSince1970), queue: Queue.concurrentDefaultQueue(), alternate: .fail(.generic))
                |> map { walletTransactions(from: $0.items) }
            )
            for id in unresolvedIds {
                guard self.isCurrentWalletTransferResolution(generation),
                      let pending = self.pendingWalletTransferResolution(id),
                      let transaction = walletTransferResolutionCandidate(pending, transactions: transactions) else { continue }
                let sameRecipient = self.walletTransferResolutions.values.filter {
                    $0.expiresAt > currentWalletTimestamp() && $0.pending.sentTransfer?.msgHash == hash
                        && walletEngineAddressesEqual($0.pending.recipient, pending.recipient)
                }
                guard sameRecipient.count == 1 else { continue }
                if try await self.applyWalletTransferResolution(operationId: id, transaction: transaction, generation: generation) {
                    self.walletTransferResolutions[id] = nil
                }
            }
        } catch {
            if !(error is CancellationError) {
                self.logger.error("wallet_transfer_resolution_failed", error)
            }
        }
    }

    private func applyWalletTransferResolution(operationId: String, transaction: Transaction, generation: UInt64) async throws -> Bool {
        guard self.isCurrentWalletTransferResolution(generation),
              let pending = self.pendingWalletTransferResolution(operationId) else { return false }
        if let knownHash = pending.transactionHash, knownHash != transaction.transactionHash { return false }
        if transaction.status == .failed, pending.status == .confirmed { return false }

        var values = self.currentState.pendingTransfers
        var overlayChanged = false
        if transaction.status == .failed {
            values.removeAll { $0.id == operationId }
            if let traceId = pending.streamingTraceId {
                let expired = self.streamingPresentationOverlay.expirePendingTraces([traceId])
                self.expiredPendingStreamingTraceIds.formUnion(expired.suppressedTraceIds)
                overlayChanged = expired.removedCount != 0
            }
        } else {
            let confirmed = walletTransferConfirmed(pending, transaction: transaction)
            values = values.map { $0.id == operationId ? confirmed : $0 }
            self.rememberOutgoingTransactionPresentationIdentities([confirmed])
        }
        let items = mergeTransactions(existing: self.currentState.transactions.items, new: [
            walletTransactionWithPresentationId(transaction, presentationId: "pending:\(operationId)")
        ])
        let reconciliation = self.pendingTransfers(values, reconcilingWith: items)
        let removed = self.streamingPresentationOverlay.clearTransactions(
            through: self.streamingPresentationOverlay.revision,
            presentIn: items, resolvedTraceIds: reconciliation.resolvedStreamingTraceIds
        )
        let previousState = self.currentState
        self.replaceState(
            phase: self.currentState.phase, balance: self.currentState.balance,
            transactions: TransactionsState(
                items: items, offset: items.count,
                canLoadMore: self.currentState.transactions.canLoadMore,
                isLoadingMore: self.currentState.transactions.isLoadingMore, error: self.currentState.transactions.error
            ),
            pendingTransfers: reconciliation.pendingTransfers, activeOperation: self.currentState.activeOperation
        )
        if previousState == self.currentState && (overlayChanged || removed != 0) {
            self.publishPresentationState()
        }
        self.logPendingTransferHistoryReconciliation(reconciliation, removedStreamingTraceCount: removed)
        if let reference = pending.pendingMessage {
            guard case let .user(peer, _, _) = transaction.peer, peer.id.toInt64() == reference.peerId else {
                let unresolved = try await WalletSignalRequestContext<Bool>().run(
                    self.engine.wallet.hasUnresolvedPendingTransferMessage(reference) |> castError(WalletError.self)
                )
                return self.isCurrentWalletTransferResolution(generation) && !unresolved
            }
            try await WalletSignalRequestContext<Void>().run(
                self.engine.wallet.resolvePendingTransferMessage(reference, transactionId: transaction.id, failed: transaction.status == .failed)
                |> castError(WalletError.self)
            )
        }
        return self.isCurrentWalletTransferResolution(generation)
    }
}
