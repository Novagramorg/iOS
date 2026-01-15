public extension Api {
    enum PrivacyRule: TypeConstructorDescription {
        case privacyValueAllowAll
        case privacyValueAllowBots
        case privacyValueAllowChatParticipants(chats: [Int64])
        case privacyValueAllowCloseFriends
        case privacyValueAllowContacts
        case privacyValueAllowPremium
        case privacyValueAllowUsers(users: [Int64])
        case privacyValueDisallowAll
        case privacyValueDisallowBots
        case privacyValueDisallowChatParticipants(chats: [Int64])
        case privacyValueDisallowContacts
        case privacyValueDisallowUsers(users: [Int64])

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
        case publicForwardMessage(message: Api.Message)
        case publicForwardStory(peer: Api.Peer, story: Api.StoryItem)

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
        case quickReply(shortcutId: Int32, shortcut: String, topMessage: Int32, count: Int32)

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
        case reactionCustomEmoji(documentId: Int64)
        case reactionEmoji(emoticon: String)
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
        case reactionCount(flags: Int32, chosenOrder: Int32?, reaction: Api.Reaction, count: Int32)

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
        case reactionsNotifySettings(flags: Int32, messagesNotifyFrom: Api.ReactionNotificationsFrom?, storiesNotifyFrom: Api.ReactionNotificationsFrom?, sound: Api.NotificationSound, showPreviews: Api.Bool)

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
        case readParticipantDate(userId: Int64, date: Int32)

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
