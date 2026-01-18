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
        public class Cons_starsSubscription {
            public var flags: Int32
            public var id: String
            public var peer: Api.Peer
            public var untilDate: Int32
            public var pricing: Api.StarsSubscriptionPricing
            public var chatInviteHash: String?
            public var title: String?
            public var photo: Api.WebDocument?
            public var invoiceSlug: String?
            public init(flags: Int32, id: String, peer: Api.Peer, untilDate: Int32, pricing: Api.StarsSubscriptionPricing, chatInviteHash: String?, title: String?, photo: Api.WebDocument?, invoiceSlug: String?) {
                self.flags = flags
                self.id = id
                self.peer = peer
                self.untilDate = untilDate
                self.pricing = pricing
                self.chatInviteHash = chatInviteHash
                self.title = title
                self.photo = photo
                self.invoiceSlug = invoiceSlug
            }
        }
        case starsSubscription(Cons_starsSubscription)

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
        public class Cons_starsSubscriptionPricing {
            public var period: Int32
            public var amount: Int64
            public init(period: Int32, amount: Int64) {
                self.period = period
                self.amount = amount
            }
        }
        case starsSubscriptionPricing(Cons_starsSubscriptionPricing)

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
        public class Cons_starsTopupOption {
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
        case starsTopupOption(Cons_starsTopupOption)

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
        public class Cons_starsTransaction {
            public var flags: Int32
            public var id: String
            public var amount: Api.StarsAmount
            public var date: Int32
            public var peer: Api.StarsTransactionPeer
            public var title: String?
            public var description: String?
            public var photo: Api.WebDocument?
            public var transactionDate: Int32?
            public var transactionUrl: String?
            public var botPayload: Buffer?
            public var msgId: Int32?
            public var extendedMedia: [Api.MessageMedia]?
            public var subscriptionPeriod: Int32?
            public var giveawayPostId: Int32?
            public var stargift: Api.StarGift?
            public var floodskipNumber: Int32?
            public var starrefCommissionPermille: Int32?
            public var starrefPeer: Api.Peer?
            public var starrefAmount: Api.StarsAmount?
            public var paidMessages: Int32?
            public var premiumGiftMonths: Int32?
            public var adsProceedsFromDate: Int32?
            public var adsProceedsToDate: Int32?
            public init(flags: Int32, id: String, amount: Api.StarsAmount, date: Int32, peer: Api.StarsTransactionPeer, title: String?, description: String?, photo: Api.WebDocument?, transactionDate: Int32?, transactionUrl: String?, botPayload: Buffer?, msgId: Int32?, extendedMedia: [Api.MessageMedia]?, subscriptionPeriod: Int32?, giveawayPostId: Int32?, stargift: Api.StarGift?, floodskipNumber: Int32?, starrefCommissionPermille: Int32?, starrefPeer: Api.Peer?, starrefAmount: Api.StarsAmount?, paidMessages: Int32?, premiumGiftMonths: Int32?, adsProceedsFromDate: Int32?, adsProceedsToDate: Int32?) {
                self.flags = flags
                self.id = id
                self.amount = amount
                self.date = date
                self.peer = peer
                self.title = title
                self.description = description
                self.photo = photo
                self.transactionDate = transactionDate
                self.transactionUrl = transactionUrl
                self.botPayload = botPayload
                self.msgId = msgId
                self.extendedMedia = extendedMedia
                self.subscriptionPeriod = subscriptionPeriod
                self.giveawayPostId = giveawayPostId
                self.stargift = stargift
                self.floodskipNumber = floodskipNumber
                self.starrefCommissionPermille = starrefCommissionPermille
                self.starrefPeer = starrefPeer
                self.starrefAmount = starrefAmount
                self.paidMessages = paidMessages
                self.premiumGiftMonths = premiumGiftMonths
                self.adsProceedsFromDate = adsProceedsFromDate
                self.adsProceedsToDate = adsProceedsToDate
            }
        }
        case starsTransaction(Cons_starsTransaction)

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
        public class Cons_starsTransactionPeer {
            public var peer: Api.Peer
            public init(peer: Api.Peer) {
                self.peer = peer
            }
        }
        case starsTransactionPeer(Cons_starsTransactionPeer)
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
        public class Cons_statsAbsValueAndPrev {
            public var current: Double
            public var previous: Double
            public init(current: Double, previous: Double) {
                self.current = current
                self.previous = previous
            }
        }
        case statsAbsValueAndPrev(Cons_statsAbsValueAndPrev)

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
        public class Cons_statsDateRangeDays {
            public var minDate: Int32
            public var maxDate: Int32
            public init(minDate: Int32, maxDate: Int32) {
                self.minDate = minDate
                self.maxDate = maxDate
            }
        }
        case statsDateRangeDays(Cons_statsDateRangeDays)

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
        public class Cons_statsGraph {
            public var flags: Int32
            public var json: Api.DataJSON
            public var zoomToken: String?
            public init(flags: Int32, json: Api.DataJSON, zoomToken: String?) {
                self.flags = flags
                self.json = json
                self.zoomToken = zoomToken
            }
        }
        public class Cons_statsGraphAsync {
            public var token: String
            public init(token: String) {
                self.token = token
            }
        }
        public class Cons_statsGraphError {
            public var error: String
            public init(error: String) {
                self.error = error
            }
        }
        case statsGraph(Cons_statsGraph)
        case statsGraphAsync(Cons_statsGraphAsync)
        case statsGraphError(Cons_statsGraphError)

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
        public class Cons_statsGroupTopAdmin {
            public var userId: Int64
            public var deleted: Int32
            public var kicked: Int32
            public var banned: Int32
            public init(userId: Int64, deleted: Int32, kicked: Int32, banned: Int32) {
                self.userId = userId
                self.deleted = deleted
                self.kicked = kicked
                self.banned = banned
            }
        }
        case statsGroupTopAdmin(Cons_statsGroupTopAdmin)

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
        public class Cons_statsGroupTopInviter {
            public var userId: Int64
            public var invitations: Int32
            public init(userId: Int64, invitations: Int32) {
                self.userId = userId
                self.invitations = invitations
            }
        }
        case statsGroupTopInviter(Cons_statsGroupTopInviter)

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
        public class Cons_statsGroupTopPoster {
            public var userId: Int64
            public var messages: Int32
            public var avgChars: Int32
            public init(userId: Int64, messages: Int32, avgChars: Int32) {
                self.userId = userId
                self.messages = messages
                self.avgChars = avgChars
            }
        }
        case statsGroupTopPoster(Cons_statsGroupTopPoster)

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
        public class Cons_statsPercentValue {
            public var part: Double
            public var total: Double
            public init(part: Double, total: Double) {
                self.part = part
                self.total = total
            }
        }
        case statsPercentValue(Cons_statsPercentValue)

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
        public class Cons_statsURL {
            public var url: String
            public init(url: String) {
                self.url = url
            }
        }
        case statsURL(Cons_statsURL)

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
        public class Cons_stickerKeyword {
            public var documentId: Int64
            public var keyword: [String]
            public init(documentId: Int64, keyword: [String]) {
                self.documentId = documentId
                self.keyword = keyword
            }
        }
        case stickerKeyword(Cons_stickerKeyword)

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
        public class Cons_stickerPack {
            public var emoticon: String
            public var documents: [Int64]
            public init(emoticon: String, documents: [Int64]) {
                self.emoticon = emoticon
                self.documents = documents
            }
        }
        case stickerPack(Cons_stickerPack)

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
        public class Cons_stickerSet {
            public var flags: Int32
            public var installedDate: Int32?
            public var id: Int64
            public var accessHash: Int64
            public var title: String
            public var shortName: String
            public var thumbs: [Api.PhotoSize]?
            public var thumbDcId: Int32?
            public var thumbVersion: Int32?
            public var thumbDocumentId: Int64?
            public var count: Int32
            public var hash: Int32
            public init(flags: Int32, installedDate: Int32?, id: Int64, accessHash: Int64, title: String, shortName: String, thumbs: [Api.PhotoSize]?, thumbDcId: Int32?, thumbVersion: Int32?, thumbDocumentId: Int64?, count: Int32, hash: Int32) {
                self.flags = flags
                self.installedDate = installedDate
                self.id = id
                self.accessHash = accessHash
                self.title = title
                self.shortName = shortName
                self.thumbs = thumbs
                self.thumbDcId = thumbDcId
                self.thumbVersion = thumbVersion
                self.thumbDocumentId = thumbDocumentId
                self.count = count
                self.hash = hash
            }
        }
        case stickerSet(Cons_stickerSet)

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
