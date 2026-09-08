import XCTest
@testable import TelegramCore

final class ProxySettingsTests: XCTestCase {
    func testExistingProxyDiscriminatorsRemainStable() throws {
        let socks = ProxyServerConnection.socks5(username: "user", password: "pass")
        let mtp = ProxyServerConnection.mtp(secret: Data(repeating: 1, count: 16))
        XCTAssertEqual(try discriminator(socks), 0)
        XCTAssertEqual(try discriminator(mtp), 1)

        let oldSocks = Data(#"{"_t":0,"username":"user","password":"pass"}"#.utf8)
        let oldMtp = Data(#"{"_t":1,"secret":"AAECAwQFBgcICQoLDA0ODw=="}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(ProxyServerConnection.self, from: oldSocks), socks)
        XCTAssertEqual(try JSONDecoder().decode(ProxyServerConnection.self, from: oldMtp), .mtp(secret: Data(0 ..< 16)))

        let unknown = Data(#"{"_t":999}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(ProxyServerConnection.self, from: unknown), .socks5(username: nil, password: nil))
    }

    func testWebProxyRoundTrip() throws {
        let secret = Data((0 ..< 16).map(UInt8.init))
        let settings = ProxyServerSettings(host: "proxy.example.com", port: 8443, connection: .web(secret: secret))
        XCTAssertEqual(settings.port, 443)
        let data = try JSONEncoder().encode(settings)
        XCTAssertEqual(try JSONDecoder().decode(ProxyServerSettings.self, from: data), settings)
        XCTAssertEqual(try discriminator(settings.connection), 2)

        let mtSettings = settings.mtProxySettings
        XCTAssertEqual(mtSettings.ip, "proxy.example.com")
        XCTAssertEqual(mtSettings.port, 443)
        XCTAssertEqual(mtSettings.secret, secret)
        XCTAssertTrue(mtSettings.webProxy)
    }

    func testWebProxyValidationAndNormalization() throws {
        let settings = try XCTUnwrap(makeWebProxySettings(host: "PROXY.EXAMPLE.COM", secret: "000102030405060708090a0b0c0d0e0f"))
        XCTAssertEqual(settings.host, "proxy.example.com")
        XCTAssertEqual(settings.port, 443)
        XCTAssertNil(makeWebProxySettings(host: "proxy.example.com:8443", secret: "000102030405060708090a0b0c0d0e0f"))
        XCTAssertNil(makeWebProxySettings(host: "proxy.example.com", secret: "00"))
    }

    func testWebProxyLinksAreStrictAndCanonical() throws {
        let secret = "000102030405060708090a0b0c0d0e0f"
        let settings = try XCTUnwrap(parseWebProxySettingsLink("tg://webproxy?server=PROXY.EXAMPLE.COM&secret=\(secret)"))
        XCTAssertEqual(settings.host, "proxy.example.com")
        XCTAssertEqual(settings.port, 443)
        XCTAssertEqual(webProxySettingsLink(settings), "https://t.me/webproxy?server=proxy.example.com&secret=\(secret)")
        XCTAssertEqual(parseWebProxySettingsLink(try XCTUnwrap(webProxySettingsLink(settings))), settings)

        XCTAssertNil(parseWebProxySettingsLink("https://t.me/webproxy?server=proxy.example.com&server=other.example.com&secret=\(secret)"))
        XCTAssertNil(parseWebProxySettingsLink("https://t.me/webproxy?server=proxy.example.com&secret=\(secret)&extra=1"))
        XCTAssertNil(parseWebProxySettingsLink("https://t.me:8443/webproxy?server=proxy.example.com&secret=\(secret)"))
        XCTAssertNil(parseWebProxySettingsLink("https://user@t.me/webproxy?server=proxy.example.com&secret=\(secret)"))
        XCTAssertNil(parseWebProxySettingsLink("tg://webproxy?server=proxy.example.com%2Fpath&secret=\(secret)"))
        XCTAssertNil(parseWebProxySettingsLink("tg://webproxy?server=proxy.example.com&secret=00"))

        let idna = try XCTUnwrap(parseWebProxySettingsLink("tg://webproxy?server=BÜCHER.example&secret=\(secret)"))
        XCTAssertEqual(idna.host, "xn--bcher-kva.example")
    }

    func testWebProxyLinkIsDistinguishableFromAnMtpLink() throws {
        let secret = "000102030405060708090a0b0c0d0e0f"
        let web = try XCTUnwrap(parseWebProxySettingsLink("tg://webproxy?server=proxy.example.com&secret=\(secret)"))
        guard case .web = web.connection else {
            return XCTFail("expected .web, got \(web.connection)")
        }
        // A regular proxy link must never resolve through the WEB parser.
        XCTAssertNil(parseWebProxySettingsLink("tg://proxy?server=proxy.example.com&port=443&secret=\(secret)"))
        XCTAssertNil(parseWebProxySettingsLink("https://t.me/proxy?server=proxy.example.com&port=443&secret=\(secret)"))
    }

    func testWebProxyLinkAcceptsADdPaddedSecret() throws {
        let secret = "dd000102030405060708090a0b0c0d0e0f"
        let web = try XCTUnwrap(parseWebProxySettingsLink("tg://webproxy?server=proxy.example.com&secret=\(secret)"))
        XCTAssertEqual(web.connection, .web(secret: Data([0xdd] + (0 ..< 16).map(UInt8.init))))
    }

    /// ANDROID.md: "`host` is accepted as a legacy input alias, but generated links
    /// always use `server`." Real deployments emit the `host` form.
    func testWebProxyLinkAcceptsHostAsALegacyAliasForServer() throws {
        let secret = "dddeb5753b0a4ee7043f5ad53c9da03cee"
        let viaHost = try XCTUnwrap(parseWebProxySettingsLink("https://t.me/webproxy?host=tproxy.remindbot.ai&secret=\(secret)"))
        XCTAssertEqual(viaHost.host, "tproxy.remindbot.ai")
        XCTAssertEqual(viaHost.port, 443)
        XCTAssertEqual(viaHost.connection, .web(secret: try XCTUnwrap(parseWebProxySecret(secret))))
        XCTAssertEqual(webProxySecretString(try XCTUnwrap(parseWebProxySecret(secret))), secret)

        let viaServer = try XCTUnwrap(parseWebProxySettingsLink("https://t.me/webproxy?server=tproxy.remindbot.ai&secret=\(secret)"))
        XCTAssertEqual(viaHost, viaServer)

        // tg:// form too.
        XCTAssertEqual(parseWebProxySettingsLink("tg://webproxy?host=tproxy.remindbot.ai&secret=\(secret)"), viaHost)

        // Emitted links still use `server`, never `host`.
        XCTAssertEqual(webProxySettingsLink(viaHost), "https://t.me/webproxy?server=tproxy.remindbot.ai&secret=\(secret)")

        // The alias must not loosen the strictness the other tests pin.
        XCTAssertNil(parseWebProxySettingsLink("https://t.me/webproxy?host=a.example.com&server=b.example.com&secret=\(secret)"))
        XCTAssertNil(parseWebProxySettingsLink("https://t.me/webproxy?host=a.example.com&host=b.example.com&secret=\(secret)"))
        XCTAssertNil(parseWebProxySettingsLink("https://t.me/webproxy?host=a.example.com&secret=\(secret)&extra=1"))
    }

    private func discriminator(_ connection: ProxyServerConnection) throws -> Int {
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(connection)) as? [String: Any])
        return try XCTUnwrap(object["_t"] as? Int)
    }
}
