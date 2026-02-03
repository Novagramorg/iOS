import WebKit

protocol ServiceWorkerContextDelegate: AnyObject {
    func serviceWorkerContext(_ context: ServiceWorkerContext, didReceiveFetchResponse response: [String: Any], forRequestId requestId: String)
    func serviceWorkerContext(_ context: ServiceWorkerContext, requestPassthroughForRequestId requestId: String)
}

class ServiceWorkerContext: NSObject {
    private var webView: WKWebView!
    private let registration: ServiceWorkerRegistration
    private let origin: String  // Cached for synchronous access
    private weak var pageWebView: WKWebView?  // Page WebView for state updates
    private let scope: String
    weak var delegate: ServiceWorkerContextDelegate?

    private var isReady = false
    private var pendingScript: String?
    private var loadedScriptHash: Int?  // Track loaded script to prevent duplicate execution
    private var pendingInstallCallback: ((Bool) -> Void)?
    private var pendingActivateCallback: ((Bool) -> Void)?

    init(registration: ServiceWorkerRegistration, origin: String, pageWebView: WKWebView? = nil, scope: String = "/") {
        self.registration = registration
        self.origin = origin
        self.pageWebView = pageWebView
        self.scope = scope
        super.init()

        setupWebView()
    }

    /// Notify the page WebView of SW state changes
    private func notifyStateChange(_ state: String) {
        let escapedScope = scope.replacingOccurrences(of: "'", with: "\\'")
        let js = "if (window.updateSWState) { window.updateSWState('\(escapedScope)', '\(state)'); }"
        pageWebView?.evaluateJavaScript(js, completionHandler: nil)
    }

    deinit {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "swBridge")
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.userContentController = WKUserContentController()

        // Add message handler
        config.userContentController.add(self, name: "swBridge")

        // Inject context shim
        let mainBundle = Bundle(for: PWAWebView.self)
        if let bundle = Bundle(path: mainBundle.bundlePath + "/WebWorkerShimBundle.bundle") {
            if let shimURL = bundle.url(forResource: "sw-context-shim", withExtension: "js"),
               let shimCode = try? String(contentsOf: shimURL, encoding: .utf8) {
                let script = WKUserScript(source: shimCode, injectionTime: .atDocumentStart, forMainFrameOnly: true)
                config.userContentController.addUserScript(script)
            }
        }

