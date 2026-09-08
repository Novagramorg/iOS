import Foundation
import SwiftSignalKit
import TelegramCore
import WalletEngineFFI

private let walletOwnershipProofDomain = "telegram.org"

func acceptedWalletEngineSubmission(
    pending: WalletContext.PendingTransfer,
    messageHash: String?,
    phase: SendPhase,
    acceptedAt: Int32,
    sentTransfer: WalletSentTransfer? = nil
) -> WalletContext.PendingTransfer? {
    let status: WalletContext.PendingTransfer.Status
    switch phase {
    case .submitted:
        status = .pending
    case .submissionUnknown:
        status = .submissionUnknown
    case .confirmed:
        status = .confirmed
    case .idle, .validating, .authorizing, .preparing, .persisting, .readyToSubmit,
         .submitting, .handedOff, .replaced, .sequenceNumberConsumed, .expired,
         .superseded, .failed, .cancelled:
        return nil
    }
    return WalletContext.PendingTransfer(
        id: pending.id,
        recipient: pending.recipient,
        amount: pending.amount,
        comment: pending.comment,
        commentEncrypted: pending.commentEncrypted,
        collectibleAddress: pending.collectibleAddress,
        normalizedHash: messageHash ?? pending.normalizedHash,
        sentTransfer: sentTransfer ?? pending.sentTransfer,
        pendingMessage: pending.pendingMessage,
        fee: pending.fee,
        transactionHash: pending.transactionHash,
        transactionLt: pending.transactionLt,
        uiExpiresAt: walletPendingTransferUIExpirationTimestamp(from: acceptedAt),
        createdAt: pending.createdAt,
        status: status
    )
}

private func walletEngineSendPhaseIsTerminal(_ phase: SendPhase) -> Bool {
    switch phase {
    case .replaced, .sequenceNumberConsumed, .expired, .superseded, .failed, .cancelled:
        return true
    case .idle, .validating, .authorizing, .preparing, .persisting, .readyToSubmit,
         .submitting, .submissionUnknown, .submitted, .confirmed, .handedOff:
        return false
    }
}

private func walletServerIdentity(_ state: TelegramCore.WalletState) throws -> (address: String, publicKey: Data) {
    switch state {
    case let .ready(_, _, _, address, publicKey, _):
        guard publicKey.count == 32 else {
            throw WalletContext.WalletError.storage(.identityMismatch)
        }
        return (address, publicKey)
    case .empty:
        throw WalletContext.WalletError.replacementInvalid
    }
}

func stageRecoveryPhraseImport(
    runtime: WalletEngineRuntime,
    words: [String],
    sourceAddress: String,
    sourcePublicKey: Data
) async throws -> WalletContext.PreparedRecoveryPhraseImport {
    let normalizedWords = normalizedEngineMnemonic(words)
    guard detectMnemonicSchemes(words: normalizedWords).contains(.rotation) else {
        throw WalletContext.WalletError.invalidMnemonic
    }
    let staged = try await runtime.stageTransientReplacement(words: normalizedWords)
    let disposition: WalletContext.PreparedRecoveryPhraseImport.Disposition
    if walletEngineAddressesEqual(staged.address, sourceAddress),
       staged.publicKey == sourcePublicKey {
        disposition = .currentWallet
    } else {
        disposition = .replacement
    }
    return WalletContext.PreparedRecoveryPhraseImport(
        disposition: disposition,
        recordId: staged.recordId,
        sourceAddress: sourceAddress,
        sourcePublicKey: sourcePublicKey,
        candidateAddress: staged.address,
        candidatePublicKey: staged.publicKey
    )
}

public extension WalletContext {
    static func isTonConnectUrl(_ value: String) -> Bool {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased() else {
            return false
        }
        let isUniversalLink = scheme == "https"
            && components.path.lowercased().split(separator: "/").last == "ton-connect"
        guard scheme == "tg" || scheme == "tc" || isUniversalLink else { return false }
        let parameters = Dictionary(
            (components.queryItems ?? []).compactMap { item in item.value.map { (item.name, $0) } },
            uniquingKeysWith: { current, _ in current }
        )
        return parameters["v"] == "2"
            && parameters["id"]?.isEmpty == false
            && parameters["r"]?.isEmpty == false
    }

    static func transferAddress(from value: String) -> String? {
        normalizedMainnetAddress(value)
    }

    static func transferRecipient(from value: String) -> ResolvedTransferRecipient? {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let address = normalizedMainnetAddress(value) else {
            return nil
        }
        return ResolvedTransferRecipient(
            address: address,
            displayName: nil,
            transferLink: value.lowercased().hasPrefix("ton://") ? value : nil
        )
    }

    func rememberWalletPeer(_ peer: EnginePeer, address: String) {
        let mapping = WalletPeerAddressMapping(peer: peer, address: address)
        Task { [impl = self.impl, mapping] in
            await impl.rememberWalletPeer(mapping)
        }
    }

    func resolveTransferRecipient(_ value: String) -> Signal<ResolvedTransferRecipient?, WalletError> {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return .single(nil) }
        if let recipient = Self.transferRecipient(from: value) {
            return .single(recipient)
        }
        let lowercaseValue = value.lowercased()
        guard (lowercaseValue.hasSuffix(".ton") || lowercaseValue.hasSuffix(".t.me")),
              !value.unicodeScalars.contains(where: CharacterSet.whitespacesAndNewlines.contains) else {
            return .single(nil)
        }
        return self.signal(name: "resolve_transfer_recipient") { impl, _ in
            try await impl.resolveTransferRecipient(value)
        }
    }

    func processTonConnectUrl(_ value: String) {
        guard Self.isTonConnectUrl(value) else { return }
        Task { [impl = self.impl] in
            await impl.processTonConnectUrl(value)
        }
    }

    func approveTonConnectRequest(id: String) -> Signal<Void, WalletError> {
        self.signal(name: "approve_ton_connect_request") { impl, _ in
            try await impl.approveTonConnectRequest(id: id)
        }
    }

    func approveTonConnectOperation(id: String) -> Signal<Void, WalletError> {
        self.signal(name: "approve_ton_connect_operation") { impl, _ in
            try await impl.approveTonConnectOperation(id: id)
        }
    }

    func rejectTonConnectRequest(id: String) -> Signal<Void, NoError> {
        self.noErrorSignal { impl in
            await impl.rejectTonConnectRequest(id: id)
        }
    }

    func setFiatCurrency(_ currency: FiatCurrency) {
        let revision = self.fiatCurrencyRevision.modify { $0 &+ 1 }
        Task { [impl = self.impl] in
            await impl.setFiatCurrency(currency, revision: revision)
        }
    }

    func isMnemonicWord(_ word: String) -> Bool {
        let word = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return mnemonicWordlist().contains(word)
    }

    func mnemonicWordSuggestions(for prefix: String, limit: Int) -> [String] {
        let prefix = prefix.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prefix.isEmpty, limit > 0 else { return [] }
        return Array(mnemonicWordlist().lazy.filter { $0.hasPrefix(prefix) }.prefix(limit))
    }

    func isMnemonicValid(words: [String]) -> Bool {
        detectMnemonicSchemes(words: normalizedEngineMnemonic(words)).contains(.rotation)
    }

    func createWallet(password: String? = nil) -> Signal<WalletInfo, WalletError> {
        self.signal(name: "creating", cancelOnDispose: false) { impl, operationId in
            try await impl.createWallet(password: password, operationId: operationId)
        }
    }

    func importWallet(words: [String], password: String? = nil) -> Signal<WalletInfo, WalletError> {
        self.signal(name: "importing", cancelOnDispose: false) { impl, operationId in
            try await impl.importWallet(words: words, password: password, operationId: operationId)
        }
    }

    func recoveryPhrase(password: String? = nil) -> Signal<[String], WalletError> {
        self.signal(name: "recovering_phrase", cancelOnDispose: false) { impl, operationId in
            try await impl.recoveryPhrase(password: password, operationId: operationId)
        }
    }

    func prepareRecoveryPhraseImport(words: [String]) -> Signal<PreparedRecoveryPhraseImport, WalletError> {
        self.signal(name: "preparing_recovery_phrase_import") { impl, operationId in
            try await impl.prepareRecoveryPhraseImport(words: words, operationId: operationId)
        }
    }

    func completeRecoveryPhraseImport(
        _ prepared: PreparedRecoveryPhraseImport,
        password: String? = nil
    ) -> Signal<WalletInfo, WalletError> {
        self.signal(name: "completing_recovery_phrase_import", cancelOnDispose: false) { impl, operationId in
            try await impl.completeRecoveryPhraseImport(prepared, password: password, operationId: operationId)
        }
    }

    func discardRecoveryPhraseImport(_ prepared: PreparedRecoveryPhraseImport) -> Signal<Void, WalletError> {
        self.signal(name: "discard_recovery_phrase_import", cancelOnDispose: false) { impl, _ in
            try await impl.discardRecoveryPhraseImport(prepared)
        }
    }

    func enableBackup(password: String? = nil) -> Signal<WalletInfo, WalletError> {
        self.signal(name: "enabling_backup", cancelOnDispose: false) { impl, operationId in
            try await impl.enableBackup(password: password, operationId: operationId)
        }
    }

    func prepareDisableBackup() -> Signal<PreparedBackupDisable, WalletError> {
        self.signal(name: "preparing_backup_disable") { impl, operationId in
            try await impl.prepareDisableBackup(operationId: operationId)
        }
    }

    func disableBackup(_ prepared: PreparedBackupDisable, password: String? = nil) -> Signal<WalletInfo, WalletError> {
        self.signal(name: "disabling_backup", cancelOnDispose: false) { impl, operationId in
            try await impl.disableBackup(prepared, password: password, operationId: operationId)
        }
    }

    func prepareTransfer(address: String, amount: Int64, sendAll: Bool = false, comment: String?, commentEncrypted: Bool = false) -> Signal<PreparedTransfer, WalletError> {
        self.signal(name: "preparing_transfer") { impl, operationId in
            try await impl.prepareTransfer(
                address: address,
                amount: amount,
                sendAll: sendAll,
                comment: comment,
                commentEncrypted: commentEncrypted,
                operationId: operationId
            )
        }
    }

    func decryptTransactionComment(_ transaction: Transaction) -> Signal<String, WalletError> {
        self.signal(name: "decrypting_comment") { impl, operationId in
            try await impl.decryptTransactionComment(transaction, operationId: operationId)
        }
    }

    func prepareCollectibleTransfer(
        address: String,
        collectible: Collectible,
        comment: String?
    ) -> Signal<PreparedTransfer, WalletError> {
        self.signal(name: "preparing_transfer") { impl, operationId in
            try await impl.prepareCollectibleTransfer(
                address: address,
                collectible: collectible,
                comment: comment,
                operationId: operationId
            )
        }
    }

    func submitTransfer(_ prepared: PreparedTransfer, recipientPeerId: EnginePeer.Id? = nil) -> Signal<PendingTransfer, WalletError> {
        self.signal(name: "submitting_transfer", cancelOnDispose: false) { impl, operationId in
            try await impl.submitTransfer(prepared, recipientPeerId: recipientPeerId, operationId: operationId)
        }
    }

    func discardPreparedTransfer(_ prepared: PreparedTransfer) -> Signal<Void, WalletError> {
        self.signal(name: "discarding_prepared_transfer", cancelOnDispose: false) { impl, _ in
            await impl.discardPreparedTransfer(prepared)
        }
    }

    func loadMoreTransactions() -> Signal<Void, WalletError> {
        self.signal(name: "loading_more_transactions") { impl, operationId in
            try await impl.loadMoreTransactions(operationId: operationId)
        }
    }

    func loadMoreCollectibles() -> Signal<Void, WalletError> {
        self.signal(name: "loading_more_collectibles") { impl, operationId in
            try await impl.loadMoreCollectibles(operationId: operationId)
        }
    }
}

