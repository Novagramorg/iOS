public extension Api {
    enum ChatInviteImporter: TypeConstructorDescription {
        public class Cons_chatInviteImporter {
            public var flags: Int32
            public var userId: Int64
            public var date: Int32
            public var about: String?
            public var approvedBy: Int64?
            public init(flags: Int32, userId: Int64, date: Int32, about: String?, approvedBy: Int64?) {
                self.flags = flags
                self.userId = userId
                self.date = date
                self.about = about
                self.approvedBy = approvedBy
            }
        }
        case chatInviteImporter(Cons_chatInviteImporter)

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

        public static func parse_chatInviteImporter(_ reader: BufferReader) -> ChatInviteImporter? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum ChatOnlines: TypeConstructorDescription {
        public class Cons_chatOnlines {
            public var onlines: Int32
            public init(onlines: Int32) {
                self.onlines = onlines
            }
        }
        case chatOnlines(Cons_chatOnlines)

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

        public static func parse_chatOnlines(_ reader: BufferReader) -> ChatOnlines? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum ChatParticipant: TypeConstructorDescription {
        public class Cons_chatParticipant {
            public var userId: Int64
            public var inviterId: Int64
            public var date: Int32
            public init(userId: Int64, inviterId: Int64, date: Int32) {
                self.userId = userId
                self.inviterId = inviterId
                self.date = date
            }
        }
        public class Cons_chatParticipantAdmin {
            public var userId: Int64
            public var inviterId: Int64
            public var date: Int32
            public init(userId: Int64, inviterId: Int64, date: Int32) {
                self.userId = userId
                self.inviterId = inviterId
                self.date = date
            }
        }
        public class Cons_chatParticipantCreator {
            public var userId: Int64
            public init(userId: Int64) {
                self.userId = userId
            }
        }
        case chatParticipant(Cons_chatParticipant)
        case chatParticipantAdmin(Cons_chatParticipantAdmin)
        case chatParticipantCreator(Cons_chatParticipantCreator)

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

        public static func parse_chatParticipant(_ reader: BufferReader) -> ChatParticipant? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_chatParticipantAdmin(_ reader: BufferReader) -> ChatParticipant? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_chatParticipantCreator(_ reader: BufferReader) -> ChatParticipant? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum ChatParticipants: TypeConstructorDescription {
        public class Cons_chatParticipants {
            public var chatId: Int64
            public var participants: [Api.ChatParticipant]
            public var version: Int32
            public init(chatId: Int64, participants: [Api.ChatParticipant], version: Int32) {
                self.chatId = chatId
                self.participants = participants
                self.version = version
            }
        }
        public class Cons_chatParticipantsForbidden {
            public var flags: Int32
            public var chatId: Int64
            public var selfParticipant: Api.ChatParticipant?
            public init(flags: Int32, chatId: Int64, selfParticipant: Api.ChatParticipant?) {
                self.flags = flags
                self.chatId = chatId
                self.selfParticipant = selfParticipant
            }
        }
        case chatParticipants(Cons_chatParticipants)
        case chatParticipantsForbidden(Cons_chatParticipantsForbidden)

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

        public static func parse_chatParticipants(_ reader: BufferReader) -> ChatParticipants? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_chatParticipantsForbidden(_ reader: BufferReader) -> ChatParticipants? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum ChatPhoto: TypeConstructorDescription {
        public class Cons_chatPhoto {
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
        case chatPhoto(Cons_chatPhoto)
        case chatPhotoEmpty

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

        public static func parse_chatPhoto(_ reader: BufferReader) -> ChatPhoto? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_chatPhotoEmpty(_ reader: BufferReader) -> ChatPhoto? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum ChatReactions: TypeConstructorDescription {
        public class Cons_chatReactionsAll {
            public var flags: Int32
            public init(flags: Int32) {
                self.flags = flags
            }
        }
        public class Cons_chatReactionsSome {
            public var reactions: [Api.Reaction]
            public init(reactions: [Api.Reaction]) {
                self.reactions = reactions
            }
        }
        case chatReactionsAll(Cons_chatReactionsAll)
        case chatReactionsNone
        case chatReactionsSome(Cons_chatReactionsSome)

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

        public static func parse_chatReactionsAll(_ reader: BufferReader) -> ChatReactions? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_chatReactionsNone(_ reader: BufferReader) -> ChatReactions? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_chatReactionsSome(_ reader: BufferReader) -> ChatReactions? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum ChatTheme: TypeConstructorDescription {
        public class Cons_chatTheme {
            public var emoticon: String
            public init(emoticon: String) {
                self.emoticon = emoticon
            }
        }
        public class Cons_chatThemeUniqueGift {
            public var gift: Api.StarGift
            public var themeSettings: [Api.ThemeSettings]
            public init(gift: Api.StarGift, themeSettings: [Api.ThemeSettings]) {
                self.gift = gift
                self.themeSettings = themeSettings
            }
        }
        case chatTheme(Cons_chatTheme)
        case chatThemeUniqueGift(Cons_chatThemeUniqueGift)

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

        public static func parse_chatTheme(_ reader: BufferReader) -> ChatTheme? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_chatThemeUniqueGift(_ reader: BufferReader) -> ChatTheme? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum CodeSettings: TypeConstructorDescription {
        public class Cons_codeSettings {
            public var flags: Int32
            public var logoutTokens: [Buffer]?
            public var token: String?
            public var appSandbox: Api.Bool?
            public init(flags: Int32, logoutTokens: [Buffer]?, token: String?, appSandbox: Api.Bool?) {
                self.flags = flags
                self.logoutTokens = logoutTokens
                self.token = token
                self.appSandbox = appSandbox
            }
        }
        case codeSettings(Cons_codeSettings)

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

        public static func parse_codeSettings(_ reader: BufferReader) -> CodeSettings? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum Config: TypeConstructorDescription {
        public class Cons_config {
            public var flags: Int32
            public var date: Int32
            public var expires: Int32
            public var testMode: Api.Bool
            public var thisDc: Int32
            public var dcOptions: [Api.DcOption]
            public var dcTxtDomainName: String
            public var chatSizeMax: Int32
            public var megagroupSizeMax: Int32
            public var forwardedCountMax: Int32
            public var onlineUpdatePeriodMs: Int32
            public var offlineBlurTimeoutMs: Int32
            public var offlineIdleTimeoutMs: Int32
            public var onlineCloudTimeoutMs: Int32
            public var notifyCloudDelayMs: Int32
            public var notifyDefaultDelayMs: Int32
            public var pushChatPeriodMs: Int32
            public var pushChatLimit: Int32
            public var editTimeLimit: Int32
            public var revokeTimeLimit: Int32
            public var revokePmTimeLimit: Int32
            public var ratingEDecay: Int32
            public var stickersRecentLimit: Int32
            public var channelsReadMediaPeriod: Int32
            public var tmpSessions: Int32?
            public var callReceiveTimeoutMs: Int32
            public var callRingTimeoutMs: Int32
            public var callConnectTimeoutMs: Int32
            public var callPacketTimeoutMs: Int32
            public var meUrlPrefix: String
            public var autoupdateUrlPrefix: String?
            public var gifSearchUsername: String?
            public var venueSearchUsername: String?
            public var imgSearchUsername: String?
            public var staticMapsProvider: String?
            public var captionLengthMax: Int32
            public var messageLengthMax: Int32
            public var webfileDcId: Int32
            public var suggestedLangCode: String?
            public var langPackVersion: Int32?
            public var baseLangPackVersion: Int32?
            public var reactionsDefault: Api.Reaction?
            public var autologinToken: String?
            public init(flags: Int32, date: Int32, expires: Int32, testMode: Api.Bool, thisDc: Int32, dcOptions: [Api.DcOption], dcTxtDomainName: String, chatSizeMax: Int32, megagroupSizeMax: Int32, forwardedCountMax: Int32, onlineUpdatePeriodMs: Int32, offlineBlurTimeoutMs: Int32, offlineIdleTimeoutMs: Int32, onlineCloudTimeoutMs: Int32, notifyCloudDelayMs: Int32, notifyDefaultDelayMs: Int32, pushChatPeriodMs: Int32, pushChatLimit: Int32, editTimeLimit: Int32, revokeTimeLimit: Int32, revokePmTimeLimit: Int32, ratingEDecay: Int32, stickersRecentLimit: Int32, channelsReadMediaPeriod: Int32, tmpSessions: Int32?, callReceiveTimeoutMs: Int32, callRingTimeoutMs: Int32, callConnectTimeoutMs: Int32, callPacketTimeoutMs: Int32, meUrlPrefix: String, autoupdateUrlPrefix: String?, gifSearchUsername: String?, venueSearchUsername: String?, imgSearchUsername: String?, staticMapsProvider: String?, captionLengthMax: Int32, messageLengthMax: Int32, webfileDcId: Int32, suggestedLangCode: String?, langPackVersion: Int32?, baseLangPackVersion: Int32?, reactionsDefault: Api.Reaction?, autologinToken: String?) {
                self.flags = flags
                self.date = date
                self.expires = expires
                self.testMode = testMode
                self.thisDc = thisDc
                self.dcOptions = dcOptions
                self.dcTxtDomainName = dcTxtDomainName
                self.chatSizeMax = chatSizeMax
                self.megagroupSizeMax = megagroupSizeMax
                self.forwardedCountMax = forwardedCountMax
                self.onlineUpdatePeriodMs = onlineUpdatePeriodMs
                self.offlineBlurTimeoutMs = offlineBlurTimeoutMs
                self.offlineIdleTimeoutMs = offlineIdleTimeoutMs
                self.onlineCloudTimeoutMs = onlineCloudTimeoutMs
                self.notifyCloudDelayMs = notifyCloudDelayMs
                self.notifyDefaultDelayMs = notifyDefaultDelayMs
                self.pushChatPeriodMs = pushChatPeriodMs
                self.pushChatLimit = pushChatLimit
                self.editTimeLimit = editTimeLimit
                self.revokeTimeLimit = revokeTimeLimit
                self.revokePmTimeLimit = revokePmTimeLimit
                self.ratingEDecay = ratingEDecay
                self.stickersRecentLimit = stickersRecentLimit
                self.channelsReadMediaPeriod = channelsReadMediaPeriod
                self.tmpSessions = tmpSessions
                self.callReceiveTimeoutMs = callReceiveTimeoutMs
                self.callRingTimeoutMs = callRingTimeoutMs
                self.callConnectTimeoutMs = callConnectTimeoutMs
                self.callPacketTimeoutMs = callPacketTimeoutMs
                self.meUrlPrefix = meUrlPrefix
                self.autoupdateUrlPrefix = autoupdateUrlPrefix
                self.gifSearchUsername = gifSearchUsername
                self.venueSearchUsername = venueSearchUsername
                self.imgSearchUsername = imgSearchUsername
                self.staticMapsProvider = staticMapsProvider
                self.captionLengthMax = captionLengthMax
                self.messageLengthMax = messageLengthMax
                self.webfileDcId = webfileDcId
                self.suggestedLangCode = suggestedLangCode
                self.langPackVersion = langPackVersion
                self.baseLangPackVersion = baseLangPackVersion
                self.reactionsDefault = reactionsDefault
                self.autologinToken = autologinToken
            }
        }
        case config(Cons_config)

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

        public static func parse_config(_ reader: BufferReader) -> Config? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum ConnectedBot: TypeConstructorDescription {
        public class Cons_connectedBot {
            public var flags: Int32
            public var botId: Int64
            public var recipients: Api.BusinessBotRecipients
            public var rights: Api.BusinessBotRights
            public init(flags: Int32, botId: Int64, recipients: Api.BusinessBotRecipients, rights: Api.BusinessBotRights) {
                self.flags = flags
                self.botId = botId
                self.recipients = recipients
                self.rights = rights
            }
        }
        case connectedBot(Cons_connectedBot)

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

        public static func parse_connectedBot(_ reader: BufferReader) -> ConnectedBot? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum ConnectedBotStarRef: TypeConstructorDescription {
        public class Cons_connectedBotStarRef {
            public var flags: Int32
            public var url: String
            public var date: Int32
            public var botId: Int64
            public var commissionPermille: Int32
            public var durationMonths: Int32?
            public var participants: Int64
            public var revenue: Int64
            public init(flags: Int32, url: String, date: Int32, botId: Int64, commissionPermille: Int32, durationMonths: Int32?, participants: Int64, revenue: Int64) {
                self.flags = flags
                self.url = url
                self.date = date
                self.botId = botId
                self.commissionPermille = commissionPermille
                self.durationMonths = durationMonths
                self.participants = participants
                self.revenue = revenue
            }
        }
        case connectedBotStarRef(Cons_connectedBotStarRef)

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

        public static func parse_connectedBotStarRef(_ reader: BufferReader) -> ConnectedBotStarRef? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum Contact: TypeConstructorDescription {
        public class Cons_contact {
            public var userId: Int64
            public var mutual: Api.Bool
            public init(userId: Int64, mutual: Api.Bool) {
                self.userId = userId
                self.mutual = mutual
            }
        }
        case contact(Cons_contact)

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

        public static func parse_contact(_ reader: BufferReader) -> Contact? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum ContactBirthday: TypeConstructorDescription {
        public class Cons_contactBirthday {
            public var contactId: Int64
            public var birthday: Api.Birthday
            public init(contactId: Int64, birthday: Api.Birthday) {
                self.contactId = contactId
                self.birthday = birthday
            }
        }
        case contactBirthday(Cons_contactBirthday)

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

        public static func parse_contactBirthday(_ reader: BufferReader) -> ContactBirthday? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum ContactStatus: TypeConstructorDescription {
        public class Cons_contactStatus {
            public var userId: Int64
            public var status: Api.UserStatus
            public init(userId: Int64, status: Api.UserStatus) {
                self.userId = userId
                self.status = status
            }
        }
        case contactStatus(Cons_contactStatus)

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

        public static func parse_contactStatus(_ reader: BufferReader) -> ContactStatus? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum DataJSON: TypeConstructorDescription {
        public class Cons_dataJSON {
            public var data: String
            public init(data: String) {
                self.data = data
            }
        }
        case dataJSON(Cons_dataJSON)

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

        public static func parse_dataJSON(_ reader: BufferReader) -> DataJSON? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum DcOption: TypeConstructorDescription {
        public class Cons_dcOption {
            public var flags: Int32
            public var id: Int32
            public var ipAddress: String
            public var port: Int32
            public var secret: Buffer?
            public init(flags: Int32, id: Int32, ipAddress: String, port: Int32, secret: Buffer?) {
                self.flags = flags
                self.id = id
                self.ipAddress = ipAddress
                self.port = port
                self.secret = secret
            }
        }
        case dcOption(Cons_dcOption)

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

        public static func parse_dcOption(_ reader: BufferReader) -> DcOption? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum DefaultHistoryTTL: TypeConstructorDescription {
        public class Cons_defaultHistoryTTL {
            public var period: Int32
            public init(period: Int32) {
                self.period = period
            }
        }
        case defaultHistoryTTL(Cons_defaultHistoryTTL)

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

        public static func parse_defaultHistoryTTL(_ reader: BufferReader) -> DefaultHistoryTTL? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum Dialog: TypeConstructorDescription {
        public class Cons_dialog {
            public var flags: Int32
            public var peer: Api.Peer
            public var topMessage: Int32
            public var readInboxMaxId: Int32
            public var readOutboxMaxId: Int32
            public var unreadCount: Int32
            public var unreadMentionsCount: Int32
            public var unreadReactionsCount: Int32
            public var notifySettings: Api.PeerNotifySettings
            public var pts: Int32?
            public var draft: Api.DraftMessage?
            public var folderId: Int32?
            public var ttlPeriod: Int32?
            public init(flags: Int32, peer: Api.Peer, topMessage: Int32, readInboxMaxId: Int32, readOutboxMaxId: Int32, unreadCount: Int32, unreadMentionsCount: Int32, unreadReactionsCount: Int32, notifySettings: Api.PeerNotifySettings, pts: Int32?, draft: Api.DraftMessage?, folderId: Int32?, ttlPeriod: Int32?) {
                self.flags = flags
                self.peer = peer
                self.topMessage = topMessage
                self.readInboxMaxId = readInboxMaxId
                self.readOutboxMaxId = readOutboxMaxId
                self.unreadCount = unreadCount
                self.unreadMentionsCount = unreadMentionsCount
                self.unreadReactionsCount = unreadReactionsCount
                self.notifySettings = notifySettings
                self.pts = pts
                self.draft = draft
                self.folderId = folderId
                self.ttlPeriod = ttlPeriod
            }
        }
        public class Cons_dialogFolder {
            public var flags: Int32
            public var folder: Api.Folder
            public var peer: Api.Peer
            public var topMessage: Int32
            public var unreadMutedPeersCount: Int32
            public var unreadUnmutedPeersCount: Int32
            public var unreadMutedMessagesCount: Int32
            public var unreadUnmutedMessagesCount: Int32
            public init(flags: Int32, folder: Api.Folder, peer: Api.Peer, topMessage: Int32, unreadMutedPeersCount: Int32, unreadUnmutedPeersCount: Int32, unreadMutedMessagesCount: Int32, unreadUnmutedMessagesCount: Int32) {
                self.flags = flags
                self.folder = folder
                self.peer = peer
                self.topMessage = topMessage
                self.unreadMutedPeersCount = unreadMutedPeersCount
                self.unreadUnmutedPeersCount = unreadUnmutedPeersCount
                self.unreadMutedMessagesCount = unreadMutedMessagesCount
                self.unreadUnmutedMessagesCount = unreadUnmutedMessagesCount
            }
        }
        case dialog(Cons_dialog)
        case dialogFolder(Cons_dialogFolder)

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

        public static func parse_dialog(_ reader: BufferReader) -> Dialog? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_dialogFolder(_ reader: BufferReader) -> Dialog? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum DialogFilter: TypeConstructorDescription {
        public class Cons_dialogFilter {
            public var flags: Int32
            public var id: Int32
            public var title: Api.TextWithEntities
            public var emoticon: String?
            public var color: Int32?
            public var pinnedPeers: [Api.InputPeer]
            public var includePeers: [Api.InputPeer]
            public var excludePeers: [Api.InputPeer]
            public init(flags: Int32, id: Int32, title: Api.TextWithEntities, emoticon: String?, color: Int32?, pinnedPeers: [Api.InputPeer], includePeers: [Api.InputPeer], excludePeers: [Api.InputPeer]) {
                self.flags = flags
                self.id = id
                self.title = title
                self.emoticon = emoticon
                self.color = color
                self.pinnedPeers = pinnedPeers
                self.includePeers = includePeers
                self.excludePeers = excludePeers
            }
        }
        public class Cons_dialogFilterChatlist {
            public var flags: Int32
            public var id: Int32
            public var title: Api.TextWithEntities
            public var emoticon: String?
            public var color: Int32?
            public var pinnedPeers: [Api.InputPeer]
            public var includePeers: [Api.InputPeer]
            public init(flags: Int32, id: Int32, title: Api.TextWithEntities, emoticon: String?, color: Int32?, pinnedPeers: [Api.InputPeer], includePeers: [Api.InputPeer]) {
                self.flags = flags
                self.id = id
                self.title = title
                self.emoticon = emoticon
                self.color = color
                self.pinnedPeers = pinnedPeers
                self.includePeers = includePeers
            }
        }
        case dialogFilter(Cons_dialogFilter)
        case dialogFilterChatlist(Cons_dialogFilterChatlist)
        case dialogFilterDefault

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

        public static func parse_dialogFilter(_ reader: BufferReader) -> DialogFilter? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_dialogFilterChatlist(_ reader: BufferReader) -> DialogFilter? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_dialogFilterDefault(_ reader: BufferReader) -> DialogFilter? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum DialogFilterSuggested: TypeConstructorDescription {
        public class Cons_dialogFilterSuggested {
            public var filter: Api.DialogFilter
            public var description: String
            public init(filter: Api.DialogFilter, description: String) {
                self.filter = filter
                self.description = description
            }
        }
        case dialogFilterSuggested(Cons_dialogFilterSuggested)

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

        public static func parse_dialogFilterSuggested(_ reader: BufferReader) -> DialogFilterSuggested? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum DialogPeer: TypeConstructorDescription {
        public class Cons_dialogPeer {
            public var peer: Api.Peer
            public init(peer: Api.Peer) {
                self.peer = peer
            }
        }
        public class Cons_dialogPeerFolder {
            public var folderId: Int32
            public init(folderId: Int32) {
                self.folderId = folderId
            }
        }
        case dialogPeer(Cons_dialogPeer)
        case dialogPeerFolder(Cons_dialogPeerFolder)

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

        public static func parse_dialogPeer(_ reader: BufferReader) -> DialogPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_dialogPeerFolder(_ reader: BufferReader) -> DialogPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