        webView = WKWebView(frame: .zero, configuration: config)
        webView.loadHTMLString("<!DOCTYPE html><html><head></head><body></body></html>", baseURL: nil)
    }

    func loadServiceWorkerScript(_ script: String) {
        let scriptHash = script.hashValue

        // Skip if same script is already loaded (prevents duplicate variable errors on page reload)
        if let existingHash = loadedScriptHash, existingHash == scriptHash {
            // Script already loaded - notify page of current state
            Task {
                let state = await registration.state
                if state == .activated {
                    await MainActor.run { self.notifyStateChange("activated") }
                }
            }
            return
        }

        // If a different script, we need to reset the WebView (SW update scenario)
        if loadedScriptHash != nil {
            resetWebView()
        }

        loadedScriptHash = scriptHash

        if isReady {
            executeScript(script)
        } else {
            pendingScript = script
        }
    }

    private func resetWebView() {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "swBridge")
        isReady = false
        pendingScript = nil
        setupWebView()
    }

    private func escapeForJS(_ string: String) -> String {
        // Wrap string in array since JSONSerialization requires array/dict as top-level
        guard let data = try? JSONSerialization.data(withJSONObject: [string], options: []),
              let jsonArray = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        // Remove the array brackets: ["string"] -> "string"
        let trimmed = jsonArray.dropFirst().dropLast()
        return String(trimmed)
    }

    private func executeScript(_ script: String) {
        // Notify page that SW is installing
        notifyStateChange("installing")

        Task {
            let scriptURL = await registration.scriptURL
            let realScriptURL = scriptURL.absoluteString  // Already a real https:// URL

            await MainActor.run {
                let escapedOrigin = self.escapeForJS(self.origin)
                let escapedScriptURL = self.escapeForJS(realScriptURL)
                let setOrigin = "window.setOrigin(\(escapedOrigin), \(escapedScriptURL));"
                self.webView.evaluateJavaScript(setOrigin) { [weak self] _, _ in
                    self?.webView.evaluateJavaScript(script) { [weak self] _, error in
                        if let error = error {
                            print("SW script error: \(error)")
                            return
                        }
                        self?.dispatchInstallEvent()
                    }
                }
            }
        }
    }

    private func dispatchInstallEvent() {
        // The JS function returns a Promise that resolves after all waitUntil promises complete.
        // We use a callback-based approach to properly wait for the Promise.
        let callbackId = "install_\(UUID().uuidString)"
        let js = """
        (function() {
            window.dispatchInstallEvent().then(function(success) {
                webkit.messageHandlers.swBridge.postMessage({
                    type: 'installComplete',
                    callbackId: '\(callbackId)',
                    success: success
                });
            }).catch(function(err) {
                webkit.messageHandlers.swBridge.postMessage({
                    type: 'installComplete',
                    callbackId: '\(callbackId)',
                    success: false,
                    error: err.message || String(err)
                });
            });
        })();
        """

        pendingInstallCallback = { [weak self] success in
            guard let self = self else { return }
            if success {
                Task {
                    await ServiceWorkerManager.shared.updateState(self.registration, to: .installed)
                    await MainActor.run {
                        self.notifyStateChange("installed")
                        self.dispatchActivateEvent()
                    }
                }
            } else {
                Task { await ServiceWorkerManager.shared.updateState(self.registration, to: .redundant) }
            }
        }

        webView.evaluateJavaScript(js) { [weak self] _, error in
            if let error = error {
                print("SW install event error: \(error)")
                self?.pendingInstallCallback?(false)
                self?.pendingInstallCallback = nil
            }
        }
    }

    private func dispatchActivateEvent() {
        // The JS function returns a Promise that resolves after all waitUntil promises complete.
        // We use a callback-based approach to properly wait for the Promise.
        let callbackId = "activate_\(UUID().uuidString)"
        let js = """
        (function() {
            window.dispatchActivateEvent().then(function(success) {
                webkit.messageHandlers.swBridge.postMessage({
                    type: 'activateComplete',
                    callbackId: '\(callbackId)',
                    success: success
                });
            }).catch(function(err) {
                webkit.messageHandlers.swBridge.postMessage({
                    type: 'activateComplete',
                    callbackId: '\(callbackId)',
                    success: false,
                    error: err.message || String(err)
                });
            });
        })();
        """

        pendingActivateCallback = { [weak self] success in
            guard let self = self else { return }
            if success {
                Task {
                    await ServiceWorkerManager.shared.updateState(self.registration, to: .activated)
                    await MainActor.run { self.notifyStateChange("activated") }
                }
            } else {
                Task { await ServiceWorkerManager.shared.updateState(self.registration, to: .redundant) }
            }
        }

        webView.evaluateJavaScript(js) { [weak self] _, error in
            if let error = error {
                print("SW activate event error: \(error)")
                self?.pendingActivateCallback?(false)
                self?.pendingActivateCallback = nil
            }
        }
    }

    func dispatchFetchEvent(requestId: String, url: String, method: String, headers: [String: String], body: Data?, options: [String: String]?) {
        let escapedRequestId = escapeForJS(requestId)
        let escapedUrl = escapeForJS(url)
        let escapedMethod = escapeForJS(method)
        let headersJSON = (try? JSONSerialization.data(withJSONObject: headers, options: []))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

        // Encode body as base64, or null if empty
        let bodyBase64: String
        if let body = body, !body.isEmpty {
            bodyBase64 = "\"\(body.base64EncodedString())\""
        } else {
            bodyBase64 = "null"
        }

        // Encode options as JSON, or null if empty
        let optionsJSON: String
        if let options = options, !options.isEmpty {
            optionsJSON = (try? JSONSerialization.data(withJSONObject: options, options: []))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "null"
        } else {
            optionsJSON = "null"
        }

        let js = "window.dispatchFetchEvent(\(escapedRequestId), \(escapedUrl), \(escapedMethod), \(headersJSON), \(bodyBase64), \(optionsJSON));"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
}

// MARK: - SW Fetch Handling