extension WalletContextImpl {
    private func replaceWalletWithImportedCandidate(
        recordId: String,
        publicKey: Data,
        password: String?
    ) async throws -> TelegramCore.WalletState {
        guard publicKey.count == 32 else {
            throw WalletError.publicKeyInvalid
        }
        let challenge = try await WalletSignalRequestContext<TelegramCore.WalletProofChallenge>().run(
            self.engine.wallet.getProofChallenge()
        )
        guard challenge.domain == walletOwnershipProofDomain, challenge.timestamp > 0 else {
            throw WalletError.proofInvalid
        }
        guard challenge.expires > challenge.timestamp else {
            throw WalletError.proofExpired
        }
        let signature = try await self.runtime.signReplacementProof(
            recordId: recordId,
            expectedPublicKey: publicKey,
            domain: challenge.domain,
            timestamp: UInt64(challenge.timestamp),
            payload: challenge.payload
        )
        guard signature.count == 64 else {
            throw WalletError.proofInvalid
        }
        return try await WalletSignalRequestContext<TelegramCore.WalletState>().run(
            self.engine.wallet.replaceWallet(
                replacement: .imported(
                    publicKey: publicKey,
                    proof: TelegramCore.WalletOwnershipProof(
                        timestamp: challenge.timestamp,
                        signature: signature
                    )
                ),
                password: password
            )
        )
    }

    func resolveTransferRecipient(_ value: String) async throws -> ResolvedTransferRecipient? {
        guard !self.isShutdown else { throw WalletError.unavailable }
        guard let address = try await self.runtime.resolveDns(value.lowercased()),
              let normalized = normalizedMainnetAddress(address) else {
            return nil
        }
        return ResolvedTransferRecipient(address: normalized, displayName: value)
    }

    func processTonConnectUrl(_ value: String) async {
        guard !self.isShutdown,
              case let .wallet(info) = self.currentState.phase,
              info.canSign,
              let coordinator = self.tonConnectCoordinator else {
            return
        }
        do {
            try await coordinator.start(link: value)
        } catch {
            self.logger.error("wallet_ton_connect_start_failed", error)
            self.output.publish(presentation: .error(
                sanitizedWalletEngineDiagnostic(String(describing: error))
            ))
        }
    }

    func approveTonConnectRequest(id: String) async throws {
        guard !self.isShutdown,
              case let .wallet(info) = self.currentState.phase,
              info.canSign,
              let coordinator = self.tonConnectCoordinator else {
            throw WalletError.unavailable
        }
        try await coordinator.approveConnection(id: id)
    }

    func approveTonConnectOperation(id: String) async throws {
        guard !self.isShutdown,
              case let .wallet(info) = self.currentState.phase,
              info.canSign,
              let coordinator = self.tonConnectCoordinator else {
            throw WalletError.unavailable
        }
        let method = try await coordinator.approveOperation(id: id)
        if method == .sendTransaction {
            self.requestSynchronization(scope: .all, force: true)
        }
    }

    func rejectTonConnectRequest(id: String) async {
        guard !self.isShutdown else { return }
        await self.tonConnectCoordinator?.reject(id: id)
    }

    func setFiatCurrency(_ currency: FiatCurrency, revision: UInt64) {
        guard !self.isShutdown else { return }
        guard revision > self.latestFiatCurrencyRevision else { return }
        self.latestFiatCurrencyRevision = revision
        guard self.currentState.fiat.selectedCurrency != currency else { return }
        self.replaceState(
            phase: self.currentState.phase,
            balance: self.currentState.balance,
            transactions: self.currentState.transactions,
            pendingTransfers: self.currentState.pendingTransfers,
            activeOperation: self.currentState.activeOperation,
            fiat: FiatState(selectedCurrency: currency, rates: self.currentState.fiat.rates)
        )
    }

    func createWallet(password: String?, operationId: UUID) async throws -> WalletInfo {
        return try await self.performOperation(.creating, operationId: operationId) {
            let state = try await WalletSignalRequestContext<TelegramCore.WalletState>().run(
                self.engine.wallet.replaceWallet(replacement: .new, password: password)
            )
            let identity = try walletServerIdentity(state)
            let generation = await self.prepareForRuntimeIdentityChange()
            let words: [String]
            do {
                words = try await exportWalletSecretPhrase(
                    engine: self.engine,
                    password: password,
                    expectedPublicKey: identity.publicKey
                )
            } catch {
                // Replacement has already committed on the server. Keep the new
                // identity usable as read-only and let recovery retry later.
                let activation = try await self.runtime.activate(
                    serverAddress: identity.address,
                    serverPublicKey: identity.publicKey
                )
                _ = self.installRuntimeActivation(state: state, activation: activation, generation: generation)
                throw error
            }
            let staged = try await self.runtime.stageReplacement(words: words)
            guard walletEngineAddressesEqual(staged.address, identity.address),
                  staged.publicKey == identity.publicKey else {
                await self.discardReplacementForCleanup(recordId: staged.recordId)
                let activation = try await self.runtime.activate(
                    serverAddress: identity.address,
                    serverPublicKey: identity.publicKey
                )
                _ = self.installRuntimeActivation(state: state, activation: activation, generation: generation)
                throw WalletError.storage(.identityMismatch)
            }
            let activation = try await self.runtime.commitReplacement(
                recordId: staged.recordId,
                serverAddress: identity.address,
                serverPublicKey: identity.publicKey
            )
            return self.installRuntimeActivation(state: state, activation: activation, generation: generation)
        }
    }

