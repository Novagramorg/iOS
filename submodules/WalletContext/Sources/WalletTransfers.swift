import Foundation
import SwiftSignalKit
import TelegramCore
import WalletEngineFFI

private let walletTransferResolutionInterval: Int32 = 15
private let walletTransferSubmissionTimeout: UInt64 = 45_000_000_000

@available(macOS 10.15, *)
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

@available(macOS 10.15, *)
private struct WalletTransferSubmissionResult: Sendable {
    let pendingTransfer: WalletContext.PendingTransfer
    let receipt: WalletEngineTransferReceipt?
    let transaction: WalletContext.Transaction?
}

@available(macOS 10.15, *)
func walletPendingTransferAfterRestart(_ pending: WalletContext.PendingTransfer) -> WalletContext.PendingTransfer {
    guard pending.status == .broadcasting, pending.streamingData != nil else { return pending }
    return acceptedWalletTransferSubmission(
        pending: pending, messageHash: nil, phase: .submissionUnknown, acceptedAt: pending.createdAt
    ) ?? pending
}

@available(macOS 10.15, *)
struct WalletTransferHashState {
    let expiresAt: Int32
    var nextAttemptAt: Int32
    var transactions: [WalletContext.Transaction]
}

@available(macOS 10.15, *)
struct WalletTransferResolution {
    let pending: WalletContext.PendingTransfer
    let expiresAt: Int32
    var nextAttemptAt: Int32
}

@available(macOS 10.15, *)
func walletTransferResolutionCandidate(_ pending: WalletContext.PendingTransfer, transactions: [WalletContext.Transaction], history: [WalletContext.Transaction] = []) -> WalletContext.Transaction? {
    let matches = transactions.filter {
        $0.direction == .outgoing
            && $0.peer.address.map { walletEngineAddressesEqual($0, pending.recipient) } == true
    }
    guard matches.count == 1, let transaction = matches.first, !transaction.id.isEmpty,
          transaction.status == .failed || transaction.status == .completed else { return nil }
    // A relayer message can cover several operations, including the same recipient.
    // Never reuse a transaction already attributed to a different local operation.
    guard !history.contains(where: {
        ($0.id == transaction.id || (transaction.transactionHash != nil && $0.transactionHash == transaction.transactionHash))
            && $0.presentationId.hasPrefix("pending:") && $0.presentationId != "pending:\(pending.id)"
    }) else { return nil }
    return transaction
}

@available(macOS 10.15, *)
private func walletTransferConfirmed(_ pending: WalletContext.PendingTransfer, transaction: WalletContext.Transaction) -> WalletContext.PendingTransfer {
    WalletContext.PendingTransfer(
        id: pending.id, recipient: pending.recipient, amount: pending.amount,
        comment: pending.comment, commentEncrypted: pending.commentEncrypted,
        collectibleAddress: pending.collectibleAddress, normalizedHash: pending.normalizedHash,
        sentTransfer: pending.sentTransfer, expectedGasless: pending.expectedGasless,
        pendingMessage: pending.pendingMessage,
        streamingData: pending.streamingData, fee: transaction.fee,
        transactionHash: transaction.transactionHash, transactionLt: transaction.logicalTime,
        uiExpiresAt: pending.uiExpiresAt, createdAt: pending.createdAt, status: .confirmed
    )
}

@available(macOS 10.15, *)
extension WalletContextImpl {
    func submitTransferThroughWalletApi(
        prepared: PreparedTransfer,
        intent: SendIntent,
        pending: PendingTransfer,
        randomId: Int64,
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
                    && !WalletContext.isSelfTransfer(recipient: prepared.recipient, walletAddress: walletAddress)
            )
            result = try await self.submitTransferData(
                data,
                recordId: preparedData.recordId,
                walletAddress: walletAddress,
                pending: pending,
                randomId: randomId,
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
        let finalTransaction = result.transaction ?? accepted.sentTransfer.flatMap {
            self.cachedWalletTransferTransaction(accepted, msgHash: $0.msgHash)
        }
        if let finalTransaction {
            await self.applyWalletFinalTransaction(finalTransaction, pending: accepted, generation: generation)
            guard !self.isShutdown, self.activationGeneration == generation else { throw WalletError.unavailable }
            if let sent = accepted.sentTransfer {
                self.rememberWalletFinalTransaction(finalTransaction, msgHash: sent.msgHash)
            }
            self.requestSynchronization(scope: [.account], force: true)
            if finalTransaction.status == .failed { throw WalletSendTransferError.sendFailed }
            return walletTransferConfirmed(accepted, transaction: finalTransaction)
        }
        if let receipt = result.receipt {
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
        randomId: Int64,
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
        let response: WalletSendTransferResult?
        do {
            response = try await withThrowingTaskGroup(of: WalletSendTransferResult.self) { group in
                group.addTask {
                    try await WalletSignalRequestContext<WalletSendTransferResult>().run(
                        engine.wallet.sendTransfer(dataNormal: data.normal, dataGasless: data.gasless, randomId: randomId, pendingMessage: pendingMessage)
                    )
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: walletTransferSubmissionTimeout)
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
            response = nil
        }
        let transfer = response?.transfer
        let finalTransaction = response?.transaction.flatMap { walletTransactions(from: [$0]).first }
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
                transfer: $0,
                transaction: finalTransaction.map(WalletStoredTransaction.init)
            )
        }
        if let receipt {
            do {
                try await self.storage.saveTransferReceipt(receipt)
            } catch {
                self.logger.error("wallet_transfer_receipt_save_failed", error)
            }
        }
        return WalletTransferSubmissionResult(pendingTransfer: accepted, receipt: receipt, transaction: finalTransaction)
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
        self.walletTransferResolutionTask?.cancel()
    }

