import Foundation
import TONCore
import TONToncenter

/// Caches jetton metadata.
///
/// **Metadata only, never balances.** Name, symbol, decimals and icon are effectively immutable
/// for a deployed token, so serving them from memory is free correctness; a balance is the
/// opposite — stale by definition the moment it is stored, and showing a stale one is how a
/// wallet tells a user they hold money they have already spent. Balances are always read live.
///
/// The win is repeat lookups. A transaction list rendering thirty rows of the same token asks
/// about that master thirty times; without a cache that is thirty round trips for a value that
/// cannot have changed.
///
/// Least-recently-used with a TTL, matching the reference's 10k entries / 10 minutes. The TTL
/// exists because metadata is *effectively* immutable rather than actually so: a token can
/// update its content cell, and a wallet that cached a name forever would never notice.
public actor AssetCache {
    public struct Statistics: Sendable, Equatable {
        public let entries: Int
        public let capacity: Int
        public let hits: Int
        public let misses: Int

        /// Share of lookups served from memory. Nil before any lookup, rather than a
        /// meaningless zero.
        public var hitRate: Double? {
            let total = hits + misses
            guard total > 0 else { return nil }
            return Double(hits) / Double(total)
        }
    }

    private struct Entry {
        let value: JettonInfo
        let storedAt: Int64
        /// Bumped on every read, so eviction can find the least recently *used* rather than
        /// the least recently written.
        var lastUsed: Int64
    }

    /// Cache key. Includes the network: the same master address can exist on both chains and
    /// mean different tokens, so a shared key would show mainnet metadata for a testnet token.
    private struct Key: Hashable {
        let network: String
        let master: String
    }

    private let capacity: Int
    private let ttl: TimeInterval
    private let now: @Sendable () -> Int64

    private var entries: [Key: Entry] = [:]
    private var hits = 0
    private var misses = 0
    /// Monotonic counter for recency, rather than the clock — two reads in the same
    /// millisecond must still be ordered, and a clock that moves backwards must not scramble
    /// eviction order.
    private var useCounter: Int64 = 0

    public init(
        capacity: Int = 10_000,
        ttl: TimeInterval = 600,
        now: @Sendable @escaping () -> Int64 = { Int64(Date().timeIntervalSince1970 * 1000) }
    ) {
        self.capacity = max(1, capacity)
        self.ttl = ttl
        self.now = now
    }

    /// Cached metadata, or nil when absent or stale.
    public func info(network: Network, master: String) -> JettonInfo? {
        let key = Key(network: network.chainId, master: Self.normalize(master))
        guard let entry = entries[key] else {
            misses += 1
            return nil
        }
        guard now() - entry.storedAt < Int64(ttl * 1000) else {
            // Expired entries are dropped on read rather than swept: a sweep costs work for
            // tokens nobody is asking about.
            entries[key] = nil
            misses += 1
            return nil
        }

        useCounter += 1
        entries[key]?.lastUsed = useCounter
        hits += 1
        return entry.value
    }

    public func store(_ info: JettonInfo, network: Network, master: String) {
        let key = Key(network: network.chainId, master: Self.normalize(master))
        useCounter += 1
        entries[key] = Entry(value: info, storedAt: now(), lastUsed: useCounter)
        evictIfNeeded()
    }

    /// Stores everything a holdings response already carried.
    ///
    /// Listing holdings returns metadata inline, so a later per-token lookup should not go back
    /// to the network for something already in hand.
    public func store(from holdings: [JettonHolding], network: Network) {
        for holding in holdings {
            guard let info = holding.info else { continue }
            store(info, network: network, master: holding.master)
        }
    }

    public func clear(network: Network? = nil) {
        guard let network else {
            entries.removeAll()
            return
        }
        entries = entries.filter { $0.key.network != network.chainId }
    }

    public func statistics() -> Statistics {
        Statistics(entries: entries.count, capacity: capacity, hits: hits, misses: misses)
    }

    private func evictIfNeeded() {
        guard entries.count > capacity else { return }
        // Drop the least recently used until back within capacity. Sorted rather than
        // repeatedly scanning for the minimum, since an over-capacity insert can only exceed
        // by one in normal use but a bulk `store(from:)` can exceed by many.
        let excess = entries.count - capacity
        let doomed = entries
            .sorted { $0.value.lastUsed < $1.value.lastUsed }
            .prefix(excess)
            .map(\.key)
        for key in doomed { entries[key] = nil }
    }

    /// Addresses arrive in raw or friendly form depending on the endpoint, so the key is
    /// normalised to the raw form — otherwise the same token caches twice under two spellings
    /// and neither entry is ever hit.
    static func normalize(_ address: String) -> String {
        (try? Address.parse(address).rawString) ?? address.lowercased()
    }
}