    func importWallet(words: [String], password: String?, operationId: UUID) async throws -> WalletInfo {
        return try await self.performOperation(.importing, operationId: operationId) {
            let normalizedWords = normalizedEngineMnemonic(words)
            guard detectMnemonicSchemes(words: normalizedWords).contains(.rotation) else {
                throw WalletError.invalidMnemonic
            }
            let staged = try await self.runtime.stageTransientReplacement(words: normalizedWords)
            let state: TelegramCore.WalletState
            do {
                state = try await self.replaceWalletWithImportedCandidate(
                    recordId: staged.recordId,
                    publicKey: staged.publicKey,
                    password: password
                )
            } catch let error as TelegramCore.WalletOperationError {
                if error == .network {
                    try await self.runtime.persistReplacementCandidate(recordId: staged.recordId)
                } else {
                    await self.discardReplacementForCleanup(recordId: staged.recordId)
                }
                throw error
            } catch {
                await self.discardReplacementForCleanup(recordId: staged.recordId)
                throw error
            }
            let identity: (address: String, publicKey: Data)
            do {
                identity = try walletServerIdentity(state)
            } catch {
                await self.discardReplacementForCleanup(recordId: staged.recordId)
                throw error
            }
            guard walletEngineAddressesEqual(staged.address, identity.address),
                  staged.publicKey == identity.publicKey else {
                await self.discardReplacementForCleanup(recordId: staged.recordId)
                throw WalletError.storage(.identityMismatch)
            }
            let generation = await self.prepareForRuntimeIdentityChange()
            let activation = try await self.runtime.commitReplacement(
                recordId: staged.recordId,
                serverAddress: identity.address,
                serverPublicKey: identity.publicKey
            )
            return self.installRuntimeActivation(state: state, activation: activation, generation: generation)
        }
    }

    func recoveryPhrase(password: String?, operationId: UUID) async throws -> [String] {
        return try await self.performOperation(.recoveringPhrase, operationId: operationId) {
            guard case let .wallet(info) = self.currentState.phase, info.canRevealPhrase else {
                throw WalletError.unavailable
            }
            if info.canSign {
                return try await self.runtime.revealRecoveryPhrase()
            }
            guard info.canExportPhrase,
                  case let .ready(_, _, _, address, publicKey, _) = self.serverWalletState else {
                throw WalletError.unavailable
            }
            let words = try await exportWalletSecretPhrase(
                engine: self.engine,
                password: password,
                expectedPublicKey: publicKey
            )
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
            let generation = await self.prepareForRuntimeIdentityChange(
                preserveCurrentWalletState: true
            )
            let activation: WalletEngineActivation
            do {
                activation = try await self.runtime.commitReplacement(
                    recordId: prepared.recordId,
                    serverAddress: address,
                    serverPublicKey: publicKey
                )
            } catch {
                await self.discardReplacementForCleanup(recordId: prepared.recordId)
                throw error
            }
            if let state = self.serverWalletState {
                _ = self.installRuntimeActivation(
                    state: state,
                    activation: activation,
                    generation: generation,
                    preserveCurrentWalletState: true
                )
            }
            return words
        }
    }

    func prepareRecoveryPhraseImport(words: [String], operationId: UUID) async throws -> PreparedRecoveryPhraseImport {
        return try await self.performOperation(.preparingRecoveryPhraseImport, operationId: operationId) {
            guard let state = self.serverWalletState else {
                throw WalletError.noWallet
            }
            let sourceIdentity = try walletServerIdentity(state)
            let prepared = try await stageRecoveryPhraseImport(
                runtime: self.runtime,
                words: words,
                sourceAddress: sourceIdentity.address,
                sourcePublicKey: sourceIdentity.publicKey
            )
            self.preparedRecoveryPhraseImportRecordId = prepared.recordId
            return prepared
        }
    }

    func completeRecoveryPhraseImport(
        _ prepared: PreparedRecoveryPhraseImport,
        password: String?,
        operationId: UUID
    ) async throws -> WalletInfo {
        return try await self.performOperation(.completingRecoveryPhraseImport, operationId: operationId) {
            guard let currentServerState = self.serverWalletState else {
                throw WalletError.noWallet
            }
            let currentIdentity: (address: String, publicKey: Data)
            do {
                currentIdentity = try walletServerIdentity(currentServerState)
            } catch {
                if self.preparedRecoveryPhraseImportRecordId == prepared.recordId {
                    self.preparedRecoveryPhraseImportRecordId = nil
                }
                await self.discardReplacementForCleanup(recordId: prepared.recordId)
                throw error
            }
            guard walletEngineAddressesEqual(currentIdentity.address, prepared.sourceAddress),
                  currentIdentity.publicKey == prepared.sourcePublicKey else {
                if self.preparedRecoveryPhraseImportRecordId == prepared.recordId {
                    self.preparedRecoveryPhraseImportRecordId = nil
                }
                await self.discardReplacementForCleanup(recordId: prepared.recordId)
                throw WalletError.storage(.identityMismatch)
            }

            switch prepared.disposition {
            case .currentWallet:
                guard walletEngineAddressesEqual(prepared.candidateAddress, currentIdentity.address),
                      prepared.candidatePublicKey == currentIdentity.publicKey else {
                    if self.preparedRecoveryPhraseImportRecordId == prepared.recordId {
                        self.preparedRecoveryPhraseImportRecordId = nil
                    }
                    await self.discardReplacementForCleanup(recordId: prepared.recordId)
                    throw WalletError.storage(.identityMismatch)
                }
                if self.preparedRecoveryPhraseImportRecordId == prepared.recordId {
                    self.preparedRecoveryPhraseImportRecordId = nil
                }
                let generation = await self.prepareForRuntimeIdentityChange(
                    preserveCurrentWalletState: true
                )
                let activation: WalletEngineActivation
                do {
                    activation = try await self.runtime.commitReplacement(
                        recordId: prepared.recordId,
                        serverAddress: currentIdentity.address,
                        serverPublicKey: currentIdentity.publicKey
                    )
                } catch {
                    await self.discardReplacementForCleanup(recordId: prepared.recordId)
                    throw error
                }
                return self.installRuntimeActivation(
                    state: currentServerState,
                    activation: activation,
                    generation: generation,
                    preserveCurrentWalletState: true
                )

            case .replacement:
                let state: TelegramCore.WalletState
                do {
                    state = try await self.replaceWalletWithImportedCandidate(
                        recordId: prepared.recordId,
                        publicKey: prepared.candidatePublicKey,
                        password: password
                    )
                } catch let error as TelegramCore.WalletOperationError {
                    switch error {
                    case .requestPassword, .invalidPassword, .twoStepAuthMissing:
                        break
                    case .network:
                        try await self.runtime.persistReplacementCandidate(recordId: prepared.recordId)
                        if self.preparedRecoveryPhraseImportRecordId == prepared.recordId {
                            self.preparedRecoveryPhraseImportRecordId = nil
                        }
                    default:
                        if self.preparedRecoveryPhraseImportRecordId == prepared.recordId {
                            self.preparedRecoveryPhraseImportRecordId = nil
                        }
                        await self.discardReplacementForCleanup(recordId: prepared.recordId)
                    }
                    throw error
                } catch {
                    if self.preparedRecoveryPhraseImportRecordId == prepared.recordId {
                        self.preparedRecoveryPhraseImportRecordId = nil
                    }
                    await self.discardReplacementForCleanup(recordId: prepared.recordId)
                    throw error
                }
                let replacementIdentity: (address: String, publicKey: Data)
                do {
                    replacementIdentity = try walletServerIdentity(state)
                } catch {
                    if self.preparedRecoveryPhraseImportRecordId == prepared.recordId {
                        self.preparedRecoveryPhraseImportRecordId = nil
                    }
                    await self.discardReplacementForCleanup(recordId: prepared.recordId)
                    throw error
                }
                guard walletEngineAddressesEqual(prepared.candidateAddress, replacementIdentity.address),
                      prepared.candidatePublicKey == replacementIdentity.publicKey else {
                    if self.preparedRecoveryPhraseImportRecordId == prepared.recordId {
                        self.preparedRecoveryPhraseImportRecordId = nil
                    }
                    await self.discardReplacementForCleanup(recordId: prepared.recordId)
                    throw WalletError.storage(.identityMismatch)
                }
                if self.preparedRecoveryPhraseImportRecordId == prepared.recordId {
                    self.preparedRecoveryPhraseImportRecordId = nil
                }
                let generation = await self.prepareForRuntimeIdentityChange()
                let activation = try await self.runtime.commitReplacement(
                    recordId: prepared.recordId,
                    serverAddress: replacementIdentity.address,
                    serverPublicKey: replacementIdentity.publicKey
                )
                return self.installRuntimeActivation(
                    state: state,
                    activation: activation,
                    generation: generation
                )
            }
        }
    }

