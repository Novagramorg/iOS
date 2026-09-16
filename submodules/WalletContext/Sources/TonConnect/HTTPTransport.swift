import Foundation
import WalletEngineFFI

@available(macOS 10.15, *)
private final class TransferCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var task: URLSessionTask?
    private var session: URLSession?
    private var cancelled = false

    func install(task: URLSessionTask, session: URLSession) {
        self.lock.lock()
        if self.cancelled {
            self.lock.unlock()
            task.cancel()
            session.invalidateAndCancel()
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

/// URLSession invokes this delegate on its serial delegate queue.
@available(macOS 10.15, *)
private final class ReceiveDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let url: URL
    private let maximumBytes: Int
    private let events: Bool
    private let continuation: AsyncThrowingStream<Data, Error>.Continuation
    private var bytes = 0
    private var previousLineFeed = false
    private var finished = false

    init(url: URL, maximumBytes: Int, events: Bool, continuation: AsyncThrowingStream<Data, Error>.Continuation) {
        self.url = url
        self.maximumBytes = maximumBytes
        self.events = events
        self.continuation = continuation
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let response = response as? HTTPURLResponse, response.url == self.url,
              (200..<300).contains(response.statusCode),
              !self.events || response.mimeType?.lowercased() == "text/event-stream" else {
            self.finish(TonConnectFailure.invalidResponse)
            completionHandler(.cancel)
            return
        }
        if !self.events, response.expectedContentLength > Int64(self.maximumBytes) {
            self.finish(TonConnectFailure.responseTooLarge)
            completionHandler(.cancel)
            return
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard !self.finished else { return }
        for byte in data {
            self.bytes += 1
            if self.events {
                if byte == 0x0a {
                    if self.previousLineFeed { self.bytes = 0 }
                    self.previousLineFeed = true
                } else if byte != 0x0d {
                    self.previousLineFeed = false
                }
            }
            if self.bytes > self.maximumBytes {
                self.finish(TonConnectFailure.responseTooLarge)
                dataTask.cancel()
                return
            }
        }
        // On overflow, reconnect from the persisted SSE cursor.
        var offset = 0
        while offset < data.count {
            let end = min(data.count, offset + 64 * 1024)
            switch self.continuation.yield(data.subdata(in: offset..<end)) {
            case .enqueued: break
            case .dropped:
                self.finish(TonConnectFailure.responseTooLarge)
                dataTask.cancel()
                return
            case .terminated:
                dataTask.cancel()
                return
            @unknown default:
                self.finish(TonConnectFailure.invalidResponse)
                dataTask.cancel()
                return
            }
            offset = end
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        self.finish(error)
    }

    private func finish(_ error: Error?) {
        guard !self.finished else { return }
        self.finished = true
        self.continuation.finish(throwing: error)
    }
}

@available(macOS 10.15, *)
public struct TonConnectHTTPTransport: TonConnectTransport {
    public init() {}

    public func loadManifest(from url: String) async throws -> String {
        var data = Data()
        try await self.receive(request: self.request(url, method: "GET"), maximumBytes: 256 * 1024, events: false) {
            data.append($0)
        }
        guard let json = String(data: data, encoding: .utf8) else { throw TonConnectFailure.invalidManifest }
        return json
    }

    public func post(_ post: TonConnectPreparedPost) async throws {
        var request = try self.request(post.url, method: "POST")
        request.httpBody = Data(post.body.utf8)
        request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")
        try await self.receive(request: request, maximumBytes: 4 * 1024 * 1024, events: false) { _ in }
    }

    public func stream(from url: String, onChunk: @escaping @Sendable (Data) async throws -> Void) async throws {
        var request = try self.request(url, method: "GET")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 5 * 60
        try await self.receive(request: request, maximumBytes: 1_048_576, events: true, onChunk: onChunk)
    }

    private func request(_ value: String, method: String) throws -> URLRequest {
        guard let url = URL(string: value), url.scheme?.lowercased() == "https", url.host?.isEmpty == false,
              url.user == nil, url.password == nil, url.fragment == nil else { throw TonConnectFailure.invalidLink }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData
        return request
    }

    private func receive(request: URLRequest, maximumBytes: Int, events: Bool,
                         onChunk: (Data) async throws -> Void) async throws {
        guard let url = request.url else { throw TonConnectFailure.invalidLink }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.timeoutIntervalForRequest = events ? 5 * 60 : 30
        configuration.timeoutIntervalForResource = events ? 24 * 60 * 60 : 60
        let cancellation = TransferCancellation()
        let stream = AsyncThrowingStream<Data, Error>(bufferingPolicy: .bufferingOldest(32)) { continuation in
            let delegate = ReceiveDelegate(url: url, maximumBytes: maximumBytes, events: events, continuation: continuation)
            let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
            let task = session.dataTask(with: request)
            cancellation.install(task: task, session: session)
            continuation.onTermination = { @Sendable _ in cancellation.cancel() }
            task.resume()
        }
        defer { cancellation.cancel() }
        try await withTaskCancellationHandler(operation: {
            for try await data in stream {
                try Task.checkCancellation()
                try await onChunk(data)
            }
        }, onCancel: { cancellation.cancel() })
    }
}
