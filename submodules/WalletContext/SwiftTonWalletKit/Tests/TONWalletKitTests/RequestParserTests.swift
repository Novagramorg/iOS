import XCTest
import TONCore
import TONCrypto
import TONConnect
@testable import TONWalletKit

/// Verifies that malformed and hostile requests are refused rather than coerced.
///
/// Every case here is a request a dApp could send that, if mishandled, would produce a
/// confirmation sheet showing the user something other than what they would be signing.
final class RequestParserTests: XCTestCase {
    private let walletA = WalletID("wallet-a")
    private let mainnet = "-239"
    private let testnet = "-3"

    private func session(domain: String? = "example.com") throws -> TONConnectSession {
        let crypto = try SessionCrypto()
        return TONConnectSession(
            id: "dapp-client-id",
            walletID: walletA,
            dApp: DAppInfo(
                manifestURL: "https://example.com/tonconnect-manifest.json",
                name: "Example",
                iconURL: nil,
                domain: domain
            ),
            sessionPublicKey: crypto.storedKeys.publicKey,
            sessionSecretKey: crypto.storedKeys.secretKey,
            bridgeURL: "https://bridge.example.com/bridge",
            createdAt: 1,
            lastActivityAt: 1
        )
    }

    /// Builds the double-encoded shape the protocol actually uses: `params` is an array of
    /// JSON *strings*, not objects.
    private func request(method: String, params: String) -> Data {
        Data(#"{"id":"42","method":"\#(method)","params":[\#(jsonString(params))]}"#.utf8)
    }

    private func jsonString(_ raw: String) -> String {
        String(decoding: try! JSONEncoder().encode(raw))
    }

    private func parse(
        method: String,
        params: String,
        network: String? = nil,
        domain: String? = "example.com"
    ) throws -> RequestParser.Parsed {
        RequestParser.parse(
            payload: request(method: method, params: params),
            session: try session(domain: domain),
            walletNetwork: network ?? mainnet
        )
    }

    private let validAddress = "0:0000000000000000000000000000000000000000000000000000000000000000"

    // MARK: - Happy path

    func testParsesSendTransaction() throws {
        let parsed = try parse(
            method: "sendTransaction",
            params: #"{"valid_until":1700000000,"messages":[{"address":"\#(validAddress)","amount":"1000000000"}]}"#
        )
        guard case .sendTransaction(let request) = parsed else {
            return XCTFail("expected sendTransaction, got \(parsed)")
        }
        XCTAssertEqual(request.id, "42")
        XCTAssertEqual(request.sessionID, "dapp-client-id")
        XCTAssertEqual(request.walletID, walletA)
        XCTAssertEqual(request.validUntil, 1_700_000_000)
        XCTAssertEqual(request.messages.count, 1)
        XCTAssertEqual(request.messages[0].amount, 1_000_000_000)
    }

    /// `signMessage` shares the payload shape but must never be parsed as a broadcastable
    /// transfer — approving one sends funds, approving the other does not.
    func testSignMessageIsADistinctCase() throws {
        let parsed = try parse(
            method: "signMessage",
            params: #"{"messages":[{"address":"\#(validAddress)","amount":"1"}]}"#
        )
        guard case .signMessage(let request) = parsed else {
            return XCTFail("expected signMessage, got \(parsed)")
        }
        XCTAssertEqual(request.messages.count, 1)
    }

    func testParsesDisconnect() throws {
        let payload = Data(#"{"id":"7","method":"disconnect","params":[]}"#.utf8)
        let parsed = RequestParser.parse(
            payload: payload,
            session: try session(),
            walletNetwork: mainnet
        )
        guard case .disconnect(let request) = parsed else {
            return XCTFail("expected disconnect, got \(parsed)")
        }
        XCTAssertEqual(request.id, "7")
        XCTAssertEqual(request.walletID, walletA)
    }

    func testUnknownMethodIsUnsupportedNotMalformed() throws {
        let payload = Data(#"{"id":"9","method":"summonDemon","params":[]}"#.utf8)
        let parsed = RequestParser.parse(payload: payload, session: try session(), walletNetwork: mainnet)
        guard case .unsupported(let id, let method) = parsed else {
            return XCTFail("expected unsupported, got \(parsed)")
        }
        XCTAssertEqual(id, "9")
        XCTAssertEqual(method, "summonDemon")
    }

    // MARK: - Refusals

    /// The case that spends real money if it goes wrong: the same key derives the same
    /// address on both networks, so a mainnet request approved as testnet is a real transfer.
    func testCrossNetworkRequestIsRefused() throws {
        let parsed = try parse(
            method: "sendTransaction",
            params: #"{"network":"-239","messages":[{"address":"\#(validAddress)","amount":"1"}]}"#,
            network: testnet
        )
        guard case .malformed(let malformed) = parsed else {
            return XCTFail("expected refusal, got \(parsed)")
        }
        XCTAssertTrue(malformed.reason.contains("-239"), malformed.reason)
        XCTAssertTrue(malformed.reason.contains("-3"), malformed.reason)
    }

    func testMatchingNetworkIsAccepted() throws {
        let parsed = try parse(
            method: "sendTransaction",
            params: #"{"network":"-3","messages":[{"address":"\#(validAddress)","amount":"1"}]}"#,
            network: testnet
        )
        guard case .sendTransaction = parsed else {
            return XCTFail("expected acceptance, got \(parsed)")
        }
    }

    func testEmptyMessageListIsRefused() throws {
        let parsed = try parse(method: "sendTransaction", params: #"{"messages":[]}"#)
        guard case .malformed(let malformed) = parsed else {
            return XCTFail("expected refusal, got \(parsed)")
        }
        XCTAssertTrue(malformed.reason.contains("no messages"), malformed.reason)
    }

    /// A rejected request still has to carry the dApp's id, or the dApp never learns the
    /// outcome and waits forever.
    func testRefusalPreservesTheRequestID() throws {
        let parsed = try parse(method: "sendTransaction", params: #"{"messages":[]}"#)
        guard case .malformed(let malformed) = parsed else {
            return XCTFail("expected refusal, got \(parsed)")
        }
        XCTAssertEqual(malformed.id, "42")
        XCTAssertEqual(malformed.sessionID, "dapp-client-id")
    }

    func testBadAddressIsRefused() throws {
        let parsed = try parse(
            method: "sendTransaction",
            params: #"{"messages":[{"address":"not-an-address","amount":"1"}]}"#
        )
        guard case .malformed(let malformed) = parsed else {
            return XCTFail("expected refusal, got \(parsed)")
        }
        XCTAssertTrue(malformed.reason.contains("Message 0"), malformed.reason)
    }

    /// Which message failed has to be identifiable — "one of your five messages is bad" is
    /// not a usable diagnostic.
    func testFailingMessageIsIdentifiedByIndex() throws {
        let good = #"{"address":"\#(validAddress)","amount":"1"}"#
        let parsed = try parse(
            method: "sendTransaction",
            params: #"{"messages":[\#(good),\#(good),{"address":"bad","amount":"1"}]}"#
        )
        guard case .malformed(let malformed) = parsed else {
            return XCTFail("expected refusal, got \(parsed)")
        }
        XCTAssertTrue(malformed.reason.contains("Message 2"), malformed.reason)
    }

    /// A non-numeric amount must not coerce to zero: the user would approve a sheet showing
    /// nothing being sent, for a message that is not what the dApp asked for.
    func testNonNumericAmountIsRefused() throws {
        for amount in ["", "abc", "1.5", "1e9", " 1"] {
            let parsed = try parse(
                method: "sendTransaction",
                params: #"{"messages":[{"address":"\#(validAddress)","amount":"\#(amount)"}]}"#
            )
            guard case .malformed = parsed else {
                return XCTFail("amount \(amount.debugDescription) should be refused, got \(parsed)")
            }
        }
    }

    func testNegativeAmountIsRefused() throws {
        let parsed = try parse(
            method: "sendTransaction",
            params: #"{"messages":[{"address":"\#(validAddress)","amount":"-1"}]}"#
        )
        guard case .malformed(let malformed) = parsed else {
            return XCTFail("expected refusal, got \(parsed)")
        }
        XCTAssertTrue(malformed.reason.contains("non-negative"), malformed.reason)
    }

    func testZeroAmountIsAllowed() throws {
        // A zero-value message is legitimate: it carries a payload to a contract.
        let parsed = try parse(
            method: "sendTransaction",
            params: #"{"messages":[{"address":"\#(validAddress)","amount":"0"}]}"#
        )
        guard case .sendTransaction(let request) = parsed else {
            return XCTFail("expected acceptance, got \(parsed)")
        }
        XCTAssertEqual(request.messages[0].amount, 0)
    }

    func testGarbagePayloadIsRefused() throws {
        let parsed = try parse(
            method: "sendTransaction",
            params: #"{"messages":[{"address":"\#(validAddress)","amount":"1","payload":"not base64 boc!!"}]}"#
        )
        guard case .malformed(let malformed) = parsed else {
            return XCTFail("expected refusal, got \(parsed)")
        }
        XCTAssertTrue(malformed.reason.contains("payload"), malformed.reason)
    }

    func testNonJSONPayloadIsRefused() throws {
        let parsed = RequestParser.parse(
            payload: Data("this is not json".utf8),
            session: try session(),
            walletNetwork: mainnet
        )
        guard case .malformed(let malformed) = parsed else {
            return XCTFail("expected refusal, got \(parsed)")
        }
        XCTAssertTrue(malformed.reason.contains("not a TON Connect request"), malformed.reason)
    }

    // MARK: - signData

    func testParsesTextSignData() throws {
        let parsed = try parse(method: "signData", params: #"{"type":"text","text":"hello"}"#)
        guard case .signData(let request) = parsed else {
            return XCTFail("expected signData, got \(parsed)")
        }
        XCTAssertEqual(request.payload, .text("hello"))
        XCTAssertEqual(request.domain, "example.com")
    }

    func testParsesBinarySignData() throws {
        let bytes = Data([1, 2, 3]).base64EncodedString()
        let parsed = try parse(method: "signData", params: #"{"type":"binary","bytes":"\#(bytes)"}"#)
        guard case .signData(let request) = parsed else {
            return XCTFail("expected signData, got \(parsed)")
        }
        XCTAssertEqual(request.payload, .binary(Data([1, 2, 3])))
    }

    func testParsesCellSignData() throws {
        let cell = Cell.empty.toBocBase64()
        let parsed = try parse(
            method: "signData",
            params: #"{"type":"cell","schema":"transfer#0f8a7ea5","cell":"\#(cell)"}"#
        )
        guard case .signData(let request) = parsed else {
            return XCTFail("expected signData, got \(parsed)")
        }
        guard case .cell(let schema, _) = request.payload else {
            return XCTFail("expected a cell payload")
        }
        XCTAssertEqual(schema, "transfer#0f8a7ea5")
    }

    /// The domain a signature binds to must come from the manifest. A session with no
    /// verified domain cannot produce a meaningful `signData` signature, so the request has
    /// to be refused rather than signed against an empty or dApp-chosen domain.
    func testSignDataWithoutAManifestDomainIsRefused() throws {
        for domain in [nil, ""] as [String?] {
            let parsed = try parse(
                method: "signData",
                params: #"{"type":"text","text":"hello"}"#,
                domain: domain
            )
            guard case .malformed(let malformed) = parsed else {
                return XCTFail("domain \(String(describing: domain)) should be refused, got \(parsed)")
            }
            XCTAssertTrue(malformed.reason.contains("domain"), malformed.reason)
        }
    }

    /// The domain is never read from the request, even when the dApp supplies one. Otherwise
    /// a dApp could obtain a signature that verifies against a domain it does not own.
    func testSignDataIgnoresARequestSuppliedDomain() throws {
        let parsed = try parse(
            method: "signData",
            params: #"{"type":"text","text":"hello","domain":"attacker.com","from":"0:0"}"#
        )
        guard case .signData(let request) = parsed else {
            return XCTFail("expected signData, got \(parsed)")
        }
        XCTAssertEqual(request.domain, "example.com", "the manifest domain must win")
    }

    func testUnknownSignDataTypeIsRefused() throws {
        let parsed = try parse(method: "signData", params: #"{"type":"jpeg","text":"hello"}"#)
        guard case .malformed(let malformed) = parsed else {
            return XCTFail("expected refusal, got \(parsed)")
        }
        XCTAssertTrue(malformed.reason.contains("jpeg"), malformed.reason)
    }

    func testSignDataMissingItsContentIsRefused() throws {
        let cases = [
            #"{"type":"text"}"#,
            #"{"type":"binary"}"#,
            #"{"type":"binary","bytes":"not base64!!!"}"#,
            #"{"type":"cell","schema":"x"}"#,
            #"{"type":"cell","cell":"\#(Cell.empty.toBocBase64())"}"#,
        ]
        for params in cases {
            let parsed = try parse(method: "signData", params: params)
            guard case .malformed = parsed else {
                return XCTFail("\(params) should be refused, got \(parsed)")
            }
        }
    }

    // MARK: - Message conversion

    // MARK: - Bounce

    /// A non-bounceable friendly address must stay non-bounceable.
    ///
    /// This is how a dApp funds an address with no contract yet. Forcing bounce on makes the
    /// message bounce off the undeployed account and the transfer fails — so the flag the
    /// sender chose has to survive parsing.
    func testNonBounceableFriendlyAddressIsHonoured() throws {
        // Same account, two forms: UQ… is non-bounceable, EQ… is bounceable.
        let nonBounceable = "0QC9DvTRGwquDoy7o6ixlPuvx_GrRT81MbLy9b_mM6m2FdKg"
        let parsed = try parse(
            method: "sendTransaction",
            params: #"{"messages":[{"address":"\#(nonBounceable)","amount":"1"}]}"#
        )
        guard case .sendTransaction(let request) = parsed else {
            return XCTFail("expected acceptance, got \(parsed)")
        }
        XCTAssertFalse(request.messages[0].bounce)

        guard case .internalMessage(let info) = request.messages[0].toMessageRelaxed().info else {
            return XCTFail("expected an internal message")
        }
        XCTAssertFalse(info.bounce, "the flag must reach the signed message, not just the model")
    }

    func testBounceableFriendlyAddressStaysBounceable() throws {
        let bounceable = "kQC9DvTRGwquDoy7o6ixlPuvx_GrRT81MbLy9b_mM6m2FY9l"
        let parsed = try parse(
            method: "sendTransaction",
            params: #"{"messages":[{"address":"\#(bounceable)","amount":"1"}]}"#
        )
        guard case .sendTransaction(let request) = parsed else {
            return XCTFail("expected acceptance, got \(parsed)")
        }
        XCTAssertTrue(request.messages[0].bounce)
    }

    /// The raw form carries no flag, so value must come back from a typo'd address.
    func testRawAddressDefaultsToBounceable() throws {
        let parsed = try parse(
            method: "sendTransaction",
            params: #"{"messages":[{"address":"\#(validAddress)","amount":"1"}]}"#
        )
        guard case .sendTransaction(let request) = parsed else {
            return XCTFail("expected acceptance, got \(parsed)")
        }
        XCTAssertTrue(request.messages[0].bounce)
    }

    /// The convenience initialiser must apply the same rule as the parser, or a host app
    /// building a transfer directly gets different behaviour from a dApp-driven one.
    func testAddressStringInitialiserHonoursTheFlag() throws {
        let fromNonBounceable = try TransferMessage(
            addressString: "0QC9DvTRGwquDoy7o6ixlPuvx_GrRT81MbLy9b_mM6m2FdKg",
            amount: 1
        )
        XCTAssertFalse(fromNonBounceable.bounce)

        let fromBounceable = try TransferMessage(
            addressString: "kQC9DvTRGwquDoy7o6ixlPuvx_GrRT81MbLy9b_mM6m2FY9l",
            amount: 1
        )
        XCTAssertTrue(fromBounceable.bounce)

        let fromRaw = try TransferMessage(addressString: validAddress, amount: 1)
        XCTAssertTrue(fromRaw.bounce)

        // All three must land on the same account regardless of form.
        XCTAssertEqual(fromNonBounceable.address, fromBounceable.address)
    }

    /// The relaxed message must be bounceable by default, or a transfer to a typo'd address
    /// burns the funds instead of returning them.
    func testTransfersAreBounceableByDefault() throws {
        let message = TransferMessage(address: try Address.parse(validAddress), amount: 5)
        let relaxed = message.toMessageRelaxed()
        guard case .internalMessage(let info) = relaxed.info else {
            return XCTFail("expected an internal message")
        }
        XCTAssertTrue(info.bounce)
        XCTAssertEqual(info.value.coins, 5)
        XCTAssertEqual(info.dest, try Address.parse(validAddress))
    }

    func testExtraCurrencyIsCarriedThrough() throws {
        let parsed = try parse(
            method: "sendTransaction",
            params: #"{"messages":[{"address":"\#(validAddress)","amount":"1","extra_currency":{"239":"100"}}]}"#
        )
        guard case .sendTransaction(let request) = parsed else {
            return XCTFail("expected acceptance, got \(parsed)")
        }
        XCTAssertEqual(request.messages[0].extraCurrency, [239: 100])

        let relaxed = request.messages[0].toMessageRelaxed()
        guard case .internalMessage(let info) = relaxed.info else {
            return XCTFail("expected an internal message")
        }
        XCTAssertEqual(info.value.other[239], 100)
    }

    func testMalformedExtraCurrencyIsRefused() throws {
        for extra in [#"{"abc":"100"}"#, #"{"239":"abc"}"#] {
            let parsed = try parse(
                method: "sendTransaction",
                params: #"{"messages":[{"address":"\#(validAddress)","amount":"1","extra_currency":\#(extra)}]}"#
            )
            guard case .malformed = parsed else {
                return XCTFail("\(extra) should be refused, got \(parsed)")
            }
        }
    }
}
