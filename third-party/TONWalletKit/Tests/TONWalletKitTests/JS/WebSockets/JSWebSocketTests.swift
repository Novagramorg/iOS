//
//  JSWebSocketTests.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 16.03.2026.
//
//  Copyright (c) 2026 TON Connect
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

import Testing
import JavaScriptCore
@testable import TONWalletKit
@_private(sourceFile: "JSWebSocket.swift")
import TONWalletKit

@Suite("JSWebSocket Tests")
struct JSWebSocketTests {

    private let context: JSContext = {
        let ctx = JSContext()!
        try! ctx.install([.blob])
        return ctx
    }()

    private func makeWebSocket(url: String = "ws://localhost:8080", task: MockJSWebSocketTask = MockJSWebSocketTask()) -> JSWebSocket? {
        let protocols = JSValue(undefinedIn: context)!
        return JSWebSocket(url: url, protocols: protocols, context: context, task: task)
    }

    // MARK: - Initialization

    @Test("Initializes with valid ws URL")
    func initWithValidWsURL() {
        let ws = makeWebSocket(url: "ws://localhost:8080")
        #expect(ws != nil)
        #expect(ws?.url == "ws://localhost:8080")
        #expect(ws?._readyState == .connecting)
    }

    @Test("Initializes with valid wss URL")
    func initWithValidWssURL() {
        let ws = makeWebSocket(url: "wss://example.com/socket")
        #expect(ws != nil)
    }

    @Test("Initializes with valid http URL")
    func initWithValidHttpURL() {
        let ws = makeWebSocket(url: "http://example.com/ws")
        #expect(ws != nil)
    }

    @Test("Initializes with valid https URL")
    func initWithValidHttpsURL() {
        let ws = makeWebSocket(url: "https://example.com/ws")
        #expect(ws != nil)
    }

    @Test("Fails with invalid scheme")
    func failsWithInvalidScheme() {
        let ws = makeWebSocket(url: "ftp://example.com")
        #expect(ws == nil)
        #expect(context.exception != nil)
    }

    @Test("Fails with invalid URL")
    func failsWithInvalidURL() {
        let ws = makeWebSocket(url: "")
        #expect(ws == nil)
    }

    @Test("Fails with fragment in URL")
    func failsWithFragment() {
        let ws = makeWebSocket(url: "ws://example.com/path#fragment")
        #expect(ws == nil)
        #expect(context.exception != nil)
    }

    @Test("Fails with duplicate protocols")
    func failsWithDuplicateProtocols() {
        let protocols = JSValue(object: ["soap", "soap"], in: context)!
        let ws = JSWebSocket(url: "ws://localhost", protocols: protocols, context: context, task: MockJSWebSocketTask())
        #expect(ws == nil)
        #expect(context.exception != nil)
    }

    @Test("Parses string protocol")
    func parsesStringProtocol() {
        let protocols = JSValue(object: "soap", in: context)!
        let ws = JSWebSocket(url: "ws://localhost", protocols: protocols, context: context, task: MockJSWebSocketTask())
        #expect(ws != nil)
    }

    @Test("Parses array protocols")
    func parsesArrayProtocols() {
        let protocols = JSValue(object: ["soap", "wamp"], in: context)!
        let ws = JSWebSocket(url: "ws://localhost", protocols: protocols, context: context, task: MockJSWebSocketTask())
        #expect(ws != nil)
    }

    @Test("Default readyState is connecting")
    func defaultReadyState() {
        let ws = makeWebSocket()
        #expect(ws?.readyState == JSWebSocketReadyState.connecting.rawValue)
    }

    @Test("Default binaryType is blob")
    func defaultBinaryType() {
        let ws = makeWebSocket()
        #expect(ws?.binaryType == "blob")
    }

    @Test("Default protocol is empty")
    func defaultProtocol() {
        let ws = makeWebSocket()
        #expect(ws?.protocol == "")
    }

    // MARK: - Event Handling: Open

    @Test("Open event sets readyState to open")
    func openEventSetsReadyState() {
        let ws = makeWebSocket()!
        ws.handleEvent(.open(negotiatedProtocol: nil))
        #expect(ws._readyState == .open)
    }

    @Test("Open event sets negotiated protocol")
    func openEventSetsProtocol() {
        let ws = makeWebSocket()!
        ws.handleEvent(.open(negotiatedProtocol: "soap"))
        #expect(ws.protocol == "soap")
    }

    @Test("Open event with nil protocol sets empty string")
    func openEventNilProtocol() {
        let ws = makeWebSocket()!
        ws.handleEvent(.open(negotiatedProtocol: nil))
        #expect(ws.protocol == "")
    }

    @Test("Open event dispatches to onopen handler")
    func openEventDispatchesToHandler() {
        let ws = makeWebSocket()!

        context.evaluateScript("var openCalled = false;")
        ws.onopen = context.evaluateScript("(function(e) { openCalled = true; })")

        ws.handleEvent(.open(negotiatedProtocol: nil))

        let called: Bool = context.evaluateScript("openCalled").toBool()
        #expect(called == true)
    }

    @Test("Open event has correct type")
    func openEventHasCorrectType() {
        let ws = makeWebSocket()!

        context.evaluateScript("var eventType = '';")
        ws.onopen = context.evaluateScript("(function(e) { eventType = e.type; })")

        ws.handleEvent(.open(negotiatedProtocol: nil))

        let type: String = context.evaluateScript("eventType").toString()
        #expect(type == "open")
    }

    // MARK: - Event Handling: Message

    @Test("Text message dispatches to onmessage with data and origin")
    func textMessageEvent() {
        let ws = makeWebSocket()!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        context.evaluateScript("var msgData = ''; var msgOrigin = '';")
        ws.onmessage = context.evaluateScript("(function(e) { msgData = e.data; msgOrigin = e.origin; })")

        ws.handleEvent(.message(.text("hello")))

        let data: String = context.evaluateScript("msgData").toString()
        let origin: String = context.evaluateScript("msgOrigin").toString()
        #expect(data == "hello")
        #expect(origin == "ws://localhost:8080")
    }

    @Test("Message event has correct type")
    func messageEventHasCorrectType() {
        let ws = makeWebSocket()!

        context.evaluateScript("var eventType = '';")
        ws.onmessage = context.evaluateScript("(function(e) { eventType = e.type; })")

        ws.handleEvent(.message(.text("test")))

        let type: String = context.evaluateScript("eventType").toString()
        #expect(type == "message")
    }

    // MARK: - Event Handling: Close

    @Test("Close event sets readyState to closed")
    func closeEventSetsReadyState() {
        let ws = makeWebSocket()!
        ws.handleEvent(.open(negotiatedProtocol: nil))
        ws.handleEvent(.close(code: 1000, reason: "normal", wasClean: true))
        #expect(ws._readyState == .closed)
    }

    @Test("Close event dispatches with code, reason, and wasClean")
    func closeEventProperties() {
        let ws = makeWebSocket()!

        context.evaluateScript("var closeCode = 0; var closeReason = ''; var closeWasClean = false;")
        ws.onclose = context.evaluateScript("""
            (function(e) {
                closeCode = e.code;
                closeReason = e.reason;
                closeWasClean = e.wasClean;
            })
        """)

        ws.handleEvent(.close(code: 1001, reason: "going away", wasClean: true))

        let code: Int32 = context.evaluateScript("closeCode").toInt32()
        let reason: String = context.evaluateScript("closeReason").toString()
        let wasClean: Bool = context.evaluateScript("closeWasClean").toBool()
        #expect(code == 1001)
        #expect(reason == "going away")
        #expect(wasClean == true)
    }

    // MARK: - Event Handling: Error

    @Test("Error event dispatches with message")
    func errorEventMessage() {
        let ws = makeWebSocket()!

        context.evaluateScript("var errorMsg = '';")
        ws.onerror = context.evaluateScript("(function(e) { errorMsg = e.message; })")

        ws.handleEvent(.error("connection refused"))

        let message: String = context.evaluateScript("errorMsg").toString()
        #expect(message == "connection refused")
    }

