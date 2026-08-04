import XCTest
import TONTestVectors
import TONCore
@testable import TONToncenter

/// Exercises the client against **real recorded Toncenter responses** on both networks.
///
/// These fixtures are what caught the reference's `trace_external_hash` bug, so the
/// tests below deliberately assert the shapes that broke it.
final class ClientFixtureTests: XCTestCase {
    private func client(_ network: String) throws -> ToncenterClient {
        ToncenterClient(
            network: network == "mainnet" ? .mainnet : .testnet,
            transport: try FixtureTransport(network: network)
        )
    }

    private let networks = ["mainnet", "testnet"]

    // MARK: - Masterchain

    func testMasterchainInfoDecodesOnBothNetworks() async throws {
        for network in networks {
            let info = try await client(network).getMasterchainInfo()
            XCTAssertEqual(info.workchain, -1, "masterchain is workchain -1 (\(network))")
            XCTAssertGreaterThan(info.seqno, 0, "seqno should be populated (\(network))")
            XCTAssertEqual(info.shard, "8000000000000000")
            // Hashes arrive base64 and must be exposed as 0x-prefixed hex.
            XCTAssertTrue(info.rootHash.hasPrefix("0x"), "root hash should be hex (\(network))")
            XCTAssertEqual(info.rootHash.count, 66, "32 bytes as 0x-hex")
            XCTAssertEqual(info.fileHash.count, 66)
        }
    }

    /// The exact mapping the reference produced for the recorded response.
    func testMasterchainInfoMatchesRecordedMapping() async throws {
        let raw = try Vectors.rawFixture("toncenter/mainnet/masterchain-info")
        let recorded = try JSONDecoder().decode(RecordedFile<RecordedMasterchain>.self, from: raw)
        let expected = try XCTUnwrap(recorded.fixtures.first?.mapped)

        let info = try await client("mainnet").getMasterchainInfo()
        XCTAssertEqual(info.workchain, expected.workchain)
        XCTAssertEqual(info.seqno, expected.seqno)
        XCTAssertEqual(info.shard, expected.shard)
        XCTAssertEqual(info.rootHash, expected.rootHash)
        XCTAssertEqual(info.fileHash, expected.fileHash)
    }

    // MARK: - Account state

    func testAccountStateDecodesActiveAccount() async throws {
        let raw = try Vectors.rawFixture("toncenter/mainnet/account-state")
        let recorded = try JSONDecoder().decode(RecordedFile<RecordedAccountState>.self, from: raw)
        let active = try XCTUnwrap(recorded.fixtures.first { $0.label == "active" })
        let expected = try XCTUnwrap(active.mapped)
        let address = try XCTUnwrap(active.args.address)

        let state = try await client("mainnet").getAccountState(address: address)

        XCTAssertEqual(state.address, expected.address, "canonical address form")
        XCTAssertEqual(state.status.rawValue, expected.status)
        XCTAssertEqual(state.rawBalance, expected.rawBalance)
        XCTAssertEqual(state.balance, expected.balance, "formatted TON balance")
        XCTAssertNotNil(state.code, "an active account has code")
        XCTAssertNotNil(state.data)
        XCTAssertEqual(state.lastTransaction?.hash, expected.lastTransaction?.hash)
        XCTAssertEqual(state.lastTransaction?.logicalTime, expected.lastTransaction?.lt)
        XCTAssertTrue(state.isDeployed)
    }

