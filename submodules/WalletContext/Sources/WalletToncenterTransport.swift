import Foundation
import SwiftSignalKit
import TelegramCore
import TONToncenter

private enum WalletToncenterTransportError: Error {
    case invalidPayload
    case invalidStreamingUrl
    case completedWithoutResponse
}

final class WalletToncenterRequestContext<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?
    private var disposable: Disposable?
    private var isFinished = false

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
        if self.isFinished {
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
            self?.finish(.failure(WalletToncenterTransportError.completedWithoutResponse))
        })

        self.lock.lock()
        let disposeImmediately = self.isFinished
        if !disposeImmediately {
            self.disposable = disposable
        }
        self.lock.unlock()

        if disposeImmediately {
            disposable.dispose()
        }
    }

    private func finish(_ result: Result<Value, Error>) {
        let continuation: CheckedContinuation<Value, Error>?
        let disposable: Disposable?

        self.lock.lock()
        if self.isFinished {
            self.lock.unlock()
            return
        }
        self.isFinished = true
        continuation = self.continuation
        self.continuation = nil
        disposable = self.disposable
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

actor WalletToncenterStreamingURLProvider {
    private struct CachedValue {
        let url: URL
        let expires: Int32
    }

    private let engine: TelegramEngine
    private let refreshBeforeExpiration: Int64 = 30
    private var cachedValue: CachedValue?

    init(engine: TelegramEngine) {
        self.engine = engine
    }

    func url() async throws -> URL {
        let currentTimestamp = Int64(Date().timeIntervalSince1970)
        if let cachedValue = self.cachedValue,
           Int64(cachedValue.expires) > currentTimestamp + self.refreshBeforeExpiration {
            return cachedValue.url
        }

        do {
            let result = try await WalletToncenterRequestContext<WalletStreamingUrl>().run(
                self.engine.wallet.getStreamingUrl()
            )
            guard let url = URL(string: result.url),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "ws" || scheme == "wss",
                  url.host != nil,
                  Int64(result.expires) > Int64(Date().timeIntervalSince1970) else {
                throw WalletToncenterTransportError.invalidStreamingUrl
            }
            self.cachedValue = CachedValue(url: url, expires: result.expires)
            return url
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            let fallbackTimestamp = Int64(Date().timeIntervalSince1970)
            if let cachedValue = self.cachedValue,
               Int64(cachedValue.expires) > fallbackTimestamp {
                return cachedValue.url
            }
            throw error
        }
    }
}

final class WalletToncenterTransport: Transport, @unchecked Sendable {
    private let engine: TelegramEngine

    init(engine: TelegramEngine) {
        self.engine = engine
    }

    func send(_ request: TransportRequest) async throws -> TransportResponse {
        let signal: Signal<String, TonApiRequestError>
        switch request.method {
        case .get:
            signal = self.engine.wallet.performGetRequest(
                endpoint: request.path,
                query: Self.encodedQuery(request.query)
            )
        case .post:
            let payload: String?
            if let body = request.body {
                guard let value = String(data: body, encoding: .utf8) else {
                    throw WalletToncenterTransportError.invalidPayload
                }
                payload = value
            } else {
                payload = nil
            }
            signal = self.engine.wallet.performPostRequest(
                endpoint: request.path,
                payload: payload
            )
        }

        let response = try await WalletToncenterRequestContext<String>().run(signal)
        return TransportResponse(status: 200, body: Data(response.utf8))
    }

    private static func encodedQuery(_ query: [String: [String]]) -> String? {
        let value = query
            .sorted { $0.key < $1.key }
            .flatMap { key, values in values.map { (key, $0) } }
            .map { "\(Self.encodeQueryComponent($0.0))=\(Self.encodeQueryComponent($0.1))" }
            .joined(separator: "&")
        return value.isEmpty ? nil : value
    }

    private static func encodeQueryComponent(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
