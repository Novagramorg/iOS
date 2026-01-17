public extension Api {
    enum KeyboardButtonRow: TypeConstructorDescription {
        public class Cons_keyboardButtonRow {
            public var buttons: [Api.KeyboardButton]
            public init(buttons: [Api.KeyboardButton]) {
                self.buttons = buttons
            }
        }
        case keyboardButtonRow(Cons_keyboardButtonRow)

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

        public static func parse_keyboardButtonRow(_ reader: BufferReader) -> KeyboardButtonRow? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum LabeledPrice: TypeConstructorDescription {
        public class Cons_labeledPrice {
            public var label: String
            public var amount: Int64
            public init(label: String, amount: Int64) {
                self.label = label
                self.amount = amount
            }
        }
        case labeledPrice(Cons_labeledPrice)

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

        public static func parse_labeledPrice(_ reader: BufferReader) -> LabeledPrice? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum LangPackDifference: TypeConstructorDescription {
        public class Cons_langPackDifference {
            public var langCode: String
            public var fromVersion: Int32
            public var version: Int32
            public var strings: [Api.LangPackString]
            public init(langCode: String, fromVersion: Int32, version: Int32, strings: [Api.LangPackString]) {
                self.langCode = langCode
                self.fromVersion = fromVersion
                self.version = version
                self.strings = strings
            }
        }
        case langPackDifference(Cons_langPackDifference)

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

        public static func parse_langPackDifference(_ reader: BufferReader) -> LangPackDifference? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum LangPackLanguage: TypeConstructorDescription {
        public class Cons_langPackLanguage {
            public var flags: Int32
            public var name: String
            public var nativeName: String
            public var langCode: String
            public var baseLangCode: String?
            public var pluralCode: String
            public var stringsCount: Int32
            public var translatedCount: Int32
            public var translationsUrl: String
            public init(flags: Int32, name: String, nativeName: String, langCode: String, baseLangCode: String?, pluralCode: String, stringsCount: Int32, translatedCount: Int32, translationsUrl: String) {
                self.flags = flags
                self.name = name
                self.nativeName = nativeName
                self.langCode = langCode
                self.baseLangCode = baseLangCode
                self.pluralCode = pluralCode
                self.stringsCount = stringsCount
                self.translatedCount = translatedCount
                self.translationsUrl = translationsUrl
            }
        }
        case langPackLanguage(Cons_langPackLanguage)

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

        public static func parse_langPackLanguage(_ reader: BufferReader) -> LangPackLanguage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum LangPackString: TypeConstructorDescription {
        public class Cons_langPackString {
            public var key: String
            public var value: String
            public init(key: String, value: String) {
                self.key = key
                self.value = value
            }
        }
        public class Cons_langPackStringDeleted {
            public var key: String
            public init(key: String) {
                self.key = key
            }
        }
        public class Cons_langPackStringPluralized {
            public var flags: Int32
            public var key: String
            public var zeroValue: String?
            public var oneValue: String?
            public var twoValue: String?
            public var fewValue: String?
            public var manyValue: String?
            public var otherValue: String
            public init(flags: Int32, key: String, zeroValue: String?, oneValue: String?, twoValue: String?, fewValue: String?, manyValue: String?, otherValue: String) {
                self.flags = flags
                self.key = key
                self.zeroValue = zeroValue
                self.oneValue = oneValue
                self.twoValue = twoValue
                self.fewValue = fewValue
                self.manyValue = manyValue
                self.otherValue = otherValue
            }
        }
        case langPackString(Cons_langPackString)
        case langPackStringDeleted(Cons_langPackStringDeleted)
        case langPackStringPluralized(Cons_langPackStringPluralized)

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

        public static func parse_langPackString(_ reader: BufferReader) -> LangPackString? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_langPackStringDeleted(_ reader: BufferReader) -> LangPackString? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_langPackStringPluralized(_ reader: BufferReader) -> LangPackString? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum MaskCoords: TypeConstructorDescription {
        public class Cons_maskCoords {
            public var n: Int32
            public var x: Double
            public var y: Double
            public var zoom: Double
            public init(n: Int32, x: Double, y: Double, zoom: Double) {
                self.n = n
                self.x = x
                self.y = y
                self.zoom = zoom
            }
        }
        case maskCoords(Cons_maskCoords)

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

        public static func parse_maskCoords(_ reader: BufferReader) -> MaskCoords? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum MediaArea: TypeConstructorDescription {
        public class Cons_inputMediaAreaChannelPost {
            public var coordinates: Api.MediaAreaCoordinates
            public var channel: Api.InputChannel
            public var msgId: Int32
            public init(coordinates: Api.MediaAreaCoordinates, channel: Api.InputChannel, msgId: Int32) {
                self.coordinates = coordinates
                self.channel = channel
                self.msgId = msgId
            }
        }
        public class Cons_inputMediaAreaVenue {
            public var coordinates: Api.MediaAreaCoordinates
            public var queryId: Int64
            public var resultId: String
            public init(coordinates: Api.MediaAreaCoordinates, queryId: Int64, resultId: String) {
                self.coordinates = coordinates
                self.queryId = queryId
                self.resultId = resultId
            }
        }
        public class Cons_mediaAreaChannelPost {
            public var coordinates: Api.MediaAreaCoordinates
            public var channelId: Int64
            public var msgId: Int32
            public init(coordinates: Api.MediaAreaCoordinates, channelId: Int64, msgId: Int32) {
                self.coordinates = coordinates
                self.channelId = channelId
                self.msgId = msgId
            }
        }
        public class Cons_mediaAreaGeoPoint {
            public var flags: Int32
            public var coordinates: Api.MediaAreaCoordinates
            public var geo: Api.GeoPoint
            public var address: Api.GeoPointAddress?
            public init(flags: Int32, coordinates: Api.MediaAreaCoordinates, geo: Api.GeoPoint, address: Api.GeoPointAddress?) {
                self.flags = flags
                self.coordinates = coordinates
                self.geo = geo
                self.address = address
            }
        }
        public class Cons_mediaAreaStarGift {
            public var coordinates: Api.MediaAreaCoordinates
            public var slug: String
            public init(coordinates: Api.MediaAreaCoordinates, slug: String) {
                self.coordinates = coordinates
                self.slug = slug
            }
        }
        public class Cons_mediaAreaSuggestedReaction {
            public var flags: Int32
            public var coordinates: Api.MediaAreaCoordinates
            public var reaction: Api.Reaction
            public init(flags: Int32, coordinates: Api.MediaAreaCoordinates, reaction: Api.Reaction) {
                self.flags = flags
                self.coordinates = coordinates
                self.reaction = reaction
            }
        }
        public class Cons_mediaAreaUrl {
            public var coordinates: Api.MediaAreaCoordinates
            public var url: String
            public init(coordinates: Api.MediaAreaCoordinates, url: String) {
                self.coordinates = coordinates
                self.url = url
            }
        }
        public class Cons_mediaAreaVenue {
            public var coordinates: Api.MediaAreaCoordinates
            public var geo: Api.GeoPoint
            public var title: String
            public var address: String
            public var provider: String
            public var venueId: String
            public var venueType: String
            public init(coordinates: Api.MediaAreaCoordinates, geo: Api.GeoPoint, title: String, address: String, provider: String, venueId: String, venueType: String) {
                self.coordinates = coordinates
                self.geo = geo
                self.title = title
                self.address = address
                self.provider = provider
                self.venueId = venueId
                self.venueType = venueType
            }
        }
        public class Cons_mediaAreaWeather {
            public var coordinates: Api.MediaAreaCoordinates
            public var emoji: String
            public var temperatureC: Double
            public var color: Int32
            public init(coordinates: Api.MediaAreaCoordinates, emoji: String, temperatureC: Double, color: Int32) {
                self.coordinates = coordinates
                self.emoji = emoji
                self.temperatureC = temperatureC
                self.color = color
            }
        }
        case inputMediaAreaChannelPost(Cons_inputMediaAreaChannelPost)
        case inputMediaAreaVenue(Cons_inputMediaAreaVenue)
        case mediaAreaChannelPost(Cons_mediaAreaChannelPost)
        case mediaAreaGeoPoint(Cons_mediaAreaGeoPoint)
        case mediaAreaStarGift(Cons_mediaAreaStarGift)
        case mediaAreaSuggestedReaction(Cons_mediaAreaSuggestedReaction)
        case mediaAreaUrl(Cons_mediaAreaUrl)
        case mediaAreaVenue(Cons_mediaAreaVenue)
        case mediaAreaWeather(Cons_mediaAreaWeather)

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

        public static func parse_inputMediaAreaChannelPost(_ reader: BufferReader) -> MediaArea? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMediaAreaVenue(_ reader: BufferReader) -> MediaArea? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_mediaAreaChannelPost(_ reader: BufferReader) -> MediaArea? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_mediaAreaGeoPoint(_ reader: BufferReader) -> MediaArea? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_mediaAreaStarGift(_ reader: BufferReader) -> MediaArea? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_mediaAreaSuggestedReaction(_ reader: BufferReader) -> MediaArea? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_mediaAreaUrl(_ reader: BufferReader) -> MediaArea? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_mediaAreaVenue(_ reader: BufferReader) -> MediaArea? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_mediaAreaWeather(_ reader: BufferReader) -> MediaArea? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum MediaAreaCoordinates: TypeConstructorDescription {
        public class Cons_mediaAreaCoordinates {
            public var flags: Int32
            public var x: Double
            public var y: Double
            public var w: Double
            public var h: Double
            public var rotation: Double
            public var radius: Double?
            public init(flags: Int32, x: Double, y: Double, w: Double, h: Double, rotation: Double, radius: Double?) {
                self.flags = flags
                self.x = x
                self.y = y
                self.w = w
                self.h = h
                self.rotation = rotation
                self.radius = radius
            }
        }
        case mediaAreaCoordinates(Cons_mediaAreaCoordinates)

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

        public static func parse_mediaAreaCoordinates(_ reader: BufferReader) -> MediaAreaCoordinates? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum Message: TypeConstructorDescription {
        public class Cons_message {
            public var flags: Int32
            public var flags2: Int32
            public var id: Int32
            public var fromId: Api.Peer?
            public var fromBoostsApplied: Int32?
            public var peerId: Api.Peer
            public var savedPeerId: Api.Peer?
            public var fwdFrom: Api.MessageFwdHeader?
            public var viaBotId: Int64?
            public var viaBusinessBotId: Int64?
            public var replyTo: Api.MessageReplyHeader?
            public var date: Int32
            public var message: String
            public var media: Api.MessageMedia?
            public var replyMarkup: Api.ReplyMarkup?
            public var entities: [Api.MessageEntity]?
            public var views: Int32?
            public var forwards: Int32?
            public var replies: Api.MessageReplies?
            public var editDate: Int32?
            public var postAuthor: String?
            public var groupedId: Int64?
            public var reactions: Api.MessageReactions?
            public var restrictionReason: [Api.RestrictionReason]?
            public var ttlPeriod: Int32?
            public var quickReplyShortcutId: Int32?
            public var effect: Int64?
            public var factcheck: Api.FactCheck?
            public var reportDeliveryUntilDate: Int32?
            public var paidMessageStars: Int64?
            public var suggestedPost: Api.SuggestedPost?
            public var scheduleRepeatPeriod: Int32?
            public var summaryFromLanguage: String?
            public init(flags: Int32, flags2: Int32, id: Int32, fromId: Api.Peer?, fromBoostsApplied: Int32?, peerId: Api.Peer, savedPeerId: Api.Peer?, fwdFrom: Api.MessageFwdHeader?, viaBotId: Int64?, viaBusinessBotId: Int64?, replyTo: Api.MessageReplyHeader?, date: Int32, message: String, media: Api.MessageMedia?, replyMarkup: Api.ReplyMarkup?, entities: [Api.MessageEntity]?, views: Int32?, forwards: Int32?, replies: Api.MessageReplies?, editDate: Int32?, postAuthor: String?, groupedId: Int64?, reactions: Api.MessageReactions?, restrictionReason: [Api.RestrictionReason]?, ttlPeriod: Int32?, quickReplyShortcutId: Int32?, effect: Int64?, factcheck: Api.FactCheck?, reportDeliveryUntilDate: Int32?, paidMessageStars: Int64?, suggestedPost: Api.SuggestedPost?, scheduleRepeatPeriod: Int32?, summaryFromLanguage: String?) {
                self.flags = flags
                self.flags2 = flags2
                self.id = id
                self.fromId = fromId
                self.fromBoostsApplied = fromBoostsApplied
                self.peerId = peerId
                self.savedPeerId = savedPeerId
                self.fwdFrom = fwdFrom
                self.viaBotId = viaBotId
                self.viaBusinessBotId = viaBusinessBotId
                self.replyTo = replyTo
                self.date = date
                self.message = message
                self.media = media
                self.replyMarkup = replyMarkup
                self.entities = entities
                self.views = views
                self.forwards = forwards
                self.replies = replies
                self.editDate = editDate
                self.postAuthor = postAuthor
                self.groupedId = groupedId
                self.reactions = reactions
                self.restrictionReason = restrictionReason
                self.ttlPeriod = ttlPeriod
                self.quickReplyShortcutId = quickReplyShortcutId
                self.effect = effect
                self.factcheck = factcheck
                self.reportDeliveryUntilDate = reportDeliveryUntilDate
                self.paidMessageStars = paidMessageStars
                self.suggestedPost = suggestedPost
                self.scheduleRepeatPeriod = scheduleRepeatPeriod
                self.summaryFromLanguage = summaryFromLanguage
            }
        }
        public class Cons_messageEmpty {
            public var flags: Int32
            public var id: Int32
            public var peerId: Api.Peer?
            public init(flags: Int32, id: Int32, peerId: Api.Peer?) {
                self.flags = flags
                self.id = id
                self.peerId = peerId
            }
        }
        public class Cons_messageService {
            public var flags: Int32
            public var id: Int32
            public var fromId: Api.Peer?
            public var peerId: Api.Peer
            public var savedPeerId: Api.Peer?
            public var replyTo: Api.MessageReplyHeader?
            public var date: Int32
            public var action: Api.MessageAction
            public var reactions: Api.MessageReactions?
            public var ttlPeriod: Int32?
            public init(flags: Int32, id: Int32, fromId: Api.Peer?, peerId: Api.Peer, savedPeerId: Api.Peer?, replyTo: Api.MessageReplyHeader?, date: Int32, action: Api.MessageAction, reactions: Api.MessageReactions?, ttlPeriod: Int32?) {
                self.flags = flags
                self.id = id
                self.fromId = fromId
                self.peerId = peerId
                self.savedPeerId = savedPeerId
                self.replyTo = replyTo
                self.date = date
                self.action = action
                self.reactions = reactions
                self.ttlPeriod = ttlPeriod
            }
        }
        case message(Cons_message)
        case messageEmpty(Cons_messageEmpty)
        case messageService(Cons_messageService)

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

        public static func parse_message(_ reader: BufferReader) -> Message? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageEmpty(_ reader: BufferReader) -> Message? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageService(_ reader: BufferReader) -> Message? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum MessageAction: TypeConstructorDescription {
        public class Cons_messageActionBoostApply {
            public var boosts: Int32
            public init(boosts: Int32) {
                self.boosts = boosts
            }
        }
        public class Cons_messageActionBotAllowed {
            public var flags: Int32
            public var domain: String?
            public var app: Api.BotApp?
            public init(flags: Int32, domain: String?, app: Api.BotApp?) {
                self.flags = flags
                self.domain = domain
                self.app = app
            }
        }
        public class Cons_messageActionChannelCreate {
            public var title: String
            public init(title: String) {
                self.title = title
            }
        }
        public class Cons_messageActionChannelMigrateFrom {
            public var title: String
            public var chatId: Int64
            public init(title: String, chatId: Int64) {
                self.title = title
                self.chatId = chatId
            }
        }
        public class Cons_messageActionChatAddUser {
            public var users: [Int64]
            public init(users: [Int64]) {
                self.users = users
            }
        }
        public class Cons_messageActionChatCreate {
            public var title: String
            public var users: [Int64]
            public init(title: String, users: [Int64]) {
                self.title = title
                self.users = users
            }
        }
        public class Cons_messageActionChatDeleteUser {
            public var userId: Int64
            public init(userId: Int64) {
                self.userId = userId
            }
        }
        public class Cons_messageActionChatEditPhoto {
            public var photo: Api.Photo
            public init(photo: Api.Photo) {
                self.photo = photo
            }
        }
        public class Cons_messageActionChatEditTitle {
            public var title: String
            public init(title: String) {
                self.title = title
            }
        }
        public class Cons_messageActionChatJoinedByLink {
            public var inviterId: Int64
            public init(inviterId: Int64) {
                self.inviterId = inviterId
            }
        }
        public class Cons_messageActionChatMigrateTo {
            public var channelId: Int64
            public init(channelId: Int64) {
                self.channelId = channelId
            }
        }
        public class Cons_messageActionConferenceCall {
            public var flags: Int32
            public var callId: Int64
            public var duration: Int32?
            public var otherParticipants: [Api.Peer]?
            public init(flags: Int32, callId: Int64, duration: Int32?, otherParticipants: [Api.Peer]?) {
                self.flags = flags
                self.callId = callId
                self.duration = duration
                self.otherParticipants = otherParticipants
            }
        }
        public class Cons_messageActionCustomAction {
            public var message: String
            public init(message: String) {
                self.message = message
            }
        }
        public class Cons_messageActionGameScore {
            public var gameId: Int64
            public var score: Int32
            public init(gameId: Int64, score: Int32) {
                self.gameId = gameId
                self.score = score
            }
        }
        public class Cons_messageActionGeoProximityReached {
            public var fromId: Api.Peer
            public var toId: Api.Peer
            public var distance: Int32
            public init(fromId: Api.Peer, toId: Api.Peer, distance: Int32) {
                self.fromId = fromId
                self.toId = toId
                self.distance = distance
            }
        }
        public class Cons_messageActionGiftCode {
            public var flags: Int32
            public var boostPeer: Api.Peer?
            public var days: Int32
            public var slug: String
            public var currency: String?
            public var amount: Int64?
            public var cryptoCurrency: String?
            public var cryptoAmount: Int64?
            public var message: Api.TextWithEntities?
            public init(flags: Int32, boostPeer: Api.Peer?, days: Int32, slug: String, currency: String?, amount: Int64?, cryptoCurrency: String?, cryptoAmount: Int64?, message: Api.TextWithEntities?) {
                self.flags = flags
                self.boostPeer = boostPeer
                self.days = days
                self.slug = slug
                self.currency = currency
                self.amount = amount
                self.cryptoCurrency = cryptoCurrency
                self.cryptoAmount = cryptoAmount
                self.message = message
            }
        }
        public class Cons_messageActionGiftPremium {
            public var flags: Int32
            public var currency: String
            public var amount: Int64
            public var days: Int32
            public var cryptoCurrency: String?
            public var cryptoAmount: Int64?
            public var message: Api.TextWithEntities?
            public init(flags: Int32, currency: String, amount: Int64, days: Int32, cryptoCurrency: String?, cryptoAmount: Int64?, message: Api.TextWithEntities?) {
                self.flags = flags
                self.currency = currency
                self.amount = amount
                self.days = days
                self.cryptoCurrency = cryptoCurrency
                self.cryptoAmount = cryptoAmount
                self.message = message
            }
        }
        public class Cons_messageActionGiftStars {
            public var flags: Int32
            public var currency: String
            public var amount: Int64
            public var stars: Int64
            public var cryptoCurrency: String?
            public var cryptoAmount: Int64?
            public var transactionId: String?
            public init(flags: Int32, currency: String, amount: Int64, stars: Int64, cryptoCurrency: String?, cryptoAmount: Int64?, transactionId: String?) {
                self.flags = flags
                self.currency = currency
                self.amount = amount
                self.stars = stars
                self.cryptoCurrency = cryptoCurrency
                self.cryptoAmount = cryptoAmount
                self.transactionId = transactionId
            }
        }
        public class Cons_messageActionGiftTon {
            public var flags: Int32
            public var currency: String
            public var amount: Int64
            public var cryptoCurrency: String
            public var cryptoAmount: Int64
            public var transactionId: String?
            public init(flags: Int32, currency: String, amount: Int64, cryptoCurrency: String, cryptoAmount: Int64, transactionId: String?) {
                self.flags = flags
                self.currency = currency
                self.amount = amount
                self.cryptoCurrency = cryptoCurrency
                self.cryptoAmount = cryptoAmount
                self.transactionId = transactionId
            }
        }
        public class Cons_messageActionGiveawayLaunch {
            public var flags: Int32
            public var stars: Int64?
            public init(flags: Int32, stars: Int64?) {
                self.flags = flags
                self.stars = stars
            }
        }
        public class Cons_messageActionGiveawayResults {
            public var flags: Int32
            public var winnersCount: Int32
            public var unclaimedCount: Int32
            public init(flags: Int32, winnersCount: Int32, unclaimedCount: Int32) {
                self.flags = flags
                self.winnersCount = winnersCount
                self.unclaimedCount = unclaimedCount
            }
        }
        public class Cons_messageActionGroupCall {
            public var flags: Int32
            public var call: Api.InputGroupCall
            public var duration: Int32?
            public init(flags: Int32, call: Api.InputGroupCall, duration: Int32?) {
                self.flags = flags
                self.call = call
                self.duration = duration
            }
        }
        public class Cons_messageActionGroupCallScheduled {
            public var call: Api.InputGroupCall
            public var scheduleDate: Int32
            public init(call: Api.InputGroupCall, scheduleDate: Int32) {
                self.call = call
                self.scheduleDate = scheduleDate
            }
        }
        public class Cons_messageActionInviteToGroupCall {
            public var call: Api.InputGroupCall
            public var users: [Int64]
            public init(call: Api.InputGroupCall, users: [Int64]) {
                self.call = call
                self.users = users
            }
        }
        public class Cons_messageActionPaidMessagesPrice {
            public var flags: Int32
            public var stars: Int64
            public init(flags: Int32, stars: Int64) {
                self.flags = flags
                self.stars = stars
            }
        }
        public class Cons_messageActionPaidMessagesRefunded {
            public var count: Int32
            public var stars: Int64
            public init(count: Int32, stars: Int64) {
                self.count = count
                self.stars = stars
            }
        }
        public class Cons_messageActionPaymentRefunded {
            public var flags: Int32
            public var peer: Api.Peer
            public var currency: String
            public var totalAmount: Int64
            public var payload: Buffer?
            public var charge: Api.PaymentCharge
            public init(flags: Int32, peer: Api.Peer, currency: String, totalAmount: Int64, payload: Buffer?, charge: Api.PaymentCharge) {
                self.flags = flags
                self.peer = peer
                self.currency = currency
                self.totalAmount = totalAmount
                self.payload = payload
                self.charge = charge
            }
        }
        public class Cons_messageActionPaymentSent {
            public var flags: Int32
            public var currency: String
            public var totalAmount: Int64
            public var invoiceSlug: String?
            public var subscriptionUntilDate: Int32?
            public init(flags: Int32, currency: String, totalAmount: Int64, invoiceSlug: String?, subscriptionUntilDate: Int32?) {
                self.flags = flags
                self.currency = currency
                self.totalAmount = totalAmount
                self.invoiceSlug = invoiceSlug
                self.subscriptionUntilDate = subscriptionUntilDate
            }
        }
        public class Cons_messageActionPaymentSentMe {
            public var flags: Int32
            public var currency: String
            public var totalAmount: Int64
            public var payload: Buffer
            public var info: Api.PaymentRequestedInfo?
            public var shippingOptionId: String?
            public var charge: Api.PaymentCharge
            public var subscriptionUntilDate: Int32?
            public init(flags: Int32, currency: String, totalAmount: Int64, payload: Buffer, info: Api.PaymentRequestedInfo?, shippingOptionId: String?, charge: Api.PaymentCharge, subscriptionUntilDate: Int32?) {
                self.flags = flags
                self.currency = currency
                self.totalAmount = totalAmount
                self.payload = payload
                self.info = info
                self.shippingOptionId = shippingOptionId
                self.charge = charge
                self.subscriptionUntilDate = subscriptionUntilDate
            }
        }
        public class Cons_messageActionPhoneCall {
            public var flags: Int32
            public var callId: Int64
            public var reason: Api.PhoneCallDiscardReason?
            public var duration: Int32?
            public init(flags: Int32, callId: Int64, reason: Api.PhoneCallDiscardReason?, duration: Int32?) {
                self.flags = flags
                self.callId = callId
                self.reason = reason
                self.duration = duration
            }
        }
        public class Cons_messageActionPrizeStars {
            public var flags: Int32
            public var stars: Int64
            public var transactionId: String
            public var boostPeer: Api.Peer
            public var giveawayMsgId: Int32
            public init(flags: Int32, stars: Int64, transactionId: String, boostPeer: Api.Peer, giveawayMsgId: Int32) {
                self.flags = flags
                self.stars = stars
                self.transactionId = transactionId
                self.boostPeer = boostPeer
                self.giveawayMsgId = giveawayMsgId
            }
        }
        public class Cons_messageActionRequestedPeer {
            public var buttonId: Int32
            public var peers: [Api.Peer]
            public init(buttonId: Int32, peers: [Api.Peer]) {
                self.buttonId = buttonId
                self.peers = peers
            }
        }
        public class Cons_messageActionRequestedPeerSentMe {
            public var buttonId: Int32
            public var peers: [Api.RequestedPeer]
            public init(buttonId: Int32, peers: [Api.RequestedPeer]) {
                self.buttonId = buttonId
                self.peers = peers
            }
        }
        public class Cons_messageActionSecureValuesSent {
            public var types: [Api.SecureValueType]
            public init(types: [Api.SecureValueType]) {
                self.types = types
            }
        }
        public class Cons_messageActionSecureValuesSentMe {
            public var values: [Api.SecureValue]
            public var credentials: Api.SecureCredentialsEncrypted
            public init(values: [Api.SecureValue], credentials: Api.SecureCredentialsEncrypted) {
                self.values = values
                self.credentials = credentials
            }
        }
        public class Cons_messageActionSetChatTheme {
            public var theme: Api.ChatTheme
            public init(theme: Api.ChatTheme) {
                self.theme = theme
            }
        }
        public class Cons_messageActionSetChatWallPaper {
            public var flags: Int32
            public var wallpaper: Api.WallPaper
            public init(flags: Int32, wallpaper: Api.WallPaper) {
                self.flags = flags
                self.wallpaper = wallpaper
            }
        }
        public class Cons_messageActionSetMessagesTTL {
            public var flags: Int32
            public var period: Int32
            public var autoSettingFrom: Int64?
            public init(flags: Int32, period: Int32, autoSettingFrom: Int64?) {
                self.flags = flags
                self.period = period
                self.autoSettingFrom = autoSettingFrom
            }
        }
        public class Cons_messageActionStarGift {
            public var flags: Int32
            public var gift: Api.StarGift
            public var message: Api.TextWithEntities?
            public var convertStars: Int64?
            public var upgradeMsgId: Int32?
            public var upgradeStars: Int64?
            public var fromId: Api.Peer?
            public var peer: Api.Peer?
            public var savedId: Int64?
            public var prepaidUpgradeHash: String?
            public var giftMsgId: Int32?
            public var toId: Api.Peer?
            public var giftNum: Int32?
            public init(flags: Int32, gift: Api.StarGift, message: Api.TextWithEntities?, convertStars: Int64?, upgradeMsgId: Int32?, upgradeStars: Int64?, fromId: Api.Peer?, peer: Api.Peer?, savedId: Int64?, prepaidUpgradeHash: String?, giftMsgId: Int32?, toId: Api.Peer?, giftNum: Int32?) {
                self.flags = flags
                self.gift = gift
                self.message = message
                self.convertStars = convertStars
                self.upgradeMsgId = upgradeMsgId
                self.upgradeStars = upgradeStars
                self.fromId = fromId
                self.peer = peer
                self.savedId = savedId
                self.prepaidUpgradeHash = prepaidUpgradeHash
                self.giftMsgId = giftMsgId
                self.toId = toId
                self.giftNum = giftNum
            }
        }
        public class Cons_messageActionStarGiftPurchaseOffer {
            public var flags: Int32
            public var gift: Api.StarGift
            public var price: Api.StarsAmount
            public var expiresAt: Int32
            public init(flags: Int32, gift: Api.StarGift, price: Api.StarsAmount, expiresAt: Int32) {
                self.flags = flags
                self.gift = gift
                self.price = price
                self.expiresAt = expiresAt
            }
        }
        public class Cons_messageActionStarGiftPurchaseOfferDeclined {
            public var flags: Int32
            public var gift: Api.StarGift
            public var price: Api.StarsAmount
            public init(flags: Int32, gift: Api.StarGift, price: Api.StarsAmount) {
                self.flags = flags
                self.gift = gift
                self.price = price
            }
        }
        public class Cons_messageActionStarGiftUnique {
            public var flags: Int32
            public var gift: Api.StarGift
            public var canExportAt: Int32?
            public var transferStars: Int64?
            public var fromId: Api.Peer?
            public var peer: Api.Peer?
            public var savedId: Int64?
            public var resaleAmount: Api.StarsAmount?
            public var canTransferAt: Int32?
            public var canResellAt: Int32?
            public var dropOriginalDetailsStars: Int64?
            public var canCraftAt: Int32?
            public var craftChancePermille: Int32?
            public init(flags: Int32, gift: Api.StarGift, canExportAt: Int32?, transferStars: Int64?, fromId: Api.Peer?, peer: Api.Peer?, savedId: Int64?, resaleAmount: Api.StarsAmount?, canTransferAt: Int32?, canResellAt: Int32?, dropOriginalDetailsStars: Int64?, canCraftAt: Int32?, craftChancePermille: Int32?) {
                self.flags = flags
                self.gift = gift
                self.canExportAt = canExportAt
                self.transferStars = transferStars
                self.fromId = fromId
                self.peer = peer
                self.savedId = savedId
                self.resaleAmount = resaleAmount
                self.canTransferAt = canTransferAt
                self.canResellAt = canResellAt
                self.dropOriginalDetailsStars = dropOriginalDetailsStars
                self.canCraftAt = canCraftAt
                self.craftChancePermille = craftChancePermille
            }
        }
        public class Cons_messageActionSuggestBirthday {
            public var birthday: Api.Birthday
            public init(birthday: Api.Birthday) {
                self.birthday = birthday
            }
        }
        public class Cons_messageActionSuggestProfilePhoto {
            public var photo: Api.Photo
            public init(photo: Api.Photo) {
                self.photo = photo
            }
        }
        public class Cons_messageActionSuggestedPostApproval {
            public var flags: Int32
            public var rejectComment: String?
            public var scheduleDate: Int32?
            public var price: Api.StarsAmount?
            public init(flags: Int32, rejectComment: String?, scheduleDate: Int32?, price: Api.StarsAmount?) {
                self.flags = flags
                self.rejectComment = rejectComment
                self.scheduleDate = scheduleDate
                self.price = price
            }
        }
        public class Cons_messageActionSuggestedPostRefund {
            public var flags: Int32
            public init(flags: Int32) {
                self.flags = flags
            }
        }
        public class Cons_messageActionSuggestedPostSuccess {
            public var price: Api.StarsAmount
            public init(price: Api.StarsAmount) {
                self.price = price
            }
        }
        public class Cons_messageActionTodoAppendTasks {
            public var list: [Api.TodoItem]
            public init(list: [Api.TodoItem]) {
                self.list = list
            }
        }
        public class Cons_messageActionTodoCompletions {
            public var completed: [Int32]
            public var incompleted: [Int32]
            public init(completed: [Int32], incompleted: [Int32]) {
                self.completed = completed
                self.incompleted = incompleted
            }
        }
        public class Cons_messageActionTopicCreate {
            public var flags: Int32
            public var title: String
            public var iconColor: Int32
            public var iconEmojiId: Int64?
            public init(flags: Int32, title: String, iconColor: Int32, iconEmojiId: Int64?) {
                self.flags = flags
                self.title = title
                self.iconColor = iconColor
                self.iconEmojiId = iconEmojiId
            }
        }
        public class Cons_messageActionTopicEdit {
            public var flags: Int32
            public var title: String?
            public var iconEmojiId: Int64?
            public var closed: Api.Bool?
            public var hidden: Api.Bool?
            public init(flags: Int32, title: String?, iconEmojiId: Int64?, closed: Api.Bool?, hidden: Api.Bool?) {
                self.flags = flags
                self.title = title
                self.iconEmojiId = iconEmojiId
                self.closed = closed
                self.hidden = hidden
            }
        }
        public class Cons_messageActionWebViewDataSent {
            public var text: String
            public init(text: String) {
                self.text = text
            }
        }
        public class Cons_messageActionWebViewDataSentMe {
            public var text: String
            public var data: String
            public init(text: String, data: String) {
                self.text = text
                self.data = data
            }
        }
        case messageActionBoostApply(Cons_messageActionBoostApply)
        case messageActionBotAllowed(Cons_messageActionBotAllowed)
        case messageActionChannelCreate(Cons_messageActionChannelCreate)
        case messageActionChannelMigrateFrom(Cons_messageActionChannelMigrateFrom)
        case messageActionChatAddUser(Cons_messageActionChatAddUser)
        case messageActionChatCreate(Cons_messageActionChatCreate)
        case messageActionChatDeletePhoto
        case messageActionChatDeleteUser(Cons_messageActionChatDeleteUser)
        case messageActionChatEditPhoto(Cons_messageActionChatEditPhoto)
        case messageActionChatEditTitle(Cons_messageActionChatEditTitle)
        case messageActionChatJoinedByLink(Cons_messageActionChatJoinedByLink)
        case messageActionChatJoinedByRequest
        case messageActionChatMigrateTo(Cons_messageActionChatMigrateTo)
        case messageActionConferenceCall(Cons_messageActionConferenceCall)
        case messageActionContactSignUp
        case messageActionCustomAction(Cons_messageActionCustomAction)
        case messageActionEmpty
        case messageActionGameScore(Cons_messageActionGameScore)
        case messageActionGeoProximityReached(Cons_messageActionGeoProximityReached)
        case messageActionGiftCode(Cons_messageActionGiftCode)
        case messageActionGiftPremium(Cons_messageActionGiftPremium)
        case messageActionGiftStars(Cons_messageActionGiftStars)
        case messageActionGiftTon(Cons_messageActionGiftTon)
        case messageActionGiveawayLaunch(Cons_messageActionGiveawayLaunch)
        case messageActionGiveawayResults(Cons_messageActionGiveawayResults)
        case messageActionGroupCall(Cons_messageActionGroupCall)
        case messageActionGroupCallScheduled(Cons_messageActionGroupCallScheduled)
        case messageActionHistoryClear
        case messageActionInviteToGroupCall(Cons_messageActionInviteToGroupCall)
        case messageActionPaidMessagesPrice(Cons_messageActionPaidMessagesPrice)
        case messageActionPaidMessagesRefunded(Cons_messageActionPaidMessagesRefunded)
        case messageActionPaymentRefunded(Cons_messageActionPaymentRefunded)
        case messageActionPaymentSent(Cons_messageActionPaymentSent)
        case messageActionPaymentSentMe(Cons_messageActionPaymentSentMe)
        case messageActionPhoneCall(Cons_messageActionPhoneCall)
        case messageActionPinMessage
        case messageActionPrizeStars(Cons_messageActionPrizeStars)
        case messageActionRequestedPeer(Cons_messageActionRequestedPeer)
        case messageActionRequestedPeerSentMe(Cons_messageActionRequestedPeerSentMe)
        case messageActionScreenshotTaken
        case messageActionSecureValuesSent(Cons_messageActionSecureValuesSent)
        case messageActionSecureValuesSentMe(Cons_messageActionSecureValuesSentMe)
        case messageActionSetChatTheme(Cons_messageActionSetChatTheme)
        case messageActionSetChatWallPaper(Cons_messageActionSetChatWallPaper)
        case messageActionSetMessagesTTL(Cons_messageActionSetMessagesTTL)
        case messageActionStarGift(Cons_messageActionStarGift)
        case messageActionStarGiftCraftFail
        case messageActionStarGiftPurchaseOffer(Cons_messageActionStarGiftPurchaseOffer)
        case messageActionStarGiftPurchaseOfferDeclined(Cons_messageActionStarGiftPurchaseOfferDeclined)
        case messageActionStarGiftUnique(Cons_messageActionStarGiftUnique)
        case messageActionSuggestBirthday(Cons_messageActionSuggestBirthday)
        case messageActionSuggestProfilePhoto(Cons_messageActionSuggestProfilePhoto)
        case messageActionSuggestedPostApproval(Cons_messageActionSuggestedPostApproval)
        case messageActionSuggestedPostRefund(Cons_messageActionSuggestedPostRefund)
        case messageActionSuggestedPostSuccess(Cons_messageActionSuggestedPostSuccess)
        case messageActionTodoAppendTasks(Cons_messageActionTodoAppendTasks)
        case messageActionTodoCompletions(Cons_messageActionTodoCompletions)
        case messageActionTopicCreate(Cons_messageActionTopicCreate)
        case messageActionTopicEdit(Cons_messageActionTopicEdit)
        case messageActionWebViewDataSent(Cons_messageActionWebViewDataSent)
        case messageActionWebViewDataSentMe(Cons_messageActionWebViewDataSentMe)

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

        public static func parse_messageActionBoostApply(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionBotAllowed(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionChannelCreate(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionChannelMigrateFrom(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionChatAddUser(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionChatCreate(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionChatDeletePhoto(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionChatDeleteUser(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionChatEditPhoto(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionChatEditTitle(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionChatJoinedByLink(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionChatJoinedByRequest(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionChatMigrateTo(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionConferenceCall(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionContactSignUp(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionCustomAction(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionEmpty(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionGameScore(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionGeoProximityReached(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionGiftCode(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionGiftPremium(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionGiftStars(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionGiftTon(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionGiveawayLaunch(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionGiveawayResults(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionGroupCall(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionGroupCallScheduled(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionHistoryClear(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionInviteToGroupCall(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionPaidMessagesPrice(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionPaidMessagesRefunded(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionPaymentRefunded(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionPaymentSent(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionPaymentSentMe(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionPhoneCall(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionPinMessage(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionPrizeStars(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionRequestedPeer(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionRequestedPeerSentMe(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionScreenshotTaken(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionSecureValuesSent(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionSecureValuesSentMe(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionSetChatTheme(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionSetChatWallPaper(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionSetMessagesTTL(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionStarGift(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionStarGiftCraftFail(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionStarGiftPurchaseOffer(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionStarGiftPurchaseOfferDeclined(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionStarGiftUnique(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionSuggestBirthday(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionSuggestProfilePhoto(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionSuggestedPostApproval(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionSuggestedPostRefund(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionSuggestedPostSuccess(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionTodoAppendTasks(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionTodoCompletions(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionTopicCreate(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionTopicEdit(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionWebViewDataSent(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionWebViewDataSentMe(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
