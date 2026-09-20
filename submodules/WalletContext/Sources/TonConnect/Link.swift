import Foundation

public struct TonConnectLink: Equatable, Sendable {
    public let peerId: String
    public let request: String?
    public let returnTarget: TonConnectReturnTarget
    public let traceId: String?

    /// Malformed TonConnect links must not fall through to payment routing.
    public static func matches(_ value: String) -> Bool {
        guard let url = URLComponents(string: value) else { return false }
        let scheme = url.scheme?.lowercased()
        let host = url.host?.lowercased()
        let telegramScheme = scheme == "tg" || scheme == "telegram"
        if scheme == "tc" || (telegramScheme && host == "ton-connect") { return true }
        let walletLink = (scheme == "https" && host == "t.me" && ["/sendgrams", "/sendgrams/"].contains(url.path.lowercased()))
            || (telegramScheme && host == "sendgrams")
        guard walletLink else { return false }
        return (url.queryItems ?? []).contains {
            ["id", "v", "r"].contains($0.name)
                || ($0.name == "startapp" && $0.value?.hasPrefix("tonconnect-") == true)
        }
    }

    public init(_ value: String) throws {
        guard value.utf8.count <= 256 * 1024, Self.matches(value),
              var url = URLComponents(string: value), url.user == nil,
              url.password == nil, url.fragment == nil else { throw TonConnectFailure.invalidLink }
        let starts = (url.queryItems ?? []).filter { $0.name == "startapp" }
        if starts.contains(where: { $0.value?.hasPrefix("tonconnect-") == true }) {
            guard starts.count == 1, let start = starts.first?.value,
                  !(url.queryItems ?? []).contains(where: { ["id", "v", "r"].contains($0.name) }) else {
                throw TonConnectFailure.invalidLink
            }
            let query = String(start.dropFirst("tonconnect-".count))
                .replacingOccurrences(of: "--", with: "%")
                .replacingOccurrences(of: "__", with: "=")
                .replacingOccurrences(of: "-", with: "&")
            guard let decoded = URLComponents(string: "tc://?" + query) else { throw TonConnectFailure.invalidLink }
            url = decoded
        }
        url.percentEncodedQuery = url.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%20")
        var fields: [String: String] = [:]
        for item in url.queryItems ?? [] where ["id", "v", "r", "ret", "trace_id"].contains(item.name) {
            guard fields[item.name] == nil, let value = item.value else { throw TonConnectFailure.invalidLink }
            fields[item.name] = value
        }
        guard let peer = fields["id"], peer.utf8.count == 64,
              peer.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }),
              fields["v"] == nil || fields["v"] == "2",
              (fields["trace_id"]?.count ?? 0) <= 100 else { throw TonConnectFailure.invalidLink }
        if let request = fields["r"] {
            guard !request.isEmpty, fields["v"] == "2" else { throw TonConnectFailure.invalidLink }
        }
        switch fields["ret"] {
        case nil, "back": self.returnTarget = .back
        case "none": self.returnTarget = .none
        case let .some(target):
            guard let parsed = URLComponents(string: target), let scheme = parsed.scheme?.lowercased(),
                  !["file", "data", "javascript"].contains(scheme), parsed.user == nil, parsed.password == nil else {
                throw TonConnectFailure.invalidLink
            }
            self.returnTarget = .url(target)
        }
        self.peerId = peer.lowercased()
        self.request = fields["r"]
        self.traceId = fields["trace_id"]
    }
}