    @Test("Error event has correct type")
    func errorEventHasCorrectType() {
        let ws = makeWebSocket()!

        context.evaluateScript("var eventType = '';")
        ws.onerror = context.evaluateScript("(function(e) { eventType = e.type; })")

        ws.handleEvent(.error("fail"))

        let type: String = context.evaluateScript("eventType").toString()
        #expect(type == "error")
    }

    // MARK: - addEventListener

    @Test("addEventListener receives dispatched events")
    func addEventListenerReceivesEvents() {
        let ws = makeWebSocket()!

        context.evaluateScript("var listenerCalled = false;")
        let listener = context.evaluateScript("(function(e) { listenerCalled = true; })")!
        ws.addEventListener("open", listener)

        ws.handleEvent(.open(negotiatedProtocol: nil))

        let called: Bool? = context.evaluateScript("listenerCalled").toBool()
        #expect(called == true)
    }

    @Test("Multiple listeners all get called")
    func multipleListenersGetCalled() {
        let ws = makeWebSocket()!

        context.evaluateScript("var count = 0;")
        let listener1 = context.evaluateScript("(function(e) { count++; })")!
        let listener2 = context.evaluateScript("(function(e) { count++; })")!
        ws.addEventListener("message", listener1)
        ws.addEventListener("message", listener2)

        ws.handleEvent(.message(.text("test")))

        let count: Int32 = context.evaluateScript("count").toInt32()
        #expect(count == 2)
    }

    @Test("removeEventListener stops dispatching")
    func removeEventListenerStopsDispatching() {
        let ws = makeWebSocket()!

        context.evaluateScript("var count = 0;")
        let listener = context.evaluateScript("(function(e) { count++; })")!
        ws.addEventListener("open", listener)
        ws.removeEventListener("open", listener)

        ws.handleEvent(.open(negotiatedProtocol: nil))

        let count: Int32 = context.evaluateScript("count").toInt32()
        #expect(count == 0)
    }

    @Test("addEventListener ignores unknown event types")
    func addEventListenerIgnoresUnknownTypes() {
        let ws = makeWebSocket()!

        context.evaluateScript("var called = false;")
        let listener = context.evaluateScript("(function(e) { called = true; })")!
        ws.addEventListener("unknown", listener)

        #expect(context.evaluateScript("called").toBool() == false)
    }

    // MARK: - Both on* handler and addEventListener

    @Test("Both onopen and addEventListener listener are called")
    func bothHandlerAndListenerCalled() {
        let ws = makeWebSocket()!

        context.evaluateScript("var handlerCalled = false; var listenerCalled = false;")
        ws.onopen = context.evaluateScript("(function(e) { handlerCalled = true; })")
        let listener = context.evaluateScript("(function(e) { listenerCalled = true; })")!
        ws.addEventListener("open", listener)

        ws.handleEvent(.open(negotiatedProtocol: nil))

        #expect(context.evaluateScript("handlerCalled").toBool() == true)
        #expect(context.evaluateScript("listenerCalled").toBool() == true)
    }

    // MARK: - Binary Message Reception: ArrayBuffer

    @Test("Binary message with arraybuffer type delivers ArrayBuffer")
    func binaryMessageArrayBuffer() {
        let ws = makeWebSocket()!
        ws.binaryType = "arraybuffer"
        ws.handleEvent(.open(negotiatedProtocol: nil))

        context.evaluateScript("var isArrayBuffer = false; var byteLength = -1;")
        ws.onmessage = context.evaluateScript("""
            (function(e) {
                isArrayBuffer = e.data instanceof ArrayBuffer;
                byteLength = e.data.byteLength;
            })
        """)

        ws.handleEvent(.message(.binary(Data([1, 2, 3]))))

        #expect(context.evaluateScript("isArrayBuffer").toBool() == true)
        #expect(context.evaluateScript("byteLength").toInt32() == 3)
    }

    @Test("Binary message with arraybuffer preserves byte values")
    func binaryMessageArrayBufferBytes() {
        let ws = makeWebSocket()!
        ws.binaryType = "arraybuffer"
        ws.handleEvent(.open(negotiatedProtocol: nil))

        context.evaluateScript("var receivedBytes = [];")
        ws.onmessage = context.evaluateScript("""
            (function(e) {
                var view = new Uint8Array(e.data);
                for (var i = 0; i < view.length; i++) {
                    receivedBytes.push(view[i]);
                }
            })
        """)

        ws.handleEvent(.message(.binary(Data([10, 20, 30, 255, 0, 128]))))

        #expect(context.evaluateScript("receivedBytes[0]").toInt32() == 10)
        #expect(context.evaluateScript("receivedBytes[1]").toInt32() == 20)
        #expect(context.evaluateScript("receivedBytes[2]").toInt32() == 30)
        #expect(context.evaluateScript("receivedBytes[3]").toInt32() == 255)
        #expect(context.evaluateScript("receivedBytes[4]").toInt32() == 0)
        #expect(context.evaluateScript("receivedBytes[5]").toInt32() == 128)
    }

    @Test("Binary message preserves all 256 byte values")
    func binaryMessageAll256Bytes() {
        let ws = makeWebSocket()!
        ws.binaryType = "arraybuffer"
        ws.handleEvent(.open(negotiatedProtocol: nil))

        context.evaluateScript("var allMatch = false;")
        ws.onmessage = context.evaluateScript("""
            (function(e) {
                var view = new Uint8Array(e.data);
                if (view.length !== 256) { allMatch = false; return; }
                allMatch = true;
                for (var i = 0; i < 256; i++) {
                    if (view[i] !== i) { allMatch = false; break; }
                }
            })
        """)

        let allBytes = Data((0...255).map { UInt8($0) })
        ws.handleEvent(.message(.binary(allBytes)))

        #expect(context.evaluateScript("allMatch").toBool() == true)
    }

    @Test("Empty binary data delivers empty ArrayBuffer")
    func emptyBinaryArrayBuffer() {
        let ws = makeWebSocket()!
        ws.binaryType = "arraybuffer"
        ws.handleEvent(.open(negotiatedProtocol: nil))

        context.evaluateScript("var called = false; var len = -1;")
        ws.onmessage = context.evaluateScript("""
            (function(e) {
                called = true;
                len = e.data.byteLength;
            })
        """)

        ws.handleEvent(.message(.binary(Data())))

        #expect(context.evaluateScript("called").toBool() == true)
        #expect(context.evaluateScript("len").toInt32() == 0)
    }

    @Test("Binary message origin matches URL with arraybuffer type")
    func binaryMessageOriginArrayBuffer() {
        let ws = makeWebSocket(url: "wss://example.com/ws")!
        ws.binaryType = "arraybuffer"
        ws.handleEvent(.open(negotiatedProtocol: nil))

        context.evaluateScript("var origin = '';")
        ws.onmessage = context.evaluateScript("(function(e) { origin = e.origin; })")

        ws.handleEvent(.message(.binary(Data([1]))))

        #expect(context.evaluateScript("origin").toString() == "wss://example.com/ws")
    }

    @Test("Large binary data preserves integrity")
    func largeBinaryData() {
        let ws = makeWebSocket()!
        ws.binaryType = "arraybuffer"
        ws.handleEvent(.open(negotiatedProtocol: nil))

        context.evaluateScript("var size = 0; var checksum = 0;")
        ws.onmessage = context.evaluateScript("""
            (function(e) {
                var view = new Uint8Array(e.data);
                size = view.length;
                for (var i = 0; i < view.length; i++) {
                    checksum = (checksum + view[i]) & 0xFFFFFFFF;
                }
            })
        """)

        var data = Data(count: 1024)
        for i in 0..<1024 { data[i] = UInt8(i % 256) }
        let expectedChecksum: Int32 = (0..<1024).reduce(0) { ($0 + Int32($1 % 256)) & 0x7FFFFFFF }

        ws.handleEvent(.message(.binary(data)))

        #expect(context.evaluateScript("size").toInt32() == 1024)
        #expect(context.evaluateScript("checksum").toInt32() == expectedChecksum)
    }

