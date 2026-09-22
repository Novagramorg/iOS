import Foundation
import PasscodeCore
import Postbox
import SwiftSignalKit
import TelegramCore
import WalletEngineFFI
#if os(iOS)
import UIKit
#endif

@available(macOS 10.15, *)
struct TonConnectMessageKey: Hashable {
    let sessionId: Int64
    let msgId: Int64
}

/// Actor-owned state; `valid` is also read by the runtime signing guard.
@available(macOS 10.15, *)
final class TonConnectPendingInteraction {
    enum Source {
        case connect(TonConnectLink, TonConnectConnectRequest)
        case request(WalletTonConnectLookup, msgId: Int64?, returnTarget: TonConnectReturnTarget)
    }
    enum Publication {
        case connect(answer: Data, body: Data, isError: Bool, traceId: String?)
        case response(msgId: Int64, body: Data, traceId: String?)
    }
    let id = UUID().uuidString
    let source: Source
    let valid = Atomic(value: true)
    var session: WalletTonConnectSession?
    var wallet: TonConnectWalletIdentity?
    var envelope: WalletTonConnectRequest?
    var request: TonConnectWireRequest?
    var validationError: TonConnectWireFailure?
    var authorization: PasscodeSession?
    var content: WalletContext.TonConnectActiveRequest.Content?
    var status: TonConnectRequestStatus = .ready
    var lifecycle = TonConnectRequestLifecycle()
    var publication: Publication?
    var connectEventId: Int64?
    var wantsRejection = false
    var approved = false
    var failure: TonConnectFailure?
    var preparationFailed = false
    var expiryTask: Task<Void, Never>?

    init(_ source: Source) { self.source = source }
    var messageKey: TonConnectMessageKey? {
        if let envelope { return TonConnectMessageKey(sessionId: envelope.sessionId, msgId: envelope.msgId) }
        if case let .request(.sessionId(sessionId), .some(msgId), _) = self.source {
            return TonConnectMessageKey(sessionId: sessionId, msgId: msgId)
        }
        return nil
    }
    var returnTarget: TonConnectReturnTarget {
        switch self.source {
        case let .connect(link, _): return link.returnTarget
        case let .request(_, _, target): return target
        }
    }
}

/// Never retry a claim, including after a lost RPC reply or signing failure.
@available(macOS 10.15, *)
struct TonConnectRequestLifecycle {
    enum Phase { case pending, claiming, claimed, executing, prepared, completed, stopped }
    private(set) var phase: Phase = .pending
    mutating func beginClaim() -> Bool {
        guard self.phase == .pending else { return false }
        self.phase = .claiming
        return true
    }
    mutating func claimSucceeded() -> Bool {
        guard self.phase == .claiming else { return false }
        self.phase = .claimed
        return true
    }
    mutating func beginExecution() -> Bool {
        guard self.phase == .claimed else { return false }
        self.phase = .executing
        return true
    }
    mutating func prepared() { self.phase = .prepared }
    mutating func completed() { self.phase = .completed }
    mutating func stop() { self.phase = .stopped }
    var ownsClaimAttempt: Bool {
        switch self.phase {
        case .claiming, .claimed, .executing, .prepared: return true
        default: return false
        }
    }
}

@available(macOS 10.15, *)
public extension WalletContext {
    var tonConnectState: Signal<TonConnectState, NoError> {
        self.output.tonConnectStatePromise.get() |> deliverOnMainQueue
    }

    static func isTonConnectUrl(_ value: String) -> Bool { TonConnectLink.matches(value) }

    func processTonConnectUrl(_ value: String) {
        Task { await self.impl.openTonConnectUrl(value) }
    }

    func openTonConnectRequest(sessionId: Int64, messageId: MessageId) {
        guard messageId.namespace == Namespaces.Message.Cloud,
              messageId.peerId == PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(777000)) else { return }
        Task { await self.impl.enqueueTonConnectRequest(sessionId: sessionId, msgId: Int64(messageId.id)) }
    }

    func decideTonConnectRequest(id: String, approve: Bool) -> Signal<TonConnectDecisionResult, WalletError> {
        self.signal(name: "ton_connect_decide", cancelOnDispose: false) { impl, operationId in
            try await impl.decideTonConnectRequest(id: id, approve: approve, operationId: operationId)
        }
    }

    func rejectTonConnectRequest(id: String) {
        Task { await self.impl.rejectTonConnectRequest(id: id) }
    }

    func retryTonConnectRequest(id: String) {
        Task { await self.impl.retryTonConnectPreparation(id: id) }
    }

    func closeTonConnectPresentation(id: String) {
        Task { await self.impl.closeTonConnectPresentation(id: id) }
    }

    func refreshTonConnectSessions() {
        Task { await self.impl.updateTonConnectEnvironment(refresh: true) }
    }

    func disconnectTonConnectSession(id: Int64) -> Signal<Void, NoError> {
        self.disconnectTonConnectSessions(ids: [id])
    }

    func disconnectAllTonConnectSessions() -> Signal<Void, NoError> {
        self.disconnectTonConnectSessions(ids: nil)
    }

    private func disconnectTonConnectSessions(ids: [Int64]?) -> Signal<Void, NoError> {
        self.signal(name: "ton_connect_disconnect", cancelOnDispose: false) { impl, operationId in
            await impl.disconnectTonConnectSessions(ids: ids, operationId: operationId)
        } |> `catch` { _ in .single(()) }
    }
}

@available(macOS 10.15, *)
extension WalletContextImpl {
    private func logTonConnect(_ stage: String, _ active: TonConnectPendingInteraction, walletClientId: String? = nil, body: Data? = nil, outcome: String? = nil, error: Error? = nil) {
        let traceId: String?
        switch active.source {
        case let .connect(link, _): traceId = link.traceId
        case .request: traceId = active.envelope?.traceId
        }
        self.logger.tonConnect(stage, requestId: active.id, session: active.session, traceId: traceId,
            eventId: active.connectEventId, walletClientId: walletClientId, body: body, outcome: outcome, error: error)
    }

