public extension Api {
    enum EmojiURL: TypeConstructorDescription {
        case emojiURL(url: String)

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

        public static func parse_emojiURL(_ reader: BufferReader) -> EmojiURL? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum EncryptedChat: TypeConstructorDescription {
        case encryptedChat(id: Int32, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64, gAOrB: Buffer, keyFingerprint: Int64)
        case encryptedChatDiscarded(flags: Int32, id: Int32)
        case encryptedChatEmpty(id: Int32)
        case encryptedChatRequested(flags: Int32, folderId: Int32?, id: Int32, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64, gA: Buffer)
        case encryptedChatWaiting(id: Int32, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64)

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

        public static func parse_encryptedChat(_ reader: BufferReader) -> EncryptedChat? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_encryptedChatDiscarded(_ reader: BufferReader) -> EncryptedChat? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_encryptedChatEmpty(_ reader: BufferReader) -> EncryptedChat? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_encryptedChatRequested(_ reader: BufferReader) -> EncryptedChat? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_encryptedChatWaiting(_ reader: BufferReader) -> EncryptedChat? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum EncryptedFile: TypeConstructorDescription {
        case encryptedFile(id: Int64, accessHash: Int64, size: Int64, dcId: Int32, keyFingerprint: Int32)
        case encryptedFileEmpty

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

        public static func parse_encryptedFile(_ reader: BufferReader) -> EncryptedFile? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_encryptedFileEmpty(_ reader: BufferReader) -> EncryptedFile? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum EncryptedMessage: TypeConstructorDescription {
        case encryptedMessage(randomId: Int64, chatId: Int32, date: Int32, bytes: Buffer, file: Api.EncryptedFile)
        case encryptedMessageService(randomId: Int64, chatId: Int32, date: Int32, bytes: Buffer)

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

        public static func parse_encryptedMessage(_ reader: BufferReader) -> EncryptedMessage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_encryptedMessageService(_ reader: BufferReader) -> EncryptedMessage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum ExportedChatInvite: TypeConstructorDescription {
        case chatInviteExported(flags: Int32, link: String, adminId: Int64, date: Int32, startDate: Int32?, expireDate: Int32?, usageLimit: Int32?, usage: Int32?, requested: Int32?, subscriptionExpired: Int32?, title: String?, subscriptionPricing: Api.StarsSubscriptionPricing?)
        case chatInvitePublicJoinRequests

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

        public static func parse_chatInviteExported(_ reader: BufferReader) -> ExportedChatInvite? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_chatInvitePublicJoinRequests(_ reader: BufferReader) -> ExportedChatInvite? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum ExportedChatlistInvite: TypeConstructorDescription {
        case exportedChatlistInvite(flags: Int32, title: String, url: String, peers: [Api.Peer])

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

        public static func parse_exportedChatlistInvite(_ reader: BufferReader) -> ExportedChatlistInvite? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum ExportedContactToken: TypeConstructorDescription {
        case exportedContactToken(url: String, expires: Int32)

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

        public static func parse_exportedContactToken(_ reader: BufferReader) -> ExportedContactToken? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum ExportedMessageLink: TypeConstructorDescription {
        case exportedMessageLink(link: String, html: String)

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

        public static func parse_exportedMessageLink(_ reader: BufferReader) -> ExportedMessageLink? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum ExportedStoryLink: TypeConstructorDescription {
        case exportedStoryLink(link: String)

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

        public static func parse_exportedStoryLink(_ reader: BufferReader) -> ExportedStoryLink? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum FactCheck: TypeConstructorDescription {
        case factCheck(flags: Int32, country: String?, text: Api.TextWithEntities?, hash: Int64)

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

        public static func parse_factCheck(_ reader: BufferReader) -> FactCheck? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum FileHash: TypeConstructorDescription {
        case fileHash(offset: Int64, limit: Int32, hash: Buffer)

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

        public static func parse_fileHash(_ reader: BufferReader) -> FileHash? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum Folder: TypeConstructorDescription {
        case folder(flags: Int32, id: Int32, title: String, photo: Api.ChatPhoto?)

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

        public static func parse_folder(_ reader: BufferReader) -> Folder? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum FolderPeer: TypeConstructorDescription {
        case folderPeer(peer: Api.Peer, folderId: Int32)

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

        public static func parse_folderPeer(_ reader: BufferReader) -> FolderPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum ForumTopic: TypeConstructorDescription {
        case forumTopic(flags: Int32, id: Int32, date: Int32, peer: Api.Peer, title: String, iconColor: Int32, iconEmojiId: Int64?, topMessage: Int32, readInboxMaxId: Int32, readOutboxMaxId: Int32, unreadCount: Int32, unreadMentionsCount: Int32, unreadReactionsCount: Int32, fromId: Api.Peer, notifySettings: Api.PeerNotifySettings, draft: Api.DraftMessage?)
        case forumTopicDeleted(id: Int32)

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

        public static func parse_forumTopic(_ reader: BufferReader) -> ForumTopic? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_forumTopicDeleted(_ reader: BufferReader) -> ForumTopic? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum FoundStory: TypeConstructorDescription {
        case foundStory(peer: Api.Peer, story: Api.StoryItem)

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

        public static func parse_foundStory(_ reader: BufferReader) -> FoundStory? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum Game: TypeConstructorDescription {
        case game(flags: Int32, id: Int64, accessHash: Int64, shortName: String, title: String, description: String, photo: Api.Photo, document: Api.Document?)

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

        public static func parse_game(_ reader: BufferReader) -> Game? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum GeoPoint: TypeConstructorDescription {
        case geoPoint(flags: Int32, long: Double, lat: Double, accessHash: Int64, accuracyRadius: Int32?)
        case geoPointEmpty

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

        public static func parse_geoPoint(_ reader: BufferReader) -> GeoPoint? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_geoPointEmpty(_ reader: BufferReader) -> GeoPoint? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum GeoPointAddress: TypeConstructorDescription {
        case geoPointAddress(flags: Int32, countryIso2: String, state: String?, city: String?, street: String?)

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

        public static func parse_geoPointAddress(_ reader: BufferReader) -> GeoPointAddress? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum GlobalPrivacySettings: TypeConstructorDescription {
        case globalPrivacySettings(flags: Int32, noncontactPeersPaidStars: Int64?, disallowedGifts: Api.DisallowedGiftsSettings?)

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

        public static func parse_globalPrivacySettings(_ reader: BufferReader) -> GlobalPrivacySettings? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum GroupCall: TypeConstructorDescription {
        case groupCall(flags: Int32, id: Int64, accessHash: Int64, participantsCount: Int32, title: String?, streamDcId: Int32?, recordStartDate: Int32?, scheduleDate: Int32?, unmutedVideoCount: Int32?, unmutedVideoLimit: Int32, version: Int32, inviteLink: String?, sendPaidMessagesStars: Int64?, defaultSendAs: Api.Peer?)
        case groupCallDiscarded(id: Int64, accessHash: Int64, duration: Int32)

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

        public static func parse_groupCall(_ reader: BufferReader) -> GroupCall? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_groupCallDiscarded(_ reader: BufferReader) -> GroupCall? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum GroupCallDonor: TypeConstructorDescription {
        case groupCallDonor(flags: Int32, peerId: Api.Peer?, stars: Int64)

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

        public static func parse_groupCallDonor(_ reader: BufferReader) -> GroupCallDonor? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum GroupCallMessage: TypeConstructorDescription {
        case groupCallMessage(flags: Int32, id: Int32, fromId: Api.Peer, date: Int32, message: Api.TextWithEntities, paidMessageStars: Int64?)

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

        public static func parse_groupCallMessage(_ reader: BufferReader) -> GroupCallMessage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
