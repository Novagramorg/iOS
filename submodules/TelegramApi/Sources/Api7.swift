public extension Api {
    enum EmojiURL: TypeConstructorDescription {
        public class Cons_emojiURL {
            public var url: String
            public init(url: String) {
                self.url = url
            }
        }
        case emojiURL(Cons_emojiURL)

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
        public class Cons_encryptedChat {
            public var id: Int32
            public var accessHash: Int64
            public var date: Int32
            public var adminId: Int64
            public var participantId: Int64
            public var gAOrB: Buffer
            public var keyFingerprint: Int64
            public init(id: Int32, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64, gAOrB: Buffer, keyFingerprint: Int64) {
                self.id = id
                self.accessHash = accessHash
                self.date = date
                self.adminId = adminId
                self.participantId = participantId
                self.gAOrB = gAOrB
                self.keyFingerprint = keyFingerprint
            }
        }
        public class Cons_encryptedChatDiscarded {
            public var flags: Int32
            public var id: Int32
            public init(flags: Int32, id: Int32) {
                self.flags = flags
                self.id = id
            }
        }
        public class Cons_encryptedChatEmpty {
            public var id: Int32
            public init(id: Int32) {
                self.id = id
            }
        }
        public class Cons_encryptedChatRequested {
            public var flags: Int32
            public var folderId: Int32?
            public var id: Int32
            public var accessHash: Int64
            public var date: Int32
            public var adminId: Int64
            public var participantId: Int64
            public var gA: Buffer
            public init(flags: Int32, folderId: Int32?, id: Int32, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64, gA: Buffer) {
                self.flags = flags
                self.folderId = folderId
                self.id = id
                self.accessHash = accessHash
                self.date = date
                self.adminId = adminId
                self.participantId = participantId
                self.gA = gA
            }
        }
        public class Cons_encryptedChatWaiting {
            public var id: Int32
            public var accessHash: Int64
            public var date: Int32
            public var adminId: Int64
            public var participantId: Int64
            public init(id: Int32, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64) {
                self.id = id
                self.accessHash = accessHash
                self.date = date
                self.adminId = adminId
                self.participantId = participantId
            }
        }
        case encryptedChat(Cons_encryptedChat)
        case encryptedChatDiscarded(Cons_encryptedChatDiscarded)
        case encryptedChatEmpty(Cons_encryptedChatEmpty)
        case encryptedChatRequested(Cons_encryptedChatRequested)
        case encryptedChatWaiting(Cons_encryptedChatWaiting)

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
        public class Cons_encryptedFile {
            public var id: Int64
            public var accessHash: Int64
            public var size: Int64
            public var dcId: Int32
            public var keyFingerprint: Int32
            public init(id: Int64, accessHash: Int64, size: Int64, dcId: Int32, keyFingerprint: Int32) {
                self.id = id
                self.accessHash = accessHash
                self.size = size
                self.dcId = dcId
                self.keyFingerprint = keyFingerprint
            }
        }
        case encryptedFile(Cons_encryptedFile)
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
        public class Cons_encryptedMessage {
            public var randomId: Int64
            public var chatId: Int32
            public var date: Int32
            public var bytes: Buffer
            public var file: Api.EncryptedFile
            public init(randomId: Int64, chatId: Int32, date: Int32, bytes: Buffer, file: Api.EncryptedFile) {
                self.randomId = randomId
                self.chatId = chatId
                self.date = date
                self.bytes = bytes
                self.file = file
            }
        }
        public class Cons_encryptedMessageService {
            public var randomId: Int64
            public var chatId: Int32
            public var date: Int32
            public var bytes: Buffer
            public init(randomId: Int64, chatId: Int32, date: Int32, bytes: Buffer) {
                self.randomId = randomId
                self.chatId = chatId
                self.date = date
                self.bytes = bytes
            }
        }
        case encryptedMessage(Cons_encryptedMessage)
        case encryptedMessageService(Cons_encryptedMessageService)

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
        public class Cons_chatInviteExported {
            public var flags: Int32
            public var link: String
            public var adminId: Int64
            public var date: Int32
            public var startDate: Int32?
            public var expireDate: Int32?
            public var usageLimit: Int32?
            public var usage: Int32?
            public var requested: Int32?
            public var subscriptionExpired: Int32?
            public var title: String?
            public var subscriptionPricing: Api.StarsSubscriptionPricing?
            public init(flags: Int32, link: String, adminId: Int64, date: Int32, startDate: Int32?, expireDate: Int32?, usageLimit: Int32?, usage: Int32?, requested: Int32?, subscriptionExpired: Int32?, title: String?, subscriptionPricing: Api.StarsSubscriptionPricing?) {
                self.flags = flags
                self.link = link
                self.adminId = adminId
                self.date = date
                self.startDate = startDate
                self.expireDate = expireDate
                self.usageLimit = usageLimit
                self.usage = usage
                self.requested = requested
                self.subscriptionExpired = subscriptionExpired
                self.title = title
                self.subscriptionPricing = subscriptionPricing
            }
        }
        case chatInviteExported(Cons_chatInviteExported)
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
        public class Cons_exportedChatlistInvite {
            public var flags: Int32
            public var title: String
            public var url: String
            public var peers: [Api.Peer]
            public init(flags: Int32, title: String, url: String, peers: [Api.Peer]) {
                self.flags = flags
                self.title = title
                self.url = url
                self.peers = peers
            }
        }
        case exportedChatlistInvite(Cons_exportedChatlistInvite)

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
        public class Cons_exportedContactToken {
            public var url: String
            public var expires: Int32
            public init(url: String, expires: Int32) {
                self.url = url
                self.expires = expires
            }
        }
        case exportedContactToken(Cons_exportedContactToken)

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
        public class Cons_exportedMessageLink {
            public var link: String
            public var html: String
            public init(link: String, html: String) {
                self.link = link
                self.html = html
            }
        }
        case exportedMessageLink(Cons_exportedMessageLink)

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
        public class Cons_exportedStoryLink {
            public var link: String
            public init(link: String) {
                self.link = link
            }
        }
        case exportedStoryLink(Cons_exportedStoryLink)

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
        public class Cons_factCheck {
            public var flags: Int32
            public var country: String?
            public var text: Api.TextWithEntities?
            public var hash: Int64
            public init(flags: Int32, country: String?, text: Api.TextWithEntities?, hash: Int64) {
                self.flags = flags
                self.country = country
                self.text = text
                self.hash = hash
            }
        }
        case factCheck(Cons_factCheck)

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