    /// An account the chain has never seen must yield a state, not an error.
    ///
    /// Note the asymmetry the recorded fixtures revealed: `addressInformation` reports
    /// such an address as **`uninit`**, while the batched `accountStates` endpoint omits
    /// it from the response entirely — which is why the batch mapper synthesizes a
    /// `.nonExisting` entry. Either way, callers get a state and never a nil.
    ///
    /// Serves the recorded body for this specific case rather than relying on replay
    /// order, which would otherwise hand back whichever `addressInformation` response was
    /// recorded first.
    func testUnseenAccountReturnsStateNotError() async throws {
        let raw = try Vectors.rawFixture("toncenter/mainnet/account-state")
        let recorded = try JSONDecoder().decode(RecordedFile<RecordedAccountState>.self, from: raw)
        let fixture = try XCTUnwrap(recorded.fixtures.first { $0.label == "non-existing" })
        let address = try XCTUnwrap(fixture.args.address)
        let expected = try XCTUnwrap(fixture.mapped)

        let body = try XCTUnwrap(rawBody(forLabel: "non-existing", in: raw))
        let client = ToncenterClient(
            network: .mainnet,
            transport: SingleResponseTransport(
                response: TransportResponse(status: 200, body: body)
            )
        )

        let state = try await client.getAccountState(address: address)
        XCTAssertEqual(state.status.rawValue, expected.status, "status must match the reference")
        XCTAssertEqual(
            state.status,
            .uninitialized,
            "addressInformation reports an unseen address as uninit, not non-existing"
        )
        XCTAssertFalse(state.isDeployed, "an uninitialized account is not deployed")
        XCTAssertNil(state.code, "no code for an account the chain has never seen")
        XCTAssertEqual(state.rawBalance, expected.rawBalance)
        XCTAssertEqual(state.balance, expected.balance)
    }

    /// Pulls one fixture's recorded HTTP body out of a fixture file.
    private func rawBody(forLabel label: String, in fileData: Data) throws -> Data? {
        guard
            let root = try JSONSerialization.jsonObject(with: fileData) as? [String: Any],
            let fixtures = root["fixtures"] as? [[String: Any]],
            let fixture = fixtures.first(where: { $0["label"] as? String == label }),
            let requests = fixture["requests"] as? [[String: Any]],
            let body = requests.first?["body"]
        else { return nil }
        return try JSONSerialization.data(withJSONObject: body)
    }

    func testBalanceFormatting() {
        // The mapped `balance` is the nanoton count rendered as TON.
        XCTAssertEqual(Mappers.formatBalance("78263996093"), "78.263996093")
        XCTAssertEqual(Mappers.formatBalance("1000000000"), "1")
        XCTAssertEqual(Mappers.formatBalance("0"), "0")
        XCTAssertEqual(Mappers.formatBalance(""), "0", "an empty balance is zero, not a crash")
        XCTAssertEqual(Mappers.formatBalance("-5"), "0", "a negative balance clamps to zero")
    }

    // MARK: - Batched account states

    /// The contract that every requested address gets an entry, including ones the chain
    /// has never seen.
    func testAccountStatesGuaranteesAnEntryPerRequestedAddress() async throws {
        let raw = try Vectors.rawFixture("toncenter/mainnet/account-states")
        let recorded = try JSONDecoder().decode(RecordedFile<[String: RecordedAccountState.Mapped]>.self, from: raw)
        let fixture = try XCTUnwrap(recorded.fixtures.first)
        let requested = try XCTUnwrap(fixture.args.addresses)

        let states = try await client("mainnet").getAccountStates(addresses: requested)

        XCTAssertEqual(states.count, requested.count, "one entry per requested address")
        for address in requested {
            let canonical = try Mappers.canonical(address: address)
            XCTAssertNotNil(states[canonical], "missing entry for \(address)")
        }
        // The recorded mapping had a mix of active and non-existing.
        XCTAssertTrue(states.values.contains { $0.status == .nonExisting })
    }

    func testEmptyAddressListShortCircuits() async throws {
        let states = try await client("mainnet").getAccountStates(addresses: [])
        XCTAssertTrue(states.isEmpty)
    }

    // MARK: - Get-method

    func testGetMethodDecodesStackAndExitCode() async throws {
        let raw = try Vectors.rawFixture("toncenter/mainnet/get-method")
        let recorded = try JSONDecoder().decode(RecordedFile<RecordedGetMethod>.self, from: raw)

        // Recorded in order: seqno, get_public_key, then a nonexistent method.
        let seqnoFixture = try XCTUnwrap(recorded.fixtures.first { $0.label == "seqno" })
        let expected = try XCTUnwrap(seqnoFixture.mapped)
        let address = try XCTUnwrap(seqnoFixture.args.address)

        let result = try await client("mainnet").runGetMethod(
            address: address,
            method: "seqno",
            stack: []
        )
        XCTAssertEqual(result.exitCode, expected.exitCode)
        XCTAssertEqual(result.gasUsed, expected.gasUsed)
        XCTAssertTrue(result.isSuccess)

        // The stack must decode into a usable integer.
        var reader = try result.reader()
        let seqno = try reader.readBigInt()
        XCTAssertGreaterThanOrEqual(seqno, 0)
    }

