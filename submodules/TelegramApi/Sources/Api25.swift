public extension Api {
    enum ShippingOption: TypeConstructorDescription {
        case shippingOption(id: String, title: String, prices: [Api.LabeledPrice])

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
        case smsJob(jobId: String, phoneNumber: String, text: String)

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
        case sponsoredMessage(flags: Int32, randomId: Buffer, url: String, title: String, message: String, entities: [Api.MessageEntity]?, photo: Api.Photo?, media: Api.MessageMedia?, color: Api.PeerColor?, buttonText: String, sponsorInfo: String?, additionalInfo: String?, minDisplayDuration: Int32?, maxDisplayDuration: Int32?)

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
        case sponsoredMessageReportOption(text: String, option: Buffer)

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
        case sponsoredPeer(flags: Int32, randomId: Buffer, peer: Api.Peer, sponsorInfo: String?, additionalInfo: String?)

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
        case starGiftAttributeBackdrop(name: String, backdropId: Int32, centerColor: Int32, edgeColor: Int32, patternColor: Int32, textColor: Int32, rarityPermille: Int32)
        case starGiftAttributeModel(name: String, document: Api.Document, rarityPermille: Int32)
        case starGiftAttributeOriginalDetails(flags: Int32, senderId: Api.Peer?, recipientId: Api.Peer, date: Int32, message: Api.TextWithEntities?)
        case starGiftAttributePattern(name: String, document: Api.Document, rarityPermille: Int32)

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
public extension Api {
    enum StarsAmount: TypeConstructorDescription {
        case starsAmount(amount: Int64, nanos: Int32)
        case starsTonAmount(amount: Int64)

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
        case starsGiftOption(flags: Int32, stars: Int64, storeProduct: String?, currency: String, amount: Int64)

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
        case starsGiveawayOption(flags: Int32, stars: Int64, yearlyBoosts: Int32, storeProduct: String?, currency: String, amount: Int64, winners: [Api.StarsGiveawayWinnersOption])

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
        case starsGiveawayWinnersOption(flags: Int32, users: Int32, perUserStars: Int64)

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
