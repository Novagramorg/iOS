import Foundation
import SwiftSignalKit
import TelegramCore
import TONWalletKit

final class WalletToncenterProxy: @unchecked Sendable {
    private let ton: TelegramEngine.Ton
    private let lock = NSLock()
    private var requests: [UUID: WalletToncenterSignalAwaiter<String>] = [:]
    private var isEnabled = false

    init(engine: TelegramEngine) {
        self.ton = engine.ton
    }

    deinit {
        self.cancelAll()
    }

    func perform(_ request: TONToncenterRequest) async throws -> String {
        let signal: Signal<String, TonApiRequestError>
        switch request.method {
        case .get:
            signal = self.ton.performGetRequest(
                endpoint: request.endpoint,
                query: request.query
            )
        case .post:
            signal = self.ton.performPostRequest(
                endpoint: request.endpoint,
                payload: request.payload
            )
        }

        let requestId = UUID()
        let awaiter = WalletToncenterSignalAwaiter<String>()
        guard self.register(awaiter, requestId: requestId) else {
            throw WalletToncenterProxyError(message: "Toncenter proxy is unavailable")
        }
        defer {
            self.remove(requestId: requestId)
        }
        return try await walletToncenterFirstValue(signal, awaiter: awaiter)
    }

    func cancelAll() {
        self.lock.lock()
        let requests = Array(self.requests.values)
        self.requests.removeAll()
        self.lock.unlock()

        for request in requests {
            request.finish(.failure(CancellationError()))
        }
    }

    func setEnabled(_ isEnabled: Bool) {
        self.lock.lock()
        self.isEnabled = isEnabled
        let requests: [WalletToncenterSignalAwaiter<String>]
        if isEnabled {
            requests = []
        } else {
            requests = Array(self.requests.values)
            self.requests.removeAll()
        }
        self.lock.unlock()

        for request in requests {
            request.finish(.failure(CancellationError()))
        }
    }

    private func register(_ request: WalletToncenterSignalAwaiter<String>, requestId: UUID) -> Bool {
        self.lock.lock()
        guard self.isEnabled else {
            self.lock.unlock()
            return false
        }
        let previousRequest = self.requests.updateValue(request, forKey: requestId)
        self.lock.unlock()
        previousRequest?.finish(.failure(CancellationError()))
        return true
    }

    private func remove(requestId: UUID) {
        self.lock.lock()
        self.requests.removeValue(forKey: requestId)
        self.lock.unlock()
    }
}

private struct WalletToncenterProxyError: LocalizedError {
    let message: String

    var errorDescription: String? {
        return self.message
    }
}

private final class WalletToncenterSignalAwaiter<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private let disposable = MetaDisposable()
    private var continuation: CheckedContinuation<Value, Error>?
    private var result: Result<Value, Error>?

    var isFinished: Bool {
        self.lock.lock()
        let isFinished = self.result != nil
        self.lock.unlock()
        return isFinished
    }

    func setContinuation(_ continuation: CheckedContinuation<Value, Error>) {
        self.lock.lock()
        if let result = self.result {
            self.lock.unlock()
            continuation.resume(with: result)
        } else {
            self.continuation = continuation
            self.lock.unlock()
        }
    }

    func setDisposable(_ disposable: Disposable) {
        self.disposable.set(disposable)
    }

    func finish(_ result: Result<Value, Error>) {
        self.lock.lock()
        guard self.result == nil else {
            self.lock.unlock()
            return
        }
        self.result = result
        let continuation = self.continuation
        self.continuation = nil
        self.lock.unlock()

        self.disposable.dispose()
        continuation?.resume(with: result)
    }
}

private func walletToncenterFirstValue(
    _ signal: Signal<String, TonApiRequestError>,
    awaiter: WalletToncenterSignalAwaiter<String>
) async throws -> String {
    return try await withTaskCancellationHandler(operation: {
        try await withCheckedThrowingContinuation { continuation in
            awaiter.setContinuation(continuation)
            if Task.isCancelled || awaiter.isFinished {
                awaiter.finish(.failure(CancellationError()))
                return
            }
            awaiter.setDisposable(signal.start(
                next: { value in
                    awaiter.finish(.success(value))
                },
                error: { error in
                    awaiter.finish(.failure(WalletToncenterProxyError(message: error.description)))
                },
                completed: {
                    awaiter.finish(.failure(WalletToncenterProxyError(message: "Toncenter proxy returned no response")))
                }
            ))
        }
    }, onCancel: {
        awaiter.finish(.failure(CancellationError()))
    })
}
