import Foundation
import WalletEngineFFI
#if os(iOS)
import UIKit
#endif

actor WalletTonConnectCoordinator {
    private let runtime: WalletEngineRuntime
    private let storage: WalletEngineStorage
    private let recordId: String
    private let event: @Sendable (WalletContext.TonConnectState, UInt64) async -> Void
    private var service: TonConnectService?
    private var setupTask: Task<TonConnectService, Error>?
    private var isShutdown = false
    private var presentationEnabled = false
    private var networkEnabled = false
    private var environmentRevision: UInt64?
    private var setupGeneration: UInt64 = 0
    private var receivedRevision: UInt64 = 0
    private var publishedRevision: UInt64 = 0
    private var currentState: WalletContext.TonConnectState = .empty

    init(runtime: WalletEngineRuntime, storage: WalletEngineStorage, logger: WalletLogger, recordId: String,
         event: @escaping @Sendable (WalletContext.TonConnectState, UInt64) async -> Void) {
        self.runtime = runtime
        self.storage = storage
        self.recordId = recordId
        self.event = event
    }

    func restore() async {
        do { _ = try await self.ready() } catch { await self.report(error) }
    }

    func start(link: String) async throws {
        let service = try await self.ready()
        try await service.open(link)
    }

    func approveConnection(id: String) async throws {
        let service = try await self.ready()
        _ = try await service.decide(id: id, approve: true)
    }

    func approveOperation(id: String) async throws {
        let service = try await self.ready()
        _ = try await service.decide(id: id, approve: true)
    }

    func reject(id: String) async {
        do { let service = try await self.ready(); _ = try await service.decide(id: id, approve: false) }
        catch { await self.report(error) }
    }

    func presentationClosed(id: String, rejectIfPending: Bool) async -> TonConnectReturnTarget? {
        await self.service?.presentationClosed(id: id, rejectIfPending: rejectIfPending)
    }

    func disconnect(id: String?) async {
        guard let service = self.service else { return }
        if let id { await service.disconnect(sessionId: id) } else { await service.disconnectAll() }
    }

    func setEnvironment(presentationEnabled: Bool, networkEnabled: Bool, revision: UInt64) async {
        guard !self.isShutdown else { return }
        if let previous = self.environmentRevision, revision <= previous { return }
        self.environmentRevision = revision
        self.presentationEnabled = presentationEnabled
        self.networkEnabled = networkEnabled
        if let service = self.service {
            await service.setEnvironment(presentationEnabled: presentationEnabled, networkEnabled: networkEnabled, revision: revision &+ 1)
        } else {
            await self.publish(WalletContext.TonConnectState(sessions: self.currentState.sessions, active: self.currentState.active,
                presentationEnabled: presentationEnabled, diagnostic: self.currentState.diagnostic))
            if networkEnabled { await self.restore() }
        }
    }

    func shutdown() async {
        self.isShutdown = true
        await self.service?.shutdown()
        if let setupTask = self.setupTask, let service = try? await setupTask.value { await service.shutdown() }
        self.service = nil
    }

    private func ready() async throws -> TonConnectService {
        guard !self.isShutdown else { throw TonConnectFailure.unavailable }
        if let setupTask = self.setupTask { return try await setupTask.value }
        let task = Task { try await self.setup() }
        self.setupTask = task
        do { return try await task.value } catch { self.setupTask = nil; throw error }
    }

    private func setup() async throws -> TonConnectService {
        self.setupGeneration &+= 1
        let generation = self.setupGeneration
        self.receivedRevision = 0
        let identity = try await self.runtime.tonConnectIdentity(recordId: self.recordId)
        guard !self.isShutdown else { throw TonConnectFailure.unavailable }
        let device = await Self.device
        guard !self.isShutdown else { throw TonConnectFailure.unavailable }
        let service = TonConnectService(identity: identity, storage: self.storage,
            wallet: WalletTonConnectExecutor(runtime: self.runtime), device: device,
            changed: { [weak self] state in await self?.receive(state, generation: generation) })
        self.service = service
        await service.setEnvironment(presentationEnabled: self.presentationEnabled, networkEnabled: self.networkEnabled,
                                     revision: (self.environmentRevision ?? 0) &+ 1)
        do {
            try await service.restore()
        } catch {
            await service.shutdown()
            self.service = nil
            throw error
        }
        guard !self.isShutdown else { await service.shutdown(); throw TonConnectFailure.unavailable }
        return service
    }

    private func receive(_ state: TonConnectServiceState, generation: UInt64) async {
        guard !self.isShutdown, generation == self.setupGeneration, state.revision > self.receivedRevision else { return }
        self.receivedRevision = state.revision
        let active: WalletContext.TonConnectActiveRequest?
        if let value = state.active {
            let presentation: WalletContext.TonConnectActiveRequest.Content
            switch value.interaction.content {
            case let .connect(prompt):
                presentation = .connect(Self.connectModel(id: value.interaction.id, manifest: value.interaction.manifest, prompt: prompt))
            case let .operation(request, preview):
                switch preview {
                case let .send(preview):
                    presentation = .operation(Self.operationModel(id: value.interaction.id, manifest: value.interaction.manifest, request: request, sendPreview: preview, signPreview: nil))
                case let .sign(preview):
                    presentation = .operation(Self.operationModel(id: value.interaction.id, manifest: value.interaction.manifest, request: request, sendPreview: nil, signPreview: preview))
                }
            }
            active = WalletContext.TonConnectActiveRequest(content: presentation, status: value.status)
        } else { active = nil }
        await self.publish(WalletContext.TonConnectState(sessions: state.sessions, active: active,
                                                       presentationEnabled: state.presentationEnabled, diagnostic: state.diagnostic))
    }

    private func report(_ error: Error) async {
        guard !self.isShutdown else { return }
        await self.publish(WalletContext.TonConnectState(sessions: self.currentState.sessions, active: self.currentState.active,
            presentationEnabled: self.presentationEnabled,
            diagnostic: TonConnectDiagnostic(id: UUID(), failure: error as? TonConnectFailure ?? .unavailable)))
    }

    private func publish(_ state: WalletContext.TonConnectState) async {
        self.currentState = state
        self.publishedRevision &+= 1
        await self.event(state, self.publishedRevision)
    }

    private static func connectModel(
        id: String,
        manifest: TonConnectManifestInfo,
        prompt: TonConnectConnectPrompt
    ) -> WalletContext.TonConnectRequest {
        var permissions = [WalletContext.TonConnectPermission(
            name: "ton_addr",
            title: "Wallet address",
            text: "Allow this app to see your wallet address"
        )]
        if prompt.proofPayload != nil {
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
            requestsProof: prompt.proofPayload != nil
        )
    }

    private static func operationModel(
        id: String,
        manifest: TonConnectManifestInfo,
        request: TonConnectIncomingRequest,
        sendPreview: SendPreview?,
        signPreview: SignMessagePreview?
    ) -> WalletContext.TonConnectOperationRequest {
        let method: WalletContext.TonConnectOperationRequest.Method = sendPreview == nil ? .signMessage : .sendTransaction
        let engineMessages = sendPreview?.messages ?? signPreview?.messages ?? []
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
        if let preview = sendPreview,
           (!preview.emulation.traceSucceeded || preview.emulation.isIncomplete) {
            warnings.append("Some emulated actions may fail or the trace is incomplete.")
        }
        if signPreview != nil {
            warnings.append("The wallet will not broadcast this message. The dApp may relay it until expiration.")
        }
        return WalletContext.TonConnectOperationRequest(
            id: id,
            applicationName: manifest.name,
            domain: manifest.domain,
            iconUrl: manifest.iconUrl,
            method: method,
            messages: messages,
            feeNanograms: sendPreview?.emulation.walletFeesNanograms,
            validUntil: sendPreview?.validUntil ?? signPreview?.validUntil,
            relayerWillSubmit: signPreview != nil,
            needsWalletStateInit: signPreview?.needsStateInit ?? false,
            warnings: warnings,
            actions: sendPreview?.emulation.actions.map {
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

    @MainActor
    private static var device: TonConnectDevice {
        let platform: TonConnectDevicePlatform
#if os(iOS)
        platform = UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone
#else
        platform = .mac
#endif
        return TonConnectDevice(
            platform: platform,
            appName: "Telegram",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        )
    }

}

private struct WalletTonConnectExecutor: TonConnectWalletExecutor {
    let runtime: WalletEngineRuntime

    func account(for wallet: TonConnectWalletIdentity) async throws -> TonConnectAccountInfo {
        try await self.runtime.tonConnectAccount(wallet: wallet)
    }

    func signProof(wallet: TonConnectWalletIdentity, domain: String, timestamp: UInt64, payload: String) async throws -> TonConnectProofSignature {
        try await self.runtime.signTonConnectProof(wallet: wallet, domain: domain, timestamp: timestamp, payload: payload)
    }

    func preview(wallet: TonConnectWalletIdentity, request: TonConnectIncomingRequest) async throws -> TonConnectPreview {
        switch request {
        case let .sendTransaction(_, _, value): return .send(try await self.runtime.previewTonConnect(value, wallet: wallet))
        case let .signMessage(_, _, value): return .sign(try await self.runtime.previewSignMessage(value, wallet: wallet))
        default: throw TonConnectFailure.unavailable
        }
    }

    func execute(wallet: TonConnectWalletIdentity, request: TonConnectIncomingRequest) async throws -> TonConnectSignedResult {
        do {
            switch request {
            case let .sendTransaction(_, _, value):
                let result = try await self.runtime.sendTonConnect(value, wallet: wallet)
                guard walletEngineAcceptsSubmission(result.phase) else { throw TonConnectFailure.outcomeUnknown }
                return .send(result.signedBoc)
            case let .signMessage(_, _, value):
                let result = try await self.runtime.signMessage(value, wallet: wallet)
                guard walletEngineAcceptsSignHandoff(result.phase) else { throw TonConnectFailure.outcomeUnknown }
                return .sign(result.internalBoc)
            default: throw TonConnectFailure.unavailable
            }
        } catch {
            if walletEngineIsSendAlreadyInProgress(error) { throw TonConnectFailure.walletBusy }
            throw error
        }
    }
}