    func discardRecoveryPhraseImport(_ prepared: PreparedRecoveryPhraseImport) async throws {
        guard !self.isShutdown else { throw WalletError.unavailable }
        if self.preparedRecoveryPhraseImportRecordId == prepared.recordId {
            self.preparedRecoveryPhraseImportRecordId = nil
        }
        try await self.runtime.discardReplacement(recordId: prepared.recordId)
    }

    func enableBackup(password: String?, operationId: UUID) async throws -> WalletInfo {
        return try await self.performOperation(.enablingBackup, operationId: operationId) {
            guard case let .wallet(info) = self.currentState.phase,
                  info.canSign,
                  info.canEnableBackup else {
                throw WalletError.unavailable
            }
            let words = try await self.runtime.revealRecoveryPhrase()
            let state = try await enableWalletBackup(engine: self.engine, words: words, password: password)
            let identity = try walletServerIdentity(state)
            guard walletEngineAddressesEqual(identity.address, info.address),
                  identity.publicKey.map({ String(format: "%02x", $0) }).joined() == info.publicKey else {
                throw WalletError.storage(.identityMismatch)
            }
            self.applyServerWalletState(state)
            guard case let .wallet(updated) = self.currentState.phase else {
                throw WalletError.unavailable
            }
            return updated
        }
    }

    func prepareDisableBackup(operationId: UUID) async throws -> PreparedBackupDisable {
        return try await self.performOperation(.preparingBackupDisable, operationId: operationId) {
            guard case let .wallet(info) = self.currentState.phase,
                  info.canSign,
                  info.backupEnabled else {
                throw WalletError.unavailable
            }

            if let existing = try await self.runtime.keyRotationRecord() {
                guard walletEngineAddressesEqual(existing.walletAddress, info.address),
                      existing.walletPublicKey.map({ String(format: "%02x", $0) }).joined() == info.publicKey,
                      existing.newPublicKey.count == 32,
                      existing.validUntil <= UInt64(Int32.max) else {
                    throw WalletError.storage(.identityMismatch)
                }

                if existing.phase == .candidateStored || existing.phase == .previousRestored {
                    _ = try await self.runtime.resolveKeyRotation()
                } else {
                    if existing.phase == .submissionStarted {
                        do {
                            _ = try await self.runtime.resolveKeyRotation()
                        } catch {
                            self.logger.error("wallet_key_rotation_resolution_failed", error)
                        }
                    }
                    if let current = try await self.runtime.keyRotationRecord() {
                        let words = try await self.runtime.keyRotationRecoveryPhrase(
                            operationId: current.operationId
                        )
                        guard words.count == 24 else {
                            throw WalletError.invalidBackupData
                        }
                        return PreparedBackupDisable(
                            id: current.operationId,
                            walletAddress: info.address,
                            walletPublicKey: info.publicKey,
                            words: words,
                            newPublicKey: current.newPublicKey,
                            signedBoc: "",
                            seqno: 0,
                            expiresAt: Int32(current.validUntil),
                            networkFeeNanograms: nil,
                            keyRotationPhase: current.phase == .chainApplied || current.phase == .backupDisabled
                                ? .confirmed
                                : .pending
                        )
                    }
                }
            }

            let expiresAt = currentWalletTimestamp() + 300
            let prepared = try await self.runtime.prepareKeyRotation(validUntil: UInt64(expiresAt))
            let words = prepared.replacementRecoveryPhrase.phrase
                .split(whereSeparator: { $0.isWhitespace })
                .map(String.init)
            guard words.count == 24,
                  prepared.newPublicKey.count == 32,
                  prepared.validUntil == UInt64(expiresAt),
                  !prepared.signedBoc.isEmpty else {
                throw WalletError.engine("Wallet engine returned invalid key-rotation material")
            }
            let id = UUID().uuidString.lowercased()
            let preview = try await self.runtime.previewKeyRotation(
                operationId: id,
                signedBoc: prepared.signedBoc,
                seqno: prepared.seqno,
                validUntil: prepared.validUntil
            )
            guard preview.messageBocBase64 == prepared.signedBoc,
                  preview.validUntil == prepared.validUntil,
                  !preview.emulation.isIncomplete,
                  let networkFeeNanograms = Int64(preview.emulation.walletFeesNanograms) else {
                throw WalletError.previewFailed
            }
            return PreparedBackupDisable(
                id: id,
                walletAddress: info.address,
                walletPublicKey: info.publicKey,
                words: words,
                newPublicKey: prepared.newPublicKey,
                signedBoc: prepared.signedBoc,
                seqno: prepared.seqno,
                expiresAt: expiresAt,
                networkFeeNanograms: networkFeeNanograms,
                keyRotationPhase: .prepared
            )
        }
    }

    func disableBackup(
        _ prepared: PreparedBackupDisable,
        password: String?,
        operationId: UUID
    ) async throws -> WalletInfo {
        return try await self.performOperation(.disablingBackup, operationId: operationId) {
            guard case let .wallet(info) = self.currentState.phase,
                  info.canSign,
                  info.address == prepared.walletAddress,
                  info.publicKey == prepared.walletPublicKey,
                  info.backupEnabled else {
                throw WalletError.unavailable
            }

            var rotation = try await self.runtime.keyRotationRecord()
            if rotation == nil {
                guard prepared.keyRotationPhase == .prepared,
                      prepared.expiresAt > currentWalletTimestamp(),
                      prepared.newPublicKey.count == 32,
                      !prepared.signedBoc.isEmpty else {
                    throw WalletError.unavailable
                }
                let result: SendResult
                do {
                    result = try await self.runtime.sendKeyRotation(
                        operationId: prepared.id,
                        words: prepared.words,
                        newPublicKey: prepared.newPublicKey,
                        signedBoc: prepared.signedBoc,
                        seqno: prepared.seqno,
                        validUntil: UInt64(prepared.expiresAt)
                    )
                } catch {
                    let sendError = error
                    let currentRotation: WalletEngineKeyRotationRecord?
                    do {
                        currentRotation = try await self.runtime.keyRotationRecord()
                    } catch {
                        self.logger.error("wallet_key_rotation_recovery_read_failed", error)
                        currentRotation = nil
                    }
                    if currentRotation == nil {
                        throw WalletError.keyRotationFailed
                    }
                    throw sendError
                }
                switch result.phase {
                case .submitted, .submissionUnknown, .confirmed:
                    break
                case .idle, .validating, .authorizing, .preparing, .persisting, .readyToSubmit,
                     .submitting, .handedOff, .replaced, .sequenceNumberConsumed, .expired,
                     .superseded, .failed, .cancelled:
                    throw WalletError.keyRotationFailed
                }
                rotation = try await self.runtime.keyRotationRecord()
            }

            guard let rotation,
                  rotation.operationId == prepared.id,
                  walletEngineAddressesEqual(rotation.walletAddress, info.address),
                  rotation.walletPublicKey.map({ String(format: "%02x", $0) }).joined() == info.publicKey else {
                throw WalletError.operationInProgress
            }
            let (resolutionDeadline, deadlineOverflow) = rotation.validUntil.addingReportingOverflow(120)
            guard !deadlineOverflow else {
                throw WalletError.invalidBackupData
            }

            while true {
                let resolution = try await self.runtime.resolveKeyRotation()
                switch resolution {
                case let .confirmed(operationId):
                    guard operationId == prepared.id else {
                        throw WalletError.operationInProgress
                    }
                    break
                case let .pending(operationId, retryAfterMilliseconds):
                    guard operationId == prepared.id else {
                        throw WalletError.operationInProgress
                    }
                    let now = UInt64(max(0, Date().timeIntervalSince1970.rounded(.down)))
                    guard now <= resolutionDeadline else {
                        throw WalletError.network
                    }
                    let delay = min(5_000, max(500, retryAfterMilliseconds ?? 1_000))
                    try await Task.sleep(nanoseconds: delay * 1_000_000)
                    continue
                case let .rolledBack(operationId, _):
                    guard operationId == prepared.id else {
                        throw WalletError.operationInProgress
                    }
                    throw WalletError.keyRotationFailed
                case .none:
                    throw WalletError.unavailable
                }
                break
            }

            let state = try await WalletSignalRequestContext<TelegramCore.WalletState>().run(
                self.engine.wallet.disableBackup(password: password)
            )
            guard case let .ready(backupEnabled, _, _, _, _, _) = state, !backupEnabled else {
                throw WalletError.invalidBackupData
            }
            let identity = try walletServerIdentity(state)
            guard walletEngineAddressesEqual(identity.address, info.address),
                  identity.publicKey.map({ String(format: "%02x", $0) }).joined() == info.publicKey else {
                throw WalletError.storage(.identityMismatch)
            }
            try await self.runtime.completeKeyRotationAfterBackupDisabled(operationId: prepared.id)
            self.applyServerWalletState(state)
            guard case let .wallet(updated) = self.currentState.phase else {
                throw WalletError.unavailable
            }
            return updated
        }
    }

