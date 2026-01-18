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
        case starGift(flags: Int32, id: Int64, sticker: Api.Document, stars: Int64, availabilityRemains: Int32?, availabilityTotal: Int32?, availabilityResale: Int64?, convertStars: Int64, firstSaleDate: Int32?, lastSaleDate: Int32?, upgradeStars: Int64?, resellMinStars: Int64?, title: String?, releasedBy: Api.Peer?, perUserTotal: Int32?, perUserRemains: Int32?, lockedUntilDate: Int32?, auctionSlug: String?, giftsPerRound: Int32?, auctionStartDate: Int32?, upgradeVariants: Int32?, background: Api.StarGiftBackground?)
        case starGiftUnique(flags: Int32, id: Int64, giftId: Int64, title: String, slug: String, num: Int32, ownerId: Api.Peer?, ownerName: String?, ownerAddress: String?, attributes: [Api.StarGiftAttribute], availabilityIssued: Int32, availabilityTotal: Int32, giftAddress: String?, resellAmount: [Api.StarsAmount]?, releasedBy: Api.Peer?, valueAmount: Int64?, valueCurrency: String?, valueUsdAmount: Int64?, themePeer: Api.Peer?, peerColor: Api.PeerColor?, hostId: Api.Peer?, offerMinStars: Int32?)

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
        case starGiftActiveAuctionState(gift: Api.StarGift, state: Api.StarGiftAuctionState, userState: Api.StarGiftAuctionUserState)

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
        case starGiftAttributeBackdrop(name: String, backdropId: Int32, centerColor: Int32, edgeColor: Int32, patternColor: Int32, textColor: Int32, rarity: Api.StarGiftAttributeRarity)
        case starGiftAttributeModel(flags: Int32, name: String, document: Api.Document, rarity: Api.StarGiftAttributeRarity)
        case starGiftAttributeOriginalDetails(flags: Int32, senderId: Api.Peer?, recipientId: Api.Peer, date: Int32, message: Api.TextWithEntities?)
        case starGiftAttributePattern(name: String, document: Api.Document, rarity: Api.StarGiftAttributeRarity)

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
        case starGiftAttributeCounter(attribute: Api.StarGiftAttributeId, count: Int32)

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
        case starGiftAttributeIdBackdrop(backdropId: Int32)
        case starGiftAttributeIdModel(documentId: Int64)
        case starGiftAttributeIdPattern(documentId: Int64)

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
        case starGiftAttributeRarity(permille: Int32)
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
        case starGiftAuctionAcquiredGift(flags: Int32, peer: Api.Peer, date: Int32, bidAmount: Int64, round: Int32, pos: Int32, message: Api.TextWithEntities?, giftNum: Int32?)

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
        case starGiftAuctionRound(num: Int32, duration: Int32)
        case starGiftAuctionRoundExtendable(num: Int32, duration: Int32, extendTop: Int32, extendWindow: Int32)

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
        case starGiftAuctionState(version: Int32, startDate: Int32, endDate: Int32, minBidAmount: Int64, bidLevels: [Api.AuctionBidLevel], topBidders: [Int64], nextRoundAt: Int32, lastGiftNum: Int32, giftsLeft: Int32, currentRound: Int32, totalRounds: Int32, rounds: [Api.StarGiftAuctionRound])
        case starGiftAuctionStateFinished(flags: Int32, startDate: Int32, endDate: Int32, averagePrice: Int64, listedCount: Int32?, fragmentListedCount: Int32?, fragmentListedUrl: String?)
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
        case starGiftAuctionUserState(flags: Int32, bidAmount: Int64?, bidDate: Int32?, minBidAmount: Int64?, bidPeer: Api.Peer?, acquiredCount: Int32)

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
        case starGiftBackground(centerColor: Int32, edgeColor: Int32, textColor: Int32)

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
        case starGiftCollection(flags: Int32, collectionId: Int32, title: String, icon: Api.Document?, giftsCount: Int32, hash: Int64)

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
        case starGiftUpgradePrice(date: Int32, upgradeStars: Int64)

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
        case starRefProgram(flags: Int32, botId: Int64, commissionPermille: Int32, durationMonths: Int32?, endDate: Int32?, dailyRevenuePerUser: Api.StarsAmount?)

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