    // MARK: - Binary Message Reception: Blob

    @Test("Binary message with blob type delivers Blob instance")
    func binaryMessageBlob() {
        let ws = makeWebSocket()!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        context.evaluateScript("var isBlob = false; var hasSize = false;")
        ws.onmessage = context.evaluateScript("""
            (function(e) {
                isBlob = e.data instanceof Blob;
                hasSize = typeof e.data.size === 'number';
            })
        """)

        ws.handleEvent(.message(.binary(Data([1, 2, 3, 4, 5]))))

        #expect(context.evaluateScript("isBlob").toBool() == true)
        #expect(context.evaluateScript("hasSize").toBool() == true)
    }

    @Test("Empty binary data delivers Blob instance")
    func emptyBinaryBlob() {
        let ws = makeWebSocket()!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        context.evaluateScript("var called = false; var isBlob = false;")
        ws.onmessage = context.evaluateScript("""
            (function(e) {
                called = true;
                isBlob = e.data instanceof Blob;
            })
        """)

        ws.handleEvent(.message(.binary(Data())))

        #expect(context.evaluateScript("called").toBool() == true)
        #expect(context.evaluateScript("isBlob").toBool() == true)
    }

    @Test("Binary message origin matches URL with blob type")
    func binaryMessageOriginBlob() {
        let ws = makeWebSocket(url: "ws://test.local:9090/path")!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        context.evaluateScript("var origin = '';")
        ws.onmessage = context.evaluateScript("(function(e) { origin = e.origin; })")

        ws.handleEvent(.message(.binary(Data([42]))))

        #expect(context.evaluateScript("origin").toString() == "ws://test.local:9090/path")
    }

    // MARK: - Switching binaryType

    @Test("Switching binaryType between messages changes data format")
    func switchBinaryType() {
        let ws = makeWebSocket()!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        context.evaluateScript("var firstIsBlob = false; var secondIsArrayBuffer = false;")
        ws.onmessage = context.evaluateScript("""
            (function(e) {
                if (e.data instanceof Blob) { firstIsBlob = true; }
                if (e.data instanceof ArrayBuffer) { secondIsArrayBuffer = true; }
            })
        """)

        ws.handleEvent(.message(.binary(Data([1]))))
        #expect(context.evaluateScript("firstIsBlob").toBool() == true)

        ws.binaryType = "arraybuffer"
        ws.handleEvent(.message(.binary(Data([2]))))
        #expect(context.evaluateScript("secondIsArrayBuffer").toBool() == true)
    }

    // MARK: - Binary + addEventListener

    @Test("Binary message dispatches to addEventListener")
    func binaryMessageAddEventListener() {
        let ws = makeWebSocket()!
        ws.binaryType = "arraybuffer"
        ws.handleEvent(.open(negotiatedProtocol: nil))

        context.evaluateScript("var listenerByteLength = -1;")
        let listener = context.evaluateScript("""
            (function(e) { listenerByteLength = e.data.byteLength; })
        """)!
        ws.addEventListener("message", listener)

        ws.handleEvent(.message(.binary(Data([10, 20]))))

        #expect(context.evaluateScript("listenerByteLength").toInt32() == 2)
    }

    @Test("Binary message dispatches to both onmessage and addEventListener")
    func binaryMessageBothHandlerAndListener() {
        let ws = makeWebSocket()!
        ws.binaryType = "arraybuffer"
        ws.handleEvent(.open(negotiatedProtocol: nil))

        context.evaluateScript("var handlerLen = -1; var listenerLen = -1;")
        ws.onmessage = context.evaluateScript("(function(e) { handlerLen = e.data.byteLength; })")
        let listener = context.evaluateScript("(function(e) { listenerLen = e.data.byteLength; })")!
        ws.addEventListener("message", listener)

        ws.handleEvent(.message(.binary(Data([1, 2, 3, 4]))))

        #expect(context.evaluateScript("handlerLen").toInt32() == 4)
        #expect(context.evaluateScript("listenerLen").toInt32() == 4)
    }

    // MARK: - Send: String

    @Test("Send string when open")
    func sendString() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        ws.send(JSValue(object: "hello", in: context))
        let messages = await sent

