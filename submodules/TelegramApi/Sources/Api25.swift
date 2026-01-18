public extension Api {
    enum ShippingOption: TypeConstructorDescription {
        public class Cons_shippingOption {
            public var id: String
            public var title: String
            public var prices: [Api.LabeledPrice]
            public init(id: String, title: String, prices: [Api.LabeledPrice]) {
                self.id = id
                self.title = title
                self.prices = prices
            }
        }
        case shippingOption(Cons_shippingOption)

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

        public static func parse_shippingOption(_ reader: BufferReader) -> ShippingOption? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum SmsJob: TypeConstructorDescription {
        public class Cons_smsJob {
            public var jobId: String
            public var phoneNumber: String
            public var text: String
            public init(jobId: String, phoneNumber: String, text: String) {
                self.jobId = jobId
                self.phoneNumber = phoneNumber
                self.text = text
            }
        }
        case smsJob(Cons_smsJob)

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

        public static func parse_smsJob(_ reader: BufferReader) -> SmsJob? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum SponsoredMessage: TypeConstructorDescription {
        public class Cons_sponsoredMessage {
            public var flags: Int32
            public var randomId: Buffer
            public var url: String
            public var title: String
            public var message: String
            public var entities: [Api.MessageEntity]?
            public var photo: Api.Photo?
            public var media: Api.MessageMedia?
            public var color: Api.PeerColor?
            public var buttonText: String
            public var sponsorInfo: String?
            public var additionalInfo: String?
            public var minDisplayDuration: Int32?
            public var maxDisplayDuration: Int32?
            public init(flags: Int32, randomId: Buffer, url: String, title: String, message: String, entities: [Api.MessageEntity]?, photo: Api.Photo?, media: Api.MessageMedia?, color: Api.PeerColor?, buttonText: String, sponsorInfo: String?, additionalInfo: String?, minDisplayDuration: Int32?, maxDisplayDuration: Int32?) {
                self.flags = flags
                self.randomId = randomId
                self.url = url
                self.title = title
                self.message = message
                self.entities = entities
                self.photo = photo
                self.media = media
                self.color = color
                self.buttonText = buttonText
                self.sponsorInfo = sponsorInfo
                self.additionalInfo = additionalInfo
                self.minDisplayDuration = minDisplayDuration
                self.maxDisplayDuration = maxDisplayDuration
            }
        }
        case sponsoredMessage(Cons_sponsoredMessage)

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

        public static func parse_sponsoredMessage(_ reader: BufferReader) -> SponsoredMessage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum SponsoredMessageReportOption: TypeConstructorDescription {
        public class Cons_sponsoredMessageReportOption {
            public var text: String
            public var option: Buffer
            public init(text: String, option: Buffer) {
                self.text = text
                self.option = option
            }
        }
        case sponsoredMessageReportOption(Cons_sponsoredMessageReportOption)

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

        public static func parse_sponsoredMessageReportOption(_ reader: BufferReader) -> SponsoredMessageReportOption? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum SponsoredPeer: TypeConstructorDescription {
        public class Cons_sponsoredPeer {
            public var flags: Int32
            public var randomId: Buffer
            public var peer: Api.Peer
            public var sponsorInfo: String?
            public var additionalInfo: String?
            public init(flags: Int32, randomId: Buffer, peer: Api.Peer, sponsorInfo: String?, additionalInfo: String?) {
                self.flags = flags
                self.randomId = randomId
                self.peer = peer
                self.sponsorInfo = sponsorInfo
                self.additionalInfo = additionalInfo
            }
        }
        case sponsoredPeer(Cons_sponsoredPeer)

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

        public static func parse_sponsoredPeer(_ reader: BufferReader) -> SponsoredPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StarGift: TypeConstructorDescription {
        public class Cons_starGift {
            public var flags: Int32
            public var id: Int64
            public var sticker: Api.Document
            public var stars: Int64
            public var availabilityRemains: Int32?
            public var availabilityTotal: Int32?
            public var availabilityResale: Int64?
            public var convertStars: Int64
            public var firstSaleDate: Int32?
            public var lastSaleDate: Int32?
            public var upgradeStars: Int64?
            public var resellMinStars: Int64?
            public var title: String?
            public var releasedBy: Api.Peer?
            public var perUserTotal: Int32?
            public var perUserRemains: Int32?
            public var lockedUntilDate: Int32?
            public var auctionSlug: String?
            public var giftsPerRound: Int32?
            public var auctionStartDate: Int32?
            public var upgradeVariants: Int32?
            public var background: Api.StarGiftBackground?
            public init(flags: Int32, id: Int64, sticker: Api.Document, stars: Int64, availabilityRemains: Int32?, availabilityTotal: Int32?, availabilityResale: Int64?, convertStars: Int64, firstSaleDate: Int32?, lastSaleDate: Int32?, upgradeStars: Int64?, resellMinStars: Int64?, title: String?, releasedBy: Api.Peer?, perUserTotal: Int32?, perUserRemains: Int32?, lockedUntilDate: Int32?, auctionSlug: String?, giftsPerRound: Int32?, auctionStartDate: Int32?, upgradeVariants: Int32?, background: Api.StarGiftBackground?) {
                self.flags = flags
                self.id = id
                self.sticker = sticker
                self.stars = stars
                self.availabilityRemains = availabilityRemains
                self.availabilityTotal = availabilityTotal
                self.availabilityResale = availabilityResale
                self.convertStars = convertStars
                self.firstSaleDate = firstSaleDate
                self.lastSaleDate = lastSaleDate
                self.upgradeStars = upgradeStars
                self.resellMinStars = resellMinStars
                self.title = title
                self.releasedBy = releasedBy
                self.perUserTotal = perUserTotal
                self.perUserRemains = perUserRemains
                self.lockedUntilDate = lockedUntilDate
                self.auctionSlug = auctionSlug
                self.giftsPerRound = giftsPerRound
                self.auctionStartDate = auctionStartDate
                self.upgradeVariants = upgradeVariants
                self.background = background
            }
        }
        public class Cons_starGiftUnique {
            public var flags: Int32
            public var id: Int64
            public var giftId: Int64
            public var title: String
            public var slug: String
            public var num: Int32
            public var ownerId: Api.Peer?
            public var ownerName: String?
            public var ownerAddress: String?
            public var attributes: [Api.StarGiftAttribute]
            public var availabilityIssued: Int32
            public var availabilityTotal: Int32
            public var giftAddress: String?
            public var resellAmount: [Api.StarsAmount]?
            public var releasedBy: Api.Peer?
            public var valueAmount: Int64?
            public var valueCurrency: String?
            public var valueUsdAmount: Int64?
            public var themePeer: Api.Peer?
            public var peerColor: Api.PeerColor?
            public var hostId: Api.Peer?
            public var offerMinStars: Int32?
            public init(flags: Int32, id: Int64, giftId: Int64, title: String, slug: String, num: Int32, ownerId: Api.Peer?, ownerName: String?, ownerAddress: String?, attributes: [Api.StarGiftAttribute], availabilityIssued: Int32, availabilityTotal: Int32, giftAddress: String?, resellAmount: [Api.StarsAmount]?, releasedBy: Api.Peer?, valueAmount: Int64?, valueCurrency: String?, valueUsdAmount: Int64?, themePeer: Api.Peer?, peerColor: Api.PeerColor?, hostId: Api.Peer?, offerMinStars: Int32?) {
                self.flags = flags
                self.id = id
                self.giftId = giftId
                self.title = title
                self.slug = slug
                self.num = num
                self.ownerId = ownerId
                self.ownerName = ownerName
                self.ownerAddress = ownerAddress
                self.attributes = attributes
                self.availabilityIssued = availabilityIssued
                self.availabilityTotal = availabilityTotal
                self.giftAddress = giftAddress
                self.resellAmount = resellAmount
                self.releasedBy = releasedBy
                self.valueAmount = valueAmount
                self.valueCurrency = valueCurrency
                self.valueUsdAmount = valueUsdAmount
                self.themePeer = themePeer
                self.peerColor = peerColor
                self.hostId = hostId
                self.offerMinStars = offerMinStars
            }
        }
        case starGift(Cons_starGift)
        case starGiftUnique(Cons_starGiftUnique)

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

        public static func parse_starGift(_ reader: BufferReader) -> StarGift? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_starGiftUnique(_ reader: BufferReader) -> StarGift? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StarGiftActiveAuctionState: TypeConstructorDescription {
        public class Cons_starGiftActiveAuctionState {
            public var gift: Api.StarGift
            public var state: Api.StarGiftAuctionState
            public var userState: Api.StarGiftAuctionUserState
            public init(gift: Api.StarGift, state: Api.StarGiftAuctionState, userState: Api.StarGiftAuctionUserState) {
                self.gift = gift
                self.state = state
                self.userState = userState
            }
        }
        case starGiftActiveAuctionState(Cons_starGiftActiveAuctionState)

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

        public static func parse_starGiftActiveAuctionState(_ reader: BufferReader) -> StarGiftActiveAuctionState? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StarGiftAttribute: TypeConstructorDescription {
        public class Cons_starGiftAttributeBackdrop {
            public var name: String
            public var backdropId: Int32
            public var centerColor: Int32
            public var edgeColor: Int32
            public var patternColor: Int32
            public var textColor: Int32
            public var rarity: Api.StarGiftAttributeRarity
            public init(name: String, backdropId: Int32, centerColor: Int32, edgeColor: Int32, patternColor: Int32, textColor: Int32, rarity: Api.StarGiftAttributeRarity) {
                self.name = name
                self.backdropId = backdropId
                self.centerColor = centerColor
                self.edgeColor = edgeColor
                self.patternColor = patternColor
                self.textColor = textColor
                self.rarity = rarity
            }
        }
        public class Cons_starGiftAttributeModel {
            public var flags: Int32
            public var name: String
            public var document: Api.Document
            public var rarity: Api.StarGiftAttributeRarity
            public init(flags: Int32, name: String, document: Api.Document, rarity: Api.StarGiftAttributeRarity) {
                self.flags = flags
                self.name = name
                self.document = document
                self.rarity = rarity
            }
        }
        public class Cons_starGiftAttributeOriginalDetails {
            public var flags: Int32
            public var senderId: Api.Peer?
            public var recipientId: Api.Peer
            public var date: Int32
            public var message: Api.TextWithEntities?
            public init(flags: Int32, senderId: Api.Peer?, recipientId: Api.Peer, date: Int32, message: Api.TextWithEntities?) {
                self.flags = flags
                self.senderId = senderId
                self.recipientId = recipientId
                self.date = date
                self.message = message
            }
        }
        public class Cons_starGiftAttributePattern {
            public var name: String
            public var document: Api.Document
            public var rarity: Api.StarGiftAttributeRarity
            public init(name: String, document: Api.Document, rarity: Api.StarGiftAttributeRarity) {
                self.name = name
                self.document = document
                self.rarity = rarity
            }
        }
        case starGiftAttributeBackdrop(Cons_starGiftAttributeBackdrop)
        case starGiftAttributeModel(Cons_starGiftAttributeModel)
        case starGiftAttributeOriginalDetails(Cons_starGiftAttributeOriginalDetails)
        case starGiftAttributePattern(Cons_starGiftAttributePattern)

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

        public static func parse_starGiftAttributeBackdrop(_ reader: BufferReader) -> StarGiftAttribute? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_starGiftAttributeModel(_ reader: BufferReader) -> StarGiftAttribute? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_starGiftAttributeOriginalDetails(_ reader: BufferReader) -> StarGiftAttribute? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_starGiftAttributePattern(_ reader: BufferReader) -> StarGiftAttribute? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StarGiftAttributeCounter: TypeConstructorDescription {
        public class Cons_starGiftAttributeCounter {
            public var attribute: Api.StarGiftAttributeId
            public var count: Int32
            public init(attribute: Api.StarGiftAttributeId, count: Int32) {
                self.attribute = attribute
                self.count = count
            }
        }
        case starGiftAttributeCounter(Cons_starGiftAttributeCounter)

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

        public static func parse_starGiftAttributeCounter(_ reader: BufferReader) -> StarGiftAttributeCounter? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StarGiftAttributeId: TypeConstructorDescription {
        public class Cons_starGiftAttributeIdBackdrop {
            public var backdropId: Int32
            public init(backdropId: Int32) {
                self.backdropId = backdropId
            }
        }
        public class Cons_starGiftAttributeIdModel {
            public var documentId: Int64
            public init(documentId: Int64) {
                self.documentId = documentId
            }
        }
        public class Cons_starGiftAttributeIdPattern {
            public var documentId: Int64
            public init(documentId: Int64) {
                self.documentId = documentId
            }
        }
        case starGiftAttributeIdBackdrop(Cons_starGiftAttributeIdBackdrop)
        case starGiftAttributeIdModel(Cons_starGiftAttributeIdModel)
        case starGiftAttributeIdPattern(Cons_starGiftAttributeIdPattern)

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

        public static func parse_starGiftAttributeIdBackdrop(_ reader: BufferReader) -> StarGiftAttributeId? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_starGiftAttributeIdModel(_ reader: BufferReader) -> StarGiftAttributeId? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_starGiftAttributeIdPattern(_ reader: BufferReader) -> StarGiftAttributeId? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StarGiftAttributeRarity: TypeConstructorDescription {
        public class Cons_starGiftAttributeRarity {
            public var permille: Int32
            public init(permille: Int32) {
                self.permille = permille
            }
        }
        case starGiftAttributeRarity(Cons_starGiftAttributeRarity)
        case starGiftAttributeRarityEpic
        case starGiftAttributeRarityLegendary
        case starGiftAttributeRarityMythic
        case starGiftAttributeRarityRare

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

        public static func parse_starGiftAttributeRarity(_ reader: BufferReader) -> StarGiftAttributeRarity? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_starGiftAttributeRarityEpic(_ reader: BufferReader) -> StarGiftAttributeRarity? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_starGiftAttributeRarityLegendary(_ reader: BufferReader) -> StarGiftAttributeRarity? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_starGiftAttributeRarityMythic(_ reader: BufferReader) -> StarGiftAttributeRarity? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_starGiftAttributeRarityRare(_ reader: BufferReader) -> StarGiftAttributeRarity? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StarGiftAuctionAcquiredGift: TypeConstructorDescription {
        public class Cons_starGiftAuctionAcquiredGift {
            public var flags: Int32
            public var peer: Api.Peer
            public var date: Int32
            public var bidAmount: Int64
            public var round: Int32
            public var pos: Int32
            public var message: Api.TextWithEntities?
            public var giftNum: Int32?
            public init(flags: Int32, peer: Api.Peer, date: Int32, bidAmount: Int64, round: Int32, pos: Int32, message: Api.TextWithEntities?, giftNum: Int32?) {
                self.flags = flags
                self.peer = peer
                self.date = date
                self.bidAmount = bidAmount
                self.round = round
                self.pos = pos
                self.message = message
                self.giftNum = giftNum
            }
        }
        case starGiftAuctionAcquiredGift(Cons_starGiftAuctionAcquiredGift)

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

        public static func parse_starGiftAuctionAcquiredGift(_ reader: BufferReader) -> StarGiftAuctionAcquiredGift? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StarGiftAuctionRound: TypeConstructorDescription {
        public class Cons_starGiftAuctionRound {
            public var num: Int32
            public var duration: Int32
            public init(num: Int32, duration: Int32) {
                self.num = num
                self.duration = duration
            }
        }
        public class Cons_starGiftAuctionRoundExtendable {
            public var num: Int32
            public var duration: Int32
            public var extendTop: Int32
            public var extendWindow: Int32
            public init(num: Int32, duration: Int32, extendTop: Int32, extendWindow: Int32) {
                self.num = num
                self.duration = duration
                self.extendTop = extendTop
                self.extendWindow = extendWindow
            }
        }
        case starGiftAuctionRound(Cons_starGiftAuctionRound)
        case starGiftAuctionRoundExtendable(Cons_starGiftAuctionRoundExtendable)

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

        public static func parse_starGiftAuctionRound(_ reader: BufferReader) -> StarGiftAuctionRound? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_starGiftAuctionRoundExtendable(_ reader: BufferReader) -> StarGiftAuctionRound? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StarGiftAuctionState: TypeConstructorDescription {
        public class Cons_starGiftAuctionState {
            public var version: Int32
            public var startDate: Int32
            public var endDate: Int32
            public var minBidAmount: Int64
            public var bidLevels: [Api.AuctionBidLevel]
            public var topBidders: [Int64]
            public var nextRoundAt: Int32
            public var lastGiftNum: Int32
            public var giftsLeft: Int32
            public var currentRound: Int32
            public var totalRounds: Int32
            public var rounds: [Api.StarGiftAuctionRound]
            public init(version: Int32, startDate: Int32, endDate: Int32, minBidAmount: Int64, bidLevels: [Api.AuctionBidLevel], topBidders: [Int64], nextRoundAt: Int32, lastGiftNum: Int32, giftsLeft: Int32, currentRound: Int32, totalRounds: Int32, rounds: [Api.StarGiftAuctionRound]) {
                self.version = version
                self.startDate = startDate
                self.endDate = endDate
                self.minBidAmount = minBidAmount
                self.bidLevels = bidLevels
                self.topBidders = topBidders
                self.nextRoundAt = nextRoundAt
                self.lastGiftNum = lastGiftNum
                self.giftsLeft = giftsLeft
                self.currentRound = currentRound
                self.totalRounds = totalRounds
                self.rounds = rounds
            }
        }
        public class Cons_starGiftAuctionStateFinished {
            public var flags: Int32
            public var startDate: Int32
            public var endDate: Int32
            public var averagePrice: Int64
            public var listedCount: Int32?
            public var fragmentListedCount: Int32?
            public var fragmentListedUrl: String?
            public init(flags: Int32, startDate: Int32, endDate: Int32, averagePrice: Int64, listedCount: Int32?, fragmentListedCount: Int32?, fragmentListedUrl: String?) {
                self.flags = flags
                self.startDate = startDate
                self.endDate = endDate
                self.averagePrice = averagePrice
                self.listedCount = listedCount
                self.fragmentListedCount = fragmentListedCount
                self.fragmentListedUrl = fragmentListedUrl
            }
        }
        case starGiftAuctionState(Cons_starGiftAuctionState)
        case starGiftAuctionStateFinished(Cons_starGiftAuctionStateFinished)
        case starGiftAuctionStateNotModified

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
        public static func parse_starGiftAuctionStateFinished(_ reader: BufferReader) -> StarGiftAuctionState? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_starGiftAuctionStateNotModified(_ reader: BufferReader) -> StarGiftAuctionState? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StarGiftAuctionUserState: TypeConstructorDescription {
        public class Cons_starGiftAuctionUserState {
            public var flags: Int32
            public var bidAmount: Int64?
            public var bidDate: Int32?
            public var minBidAmount: Int64?
            public var bidPeer: Api.Peer?
            public var acquiredCount: Int32
            public init(flags: Int32, bidAmount: Int64?, bidDate: Int32?, minBidAmount: Int64?, bidPeer: Api.Peer?, acquiredCount: Int32) {
                self.flags = flags
                self.bidAmount = bidAmount
                self.bidDate = bidDate
                self.minBidAmount = minBidAmount
                self.bidPeer = bidPeer
                self.acquiredCount = acquiredCount
            }
        }
        case starGiftAuctionUserState(Cons_starGiftAuctionUserState)

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

        public static func parse_starGiftAuctionUserState(_ reader: BufferReader) -> StarGiftAuctionUserState? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StarGiftBackground: TypeConstructorDescription {
        public class Cons_starGiftBackground {
            public var centerColor: Int32
            public var edgeColor: Int32
            public var textColor: Int32
            public init(centerColor: Int32, edgeColor: Int32, textColor: Int32) {
                self.centerColor = centerColor
                self.edgeColor = edgeColor
                self.textColor = textColor
            }
        }
        case starGiftBackground(Cons_starGiftBackground)

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

        public static func parse_starGiftBackground(_ reader: BufferReader) -> StarGiftBackground? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StarGiftCollection: TypeConstructorDescription {
        public class Cons_starGiftCollection {
            public var flags: Int32
            public var collectionId: Int32
            public var title: String
            public var icon: Api.Document?
            public var giftsCount: Int32
            public var hash: Int64
            public init(flags: Int32, collectionId: Int32, title: String, icon: Api.Document?, giftsCount: Int32, hash: Int64) {
                self.flags = flags
                self.collectionId = collectionId
                self.title = title
                self.icon = icon
                self.giftsCount = giftsCount
                self.hash = hash
            }
        }
        case starGiftCollection(Cons_starGiftCollection)

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

        public static func parse_starGiftCollection(_ reader: BufferReader) -> StarGiftCollection? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StarGiftUpgradePrice: TypeConstructorDescription {
        public class Cons_starGiftUpgradePrice {
            public var date: Int32
            public var upgradeStars: Int64
            public init(date: Int32, upgradeStars: Int64) {
                self.date = date
                self.upgradeStars = upgradeStars
            }
        }
        case starGiftUpgradePrice(Cons_starGiftUpgradePrice)

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

        public static func parse_starGiftUpgradePrice(_ reader: BufferReader) -> StarGiftUpgradePrice? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StarRefProgram: TypeConstructorDescription {
        public class Cons_starRefProgram {
            public var flags: Int32
            public var botId: Int64
            public var commissionPermille: Int32
            public var durationMonths: Int32?
            public var endDate: Int32?
            public var dailyRevenuePerUser: Api.StarsAmount?
            public init(flags: Int32, botId: Int64, commissionPermille: Int32, durationMonths: Int32?, endDate: Int32?, dailyRevenuePerUser: Api.StarsAmount?) {
                self.flags = flags
                self.botId = botId
                self.commissionPermille = commissionPermille
                self.durationMonths = durationMonths
                self.endDate = endDate
                self.dailyRevenuePerUser = dailyRevenuePerUser
            }
        }
        case starRefProgram(Cons_starRefProgram)

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

        public static func parse_starRefProgram(_ reader: BufferReader) -> StarRefProgram? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
