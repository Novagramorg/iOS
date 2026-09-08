import Foundation
import WebKit

enum WebProxyPageMessage {
    case binary(Data)
    case control(String)
}

final class WebProxyWebViewCarrier: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    let nonce: String

    /// The view the transport hands to its `WebProxyCarrierViewHost`.
    var hostedWebView: WKWebView {
        return self.webView
    }

    private let configuration: WebProxyConfiguration
    private let generation: UInt64
    private let handlerName: String
    private let bridgeURL: URL
    private let received: (UInt64, WebProxyPageMessage) -> Void
    private let failed: (UInt64, WebProxyCarrierFailure) -> Void
    private let webView: WKWebView
    private var initialNavigation = true
    private var invalidated = false
    private var pendingSends: [Data] = []
    private var pendingSendBytes = 0
    private var evaluatingSend = false
    /// The bridge routes the first ArrayBuffer to `createSession`, which must carry
    /// the lone HELLO frame, so the first message is never batched.
    private var hasSentFirstMessage = false

    init?(
        configuration: WebProxyConfiguration,
        generation: UInt64,
        received: @escaping (UInt64, WebProxyPageMessage) -> Void,
        failed: @escaping (UInt64, WebProxyCarrierFailure) -> Void
    ) {
        var nonceData = Data(count: 32)
        let randomResult = nonceData.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, bytes.count, bytes.baseAddress!)
        }
        guard randomResult == errSecSuccess else { return nil }
        let nonce = nonceData.webProxyBase64Url
        guard let bridgeURL = configuration.bridgeURL(nonce: nonce) else { return nil }

        self.configuration = configuration
        self.generation = generation
        self.handlerName = "telegramWebProxy_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        self.nonce = nonce
        self.bridgeURL = bridgeURL
        self.received = received
        self.failed = failed

        let contentController = WKUserContentController()
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.websiteDataStore = .nonPersistent()
        webConfiguration.userContentController = contentController
        webConfiguration.preferences.javaScriptCanOpenWindowsAutomatically = false

        self.webView = WKWebView(frame: .zero, configuration: webConfiguration)
        super.init()

        if #available(macOS 11.0, iOS 14.0, *) {
            let script = WKUserScript(
                source: Self.injectionScript(handlerName: self.handlerName, nonce: nonce),
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true,
                in: .page
            )
            contentController.addUserScript(script)
            contentController.add(self, contentWorld: .page, name: self.handlerName)
        } else {
            let script = WKUserScript(
                source: Self.injectionScript(handlerName: self.handlerName, nonce: nonce),
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
            contentController.addUserScript(script)
            contentController.add(self, name: self.handlerName)
        }
        self.webView.navigationDelegate = self
        self.webView.uiDelegate = self
    }

    func start() {
        guard !self.invalidated else { return }
        WebProxyDiagnostics.info("webview load started")
        self.webView.load(URLRequest(url: self.bridgeURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 20.0))
    }

    func invalidate() {
        guard !self.invalidated else { return }
        self.invalidated = true
        self.webView.stopLoading()
        self.webView.navigationDelegate = nil
        self.webView.uiDelegate = nil
        if #available(macOS 11.0, iOS 14.0, *) {
            self.webView.configuration.userContentController.removeScriptMessageHandler(forName: self.handlerName, contentWorld: .page)
        } else {
            self.webView.configuration.userContentController.removeScriptMessageHandler(forName: self.handlerName)
        }
        self.webView.configuration.userContentController.removeAllUserScripts()
        self.pendingSends.removeAll()
        self.pendingSendBytes = 0
        self.evaluatingSend = false
        self.hasSentFirstMessage = false
    }

    func send(data: Data) {
        guard !self.invalidated else { return }
        guard self.pendingSends.count < WebProxyProtocol.maximumQueuedItems,
              self.pendingSendBytes <= WebProxyProtocol.maximumQueuedBytes - data.count else {
            self.failed(self.generation, .bridgeEvaluationFailed)
            return
        }
        self.pendingSends.append(data)
        self.pendingSendBytes += data.count
        self.flushSendQueue()
    }

    private func flushSendQueue() {
        guard !self.invalidated, !self.evaluatingSend, !self.pendingSends.isEmpty else { return }
        let count = WebProxySendBatcher.batchCount(
            pending: self.pendingSends,
            isFirstMessage: !self.hasSentFirstMessage,
            maximumFrames: WebProxyProtocol.maximumBatchFrames,
            maximumBytes: WebProxyProtocol.defaultBatchSize
        )
        guard count > 0 else { return }
        self.evaluatingSend = true

        // Concatenating here is what makes the batch worth it: the bridge walks frame
        // boundaries itself, so one message carries many frames and costs one round trip.
        var batch = Data()
        var batchBytes = 0
        for frame in self.pendingSends.prefix(count) {
            batch.append(frame)
            batchBytes += frame.count
        }
        let base64 = batch.base64EncodedString()

        let completion: (Bool?, Error?) -> Void = { [weak self] value, error in
            guard let self, !self.invalidated else { return }
            if error != nil {
                self.failed(self.generation, .bridgeEvaluationFailed)
                return
            }
            guard value == true else {
                self.failed(self.generation, .bridgeUnavailable)
                return
            }
            self.pendingSends.removeFirst(count)
            self.pendingSendBytes -= batchBytes
            self.hasSentFirstMessage = true
            self.evaluatingSend = false
            self.flushSendQueue()
        }

        if #available(macOS 11.0, iOS 14.0, *) {
            // The payload travels as an argument, not interpolated into source: the
            // function body is constant so WebKit compiles it once instead of parsing
            // a fresh multi-kilobyte script per batch, and nothing needs escaping.
            self.webView.callAsyncJavaScript(
                Self.deliverFunctionBody,
                arguments: ["payload": base64],
                in: nil,
                in: .page
            ) { result in
                switch result {
                case let .success(value):
                    completion(value as? Bool, nil)
                case let .failure(error):
                    completion(nil, error)
                }
            }
        } else {
            let script = """
            (() => {
              const payload = \(Self.javaScriptString(base64));
              \(Self.deliverFunctionBody)
            })()
            """
            self.webView.evaluateJavaScript(script) { value, error in
                completion(value as? Bool, error)
            }
        }
    }

    /// Body of the delivery function. Constant so it compiles once; the batch arrives
    /// as the `payload` argument.
    private static let deliverFunctionBody = """
    const bridge = globalThis.TelegramWebProxy;
    if (!bridge || typeof bridge.onmessage !== 'function') return false;
    let bytes;
    if (typeof Uint8Array.fromBase64 === 'function') {
      bytes = Uint8Array.fromBase64(payload);
    } else {
      const raw = atob(payload);
      bytes = new Uint8Array(raw.length);
      for (let i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
    }
    const buffer = bytes.byteOffset === 0 && bytes.byteLength === bytes.buffer.byteLength ? bytes.buffer : bytes.slice().buffer;
    bridge.onmessage({data: buffer});
    return true;
    """

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard !self.invalidated,
              message.name == self.handlerName,
              message.frameInfo.isMainFrame,
              message.frameInfo.securityOrigin.protocol == "https",
              message.frameInfo.securityOrigin.host.lowercased() == self.configuration.host,
              message.frameInfo.securityOrigin.port == 0 || message.frameInfo.securityOrigin.port == 443,
              self.isAllowed(url: self.webView.url),
              let body = message.body as? [String: Any],
              body["nonce"] as? String == self.nonce,
              let kind = body["kind"] as? String,
              let value = body["data"] as? String else {
            self.failed(self.generation, .bridgeMessageRejected)
            return
        }
        if kind == "binary", let data = Data(base64Encoded: value), data.count <= WebProxyProtocol.defaultBatchSize {
            self.received(self.generation, .binary(data))
        } else if kind == "control", value.utf8.count <= 4096 {
            self.received(self.generation, .control(value))
        } else {
            self.failed(self.generation, .bridgeMessageRejected)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard !self.invalidated,
              navigationAction.targetFrame?.isMainFrame == true,
              self.initialNavigation,
              self.isAllowed(url: navigationAction.request.url) else {
            decisionHandler(.cancel)
            if !self.invalidated { self.failed(self.generation, .navigationRejected) }
            return
        }
        self.initialNavigation = false
        WebProxyDiagnostics.info("initial navigation accepted")
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        let httpResponse = navigationResponse.response as? HTTPURLResponse
        guard !self.invalidated,
              navigationResponse.isForMainFrame,
              self.isAllowed(url: navigationResponse.response.url),
              let response = httpResponse,
              response.statusCode == 200,
              response.mimeType == "text/html" else {
            decisionHandler(.cancel)
            if !self.invalidated {
                WebProxyDiagnostics.rejectedResponse(statusCode: httpResponse?.statusCode, mimeType: navigationResponse.response.mimeType)
                self.failed(self.generation, .responseRejected)
            }
            return
        }
        WebProxyDiagnostics.info("bridge response accepted")
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if !self.invalidated {
            WebProxyDiagnostics.navigationFailure(error)
            self.failed(self.generation, .navigationFailed)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if !self.invalidated {
            WebProxyDiagnostics.info("bridge document loaded")
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if !self.invalidated {
            WebProxyDiagnostics.navigationFailure(error)
            self.failed(self.generation, .navigationFailed)
        }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        if !self.invalidated { self.failed(self.generation, .webContentProcessTerminated) }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        return nil
    }

    private func isAllowed(url: URL?) -> Bool {
        guard let url,
              url.scheme?.lowercased() == "https",
              url.host?.lowercased() == self.configuration.host,
              url.port == nil || url.port == 443,
              url.path == "/" else { return false }
        return true
    }

    private static func injectionScript(handlerName: String, nonce: String) -> String {
        return """
        (() => {
          'use strict';
          const native = globalThis.webkit.messageHandlers[\(javaScriptString(handlerName))];
          const nonce = \(javaScriptString(nonce));
          const bridge = {onmessage: null};
          Object.defineProperty(bridge, 'postMessage', {value: value => {
            if (typeof value === 'string') {
              native.postMessage({kind: 'control', nonce, data: value});
              return;
            }
            let bytes;
            if (value instanceof ArrayBuffer) bytes = new Uint8Array(value);
            else if (ArrayBuffer.isView(value)) bytes = new Uint8Array(value.buffer, value.byteOffset, value.byteLength);
            else throw new TypeError('TelegramWebProxy accepts strings or binary data');
            let binary = '';
            const chunk = 0x8000;
            for (let i = 0; i < bytes.length; i += chunk) {
              binary += String.fromCharCode(...bytes.subarray(i, Math.min(i + chunk, bytes.length)));
            }
            native.postMessage({kind: 'binary', nonce, data: btoa(binary)});
          }, enumerable: true});
          Object.seal(bridge);
          Object.defineProperty(globalThis, 'TelegramWebProxy', {value: bridge, configurable: false, writable: false});
        })();
        """
    }

    private static func javaScriptString(_ value: String) -> String {
        let data = try! JSONSerialization.data(withJSONObject: [value])
        let array = String(data: data, encoding: .utf8)!
        return String(array.dropFirst().dropLast())
    }
}
