import XCTest
import TONCore
import TONToncenter
@testable import TONWalletKit

/// Verifies the jetton metadata cache.
///
/// The properties that matter are the ones whose absence is invisible in normal use: a cache
/// that never evicts grows without bound, one that never expires shows a renamed token's old
/// name forever, and one keyed without the network shows mainnet metadata for a testnet token.
/// None of those produce an error — they produce a wallet that is quietly wrong.
final class AssetCacheTests: XCTestCase {
    /// Controllable clock, so TTL is tested without waiting.
    final class Clock: @unchecked Sendable {
        private let lock = NSLock()
        private var millis: Int64 = 1_700_000_000_000

        var now: Int64 { lock.lock(); defer { lock.unlock() }; return millis }
        func advance(seconds: TimeInterval) {
            lock.lock(); millis += Int64(seconds * 1000); lock.unlock()
        }
        var reader: @Sendable () -> Int64 { { [self] in self.now } }
    }

    private func info(_ symbol: String, decimals: Int = 9) -> JettonInfo {
        JettonInfo(name: "Token \(symbol)", symbol: symbol, decimals: decimals)
    }

    private func master(_ byte: String) -> String {
        "0:" + String(repeating: byte, count: 64 / byte.count)
    }

    // MARK: - Basics

    func testStoreAndRetrieve() async {
        let cache = AssetCache()
        await cache.store(info("AAA"), network: .testnet, master: master("11"))

        let found = await cache.info(network: .testnet, master: master("11"))
        XCTAssertEqual(found?.symbol, "AAA")
        XCTAssertEqual(found?.decimals, 9)
    }

    func testMissReturnsNil() async {
        let cache = AssetCache()
        let found = await cache.info(network: .testnet, master: master("22"))
        XCTAssertNil(found)
    }

    /// The same master on two chains is two different tokens.
    ///
    /// A key without the network would show mainnet metadata for a testnet token — the kind of
    /// wrong that looks right until someone reads a symbol that does not belong to what they
    /// hold.
    func testNetworksDoNotShareEntries() async {
        let cache = AssetCache()
        await cache.store(info("MAIN"), network: .mainnet, master: master("33"))

        let onTestnet = await cache.info(network: .testnet, master: master("33"))
        XCTAssertNil(onTestnet, "a testnet lookup found mainnet metadata")

        let onMainnet = await cache.info(network: .mainnet, master: master("33"))
        XCTAssertEqual(onMainnet?.symbol, "MAIN")
    }

    /// Raw and friendly spellings of one address must hit the same entry.
    ///
    /// Endpoints return whichever form they prefer, so a cache keyed on the literal string
    /// stores the same token twice and hits neither.
    func testAddressFormsAreNormalised() async throws {
        let cache = AssetCache()
        let raw = "0:bd0ef4d11b0aae0e8cbba3a8b194fbafc7f1ab453f3531b2f2f5bfe633a9b615"
        let friendly = try Address.parse(raw).toString(testOnly: true)
        XCTAssertNotEqual(raw, friendly, "the two spellings must actually differ")

        await cache.store(info("SAME"), network: .testnet, master: raw)
        let viaFriendly = await cache.info(network: .testnet, master: friendly)
        XCTAssertEqual(viaFriendly?.symbol, "SAME", "the friendly spelling missed the entry")

        // And uppercase raw, which some endpoints return.
        let viaUppercase = await cache.info(network: .testnet, master: raw.uppercased())
        XCTAssertEqual(viaUppercase?.symbol, "SAME")
    }

    // MARK: - TTL

    func testEntriesExpire() async {
        let clock = Clock()
        let cache = AssetCache(ttl: 600, now: clock.reader)
        await cache.store(info("OLD"), network: .testnet, master: master("44"))

        clock.advance(seconds: 599)
        let stillFresh = await cache.info(network: .testnet, master: master("44"))
        XCTAssertNotNil(stillFresh, "expired a second early")

        clock.advance(seconds: 2)
        let expired = await cache.info(network: .testnet, master: master("44"))
        XCTAssertNil(expired, "a stale entry was served")
    }

    /// Re-storing must reset the clock, or a token refreshed just before expiry vanishes.
    func testStoringAgainRefreshesTheEntry() async {
        let clock = Clock()
        let cache = AssetCache(ttl: 600, now: clock.reader)
        await cache.store(info("A"), network: .testnet, master: master("55"))

        clock.advance(seconds: 599)
        await cache.store(info("B"), network: .testnet, master: master("55"))
        clock.advance(seconds: 100)

        let found = await cache.info(network: .testnet, master: master("55"))
        XCTAssertEqual(found?.symbol, "B", "the refreshed entry expired on the original schedule")
    }

    // MARK: - Eviction

    func testCapacityIsEnforced() async {
        let cache = AssetCache(capacity: 3)
        for index in 1...5 {
            await cache.store(info("T\(index)"), network: .testnet, master: master(String(format: "%02d", index)))
        }
        let stats = await cache.statistics()
        XCTAssertEqual(stats.entries, 3, "the cache grew past its capacity")
    }

