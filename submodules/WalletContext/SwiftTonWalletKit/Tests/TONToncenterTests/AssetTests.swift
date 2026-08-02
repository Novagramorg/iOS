import XCTest
import TONTestVectors
import TONCore
@testable import TONToncenter

/// Verifies jetton, NFT and DNS mapping against recorded responses.
///
/// Uses **testnet** fixtures for the asset cases: the mainnet recording happened to land
/// on an account holding no NFTs, so its `nft/items` response is empty and proves nothing.
/// The testnet recording has 5 NFTs and 5 jetton wallets.
final class AssetTests: XCTestCase {
    private func client(_ network: String) throws -> ToncenterClient {
        ToncenterClient(
            network: network == "mainnet" ? .mainnet : .testnet,
            transport: try FixtureTransport(network: network),
            retryDelayNanoseconds: 0
        )
    }

    // MARK: - Jettons

    /// The jetton wallet address is what a transfer is sent *to*, so getting it wrong
    /// sends tokens nowhere.
    func testJettonHoldingsMapMasterAndWalletSeparately() async throws {
        let page = try await client("testnet").getJettons(owner: "0:" + String(repeating: "40", count: 32))

        XCTAssertFalse(page.jettons.isEmpty, "testnet fixture should hold jettons")
        for holding in page.jettons {
            XCTAssertNotEqual(
                holding.master,
                holding.walletAddress,
                "the master and the owner's jetton wallet are different contracts"
            )
            // Both must be canonical friendly form.
            XCTAssertNoThrow(try Address.parse(holding.master))
            XCTAssertNoThrow(try Address.parse(holding.walletAddress))
            XCTAssertNotNil(BigUInt(holding.balance), "balance should be a decimal string")
        }
    }

    /// Metadata lives on the *master*, not the wallet. Looking it up on the wallet yields
    /// a `jetton_wallets` record with no name or decimals.
    func testJettonMetadataComesFromTheMaster() async throws {
        let raw = try Vectors.rawFixture("toncenter/mainnet/jettons")
        let body = try XCTUnwrap(rawBody(forLabel: "by-owner", in: raw))
        let wire = try JSONDecoder().decode(Wire.JettonWalletsResponse.self, from: body)
        let page = try Mappers.jettons(wire)

        let usdt = try XCTUnwrap(page.jettons.first, "mainnet fixture holds one jetton")
        XCTAssertEqual(usdt.info?.name, "Tether USD")
        XCTAssertEqual(usdt.info?.symbol, "USD₮")
        XCTAssertEqual(usdt.info?.decimals, 6, "decimals arrive inside the extra block")
        XCTAssertFalse(usdt.info?.isScam ?? true)
    }

    /// The recorded mapping the reference produced, for the same response.
    func testJettonMappingMatchesReference() throws {
        let raw = try Vectors.rawFixture("toncenter/mainnet/jettons")
        let recorded = try JSONSerialization.jsonObject(with: raw) as? [String: Any]
        let fixtures = try XCTUnwrap(recorded?["fixtures"] as? [[String: Any]])
        let fixture = try XCTUnwrap(fixtures.first { $0["label"] as? String == "by-owner" })
        let mapped = try XCTUnwrap(fixture["mapped"] as? [String: Any])
        let expected = try XCTUnwrap((mapped["jettons"] as? [[String: Any]])?.first)

        let body = try XCTUnwrap(rawBody(forLabel: "by-owner", in: raw))
        let wire = try JSONDecoder().decode(Wire.JettonWalletsResponse.self, from: body)
        let holding = try XCTUnwrap(try Mappers.jettons(wire).jettons.first)

        XCTAssertEqual(holding.master, expected["address"] as? String, "master address")
        XCTAssertEqual(holding.walletAddress, expected["walletAddress"] as? String)
        XCTAssertEqual(holding.balance, expected["balance"] as? String)
        XCTAssertEqual(holding.info?.decimals, expected["decimalsNumber"] as? Int)
    }

