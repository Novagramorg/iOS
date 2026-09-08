import Foundation

struct WalletRequestCoalescingKey: Hashable, Sendable {
    struct Header: Hashable, Sendable {
        let name: String
        let value: String
    }

    let url: String
    let headers: [Header]
    let body: Data
    let timeoutMs: UInt64

    init?(isGet: Bool, url: String, headers: [Header], body: Data, timeoutMs: UInt64) {
        guard isGet,
              let components = URLComponents(string: url),
              components.scheme?.lowercased() == "https",
              components.host != nil,
              components.user == nil,
              components.password == nil,
              components.fragment == nil,
              components.path == "/api/v2/getAddressInformation" else {
            return nil
        }
        self.url = url
        self.headers = headers
        self.body = body
        self.timeoutMs = timeoutMs
    }
}

// Shares only running requests. Every consumer owns its own cancellable wait.
final class WalletRequestCoalescer: @unchecked Sendable {
    final class Request: @unchecked Sendable {
        private let lock = NSLock()
        private let onCancel: @Sendable () -> Void
        private var result: Result<Data, Error>?
        private var continuation: CheckedContinuation<Data, Error>?

        fileprivate init(onCancel: @escaping @Sendable () -> Void) {
            self.onCancel = onCancel
        }

        // A Request represents one consumer and must be awaited only once.
        var value: Data {
            get async throws {
                return try await withTaskCancellationHandler(operation: {
                    try await withCheckedThrowingContinuation { continuation in
                        self.lock.lock()
                        let result = self.result
                        if result == nil {
                            precondition(self.continuation == nil)
                            self.continuation = continuation
                        }
                        self.lock.unlock()
                        if let result {
                            continuation.resume(with: result)
                        }
                    }
                }, onCancel: {
                    self.cancel()
                })
            }
        }

        func cancel() {
            self.onCancel()
        }

        fileprivate func complete(_ result: Result<Data, Error>) {
            self.lock.lock()
            guard self.result == nil else {
                self.lock.unlock()
                return
            }
            self.result = result
            let continuation = self.continuation
            self.continuation = nil
            self.lock.unlock()
            continuation?.resume(with: result)
        }
    }

    private final class Operation {
        let id = UUID()
        var task: Task<Void, Never>?
        var requests: [UUID: Request] = [:]
    }

    private let lock = NSLock()
    private var operations: [WalletRequestCoalescingKey: Operation] = [:]

    func execute(
        key: WalletRequestCoalescingKey,
        operation: @escaping @Sendable () async throws -> Data
    ) async throws -> Data {
        try Task.checkCancellation()
        let request = self.start(key: key, operation: operation)
        return try await request.value
    }

    func start(
        key: WalletRequestCoalescingKey,
        operation: @escaping @Sendable () async throws -> Data
    ) -> Request {
        self.lock.lock()
        let existing = self.operations[key]
        let shared = existing ?? Operation()
        let operationId = shared.id
        let requestId = UUID()
        let request = Request(onCancel: { [weak self] in
            self?.cancel(key: key, operationId: operationId, requestId: requestId)
        })
        shared.requests[requestId] = request
        if existing == nil {
            self.operations[key] = shared
            shared.task = Task {
                let result: Result<Data, Error>
                do {
                    try Task.checkCancellation()
                    result = .success(try await operation())
                } catch {
                    result = .failure(error)
                }
                self.complete(key: key, operationId: operationId, result: result)
            }
        }
        self.lock.unlock()
        return request
    }

    private func cancel(key: WalletRequestCoalescingKey, operationId: UUID, requestId: UUID) {
        self.lock.lock()
        guard let shared = self.operations[key], shared.id == operationId,
              let request = shared.requests.removeValue(forKey: requestId) else {
            self.lock.unlock()
            return
        }
        let task: Task<Void, Never>?
        if shared.requests.isEmpty {
            self.operations.removeValue(forKey: key)
            task = shared.task
        } else {
            task = nil
        }
        self.lock.unlock()
        task?.cancel()
        request.complete(.failure(CancellationError()))
    }

    private func complete(key: WalletRequestCoalescingKey, operationId: UUID, result: Result<Data, Error>) {
        self.lock.lock()
        guard let shared = self.operations[key], shared.id == operationId else {
            self.lock.unlock()
            return
        }
        self.operations.removeValue(forKey: key)
        let requests = Array(shared.requests.values)
        self.lock.unlock()
        for request in requests {
            request.complete(result)
        }
    }
}
