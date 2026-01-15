public extension Api {
    indirect enum MessageEntity: TypeConstructorDescription {
        case inputMessageEntityMentionName(offset: Int32, length: Int32, userId: Api.InputUser)
        case messageEntityBankCard(offset: Int32, length: Int32)
        case messageEntityBlockquote(flags: Int32, offset: Int32, length: Int32)
        case messageEntityBold(offset: Int32, length: Int32)
        case messageEntityBotCommand(offset: Int32, length: Int32)
        case messageEntityCashtag(offset: Int32, length: Int32)
        case messageEntityCode(offset: Int32, length: Int32)
        case messageEntityCustomEmoji(offset: Int32, length: Int32, documentId: Int64)
        case messageEntityEmail(offset: Int32, length: Int32)
        case messageEntityHashtag(offset: Int32, length: Int32)
        case messageEntityItalic(offset: Int32, length: Int32)
        case messageEntityMention(offset: Int32, length: Int32)
        case messageEntityMentionName(offset: Int32, length: Int32, userId: Int64)
        case messageEntityPhone(offset: Int32, length: Int32)
        case messageEntityPre(offset: Int32, length: Int32, language: String)
        case messageEntitySpoiler(offset: Int32, length: Int32)
        case messageEntityStrike(offset: Int32, length: Int32)
        case messageEntityTextUrl(offset: Int32, length: Int32, url: String)
        case messageEntityUnderline(offset: Int32, length: Int32)
        case messageEntityUnknown(offset: Int32, length: Int32)
        case messageEntityUrl(offset: Int32, length: Int32)

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

        public static func parse_inputMessageEntityMentionName(_ reader: BufferReader) -> MessageEntity? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageEntityBankCard(_ reader: BufferReader) -> MessageEntity? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageEntityBlockquote(_ reader: BufferReader) -> MessageEntity? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageEntityBold(_ reader: BufferReader) -> MessageEntity? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageEntityBotCommand(_ reader: BufferReader) -> MessageEntity? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageEntityCashtag(_ reader: BufferReader) -> MessageEntity? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageEntityCode(_ reader: BufferReader) -> MessageEntity? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageEntityCustomEmoji(_ reader: BufferReader) -> MessageEntity? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageEntityEmail(_ reader: BufferReader) -> MessageEntity? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageEntityHashtag(_ reader: BufferReader) -> MessageEntity? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageEntityItalic(_ reader: BufferReader) -> MessageEntity? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageEntityMention(_ reader: BufferReader) -> MessageEntity? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageEntityMentionName(_ reader: BufferReader) -> MessageEntity? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageEntityPhone(_ reader: BufferReader) -> MessageEntity? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageEntityPre(_ reader: BufferReader) -> MessageEntity? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageEntitySpoiler(_ reader: BufferReader) -> MessageEntity? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageEntityStrike(_ reader: BufferReader) -> MessageEntity? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageEntityTextUrl(_ reader: BufferReader) -> MessageEntity? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageEntityUnderline(_ reader: BufferReader) -> MessageEntity? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageEntityUnknown(_ reader: BufferReader) -> MessageEntity? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageEntityUrl(_ reader: BufferReader) -> MessageEntity? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum MessageExtendedMedia: TypeConstructorDescription {
        case messageExtendedMedia(media: Api.MessageMedia)
        case messageExtendedMediaPreview(flags: Int32, w: Int32?, h: Int32?, thumb: Api.PhotoSize?, videoDuration: Int32?)

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

        public static func parse_messageExtendedMedia(_ reader: BufferReader) -> MessageExtendedMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageExtendedMediaPreview(_ reader: BufferReader) -> MessageExtendedMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum MessageFwdHeader: TypeConstructorDescription {
        case messageFwdHeader(flags: Int32, fromId: Api.Peer?, fromName: String?, date: Int32, channelPost: Int32?, postAuthor: String?, savedFromPeer: Api.Peer?, savedFromMsgId: Int32?, savedFromId: Api.Peer?, savedFromName: String?, savedDate: Int32?, psaType: String?)

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

        public static func parse_messageFwdHeader(_ reader: BufferReader) -> MessageFwdHeader? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum MessageMedia: TypeConstructorDescription {
        case messageMediaContact(phoneNumber: String, firstName: String, lastName: String, vcard: String, userId: Int64)
        case messageMediaDice(flags: Int32, value: Int32, emoticon: String, gameOutcome: Api.messages.EmojiGameOutcome?)
        case messageMediaDocument(flags: Int32, document: Api.Document?, altDocuments: [Api.Document]?, videoCover: Api.Photo?, videoTimestamp: Int32?, ttlSeconds: Int32?)
        case messageMediaEmpty
        case messageMediaGame(game: Api.Game)
        case messageMediaGeo(geo: Api.GeoPoint)
        case messageMediaGeoLive(flags: Int32, geo: Api.GeoPoint, heading: Int32?, period: Int32, proximityNotificationRadius: Int32?)
        case messageMediaGiveaway(flags: Int32, channels: [Int64], countriesIso2: [String]?, prizeDescription: String?, quantity: Int32, months: Int32?, stars: Int64?, untilDate: Int32)
        case messageMediaGiveawayResults(flags: Int32, channelId: Int64, additionalPeersCount: Int32?, launchMsgId: Int32, winnersCount: Int32, unclaimedCount: Int32, winners: [Int64], months: Int32?, stars: Int64?, prizeDescription: String?, untilDate: Int32)
        case messageMediaInvoice(flags: Int32, title: String, description: String, photo: Api.WebDocument?, receiptMsgId: Int32?, currency: String, totalAmount: Int64, startParam: String, extendedMedia: Api.MessageExtendedMedia?)
        case messageMediaPaidMedia(starsAmount: Int64, extendedMedia: [Api.MessageExtendedMedia])
        case messageMediaPhoto(flags: Int32, photo: Api.Photo?, ttlSeconds: Int32?)
        case messageMediaPoll(poll: Api.Poll, results: Api.PollResults)
        case messageMediaStory(flags: Int32, peer: Api.Peer, id: Int32, story: Api.StoryItem?)
        case messageMediaToDo(flags: Int32, todo: Api.TodoList, completions: [Api.TodoCompletion]?)
        case messageMediaUnsupported
        case messageMediaVenue(geo: Api.GeoPoint, title: String, address: String, provider: String, venueId: String, venueType: String)
        case messageMediaVideoStream(flags: Int32, call: Api.InputGroupCall)
        case messageMediaWebPage(flags: Int32, webpage: Api.WebPage)

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

        public static func parse_messageMediaContact(_ reader: BufferReader) -> MessageMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageMediaDice(_ reader: BufferReader) -> MessageMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageMediaDocument(_ reader: BufferReader) -> MessageMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageMediaEmpty(_ reader: BufferReader) -> MessageMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageMediaGame(_ reader: BufferReader) -> MessageMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageMediaGeo(_ reader: BufferReader) -> MessageMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageMediaGeoLive(_ reader: BufferReader) -> MessageMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageMediaGiveaway(_ reader: BufferReader) -> MessageMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageMediaGiveawayResults(_ reader: BufferReader) -> MessageMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageMediaInvoice(_ reader: BufferReader) -> MessageMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageMediaPaidMedia(_ reader: BufferReader) -> MessageMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageMediaPhoto(_ reader: BufferReader) -> MessageMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageMediaPoll(_ reader: BufferReader) -> MessageMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageMediaStory(_ reader: BufferReader) -> MessageMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageMediaToDo(_ reader: BufferReader) -> MessageMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageMediaUnsupported(_ reader: BufferReader) -> MessageMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageMediaVenue(_ reader: BufferReader) -> MessageMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageMediaVideoStream(_ reader: BufferReader) -> MessageMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageMediaWebPage(_ reader: BufferReader) -> MessageMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