    func prepareTransfer(
        address: String,
        amount: Int64,
        sendAll: Bool,
        comment: String?,
        commentEncrypted: Bool,
        operationId: UUID
    ) async throws -> PreparedTransfer {
        return try await self.performOperation(.preparingTransfer, operationId: operationId) {
            guard case let .wallet(info) = self.currentState.phase,
                  info.canSign else {
                throw WalletError.unavailable
            }
            let resolved = try resolveTransferInput(address: address, amount: amount, comment: comment)
            self.requestGaslessInfo()
            let activationGeneration = self.activationGeneration
            let encryptComment = commentEncrypted && resolved.comment != nil
            let body: SendMessageBody
            if encryptComment, let comment = resolved.comment {
                guard comment.utf8.count <= 960 else {
                    throw WalletError.commentTooLong
                }
                let boc: String
                do {
                    boc = try await self.runtime.createEncryptedComment(recipient: resolved.address, comment: comment)
                } catch {
                    try Task.checkCancellation()
                    self.logger.error("wallet_comment_encryption_failed", error)
                    if let error = error as? WalletClientError, case .EncryptedCommentUnavailable = error {
                        throw WalletError.commentEncryptionRecipientUnavailable
                    }
                    throw WalletError.commentEncryptionFailed
                }
                try Task.checkCancellation()
                guard let data = Data(base64Encoded: boc) else {
                    throw WalletError.commentEncryptionFailed
                }
                guard data.count <= 1024 else {
                    throw WalletError.commentTooLong
                }
                body = .rawPayload(boc: boc)
            } else {
                body = resolved.body
            }
            let resolvedSendAll = sendAll && !resolved.hasLinkAmount
            let sendAmount: SendAmount = resolvedSendAll
                ? .all
                : .exact(nanograms: String(resolved.amount))
            let intent = SendIntent(
                expiration: resolved.expiration,
                messages: [SendMessage(
                    destination: resolved.address,
                    amount: sendAmount,
                    body: body,
                    bounce: false,
                    stateInit: nil
                )]
            )
            let preview = try await self.runtime.previewSend(intent: intent)
            try Task.checkCancellation()
            guard self.activationGeneration == activationGeneration else { throw WalletError.unavailable }
            guard !preview.emulation.isIncomplete else { throw WalletError.previewIncomplete }
            guard let fee = Int64(preview.emulation.walletFeesNanograms) else { throw WalletError.previewFailed }
            let effectiveAmount: Int64
            if resolvedSendAll {
                guard fee < resolved.amount else {
                    throw WalletError.insufficientBalance(required: resolved.amount)
                }
                effectiveAmount = resolved.amount - fee
            } else {
                if let balance = self.currentState.balance.currentValue,
                   resolved.amount > balance || fee > balance - resolved.amount {
                    let (required, overflow) = resolved.amount.addingReportingOverflow(fee)
                    throw WalletError.insufficientBalance(required: overflow ? Int64.max : required)
                }
                effectiveAmount = resolved.amount
            }
            let transfer = PreparedTransfer(
                id: UUID().uuidString.lowercased(),
                recipient: resolved.address,
                amount: effectiveAmount,
                requestedAmount: resolved.amount,
                isSendAll: resolvedSendAll,
                comment: resolved.comment,
                commentEncrypted: encryptComment,
                fee: fee,
                expiresAt: Int32(clamping: preview.validUntil)
            )
            self.preparedTransfers[transfer.id] = PreparedEngineTransferRecord(
                walletAddress: info.address,
                transfer: transfer,
                request: .send(intent)
            )
            self.removeExpiredPreparedTransfers()
            return transfer
        }
    }

    func decryptTransactionComment(
        _ transaction: WalletContext.Transaction,
        operationId: UUID
    ) async throws -> String {
        try await self.performOperation(.decryptingComment, operationId: operationId) {
            guard case let .wallet(info) = self.currentState.phase, info.canSign else {
                throw WalletError.unavailable
            }
            guard transaction.commentEncrypted,
                  let encryptedComment = transaction.comment,
                  let body = encryptedCommentBoc(encryptedComment) else {
                throw WalletError.commentDecryptionFailed
            }
            let sender: String
            switch transaction.direction {
            case .incoming:
                guard let address = transaction.peer.address else { throw WalletError.commentDecryptionFailed }
                sender = address
            case .outgoing:
                sender = info.address
            case .unknown:
                throw WalletError.commentDecryptionFailed
            }
            let activationGeneration = self.activationGeneration
            let comment: String
            do {
                comment = try await self.runtime.decryptComment(sender: sender, body: body)
            } catch {
                try Task.checkCancellation()
                self.logger.error("wallet_comment_decryption_failed", error)
                throw WalletError.commentDecryptionFailed
            }
            try Task.checkCancellation()
            guard self.activationGeneration == activationGeneration else { throw WalletError.unavailable }
            return comment
        }
    }

    func prepareCollectibleTransfer(
        address: String,
        collectible: Collectible,
        comment: String?,
        operationId: UUID
    ) async throws -> PreparedTransfer {
        return try await self.performOperation(.preparingTransfer, operationId: operationId) {
            guard case let .wallet(info) = self.currentState.phase,
                  info.canSign,
                  let recipient = normalizedMainnetAddress(address),
                  let nft = normalizedMainnetAddress(collectible.address) else {
                throw WalletError.invalidAddress
            }
            let normalizedComment = comment?.trimmingCharacters(in: .whitespacesAndNewlines)
            let payload: NftTransferPayload = normalizedComment?.isEmpty == false
                ? .comment(text: normalizedComment!)
                : .empty
            let intent = NftTransferIntent(
                nftAddress: nft,
                recipient: recipient,
                funding: .exact(attachedNanograms: "100000001", forwardNanograms: "1"),
                payload: payload,
                expiration: .engineDefault
            )
            let id = UUID().uuidString.lowercased()
            let preview = try await self.runtime.previewNft(operationId: id, intent: intent)
            try Task.checkCancellation()
            guard !preview.emulation.isIncomplete else { throw WalletError.previewIncomplete }
            guard let fee = Int64(preview.emulation.walletFeesNanograms) else { throw WalletError.previewFailed }
            let transfer = PreparedTransfer(
                id: id,
                recipient: recipient,
                amount: 0,
                comment: normalizedComment?.isEmpty == false ? normalizedComment : nil,
                collectible: collectible,
                fee: fee,
                expiresAt: Int32(clamping: preview.validUntil)
            )
            self.preparedTransfers[id] = PreparedEngineTransferRecord(
                walletAddress: info.address,
                transfer: transfer,
                request: .nft(intent)
            )
            self.removeExpiredPreparedTransfers()
            return transfer
        }
    }

