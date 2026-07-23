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

@preconcurrency import JavaScriptCore

// MARK: - JSFetch

/// A `JSContextInstallable` that wires the WHATWG `fetch` global into a JS context.
///
/// Use the static factory methods on `JSContextInstallable` (`.fetch`,
/// `.fetch(sessionConfiguration:)`, `.fetch(session:)`) rather than constructing this directly.
public struct JSFetchInstaller: Sendable, JSContextInstallable {
    let session: URLSession

    public func install(in context: JSContext) throws {
        try context.install([
            .request,
            .response,
            .jsCoreExtrasBundled(path: "fetch.js")
        ])
        let constructFetchTask: @convention(block) (JSValue) -> JSFetchTask? = { request in
            self.constructFetchTask(request: request)
        }
        context.setObject(constructFetchTask, forPath: "_jsCoreExtrasFetchTask")
    }

    private func constructFetchTask(request: JSValue) -> JSFetchTask? {
        guard let context = JSContext.current() else {
            return nil
        }
        let path = request.objectForKeyedSubscript("url").toString() ?? ""
        guard let url = URL(string: path) else {
            context.exception = .typeError(message: "Failed to parse URL from \(path).", in: context)
            return nil
        }
        guard url.hasHTTPScheme else {
            context.exception = .typeError(
                message:
                    "Cannot load from \(url). URL scheme \"\(url.scheme ?? "unknown")\" is not supported.",
                in: context
            )
            return nil
        }
        return JSFetchTask(
            request: URLRequest(
                url: url,
                request: request,
                cookieStorage: self.session.configuration.httpCookieStorage
            ),
            session: self.session
        )
    }
}

extension JSContextInstallable where Self == JSFetchInstaller {
    /// An installable that installs a fetch implementation backed by `URLSession.shared`.
    public static var fetch: Self { JSFetchInstaller(session: .shared) }

    /// An installable that installs a fetch implementation backed by a custom configuration.
    ///
    /// > Important: Each call constructs a fresh `URLSession` that is **not** invalidated automatically.
    /// > Prefer `.fetch` (which uses `URLSession.shared`) or `.fetch(session:)` with a session you
    /// > own and invalidate explicitly.
    ///
    /// - Parameters:
    ///   - sessionConfiguration: The configuration to use for the underlying `URLSession` that makes HTTP requests.
    /// - Returns: An installable.
    public static func fetch(sessionConfiguration: URLSessionConfiguration) -> Self {
        JSFetchInstaller(session: URLSession(configuration: sessionConfiguration))
    }

    /// An installable that installs a fetch implementation using a caller-provided session.
    ///
    /// - Parameters:
    ///   - session: The underlying `URLSession` to use to make HTTP requests. Caller owns the lifecycle.
    /// - Returns: An installable.
    public static func fetch(session: URLSession) -> Self {
        JSFetchInstaller(session: session)
    }
}

// MARK: - Fetch Task

@objc private protocol JSFetchTaskExport: JSExport {
    func perform() -> JSValue
    func cancel(_ reason: JSValue)
}

private actor JSFetchExecutor {
    private let request: URLRequest
    private let session: URLSession
    private var swiftTask: Task<Void, Never>?
    private var cancelReason: JSValue?

    init(request: URLRequest, session: URLSession) {
        self.request = request
        self.session = session
    }

    func setCancelReason(_ reason: JSValue) {
        self.cancelReason = reason
        self.swiftTask?.cancel()
    }

    func run(context: JSContext, resolve: JSValue?, reject: JSValue?) {
        if let reason = self.cancelReason {
            reject?.call(withArguments: [reason as Any])
            return
        }
        self.swiftTask = Task {
            await self.executeFetch(context: context, resolve: resolve, reject: reject)
        }
    }

    private func executeFetch(context: JSContext, resolve: JSValue?, reject: JSValue?) async {
        JSFetchLogger.logRequest(self.request)
        do {
            let data: Data
            let urlResponse: URLResponse
            let didRedirect: Bool
            if #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) {
                let observer = JSRedirectObserver()
                (data, urlResponse) = try await self.session.data(for: self.request, delegate: observer)
                didRedirect = observer.didRedirect
            } else {
                (data, urlResponse) = try await self.session.data(for: self.request)
                didRedirect = urlResponse.url != self.request.url
            }
            JSFetchLogger.logResponse(urlResponse, data: data)
            guard let httpResponse = urlResponse as? HTTPURLResponse else {
                rejectWithMessage("Server responded with a non-HTTP response.", in: context, reject: reject)
                return
            }
            let (cookies, headers) = httpResponse.cookieFilteredHeaders
            if self.request.httpShouldHandleCookies {
                self.session.configuration.httpCookieStorage?
                    .setCookies(cookies, for: httpResponse.url, mainDocumentURL: httpResponse.url)
            }
            let storage = JSFetchResponseBlobStorage(data: data)
            let responseJS = JSValue.response(
                response: httpResponse,
                headers: headers,
                body: storage,
                didRedirect: didRedirect,
                in: context
            )
            resolve?.call(withArguments: [responseJS as Any])
        } catch {
            if (error as? URLError)?.code == .cancelled {
                let reason = self.cancelReason
                    ?? JSValue(newErrorFromMessage: "Fetch was aborted.", in: context)
                reject?.call(withArguments: [reason as Any])
            } else {
                rejectWithMessage(error.localizedDescription, in: context, reject: reject)
            }
        }
    }
}

private func rejectWithMessage(_ message: String, in context: JSContext, reject: JSValue?) {
    reject?.call(withArguments: [JSValue(newErrorFromMessage: message, in: context) as Any])
}

private final class JSRedirectObserver: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    var didRedirect = false

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        self.didRedirect = true
        completionHandler(request)
    }
}

