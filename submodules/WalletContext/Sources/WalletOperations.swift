import Foundation
import SwiftSignalKit
import TelegramCore
import WalletEngineFFI

private struct AcceptedWalletEngineSubmission {
    let transfer: WalletContext.PendingTransfer
    let remainsPending: Bool
}

private func acceptedWalletEngineSubmission(
    pending: WalletContext.PendingTransfer,
    messageHash: String?,
    phase: SendPhase
) -> AcceptedWalletEngineSubmission? {
    let status: WalletContext.PendingTransfer.Status
    let remainsPending: Bool
    switch phase {
    case .submitted:
        status = .pending
        remainsPending = true
    case .submissionUnknown:
        status = .submissionUnknown
        remainsPending = true
    case .confirmed:
        status = .pending
        remainsPending = false
    case .idle, .validating, .authorizing, .preparing, .persisting, .readyToSubmit,
         .submitting, .handedOff, .replaced, .sequenceNumberConsumed, .expired,
         .superseded, .failed, .cancelled:
        return nil
    }
    return AcceptedWalletEngineSubmission(
        transfer: WalletContext.PendingTransfer(
            id: pending.id,
            recipient: pending.recipient,
            amount: pending.amount,
            comment: pending.comment,
            collectibleAddress: pending.collectibleAddress,
            normalizedHash: messageHash ?? pending.normalizedHash,
            createdAt: pending.createdAt,
            status: status
        ),
        remainsPending: remainsPending
    )
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
    let staged = try await runtime.stageReplacement(words: normalizedWords)
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

    func resolveTransferRecipient(_ value: String) -> Signal<ResolvedTransferRecipient?, WalletError> {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return .single(nil) }
        if let address = normalizedMainnetAddress(value) {
            return .single(ResolvedTransferRecipient(address: address, displayName: nil))
        }
        guard value.lowercased().hasSuffix(".ton"),
              !value.unicodeScalars.contains(where: CharacterSet.whitespacesAndNewlines.contains) else {
            return .single(nil)
        }
        return self.performUtility { context in
            guard let address = try await context.runtime.resolveDns(value.lowercased()),
                  let normalized = normalizedMainnetAddress(address) else {
                return nil
            }
            return ResolvedTransferRecipient(address: normalized, displayName: value)
        }
    }

    func resolveUserAddresses(userIds: [EnginePeer.Id]) -> Signal<[EnginePeer.Id: String], WalletError> {
        self.performUtility { context in
            var result: [EnginePeer.Id: String] = [:]
            let ids = Array(Set(userIds))
            var index = 0
            while index < ids.count {
                let upperBound = min(index + 100, ids.count)
                let values = try await WalletSignalRequestContext<[WalletUserAddress]>().run(
                    context.engine.wallet.getUserAddresses(userIds: Array(ids[index ..< upperBound]))
                )
                for value in values {
                    result[value.userId] = value.address
                }
                index = upperBound
            }
            return result
        }
    }

    func processTonConnectUrl(_ value: String) {
        guard Self.isTonConnectUrl(value) else { return }
        self.withMainQueue { [weak self] in
            guard let self, self.canSignCurrentWallet, let coordinator = self.tonConnectCoordinator else { return }
            Task {
                do {
                    try await coordinator.start(link: value)
                } catch {
                    self.withMainQueue {
                        self.tonConnectPresentationPipe.putNext(.error(
                            sanitizedWalletEngineDiagnostic(String(describing: error))
                        ))
                    }
                }
            }
        }
    }

    func approveTonConnectRequest(id: String) -> Signal<Void, WalletError> {
        self.performUtility { context in
            guard context.canSignCurrentWallet, let coordinator = context.tonConnectCoordinator else {
                throw WalletError.unavailable
            }
            try await coordinator.approveConnection(id: id)
        }
    }

    func approveTonConnectOperation(id: String) -> Signal<Void, WalletError> {
        self.performUtility { context in
            guard context.canSignCurrentWallet, let coordinator = context.tonConnectCoordinator else {
                throw WalletError.unavailable
            }
            try await coordinator.approveOperation(id: id)
            context.withMainQueue { context.requestSynchronization(force: true) }
        }
    }

    func rejectTonConnectRequest(id: String) -> Signal<Void, NoError> {
        Signal { [weak self] subscriber in
            guard let self else {
                subscriber.putCompletion()
                return EmptyDisposable
            }
            let task = Task {
                await self.tonConnectCoordinator?.reject(id: id)
                subscriber.putNext(Void())
                subscriber.putCompletion()
            }
            return ActionDisposable { task.cancel() }
        }
    }

    func setFiatCurrency(_ currency: FiatCurrency) {
        assert(Queue.mainQueue().isCurrent())
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

    func containsMnemonicWord(_ word: String) -> Signal<Bool, WalletError> {
        .single(self.isMnemonicWord(word))
    }

    func validateMnemonic(words: [String]) -> Signal<Bool, WalletError> {
        self.isMnemonicValid(words: words) ? .single(true) : .fail(.invalidMnemonic)
    }

    func generateMnemonic() -> Signal<[String], WalletError> { .fail(.unavailable) }

    func createWallet(password: String? = nil) -> Signal<CreatedWallet, WalletError> {
        self.performOperation(.creating, cancelOnDispose: false) { context in
            let state = try await WalletSignalRequestContext<TelegramCore.WalletState>().run(
                context.engine.wallet.replaceWallet(replacement: .new, password: password)
            )
            let identity = try walletServerIdentity(state)
            let generation = await context.prepareForRuntimeIdentityChange()
            let words: [String]
            do {
                words = try await exportWalletSecretPhrase(engine: context.engine, password: password)
            } catch {
                // Replacement has already committed on the server. Keep the new
                // identity usable as read-only and let recovery retry later.
                let activation = try await context.runtime.activate(
                    serverAddress: identity.address,
                    serverPublicKey: identity.publicKey,
                    exportedWords: nil
                )
                _ = context.installRuntimeActivation(state: state, activation: activation, generation: generation)
                throw error
            }
            let staged = try await context.runtime.stageReplacement(words: words)
            guard walletEngineAddressesEqual(staged.address, identity.address),
                  staged.publicKey == identity.publicKey else {
                try? await context.runtime.discardReplacement(recordId: staged.recordId)
                let activation = try await context.runtime.activate(
                    serverAddress: identity.address,
                    serverPublicKey: identity.publicKey,
                    exportedWords: nil
                )
                _ = context.installRuntimeActivation(state: state, activation: activation, generation: generation)
                throw WalletError.storage(.identityMismatch)
            }
            let activation = try await context.runtime.commitReplacement(
                recordId: staged.recordId,
                serverAddress: identity.address,
                serverPublicKey: identity.publicKey
            )
            let info = context.installRuntimeActivation(state: state, activation: activation, generation: generation)
            return CreatedWallet(info: info, words: words)
        }
    }

    func importWallet(words: [String], password: String? = nil) -> Signal<WalletInfo, WalletError> {
        self.performOperation(.importing, cancelOnDispose: false) { context in
            let normalizedWords = normalizedEngineMnemonic(words)
            guard detectMnemonicSchemes(words: normalizedWords).contains(.rotation) else {
                throw WalletError.invalidMnemonic
            }
            let staged = try await context.runtime.stageReplacement(words: normalizedWords)
            let state: TelegramCore.WalletState
            do {
                state = try await WalletSignalRequestContext<TelegramCore.WalletState>().run(
                    context.engine.wallet.replaceWallet(
                        replacement: .imported(publicKey: staged.publicKey),
                        password: password
                    )
                )
            } catch let error as TelegramCore.WalletOperationError {
                if error == .replacementInvalid || error == .publicKeyInvalid {
                    try? await context.runtime.discardReplacement(recordId: staged.recordId)
                }
                throw error
            }
            let identity = try walletServerIdentity(state)
            guard walletEngineAddressesEqual(staged.address, identity.address),
                  staged.publicKey == identity.publicKey else {
                try? await context.runtime.discardReplacement(recordId: staged.recordId)
                throw WalletError.storage(.identityMismatch)
            }
            let generation = await context.prepareForRuntimeIdentityChange()
            let activation = try await context.runtime.commitReplacement(
                recordId: staged.recordId,
                serverAddress: identity.address,
                serverPublicKey: identity.publicKey
            )
            return context.installRuntimeActivation(state: state, activation: activation, generation: generation)
        }
    }

    func recoveryPhrase(password: String? = nil) -> Signal<[String], WalletError> {
        self.performOperation(.recoveringPhrase, cancelOnDispose: false) { context in
            guard case let .wallet(info) = context.currentState.phase, info.canRevealPhrase else {
                throw WalletError.unavailable
            }
            if context.canSignCurrentWallet {
                return try await context.runtime.revealRecoveryPhrase()
            }
            guard info.canExportPhrase,
                  case let .ready(_, _, _, address, publicKey, _) = context.serverWalletState else {
                throw WalletError.unavailable
            }
            let words = try await exportWalletSecretPhrase(engine: context.engine, password: password)
            let prepared = try await stageRecoveryPhraseImport(
                runtime: context.runtime,
                words: words,
                sourceAddress: address,
                sourcePublicKey: publicKey
            )
            guard prepared.disposition == .currentWallet else {
                try? await context.runtime.discardReplacement(recordId: prepared.recordId)
                throw WalletError.storage(.identityMismatch)
            }
            let generation = await context.prepareForRuntimeIdentityChange()
            let activation = try await context.runtime.commitReplacement(
                recordId: prepared.recordId,
                serverAddress: address,
                serverPublicKey: publicKey
            )
            if let state = context.serverWalletState {
                _ = context.installRuntimeActivation(
                    state: state,
                    activation: activation,
                    generation: generation,
                    preserveCurrentWalletState: true
                )
            }
            return words
        }
    }

    func prepareRecoveryPhraseImport(words: [String]) -> Signal<PreparedRecoveryPhraseImport, WalletError> {
        self.performOperation(.preparingRecoveryPhraseImport) { context in
            guard let state = context.serverWalletState else {
                throw WalletError.noWallet
            }
            let sourceIdentity = try walletServerIdentity(state)
            let prepared = try await stageRecoveryPhraseImport(
                runtime: context.runtime,
                words: words,
                sourceAddress: sourceIdentity.address,
                sourcePublicKey: sourceIdentity.publicKey
            )
            context.preparedRecoveryPhraseImportRecordId = prepared.recordId
            return prepared
        }
    }

    func completeRecoveryPhraseImport(
        _ prepared: PreparedRecoveryPhraseImport,
        password: String? = nil
    ) -> Signal<WalletInfo, WalletError> {
        self.performOperation(.completingRecoveryPhraseImport, cancelOnDispose: false) { context in
            guard let currentServerState = context.serverWalletState else {
                throw WalletError.noWallet
            }
            let currentIdentity: (address: String, publicKey: Data)
            do {
                currentIdentity = try walletServerIdentity(currentServerState)
            } catch {
                if context.preparedRecoveryPhraseImportRecordId == prepared.recordId {
                    context.preparedRecoveryPhraseImportRecordId = nil
                }
                try? await context.runtime.discardReplacement(recordId: prepared.recordId)
                throw error
            }
            guard walletEngineAddressesEqual(currentIdentity.address, prepared.sourceAddress),
                  currentIdentity.publicKey == prepared.sourcePublicKey else {
                if context.preparedRecoveryPhraseImportRecordId == prepared.recordId {
                    context.preparedRecoveryPhraseImportRecordId = nil
                }
                try? await context.runtime.discardReplacement(recordId: prepared.recordId)
                throw WalletError.storage(.identityMismatch)
            }

            switch prepared.disposition {
            case .currentWallet:
                guard walletEngineAddressesEqual(prepared.candidateAddress, currentIdentity.address),
                      prepared.candidatePublicKey == currentIdentity.publicKey else {
                    if context.preparedRecoveryPhraseImportRecordId == prepared.recordId {
                        context.preparedRecoveryPhraseImportRecordId = nil
                    }
                    try? await context.runtime.discardReplacement(recordId: prepared.recordId)
                    throw WalletError.storage(.identityMismatch)
                }
                if context.preparedRecoveryPhraseImportRecordId == prepared.recordId {
                    context.preparedRecoveryPhraseImportRecordId = nil
                }
                let generation = await context.prepareForRuntimeIdentityChange()
                let activation = try await context.runtime.commitReplacement(
                    recordId: prepared.recordId,
                    serverAddress: currentIdentity.address,
                    serverPublicKey: currentIdentity.publicKey
                )
                return context.installRuntimeActivation(
                    state: currentServerState,
                    activation: activation,
                    generation: generation,
                    preserveCurrentWalletState: true
                )

            case .replacement:
                let state: TelegramCore.WalletState
                do {
                    state = try await WalletSignalRequestContext<TelegramCore.WalletState>().run(
                        context.engine.wallet.replaceWallet(
                            replacement: .imported(publicKey: prepared.candidatePublicKey),
                            password: password
                        )
                    )
                } catch let error as TelegramCore.WalletOperationError {
                    switch error {
                    case .requestPassword, .invalidPassword:
                        break
                    case .network:
                        if context.preparedRecoveryPhraseImportRecordId == prepared.recordId {
                            context.preparedRecoveryPhraseImportRecordId = nil
                        }
                    default:
                        if context.preparedRecoveryPhraseImportRecordId == prepared.recordId {
                            context.preparedRecoveryPhraseImportRecordId = nil
                        }
                        try? await context.runtime.discardReplacement(recordId: prepared.recordId)
                    }
                    throw error
                }
                let replacementIdentity: (address: String, publicKey: Data)
                do {
                    replacementIdentity = try walletServerIdentity(state)
                } catch {
                    if context.preparedRecoveryPhraseImportRecordId == prepared.recordId {
                        context.preparedRecoveryPhraseImportRecordId = nil
                    }
                    try? await context.runtime.discardReplacement(recordId: prepared.recordId)
                    throw error
                }
                guard walletEngineAddressesEqual(prepared.candidateAddress, replacementIdentity.address),
                      prepared.candidatePublicKey == replacementIdentity.publicKey else {
                    if context.preparedRecoveryPhraseImportRecordId == prepared.recordId {
                        context.preparedRecoveryPhraseImportRecordId = nil
                    }
                    try? await context.runtime.discardReplacement(recordId: prepared.recordId)
                    throw WalletError.storage(.identityMismatch)
                }
                if context.preparedRecoveryPhraseImportRecordId == prepared.recordId {
                    context.preparedRecoveryPhraseImportRecordId = nil
                }
                let generation = await context.prepareForRuntimeIdentityChange()
                let activation = try await context.runtime.commitReplacement(
                    recordId: prepared.recordId,
                    serverAddress: replacementIdentity.address,
                    serverPublicKey: replacementIdentity.publicKey
                )
                return context.installRuntimeActivation(
                    state: state,
                    activation: activation,
                    generation: generation
                )
            }
        }
    }

    func discardRecoveryPhraseImport(_ prepared: PreparedRecoveryPhraseImport) -> Signal<Void, WalletError> {
        self.performUtility { context in
            if context.preparedRecoveryPhraseImportRecordId == prepared.recordId {
                context.preparedRecoveryPhraseImportRecordId = nil
            }
            try await context.runtime.discardReplacement(recordId: prepared.recordId)
        }
    }

    func enableBackup(password: String? = nil) -> Signal<WalletInfo, WalletError> {
        self.performOperation(.enablingBackup, cancelOnDispose: false) { context in
            guard context.canSignCurrentWallet,
                  case let .wallet(info) = context.currentState.phase,
                  info.canEnableBackup else {
                throw WalletError.unavailable
            }
            let words = try await context.runtime.revealRecoveryPhrase()
            let state = try await enableWalletBackup(engine: context.engine, words: words, password: password)
            let identity = try walletServerIdentity(state)
            guard walletEngineAddressesEqual(identity.address, info.address),
                  identity.publicKey.map({ String(format: "%02x", $0) }).joined() == info.publicKey else {
                throw WalletError.storage(.identityMismatch)
            }
            context.applyServerWalletState(state)
            guard case let .wallet(updated) = context.currentState.phase else {
                throw WalletError.unavailable
            }
            return updated
        }
    }

    func prepareDisableBackup() -> Signal<PreparedBackupDisable, WalletError> {
        self.performOperation(.preparingBackupDisable) { context in
            guard context.canSignCurrentWallet,
                  case let .wallet(info) = context.currentState.phase,
                  info.backupEnabled else {
                throw WalletError.unavailable
            }

            if let existing = try await context.runtime.keyRotationRecord() {
                guard walletEngineAddressesEqual(existing.walletAddress, info.address),
                      existing.walletPublicKey.map({ String(format: "%02x", $0) }).joined() == info.publicKey,
                      existing.newPublicKey.count == 32,
                      existing.validUntil <= UInt64(Int32.max) else {
                    throw WalletError.storage(.identityMismatch)
                }

                if existing.phase == .rollbackStored || existing.phase == .replacementStored || existing.phase == .rolledBack {
                    _ = try await context.runtime.resolveKeyRotation()
                } else {
                    if existing.phase == .submissionStarted {
                        _ = try? await context.runtime.resolveKeyRotation()
                    }
                    if let current = try await context.runtime.keyRotationRecord() {
                        let words = try await context.runtime.revealRecoveryPhrase()
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
                            keyRotationPhase: current.phase == .confirmed ? .confirmed : .pending
                        )
                    }
                }
            }

            let expiresAt = currentWalletTimestamp() + 300
            let prepared = try await context.runtime.prepareKeyRotation(validUntil: UInt64(expiresAt))
            let words = prepared.replacementRecoveryPhrase.phrase
                .split(whereSeparator: { $0.isWhitespace })
                .map(String.init)
            guard words.count == 24,
                  prepared.newPublicKey.count == 32,
                  prepared.validUntil == UInt64(expiresAt),
                  !prepared.signedBoc.isEmpty else {
                throw WalletError.sdk("Wallet engine returned invalid key-rotation material")
            }
            return PreparedBackupDisable(
                id: UUID().uuidString.lowercased(),
                walletAddress: info.address,
                walletPublicKey: info.publicKey,
                words: words,
                newPublicKey: prepared.newPublicKey,
                signedBoc: prepared.signedBoc,
                seqno: prepared.seqno,
                expiresAt: expiresAt,
                keyRotationPhase: .prepared
            )
        }
    }

    func disableBackup(_ prepared: PreparedBackupDisable, password: String? = nil) -> Signal<WalletInfo, WalletError> {
        self.performOperation(.disablingBackup, cancelOnDispose: false) { context in
            guard context.canSignCurrentWallet,
                  case let .wallet(info) = context.currentState.phase,
                  info.address == prepared.walletAddress,
                  info.publicKey == prepared.walletPublicKey,
                  info.backupEnabled else {
                throw WalletError.unavailable
            }

            var rotation = try await context.runtime.keyRotationRecord()
            if rotation == nil {
                guard prepared.keyRotationPhase == .prepared,
                      prepared.expiresAt > currentWalletTimestamp(),
                      prepared.newPublicKey.count == 32,
                      !prepared.signedBoc.isEmpty else {
                    throw WalletError.unavailable
                }
                let result: SendResult
                do {
                    result = try await context.runtime.sendKeyRotation(
                        operationId: prepared.id,
                        words: prepared.words,
                        newPublicKey: prepared.newPublicKey,
                        signedBoc: prepared.signedBoc,
                        seqno: prepared.seqno,
                        validUntil: UInt64(prepared.expiresAt)
                    )
                } catch {
                    if (try? await context.runtime.keyRotationRecord()) == nil {
                        throw WalletError.keyRotationFailed
                    }
                    throw error
                }
                switch result.phase {
                case .submitted, .submissionUnknown, .confirmed:
                    break
                case .idle, .validating, .authorizing, .preparing, .persisting, .readyToSubmit,
                     .submitting, .handedOff, .replaced, .sequenceNumberConsumed, .expired,
                     .superseded, .failed, .cancelled:
                    throw WalletError.keyRotationFailed
                }
                rotation = try await context.runtime.keyRotationRecord()
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
                let resolution = try await context.runtime.resolveKeyRotation()
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
                context.engine.wallet.disableBackup(password: password)
            )
            guard case let .ready(backupEnabled, _, _, _, _, _) = state, !backupEnabled else {
                throw WalletError.invalidBackupData
            }
            let identity = try walletServerIdentity(state)
            guard walletEngineAddressesEqual(identity.address, info.address),
                  identity.publicKey.map({ String(format: "%02x", $0) }).joined() == info.publicKey else {
                throw WalletError.storage(.identityMismatch)
            }
            try await context.runtime.completeKeyRotation(operationId: prepared.id)
            context.applyServerWalletState(state)
            guard case let .wallet(updated) = context.currentState.phase else {
                throw WalletError.unavailable
            }
            return updated
        }
    }

    func prepareTransfer(address: String, amount: Int64, comment: String?) -> Signal<PreparedTransfer, WalletError> {
        self.performOperation(.preparingTransfer) { context in
            guard context.canSignCurrentWallet,
                  case let .wallet(info) = context.currentState.phase else {
                throw WalletError.unavailable
            }
            let resolved = try resolveTransferInput(address: address, amount: amount, comment: comment)
            let intent = SendIntent(
                expiration: resolved.expiration,
                messages: [SendMessage(
                    destination: resolved.address,
                    amount: .exact(nanograms: String(resolved.amount)),
                    body: resolved.body,
                    bounce: false,
                    stateInit: nil
                )]
            )
            let preview = try await context.runtime.previewSend(intent: intent)
            guard !preview.emulation.isIncomplete else { throw WalletError.previewIncomplete }
            guard let fee = Int64(preview.emulation.walletFeesNanograms) else { throw WalletError.previewFailed }
            if let balance = context.currentState.balance.currentValue,
               resolved.amount > balance || fee > balance - resolved.amount {
                throw WalletError.insufficientBalance(required: resolved.amount + fee)
            }
            let transfer = PreparedTransfer(
                id: UUID().uuidString.lowercased(),
                recipient: resolved.address,
                amount: resolved.amount,
                comment: resolved.comment,
                fee: fee,
                expiresAt: Int32(clamping: preview.validUntil)
            )
            context.preparedTransfers[transfer.id] = PreparedEngineTransferRecord(
                walletAddress: info.address,
                transfer: transfer,
                request: .send(intent)
            )
            context.removeExpiredPreparedTransfers()
            return transfer
        }
    }

    func prepareCollectibleTransfer(
        address: String,
        collectible: Collectible,
        comment: String?
    ) -> Signal<PreparedTransfer, WalletError> {
        self.performOperation(.preparingTransfer) { context in
            guard context.canSignCurrentWallet,
                  case let .wallet(info) = context.currentState.phase,
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
            let preview = try await context.runtime.previewNft(operationId: id, intent: intent)
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
            context.preparedTransfers[id] = PreparedEngineTransferRecord(
                walletAddress: info.address,
                transfer: transfer,
                request: .nft(intent)
            )
            context.removeExpiredPreparedTransfers()
            return transfer
        }
    }

    func submitTransfer(_ prepared: PreparedTransfer) -> Signal<SubmittedTransfer, WalletError> {
        self.performOperation(.submittingTransfer, cancelOnDispose: false) { context in
            guard context.canSignCurrentWallet,
                  case let .wallet(info) = context.currentState.phase,
                  let record = context.preparedTransfers[prepared.id],
                  record.walletAddress == info.address,
                  record.transfer == prepared else {
                throw WalletError.preparedTransferNotFound
            }
            guard prepared.expiresAt > currentWalletTimestamp() else {
                context.preparedTransfers[prepared.id] = nil
                throw WalletError.preparedTransferExpired
            }
            let pending = PendingTransfer(
                id: prepared.id,
                recipient: prepared.recipient,
                amount: prepared.amount,
                comment: prepared.comment,
                collectibleAddress: prepared.collectible?.address,
                createdAt: currentWalletTimestamp(),
                status: .broadcasting
            )
            var values = context.currentState.pendingTransfers.filter { $0.id != pending.id }
            values.append(pending)
            context.replaceState(
                phase: context.currentState.phase,
                balance: context.currentState.balance,
                transactions: context.currentState.transactions,
                pendingTransfers: values,
                activeOperation: context.currentState.activeOperation
            )
            context.preparedTransfers[prepared.id] = nil

            let applyAcceptedSubmission: (SendPhase, String?) -> SubmittedTransfer? = { phase, messageHash in
                guard let accepted = acceptedWalletEngineSubmission(
                    pending: pending,
                    messageHash: messageHash,
                    phase: phase
                ) else {
                    return nil
                }
                var updated = context.currentState.pendingTransfers.filter { $0.id != accepted.transfer.id }
                if accepted.remainsPending {
                    updated.append(accepted.transfer)
                }
                context.replaceState(
                    phase: context.currentState.phase,
                    balance: context.currentState.balance,
                    transactions: context.currentState.transactions,
                    pendingTransfers: updated,
                    activeOperation: context.currentState.activeOperation
                )
                context.requestSynchronization(force: true)
                return SubmittedTransfer(pendingTransfer: accepted.transfer)
            }

            do {
                let result: SendResult
                switch record.request {
                case let .send(intent):
                    result = try await context.runtime.send(operationId: prepared.id, intent: intent)
                case let .nft(intent):
                    result = try await context.runtime.sendNft(operationId: prepared.id, intent: intent)
                }
                guard let submitted = applyAcceptedSubmission(result.phase, result.messageHash) else {
                    throw WalletError.sdk("wallet-engine send ended in \(result.phase)")
                }
                return submitted
            } catch {
                let snapshot = try? await context.runtime.snapshot()
                if let send = snapshot?.send,
                   send.operationId == pending.id,
                   let submitted = applyAcceptedSubmission(send.phase, nil) {
                    return submitted
                }
                context.replaceState(
                    phase: context.currentState.phase,
                    balance: context.currentState.balance,
                    transactions: context.currentState.transactions,
                    pendingTransfers: context.currentState.pendingTransfers.filter { $0.id != pending.id },
                    activeOperation: context.currentState.activeOperation
                )
                throw error
            }
        }
    }

    func loadMoreTransactions() -> Signal<Void, WalletError> {
        self.performOperation(.loadingMoreTransactions) { context in
            guard context.currentState.transactions.canLoadMore,
                  let offset = context.serverTransactionsNextOffset else { return Void() }
            let response = try await WalletSignalRequestContext<TelegramCore.WalletTransactions>().run(
                context.engine.wallet.getTransactions(
                    inbound: true,
                    outbound: true,
                    offset: offset,
                    limit: Int32(walletTransactionFetchLimit)
                )
            )
            let items = mergeTransactions(
                existing: context.currentState.transactions.items,
                new: walletTransactions(from: response.items)
            )
            context.serverTransactionsNextOffset = response.nextOffset
            context.replaceState(
                phase: context.currentState.phase,
                balance: context.currentState.balance,
                transactions: TransactionsState(
                    items: items,
                    offset: items.count,
                    canLoadMore: response.nextOffset != nil,
                    isLoadingMore: false,
                    error: nil
                ),
                pendingTransfers: context.currentState.pendingTransfers,
                activeOperation: context.currentState.activeOperation
            )
        }
    }

    func loadMoreCollectibles() -> Signal<Void, WalletError> {
        self.performOperation(.loadingMoreCollectibles) { context in
            guard context.currentState.collectibles.canLoadMore else { return Void() }
            let update = try await context.runtime.loadMoreNfts()
            let items = await walletCollectibles(from: update.snapshot.nfts.items)
            context.replaceState(
                phase: context.currentState.phase,
                balance: context.currentState.balance,
                transactions: context.currentState.transactions,
                collectibles: CollectiblesState(
                    items: items,
                    offset: items.count,
                    canLoadMore: update.snapshot.nfts.hasMore,
                    isLoadingMore: false,
                    error: nil
                ),
                pendingTransfers: context.reconcilePendingTransfers(update.snapshot.send),
                activeOperation: context.currentState.activeOperation
            )
        }
    }
}

