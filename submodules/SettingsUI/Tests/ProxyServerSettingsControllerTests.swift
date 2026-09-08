import XCTest
import TelegramCore
@testable import SettingsUI

final class ProxyServerSettingsControllerTests: XCTestCase {
    private let secretHex = "000102030405060708090a0b0c0d0e0f"

    private var webSecret: Data {
        return Data((0 ..< 16).map(UInt8.init))
    }

    func testModeDerivationCoversEveryConnection() {
        XCTAssertEqual(proxyServerSettingsControllerMode(for: .socks5(username: "u", password: "p")), .socks5)
        XCTAssertEqual(proxyServerSettingsControllerMode(for: .mtp(secret: Data(repeating: 1, count: 16))), .mtp)
        XCTAssertEqual(proxyServerSettingsControllerMode(for: .web(secret: self.webSecret)), .web)
    }

    /// Regression: a saved WEB server used to load as .mtp and be rewritten to .mtp on save.
    func testEditingAWebServerWithoutChangesPreservesIt() throws {
        let original = ProxyServerSettings(host: "proxy.example.com", port: 443, connection: .web(secret: self.webSecret))
        let state = ProxyServerSettingsControllerState(
            mode: proxyServerSettingsControllerMode(for: original.connection),
            host: original.host,
            port: "\(original.port)",
            username: "",
            password: "",
            secret: webProxySecretString(self.webSecret)
        )
        let saved = try XCTUnwrap(proxyServerSettings(with: state))
        XCTAssertEqual(saved, original)
        XCTAssertEqual(saved.connection, .web(secret: self.webSecret))
    }

    func testWebModeIgnoresPortAndPinsIt() throws {
        let state = ProxyServerSettingsControllerState(mode: .web, host: "proxy.example.com", port: "", username: "", password: "", secret: self.secretHex)
        XCTAssertTrue(state.isComplete)
        let saved = try XCTUnwrap(proxyServerSettings(with: state))
        XCTAssertEqual(saved.port, 443)
    }

    func testWebModeNormalizesTheHost() throws {
        let state = ProxyServerSettingsControllerState(mode: .web, host: "PROXY.EXAMPLE.COM", port: "", username: "", password: "", secret: self.secretHex)
        let saved = try XCTUnwrap(proxyServerSettings(with: state))
        XCTAssertEqual(saved.host, "proxy.example.com")
    }

    func testWebModeAcceptsADdPaddedSecret() throws {
        let state = ProxyServerSettingsControllerState(mode: .web, host: "proxy.example.com", port: "", username: "", password: "", secret: "dd" + self.secretHex)
        XCTAssertTrue(state.isComplete)
        XCTAssertNotNil(proxyServerSettings(with: state))
    }

    /// MTProxySecret.parse accepts these; WebProxyConfiguration.isValidSecret does not.
    func testWebModeRejectsSecretsTheTransportCannotUse() {
        for secret in ["ee" + self.secretHex, "00", ""] {
            let state = ProxyServerSettingsControllerState(mode: .web, host: "proxy.example.com", port: "", username: "", password: "", secret: secret)
            XCTAssertFalse(state.isComplete, "expected \(secret) to be rejected")
            XCTAssertNil(proxyServerSettings(with: state))
        }
    }

    func testWebModeRejectsNonCanonicalHosts() {
        for host in ["proxy.example.com:8443", "user@proxy.example.com", "127.0.0.1", ""] {
            let state = ProxyServerSettingsControllerState(mode: .web, host: host, port: "", username: "", password: "", secret: self.secretHex)
            XCTAssertFalse(state.isComplete, "expected \(host) to be rejected")
            XCTAssertNil(proxyServerSettings(with: state))
        }
    }

    func testSocks5AndMtpModesStillRequireAPort() {
        let socks = ProxyServerSettingsControllerState(mode: .socks5, host: "proxy.example.com", port: "", username: "u", password: "p", secret: "")
        XCTAssertFalse(socks.isComplete)
        let mtp = ProxyServerSettingsControllerState(mode: .mtp, host: "proxy.example.com", port: "", username: "", password: "", secret: self.secretHex)
        XCTAssertFalse(mtp.isComplete)
    }

    func testMtpModeIsUnaffected() throws {
        let state = ProxyServerSettingsControllerState(mode: .mtp, host: "proxy.example.com", port: "443", username: "", password: "", secret: self.secretHex)
        let saved = try XCTUnwrap(proxyServerSettings(with: state))
        XCTAssertEqual(saved.host, "proxy.example.com")
        XCTAssertEqual(saved.port, 443)
        guard case .mtp = saved.connection else {
            return XCTFail("expected .mtp, got \(saved.connection)")
        }
    }
}
