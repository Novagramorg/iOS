public extension Api {
    enum BotBusinessConnection: TypeConstructorDescription {
        case botBusinessConnection(flags: Int32, connectionId: String, userId: Int64, dcId: Int32, date: Int32, rights: Api.BusinessBotRights?)

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
        case botCommand(command: String, description: String)

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
        case botCommandScopeChatAdmins
        case botCommandScopeChats
        case botCommandScopeDefault
        case botCommandScopePeer(peer: Api.InputPeer)
        case botCommandScopePeerAdmins(peer: Api.InputPeer)
        case botCommandScopePeerUser(peer: Api.InputPeer, userId: Api.InputUser)
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
        case botInfo(flags: Int32, userId: Int64?, description: String?, descriptionPhoto: Api.Photo?, descriptionDocument: Api.Document?, commands: [Api.BotCommand]?, menuButton: Api.BotMenuButton?, privacyPolicyUrl: String?, appSettings: Api.BotAppSettings?, verifierSettings: Api.BotVerifierSettings?)

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
        case botInlineMessageMediaAuto(flags: Int32, message: String, entities: [Api.MessageEntity]?, replyMarkup: Api.ReplyMarkup?)
        case botInlineMessageMediaContact(flags: Int32, phoneNumber: String, firstName: String, lastName: String, vcard: String, replyMarkup: Api.ReplyMarkup?)
        case botInlineMessageMediaGeo(flags: Int32, geo: Api.GeoPoint, heading: Int32?, period: Int32?, proximityNotificationRadius: Int32?, replyMarkup: Api.ReplyMarkup?)
        case botInlineMessageMediaInvoice(flags: Int32, title: String, description: String, photo: Api.WebDocument?, currency: String, totalAmount: Int64, replyMarkup: Api.ReplyMarkup?)
        case botInlineMessageMediaVenue(flags: Int32, geo: Api.GeoPoint, title: String, address: String, provider: String, venueId: String, venueType: String, replyMarkup: Api.ReplyMarkup?)
        case botInlineMessageMediaWebPage(flags: Int32, message: String, entities: [Api.MessageEntity]?, url: String, replyMarkup: Api.ReplyMarkup?)
        case botInlineMessageText(flags: Int32, message: String, entities: [Api.MessageEntity]?, replyMarkup: Api.ReplyMarkup?)

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
        case botInlineMediaResult(flags: Int32, id: String, type: String, photo: Api.Photo?, document: Api.Document?, title: String?, description: String?, sendMessage: Api.BotInlineMessage)
        case botInlineResult(flags: Int32, id: String, type: String, title: String?, description: String?, url: String?, thumb: Api.WebDocument?, content: Api.WebDocument?, sendMessage: Api.BotInlineMessage)

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
        case botMenuButton(text: String, url: String)
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
        case botPreviewMedia(date: Int32, media: Api.MessageMedia)

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
        case botVerification(botId: Int64, icon: Int64, description: String)

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
        case botVerifierSettings(flags: Int32, icon: Int64, company: String, customDescription: String?)

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
        case businessAwayMessage(flags: Int32, shortcutId: Int32, schedule: Api.BusinessAwayMessageSchedule, recipients: Api.BusinessRecipients)

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
        case businessAwayMessageScheduleAlways
        case businessAwayMessageScheduleCustom(startDate: Int32, endDate: Int32)
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