    func resetTonConnect() {
        self.tonConnectEpoch &+= 1
        self.tonConnectPreparationTask?.cancel()
        self.tonConnectRefreshTask?.cancel()
        self.tonConnectPreparationTask = nil
        self.tonConnectRefreshTask = nil
        if let active = self.tonConnectActive {
            _ = active.valid.swap(false)
            active.expiryTask?.cancel()
            self.authorization.finish(active.authorization)
        }
        self.tonConnectActive = nil
        self.tonConnectQueue.removeAll()
        self.tonConnectHandledRequests.removeAll()
        self.tonConnectProvenSessions.removeAll()
        self.tonConnectDisconnectBodies.removeAll()
        self.tonConnectPendingDisconnects.removeAll()
        self.tonConnectSessionErrors.removeAll()
        self.tonConnectSessions.removeAll()
        self.tonConnectSessionRevisions.removeAll()
        self.tonConnectRevision &+= 1
        self.tonConnectDiagnostic = nil
        self.publishTonConnectState()
    }

    func updateTonConnectWallet() {
        guard case let .wallet(info) = self.currentState.phase else {
            if case .empty = self.currentState.phase {
                self.resetTonConnect()
                self.tonConnectWalletIdentity = nil
            }
            return
        }
        let identity = info.address + ":" + info.publicKey
        if let previous = self.tonConnectWalletIdentity, previous != identity { self.resetTonConnect() }
        let changed = self.tonConnectWalletIdentity != identity
        self.tonConnectWalletIdentity = identity
        self.updateTonConnectEnvironment(refresh: changed)
    }

    var tonConnectNow: Int32 { Int32(clamping: Int64(self.engine.account.network.globalTime)) }
    var canPresentTonConnect: Bool {
        self.isApplicationInForeground && self.isAccountCurrent && self.authorization.isAvailable && !self.isShutdown
    }

    func publishTonConnectState() {
        let sessions = self.tonConnectSessions.values.filter { !$0.isClosed }.sorted { $0.date > $1.date }.map { session in
            TonConnectSessionInfo(id: session.id, manifest: session.manifest.map(TonConnectManifestInfo.init),
                status: session.isClosing || self.tonConnectDisconnectBodies[session.id] != nil ? .disconnecting : session.isPending ? .connecting : .connected,
                error: self.tonConnectSessionErrors[session.id])
        }
        let active = self.tonConnectActive.flatMap { interaction -> WalletContext.TonConnectActiveRequest? in
            guard let content = interaction.content else { return nil }
            return WalletContext.TonConnectActiveRequest(content: content, status: interaction.status)
        }
        self.output.tonConnectStatePromise.set(WalletContext.TonConnectState(sessions: sessions, active: active,
            presentationEnabled: self.canPresentTonConnect, diagnostic: self.tonConnectDiagnostic))
    }

    func reportTonConnectError(_ error: Error, requestId: String? = nil) {
        self.logger.error("ton_connect_failed", error)
        let failure: TonConnectFailure
        if let value = error as? TonConnectFailure { failure = value }
        else { failure = .unavailable }
        self.tonConnectDiagnostic = TonConnectDiagnostic(id: UUID(), failure: failure, requestId: requestId)
        self.publishTonConnectState()
    }

    func updateTonConnectEnvironment(refresh: Bool) {
        let becameAvailable = self.canPresentTonConnect && !self.tonConnectWasAvailable
        self.tonConnectWasAvailable = self.canPresentTonConnect
        self.publishTonConnectState()
        guard self.canPresentTonConnect else {
            self.tonConnectPreparationTask?.cancel()
            if let active = self.tonConnectActive, !active.lifecycle.ownsClaimAttempt {
                self.authorization.finish(active.authorization)
                active.authorization = nil
            }
            return
        }
        if refresh || becameAvailable, self.isNetworkAvailable, self.tonConnectRefreshTask == nil {
            self.tonConnectRefreshTask = Task { [weak self] in
                guard let self else { return }
                await self.refreshTonConnectFromServer()
            }
        }
        self.advanceTonConnectQueue()
    }

    func refreshTonConnectFromServer() async {
        guard !Task.isCancelled else { return }
        let revision = self.tonConnectRevision
        let epoch = self.tonConnectEpoch
        defer { if epoch == self.tonConnectEpoch { self.tonConnectRefreshTask = nil } }
        do {
            let sessions = try await WalletSignalRequestContext<[WalletTonConnectSession]>().run(self.engine.wallet.tonConnectGetSessions())
            guard !self.isShutdown, epoch == self.tonConnectEpoch else { return }
            let ids = Set(sessions.map(\.id))
            for id in Array(self.tonConnectSessions.keys) where !ids.contains(id) && (self.tonConnectSessionRevisions[id] ?? 0) <= revision {
                self.removeTonConnectSession(id)
            }
            for session in sessions { self.mergeTonConnectSession(session, fetchedAt: revision) }
            self.publishTonConnectState()
            if let active = self.tonConnectActive, active.publication != nil, active.status == .ready {
                if (try? await self.decideTonConnectRequest(id: active.id, approve: active.approved, operationId: UUID())) != nil, active.content == nil || active.wantsRejection {
                    self.finishTonConnect(active)
                }
            }
            await self.finishPendingTonConnectDisconnects()
            self.advanceTonConnectQueue()
        } catch { self.logger.error("ton_connect_refresh_failed", error) }
    }

    func mergeTonConnectSession(_ session: WalletTonConnectSession, fetchedAt revision: UInt64? = nil) {
        if let revision, (self.tonConnectSessionRevisions[session.id] ?? 0) > revision { return }
        self.tonConnectSessions[session.id] = session
        self.tonConnectRevision &+= 1
        self.tonConnectSessionRevisions[session.id] = self.tonConnectRevision
        if session.isClosed { self.tonConnectPendingDisconnects.remove(session.id) }
    }

    func removeTonConnectSession(_ id: Int64) {
        self.tonConnectSessions[id] = nil
        self.tonConnectRevision &+= 1
        self.tonConnectSessionRevisions[id] = self.tonConnectRevision
    }

