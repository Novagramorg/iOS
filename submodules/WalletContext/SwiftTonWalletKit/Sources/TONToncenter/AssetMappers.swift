import Foundation
import TONCore

extension Mappers {
    // MARK: - Jettons

    /// Maps jetton wallets, enriching each with metadata for its **master**.
    ///
    /// The metadata block is keyed by raw address and contains entries for both the
    /// wallet and the master; the token name, symbol and decimals live on the master.
    /// Looking them up on the wallet returns a `jetton_wallets` entry with no name,
    /// which is why the master address drives the lookup.
    static func jettons(_ wire: Wire.JettonWalletsResponse) throws -> JettonsPage {
        let metadata = wire.metadata ?? [:]

        let holdings: [JettonHolding] = try wire.jettonWallets.compactMap { wallet in
            guard let masterRaw = wallet.jetton else { return nil }
            return JettonHolding(
                master: try canonical(address: masterRaw),
                walletAddress: try canonical(address: wallet.address),
                balance: wallet.balance,
                info: jettonInfo(from: metadata, rawAddress: masterRaw)
            )
        }

        return JettonsPage(
            jettons: holdings,
            addressBook: (wire.addressBook ?? [:]).compactMapValues(\.userFriendly)
        )
    }

    /// Extracts token metadata for one address, if the indexer has it.
    static func jettonInfo(
        from metadata: [String: Wire.AddressMetadata],
        rawAddress: String
    ) -> JettonInfo? {
        // Toncenter keys metadata by uppercase raw address; be tolerant of case.
        let entry = metadata[rawAddress]
            ?? metadata[rawAddress.uppercased()]
            ?? metadata.first { $0.key.caseInsensitiveCompare(rawAddress) == .orderedSame }?.value
        guard let entry else { return nil }

        // Prefer the master record; a wallet record carries no name or decimals.
        let token = entry.tokenInfo?.first { $0.type == "jetton_masters" }
            ?? entry.tokenInfo?.first

        guard let token else { return nil }

        let extra = token.extra?.flattened ?? [:]
        return JettonInfo(
            name: token.name,
            symbol: token.symbol,
            description: token.description,
            imageURL: token.image,
            decimals: extra["decimals"].flatMap(Int.init),
            isScam: token.isScam ?? false,
            isNSFW: token.isNSFW ?? false
        )
    }

    // MARK: - NFTs

    static func nfts(_ wire: Wire.NFTItemsResponse) throws -> NFTsPage {
        let metadata = wire.metadata ?? [:]
        let items: [NFTItem] = try wire.nftItems.map { item in
            NFTItem(
                address: try canonical(address: item.address),
                index: item.index,
                ownerAddress: try item.ownerAddress.map { try canonical(address: $0) },
                realOwnerAddress: try item.realOwner.map { try canonical(address: $0) },
                collectionAddress: try item.collectionAddress.map { try canonical(address: $0) },
                codeHash: hexHash(fromBase64: item.codeHash),
                dataHash: hexHash(fromBase64: item.dataHash),
                isInited: item.`init` ?? false,
                isOnSale: item.onSale ?? false,
                content: item.content?.flattened ?? [:],
                info: nftInfo(from: metadata, rawAddress: item.address, type: "nft_items"),
                collectionInfo: item.collectionAddress.flatMap {
                    nftInfo(from: metadata, rawAddress: $0, type: "nft_collections")
                }
            )
        }

        return NFTsPage(
            nfts: items,
            addressBook: (wire.addressBook ?? [:]).compactMapValues(\.userFriendly)
        )
    }

    static func nftInfo(
        from metadata: [String: Wire.AddressMetadata],
        rawAddress: String,
        type: String
    ) -> NFTInfo? {
        let entry = metadata[rawAddress]
            ?? metadata[rawAddress.uppercased()]
            ?? metadata.first { $0.key.caseInsensitiveCompare(rawAddress) == .orderedSame }?.value
        guard let token = entry?.tokenInfo?.first(where: { $0.type == type })
            ?? entry?.tokenInfo?.first else {
            return nil
        }
        return NFTInfo(
            name: token.name,
            description: token.description,
            imageURL: token.image,
            isScam: token.isScam ?? false,
            isNSFW: token.isNSFW ?? false,
            extra: token.extra?.flattened ?? [:]
        )
    }

    // MARK: - DNS

    /// Resolves a domain to the wallet address it points at.
    ///
    /// Returns nil rather than throwing when the domain does not resolve — an
    /// unregistered domain is an ordinary outcome, not an error.
    static func dnsWallet(_ wire: Wire.DNSRecordsResponse) throws -> String? {
        guard let record = wire.records?.first(where: { $0.dnsWalletAddress != nil }),
              let raw = record.dnsWalletAddress
        else { return nil }
        return try canonical(address: raw)
    }

