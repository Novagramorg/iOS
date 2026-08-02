import Foundation
import TONCore
import TONToncenter

/// What a wallet holds.
public struct Portfolio: Sendable {
    /// Nanoton.
    public let ton: BigUInt
    public let jettons: [JettonHolding]
    public let nfts: [NFTItem]

    public init(ton: BigUInt, jettons: [JettonHolding], nfts: [NFTItem]) {
        self.ton = ton
        self.jettons = jettons
        self.nfts = nfts
    }
}

extension TonWalletKit {
    // MARK: - Balances and holdings

    /// A wallet's TON balance, in nanoton.
    ///
    /// Read live every time. A cached balance is wrong the moment something spends, and a
    /// wallet showing money that is already gone is worse than one that is briefly slow.
    public func balance(of walletID: WalletID) async throws -> BigUInt {
        let wallet = try requireWallet(walletID)
        do {
            return try await requireClient(for: wallet)
                .getAccountState(address: wallet.address.toString())
                .nanoton
        } catch {
            throw WalletKitError.chainFailure(underlying: error)
        }
    }

    /// A wallet's jetton holdings.
    ///
    /// Balances come from the network; the metadata each holding carries is also folded into
    /// the cache, so a later per-token lookup costs nothing.
    public func jettons(
        of walletID: WalletID,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> [JettonHolding] {
        let wallet = try requireWallet(walletID)
        do {
            let page = try await requireClient(for: wallet)
                .getJettons(owner: wallet.address.toString(), limit: limit, offset: offset)
            await assetCache.store(from: page.jettons, network: wallet.network)
            return page.jettons
        } catch {
            throw WalletKitError.chainFailure(underlying: error)
        }
    }

    /// NFTs a wallet owns.
    ///
    /// An item listed on a marketplace is owned by the sale contract, so the indexer reports
    /// the sale as owner and the wallet as `realOwnerAddress`. Both are returned as-is rather
    /// than reconciled here: which one a wallet should show depends on whether it wants to
    /// offer a transfer, which it cannot do for an item under sale.
    public func nfts(
        of walletID: WalletID,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> [NFTItem] {
        let wallet = try requireWallet(walletID)
        do {
            return try await requireClient(for: wallet)
                .getNFTs(owner: wallet.address.toString(), limit: limit, offset: offset)
                .nfts
        } catch {
            throw WalletKitError.chainFailure(underlying: error)
        }
    }

    /// Everything a wallet holds, fetched concurrently.
    ///
    /// The three reads are independent, so they run together: done in sequence this is three
    /// round trips of latency on a screen the user is already looking at.
    public func portfolio(
        of walletID: WalletID,
        jettonLimit: Int = 50,
        nftLimit: Int = 50
    ) async throws -> Portfolio {
        _ = try requireWallet(walletID)

        async let ton = balance(of: walletID)
        async let jettons = jettons(of: walletID, limit: jettonLimit)
        async let nfts = nfts(of: walletID, limit: nftLimit)

        return Portfolio(
            ton: try await ton,
            jettons: try await jettons,
            nfts: try await nfts
        )
    }

    // MARK: - Metadata

    /// Metadata for a jetton, from the cache when possible.
    ///
    /// Falls back to a holdings lookup for the given wallet, which is the only place Toncenter
    /// returns metadata for a token — so this resolves for tokens the wallet holds, and returns
    /// nil for ones it does not. Stated plainly because a silent nil for an unheld token looks
    /// like a failure otherwise.
    public func jettonInfo(
        master: String,
        for walletID: WalletID
    ) async throws -> JettonInfo? {
        let wallet = try requireWallet(walletID)
        if let cached = await assetCache.info(network: wallet.network, master: master) {
            return cached
        }

        let holdings = try await jettons(of: walletID)
        let wanted = AssetCache.normalize(master)
        return holdings
            .first { AssetCache.normalize($0.master) == wanted }?
            .info
    }

    /// Cache counters, for diagnosing whether the cache is earning its keep.
    public func assetCacheStatistics() async -> AssetCache.Statistics {
        await assetCache.statistics()
    }

    /// Empties the metadata cache, optionally for one network only.
    public func clearAssetCache(network: Network? = nil) async {
        await assetCache.clear(network: network)
    }
}
