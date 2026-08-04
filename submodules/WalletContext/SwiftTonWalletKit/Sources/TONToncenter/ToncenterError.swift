import Foundation

/// Errors from the Toncenter client.
///
/// Typed rather than stringly, so callers can distinguish "the request was malformed"
/// from "the network failed" from "the response did not decode" — three cases the
/// reference collapses into one `TonClientError` with a message.
public enum ToncenterError: Error, CustomStringConvertible {
    /// HTTP 4xx: Toncenter rejected the request. Not worth retrying.
    case clientError(status: Int, body: String)
    /// HTTP 5xx or a transport failure. Worth retrying.
    case serverError(status: Int, body: String)
    /// HTTP 429. Worth retrying, but only after backing off.
    case rateLimited(body: String)
    case decodingFailed(endpoint: String, underlying: Error)
    case invalidURL(String)
    case nonHTTPResponse
    case retriesExhausted
    /// The response was well-formed but semantically unusable.
    case unexpectedResponse(String)
    case addressNormalizationFailed(String)

    public var description: String {
        switch self {
        case .clientError(let status, let body):
            return "Toncenter rejected the request (HTTP \(status)): \(body.prefix(200))"
        case .serverError(let status, let body):
            return "Toncenter server error (HTTP \(status)): \(body.prefix(200))"
        case .rateLimited(let body):
            return "Toncenter rate limit exceeded (HTTP 429): \(body.prefix(200))"
        case .decodingFailed(let endpoint, let underlying):
            return "Failed to decode \(endpoint): \(underlying)"
        case .invalidURL(let path):
            return "Could not build a URL for \(path)"
        case .nonHTTPResponse:
            return "Received a non-HTTP response"
        case .retriesExhausted:
            return "Retries exhausted without a successful response"
        case .unexpectedResponse(let detail):
            return "Unexpected response: \(detail)"
        case .addressNormalizationFailed(let address):
            return "Could not normalize address \"\(address)\""
        }
    }

    /// Whether retrying could plausibly help.
    public var isClientError: Bool {
        switch self {
        case .clientError, .invalidURL, .addressNormalizationFailed:
            return true
        case .serverError, .rateLimited, .decodingFailed, .nonHTTPResponse,
             .retriesExhausted, .unexpectedResponse:
            return false
        }
    }

    /// Builds the right case from a status code.
    static func from(status: Int, body: Data) -> ToncenterError {
        let text = String(data: body, encoding: .utf8) ?? "<\(body.count) bytes>"
        switch status {
        case 429: return .rateLimited(body: text)
        case 400..<500: return .clientError(status: status, body: text)
        default: return .serverError(status: status, body: text)
        }
    }
}
