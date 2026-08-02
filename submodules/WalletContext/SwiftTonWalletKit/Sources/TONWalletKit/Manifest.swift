import Foundation
import TONConnect

/// A dApp's self-description, fetched from its manifest URL.
///
/// This is the only identity a dApp has. Everything the user sees on the confirmation
/// sheet — the name, the icon, the domain a signature binds to — comes from here, so
/// fetching it is a security step rather than a cosmetic one.
public struct DAppManifest: Codable, Sendable, Equatable {
    public let url: String
    public let name: String
    public let iconUrl: String?
    public let termsOfUseUrl: String?
    public let privacyPolicyUrl: String?

    public init(
        url: String,
        name: String,
        iconUrl: String? = nil,
        termsOfUseUrl: String? = nil,
        privacyPolicyUrl: String? = nil
    ) {
        self.url = url
        self.name = name
        self.iconUrl = iconUrl
        self.termsOfUseUrl = termsOfUseUrl
        self.privacyPolicyUrl = privacyPolicyUrl
    }

    /// Host of ``url``. This is what TON Proof and `signData` bind to.
    public var host: String? {
        URL(string: url)?.host
    }
}

/// Why a manifest could not be used.
///
/// Carries the TON Connect wire code so the rejection sent back to the dApp says which of
/// the two failures happened — not found versus fetched-but-unusable — since a dApp
/// author debugging an integration needs to tell those apart.
public enum ManifestFailure: Error, Sendable, Equatable {
    /// The URL itself is unusable: unparseable, not https, or a host that is not a domain.
    case notFound(reason: String)
    /// Fetched, but the response was not a usable manifest.
    case invalidContent(reason: String)

    public var connectErrorCode: ConnectEventErrorCode {
        switch self {
        case .notFound: return .manifestNotFound
        case .invalidContent: return .manifestContent
        }
    }

    public var reason: String {
        switch self {
        case .notFound(let reason), .invalidContent(let reason): return reason
        }
    }
}

/// Fetches dApp manifests.
///
/// A protocol so a host app can route through its own networking stack — a shared
/// `URLSession` with pinning, a proxy, or a cache — and so tests need no network.
public protocol ManifestFetching: Sendable {
    func fetch(manifestURL: String) async -> Result<DAppManifest, ManifestFailure>
}

/// Validates a manifest host.
///
/// Requires a dotted domain, which rejects `localhost`, bare hostnames, and IP-ish
/// single labels. A dApp identified by something a user cannot recognise as a domain
/// cannot be shown meaningfully on a confirmation sheet.
public func isValidManifestHost(_ host: String) -> Bool {
    guard host.contains(".") else { return false }
    guard !host.hasPrefix("."), !host.hasSuffix(".") else { return false }
    return host.split(separator: ".", omittingEmptySubsequences: false).allSatisfy { !$0.isEmpty }
}

/// Fetches manifests over `URLSession`.
public struct URLSessionManifestFetcher: ManifestFetching {
    private let session: URLSession
    private let timeout: TimeInterval
    /// Refuse a response larger than this. A manifest is a few hundred bytes; anything
    /// bigger is either a misconfigured server or an attempt to make the wallet chew
    /// through a large body on a screen the user is waiting on.
    private let maxBytes: Int
    /// Reject plaintext manifests. A dApp's identity must not be substitutable in transit.
    private let requiresHTTPS: Bool

    public init(
        session: URLSession = .shared,
        timeout: TimeInterval = 10,
        maxBytes: Int = 64 * 1024,
        requiresHTTPS: Bool = true
    ) {
        self.session = session
        self.timeout = timeout
        self.maxBytes = maxBytes
        self.requiresHTTPS = requiresHTTPS
    }

    public func fetch(manifestURL: String) async -> Result<DAppManifest, ManifestFailure> {
        guard let url = URL(string: manifestURL), let host = url.host else {
            return .failure(.notFound(reason: "Manifest URL \(manifestURL) is not a valid URL"))
        }
        if requiresHTTPS, url.scheme?.lowercased() != "https" {
            return .failure(.notFound(reason: "Manifest URL must be https, got \(url.scheme ?? "no scheme")"))
        }
        guard isValidManifestHost(host) else {
            return .failure(.notFound(reason: "Manifest host \(host) is not a domain"))
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            return .failure(.invalidContent(reason: "Manifest fetch failed: \(error)"))
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            return .failure(.invalidContent(reason: "Manifest fetch returned HTTP \(http.statusCode)"))
        }
        guard data.count <= maxBytes else {
            return .failure(.invalidContent(reason: "Manifest is \(data.count) bytes, over the \(maxBytes) limit"))
        }

        return Self.decode(data)
    }

    /// Decodes and sanity-checks a manifest body.
    ///
    /// The `url` field is checked for a valid domain host because it — not the manifest
    /// URL — is what a signature binds to. A manifest served from `good.com` claiming
    /// `url: "bad"` must not produce a proof the user cannot interpret.
    static func decode(_ data: Data) -> Result<DAppManifest, ManifestFailure> {
        let manifest: DAppManifest
        do {
            manifest = try JSONDecoder().decode(DAppManifest.self, from: data)
        } catch {
            return .failure(.invalidContent(reason: "Manifest is not valid JSON: \(error)"))
        }

        let name = manifest.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return .failure(.invalidContent(reason: "Manifest has no name"))
        }
        // Trim before validating, not after: a manifest with a padded `url` is sloppy, not
        // hostile, and rejecting it would break a working dApp over whitespace.
        let url = manifest.url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let host = URL(string: url)?.host, isValidManifestHost(host) else {
            return .failure(.invalidContent(reason: "Manifest url \(url) has no valid domain host"))
        }

        return .success(
            DAppManifest(
                url: url,
                name: name,
                iconUrl: manifest.iconUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
                termsOfUseUrl: manifest.termsOfUseUrl,
                privacyPolicyUrl: manifest.privacyPolicyUrl
            )
        )
    }
}
