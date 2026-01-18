public extension Api.messages {
    enum AllStickers: TypeConstructorDescription {
        public class Cons_allStickers {
            public var hash: Int64
            public var sets: [Api.StickerSet]
            public init(hash: Int64, sets: [Api.StickerSet]) {
                self.hash = hash
                self.sets = sets
            }
        }
        case allStickers(Cons_allStickers)
        case allStickersNotModified

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

        public static func parse_allStickers(_ reader: BufferReader) -> AllStickers? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_allStickersNotModified(_ reader: BufferReader) -> AllStickers? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum ArchivedStickers: TypeConstructorDescription {
        public class Cons_archivedStickers {
            public var count: Int32
            public var sets: [Api.StickerSetCovered]
            public init(count: Int32, sets: [Api.StickerSetCovered]) {
                self.count = count
                self.sets = sets
            }
        }
        case archivedStickers(Cons_archivedStickers)

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

        public static func parse_archivedStickers(_ reader: BufferReader) -> ArchivedStickers? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum AvailableEffects: TypeConstructorDescription {
        public class Cons_availableEffects {
            public var hash: Int32
            public var effects: [Api.AvailableEffect]
            public var documents: [Api.Document]
            public init(hash: Int32, effects: [Api.AvailableEffect], documents: [Api.Document]) {
                self.hash = hash
                self.effects = effects
                self.documents = documents
            }
        }
        case availableEffects(Cons_availableEffects)
        case availableEffectsNotModified

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

        public static func parse_availableEffects(_ reader: BufferReader) -> AvailableEffects? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_availableEffectsNotModified(_ reader: BufferReader) -> AvailableEffects? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum AvailableReactions: TypeConstructorDescription {
        public class Cons_availableReactions {
            public var hash: Int32
            public var reactions: [Api.AvailableReaction]
            public init(hash: Int32, reactions: [Api.AvailableReaction]) {
                self.hash = hash
                self.reactions = reactions
            }
        }
        case availableReactions(Cons_availableReactions)
        case availableReactionsNotModified

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

        public static func parse_availableReactions(_ reader: BufferReader) -> AvailableReactions? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_availableReactionsNotModified(_ reader: BufferReader) -> AvailableReactions? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum BotApp: TypeConstructorDescription {
        public class Cons_botApp {
            public var flags: Int32
            public var app: Api.BotApp
            public init(flags: Int32, app: Api.BotApp) {
                self.flags = flags
                self.app = app
            }
        }
        case botApp(Cons_botApp)

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

        public static func parse_botApp(_ reader: BufferReader) -> BotApp? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum BotCallbackAnswer: TypeConstructorDescription {
        public class Cons_botCallbackAnswer {
            public var flags: Int32
            public var message: String?
            public var url: String?
            public var cacheTime: Int32
            public init(flags: Int32, message: String?, url: String?, cacheTime: Int32) {
                self.flags = flags
                self.message = message
                self.url = url
                self.cacheTime = cacheTime
            }
        }
        case botCallbackAnswer(Cons_botCallbackAnswer)

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

        public static func parse_botCallbackAnswer(_ reader: BufferReader) -> BotCallbackAnswer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum BotPreparedInlineMessage: TypeConstructorDescription {
        public class Cons_botPreparedInlineMessage {
            public var id: String
            public var expireDate: Int32
            public init(id: String, expireDate: Int32) {
                self.id = id
                self.expireDate = expireDate
            }
        }
        case botPreparedInlineMessage(Cons_botPreparedInlineMessage)

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

        public static func parse_botPreparedInlineMessage(_ reader: BufferReader) -> BotPreparedInlineMessage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum BotResults: TypeConstructorDescription {
        public class Cons_botResults {
            public var flags: Int32
            public var queryId: Int64
            public var nextOffset: String?
            public var switchPm: Api.InlineBotSwitchPM?
            public var switchWebview: Api.InlineBotWebView?
            public var results: [Api.BotInlineResult]
            public var cacheTime: Int32
            public var users: [Api.User]
            public init(flags: Int32, queryId: Int64, nextOffset: String?, switchPm: Api.InlineBotSwitchPM?, switchWebview: Api.InlineBotWebView?, results: [Api.BotInlineResult], cacheTime: Int32, users: [Api.User]) {
                self.flags = flags
                self.queryId = queryId
                self.nextOffset = nextOffset
                self.switchPm = switchPm
                self.switchWebview = switchWebview
                self.results = results
                self.cacheTime = cacheTime
                self.users = users
            }
        }
        case botResults(Cons_botResults)

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

        public static func parse_botResults(_ reader: BufferReader) -> BotResults? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum ChatAdminsWithInvites: TypeConstructorDescription {
        public class Cons_chatAdminsWithInvites {
            public var admins: [Api.ChatAdminWithInvites]
            public var users: [Api.User]
            public init(admins: [Api.ChatAdminWithInvites], users: [Api.User]) {
                self.admins = admins
                self.users = users
            }
        }
        case chatAdminsWithInvites(Cons_chatAdminsWithInvites)

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

        public static func parse_chatAdminsWithInvites(_ reader: BufferReader) -> ChatAdminsWithInvites? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum ChatFull: TypeConstructorDescription {
        public class Cons_chatFull {
            public var fullChat: Api.ChatFull
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(fullChat: Api.ChatFull, chats: [Api.Chat], users: [Api.User]) {
                self.fullChat = fullChat
                self.chats = chats
                self.users = users
            }
        }
        case chatFull(Cons_chatFull)

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

        public static func parse_chatFull(_ reader: BufferReader) -> ChatFull? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum ChatInviteImporters: TypeConstructorDescription {
        public class Cons_chatInviteImporters {
            public var count: Int32
            public var importers: [Api.ChatInviteImporter]
            public var users: [Api.User]
            public init(count: Int32, importers: [Api.ChatInviteImporter], users: [Api.User]) {
                self.count = count
                self.importers = importers
                self.users = users
            }
        }
        case chatInviteImporters(Cons_chatInviteImporters)

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

        public static func parse_chatInviteImporters(_ reader: BufferReader) -> ChatInviteImporters? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum Chats: TypeConstructorDescription {
        public class Cons_chats {
            public var chats: [Api.Chat]
            public init(chats: [Api.Chat]) {
                self.chats = chats
            }
        }
        public class Cons_chatsSlice {
            public var count: Int32
            public var chats: [Api.Chat]
            public init(count: Int32, chats: [Api.Chat]) {
                self.count = count
                self.chats = chats
            }
        }
        case chats(Cons_chats)
        case chatsSlice(Cons_chatsSlice)

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

        public static func parse_chats(_ reader: BufferReader) -> Chats? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_chatsSlice(_ reader: BufferReader) -> Chats? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum CheckedHistoryImportPeer: TypeConstructorDescription {
        public class Cons_checkedHistoryImportPeer {
            public var confirmText: String
            public init(confirmText: String) {
                self.confirmText = confirmText
            }
        }
        case checkedHistoryImportPeer(Cons_checkedHistoryImportPeer)

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

        public static func parse_checkedHistoryImportPeer(_ reader: BufferReader) -> CheckedHistoryImportPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum DhConfig: TypeConstructorDescription {
        public class Cons_dhConfig {
            public var g: Int32
            public var p: Buffer
            public var version: Int32
            public var random: Buffer
            public init(g: Int32, p: Buffer, version: Int32, random: Buffer) {
                self.g = g
                self.p = p
                self.version = version
                self.random = random
            }
        }
        public class Cons_dhConfigNotModified {
            public var random: Buffer
            public init(random: Buffer) {
                self.random = random
            }
        }
        case dhConfig(Cons_dhConfig)
        case dhConfigNotModified(Cons_dhConfigNotModified)

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

        public static func parse_dhConfig(_ reader: BufferReader) -> DhConfig? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_dhConfigNotModified(_ reader: BufferReader) -> DhConfig? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum DialogFilters: TypeConstructorDescription {
        public class Cons_dialogFilters {
            public var flags: Int32
            public var filters: [Api.DialogFilter]
            public init(flags: Int32, filters: [Api.DialogFilter]) {
                self.flags = flags
                self.filters = filters
            }
        }
        case dialogFilters(Cons_dialogFilters)

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

        public static func parse_dialogFilters(_ reader: BufferReader) -> DialogFilters? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum Dialogs: TypeConstructorDescription {
        public class Cons_dialogs {
            public var dialogs: [Api.Dialog]
            public var messages: [Api.Message]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(dialogs: [Api.Dialog], messages: [Api.Message], chats: [Api.Chat], users: [Api.User]) {
                self.dialogs = dialogs
                self.messages = messages
                self.chats = chats
                self.users = users
            }
        }
        public class Cons_dialogsNotModified {
            public var count: Int32
            public init(count: Int32) {
                self.count = count
            }
        }
        public class Cons_dialogsSlice {
            public var count: Int32
            public var dialogs: [Api.Dialog]
            public var messages: [Api.Message]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(count: Int32, dialogs: [Api.Dialog], messages: [Api.Message], chats: [Api.Chat], users: [Api.User]) {
                self.count = count
                self.dialogs = dialogs
                self.messages = messages
                self.chats = chats
                self.users = users
            }
        }
        case dialogs(Cons_dialogs)
        case dialogsNotModified(Cons_dialogsNotModified)
        case dialogsSlice(Cons_dialogsSlice)

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

        public static func parse_dialogs(_ reader: BufferReader) -> Dialogs? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_dialogsNotModified(_ reader: BufferReader) -> Dialogs? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_dialogsSlice(_ reader: BufferReader) -> Dialogs? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum DiscussionMessage: TypeConstructorDescription {
        public class Cons_discussionMessage {
            public var flags: Int32
            public var messages: [Api.Message]
            public var maxId: Int32?
            public var readInboxMaxId: Int32?
            public var readOutboxMaxId: Int32?
            public var unreadCount: Int32
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(flags: Int32, messages: [Api.Message], maxId: Int32?, readInboxMaxId: Int32?, readOutboxMaxId: Int32?, unreadCount: Int32, chats: [Api.Chat], users: [Api.User]) {
                self.flags = flags
                self.messages = messages
                self.maxId = maxId
                self.readInboxMaxId = readInboxMaxId
                self.readOutboxMaxId = readOutboxMaxId
                self.unreadCount = unreadCount
                self.chats = chats
                self.users = users
            }
        }
        case discussionMessage(Cons_discussionMessage)

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

        public static func parse_discussionMessage(_ reader: BufferReader) -> DiscussionMessage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum EmojiGameInfo: TypeConstructorDescription {
        public class Cons_emojiGameDiceInfo {
            public var flags: Int32
            public var gameHash: String
            public var prevStake: Int64
            public var currentStreak: Int32
            public var params: [Int32]
            public var playsLeft: Int32?
            public init(flags: Int32, gameHash: String, prevStake: Int64, currentStreak: Int32, params: [Int32], playsLeft: Int32?) {
                self.flags = flags
                self.gameHash = gameHash
                self.prevStake = prevStake
                self.currentStreak = currentStreak
                self.params = params
                self.playsLeft = playsLeft
            }
        }
        case emojiGameDiceInfo(Cons_emojiGameDiceInfo)
        case emojiGameUnavailable

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

        public static func parse_emojiGameDiceInfo(_ reader: BufferReader) -> EmojiGameInfo? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_emojiGameUnavailable(_ reader: BufferReader) -> EmojiGameInfo? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum EmojiGameOutcome: TypeConstructorDescription {
        public class Cons_emojiGameOutcome {
            public var seed: Buffer
            public var stakeTonAmount: Int64
            public var tonAmount: Int64
            public init(seed: Buffer, stakeTonAmount: Int64, tonAmount: Int64) {
                self.seed = seed
                self.stakeTonAmount = stakeTonAmount
                self.tonAmount = tonAmount
            }
        }
        case emojiGameOutcome(Cons_emojiGameOutcome)

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

        public static func parse_emojiGameOutcome(_ reader: BufferReader) -> EmojiGameOutcome? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum EmojiGroups: TypeConstructorDescription {
        public class Cons_emojiGroups {
            public var hash: Int32
            public var groups: [Api.EmojiGroup]
            public init(hash: Int32, groups: [Api.EmojiGroup]) {
                self.hash = hash
                self.groups = groups
            }
        }
        case emojiGroups(Cons_emojiGroups)
        case emojiGroupsNotModified

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

        public static func parse_emojiGroups(_ reader: BufferReader) -> EmojiGroups? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_emojiGroupsNotModified(_ reader: BufferReader) -> EmojiGroups? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum ExportedChatInvite: TypeConstructorDescription {
        public class Cons_exportedChatInvite {
            public var invite: Api.ExportedChatInvite
            public var users: [Api.User]
            public init(invite: Api.ExportedChatInvite, users: [Api.User]) {
                self.invite = invite
                self.users = users
            }
        }
        public class Cons_exportedChatInviteReplaced {
            public var invite: Api.ExportedChatInvite
            public var newInvite: Api.ExportedChatInvite
            public var users: [Api.User]
            public init(invite: Api.ExportedChatInvite, newInvite: Api.ExportedChatInvite, users: [Api.User]) {
                self.invite = invite
                self.newInvite = newInvite
                self.users = users
            }
        }
        case exportedChatInvite(Cons_exportedChatInvite)
        case exportedChatInviteReplaced(Cons_exportedChatInviteReplaced)

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

        public static func parse_exportedChatInvite(_ reader: BufferReader) -> ExportedChatInvite? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_exportedChatInviteReplaced(_ reader: BufferReader) -> ExportedChatInvite? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum ExportedChatInvites: TypeConstructorDescription {
        public class Cons_exportedChatInvites {
            public var count: Int32
            public var invites: [Api.ExportedChatInvite]
            public var users: [Api.User]
            public init(count: Int32, invites: [Api.ExportedChatInvite], users: [Api.User]) {
                self.count = count
                self.invites = invites
                self.users = users
            }
        }
        case exportedChatInvites(Cons_exportedChatInvites)

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

        public static func parse_exportedChatInvites(_ reader: BufferReader) -> ExportedChatInvites? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
