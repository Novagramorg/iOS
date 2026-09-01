import Foundation
import SwiftSignalKit
import TelegramCore
import WalletEngineFFI

private enum WalletEngineRelayError: Error {
    case completedWithoutResponse
    case invalidRequest
    case responseTooLarge
}

let walletEngineMaximumStatuslessResponseBytes = 4 * 1024 * 1024

func walletEngineTransportKind(_ code: URLError.Code) -> StatuslessHostErrorKind {
    switch code {
    case .notConnectedToInternet, .internationalRoamingOff, .dataNotAllowed, .callIsActive:
        return .offline
    case .timedOut:
        return .timeout
    case .networkConnectionLost, .cannotConnectToHost:
        return .connectionLost
    case .cancelled:
        return .cancelled
    default:
        return .other
    }
}

final class WalletSignalRequestContext<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?
    private var disposable: Disposable?
    private var finished = false

    func run<SignalError: Error>(_ signal: Signal<Value, SignalError>) async throws -> Value {
        try Task.checkCancellation()
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                self.start(signal, continuation: continuation)
            }
        }, onCancel: {
            self.finish(.failure(CancellationError()))
        })
    }

    private func start<SignalError: Error>(
        _ signal: Signal<Value, SignalError>,
        continuation: CheckedContinuation<Value, Error>
    ) {
        self.lock.lock()
        if self.finished {
            self.lock.unlock()
            continuation.resume(throwing: CancellationError())
            return
        }
        self.continuation = continuation
        self.lock.unlock()

        let disposable = signal.start(next: { [weak self] value in
            self?.finish(.success(value))
        }, error: { [weak self] error in
            self?.finish(.failure(error))
        }, completed: { [weak self] in
            self?.finish(.failure(WalletEngineRelayError.completedWithoutResponse))
        })

        self.lock.lock()
        let disposeImmediately = self.finished
        if !disposeImmediately {
            self.disposable = disposable
        }
        self.lock.unlock()
        if disposeImmediately {
            disposable.dispose()
        }
    }

    private func finish(_ result: Result<Value, Error>) {
        self.lock.lock()
        guard !self.finished else {
            self.lock.unlock()
            return
        }
        self.finished = true
        let continuation = self.continuation
        let disposable = self.disposable
        self.continuation = nil
        self.disposable = nil
        self.lock.unlock()

        disposable?.dispose()
        switch result {
        case let .success(value):
            continuation?.resume(returning: value)
        case let .failure(error):
            continuation?.resume(throwing: error)
        }
    }
}

/// Executes the logical Toncenter request through Telegram's authenticated relay.
actor WalletEngineStatuslessHost: WalletStatuslessHost {
    private static let maximumEarlyCancellations = 256

    private let engine: TelegramEngine
    private var tasks: [UInt64: Task<Data, Error>] = [:]
    private var cancelledBeforeStart = Set<UInt64>()

    init(engine: TelegramEngine) {
        self.engine = engine
    }

    func executeStatusless(request: HttpRequest) async throws -> Data {
        let id = request.id.value
        guard self.tasks[id] == nil else {
            throw Self.failure(.policyViolation, "Duplicate provider request identifier")
        }
        guard self.cancelledBeforeStart.remove(id) == nil else {
            throw Self.failure(.cancelled, "Provider request was cancelled")
        }

        let engine = self.engine
        let task = Task<Data, Error> {
            try await Self.perform(request, engine: engine)
        }
        self.tasks[id] = task
        defer { self.tasks[id] = nil }

        do {
            return try await task.value
        } catch is CancellationError {
            throw Self.failure(.cancelled, "Provider request was cancelled")
        } catch let error as StatuslessHostError {
            throw error
        } catch let error as TonApiRequestError {
            throw Self.failure(.other, "Telegram relay failed (\(error.code))")
        } catch let error as URLError {
            throw Self.failure(walletEngineTransportKind(error.code), error.localizedDescription)
        } catch WalletEngineRelayError.responseTooLarge {
            throw Self.failure(.responseTooLarge, "Provider response exceeds 4 MiB")
        } catch WalletEngineRelayError.invalidRequest {
            throw Self.failure(.policyViolation, "Provider request body is not valid UTF-8")
        } catch WalletEngineRelayError.completedWithoutResponse {
            throw Self.failure(.other, "Telegram relay completed without a response")
        } catch {
            throw Self.failure(.other, String(describing: error))
        }
    }

    func cancelStatusless(requestId: HttpRequestId) async {
        if let task = self.tasks[requestId.value] {
            task.cancel()
        } else {
            self.cancelledBeforeStart.insert(requestId.value)
            while self.cancelledBeforeStart.count > Self.maximumEarlyCancellations,
                  let oldest = self.cancelledBeforeStart.min() {
                self.cancelledBeforeStart.remove(oldest)
            }
        }
    }

    private nonisolated static func perform(
        _ request: HttpRequest,
        engine: TelegramEngine
    ) async throws -> Data {
        guard let components = URLComponents(string: request.url),
              components.scheme?.lowercased() == "https",
              components.host != nil,
              components.user == nil,
              components.password == nil,
              components.fragment == nil else {
            throw failure(.policyViolation, "Provider URL is invalid")
        }

        let endpoint = components.path.isEmpty ? "/" : components.path
        let response: String = try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                switch request.method {
                case .get:
                    return try await WalletSignalRequestContext<String>().run(
                        engine.wallet.performGetRequest(endpoint: endpoint, query: components.percentEncodedQuery)
                    )
                case .post:
                    guard request.body.count <= walletEngineMaximumStatuslessResponseBytes else {
                        throw WalletEngineRelayError.responseTooLarge
                    }
                    let payload: String?
                    if request.body.isEmpty {
                        payload = nil
                    } else if let value = String(data: request.body, encoding: .utf8) {
                        payload = value
                    } else {
                        throw WalletEngineRelayError.invalidRequest
                    }
                    return try await WalletSignalRequestContext<String>().run(
                        engine.wallet.performPostRequest(endpoint: endpoint, payload: payload)
                    )
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: request.timeoutMs * 1_000_000)
                throw failure(.timeout, "Provider request timed out")
            }
            defer { group.cancelAll() }
            guard let value = try await group.next() else {
                throw failure(.other, "Provider request produced no response")
            }
            return value
        }

        let data = Data(response.utf8)
        guard data.count <= walletEngineMaximumStatuslessResponseBytes else {
            throw WalletEngineRelayError.responseTooLarge
        }
        return data
    }

    private nonisolated static func failure(
        _ kind: StatuslessHostErrorKind,
        _ diagnostic: String
    ) -> StatuslessHostError {
        .Failed(kind: kind, diagnostic: sanitizedWalletEngineDiagnostic(diagnostic))
    }
}