    func evaluateWalletTransferResolution() {
        let now = currentWalletTimestamp()
        self.walletTransferResolutions = self.walletTransferResolutions.filter { $0.value.expiresAt > now }
        self.walletTransferHashStates = self.walletTransferHashStates.filter { $0.value.expiresAt > now }
        let remoteDeadlines = self.walletTransferHashStates.values.filter { $0.transactions.isEmpty }.map(\.nextAttemptAt)
        guard self.canUseNetworkRuntime, case .wallet = self.currentState.phase else {
            self.cancelWalletTransferResolution()
            return
        }
        guard let deadline = (self.walletTransferResolutions.values.map(\.nextAttemptAt) + remoteDeadlines).min() else {
            // A running request may still be applying the rest of a transaction batch.
            if self.walletTransferResolutionScheduledAt != nil {
                self.cancelWalletTransferResolution()
            }
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
                if self.walletTransferHashStates[attemptedHash]?.transactions.isEmpty == true {
                    self.walletTransferHashStates[attemptedHash]?.nextAttemptAt = nextAttemptAt
                }
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
            let remoteHash = self.walletTransferHashStates.filter {
                $0.value.transactions.isEmpty && $0.value.nextAttemptAt <= now
            }.min { $0.value.nextAttemptAt < $1.value.nextAttemptAt }?.key
            guard let hash = due.first?.pending.sentTransfer?.msgHash ?? remoteHash else { return }
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
            var deadlines = unresolvedIds.compactMap { self.walletTransferResolutions[$0]?.expiresAt }
            if let state = self.walletTransferHashStates[hash], state.transactions.isEmpty {
                deadlines.append(state.expiresAt)
            }
            guard self.isCurrentWalletTransferResolution(generation),
                  let expiresAt = deadlines.max(),
                  expiresAt > currentWalletTimestamp() else { return }
            self.logger.log("event=wallet_transfer_fallback_requested operation_count=\(unresolvedIds.count)")
            let transactions = try await WalletSignalRequestContext<[Transaction]>().run(
                self.engine.wallet.getTransactionsByMsgHash(msgHash: [hash])
                |> timeout(min(Double(walletTransferResolutionInterval), Double(expiresAt) - Date().timeIntervalSince1970), queue: Queue.concurrentDefaultQueue(), alternate: .fail(.generic))
                |> map { walletTransactions(from: $0.items) }
            )
            guard self.isCurrentWalletTransferResolution(generation) else { return }
            for transaction in transactions {
                self.rememberWalletFinalTransaction(transaction, msgHash: hash)
                await self.applyWalletFinalTransaction(transaction, pending: nil, generation: generation)
                guard self.isCurrentWalletTransferResolution(generation) else { return }
            }
            for id in unresolvedIds {
                guard self.isCurrentWalletTransferResolution(generation),
                      let pending = self.pendingWalletTransferResolution(id),
                      let transaction = walletTransferResolutionCandidate(pending, transactions: transactions, history: self.currentState.transactions.items) else { continue }
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
        if let knownHash = pending.transactionHash, let hash = transaction.transactionHash, knownHash != hash { return false }
        await self.applyWalletFinalTransaction(transaction, pending: pending, generation: generation)
        return !self.isShutdown && self.activationGeneration == generation
    }

    func applyWalletFinalTransaction(_ transaction: Transaction, pending: PendingTransfer?, generation: UInt64) async {
        guard !self.isShutdown, self.activationGeneration == generation, !transaction.id.isEmpty else { return }
        var values = self.currentState.pendingTransfers
        var resolvedTraceIds = Set<String>()
        var overlayChanged = false
        if let pending {
            self.walletTransferResolutions[pending.id] = nil
            values.removeAll { $0.id == pending.id }
            if let traceId = pending.streamingTraceId {
                resolvedTraceIds.insert(traceId)
                if transaction.status == .failed {
                    let expired = self.streamingPresentationOverlay.expirePendingTraces([traceId])
                    self.expiredPendingStreamingTraceIds.formUnion(expired.suppressedTraceIds)
                    overlayChanged = expired.removedCount != 0
                }
            }
            if transaction.status != .failed {
                self.rememberOutgoingTransactionPresentationIdentities([walletTransferConfirmed(pending, transaction: transaction)])
            }
        }
        let value = pending.map {
            walletTransactionWithPresentationId(transaction, presentationId: "pending:\($0.id)")
        } ?? transaction
        let items = mergeTransactions(existing: self.currentState.transactions.items, new: [value])
        let reconciliation = self.pendingTransfers(values, reconcilingWith: items)
        resolvedTraceIds.formUnion(reconciliation.resolvedStreamingTraceIds)
        let removed = self.streamingPresentationOverlay.clearTransactions(
            through: self.streamingPresentationOverlay.revision,
            presentIn: items, resolvedTraceIds: resolvedTraceIds
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
        if let reference = pending?.pendingMessage,
           case let .user(peer, _, _) = transaction.peer, peer.id.toInt64() == reference.peerId {
            // Message reconciliation is local and must not turn a final transfer into a network failure.
            do {
                try await WalletSignalRequestContext<Void>().run(
                    self.engine.wallet.resolvePendingTransferMessage(reference, transactionId: transaction.id, failed: transaction.status == .failed)
                    |> castError(WalletError.self)
                )
            } catch {
                self.logger.error("wallet_transfer_message_resolution_failed", error)
            }
        }
    }

    func cachedWalletTransferTransaction(_ pending: PendingTransfer, msgHash: String) -> Transaction? {
        guard let state = self.walletTransferHashStates[msgHash], state.expiresAt > currentWalletTimestamp() else { return nil }
        return walletTransferResolutionCandidate(pending, transactions: state.transactions, history: self.currentState.transactions.items)
    }

    func rememberWalletFinalTransaction(_ transaction: Transaction, msgHash: String) {
        let now = currentWalletTimestamp()
        let existing = self.walletTransferHashStates[msgHash].flatMap { $0.expiresAt > now ? $0 : nil }
        var state = existing ?? WalletTransferHashState(
            expiresAt: walletPendingTransferUIExpirationTimestamp(from: now), nextAttemptAt: now, transactions: []
        )
        state.transactions = mergeTransactions(existing: state.transactions, new: [transaction])
        self.walletTransferHashStates[msgHash] = state
    }

    func receiveWalletTransferUpdates(_ updates: [WalletTransferUpdate], walletAddress: String?) async {
        guard !self.isShutdown, let walletAddress, case let .wallet(info) = self.currentState.phase,
              walletEngineAddressesEqual(info.address, walletAddress) else { return }
        let generation = self.activationGeneration
        for update in updates {
            guard !Task.isCancelled, !self.isShutdown, self.activationGeneration == generation else { return }
            switch update {
            case let .gaslessInfo(info):
                self.applyGaslessInfo(info)
            case let .sentTransaction(transfer, apiTransaction):
                let now = currentWalletTimestamp()
                if let state = self.walletTransferHashStates[transfer.msgHash], state.expiresAt <= now {
                    self.walletTransferHashStates[transfer.msgHash] = nil
                }
                if let apiTransaction, let transaction = walletTransactions(from: [apiTransaction]).first {
                    self.rememberWalletFinalTransaction(transaction, msgHash: transfer.msgHash)
                    let candidates = self.currentState.pendingTransfers.filter {
                        $0.sentTransfer?.msgHash == transfer.msgHash
                            && walletTransferResolutionCandidate($0, transactions: [transaction], history: self.currentState.transactions.items) != nil
                    }
                    await self.applyWalletFinalTransaction(transaction, pending: candidates.count == 1 ? candidates[0] : nil, generation: generation)
                    guard !self.isShutdown, self.activationGeneration == generation else { return }
                    self.requestSynchronization(scope: [.account], force: true)
                } else if self.walletTransferHashStates[transfer.msgHash] == nil {
                    self.walletTransferHashStates[transfer.msgHash] = WalletTransferHashState(
                        expiresAt: walletPendingTransferUIExpirationTimestamp(from: now),
                        nextAttemptAt: Int32(clamping: Int64(now) + Int64(walletTransferResolutionInterval)), transactions: []
                    )
                }
            }
        }
        self.evaluateWalletTransferResolution()
    }
}