    /// Formatting must not guess: an unknown decimals value yields nil rather than a
    /// wrongly scaled number.
    func testBalanceFormattingRequiresKnownDecimals() {
        let known = JettonHolding(
            master: "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c",
            walletAddress: "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c",
            balance: "1500000",
            info: JettonInfo(decimals: 6)
        )
        XCTAssertEqual(known.formattedBalance, "1.5")

        let unknown = JettonHolding(
            master: "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c",
            walletAddress: "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c",
            balance: "1500000",
            info: nil
        )
        XCTAssertNil(unknown.formattedBalance, "unknown decimals must not be guessed")
    }

    /// Toncenter sends `decimals` as a string for some tokens and a number for others.
    func testHeterogeneousExtraValuesDecode() throws {
        for decimalsJSON in ["\"9\"", "9"] {
            let json = """
            {
              "jetton_wallets": [
                {"address":"0:\(String(repeating: "11", count: 32))","balance":"1","jetton":"0:\(String(repeating: "22", count: 32))"}
              ],
              "metadata": {
                "0:\(String(repeating: "22", count: 32))": {
                  "token_info": [
                    {"type":"jetton_masters","name":"T","symbol":"T","extra":{"decimals":\(decimalsJSON)}}
                  ]
                }
              }
            }
            """
            let wire = try JSONDecoder().decode(
                Wire.JettonWalletsResponse.self,
                from: Data(json.utf8)
            )
            let page = try Mappers.jettons(wire)
            XCTAssertEqual(
                page.jettons.first?.info?.decimals,
                9,
                "decimals should decode whether sent as \(decimalsJSON)"
            )
        }
    }

    /// The master record must be selected **by type**, not by position.
    ///
    /// An indexer entry can carry several `token_info` records, and the recorded fixtures
    /// happen to have the master record first — so a positional `.first` looks correct
    /// there. Verified by mutation: without this case, replacing the type filter with
    /// `.first` leaves the suite green.
    func testMasterRecordIsSelectedByTypeNotPosition() throws {
        let master = "0:" + String(repeating: "22", count: 32)
        let json = """
        {
          "jetton_wallets": [
            {"address":"0:\(String(repeating: "11", count: 32))","balance":"1","jetton":"\(master)"}
          ],
          "metadata": {
            "\(master)": {
              "token_info": [
                {"type":"jetton_wallets","extra":{"balance":"1"}},
                {"type":"jetton_masters","name":"Correct","symbol":"OK","extra":{"decimals":"4"}}
              ]
            }
          }
        }
        """
        let wire = try JSONDecoder().decode(
            Wire.JettonWalletsResponse.self,
            from: Data(json.utf8)
        )
        let holding = try XCTUnwrap(try Mappers.jettons(wire).jettons.first)

        XCTAssertEqual(holding.info?.name, "Correct", "must pick the jetton_masters record")
        XCTAssertEqual(holding.info?.symbol, "OK")
        XCTAssertEqual(holding.info?.decimals, 4)
    }

    /// A wallet with no `jetton` field cannot be attributed to a token, so it is dropped
    /// rather than mapped to a holding with an empty master.
    func testWalletWithoutMasterIsDropped() throws {
        let json = """
        {"jetton_wallets":[{"address":"0:\(String(repeating: "11", count: 32))","balance":"5"}]}
        """
        let wire = try JSONDecoder().decode(Wire.JettonWalletsResponse.self, from: Data(json.utf8))
        XCTAssertTrue(try Mappers.jettons(wire).jettons.isEmpty)
    }

    // MARK: - NFTs

    func testNFTItemsMapFromTestnetFixture() async throws {
        let page = try await client("testnet").getNFTs(owner: "0:" + String(repeating: "40", count: 32))
        XCTAssertFalse(page.nfts.isEmpty, "testnet fixture should hold NFTs")

        for item in page.nfts {
            XCTAssertNoThrow(try Address.parse(item.address))
            if let owner = item.ownerAddress {
                XCTAssertNoThrow(try Address.parse(owner))
            }
        }
    }

