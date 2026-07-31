import Foundation

public struct TONAccountActionsResponse: Codable {
    public let actions: [TONTransactionTraceAction]
    public let addressBook: [String: TONAddressBookEntry]
    public let metadata: [String: TONAccountActionMetadata]

    public init(
        actions: [TONTransactionTraceAction],
        addressBook: [String: TONAddressBookEntry],
        metadata: [String: TONAccountActionMetadata]
    ) {
        self.actions = actions
        self.addressBook = addressBook
        self.metadata = metadata
    }
}

extension TONAccountActionsResponse: JSValueCodable {}

public struct TONAccountActionMetadata: Codable {
    public let isIndexed: Bool?
    public let tokenInfo: [TONAccountActionTokenInfo]

    public init(isIndexed: Bool?, tokenInfo: [TONAccountActionTokenInfo]) {
        self.isIndexed = isIndexed
        self.tokenInfo = tokenInfo
    }
}

extension TONAccountActionMetadata: JSValueCodable {}

public struct TONAccountActionTokenInfo: Codable {
    public let type: String
    public let name: String?
    public let description: String?
    public let image: String?
    public let symbol: String?
    public let nftIndex: String?
    public let valid: Bool?
    public let isScam: Bool?
    public let isNsfw: Bool?
    public let extra: [String: AnyCodable]
    public let lottie: String?

    public init(
        type: String,
        name: String?,
        description: String?,
        image: String?,
        symbol: String?,
        nftIndex: String?,
        valid: Bool?,
        isScam: Bool?,
        isNsfw: Bool?,
        extra: [String: AnyCodable],
        lottie: String? = nil
    ) {
        self.type = type
        self.name = name
        self.description = description
        self.image = image
        self.symbol = symbol
        self.nftIndex = nftIndex
        self.valid = valid
        self.isScam = isScam
        self.isNsfw = isNsfw
        self.extra = extra
        self.lottie = lottie
    }
}

extension TONAccountActionTokenInfo: JSValueCodable {}

public struct TONTransactionTraceActionJettonTransferDetails: Codable {
    public let asset: TONUserFriendlyAddress?
    public let sender: TONUserFriendlyAddress?
    public let receiver: TONUserFriendlyAddress?
    public let senderJettonWallet: TONUserFriendlyAddress?
    public let receiverJettonWallet: TONUserFriendlyAddress?
    public let amount: String
    public let comment: String?

    public init(
        asset: TONUserFriendlyAddress?,
        sender: TONUserFriendlyAddress?,
        receiver: TONUserFriendlyAddress?,
        senderJettonWallet: TONUserFriendlyAddress?,
        receiverJettonWallet: TONUserFriendlyAddress?,
        amount: String,
        comment: String?
    ) {
        self.asset = asset
        self.sender = sender
        self.receiver = receiver
        self.senderJettonWallet = senderJettonWallet
        self.receiverJettonWallet = receiverJettonWallet
        self.amount = amount
        self.comment = comment
    }
}

extension TONTransactionTraceActionJettonTransferDetails: JSValueCodable {}

public struct TONTransactionTraceActionNFTTransferDetails: Codable {
    public let nftCollection: TONUserFriendlyAddress?
    public let nftItem: TONUserFriendlyAddress
    public let nftItemIndex: String?
    public let newOwner: TONUserFriendlyAddress?
    public let oldOwner: TONUserFriendlyAddress?
    public let isPurchase: Bool

    public init(
        nftCollection: TONUserFriendlyAddress?,
        nftItem: TONUserFriendlyAddress,
        nftItemIndex: String?,
        newOwner: TONUserFriendlyAddress?,
        oldOwner: TONUserFriendlyAddress?,
        isPurchase: Bool
    ) {
        self.nftCollection = nftCollection
        self.nftItem = nftItem
        self.nftItemIndex = nftItemIndex
        self.newOwner = newOwner
        self.oldOwner = oldOwner
        self.isPurchase = isPurchase
    }
}

extension TONTransactionTraceActionNFTTransferDetails: JSValueCodable {}
