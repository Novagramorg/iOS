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
        public class Cons_fileHash {
            public var offset: Int64
            public var limit: Int32
            public var hash: Buffer
            public init(offset: Int64, limit: Int32, hash: Buffer) {
                self.offset = offset
                self.limit = limit
                self.hash = hash
            }
        }
        case fileHash(Cons_fileHash)

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
        public class Cons_folder {
            public var flags: Int32
            public var id: Int32
            public var title: String
            public var photo: Api.ChatPhoto?
            public init(flags: Int32, id: Int32, title: String, photo: Api.ChatPhoto?) {
                self.flags = flags
                self.id = id
                self.title = title
                self.photo = photo
            }
        }
        case folder(Cons_folder)

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
        public class Cons_folderPeer {
            public var peer: Api.Peer
            public var folderId: Int32
            public init(peer: Api.Peer, folderId: Int32) {
                self.peer = peer
                self.folderId = folderId
            }
        }
        case folderPeer(Cons_folderPeer)

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
        public class Cons_forumTopic {
            public var flags: Int32
            public var id: Int32
            public var date: Int32
            public var peer: Api.Peer
            public var title: String
            public var iconColor: Int32
            public var iconEmojiId: Int64?
            public var topMessage: Int32
            public var readInboxMaxId: Int32
            public var readOutboxMaxId: Int32
            public var unreadCount: Int32
            public var unreadMentionsCount: Int32
            public var unreadReactionsCount: Int32
            public var fromId: Api.Peer
            public var notifySettings: Api.PeerNotifySettings
            public var draft: Api.DraftMessage?
            public init(flags: Int32, id: Int32, date: Int32, peer: Api.Peer, title: String, iconColor: Int32, iconEmojiId: Int64?, topMessage: Int32, readInboxMaxId: Int32, readOutboxMaxId: Int32, unreadCount: Int32, unreadMentionsCount: Int32, unreadReactionsCount: Int32, fromId: Api.Peer, notifySettings: Api.PeerNotifySettings, draft: Api.DraftMessage?) {
                self.flags = flags
                self.id = id
                self.date = date
                self.peer = peer
                self.title = title
                self.iconColor = iconColor
                self.iconEmojiId = iconEmojiId
                self.topMessage = topMessage
                self.readInboxMaxId = readInboxMaxId
                self.readOutboxMaxId = readOutboxMaxId
                self.unreadCount = unreadCount
                self.unreadMentionsCount = unreadMentionsCount
                self.unreadReactionsCount = unreadReactionsCount
                self.fromId = fromId
                self.notifySettings = notifySettings
                self.draft = draft
            }
        }
        public class Cons_forumTopicDeleted {
            public var id: Int32
            public init(id: Int32) {
                self.id = id
            }
        }
        case forumTopic(Cons_forumTopic)
        case forumTopicDeleted(Cons_forumTopicDeleted)

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
        public class Cons_foundStory {
            public var peer: Api.Peer
            public var story: Api.StoryItem
            public init(peer: Api.Peer, story: Api.StoryItem) {
                self.peer = peer
                self.story = story
            }
        }
        case foundStory(Cons_foundStory)

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
        public class Cons_game {
            public var flags: Int32
            public var id: Int64
            public var accessHash: Int64
            public var shortName: String
            public var title: String
            public var description: String
            public var photo: Api.Photo
            public var document: Api.Document?
            public init(flags: Int32, id: Int64, accessHash: Int64, shortName: String, title: String, description: String, photo: Api.Photo, document: Api.Document?) {
                self.flags = flags
                self.id = id
                self.accessHash = accessHash
                self.shortName = shortName
                self.title = title
                self.description = description
                self.photo = photo
                self.document = document
            }
        }
        case game(Cons_game)

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
        public class Cons_geoPoint {
            public var flags: Int32
            public var long: Double
            public var lat: Double
            public var accessHash: Int64
            public var accuracyRadius: Int32?
            public init(flags: Int32, long: Double, lat: Double, accessHash: Int64, accuracyRadius: Int32?) {
                self.flags = flags
                self.long = long
                self.lat = lat
                self.accessHash = accessHash
                self.accuracyRadius = accuracyRadius
            }
        }
        case geoPoint(Cons_geoPoint)
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
        public class Cons_geoPointAddress {
            public var flags: Int32
            public var countryIso2: String
            public var state: String?
            public var city: String?
            public var street: String?
            public init(flags: Int32, countryIso2: String, state: String?, city: String?, street: String?) {
                self.flags = flags
                self.countryIso2 = countryIso2
                self.state = state
                self.city = city
                self.street = street
            }
        }
        case geoPointAddress(Cons_geoPointAddress)

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
        public class Cons_globalPrivacySettings {
            public var flags: Int32
            public var noncontactPeersPaidStars: Int64?
            public var disallowedGifts: Api.DisallowedGiftsSettings?
            public init(flags: Int32, noncontactPeersPaidStars: Int64?, disallowedGifts: Api.DisallowedGiftsSettings?) {
                self.flags = flags
                self.noncontactPeersPaidStars = noncontactPeersPaidStars
                self.disallowedGifts = disallowedGifts
            }
        }
        case globalPrivacySettings(Cons_globalPrivacySettings)

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
        public class Cons_groupCall {
            public var flags: Int32
            public var id: Int64
            public var accessHash: Int64
            public var participantsCount: Int32
            public var title: String?
            public var streamDcId: Int32?
            public var recordStartDate: Int32?
            public var scheduleDate: Int32?
            public var unmutedVideoCount: Int32?
            public var unmutedVideoLimit: Int32
            public var version: Int32
            public var inviteLink: String?
            public var sendPaidMessagesStars: Int64?
            public var defaultSendAs: Api.Peer?
            public init(flags: Int32, id: Int64, accessHash: Int64, participantsCount: Int32, title: String?, streamDcId: Int32?, recordStartDate: Int32?, scheduleDate: Int32?, unmutedVideoCount: Int32?, unmutedVideoLimit: Int32, version: Int32, inviteLink: String?, sendPaidMessagesStars: Int64?, defaultSendAs: Api.Peer?) {
                self.flags = flags
                self.id = id
                self.accessHash = accessHash
                self.participantsCount = participantsCount
                self.title = title
                self.streamDcId = streamDcId
                self.recordStartDate = recordStartDate
                self.scheduleDate = scheduleDate
                self.unmutedVideoCount = unmutedVideoCount
                self.unmutedVideoLimit = unmutedVideoLimit
                self.version = version
                self.inviteLink = inviteLink
                self.sendPaidMessagesStars = sendPaidMessagesStars
                self.defaultSendAs = defaultSendAs
            }
        }
        public class Cons_groupCallDiscarded {
            public var id: Int64
            public var accessHash: Int64
            public var duration: Int32
            public init(id: Int64, accessHash: Int64, duration: Int32) {
                self.id = id
                self.accessHash = accessHash
                self.duration = duration
            }
        }
        case groupCall(Cons_groupCall)
        case groupCallDiscarded(Cons_groupCallDiscarded)

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
        public class Cons_groupCallDonor {
            public var flags: Int32
            public var peerId: Api.Peer?
            public var stars: Int64
            public init(flags: Int32, peerId: Api.Peer?, stars: Int64) {
                self.flags = flags
                self.peerId = peerId
                self.stars = stars
            }
        }
        case groupCallDonor(Cons_groupCallDonor)

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
        public class Cons_groupCallMessage {
            public var flags: Int32
            public var id: Int32
            public var fromId: Api.Peer
            public var date: Int32
            public var message: Api.TextWithEntities
            public var paidMessageStars: Int64?
            public init(flags: Int32, id: Int32, fromId: Api.Peer, date: Int32, message: Api.TextWithEntities, paidMessageStars: Int64?) {
                self.flags = flags
                self.id = id
                self.fromId = fromId
                self.date = date
                self.message = message
                self.paidMessageStars = paidMessageStars
            }
        }
        case groupCallMessage(Cons_groupCallMessage)

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