    func receiveTonConnectUpdates(_ updates: [WalletTonConnectEvent]) {
        guard !self.isShutdown else { return }
        for update in updates {
            switch update {
            case let .session(session):
                self.mergeTonConnectSession(session)
                if let active = self.tonConnectActive, active.session?.id == session.id {
                    let previousKey = active.session?.clientId
                    let previousManifest = active.session?.manifest
                    active.session = session
                    self.logTonConnect("session_update", active, outcome: session.isActive ? "active" : session.isClosed ? "closed" : session.isClosing ? "closing" : "pending")
                    if case .connect = active.source, active.content != nil, previousManifest != session.manifest {
                        self.invalidateTonConnect(active, failure: .invalidManifest)
                    } else if let previousKey, session.clientId != previousKey {
                        self.invalidateTonConnect(active, failure: .keyMismatch)
                    } else if (session.isClosed || session.isClosing) && !active.lifecycle.ownsClaimAttempt {
                        self.invalidateTonConnect(active, failure: .unavailable)
                    } else if session.isClosed || session.isClosing {
                        active.validationError = TonConnectWireFailure(requestId: active.request?.id, code: .unknownApp)
                        if active.lifecycle.phase == .executing { _ = active.valid.swap(false) }
                    } else if session.isActive, case .connect = active.source,
                              active.lifecycle.phase == .pending, active.publication == nil {
                        // Own success can clear publication before this update arrives.
                        self.invalidateTonConnect(active, failure: .handledElsewhere)
                    }
                }
            case let .request(message):
                let key = TonConnectMessageKey(sessionId: message.sessionId, msgId: message.msgId)
                if message.isAccepted || message.isDeclined {
                    self.tonConnectHandledRequests.insert(key)
                    self.tonConnectQueue.removeAll { $0.messageKey == key }
                    if let active = self.tonConnectActive, active.messageKey == key, !active.lifecycle.ownsClaimAttempt {
                        self.invalidateTonConnect(active, failure: .handledElsewhere)
                    }
                } else if message.expires > self.tonConnectNow {
                    self.enqueueTonConnectRequest(sessionId: message.sessionId, msgId: message.msgId)
                }
            case let .pendingDisconnect(sessionIds):
                self.tonConnectPendingDisconnects.formUnion(sessionIds)
            }
        }
        self.updateTonConnectEnvironment(refresh: !self.tonConnectPendingDisconnects.isEmpty)
    }

    func openTonConnectUrl(_ value: String) {
        do {
            if case .empty = self.currentState.phase { throw TonConnectFailure.unavailable }
            if case let .wallet(info) = self.currentState.phase, !info.canSign { throw TonConnectFailure.unavailable }
            let link = try TonConnectLink(value)
            if let raw = link.request {
                let request = try TonConnectConnectRequest(Data(raw.utf8))
                let existing = ([self.tonConnectActive].compactMap { $0 } + self.tonConnectQueue).first {
                    if case let .connect(other, _) = $0.source { return other.peerId == link.peerId }
                    return false
                }
                if let existing {
                    if case let .connect(other, _) = existing.source, other != link { throw TonConnectFailure.conflictingLink }
                    return
                }
                self.tonConnectQueue.append(TonConnectPendingInteraction(.connect(link, request)))
            } else {
                self.tonConnectQueue.append(TonConnectPendingInteraction(.request(.dappClientId(link.peerId), msgId: nil, returnTarget: link.returnTarget)))
            }
            self.advanceTonConnectQueue()
        } catch { self.reportTonConnectError(error) }
    }

    func enqueueTonConnectRequest(sessionId: Int64, msgId: Int64) {
        let key = TonConnectMessageKey(sessionId: sessionId, msgId: msgId)
        guard !self.tonConnectHandledRequests.contains(key), self.tonConnectActive?.messageKey != key,
              !self.tonConnectQueue.contains(where: { $0.messageKey == key }) else { return }
        self.tonConnectQueue.append(TonConnectPendingInteraction(.request(.sessionId(sessionId), msgId: msgId, returnTarget: .none)))
        self.advanceTonConnectQueue()
    }

    func advanceTonConnectQueue() {
        guard self.canPresentTonConnect, self.isNetworkAvailable, self.currentState.activeOperation == nil,
              case let .wallet(info) = self.currentState.phase, info.canSign,
              self.tonConnectPreparationTask == nil else { return }
        if self.tonConnectActive == nil, !self.tonConnectQueue.isEmpty {
            self.tonConnectActive = self.tonConnectQueue.removeFirst()
        }
        guard let active = self.tonConnectActive, active.wallet == nil, !active.preparationFailed, active.valid.with({ $0 }) else { return }
        self.publishTonConnectState()
        self.tonConnectPreparationTask = Task { [weak self] in
            guard let self else { return }
            await self.prepareTonConnect(active)
        }
    }

