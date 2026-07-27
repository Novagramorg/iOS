//
//  TONToncenterRequestHandlerJSAdapter.swift
//  TONWalletKit
//

import Foundation
import JavaScriptCore

@objc protocol JSToncenterRequestHandler: JSExport {
    @objc(getNetwork)
    func getNetwork() -> JSValue

    @objc(performRequest:::::)
    func performRequest(
        method: String,
        endpoint: String,
        query: String,
        payload: String,
        requestId: String
    ) -> JSValue

    @objc(cancelRequest:)
    func cancelRequest(requestId: String)
}

final class TONToncenterRequestHandlerJSAdapter: NSObject, JSToncenterRequestHandler {
    private weak var context: JSContext?
    private let network: TONNetwork
    private let requestHandler: TONWalletKitConfiguration.APIClientConfiguration.RequestHandler
    private let lock = NSLock()
    private var requests: [String: TONToncenterRequestCancellation] = [:]

    init(
        context: JSContext,
        network: TONNetwork,
        requestHandler: @escaping TONWalletKitConfiguration.APIClientConfiguration.RequestHandler
    ) {
        self.context = context
        self.network = network
        self.requestHandler = requestHandler
    }

    deinit {
        self.lock.lock()
        let requests = Array(self.requests.values)
        self.requests.removeAll()
        self.lock.unlock()

        for request in requests {
            request.cancel()
        }
    }

    @objc(getNetwork) func getNetwork() -> JSValue {
        guard let context else {
            return JSValue(undefinedIn: JSContext())
        }
        do {
            return JSValue(object: try self.network.encode(in: context), in: context)
        } catch {
            return JSValue(undefinedIn: context)
        }
    }

    @objc(performRequest:::::) func performRequest(
        method: String,
        endpoint: String,
        query: String,
        payload: String,
        requestId: String
    ) -> JSValue {
        guard let context else {
            return JSValue(
                newPromiseRejectedWithReason: "WalletKit context deallocated",
                in: JSContext()
            )
        }
        guard let method = TONToncenterRequest.Method(rawValue: method.lowercased()) else {
            return JSValue(
                newPromiseRejectedWithReason: "Unsupported Toncenter request method",
                in: context
            )
        }

        let request = TONToncenterRequest(
            method: method,
            endpoint: endpoint,
            query: query.isEmpty ? nil : query,
            payload: payload.isEmpty ? nil : payload
        )

        return JSValue(newPromiseIn: context) { [weak self] resolve, reject in
            guard let self else {
                reject?.call(withArguments: ["Toncenter request handler deallocated"])
                return
            }

            let cancellation = TONToncenterRequestCancellation()
            self.registerRequest(cancellation, requestId: requestId)
            let requestHandler = self.requestHandler
            let task = Task { [weak self] in
                defer {
                    self?.removeTask(requestId: requestId)
                }

                do {
                    let result = try await requestHandler(request)
                    try Task.checkCancellation()
                    resolve?.call(withArguments: [result])
                } catch {
                    reject?.call(withArguments: [error.localizedDescription])
                }
            }
            cancellation.setTask(task)
        }
    }

    @objc(cancelRequest:) func cancelRequest(requestId: String) {
        self.lock.lock()
        let request = self.requests.removeValue(forKey: requestId)
        self.lock.unlock()
        request?.cancel()
    }

    private func registerRequest(_ request: TONToncenterRequestCancellation, requestId: String) {
        self.lock.lock()
        let previousRequest = self.requests.updateValue(request, forKey: requestId)
        self.lock.unlock()
        previousRequest?.cancel()
    }

    private func removeTask(requestId: String) {
        self.lock.lock()
        self.requests.removeValue(forKey: requestId)
        self.lock.unlock()
    }
}

private final class TONToncenterRequestCancellation {
    private let lock = NSLock()
    private var task: Task<Void, Never>?
    private var isCancelled = false

    func setTask(_ task: Task<Void, Never>) {
        self.lock.lock()
        if self.isCancelled {
            self.lock.unlock()
            task.cancel()
        } else {
            self.task = task
            self.lock.unlock()
        }
    }

    func cancel() {
        self.lock.lock()
        self.isCancelled = true
        let task = self.task
        self.task = nil
        self.lock.unlock()
        task?.cancel()
    }
}

extension TONToncenterRequestHandlerJSAdapter: JSValueEncodable {}
