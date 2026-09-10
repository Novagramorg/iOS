import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit
import WebProxyTransport

public func updateProxySettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (ProxySettings) -> ProxySettings) -> Signal<Bool, NoError> {
    return accountManager.transaction { transaction -> Bool in
        return updateProxySettingsInteractively(transaction: transaction, f)
    }
}

extension ProxyServerSettings {
    var isWebProxy: Bool {
        if case .web = self.connection {
            return true
        } else {
            return false
        }
    }

    var mtProxySettings: MTSocksProxySettings {
        switch self.connection {
            case let .socks5(username, password):
                return MTSocksProxySettings(ip: self.host, port: UInt16(clamping: self.port), username: username, password: password, secret: nil)
            case let .mtp(secret):
                return MTSocksProxySettings(ip: self.host, port: UInt16(clamping: self.port), username: nil, password: nil, secret: secret)
            case let .web(secret, _):
                return MTSocksProxySettings(ip: WebProxyConfiguration.canonicalHost(self.host) ?? self.host, port: WebProxyConfiguration.port, username: nil, password: nil, secret: secret, webProxy: true)
        }
    }

    var webProxyConfiguration: WebProxyConfiguration? {
        guard case let .web(secret, path) = self.connection else {
            return nil
        }
        return WebProxyConfiguration(host: self.host, path: path, secret: secret)
    }
}

extension ProxyServerSettings {
    public var webProxyAddress: String? {
        guard case let .web(_, path) = self.connection else {
            return nil
        }
        return path.isEmpty ? self.host : "\(self.host)/\(path)"
    }
}

public func canonicalWebProxyHost(_ value: String) -> String? {
    return WebProxyConfiguration.canonicalHost(value)
}

public func canonicalWebProxyAddress(_ value: String) -> (host: String, path: String)? {
    return WebProxyConfiguration.canonicalAddress(value)
}

public func parseWebProxySecret(_ value: String) -> Data? {
    return WebProxyConfiguration.parseSecret(value)
}

public func webProxySecretString(_ secret: Data) -> String {
    return secret.map { String(format: "%02x", $0) }.joined()
}

public func makeWebProxySettings(address: String, secret: String) -> ProxyServerSettings? {
    guard let address = canonicalWebProxyAddress(address), let data = parseWebProxySecret(secret) else {
        return nil
    }
    return ProxyServerSettings(host: address.host, port: Int32(WebProxyConfiguration.port), connection: .web(secret: data, path: address.path))
}

public func parseWebProxySettingsLink(_ value: String) -> ProxyServerSettings? {
    guard let components = URLComponents(string: value),
          components.fragment == nil,
          components.user == nil,
          components.password == nil else {
        return nil
    }

    let scheme = components.scheme?.lowercased()
    let isTelegramLink = scheme == "https"
        && components.host?.lowercased() == "t.me"
        && components.path == "/webproxy"
        && (components.port == nil || components.port == Int(WebProxyConfiguration.port))
    let isTelegramScheme = scheme == "tg"
        && components.host?.lowercased() == "webproxy"
        && (components.path.isEmpty || components.path == "/")
        && components.port == nil
    guard isTelegramLink || isTelegramScheme else {
        return nil
    }

    let items = components.queryItems ?? []
    guard items.count == 2,
          items.filter({ $0.name == "server" }).count == 1,
          items.filter({ $0.name == "secret" }).count == 1,
          let address = items.first(where: { $0.name == "server" })?.value,
          let secret = items.first(where: { $0.name == "secret" })?.value else {
        return nil
    }
    return makeWebProxySettings(address: address, secret: secret)
}

public func webProxySettingsLink(_ settings: ProxyServerSettings) -> String? {
    guard case let .web(secret, path) = settings.connection,
          let configuration = WebProxyConfiguration(host: settings.host, path: path, secret: secret) else {
        return nil
    }
    var components = URLComponents()
    components.scheme = "https"
    components.host = "t.me"
    components.path = "/webproxy"
    components.percentEncodedQueryItems = [
        URLQueryItem(name: "server", value: webProxyPercentEncodedAddress(configuration.address)),
        URLQueryItem(name: "secret", value: webProxySecretString(secret))
    ]
    return components.string
}

private func webProxyPercentEncodedAddress(_ value: String) -> String {
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-._~")
    return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
}

public func updateProxySettingsInteractively(transaction: AccountManagerModifier<TelegramAccountManagerTypes>, _ f: @escaping (ProxySettings) -> ProxySettings) -> Bool {
    var hasChanges = false
    transaction.updateSharedData(SharedDataKeys.proxySettings, { current in
        let previous = current?.get(ProxySettings.self) ?? ProxySettings.defaultSettings
        let updated = f(previous)
        hasChanges = previous != updated
        return PreferencesEntry(updated)
    })
    return hasChanges
}