    /// Reverse lookup: the domain that points at an address.
    static func dnsDomain(_ wire: Wire.DNSRecordsResponse) -> String? {
        wire.records?.first(where: { $0.domain != nil })?.domain
    }
}

extension Mappers {
    // MARK: - Emulation

    static func emulation(_ wire: Wire.EmulateTraceResponse) -> EmulationResult {
        let trace = wire.trace.flatMap(traceNode)

        // The response keys transactions by hash. Order them by the trace so the sender's
        // transaction comes first, which is what a preview needs; anything the trace does
        // not mention is appended so nothing is silently dropped.
        let byHash = wire.transactions ?? [:]
        var ordered: [ChainTransaction] = []
        var seen = Set<String>()

        func visit(_ node: Wire.EmulateTraceResponse.TraceNode) {
            if let hash = node.txHash, let tx = byHash[hash], !seen.contains(hash) {
                seen.insert(hash)
                ordered.append(transaction(tx))
            }
            for child in node.children ?? [] { visit(child) }
        }
        if let root = wire.trace { visit(root) }

        for (hash, tx) in byHash.sorted(by: { $0.key < $1.key }) where !seen.contains(hash) {
            ordered.append(transaction(tx))
        }

        return EmulationResult(
            mcBlockSeqno: wire.mcBlockSeqno ?? 0,
            transactions: ordered,
            trace: trace,
            // Absent means complete; only an explicit true marks a partial result.
            isIncomplete: wire.isIncomplete ?? false
        )
    }

    private static func traceNode(_ wire: Wire.EmulateTraceResponse.TraceNode) -> EmulationTraceNode? {
        guard let hash = wire.txHash else { return nil }
        return EmulationTraceNode(
            transactionHash: hash,
            children: (wire.children ?? []).compactMap(traceNode)
        )
    }
}

extension Mappers {
    // MARK: - Traces

    static func traces(_ wire: Wire.TracesResponse) -> [Trace] {
        (wire.traces ?? []).map(trace)
    }

    static func tracesPage(_ wire: Wire.TracesResponse) -> TracesPage {
        TracesPage(
            traces: traces(wire),
            addressBook: (wire.addressBook ?? [:]).compactMapValues { $0.domain ?? $0.userFriendly }
        )
    }

    static func trace(_ wire: Wire.TraceWire) -> Trace {
        let root = wire.trace.flatMap(traceNode)
        let byHash = wire.transactions ?? [:]

        // Order by the tree, which is causal order. `transactions_order` exists but the
        // tree is authoritative about causality, and a wallet explaining a transfer needs
        // cause before effect.
        var ordered: [ChainTransaction] = []
        var seen = Set<String>()
        if let root = wire.trace {
            for node in flatten(root) {
                guard let hash = node.txHash, let tx = byHash[hash], !seen.contains(hash) else { continue }
                seen.insert(hash)
                ordered.append(transaction(tx))
            }
        }
        // Anything the tree omits is appended rather than dropped.
        for (hash, tx) in byHash.sorted(by: { $0.key < $1.key }) where !seen.contains(hash) {
            ordered.append(transaction(tx))
        }

        return Trace(
            traceID: hexHash(fromBase64: wire.traceId) ?? "0x",
            externalHash: hexHash(fromBase64: wire.externalHash),
            startLogicalTime: wire.startLt,
            endLogicalTime: wire.endLt,
            startTime: wire.startUtime,
            endTime: wire.endUtime,
            isIncomplete: wire.isIncomplete ?? false,
            info: wire.traceInfo.map {
                TraceInfo(
                    state: $0.traceState,
                    messageCount: $0.messages ?? 0,
                    transactionCount: $0.transactions ?? 0,
                    pendingMessageCount: $0.pendingMessages ?? 0,
                    classificationState: $0.classificationState
                )
            },
            root: root,
            transactions: ordered
        )
    }

    private static func traceNode(_ wire: Wire.TraceNodeWire) -> TraceNode? {
        guard let hash = wire.txHash else { return nil }
        return TraceNode(
            transactionHash: hash,
            inMessageHash: wire.inMsgHash,
            children: (wire.children ?? []).compactMap(traceNode)
        )
    }

    /// Depth-first pre-order over the wire tree.
    private static func flatten(_ node: Wire.TraceNodeWire) -> [Wire.TraceNodeWire] {
        [node] + (node.children ?? []).flatMap(flatten)
    }
}
