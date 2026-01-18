public extension Api.messages {
    enum FavedStickers: TypeConstructorDescription {
        public class Cons_favedStickers {
            public var hash: Int64
            public var packs: [Api.StickerPack]
            public var stickers: [Api.Document]
            public init(hash: Int64, packs: [Api.StickerPack], stickers: [Api.Document]) {
                self.hash = hash
                self.packs = packs
                self.stickers = stickers
            }
        }
        case favedStickers(Cons_favedStickers)
        case favedStickersNotModified

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

        public static func parse_favedStickers(_ reader: BufferReader) -> FavedStickers? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_favedStickersNotModified(_ reader: BufferReader) -> FavedStickers? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum FeaturedStickers: TypeConstructorDescription {
        public class Cons_featuredStickers {
            public var flags: Int32
            public var hash: Int64
            public var count: Int32
            public var sets: [Api.StickerSetCovered]
            public var unread: [Int64]
            public init(flags: Int32, hash: Int64, count: Int32, sets: [Api.StickerSetCovered], unread: [Int64]) {
                self.flags = flags
                self.hash = hash
                self.count = count
                self.sets = sets
                self.unread = unread
            }
        }
        public class Cons_featuredStickersNotModified {
            public var count: Int32
            public init(count: Int32) {
                self.count = count
            }
        }
        case featuredStickers(Cons_featuredStickers)
        case featuredStickersNotModified(Cons_featuredStickersNotModified)

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

        public static func parse_featuredStickers(_ reader: BufferReader) -> FeaturedStickers? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_featuredStickersNotModified(_ reader: BufferReader) -> FeaturedStickers? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum ForumTopics: TypeConstructorDescription {
        public class Cons_forumTopics {
            public var flags: Int32
            public var count: Int32
            public var topics: [Api.ForumTopic]
            public var messages: [Api.Message]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public var pts: Int32
            public init(flags: Int32, count: Int32, topics: [Api.ForumTopic], messages: [Api.Message], chats: [Api.Chat], users: [Api.User], pts: Int32) {
                self.flags = flags
                self.count = count
                self.topics = topics
                self.messages = messages
                self.chats = chats
                self.users = users
                self.pts = pts
            }
        }
        case forumTopics(Cons_forumTopics)

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

        public static func parse_forumTopics(_ reader: BufferReader) -> ForumTopics? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum FoundStickerSets: TypeConstructorDescription {
        public class Cons_foundStickerSets {
            public var hash: Int64
            public var sets: [Api.StickerSetCovered]
            public init(hash: Int64, sets: [Api.StickerSetCovered]) {
                self.hash = hash
                self.sets = sets
            }
        }
        case foundStickerSets(Cons_foundStickerSets)
        case foundStickerSetsNotModified

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

        public static func parse_foundStickerSets(_ reader: BufferReader) -> FoundStickerSets? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_foundStickerSetsNotModified(_ reader: BufferReader) -> FoundStickerSets? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum FoundStickers: TypeConstructorDescription {
        public class Cons_foundStickers {
            public var flags: Int32
            public var nextOffset: Int32?
            public var hash: Int64
            public var stickers: [Api.Document]
            public init(flags: Int32, nextOffset: Int32?, hash: Int64, stickers: [Api.Document]) {
                self.flags = flags
                self.nextOffset = nextOffset
                self.hash = hash
                self.stickers = stickers
            }
        }
        public class Cons_foundStickersNotModified {
            public var flags: Int32
            public var nextOffset: Int32?
            public init(flags: Int32, nextOffset: Int32?) {
                self.flags = flags
                self.nextOffset = nextOffset
            }
        }
        case foundStickers(Cons_foundStickers)
        case foundStickersNotModified(Cons_foundStickersNotModified)

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

        public static func parse_foundStickers(_ reader: BufferReader) -> FoundStickers? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_foundStickersNotModified(_ reader: BufferReader) -> FoundStickers? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum HighScores: TypeConstructorDescription {
        case highScores(scores: [Api.HighScore], users: [Api.User])

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

        public static func parse_highScores(_ reader: BufferReader) -> HighScores? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum HistoryImport: TypeConstructorDescription {
        case historyImport(id: Int64)

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

        public static func parse_historyImport(_ reader: BufferReader) -> HistoryImport? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum HistoryImportParsed: TypeConstructorDescription {
        case historyImportParsed(flags: Int32, title: String?)

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

        public static func parse_historyImportParsed(_ reader: BufferReader) -> HistoryImportParsed? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum InactiveChats: TypeConstructorDescription {
        case inactiveChats(dates: [Int32], chats: [Api.Chat], users: [Api.User])

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

        public static func parse_inactiveChats(_ reader: BufferReader) -> InactiveChats? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    indirect enum InvitedUsers: TypeConstructorDescription {
        case invitedUsers(updates: Api.Updates, missingInvitees: [Api.MissingInvitee])

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

        public static func parse_invitedUsers(_ reader: BufferReader) -> InvitedUsers? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum MessageEditData: TypeConstructorDescription {
        case messageEditData(flags: Int32)

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

        public static func parse_messageEditData(_ reader: BufferReader) -> MessageEditData? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum MessageReactionsList: TypeConstructorDescription {
        case messageReactionsList(flags: Int32, count: Int32, reactions: [Api.MessagePeerReaction], chats: [Api.Chat], users: [Api.User], nextOffset: String?)

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

        public static func parse_messageReactionsList(_ reader: BufferReader) -> MessageReactionsList? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum MessageViews: TypeConstructorDescription {
        case messageViews(views: [Api.MessageViews], chats: [Api.Chat], users: [Api.User])

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

        public static func parse_messageViews(_ reader: BufferReader) -> MessageViews? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum Messages: TypeConstructorDescription {
        case channelMessages(flags: Int32, pts: Int32, count: Int32, offsetIdOffset: Int32?, messages: [Api.Message], topics: [Api.ForumTopic], chats: [Api.Chat], users: [Api.User])
        case messages(messages: [Api.Message], topics: [Api.ForumTopic], chats: [Api.Chat], users: [Api.User])
        case messagesNotModified(count: Int32)
        case messagesSlice(flags: Int32, count: Int32, nextRate: Int32?, offsetIdOffset: Int32?, searchFlood: Api.SearchPostsFlood?, messages: [Api.Message], topics: [Api.ForumTopic], chats: [Api.Chat], users: [Api.User])

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

        public static func parse_channelMessages(_ reader: BufferReader) -> Messages? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messages(_ reader: BufferReader) -> Messages? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messagesNotModified(_ reader: BufferReader) -> Messages? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messagesSlice(_ reader: BufferReader) -> Messages? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum MyStickers: TypeConstructorDescription {
        case myStickers(count: Int32, sets: [Api.StickerSetCovered])

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

        public static func parse_myStickers(_ reader: BufferReader) -> MyStickers? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum PeerDialogs: TypeConstructorDescription {
        case peerDialogs(dialogs: [Api.Dialog], messages: [Api.Message], chats: [Api.Chat], users: [Api.User], state: Api.updates.State)

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

        public static func parse_peerDialogs(_ reader: BufferReader) -> PeerDialogs? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum PeerSettings: TypeConstructorDescription {
        case peerSettings(settings: Api.PeerSettings, chats: [Api.Chat], users: [Api.User])

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

        public static func parse_peerSettings(_ reader: BufferReader) -> PeerSettings? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum PreparedInlineMessage: TypeConstructorDescription {
        case preparedInlineMessage(queryId: Int64, result: Api.BotInlineResult, peerTypes: [Api.InlineQueryPeerType], cacheTime: Int32, users: [Api.User])

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

        public static func parse_preparedInlineMessage(_ reader: BufferReader) -> PreparedInlineMessage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum QuickReplies: TypeConstructorDescription {
        case quickReplies(quickReplies: [Api.QuickReply], messages: [Api.Message], chats: [Api.Chat], users: [Api.User])
        case quickRepliesNotModified

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

        public static func parse_quickReplies(_ reader: BufferReader) -> QuickReplies? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_quickRepliesNotModified(_ reader: BufferReader) -> QuickReplies? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum Reactions: TypeConstructorDescription {
        case reactions(hash: Int64, reactions: [Api.Reaction])
        case reactionsNotModified

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

        public static func parse_reactions(_ reader: BufferReader) -> Reactions? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_reactionsNotModified(_ reader: BufferReader) -> Reactions? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum RecentStickers: TypeConstructorDescription {
        case recentStickers(hash: Int64, packs: [Api.StickerPack], stickers: [Api.Document], dates: [Int32])
        case recentStickersNotModified

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

        public static func parse_recentStickers(_ reader: BufferReader) -> RecentStickers? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_recentStickersNotModified(_ reader: BufferReader) -> RecentStickers? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum SavedDialogs: TypeConstructorDescription {
        case savedDialogs(dialogs: [Api.SavedDialog], messages: [Api.Message], chats: [Api.Chat], users: [Api.User])
        case savedDialogsNotModified(count: Int32)
        case savedDialogsSlice(count: Int32, dialogs: [Api.SavedDialog], messages: [Api.Message], chats: [Api.Chat], users: [Api.User])

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

        public static func parse_savedDialogs(_ reader: BufferReader) -> SavedDialogs? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_savedDialogsNotModified(_ reader: BufferReader) -> SavedDialogs? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_savedDialogsSlice(_ reader: BufferReader) -> SavedDialogs? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
