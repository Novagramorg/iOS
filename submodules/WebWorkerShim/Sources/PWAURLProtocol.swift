import Foundation
import WebKit

class PWAURLProtocol: URLProtocol {
    private static let handledKey = "PWAURLProtocol.handled"
    static var simulateOffline = false
    static var testResourceBundle: Bundle?

    /// Build origin string including port if non-standard
    static func buildOrigin(scheme: String, host: String, port: Int?) -> String {
        var origin = "\(scheme)://\(host)"
        if let port = port {
            // Only add port if non-standard for the scheme
            if (scheme == "http" && port != 80) || (scheme == "https" && port != 443) {
                origin += ":\(port)"
            }
        }
        return origin
    }

    // MARK: - Network Fetching

    private var dataTask: URLSessionDataTask?

    // MARK: - Registration

    static func register() {
        URLProtocol.registerClass(PWAURLProtocol.self)

        // Private API to make WKWebView use NSURLProtocol
        let className = "WKBrowsingContextController"
        let selectorName = "registerSchemeForCustomProtocol:"

        guard let cls = NSClassFromString(className) as? NSObject.Type else {
            print("[PWAURLProtocol] Failed to find \(className)")
            return
        }

        let selector = NSSelectorFromString(selectorName)
        guard cls.responds(to: selector) else {
            print("[PWAURLProtocol] \(className) doesn't respond to \(selectorName)")
            return
        }

        cls.perform(selector, with: "https")
        cls.perform(selector, with: "http")
        print("[PWAURLProtocol] Registered for http and https schemes")
    }

    static func unregister() {
        URLProtocol.unregisterClass(PWAURLProtocol.self)

        let className = "WKBrowsingContextController"
        let selectorName = "unregisterSchemeForCustomProtocol:"

        guard let cls = NSClassFromString(className) as? NSObject.Type else { return }
        let selector = NSSelectorFromString(selectorName)
        guard cls.responds(to: selector) else { return }

        cls.perform(selector, with: "https")
        cls.perform(selector, with: "http")
    }

    // MARK: - URLProtocol Overrides

    override class func canInit(with request: URLRequest) -> Bool {
        // Already handled - prevent infinite loop
        if property(forKey: handledKey, in: request) != nil {
            return false
        }
        
        if let url = request.url, url.path.hasSuffix("/rpc") {
            return false
        }

        // Skip SW context requests (marked with header)
        if request.value(forHTTPHeaderField: "X-SW-Context") != nil {
            return false
        }

        // Only intercept http/https
        guard let url = request.url,
              let scheme = url.scheme,
              (scheme == "http" || scheme == "https"),
              let host = url.host else {
            return false
        }

        // Only intercept origins we're managing (have SW registered or being registered)
        let origin = buildOrigin(scheme: scheme, host: host, port: url.port)
        if origin.range(of: "ddns.net") == nil {
            return false
        }
        return ServiceWorkerManager.shared.hasManagedOrigin(origin)
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        // Mark as handled to prevent re-entry
        let mutableRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.setProperty(true, forKey: Self.handledKey, in: mutableRequest)

        guard let url = request.url,
              let scheme = url.scheme,
              let host = url.host else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let urlPath: String
        if #available(iOS 16.0, *) {
            urlPath = url.path()
        } else {
            urlPath = url.path
        }

        let origin = Self.buildOrigin(scheme: scheme, host: host, port: url.port)

        // Check for offline simulation (applies to all hosts including test host)
        if Self.simulateOffline {
            // Check cache first
            if let cached = CacheStorage.shared.match(origin: origin, cacheName: nil, url: url.absoluteString) {
                deliverCachedResponse(cached, for: url)
                return
            }
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }

