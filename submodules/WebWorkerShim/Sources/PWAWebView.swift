import WebKit

let registeredPWAProtocol: Bool = {
    PWAURLProtocol.register()
    
    // Initialize persistence
    let persistence = CachePersistence.shared
    CacheStorage.shared.persistence = persistence

    // Load persisted data
    CacheStorage.shared.loadFromDisk()

    Task {
        await ServiceWorkerManager.shared.setPersistence(persistence)
        await ServiceWorkerManager.shared.loadFromDisk()
    }
    
    return true
}()

open class PWAWebView: WKWebView {

    /// Creates a PWAWebView with message handlers configured.
    override public init(frame: CGRect, configuration: WKWebViewConfiguration) {
        let _ = registeredPWAProtocol

        // Add message handler for SW registration and cache operations
        let messageHandler = PWAMessageHandler()
        configuration.userContentController.add(messageHandler, name: "swBridge")

        super.init(frame: frame, configuration: configuration)
    }

    required public init?(coder: NSCoder) {
        fatalError("PWAWebView does not support initialization from storyboard.")
    }

    deinit {
        self.configuration.userContentController.removeScriptMessageHandler(forName: "swBridge")
    }

    public func loadPWA(url: URL) {
        // Pre-register this origin so PWAURLProtocol knows to intercept it
        if let scheme = url.scheme, let host = url.host {
            let origin = PWAURLProtocol.buildOrigin(scheme: scheme, host: host, port: url.port)
            Task {
                await ServiceWorkerManager.shared.addManagedOrigin(origin)
            }
        }

        // Load the real URL directly - PWAURLProtocol will intercept it
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        load(request)
    }
}

private class PWAMessageHandler: NSObject, WKScriptMessageHandler {
    /// Extract the actual origin from the page URL for validation
    private func getPageOrigin(from message: WKScriptMessage) -> String? {
        guard let pageURL = message.frameInfo.request.url,
              let host = pageURL.host,
              let scheme = pageURL.scheme else { return nil }

        var origin = "\(scheme)://\(host)"
        if let port = pageURL.port, port != 80 && port != 443 {
            origin += ":\(port)"
        }
        return origin
    }

    /// Validate that the claimed origin matches the page's actual origin
    private func validateOrigin(_ claimedOrigin: String, message: WKScriptMessage) -> Bool {
        guard let pageOrigin = getPageOrigin(from: message) else { return false }
        return claimedOrigin == pageOrigin
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }

        switch type {
        case "register":
            handleRegister(body: body, message: message)

        case "unregister":
            handleUnregister(body: body, message: message)

        case "cacheOpen":
            if let claimedOrigin = body["origin"] as? String,
               let name = body["cacheName"] as? String,
               validateOrigin(claimedOrigin, message: message) {
                CacheStorage.shared.open(origin: claimedOrigin, name: name)
            }

        case "cachePut":
            if let claimedOrigin = body["origin"] as? String,
               let cacheName = body["cacheName"] as? String,
               let url = body["url"] as? String,
               let responseDict = body["response"] as? [String: Any],
               validateOrigin(claimedOrigin, message: message) {
                let response = CachedResponse(
                    url: url,
                    status: responseDict["status"] as? Int ?? 200,
                    statusText: responseDict["statusText"] as? String ?? "OK",
                    headers: responseDict["headers"] as? [String: String] ?? [:],
                    body: Data(base64Encoded: responseDict["bodyBase64"] as? String ?? "") ?? Data()
                )
                CacheStorage.shared.put(origin: claimedOrigin, cacheName: cacheName, url: url, response: response)
            }

        case "cacheMatch":
            handleCacheMatch(body: body, message: message)

        case "cacheEntryDelete":
            handleCacheEntryDelete(body: body, message: message)

        case "cacheKeys":
            handleCacheKeys(body: body, message: message)

        case "cacheStorageDelete":
            handleCacheStorageDelete(body: body, message: message)

        case "cachesKeys":
            handleCachesKeys(body: body, message: message)

        default:
            break
        }
    }

    private func handleRegister(body: [String: Any], message: WKScriptMessage) {
        guard let scriptURLString = body["scriptURL"] as? String,
              let scriptURL = URL(string: scriptURLString),
              let scope = body["scope"] as? String else { return }

        let callbackId = body["callbackId"] as? String

        // Get origin from the page URL (now a real https:// URL)
        guard let pageURL = message.frameInfo.request.url,
              let host = pageURL.host,
              let scheme = pageURL.scheme else {
            if let callbackId = callbackId {
                message.webView?.evaluateJavaScript(
                    "window.resolveRegistrationCallback('\(callbackId)', false, 'Invalid page URL');",
                    completionHandler: nil
                )
            }
            return
        }

        // Include port in origin
        var origin = "\(scheme)://\(host)"
        if let port = pageURL.port, port != 80 && port != 443 {
            origin += ":\(port)"
        }

        // Register the service worker
        Task {
            let registration = await ServiceWorkerManager.shared.register(
                scriptURL: scriptURL,
                scope: scope,
                origin: origin
            )

            // Notify JS that registration started successfully
            if let callbackId = callbackId {
                await MainActor.run {
                    message.webView?.evaluateJavaScript(
                        "window.resolveRegistrationCallback('\(callbackId)', true, null);",
                        completionHandler: nil
                    )
                }
            }

            // Fetch the SW script
            await self.fetchAndLoadServiceWorker(
                scriptURL: scriptURL,
                registration: registration,
                origin: origin,
                webView: message.webView,
                scope: scope
            )
        }
    }

    private func fetchAndLoadServiceWorker(scriptURL: URL, registration: ServiceWorkerRegistration, origin: String, webView: WKWebView?, scope: String) async {
        // Handle test host
        if scriptURL.host == "testpwa.local" {
            let path = scriptURL.path
            let filename = (path as NSString).lastPathComponent
            let ext = (filename as NSString).pathExtension
            let name = (filename as NSString).deletingPathExtension

            let bundle = PWAURLProtocol.testResourceBundle ?? Bundle(for: PWAMessageHandler.self)
            if let fileURL = bundle.url(forResource: name, withExtension: ext),
               let script = try? String(contentsOf: fileURL, encoding: .utf8) {
                await loadServiceWorkerScript(script, registration: registration, origin: origin, webView: webView, scope: scope)
            } else {
                print("[PWAMessageHandler] Failed to load test SW script: \(filename)")
            }
            return
        }

        // Fetch from network
        do {
            // Mark as SW context request to avoid interception
            var request = URLRequest(url: scriptURL)
            request.setValue("true", forHTTPHeaderField: "X-SW-Context")

            let (data, _) = try await URLSession.shared.data(for: request)
            guard let script = String(data: data, encoding: .utf8) else {
                print("[PWAMessageHandler] Failed to decode SW script")
                return
            }
            await loadServiceWorkerScript(script, registration: registration, origin: origin, webView: webView, scope: scope)
        } catch {
            print("[PWAMessageHandler] Failed to fetch SW script: \(error)")
        }
    }

    private func loadServiceWorkerScript(_ script: String, registration: ServiceWorkerRegistration, origin: String, webView: WKWebView?, scope: String) async {
        await registration.setScriptContent(script)

        // Persist the script
        CachePersistence.shared.saveScript(script, for: origin)

        await MainActor.run {
            // Create context if needed
            Task {
                var context = await ServiceWorkerManager.shared.getContext(for: origin, scope: scope)
                if context == nil {
                    context = ServiceWorkerContext(registration: registration, origin: origin, pageWebView: webView, scope: scope)
                    await ServiceWorkerManager.shared.setContext(context!, for: origin, scope: scope)
                }
                context?.loadServiceWorkerScript(script)
            }
        }
    }

    private func handleUnregister(body: [String: Any], message: WKScriptMessage) {
        guard let callbackId = body["callbackId"] as? String else { return }

        // Get origin from the page URL
        guard let pageURL = message.frameInfo.request.url,
              let host = pageURL.host,
              let scheme = pageURL.scheme else {
            message.webView?.evaluateJavaScript(
                "window.resolveRegistrationCallback('\(callbackId)', false, 'Invalid page URL');",
                completionHandler: nil
            )
            return
        }

        // Include port in origin
        var origin = "\(scheme)://\(host)"
        if let port = pageURL.port, port != 80 && port != 443 {
            origin += ":\(port)"
        }

        Task {
            let success = await ServiceWorkerManager.shared.unregister(origin: origin)
            await ServiceWorkerManager.shared.removeContext(for: origin)
            await ServiceWorkerManager.shared.removeManagedOrigin(origin)

            await MainActor.run {
                message.webView?.evaluateJavaScript(
                    "window.resolveRegistrationCallback('\(callbackId)', \(success), null);",
                    completionHandler: nil
                )
            }
        }
    }

    private func handleCacheMatch(body: [String: Any], message: WKScriptMessage) {
        guard let callbackId = body["callbackId"] as? String,
              let claimedOrigin = body["origin"] as? String,
              let url = body["url"] as? String,
              validateOrigin(claimedOrigin, message: message) else {
            // Return null for invalid/missing origin
            if let callbackId = body["callbackId"] as? String {
                message.webView?.evaluateJavaScript("window.resolveCacheCallback('\(callbackId)', null);", completionHandler: nil)
            }
            return
        }

        let cacheName = body["cacheName"] as? String
        let response = CacheStorage.shared.match(origin: claimedOrigin, cacheName: cacheName, url: url)

        let responseJS: String
        if let r = response {
            let dict = r.toDictionary()
            let data = try? JSONSerialization.data(withJSONObject: dict, options: [])
            responseJS = data.flatMap { String(data: $0, encoding: .utf8) } ?? "null"
        } else {
            responseJS = "null"
        }

        message.webView?.evaluateJavaScript("window.resolveCacheCallback('\(callbackId)', \(responseJS));", completionHandler: nil)
    }

    private func handleCacheEntryDelete(body: [String: Any], message: WKScriptMessage) {
        guard let callbackId = body["callbackId"] as? String,
              let claimedOrigin = body["origin"] as? String,
              let cacheName = body["cacheName"] as? String,
              let url = body["url"] as? String,
              validateOrigin(claimedOrigin, message: message) else {
            if let callbackId = body["callbackId"] as? String {
                message.webView?.evaluateJavaScript("window.resolveCacheCallback('\(callbackId)', false);", completionHandler: nil)
            }
            return
        }

        let deleted = CacheStorage.shared.deleteEntry(origin: claimedOrigin, cacheName: cacheName, url: url)
        message.webView?.evaluateJavaScript("window.resolveCacheCallback('\(callbackId)', \(deleted));", completionHandler: nil)
    }

    private func handleCacheKeys(body: [String: Any], message: WKScriptMessage) {
        guard let callbackId = body["callbackId"] as? String,
              let claimedOrigin = body["origin"] as? String,
              let cacheName = body["cacheName"] as? String,
              validateOrigin(claimedOrigin, message: message) else {
            if let callbackId = body["callbackId"] as? String {
                message.webView?.evaluateJavaScript("window.resolveCacheCallback('\(callbackId)', []);", completionHandler: nil)
            }
            return
        }

        let urls = CacheStorage.shared.cacheKeys(origin: claimedOrigin, cacheName: cacheName)
        let data = try? JSONSerialization.data(withJSONObject: urls, options: [])
        let urlsJS = data.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        message.webView?.evaluateJavaScript("window.resolveCacheCallback('\(callbackId)', \(urlsJS));", completionHandler: nil)
    }

    private func handleCacheStorageDelete(body: [String: Any], message: WKScriptMessage) {
        guard let callbackId = body["callbackId"] as? String,
              let claimedOrigin = body["origin"] as? String,
              let name = body["cacheName"] as? String,
              validateOrigin(claimedOrigin, message: message) else {
            if let callbackId = body["callbackId"] as? String {
                message.webView?.evaluateJavaScript("window.resolveCacheCallback('\(callbackId)', false);", completionHandler: nil)
            }
            return
        }

        let deleted = CacheStorage.shared.delete(origin: claimedOrigin, name: name)
        message.webView?.evaluateJavaScript("window.resolveCacheCallback('\(callbackId)', \(deleted));", completionHandler: nil)
    }

    private func handleCachesKeys(body: [String: Any], message: WKScriptMessage) {
        guard let callbackId = body["callbackId"] as? String,
              let claimedOrigin = body["origin"] as? String,
              validateOrigin(claimedOrigin, message: message) else {
            if let callbackId = body["callbackId"] as? String {
                message.webView?.evaluateJavaScript("window.resolveCacheCallback('\(callbackId)', []);", completionHandler: nil)
            }
            return
        }

        let names = CacheStorage.shared.keys(origin: claimedOrigin)
        let data = try? JSONSerialization.data(withJSONObject: names, options: [])
        let namesJS = data.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        message.webView?.evaluateJavaScript("window.resolveCacheCallback('\(callbackId)', \(namesJS));", completionHandler: nil)
    }
}