    func submitTransfer(
        _ prepared: PreparedTransfer,
        recipientPeerId: EnginePeer.Id? = nil,
        operationId: UUID
    ) async throws -> PendingTransfer {
        return try await self.performOperation(.submittingTransfer, operationId: operationId) {
            guard case let .wallet(info) = self.currentState.phase,
                  info.canSign,
                  let record = self.preparedTransfers[prepared.id],
                  record.walletAddress == info.address,
                  record.transfer == prepared else {
                throw WalletError.preparedTransferNotFound
            }
            guard prepared.expiresAt > currentWalletTimestamp() else {
                self.preparedTransfers[prepared.id] = nil
                throw WalletError.preparedTransferExpired
            }
            let pendingComment: String?
            if prepared.commentEncrypted {
                guard case let .send(intent) = record.request,
                      let message = intent.messages.first,
                      case let .rawPayload(boc) = message.body else {
                    throw WalletError.preparedTransferNotFound
                }
                pendingComment = boc
            } else {
                pendingComment = prepared.comment
            }
            let activationGenerationBeforeSend = self.activationGeneration
            let createdAt = currentWalletTimestamp()
            let pendingMessage: WalletPendingTransferMessageReference?
            if let recipientPeerId, prepared.collectible == nil, WalletContext.useWalletTransferApi {
                pendingMessage = try await WalletSignalRequestContext<WalletPendingTransferMessageReference?>().run(
                    self.engine.wallet.createPendingTransferMessage(
                        peerId: recipientPeerId,
                        operationId: prepared.id,
                        amount: prepared.amount,
                        address: prepared.recipient,
                        comment: pendingComment,
                        commentEncrypted: prepared.commentEncrypted,
                        timestamp: createdAt
                    )
                    |> castError(WalletError.self)
                )
            } else {
                pendingMessage = nil
            }
            guard !Task.isCancelled, !self.isShutdown, self.activationGeneration == activationGenerationBeforeSend else {
                if let pendingMessage {
                    let _ = self.engine.wallet.removePendingTransferMessage(pendingMessage).start()
                }
                throw WalletError.unavailable
            }
            let pending = PendingTransfer(
                id: prepared.id,
                recipient: prepared.recipient,
                amount: prepared.amount,
                comment: pendingComment,
                commentEncrypted: prepared.commentEncrypted,
                collectibleAddress: prepared.collectible?.address,
                pendingMessage: pendingMessage,
                fee: prepared.fee,
                createdAt: createdAt,
                status: .broadcasting
            )
            var values = self.currentState.pendingTransfers.filter { $0.id != pending.id }
            values.append(pending)
            self.replaceState(
                phase: self.currentState.phase,
                balance: self.currentState.balance,
                transactions: self.currentState.transactions,
                pendingTransfers: values,
                activeOperation: self.currentState.activeOperation
            )
            let useWalletTransferApi = WalletContext.useWalletTransferApi
            let clientRevisionBeforeSend = await self.runtime.currentClientRevision()

            let applyAcceptedSubmission: (SendPhase, String?, WalletEngineTransferReceipt?) -> PendingTransfer? = { phase, messageHash, receipt in
                guard self.activationGeneration == activationGenerationBeforeSend,
                      case let .wallet(currentInfo) = self.currentState.phase,
                      walletEngineAddressesEqual(currentInfo.address, record.walletAddress),
                      let accepted = acceptedWalletEngineSubmission(
                    pending: pending,
                    messageHash: messageHash,
                    phase: phase,
                    acceptedAt: receipt?.receivedAt ?? currentWalletTimestamp(),
                    sentTransfer: receipt?.transfer
                ) else {
                    return nil
                }
                var updated = self.currentState.pendingTransfers.filter { $0.id != accepted.id }
                updated.append(accepted)
                self.preparedTransfers[prepared.id] = nil
                if let receipt {
                    self.applyGaslessQuota(receipt.transfer, receivedAt: receipt.receivedAt)
                }
                self.replaceState(
                    phase: self.currentState.phase,
                    balance: self.currentState.balance,
                    transactions: self.currentState.transactions,
                    pendingTransfers: updated,
                    activeOperation: self.currentState.activeOperation
                )
                if phase != .submitted || accepted.collectibleAddress != nil || self.streamingConnectionState != .subscribed {
                    self.requestSynchronization(scope: accepted.collectibleAddress == nil ? [.account, .transactions] : .all, force: true)
                }
                return accepted
            }

            do {
                let execution: WalletEngineSendExecution
                switch record.request {
                case let .send(intent):
                    execution = try await self.runtime.send(pendingTransfer: pending, intent: intent, useWalletTransferApi: useWalletTransferApi)
                case let .nft(intent):
                    execution = try await self.runtime.sendNft(operationId: prepared.id, intent: intent)
                }
                if execution.didRecreateClient {
                    await self.rebindRuntimeObservationAfterClientRecreation(
                        previousClientRevision: clientRevisionBeforeSend,
                        activationGeneration: activationGenerationBeforeSend,
                        walletAddress: record.walletAddress
                    )
                }
                let result = execution.result
                guard let submitted = applyAcceptedSubmission(result.phase, result.messageHash, execution.receipt) else {
                    if walletEngineSendPhaseIsTerminal(result.phase) {
                        self.preparedTransfers[prepared.id] = nil
                        if let pendingMessage = pending.pendingMessage {
                            let _ = self.engine.wallet.removePendingTransferMessage(pendingMessage).start()
                        }
                        throw WalletError.preparedTransferNotFound
                    }
                    throw WalletError.engine("wallet-engine send ended in \(result.phase)")
                }
                return submitted
            } catch {
                self.logger.error("wallet_send_failed", error)
                var preparedTransferWasInvalidated = false
                let snapshot: WalletSnapshot?
                do {
                    snapshot = try await self.runtime.snapshot()
                } catch {
                    self.logger.error("wallet_send_recovery_snapshot_failed", error)
                    snapshot = nil
                }
                if let snapshot {
                    let receipt = await self.runtime.transferReceipt(operationId: pending.id)
                    await self.rebindRuntimeObservationAfterClientRecreation(
                        previousClientRevision: clientRevisionBeforeSend,
                        activationGeneration: activationGenerationBeforeSend,
                        walletAddress: record.walletAddress,
                        snapshot: snapshot
                    )
                    if snapshot.send.operationId == pending.id,
                       let submitted = applyAcceptedSubmission(snapshot.send.phase, nil, receipt) {
                        return submitted
                    }
                    if snapshot.send.operationId == pending.id,
                       walletEngineSendPhaseIsTerminal(snapshot.send.phase) {
                        self.preparedTransfers[prepared.id] = nil
                        preparedTransferWasInvalidated = true
                    }
                }
                self.replaceState(
                    phase: self.currentState.phase,
                    balance: self.currentState.balance,
                    transactions: self.currentState.transactions,
                    pendingTransfers: self.currentState.pendingTransfers.filter { $0.id != pending.id },
                    activeOperation: self.currentState.activeOperation
                )
                if preparedTransferWasInvalidated {
                    if let pendingMessage = pending.pendingMessage {
                        let _ = self.engine.wallet.removePendingTransferMessage(pendingMessage).start()
                    }
                    throw WalletError.preparedTransferNotFound
                }
                throw error
            }
        }
    }

    func discardPreparedTransfer(_ prepared: PreparedTransfer) {
        guard let record = self.preparedTransfers[prepared.id], record.transfer == prepared else {
            return
        }
        self.preparedTransfers[prepared.id] = nil
        self.resumeDeferredSynchronizationIfNeeded()
    }

    func rebindRuntimeObservationAfterClientRecreation(
        previousClientRevision: UInt64,
        activationGeneration: UInt64,
        walletAddress: String,
        snapshot suppliedSnapshot: WalletSnapshot? = nil
    ) async {
        let currentClientRevision = await self.runtime.currentClientRevision()
        guard currentClientRevision != previousClientRevision,
              self.activationGeneration == activationGeneration,
              case let .wallet(info) = self.currentState.phase,
              walletEngineAddressesEqual(info.address, walletAddress) else {
            return
        }
        do {
            let snapshot: WalletSnapshot
            if let suppliedSnapshot {
                snapshot = suppliedSnapshot
            } else {
                snapshot = try await self.runtime.snapshot()
            }
            self.beginObserving(snapshot: snapshot, generation: activationGeneration)
        } catch {
            self.logger.error("wallet_engine_client_rebind_failed", error)
        }
    }