extension ServiceWorkerContext {
    func handleSWFetch(requestId: String, urlString: String, origin: String, method: String, headers: [String: String], body: Data?) {
        // Check for test host - serve from test bundle
        if let url = URL(string: urlString), url.host == "testpwa.local" {
            serveTestResource(requestId: requestId, url: url, method: method, body: body)
            return
        }

        // Fetch from network
        guard let url = URL(string: urlString) else {
            sendSWFetchError(requestId: requestId, error: "Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Mark as SW context request to prevent re-interception by PWAURLProtocol
        request.setValue("true", forHTTPHeaderField: "X-SW-Context")

        // Set request body if provided (for POST, PUT, etc.)
        if let body = body, !body.isEmpty {
            request.httpBody = body
        }

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.sendSWFetchError(requestId: requestId, error: error.localizedDescription)
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse,
                      let data = data else {
                    self?.sendSWFetchError(requestId: requestId, error: "Invalid response")
                    return
                }

                var responseHeaders: [String: String] = [:]
                httpResponse.allHeaderFields.forEach { key, value in
                    if let keyStr = key as? String, let valueStr = value as? String {
                        responseHeaders[keyStr] = valueStr
                    }
                }

                let responseDict: [String: Any] = [
                    "status": httpResponse.statusCode,
                    "statusText": HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode),
                    "headers": responseHeaders,
                    "bodyBase64": data.base64EncodedString()
                ]

                self?.sendSWFetchResponse(requestId: requestId, response: responseDict)
            }
        }.resume()
    }

    private func serveTestResource(requestId: String, url: URL, method: String = "GET", body: Data? = nil) {
        let path = url.path

        // Special endpoint: /echo-body - echoes the request body back as JSON
        if path == "/echo-body" || path.hasSuffix("/echo-body") {
            let bodyString = body.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            let responseJSON: [String: Any] = [
                "method": method,
                "bodyReceived": bodyString,
                "bodyLength": body?.count ?? 0
            ]
            guard let jsonData = try? JSONSerialization.data(withJSONObject: responseJSON, options: []) else {
                sendSWFetchError(requestId: requestId, error: "Failed to serialize echo response")
                return
            }
            let responseDict: [String: Any] = [
                "status": 200,
                "statusText": "OK",
                "headers": ["Content-Type": "application/json"],
                "bodyBase64": jsonData.base64EncodedString()
            ]
            sendSWFetchResponse(requestId: requestId, response: responseDict)
            return
        }

        let filename = (path as NSString).lastPathComponent
        let ext = (filename as NSString).pathExtension
        let name = (filename as NSString).deletingPathExtension

        let bundle = PWAURLProtocol.testResourceBundle ?? Bundle.main
        guard let fileURL = bundle.url(forResource: name, withExtension: ext),
              let data = try? Data(contentsOf: fileURL) else {
            sendSWFetchError(requestId: requestId, error: "Resource not found: \(filename)")
            return
        }

        let mimeType: String
        switch ext.lowercased() {
        case "html": mimeType = "text/html"
        case "js": mimeType = "application/javascript"
        case "json": mimeType = "application/json"
        case "css": mimeType = "text/css"
        default: mimeType = "application/octet-stream"
        }

        let responseDict: [String: Any] = [
            "status": 200,
            "statusText": "OK",
            "headers": ["Content-Type": mimeType],
            "bodyBase64": data.base64EncodedString()
        ]

        sendSWFetchResponse(requestId: requestId, response: responseDict)
    }

    private func sendSWFetchResponse(requestId: String, response: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: response, options: []),
              let responseJS = String(data: data, encoding: .utf8) else {
            sendSWFetchError(requestId: requestId, error: "Failed to serialize response")
            return
        }

        let js = "window.resolveSWFetchCallback('\(requestId)', \(responseJS), null);"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func sendSWFetchError(requestId: String, error: String) {
        let escapedError = error.replacingOccurrences(of: "'", with: "\\'")
        let js = "window.resolveSWFetchCallback('\(requestId)', null, '\(escapedError)');"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
}

