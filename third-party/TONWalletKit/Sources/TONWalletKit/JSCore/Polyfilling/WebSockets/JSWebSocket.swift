//
//  JSWebSocket.swift
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

import JavaScriptCore

enum JSWebSocketReadyState: Int {
    case connecting = 0
    case open = 1
    case closing = 2
    case closed = 3
}

enum JSWebSocketBinaryType: String {
    case blob
    case arraybuffer
}

@objc private protocol JSWebSocketExport: JSExport {
    init?(url: String, protocols: JSValue)

    var binaryType: String { get set }
    var bufferedAmount: Int { get }
    var extensions: String { get }
    var `protocol`: String { get }
    var readyState: Int { get }
    var url: String { get }

    var onopen: JSValue? { get set }
    var onmessage: JSValue? { get set }
    var onclose: JSValue? { get set }
    var onerror: JSValue? { get set }

    @objc(send:) func send(_ data: JSValue)
    @objc(close::) func close(_ code: JSValue, _ reason: JSValue)

    @objc(addEventListener::) func addEventListener(_ type: String, _ listener: JSValue)
    @objc(removeEventListener::) func removeEventListener(_ type: String, _ listener: JSValue)
}

@objc(WebSocket) class JSWebSocket: NSObject, JSWebSocketExport {
    private(set) var url: String
    private(set) var `protocol`: String = ""
    private(set) var extensions: String = ""
    private(set) var bufferedAmount: Int = 0

    private var _readyState: JSWebSocketReadyState = .connecting
    var readyState: Int { _readyState.rawValue }

    private var _binaryType: JSWebSocketBinaryType = .blob
    var binaryType: String {
        get { _binaryType.rawValue }
        set { _binaryType = JSWebSocketBinaryType(rawValue: newValue) ?? .blob }
    }

    var onopen: JSValue?
    var onmessage: JSValue?
    var onclose: JSValue?
    var onerror: JSValue?

    private var eventListeners: [JSEventType: [JSManagedValue]] = [:]
    private var task: (any JSWebSocketTaskProtocol)?
    private weak var context: JSContext?

    private init?(url urlString: String, protocols: JSValue, context: JSContext, task: (any JSWebSocketTaskProtocol)? = nil) {
        self.context = context

        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              ["ws", "wss", "http", "https"].contains(scheme) else {
            context.exception = JSValue(
                newErrorFromMessage: "Failed to construct 'WebSocket': The URL '\(urlString)' is invalid.",
                in: context
            )
            return nil
        }

        if url.fragment != nil {
            context.exception = JSValue(
                newErrorFromMessage: "Failed to construct 'WebSocket': The URL contains a fragment identifier ('\(urlString)').",
                in: context
            )
            return nil
        }

        self.url = urlString

        let protocolList: [String]

        if protocols.isString {
            protocolList = [protocols.toString()]
        } else if protocols.isArray {
            protocolList = protocols.toArray().compactMap { $0 as? String }
        } else {
            protocolList = []
        }

        if Set(protocolList).count != protocolList.count {
            context.exception = JSValue(
                newErrorFromMessage: "Failed to construct 'WebSocket': The subprotocol is duplicated.",
                in: context
            )
            return nil
        }

        super.init()

        let wsTask = task ?? JSWebSocketTask(url: url, protocols: protocolList)
        self.task = wsTask

        Task {
            let stream = await wsTask.start()

            for await event in stream {
                self.handleEvent(event)
            }
        }
    }

    required convenience init?(url urlString: String, protocols: JSValue) {
        guard let context = JSContext.current() else { return nil }

        self.init(url: urlString, protocols: protocols, context: context)
    }

    @objc(send:)
    func send(_ data: JSValue) {
        guard let context = self.context else { return }

        guard _readyState != .connecting else {
            context.exception = JSValue(
                newErrorFromMessage: "Failed to execute 'send': Still in CONNECTING state.",
                in: context
            )
            return
        }

        let byteCount = data.bytesNumber
        bufferedAmount += byteCount

        guard _readyState == .open else { return }

        Task {
            guard let task = self.task else { return }
            do {
                if data.isString {
                    try await task.send(.string(data.toString()))
                } else {
                    let bytes = await extractBytes(from: data, in: context)

                    if let bytes {
                        try await task.send(.data(bytes))
                    } else {
                        try await task.send(.string(data.toString()))
                    }
                }
            } catch {
                // Do not log transport errors here: their descriptions may contain
                // authenticated streaming URLs.
            }
            bufferedAmount = max(0, bufferedAmount - byteCount)
        }
    }

