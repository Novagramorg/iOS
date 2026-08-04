import Foundation

/// One HTTP exchange, abstracted so tests can replay recorded fixtures without a
/// network and a host app can supply its own session configuration.
public protocol Transport: Sendable {
    func send(_ request: TransportRequest) async throws -> TransportResponse
}

public struct TransportRequest: Sendable {
    public enum Method: String, Sendable {
        case get = "GET"
        case post = "POST"
    }

    public var method: Method
    /// Path plus query, relative to the endpoint base.
    public var path: String
    public var query: [String: [String]]
    public var body: Data?

    public init(
        method: Method = .get,
        path: String,
        query: [String: [String]] = [:],
        body: Data? = nil
    ) {
        self.method = method
        self.path = path
        self.query = query
        self.body = body
    }

    /// Canonical path+query string, used as the fixture lookup key.
    ///
    /// Query parameters are sorted so the key does not depend on dictionary ordering.
    public var canonicalTarget: String {
        guard !query.isEmpty else { return path }
        let pairs = query
            .sorted { $0.key < $1.key }
            .flatMap { key, values in values.map { (key, $0) } }
            .map { "\($0.0)=\($0.1)" }
        return "\(path)?\(pairs.joined(separator: "&"))"
    }
}

public struct TransportResponse: Sendable {
    public var status: Int
    public var body: Data

    public init(status: Int, body: Data) {
        self.status = status
        self.body = body
    }

    public var isSuccess: Bool { (200..<300).contains(status) }
}

/// `URLSession`-backed transport.
///
/// Uses `URLSession.data(for:)`, which despite appearances is available at our iOS 13
/// floor: it is the async import of the completion-handler method and inherits its
/// availability. `bytes(for:)` is the iOS 15 one, and is not used here.
public struct URLSessionTransport: Transport {
    let endpoint: URL
    let apiKey: String?
    let session: URLSession
    let timeout: TimeInterval

    public init(
        endpoint: URL,
        apiKey: String? = nil,
        session: URLSession = .shared,
        timeout: TimeInterval = 30
    ) {
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.session = session
        self.timeout = timeout
    }

    /// Percent-encodes a query name or value, leaving only RFC 3986 unreserved characters.
    ///
    /// Deliberately stricter than `URLComponents`: encoding `+`, `/`, `=` and `&` is what makes
    /// base64 payloads survive the round trip. Over-encoding is harmless — a server must decode
    /// `%2F` and `/` identically — while under-encoding silently corrupts the value.
    static func encodeQueryComponent(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    /// Builds the request URL, including the encoded query.
    ///
    /// Split out of ``send(_:)`` so the encoding is testable without a network round trip —
    /// it is the part that was silently wrong, and a bug that only appears for half of all
    /// inputs needs a test that can enumerate inputs cheaply.
    func url(for request: TransportRequest) throws -> URL {
        var components = URLComponents(
            url: endpoint.appendingPathComponent(request.path.hasPrefix("/")
                ? String(request.path.dropFirst())
                : request.path),
            resolvingAgainstBaseURL: false
        )
        if !request.query.isEmpty {
            // Encoded by hand rather than through `queryItems`, which leaves `+` untouched.
            // A raw `+` in a query value is read as a space by the server, and about half of
            // all base64-encoded 32-byte hashes contain one — so `msg_hash` and `trace_id`
            // lookups failed with HTTP 422 roughly every other time, meaning a wallet trying
            // to confirm its own transfer lost it on a coin flip. Passing an already-correct
            // hash makes it look like a server problem rather than an encoding one.
            components?.percentEncodedQuery = request.query
                .sorted { $0.key < $1.key }
                .flatMap { key, values in values.map { (key, $0) } }
                .map { "\(Self.encodeQueryComponent($0.0))=\(Self.encodeQueryComponent($0.1))" }
                .joined(separator: "&")
        }
        guard let url = components?.url else {
            throw ToncenterError.invalidURL(request.path)
        }
        return url
    }

    public func send(_ request: TransportRequest) async throws -> TransportResponse {
        let url = try url(for: request)

        var urlRequest = URLRequest(url: url, timeoutInterval: timeout)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        // The key goes in a header rather than a query parameter so it does not appear
        // in logs or recorded fixture paths.
        if let apiKey { urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key") }
        if let body = request.body {
            urlRequest.httpBody = body
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw ToncenterError.nonHTTPResponse
        }
        return TransportResponse(status: http.statusCode, body: data)
    }
}

/// Retries a transport operation with a fixed delay.
///
/// Ported from the reference's `CallForSuccess`: five attempts, one second apart. The
/// `shouldRetry` predicate exists because a 422 means Toncenter rejected the *request*,
/// so retrying is pointless — it would just multiply load on a call that can never
/// succeed.
public enum Retry {
    public static let defaultAttempts = 5
    public static let defaultDelayNanoseconds: UInt64 = 1_000_000_000

    static func callForSuccess<T>(
        attempts: Int = defaultAttempts,
        delayNanoseconds: UInt64 = defaultDelayNanoseconds,
        shouldRetry: (Error) -> Bool = { !($0 as? ToncenterError).map(\.isClientError).and(false) },
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        for attempt in 0..<max(attempts, 1) {
            do {
                return try await operation()
            } catch {
                lastError = error
                guard shouldRetry(error), attempt < attempts - 1 else { throw error }
                // Task.sleep(nanoseconds:) rather than sleep(for:) — the latter is iOS 16.
                try? await Task.sleep(nanoseconds: delayNanoseconds)
            }
        }
        throw lastError ?? ToncenterError.retriesExhausted
    }
}

extension Optional where Wrapped == Bool {
    /// `nil` (not a `ToncenterError`) means "retry"; a client error means "do not".
    func and(_ fallback: Bool) -> Bool {
        self ?? fallback
    }
}
