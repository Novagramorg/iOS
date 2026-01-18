public extension Api {
    enum StarsAmount: TypeConstructorDescription {
        public class Cons_starsAmount {
            public var amount: Int64
            public var nanos: Int32
            public init(amount: Int64, nanos: Int32) {
                self.amount = amount
                self.nanos = nanos
            }
        }
        public class Cons_starsTonAmount {
            public var amount: Int64
            public init(amount: Int64) {
                self.amount = amount
            }
        }
        case starsAmount(Cons_starsAmount)
        case starsTonAmount(Cons_starsTonAmount)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_starsAmount(_ reader: BufferReader) -> StarsAmount? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_starsTonAmount(_ reader: BufferReader) -> StarsAmount? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StarsGiftOption: TypeConstructorDescription {
        public class Cons_starsGiftOption {
            public var flags: Int32
            public var stars: Int64
            public var storeProduct: String?
            public var currency: String
            public var amount: Int64
            public init(flags: Int32, stars: Int64, storeProduct: String?, currency: String, amount: Int64) {
                self.flags = flags
                self.stars = stars
                self.storeProduct = storeProduct
                self.currency = currency
                self.amount = amount
            }
        }
        case starsGiftOption(Cons_starsGiftOption)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_starsGiftOption(_ reader: BufferReader) -> StarsGiftOption? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StarsGiveawayOption: TypeConstructorDescription {
        public class Cons_starsGiveawayOption {
            public var flags: Int32
            public var stars: Int64
            public var yearlyBoosts: Int32
            public var storeProduct: String?
            public var currency: String
            public var amount: Int64
            public var winners: [Api.StarsGiveawayWinnersOption]
            public init(flags: Int32, stars: Int64, yearlyBoosts: Int32, storeProduct: String?, currency: String, amount: Int64, winners: [Api.StarsGiveawayWinnersOption]) {
                self.flags = flags
                self.stars = stars
                self.yearlyBoosts = yearlyBoosts
                self.storeProduct = storeProduct
                self.currency = currency
                self.amount = amount
                self.winners = winners
            }
        }
        case starsGiveawayOption(Cons_starsGiveawayOption)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_starsGiveawayOption(_ reader: BufferReader) -> StarsGiveawayOption? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StarsGiveawayWinnersOption: TypeConstructorDescription {
        public class Cons_starsGiveawayWinnersOption {
            public var flags: Int32
            public var users: Int32
            public var perUserStars: Int64
            public init(flags: Int32, users: Int32, perUserStars: Int64) {
                self.flags = flags
                self.users = users
                self.perUserStars = perUserStars
            }
        }
        case starsGiveawayWinnersOption(Cons_starsGiveawayWinnersOption)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_starsGiveawayWinnersOption(_ reader: BufferReader) -> StarsGiveawayWinnersOption? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StarsRating: TypeConstructorDescription {
        public class Cons_starsRating {
            public var flags: Int32
            public var level: Int32
            public var currentLevelStars: Int64
            public var stars: Int64
            public var nextLevelStars: Int64?
            public init(flags: Int32, level: Int32, currentLevelStars: Int64, stars: Int64, nextLevelStars: Int64?) {
                self.flags = flags
                self.level = level
                self.currentLevelStars = currentLevelStars
                self.stars = stars
                self.nextLevelStars = nextLevelStars
            }
        }
        case starsRating(Cons_starsRating)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_starsRating(_ reader: BufferReader) -> StarsRating? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StarsRevenueStatus: TypeConstructorDescription {
        public class Cons_starsRevenueStatus {
            public var flags: Int32
            public var currentBalance: Api.StarsAmount
            public var availableBalance: Api.StarsAmount
            public var overallRevenue: Api.StarsAmount
            public var nextWithdrawalAt: Int32?
            public init(flags: Int32, currentBalance: Api.StarsAmount, availableBalance: Api.StarsAmount, overallRevenue: Api.StarsAmount, nextWithdrawalAt: Int32?) {
                self.flags = flags
                self.currentBalance = currentBalance
                self.availableBalance = availableBalance
                self.overallRevenue = overallRevenue
                self.nextWithdrawalAt = nextWithdrawalAt
            }
        }
        case starsRevenueStatus(Cons_starsRevenueStatus)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_starsRevenueStatus(_ reader: BufferReader) -> StarsRevenueStatus? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StarsSubscription: TypeConstructorDescription {
        case starsSubscription(flags: Int32, id: String, peer: Api.Peer, untilDate: Int32, pricing: Api.StarsSubscriptionPricing, chatInviteHash: String?, title: String?, photo: Api.WebDocument?, invoiceSlug: String?)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_starsSubscription(_ reader: BufferReader) -> StarsSubscription? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StarsSubscriptionPricing: TypeConstructorDescription {
        case starsSubscriptionPricing(period: Int32, amount: Int64)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_starsSubscriptionPricing(_ reader: BufferReader) -> StarsSubscriptionPricing? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StarsTopupOption: TypeConstructorDescription {
        case starsTopupOption(flags: Int32, stars: Int64, storeProduct: String?, currency: String, amount: Int64)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_starsTopupOption(_ reader: BufferReader) -> StarsTopupOption? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StarsTransaction: TypeConstructorDescription {
        case starsTransaction(flags: Int32, id: String, amount: Api.StarsAmount, date: Int32, peer: Api.StarsTransactionPeer, title: String?, description: String?, photo: Api.WebDocument?, transactionDate: Int32?, transactionUrl: String?, botPayload: Buffer?, msgId: Int32?, extendedMedia: [Api.MessageMedia]?, subscriptionPeriod: Int32?, giveawayPostId: Int32?, stargift: Api.StarGift?, floodskipNumber: Int32?, starrefCommissionPermille: Int32?, starrefPeer: Api.Peer?, starrefAmount: Api.StarsAmount?, paidMessages: Int32?, premiumGiftMonths: Int32?, adsProceedsFromDate: Int32?, adsProceedsToDate: Int32?)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_starsTransaction(_ reader: BufferReader) -> StarsTransaction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StarsTransactionPeer: TypeConstructorDescription {
        case starsTransactionPeer(peer: Api.Peer)
        case starsTransactionPeerAPI
        case starsTransactionPeerAds
        case starsTransactionPeerAppStore
        case starsTransactionPeerFragment
        case starsTransactionPeerPlayMarket
        case starsTransactionPeerPremiumBot
        case starsTransactionPeerUnsupported

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_starsTransactionPeer(_ reader: BufferReader) -> StarsTransactionPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_starsTransactionPeerAPI(_ reader: BufferReader) -> StarsTransactionPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_starsTransactionPeerAds(_ reader: BufferReader) -> StarsTransactionPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_starsTransactionPeerAppStore(_ reader: BufferReader) -> StarsTransactionPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_starsTransactionPeerFragment(_ reader: BufferReader) -> StarsTransactionPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_starsTransactionPeerPlayMarket(_ reader: BufferReader) -> StarsTransactionPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_starsTransactionPeerPremiumBot(_ reader: BufferReader) -> StarsTransactionPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_starsTransactionPeerUnsupported(_ reader: BufferReader) -> StarsTransactionPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StatsAbsValueAndPrev: TypeConstructorDescription {
        case statsAbsValueAndPrev(current: Double, previous: Double)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_statsAbsValueAndPrev(_ reader: BufferReader) -> StatsAbsValueAndPrev? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StatsDateRangeDays: TypeConstructorDescription {
        case statsDateRangeDays(minDate: Int32, maxDate: Int32)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_statsDateRangeDays(_ reader: BufferReader) -> StatsDateRangeDays? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StatsGraph: TypeConstructorDescription {
        case statsGraph(flags: Int32, json: Api.DataJSON, zoomToken: String?)
        case statsGraphAsync(token: String)
        case statsGraphError(error: String)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_statsGraph(_ reader: BufferReader) -> StatsGraph? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_statsGraphAsync(_ reader: BufferReader) -> StatsGraph? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_statsGraphError(_ reader: BufferReader) -> StatsGraph? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StatsGroupTopAdmin: TypeConstructorDescription {
        case statsGroupTopAdmin(userId: Int64, deleted: Int32, kicked: Int32, banned: Int32)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_statsGroupTopAdmin(_ reader: BufferReader) -> StatsGroupTopAdmin? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StatsGroupTopInviter: TypeConstructorDescription {
        case statsGroupTopInviter(userId: Int64, invitations: Int32)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_statsGroupTopInviter(_ reader: BufferReader) -> StatsGroupTopInviter? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StatsGroupTopPoster: TypeConstructorDescription {
        case statsGroupTopPoster(userId: Int64, messages: Int32, avgChars: Int32)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_statsGroupTopPoster(_ reader: BufferReader) -> StatsGroupTopPoster? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StatsPercentValue: TypeConstructorDescription {
        case statsPercentValue(part: Double, total: Double)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_statsPercentValue(_ reader: BufferReader) -> StatsPercentValue? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StatsURL: TypeConstructorDescription {
        case statsURL(url: String)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_statsURL(_ reader: BufferReader) -> StatsURL? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StickerKeyword: TypeConstructorDescription {
        case stickerKeyword(documentId: Int64, keyword: [String])

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_stickerKeyword(_ reader: BufferReader) -> StickerKeyword? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StickerPack: TypeConstructorDescription {
        case stickerPack(emoticon: String, documents: [Int64])

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_stickerPack(_ reader: BufferReader) -> StickerPack? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StickerSet: TypeConstructorDescription {
        case stickerSet(flags: Int32, installedDate: Int32?, id: Int64, accessHash: Int64, title: String, shortName: String, thumbs: [Api.PhotoSize]?, thumbDcId: Int32?, thumbVersion: Int32?, thumbDocumentId: Int64?, count: Int32, hash: Int32)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_stickerSet(_ reader: BufferReader) -> StickerSet? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