    @objc(close::)
    func close(_ codeValue: JSValue, _ reasonValue: JSValue) {
        guard _readyState == .connecting || _readyState == .open else { return }

        let reason: String = reasonValue.toString() ?? ""
        
        self._readyState = .closing

        Task {
            let closeCode = URLSessionWebSocketTask.CloseCode(rawValue: Int(codeValue.toInt32())) ?? .normalClosure

            await task?.close(code: closeCode, reason: reason.data(using: .utf8))
        }
    }

    @objc(addEventListener::)
    func addEventListener(_ type: String, _ listener: JSValue) {
        guard let eventType = JSEventType(rawValue: type), listener.isObject else { return }
        
        guard let managed = JSManagedValue(value: listener, andOwner: self) else { return }
        
        eventListeners[eventType, default: []].append(managed)
    }

    @objc(removeEventListener::)
    func removeEventListener(_ type: String, _ listener: JSValue) {
        guard let eventType = JSEventType(rawValue: type) else { return }
        
        eventListeners[eventType]?.removeAll { managed in
            managed.value?.isEqual(to: listener) ?? false
        }
    }

    func extractBytes(from value: JSValue, in context: JSContext) async -> Data? {
        if value.isUndefined || value.isNull {
            return nil
        }

        if let blob = value.toObjectOf(JSBlob.self) as? JSBlob {
            guard let utf8 = try? await blob.utf8(context: context) else { return nil }
            return Data(utf8)
        }

        let uint8Array = JSValue.uint8Array(from: value, context: context)
        return Data(uint8Array: uint8Array)
    }
}

extension JSWebSocket {

    func handleEvent(_ event: JSWebSocketEvent) {
        guard let context = self.context else { return }

        switch event {
        case .open(let negotiatedProtocol):
            _readyState = .open
            `protocol` = negotiatedProtocol ?? ""
            dispatchEvent(JSOpenEvent(), in: context)

        case .message(let message):
            switch message {
            case .text(let text):
                let value = JSValue(object: text, in: context)
                let properties = JSMessageEventProperties(data: value, origin: url)
                
                dispatchEvent(JSMessageEvent(type: .message, properties: properties), in: context)
            case .binary(let data):
                guard let binaryData = self.convertBinaryData(data, in: context) else { return }
                
                let jsValue = binaryData as? JSValue ?? JSValue(object: binaryData, in: context)
                let properties = JSMessageEventProperties(data: jsValue, origin: url)
                
                dispatchEvent(JSMessageEvent(type: .message, properties: properties), in: context)
            }
            
        case .close(let code, let reason, let wasClean):
            _readyState = .closed
            
            let properties = JSCloseEventProperties(wasClean: wasClean, code: code, reason: reason)
            dispatchEvent(JSCloseEvent(properties: properties), in: context)

        case .error(let message):
            let properties = JSErrorEventProperties(message: message)
            dispatchEvent(JSErrorEvent(type: .error, properties: properties), in: context)
        }
    }

    private func convertBinaryData(_ data: Data, in context: JSContext) -> Any? {
        let UInt8Type: JSValue? = context.Uint8Array
        
        guard let bytes = UInt8Type?.construct(withArguments: [Array(data)]) else { return nil }

        let buffer: JSValue? = bytes.buffer
        
        if _binaryType == .blob, let buffer {
            let blob = JSBlob(
                blobParts: JSValue(object: [buffer], in: context),
                options: JSValue(undefinedIn: context),
                context: context
            )
            return JSValue(object: blob, in: context)
        }
        
        return buffer
    }

    private func dispatchEvent(_ event: JSEvent, in context: JSContext) {
        guard let encoded = try? event.encode(in: context) else { return }

        let handler: JSValue?
        
        switch event.type {
        case .open: handler = onopen
        case .message: handler = onmessage
        case .close: handler = onclose
        case .error: handler = onerror
        }
        
        if let handler, handler.isObject {
            handler.call(withArguments: [encoded])
        }
        
        eventListeners[event.type]?.forEach {
            $0.value?.call(withArguments: [encoded])
        }
    }
}