    /// A failing get-method must not hand back a stack that looks usable.
    func testFailedGetMethodRefusesToProduceAReader() throws {
        let failed = GetMethodResult(exitCode: 11, gasUsed: 0, stack: [.num("0x11247")])
        XCTAssertFalse(failed.isSuccess)
        XCTAssertThrowsError(try failed.reader()) { error in
            guard case ToncenterError.unexpectedResponse = error else {
                return XCTFail("expected unexpectedResponse, got \(error)")
            }
        }
    }

    /// Exit code 11 is what a missing method returns; it is recorded in the fixtures.
    func testRecordedNonexistentMethodHasNonZeroExitCode() throws {
        let raw = try Vectors.rawFixture("toncenter/mainnet/get-method")
        let recorded = try JSONDecoder().decode(RecordedFile<RecordedGetMethod>.self, from: raw)
        let fixture = try XCTUnwrap(recorded.fixtures.first { $0.label == "nonexistent-method" })
        XCTAssertNotEqual(fixture.mapped?.exitCode, 0)
    }

    // MARK: - Transactions: the reference's broken path

    /// **The regression this whole fixture suite exists for.**
    ///
    /// Toncenter v3 stopped returning `trace_external_hash`. The reference dereferences
    /// it unguarded and throws for any account with history — one ordinary transaction is
    /// enough. Our mapper must treat it as optional and map the transaction anyway.
    func testTransactionsMapDespiteMissingTraceExternalHash() async throws {
        for network in networks {
            let page = try await client(network).getTransactions(
                address: "0:dededededededededededededededededededededededededededededededede",
                limit: 5,
                offset: 0
            )
            // The recorded responses for these paths contain real transactions on at
            // least one network; the point is that mapping does not throw.
            for tx in page.transactions {
                XCTAssertTrue(tx.hash.hasPrefix("0x"), "hash should be hex (\(network))")
                XCTAssertNil(
                    tx.traceExternalHash,
                    "the server no longer sends this field, so it must map to nil"
                )
            }
        }
    }

    // MARK: - Compute-phase skips

