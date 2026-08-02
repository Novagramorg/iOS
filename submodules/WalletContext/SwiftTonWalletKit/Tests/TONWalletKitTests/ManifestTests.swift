import XCTest
@testable import TONWalletKit

/// Verifies manifest validation.
///
/// A manifest is a dApp's whole identity: the name on the sheet, the domain a signature binds
/// to. Accepting a bad one means the user approves something attributed to the wrong party.
final class ManifestTests: XCTestCase {
    // MARK: - Host validation

    func testValidHosts() {
        for host in ["example.com", "sub.example.com", "a.b.c.d", "xn--80ak6aa92e.com"] {
            XCTAssertTrue(isValidManifestHost(host), host)
        }
    }

    /// A single-label host cannot be recognised by a user as belonging to anyone, and
    /// `localhost` in particular would let a dApp claim to be the wallet's own machine.
    func testRejectedHosts() {
        for host in ["localhost", "", ".", ".com", "example.", "a..b", "example"] {
            XCTAssertFalse(isValidManifestHost(host), host)
        }
    }

    // MARK: - Decoding

    private func decode(_ json: String) -> Result<DAppManifest, ManifestFailure> {
        URLSessionManifestFetcher.decode(Data(json.utf8))
    }

    func testDecodesAValidManifest() throws {
        let result = decode("""
        {"url":"https://example.com","name":"Example dApp","iconUrl":"https://example.com/icon.png"}
        """)
        let manifest = try result.get()
        XCTAssertEqual(manifest.name, "Example dApp")
        XCTAssertEqual(manifest.host, "example.com")
    }

    func testExtraFieldsAreIgnored() throws {
        let result = decode("""
        {"url":"https://example.com","name":"Example","somethingNew":{"nested":true}}
        """)
        XCTAssertNoThrow(try result.get())
    }

    func testWhitespaceIsTrimmed() throws {
        let manifest = try decode(#"{"url":" https://example.com ","name":"  Example  "}"#).get()
        XCTAssertEqual(manifest.name, "Example")
        XCTAssertEqual(manifest.url, "https://example.com")
    }

    /// A nameless dApp gives the user nothing to recognise on the sheet.
    func testNamelessManifestIsRejected() {
        for json in [#"{"url":"https://example.com","name":""}"#, #"{"url":"https://example.com","name":"   "}"#] {
            guard case .failure(let failure) = decode(json) else {
                return XCTFail("\(json) should be rejected")
            }
            XCTAssertEqual(failure.connectErrorCode, .manifestContent)
        }
    }

    func testMissingRequiredFieldsAreRejected() {
        for json in [#"{"name":"Example"}"#, #"{"url":"https://example.com"}"#, "{}", "not json"] {
            guard case .failure = decode(json) else {
                return XCTFail("\(json) should be rejected")
            }
        }
    }

    /// The `url` field — not the manifest URL — is what a signature binds to. A manifest
    /// served from a real domain but claiming an unusable `url` must not yield a proof the
    /// user cannot interpret.
    func testManifestURLFieldMustBeADomain() {
        for url in ["not-a-url", "https://localhost", "https://localhost:3000", "file:///etc/passwd", ""] {
            guard case .failure(let failure) = decode(#"{"url":"\#(url)","name":"Example"}"#) else {
                return XCTFail("url \(url.debugDescription) should be rejected")
            }
            XCTAssertEqual(failure.connectErrorCode, .manifestContent)
        }
    }

    // MARK: - Fetch-level validation

    /// A plaintext manifest can be swapped in transit, which means a dApp's identity could be
    /// substituted on a hostile network.
    func testHTTPManifestIsRejected() async {
        let fetcher = URLSessionManifestFetcher()
        guard case .failure(let failure) = await fetcher.fetch(manifestURL: "http://example.com/m.json") else {
            return XCTFail("http should be rejected")
        }
        XCTAssertEqual(failure.connectErrorCode, .manifestNotFound)
        XCTAssertTrue(failure.reason.contains("https"), failure.reason)
    }

    func testUnparseableURLIsNotFoundRatherThanBadContent() async {
        let fetcher = URLSessionManifestFetcher()
        // Distinguishing the two matters to a dApp author debugging an integration: one means
        // "fix your URL", the other means "fix your JSON".
        guard case .failure(let failure) = await fetcher.fetch(manifestURL: "://////") else {
            return XCTFail("garbage should be rejected")
        }
        XCTAssertEqual(failure.connectErrorCode, .manifestNotFound)
    }

    func testNonDomainHostIsRejectedBeforeAnyRequest() async {
        let fetcher = URLSessionManifestFetcher()
        guard case .failure(let failure) = await fetcher.fetch(manifestURL: "https://localhost/m.json") else {
            return XCTFail("localhost should be rejected")
        }
        XCTAssertEqual(failure.connectErrorCode, .manifestNotFound)
    }

    // MARK: - Preview

    /// A dApp whose manifest failed must be presented as unverified, not as a blank but
    /// trustworthy-looking entry.
    func testPreviewReportsAnUnusableManifest() {
        let preview = DAppPreview(
            manifestURL: "https://example.com/m.json",
            manifest: nil,
            manifestFailure: .invalidContent(reason: "HTTP 404")
        )
        XCTAssertFalse(preview.isVerified)
        XCTAssertNil(preview.domain)
        XCTAssertNil(preview.name)
    }

    func testPreviewExposesTheManifestDomain() {
        let preview = DAppPreview(
            manifestURL: "https://example.com/m.json",
            manifest: DAppManifest(url: "https://app.example.com", name: "Example"),
            manifestFailure: nil
        )
        XCTAssertTrue(preview.isVerified)
        XCTAssertEqual(preview.domain, "app.example.com")
        XCTAssertEqual(preview.info.domain, "app.example.com")
    }
}
