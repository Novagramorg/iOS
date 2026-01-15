public extension Api {
    enum ChannelAdminLogEventsFilter: TypeConstructorDescription {
        case channelAdminLogEventsFilter(flags: Int32)

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
        case channelLocation(geoPoint: Api.GeoPoint, address: String)
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
        case channelMessagesFilter(flags: Int32, ranges: [Api.MessageRange])
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
        case channelParticipant(flags: Int32, userId: Int64, date: Int32, subscriptionUntilDate: Int32?)
        case channelParticipantAdmin(flags: Int32, userId: Int64, inviterId: Int64?, promotedBy: Int64, date: Int32, adminRights: Api.ChatAdminRights, rank: String?)
        case channelParticipantBanned(flags: Int32, peer: Api.Peer, kickedBy: Int64, date: Int32, bannedRights: Api.ChatBannedRights)
        case channelParticipantCreator(flags: Int32, userId: Int64, adminRights: Api.ChatAdminRights, rank: String?)
        case channelParticipantLeft(peer: Api.Peer)
        case channelParticipantSelf(flags: Int32, userId: Int64, inviterId: Int64, date: Int32, subscriptionUntilDate: Int32?)

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
        case channelParticipantsAdmins
        case channelParticipantsBanned(q: String)
        case channelParticipantsBots
        case channelParticipantsContacts(q: String)
        case channelParticipantsKicked(q: String)
        case channelParticipantsMentions(flags: Int32, q: String?, topMsgId: Int32?)
        case channelParticipantsRecent
        case channelParticipantsSearch(q: String)

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
        case channel(flags: Int32, flags2: Int32, id: Int64, accessHash: Int64?, title: String, username: String?, photo: Api.ChatPhoto, date: Int32, restrictionReason: [Api.RestrictionReason]?, adminRights: Api.ChatAdminRights?, bannedRights: Api.ChatBannedRights?, defaultBannedRights: Api.ChatBannedRights?, participantsCount: Int32?, usernames: [Api.Username]?, storiesMaxId: Api.RecentStory?, color: Api.PeerColor?, profileColor: Api.PeerColor?, emojiStatus: Api.EmojiStatus?, level: Int32?, subscriptionUntilDate: Int32?, botVerificationIcon: Int64?, sendPaidMessagesStars: Int64?, linkedMonoforumId: Int64?)
        case channelForbidden(flags: Int32, id: Int64, accessHash: Int64, title: String, untilDate: Int32?)
        case chat(flags: Int32, id: Int64, title: String, photo: Api.ChatPhoto, participantsCount: Int32, date: Int32, version: Int32, migratedTo: Api.InputChannel?, adminRights: Api.ChatAdminRights?, defaultBannedRights: Api.ChatBannedRights?)
        case chatEmpty(id: Int64)
        case chatForbidden(id: Int64, title: String)

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
        case chatAdminRights(flags: Int32)

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