    /// A transfer to an address with no code must not read as failed.
    ///
    /// TON skips the compute phase with reason `no_state` and sets `aborted`, because there is
    /// nothing to execute — but the inbound value is still credited. Reading `aborted` alone
    /// made every transfer to an undeployed address look like a failure, which surfaced to the
    /// user as "this will fail" when funding a fresh wallet. Found by an on-chain top-up whose
    /// emulation was rejected by our own gate even though the money would have arrived.
    func testNoStateComputeSkipIsNotAFailure() throws {
        let json: [String: Any] = [
            "transactions": [
                [
                    "account": "0:5513c6035d5422d37ec8b94cd1f4441b2536f5ae6009b5a690a61ed21fac299e",
                    "hash": "PZN0ti+X5r3ZbAycxzr+t96pPbXhl3p7dqMxnqWVIuk=",
                    "lt": "1",
                    "now": 1_700_000_000,
                    // Exactly the shape the emulator returns for value sent to a codeless
                    // account: aborted, with a skipped compute phase and no exit code.
                    "description": [
                        "type": "ordinary",
                        "aborted": true,
                        "compute_ph": ["skipped": true, "reason": "no_state"],
                    ],
                    "out_msgs": [],
                ]
            ],
            "address_book": [:],
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let wire = try JSONDecoder().decode(Wire.TransactionsResponse.self, from: data)
        let tx = Mappers.transactions(wire).transactions[0]

        XCTAssertTrue(tx.aborted, "the chain really does mark it aborted")
        XCTAssertEqual(tx.computeSkipReason, .noState)
        XCTAssertFalse(tx.isFailed, "value was delivered; this is not a failure")
        XCTAssertTrue(tx.deliveredWithoutCode, "callers need to distinguish this case")
    }

    /// `no_gas` is a genuine failure and must stay one — the suppression above is specific to
    /// `no_state`, not to skipped phases in general.
    func testNoGasComputeSkipIsStillAFailure() throws {
        let json: [String: Any] = [
            "transactions": [
                [
                    "account": "0:5513c6035d5422d37ec8b94cd1f4441b2536f5ae6009b5a690a61ed21fac299e",
                    "hash": "PZN0ti+X5r3ZbAycxzr+t96pPbXhl3p7dqMxnqWVIuk=",
                    "lt": "1",
                    "now": 1_700_000_000,
                    "description": [
                        "type": "ordinary",
                        "aborted": true,
                        "compute_ph": ["skipped": true, "reason": "no_gas"],
                    ],
                    "out_msgs": [],
                ]
            ],
            "address_book": [:],
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let wire = try JSONDecoder().decode(Wire.TransactionsResponse.self, from: data)
        let tx = Mappers.transactions(wire).transactions[0]

        XCTAssertEqual(tx.computeSkipReason, .noGas)
        XCTAssertTrue(tx.isFailed)
        XCTAssertFalse(tx.deliveredWithoutCode)
    }

    /// An unrecognised reason must not read as benign.
    ///
    /// A future TVM reason mapping to nil would fall through to the `aborted` check, which is
    /// the safe direction: report failure rather than quietly approve.
    func testUnknownComputeSkipReasonIsTreatedAsFailure() throws {
        let json: [String: Any] = [
            "transactions": [
                [
                    "account": "0:5513c6035d5422d37ec8b94cd1f4441b2536f5ae6009b5a690a61ed21fac299e",
                    "hash": "PZN0ti+X5r3ZbAycxzr+t96pPbXhl3p7dqMxnqWVIuk=",
                    "lt": "1",
                    "now": 1_700_000_000,
                    "description": [
                        "type": "ordinary",
                        "aborted": true,
                        "compute_ph": ["skipped": true, "reason": "some_future_reason"],
                    ],
                    "out_msgs": [],
                ]
            ],
            "address_book": [:],
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let wire = try JSONDecoder().decode(Wire.TransactionsResponse.self, from: data)
        let tx = Mappers.transactions(wire).transactions[0]

        XCTAssertNil(tx.computeSkipReason)
        XCTAssertTrue(tx.isFailed, "an unknown reason must not be assumed benign")
    }

    /// The recorded fixtures contain a real `no_state` transaction, so the rule is pinned
    /// against actual server output rather than only hand-built JSON.
    ///
    /// Read straight from the fixture file rather than through ``FixtureTransport``, which
    /// keys recordings by path — several `/api/v3/transactions` recordings share one path, so
    /// going through the transport reaches whichever happens to win and not necessarily this
    /// one.
    func testRecordedFixturesContainABenignNoStateTransaction() throws {
        var checked = 0
        for network in ["mainnet", "testnet"] {
            guard let data = try? Vectors.rawFixture("toncenter/\(network)/transactions.json"),
                  let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let fixtures = root["fixtures"] as? [[String: Any]]
            else { continue }

            for fixture in fixtures {
                for request in (fixture["requests"] as? [[String: Any]]) ?? [] {
                    guard let body = request["body"] as? [String: Any],
                          body["transactions"] != nil
                    else { continue }

                    let bodyData = try JSONSerialization.data(withJSONObject: body)
                    let wire = try JSONDecoder().decode(Wire.TransactionsResponse.self, from: bodyData)
                    for tx in Mappers.transactions(wire).transactions
                    where tx.computeSkipReason == .noState {
                        checked += 1
                        XCTAssertTrue(tx.aborted, "the recorded transaction really is marked aborted")
                        XCTAssertFalse(
                            tx.isFailed,
                            "recorded no_state transaction must not read as failed (\(network))"
                        )
                    }
                }
            }
        }
        XCTAssertGreaterThan(checked, 0, "expected at least one recorded no_state transaction")
    }

    /// `tick_tock` transactions carry an *empty* `in_msg` object. The reference throws on
    /// this shape; we must map it with a nil inbound message.
    func testTickTockTransactionsMapWithNoInboundMessage() throws {
        let json: [String: Any] = [
            "transactions": [
                [
                    "account": "-1:5555555555555555555555555555555555555555555555555555555555555555",
                    "hash": "PZN0ti+X5r3ZbAycxzr+t96pPbXhl3p7dqMxnqWVIuk=",
                    "lt": "93552348000017",
                    "now": 1_700_000_000,
                    "description": ["type": "tick_tock", "aborted": false],
                    "in_msg": [:],
                    "out_msgs": [],
                ]
            ],
            "address_book": [:],
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let wire = try JSONDecoder().decode(Wire.TransactionsResponse.self, from: data)
        let page = Mappers.transactions(wire)

        XCTAssertEqual(page.transactions.count, 1)
        let tx = page.transactions[0]
        XCTAssertEqual(tx.kind, .tickTock)
        XCTAssertNil(tx.inMessage, "a tick_tock transaction is not message-driven")
        XCTAssertTrue(tx.hash.hasPrefix("0x"))
    }

    /// An ordinary transaction with no `trace_external_hash` must still decode — this is
    /// the precise shape that breaks the reference.
    func testOrdinaryTransactionWithoutTraceExternalHashDecodes() throws {
        let json: [String: Any] = [
            "transactions": [
                [
                    "account": "0:DEC3BA2AF7B41D666FCFE99FFD97CEE9826F41C9FB93D56D6368F3795374A8D5",
                    "hash": "PZN0ti+X5r3ZbAycxzr+t96pPbXhl3p7dqMxnqWVIuk=",
                    "lt": "93552348000017",
                    "now": 1_700_000_000,
                    "description": [
                        "type": "ord",
                        "aborted": false,
                        "compute_ph": ["success": true, "exit_code": 0],
                    ],
                    "in_msg": [
                        "hash": "taAG4ZVvNa/3AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
                        "source": "0:1111111111111111111111111111111111111111111111111111111111111111",
                        "destination": "0:DEC3BA2AF7B41D666FCFE99FFD97CEE9826F41C9FB93D56D6368F3795374A8D5",
                        "value": "1000000000",
                        "bounce": true,
                        "bounced": false,
                    ],
                    "out_msgs": [],
                ]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let wire = try JSONDecoder().decode(Wire.TransactionsResponse.self, from: data)
        let page = Mappers.transactions(wire)

        let tx = page.transactions[0]
        XCTAssertEqual(tx.kind, .ordinary)
        XCTAssertNil(tx.traceExternalHash)
        XCTAssertNotNil(tx.inMessage, "an ordinary transaction has an inbound message")
        XCTAssertEqual(tx.inMessage?.value, "1000000000")
        XCTAssertFalse(tx.isFailed)
    }

    /// A non-zero compute exit code means failure even when `aborted` is false.
    func testFailureDetectionUsesExitCodeNotJustAborted() throws {
        let json: [String: Any] = [
            "transactions": [
                [
                    "account": "0:1111111111111111111111111111111111111111111111111111111111111111",
                    "hash": "PZN0ti+X5r3ZbAycxzr+t96pPbXhl3p7dqMxnqWVIuk=",
                    "lt": "1",
                    "now": 1,
                    "description": [
                        "type": "ord",
                        "aborted": false,
                        "compute_ph": ["success": false, "exit_code": 37],
                    ],
                    "out_msgs": [],
                ]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let wire = try JSONDecoder().decode(Wire.TransactionsResponse.self, from: data)
        let tx = Mappers.transactions(wire).transactions[0]
        XCTAssertFalse(tx.aborted)
        XCTAssertEqual(tx.exitCode, 37)
        XCTAssertTrue(tx.isFailed, "a non-zero exit code is a failure even without abort")
    }
}

// MARK: - Error handling and retry

final class ClientErrorTests: XCTestCase {
    /// Zero delay: these tests exercise retry *counts*, not timing.
    private func client(_ transport: some Transport) -> ToncenterClient {
        ToncenterClient(network: .mainnet, transport: transport, retryDelayNanoseconds: 0)
    }

    /// A 4xx means the request was wrong, so retrying only multiplies load on a call
    /// that can never succeed.
    func testClientErrorsAreNotRetried() async throws {
        let transport = CountingTransport(
            response: TransportResponse(status: 422, body: Data(#"{"error":"bad"}"#.utf8))
        )
        do {
            _ = try await client(transport).getMasterchainInfo()
            XCTFail("expected a client error")
        } catch {
            guard let toncenter = error as? ToncenterError, toncenter.isClientError else {
                return XCTFail("expected a client error, got \(error)")
            }
        }
        XCTAssertEqual(transport.requestCount, 1, "a 422 must not be retried")
    }

    /// A 5xx might be transient, so it is retried.
    func testServerErrorsAreRetried() async throws {
        let transport = CountingTransport(
            response: TransportResponse(status: 503, body: Data("unavailable".utf8))
        )
        _ = try? await client(transport).getMasterchainInfo()
        XCTAssertGreaterThan(transport.requestCount, 1, "a 503 should be retried")
    }

    func testRateLimitIsClassifiedSeparately() {
        let error = ToncenterError.from(status: 429, body: Data("slow down".utf8))
        guard case .rateLimited = error else {
            return XCTFail("429 should map to rateLimited, got \(error)")
        }
        XCTAssertFalse(error.isClientError, "a rate limit is worth retrying after backoff")
    }

    func testMalformedJSONProducesDecodingError() async throws {
        let transport = SingleResponseTransport(
            response: TransportResponse(status: 200, body: Data("not json".utf8))
        )
        do {
            _ = try await client(transport).getMasterchainInfo()
            XCTFail("expected a decoding failure")
        } catch {
            guard case ToncenterError.decodingFailed = error else {
                return XCTFail("expected decodingFailed, got \(error)")
            }
        }
    }

    /// A malformed address must fail locally, before any network call.
    func testMalformedAddressFailsWithoutARequest() async throws {
        let transport = CountingTransport(
            response: TransportResponse(status: 200, body: Data("{}".utf8))
        )
        do {
            _ = try await client(transport).getAccountState(address: "not-an-address")
            XCTFail("expected an address error")
        } catch {
            guard case ToncenterError.addressNormalizationFailed = error else {
                return XCTFail("expected addressNormalizationFailed, got \(error)")
            }
        }
        XCTAssertEqual(transport.requestCount, 0, "no request should have been issued")
    }

    /// Truncated responses must not yield half-built models.
    func testTruncatedResponsesAreRejected() async throws {
        let full = try Vectors.rawFixture("toncenter/mainnet/masterchain-info")
        // Feed progressively longer prefixes of a valid body; none should decode.
        for cut in [1, 10, 50, 100] where cut < full.count {
            let transport = SingleResponseTransport(
                response: TransportResponse(status: 200, body: full.prefix(cut))
            )
            do {
                _ = try await client(transport).getMasterchainInfo()
                XCTFail("prefix of \(cut) bytes should not decode")
            } catch {
                // Any error is acceptable; silently succeeding is not.
            }
        }
    }
}

// MARK: - Hash conversion

final class HashConversionTests: XCTestCase {
    func testHexHashFromBase64() {
        let base64 = "F1cTpkhm2AA3i1g8FA3HojN6V7A90CJhaTz6iWHkogA="
        let hex = Mappers.hexHash(fromBase64: base64)
        XCTAssertEqual(
            hex,
            "0x175713a64866d800378b583c140dc7a2337a57b03dd02261693cfa8961e4a200"
        )
    }

    /// A missing hash maps to nil rather than throwing: a field the server stopped
    /// sending must not take down the whole response.
    func testMissingHashMapsToNil() {
        XCTAssertNil(Mappers.hexHash(fromBase64: nil))
        XCTAssertNil(Mappers.hexHash(fromBase64: ""))
        XCTAssertNil(Mappers.hexHash(fromBase64: "not!base64!"))
    }

    /// Callers hold `0x`-hex from normalized hashing, but Toncenter wants base64.
    func testMessageHashRoundTripsToBase64() {
        let hex = "0x175713a64866d800378b583c140dc7a2337a57b03dd02261693cfa8961e4a200"
        let base64 = ToncenterClient.toBase64Hash(hex)
        XCTAssertEqual(base64, "F1cTpkhm2AA3i1g8FA3HojN6V7A90CJhaTz6iWHkogA=")
        // Already-base64 input passes through untouched.
        XCTAssertEqual(ToncenterClient.toBase64Hash(base64), base64)
    }
}

// MARK: - Recorded fixture shapes

struct RecordedFile<Mapped: Decodable>: Decodable {
    let fixtures: [Fixture]

    struct Fixture: Decodable {
        let label: String
        let method: String
        let args: Args
        let mapped: Mapped?
    }

    struct Args: Decodable {
        let address: String?
        let addresses: [String]?
        let method: String?
    }
}

struct RecordedMasterchain: Decodable {
    let workchain: Int
    let seqno: Int
    let shard: String
    let rootHash: String
    let fileHash: String
}

struct RecordedAccountState: Decodable {
    let address: String
    let status: String
    let rawBalance: String
    let balance: String
    let lastTransaction: LastTransaction?

    struct LastTransaction: Decodable {
        let lt: String
        let hash: String
    }

    typealias Mapped = RecordedAccountState
}

struct RecordedGetMethod: Decodable {
    let gasUsed: Int
    let exitCode: Int
}

/// Verifies query encoding.
///
/// Base64 hashes are the reason this matters. `URLComponents.queryItems` leaves `+` unencoded,
/// servers read a raw `+` in a query value as a space, and about half of all 32-byte hashes
/// base64-encode to something containing one — so `transactionsByMessage` and `getTrace` failed
/// with HTTP 422 roughly every other call. Confirmed against the live API: the same endpoint
/// answers 200 for an encoded `+` and 422 for a raw one.
final class QueryEncodingTests: XCTestCase {
    func testPlusIsEncoded() {
        XCTAssertEqual(URLSessionTransport.encodeQueryComponent("a+b"), "a%2Bb")
    }

    /// Every base64 character that is not unreserved must be escaped.
    func testBase64PayloadIsFullyEscaped() {
        let encoded = URLSessionTransport.encodeQueryComponent("aa+bb/cc=")
        XCTAssertEqual(encoded, "aa%2Bbb%2Fcc%3D")
        for character in ["+", "/", "="] {
            XCTAssertFalse(encoded.contains(character), "\(character) survived encoding")
        }
    }

    func testUnreservedCharactersAreLeftAlone() {
        let plain = "abcXYZ019-._~"
        XCTAssertEqual(URLSessionTransport.encodeQueryComponent(plain), plain)
    }

    func testSeparatorsCannotBeInjected() {
        // A value containing & or = must not be able to introduce another parameter.
        XCTAssertEqual(
            URLSessionTransport.encodeQueryComponent("x&injected=1"),
            "x%26injected%3D1"
        )
    }

    /// A realistic hash must round-trip through encode/decode unchanged.
    func testRealisticHashRoundTrips() throws {
        // Contains both `+` and `/`, which is the common case rather than a contrived one.
        let hash = "fJQzIiimmhuO+l4GL/g5LZE7YlKtvPhikizVcjxR6tM="
        let encoded = URLSessionTransport.encodeQueryComponent(hash)
        let decoded = encoded.removingPercentEncoding
        XCTAssertEqual(decoded, hash)
    }

    /// The whole query string must be assembled without raw separators leaking through.
    func testQueryStringAssembly() throws {
        let transport = URLSessionTransport(
            endpoint: URL(string: "https://example.com")!,
            apiKey: nil
        )
        let url = try transport.url(
            for: TransportRequest(
                method: .get,
                path: "/api/v3/transactionsByMessage",
                query: ["msg_hash": ["aa+bb/cc="]]
            )
        )
        XCTAssertEqual(
            url.absoluteString,
            "https://example.com/api/v3/transactionsByMessage?msg_hash=aa%2Bbb%2Fcc%3D"
        )
    }
}
