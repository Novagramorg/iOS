import Foundation
import TONCore

/// A parsed TON Connect handoff link.
///
/// A dApp starts a connection by handing the wallet one of these — via QR code, deep link,
/// or universal link. It carries the dApp's session public key, the bridge to talk over,
/// and the connect request itself.
public struct ConnectURL: Sendable {
    /// The dApp's session public key, hex. Messages are sealed to this.
    public let clientID: String
    /// The connect request, decoded from the `r` parameter.
    public let request: ConnectRequest
    /// Bridge base URL when the dApp names one. Wallets usually use their own default.
    public let bridgeURL: String?
    /// Version parameter, if present.
    public let version: String?
    /// True when the link asked the wallet to return without user interaction.
    public let returnStrategy: String?

    public init(
        clientID: String,
        request: ConnectRequest,
        bridgeURL: String? = nil,
        version: String? = nil,
        returnStrategy: String? = nil
    ) {
        self.clientID = clientID
        self.request = request
        self.bridgeURL = bridgeURL
        self.version = version
        self.returnStrategy = returnStrategy
    }
}

public enum ConnectURLError: Error, CustomStringConvertible {
    case malformedURL(String)
    case missingClientID
    case missingRequest
    case malformedRequest(underlying: Error)
    case invalidClientID(String)

    public var description: String {
        switch self {
        case .malformedURL(let s):
            return "Not a parseable URL: \"\(s)\""
        case .missingClientID:
            return "Link carries no `id` parameter (the dApp's session public key)"
        case .missingRequest:
            return "Link carries no `r` parameter (the connect request)"
        case .malformedRequest(let underlying):
            return "Connect request failed to decode: \(underlying)"
        case .invalidClientID(let s):
            return "Client id \"\(s)\" is not a 32-byte hex key"
        }
    }
}

extension ConnectURL {
    /// Parses a TON Connect link.
    ///
    /// Accepts every shape wallets encounter in practice:
    ///
    /// - `tc://?v=2&id=<hex>&r=<json>`
    /// - `https://app.tonkeeper.com/ton-connect?v=2&id=…&r=…` (universal link)
    /// - a bare `?v=2&id=…&r=…` query, and one with no leading `?`
    ///
    /// A scheme-less string is treated as `tc://`, matching the existing iOS wrapper's
    /// behaviour of defaulting the scheme when absent.
    public static func parse(_ string: String) throws -> ConnectURL {
        let normalized = normalize(string)

        guard let components = URLComponents(string: normalized) else {
            throw ConnectURLError.malformedURL(string)
        }

        // A universal link puts the parameters after a path; a deep link has no path. Both
        // land in `queryItems`, so no special-casing is needed beyond normalization.
        let items = components.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value
        }

        guard let clientID = value("id"), !clientID.isEmpty else {
            throw ConnectURLError.missingClientID
        }
        // A client id is an X25519 public key. Rejecting a malformed one here beats
        // discovering it when the first sealed message cannot be routed.
        guard clientID.count == 64, Data(hexString: clientID) != nil else {
            throw ConnectURLError.invalidClientID(clientID)
        }

        guard let rawRequest = value("r"), !rawRequest.isEmpty else {
            throw ConnectURLError.missingRequest
        }

        let request: ConnectRequest
        do {
            request = try JSONDecoder().decode(
                ConnectRequest.self,
                from: Data(rawRequest.utf8)
            )
        } catch {
            throw ConnectURLError.malformedRequest(underlying: error)
        }

        return ConnectURL(
            clientID: clientID,
            request: request,
            bridgeURL: value("bridge") ?? value("bridgeUrl"),
            version: value("v"),
            returnStrategy: value("ret")
        )
    }

    /// Brings the many link shapes into something `URLComponents` can parse.
    static func normalize(_ string: String) -> String {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)

        // Already has a scheme.
        if trimmed.contains("://") { return trimmed }

        // A bare query, with or without the leading `?`.
        if trimmed.hasPrefix("?") { return "tc://\(trimmed)" }
        if trimmed.contains("=") && !trimmed.contains("/") { return "tc://?\(trimmed)" }

        // Something like `tc:?v=2&…` — a scheme with no authority.
        if let colon = trimmed.firstIndex(of: ":"), !trimmed.hasPrefix("http") {
            let scheme = trimmed[trimmed.startIndex..<colon]
            let rest = trimmed[trimmed.index(after: colon)...]
            if !rest.hasPrefix("//") {
                return "\(scheme)://\(rest.hasPrefix("?") ? String(rest) : "?\(rest)")"
            }
        }

        return trimmed
    }

    /// Whether a string plausibly is a TON Connect link, for deciding whether to try.
    public static func looksLikeConnectLink(_ string: String) -> Bool {
        let lower = string.lowercased()
        guard lower.contains("id=") && lower.contains("r=") else { return false }
        return lower.hasPrefix("tc://")
            || lower.hasPrefix("tc:")
            || lower.contains("ton-connect")
            || lower.contains("tonconnect")
            || lower.hasPrefix("?")
    }
}
