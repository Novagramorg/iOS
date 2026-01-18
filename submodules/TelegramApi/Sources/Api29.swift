public extension Api {
    indirect enum Updates: TypeConstructorDescription {
        public class Cons_updateShort {
            public var update: Api.Update
            public var date: Int32
            public init(update: Api.Update, date: Int32) {
                self.update = update
                self.date = date
            }
        }
        public class Cons_updateShortChatMessage {
            public var flags: Int32
            public var id: Int32
            public var fromId: Int64
            public var chatId: Int64
            public var message: String
            public var pts: Int32
            public var ptsCount: Int32
            public var date: Int32
            public var fwdFrom: Api.MessageFwdHeader?
            public var viaBotId: Int64?
            public var replyTo: Api.MessageReplyHeader?
            public var entities: [Api.MessageEntity]?
            public var ttlPeriod: Int32?
            public init(flags: Int32, id: Int32, fromId: Int64, chatId: Int64, message: String, pts: Int32, ptsCount: Int32, date: Int32, fwdFrom: Api.MessageFwdHeader?, viaBotId: Int64?, replyTo: Api.MessageReplyHeader?, entities: [Api.MessageEntity]?, ttlPeriod: Int32?) {
                self.flags = flags
                self.id = id
                self.fromId = fromId
                self.chatId = chatId
                self.message = message
                self.pts = pts
                self.ptsCount = ptsCount
                self.date = date
                self.fwdFrom = fwdFrom
                self.viaBotId = viaBotId
                self.replyTo = replyTo
                self.entities = entities
                self.ttlPeriod = ttlPeriod
            }
        }
        public class Cons_updateShortMessage {
            public var flags: Int32
            public var id: Int32
            public var userId: Int64
            public var message: String
            public var pts: Int32
            public var ptsCount: Int32
            public var date: Int32
            public var fwdFrom: Api.MessageFwdHeader?
            public var viaBotId: Int64?
            public var replyTo: Api.MessageReplyHeader?
            public var entities: [Api.MessageEntity]?
            public var ttlPeriod: Int32?
            public init(flags: Int32, id: Int32, userId: Int64, message: String, pts: Int32, ptsCount: Int32, date: Int32, fwdFrom: Api.MessageFwdHeader?, viaBotId: Int64?, replyTo: Api.MessageReplyHeader?, entities: [Api.MessageEntity]?, ttlPeriod: Int32?) {
                self.flags = flags
                self.id = id
                self.userId = userId
                self.message = message
                self.pts = pts
                self.ptsCount = ptsCount
                self.date = date
                self.fwdFrom = fwdFrom
                self.viaBotId = viaBotId
                self.replyTo = replyTo
                self.entities = entities
                self.ttlPeriod = ttlPeriod
            }
        }
        public class Cons_updateShortSentMessage {
            public var flags: Int32
            public var id: Int32
            public var pts: Int32
            public var ptsCount: Int32
            public var date: Int32
            public var media: Api.MessageMedia?
            public var entities: [Api.MessageEntity]?
            public var ttlPeriod: Int32?
            public init(flags: Int32, id: Int32, pts: Int32, ptsCount: Int32, date: Int32, media: Api.MessageMedia?, entities: [Api.MessageEntity]?, ttlPeriod: Int32?) {
                self.flags = flags
                self.id = id
                self.pts = pts
                self.ptsCount = ptsCount
                self.date = date
                self.media = media
                self.entities = entities
                self.ttlPeriod = ttlPeriod
            }
        }
        public class Cons_updates {
            public var updates: [Api.Update]
            public var users: [Api.User]
            public var chats: [Api.Chat]
            public var date: Int32
            public var seq: Int32
            public init(updates: [Api.Update], users: [Api.User], chats: [Api.Chat], date: Int32, seq: Int32) {
                self.updates = updates
                self.users = users
                self.chats = chats
                self.date = date
                self.seq = seq
            }
        }
        public class Cons_updatesCombined {
            public var updates: [Api.Update]
            public var users: [Api.User]
            public var chats: [Api.Chat]
            public var date: Int32
            public var seqStart: Int32
            public var seq: Int32
            public init(updates: [Api.Update], users: [Api.User], chats: [Api.Chat], date: Int32, seqStart: Int32, seq: Int32) {
                self.updates = updates
                self.users = users
                self.chats = chats
                self.date = date
                self.seqStart = seqStart
                self.seq = seq
            }
        }
        case updateShort(Cons_updateShort)
        case updateShortChatMessage(Cons_updateShortChatMessage)
        case updateShortMessage(Cons_updateShortMessage)
        case updateShortSentMessage(Cons_updateShortSentMessage)
        case updates(Cons_updates)
        case updatesCombined(Cons_updatesCombined)
        case updatesTooLong

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

        public static func parse_updateShort(_ reader: BufferReader) -> Updates? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateShortChatMessage(_ reader: BufferReader) -> Updates? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateShortMessage(_ reader: BufferReader) -> Updates? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateShortSentMessage(_ reader: BufferReader) -> Updates? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updates(_ reader: BufferReader) -> Updates? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updatesCombined(_ reader: BufferReader) -> Updates? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updatesTooLong(_ reader: BufferReader) -> Updates? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum UrlAuthResult: TypeConstructorDescription {
        public class Cons_urlAuthResultAccepted {
            public var url: String
            public init(url: String) {
                self.url = url
            }
        }
        public class Cons_urlAuthResultRequest {
            public var flags: Int32
            public var bot: Api.User
            public var domain: String
            public init(flags: Int32, bot: Api.User, domain: String) {
                self.flags = flags
                self.bot = bot
                self.domain = domain
            }
        }
        case urlAuthResultAccepted(Cons_urlAuthResultAccepted)
        case urlAuthResultDefault
        case urlAuthResultRequest(Cons_urlAuthResultRequest)

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

        public static func parse_urlAuthResultAccepted(_ reader: BufferReader) -> UrlAuthResult? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_urlAuthResultDefault(_ reader: BufferReader) -> UrlAuthResult? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_urlAuthResultRequest(_ reader: BufferReader) -> UrlAuthResult? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum User: TypeConstructorDescription {
        public class Cons_user {
            public var flags: Int32
            public var flags2: Int32
            public var id: Int64
            public var accessHash: Int64?
            public var firstName: String?
            public var lastName: String?
            public var username: String?
            public var phone: String?
            public var photo: Api.UserProfilePhoto?
            public var status: Api.UserStatus?
            public var botInfoVersion: Int32?
            public var restrictionReason: [Api.RestrictionReason]?
            public var botInlinePlaceholder: String?
            public var langCode: String?
            public var emojiStatus: Api.EmojiStatus?
            public var usernames: [Api.Username]?
            public var storiesMaxId: Api.RecentStory?
            public var color: Api.PeerColor?
            public var profileColor: Api.PeerColor?
            public var botActiveUsers: Int32?
            public var botVerificationIcon: Int64?
            public var sendPaidMessagesStars: Int64?
            public init(flags: Int32, flags2: Int32, id: Int64, accessHash: Int64?, firstName: String?, lastName: String?, username: String?, phone: String?, photo: Api.UserProfilePhoto?, status: Api.UserStatus?, botInfoVersion: Int32?, restrictionReason: [Api.RestrictionReason]?, botInlinePlaceholder: String?, langCode: String?, emojiStatus: Api.EmojiStatus?, usernames: [Api.Username]?, storiesMaxId: Api.RecentStory?, color: Api.PeerColor?, profileColor: Api.PeerColor?, botActiveUsers: Int32?, botVerificationIcon: Int64?, sendPaidMessagesStars: Int64?) {
                self.flags = flags
                self.flags2 = flags2
                self.id = id
                self.accessHash = accessHash
                self.firstName = firstName
                self.lastName = lastName
                self.username = username
                self.phone = phone
                self.photo = photo
                self.status = status
                self.botInfoVersion = botInfoVersion
                self.restrictionReason = restrictionReason
                self.botInlinePlaceholder = botInlinePlaceholder
                self.langCode = langCode
                self.emojiStatus = emojiStatus
                self.usernames = usernames
                self.storiesMaxId = storiesMaxId
                self.color = color
                self.profileColor = profileColor
                self.botActiveUsers = botActiveUsers
                self.botVerificationIcon = botVerificationIcon
                self.sendPaidMessagesStars = sendPaidMessagesStars
            }
        }
        public class Cons_userEmpty {
            public var id: Int64
            public init(id: Int64) {
                self.id = id
            }
        }
        case user(Cons_user)
        case userEmpty(Cons_userEmpty)

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

        public static func parse_user(_ reader: BufferReader) -> User? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_userEmpty(_ reader: BufferReader) -> User? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum UserFull: TypeConstructorDescription {
        public class Cons_userFull {
            public var flags: Int32
            public var flags2: Int32
            public var id: Int64
            public var about: String?
            public var settings: Api.PeerSettings
            public var personalPhoto: Api.Photo?
            public var profilePhoto: Api.Photo?
            public var fallbackPhoto: Api.Photo?
            public var notifySettings: Api.PeerNotifySettings
            public var botInfo: Api.BotInfo?
            public var pinnedMsgId: Int32?
            public var commonChatsCount: Int32
            public var folderId: Int32?
            public var ttlPeriod: Int32?
            public var theme: Api.ChatTheme?
            public var privateForwardName: String?
            public var botGroupAdminRights: Api.ChatAdminRights?
            public var botBroadcastAdminRights: Api.ChatAdminRights?
            public var wallpaper: Api.WallPaper?
            public var stories: Api.PeerStories?
            public var businessWorkHours: Api.BusinessWorkHours?
            public var businessLocation: Api.BusinessLocation?
            public var businessGreetingMessage: Api.BusinessGreetingMessage?
            public var businessAwayMessage: Api.BusinessAwayMessage?
            public var businessIntro: Api.BusinessIntro?
            public var birthday: Api.Birthday?
            public var personalChannelId: Int64?
            public var personalChannelMessage: Int32?
            public var stargiftsCount: Int32?
            public var starrefProgram: Api.StarRefProgram?
            public var botVerification: Api.BotVerification?
            public var sendPaidMessagesStars: Int64?
            public var disallowedGifts: Api.DisallowedGiftsSettings?
            public var starsRating: Api.StarsRating?
            public var starsMyPendingRating: Api.StarsRating?
            public var starsMyPendingRatingDate: Int32?
            public var mainTab: Api.ProfileTab?
            public var savedMusic: Api.Document?
            public var note: Api.TextWithEntities?
            public init(flags: Int32, flags2: Int32, id: Int64, about: String?, settings: Api.PeerSettings, personalPhoto: Api.Photo?, profilePhoto: Api.Photo?, fallbackPhoto: Api.Photo?, notifySettings: Api.PeerNotifySettings, botInfo: Api.BotInfo?, pinnedMsgId: Int32?, commonChatsCount: Int32, folderId: Int32?, ttlPeriod: Int32?, theme: Api.ChatTheme?, privateForwardName: String?, botGroupAdminRights: Api.ChatAdminRights?, botBroadcastAdminRights: Api.ChatAdminRights?, wallpaper: Api.WallPaper?, stories: Api.PeerStories?, businessWorkHours: Api.BusinessWorkHours?, businessLocation: Api.BusinessLocation?, businessGreetingMessage: Api.BusinessGreetingMessage?, businessAwayMessage: Api.BusinessAwayMessage?, businessIntro: Api.BusinessIntro?, birthday: Api.Birthday?, personalChannelId: Int64?, personalChannelMessage: Int32?, stargiftsCount: Int32?, starrefProgram: Api.StarRefProgram?, botVerification: Api.BotVerification?, sendPaidMessagesStars: Int64?, disallowedGifts: Api.DisallowedGiftsSettings?, starsRating: Api.StarsRating?, starsMyPendingRating: Api.StarsRating?, starsMyPendingRatingDate: Int32?, mainTab: Api.ProfileTab?, savedMusic: Api.Document?, note: Api.TextWithEntities?) {
                self.flags = flags
                self.flags2 = flags2
                self.id = id
                self.about = about
                self.settings = settings
                self.personalPhoto = personalPhoto
                self.profilePhoto = profilePhoto
                self.fallbackPhoto = fallbackPhoto
                self.notifySettings = notifySettings
                self.botInfo = botInfo
                self.pinnedMsgId = pinnedMsgId
                self.commonChatsCount = commonChatsCount
                self.folderId = folderId
                self.ttlPeriod = ttlPeriod
                self.theme = theme
                self.privateForwardName = privateForwardName
                self.botGroupAdminRights = botGroupAdminRights
                self.botBroadcastAdminRights = botBroadcastAdminRights
                self.wallpaper = wallpaper
                self.stories = stories
                self.businessWorkHours = businessWorkHours
                self.businessLocation = businessLocation
                self.businessGreetingMessage = businessGreetingMessage
                self.businessAwayMessage = businessAwayMessage
                self.businessIntro = businessIntro
                self.birthday = birthday
                self.personalChannelId = personalChannelId
                self.personalChannelMessage = personalChannelMessage
                self.stargiftsCount = stargiftsCount
                self.starrefProgram = starrefProgram
                self.botVerification = botVerification
                self.sendPaidMessagesStars = sendPaidMessagesStars
                self.disallowedGifts = disallowedGifts
                self.starsRating = starsRating
                self.starsMyPendingRating = starsMyPendingRating
                self.starsMyPendingRatingDate = starsMyPendingRatingDate
                self.mainTab = mainTab
                self.savedMusic = savedMusic
                self.note = note
            }
        }
        case userFull(Cons_userFull)

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

        public static func parse_userFull(_ reader: BufferReader) -> UserFull? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum UserProfilePhoto: TypeConstructorDescription {
        public class Cons_userProfilePhoto {
            public var flags: Int32
            public var photoId: Int64
            public var strippedThumb: Buffer?
            public var dcId: Int32
            public init(flags: Int32, photoId: Int64, strippedThumb: Buffer?, dcId: Int32) {
                self.flags = flags
                self.photoId = photoId
                self.strippedThumb = strippedThumb
                self.dcId = dcId
            }
        }
        case userProfilePhoto(Cons_userProfilePhoto)
        case userProfilePhotoEmpty

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

        public static func parse_userProfilePhoto(_ reader: BufferReader) -> UserProfilePhoto? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_userProfilePhotoEmpty(_ reader: BufferReader) -> UserProfilePhoto? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum UserStatus: TypeConstructorDescription {
        public class Cons_userStatusLastMonth {
            public var flags: Int32
            public init(flags: Int32) {
                self.flags = flags
            }
        }
        public class Cons_userStatusLastWeek {
            public var flags: Int32
            public init(flags: Int32) {
                self.flags = flags
            }
        }
        public class Cons_userStatusOffline {
            public var wasOnline: Int32
            public init(wasOnline: Int32) {
                self.wasOnline = wasOnline
            }
        }
        public class Cons_userStatusOnline {
            public var expires: Int32
            public init(expires: Int32) {
                self.expires = expires
            }
        }
        public class Cons_userStatusRecently {
            public var flags: Int32
            public init(flags: Int32) {
                self.flags = flags
            }
        }
        case userStatusEmpty
        case userStatusLastMonth(Cons_userStatusLastMonth)
        case userStatusLastWeek(Cons_userStatusLastWeek)
        case userStatusOffline(Cons_userStatusOffline)
        case userStatusOnline(Cons_userStatusOnline)
        case userStatusRecently(Cons_userStatusRecently)

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

        public static func parse_userStatusEmpty(_ reader: BufferReader) -> UserStatus? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_userStatusLastMonth(_ reader: BufferReader) -> UserStatus? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_userStatusLastWeek(_ reader: BufferReader) -> UserStatus? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_userStatusOffline(_ reader: BufferReader) -> UserStatus? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_userStatusOnline(_ reader: BufferReader) -> UserStatus? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_userStatusRecently(_ reader: BufferReader) -> UserStatus? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum Username: TypeConstructorDescription {
        public class Cons_username {
            public var flags: Int32
            public var username: String
            public init(flags: Int32, username: String) {
                self.flags = flags
                self.username = username
            }
        }
        case username(Cons_username)

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

        public static func parse_username(_ reader: BufferReader) -> Username? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum VideoSize: TypeConstructorDescription {
        public class Cons_videoSize {
            public var flags: Int32
            public var type: String
            public var w: Int32
            public var h: Int32
            public var size: Int32
            public var videoStartTs: Double?
            public init(flags: Int32, type: String, w: Int32, h: Int32, size: Int32, videoStartTs: Double?) {
                self.flags = flags
                self.type = type
                self.w = w
                self.h = h
                self.size = size
                self.videoStartTs = videoStartTs
            }
        }
        public class Cons_videoSizeEmojiMarkup {
            public var emojiId: Int64
            public var backgroundColors: [Int32]
            public init(emojiId: Int64, backgroundColors: [Int32]) {
                self.emojiId = emojiId
                self.backgroundColors = backgroundColors
            }
        }
        public class Cons_videoSizeStickerMarkup {
            public var stickerset: Api.InputStickerSet
            public var stickerId: Int64
            public var backgroundColors: [Int32]
            public init(stickerset: Api.InputStickerSet, stickerId: Int64, backgroundColors: [Int32]) {
                self.stickerset = stickerset
                self.stickerId = stickerId
                self.backgroundColors = backgroundColors
            }
        }
        case videoSize(Cons_videoSize)
        case videoSizeEmojiMarkup(Cons_videoSizeEmojiMarkup)
        case videoSizeStickerMarkup(Cons_videoSizeStickerMarkup)

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

        public static func parse_videoSize(_ reader: BufferReader) -> VideoSize? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_videoSizeEmojiMarkup(_ reader: BufferReader) -> VideoSize? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_videoSizeStickerMarkup(_ reader: BufferReader) -> VideoSize? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum WallPaper: TypeConstructorDescription {
        public class Cons_wallPaper {
            public var id: Int64
            public var flags: Int32
            public var accessHash: Int64
            public var slug: String
            public var document: Api.Document
            public var settings: Api.WallPaperSettings?
            public init(id: Int64, flags: Int32, accessHash: Int64, slug: String, document: Api.Document, settings: Api.WallPaperSettings?) {
                self.id = id
                self.flags = flags
                self.accessHash = accessHash
                self.slug = slug
                self.document = document
                self.settings = settings
            }
        }
        public class Cons_wallPaperNoFile {
            public var id: Int64
            public var flags: Int32
            public var settings: Api.WallPaperSettings?
            public init(id: Int64, flags: Int32, settings: Api.WallPaperSettings?) {
                self.id = id
                self.flags = flags
                self.settings = settings
            }
        }
        case wallPaper(Cons_wallPaper)
        case wallPaperNoFile(Cons_wallPaperNoFile)

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

        public static func parse_wallPaper(_ reader: BufferReader) -> WallPaper? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_wallPaperNoFile(_ reader: BufferReader) -> WallPaper? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum WallPaperSettings: TypeConstructorDescription {
        public class Cons_wallPaperSettings {
            public var flags: Int32
            public var backgroundColor: Int32?
            public var secondBackgroundColor: Int32?
            public var thirdBackgroundColor: Int32?
            public var fourthBackgroundColor: Int32?
            public var intensity: Int32?
            public var rotation: Int32?
            public var emoticon: String?
            public init(flags: Int32, backgroundColor: Int32?, secondBackgroundColor: Int32?, thirdBackgroundColor: Int32?, fourthBackgroundColor: Int32?, intensity: Int32?, rotation: Int32?, emoticon: String?) {
                self.flags = flags
                self.backgroundColor = backgroundColor
                self.secondBackgroundColor = secondBackgroundColor
                self.thirdBackgroundColor = thirdBackgroundColor
                self.fourthBackgroundColor = fourthBackgroundColor
                self.intensity = intensity
                self.rotation = rotation
                self.emoticon = emoticon
            }
        }
        case wallPaperSettings(Cons_wallPaperSettings)

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

        public static func parse_wallPaperSettings(_ reader: BufferReader) -> WallPaperSettings? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum WebAuthorization: TypeConstructorDescription {
        public class Cons_webAuthorization {
            public var hash: Int64
            public var botId: Int64
            public var domain: String
            public var browser: String
            public var platform: String
            public var dateCreated: Int32
            public var dateActive: Int32
            public var ip: String
            public var region: String
            public init(hash: Int64, botId: Int64, domain: String, browser: String, platform: String, dateCreated: Int32, dateActive: Int32, ip: String, region: String) {
                self.hash = hash
                self.botId = botId
                self.domain = domain
                self.browser = browser
                self.platform = platform
                self.dateCreated = dateCreated
                self.dateActive = dateActive
                self.ip = ip
                self.region = region
            }
        }
        case webAuthorization(Cons_webAuthorization)

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

        public static func parse_webAuthorization(_ reader: BufferReader) -> WebAuthorization? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum WebDocument: TypeConstructorDescription {
        public class Cons_webDocument {
            public var url: String
            public var accessHash: Int64
            public var size: Int32
            public var mimeType: String
            public var attributes: [Api.DocumentAttribute]
            public init(url: String, accessHash: Int64, size: Int32, mimeType: String, attributes: [Api.DocumentAttribute]) {
                self.url = url
                self.accessHash = accessHash
                self.size = size
                self.mimeType = mimeType
                self.attributes = attributes
            }
        }
        public class Cons_webDocumentNoProxy {
            public var url: String
            public var size: Int32
            public var mimeType: String
            public var attributes: [Api.DocumentAttribute]
            public init(url: String, size: Int32, mimeType: String, attributes: [Api.DocumentAttribute]) {
                self.url = url
                self.size = size
                self.mimeType = mimeType
                self.attributes = attributes
            }
        }
        case webDocument(Cons_webDocument)
        case webDocumentNoProxy(Cons_webDocumentNoProxy)

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

        public static func parse_webDocument(_ reader: BufferReader) -> WebDocument? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_webDocumentNoProxy(_ reader: BufferReader) -> WebDocument? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum WebPage: TypeConstructorDescription {
        public class Cons_webPage {
            public var flags: Int32
            public var id: Int64
            public var url: String
            public var displayUrl: String
            public var hash: Int32
            public var type: String?
            public var siteName: String?
            public var title: String?
            public var description: String?
            public var photo: Api.Photo?
            public var embedUrl: String?
            public var embedType: String?
            public var embedWidth: Int32?
            public var embedHeight: Int32?
            public var duration: Int32?
            public var author: String?
            public var document: Api.Document?
            public var cachedPage: Api.Page?
            public var attributes: [Api.WebPageAttribute]?
            public init(flags: Int32, id: Int64, url: String, displayUrl: String, hash: Int32, type: String?, siteName: String?, title: String?, description: String?, photo: Api.Photo?, embedUrl: String?, embedType: String?, embedWidth: Int32?, embedHeight: Int32?, duration: Int32?, author: String?, document: Api.Document?, cachedPage: Api.Page?, attributes: [Api.WebPageAttribute]?) {
                self.flags = flags
                self.id = id
                self.url = url
                self.displayUrl = displayUrl
                self.hash = hash
                self.type = type
                self.siteName = siteName
                self.title = title
                self.description = description
                self.photo = photo
                self.embedUrl = embedUrl
                self.embedType = embedType
                self.embedWidth = embedWidth
                self.embedHeight = embedHeight
                self.duration = duration
                self.author = author
                self.document = document
                self.cachedPage = cachedPage
                self.attributes = attributes
            }
        }
        public class Cons_webPageEmpty {
            public var flags: Int32
            public var id: Int64
            public var url: String?
            public init(flags: Int32, id: Int64, url: String?) {
                self.flags = flags
                self.id = id
                self.url = url
            }
        }
        public class Cons_webPageNotModified {
            public var flags: Int32
            public var cachedPageViews: Int32?
            public init(flags: Int32, cachedPageViews: Int32?) {
                self.flags = flags
                self.cachedPageViews = cachedPageViews
            }
        }
        public class Cons_webPagePending {
            public var flags: Int32
            public var id: Int64
            public var url: String?
            public var date: Int32
            public init(flags: Int32, id: Int64, url: String?, date: Int32) {
                self.flags = flags
                self.id = id
                self.url = url
                self.date = date
            }
        }
        case webPage(Cons_webPage)
        case webPageEmpty(Cons_webPageEmpty)
        case webPageNotModified(Cons_webPageNotModified)
        case webPagePending(Cons_webPagePending)

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

        public static func parse_webPage(_ reader: BufferReader) -> WebPage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_webPageEmpty(_ reader: BufferReader) -> WebPage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_webPageNotModified(_ reader: BufferReader) -> WebPage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_webPagePending(_ reader: BufferReader) -> WebPage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