    func prepareTonConnect(_ active: TonConnectPendingInteraction) async {
        guard self.tonConnectActive === active else { return }
        let epoch = self.tonConnectEpoch
        defer {
            if epoch == self.tonConnectEpoch {
                self.tonConnectPreparationTask = nil
                self.advanceTonConnectQueue()
            }
        }
        do {
            let wallet = try await self.runtime.tonConnectIdentity()
            try self.checkTonConnect(active)
            switch active.source {
            case let .connect(link, request):
                let revision = self.tonConnectRevision
                let session = try await WalletSignalRequestContext<WalletTonConnectSession>().run(
                    self.engine.wallet.tonConnectCreateSession(dappClientId: link.peerId, manifestUrl: request.prompt.manifestUrl))
                self.mergeTonConnectSession(session, fetchedAt: revision)
                active.session = self.tonConnectSessions[session.id] ?? session
                self.logTonConnect("session_created", active)
                try self.checkTonConnect(active)
                if active.session?.isActive == true { throw TonConnectFailure.handledElsewhere }
                // A stalled getPending must not extend the manifest deadline.
                let deadline = Date().addingTimeInterval(30)
                let reconcile = Task { [weak self] in await self?.reconcileTonConnectSession(session.id) }
                defer { reconcile.cancel() }
                while active.session?.manifest == nil && active.session?.manifestError == nil && !active.wantsRejection {
                    try self.checkTonConnect(active)
                    guard Date() < deadline else { throw TonConnectFailure.invalidManifest }
                    try await Task.sleep(nanoseconds: 100_000_000)
                }
                try self.checkTonConnect(active)
                guard let current = active.session else { throw TonConnectFailure.unavailable }
                _ = try self.checkTonConnectConnection(active, matching: current)
                guard current.manifestError == nil, let manifest = current.manifest else { throw TonConnectFailure.invalidManifest }
                let info = TonConnectManifestInfo(manifest)
                guard !info.domain.isEmpty else { throw TonConnectFailure.invalidManifest }
                active.wallet = wallet
                active.content = .connect(Self.tonConnectPrompt(id: active.id, manifest: info, request: request))
                self.logTonConnect("manifest_ready", active)
            case let .request(lookup, msgId, _):
                let revision = self.tonConnectRevision
                let pending = try await WalletSignalRequestContext<WalletTonConnectPending>().run(self.engine.wallet.tonConnectGetPending(lookup: lookup))
                self.mergeTonConnectSession(pending.session, fetchedAt: revision)
                let session = self.tonConnectSessions[pending.session.id] ?? pending.session
                active.session = session
                let requests = pending.requests.filter { $0.sessionId == session.id && $0.expires > self.tonConnectNow }
                guard let envelope = requests.first(where: { msgId == nil || $0.msgId == msgId }) else {
                    self.finishTonConnect(active)
                    return
                }
                active.envelope = envelope
                if msgId == nil {
                    self.tonConnectQueue.removeAll { $0.messageKey == active.messageKey }
                    for other in requests where other.msgId != envelope.msgId {
                        self.enqueueTonConnectRequest(sessionId: session.id, msgId: other.msgId)
                    }
                }
                guard !self.tonConnectHandledRequests.contains(active.messageKey!) else { throw TonConnectFailure.handledElsewhere }
                try await self.authorizeTonConnect(active)
                let body = try await self.authorization.withSession(active.authorization) { try await self.runtime.openTonConnectPacket(envelope.body, wallet: wallet, session: session) }
                do {
                    active.request = try TonConnectWireCodec.decodeRequest(body, wallet: wallet, now: UInt64(max(0, self.tonConnectNow)), operationId: active.id)
                } catch let error as TonConnectWireFailure {
                    guard error.requestId != nil else { throw error }
                    active.validationError = error
                }
                active.wallet = wallet
                try self.checkTonConnect(active)
                self.scheduleTonConnectExpiry(active)
                let automaticError: TonConnectWireErrorCode?
                if session.isClosed || session.isClosing || session.isPending { automaticError = .unknownApp }
                else if active.validationError != nil { automaticError = .badRequest }
                else if case .unsupported = active.request { automaticError = .methodNotSupported }
                else { automaticError = nil }
                if let automaticError {
                    active.validationError = TonConnectWireFailure(requestId: active.request?.id ?? active.validationError?.requestId, code: automaticError)
                }
                if automaticError != nil || { if case .disconnect = active.request { return true }; return false }() {
                    _ = try await self.decideTonConnectRequest(id: active.id, approve: true, operationId: UUID())
                    self.finishTonConnect(active)
                    return
                }
                guard let manifest = session.manifest else { throw TonConnectFailure.invalidManifest }
                let info = TonConnectManifestInfo(manifest)
                switch active.request {
                case let .sendTransaction(_, request):
                    let preview = try await self.authorization.withSession(active.authorization) { try await self.runtime.previewTonConnect(request, wallet: wallet) }
                    active.content = .operation(Self.tonConnectOperation(id: active.id, manifest: info, send: preview, sign: nil))
                case let .signMessage(_, request):
                    let preview = try await self.authorization.withSession(active.authorization) { try await self.runtime.previewSignMessage(request, wallet: wallet) }
                    active.content = .operation(Self.tonConnectOperation(id: active.id, manifest: info, send: nil, sign: preview))
                case let .signData(_, payload):
                    _ = try payload.digest(address: wallet.address, domain: info.domain, timestamp: UInt64(max(0, self.tonConnectNow)))
                    active.content = .signData(WalletContext.TonConnectSignDataRequest(id: active.id, applicationName: info.name,
                        domain: info.domain, iconUrl: info.iconUrl, payload: payload.content, address: wallet.address, network: wallet.network))
                default: throw TonConnectFailure.unavailable
                }
            }
            try self.checkTonConnect(active)
            self.publishTonConnectState()
        } catch {
            self.logTonConnect("preparation_failed", active, error: error)
            guard self.tonConnectActive === active else { return }
            if active.publication != nil {
                active.status = .ready
                self.reportTonConnectError(TonConnectFailure.bridgeUnavailable)
            } else if !self.canPresentTonConnect, active.valid.with({ $0 }) {
                active.wallet = nil
                self.authorization.finish(active.authorization)
                active.authorization = nil
            } else if case .connect = active.source, !active.wantsRejection, active.valid.with({ $0 }),
                      (error as? TonConnectFailure) != .keyMismatch, (error as? TonConnectFailure) != .handledElsewhere {
                active.preparationFailed = true
                active.wallet = nil
                self.authorization.finish(active.authorization)
                active.authorization = nil
                active.content = nil
                self.reportTonConnectError(error, requestId: active.id)
            } else {
                self.reportTonConnectError(error)
                self.finishTonConnect(active)
            }
        }
    }

    func reconcileTonConnectSession(_ id: Int64) async {
        let revision = self.tonConnectRevision
        let epoch = self.tonConnectEpoch
        do {
            let pending = try await WalletSignalRequestContext<WalletTonConnectPending>().run(self.engine.wallet.tonConnectGetPending(lookup: .sessionId(id)))
            guard !Task.isCancelled, !self.isShutdown, epoch == self.tonConnectEpoch else { return }
            self.mergeTonConnectSession(pending.session, fetchedAt: revision)
            if self.tonConnectActive?.session?.id == id { self.tonConnectActive?.session = self.tonConnectSessions[id] }
        } catch { self.logger.error("ton_connect_reconcile_failed", error) }
    }

