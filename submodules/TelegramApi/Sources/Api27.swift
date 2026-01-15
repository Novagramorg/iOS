public extension Api {
    enum StoryAlbum: TypeConstructorDescription {
        case storyAlbum(flags: Int32, albumId: Int32, title: String, iconPhoto: Api.Photo?, iconVideo: Api.Document?)

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

        public static func parse_storyAlbum(_ reader: BufferReader) -> StoryAlbum? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StoryFwdHeader: TypeConstructorDescription {
        case storyFwdHeader(flags: Int32, from: Api.Peer?, fromName: String?, storyId: Int32?)

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

        public static func parse_storyFwdHeader(_ reader: BufferReader) -> StoryFwdHeader? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum StoryItem: TypeConstructorDescription {
        case storyItem(flags: Int32, id: Int32, date: Int32, fromId: Api.Peer?, fwdFrom: Api.StoryFwdHeader?, expireDate: Int32, caption: String?, entities: [Api.MessageEntity]?, media: Api.MessageMedia, mediaAreas: [Api.MediaArea]?, privacy: [Api.PrivacyRule]?, views: Api.StoryViews?, sentReaction: Api.Reaction?, albums: [Int32]?)
        case storyItemDeleted(id: Int32)
        case storyItemSkipped(flags: Int32, id: Int32, date: Int32, expireDate: Int32)

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

        public static func parse_storyItem(_ reader: BufferReader) -> StoryItem? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_storyItemDeleted(_ reader: BufferReader) -> StoryItem? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_storyItemSkipped(_ reader: BufferReader) -> StoryItem? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum StoryReaction: TypeConstructorDescription {
        case storyReaction(peerId: Api.Peer, date: Int32, reaction: Api.Reaction)
        case storyReactionPublicForward(message: Api.Message)
        case storyReactionPublicRepost(peerId: Api.Peer, story: Api.StoryItem)

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

        public static func parse_storyReaction(_ reader: BufferReader) -> StoryReaction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_storyReactionPublicForward(_ reader: BufferReader) -> StoryReaction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_storyReactionPublicRepost(_ reader: BufferReader) -> StoryReaction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum StoryView: TypeConstructorDescription {
        case storyView(flags: Int32, userId: Int64, date: Int32, reaction: Api.Reaction?)
        case storyViewPublicForward(flags: Int32, message: Api.Message)
        case storyViewPublicRepost(flags: Int32, peerId: Api.Peer, story: Api.StoryItem)

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

        public static func parse_storyView(_ reader: BufferReader) -> StoryView? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_storyViewPublicForward(_ reader: BufferReader) -> StoryView? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_storyViewPublicRepost(_ reader: BufferReader) -> StoryView? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StoryViews: TypeConstructorDescription {
        case storyViews(flags: Int32, viewsCount: Int32, forwardsCount: Int32?, reactions: [Api.ReactionCount]?, reactionsCount: Int32?, recentViewers: [Int64]?)

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

        public static func parse_storyViews(_ reader: BufferReader) -> StoryViews? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum SuggestedPost: TypeConstructorDescription {
        case suggestedPost(flags: Int32, price: Api.StarsAmount?, scheduleDate: Int32?)

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

        public static func parse_suggestedPost(_ reader: BufferReader) -> SuggestedPost? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum TextWithEntities: TypeConstructorDescription {
        case textWithEntities(text: String, entities: [Api.MessageEntity])

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

        public static func parse_textWithEntities(_ reader: BufferReader) -> TextWithEntities? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum Theme: TypeConstructorDescription {
        case theme(flags: Int32, id: Int64, accessHash: Int64, slug: String, title: String, document: Api.Document?, settings: [Api.ThemeSettings]?, emoticon: String?, installsCount: Int32?)

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

        public static func parse_theme(_ reader: BufferReader) -> Theme? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum ThemeSettings: TypeConstructorDescription {
        case themeSettings(flags: Int32, baseTheme: Api.BaseTheme, accentColor: Int32, outboxAccentColor: Int32?, messageColors: [Int32]?, wallpaper: Api.WallPaper?)

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

        public static func parse_themeSettings(_ reader: BufferReader) -> ThemeSettings? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum Timezone: TypeConstructorDescription {
        case timezone(id: String, name: String, utcOffset: Int32)

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

        public static func parse_timezone(_ reader: BufferReader) -> Timezone? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum TodoCompletion: TypeConstructorDescription {
        case todoCompletion(id: Int32, completedBy: Api.Peer, date: Int32)

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

        public static func parse_todoCompletion(_ reader: BufferReader) -> TodoCompletion? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum TodoItem: TypeConstructorDescription {
        case todoItem(id: Int32, title: Api.TextWithEntities)

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

        public static func parse_todoItem(_ reader: BufferReader) -> TodoItem? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum TodoList: TypeConstructorDescription {
        case todoList(flags: Int32, title: Api.TextWithEntities, list: [Api.TodoItem])

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

        public static func parse_todoList(_ reader: BufferReader) -> TodoList? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum TopPeer: TypeConstructorDescription {
        case topPeer(peer: Api.Peer, rating: Double)

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

        public static func parse_topPeer(_ reader: BufferReader) -> TopPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum TopPeerCategory: TypeConstructorDescription {
        case topPeerCategoryBotsApp
        case topPeerCategoryBotsInline
        case topPeerCategoryBotsPM
        case topPeerCategoryChannels
        case topPeerCategoryCorrespondents
        case topPeerCategoryForwardChats
        case topPeerCategoryForwardUsers
        case topPeerCategoryGroups
        case topPeerCategoryPhoneCalls

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

        public static func parse_topPeerCategoryBotsApp(_ reader: BufferReader) -> TopPeerCategory? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_topPeerCategoryBotsInline(_ reader: BufferReader) -> TopPeerCategory? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_topPeerCategoryBotsPM(_ reader: BufferReader) -> TopPeerCategory? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_topPeerCategoryChannels(_ reader: BufferReader) -> TopPeerCategory? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_topPeerCategoryCorrespondents(_ reader: BufferReader) -> TopPeerCategory? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_topPeerCategoryForwardChats(_ reader: BufferReader) -> TopPeerCategory? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_topPeerCategoryForwardUsers(_ reader: BufferReader) -> TopPeerCategory? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_topPeerCategoryGroups(_ reader: BufferReader) -> TopPeerCategory? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_topPeerCategoryPhoneCalls(_ reader: BufferReader) -> TopPeerCategory? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum TopPeerCategoryPeers: TypeConstructorDescription {
        case topPeerCategoryPeers(category: Api.TopPeerCategory, count: Int32, peers: [Api.TopPeer])

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

        public static func parse_topPeerCategoryPeers(_ reader: BufferReader) -> TopPeerCategoryPeers? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum Update: TypeConstructorDescription {
        case updateAttachMenuBots
        case updateAutoSaveSettings
        case updateBotBusinessConnect(connection: Api.BotBusinessConnection, qts: Int32)
        case updateBotCallbackQuery(flags: Int32, queryId: Int64, userId: Int64, peer: Api.Peer, msgId: Int32, chatInstance: Int64, data: Buffer?, gameShortName: String?)
        case updateBotChatBoost(peer: Api.Peer, boost: Api.Boost, qts: Int32)
        case updateBotChatInviteRequester(peer: Api.Peer, date: Int32, userId: Int64, about: String, invite: Api.ExportedChatInvite, qts: Int32)
        case updateBotCommands(peer: Api.Peer, botId: Int64, commands: [Api.BotCommand])
        case updateBotDeleteBusinessMessage(connectionId: String, peer: Api.Peer, messages: [Int32], qts: Int32)
        case updateBotEditBusinessMessage(flags: Int32, connectionId: String, message: Api.Message, replyToMessage: Api.Message?, qts: Int32)
        case updateBotInlineQuery(flags: Int32, queryId: Int64, userId: Int64, query: String, geo: Api.GeoPoint?, peerType: Api.InlineQueryPeerType?, offset: String)
        case updateBotInlineSend(flags: Int32, userId: Int64, query: String, geo: Api.GeoPoint?, id: String, msgId: Api.InputBotInlineMessageID?)
        case updateBotMenuButton(botId: Int64, button: Api.BotMenuButton)
        case updateBotMessageReaction(peer: Api.Peer, msgId: Int32, date: Int32, actor: Api.Peer, oldReactions: [Api.Reaction], newReactions: [Api.Reaction], qts: Int32)
        case updateBotMessageReactions(peer: Api.Peer, msgId: Int32, date: Int32, reactions: [Api.ReactionCount], qts: Int32)
        case updateBotNewBusinessMessage(flags: Int32, connectionId: String, message: Api.Message, replyToMessage: Api.Message?, qts: Int32)
        case updateBotPrecheckoutQuery(flags: Int32, queryId: Int64, userId: Int64, payload: Buffer, info: Api.PaymentRequestedInfo?, shippingOptionId: String?, currency: String, totalAmount: Int64)
        case updateBotPurchasedPaidMedia(userId: Int64, payload: String, qts: Int32)
        case updateBotShippingQuery(queryId: Int64, userId: Int64, payload: Buffer, shippingAddress: Api.PostAddress)
        case updateBotStopped(userId: Int64, date: Int32, stopped: Api.Bool, qts: Int32)
        case updateBotWebhookJSON(data: Api.DataJSON)
        case updateBotWebhookJSONQuery(queryId: Int64, data: Api.DataJSON, timeout: Int32)
        case updateBusinessBotCallbackQuery(flags: Int32, queryId: Int64, userId: Int64, connectionId: String, message: Api.Message, replyToMessage: Api.Message?, chatInstance: Int64, data: Buffer?)
        case updateChannel(channelId: Int64)
        case updateChannelAvailableMessages(channelId: Int64, availableMinId: Int32)
        case updateChannelMessageForwards(channelId: Int64, id: Int32, forwards: Int32)
        case updateChannelMessageViews(channelId: Int64, id: Int32, views: Int32)
        case updateChannelParticipant(flags: Int32, channelId: Int64, date: Int32, actorId: Int64, userId: Int64, prevParticipant: Api.ChannelParticipant?, newParticipant: Api.ChannelParticipant?, invite: Api.ExportedChatInvite?, qts: Int32)
        case updateChannelReadMessagesContents(flags: Int32, channelId: Int64, topMsgId: Int32?, savedPeerId: Api.Peer?, messages: [Int32])
        case updateChannelTooLong(flags: Int32, channelId: Int64, pts: Int32?)
        case updateChannelUserTyping(flags: Int32, channelId: Int64, topMsgId: Int32?, fromId: Api.Peer, action: Api.SendMessageAction)
        case updateChannelViewForumAsMessages(channelId: Int64, enabled: Api.Bool)
        case updateChannelWebPage(channelId: Int64, webpage: Api.WebPage, pts: Int32, ptsCount: Int32)
        case updateChat(chatId: Int64)
        case updateChatDefaultBannedRights(peer: Api.Peer, defaultBannedRights: Api.ChatBannedRights, version: Int32)
        case updateChatParticipant(flags: Int32, chatId: Int64, date: Int32, actorId: Int64, userId: Int64, prevParticipant: Api.ChatParticipant?, newParticipant: Api.ChatParticipant?, invite: Api.ExportedChatInvite?, qts: Int32)
        case updateChatParticipantAdd(chatId: Int64, userId: Int64, inviterId: Int64, date: Int32, version: Int32)
        case updateChatParticipantAdmin(chatId: Int64, userId: Int64, isAdmin: Api.Bool, version: Int32)
        case updateChatParticipantDelete(chatId: Int64, userId: Int64, version: Int32)
        case updateChatParticipants(participants: Api.ChatParticipants)
        case updateChatUserTyping(chatId: Int64, fromId: Api.Peer, action: Api.SendMessageAction)
        case updateConfig
        case updateContactsReset
        case updateDcOptions(dcOptions: [Api.DcOption])
        case updateDeleteChannelMessages(channelId: Int64, messages: [Int32], pts: Int32, ptsCount: Int32)
        case updateDeleteGroupCallMessages(call: Api.InputGroupCall, messages: [Int32])
        case updateDeleteMessages(messages: [Int32], pts: Int32, ptsCount: Int32)
        case updateDeleteQuickReply(shortcutId: Int32)
        case updateDeleteQuickReplyMessages(shortcutId: Int32, messages: [Int32])
        case updateDeleteScheduledMessages(flags: Int32, peer: Api.Peer, messages: [Int32], sentMessages: [Int32]?)
        case updateDialogFilter(flags: Int32, id: Int32, filter: Api.DialogFilter?)
        case updateDialogFilterOrder(order: [Int32])
        case updateDialogFilters
        case updateDialogPinned(flags: Int32, folderId: Int32?, peer: Api.DialogPeer)
        case updateDialogUnreadMark(flags: Int32, peer: Api.DialogPeer, savedPeerId: Api.Peer?)
        case updateDraftMessage(flags: Int32, peer: Api.Peer, topMsgId: Int32?, savedPeerId: Api.Peer?, draft: Api.DraftMessage)
        case updateEditChannelMessage(message: Api.Message, pts: Int32, ptsCount: Int32)
        case updateEditMessage(message: Api.Message, pts: Int32, ptsCount: Int32)
        case updateEmojiGameInfo(info: Api.messages.EmojiGameInfo)
        case updateEncryptedChatTyping(chatId: Int32)
        case updateEncryptedMessagesRead(chatId: Int32, maxDate: Int32, date: Int32)
        case updateEncryption(chat: Api.EncryptedChat, date: Int32)
        case updateFavedStickers
        case updateFolderPeers(folderPeers: [Api.FolderPeer], pts: Int32, ptsCount: Int32)
        case updateGeoLiveViewed(peer: Api.Peer, msgId: Int32)
        case updateGroupCall(flags: Int32, peer: Api.Peer?, call: Api.GroupCall)
        case updateGroupCallChainBlocks(call: Api.InputGroupCall, subChainId: Int32, blocks: [Buffer], nextOffset: Int32)
        case updateGroupCallConnection(flags: Int32, params: Api.DataJSON)
        case updateGroupCallEncryptedMessage(call: Api.InputGroupCall, fromId: Api.Peer, encryptedMessage: Buffer)
        case updateGroupCallMessage(call: Api.InputGroupCall, message: Api.GroupCallMessage)
        case updateGroupCallParticipants(call: Api.InputGroupCall, participants: [Api.GroupCallParticipant], version: Int32)
        case updateInlineBotCallbackQuery(flags: Int32, queryId: Int64, userId: Int64, msgId: Api.InputBotInlineMessageID, chatInstance: Int64, data: Buffer?, gameShortName: String?)
        case updateLangPack(difference: Api.LangPackDifference)
        case updateLangPackTooLong(langCode: String)
        case updateLoginToken
        case updateMessageExtendedMedia(peer: Api.Peer, msgId: Int32, extendedMedia: [Api.MessageExtendedMedia])
        case updateMessageID(id: Int32, randomId: Int64)
        case updateMessagePoll(flags: Int32, pollId: Int64, poll: Api.Poll?, results: Api.PollResults)
        case updateMessagePollVote(pollId: Int64, peer: Api.Peer, options: [Buffer], qts: Int32)
        case updateMessageReactions(flags: Int32, peer: Api.Peer, msgId: Int32, topMsgId: Int32?, savedPeerId: Api.Peer?, reactions: Api.MessageReactions)
        case updateMonoForumNoPaidException(flags: Int32, channelId: Int64, savedPeerId: Api.Peer)
        case updateMoveStickerSetToTop(flags: Int32, stickerset: Int64)
        case updateNewAuthorization(flags: Int32, hash: Int64, date: Int32?, device: String?, location: String?)
        case updateNewChannelMessage(message: Api.Message, pts: Int32, ptsCount: Int32)
        case updateNewEncryptedMessage(message: Api.EncryptedMessage, qts: Int32)
        case updateNewMessage(message: Api.Message, pts: Int32, ptsCount: Int32)
        case updateNewQuickReply(quickReply: Api.QuickReply)
        case updateNewScheduledMessage(message: Api.Message)
        case updateNewStickerSet(stickerset: Api.messages.StickerSet)
        case updateNewStoryReaction(storyId: Int32, peer: Api.Peer, reaction: Api.Reaction)
        case updateNotifySettings(peer: Api.NotifyPeer, notifySettings: Api.PeerNotifySettings)
        case updatePaidReactionPrivacy(private: Api.PaidReactionPrivacy)
        case updatePeerBlocked(flags: Int32, peerId: Api.Peer)
        case updatePeerHistoryTTL(flags: Int32, peer: Api.Peer, ttlPeriod: Int32?)
        case updatePeerLocated(peers: [Api.PeerLocated])
        case updatePeerSettings(peer: Api.Peer, settings: Api.PeerSettings)
        case updatePeerWallpaper(flags: Int32, peer: Api.Peer, wallpaper: Api.WallPaper?)
        case updatePendingJoinRequests(peer: Api.Peer, requestsPending: Int32, recentRequesters: [Int64])
        case updatePhoneCall(phoneCall: Api.PhoneCall)
        case updatePhoneCallSignalingData(phoneCallId: Int64, data: Buffer)
        case updatePinnedChannelMessages(flags: Int32, channelId: Int64, messages: [Int32], pts: Int32, ptsCount: Int32)
        case updatePinnedDialogs(flags: Int32, folderId: Int32?, order: [Api.DialogPeer]?)
        case updatePinnedForumTopic(flags: Int32, peer: Api.Peer, topicId: Int32)
        case updatePinnedForumTopics(flags: Int32, peer: Api.Peer, order: [Int32]?)
        case updatePinnedMessages(flags: Int32, peer: Api.Peer, messages: [Int32], pts: Int32, ptsCount: Int32)
        case updatePinnedSavedDialogs(flags: Int32, order: [Api.DialogPeer]?)
        case updatePrivacy(key: Api.PrivacyKey, rules: [Api.PrivacyRule])
        case updatePtsChanged
        case updateQuickReplies(quickReplies: [Api.QuickReply])
        case updateQuickReplyMessage(message: Api.Message)
        case updateReadChannelDiscussionInbox(flags: Int32, channelId: Int64, topMsgId: Int32, readMaxId: Int32, broadcastId: Int64?, broadcastPost: Int32?)
        case updateReadChannelDiscussionOutbox(channelId: Int64, topMsgId: Int32, readMaxId: Int32)
        case updateReadChannelInbox(flags: Int32, folderId: Int32?, channelId: Int64, maxId: Int32, stillUnreadCount: Int32, pts: Int32)
        case updateReadChannelOutbox(channelId: Int64, maxId: Int32)
        case updateReadFeaturedEmojiStickers
        case updateReadFeaturedStickers
        case updateReadHistoryInbox(flags: Int32, folderId: Int32?, peer: Api.Peer, topMsgId: Int32?, maxId: Int32, stillUnreadCount: Int32, pts: Int32, ptsCount: Int32)
        case updateReadHistoryOutbox(peer: Api.Peer, maxId: Int32, pts: Int32, ptsCount: Int32)
        case updateReadMessagesContents(flags: Int32, messages: [Int32], pts: Int32, ptsCount: Int32, date: Int32?)
        case updateReadMonoForumInbox(channelId: Int64, savedPeerId: Api.Peer, readMaxId: Int32)
        case updateReadMonoForumOutbox(channelId: Int64, savedPeerId: Api.Peer, readMaxId: Int32)
        case updateReadStories(peer: Api.Peer, maxId: Int32)
        case updateRecentEmojiStatuses
        case updateRecentReactions
        case updateRecentStickers
        case updateSavedDialogPinned(flags: Int32, peer: Api.DialogPeer)
        case updateSavedGifs
        case updateSavedReactionTags
        case updateSavedRingtones
        case updateSentPhoneCode(sentCode: Api.auth.SentCode)
        case updateSentStoryReaction(peer: Api.Peer, storyId: Int32, reaction: Api.Reaction)
        case updateServiceNotification(flags: Int32, inboxDate: Int32?, type: String, message: String, media: Api.MessageMedia, entities: [Api.MessageEntity])
        case updateSmsJob(jobId: String)
        case updateStarGiftAuctionState(giftId: Int64, state: Api.StarGiftAuctionState)
        case updateStarGiftAuctionUserState(giftId: Int64, userState: Api.StarGiftAuctionUserState)
        case updateStarsBalance(balance: Api.StarsAmount)
        case updateStarsRevenueStatus(peer: Api.Peer, status: Api.StarsRevenueStatus)
        case updateStickerSets(flags: Int32)
        case updateStickerSetsOrder(flags: Int32, order: [Int64])
        case updateStoriesStealthMode(stealthMode: Api.StoriesStealthMode)
        case updateStory(peer: Api.Peer, story: Api.StoryItem)
        case updateStoryID(id: Int32, randomId: Int64)
        case updateTheme(theme: Api.Theme)
        case updateTranscribedAudio(flags: Int32, peer: Api.Peer, msgId: Int32, transcriptionId: Int64, text: String)
        case updateUser(userId: Int64)
        case updateUserEmojiStatus(userId: Int64, emojiStatus: Api.EmojiStatus)
        case updateUserName(userId: Int64, firstName: String, lastName: String, usernames: [Api.Username])
        case updateUserPhone(userId: Int64, phone: String)
        case updateUserStatus(userId: Int64, status: Api.UserStatus)
        case updateUserTyping(flags: Int32, userId: Int64, topMsgId: Int32?, action: Api.SendMessageAction)
        case updateWebPage(webpage: Api.WebPage, pts: Int32, ptsCount: Int32)
        case updateWebViewResultSent(queryId: Int64)

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

        public static func parse_updateAttachMenuBots(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateAutoSaveSettings(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateBotBusinessConnect(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateBotCallbackQuery(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateBotChatBoost(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateBotChatInviteRequester(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateBotCommands(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateBotDeleteBusinessMessage(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateBotEditBusinessMessage(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateBotInlineQuery(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateBotInlineSend(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateBotMenuButton(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateBotMessageReaction(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateBotMessageReactions(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateBotNewBusinessMessage(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateBotPrecheckoutQuery(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateBotPurchasedPaidMedia(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateBotShippingQuery(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateBotStopped(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateBotWebhookJSON(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateBotWebhookJSONQuery(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateBusinessBotCallbackQuery(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateChannel(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateChannelAvailableMessages(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateChannelMessageForwards(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateChannelMessageViews(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateChannelParticipant(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateChannelReadMessagesContents(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateChannelTooLong(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateChannelUserTyping(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateChannelViewForumAsMessages(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateChannelWebPage(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateChat(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateChatDefaultBannedRights(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateChatParticipant(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateChatParticipantAdd(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateChatParticipantAdmin(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateChatParticipantDelete(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateChatParticipants(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateChatUserTyping(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateConfig(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateContactsReset(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateDcOptions(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateDeleteChannelMessages(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateDeleteGroupCallMessages(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateDeleteMessages(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateDeleteQuickReply(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateDeleteQuickReplyMessages(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateDeleteScheduledMessages(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateDialogFilter(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateDialogFilterOrder(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateDialogFilters(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateDialogPinned(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateDialogUnreadMark(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateDraftMessage(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateEditChannelMessage(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateEditMessage(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateEmojiGameInfo(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateEncryptedChatTyping(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateEncryptedMessagesRead(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateEncryption(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateFavedStickers(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateFolderPeers(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateGeoLiveViewed(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateGroupCall(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateGroupCallChainBlocks(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateGroupCallConnection(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateGroupCallEncryptedMessage(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateGroupCallMessage(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateGroupCallParticipants(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateInlineBotCallbackQuery(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateLangPack(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateLangPackTooLong(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateLoginToken(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateMessageExtendedMedia(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateMessageID(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateMessagePoll(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateMessagePollVote(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateMessageReactions(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateMonoForumNoPaidException(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateMoveStickerSetToTop(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateNewAuthorization(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateNewChannelMessage(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateNewEncryptedMessage(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateNewMessage(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateNewQuickReply(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateNewScheduledMessage(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateNewStickerSet(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateNewStoryReaction(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateNotifySettings(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updatePaidReactionPrivacy(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updatePeerBlocked(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updatePeerHistoryTTL(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updatePeerLocated(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updatePeerSettings(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updatePeerWallpaper(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updatePendingJoinRequests(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updatePhoneCall(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updatePhoneCallSignalingData(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updatePinnedChannelMessages(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updatePinnedDialogs(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updatePinnedForumTopic(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updatePinnedForumTopics(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updatePinnedMessages(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updatePinnedSavedDialogs(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updatePrivacy(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updatePtsChanged(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateQuickReplies(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateQuickReplyMessage(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateReadChannelDiscussionInbox(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateReadChannelDiscussionOutbox(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateReadChannelInbox(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateReadChannelOutbox(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateReadFeaturedEmojiStickers(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateReadFeaturedStickers(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateReadHistoryInbox(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateReadHistoryOutbox(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateReadMessagesContents(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateReadMonoForumInbox(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateReadMonoForumOutbox(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateReadStories(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateRecentEmojiStatuses(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateRecentReactions(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateRecentStickers(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateSavedDialogPinned(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateSavedGifs(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateSavedReactionTags(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateSavedRingtones(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateSentPhoneCode(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateSentStoryReaction(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateServiceNotification(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateSmsJob(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateStarGiftAuctionState(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateStarGiftAuctionUserState(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateStarsBalance(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateStarsRevenueStatus(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateStickerSets(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateStickerSetsOrder(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateStoriesStealthMode(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateStory(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateStoryID(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateTheme(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateTranscribedAudio(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateUser(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateUserEmojiStatus(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateUserName(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateUserPhone(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateUserStatus(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateUserTyping(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateWebPage(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateWebViewResultSent(_ reader: BufferReader) -> Update? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
