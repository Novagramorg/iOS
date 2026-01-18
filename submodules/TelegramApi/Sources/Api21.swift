public extension Api {
    enum PrivacyRule: TypeConstructorDescription {
        public class Cons_privacyValueAllowChatParticipants {
            public var chats: [Int64]
            public init(chats: [Int64]) {
                self.chats = chats
            }
        }
        public class Cons_privacyValueAllowUsers {
            public var users: [Int64]
            public init(users: [Int64]) {
                self.users = users
            }
        }
        public class Cons_privacyValueDisallowChatParticipants {
            public var chats: [Int64]
            public init(chats: [Int64]) {
                self.chats = chats
            }
        }
        public class Cons_privacyValueDisallowUsers {
            public var users: [Int64]
            public init(users: [Int64]) {
                self.users = users
            }
        }
        case privacyValueAllowAll
        case privacyValueAllowBots
        case privacyValueAllowChatParticipants(Cons_privacyValueAllowChatParticipants)
        case privacyValueAllowCloseFriends
        case privacyValueAllowContacts
        case privacyValueAllowPremium
        case privacyValueAllowUsers(Cons_privacyValueAllowUsers)
        case privacyValueDisallowAll
        case privacyValueDisallowBots
        case privacyValueDisallowChatParticipants(Cons_privacyValueDisallowChatParticipants)
        case privacyValueDisallowContacts
        case privacyValueDisallowUsers(Cons_privacyValueDisallowUsers)

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

        public static func parse_privacyValueAllowAll(_ reader: BufferReader) -> PrivacyRule? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_privacyValueAllowBots(_ reader: BufferReader) -> PrivacyRule? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_privacyValueAllowChatParticipants(_ reader: BufferReader) -> PrivacyRule? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_privacyValueAllowCloseFriends(_ reader: BufferReader) -> PrivacyRule? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_privacyValueAllowContacts(_ reader: BufferReader) -> PrivacyRule? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_privacyValueAllowPremium(_ reader: BufferReader) -> PrivacyRule? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_privacyValueAllowUsers(_ reader: BufferReader) -> PrivacyRule? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_privacyValueDisallowAll(_ reader: BufferReader) -> PrivacyRule? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_privacyValueDisallowBots(_ reader: BufferReader) -> PrivacyRule? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_privacyValueDisallowChatParticipants(_ reader: BufferReader) -> PrivacyRule? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_privacyValueDisallowContacts(_ reader: BufferReader) -> PrivacyRule? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_privacyValueDisallowUsers(_ reader: BufferReader) -> PrivacyRule? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum ProfileTab: TypeConstructorDescription {
        case profileTabFiles
        case profileTabGifs
        case profileTabGifts
        case profileTabLinks
        case profileTabMedia
        case profileTabMusic
        case profileTabPosts
        case profileTabVoice

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

        public static func parse_profileTabFiles(_ reader: BufferReader) -> ProfileTab? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_profileTabGifs(_ reader: BufferReader) -> ProfileTab? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_profileTabGifts(_ reader: BufferReader) -> ProfileTab? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_profileTabLinks(_ reader: BufferReader) -> ProfileTab? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_profileTabMedia(_ reader: BufferReader) -> ProfileTab? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_profileTabMusic(_ reader: BufferReader) -> ProfileTab? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_profileTabPosts(_ reader: BufferReader) -> ProfileTab? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_profileTabVoice(_ reader: BufferReader) -> ProfileTab? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum PublicForward: TypeConstructorDescription {
        public class Cons_publicForwardMessage {
            public var message: Api.Message
            public init(message: Api.Message) {
                self.message = message
            }
        }
        public class Cons_publicForwardStory {
            public var peer: Api.Peer
            public var story: Api.StoryItem
            public init(peer: Api.Peer, story: Api.StoryItem) {
                self.peer = peer
                self.story = story
            }
        }
        case publicForwardMessage(Cons_publicForwardMessage)
        case publicForwardStory(Cons_publicForwardStory)

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

        public static func parse_publicForwardMessage(_ reader: BufferReader) -> PublicForward? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_publicForwardStory(_ reader: BufferReader) -> PublicForward? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum QuickReply: TypeConstructorDescription {
        public class Cons_quickReply {
            public var shortcutId: Int32
            public var shortcut: String
            public var topMessage: Int32
            public var count: Int32
            public init(shortcutId: Int32, shortcut: String, topMessage: Int32, count: Int32) {
                self.shortcutId = shortcutId
                self.shortcut = shortcut
                self.topMessage = topMessage
                self.count = count
            }
        }
        case quickReply(Cons_quickReply)

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

        public static func parse_quickReply(_ reader: BufferReader) -> QuickReply? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum Reaction: TypeConstructorDescription {
        public class Cons_reactionCustomEmoji {
            public var documentId: Int64
            public init(documentId: Int64) {
                self.documentId = documentId
            }
        }
        public class Cons_reactionEmoji {
            public var emoticon: String
            public init(emoticon: String) {
                self.emoticon = emoticon
            }
        }
        case reactionCustomEmoji(Cons_reactionCustomEmoji)
        case reactionEmoji(Cons_reactionEmoji)
        case reactionEmpty
        case reactionPaid

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

        public static func parse_reactionCustomEmoji(_ reader: BufferReader) -> Reaction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_reactionEmoji(_ reader: BufferReader) -> Reaction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_reactionEmpty(_ reader: BufferReader) -> Reaction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_reactionPaid(_ reader: BufferReader) -> Reaction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum ReactionCount: TypeConstructorDescription {
        public class Cons_reactionCount {
            public var flags: Int32
            public var chosenOrder: Int32?
            public var reaction: Api.Reaction
            public var count: Int32
            public init(flags: Int32, chosenOrder: Int32?, reaction: Api.Reaction, count: Int32) {
                self.flags = flags
                self.chosenOrder = chosenOrder
                self.reaction = reaction
                self.count = count
            }
        }
        case reactionCount(Cons_reactionCount)

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

        public static func parse_reactionCount(_ reader: BufferReader) -> ReactionCount? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum ReactionNotificationsFrom: TypeConstructorDescription {
        case reactionNotificationsFromAll
        case reactionNotificationsFromContacts

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

        public static func parse_reactionNotificationsFromAll(_ reader: BufferReader) -> ReactionNotificationsFrom? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_reactionNotificationsFromContacts(_ reader: BufferReader) -> ReactionNotificationsFrom? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum ReactionsNotifySettings: TypeConstructorDescription {
        public class Cons_reactionsNotifySettings {
            public var flags: Int32
            public var messagesNotifyFrom: Api.ReactionNotificationsFrom?
            public var storiesNotifyFrom: Api.ReactionNotificationsFrom?
            public var sound: Api.NotificationSound
            public var showPreviews: Api.Bool
            public init(flags: Int32, messagesNotifyFrom: Api.ReactionNotificationsFrom?, storiesNotifyFrom: Api.ReactionNotificationsFrom?, sound: Api.NotificationSound, showPreviews: Api.Bool) {
                self.flags = flags
                self.messagesNotifyFrom = messagesNotifyFrom
                self.storiesNotifyFrom = storiesNotifyFrom
                self.sound = sound
                self.showPreviews = showPreviews
            }
        }
        case reactionsNotifySettings(Cons_reactionsNotifySettings)

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

        public static func parse_reactionsNotifySettings(_ reader: BufferReader) -> ReactionsNotifySettings? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum ReadParticipantDate: TypeConstructorDescription {
        public class Cons_readParticipantDate {
            public var userId: Int64
            public var date: Int32
            public init(userId: Int64, date: Int32) {
                self.userId = userId
                self.date = date
            }
        }
        case readParticipantDate(Cons_readParticipantDate)

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

        public static func parse_readParticipantDate(_ reader: BufferReader) -> ReadParticipantDate? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