    func authorizeTonConnect(_ active: TonConnectPendingInteraction) async throws {
        if let session = active.authorization, (try? self.authorization.validate(session)) != nil { return }
        self.authorization.finish(active.authorization)
        active.authorization = try await self.authorization.beginSession(id: UUID(), reason: "TON Connect", lifetime: .ownerManaged)
        try self.checkTonConnect(active)
    }

    func checkTonConnect(_ active: TonConnectPendingInteraction) throws {
        try Task.checkCancellation()
        guard self.tonConnectActive === active, active.valid.with({ $0 }), self.canPresentTonConnect else { throw TonConnectFailure.unavailable }
        if let envelope = active.envelope, envelope.expires <= self.tonConnectNow { throw TonConnectFailure.expired }
        if let until = active.request?.validUntil, until <= UInt64(max(0, self.tonConnectNow)) { throw TonConnectFailure.expired }
    }

    private func checkTonConnectConnection(_ active: TonConnectPendingInteraction, matching expected: WalletTonConnectSession, clientId: String? = nil) throws -> WalletTonConnectSession {
        try self.checkTonConnect(active)
        guard let current = active.session, current.id == expected.id,
              current.dappClientId == expected.dappClientId, current.nonce == expected.nonce,
              current.manifest == expected.manifest, current.manifestError == expected.manifestError,
              !current.isClosing, !current.isClosed else { throw TonConnectFailure.unavailable }
        guard current.isPending else { throw TonConnectFailure.handledElsewhere }
        if let expectedKey = clientId ?? expected.clientId, let currentKey = current.clientId, expectedKey != currentKey {
            throw TonConnectFailure.keyMismatch
        }
        return current
    }