    /// Eviction must drop the least recently *used*, not the least recently written.
    ///
    /// Otherwise the token a wallet renders on every row — the one worth caching — is the first
    /// evicted, and the cache does the opposite of its job.
    func testEvictionPrefersTheLeastRecentlyUsed() async {
        let cache = AssetCache(capacity: 2)
        await cache.store(info("FIRST"), network: .testnet, master: master("11"))
        await cache.store(info("SECOND"), network: .testnet, master: master("22"))

        // Touch the first, making the second the least recently used.
        _ = await cache.info(network: .testnet, master: master("11"))
        await cache.store(info("THIRD"), network: .testnet, master: master("33"))

        let first = await cache.info(network: .testnet, master: master("11"))
        let second = await cache.info(network: .testnet, master: master("22"))
        XCTAssertNotNil(first, "the recently used entry was evicted")
        XCTAssertNil(second, "the least recently used entry survived")
    }

    /// A bulk store that overshoots by many must come back to capacity in one go.
    func testBulkStoreRespectsCapacity() async {
        let cache = AssetCache(capacity: 2)
        let holdings = (1...6).map { index in
            JettonHolding(
                master: master(String(format: "%02d", index)),
                walletAddress: master("ff"),
                balance: "1",
                info: info("T\(index)")
            )
        }
        await cache.store(from: holdings, network: .testnet)

        let stats = await cache.statistics()
        XCTAssertEqual(stats.entries, 2)
    }

    // MARK: - Bulk population

    func testHoldingsPopulateTheCache() async {
        let cache = AssetCache()
        let holdings = [
            JettonHolding(master: master("11"), walletAddress: master("ee"), balance: "5", info: info("AAA")),
            // No metadata: must be skipped rather than caching an empty entry that then
            // shadows a later good one.
            JettonHolding(master: master("22"), walletAddress: master("ee"), balance: "7", info: nil),
        ]
        await cache.store(from: holdings, network: .testnet)

        let withInfo = await cache.info(network: .testnet, master: master("11"))
        XCTAssertEqual(withInfo?.symbol, "AAA")

        let withoutInfo = await cache.info(network: .testnet, master: master("22"))
        XCTAssertNil(withoutInfo, "a holding with no metadata cached an empty entry")
    }

    // MARK: - Clearing and stats

    func testClearingOneNetworkLeavesTheOther() async {
        let cache = AssetCache()
        await cache.store(info("M"), network: .mainnet, master: master("11"))
        await cache.store(info("T"), network: .testnet, master: master("11"))

        await cache.clear(network: .testnet)

        let mainnet = await cache.info(network: .mainnet, master: master("11"))
        let testnet = await cache.info(network: .testnet, master: master("11"))
        XCTAssertEqual(mainnet?.symbol, "M", "clearing testnet removed mainnet entries")
        XCTAssertNil(testnet)
    }

    func testClearingEverything() async {
        let cache = AssetCache()
        await cache.store(info("M"), network: .mainnet, master: master("11"))
        await cache.store(info("T"), network: .testnet, master: master("22"))
        await cache.clear()

        let stats = await cache.statistics()
        XCTAssertEqual(stats.entries, 0)
    }

    func testStatisticsCountHitsAndMisses() async {
        let cache = AssetCache(capacity: 10)
        await cache.store(info("A"), network: .testnet, master: master("11"))

        _ = await cache.info(network: .testnet, master: master("11"))   // hit
        _ = await cache.info(network: .testnet, master: master("11"))   // hit
        _ = await cache.info(network: .testnet, master: master("99"))   // miss

        let stats = await cache.statistics()
        XCTAssertEqual(stats.hits, 2)
        XCTAssertEqual(stats.misses, 1)
        XCTAssertEqual(stats.capacity, 10)
        XCTAssertEqual(stats.hitRate.map { ($0 * 100).rounded() }, 67)
    }

    /// A hit rate before any lookup is undefined, not zero — zero reads as "the cache is
    /// useless" when nothing has been asked of it yet.
    func testHitRateIsNilBeforeAnyLookup() async {
        let cache = AssetCache()
        let stats = await cache.statistics()
        XCTAssertNil(stats.hitRate)
    }

    /// An expired entry counts as a miss, since that is what the caller experiences.
    func testExpiryCountsAsAMiss() async {
        let clock = Clock()
        let cache = AssetCache(ttl: 10, now: clock.reader)
        await cache.store(info("A"), network: .testnet, master: master("11"))
        clock.advance(seconds: 20)
        _ = await cache.info(network: .testnet, master: master("11"))

        let stats = await cache.statistics()
        XCTAssertEqual(stats.misses, 1)
        XCTAssertEqual(stats.hits, 0)
        XCTAssertEqual(stats.entries, 0, "the expired entry should have been dropped")
    }
}
