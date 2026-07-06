import Foundation
import TelegramCore

// Loads the bundled Webshare proxy list (one `host:port:username:password` per line) and returns
// it as SOCKS5 proxy servers in randomized order, so each launch spreads load across the pool and
// starts from a different candidate.
enum FenixuzProxyPool {
    static func loadShuffled() -> [ProxyServerSettings] {
        guard let text = self.loadBundledText() else {
            return []
        }
        var servers: [ProxyServerSettings] = []
        for rawLine in text.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            let line = String(rawLine).trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                continue
            }
            let components = line.split(separator: ":", maxSplits: 3, omittingEmptySubsequences: false).map(String.init)
            if components.count != 4 {
                continue
            }
            let host = components[0]
            guard !host.isEmpty, let port = Int32(components[1]), port > 0, port <= 65535 else {
                continue
            }
            let username = components[2]
            let password = components[3]
            servers.append(ProxyServerSettings(host: host, port: port, connection: .socks5(username: username, password: password)))
        }
        return servers.shuffled()
    }

    private static func loadBundledText() -> String? {
        let moduleBundle = Bundle(for: FenixuzAutoProxyManager.self)
        guard let bundlePath = moduleBundle.path(forResource: "FenixuzAutoProxyResources", ofType: "bundle"),
              let resourceBundle = Bundle(path: bundlePath),
              let filePath = resourceBundle.path(forResource: "russia_proxies", ofType: "txt"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
