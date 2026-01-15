public extension Api {
    enum GroupCallParticipant: TypeConstructorDescription {
        public class Cons_groupCallParticipant {
            public var flags: Int32
            public var peer: Api.Peer
            public var date: Int32
            public var activeDate: Int32?
            public var source: Int32
            public var volume: Int32?
            public var about: String?
            public var raiseHandRating: Int64?
            public var video: Api.GroupCallParticipantVideo?
            public var presentation: Api.GroupCallParticipantVideo?
            public var paidStarsTotal: Int64?
            public init(flags: Int32, peer: Api.Peer, date: Int32, activeDate: Int32?, source: Int32, volume: Int32?, about: String?, raiseHandRating: Int64?, video: Api.GroupCallParticipantVideo?, presentation: Api.GroupCallParticipantVideo?, paidStarsTotal: Int64?) {
                self.flags = flags
                self.peer = peer
                self.date = date
                self.activeDate = activeDate
                self.source = source
                self.volume = volume
                self.about = about
                self.raiseHandRating = raiseHandRating
                self.video = video
                self.presentation = presentation
                self.paidStarsTotal = paidStarsTotal
            }
        }
        case groupCallParticipant(Cons_groupCallParticipant)

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

        public static func parse_groupCallParticipant(_ reader: BufferReader) -> GroupCallParticipant? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum GroupCallParticipantVideo: TypeConstructorDescription {
        public class Cons_groupCallParticipantVideo {
            public var flags: Int32
            public var endpoint: String
            public var sourceGroups: [Api.GroupCallParticipantVideoSourceGroup]
            public var audioSource: Int32?
            public init(flags: Int32, endpoint: String, sourceGroups: [Api.GroupCallParticipantVideoSourceGroup], audioSource: Int32?) {
                self.flags = flags
                self.endpoint = endpoint
                self.sourceGroups = sourceGroups
                self.audioSource = audioSource
            }
        }
        case groupCallParticipantVideo(Cons_groupCallParticipantVideo)

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

        public static func parse_groupCallParticipantVideo(_ reader: BufferReader) -> GroupCallParticipantVideo? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum GroupCallParticipantVideoSourceGroup: TypeConstructorDescription {
        public class Cons_groupCallParticipantVideoSourceGroup {
            public var semantics: String
            public var sources: [Int32]
            public init(semantics: String, sources: [Int32]) {
                self.semantics = semantics
                self.sources = sources
            }
        }
        case groupCallParticipantVideoSourceGroup(Cons_groupCallParticipantVideoSourceGroup)

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

        public static func parse_groupCallParticipantVideoSourceGroup(_ reader: BufferReader) -> GroupCallParticipantVideoSourceGroup? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum GroupCallStreamChannel: TypeConstructorDescription {
        public class Cons_groupCallStreamChannel {
            public var channel: Int32
            public var scale: Int32
            public var lastTimestampMs: Int64
            public init(channel: Int32, scale: Int32, lastTimestampMs: Int64) {
                self.channel = channel
                self.scale = scale
                self.lastTimestampMs = lastTimestampMs
            }
        }
        case groupCallStreamChannel(Cons_groupCallStreamChannel)

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

        public static func parse_groupCallStreamChannel(_ reader: BufferReader) -> GroupCallStreamChannel? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum HighScore: TypeConstructorDescription {
        public class Cons_highScore {
            public var pos: Int32
            public var userId: Int64
            public var score: Int32
            public init(pos: Int32, userId: Int64, score: Int32) {
                self.pos = pos
                self.userId = userId
                self.score = score
            }
        }
        case highScore(Cons_highScore)

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

        public static func parse_highScore(_ reader: BufferReader) -> HighScore? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum ImportedContact: TypeConstructorDescription {
        public class Cons_importedContact {
            public var userId: Int64
            public var clientId: Int64
            public init(userId: Int64, clientId: Int64) {
                self.userId = userId
                self.clientId = clientId
            }
        }
        case importedContact(Cons_importedContact)

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

        public static func parse_importedContact(_ reader: BufferReader) -> ImportedContact? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InlineBotSwitchPM: TypeConstructorDescription {
        public class Cons_inlineBotSwitchPM {
            public var text: String
            public var startParam: String
            public init(text: String, startParam: String) {
                self.text = text
                self.startParam = startParam
            }
        }
        case inlineBotSwitchPM(Cons_inlineBotSwitchPM)

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

        public static func parse_inlineBotSwitchPM(_ reader: BufferReader) -> InlineBotSwitchPM? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InlineBotWebView: TypeConstructorDescription {
        public class Cons_inlineBotWebView {
            public var text: String
            public var url: String
            public init(text: String, url: String) {
                self.text = text
                self.url = url
            }
        }
        case inlineBotWebView(Cons_inlineBotWebView)

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

        public static func parse_inlineBotWebView(_ reader: BufferReader) -> InlineBotWebView? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InlineQueryPeerType: TypeConstructorDescription {
        case inlineQueryPeerTypeBotPM
        case inlineQueryPeerTypeBroadcast
        case inlineQueryPeerTypeChat
        case inlineQueryPeerTypeMegagroup
        case inlineQueryPeerTypePM
        case inlineQueryPeerTypeSameBotPM

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

        public static func parse_inlineQueryPeerTypeBotPM(_ reader: BufferReader) -> InlineQueryPeerType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inlineQueryPeerTypeBroadcast(_ reader: BufferReader) -> InlineQueryPeerType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inlineQueryPeerTypeChat(_ reader: BufferReader) -> InlineQueryPeerType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inlineQueryPeerTypeMegagroup(_ reader: BufferReader) -> InlineQueryPeerType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inlineQueryPeerTypePM(_ reader: BufferReader) -> InlineQueryPeerType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inlineQueryPeerTypeSameBotPM(_ reader: BufferReader) -> InlineQueryPeerType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputAppEvent: TypeConstructorDescription {
        public class Cons_inputAppEvent {
            public var time: Double
            public var type: String
            public var peer: Int64
            public var data: Api.JSONValue
            public init(time: Double, type: String, peer: Int64, data: Api.JSONValue) {
                self.time = time
                self.type = type
                self.peer = peer
                self.data = data
            }
        }
        case inputAppEvent(Cons_inputAppEvent)

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

        public static func parse_inputAppEvent(_ reader: BufferReader) -> InputAppEvent? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum InputBotApp: TypeConstructorDescription {
        public class Cons_inputBotAppID {
            public var id: Int64
            public var accessHash: Int64
            public init(id: Int64, accessHash: Int64) {
                self.id = id
                self.accessHash = accessHash
            }
        }
        public class Cons_inputBotAppShortName {
            public var botId: Api.InputUser
            public var shortName: String
            public init(botId: Api.InputUser, shortName: String) {
                self.botId = botId
                self.shortName = shortName
            }
        }
        case inputBotAppID(Cons_inputBotAppID)
        case inputBotAppShortName(Cons_inputBotAppShortName)

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

        public static func parse_inputBotAppID(_ reader: BufferReader) -> InputBotApp? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputBotAppShortName(_ reader: BufferReader) -> InputBotApp? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputBotInlineMessage: TypeConstructorDescription {
        public class Cons_inputBotInlineMessageGame {
            public var flags: Int32
            public var replyMarkup: Api.ReplyMarkup?
            public init(flags: Int32, replyMarkup: Api.ReplyMarkup?) {
                self.flags = flags
                self.replyMarkup = replyMarkup
            }
        }
        public class Cons_inputBotInlineMessageMediaAuto {
            public var flags: Int32
            public var message: String
            public var entities: [Api.MessageEntity]?
            public var replyMarkup: Api.ReplyMarkup?
            public init(flags: Int32, message: String, entities: [Api.MessageEntity]?, replyMarkup: Api.ReplyMarkup?) {
                self.flags = flags
                self.message = message
                self.entities = entities
                self.replyMarkup = replyMarkup
            }
        }
        public class Cons_inputBotInlineMessageMediaContact {
            public var flags: Int32
            public var phoneNumber: String
            public var firstName: String
            public var lastName: String
            public var vcard: String
            public var replyMarkup: Api.ReplyMarkup?
            public init(flags: Int32, phoneNumber: String, firstName: String, lastName: String, vcard: String, replyMarkup: Api.ReplyMarkup?) {
                self.flags = flags
                self.phoneNumber = phoneNumber
                self.firstName = firstName
                self.lastName = lastName
                self.vcard = vcard
                self.replyMarkup = replyMarkup
            }
        }
        public class Cons_inputBotInlineMessageMediaGeo {
            public var flags: Int32
            public var geoPoint: Api.InputGeoPoint
            public var heading: Int32?
            public var period: Int32?
            public var proximityNotificationRadius: Int32?
            public var replyMarkup: Api.ReplyMarkup?
            public init(flags: Int32, geoPoint: Api.InputGeoPoint, heading: Int32?, period: Int32?, proximityNotificationRadius: Int32?, replyMarkup: Api.ReplyMarkup?) {
                self.flags = flags
                self.geoPoint = geoPoint
                self.heading = heading
                self.period = period
                self.proximityNotificationRadius = proximityNotificationRadius
                self.replyMarkup = replyMarkup
            }
        }
        public class Cons_inputBotInlineMessageMediaInvoice {
            public var flags: Int32
            public var title: String
            public var description: String
            public var photo: Api.InputWebDocument?
            public var invoice: Api.Invoice
            public var payload: Buffer
            public var provider: String
            public var providerData: Api.DataJSON
            public var replyMarkup: Api.ReplyMarkup?
            public init(flags: Int32, title: String, description: String, photo: Api.InputWebDocument?, invoice: Api.Invoice, payload: Buffer, provider: String, providerData: Api.DataJSON, replyMarkup: Api.ReplyMarkup?) {
                self.flags = flags
                self.title = title
                self.description = description
                self.photo = photo
                self.invoice = invoice
                self.payload = payload
                self.provider = provider
                self.providerData = providerData
                self.replyMarkup = replyMarkup
            }
        }
        public class Cons_inputBotInlineMessageMediaVenue {
            public var flags: Int32
            public var geoPoint: Api.InputGeoPoint
            public var title: String
            public var address: String
            public var provider: String
            public var venueId: String
            public var venueType: String
            public var replyMarkup: Api.ReplyMarkup?
            public init(flags: Int32, geoPoint: Api.InputGeoPoint, title: String, address: String, provider: String, venueId: String, venueType: String, replyMarkup: Api.ReplyMarkup?) {
                self.flags = flags
                self.geoPoint = geoPoint
                self.title = title
                self.address = address
                self.provider = provider
                self.venueId = venueId
                self.venueType = venueType
                self.replyMarkup = replyMarkup
            }
        }
        public class Cons_inputBotInlineMessageMediaWebPage {
            public var flags: Int32
            public var message: String
            public var entities: [Api.MessageEntity]?
            public var url: String
            public var replyMarkup: Api.ReplyMarkup?
            public init(flags: Int32, message: String, entities: [Api.MessageEntity]?, url: String, replyMarkup: Api.ReplyMarkup?) {
                self.flags = flags
                self.message = message
                self.entities = entities
                self.url = url
                self.replyMarkup = replyMarkup
            }
        }
        public class Cons_inputBotInlineMessageText {
            public var flags: Int32
            public var message: String
            public var entities: [Api.MessageEntity]?
            public var replyMarkup: Api.ReplyMarkup?
            public init(flags: Int32, message: String, entities: [Api.MessageEntity]?, replyMarkup: Api.ReplyMarkup?) {
                self.flags = flags
                self.message = message
                self.entities = entities
                self.replyMarkup = replyMarkup
            }
        }
        case inputBotInlineMessageGame(Cons_inputBotInlineMessageGame)
        case inputBotInlineMessageMediaAuto(Cons_inputBotInlineMessageMediaAuto)
        case inputBotInlineMessageMediaContact(Cons_inputBotInlineMessageMediaContact)
        case inputBotInlineMessageMediaGeo(Cons_inputBotInlineMessageMediaGeo)
        case inputBotInlineMessageMediaInvoice(Cons_inputBotInlineMessageMediaInvoice)
        case inputBotInlineMessageMediaVenue(Cons_inputBotInlineMessageMediaVenue)
        case inputBotInlineMessageMediaWebPage(Cons_inputBotInlineMessageMediaWebPage)
        case inputBotInlineMessageText(Cons_inputBotInlineMessageText)

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

        public static func parse_inputBotInlineMessageGame(_ reader: BufferReader) -> InputBotInlineMessage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputBotInlineMessageMediaAuto(_ reader: BufferReader) -> InputBotInlineMessage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputBotInlineMessageMediaContact(_ reader: BufferReader) -> InputBotInlineMessage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputBotInlineMessageMediaGeo(_ reader: BufferReader) -> InputBotInlineMessage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputBotInlineMessageMediaInvoice(_ reader: BufferReader) -> InputBotInlineMessage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputBotInlineMessageMediaVenue(_ reader: BufferReader) -> InputBotInlineMessage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputBotInlineMessageMediaWebPage(_ reader: BufferReader) -> InputBotInlineMessage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputBotInlineMessageText(_ reader: BufferReader) -> InputBotInlineMessage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputBotInlineMessageID: TypeConstructorDescription {
        public class Cons_inputBotInlineMessageID {
            public var dcId: Int32
            public var id: Int64
            public var accessHash: Int64
            public init(dcId: Int32, id: Int64, accessHash: Int64) {
                self.dcId = dcId
                self.id = id
                self.accessHash = accessHash
            }
        }
        public class Cons_inputBotInlineMessageID64 {
            public var dcId: Int32
            public var ownerId: Int64
            public var id: Int32
            public var accessHash: Int64
            public init(dcId: Int32, ownerId: Int64, id: Int32, accessHash: Int64) {
                self.dcId = dcId
                self.ownerId = ownerId
                self.id = id
                self.accessHash = accessHash
            }
        }
        case inputBotInlineMessageID(Cons_inputBotInlineMessageID)
        case inputBotInlineMessageID64(Cons_inputBotInlineMessageID64)

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

        public static func parse_inputBotInlineMessageID(_ reader: BufferReader) -> InputBotInlineMessageID? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputBotInlineMessageID64(_ reader: BufferReader) -> InputBotInlineMessageID? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputBotInlineResult: TypeConstructorDescription {
        public class Cons_inputBotInlineResult {
            public var flags: Int32
            public var id: String
            public var type: String
            public var title: String?
            public var description: String?
            public var url: String?
            public var thumb: Api.InputWebDocument?
            public var content: Api.InputWebDocument?
            public var sendMessage: Api.InputBotInlineMessage
            public init(flags: Int32, id: String, type: String, title: String?, description: String?, url: String?, thumb: Api.InputWebDocument?, content: Api.InputWebDocument?, sendMessage: Api.InputBotInlineMessage) {
                self.flags = flags
                self.id = id
                self.type = type
                self.title = title
                self.description = description
                self.url = url
                self.thumb = thumb
                self.content = content
                self.sendMessage = sendMessage
            }
        }
        public class Cons_inputBotInlineResultDocument {
            public var flags: Int32
            public var id: String
            public var type: String
            public var title: String?
            public var description: String?
            public var document: Api.InputDocument
            public var sendMessage: Api.InputBotInlineMessage
            public init(flags: Int32, id: String, type: String, title: String?, description: String?, document: Api.InputDocument, sendMessage: Api.InputBotInlineMessage) {
                self.flags = flags
                self.id = id
                self.type = type
                self.title = title
                self.description = description
                self.document = document
                self.sendMessage = sendMessage
            }
        }
        public class Cons_inputBotInlineResultGame {
            public var id: String
            public var shortName: String
            public var sendMessage: Api.InputBotInlineMessage
            public init(id: String, shortName: String, sendMessage: Api.InputBotInlineMessage) {
                self.id = id
                self.shortName = shortName
                self.sendMessage = sendMessage
            }
        }
        public class Cons_inputBotInlineResultPhoto {
            public var id: String
            public var type: String
            public var photo: Api.InputPhoto
            public var sendMessage: Api.InputBotInlineMessage
            public init(id: String, type: String, photo: Api.InputPhoto, sendMessage: Api.InputBotInlineMessage) {
                self.id = id
                self.type = type
                self.photo = photo
                self.sendMessage = sendMessage
            }
        }
        case inputBotInlineResult(Cons_inputBotInlineResult)
        case inputBotInlineResultDocument(Cons_inputBotInlineResultDocument)
        case inputBotInlineResultGame(Cons_inputBotInlineResultGame)
        case inputBotInlineResultPhoto(Cons_inputBotInlineResultPhoto)

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

        public static func parse_inputBotInlineResult(_ reader: BufferReader) -> InputBotInlineResult? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputBotInlineResultDocument(_ reader: BufferReader) -> InputBotInlineResult? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputBotInlineResultGame(_ reader: BufferReader) -> InputBotInlineResult? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputBotInlineResultPhoto(_ reader: BufferReader) -> InputBotInlineResult? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputBusinessAwayMessage: TypeConstructorDescription {
        public class Cons_inputBusinessAwayMessage {
            public var flags: Int32
            public var shortcutId: Int32
            public var schedule: Api.BusinessAwayMessageSchedule
            public var recipients: Api.InputBusinessRecipients
            public init(flags: Int32, shortcutId: Int32, schedule: Api.BusinessAwayMessageSchedule, recipients: Api.InputBusinessRecipients) {
                self.flags = flags
                self.shortcutId = shortcutId
                self.schedule = schedule
                self.recipients = recipients
            }
        }
        case inputBusinessAwayMessage(Cons_inputBusinessAwayMessage)

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

        public static func parse_inputBusinessAwayMessage(_ reader: BufferReader) -> InputBusinessAwayMessage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
