public extension Api {
    enum ChatInviteImporter: TypeConstructorDescription {
        case chatInviteImporter(flags: Int32, userId: Int64, date: Int32, about: String?, approvedBy: Int64?)

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
        case chatOnlines(onlines: Int32)

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
        case chatParticipant(userId: Int64, inviterId: Int64, date: Int32)
        case chatParticipantAdmin(userId: Int64, inviterId: Int64, date: Int32)
        case chatParticipantCreator(userId: Int64)

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
        case chatParticipants(chatId: Int64, participants: [Api.ChatParticipant], version: Int32)
        case chatParticipantsForbidden(flags: Int32, chatId: Int64, selfParticipant: Api.ChatParticipant?)

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
        case chatPhoto(flags: Int32, photoId: Int64, strippedThumb: Buffer?, dcId: Int32)
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
        case chatReactionsAll(flags: Int32)
        case chatReactionsNone
        case chatReactionsSome(reactions: [Api.Reaction])

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
        case chatTheme(emoticon: String)
        case chatThemeUniqueGift(gift: Api.StarGift, themeSettings: [Api.ThemeSettings])

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
        case codeSettings(flags: Int32, logoutTokens: [Buffer]?, token: String?, appSandbox: Api.Bool?)

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
        case config(flags: Int32, date: Int32, expires: Int32, testMode: Api.Bool, thisDc: Int32, dcOptions: [Api.DcOption], dcTxtDomainName: String, chatSizeMax: Int32, megagroupSizeMax: Int32, forwardedCountMax: Int32, onlineUpdatePeriodMs: Int32, offlineBlurTimeoutMs: Int32, offlineIdleTimeoutMs: Int32, onlineCloudTimeoutMs: Int32, notifyCloudDelayMs: Int32, notifyDefaultDelayMs: Int32, pushChatPeriodMs: Int32, pushChatLimit: Int32, editTimeLimit: Int32, revokeTimeLimit: Int32, revokePmTimeLimit: Int32, ratingEDecay: Int32, stickersRecentLimit: Int32, channelsReadMediaPeriod: Int32, tmpSessions: Int32?, callReceiveTimeoutMs: Int32, callRingTimeoutMs: Int32, callConnectTimeoutMs: Int32, callPacketTimeoutMs: Int32, meUrlPrefix: String, autoupdateUrlPrefix: String?, gifSearchUsername: String?, venueSearchUsername: String?, imgSearchUsername: String?, staticMapsProvider: String?, captionLengthMax: Int32, messageLengthMax: Int32, webfileDcId: Int32, suggestedLangCode: String?, langPackVersion: Int32?, baseLangPackVersion: Int32?, reactionsDefault: Api.Reaction?, autologinToken: String?)

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
        case connectedBot(flags: Int32, botId: Int64, recipients: Api.BusinessBotRecipients, rights: Api.BusinessBotRights)

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
        case connectedBotStarRef(flags: Int32, url: String, date: Int32, botId: Int64, commissionPermille: Int32, durationMonths: Int32?, participants: Int64, revenue: Int64)

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
        case contact(userId: Int64, mutual: Api.Bool)

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
        case contactBirthday(contactId: Int64, birthday: Api.Birthday)

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
        case contactStatus(userId: Int64, status: Api.UserStatus)

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
        case dataJSON(data: String)

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
        case dcOption(flags: Int32, id: Int32, ipAddress: String, port: Int32, secret: Buffer?)

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
        case defaultHistoryTTL(period: Int32)

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
        case dialog(flags: Int32, peer: Api.Peer, topMessage: Int32, readInboxMaxId: Int32, readOutboxMaxId: Int32, unreadCount: Int32, unreadMentionsCount: Int32, unreadReactionsCount: Int32, notifySettings: Api.PeerNotifySettings, pts: Int32?, draft: Api.DraftMessage?, folderId: Int32?, ttlPeriod: Int32?)
        case dialogFolder(flags: Int32, folder: Api.Folder, peer: Api.Peer, topMessage: Int32, unreadMutedPeersCount: Int32, unreadUnmutedPeersCount: Int32, unreadMutedMessagesCount: Int32, unreadUnmutedMessagesCount: Int32)

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
        case dialogFilter(flags: Int32, id: Int32, title: Api.TextWithEntities, emoticon: String?, color: Int32?, pinnedPeers: [Api.InputPeer], includePeers: [Api.InputPeer], excludePeers: [Api.InputPeer])
        case dialogFilterChatlist(flags: Int32, id: Int32, title: Api.TextWithEntities, emoticon: String?, color: Int32?, pinnedPeers: [Api.InputPeer], includePeers: [Api.InputPeer])
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
        case dialogFilterSuggested(filter: Api.DialogFilter, description: String)

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
        case dialogPeer(peer: Api.Peer)
        case dialogPeerFolder(folderId: Int32)

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
