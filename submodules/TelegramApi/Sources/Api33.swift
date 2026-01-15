public extension Api.messages {
    enum AllStickers: TypeConstructorDescription {
        case allStickers(hash: Int64, sets: [Api.StickerSet])
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
        case archivedStickers(count: Int32, sets: [Api.StickerSetCovered])

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
        case availableEffects(hash: Int32, effects: [Api.AvailableEffect], documents: [Api.Document])
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
        case availableReactions(hash: Int32, reactions: [Api.AvailableReaction])
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
        case botApp(flags: Int32, app: Api.BotApp)

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
        case botCallbackAnswer(flags: Int32, message: String?, url: String?, cacheTime: Int32)

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
        case botPreparedInlineMessage(id: String, expireDate: Int32)

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
        case botResults(flags: Int32, queryId: Int64, nextOffset: String?, switchPm: Api.InlineBotSwitchPM?, switchWebview: Api.InlineBotWebView?, results: [Api.BotInlineResult], cacheTime: Int32, users: [Api.User])

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
        case chatAdminsWithInvites(admins: [Api.ChatAdminWithInvites], users: [Api.User])

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
        case chatFull(fullChat: Api.ChatFull, chats: [Api.Chat], users: [Api.User])

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
        case chatInviteImporters(count: Int32, importers: [Api.ChatInviteImporter], users: [Api.User])

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
        case chats(chats: [Api.Chat])
        case chatsSlice(count: Int32, chats: [Api.Chat])

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
        case checkedHistoryImportPeer(confirmText: String)

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
        case dhConfig(g: Int32, p: Buffer, version: Int32, random: Buffer)
        case dhConfigNotModified(random: Buffer)

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
        case dialogFilters(flags: Int32, filters: [Api.DialogFilter])

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
        case dialogs(dialogs: [Api.Dialog], messages: [Api.Message], chats: [Api.Chat], users: [Api.User])
        case dialogsNotModified(count: Int32)
        case dialogsSlice(count: Int32, dialogs: [Api.Dialog], messages: [Api.Message], chats: [Api.Chat], users: [Api.User])

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
        case discussionMessage(flags: Int32, messages: [Api.Message], maxId: Int32?, readInboxMaxId: Int32?, readOutboxMaxId: Int32?, unreadCount: Int32, chats: [Api.Chat], users: [Api.User])

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
        case emojiGameDiceInfo(flags: Int32, gameHash: String, prevStake: Int64, currentStreak: Int32, params: [Int32], playsLeft: Int32?)
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
        case emojiGameOutcome(seed: Buffer, stakeTonAmount: Int64, tonAmount: Int64)

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
        case emojiGroups(hash: Int32, groups: [Api.EmojiGroup])
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
        case exportedChatInvite(invite: Api.ExportedChatInvite, users: [Api.User])
        case exportedChatInviteReplaced(invite: Api.ExportedChatInvite, newInvite: Api.ExportedChatInvite, users: [Api.User])

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
        case exportedChatInvites(count: Int32, invites: [Api.ExportedChatInvite], users: [Api.User])

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