@objc private final class JSFetchTask: NSObject, Sendable {
    private let executor: JSFetchExecutor

    init(request: URLRequest, session: URLSession) {
        self.executor = JSFetchExecutor(request: request, session: session)
    }
}

extension JSFetchTask: JSFetchTaskExport {
    func perform() -> JSValue {
        guard let context = JSContext.current() else {
            return JSValue(
                newPromiseRejectedWithReason: "No context exists to perform \(#function)",
                in: JSContext()
            )
        }

        return JSValue(newPromiseIn: context) { resolve, reject in
            Task {
                await self.executor.run(context: context, resolve: resolve, reject: reject)
            }
        }
    }

    func cancel(_ reason: JSValue) {
        Task { await self.executor.setCancelReason(reason) }
    }
}

// MARK: - Response Blob Storage

private final class JSFetchResponseBlobStorage: JSBlobStorage {
    private let data: Data
    private let decoded: String
    let utf8SizeInBytes: Int64

    init(data: Data) {
        self.data = data
        self.decoded = String(decoding: data, as: UTF8.self)
        self.utf8SizeInBytes = Int64(data.count)
    }

    func utf8Bytes(
        startIndex: Int64,
        endIndex: Int64,
        context: JSContext
    ) async throws(JSValueError) -> String.UTF8View {
        self.decoded.utf8Bytes(startIndex: startIndex, endIndex: endIndex, context: context)
    }

    func rawBytes(
        startIndex: Int64,
        endIndex: Int64,
        context: JSContext
    ) async throws(JSValueError) -> Data {
        let lower = max(0, Int(startIndex))
        let upper = min(self.data.count, Int(endIndex))
        guard lower < upper else { return Data() }
        return self.data.subdata(in: lower..<upper)
    }
}

// MARK: - Request

extension URLRequest {
    fileprivate init(url: URL, request: JSValue, cookieStorage: HTTPCookieStorage?) {
        self.init(url: url)
        self.httpShouldHandleCookies = request.objectForKeyedSubscript("includeCookies").toBool()
        self.httpMethod = request.objectForKeyedSubscript("method").toString()
        self.httpBody = jsRequestBody(from: request)
        self.allHTTPHeaderFields = mergedHeaders(
            from: request,
            url: url,
            cookieStorage: self.httpShouldHandleCookies ? cookieStorage : nil
        )
    }
}

private func jsRequestBody(from request: JSValue) -> Data? {
    (request.objectForKeyedSubscript("body").toArray() as? [UInt8]).map { Data($0) }
}

private func mergedHeaders(
    from request: JSValue,
    url: URL,
    cookieStorage: HTTPCookieStorage?
) -> [String: String] {
    var merged: [String: String] = [:]
    if let cookies = cookieStorage?.cookies(for: url) {
        for (key, value) in HTTPCookie.requestHeaderFields(with: cookies) {
            merged[key] = value
        }
    }
    for (key, value) in jsHeaderEntries(from: request) {
        merged[key] = value
    }
    return merged
}

private func jsHeaderEntries(from request: JSValue) -> [(String, String)] {
    guard let headers = request.objectForKeyedSubscript("headers"), !headers.isUndefined else {
        return []
    }
    guard let entries = headers.invokeMethod("entries", withArguments: []), entries.isObject else {
        return []
    }
    var result: [(String, String)] = []
    while let next = entries.invokeMethod("next", withArguments: []),
          let done = next.objectForKeyedSubscript("done")?.toBool(),
          !done
    {
        if let pair = next.objectForKeyedSubscript("value"),
           let key = pair.atIndex(0),
           let value = pair.atIndex(1)
        {
            result.append((key.toString(), value.toString()))
        }
    }
    return result
}

// MARK: - Status Code

private let statusCodeMessages = [200: "ok"]

extension HTTPURLResponse {
    fileprivate var localizedStatusText: String {
        if let message = statusCodeMessages[self.statusCode] {
            return message
        }
        return HTTPURLResponse.localizedString(forStatusCode: self.statusCode)
    }
}

// MARK: - Cookie Filtering

extension HTTPURLResponse {
    fileprivate var cookieFilteredHeaders: ([HTTPCookie], [AnyHashable: Any]) {
        var headers = self.allHeaderFields
        var cookies = [HTTPCookie]()
        for (key, value) in self.allHeaderFields {
            guard let strKey = key.base as? String, let value = value as? String,
                  let url = self.url
            else { continue }
            guard
                let cookie =
                    HTTPCookie.cookies(withResponseHeaderFields: [strKey: value], for: url)
                    .first
            else { continue }
            cookies.append(cookie)
            if cookie.isHTTPOnly {
                headers.removeValue(forKey: key)
            }
        }
        return (cookies, headers)
    }
}

// MARK: - Response

extension JSValue {
    fileprivate static func response(
        response: HTTPURLResponse,
        headers: [AnyHashable: Any],
        body: some JSBlobStorage,
        didRedirect: Bool,
        in context: JSContext
    ) -> JSValue? {
        guard let responseInit = JSValue(newObjectIn: context) else { return nil }
        responseInit.setValue(response.statusCode, forPath: "status")
        responseInit.setValue(response.localizedStatusText, forPath: "statusText")
        responseInit.setValue(headers, forPath: "headers")
        let response = context.objectForKeyedSubscript("Response")
            .construct(withArguments: [
                JSBlob(storage: body, type: response.mimeType.map { MIMEType(rawValue: $0) } ?? .empty),
                responseInit
            ])
        let privateSymbol = context.evaluateScript("Symbol._jsCoreExtrasPrivate")
        response?.objectForKeyedSubscript(privateSymbol)
            .setValue(didRedirect, forPath: "options.redirected")
        return response
    }
}
