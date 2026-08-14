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
            case let .web(secret):
                return MTSocksProxySettings(ip: WebProxyConfiguration.canonicalHost(self.host) ?? self.host, port: WebProxyConfiguration.port, username: nil, password: nil, secret: secret, webProxy: true)
        }
    }

    var webProxyConfiguration: WebProxyConfiguration? {
        guard case let .web(secret) = self.connection else {
            return nil
        }
        return WebProxyConfiguration(host: self.host, secret: secret)
    }
}

public func canonicalWebProxyHost(_ value: String) -> String? {
    return WebProxyConfiguration.canonicalHost(value)
}

public func parseWebProxySecret(_ value: String) -> Data? {
    return WebProxyConfiguration.parseSecret(value)
}

public func webProxySecretString(_ secret: Data) -> String {
    return secret.map { String(format: "%02x", $0) }.joined()
}

public func makeWebProxySettings(host: String, secret: String) -> ProxyServerSettings? {
    guard let canonicalHost = canonicalWebProxyHost(host), let data = parseWebProxySecret(secret) else {
        return nil
    }
    return ProxyServerSettings(host: canonicalHost, port: Int32(WebProxyConfiguration.port), connection: .web(secret: data))
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
          let host = items.first(where: { $0.name == "server" })?.value,
          let secret = items.first(where: { $0.name == "secret" })?.value else {
        return nil
    }
    return makeWebProxySettings(host: host, secret: secret)
}

public func webProxySettingsLink(_ settings: ProxyServerSettings) -> String? {
    guard case let .web(secret) = settings.connection,
          let host = canonicalWebProxyHost(settings.host),
          WebProxyConfiguration.isValidSecret(secret) else {
        return nil
    }
    var components = URLComponents()
    components.scheme = "https"
    components.host = "t.me"
    components.path = "/webproxy"
    components.queryItems = [
        URLQueryItem(name: "server", value: host),
        URLQueryItem(name: "secret", value: webProxySecretString(secret))
    ]
    return components.string
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
