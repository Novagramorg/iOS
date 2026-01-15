public extension Api {
    enum AccountDaysTTL: TypeConstructorDescription {
        public class Cons_accountDaysTTL {
            public var days: Int32
            public init(days: Int32) {
                self.days = days
            }
        }
        case accountDaysTTL(Cons_accountDaysTTL)

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

        public static func parse_accountDaysTTL(_ reader: BufferReader) -> AccountDaysTTL? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum AttachMenuBot: TypeConstructorDescription {
        public class Cons_attachMenuBot {
            public var flags: Int32
            public var botId: Int64
            public var shortName: String
            public var peerTypes: [Api.AttachMenuPeerType]?
            public var icons: [Api.AttachMenuBotIcon]
            public init(flags: Int32, botId: Int64, shortName: String, peerTypes: [Api.AttachMenuPeerType]?, icons: [Api.AttachMenuBotIcon]) {
                self.flags = flags
                self.botId = botId
                self.shortName = shortName
                self.peerTypes = peerTypes
                self.icons = icons
            }
        }
        case attachMenuBot(Cons_attachMenuBot)

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

        public static func parse_attachMenuBot(_ reader: BufferReader) -> AttachMenuBot? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum AttachMenuBotIcon: TypeConstructorDescription {
        public class Cons_attachMenuBotIcon {
            public var flags: Int32
            public var name: String
            public var icon: Api.Document
            public var colors: [Api.AttachMenuBotIconColor]?
            public init(flags: Int32, name: String, icon: Api.Document, colors: [Api.AttachMenuBotIconColor]?) {
                self.flags = flags
                self.name = name
                self.icon = icon
                self.colors = colors
            }
        }
        case attachMenuBotIcon(Cons_attachMenuBotIcon)

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

        public static func parse_attachMenuBotIcon(_ reader: BufferReader) -> AttachMenuBotIcon? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum AttachMenuBotIconColor: TypeConstructorDescription {
        case attachMenuBotIconColor(name: String, color: Int32)

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

        public static func parse_attachMenuBotIconColor(_ reader: BufferReader) -> AttachMenuBotIconColor? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum AttachMenuBots: TypeConstructorDescription {
        case attachMenuBots(hash: Int64, bots: [Api.AttachMenuBot], users: [Api.User])
        case attachMenuBotsNotModified

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

        public static func parse_attachMenuBots(_ reader: BufferReader) -> AttachMenuBots? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_attachMenuBotsNotModified(_ reader: BufferReader) -> AttachMenuBots? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum AttachMenuBotsBot: TypeConstructorDescription {
        case attachMenuBotsBot(bot: Api.AttachMenuBot, users: [Api.User])

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

        public static func parse_attachMenuBotsBot(_ reader: BufferReader) -> AttachMenuBotsBot? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum AttachMenuPeerType: TypeConstructorDescription {
        case attachMenuPeerTypeBotPM
        case attachMenuPeerTypeBroadcast
        case attachMenuPeerTypeChat
        case attachMenuPeerTypePM
        case attachMenuPeerTypeSameBotPM

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

        public static func parse_attachMenuPeerTypeBotPM(_ reader: BufferReader) -> AttachMenuPeerType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_attachMenuPeerTypeBroadcast(_ reader: BufferReader) -> AttachMenuPeerType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_attachMenuPeerTypeChat(_ reader: BufferReader) -> AttachMenuPeerType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_attachMenuPeerTypePM(_ reader: BufferReader) -> AttachMenuPeerType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_attachMenuPeerTypeSameBotPM(_ reader: BufferReader) -> AttachMenuPeerType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum AuctionBidLevel: TypeConstructorDescription {
        case auctionBidLevel(pos: Int32, amount: Int64, date: Int32)

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

        public static func parse_auctionBidLevel(_ reader: BufferReader) -> AuctionBidLevel? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum Authorization: TypeConstructorDescription {
        case authorization(flags: Int32, hash: Int64, deviceModel: String, platform: String, systemVersion: String, apiId: Int32, appName: String, appVersion: String, dateCreated: Int32, dateActive: Int32, ip: String, country: String, region: String)

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

        public static func parse_authorization(_ reader: BufferReader) -> Authorization? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum AutoDownloadSettings: TypeConstructorDescription {
        case autoDownloadSettings(flags: Int32, photoSizeMax: Int32, videoSizeMax: Int64, fileSizeMax: Int64, videoUploadMaxbitrate: Int32, smallQueueActiveOperationsMax: Int32, largeQueueActiveOperationsMax: Int32)

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

        public static func parse_autoDownloadSettings(_ reader: BufferReader) -> AutoDownloadSettings? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum AutoSaveException: TypeConstructorDescription {
        case autoSaveException(peer: Api.Peer, settings: Api.AutoSaveSettings)

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

        public static func parse_autoSaveException(_ reader: BufferReader) -> AutoSaveException? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum AutoSaveSettings: TypeConstructorDescription {
        case autoSaveSettings(flags: Int32, videoMaxSize: Int64?)

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

        public static func parse_autoSaveSettings(_ reader: BufferReader) -> AutoSaveSettings? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum AvailableEffect: TypeConstructorDescription {
        case availableEffect(flags: Int32, id: Int64, emoticon: String, staticIconId: Int64?, effectStickerId: Int64, effectAnimationId: Int64?)

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

        public static func parse_availableEffect(_ reader: BufferReader) -> AvailableEffect? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum AvailableReaction: TypeConstructorDescription {
        case availableReaction(flags: Int32, reaction: String, title: String, staticIcon: Api.Document, appearAnimation: Api.Document, selectAnimation: Api.Document, activateAnimation: Api.Document, effectAnimation: Api.Document, aroundAnimation: Api.Document?, centerIcon: Api.Document?)

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

        public static func parse_availableReaction(_ reader: BufferReader) -> AvailableReaction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum BankCardOpenUrl: TypeConstructorDescription {
        case bankCardOpenUrl(url: String, name: String)

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

        public static func parse_bankCardOpenUrl(_ reader: BufferReader) -> BankCardOpenUrl? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum BaseTheme: TypeConstructorDescription {
        case baseThemeArctic
        case baseThemeClassic
        case baseThemeDay
        case baseThemeNight
        case baseThemeTinted

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

        public static func parse_baseThemeArctic(_ reader: BufferReader) -> BaseTheme? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_baseThemeClassic(_ reader: BufferReader) -> BaseTheme? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_baseThemeDay(_ reader: BufferReader) -> BaseTheme? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_baseThemeNight(_ reader: BufferReader) -> BaseTheme? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_baseThemeTinted(_ reader: BufferReader) -> BaseTheme? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum Birthday: TypeConstructorDescription {
        case birthday(flags: Int32, day: Int32, month: Int32, year: Int32?)

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

        public static func parse_birthday(_ reader: BufferReader) -> Birthday? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum Bool: TypeConstructorDescription {
        case boolFalse
        case boolTrue

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

        public static func parse_boolFalse(_ reader: BufferReader) -> Bool? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_boolTrue(_ reader: BufferReader) -> Bool? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum Boost: TypeConstructorDescription {
        case boost(flags: Int32, id: String, userId: Int64?, giveawayMsgId: Int32?, date: Int32, expires: Int32, usedGiftSlug: String?, multiplier: Int32?, stars: Int64?)

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

        public static func parse_boost(_ reader: BufferReader) -> Boost? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum BotApp: TypeConstructorDescription {
        case botApp(flags: Int32, id: Int64, accessHash: Int64, shortName: String, title: String, description: String, photo: Api.Photo, document: Api.Document?, hash: Int64)
        case botAppNotModified

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

        public static func parse_botApp(_ reader: BufferReader) -> BotApp? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_botAppNotModified(_ reader: BufferReader) -> BotApp? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum BotAppSettings: TypeConstructorDescription {
        case botAppSettings(flags: Int32, placeholderPath: Buffer?, backgroundColor: Int32?, backgroundDarkColor: Int32?, headerColor: Int32?, headerDarkColor: Int32?)

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

        public static func parse_botAppSettings(_ reader: BufferReader) -> BotAppSettings? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
