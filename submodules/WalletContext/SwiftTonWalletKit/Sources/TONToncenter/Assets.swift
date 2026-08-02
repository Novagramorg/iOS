import Foundation
import TONCore

/// A jetton holding: the master contract, the owner's jetton wallet, and the balance.
public struct JettonHolding: Sendable {
    /// Jetton master (the token contract), canonical friendly form.
    public let master: String
    /// The owner's jetton wallet for this token — the contract a transfer is sent *to*.
    public let walletAddress: String
    /// Balance in the token's base units, as a decimal string.
    public let balance: String
    public let info: JettonInfo?

    public init(master: String, walletAddress: String, balance: String, info: JettonInfo? = nil) {
        self.master = master
        self.walletAddress = walletAddress
        self.balance = balance
        self.info = info
    }

    /// Balance rendered with the token's decimals, or the raw value when decimals are
    /// unknown.
    ///
    /// Never guesses a decimals value: showing a wrongly scaled balance is worse than
    /// showing base units.
    public var formattedBalance: String? {
        guard let decimals = info?.decimals, let amount = BigUInt(balance) else { return nil }
        return Units.formatUnits(amount, decimals: decimals)
    }
}

/// Token metadata, as Toncenter's indexer reports it.
public struct JettonInfo: Sendable {
    public let name: String?
    public let symbol: String?
    public let description: String?
    public let imageURL: String?
    public let decimals: Int?
    public let isScam: Bool
    public let isNSFW: Bool

    public init(
        name: String? = nil,
        symbol: String? = nil,
        description: String? = nil,
        imageURL: String? = nil,
        decimals: Int? = nil,
        isScam: Bool = false,
        isNSFW: Bool = false
    ) {
        self.name = name
        self.symbol = symbol
        self.description = description
        self.imageURL = imageURL
        self.decimals = decimals
        self.isScam = isScam
        self.isNSFW = isNSFW
    }
}

/// Toncenter metadata attached to an NFT item or collection.
public struct NFTInfo: Sendable {
    public let name: String?
    public let description: String?
    public let imageURL: String?
    public let isScam: Bool
    public let isNSFW: Bool
    public let extra: [String: String]

    public init(
        name: String? = nil,
        description: String? = nil,
        imageURL: String? = nil,
        isScam: Bool = false,
        isNSFW: Bool = false,
        extra: [String: String] = [:]
    ) {
        self.name = name
        self.description = description
        self.imageURL = imageURL
        self.isScam = isScam
        self.isNSFW = isNSFW
        self.extra = extra
    }
}

/// An NFT item.
public struct NFTItem: Sendable {
    public let address: String
    public let index: String?
    public let ownerAddress: String?
    /// Present when the item sits in a sale contract: the beneficial owner behind it.
    public let realOwnerAddress: String?
    public let collectionAddress: String?
    public let codeHash: String?
    public let dataHash: String?
    public let isInited: Bool
    public let isOnSale: Bool
    /// Raw content dictionary — an off-chain URI, or on-chain attributes.
    public let content: [String: String]
    public let info: NFTInfo?
    public let collectionInfo: NFTInfo?

    public init(
        address: String,
        index: String? = nil,
        ownerAddress: String? = nil,
        realOwnerAddress: String? = nil,
        collectionAddress: String? = nil,
        codeHash: String? = nil,
        dataHash: String? = nil,
        isInited: Bool = false,
        isOnSale: Bool = false,
        content: [String: String] = [:],
        info: NFTInfo? = nil,
        collectionInfo: NFTInfo? = nil
    ) {
        self.address = address
        self.index = index
        self.ownerAddress = ownerAddress
        self.realOwnerAddress = realOwnerAddress
        self.collectionAddress = collectionAddress
        self.codeHash = codeHash
        self.dataHash = dataHash
        self.isInited = isInited
        self.isOnSale = isOnSale
        self.content = content
        self.info = info
        self.collectionInfo = collectionInfo
    }

    /// Off-chain metadata location, when the item uses one.
    public var contentURI: String? { content["uri"] }

    /// Whether transferring requires going through a sale contract first.
    ///
    /// `ownerAddress` is the sale contract in that case, so sending a transfer to the
    /// item directly would fail.
    public var isEscrowed: Bool {
        isOnSale || (realOwnerAddress != nil && realOwnerAddress != ownerAddress)
    }
}

/// A page of jetton holdings.
public struct JettonsPage: Sendable {
    public let jettons: [JettonHolding]
    public let addressBook: [String: String]

    public init(jettons: [JettonHolding], addressBook: [String: String] = [:]) {
        self.jettons = jettons
        self.addressBook = addressBook
    }
}

/// A page of NFT items.
public struct NFTsPage: Sendable {
    public let nfts: [NFTItem]
    public let addressBook: [String: String]

    public init(nfts: [NFTItem], addressBook: [String: String] = [:]) {
        self.nfts = nfts
        self.addressBook = addressBook
    }
}