        #expect(messages.count == 1)
        if case .string(let text) = messages.first {
            #expect(text == "hello")
        } else {
            Issue.record("Expected string message")
        }
    }

    @Test("Send throws when connecting")
    func sendThrowsWhenConnecting() {
        let ws = makeWebSocket()!

        ws.send(JSValue(object: "test", in: context))

        #expect(context.exception != nil)
    }

    @Test("Send ignored when closed")
    func sendIgnoredWhenClosed() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))
        ws.handleEvent(.close(code: 1000, reason: "done", wasClean: true))

        ws.send(JSValue(object: "test", in: context))

        try? await Task.sleep(nanoseconds: 50 * 1_000_000)

        let messages = await mockTask.sentMessages
        #expect(messages.isEmpty)
    }

    @Test("Send number creates Uint8Array of that length")
    func sendNumberCreatesTypedArray() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        ws.send(JSValue(int32: 3, in: context))
        let messages = await sent

        #expect(messages.count == 1)
        if case .data(let data) = messages.first {
            #expect(data.count == 3)
            #expect(Array(data) == [0, 0, 0])
        } else {
            Issue.record("Expected data message")
        }
    }

    @Test("Send boolean creates Uint8Array of length 1")
    func sendBooleanCreatesTypedArray() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        ws.send(JSValue(bool: true, in: context))
        let messages = await sent

        #expect(messages.count == 1)
        if case .data(let data) = messages.first {
            #expect(data.count == 1)
            #expect(Array(data) == [0])
        } else {
            Issue.record("Expected data message")
        }
    }

    // MARK: - Send: Binary

    @Test("Send Uint8Array")
    func sendUint8Array() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        let uint8Array = context.evaluateScript("new Uint8Array([1, 2, 3])")!
        ws.send(uint8Array)
        let messages = await sent

        #expect(messages.count == 1)
        if case .data(let data) = messages.first {
            #expect(Array(data) == [1, 2, 3])
        } else {
            Issue.record("Expected data message")
        }
    }

    @Test("Send ArrayBuffer")
    func sendArrayBuffer() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        let arrayBuffer = context.evaluateScript("""
            (function() {
                var buf = new ArrayBuffer(3);
                var view = new Uint8Array(buf);
                view[0] = 10; view[1] = 20; view[2] = 30;
                return buf;
            })()
        """)!
        ws.send(arrayBuffer)
        let messages = await sent

        #expect(messages.count == 1)
        if case .data(let data) = messages.first {
            #expect(Array(data) == [10, 20, 30])
        } else {
            Issue.record("Expected data message")
        }
    }

    @Test("Send Uint16Array reads raw buffer bytes")
    func sendUint16Array() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        let typedArray = context.evaluateScript("new Uint16Array([256, 512])")!
        ws.send(typedArray)
        let messages = await sent

        #expect(messages.count == 1)
        if case .data(let data) = messages.first {
            #expect(data.count == 4)
            #expect(Array(data) == [0, 1, 0, 2])
        } else {
            Issue.record("Expected data message")
        }
    }

    @Test("Send empty Uint8Array")
    func sendEmptyUint8Array() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        let empty = context.evaluateScript("new Uint8Array([])")!
        ws.send(empty)
        let messages = await sent

        #expect(messages.count == 1)
        if case .data(let data) = messages.first {
            #expect(data.isEmpty)
        } else {
            Issue.record("Expected data message")
        }
    }

    // MARK: - Send: extractBytes edge cases

    @Test("Send null falls back to string")
    func sendNullFallsBackToString() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        ws.send(JSValue(nullIn: context))
        let messages = await sent

        #expect(messages.count == 1)
        if case .string(let text) = messages.first {
            #expect(text == "null")
        } else {
            Issue.record("Expected string fallback for null")
        }
    }

    @Test("Send undefined falls back to string")
    func sendUndefinedFallsBackToString() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        ws.send(JSValue(undefinedIn: context))
        let messages = await sent

        #expect(messages.count == 1)
        if case .string(let text) = messages.first {
            #expect(text == "undefined")
        } else {
            Issue.record("Expected string fallback for undefined")
        }
    }

    @Test("Send plain JS object extracts zero bytes")
    func sendPlainObjectExtractsZeroBytes() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        let obj = context.evaluateScript("({})")!
        ws.send(obj)
        let messages = await sent

        #expect(messages.count == 1)
        if case .data(let data) = messages.first {
            #expect(data.isEmpty)
        } else {
            Issue.record("Expected empty data for plain object")
        }
    }

    @Test("Send JS array extracts bytes via Uint8Array constructor")
    func sendJSArrayExtractsBytes() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        let arr = context.evaluateScript("[10, 20, 30]")!
        ws.send(arr)
        let messages = await sent

        #expect(messages.count == 1)
        if case .data(let data) = messages.first {
            #expect(Array(data) == [10, 20, 30])
        } else {
            Issue.record("Expected data message from JS array")
        }
    }

    @Test("Send Int8Array with negative values reads raw buffer bytes")
    func sendInt8ArrayNegativeValues() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        let int8 = context.evaluateScript("new Int8Array([-1, -128, 127, 0])")!
        ws.send(int8)
        let messages = await sent

        #expect(messages.count == 1)
        if case .data(let data) = messages.first {
            #expect(data.count == 4)
            #expect(Array(data) == [255, 128, 127, 0])
        } else {
            Issue.record("Expected data message from Int8Array")
        }
    }

    @Test("Send Float64Array reads raw buffer bytes")
    func sendFloat64ArrayRawBuffer() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        let float64 = context.evaluateScript("new Float64Array([1.9, 255.5, 0.1])")!
        ws.send(float64)
        let messages = await sent

        #expect(messages.count == 1)
        if case .data(let data) = messages.first {
            #expect(data.count == 24)
        } else {
            Issue.record("Expected data message from Float64Array")
        }
    }

    @Test("Send Uint8Array with boundary values 0 and 255")
    func sendBoundaryByteValues() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        let arr = context.evaluateScript("new Uint8Array([0, 1, 254, 255])")!
        ws.send(arr)
        let messages = await sent

        #expect(messages.count == 1)
        if case .data(let data) = messages.first {
            #expect(Array(data) == [0, 1, 254, 255])
        } else {
            Issue.record("Expected data message")
        }
    }

    @Test("Send Uint8Array subarray extracts correct slice")
    func sendUint8ArraySubarray() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        let subarray = context.evaluateScript("""
            new Uint8Array([10, 20, 30, 40, 50]).subarray(1, 4)
        """)!
        ws.send(subarray)
        let messages = await sent

        #expect(messages.count == 1)
        if case .data(let data) = messages.first {
            #expect(Array(data) == [20, 30, 40])
        } else {
            Issue.record("Expected data message from subarray")
        }
    }

    @Test("Send Uint16Array subarray extracts correct slice")
    func sendUint16ArraySubarray() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        let subarray = context.evaluateScript("new Uint16Array([1, 2, 3, 4]).subarray(1, 3)")!
        ws.send(subarray)
        let messages = await sent

        #expect(messages.count == 1)
        if case .data(let data) = messages.first {
            #expect(data.count == 4)
            #expect(Array(data) == [2, 0, 3, 0])
        } else {
            Issue.record("Expected data message from Uint16Array subarray")
        }
    }

    @Test("Send Uint32Array subarray extracts correct slice")
    func sendUint32ArraySubarray() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        let subarray = context.evaluateScript("new Uint32Array([1, 2, 3]).subarray(0, 2)")!
        ws.send(subarray)
        let messages = await sent

        #expect(messages.count == 1)
        if case .data(let data) = messages.first {
            #expect(data.count == 8)
        } else {
            Issue.record("Expected data message from Uint32Array subarray")
        }
    }

    @Test("Send Float64Array subarray extracts correct slice")
    func sendFloat64ArraySubarray() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        let subarray = context.evaluateScript("new Float64Array([1.0, 2.0, 3.0]).subarray(1, 2)")!
        ws.send(subarray)
        let messages = await sent

        #expect(messages.count == 1)
        if case .data(let data) = messages.first {
            #expect(data.count == 8)
        } else {
            Issue.record("Expected data message from Float64Array subarray")
        }
    }

    @Test("Send Int16Array reads raw buffer bytes")
    func sendInt16ArrayRawBuffer() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        let int16 = context.evaluateScript("new Int16Array([300, -1, 0, 32767])")!
        ws.send(int16)
        let messages = await sent

        #expect(messages.count == 1)
        if case .data(let data) = messages.first {
            #expect(data.count == 8)
            #expect(Array(data) == [0x2C, 0x01, 0xFF, 0xFF, 0x00, 0x00, 0xFF, 0x7F])
        } else {
            Issue.record("Expected data message from Int16Array")
        }
    }

    @Test("Send Uint32Array reads raw buffer bytes")
    func sendUint32ArrayRawBuffer() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        let uint32 = context.evaluateScript("new Uint32Array([256, 65535, 0, 1])")!
        ws.send(uint32)
        let messages = await sent

        #expect(messages.count == 1)
        if case .data(let data) = messages.first {
            #expect(data.count == 16)
        } else {
            Issue.record("Expected data message from Uint32Array")
        }
    }

    @Test("Send Float32Array reads raw buffer bytes")
    func sendFloat32ArrayRawBuffer() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        let float32 = context.evaluateScript("new Float32Array([NaN, Infinity, -Infinity])")!
        ws.send(float32)
        let messages = await sent

        #expect(messages.count == 1)
        if case .data(let data) = messages.first {
            #expect(data.count == 12)
        } else {
            Issue.record("Expected data message from Float32Array")
        }
    }

    @Test("Send Uint8ClampedArray preserves clamped values")
    func sendUint8ClampedArray() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        let clamped = context.evaluateScript("new Uint8ClampedArray([0, 128, 255, 300, -10])")!
        ws.send(clamped)
        let messages = await sent

        #expect(messages.count == 1)
        if case .data(let data) = messages.first {
            #expect(data.count == 5)
            #expect(Array(data) == [0, 128, 255, 255, 0])
        } else {
            Issue.record("Expected data message from Uint8ClampedArray")
        }
    }

    @Test("Send DataView reads correct bytes")
    func sendDataView() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        let dv = context.evaluateScript("""
            (function() {
                var buf = new ArrayBuffer(4);
                var dv = new DataView(buf);
                dv.setUint8(0, 0xDE);
                dv.setUint8(1, 0xAD);
                dv.setUint8(2, 0xBE);
                dv.setUint8(3, 0xEF);
                return dv;
            })()
        """)!
        ws.send(dv)
        let messages = await sent

        #expect(messages.count == 1)
        if case .data(let data) = messages.first {
            #expect(Array(data) == [0xDE, 0xAD, 0xBE, 0xEF])
        } else {
            Issue.record("Expected data message from DataView")
        }
    }

    @Test("Send DataView with offset reads only the viewed portion")
    func sendDataViewWithOffset() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        let dv = context.evaluateScript("""
            (function() {
                var buf = new ArrayBuffer(6);
                var v = new Uint8Array(buf);
                v[0] = 1; v[1] = 2; v[2] = 3; v[3] = 4; v[4] = 5; v[5] = 6;
                return new DataView(buf, 2, 3);
            })()
        """)!
        ws.send(dv)
        let messages = await sent

        #expect(messages.count == 1)
        if case .data(let data) = messages.first {
            #expect(Array(data) == [3, 4, 5])
        } else {
            Issue.record("Expected data message from DataView with offset")
        }
    }

    @Test("Send ArrayBuffer wraps into Uint8Array")
    func sendArrayBufferWithFilledValues() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        let buffer = context.evaluateScript("""
            (function() {
                var buf = new ArrayBuffer(3);
                var view = new Uint8Array(buf);
                view[0] = 0xAA; view[1] = 0xBB; view[2] = 0xCC;
                return buf;
            })()
        """)!
        ws.send(buffer)
        let messages = await sent

        #expect(messages.count == 1)
        if case .data(let data) = messages.first {
            #expect(Array(data) == [0xAA, 0xBB, 0xCC])
        } else {
            Issue.record("Expected data message from ArrayBuffer")
        }
    }

    @Test("Send typed array with single element")
    func sendSingleElementTypedArray() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        let single = context.evaluateScript("new Uint8Array([42])")!
        ws.send(single)
        let messages = await sent

        #expect(messages.count == 1)
        if case .data(let data) = messages.first {
            #expect(Array(data) == [42])
        } else {
            Issue.record("Expected data message")
        }
    }

    @Test("Send JS array with mixed numeric types extracts bytes")
    func sendJSArrayMixedNumericTypes() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        let arr = context.evaluateScript("[1, 2.7, 255, 0, -1]")!
        ws.send(arr)
        let messages = await sent

        #expect(messages.count == 1)
        if case .data(let data) = messages.first {
            #expect(data.count == 5)
            #expect(Array(data) == [1, 2, 255, 0, 255])
        } else {
            Issue.record("Expected data message from mixed array")
        }
    }

    @Test("Send large typed array preserves all bytes")
    func sendLargeTypedArray() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        let large = context.evaluateScript("""
            (function() {
                var arr = new Uint8Array(512);
                for (var i = 0; i < 512; i++) arr[i] = i % 256;
                return arr;
            })()
        """)!
        ws.send(large)
        let messages = await sent

        #expect(messages.count == 1)
        if case .data(let data) = messages.first {
            #expect(data.count == 512)
            for i in 0..<512 {
                #expect(data[i] == UInt8(i % 256))
            }
        } else {
            Issue.record("Expected data message from large typed array")
        }
    }

    @Test("Send ArrayBuffer slice extracts correct portion")
    func sendArrayBufferSlice() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        let slice = context.evaluateScript("""
            (function() {
                var buf = new ArrayBuffer(5);
                var view = new Uint8Array(buf);
                view[0] = 10; view[1] = 20; view[2] = 30; view[3] = 40; view[4] = 50;
                return buf.slice(2, 4);
            })()
        """)!
        ws.send(slice)
        let messages = await sent

        #expect(messages.count == 1)
        if case .data(let data) = messages.first {
            #expect(Array(data) == [30, 40])
        } else {
            Issue.record("Expected data message from ArrayBuffer slice")
        }
    }

    @Test("Send typed array created from another typed array")
    func sendTypedArrayFromTypedArray() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        let derived = context.evaluateScript("""
            new Uint8Array(new Uint16Array([1, 2, 256, 512]))
        """)!
        ws.send(derived)
        let messages = await sent

        #expect(messages.count == 1)
        if case .data(let data) = messages.first {
            #expect(data.count == 4)
            #expect(Array(data) == [1, 2, 0, 0])
        } else {
            Issue.record("Expected data message from derived typed array")
        }
    }

    // MARK: - Round-Trip JS Tests

    @Test("JS Uint8Array round-trip: send and verify exact bytes")
    func jsUint8ArrayRoundTrip() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        let jsArray = context.evaluateScript("new Uint8Array([72, 101, 108, 108, 111])")!
        ws.send(jsArray)
        let messages = await sent

        #expect(messages.count == 1)
        if case .data(let data) = messages.first {
            #expect(Array(data) == [72, 101, 108, 108, 111])
            #expect(String(data: data, encoding: .utf8) == "Hello")
        } else {
            Issue.record("Expected data message")
        }
    }

    @Test("Receive binary and read back as Uint8Array in JS")
    func receiveBinaryReadAsUint8Array() {
        let ws = makeWebSocket()!
        ws.binaryType = "arraybuffer"
        ws.handleEvent(.open(negotiatedProtocol: nil))

        context.evaluateScript("""
            var receivedValues = [];
            var receivedLength = 0;
        """)
        ws.onmessage = context.evaluateScript("""
            (function(e) {
                var view = new Uint8Array(e.data);
                receivedLength = view.length;
                for (var i = 0; i < view.length; i++) {
                    receivedValues.push(view[i]);
                }
            })
        """)

        ws.handleEvent(.message(.binary(Data([10, 20, 30]))))

        #expect(context.evaluateScript("receivedLength").toInt32() == 3)
        #expect(context.evaluateScript("receivedValues[0]").toInt32() == 10)
        #expect(context.evaluateScript("receivedValues[1]").toInt32() == 20)
        #expect(context.evaluateScript("receivedValues[2]").toInt32() == 30)
    }

    @Test("Receive binary as Blob instance in JS")
    func receiveBinaryAsBlob() {
        let ws = makeWebSocket()!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        context.evaluateScript("var isBlob = false; var hasSize = false;")
        ws.onmessage = context.evaluateScript("""
            (function(e) {
                isBlob = e.data instanceof Blob;
                hasSize = typeof e.data.size === 'number';
            })
        """)

        let data = Data(repeating: 0xAB, count: 100)
        ws.handleEvent(.message(.binary(data)))

        #expect(context.evaluateScript("isBlob").toBool() == true)
        #expect(context.evaluateScript("hasSize").toBool() == true)
    }

    @Test("JS DataView fill ArrayBuffer, send, verify bytes")
    func jsDataViewRoundTrip() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        let buf = context.evaluateScript("""
            (function() {
                var buf = new ArrayBuffer(4);
                var view = new DataView(buf);
                view.setUint8(0, 0xDE);
                view.setUint8(1, 0xAD);
                view.setUint8(2, 0xBE);
                view.setUint8(3, 0xEF);
                return buf;
            })()
        """)!
        ws.send(buf)
        let messages = await sent

        #expect(messages.count == 1)
        if case .data(let data) = messages.first {
            #expect(Array(data) == [0xDE, 0xAD, 0xBE, 0xEF])
        } else {
            Issue.record("Expected data message")
        }
    }

    @Test("Send multiple messages in sequence")
    func sendMultipleMessages() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 3)
        ws.send(JSValue(object: "first", in: context))
        ws.send(JSValue(object: "second", in: context))
        ws.send(context.evaluateScript("new Uint8Array([1, 2])")!)
        let messages = await sent

        #expect(messages.count == 3)
        let strings = messages.compactMap { if case .string(let t) = $0 { return t } else { return nil } }
        let datas = messages.compactMap { if case .data(let d) = $0 { return Array(d) } else { return nil } }
        #expect(Set(strings) == Set(["first", "second"]))
        #expect(datas == [[1, 2]])
    }

    @Test("bufferedAmount starts at zero")
    func bufferedAmountStartsAtZero() {
        let ws = makeWebSocket()!
        #expect(ws.bufferedAmount == 0)
    }

    @Test("bufferedAmount increases by UTF-8 byte count for string")
    func bufferedAmountString() {
        let ws = makeWebSocket()!
        ws.handleEvent(.open(negotiatedProtocol: nil))
        ws.send(JSValue(object: "hello", in: context))
        #expect(ws.bufferedAmount == 5)
    }

    @Test("bufferedAmount increases by UTF-8 byte count for multi-byte string")
    func bufferedAmountMultiByteString() {
        let ws = makeWebSocket()!
        ws.handleEvent(.open(negotiatedProtocol: nil))
        ws.send(JSValue(object: "héllo", in: context))
        #expect(ws.bufferedAmount == 6)
    }

    @Test("bufferedAmount increases by UTF-8 byte count for emoji string")
    func bufferedAmountEmojiString() {
        let ws = makeWebSocket()!
        ws.handleEvent(.open(negotiatedProtocol: nil))
        ws.send(JSValue(object: "😀", in: context))
        #expect(ws.bufferedAmount == 4)
    }

    @Test("bufferedAmount increases by byteLength for Uint8Array")
    func bufferedAmountUint8Array() {
        let ws = makeWebSocket()!
        ws.handleEvent(.open(negotiatedProtocol: nil))
        ws.send(context.evaluateScript("new Uint8Array([1, 2, 3])")!)
        #expect(ws.bufferedAmount == 3)
    }

    @Test("bufferedAmount increases by byteLength for Uint16Array")
    func bufferedAmountUint16Array() {
        let ws = makeWebSocket()!
        ws.handleEvent(.open(negotiatedProtocol: nil))
        ws.send(context.evaluateScript("new Uint16Array([1, 2])")!)
        #expect(ws.bufferedAmount == 4)
    }

    @Test("bufferedAmount increases by byteLength for Uint32Array")
    func bufferedAmountUint32Array() {
        let ws = makeWebSocket()!
        ws.handleEvent(.open(negotiatedProtocol: nil))
        ws.send(context.evaluateScript("new Uint32Array([1])")!)
        #expect(ws.bufferedAmount == 4)
    }

    @Test("bufferedAmount increases by byteLength for Float64Array")
    func bufferedAmountFloat64Array() {
        let ws = makeWebSocket()!
        ws.handleEvent(.open(negotiatedProtocol: nil))
        ws.send(context.evaluateScript("new Float64Array([1.0, 2.0])")!)
        #expect(ws.bufferedAmount == 16)
    }

    @Test("bufferedAmount increases by byteLength for ArrayBuffer")
    func bufferedAmountArrayBuffer() {
        let ws = makeWebSocket()!
        ws.handleEvent(.open(negotiatedProtocol: nil))
        ws.send(context.evaluateScript("new ArrayBuffer(10)")!)
        #expect(ws.bufferedAmount == 10)
    }

    @Test("bufferedAmount increases by byteLength for DataView")
    func bufferedAmountDataView() {
        let ws = makeWebSocket()!
        ws.handleEvent(.open(negotiatedProtocol: nil))
        ws.send(context.evaluateScript("new DataView(new ArrayBuffer(8), 2, 4)")!)
        #expect(ws.bufferedAmount == 4)
    }

    @Test("bufferedAmount increases by blob size")
    func bufferedAmountBlob() {
        let ws = makeWebSocket()!
        ws.handleEvent(.open(negotiatedProtocol: nil))
        ws.send(context.evaluateScript("new Blob(['hello world'])")!)
        #expect(ws.bufferedAmount == 11)
    }

    @Test("bufferedAmount increases by byteLength for TypedArray subarray")
    func bufferedAmountTypedArraySubarray() {
        let ws = makeWebSocket()!
        ws.handleEvent(.open(negotiatedProtocol: nil))
        ws.send(context.evaluateScript("new Uint16Array([1, 2, 3, 4]).subarray(1, 3)")!)
        #expect(ws.bufferedAmount == 4)
    }

    @Test("bufferedAmount accumulates across multiple sends")
    func bufferedAmountAccumulates() {
        let ws = makeWebSocket()!
        ws.handleEvent(.open(negotiatedProtocol: nil))
        ws.send(JSValue(object: "abc", in: context))
        ws.send(context.evaluateScript("new Uint8Array([1, 2])")!)
        #expect(ws.bufferedAmount == 5)
    }

    @Test("bufferedAmount decreases after send completes")
    func bufferedAmountDecreasesAfterSend() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        ws.send(JSValue(object: "hello", in: context))
        #expect(ws.bufferedAmount == 5)

        _ = await sent
        #expect(ws.bufferedAmount == 0)
    }

    @Test("bufferedAmount increases but does not decrease when closing")
    func bufferedAmountWhenClosing() {
        let ws = makeWebSocket()!
        ws.handleEvent(.open(negotiatedProtocol: nil))
        ws.close(JSValue(int32: 1000, in: context), JSValue(object: "", in: context))
        ws.send(JSValue(object: "hello", in: context))
        #expect(ws.bufferedAmount == 5)
    }

    @Test("bufferedAmount increases but does not decrease when closed")
    func bufferedAmountWhenClosed() {
        let ws = makeWebSocket()!
        ws.handleEvent(.open(negotiatedProtocol: nil))
        ws.handleEvent(.close(code: 1000, reason: "", wasClean: true))
        ws.send(JSValue(object: "test", in: context))
        #expect(ws.bufferedAmount == 4)
    }

    @Test("bufferedAmount unchanged when CONNECTING throws")
    func bufferedAmountUnchangedWhenConnecting() {
        let ws = makeWebSocket()!
        ws.send(JSValue(object: "hello", in: context))
        #expect(ws.bufferedAmount == 0)
    }

    @Test("Receive multiple binary messages preserves order and data")
    func receiveMultipleBinaryMessages() {
        let ws = makeWebSocket()!
        ws.binaryType = "arraybuffer"
        ws.handleEvent(.open(negotiatedProtocol: nil))

        context.evaluateScript("var messages = [];")
        ws.onmessage = context.evaluateScript("""
            (function(e) {
                var view = new Uint8Array(e.data);
                var arr = [];
                for (var i = 0; i < view.length; i++) arr.push(view[i]);
                messages.push(arr);
            })
        """)

        ws.handleEvent(.message(.binary(Data([1, 2]))))
        ws.handleEvent(.message(.binary(Data([3, 4, 5]))))
        ws.handleEvent(.message(.binary(Data([6]))))

        #expect(context.evaluateScript("messages.length").toInt32() == 3)
        #expect(context.evaluateScript("messages[0].length").toInt32() == 2)
        #expect(context.evaluateScript("messages[0][0]").toInt32() == 1)
        #expect(context.evaluateScript("messages[0][1]").toInt32() == 2)
        #expect(context.evaluateScript("messages[1].length").toInt32() == 3)
        #expect(context.evaluateScript("messages[1][0]").toInt32() == 3)
        #expect(context.evaluateScript("messages[2][0]").toInt32() == 6)
    }

    @Test("Mixed text and binary messages dispatch correctly")
    func mixedTextAndBinaryMessages() {
        let ws = makeWebSocket()!
        ws.binaryType = "arraybuffer"
        ws.handleEvent(.open(negotiatedProtocol: nil))

        context.evaluateScript("var results = [];")
        ws.onmessage = context.evaluateScript("""
            (function(e) {
                if (typeof e.data === 'string') {
                    results.push('text:' + e.data);
                } else {
                    results.push('binary:' + new Uint8Array(e.data).length);
                }
            })
        """)

        ws.handleEvent(.message(.text("hello")))
        ws.handleEvent(.message(.binary(Data([1, 2, 3]))))
        ws.handleEvent(.message(.text("world")))

        #expect(context.evaluateScript("results[0]").toString() == "text:hello")
        #expect(context.evaluateScript("results[1]").toString() == "binary:3")
        #expect(context.evaluateScript("results[2]").toString() == "text:world")
    }

    // MARK: - Close via send

    @Test("Close dispatches to mock task with code and reason")
    func closeDispatchesToTask() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareClose()
        async let closed = mockTask.awaitClose()
        ws.close(JSValue(int32: 1001, in: context), JSValue(object: "going away", in: context))
        let call = await closed

        #expect(call.code == .goingAway)
        let reason = call.reason.flatMap { String(data: $0, encoding: .utf8) }
        #expect(reason == "going away")
    }

    @Test("Close sets readyState to closing")
    func closeSetsClosingState() {
        let ws = makeWebSocket()!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        ws.close(JSValue(int32: 1000, in: context), JSValue(object: "", in: context))

        #expect(ws._readyState == .closing)
    }

    // MARK: - extractBytes (direct)

    @Test("extractBytes returns data from Uint8Array")
    func extractBytesUint8Array() async {
        let ws = makeWebSocket()!
        let value = context.evaluateScript("new Uint8Array([5, 10, 15])")!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result == Data([5, 10, 15]))
    }

    @Test("extractBytes returns data from ArrayBuffer")
    func extractBytesArrayBuffer() async {
        let ws = makeWebSocket()!
        let value = context.evaluateScript("""
            (function() {
                var buf = new ArrayBuffer(4);
                var v = new Uint8Array(buf);
                v[0] = 0xDE; v[1] = 0xAD; v[2] = 0xBE; v[3] = 0xEF;
                return buf;
            })()
        """)!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result == Data([0xDE, 0xAD, 0xBE, 0xEF]))
    }

    @Test("extractBytes returns empty data from empty Uint8Array")
    func extractBytesEmptyUint8Array() async {
        let ws = makeWebSocket()!
        let value = context.evaluateScript("new Uint8Array([])")!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result == Data())
    }

    @Test("extractBytes returns nil for null")
    func extractBytesNull() async {
        let ws = makeWebSocket()!
        let value = JSValue(nullIn: context)!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result == nil)
    }

    @Test("extractBytes returns nil for undefined")
    func extractBytesUndefined() async {
        let ws = makeWebSocket()!
        let value = JSValue(undefinedIn: context)!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result == nil)
    }

    @Test("extractBytes returns empty data for plain object")
    func extractBytesPlainObject() async {
        let ws = makeWebSocket()!
        let value = context.evaluateScript("({})")!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result == Data())
    }

    @Test("extractBytes returns data from JS array")
    func extractBytesJSArray() async {
        let ws = makeWebSocket()!
        let value = context.evaluateScript("[1, 2, 3, 4]")!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result == Data([1, 2, 3, 4]))
    }

    @Test("extractBytes returns data from Int8Array with negative values")
    func extractBytesInt8ArrayNegatives() async {
        let ws = makeWebSocket()!
        let value = context.evaluateScript("new Int8Array([-1, -128, 0, 127])")!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result == Data([255, 128, 0, 127]))
    }

    @Test("extractBytes returns data from Float64Array")
    func extractBytesFloat64Array() async {
        let ws = makeWebSocket()!
        let value = context.evaluateScript("new Float64Array([1.9, 0.0, 255.1])")!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result?.count == 24)
    }

    @Test("extractBytes returns data from Uint8ClampedArray")
    func extractBytesUint8ClampedArray() async {
        let ws = makeWebSocket()!
        let value = context.evaluateScript("new Uint8ClampedArray([0, 128, 255, 300, -5])")!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result == Data([0, 128, 255, 255, 0]))
    }

    @Test("extractBytes reads Uint16Array raw buffer bytes")
    func extractBytesUint16Array() async {
        let ws = makeWebSocket()!
        let value = context.evaluateScript("new Uint16Array([256, 512, 0, 1])")!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result?.count == 8)
    }

    @Test("extractBytes reads Uint32Array raw buffer bytes")
    func extractBytesUint32Array() async {
        let ws = makeWebSocket()!
        let value = context.evaluateScript("new Uint32Array([65536, 255, 0])")!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result?.count == 12)
    }

    @Test("extractBytes handles Float32Array with NaN and Infinity")
    func extractBytesFloat32ArraySpecialValues() async {
        let ws = makeWebSocket()!
        let value = context.evaluateScript("new Float32Array([NaN, Infinity, -Infinity])")!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result?.count == 12)
    }

    @Test("extractBytes returns data from Uint8Array subarray")
    func extractBytesSubarray() async {
        let ws = makeWebSocket()!
        let value = context.evaluateScript("new Uint8Array([10, 20, 30, 40, 50]).subarray(1, 4)")!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result == Data([20, 30, 40]))
    }

    @Test("extractBytes returns correct data from Uint16Array subarray")
    func extractBytesUint16ArraySubarray() async {
        let ws = makeWebSocket()!
        let value = context.evaluateScript("new Uint16Array([1, 2, 3, 4]).subarray(1, 3)")!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result?.count == 4)
        #expect(result == Data([2, 0, 3, 0]))
    }

    @Test("extractBytes returns correct data from Uint32Array subarray")
    func extractBytesUint32ArraySubarray() async {
        let ws = makeWebSocket()!
        let value = context.evaluateScript("new Uint32Array([1, 2, 3]).subarray(0, 2)")!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result?.count == 8)
    }

    @Test("extractBytes returns correct data from Float64Array subarray")
    func extractBytesFloat64ArraySubarray() async {
        let ws = makeWebSocket()!
        let value = context.evaluateScript("new Float64Array([1.0, 2.0, 3.0]).subarray(1, 2)")!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result?.count == 8)
    }

    @Test("extractBytes returns data from ArrayBuffer slice")
    func extractBytesArrayBufferSlice() async {
        let ws = makeWebSocket()!
        let value = context.evaluateScript("""
            (function() {
                var buf = new ArrayBuffer(5);
                var v = new Uint8Array(buf);
                v[0] = 10; v[1] = 20; v[2] = 30; v[3] = 40; v[4] = 50;
                return buf.slice(2, 5);
            })()
        """)!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result == Data([30, 40, 50]))
    }

    @Test("extractBytes returns data from number value")
    func extractBytesNumber() async {
        let ws = makeWebSocket()!
        let value = JSValue(int32: 3, in: context)!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result == Data([0, 0, 0]))
    }

    @Test("extractBytes returns single zero byte from boolean true")
    func extractBytesBooleanTrue() async {
        let ws = makeWebSocket()!
        let value = JSValue(bool: true, in: context)!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result == Data([0]))
    }

    @Test("extractBytes returns empty data from boolean false")
    func extractBytesBooleanFalse() async {
        let ws = makeWebSocket()!
        let value = JSValue(bool: false, in: context)!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result == Data())
    }

    @Test("extractBytes returns empty data for string value")
    func extractBytesString() async {
        let ws = makeWebSocket()!
        let value = JSValue(object: "hello", in: context)!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result == Data())
    }

    @Test("extractBytes preserves all 256 byte values")
    func extractBytesAll256Values() async {
        let ws = makeWebSocket()!
        let value = context.evaluateScript("""
            (function() {
                var arr = new Uint8Array(256);
                for (var i = 0; i < 256; i++) arr[i] = i;
                return arr;
            })()
        """)!
        let result = await ws.extractBytes(from: value, in: context)
        let expected = Data((0...255).map { UInt8($0) })
        #expect(result == expected)
    }

    @Test("extractBytes handles large typed array")
    func extractBytesLargeArray() async {
        let ws = makeWebSocket()!
        let value = context.evaluateScript("""
            (function() {
                var arr = new Uint8Array(1024);
                for (var i = 0; i < 1024; i++) arr[i] = i % 256;
                return arr;
            })()
        """)!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result?.count == 1024)
        for i in 0..<1024 {
            #expect(result?[i] == UInt8(i % 256))
        }
    }

    @Test("extractBytes returns data from mixed-type JS array")
    func extractBytesMixedJSArray() async {
        let ws = makeWebSocket()!
        let value = context.evaluateScript("[1, 2.7, 255, 0, -1]")!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result == Data([1, 2, 255, 0, 255]))
    }

    @Test("extractBytes returns single byte from single-element array")
    func extractBytesSingleElement() async {
        let ws = makeWebSocket()!
        let value = context.evaluateScript("new Uint8Array([42])")!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result == Data([42]))
    }

    @Test("extractBytes returns data from typed array created from another typed array")
    func extractBytesDerivedTypedArray() async {
        let ws = makeWebSocket()!
        let value = context.evaluateScript("new Uint8Array(new Uint16Array([1, 2, 256, 512]))")!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result == Data([1, 2, 0, 0]))
    }

    @Test("extractBytes with zero-length ArrayBuffer returns empty data")
    func extractBytesEmptyArrayBuffer() async {
        let ws = makeWebSocket()!
        let value = context.evaluateScript("new ArrayBuffer(0)")!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result == Data())
    }

    @Test("extractBytes returns data from DataView")
    func extractBytesDataView() async {
        let ws = makeWebSocket()!
        let value = context.evaluateScript("""
            (function() {
                var buf = new ArrayBuffer(3);
                var dv = new DataView(buf);
                dv.setUint8(0, 0xAA);
                dv.setUint8(1, 0xBB);
                dv.setUint8(2, 0xCC);
                return dv;
            })()
        """)!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result == Data([0xAA, 0xBB, 0xCC]))
    }

    @Test("extractBytes returns data from DataView with offset")
    func extractBytesDataViewWithOffset() async {
        let ws = makeWebSocket()!
        let value = context.evaluateScript("""
            (function() {
                var buf = new ArrayBuffer(6);
                var v = new Uint8Array(buf);
                v[0] = 1; v[1] = 2; v[2] = 3; v[3] = 4; v[4] = 5; v[5] = 6;
                return new DataView(buf, 2, 3);
            })()
        """)!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result == Data([3, 4, 5]))
    }

    @Test("extractBytes returns empty data from empty DataView")
    func extractBytesEmptyDataView() async {
        let ws = makeWebSocket()!
        let value = context.evaluateScript("new DataView(new ArrayBuffer(0))")!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result == Data())
    }

    // MARK: - extractBytes with Blob

    @Test("extractBytes returns UTF-8 bytes for Blob with text content")
    func extractBytesBlob() async {
        let ws = makeWebSocket()!
        let blob = JSBlob(storage: "hello", type: MIMEType(rawValue: "text/plain"))
        let value = JSValue(object: blob, in: context)!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result == Data([104, 101, 108, 108, 111]))
    }

    @Test("extractBytes returns empty data for empty Blob")
    func extractBytesEmptyBlob() async {
        let ws = makeWebSocket()!
        let blob = JSBlob(storage: "", type: MIMEType(rawValue: ""))
        let value = JSValue(object: blob, in: context)!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result == Data())
    }

    @Test("extractBytes returns UTF-8 bytes for Blob with octet-stream type")
    func extractBytesBlobOctetStream() async {
        let ws = makeWebSocket()!
        let blob = JSBlob(storage: "abc", type: MIMEType(rawValue: "application/octet-stream"))
        let value = JSValue(object: blob, in: context)!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result == Data([97, 98, 99]))
    }

    @Test("extractBytes returns UTF-8 bytes for single-char Blob")
    func extractBytesBlobSingleChar() async {
        let ws = makeWebSocket()!
        let blob = JSBlob(storage: "x", type: MIMEType(rawValue: "text/plain"))
        let value = JSValue(object: blob, in: context)!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result == Data([120]))
    }

    @Test("extractBytes returns UTF-8 bytes for large Blob")
    func extractBytesLargeBlob() async {
        let ws = makeWebSocket()!
        let content = String(repeating: "a", count: 256)
        let blob = JSBlob(storage: content, type: MIMEType(rawValue: "text/plain"))
        let value = JSValue(object: blob, in: context)!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result == Data(repeating: 97, count: 256))
    }

    @Test("extractBytes returns UTF-8 bytes for Blob created via JS constructor")
    func extractBytesBlobFromJS() async {
        let ws = makeWebSocket()!
        let value = context.evaluateScript("new Blob(['test data'])")!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result == Data(Array("test data".utf8)))
    }

    @Test("extractBytes returns UTF-8 bytes for Blob with multi-byte UTF8 content")
    func extractBytesBlobMultiByteUTF8() async {
        let ws = makeWebSocket()!
        let blob = JSBlob(storage: "héllo", type: MIMEType(rawValue: "text/plain"))
        let value = JSValue(object: blob, in: context)!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result == Data(Array("héllo".utf8)))
    }

    @Test("extractBytes returns UTF-8 bytes for Blob with emoji content")
    func extractBytesBlobEmoji() async {
        let ws = makeWebSocket()!
        let blob = JSBlob(storage: "😀", type: MIMEType(rawValue: "text/plain"))
        let value = JSValue(object: blob, in: context)!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result == Data(Array("😀".utf8)))
    }

    @Test("extractBytes returns UTF-8 bytes for sliced Blob from JS")
    func extractBytesBlobSliced() async {
        let ws = makeWebSocket()!
        let value = context.evaluateScript("new Blob(['hello world']).slice(0, 5)")!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result == Data(Array("hello".utf8)))
    }

    @Test("extractBytes returns UTF-8 bytes for multi-part Blob from JS")
    func extractBytesBlobMultiPart() async {
        let ws = makeWebSocket()!
        let value = context.evaluateScript("new Blob(['hello', ' ', 'world'])")!
        let result = await ws.extractBytes(from: value, in: context)
        #expect(result == Data(Array("hello world".utf8)))
    }

    // MARK: - Send with Blob

    @Test("Send Blob sends UTF-8 content bytes")
    func sendBlob() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        let blob = JSBlob(storage: "hello", type: MIMEType(rawValue: "text/plain"))
        ws.send(JSValue(object: blob, in: context))
        let messages = await sent

        #expect(messages.count == 1)
        if case .data(let data) = messages.first {
            #expect(Array(data) == [104, 101, 108, 108, 111])
        } else {
            Issue.record("Expected data message from Blob")
        }
    }

    @Test("Send empty Blob sends empty data")
    func sendEmptyBlob() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        let blob = JSBlob(storage: "", type: MIMEType(rawValue: ""))
        ws.send(JSValue(object: blob, in: context))
        let messages = await sent

        #expect(messages.count == 1)
        if case .data(let data) = messages.first {
            #expect(data.isEmpty)
        } else {
            Issue.record("Expected data message from empty Blob")
        }
    }

    @Test("Send Blob created via JS constructor sends content bytes")
    func sendBlobFromJS() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        let blob = context.evaluateScript("new Blob(['abc'])")!
        ws.send(blob)
        let messages = await sent

        #expect(messages.count == 1)
        if case .data(let data) = messages.first {
            #expect(Array(data) == [97, 98, 99])
        } else {
            Issue.record("Expected data message from JS Blob")
        }
    }

    @Test("Send sliced Blob sends sliced content bytes")
    func sendSlicedBlob() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        let blob = context.evaluateScript("new Blob(['hello world']).slice(0, 5)")!
        ws.send(blob)
        let messages = await sent

        #expect(messages.count == 1)
        if case .data(let data) = messages.first {
            #expect(data == Data(Array("hello".utf8)))
        } else {
            Issue.record("Expected data message from sliced Blob")
        }
    }

    @Test("Send large Blob sends all content bytes")
    func sendLargeBlob() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        let content = String(repeating: "z", count: 512)
        let blob = JSBlob(storage: content, type: MIMEType(rawValue: "text/plain"))
        ws.send(JSValue(object: blob, in: context))
        let messages = await sent

        #expect(messages.count == 1)
        if case .data(let data) = messages.first {
            #expect(data == Data(repeating: 122, count: 512))
        } else {
            Issue.record("Expected data message from large Blob")
        }
    }

    @Test("Send multi-part Blob sends combined content bytes")
    func sendMultiPartBlob() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        let blob = context.evaluateScript("new Blob(['hello', ' ', 'world'])")!
        ws.send(blob)
        let messages = await sent

        #expect(messages.count == 1)
        if case .data(let data) = messages.first {
            #expect(data == Data(Array("hello world".utf8)))
        } else {
            Issue.record("Expected data message from multi-part Blob")
        }
    }

    @Test("Send Blob with multi-byte UTF8 sends correct bytes")
    func sendBlobMultiByteUTF8() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        let blob = JSBlob(storage: "héllo", type: MIMEType(rawValue: "text/plain"))
        ws.send(JSValue(object: blob, in: context))
        let messages = await sent

        #expect(messages.count == 1)
        if case .data(let data) = messages.first {
            #expect(data == Data(Array("héllo".utf8)))
        } else {
            Issue.record("Expected data message from multi-byte Blob")
        }
    }

    @Test("Send Blob with emoji sends correct bytes")
    func sendBlobEmoji() async {
        let mockTask = MockJSWebSocketTask()
        let ws = makeWebSocket(task: mockTask)!
        ws.handleEvent(.open(negotiatedProtocol: nil))

        mockTask.prepareSend()
        async let sent = mockTask.awaitSend(count: 1)
        let blob = JSBlob(storage: "😀", type: MIMEType(rawValue: "text/plain"))
        ws.send(JSValue(object: blob, in: context))
        let messages = await sent

        #expect(messages.count == 1)
        if case .data(let data) = messages.first {
            #expect(data == Data(Array("😀".utf8)))
        } else {
            Issue.record("Expected data message from emoji Blob")
        }
    }
}