    func loadMoreTransactions(operationId: UUID) async throws {
        try await self.performOperation(.loadingMoreTransactions, operationId: operationId) {
            guard self.currentState.transactions.canLoadMore,
                  self.transactionHistory.nextPageRequest != nil else { return Void() }
            let generation = self.activationGeneration
            let streamingOverlayWatermark = self.streamingPresentationOverlay.revision
            self.updateTransactionsPagination(isLoadingMore: true, error: nil)
            do {
                try await loadWalletTransactionHistoryPages(nextRequest: {
                    try self.checkPaginationOperation(operationId, generation: generation)
                    return self.transactionHistory.nextPageRequest
                }, fetch: { offset in
                    let response = try await WalletSignalRequestContext<TelegramCore.WalletTransactions>().run(
                        self.engine.wallet.getTransactions(
                            inbound: true,
                            outbound: true,
                            offset: offset,
                            limit: Int32(walletTransactionFetchLimit)
                        )
                    )
                    return WalletTransactionHistory.Page(
                        items: walletTransactions(from: response.items),
                        nextOffset: response.nextOffset
                    )
                }, apply: { request, page in
                    try self.checkPaginationOperation(operationId, generation: generation)
                    let result = self.transactionHistory.applyPage(page, request: request, previous: self.currentState.transactions)
                    let historyReconciliation = self.pendingTransfers(
                        self.currentState.pendingTransfers,
                        reconcilingWith: result.state.items
                    )
                    let removedStreamingTraceCount = self.streamingPresentationOverlay.clearTransactions(
                        through: streamingOverlayWatermark,
                        presentIn: result.state.items,
                        resolvedTraceIds: historyReconciliation.resolvedStreamingTraceIds
                    )
                    self.logPendingTransferHistoryReconciliation(
                        historyReconciliation,
                        removedStreamingTraceCount: removedStreamingTraceCount
                    )
                    let previousState = self.currentState
                    self.replaceState(
                        phase: self.currentState.phase,
                        balance: self.currentState.balance,
                        transactions: result.state,
                        pendingTransfers: historyReconciliation.pendingTransfers,
                        activeOperation: self.currentState.activeOperation
                    )
                    if removedStreamingTraceCount != 0 && self.currentState == previousState {
                        self.publishPresentationState()
                    }
                    return result.shouldContinue
                })
            } catch {
                guard self.isCurrentPaginationOperation(operationId, generation: generation) else {
                    throw CancellationError()
                }
                let isCancelled = Task.isCancelled || error is CancellationError
                self.replaceState(
                    phase: self.currentState.phase,
                    balance: self.currentState.balance,
                    transactions: self.transactionHistory.failed(
                        isCancelled ? CancellationError() : error,
                        previous: self.currentState.transactions,
                        pagination: true
                    ),
                    pendingTransfers: self.currentState.pendingTransfers,
                    activeOperation: self.currentState.activeOperation
                )
                if isCancelled { throw CancellationError() }
                throw error
            }
        }
    }

    func loadMoreCollectibles(operationId: UUID) async throws {
        try await self.performOperation(.loadingMoreCollectibles, operationId: operationId) {
            guard self.currentState.collectibles.canLoadMore else { return Void() }
            let generation = self.activationGeneration
            let observationId = self.runtimeObservationId
            let previousRevision = self.collectiblesRevision.latest
            var resultRevision: UInt64?
            self.updateCollectiblesPagination(isLoadingMore: true, error: nil)
            do {
                let update = try await self.runtime.loadMoreNfts()
                resultRevision = update.snapshot.revision
                try self.checkPaginationOperation(operationId, generation: generation)
                let items = try await walletEngineCollectibles(update, pagination: true) { items in
                    try await walletCollectibles(from: items, logger: self.logger)
                }
                try self.checkPaginationOperation(operationId, generation: generation)
                guard self.runtimeObservationId == observationId else { throw CancellationError() }
                guard items == nil || self.collectiblesRevision.accept(update.snapshot.revision) else {
                    self.updateCollectiblesPagination(isLoadingMore: false, error: self.currentState.collectibles.error)
                    return
                }
                self.replaceState(
                    phase: self.currentState.phase,
                    balance: self.currentState.balance,
                    transactions: self.currentState.transactions,
                    collectibles: walletEngineCollectiblesState(
                        previous: self.currentState.collectibles,
                        items: items,
                        hasMore: update.snapshot.nfts.hasMore
                    ),
                    pendingTransfers: self.currentState.pendingTransfers,
                    activeOperation: self.currentState.activeOperation
                )
            } catch {
                guard self.isCurrentPaginationOperation(operationId, generation: generation),
                      self.runtimeObservationId == observationId else {
                    throw CancellationError()
                }
                let isCancelled = Task.isCancelled || error is CancellationError
                let canApply = resultRevision.map { self.collectiblesRevision.isCurrent($0) }
                    ?? (self.collectiblesRevision.latest == previousRevision)
                if !canApply {
                    self.updateCollectiblesPagination(isLoadingMore: false, error: self.currentState.collectibles.error)
                    throw error
                }
                self.replaceState(
                    phase: self.currentState.phase,
                    balance: self.currentState.balance,
                    transactions: self.currentState.transactions,
                    collectibles: walletEngineCollectiblesState(
                        previous: self.currentState.collectibles,
                        failure: isCancelled ? CancellationError() : error
                    ),
                    pendingTransfers: self.currentState.pendingTransfers,
                    activeOperation: self.currentState.activeOperation
                )
                if isCancelled { throw CancellationError() }
                throw error
            }
        }
    }
}

extension WalletContextImpl {
    private func isCurrentPaginationOperation(_ operationId: UUID, generation: UInt64) -> Bool {
        !self.isShutdown
            && self.activationGeneration == generation
            && self.activeOperationId == operationId
    }

    private func checkPaginationOperation(_ operationId: UUID, generation: UInt64) throws {
        try Task.checkCancellation()
        guard self.isCurrentPaginationOperation(operationId, generation: generation) else {
            throw CancellationError()
        }
    }

    private func updateTransactionsPagination(isLoadingMore: Bool, error: SynchronizationError?) {
        let transactions = self.currentState.transactions
        self.replaceState(
            phase: self.currentState.phase,
            balance: self.currentState.balance,
            transactions: TransactionsState(
                items: transactions.items,
                offset: transactions.offset,
                canLoadMore: transactions.canLoadMore,
                isLoadingMore: isLoadingMore,
                error: error
            ),
            pendingTransfers: self.currentState.pendingTransfers,
            activeOperation: self.currentState.activeOperation
        )
    }

    private func updateCollectiblesPagination(isLoadingMore: Bool, error: SynchronizationError?) {
        let collectibles = self.currentState.collectibles
        self.replaceState(
            phase: self.currentState.phase,
            balance: self.currentState.balance,
            transactions: self.currentState.transactions,
            collectibles: CollectiblesState(
                items: collectibles.items,
                offset: collectibles.offset,
                canLoadMore: collectibles.canLoadMore,
                isLoadingMore: isLoadingMore,
                error: error
            ),
            pendingTransfers: self.currentState.pendingTransfers,
            activeOperation: self.currentState.activeOperation
        )
    }

    func discardReplacementForCleanup(recordId: String) async {
        do {
            try await self.runtime.discardReplacement(recordId: recordId)
        } catch {
            self.logger.error("wallet_replacement_cleanup_failed", error)
        }
    }

    func prepareForRuntimeIdentityChange(
        preserveCurrentWalletState: Bool = false
    ) async -> UInt64 {
        if !preserveCurrentWalletState {
            self.resetPendingTransferExpiration(clearSuppressedTraceIds: true)
            self.outgoingTransactionPresentationIdentities.removeAll()
        }
        self.clearStreamingPresentationOverlay()
        self.streamingRefreshTracker = WalletStreamingRefreshTracker()
        self.activationGeneration &+= 1
        let generation = self.activationGeneration
        self.activationTask?.cancel()
        self.activationTask = nil
        self.observationTask?.cancel()
        self.observationTask = nil
        self.cancelSynchronization()
        self.stopStreaming()
        self.cancelWalletStateFallbackRefresh()
        self.preparedTransfers.removeAll()
        self.deferredSynchronizationScope = []
        let coordinator = self.tonConnectCoordinator
        self.tonConnectCoordinator = nil
        await coordinator?.shutdown()
        return generation
    }

