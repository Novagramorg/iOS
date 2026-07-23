//
//  WebSocketTask.swift
//  TONWalletKit
//
//  Copyright (c) 2025 TON Connect
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import Foundation

enum JSWebSocketEvent: Sendable {
    case open(negotiatedProtocol: String?)
    case message(JSWebSocketMessage)
    case close(code: Int, reason: String, wasClean: Bool)
    case error(String)
}

enum JSWebSocketMessage: Sendable {
    case text(String)
    case binary(Data)
}

protocol JSWebSocketTaskProtocol: Actor {
    func start() -> AsyncStream<JSWebSocketEvent>
    func send(_ message: URLSessionWebSocketTask.Message) async throws
    func close(code: URLSessionWebSocketTask.CloseCode, reason: Data?)
    func cancel()
}

actor JSWebSocketTask: JSWebSocketTaskProtocol {
    enum State {
        case connecting
        case open
        case closing
        case closed
    }

    private var state: State = .connecting
    private var urlSession: URLSession?
    private var webSocketTask: URLSessionWebSocketTask?
    private let url: URL
    private let protocols: [String]
    private var continuation: AsyncStream<JSWebSocketEvent>.Continuation?
    private var delegate: SessionDelegate?

    init(url: URL, protocols: [String]) {
        self.url = url
        self.protocols = protocols
    }

    func start() -> AsyncStream<JSWebSocketEvent> {
        let delegate = SessionDelegate()
        self.delegate = delegate

        let session = URLSession(
            configuration: .default,
            delegate: delegate,
            delegateQueue: nil
        )
        self.urlSession = session

        let task: URLSessionWebSocketTask

        if protocols.isEmpty {
            task = session.webSocketTask(with: url)
        } else {
            task = session.webSocketTask(with: url, protocols: protocols)
        }

        self.webSocketTask = task

        delegate.onOpen = { [weak self] negotiatedProtocol in
            Task { [weak self] in
                await self?.handleOpen(negotiatedProtocol: negotiatedProtocol)
            }
        }

        delegate.onClose = { [weak self] closeCode, reason in
            Task { [weak self] in
                await self?.handleClose(closeCode: closeCode, reason: reason)
            }
        }

        delegate.onComplete = { [weak self] error in
            Task { [weak self] in
                await self?.handleComplete(error: error)
            }
        }

        let stream = AsyncStream<JSWebSocketEvent> { continuation in
            self.continuation = continuation
        }

        task.resume()

        return stream
    }

    func send(_ message: URLSessionWebSocketTask.Message) async throws {
        guard let webSocketTask else { return }

        try await webSocketTask.send(message)
    }

    func close(code: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        guard state == .connecting || state == .open else { return }

        state = .closing
        webSocketTask?.cancel(with: code, reason: reason)
    }

    func cancel() {
        state = .closed
        webSocketTask?.cancel()
        urlSession?.invalidateAndCancel()
        continuation?.finish()
    }

    private func handleOpen(negotiatedProtocol: String?) async {
        guard state == .connecting else { return }

        state = .open
        continuation?.yield(.open(negotiatedProtocol: negotiatedProtocol))

        await receiveLoop()
    }

    private func handleClose(closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let code = closeCode.rawValue
        let reasonString = reason.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let wasClean = state == .closing || state == .open

        state = .closed
        continuation?.yield(.close(code: code, reason: reasonString, wasClean: wasClean))
        continuation?.finish()
    }

    private func handleComplete(error: Error?) {
        guard state != .closed else { return }

        if let error {
            continuation?.yield(.error(error.localizedDescription))
        }

        let wasClean = state == .closing

        state = .closed
        continuation?.yield(.close(code: 1006, reason: "", wasClean: wasClean))
        continuation?.finish()
    }

    private func receiveLoop() async {
        guard let webSocketTask else { return }

        while state == .open {
            do {
                let message = try await webSocketTask.receive()
                switch message {
                case .string(let text):
                    continuation?.yield(.message(.text(text)))
                case .data(let data):
                    continuation?.yield(.message(.binary(data)))
                @unknown default:
                    break
                }
            } catch {
                break
            }
        }
    }
}

private final class SessionDelegate: NSObject, URLSessionWebSocketDelegate {
    var onOpen: ((String?) -> Void)?
    var onClose: ((URLSessionWebSocketTask.CloseCode, Data?) -> Void)?
    var onComplete: ((Error?) -> Void)?

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        onOpen?(`protocol`)
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        onClose?(closeCode, reason)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        onComplete?(error)
    }
}