    func testNFTMappingMatchesReference() throws {
        let raw = try Vectors.rawFixture("toncenter/testnet/nfts")
        let recorded = try JSONSerialization.jsonObject(with: raw) as? [String: Any]
        let fixtures = try XCTUnwrap(recorded?["fixtures"] as? [[String: Any]])
        let fixture = try XCTUnwrap(fixtures.first)
        let mapped = try XCTUnwrap(fixture["mapped"] as? [String: Any])
        let expected = try XCTUnwrap((mapped["nfts"] as? [[String: Any]])?.first)

        let body = try XCTUnwrap(rawBody(forLabel: "by-owner", in: raw))
        let wire = try JSONDecoder().decode(Wire.NFTItemsResponse.self, from: body)
        let item = try XCTUnwrap(try Mappers.nfts(wire).nfts.first)

        XCTAssertEqual(item.address, expected["address"] as? String)
        XCTAssertEqual(item.index, expected["index"] as? String)
        XCTAssertEqual(item.ownerAddress, expected["ownerAddress"] as? String)
        XCTAssertEqual(item.realOwnerAddress, expected["realOwnerAddress"] as? String)
        XCTAssertEqual(item.codeHash, expected["codeHash"] as? String)
        XCTAssertEqual(item.dataHash, expected["dataHash"] as? String)
        XCTAssertEqual(item.isInited, expected["isInited"] as? Bool)
        XCTAssertEqual(item.isOnSale, expected["isOnSale"] as? Bool)
        XCTAssertEqual(item.contentURI, (expected["extra"] as? [String: Any])?["uri"] as? String)
    }

    /// An NFT held by a sale contract cannot be transferred directly — `ownerAddress` is
    /// the sale contract, not the user. Sending a transfer to the item would fail.
    func testEscrowDetection() {
        let onSale = NFTItem(
            address: "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c",
            ownerAddress: "EQD__________________________________________0vo",
            realOwnerAddress: "EQAvlWFDxGF2lXm67y4yzC17wYKD9A0guwPkMs1gOsM__NOT",
            isOnSale: true
        )
        XCTAssertTrue(onSale.isEscrowed)

        let plain = NFTItem(
            address: "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c",
            ownerAddress: "EQD__________________________________________0vo",
            realOwnerAddress: "EQD__________________________________________0vo",
            isOnSale: false
        )
        XCTAssertFalse(plain.isEscrowed)
    }

    func testEmptyNFTAddressListShortCircuits() async throws {
        let page = try await client("testnet").getNFTs(addresses: [])
        XCTAssertTrue(page.nfts.isEmpty)
    }

    // MARK: - DNS

    /// An unregistered domain is an ordinary outcome, so it returns nil rather than
    /// throwing.
    func testUnresolvedDomainReturnsNil() throws {
        let json = #"{"records":[],"address_book":{}}"#
        let wire = try JSONDecoder().decode(Wire.DNSRecordsResponse.self, from: Data(json.utf8))
        XCTAssertNil(try Mappers.dnsWallet(wire))
        XCTAssertNil(Mappers.dnsDomain(wire))
    }

    func testResolvedDomainYieldsCanonicalAddress() throws {
        let json = """
        {"records":[{"domain":"example.ton","dns_wallet_address":"0:\(String(repeating: "83", count: 32))"}]}
        """
        let wire = try JSONDecoder().decode(Wire.DNSRecordsResponse.self, from: Data(json.utf8))
        let resolved = try XCTUnwrap(try Mappers.dnsWallet(wire))
        // Must come back in canonical friendly form, not the raw form the server sent.
        XCTAssertFalse(resolved.contains(":"))
        XCTAssertEqual(try Address.parse(resolved).rawString, "0:" + String(repeating: "83", count: 32))
        XCTAssertEqual(Mappers.dnsDomain(wire), "example.ton")
    }

    /// Records without a wallet address (a next-resolver or site record) must be skipped
    /// rather than mapped to an empty address.
    func testRecordsWithoutWalletAddressAreSkipped() throws {
        let json = """
        {"records":[
          {"domain":"a.ton","dns_next_resolver":"0:\(String(repeating: "11", count: 32))"},
          {"domain":"a.ton","dns_wallet_address":"0:\(String(repeating: "22", count: 32))"}
        ]}
        """
        let wire = try JSONDecoder().decode(Wire.DNSRecordsResponse.self, from: Data(json.utf8))
        let resolved = try XCTUnwrap(try Mappers.dnsWallet(wire))
        XCTAssertEqual(try Address.parse(resolved).rawString, "0:" + String(repeating: "22", count: 32))
    }

    // MARK: - Helpers

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
}