        // Check for active service worker first (even for test host)
        // This allows SW to intercept requests before falling back to test bundle
        Task {
            if let registration = await ServiceWorkerManager.shared.getRegistration(for: origin, path: urlPath),
               let context = await ServiceWorkerManager.shared.getContext(for: origin, path: urlPath) {
                // Dispatch fetch event to SW
                await self.dispatchToServiceWorker(context: context, origin: origin)
            } else if host == "testpwa.local" {
                // No SW, serve from test bundle for test host
                await MainActor.run { self.serveTestResource(url: url) }
            } else {
                // No SW, fetch directly
                self.fetchFromNetwork(mutableRequest as URLRequest)
            }
        }
    }

    override func stopLoading() {
        dataTask?.cancel()
    }

    // MARK: - Network Fetching Methods

    func fetchFromNetwork(_ request: URLRequest) {
        dataTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                self.client?.urlProtocol(self, didFailWithError: error)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  var data = data else {
                self.client?.urlProtocol(self, didFailWithError: URLError(.cannotParseResponse))
                return
            }

            // Convert headers for passing to injection method
            var headers = httpResponse.allHeaderFields as? [String: String] ?? [:]

            // Inject shim into HTML responses
            if let mimeType = httpResponse.mimeType, mimeType.contains("html") {
                data = self.injectShimIntoHTML(data, headers: headers) ?? data
            }

            // Update content length
            headers["Content-Length"] = "\(data.count)"

            guard let newResponse = HTTPURLResponse(
                url: self.request.url!,
                statusCode: httpResponse.statusCode,
                httpVersion: nil,
                headerFields: headers
            ) else {
                self.client?.urlProtocol(self, didFailWithError: URLError(.cannotParseResponse))
                return
            }

            self.client?.urlProtocol(self, didReceive: newResponse, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: data)
            self.client?.urlProtocolDidFinishLoading(self)
        }
        dataTask?.resume()
    }

    // MARK: - HTML Injection

    /// Extract nonce from CSP header if present
    private func extractCSPNonce(from headers: [String: String]?) -> String? {
        guard let headers = headers else { return nil }

        // Check both standard and report-only CSP headers
        let cspHeader = headers.first { key, _ in
            key.lowercased() == "content-security-policy" ||
            key.lowercased() == "content-security-policy-report-only"
        }?.value

        guard let csp = cspHeader else { return nil }

        // Parse script-src directive and extract nonce
        // Format: script-src 'nonce-BASE64VALUE' ...
        let pattern = "'nonce-([A-Za-z0-9+/=]+)'"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: csp, options: [], range: NSRange(csp.startIndex..., in: csp)),
              let nonceRange = Range(match.range(at: 1), in: csp) else {
            return nil
        }

        return String(csp[nonceRange])
    }

    /// Generate a random nonce for script injection
    private func generateNonce() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
    }

    private func injectShimIntoHTML(_ data: Data, headers: [String: String]? = nil) -> Data? {
        guard var html = String(data: data, encoding: .utf8) else {
            return nil
        }
        let mainBundle = Bundle(for: PWAWebView.self)
        guard let bundle = Bundle(path: mainBundle.bundlePath + "/WebWorkerShimBundle.bundle") else {
            return nil
        }
        guard let shimURL = bundle.url(forResource: "sw-registration-shim", withExtension: "js"),
              let shimCode = try? String(contentsOf: shimURL, encoding: .utf8) else {
            return nil
        }

        // Try to use existing nonce from CSP, or generate one and add to CSP
        let nonce = extractCSPNonce(from: headers)
        let nonceAttr = nonce.map { " nonce=\"\($0)\"" } ?? ""

        let injection = "<script\(nonceAttr)>\(shimCode)</script>"

        // Inject at start of <head> or after <!DOCTYPE>
        if let headRange = html.range(of: "<head>", options: .caseInsensitive) {
            html.insert(contentsOf: injection, at: headRange.upperBound)
        } else if let doctypeRange = html.range(of: ">", options: [], range: html.startIndex..<html.endIndex) {
            html.insert(contentsOf: injection, at: doctypeRange.upperBound)
        } else {
            html = injection + html
        }

        return html.data(using: .utf8)
    }

    // MARK: - Test Resource Serving

    private func serveTestResource(url: URL) {
        let path = url.path
        let filename = (path as NSString).lastPathComponent
        let ext = (filename as NSString).pathExtension
        let name = (filename as NSString).deletingPathExtension

        let bundle = Self.testResourceBundle ?? Bundle.main
        guard let fileURL = bundle.url(forResource: name, withExtension: ext),
              var data = try? Data(contentsOf: fileURL) else {
            // Return 404
            let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data())
            client?.urlProtocolDidFinishLoading(self)
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

        // Inject shim into HTML
        if ext.lowercased() == "html" {
            data = injectShimIntoHTML(data) ?? data
        }

        let headers = [
            "Content-Type": mimeType,
            "Content-Length": "\(data.count)"
        ]

        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    // MARK: - Cache Delivery

    private func deliverCachedResponse(_ cached: CachedResponse, for url: URL) {
        var headers = cached.headers
        headers["Content-Length"] = "\(cached.body.count)"

        guard let response = HTTPURLResponse(
            url: url,
            statusCode: cached.status,
            httpVersion: nil,
            headerFields: headers
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotParseResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: cached.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    // MARK: - Service Worker Dispatch

    private func dispatchToServiceWorker(context: ServiceWorkerContext, origin: String) async {
        let requestId = UUID().uuidString
        let url = request.url!.absoluteString
        let method = request.httpMethod ?? "GET"
        var headers: [String: String] = [:]
        request.allHTTPHeaderFields?.forEach { headers[$0.key] = $0.value }

        // Extract request body
        var body: Data?
        if let httpBody = request.httpBody {
            body = httpBody
        } else if let bodyStream = request.httpBodyStream {
            bodyStream.open()
            defer { bodyStream.close() }

            // Check stream opened successfully
            if bodyStream.streamStatus == .error {
                print("[PWAURLProtocol] Failed to open body stream")
                body = nil
            } else {
                var data = Data()
                let bufferSize = 4096
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
                defer { buffer.deallocate() }

                var streamError = false
                while bodyStream.hasBytesAvailable {
                    let bytesRead = bodyStream.read(buffer, maxLength: bufferSize)
                    if bytesRead > 0 {
                        data.append(buffer, count: bytesRead)
                    } else if bytesRead < 0 {
                        // Stream error
                        print("[PWAURLProtocol] Stream read error: \(bodyStream.streamError?.localizedDescription ?? "unknown")")
                        streamError = true
                        break
                    } else {
                        // EOF (bytesRead == 0)
                        break
                    }
                }
                body = streamError ? nil : (data.isEmpty ? nil : data)
            }
        }

        // Map request options
        var options: [String: String] = [:]

        // cachePolicy -> cache
        switch request.cachePolicy {
        case .useProtocolCachePolicy:
            options["cache"] = "default"
        case .reloadIgnoringLocalCacheData:
            options["cache"] = "default"
        case .reloadIgnoringLocalAndRemoteCacheData:
            options["cache"] = "no-store"
        case .returnCacheDataElseLoad:
            options["cache"] = "force-cache"
        case .returnCacheDataDontLoad:
            options["cache"] = "only-if-cached"
        case .reloadRevalidatingCacheData:
            options["cache"] = "no-cache"
        @unknown default:
            break
        }

        // httpShouldHandleCookies -> credentials
        if request.httpShouldHandleCookies {
            options["credentials"] = "same-origin"
        } else {
            options["credentials"] = "omit"
        }

        // Register callback
        await ServiceWorkerManager.shared._registerPendingRequest(requestId, protocol: self)

        // Dispatch to SW context
        await MainActor.run {
            print("[PWAURLProtocol] Dispatching fetch to SW for: \(url)")
            context.dispatchFetchEvent(
                requestId: requestId,
                url: url,
                method: method,
                headers: headers,
                body: body,
                options: options.isEmpty ? nil : options
            )
        }
    }

    // Called by ServiceWorkerManager when SW responds
    func handleFetchResponse(_ response: [String: Any]) {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let status = response["status"] as? Int ?? 200
        var headers = response["headers"] as? [String: String] ?? [:]
        let bodyBase64 = response["bodyBase64"] as? String ?? ""
        var body = Data(base64Encoded: bodyBase64) ?? Data()

        // Inject shim into HTML responses
        let contentType = headers.first { $0.key.lowercased() == "content-type" }?.value.lowercased() ?? ""
        if contentType.contains("html") {
            body = injectShimIntoHTML(body, headers: headers) ?? body
        }
        headers["Content-Length"] = "\(body.count)"

        guard let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: nil,
            headerFields: headers
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotParseResponse))
            return
        }

        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    // Called when SW passes through (doesn't handle)
    func handlePassthrough() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let scheme = url.scheme ?? "https"
        let host = url.host ?? ""
        let origin = Self.buildOrigin(scheme: scheme, host: host, port: url.port)

        print("[PWAURLProtocol] SW passthrough for: \(url.absoluteString)")

        // Check cache before network
        if let cached = CacheStorage.shared.match(origin: origin, cacheName: nil, url: url.absoluteString) {
            print("[PWAURLProtocol] Passthrough cache HIT")
            deliverCachedResponse(cached, for: url)
            return
        }

        // For test host, serve from test bundle instead of network
        if host == "testpwa.local" {
            print("[PWAURLProtocol] Passthrough serving from test bundle")
            serveTestResource(url: url)
            return
        }

        print("[PWAURLProtocol] Passthrough cache MISS, fetching from network")

        // Mark request and fetch
        let mutableRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.setProperty(true, forKey: Self.handledKey, in: mutableRequest)
        fetchFromNetwork(mutableRequest as URLRequest)
    }
}