extension WalletContext {
    @MainActor
    func prepareForRuntimeIdentityChange() async -> UInt64 {
        self.activationGeneration &+= 1
        let generation = self.activationGeneration
        self.activationTask?.cancel()
        self.activationTask = nil
        self.observationTask?.cancel()
        self.observationTask = nil
        self.cancelSynchronization()
        self.stopStreaming()
        self.preparedTransfers.removeAll()
        let coordinator = self.tonConnectCoordinator
        self.tonConnectCoordinator = nil
        await coordinator?.shutdown()
        return generation
    }

    @discardableResult
    @MainActor
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
        self.canSignCurrentWallet = activation.canSign
        let info = WalletInfo(
            address: identity.address,
            publicKey: identity.publicKey.map { String(format: "%02x", $0) }.joined(),
            backupEnabled: identity.backupEnabled,
            canExportPhrase: identity.canExportPhrase,
            canEnableBackup: identity.canEnableBackup,
            canSign: activation.canSign
        )
        if !preserveCurrentWalletState {
            self.serverTransactionsNextOffset = nil
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
                recordId: activation.snapshot.recordId,
                event: { [weak self] event in
                    self?.withMainQueue { self?.handleTonConnectEvent(event) }
                }
            )
            self.tonConnectCoordinator = coordinator
            Task { await coordinator.restore() }
        }
        self.requestSynchronization(force: true)
        return info
    }

    func performUtility<Value>(
        _ operation: @escaping @MainActor (WalletContext) async throws -> Value
    ) -> Signal<Value, WalletError> {
        Signal { [weak self] subscriber in
            guard let self else {
                subscriber.putError(.unavailable)
                return EmptyDisposable
            }
            let cancellation = WalletOperationCancellation()
            let task = Task { @MainActor [weak self] in
                guard let self else { subscriber.putError(.unavailable); return }
                do {
                    let value = try await operation(self)
                    try Task.checkCancellation()
                    subscriber.putNext(value)
                    subscriber.putCompletion()
                } catch is CancellationError {
                    subscriber.putError(.unavailable)
                } catch {
                    subscriber.putError(walletError(error))
                }
            }
            cancellation.setTask(task)
            return ActionDisposable { cancellation.cancel() }
        }
    }

    func performOperation<Value>(
        _ activeOperation: ActiveOperation,
        cancelOnDispose: Bool = true,
        _ operation: @escaping @MainActor (WalletContext) async throws -> Value
    ) -> Signal<Value, WalletError> {
        Signal { [weak self] subscriber in
            guard let self else {
                subscriber.putError(.unavailable)
                return EmptyDisposable
            }
            let cancellation = WalletOperationCancellation()
            self.withMainQueue { [weak self] in
                guard let self else { subscriber.putError(.unavailable); return }
                guard self.currentState.activeOperation == nil else {
                    subscriber.putError(.operationInProgress)
                    return
                }
                self.activeOperationCancellation = cancellation
                self.replaceState(
                    phase: self.currentState.phase,
                    balance: self.currentState.balance,
                    transactions: self.currentState.transactions,
                    pendingTransfers: self.currentState.pendingTransfers,
                    activeOperation: activeOperation
                )
                let task = Task { @MainActor [weak self] in
                    guard let self else { subscriber.putError(.unavailable); return }
                    let finishOperation = {
                        if self.activeOperationCancellation === cancellation {
                            self.activeOperationCancellation = nil
                            self.replaceState(
                                phase: self.currentState.phase,
                                balance: self.currentState.balance,
                                transactions: self.currentState.transactions,
                                pendingTransfers: self.currentState.pendingTransfers,
                                activeOperation: nil
                            )
                            if activeOperation == .creating || activeOperation == .importing {
                                self.requestServerWalletState()
                            }
                        }
                    }
                    defer {
                        finishOperation()
                    }
                    do {
                        let value = try await operation(self)
                        finishOperation()
                        subscriber.putNext(value)
                        subscriber.putCompletion()
                    } catch is CancellationError {
                        finishOperation()
                        subscriber.putError(.unavailable)
                    } catch {
                        finishOperation()
                        subscriber.putError(walletError(error))
                    }
                }
                cancellation.setTask(task)
            }
            return ActionDisposable { if cancelOnDispose { cancellation.cancel() } }
        }
    }

    func removeExpiredPreparedTransfers() {
        let now = currentWalletTimestamp()
        self.preparedTransfers = self.preparedTransfers.filter { $0.value.transfer.expiresAt > now }
    }

    func requestFiatRates() {
        guard self.canUseNetworkRuntime, self.stateSubscriberCount > 0 else { return }
        self.fiatRefreshTask?.cancel()
        self.fiatRatesDisposable.set((combineLatest(
            self.engine.payments.currencyRates(),
            self.engine.data.get(TelegramEngine.EngineData.Item.Configuration.App())
        )
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] currencyRates, configuration in
            guard let self,
                  let currencyRates,
                  let tonUsd = configuration.data?["ton_usd_rate"] as? Double,
                  tonUsd.isFinite,
                  tonUsd > 0 else { return }
            var byCode: [String: Double] = [:]
            for value in currencyRates where value.rate.isFinite && value.rate > 0 {
                byCode[value.currency] = value.rate
            }
            var rates: [FiatCurrency: FiatRate] = [:]
            for currency in FiatCurrency.allCases {
                guard let perUsd = byCode[currency.rawValue] else { continue }
                rates[currency] = FiatRate(unitsPerUsd: perUsd, unitsPerGram: perUsd * tonUsd)
            }
            let timestamp = currentWalletTimestamp()
            self.fiatLastSuccessfulAt = timestamp
            self.replaceState(
                phase: self.currentState.phase,
                balance: self.currentState.balance,
                transactions: self.currentState.transactions,
                pendingTransfers: self.currentState.pendingTransfers,
                activeOperation: self.currentState.activeOperation,
                fiat: FiatState(selectedCurrency: self.currentState.fiat.selectedCurrency, rates: .value(rates, updatedAt: timestamp))
            )
            self.fiatRefreshTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(walletFiatRatesRefreshInterval * 1_000_000_000))
                guard let self, !Task.isCancelled else { return }
                self.requestFiatRates()
            }
        }))
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
