import Foundation
import WalletEngineFFI
#if os(iOS)
import UIKit
#endif

private struct StoredWalletTonConnectSession: Codable, Sendable {
    let rustSession: String
    let manifestURL: String
    let manifestName: String
    let manifestIconURL: String
    let manifestDomain: String
}

enum WalletTonConnectEvent: @unchecked Sendable {
    case connect(WalletContext.TonConnectRequest)
    case operation(WalletContext.TonConnectOperationRequest)
    case dismiss(String)
    case error(String)
}

private enum WalletTonConnectError: Error {
    case sessionUnavailable
    case requestUnavailable
    case invalidResponse
    case responseTooLarge
    case invalidURL
    case unsuccessfulSend
}

private final class WalletTonConnectDataTask: @unchecked Sendable {
    private let lock = NSLock()
    private var task: URLSessionTask?
    private var session: URLSession?
    private var cancelled = false

    func set(_ task: URLSessionTask, session: URLSession? = nil) {
        self.lock.lock()
        if self.cancelled {
            self.lock.unlock()
            task.cancel()
            session?.invalidateAndCancel()
        } else {
            self.task = task
            self.session = session
            self.lock.unlock()
        }
    }

    func cancel() {
        self.lock.lock()
        self.cancelled = true
        let task = self.task
        let session = self.session
        self.task = nil
        self.session = nil
        self.lock.unlock()
        task?.cancel()
        session?.invalidateAndCancel()
    }
}

private final class WalletTonConnectRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

private final class WalletTonConnectStreamDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let expectedURL: URL
    private let maximumEventBytes: Int
    private let continuation: AsyncThrowingStream<Data, Error>.Continuation
    private var eventBytes = 0
    private var previousWasLineFeed = false
    private var finished = false

    init(
        expectedURL: URL,
        maximumEventBytes: Int,
        continuation: AsyncThrowingStream<Data, Error>.Continuation
    ) {
        self.expectedURL = expectedURL
        self.maximumEventBytes = maximumEventBytes
        self.continuation = continuation
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let response = response as? HTTPURLResponse,
              response.url == self.expectedURL,
              (200 ..< 300).contains(response.statusCode) else {
            self.finish(throwing: WalletTonConnectError.invalidResponse)
            completionHandler(.cancel)
            return
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard !self.finished else { return }
        for byte in data {
            self.eventBytes += 1
            if byte == 0x0a {
                if self.previousWasLineFeed {
                    self.eventBytes = 0
                }
                self.previousWasLineFeed = true
            } else if byte != 0x0d {
                self.previousWasLineFeed = false
            }
            if self.eventBytes > self.maximumEventBytes {
                self.finish(throwing: WalletTonConnectError.responseTooLarge)
                dataTask.cancel()
                return
            }
        }
        self.continuation.yield(data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error, !self.finished {
            self.finish(throwing: error)
        } else {
            self.finish()
        }
    }

    private func finish(throwing error: Error? = nil) {
        guard !self.finished else { return }
        self.finished = true
        if let error {
            self.continuation.finish(throwing: error)
        } else {
            self.continuation.finish()
        }
    }
}

actor WalletTonConnectTransport {
    private static let maximumManifestBytes = 256 * 1024
    private static let maximumMessageBytes = 4 * 1024 * 1024
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 5 * 60
        self.session = URLSession(
            configuration: configuration,
            delegate: WalletTonConnectRedirectDelegate(),
            delegateQueue: nil
        )
    }

    func loadManifest(from value: String) async throws -> String {
        let data = try await self.perform(
            request: try self.request(url: value, method: "GET"),
            maximumBytes: Self.maximumManifestBytes
        )
        guard let value = String(data: data, encoding: .utf8) else {
            throw WalletTonConnectError.invalidResponse
        }
        return value
    }

    func post(_ value: TonConnectPreparedPost) async throws {
        var request = try self.request(url: value.url, method: "POST")
        request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(value.body.utf8)
        _ = try await self.perform(request: request, maximumBytes: Self.maximumMessageBytes)
    }

    func stream(
        from value: String,
        onChunk: @escaping @Sendable (Data) async throws -> Void
    ) async throws {
        var request = try self.request(url: value, method: "GET")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 5 * 60
        guard let url = request.url else { throw WalletTonConnectError.invalidURL }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.timeoutIntervalForRequest = 5 * 60
        configuration.timeoutIntervalForResource = 24 * 60 * 60

        let cancellation = WalletTonConnectDataTask()
        let stream = AsyncThrowingStream<Data, Error> { continuation in
            let delegate = WalletTonConnectStreamDelegate(
                expectedURL: url,
                maximumEventBytes: 1_048_576,
                continuation: continuation
            )
            let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
            let task = session.dataTask(with: request)
            cancellation.set(task, session: session)
            continuation.onTermination = { @Sendable _ in
                cancellation.cancel()
            }
            task.resume()
        }
        defer {
            cancellation.cancel()
        }
        for try await chunk in stream {
            try Task.checkCancellation()
            try await onChunk(chunk)
        }
    }

    private func request(url value: String, method: String) throws -> URLRequest {
        guard let url = URL(string: value),
              url.scheme?.lowercased() == "https",
              url.host?.isEmpty == false,
              url.user == nil,
              url.password == nil,
              url.fragment == nil else {
            throw WalletTonConnectError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.cachePolicy = .reloadIgnoringLocalCacheData
        return request
    }

    private func perform(request: URLRequest, maximumBytes: Int) async throws -> Data {
        let cancellation = WalletTonConnectDataTask()
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                let task = self.session.dataTask(with: request) { data, response, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let response = response as? HTTPURLResponse,
                          response.url == request.url,
                          (200 ..< 300).contains(response.statusCode),
                          let data else {
                        continuation.resume(throwing: WalletTonConnectError.invalidResponse)
                        return
                    }
                    guard data.count <= maximumBytes else {
                        continuation.resume(throwing: WalletTonConnectError.responseTooLarge)
                        return
                    }
                    continuation.resume(returning: data)
                }
                cancellation.set(task)
                task.resume()
            }
        }, onCancel: {
            cancellation.cancel()
        })
    }
}