extension ServiceWorkerContext: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }

        switch type {
        case "contextReady":
            isReady = true
            if let script = pendingScript {
                pendingScript = nil
                executeScript(script)
            }

        case "installComplete":
            let success = body["success"] as? Bool ?? false
            pendingInstallCallback?(success)
            pendingInstallCallback = nil

        case "activateComplete":
            let success = body["success"] as? Bool ?? false
            pendingActivateCallback?(success)
            pendingActivateCallback = nil

        case "fetchResponse":
            guard let requestId = body["requestId"] as? String else { return }

            // Route to PWAURLProtocol if this is a protocol request
            Task {
                if let urlProtocol = await ServiceWorkerManager.shared.getPendingRequest(requestId) {
                    await MainActor.run {
                        if body["passthrough"] as? Bool == true {
                            urlProtocol.handlePassthrough()
                        } else if let response = body["response"] as? [String: Any] {
                            urlProtocol.handleFetchResponse(response)
                        } else if body["error"] != nil {
                            urlProtocol.handlePassthrough()
                        }
                    }
                } else {
                    // Fallback to delegate (for backwards compatibility during migration)
                    await MainActor.run {
                        if body["passthrough"] as? Bool == true {
                            self.delegate?.serviceWorkerContext(self, requestPassthroughForRequestId: requestId)
                        } else if let response = body["response"] as? [String: Any] {
                            self.delegate?.serviceWorkerContext(self, didReceiveFetchResponse: response, forRequestId: requestId)
                        } else if body["error"] != nil {
                            self.delegate?.serviceWorkerContext(self, requestPassthroughForRequestId: requestId)
                        }
                    }
                }
            }

        case "cacheOpen":
            if let origin = body["origin"] as? String,
               let name = body["cacheName"] as? String {
                CacheStorage.shared.open(origin: origin, name: name)
            }

        case "cachePut":
            if let origin = body["origin"] as? String,
               let cacheName = body["cacheName"] as? String,
               let url = body["url"] as? String,
               let responseDict = body["response"] as? [String: Any] {
                let response = CachedResponse(
                    url: url,
                    status: responseDict["status"] as? Int ?? 200,
                    statusText: responseDict["statusText"] as? String ?? "OK",
                    headers: responseDict["headers"] as? [String: String] ?? [:],
                    body: Data(base64Encoded: responseDict["bodyBase64"] as? String ?? "") ?? Data()
                )
                CacheStorage.shared.put(origin: origin, cacheName: cacheName, url: url, response: response)
            }

        case "cacheMatch":
            if let callbackId = body["callbackId"] as? String,
               let origin = body["origin"] as? String,
               let url = body["url"] as? String {
                let cacheName = body["cacheName"] as? String
                let response = CacheStorage.shared.match(origin: origin, cacheName: cacheName, url: url)
                let responseJS: String
                if let r = response {
                    let dict = r.toDictionary()
                    let data = try? JSONSerialization.data(withJSONObject: dict, options: [])
                    responseJS = data.flatMap { String(data: $0, encoding: .utf8) } ?? "null"
                } else {
                    responseJS = "null"
                }
                webView.evaluateJavaScript("window.resolveCacheCallback('\(callbackId)', \(responseJS));", completionHandler: nil)
            }

        case "cacheEntryDelete":
            if let callbackId = body["callbackId"] as? String,
               let origin = body["origin"] as? String,
               let cacheName = body["cacheName"] as? String,
               let url = body["url"] as? String {
                let deleted = CacheStorage.shared.deleteEntry(origin: origin, cacheName: cacheName, url: url)
                webView.evaluateJavaScript("window.resolveCacheCallback('\(callbackId)', \(deleted));", completionHandler: nil)
            }

        case "cachesKeys":
            if let callbackId = body["callbackId"] as? String,
               let origin = body["origin"] as? String {
                let names = CacheStorage.shared.keys(origin: origin)
                let data = try? JSONSerialization.data(withJSONObject: names, options: [])
                let namesJS = data.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
                webView.evaluateJavaScript("window.resolveCacheCallback('\(callbackId)', \(namesJS));", completionHandler: nil)
            }

        case "cacheStorageDelete":
            // Handle both callback-based and fire-and-forget versions
            if let callbackId = body["callbackId"] as? String,
               let origin = body["origin"] as? String,
               let name = body["cacheName"] as? String {
                let deleted = CacheStorage.shared.delete(origin: origin, name: name)
                webView.evaluateJavaScript("window.resolveCacheCallback('\(callbackId)', \(deleted));", completionHandler: nil)
            } else if let origin = body["origin"] as? String,
                      let name = body["cacheName"] as? String {
                _ = CacheStorage.shared.delete(origin: origin, name: name)
            }

        case "swFetch":
            if let requestId = body["requestId"] as? String,
               let urlString = body["url"] as? String,
               let origin = body["origin"] as? String {
                let method = body["method"] as? String ?? "GET"
                let headers = body["headers"] as? [String: String] ?? [:]
                // Decode body from base64 if provided
                var requestBody: Data?
                if let bodyBase64 = body["bodyBase64"] as? String {
                    requestBody = Data(base64Encoded: bodyBase64)
                }
                handleSWFetch(requestId: requestId, urlString: urlString, origin: origin, method: method, headers: headers, body: requestBody)
            }

        default:
            break
        }
    }
}
