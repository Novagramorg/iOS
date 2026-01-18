public extension Api.payments {
    enum PaymentReceipt: TypeConstructorDescription {
        public class Cons_paymentReceipt {
            public var flags: Int32
            public var date: Int32
            public var botId: Int64
            public var providerId: Int64
            public var title: String
            public var description: String
            public var photo: Api.WebDocument?
            public var invoice: Api.Invoice
            public var info: Api.PaymentRequestedInfo?
            public var shipping: Api.ShippingOption?
            public var tipAmount: Int64?
            public var currency: String
            public var totalAmount: Int64
            public var credentialsTitle: String
            public var users: [Api.User]
            public init(flags: Int32, date: Int32, botId: Int64, providerId: Int64, title: String, description: String, photo: Api.WebDocument?, invoice: Api.Invoice, info: Api.PaymentRequestedInfo?, shipping: Api.ShippingOption?, tipAmount: Int64?, currency: String, totalAmount: Int64, credentialsTitle: String, users: [Api.User]) {
                self.flags = flags
                self.date = date
                self.botId = botId
                self.providerId = providerId
                self.title = title
                self.description = description
                self.photo = photo
                self.invoice = invoice
                self.info = info
                self.shipping = shipping
                self.tipAmount = tipAmount
                self.currency = currency
                self.totalAmount = totalAmount
                self.credentialsTitle = credentialsTitle
                self.users = users
            }
        }
        public class Cons_paymentReceiptStars {
            public var flags: Int32
            public var date: Int32
            public var botId: Int64
            public var title: String
            public var description: String
            public var photo: Api.WebDocument?
            public var invoice: Api.Invoice
            public var currency: String
            public var totalAmount: Int64
            public var transactionId: String
            public var users: [Api.User]
            public init(flags: Int32, date: Int32, botId: Int64, title: String, description: String, photo: Api.WebDocument?, invoice: Api.Invoice, currency: String, totalAmount: Int64, transactionId: String, users: [Api.User]) {
                self.flags = flags
                self.date = date
                self.botId = botId
                self.title = title
                self.description = description
                self.photo = photo
                self.invoice = invoice
                self.currency = currency
                self.totalAmount = totalAmount
                self.transactionId = transactionId
                self.users = users
            }
        }
        case paymentReceipt(Cons_paymentReceipt)
        case paymentReceiptStars(Cons_paymentReceiptStars)

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

        public static func parse_paymentReceipt(_ reader: BufferReader) -> PaymentReceipt? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_paymentReceiptStars(_ reader: BufferReader) -> PaymentReceipt? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.payments {
    indirect enum PaymentResult: TypeConstructorDescription {
        public class Cons_paymentResult {
            public var updates: Api.Updates
            public init(updates: Api.Updates) {
                self.updates = updates
            }
        }
        public class Cons_paymentVerificationNeeded {
            public var url: String
            public init(url: String) {
                self.url = url
            }
        }
        case paymentResult(Cons_paymentResult)
        case paymentVerificationNeeded(Cons_paymentVerificationNeeded)

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

        public static func parse_paymentResult(_ reader: BufferReader) -> PaymentResult? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_paymentVerificationNeeded(_ reader: BufferReader) -> PaymentResult? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.payments {
    enum ResaleStarGifts: TypeConstructorDescription {
        public class Cons_resaleStarGifts {
            public var flags: Int32
            public var count: Int32
            public var gifts: [Api.StarGift]
            public var nextOffset: String?
            public var attributes: [Api.StarGiftAttribute]?
            public var attributesHash: Int64?
            public var chats: [Api.Chat]
            public var counters: [Api.StarGiftAttributeCounter]?
            public var users: [Api.User]
            public init(flags: Int32, count: Int32, gifts: [Api.StarGift], nextOffset: String?, attributes: [Api.StarGiftAttribute]?, attributesHash: Int64?, chats: [Api.Chat], counters: [Api.StarGiftAttributeCounter]?, users: [Api.User]) {
                self.flags = flags
                self.count = count
                self.gifts = gifts
                self.nextOffset = nextOffset
                self.attributes = attributes
                self.attributesHash = attributesHash
                self.chats = chats
                self.counters = counters
                self.users = users
            }
        }
        case resaleStarGifts(Cons_resaleStarGifts)

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

        public static func parse_resaleStarGifts(_ reader: BufferReader) -> ResaleStarGifts? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.payments {
    enum SavedInfo: TypeConstructorDescription {
        public class Cons_savedInfo {
            public var flags: Int32
            public var savedInfo: Api.PaymentRequestedInfo?
            public init(flags: Int32, savedInfo: Api.PaymentRequestedInfo?) {
                self.flags = flags
                self.savedInfo = savedInfo
            }
        }
        case savedInfo(Cons_savedInfo)

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

        public static func parse_savedInfo(_ reader: BufferReader) -> SavedInfo? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.payments {
    enum SavedStarGifts: TypeConstructorDescription {
        public class Cons_savedStarGifts {
            public var flags: Int32
            public var count: Int32
            public var chatNotificationsEnabled: Api.Bool?
            public var gifts: [Api.SavedStarGift]
            public var nextOffset: String?
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(flags: Int32, count: Int32, chatNotificationsEnabled: Api.Bool?, gifts: [Api.SavedStarGift], nextOffset: String?, chats: [Api.Chat], users: [Api.User]) {
                self.flags = flags
                self.count = count
                self.chatNotificationsEnabled = chatNotificationsEnabled
                self.gifts = gifts
                self.nextOffset = nextOffset
                self.chats = chats
                self.users = users
            }
        }
        case savedStarGifts(Cons_savedStarGifts)

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

        public static func parse_savedStarGifts(_ reader: BufferReader) -> SavedStarGifts? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.payments {
    enum StarGiftActiveAuctions: TypeConstructorDescription {
        public class Cons_starGiftActiveAuctions {
            public var auctions: [Api.StarGiftActiveAuctionState]
            public var users: [Api.User]
            public var chats: [Api.Chat]
            public init(auctions: [Api.StarGiftActiveAuctionState], users: [Api.User], chats: [Api.Chat]) {
                self.auctions = auctions
                self.users = users
                self.chats = chats
            }
        }
        case starGiftActiveAuctions(Cons_starGiftActiveAuctions)
        case starGiftActiveAuctionsNotModified

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

        public static func parse_starGiftActiveAuctions(_ reader: BufferReader) -> StarGiftActiveAuctions? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_starGiftActiveAuctionsNotModified(_ reader: BufferReader) -> StarGiftActiveAuctions? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.payments {
    enum StarGiftAuctionAcquiredGifts: TypeConstructorDescription {
        public class Cons_starGiftAuctionAcquiredGifts {
            public var gifts: [Api.StarGiftAuctionAcquiredGift]
            public var users: [Api.User]
            public var chats: [Api.Chat]
            public init(gifts: [Api.StarGiftAuctionAcquiredGift], users: [Api.User], chats: [Api.Chat]) {
                self.gifts = gifts
                self.users = users
                self.chats = chats
            }
        }
        case starGiftAuctionAcquiredGifts(Cons_starGiftAuctionAcquiredGifts)

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

        public static func parse_starGiftAuctionAcquiredGifts(_ reader: BufferReader) -> StarGiftAuctionAcquiredGifts? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.payments {
    enum StarGiftAuctionState: TypeConstructorDescription {
        public class Cons_starGiftAuctionState {
            public var gift: Api.StarGift
            public var state: Api.StarGiftAuctionState
            public var userState: Api.StarGiftAuctionUserState
            public var timeout: Int32
            public var users: [Api.User]
            public var chats: [Api.Chat]
            public init(gift: Api.StarGift, state: Api.StarGiftAuctionState, userState: Api.StarGiftAuctionUserState, timeout: Int32, users: [Api.User], chats: [Api.Chat]) {
                self.gift = gift
                self.state = state
                self.userState = userState
                self.timeout = timeout
                self.users = users
                self.chats = chats
            }
        }
        case starGiftAuctionState(Cons_starGiftAuctionState)

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

        public static func parse_starGiftAuctionState(_ reader: BufferReader) -> StarGiftAuctionState? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.payments {
    enum StarGiftCollections: TypeConstructorDescription {
        public class Cons_starGiftCollections {
            public var collections: [Api.StarGiftCollection]
            public init(collections: [Api.StarGiftCollection]) {
                self.collections = collections
            }
        }
        case starGiftCollections(Cons_starGiftCollections)
        case starGiftCollectionsNotModified

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

        public static func parse_starGiftCollections(_ reader: BufferReader) -> StarGiftCollections? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_starGiftCollectionsNotModified(_ reader: BufferReader) -> StarGiftCollections? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.payments {
    enum StarGiftUpgradeAttributes: TypeConstructorDescription {
        public class Cons_starGiftUpgradeAttributes {
            public var attributes: [Api.StarGiftAttribute]
            public init(attributes: [Api.StarGiftAttribute]) {
                self.attributes = attributes
            }
        }
        case starGiftUpgradeAttributes(Cons_starGiftUpgradeAttributes)

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

        public static func parse_starGiftUpgradeAttributes(_ reader: BufferReader) -> StarGiftUpgradeAttributes? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.payments {
    enum StarGiftUpgradePreview: TypeConstructorDescription {
        public class Cons_starGiftUpgradePreview {
            public var sampleAttributes: [Api.StarGiftAttribute]
            public var prices: [Api.StarGiftUpgradePrice]
            public var nextPrices: [Api.StarGiftUpgradePrice]
            public init(sampleAttributes: [Api.StarGiftAttribute], prices: [Api.StarGiftUpgradePrice], nextPrices: [Api.StarGiftUpgradePrice]) {
                self.sampleAttributes = sampleAttributes
                self.prices = prices
                self.nextPrices = nextPrices
            }
        }
        case starGiftUpgradePreview(Cons_starGiftUpgradePreview)

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

        public static func parse_starGiftUpgradePreview(_ reader: BufferReader) -> StarGiftUpgradePreview? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.payments {
    enum StarGiftWithdrawalUrl: TypeConstructorDescription {
        public class Cons_starGiftWithdrawalUrl {
            public var url: String
            public init(url: String) {
                self.url = url
            }
        }
        case starGiftWithdrawalUrl(Cons_starGiftWithdrawalUrl)

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

        public static func parse_starGiftWithdrawalUrl(_ reader: BufferReader) -> StarGiftWithdrawalUrl? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.payments {
    enum StarGifts: TypeConstructorDescription {
        public class Cons_starGifts {
            public var hash: Int32
            public var gifts: [Api.StarGift]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(hash: Int32, gifts: [Api.StarGift], chats: [Api.Chat], users: [Api.User]) {
                self.hash = hash
                self.gifts = gifts
                self.chats = chats
                self.users = users
            }
        }
        case starGifts(Cons_starGifts)
        case starGiftsNotModified

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

        public static func parse_starGifts(_ reader: BufferReader) -> StarGifts? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_starGiftsNotModified(_ reader: BufferReader) -> StarGifts? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.payments {
    enum StarsRevenueAdsAccountUrl: TypeConstructorDescription {
        public class Cons_starsRevenueAdsAccountUrl {
            public var url: String
            public init(url: String) {
                self.url = url
            }
        }
        case starsRevenueAdsAccountUrl(Cons_starsRevenueAdsAccountUrl)

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

        public static func parse_starsRevenueAdsAccountUrl(_ reader: BufferReader) -> StarsRevenueAdsAccountUrl? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.payments {
    enum StarsRevenueStats: TypeConstructorDescription {
        public class Cons_starsRevenueStats {
            public var flags: Int32
            public var topHoursGraph: Api.StatsGraph?
            public var revenueGraph: Api.StatsGraph
            public var status: Api.StarsRevenueStatus
            public var usdRate: Double
            public init(flags: Int32, topHoursGraph: Api.StatsGraph?, revenueGraph: Api.StatsGraph, status: Api.StarsRevenueStatus, usdRate: Double) {
                self.flags = flags
                self.topHoursGraph = topHoursGraph
                self.revenueGraph = revenueGraph
                self.status = status
                self.usdRate = usdRate
            }
        }
        case starsRevenueStats(Cons_starsRevenueStats)

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

        public static func parse_starsRevenueStats(_ reader: BufferReader) -> StarsRevenueStats? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.payments {
    enum StarsRevenueWithdrawalUrl: TypeConstructorDescription {
        public class Cons_starsRevenueWithdrawalUrl {
            public var url: String
            public init(url: String) {
                self.url = url
            }
        }
        case starsRevenueWithdrawalUrl(Cons_starsRevenueWithdrawalUrl)

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

        public static func parse_starsRevenueWithdrawalUrl(_ reader: BufferReader) -> StarsRevenueWithdrawalUrl? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.payments {
    enum StarsStatus: TypeConstructorDescription {
        public class Cons_starsStatus {
            public var flags: Int32
            public var balance: Api.StarsAmount
            public var subscriptions: [Api.StarsSubscription]?
            public var subscriptionsNextOffset: String?
            public var subscriptionsMissingBalance: Int64?
            public var history: [Api.StarsTransaction]?
            public var nextOffset: String?
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(flags: Int32, balance: Api.StarsAmount, subscriptions: [Api.StarsSubscription]?, subscriptionsNextOffset: String?, subscriptionsMissingBalance: Int64?, history: [Api.StarsTransaction]?, nextOffset: String?, chats: [Api.Chat], users: [Api.User]) {
                self.flags = flags
                self.balance = balance
                self.subscriptions = subscriptions
                self.subscriptionsNextOffset = subscriptionsNextOffset
                self.subscriptionsMissingBalance = subscriptionsMissingBalance
                self.history = history
                self.nextOffset = nextOffset
                self.chats = chats
                self.users = users
            }
        }
        case starsStatus(Cons_starsStatus)

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

        public static func parse_starsStatus(_ reader: BufferReader) -> StarsStatus? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.payments {
    enum SuggestedStarRefBots: TypeConstructorDescription {
        public class Cons_suggestedStarRefBots {
            public var flags: Int32
            public var count: Int32
            public var suggestedBots: [Api.StarRefProgram]
            public var users: [Api.User]
            public var nextOffset: String?
            public init(flags: Int32, count: Int32, suggestedBots: [Api.StarRefProgram], users: [Api.User], nextOffset: String?) {
                self.flags = flags
                self.count = count
                self.suggestedBots = suggestedBots
                self.users = users
                self.nextOffset = nextOffset
            }
        }
        case suggestedStarRefBots(Cons_suggestedStarRefBots)

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

        public static func parse_suggestedStarRefBots(_ reader: BufferReader) -> SuggestedStarRefBots? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.payments {
    enum UniqueStarGift: TypeConstructorDescription {
        public class Cons_uniqueStarGift {
            public var gift: Api.StarGift
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(gift: Api.StarGift, chats: [Api.Chat], users: [Api.User]) {
                self.gift = gift
                self.chats = chats
                self.users = users
            }
        }
        case uniqueStarGift(Cons_uniqueStarGift)

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

        public static func parse_uniqueStarGift(_ reader: BufferReader) -> UniqueStarGift? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.payments {
    enum UniqueStarGiftValueInfo: TypeConstructorDescription {
        public class Cons_uniqueStarGiftValueInfo {
            public var flags: Int32
            public var currency: String
            public var value: Int64
            public var initialSaleDate: Int32
            public var initialSaleStars: Int64
            public var initialSalePrice: Int64
            public var lastSaleDate: Int32?
            public var lastSalePrice: Int64?
            public var floorPrice: Int64?
            public var averagePrice: Int64?
            public var listedCount: Int32?
            public var fragmentListedCount: Int32?
            public var fragmentListedUrl: String?
            public init(flags: Int32, currency: String, value: Int64, initialSaleDate: Int32, initialSaleStars: Int64, initialSalePrice: Int64, lastSaleDate: Int32?, lastSalePrice: Int64?, floorPrice: Int64?, averagePrice: Int64?, listedCount: Int32?, fragmentListedCount: Int32?, fragmentListedUrl: String?) {
                self.flags = flags
                self.currency = currency
                self.value = value
                self.initialSaleDate = initialSaleDate
                self.initialSaleStars = initialSaleStars
                self.initialSalePrice = initialSalePrice
                self.lastSaleDate = lastSaleDate
                self.lastSalePrice = lastSalePrice
                self.floorPrice = floorPrice
                self.averagePrice = averagePrice
                self.listedCount = listedCount
                self.fragmentListedCount = fragmentListedCount
                self.fragmentListedUrl = fragmentListedUrl
            }
        }
        case uniqueStarGiftValueInfo(Cons_uniqueStarGiftValueInfo)

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

        public static func parse_uniqueStarGiftValueInfo(_ reader: BufferReader) -> UniqueStarGiftValueInfo? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.payments {
    enum ValidatedRequestedInfo: TypeConstructorDescription {
        public class Cons_validatedRequestedInfo {
            public var flags: Int32
            public var id: String?
            public var shippingOptions: [Api.ShippingOption]?
            public init(flags: Int32, id: String?, shippingOptions: [Api.ShippingOption]?) {
                self.flags = flags
                self.id = id
                self.shippingOptions = shippingOptions
            }
        }
        case validatedRequestedInfo(Cons_validatedRequestedInfo)

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

        public static func parse_validatedRequestedInfo(_ reader: BufferReader) -> ValidatedRequestedInfo? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.phone {
    enum ExportedGroupCallInvite: TypeConstructorDescription {
        public class Cons_exportedGroupCallInvite {
            public var link: String
            public init(link: String) {
                self.link = link
            }
        }
        case exportedGroupCallInvite(Cons_exportedGroupCallInvite)

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

        public static func parse_exportedGroupCallInvite(_ reader: BufferReader) -> ExportedGroupCallInvite? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.phone {
    enum GroupCall: TypeConstructorDescription {
        public class Cons_groupCall {
            public var call: Api.GroupCall
            public var participants: [Api.GroupCallParticipant]
            public var participantsNextOffset: String
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(call: Api.GroupCall, participants: [Api.GroupCallParticipant], participantsNextOffset: String, chats: [Api.Chat], users: [Api.User]) {
                self.call = call
                self.participants = participants
                self.participantsNextOffset = participantsNextOffset
                self.chats = chats
                self.users = users
            }
        }
        case groupCall(Cons_groupCall)

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

        public static func parse_groupCall(_ reader: BufferReader) -> GroupCall? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.phone {
    enum GroupCallStars: TypeConstructorDescription {
        public class Cons_groupCallStars {
            public var totalStars: Int64
            public var topDonors: [Api.GroupCallDonor]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(totalStars: Int64, topDonors: [Api.GroupCallDonor], chats: [Api.Chat], users: [Api.User]) {
                self.totalStars = totalStars
                self.topDonors = topDonors
                self.chats = chats
                self.users = users
            }
        }
        case groupCallStars(Cons_groupCallStars)

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

        public static func parse_groupCallStars(_ reader: BufferReader) -> GroupCallStars? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.phone {
    enum GroupCallStreamChannels: TypeConstructorDescription {
        public class Cons_groupCallStreamChannels {
            public var channels: [Api.GroupCallStreamChannel]
            public init(channels: [Api.GroupCallStreamChannel]) {
                self.channels = channels
            }
        }
        case groupCallStreamChannels(Cons_groupCallStreamChannels)

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

        public static func parse_groupCallStreamChannels(_ reader: BufferReader) -> GroupCallStreamChannels? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.phone {
    enum GroupCallStreamRtmpUrl: TypeConstructorDescription {
        public class Cons_groupCallStreamRtmpUrl {
            public var url: String
            public var key: String
            public init(url: String, key: String) {
                self.url = url
                self.key = key
            }
        }
        case groupCallStreamRtmpUrl(Cons_groupCallStreamRtmpUrl)

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

        public static func parse_groupCallStreamRtmpUrl(_ reader: BufferReader) -> GroupCallStreamRtmpUrl? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.phone {
    enum GroupParticipants: TypeConstructorDescription {
        public class Cons_groupParticipants {
            public var count: Int32
            public var participants: [Api.GroupCallParticipant]
            public var nextOffset: String
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public var version: Int32
            public init(count: Int32, participants: [Api.GroupCallParticipant], nextOffset: String, chats: [Api.Chat], users: [Api.User], version: Int32) {
                self.count = count
                self.participants = participants
                self.nextOffset = nextOffset
                self.chats = chats
                self.users = users
                self.version = version
            }
        }
        case groupParticipants(Cons_groupParticipants)

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

        public static func parse_groupParticipants(_ reader: BufferReader) -> GroupParticipants? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
