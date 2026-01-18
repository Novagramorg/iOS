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
        public class Cons_highScores {
            public var scores: [Api.HighScore]
            public var users: [Api.User]
            public init(scores: [Api.HighScore], users: [Api.User]) {
                self.scores = scores
                self.users = users
            }
        }
        case highScores(Cons_highScores)

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
        public class Cons_historyImport {
            public var id: Int64
            public init(id: Int64) {
                self.id = id
            }
        }
        case historyImport(Cons_historyImport)

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
        public class Cons_historyImportParsed {
            public var flags: Int32
            public var title: String?
            public init(flags: Int32, title: String?) {
                self.flags = flags
                self.title = title
            }
        }
        case historyImportParsed(Cons_historyImportParsed)

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
        public class Cons_inactiveChats {
            public var dates: [Int32]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(dates: [Int32], chats: [Api.Chat], users: [Api.User]) {
                self.dates = dates
                self.chats = chats
                self.users = users
            }
        }
        case inactiveChats(Cons_inactiveChats)

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
        public class Cons_invitedUsers {
            public var updates: Api.Updates
            public var missingInvitees: [Api.MissingInvitee]
            public init(updates: Api.Updates, missingInvitees: [Api.MissingInvitee]) {
                self.updates = updates
                self.missingInvitees = missingInvitees
            }
        }
        case invitedUsers(Cons_invitedUsers)

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
        public class Cons_messageEditData {
            public var flags: Int32
            public init(flags: Int32) {
                self.flags = flags
            }
        }
        case messageEditData(Cons_messageEditData)

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
        public class Cons_messageReactionsList {
            public var flags: Int32
            public var count: Int32
            public var reactions: [Api.MessagePeerReaction]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public var nextOffset: String?
            public init(flags: Int32, count: Int32, reactions: [Api.MessagePeerReaction], chats: [Api.Chat], users: [Api.User], nextOffset: String?) {
                self.flags = flags
                self.count = count
                self.reactions = reactions
                self.chats = chats
                self.users = users
                self.nextOffset = nextOffset
            }
        }
        case messageReactionsList(Cons_messageReactionsList)

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
        public class Cons_messageViews {
            public var views: [Api.MessageViews]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(views: [Api.MessageViews], chats: [Api.Chat], users: [Api.User]) {
                self.views = views
                self.chats = chats
                self.users = users
            }
        }
        case messageViews(Cons_messageViews)

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
        public class Cons_channelMessages {
            public var flags: Int32
            public var pts: Int32
            public var count: Int32
            public var offsetIdOffset: Int32?
            public var messages: [Api.Message]
            public var topics: [Api.ForumTopic]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(flags: Int32, pts: Int32, count: Int32, offsetIdOffset: Int32?, messages: [Api.Message], topics: [Api.ForumTopic], chats: [Api.Chat], users: [Api.User]) {
                self.flags = flags
                self.pts = pts
                self.count = count
                self.offsetIdOffset = offsetIdOffset
                self.messages = messages
                self.topics = topics
                self.chats = chats
                self.users = users
            }
        }
        public class Cons_messages {
            public var messages: [Api.Message]
            public var topics: [Api.ForumTopic]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(messages: [Api.Message], topics: [Api.ForumTopic], chats: [Api.Chat], users: [Api.User]) {
                self.messages = messages
                self.topics = topics
                self.chats = chats
                self.users = users
            }
        }
        public class Cons_messagesNotModified {
            public var count: Int32
            public init(count: Int32) {
                self.count = count
            }
        }
        public class Cons_messagesSlice {
            public var flags: Int32
            public var count: Int32
            public var nextRate: Int32?
            public var offsetIdOffset: Int32?
            public var searchFlood: Api.SearchPostsFlood?
            public var messages: [Api.Message]
            public var topics: [Api.ForumTopic]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(flags: Int32, count: Int32, nextRate: Int32?, offsetIdOffset: Int32?, searchFlood: Api.SearchPostsFlood?, messages: [Api.Message], topics: [Api.ForumTopic], chats: [Api.Chat], users: [Api.User]) {
                self.flags = flags
                self.count = count
                self.nextRate = nextRate
                self.offsetIdOffset = offsetIdOffset
                self.searchFlood = searchFlood
                self.messages = messages
                self.topics = topics
                self.chats = chats
                self.users = users
            }
        }
        case channelMessages(Cons_channelMessages)
        case messages(Cons_messages)
        case messagesNotModified(Cons_messagesNotModified)
        case messagesSlice(Cons_messagesSlice)

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
        public class Cons_myStickers {
            public var count: Int32
            public var sets: [Api.StickerSetCovered]
            public init(count: Int32, sets: [Api.StickerSetCovered]) {
                self.count = count
                self.sets = sets
            }
        }
        case myStickers(Cons_myStickers)

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
        public class Cons_peerDialogs {
            public var dialogs: [Api.Dialog]
            public var messages: [Api.Message]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public var state: Api.updates.State
            public init(dialogs: [Api.Dialog], messages: [Api.Message], chats: [Api.Chat], users: [Api.User], state: Api.updates.State) {
                self.dialogs = dialogs
                self.messages = messages
                self.chats = chats
                self.users = users
                self.state = state
            }
        }
        case peerDialogs(Cons_peerDialogs)

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
        public class Cons_peerSettings {
            public var settings: Api.PeerSettings
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(settings: Api.PeerSettings, chats: [Api.Chat], users: [Api.User]) {
                self.settings = settings
                self.chats = chats
                self.users = users
            }
        }
        case peerSettings(Cons_peerSettings)

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
        public class Cons_preparedInlineMessage {
            public var queryId: Int64
            public var result: Api.BotInlineResult
            public var peerTypes: [Api.InlineQueryPeerType]
            public var cacheTime: Int32
            public var users: [Api.User]
            public init(queryId: Int64, result: Api.BotInlineResult, peerTypes: [Api.InlineQueryPeerType], cacheTime: Int32, users: [Api.User]) {
                self.queryId = queryId
                self.result = result
                self.peerTypes = peerTypes
                self.cacheTime = cacheTime
                self.users = users
            }
        }
        case preparedInlineMessage(Cons_preparedInlineMessage)

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
        public class Cons_quickReplies {
            public var quickReplies: [Api.QuickReply]
            public var messages: [Api.Message]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(quickReplies: [Api.QuickReply], messages: [Api.Message], chats: [Api.Chat], users: [Api.User]) {
                self.quickReplies = quickReplies
                self.messages = messages
                self.chats = chats
                self.users = users
            }
        }
        case quickReplies(Cons_quickReplies)
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
        public class Cons_reactions {
            public var hash: Int64
            public var reactions: [Api.Reaction]
            public init(hash: Int64, reactions: [Api.Reaction]) {
                self.hash = hash
                self.reactions = reactions
            }
        }
        case reactions(Cons_reactions)
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
        public class Cons_recentStickers {
            public var hash: Int64
            public var packs: [Api.StickerPack]
            public var stickers: [Api.Document]
            public var dates: [Int32]
            public init(hash: Int64, packs: [Api.StickerPack], stickers: [Api.Document], dates: [Int32]) {
                self.hash = hash
                self.packs = packs
                self.stickers = stickers
                self.dates = dates
            }
        }
        case recentStickers(Cons_recentStickers)
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
        public class Cons_savedDialogs {
            public var dialogs: [Api.SavedDialog]
            public var messages: [Api.Message]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(dialogs: [Api.SavedDialog], messages: [Api.Message], chats: [Api.Chat], users: [Api.User]) {
                self.dialogs = dialogs
                self.messages = messages
                self.chats = chats
                self.users = users
            }
        }
        public class Cons_savedDialogsNotModified {
            public var count: Int32
            public init(count: Int32) {
                self.count = count
            }
        }
        public class Cons_savedDialogsSlice {
            public var count: Int32
            public var dialogs: [Api.SavedDialog]
            public var messages: [Api.Message]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(count: Int32, dialogs: [Api.SavedDialog], messages: [Api.Message], chats: [Api.Chat], users: [Api.User]) {
                self.count = count
                self.dialogs = dialogs
                self.messages = messages
                self.chats = chats
                self.users = users
            }
        }
        case savedDialogs(Cons_savedDialogs)
        case savedDialogsNotModified(Cons_savedDialogsNotModified)
        case savedDialogsSlice(Cons_savedDialogsSlice)

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
