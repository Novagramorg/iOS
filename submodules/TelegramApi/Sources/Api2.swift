public extension Api {
    enum BotBusinessConnection: TypeConstructorDescription {
        public class Cons_botBusinessConnection {
            public var flags: Int32
            public var connectionId: String
            public var userId: Int64
            public var dcId: Int32
            public var date: Int32
            public var rights: Api.BusinessBotRights?
            public init(flags: Int32, connectionId: String, userId: Int64, dcId: Int32, date: Int32, rights: Api.BusinessBotRights?) {
                self.flags = flags
                self.connectionId = connectionId
                self.userId = userId
                self.dcId = dcId
                self.date = date
                self.rights = rights
            }
        }
        case botBusinessConnection(Cons_botBusinessConnection)

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

        public static func parse_botBusinessConnection(_ reader: BufferReader) -> BotBusinessConnection? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum BotCommand: TypeConstructorDescription {
        public class Cons_botCommand {
            public var command: String
            public var description: String
            public init(command: String, description: String) {
                self.command = command
                self.description = description
            }
        }
        case botCommand(Cons_botCommand)

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

        public static func parse_botCommand(_ reader: BufferReader) -> BotCommand? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum BotCommandScope: TypeConstructorDescription {
        public class Cons_botCommandScopePeer {
            public var peer: Api.InputPeer
            public init(peer: Api.InputPeer) {
                self.peer = peer
            }
        }
        public class Cons_botCommandScopePeerAdmins {
            public var peer: Api.InputPeer
            public init(peer: Api.InputPeer) {
                self.peer = peer
            }
        }
        public class Cons_botCommandScopePeerUser {
            public var peer: Api.InputPeer
            public var userId: Api.InputUser
            public init(peer: Api.InputPeer, userId: Api.InputUser) {
                self.peer = peer
                self.userId = userId
            }
        }
        case botCommandScopeChatAdmins
        case botCommandScopeChats
        case botCommandScopeDefault
        case botCommandScopePeer(Cons_botCommandScopePeer)
        case botCommandScopePeerAdmins(Cons_botCommandScopePeerAdmins)
        case botCommandScopePeerUser(Cons_botCommandScopePeerUser)
        case botCommandScopeUsers

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

        public static func parse_botCommandScopeChatAdmins(_ reader: BufferReader) -> BotCommandScope? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_botCommandScopeChats(_ reader: BufferReader) -> BotCommandScope? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_botCommandScopeDefault(_ reader: BufferReader) -> BotCommandScope? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_botCommandScopePeer(_ reader: BufferReader) -> BotCommandScope? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_botCommandScopePeerAdmins(_ reader: BufferReader) -> BotCommandScope? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_botCommandScopePeerUser(_ reader: BufferReader) -> BotCommandScope? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_botCommandScopeUsers(_ reader: BufferReader) -> BotCommandScope? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum BotInfo: TypeConstructorDescription {
        public class Cons_botInfo {
            public var flags: Int32
            public var userId: Int64?
            public var description: String?
            public var descriptionPhoto: Api.Photo?
            public var descriptionDocument: Api.Document?
            public var commands: [Api.BotCommand]?
            public var menuButton: Api.BotMenuButton?
            public var privacyPolicyUrl: String?
            public var appSettings: Api.BotAppSettings?
            public var verifierSettings: Api.BotVerifierSettings?
            public init(flags: Int32, userId: Int64?, description: String?, descriptionPhoto: Api.Photo?, descriptionDocument: Api.Document?, commands: [Api.BotCommand]?, menuButton: Api.BotMenuButton?, privacyPolicyUrl: String?, appSettings: Api.BotAppSettings?, verifierSettings: Api.BotVerifierSettings?) {
                self.flags = flags
                self.userId = userId
                self.description = description
                self.descriptionPhoto = descriptionPhoto
                self.descriptionDocument = descriptionDocument
                self.commands = commands
                self.menuButton = menuButton
                self.privacyPolicyUrl = privacyPolicyUrl
                self.appSettings = appSettings
                self.verifierSettings = verifierSettings
            }
        }
        case botInfo(Cons_botInfo)

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

        public static func parse_botInfo(_ reader: BufferReader) -> BotInfo? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum BotInlineMessage: TypeConstructorDescription {
        public class Cons_botInlineMessageMediaAuto {
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
        public class Cons_botInlineMessageMediaContact {
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
        public class Cons_botInlineMessageMediaGeo {
            public var flags: Int32
            public var geo: Api.GeoPoint
            public var heading: Int32?
            public var period: Int32?
            public var proximityNotificationRadius: Int32?
            public var replyMarkup: Api.ReplyMarkup?
            public init(flags: Int32, geo: Api.GeoPoint, heading: Int32?, period: Int32?, proximityNotificationRadius: Int32?, replyMarkup: Api.ReplyMarkup?) {
                self.flags = flags
                self.geo = geo
                self.heading = heading
                self.period = period
                self.proximityNotificationRadius = proximityNotificationRadius
                self.replyMarkup = replyMarkup
            }
        }
        public class Cons_botInlineMessageMediaInvoice {
            public var flags: Int32
            public var title: String
            public var description: String
            public var photo: Api.WebDocument?
            public var currency: String
            public var totalAmount: Int64
            public var replyMarkup: Api.ReplyMarkup?
            public init(flags: Int32, title: String, description: String, photo: Api.WebDocument?, currency: String, totalAmount: Int64, replyMarkup: Api.ReplyMarkup?) {
                self.flags = flags
                self.title = title
                self.description = description
                self.photo = photo
                self.currency = currency
                self.totalAmount = totalAmount
                self.replyMarkup = replyMarkup
            }
        }
        public class Cons_botInlineMessageMediaVenue {
            public var flags: Int32
            public var geo: Api.GeoPoint
            public var title: String
            public var address: String
            public var provider: String
            public var venueId: String
            public var venueType: String
            public var replyMarkup: Api.ReplyMarkup?
            public init(flags: Int32, geo: Api.GeoPoint, title: String, address: String, provider: String, venueId: String, venueType: String, replyMarkup: Api.ReplyMarkup?) {
                self.flags = flags
                self.geo = geo
                self.title = title
                self.address = address
                self.provider = provider
                self.venueId = venueId
                self.venueType = venueType
                self.replyMarkup = replyMarkup
            }
        }
        public class Cons_botInlineMessageMediaWebPage {
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
        public class Cons_botInlineMessageText {
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
        case botInlineMessageMediaAuto(Cons_botInlineMessageMediaAuto)
        case botInlineMessageMediaContact(Cons_botInlineMessageMediaContact)
        case botInlineMessageMediaGeo(Cons_botInlineMessageMediaGeo)
        case botInlineMessageMediaInvoice(Cons_botInlineMessageMediaInvoice)
        case botInlineMessageMediaVenue(Cons_botInlineMessageMediaVenue)
        case botInlineMessageMediaWebPage(Cons_botInlineMessageMediaWebPage)
        case botInlineMessageText(Cons_botInlineMessageText)

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

        public static func parse_botInlineMessageMediaAuto(_ reader: BufferReader) -> BotInlineMessage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_botInlineMessageMediaContact(_ reader: BufferReader) -> BotInlineMessage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_botInlineMessageMediaGeo(_ reader: BufferReader) -> BotInlineMessage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_botInlineMessageMediaInvoice(_ reader: BufferReader) -> BotInlineMessage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_botInlineMessageMediaVenue(_ reader: BufferReader) -> BotInlineMessage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_botInlineMessageMediaWebPage(_ reader: BufferReader) -> BotInlineMessage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_botInlineMessageText(_ reader: BufferReader) -> BotInlineMessage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum BotInlineResult: TypeConstructorDescription {
        public class Cons_botInlineMediaResult {
            public var flags: Int32
            public var id: String
            public var type: String
            public var photo: Api.Photo?
            public var document: Api.Document?
            public var title: String?
            public var description: String?
            public var sendMessage: Api.BotInlineMessage
            public init(flags: Int32, id: String, type: String, photo: Api.Photo?, document: Api.Document?, title: String?, description: String?, sendMessage: Api.BotInlineMessage) {
                self.flags = flags
                self.id = id
                self.type = type
                self.photo = photo
                self.document = document
                self.title = title
                self.description = description
                self.sendMessage = sendMessage
            }
        }
        public class Cons_botInlineResult {
            public var flags: Int32
            public var id: String
            public var type: String
            public var title: String?
            public var description: String?
            public var url: String?
            public var thumb: Api.WebDocument?
            public var content: Api.WebDocument?
            public var sendMessage: Api.BotInlineMessage
            public init(flags: Int32, id: String, type: String, title: String?, description: String?, url: String?, thumb: Api.WebDocument?, content: Api.WebDocument?, sendMessage: Api.BotInlineMessage) {
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
        case botInlineMediaResult(Cons_botInlineMediaResult)
        case botInlineResult(Cons_botInlineResult)

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

        public static func parse_botInlineMediaResult(_ reader: BufferReader) -> BotInlineResult? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_botInlineResult(_ reader: BufferReader) -> BotInlineResult? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum BotMenuButton: TypeConstructorDescription {
        public class Cons_botMenuButton {
            public var text: String
            public var url: String
            public init(text: String, url: String) {
                self.text = text
                self.url = url
            }
        }
        case botMenuButton(Cons_botMenuButton)
        case botMenuButtonCommands
        case botMenuButtonDefault

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

        public static func parse_botMenuButton(_ reader: BufferReader) -> BotMenuButton? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_botMenuButtonCommands(_ reader: BufferReader) -> BotMenuButton? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_botMenuButtonDefault(_ reader: BufferReader) -> BotMenuButton? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum BotPreviewMedia: TypeConstructorDescription {
        public class Cons_botPreviewMedia {
            public var date: Int32
            public var media: Api.MessageMedia
            public init(date: Int32, media: Api.MessageMedia) {
                self.date = date
                self.media = media
            }
        }
        case botPreviewMedia(Cons_botPreviewMedia)

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

        public static func parse_botPreviewMedia(_ reader: BufferReader) -> BotPreviewMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum BotVerification: TypeConstructorDescription {
        public class Cons_botVerification {
            public var botId: Int64
            public var icon: Int64
            public var description: String
            public init(botId: Int64, icon: Int64, description: String) {
                self.botId = botId
                self.icon = icon
                self.description = description
            }
        }
        case botVerification(Cons_botVerification)

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

        public static func parse_botVerification(_ reader: BufferReader) -> BotVerification? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum BotVerifierSettings: TypeConstructorDescription {
        public class Cons_botVerifierSettings {
            public var flags: Int32
            public var icon: Int64
            public var company: String
            public var customDescription: String?
            public init(flags: Int32, icon: Int64, company: String, customDescription: String?) {
                self.flags = flags
                self.icon = icon
                self.company = company
                self.customDescription = customDescription
            }
        }
        case botVerifierSettings(Cons_botVerifierSettings)

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

        public static func parse_botVerifierSettings(_ reader: BufferReader) -> BotVerifierSettings? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum BusinessAwayMessage: TypeConstructorDescription {
        public class Cons_businessAwayMessage {
            public var flags: Int32
            public var shortcutId: Int32
            public var schedule: Api.BusinessAwayMessageSchedule
            public var recipients: Api.BusinessRecipients
            public init(flags: Int32, shortcutId: Int32, schedule: Api.BusinessAwayMessageSchedule, recipients: Api.BusinessRecipients) {
                self.flags = flags
                self.shortcutId = shortcutId
                self.schedule = schedule
                self.recipients = recipients
            }
        }
        case businessAwayMessage(Cons_businessAwayMessage)

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

        public static func parse_businessAwayMessage(_ reader: BufferReader) -> BusinessAwayMessage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum BusinessAwayMessageSchedule: TypeConstructorDescription {
        public class Cons_businessAwayMessageScheduleCustom {
            public var startDate: Int32
            public var endDate: Int32
            public init(startDate: Int32, endDate: Int32) {
                self.startDate = startDate
                self.endDate = endDate
            }
        }
        case businessAwayMessageScheduleAlways
        case businessAwayMessageScheduleCustom(Cons_businessAwayMessageScheduleCustom)
        case businessAwayMessageScheduleOutsideWorkHours

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

        public static func parse_businessAwayMessageScheduleAlways(_ reader: BufferReader) -> BusinessAwayMessageSchedule? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_businessAwayMessageScheduleCustom(_ reader: BufferReader) -> BusinessAwayMessageSchedule? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_businessAwayMessageScheduleOutsideWorkHours(_ reader: BufferReader) -> BusinessAwayMessageSchedule? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum BusinessBotRecipients: TypeConstructorDescription {
        case businessBotRecipients(flags: Int32, users: [Int64]?, excludeUsers: [Int64]?)

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

        public static func parse_businessBotRecipients(_ reader: BufferReader) -> BusinessBotRecipients? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum BusinessBotRights: TypeConstructorDescription {
        case businessBotRights(flags: Int32)

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

        public static func parse_businessBotRights(_ reader: BufferReader) -> BusinessBotRights? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum BusinessChatLink: TypeConstructorDescription {
        case businessChatLink(flags: Int32, link: String, message: String, entities: [Api.MessageEntity]?, title: String?, views: Int32)

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

        public static func parse_businessChatLink(_ reader: BufferReader) -> BusinessChatLink? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
