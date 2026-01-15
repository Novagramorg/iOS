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
        public class Cons_attachMenuBotIconColor {
            public var name: String
            public var color: Int32
            public init(name: String, color: Int32) {
                self.name = name
                self.color = color
            }
        }
        case attachMenuBotIconColor(Cons_attachMenuBotIconColor)

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
        public class Cons_attachMenuBots {
            public var hash: Int64
            public var bots: [Api.AttachMenuBot]
            public var users: [Api.User]
            public init(hash: Int64, bots: [Api.AttachMenuBot], users: [Api.User]) {
                self.hash = hash
                self.bots = bots
                self.users = users
            }
        }
        case attachMenuBots(Cons_attachMenuBots)
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
        public class Cons_attachMenuBotsBot {
            public var bot: Api.AttachMenuBot
            public var users: [Api.User]
            public init(bot: Api.AttachMenuBot, users: [Api.User]) {
                self.bot = bot
                self.users = users
            }
        }
        case attachMenuBotsBot(Cons_attachMenuBotsBot)

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
        public class Cons_auctionBidLevel {
            public var pos: Int32
            public var amount: Int64
            public var date: Int32
            public init(pos: Int32, amount: Int64, date: Int32) {
                self.pos = pos
                self.amount = amount
                self.date = date
            }
        }
        case auctionBidLevel(Cons_auctionBidLevel)

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
        public class Cons_authorization {
            public var flags: Int32
            public var hash: Int64
            public var deviceModel: String
            public var platform: String
            public var systemVersion: String
            public var apiId: Int32
            public var appName: String
            public var appVersion: String
            public var dateCreated: Int32
            public var dateActive: Int32
            public var ip: String
            public var country: String
            public var region: String
            public init(flags: Int32, hash: Int64, deviceModel: String, platform: String, systemVersion: String, apiId: Int32, appName: String, appVersion: String, dateCreated: Int32, dateActive: Int32, ip: String, country: String, region: String) {
                self.flags = flags
                self.hash = hash
                self.deviceModel = deviceModel
                self.platform = platform
                self.systemVersion = systemVersion
                self.apiId = apiId
                self.appName = appName
                self.appVersion = appVersion
                self.dateCreated = dateCreated
                self.dateActive = dateActive
                self.ip = ip
                self.country = country
                self.region = region
            }
        }
        case authorization(Cons_authorization)

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
        public class Cons_autoDownloadSettings {
            public var flags: Int32
            public var photoSizeMax: Int32
            public var videoSizeMax: Int64
            public var fileSizeMax: Int64
            public var videoUploadMaxbitrate: Int32
            public var smallQueueActiveOperationsMax: Int32
            public var largeQueueActiveOperationsMax: Int32
            public init(flags: Int32, photoSizeMax: Int32, videoSizeMax: Int64, fileSizeMax: Int64, videoUploadMaxbitrate: Int32, smallQueueActiveOperationsMax: Int32, largeQueueActiveOperationsMax: Int32) {
                self.flags = flags
                self.photoSizeMax = photoSizeMax
                self.videoSizeMax = videoSizeMax
                self.fileSizeMax = fileSizeMax
                self.videoUploadMaxbitrate = videoUploadMaxbitrate
                self.smallQueueActiveOperationsMax = smallQueueActiveOperationsMax
                self.largeQueueActiveOperationsMax = largeQueueActiveOperationsMax
            }
        }
        case autoDownloadSettings(Cons_autoDownloadSettings)

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
        public class Cons_autoSaveException {
            public var peer: Api.Peer
            public var settings: Api.AutoSaveSettings
            public init(peer: Api.Peer, settings: Api.AutoSaveSettings) {
                self.peer = peer
                self.settings = settings
            }
        }
        case autoSaveException(Cons_autoSaveException)

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
        public class Cons_autoSaveSettings {
            public var flags: Int32
            public var videoMaxSize: Int64?
            public init(flags: Int32, videoMaxSize: Int64?) {
                self.flags = flags
                self.videoMaxSize = videoMaxSize
            }
        }
        case autoSaveSettings(Cons_autoSaveSettings)

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
        public class Cons_availableEffect {
            public var flags: Int32
            public var id: Int64
            public var emoticon: String
            public var staticIconId: Int64?
            public var effectStickerId: Int64
            public var effectAnimationId: Int64?
            public init(flags: Int32, id: Int64, emoticon: String, staticIconId: Int64?, effectStickerId: Int64, effectAnimationId: Int64?) {
                self.flags = flags
                self.id = id
                self.emoticon = emoticon
                self.staticIconId = staticIconId
                self.effectStickerId = effectStickerId
                self.effectAnimationId = effectAnimationId
            }
        }
        case availableEffect(Cons_availableEffect)

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
