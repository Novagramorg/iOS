public extension Api {
    enum ChannelAdminLogEventsFilter: TypeConstructorDescription {
        public class Cons_channelAdminLogEventsFilter {
            public var flags: Int32
            public init(flags: Int32) {
                self.flags = flags
            }
        }
        case channelAdminLogEventsFilter(Cons_channelAdminLogEventsFilter)

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

        public static func parse_channelAdminLogEventsFilter(_ reader: BufferReader) -> ChannelAdminLogEventsFilter? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum ChannelLocation: TypeConstructorDescription {
        public class Cons_channelLocation {
            public var geoPoint: Api.GeoPoint
            public var address: String
            public init(geoPoint: Api.GeoPoint, address: String) {
                self.geoPoint = geoPoint
                self.address = address
            }
        }
        case channelLocation(Cons_channelLocation)
        case channelLocationEmpty

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

        public static func parse_channelLocation(_ reader: BufferReader) -> ChannelLocation? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelLocationEmpty(_ reader: BufferReader) -> ChannelLocation? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum ChannelMessagesFilter: TypeConstructorDescription {
        public class Cons_channelMessagesFilter {
            public var flags: Int32
            public var ranges: [Api.MessageRange]
            public init(flags: Int32, ranges: [Api.MessageRange]) {
                self.flags = flags
                self.ranges = ranges
            }
        }
        case channelMessagesFilter(Cons_channelMessagesFilter)
        case channelMessagesFilterEmpty

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

        public static func parse_channelMessagesFilter(_ reader: BufferReader) -> ChannelMessagesFilter? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelMessagesFilterEmpty(_ reader: BufferReader) -> ChannelMessagesFilter? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum ChannelParticipant: TypeConstructorDescription {
        public class Cons_channelParticipant {
            public var flags: Int32
            public var userId: Int64
            public var date: Int32
            public var subscriptionUntilDate: Int32?
            public init(flags: Int32, userId: Int64, date: Int32, subscriptionUntilDate: Int32?) {
                self.flags = flags
                self.userId = userId
                self.date = date
                self.subscriptionUntilDate = subscriptionUntilDate
            }
        }
        public class Cons_channelParticipantAdmin {
            public var flags: Int32
            public var userId: Int64
            public var inviterId: Int64?
            public var promotedBy: Int64
            public var date: Int32
            public var adminRights: Api.ChatAdminRights
            public var rank: String?
            public init(flags: Int32, userId: Int64, inviterId: Int64?, promotedBy: Int64, date: Int32, adminRights: Api.ChatAdminRights, rank: String?) {
                self.flags = flags
                self.userId = userId
                self.inviterId = inviterId
                self.promotedBy = promotedBy
                self.date = date
                self.adminRights = adminRights
                self.rank = rank
            }
        }
        public class Cons_channelParticipantBanned {
            public var flags: Int32
            public var peer: Api.Peer
            public var kickedBy: Int64
            public var date: Int32
            public var bannedRights: Api.ChatBannedRights
            public init(flags: Int32, peer: Api.Peer, kickedBy: Int64, date: Int32, bannedRights: Api.ChatBannedRights) {
                self.flags = flags
                self.peer = peer
                self.kickedBy = kickedBy
                self.date = date
                self.bannedRights = bannedRights
            }
        }
        public class Cons_channelParticipantCreator {
            public var flags: Int32
            public var userId: Int64
            public var adminRights: Api.ChatAdminRights
            public var rank: String?
            public init(flags: Int32, userId: Int64, adminRights: Api.ChatAdminRights, rank: String?) {
                self.flags = flags
                self.userId = userId
                self.adminRights = adminRights
                self.rank = rank
            }
        }
        public class Cons_channelParticipantLeft {
            public var peer: Api.Peer
            public init(peer: Api.Peer) {
                self.peer = peer
            }
        }
        public class Cons_channelParticipantSelf {
            public var flags: Int32
            public var userId: Int64
            public var inviterId: Int64
            public var date: Int32
            public var subscriptionUntilDate: Int32?
            public init(flags: Int32, userId: Int64, inviterId: Int64, date: Int32, subscriptionUntilDate: Int32?) {
                self.flags = flags
                self.userId = userId
                self.inviterId = inviterId
                self.date = date
                self.subscriptionUntilDate = subscriptionUntilDate
            }
        }
        case channelParticipant(Cons_channelParticipant)
        case channelParticipantAdmin(Cons_channelParticipantAdmin)
        case channelParticipantBanned(Cons_channelParticipantBanned)
        case channelParticipantCreator(Cons_channelParticipantCreator)
        case channelParticipantLeft(Cons_channelParticipantLeft)
        case channelParticipantSelf(Cons_channelParticipantSelf)

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

        public static func parse_channelParticipant(_ reader: BufferReader) -> ChannelParticipant? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelParticipantAdmin(_ reader: BufferReader) -> ChannelParticipant? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelParticipantBanned(_ reader: BufferReader) -> ChannelParticipant? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelParticipantCreator(_ reader: BufferReader) -> ChannelParticipant? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelParticipantLeft(_ reader: BufferReader) -> ChannelParticipant? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelParticipantSelf(_ reader: BufferReader) -> ChannelParticipant? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum ChannelParticipantsFilter: TypeConstructorDescription {
        public class Cons_channelParticipantsBanned {
            public var q: String
            public init(q: String) {
                self.q = q
            }
        }
        public class Cons_channelParticipantsContacts {
            public var q: String
            public init(q: String) {
                self.q = q
            }
        }
        public class Cons_channelParticipantsKicked {
            public var q: String
            public init(q: String) {
                self.q = q
            }
        }
        public class Cons_channelParticipantsMentions {
            public var flags: Int32
            public var q: String?
            public var topMsgId: Int32?
            public init(flags: Int32, q: String?, topMsgId: Int32?) {
                self.flags = flags
                self.q = q
                self.topMsgId = topMsgId
            }
        }
        public class Cons_channelParticipantsSearch {
            public var q: String
            public init(q: String) {
                self.q = q
            }
        }
        case channelParticipantsAdmins
        case channelParticipantsBanned(Cons_channelParticipantsBanned)
        case channelParticipantsBots
        case channelParticipantsContacts(Cons_channelParticipantsContacts)
        case channelParticipantsKicked(Cons_channelParticipantsKicked)
        case channelParticipantsMentions(Cons_channelParticipantsMentions)
        case channelParticipantsRecent
        case channelParticipantsSearch(Cons_channelParticipantsSearch)

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

        public static func parse_channelParticipantsAdmins(_ reader: BufferReader) -> ChannelParticipantsFilter? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelParticipantsBanned(_ reader: BufferReader) -> ChannelParticipantsFilter? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelParticipantsBots(_ reader: BufferReader) -> ChannelParticipantsFilter? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelParticipantsContacts(_ reader: BufferReader) -> ChannelParticipantsFilter? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelParticipantsKicked(_ reader: BufferReader) -> ChannelParticipantsFilter? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelParticipantsMentions(_ reader: BufferReader) -> ChannelParticipantsFilter? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelParticipantsRecent(_ reader: BufferReader) -> ChannelParticipantsFilter? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelParticipantsSearch(_ reader: BufferReader) -> ChannelParticipantsFilter? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum Chat: TypeConstructorDescription {
        public class Cons_channel {
            public var flags: Int32
            public var flags2: Int32
            public var id: Int64
            public var accessHash: Int64?
            public var title: String
            public var username: String?
            public var photo: Api.ChatPhoto
            public var date: Int32
            public var restrictionReason: [Api.RestrictionReason]?
            public var adminRights: Api.ChatAdminRights?
            public var bannedRights: Api.ChatBannedRights?
            public var defaultBannedRights: Api.ChatBannedRights?
            public var participantsCount: Int32?
            public var usernames: [Api.Username]?
            public var storiesMaxId: Api.RecentStory?
            public var color: Api.PeerColor?
            public var profileColor: Api.PeerColor?
            public var emojiStatus: Api.EmojiStatus?
            public var level: Int32?
            public var subscriptionUntilDate: Int32?
            public var botVerificationIcon: Int64?
            public var sendPaidMessagesStars: Int64?
            public var linkedMonoforumId: Int64?
            public init(flags: Int32, flags2: Int32, id: Int64, accessHash: Int64?, title: String, username: String?, photo: Api.ChatPhoto, date: Int32, restrictionReason: [Api.RestrictionReason]?, adminRights: Api.ChatAdminRights?, bannedRights: Api.ChatBannedRights?, defaultBannedRights: Api.ChatBannedRights?, participantsCount: Int32?, usernames: [Api.Username]?, storiesMaxId: Api.RecentStory?, color: Api.PeerColor?, profileColor: Api.PeerColor?, emojiStatus: Api.EmojiStatus?, level: Int32?, subscriptionUntilDate: Int32?, botVerificationIcon: Int64?, sendPaidMessagesStars: Int64?, linkedMonoforumId: Int64?) {
                self.flags = flags
                self.flags2 = flags2
                self.id = id
                self.accessHash = accessHash
                self.title = title
                self.username = username
                self.photo = photo
                self.date = date
                self.restrictionReason = restrictionReason
                self.adminRights = adminRights
                self.bannedRights = bannedRights
                self.defaultBannedRights = defaultBannedRights
                self.participantsCount = participantsCount
                self.usernames = usernames
                self.storiesMaxId = storiesMaxId
                self.color = color
                self.profileColor = profileColor
                self.emojiStatus = emojiStatus
                self.level = level
                self.subscriptionUntilDate = subscriptionUntilDate
                self.botVerificationIcon = botVerificationIcon
                self.sendPaidMessagesStars = sendPaidMessagesStars
                self.linkedMonoforumId = linkedMonoforumId
            }
        }
        public class Cons_channelForbidden {
            public var flags: Int32
            public var id: Int64
            public var accessHash: Int64
            public var title: String
            public var untilDate: Int32?
            public init(flags: Int32, id: Int64, accessHash: Int64, title: String, untilDate: Int32?) {
                self.flags = flags
                self.id = id
                self.accessHash = accessHash
                self.title = title
                self.untilDate = untilDate
            }
        }
        public class Cons_chat {
            public var flags: Int32
            public var id: Int64
            public var title: String
            public var photo: Api.ChatPhoto
            public var participantsCount: Int32
            public var date: Int32
            public var version: Int32
            public var migratedTo: Api.InputChannel?
            public var adminRights: Api.ChatAdminRights?
            public var defaultBannedRights: Api.ChatBannedRights?
            public init(flags: Int32, id: Int64, title: String, photo: Api.ChatPhoto, participantsCount: Int32, date: Int32, version: Int32, migratedTo: Api.InputChannel?, adminRights: Api.ChatAdminRights?, defaultBannedRights: Api.ChatBannedRights?) {
                self.flags = flags
                self.id = id
                self.title = title
                self.photo = photo
                self.participantsCount = participantsCount
                self.date = date
                self.version = version
                self.migratedTo = migratedTo
                self.adminRights = adminRights
                self.defaultBannedRights = defaultBannedRights
            }
        }
        public class Cons_chatEmpty {
            public var id: Int64
            public init(id: Int64) {
                self.id = id
            }
        }
        public class Cons_chatForbidden {
            public var id: Int64
            public var title: String
            public init(id: Int64, title: String) {
                self.id = id
                self.title = title
            }
        }
        case channel(Cons_channel)
        case channelForbidden(Cons_channelForbidden)
        case chat(Cons_chat)
        case chatEmpty(Cons_chatEmpty)
        case chatForbidden(Cons_chatForbidden)

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

        public static func parse_channel(_ reader: BufferReader) -> Chat? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelForbidden(_ reader: BufferReader) -> Chat? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_chat(_ reader: BufferReader) -> Chat? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_chatEmpty(_ reader: BufferReader) -> Chat? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_chatForbidden(_ reader: BufferReader) -> Chat? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum ChatAdminRights: TypeConstructorDescription {
        public class Cons_chatAdminRights {
            public var flags: Int32
            public init(flags: Int32) {
                self.flags = flags
            }
        }
        case chatAdminRights(Cons_chatAdminRights)

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

        public static func parse_chatAdminRights(_ reader: BufferReader) -> ChatAdminRights? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum ChatAdminWithInvites: TypeConstructorDescription {
        case chatAdminWithInvites(adminId: Int64, invitesCount: Int32, revokedInvitesCount: Int32)

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

        public static func parse_chatAdminWithInvites(_ reader: BufferReader) -> ChatAdminWithInvites? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum ChatBannedRights: TypeConstructorDescription {
        case chatBannedRights(flags: Int32, untilDate: Int32)

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

        public static func parse_chatBannedRights(_ reader: BufferReader) -> ChatBannedRights? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum ChatFull: TypeConstructorDescription {
        case channelFull(flags: Int32, flags2: Int32, id: Int64, about: String, participantsCount: Int32?, adminsCount: Int32?, kickedCount: Int32?, bannedCount: Int32?, onlineCount: Int32?, readInboxMaxId: Int32, readOutboxMaxId: Int32, unreadCount: Int32, chatPhoto: Api.Photo, notifySettings: Api.PeerNotifySettings, exportedInvite: Api.ExportedChatInvite?, botInfo: [Api.BotInfo], migratedFromChatId: Int64?, migratedFromMaxId: Int32?, pinnedMsgId: Int32?, stickerset: Api.StickerSet?, availableMinId: Int32?, folderId: Int32?, linkedChatId: Int64?, location: Api.ChannelLocation?, slowmodeSeconds: Int32?, slowmodeNextSendDate: Int32?, statsDc: Int32?, pts: Int32, call: Api.InputGroupCall?, ttlPeriod: Int32?, pendingSuggestions: [String]?, groupcallDefaultJoinAs: Api.Peer?, themeEmoticon: String?, requestsPending: Int32?, recentRequesters: [Int64]?, defaultSendAs: Api.Peer?, availableReactions: Api.ChatReactions?, reactionsLimit: Int32?, stories: Api.PeerStories?, wallpaper: Api.WallPaper?, boostsApplied: Int32?, boostsUnrestrict: Int32?, emojiset: Api.StickerSet?, botVerification: Api.BotVerification?, stargiftsCount: Int32?, sendPaidMessagesStars: Int64?, mainTab: Api.ProfileTab?)
        case chatFull(flags: Int32, id: Int64, about: String, participants: Api.ChatParticipants, chatPhoto: Api.Photo?, notifySettings: Api.PeerNotifySettings, exportedInvite: Api.ExportedChatInvite?, botInfo: [Api.BotInfo]?, pinnedMsgId: Int32?, folderId: Int32?, call: Api.InputGroupCall?, ttlPeriod: Int32?, groupcallDefaultJoinAs: Api.Peer?, themeEmoticon: String?, requestsPending: Int32?, recentRequesters: [Int64]?, availableReactions: Api.ChatReactions?, reactionsLimit: Int32?)

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

        public static func parse_channelFull(_ reader: BufferReader) -> ChatFull? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_chatFull(_ reader: BufferReader) -> ChatFull? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum ChatInvite: TypeConstructorDescription {
        case chatInvite(flags: Int32, title: String, about: String?, photo: Api.Photo, participantsCount: Int32, participants: [Api.User]?, color: Int32, subscriptionPricing: Api.StarsSubscriptionPricing?, subscriptionFormId: Int64?, botVerification: Api.BotVerification?)
        case chatInviteAlready(chat: Api.Chat)
        case chatInvitePeek(chat: Api.Chat, expires: Int32)

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

        public static func parse_chatInvite(_ reader: BufferReader) -> ChatInvite? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_chatInviteAlready(_ reader: BufferReader) -> ChatInvite? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_chatInvitePeek(_ reader: BufferReader) -> ChatInvite? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
