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
        let settings = ProxyServerSettings(host: "proxy.example.com", port: 8443, connection: .web(secret: secret, path: ""))
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

    func testWebProxyWithBasePathUsesItsOwnDiscriminator() throws {
        let secret = Data((0 ..< 16).map(UInt8.init))
        let rooted = ProxyServerSettings(host: "proxy.example.com", port: 443, connection: .web(secret: secret, path: ""))
        let prefixed = ProxyServerSettings(host: "proxy.example.com", port: 443, connection: .web(secret: secret, path: "dobry-cola-super-app"))

        XCTAssertEqual(try discriminator(prefixed.connection), 3)
        XCTAssertNotEqual(rooted, prefixed)
        XCTAssertNotEqual(prefixed, ProxyServerSettings(host: "proxy.example.com", port: 443, connection: .web(secret: secret, path: "other-app")))

        let data = try JSONEncoder().encode(prefixed)
        XCTAssertEqual(try JSONDecoder().decode(ProxyServerSettings.self, from: data), prefixed)
        XCTAssertEqual(prefixed.port, 443)
        XCTAssertEqual(prefixed.webProxyAddress, "proxy.example.com/dobry-cola-super-app")
        XCTAssertEqual(rooted.webProxyAddress, "proxy.example.com")

        let legacy = Data(#"{"_t":2,"secret":"AAECAwQFBgcICQoLDA0ODw=="}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(ProxyServerConnection.self, from: legacy), .web(secret: secret, path: ""))

        XCTAssertEqual(prefixed.mtProxySettings.ip, "proxy.example.com")
        XCTAssertEqual(prefixed.mtProxySettings.port, 443)
    }

    func testWebProxyValidationAndNormalization() throws {
        let settings = try XCTUnwrap(makeWebProxySettings(address: "PROXY.EXAMPLE.COM", secret: "000102030405060708090a0b0c0d0e0f"))
        XCTAssertEqual(settings.host, "proxy.example.com")
        XCTAssertEqual(settings.port, 443)
        XCTAssertNil(makeWebProxySettings(address: "proxy.example.com:8443", secret: "000102030405060708090a0b0c0d0e0f"))
        XCTAssertNil(makeWebProxySettings(address: "proxy.example.com", secret: "00"))

        let prefixed = try XCTUnwrap(makeWebProxySettings(address: "Proxy.Example.COM/My-App/", secret: "000102030405060708090a0b0c0d0e0f"))
        XCTAssertEqual(prefixed.host, "proxy.example.com")
        XCTAssertEqual(prefixed.webProxyAddress, "proxy.example.com/My-App")
        XCTAssertNil(makeWebProxySettings(address: "proxy.example.com//My-App", secret: "000102030405060708090a0b0c0d0e0f"))
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
        XCTAssertNil(parseWebProxySettingsLink("tg://webproxy?server=proxy.example.com%2F%2Fpath&secret=\(secret)"))
        XCTAssertNil(parseWebProxySettingsLink("tg://webproxy?server=proxy.example.com%2Fpa.th&secret=\(secret)"))
        XCTAssertNil(parseWebProxySettingsLink("tg://webproxy?server=proxy.example.com&secret=00"))

        let idna = try XCTUnwrap(parseWebProxySettingsLink("tg://webproxy?server=BÜCHER.example&secret=\(secret)"))
        XCTAssertEqual(idna.host, "xn--bcher-kva.example")
    }

    func testWebProxyLinksCarryTheBasePath() throws {
        let secret = "000102030405060708090a0b0c0d0e0f"
        let settings = try XCTUnwrap(parseWebProxySettingsLink("tg://webproxy?server=PROXY.EXAMPLE.COM%2Fdobry-cola-super-app&secret=\(secret)"))
        XCTAssertEqual(settings.webProxyAddress, "proxy.example.com/dobry-cola-super-app")
        XCTAssertEqual(settings.port, 443)
        XCTAssertEqual(
            webProxySettingsLink(settings),
            "https://t.me/webproxy?server=proxy.example.com%2Fdobry-cola-super-app&secret=\(secret)"
        )
        XCTAssertEqual(parseWebProxySettingsLink(try XCTUnwrap(webProxySettingsLink(settings))), settings)

        let cased = try XCTUnwrap(parseWebProxySettingsLink("tg://webproxy?server=proxy.example.com%2FMy-App&secret=\(secret)"))
        XCTAssertEqual(cased.webProxyAddress, "proxy.example.com/My-App")
        XCTAssertNotEqual(cased, settings)
    }

    private func discriminator(_ connection: ProxyServerConnection) throws -> Int {
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(connection)) as? [String: Any])
        return try XCTUnwrap(object["_t"] as? Int)
    }
}