/// Product-side owner of manifests, bridge delivery and approval presentation.
actor WalletTonConnectCoordinator {
    private let runtime: WalletEngineRuntime
    private let storage: WalletEngineStorage
    private let errorLogger: WalletContextErrorLogger
    private let recordId: String
    private let transport = WalletTonConnectTransport()
    private let event: @Sendable (WalletTonConnectEvent) -> Void
    private var hasSession = false
    private var manifest: TonConnectManifest?
    private var pending: [String: TonConnectIncomingRequest] = [:]
    private var pendingModels: [String: WalletContext.TonConnectOperationRequest] = [:]
    private var pendingOrder: [String] = []
    private var presentedRequestId: String?
    private var listenerTask: Task<Void, Never>?
    private var isShutdown = false

    init(
        runtime: WalletEngineRuntime,
        storage: WalletEngineStorage,
        errorLogger: WalletContextErrorLogger,
        recordId: String,
        event: @escaping @Sendable (WalletTonConnectEvent) -> Void
    ) {
        self.runtime = runtime
        self.storage = storage
        self.errorLogger = errorLogger
        self.recordId = recordId
        self.event = event
    }

    func restore() async {
        guard !self.isShutdown else { return }
        do {
            guard let data = try await self.storage.loadTonConnectSession(recordId: self.recordId) else {
                return
            }
            let stored = try JSONDecoder().decode(StoredWalletTonConnectSession.self, from: data)
            let manifest = TonConnectManifest(
                url: stored.manifestURL,
                name: stored.manifestName,
                iconUrl: stored.manifestIconURL,
                domain: stored.manifestDomain
            )
            _ = try await self.runtime.restoreTonConnectSession(persisted: stored.rustSession, config: Self.config)
            guard !self.isShutdown else {
                await self.runtime.clearTonConnectSession()
                return
            }
            self.hasSession = true
            self.manifest = manifest
            try await self.deliverPendingPostIfNeeded()
            guard !self.isShutdown else { return }
            switch try await self.runtime.tonConnectPhase() {
            case .pendingConnect:
                guard let prompt = try await self.runtime.tonConnectPrompt() else { return }
                self.event(.connect(Self.connectModel(manifest: manifest, prompt: prompt)))
            case .connected:
                for request in try await self.runtime.tonConnectPendingRequests(now: Self.now) {
                    await self.handle(request)
                }
                self.startListening()
            case .disconnected:
                if try await self.runtime.tonConnectPendingPost() == nil {
                    try await self.storage.removeTonConnectSession(recordId: self.recordId)
                    await self.clear()
                }
            }
        } catch {
            self.errorLogger.error("wallet_ton_connect_restore_failed", error)
            self.event(.error(sanitizedWalletEngineDiagnostic(String(describing: error))))
        }
    }

    func start(link: String) async throws {
        guard !self.isShutdown, !self.hasSession else {
            throw WalletTonConnectError.requestUnavailable
        }
        do {
            let prompt = try await self.runtime.startTonConnectSession(link: link, config: Self.config)
            self.hasSession = true
            let json = try await self.transport.loadManifest(from: prompt.manifestUrl)
            let manifest = try parseTonConnectManifest(json: json)
            guard !self.isShutdown else { throw CancellationError() }
            self.manifest = manifest
            try await self.persist()
            self.event(.connect(Self.connectModel(manifest: manifest, prompt: prompt)))
        } catch {
            self.hasSession = false
            await self.runtime.clearTonConnectSession()
            throw error
        }
    }

    func approveConnection(id: String) async throws {
        guard !self.isShutdown, self.hasSession,
              let manifest = self.manifest,
              Self.connectId(manifest) == id else {
            throw WalletTonConnectError.requestUnavailable
        }
        guard let prompt = try await self.runtime.tonConnectPrompt() else {
            throw WalletTonConnectError.requestUnavailable
        }
        let account = try await self.runtime.tonConnectAccount()
        let proof: TonConnectProofReply?
        if let payload = prompt.proofPayload {
            let timestamp = Self.now
            let signed = try await self.runtime.signTonConnectProof(
                domain: manifest.domain,
                timestamp: timestamp,
                payload: payload
            )
            proof = TonConnectProofReply(
                timestamp: timestamp,
                domain: manifest.domain,
                payload: payload,
                signature: signed.signature
            )
        } else {
            proof = nil
        }
        let device = await Self.device
        let post = try await self.runtime.tonConnectApprove(account: account, proof: proof, device: device)
        self.event(.dismiss(id))
        try await self.deliver(post)
        self.startListening()
    }

    func approveOperation(id: String) async throws {
        guard !self.isShutdown, self.hasSession, let request = self.pending[id] else {
            throw WalletTonConnectError.requestUnavailable
        }
        let post: TonConnectPreparedPost
        switch request {
        case let .sendTransaction(requestId, _, value):
            let result = try await self.runtime.sendTonConnect(value)
            guard walletEngineAcceptsSubmission(result.phase) else {
                throw WalletTonConnectError.unsuccessfulSend
            }
            post = try await self.runtime.tonConnectPrepareSendSuccess(requestId: requestId, signedBoc: result.signedBoc)
        case let .signMessage(requestId, _, value):
            let result = try await self.runtime.signMessage(value)
            guard walletEngineAcceptsSignHandoff(result.phase) else {
                throw WalletTonConnectError.unsuccessfulSend
            }
            post = try await self.runtime.tonConnectPrepareSignSuccess(requestId: requestId, internalBoc: result.internalBoc)
        case .disconnect, .unsupported:
            throw WalletTonConnectError.requestUnavailable
        }
        self.pending[id] = nil
        self.pendingModels[id] = nil
        self.pendingOrder.removeAll(where: { $0 == id })
        self.presentedRequestId = nil
        self.event(.dismiss(id))
        try await self.deliver(post)
        self.presentNextPendingRequest()
    }

    func reject(id: String) async {
        do {
            guard self.hasSession else { return }
            if let manifest = self.manifest,
               id == Self.connectId(manifest),
               try await self.runtime.tonConnectPhase() == .pendingConnect {
                let post = try await self.runtime.tonConnectReject(message: "User declined the connection")
                self.event(.dismiss(id))
                try await self.deliver(post, terminal: true)
                await self.clear()
                return
            }
            guard let request = self.pending.removeValue(forKey: id) else { return }
            self.pendingModels[id] = nil
            self.pendingOrder.removeAll(where: { $0 == id })
            if self.presentedRequestId == id {
                self.presentedRequestId = nil
            }
            let post = try await self.runtime.tonConnectPrepareError(
                requestId: request.requestId,
                code: .userDeclined,
                message: "User declined the TON Connect request"
            )
            self.event(.dismiss(id))
            try await self.deliver(post)
            self.presentNextPendingRequest()
        } catch {
            self.errorLogger.error("wallet_ton_connect_reject_failed", error)
            self.event(.error(sanitizedWalletEngineDiagnostic(String(describing: error))))
        }
    }

    func shutdown() async {
        self.isShutdown = true
        self.listenerTask?.cancel()
        self.listenerTask = nil
        self.hasSession = false
        await self.runtime.clearTonConnectSession()
    }

    private func startListening() {
        self.listenerTask?.cancel()
        self.listenerTask = Task { [weak self] in
            await self?.listen()
        }
    }

    private func listen() async {
        while !Task.isCancelled {
            guard !self.isShutdown else { return }
            do {
                try await self.deliverPendingPostIfNeeded()
                guard self.hasSession,
                      try await self.runtime.tonConnectPhase() == .connected else { return }
                let url = try await self.runtime.tonConnectBeginEventsSubscription()
                try await self.transport.stream(from: url) { [weak self] chunk in
                    guard let self else { return }
                    try await self.receive(chunk)
                }
            } catch let error as CancellationError {
                self.errorLogger.error("wallet_ton_connect_listener_cancelled", error)
                return
            } catch {
                self.errorLogger.error("wallet_ton_connect_listener_failed", error)
                do {
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                } catch {
                    self.errorLogger.error("wallet_ton_connect_listener_cancelled", error)
                    return
                }
            }
        }
    }

    private func receive(_ chunk: Data) async throws {
        let requests = try await self.runtime.tonConnectIngestSseChunk(chunk, now: Self.now)
        try await self.persist()
        for request in requests {
            await self.handle(request)
        }
    }

    private func handle(_ request: TonConnectIncomingRequest) async {
        guard let manifest = self.manifest else { return }
        switch request {
        case let .sendTransaction(_, _, send):
            do {
                let preview = try await self.runtime.previewTonConnect(send)
                let model = Self.operationModel(manifest: manifest, request: request, sendPreview: preview, signPreview: nil)
                self.enqueue(request: request, model: model)
            } catch {
                self.errorLogger.error("wallet_ton_connect_send_preview_failed", error)
                let diagnostic = sanitizedWalletEngineDiagnostic(String(describing: error))
                self.event(.error("TON Connect preview failed: \(diagnostic)"))
                await self.respondWithError(request: request, message: "Request preview failed: \(diagnostic)")
            }
        case let .signMessage(_, _, sign):
            do {
                let preview = try await self.runtime.previewSignMessage(sign)
                let model = Self.operationModel(manifest: manifest, request: request, sendPreview: nil, signPreview: preview)
                self.enqueue(request: request, model: model)
            } catch {
                self.errorLogger.error("wallet_ton_connect_sign_preview_failed", error)
                let diagnostic = sanitizedWalletEngineDiagnostic(String(describing: error))
                self.event(.error("TON Connect signing preview failed: \(diagnostic)"))
                await self.respondWithError(request: request, message: "Request preview failed: \(diagnostic)")
            }
        case let .disconnect(id, _):
            do {
                guard self.hasSession else { return }
                let post = try await self.runtime.tonConnectPrepareDisconnectSuccess(requestId: id)
                try await self.deliver(post, terminal: true)
                await self.clear()
            } catch {
                self.errorLogger.error("wallet_ton_connect_disconnect_failed", error)
                self.event(.error(sanitizedWalletEngineDiagnostic(String(describing: error))))
            }
        case let .unsupported(id, _, code, message):
            do {
                guard self.hasSession else { return }
                try await self.deliver(try await self.runtime.tonConnectPrepareError(requestId: id, code: code, message: message))
            } catch {
                self.errorLogger.error("wallet_ton_connect_unsupported_response_failed", error)
                self.event(.error(sanitizedWalletEngineDiagnostic(String(describing: error))))
            }
        }
    }

    private func respondWithError(request: TonConnectIncomingRequest, message: String) async {
        do {
            guard self.hasSession else { return }
            try await self.deliver(try await self.runtime.tonConnectPrepareError(
                requestId: request.requestId,
                code: .unknown,
                message: message
            ))
        } catch {
            self.errorLogger.error("wallet_ton_connect_error_response_failed", error)
            self.event(.error(sanitizedWalletEngineDiagnostic(String(describing: error))))
        }
    }

    private func enqueue(
        request: TonConnectIncomingRequest,
        model: WalletContext.TonConnectOperationRequest
    ) {
        let id = request.requestId
        self.pending[id] = request
        self.pendingModels[id] = model
        if !self.pendingOrder.contains(id) {
            self.pendingOrder.append(id)
        }
        self.presentNextPendingRequest()
    }

    private func presentNextPendingRequest() {
        guard self.presentedRequestId == nil else { return }
        while let id = self.pendingOrder.first {
            guard let model = self.pendingModels[id], self.pending[id] != nil else {
                self.pendingOrder.removeFirst()
                continue
            }
            self.presentedRequestId = id
            self.event(.operation(model))
            return
        }
    }

    private func deliverPendingPostIfNeeded() async throws {
        guard self.hasSession,
              let post = try await self.runtime.tonConnectPendingPost() else { return }
        try await self.deliver(post, terminal: try await self.runtime.tonConnectPhase() == .disconnected)
        self.presentNextPendingRequest()
    }

    private func deliver(_ post: TonConnectPreparedPost, terminal: Bool = false) async throws {
        guard self.hasSession else { throw WalletTonConnectError.sessionUnavailable }
        try await self.persist()
        do {
            try await self.transport.post(post)
        } catch {
            let isConnected: Bool
            do {
                isConnected = try await self.runtime.tonConnectPhase() == .connected
            } catch {
                self.errorLogger.error("wallet_ton_connect_phase_check_failed", error)
                isConnected = false
            }
            if isConnected {
                self.startListening()
            }
            throw error
        }
        try await self.runtime.tonConnectCompletePendingPost()
        try await self.persist()
        if terminal {
            try await self.storage.removeTonConnectSession(recordId: self.recordId)
        }
    }

    private func persist() async throws {
        guard self.hasSession, let manifest = self.manifest else { return }
        let value = StoredWalletTonConnectSession(
            rustSession: try await self.runtime.tonConnectPersisted(),
            manifestURL: manifest.url,
            manifestName: manifest.name,
            manifestIconURL: manifest.iconUrl,
            manifestDomain: manifest.domain
        )
        try await self.storage.saveTonConnectSession(try JSONEncoder().encode(value), recordId: self.recordId)
    }

    private func clear() async {
        self.listenerTask?.cancel()
        self.listenerTask = nil
        self.pending.removeAll()
        self.pendingModels.removeAll()
        self.pendingOrder.removeAll()
        self.presentedRequestId = nil
        self.hasSession = false
        self.manifest = nil
        await self.runtime.clearTonConnectSession()
    }

    private static func connectId(_ manifest: TonConnectManifest) -> String {
        "connect:\(manifest.url)"
    }

    private static func connectModel(
        manifest: TonConnectManifest,
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
            id: Self.connectId(manifest),
            applicationName: manifest.name,
            domain: manifest.domain,
            iconUrl: manifest.iconUrl,
            permissions: permissions,
            requestsProof: prompt.proofPayload != nil
        )
    }

    private static func operationModel(
        manifest: TonConnectManifest,
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
                id: "\(request.requestId):\(index)",
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
            id: request.requestId,
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
                    accounts: $0.accounts
                )
            } ?? []
        )
    }

    private static var config: TonConnectSessionConfig {
        TonConnectSessionConfig(
            bridgeUrl: "https://connect.ton.org/bridge",
            maxEventBytes: 1_048_576,
            messageTtlSeconds: 300
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

    private static var now: UInt64 {
        UInt64(max(0, Date().timeIntervalSince1970))
    }
}

private extension TonConnectIncomingRequest {
    var requestId: String {
        switch self {
        case let .sendTransaction(id, _, _),
             let .signMessage(id, _, _),
             let .disconnect(id, _),
             let .unsupported(id, _, _, _):
            return id
        }
    }
}