    @discardableResult
    func installRuntimeActivation(
        state: TelegramCore.WalletState,
        activation: WalletEngineActivation,
        generation: UInt64,
        preserveCurrentWalletState: Bool = false
    ) -> WalletInfo {
        let identity: (backupEnabled: Bool, canExportPhrase: Bool, canEnableBackup: Bool, address: String, publicKey: Data)
        switch state {
        case let .ready(backupEnabled, canExportPhrase, canEnableBackup, address, publicKey, _):
            identity = (backupEnabled, canExportPhrase, canEnableBackup, address, publicKey)
        case .empty:
            preconditionFailure("A runtime activation requires a ready server wallet")
        }
        self.serverWalletState = state
        let info = WalletInfo(
            address: identity.address,
            publicKey: identity.publicKey.map { String(format: "%02x", $0) }.joined(),
            backupEnabled: identity.backupEnabled,
            canExportPhrase: identity.canExportPhrase,
            canEnableBackup: identity.canEnableBackup,
            canSign: activation.canSign
        )
        if !preserveCurrentWalletState {
            self.transactionHistory.reset()
        }
        self.replaceState(
            phase: .wallet(info),
            balance: preserveCurrentWalletState ? self.currentState.balance : .loading(previous: nil),
            transactions: preserveCurrentWalletState
                ? self.currentState.transactions
                : TransactionsState(items: [], offset: 0, canLoadMore: false, isLoadingMore: false, error: nil),
            collectibles: preserveCurrentWalletState ? self.currentState.collectibles : .empty,
            pendingTransfers: preserveCurrentWalletState ? self.currentState.pendingTransfers : [],
            activeOperation: self.currentState.activeOperation
        )
        self.beginObserving(snapshot: activation.snapshot, generation: generation)
        if activation.canSign {
            let coordinator = WalletTonConnectCoordinator(
                runtime: self.runtime,
                storage: self.storage,
                logger: self.logger,
                recordId: activation.snapshot.recordId,
                event: { [weak self] event in
                    await self?.handleTonConnectEvent(event)
                }
            )
            self.tonConnectCoordinator = coordinator
            Task { await coordinator.restore() }
        }
        if !preserveCurrentWalletState {
            self.pendingScreenSynchronizationScope.formUnion(self.visibleScreenSynchronizationScope)
        }
        if self.hasActiveWalletRefreshDemand {
            self.deferredSynchronizationScope.formUnion([.account, .transactions])
        }
        self.resumeDeferredSynchronizationIfNeeded()
        return info
    }

    func performOperation<Value: Sendable>(
        _ activeOperation: ActiveOperation,
        operationId: UUID,
        _ operation: () async throws -> Value
    ) async throws -> Value {
        try Task.checkCancellation()
        guard !self.isShutdown else {
            throw WalletError.unavailable
        }
        guard self.currentState.activeOperation == nil else {
            self.logger.error(
                "wallet_operation_rejected",
                WalletError.operationInProgress,
                context: "operation=\(activeOperation)"
            )
            throw WalletError.operationInProgress
        }
        switch activeOperation {
        case .preparingTransfer, .submittingTransfer, .decryptingComment:
            if !self.activeSynchronizationScope.isEmpty {
                self.deferredSynchronizationScope.formUnion(self.activeSynchronizationScope.subtracting(self.pendingScreenSynchronizationScope))
                self.cancelSynchronization()
            }
        case .creating, .importing, .recoveringPhrase, .preparingRecoveryPhraseImport,
             .completingRecoveryPhraseImport, .enablingBackup, .preparingBackupDisable,
             .disablingBackup, .loadingMoreTransactions, .loadingMoreCollectibles:
            break
        }
        self.activeOperationId = operationId
        self.replaceState(
            phase: self.currentState.phase,
            balance: self.currentState.balance,
            transactions: self.currentState.transactions,
            pendingTransfers: self.currentState.pendingTransfers,
            activeOperation: activeOperation
        )
        defer {
            if self.activeOperationId == operationId {
                self.activeOperationId = nil
                self.replaceState(
                    phase: self.currentState.phase,
                    balance: self.currentState.balance,
                    transactions: self.currentState.transactions,
                    pendingTransfers: self.currentState.pendingTransfers,
                    activeOperation: nil
                )
                if activeOperation.defersServerWalletState {
                    self.applyCompatibleDeferredServerWalletState()
                    self.requestServerWalletState(forceRefreshAfterCurrent: true)
                }
                self.resumeDeferredSynchronizationIfNeeded()
                self.scheduleAutomaticPhraseRecoveryIfNeeded()
            }
        }
        return try await operation()
    }

    func removeExpiredPreparedTransfers() {
        let now = currentWalletTimestamp()
        self.preparedTransfers = self.preparedTransfers.filter { $0.value.transfer.expiresAt > now }
    }

    var isTransferFlowBlockingSynchronization: Bool {
        if !self.preparedTransfers.isEmpty {
            return true
        }
        switch self.currentState.activeOperation {
        case .preparingTransfer, .submittingTransfer, .decryptingComment:
            return true
        case .none, .creating, .importing, .recoveringPhrase, .preparingRecoveryPhraseImport,
             .completingRecoveryPhraseImport, .enablingBackup, .preparingBackupDisable,
             .disablingBackup, .loadingMoreTransactions, .loadingMoreCollectibles:
            return false
        }
    }

    func resumeDeferredSynchronizationIfNeeded() {
        let scope = self.deferredSynchronizationScope.union(self.pendingScreenSynchronizationScope)
            .subtracting(self.activeSynchronizationScope)
        guard !scope.isEmpty, !self.isTransferFlowBlockingSynchronization else { return }
        self.requestSynchronization(scope: scope)
    }
}

private func normalizedMainnetAddress(_ input: String) -> String? {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    let address: String
    if trimmed.lowercased().hasPrefix("ton://") {
        guard let value = try? parseTonTransferLink(value: trimmed) else { return nil }
        address = value.recipient
    } else {
        address = trimmed
    }
    guard let info = try? parseTonAddress(value: address) else { return nil }
    if case let .userFriendly(_, testnet) = info.format, testnet { return nil }
    return try? convertTonAddress(
        value: address,
        format: .userFriendly(bounceable: false, testnet: false)
    )
}

private func encryptedCommentBoc(_ comment: String) -> String? {
    guard let data = Data(base64Encoded: comment), !data.isEmpty, data.count <= 1024 else {
        return nil
    }
    let bocMagic: [UInt8] = [0xb5, 0xee, 0x9c, 0x72]
    if data.starts(with: bocMagic) {
        return comment
    }

    let opcode: [UInt8] = [0x21, 0x67, 0xda, 0x4b]
    let hasOpcode = data.starts(with: opcode) && data.count % 16 == 4
    let payload = Array(data.dropFirst(hasOpcode ? opcode.count : 0))
    guard payload.count >= 64, (payload.count - 48) % 16 == 0 else {
        return nil
    }

    var chunks: [[UInt8]] = [opcode + Array(payload.prefix(35))]
    for offset in stride(from: 35, to: payload.count, by: 127) {
        chunks.append(Array(payload[offset ..< min(offset + 127, payload.count)]))
    }
    var cells = Data()
    for (index, chunk) in chunks.enumerated() {
        let hasNext = index + 1 < chunks.count
        cells.append(hasNext ? 1 : 0)
        cells.append(UInt8(chunk.count * 2))
        cells.append(contentsOf: chunk)
        if hasNext {
            cells.append(UInt8(index + 1))
        }
    }

    let offsetBytes: UInt8 = cells.count > 255 ? 2 : 1
    var boc = Data(bocMagic + [0x01, offsetBytes, UInt8(chunks.count), 1, 0])
    if offsetBytes == 2 {
        boc.append(UInt8(cells.count >> 8))
    }
    boc.append(UInt8(cells.count & 0xff))
    boc.append(0)
    boc.append(cells)
    return boc.base64EncodedString()
}

final class WalletOperationTaskRegistry {
    private let lock = NSLock()
    private var operations: [UUID: WalletOperationCancellation] = [:]
    private var isShutdown = false

    func register(id: UUID, cancellation: WalletOperationCancellation) {
        self.lock.lock()
        if self.isShutdown {
            self.lock.unlock()
            cancellation.cancel()
        } else {
            self.operations[id] = cancellation
            self.lock.unlock()
        }
    }

    func remove(id: UUID) {
        self.lock.lock()
        self.operations[id] = nil
        self.lock.unlock()
    }

    func cancel(id: UUID) {
        self.lock.lock()
        let cancellation = self.operations.removeValue(forKey: id)
        self.lock.unlock()
        cancellation?.cancel()
    }

    func shutdown() {
        self.lock.lock()
        self.isShutdown = true
        let operations = Array(self.operations.values)
        self.operations.removeAll()
        self.lock.unlock()
        for operation in operations {
            operation.cancel()
        }
    }
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
