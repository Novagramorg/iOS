public extension Api {
    indirect enum MessageEntity: TypeConstructorDescription {
        public class Cons_inputMessageEntityMentionName {
            public var offset: Int32
            public var length: Int32
            public var userId: Api.InputUser
            public init(offset: Int32, length: Int32, userId: Api.InputUser) {
                self.offset = offset
                self.length = length
                self.userId = userId
            }
        }
        public class Cons_messageEntityBankCard {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
        }
        public class Cons_messageEntityBlockquote {
            public var flags: Int32
            public var offset: Int32
            public var length: Int32
            public init(flags: Int32, offset: Int32, length: Int32) {
                self.flags = flags
                self.offset = offset
                self.length = length
            }
        }
        public class Cons_messageEntityBold {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
        }
        public class Cons_messageEntityBotCommand {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
        }
        public class Cons_messageEntityCashtag {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
        }
        public class Cons_messageEntityCode {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
        }
        public class Cons_messageEntityCustomEmoji {
            public var offset: Int32
            public var length: Int32
            public var documentId: Int64
            public init(offset: Int32, length: Int32, documentId: Int64) {
                self.offset = offset
                self.length = length
                self.documentId = documentId
            }
        }
        public class Cons_messageEntityEmail {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
        }
        public class Cons_messageEntityHashtag {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
        }
        public class Cons_messageEntityItalic {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
        }
        public class Cons_messageEntityMention {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
        }
        public class Cons_messageEntityMentionName {
            public var offset: Int32
            public var length: Int32
            public var userId: Int64
            public init(offset: Int32, length: Int32, userId: Int64) {
                self.offset = offset
                self.length = length
                self.userId = userId
            }
        }
        public class Cons_messageEntityPhone {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
        }
        public class Cons_messageEntityPre {
            public var offset: Int32
            public var length: Int32
            public var language: String
            public init(offset: Int32, length: Int32, language: String) {
                self.offset = offset
                self.length = length
                self.language = language
            }
        }
        public class Cons_messageEntitySpoiler {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
        }
        public class Cons_messageEntityStrike {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
        }
        public class Cons_messageEntityTextUrl {
            public var offset: Int32
            public var length: Int32
            public var url: String
            public init(offset: Int32, length: Int32, url: String) {
                self.offset = offset
                self.length = length
                self.url = url
            }
        }
        public class Cons_messageEntityUnderline {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
        }
        public class Cons_messageEntityUnknown {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
        }
        public class Cons_messageEntityUrl {
            public var offset: Int32
            public var length: Int32
            public init(offset: Int32, length: Int32) {
                self.offset = offset
                self.length = length
            }
        }
        case inputMessageEntityMentionName(Cons_inputMessageEntityMentionName)
        case messageEntityBankCard(Cons_messageEntityBankCard)
        case messageEntityBlockquote(Cons_messageEntityBlockquote)
        case messageEntityBold(Cons_messageEntityBold)
        case messageEntityBotCommand(Cons_messageEntityBotCommand)
        case messageEntityCashtag(Cons_messageEntityCashtag)
        case messageEntityCode(Cons_messageEntityCode)
        case messageEntityCustomEmoji(Cons_messageEntityCustomEmoji)
        case messageEntityEmail(Cons_messageEntityEmail)
        case messageEntityHashtag(Cons_messageEntityHashtag)
        case messageEntityItalic(Cons_messageEntityItalic)
        case messageEntityMention(Cons_messageEntityMention)
        case messageEntityMentionName(Cons_messageEntityMentionName)
        case messageEntityPhone(Cons_messageEntityPhone)
        case messageEntityPre(Cons_messageEntityPre)
        case messageEntitySpoiler(Cons_messageEntitySpoiler)
        case messageEntityStrike(Cons_messageEntityStrike)
        case messageEntityTextUrl(Cons_messageEntityTextUrl)
        case messageEntityUnderline(Cons_messageEntityUnderline)
        case messageEntityUnknown(Cons_messageEntityUnknown)
        case messageEntityUrl(Cons_messageEntityUrl)

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
        public class Cons_messageExtendedMedia {
            public var media: Api.MessageMedia
            public init(media: Api.MessageMedia) {
                self.media = media
            }
        }
        public class Cons_messageExtendedMediaPreview {
            public var flags: Int32
            public var w: Int32?
            public var h: Int32?
            public var thumb: Api.PhotoSize?
            public var videoDuration: Int32?
            public init(flags: Int32, w: Int32?, h: Int32?, thumb: Api.PhotoSize?, videoDuration: Int32?) {
                self.flags = flags
                self.w = w
                self.h = h
                self.thumb = thumb
                self.videoDuration = videoDuration
            }
        }
        case messageExtendedMedia(Cons_messageExtendedMedia)
        case messageExtendedMediaPreview(Cons_messageExtendedMediaPreview)

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
        public class Cons_messageFwdHeader {
            public var flags: Int32
            public var fromId: Api.Peer?
            public var fromName: String?
            public var date: Int32
            public var channelPost: Int32?
            public var postAuthor: String?
            public var savedFromPeer: Api.Peer?
            public var savedFromMsgId: Int32?
            public var savedFromId: Api.Peer?
            public var savedFromName: String?
            public var savedDate: Int32?
            public var psaType: String?
            public init(flags: Int32, fromId: Api.Peer?, fromName: String?, date: Int32, channelPost: Int32?, postAuthor: String?, savedFromPeer: Api.Peer?, savedFromMsgId: Int32?, savedFromId: Api.Peer?, savedFromName: String?, savedDate: Int32?, psaType: String?) {
                self.flags = flags
                self.fromId = fromId
                self.fromName = fromName
                self.date = date
                self.channelPost = channelPost
                self.postAuthor = postAuthor
                self.savedFromPeer = savedFromPeer
                self.savedFromMsgId = savedFromMsgId
                self.savedFromId = savedFromId
                self.savedFromName = savedFromName
                self.savedDate = savedDate
                self.psaType = psaType
            }
        }
        case messageFwdHeader(Cons_messageFwdHeader)

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
        public class Cons_messageMediaContact {
            public var phoneNumber: String
            public var firstName: String
            public var lastName: String
            public var vcard: String
            public var userId: Int64
            public init(phoneNumber: String, firstName: String, lastName: String, vcard: String, userId: Int64) {
                self.phoneNumber = phoneNumber
                self.firstName = firstName
                self.lastName = lastName
                self.vcard = vcard
                self.userId = userId
            }
        }
        public class Cons_messageMediaDice {
            public var flags: Int32
            public var value: Int32
            public var emoticon: String
            public var gameOutcome: Api.messages.EmojiGameOutcome?
            public init(flags: Int32, value: Int32, emoticon: String, gameOutcome: Api.messages.EmojiGameOutcome?) {
                self.flags = flags
                self.value = value
                self.emoticon = emoticon
                self.gameOutcome = gameOutcome
            }
        }
        public class Cons_messageMediaDocument {
            public var flags: Int32
            public var document: Api.Document?
            public var altDocuments: [Api.Document]?
            public var videoCover: Api.Photo?
            public var videoTimestamp: Int32?
            public var ttlSeconds: Int32?
            public init(flags: Int32, document: Api.Document?, altDocuments: [Api.Document]?, videoCover: Api.Photo?, videoTimestamp: Int32?, ttlSeconds: Int32?) {
                self.flags = flags
                self.document = document
                self.altDocuments = altDocuments
                self.videoCover = videoCover
                self.videoTimestamp = videoTimestamp
                self.ttlSeconds = ttlSeconds
            }
        }
        public class Cons_messageMediaGame {
            public var game: Api.Game
            public init(game: Api.Game) {
                self.game = game
            }
        }
        public class Cons_messageMediaGeo {
            public var geo: Api.GeoPoint
            public init(geo: Api.GeoPoint) {
                self.geo = geo
            }
        }
        public class Cons_messageMediaGeoLive {
            public var flags: Int32
            public var geo: Api.GeoPoint
            public var heading: Int32?
            public var period: Int32
            public var proximityNotificationRadius: Int32?
            public init(flags: Int32, geo: Api.GeoPoint, heading: Int32?, period: Int32, proximityNotificationRadius: Int32?) {
                self.flags = flags
                self.geo = geo
                self.heading = heading
                self.period = period
                self.proximityNotificationRadius = proximityNotificationRadius
            }
        }
        public class Cons_messageMediaGiveaway {
            public var flags: Int32
            public var channels: [Int64]
            public var countriesIso2: [String]?
            public var prizeDescription: String?
            public var quantity: Int32
            public var months: Int32?
            public var stars: Int64?
            public var untilDate: Int32
            public init(flags: Int32, channels: [Int64], countriesIso2: [String]?, prizeDescription: String?, quantity: Int32, months: Int32?, stars: Int64?, untilDate: Int32) {
                self.flags = flags
                self.channels = channels
                self.countriesIso2 = countriesIso2
                self.prizeDescription = prizeDescription
                self.quantity = quantity
                self.months = months
                self.stars = stars
                self.untilDate = untilDate
            }
        }
        public class Cons_messageMediaGiveawayResults {
            public var flags: Int32
            public var channelId: Int64
            public var additionalPeersCount: Int32?
            public var launchMsgId: Int32
            public var winnersCount: Int32
            public var unclaimedCount: Int32
            public var winners: [Int64]
            public var months: Int32?
            public var stars: Int64?
            public var prizeDescription: String?
            public var untilDate: Int32
            public init(flags: Int32, channelId: Int64, additionalPeersCount: Int32?, launchMsgId: Int32, winnersCount: Int32, unclaimedCount: Int32, winners: [Int64], months: Int32?, stars: Int64?, prizeDescription: String?, untilDate: Int32) {
                self.flags = flags
                self.channelId = channelId
                self.additionalPeersCount = additionalPeersCount
                self.launchMsgId = launchMsgId
                self.winnersCount = winnersCount
                self.unclaimedCount = unclaimedCount
                self.winners = winners
                self.months = months
                self.stars = stars
                self.prizeDescription = prizeDescription
                self.untilDate = untilDate
            }
        }
        public class Cons_messageMediaInvoice {
            public var flags: Int32
            public var title: String
            public var description: String
            public var photo: Api.WebDocument?
            public var receiptMsgId: Int32?
            public var currency: String
            public var totalAmount: Int64
            public var startParam: String
            public var extendedMedia: Api.MessageExtendedMedia?
            public init(flags: Int32, title: String, description: String, photo: Api.WebDocument?, receiptMsgId: Int32?, currency: String, totalAmount: Int64, startParam: String, extendedMedia: Api.MessageExtendedMedia?) {
                self.flags = flags
                self.title = title
                self.description = description
                self.photo = photo
                self.receiptMsgId = receiptMsgId
                self.currency = currency
                self.totalAmount = totalAmount
                self.startParam = startParam
                self.extendedMedia = extendedMedia
            }
        }
        public class Cons_messageMediaPaidMedia {
            public var starsAmount: Int64
            public var extendedMedia: [Api.MessageExtendedMedia]
            public init(starsAmount: Int64, extendedMedia: [Api.MessageExtendedMedia]) {
                self.starsAmount = starsAmount
                self.extendedMedia = extendedMedia
            }
        }
        public class Cons_messageMediaPhoto {
            public var flags: Int32
            public var photo: Api.Photo?
            public var ttlSeconds: Int32?
            public init(flags: Int32, photo: Api.Photo?, ttlSeconds: Int32?) {
                self.flags = flags
                self.photo = photo
                self.ttlSeconds = ttlSeconds
            }
        }
        public class Cons_messageMediaPoll {
            public var poll: Api.Poll
            public var results: Api.PollResults
            public init(poll: Api.Poll, results: Api.PollResults) {
                self.poll = poll
                self.results = results
            }
        }
        public class Cons_messageMediaStory {
            public var flags: Int32
            public var peer: Api.Peer
            public var id: Int32
            public var story: Api.StoryItem?
            public init(flags: Int32, peer: Api.Peer, id: Int32, story: Api.StoryItem?) {
                self.flags = flags
                self.peer = peer
                self.id = id
                self.story = story
            }
        }
        public class Cons_messageMediaToDo {
            public var flags: Int32
            public var todo: Api.TodoList
            public var completions: [Api.TodoCompletion]?
            public init(flags: Int32, todo: Api.TodoList, completions: [Api.TodoCompletion]?) {
                self.flags = flags
                self.todo = todo
                self.completions = completions
            }
        }
        public class Cons_messageMediaVenue {
            public var geo: Api.GeoPoint
            public var title: String
            public var address: String
            public var provider: String
            public var venueId: String
            public var venueType: String
            public init(geo: Api.GeoPoint, title: String, address: String, provider: String, venueId: String, venueType: String) {
                self.geo = geo
                self.title = title
                self.address = address
                self.provider = provider
                self.venueId = venueId
                self.venueType = venueType
            }
        }
        public class Cons_messageMediaVideoStream {
            public var flags: Int32
            public var call: Api.InputGroupCall
            public init(flags: Int32, call: Api.InputGroupCall) {
                self.flags = flags
                self.call = call
            }
        }
        public class Cons_messageMediaWebPage {
            public var flags: Int32
            public var webpage: Api.WebPage
            public init(flags: Int32, webpage: Api.WebPage) {
                self.flags = flags
                self.webpage = webpage
            }
        }
        case messageMediaContact(Cons_messageMediaContact)
        case messageMediaDice(Cons_messageMediaDice)
        case messageMediaDocument(Cons_messageMediaDocument)
        case messageMediaEmpty
        case messageMediaGame(Cons_messageMediaGame)
        case messageMediaGeo(Cons_messageMediaGeo)
        case messageMediaGeoLive(Cons_messageMediaGeoLive)
        case messageMediaGiveaway(Cons_messageMediaGiveaway)
        case messageMediaGiveawayResults(Cons_messageMediaGiveawayResults)
        case messageMediaInvoice(Cons_messageMediaInvoice)
        case messageMediaPaidMedia(Cons_messageMediaPaidMedia)
        case messageMediaPhoto(Cons_messageMediaPhoto)
        case messageMediaPoll(Cons_messageMediaPoll)
        case messageMediaStory(Cons_messageMediaStory)
        case messageMediaToDo(Cons_messageMediaToDo)
        case messageMediaUnsupported
        case messageMediaVenue(Cons_messageMediaVenue)
        case messageMediaVideoStream(Cons_messageMediaVideoStream)
        case messageMediaWebPage(Cons_messageMediaWebPage)

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