    func scheduleTonConnectExpiry(_ active: TonConnectPendingInteraction) {
        guard let envelope = active.envelope else { return }
        active.expiryTask?.cancel()
        let expiry = min(Int64(envelope.expires), Int64(clamping: active.request?.validUntil ?? UInt64(Int32.max)))
        let delay = max(0, expiry - Int64(self.tonConnectNow))
        active.expiryTask = Task { [weak self, weak active] in
            guard let self, let active else { return }
            do { try await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000) } catch { return }
            await self.invalidateTonConnect(active, failure: .expired)
        }
    }

    func invalidateTonConnect(_ active: TonConnectPendingInteraction, failure: TonConnectFailure) {
        _ = active.valid.swap(false)
        if !active.lifecycle.ownsClaimAttempt { active.lifecycle.stop() }
        active.status = .invalidated
        if let key = active.messageKey { self.tonConnectHandledRequests.insert(key) }
        self.reportTonConnectError(failure)
        if active.content == nil && !active.lifecycle.ownsClaimAttempt { self.finishTonConnect(active) }
    }

    func rejectTonConnectRequest(id: String) async {
        guard let active = self.tonConnectActive, active.id == id else { return }
        if case .connect = active.source, active.status != .ready { return }
        active.wantsRejection = true
        if case .connect = active.source, active.publication == nil {
            guard let session = active.authorization, (try? self.authorization.validate(session)) != nil else {
                self.finishTonConnect(active)
                return
            }
        }
        guard active.wallet != nil else {
            self.retryTonConnectPreparation(id: id)
            return
        }
        do {
            _ = try await self.decideTonConnectRequest(id: id, approve: false, operationId: UUID())
            self.finishTonConnect(active)
        } catch {
            self.reportTonConnectError(error)
            if active.publication == nil { self.finishTonConnect(active) }
        }
    }

    func retryTonConnectPreparation(id: String) {
        guard let active = self.tonConnectActive, active.id == id, active.preparationFailed else { return }
        active.preparationFailed = false
        if self.tonConnectDiagnostic?.requestId == id { self.tonConnectDiagnostic = nil }
        self.publishTonConnectState()
        self.advanceTonConnectQueue()
    }

    func closeTonConnectPresentation(id: String) {
        guard let active = self.tonConnectActive, active.id == id, active.status != .processing,
              !active.lifecycle.ownsClaimAttempt else { return }
        self.finishTonConnect(active)
    }

    func finishTonConnect(_ active: TonConnectPendingInteraction) {
        guard self.tonConnectActive === active else { return }
        active.expiryTask?.cancel()
        self.authorization.finish(active.authorization)
        active.authorization = nil
        if self.tonConnectDiagnostic?.requestId == active.id { self.tonConnectDiagnostic = nil }
        self.tonConnectActive = nil
        self.publishTonConnectState()
        self.advanceTonConnectQueue()
        if !self.tonConnectPendingDisconnects.isEmpty {
            Task { await self.finishPendingTonConnectDisconnects() }
        }
    }

    func decideTonConnectRequest(id: String, approve: Bool, operationId: UUID) async throws -> TonConnectDecision {
        guard let active = self.tonConnectActive, active.id == id, active.status == .ready,
              let session = active.session, let wallet = active.wallet else { throw WalletError.unavailable }
        active.status = .processing
        self.publishTonConnectState()
        do {
            if active.publication != nil { return try await self.publishTonConnect(active) }
            try self.checkTonConnect(active)
            if approve, let request = active.request, request.consumesWalletSequenceNumber {
                // Wait for API transfers before taking the wallet operation slot.
                guard case let .wallet(info) = self.currentState.phase else { throw WalletError.unavailable }
                _ = try await self.waitForPreviousWalletTransfer(wallet: info, generation: self.activationGeneration,
                    operationId: operationId, expiresAt: Int32(clamping: request.validUntil ?? UInt64(max(0, self.tonConnectNow + 300))))
                try self.checkTonConnect(active)
            }
            if case .connect = active.source, !approve {
                guard let authorization = active.authorization else { throw WalletError.authorizationCancelled }
                try self.authorization.validate(authorization)
            } else {
                if case .connect = active.source { self.logTonConnect("authorization_started", active) }
                try await self.authorizeTonConnect(active)
                if case .connect = active.source { self.logTonConnect("authorization_succeeded", active) }
            }
            return try await self.performOperation(.tonConnect, operationId: operationId, session: active.authorization) {
                try self.checkTonConnect(active)
                if approve, active.request?.consumesWalletSequenceNumber == true {
                    // A native transfer may have started during authorization.
                    try await self.runtime.ensureApiTransferAllowsSigning()
                }
                let generation = try self.authorization.operationGeneration()
                let valid = active.valid
                let authorization = self.authorization
                let network = self.engine.account.network
                let expiry = active.envelope?.expires
                let validUntil = active.request?.validUntil
                let beforeSigning: @Sendable () throws -> Void = {
                    guard valid.with({ $0 }) else { throw TonConnectFailure.unavailable }
                    try authorization.validateGeneration(generation)
                    let now = network.globalTime
                    if let expiry, Double(expiry) <= now { throw TonConnectFailure.expired }
                    if let validUntil, Double(validUntil) <= now { throw TonConnectFailure.expired }
                }
                let response: Data
                switch active.source {
                case let .connect(link, request):
                    var current = try self.checkTonConnectConnection(active, matching: session)
                    guard try await self.runtime.tonConnectIdentity() == wallet else { throw TonConnectFailure.keyMismatch }
                    current = try self.checkTonConnectConnection(active, matching: session)
                    let key = try await self.runtime.tonConnectSessionPublicKey(wallet: wallet, session: current)
                    current = try self.checkTonConnectConnection(active, matching: session, clientId: key)
                    self.logTonConnect("register_key_started", active, walletClientId: key)
                    let challenge = try await WalletSignalRequestContext<WalletTonConnectChallenge>().run(
                        self.engine.wallet.tonConnectRegisterKey(sessionId: current.id, clientId: key))
                    active.connectEventId = challenge.eventId
                    self.logTonConnect("register_key_succeeded", active, walletClientId: key)
                    current = try self.checkTonConnectConnection(active, matching: session, clientId: key)
                    let answer = try await self.runtime.openTonConnectChallenge(challenge.challenge, wallet: wallet, session: current)
                    current = try self.checkTonConnectConnection(active, matching: session, clientId: key)
                    let registered = WalletTonConnectSession(flags: current.flags | (1 << 3), id: current.id,
                        dappClientId: current.dappClientId, clientId: key, nonce: current.nonce,
                        manifest: current.manifest, manifestError: current.manifestError, date: current.date)
                    self.mergeTonConnectSession(registered)
                    active.session = registered
                    self.logTonConnect("challenge_verified", active)
                    if approve {
                        guard let manifest = session.manifest else { throw TonConnectFailure.invalidManifest }
                        let domain = TonConnectManifestInfo(manifest).domain
                        let account = try await self.runtime.tonConnectAccount(wallet: wallet)
                        _ = try self.checkTonConnectConnection(active, matching: session, clientId: key)
                        if let network = request.prompt.requestedNetwork, network != account.network { throw TonConnectFailure.wrongNetwork }
                        let timestamp = UInt64(max(0, self.tonConnectNow))
                        let proof: TonConnectProofSignature?
                        if let payload = request.prompt.proofPayload {
                            proof = try await self.runtime.signTonConnectProof(wallet: wallet, domain: domain, timestamp: timestamp,
                                payload: payload, beforeSigning: beforeSigning)
                        } else { proof = nil }
                        let device = await Self.tonConnectDevice()
                        response = try TonConnectWireCodec.connectEvent(serverEventId: challenge.eventId, request: request,
                            account: account, domain: domain, timestamp: timestamp, proof: proof,
                            appName: "Telegram", appVersion: device.version, platform: device.platform)
                    } else {
                        response = try TonConnectWireCodec.connectErrorEvent(serverEventId: challenge.eventId, code: .userDeclined)
                    }
                    try beforeSigning()
                    _ = try self.checkTonConnectConnection(active, matching: session, clientId: key)
                    let body = try await self.runtime.sealTonConnectPacket(response, wallet: wallet, session: registered)
                    _ = try self.checkTonConnectConnection(active, matching: session, clientId: key)
                    active.publication = .connect(answer: answer, body: body, isError: !approve, traceId: link.traceId)
                    self.logTonConnect("packet_prepared", active, body: body, outcome: approve ? "connect" : "connect_error")
                case .request:
                    guard let envelope = active.envelope, let requestId = active.request?.id ?? active.validationError?.requestId else {
                        throw TonConnectFailure.unavailable
                    }
                    try await self.runtime.validateTonConnectAccess(wallet: wallet)
                    var answer: Data?
                    if !self.tonConnectProvenSessions.contains(session.id) {
                        let key = try await self.runtime.tonConnectSessionPublicKey(wallet: wallet, session: session)
                        let challenge = try await WalletSignalRequestContext<WalletTonConnectChallenge>().run(
                            self.engine.wallet.tonConnectRegisterKey(sessionId: session.id, clientId: key))
                        answer = try await self.runtime.openTonConnectChallenge(challenge.challenge, wallet: wallet, session: session)
                    }
                    try beforeSigning()
                    guard active.lifecycle.beginClaim() else { throw TonConnectFailure.outcomeUnknown }
                    do {
                        let claimed = try await WalletSignalRequestContext<Bool>().run(self.engine.wallet.tonConnectClaimRequest(
                            sessionId: session.id, msgId: envelope.msgId, appRequestId: requestId.apiValue,
                            challengeAnswer: answer, declined: !approve))
                        guard claimed, active.lifecycle.claimSucceeded() else { throw TonConnectFailure.handledElsewhere }
                    } catch {
                        active.lifecycle.stop()
                        _ = active.valid.swap(false)
                        self.tonConnectHandledRequests.insert(TonConnectMessageKey(sessionId: session.id, msgId: envelope.msgId))
                        // A failed claim forbids both signing and submitResponse.
                        if case let WalletTonConnectError.rpc(_, description) = error {
                            switch description {
                            case "TONCONNECT_REQUEST_ALREADY_CLAIMED", "TONCONNECT_REQUEST_NOT_FOUND": throw TonConnectFailure.handledElsewhere
                            case "TONCONNECT_REQUEST_EXPIRED": throw TonConnectFailure.expired
                            default: break
                            }
                        }
                        throw error
                    }
                    self.tonConnectProvenSessions.insert(session.id)
                    self.tonConnectHandledRequests.insert(TonConnectMessageKey(sessionId: session.id, msgId: envelope.msgId))
                    try self.checkTonConnect(active)
                    if !approve {
                        response = try TonConnectWireCodec.errorResponse(id: requestId, code: .userDeclined)
                    } else if let failure = active.validationError {
                        response = try TonConnectWireCodec.errorResponse(id: requestId, code: failure.code)
                    } else if case .disconnect = active.request {
                        response = try TonConnectWireCodec.successResponse(id: requestId, result: .object([:]))
                    } else {
                        guard active.lifecycle.beginExecution() else { throw TonConnectFailure.outcomeUnknown }
                        do {
                            try beforeSigning()
                            let result: TonConnectJSONValue
                            switch active.request {
                            case let .sendTransaction(_, request):
                                let sent = try await self.runtime.sendTonConnect(request, wallet: wallet, beforeSigning: beforeSigning)
                                guard walletEngineAcceptsSubmission(sent.phase) else { throw TonConnectFailure.outcomeUnknown }
                                result = .string(sent.signedBoc)
                                self.requestSynchronization(scope: [.account, .transactions], force: true)
                            case let .signMessage(_, request):
                                let signed = try await self.runtime.signMessage(request, wallet: wallet, beforeSigning: beforeSigning)
                                guard walletEngineAcceptsSignHandoff(signed.phase) else { throw TonConnectFailure.outcomeUnknown }
                                result = .object(["internalBoc": .string(signed.internalBoc)])
                            case let .signData(_, payload):
                                guard let manifest = session.manifest else { throw TonConnectFailure.invalidManifest }
                                let domain = TonConnectManifestInfo(manifest).domain
                                let timestamp = UInt64(max(0, self.tonConnectNow))
                                let digest = try payload.digest(address: wallet.address, domain: domain, timestamp: timestamp)
                                let signature = try await self.runtime.signTonConnectData(digest, wallet: wallet, beforeSigning: beforeSigning)
                                result = try payload.response(signature: signature, address: wallet.address, domain: domain, timestamp: timestamp)
                            default: throw TonConnectFailure.unavailable
                            }
                            response = try TonConnectWireCodec.successResponse(id: requestId, result: result)
                        } catch {
                            // The FFI may wrap expiry errors; recheck MTProto time.
                            try self.checkTonConnect(active)
                            self.logger.error("ton_connect_execution_failed", error)
                            active.failure = error as? TonConnectFailure ?? .unavailable
                            response = try TonConnectWireCodec.errorResponse(id: requestId, code: .unknown)
                        }
                    }
                    let body = try await self.runtime.sealTonConnectPacket(response, wallet: wallet, session: session)
                    active.publication = .response(msgId: envelope.msgId, body: body, traceId: envelope.traceId)
                }
                active.approved = approve
                active.lifecycle.prepared()
                return try await self.publishTonConnect(active)
            }
        } catch {
            self.logTonConnect("decision_failed", active, error: error)
            guard self.tonConnectActive === active else { throw error }
            if active.publication != nil {
                active.status = .ready
            } else if active.lifecycle.phase != .pending {
                active.lifecycle.stop()
                active.status = .invalidated
                _ = active.valid.swap(false)
                self.reportTonConnectError(error as? TonConnectFailure ?? .outcomeUnknown)
            } else if (error as? TonConnectFailure) == .expired {
                self.invalidateTonConnect(active, failure: .expired)
            } else {
                active.status = active.valid.with({ $0 }) ? .ready : .invalidated
            }
            self.publishTonConnectState()
            throw error
        }
    }

    func publishTonConnect(_ active: TonConnectPendingInteraction) async throws -> TonConnectDecision {
        guard !self.isShutdown, self.tonConnectActive === active, let session = active.session, let publication = active.publication else { throw TonConnectFailure.unavailable }
        let signal: Signal<Bool, WalletTonConnectError>
        let packet: Data
        switch publication {
        case let .connect(answer, body, isError, traceId):
            packet = body
            signal = self.engine.wallet.tonConnectSubmitConnectResult(sessionId: session.id, challengeAnswer: answer,
                body: body, isError: isError, traceId: traceId)
        case let .response(msgId, body, traceId):
            packet = body
            signal = self.engine.wallet.tonConnectSubmitResponse(sessionId: session.id, msgId: msgId, body: body, traceId: traceId)
        }
        self.logTonConnect("publish_started", active, body: packet)
        let accepted: Bool
        do {
            accepted = try await WalletSignalRequestContext<Bool>().run(signal)
        } catch {
            self.logTonConnect("publish_failed", active, body: packet, error: error)
            throw error
        }
        // RPC acceptance is not an acknowledgement from the dApp.
        self.logTonConnect("publish_result", active, body: packet, outcome: accepted ? "server_accepted" : "server_rejected")
        guard !self.isShutdown, self.tonConnectActive === active else { throw TonConnectFailure.unavailable }
        guard accepted else { throw TonConnectFailure.bridgeUnavailable }
        active.publication = nil
        active.lifecycle.completed()
        active.expiryTask?.cancel()
        if case let .connect(_, _, isError, _) = publication {
            if isError { self.removeTonConnectSession(session.id) }
            else {
                self.tonConnectProvenSessions.insert(session.id)
                // The authoritative active-session update may have arrived first.
                if self.tonConnectSessions[session.id]?.isPending == true {
                    self.mergeTonConnectSession(WalletTonConnectSession(flags: session.flags & ~1,
                        id: session.id, dappClientId: session.dappClientId, clientId: session.clientId,
                        nonce: session.nonce, manifest: session.manifest, manifestError: nil, date: session.date))
                }
            }
        } else if case .disconnect = active.request {
            self.removeTonConnectSession(session.id)
        }
        let decision = TonConnectDecision(approved: active.approved && active.failure == nil, failure: active.failure, returnTarget: active.returnTarget)
        active.status = .completed(decision)
        self.publishTonConnectState()
        return decision
    }

    func disconnectTonConnectSessions(ids: [Int64]?, operationId: UUID) async {
        let ids = ids ?? self.tonConnectSessions.values.filter { !$0.isClosed }.map(\.id)
        let epoch = self.tonConnectEpoch
        do {
            try await self.performOperation(.tonConnect, operationId: operationId) {
                let wallet = try await self.runtime.tonConnectIdentity()
                for id in ids {
                    guard epoch == self.tonConnectEpoch, !self.isShutdown else { return }
                    guard let session = self.tonConnectSessions[id], !session.isClosed else { continue }
                    do {
                        if self.tonConnectDisconnectBodies[id] == nil {
                            let eventId = try await WalletSignalRequestContext<Int64>().run(self.engine.wallet.tonConnectNextEventId(sessionId: id))
                            let event = try TonConnectWireCodec.disconnectEvent(serverEventId: eventId)
                            let body = try await self.runtime.sealTonConnectPacket(event, wallet: wallet, session: session)
                            guard epoch == self.tonConnectEpoch, !self.isShutdown else { return }
                            self.tonConnectDisconnectBodies[id] = body
                        }
                        self.publishTonConnectState()
                        let accepted = try await WalletSignalRequestContext<Bool>().run(self.engine.wallet.tonConnectCloseSession(sessionId: id, body: self.tonConnectDisconnectBodies[id]!))
                        guard epoch == self.tonConnectEpoch, !self.isShutdown else { return }
                        guard accepted else { throw TonConnectFailure.bridgeUnavailable }
                        self.tonConnectDisconnectBodies[id] = nil
                        self.tonConnectSessionErrors[id] = nil
                        self.tonConnectPendingDisconnects.remove(id)
                        self.removeTonConnectSession(id)
                        if let active = self.tonConnectActive, active.session?.id == id { self.invalidateTonConnect(active, failure: .unavailable) }
                    } catch {
                        guard epoch == self.tonConnectEpoch, !self.isShutdown else { return }
                        self.tonConnectSessionErrors[id] = error as? TonConnectFailure ?? .bridgeUnavailable
                        self.logger.error("ton_connect_disconnect_failed", error)
                    }
                }
            }
        } catch {
            guard epoch == self.tonConnectEpoch, !self.isShutdown else { return }
            for id in ids { self.tonConnectSessionErrors[id] = error as? TonConnectFailure ?? .unavailable }
        }
        self.publishTonConnectState()
    }

    func finishPendingTonConnectDisconnects() async {
        guard self.canPresentTonConnect, self.currentState.activeOperation == nil, self.tonConnectActive == nil else { return }
        let ids = self.tonConnectPendingDisconnects.union(self.tonConnectDisconnectBodies.keys)
        guard !ids.isEmpty else { return }
        await self.disconnectTonConnectSessions(ids: Array(ids), operationId: UUID())
    }

    @MainActor private static func tonConnectDevice() -> (platform: String, version: String) {
        #if os(iOS)
        let platform = UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
        #else
        let platform = "mac"
        #endif
        return (platform, Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0")
    }
}

@available(macOS 10.15, *)
extension WalletContextImpl {
    private static func tonConnectPrompt(
        id: String,
        manifest: TonConnectManifestInfo,
        request: TonConnectConnectRequest
    ) -> WalletContext.TonConnectRequest {
        var permissions = [WalletContext.TonConnectPermission(
            name: "ton_addr",
            title: "Wallet address",
            text: "Allow this app to see your wallet address"
        )]
        if request.prompt.proofPayload != nil {
            permissions.append(WalletContext.TonConnectPermission(
                name: "ton_proof",
                title: "Ownership proof",
                text: "Sign a domain-bound wallet ownership proof"
            ))
        }
        return WalletContext.TonConnectRequest(
            id: id,
            applicationName: manifest.name,
            domain: manifest.domain,
            iconUrl: manifest.iconUrl,
            permissions: permissions,
            requestsProof: request.prompt.proofPayload != nil
        )
    }

    private static func tonConnectOperation(
        id: String,
        manifest: TonConnectManifestInfo,
        send: SendPreview?,
        sign: SignMessagePreview?
    ) -> WalletContext.TonConnectOperationRequest {
        let method: WalletContext.TonConnectOperationRequest.Method = send == nil ? .signMessage : .sendTransaction
        let engineMessages = send?.messages ?? sign?.messages ?? []
        let messages = engineMessages.enumerated().map { index, value in
            let amount: String
            switch value.amount {
            case let .exact(nanograms): amount = nanograms
            case .all: amount = "all"
            }
            let payload: WalletContext.TonConnectOperationRequest.Message.Payload
            switch value.body {
            case .empty: payload = .empty
            case let .comment(text): payload = .comment(text)
            case let .rawPayload(boc): payload = .raw(boc)
            }
            return WalletContext.TonConnectOperationRequest.Message(
                id: "\(id):\(index)",
                destination: value.destination,
                amountNanograms: amount,
                payload: payload,
                stateInit: value.stateInit
            )
        }
        var warnings: [String] = []
        if let preview = send,
           (!preview.emulation.traceSucceeded || preview.emulation.isIncomplete) {
            warnings.append("Some emulated actions may fail or the trace is incomplete.")
        }
        if sign != nil {
            warnings.append("The wallet will not broadcast this message. The dApp may relay it until expiration.")
        }
        return WalletContext.TonConnectOperationRequest(
            id: id,
            applicationName: manifest.name,
            domain: manifest.domain,
            iconUrl: manifest.iconUrl,
            method: method,
            messages: messages,
            feeNanograms: send?.emulation.walletFeesNanograms,
            validUntil: send?.validUntil ?? sign?.validUntil,
            relayerWillSubmit: sign != nil,
            needsWalletStateInit: sign?.needsStateInit ?? false,
            warnings: warnings,
            actions: send?.emulation.actions.map {
                WalletContext.TonConnectOperationRequest.Action(
                    id: $0.actionId,
                    kind: $0.kind,
                    succeeded: $0.succeeded,
                    accounts: $0.accounts,
                    detailsJson: $0.detailsJson
                )
            } ?? []
        )
    }

}
