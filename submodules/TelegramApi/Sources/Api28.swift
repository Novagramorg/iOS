public extension Api {
    enum TopPeerCategoryPeers: TypeConstructorDescription {
        public class Cons_topPeerCategoryPeers {
            public var category: Api.TopPeerCategory
            public var count: Int32
            public var peers: [Api.TopPeer]
            public init(category: Api.TopPeerCategory, count: Int32, peers: [Api.TopPeer]) {
                self.category = category
                self.count = count
                self.peers = peers
            }
        }
        case topPeerCategoryPeers(Cons_topPeerCategoryPeers)

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
        public class Cons_updateBotBusinessConnect {
            public var connection: Api.BotBusinessConnection
            public var qts: Int32
            public init(connection: Api.BotBusinessConnection, qts: Int32) {
                self.connection = connection
                self.qts = qts
            }
        }
        public class Cons_updateBotCallbackQuery {
            public var flags: Int32
            public var queryId: Int64
            public var userId: Int64
            public var peer: Api.Peer
            public var msgId: Int32
            public var chatInstance: Int64
            public var data: Buffer?
            public var gameShortName: String?
            public init(flags: Int32, queryId: Int64, userId: Int64, peer: Api.Peer, msgId: Int32, chatInstance: Int64, data: Buffer?, gameShortName: String?) {
                self.flags = flags
                self.queryId = queryId
                self.userId = userId
                self.peer = peer
                self.msgId = msgId
                self.chatInstance = chatInstance
                self.data = data
                self.gameShortName = gameShortName
            }
        }
        public class Cons_updateBotChatBoost {
            public var peer: Api.Peer
            public var boost: Api.Boost
            public var qts: Int32
            public init(peer: Api.Peer, boost: Api.Boost, qts: Int32) {
                self.peer = peer
                self.boost = boost
                self.qts = qts
            }
        }
        public class Cons_updateBotChatInviteRequester {
            public var peer: Api.Peer
            public var date: Int32
            public var userId: Int64
            public var about: String
            public var invite: Api.ExportedChatInvite
            public var qts: Int32
            public init(peer: Api.Peer, date: Int32, userId: Int64, about: String, invite: Api.ExportedChatInvite, qts: Int32) {
                self.peer = peer
                self.date = date
                self.userId = userId
                self.about = about
                self.invite = invite
                self.qts = qts
            }
        }
        public class Cons_updateBotCommands {
            public var peer: Api.Peer
            public var botId: Int64
            public var commands: [Api.BotCommand]
            public init(peer: Api.Peer, botId: Int64, commands: [Api.BotCommand]) {
                self.peer = peer
                self.botId = botId
                self.commands = commands
            }
        }
        public class Cons_updateBotDeleteBusinessMessage {
            public var connectionId: String
            public var peer: Api.Peer
            public var messages: [Int32]
            public var qts: Int32
            public init(connectionId: String, peer: Api.Peer, messages: [Int32], qts: Int32) {
                self.connectionId = connectionId
                self.peer = peer
                self.messages = messages
                self.qts = qts
            }
        }
        public class Cons_updateBotEditBusinessMessage {
            public var flags: Int32
            public var connectionId: String
            public var message: Api.Message
            public var replyToMessage: Api.Message?
            public var qts: Int32
            public init(flags: Int32, connectionId: String, message: Api.Message, replyToMessage: Api.Message?, qts: Int32) {
                self.flags = flags
                self.connectionId = connectionId
                self.message = message
                self.replyToMessage = replyToMessage
                self.qts = qts
            }
        }
        public class Cons_updateBotInlineQuery {
            public var flags: Int32
            public var queryId: Int64
            public var userId: Int64
            public var query: String
            public var geo: Api.GeoPoint?
            public var peerType: Api.InlineQueryPeerType?
            public var offset: String
            public init(flags: Int32, queryId: Int64, userId: Int64, query: String, geo: Api.GeoPoint?, peerType: Api.InlineQueryPeerType?, offset: String) {
                self.flags = flags
                self.queryId = queryId
                self.userId = userId
                self.query = query
                self.geo = geo
                self.peerType = peerType
                self.offset = offset
            }
        }
        public class Cons_updateBotInlineSend {
            public var flags: Int32
            public var userId: Int64
            public var query: String
            public var geo: Api.GeoPoint?
            public var id: String
            public var msgId: Api.InputBotInlineMessageID?
            public init(flags: Int32, userId: Int64, query: String, geo: Api.GeoPoint?, id: String, msgId: Api.InputBotInlineMessageID?) {
                self.flags = flags
                self.userId = userId
                self.query = query
                self.geo = geo
                self.id = id
                self.msgId = msgId
            }
        }
        public class Cons_updateBotMenuButton {
            public var botId: Int64
            public var button: Api.BotMenuButton
            public init(botId: Int64, button: Api.BotMenuButton) {
                self.botId = botId
                self.button = button
            }
        }
        public class Cons_updateBotMessageReaction {
            public var peer: Api.Peer
            public var msgId: Int32
            public var date: Int32
            public var actor: Api.Peer
            public var oldReactions: [Api.Reaction]
            public var newReactions: [Api.Reaction]
            public var qts: Int32
            public init(peer: Api.Peer, msgId: Int32, date: Int32, actor: Api.Peer, oldReactions: [Api.Reaction], newReactions: [Api.Reaction], qts: Int32) {
                self.peer = peer
                self.msgId = msgId
                self.date = date
                self.actor = actor
                self.oldReactions = oldReactions
                self.newReactions = newReactions
                self.qts = qts
            }
        }
        public class Cons_updateBotMessageReactions {
            public var peer: Api.Peer
            public var msgId: Int32
            public var date: Int32
            public var reactions: [Api.ReactionCount]
            public var qts: Int32
            public init(peer: Api.Peer, msgId: Int32, date: Int32, reactions: [Api.ReactionCount], qts: Int32) {
                self.peer = peer
                self.msgId = msgId
                self.date = date
                self.reactions = reactions
                self.qts = qts
            }
        }
        public class Cons_updateBotNewBusinessMessage {
            public var flags: Int32
            public var connectionId: String
            public var message: Api.Message
            public var replyToMessage: Api.Message?
            public var qts: Int32
            public init(flags: Int32, connectionId: String, message: Api.Message, replyToMessage: Api.Message?, qts: Int32) {
                self.flags = flags
                self.connectionId = connectionId
                self.message = message
                self.replyToMessage = replyToMessage
                self.qts = qts
            }
        }
        public class Cons_updateBotPrecheckoutQuery {
            public var flags: Int32
            public var queryId: Int64
            public var userId: Int64
            public var payload: Buffer
            public var info: Api.PaymentRequestedInfo?
            public var shippingOptionId: String?
            public var currency: String
            public var totalAmount: Int64
            public init(flags: Int32, queryId: Int64, userId: Int64, payload: Buffer, info: Api.PaymentRequestedInfo?, shippingOptionId: String?, currency: String, totalAmount: Int64) {
                self.flags = flags
                self.queryId = queryId
                self.userId = userId
                self.payload = payload
                self.info = info
                self.shippingOptionId = shippingOptionId
                self.currency = currency
                self.totalAmount = totalAmount
            }
        }
        public class Cons_updateBotPurchasedPaidMedia {
            public var userId: Int64
            public var payload: String
            public var qts: Int32
            public init(userId: Int64, payload: String, qts: Int32) {
                self.userId = userId
                self.payload = payload
                self.qts = qts
            }
        }
        public class Cons_updateBotShippingQuery {
            public var queryId: Int64
            public var userId: Int64
            public var payload: Buffer
            public var shippingAddress: Api.PostAddress
            public init(queryId: Int64, userId: Int64, payload: Buffer, shippingAddress: Api.PostAddress) {
                self.queryId = queryId
                self.userId = userId
                self.payload = payload
                self.shippingAddress = shippingAddress
            }
        }
        public class Cons_updateBotStopped {
            public var userId: Int64
            public var date: Int32
            public var stopped: Api.Bool
            public var qts: Int32
            public init(userId: Int64, date: Int32, stopped: Api.Bool, qts: Int32) {
                self.userId = userId
                self.date = date
                self.stopped = stopped
                self.qts = qts
            }
        }
        public class Cons_updateBotWebhookJSON {
            public var data: Api.DataJSON
            public init(data: Api.DataJSON) {
                self.data = data
            }
        }
        public class Cons_updateBotWebhookJSONQuery {
            public var queryId: Int64
            public var data: Api.DataJSON
            public var timeout: Int32
            public init(queryId: Int64, data: Api.DataJSON, timeout: Int32) {
                self.queryId = queryId
                self.data = data
                self.timeout = timeout
            }
        }
        public class Cons_updateBusinessBotCallbackQuery {
            public var flags: Int32
            public var queryId: Int64
            public var userId: Int64
            public var connectionId: String
            public var message: Api.Message
            public var replyToMessage: Api.Message?
            public var chatInstance: Int64
            public var data: Buffer?
            public init(flags: Int32, queryId: Int64, userId: Int64, connectionId: String, message: Api.Message, replyToMessage: Api.Message?, chatInstance: Int64, data: Buffer?) {
                self.flags = flags
                self.queryId = queryId
                self.userId = userId
                self.connectionId = connectionId
                self.message = message
                self.replyToMessage = replyToMessage
                self.chatInstance = chatInstance
                self.data = data
            }
        }
        public class Cons_updateChannel {
            public var channelId: Int64
            public init(channelId: Int64) {
                self.channelId = channelId
            }
        }
        public class Cons_updateChannelAvailableMessages {
            public var channelId: Int64
            public var availableMinId: Int32
            public init(channelId: Int64, availableMinId: Int32) {
                self.channelId = channelId
                self.availableMinId = availableMinId
            }
        }
        public class Cons_updateChannelMessageForwards {
            public var channelId: Int64
            public var id: Int32
            public var forwards: Int32
            public init(channelId: Int64, id: Int32, forwards: Int32) {
                self.channelId = channelId
                self.id = id
                self.forwards = forwards
            }
        }
        public class Cons_updateChannelMessageViews {
            public var channelId: Int64
            public var id: Int32
            public var views: Int32
            public init(channelId: Int64, id: Int32, views: Int32) {
                self.channelId = channelId
                self.id = id
                self.views = views
            }
        }
        public class Cons_updateChannelParticipant {
            public var flags: Int32
            public var channelId: Int64
            public var date: Int32
            public var actorId: Int64
            public var userId: Int64
            public var prevParticipant: Api.ChannelParticipant?
            public var newParticipant: Api.ChannelParticipant?
            public var invite: Api.ExportedChatInvite?
            public var qts: Int32
            public init(flags: Int32, channelId: Int64, date: Int32, actorId: Int64, userId: Int64, prevParticipant: Api.ChannelParticipant?, newParticipant: Api.ChannelParticipant?, invite: Api.ExportedChatInvite?, qts: Int32) {
                self.flags = flags
                self.channelId = channelId
                self.date = date
                self.actorId = actorId
                self.userId = userId
                self.prevParticipant = prevParticipant
                self.newParticipant = newParticipant
                self.invite = invite
                self.qts = qts
            }
        }
        public class Cons_updateChannelReadMessagesContents {
            public var flags: Int32
            public var channelId: Int64
            public var topMsgId: Int32?
            public var savedPeerId: Api.Peer?
            public var messages: [Int32]
            public init(flags: Int32, channelId: Int64, topMsgId: Int32?, savedPeerId: Api.Peer?, messages: [Int32]) {
                self.flags = flags
                self.channelId = channelId
                self.topMsgId = topMsgId
                self.savedPeerId = savedPeerId
                self.messages = messages
            }
        }
        public class Cons_updateChannelTooLong {
            public var flags: Int32
            public var channelId: Int64
            public var pts: Int32?
            public init(flags: Int32, channelId: Int64, pts: Int32?) {
                self.flags = flags
                self.channelId = channelId
                self.pts = pts
            }
        }
        public class Cons_updateChannelUserTyping {
            public var flags: Int32
            public var channelId: Int64
            public var topMsgId: Int32?
            public var fromId: Api.Peer
            public var action: Api.SendMessageAction
            public init(flags: Int32, channelId: Int64, topMsgId: Int32?, fromId: Api.Peer, action: Api.SendMessageAction) {
                self.flags = flags
                self.channelId = channelId
                self.topMsgId = topMsgId
                self.fromId = fromId
                self.action = action
            }
        }
        public class Cons_updateChannelViewForumAsMessages {
            public var channelId: Int64
            public var enabled: Api.Bool
            public init(channelId: Int64, enabled: Api.Bool) {
                self.channelId = channelId
                self.enabled = enabled
            }
        }
        public class Cons_updateChannelWebPage {
            public var channelId: Int64
            public var webpage: Api.WebPage
            public var pts: Int32
            public var ptsCount: Int32
            public init(channelId: Int64, webpage: Api.WebPage, pts: Int32, ptsCount: Int32) {
                self.channelId = channelId
                self.webpage = webpage
                self.pts = pts
                self.ptsCount = ptsCount
            }
        }
        public class Cons_updateChat {
            public var chatId: Int64
            public init(chatId: Int64) {
                self.chatId = chatId
            }
        }
        public class Cons_updateChatDefaultBannedRights {
            public var peer: Api.Peer
            public var defaultBannedRights: Api.ChatBannedRights
            public var version: Int32
            public init(peer: Api.Peer, defaultBannedRights: Api.ChatBannedRights, version: Int32) {
                self.peer = peer
                self.defaultBannedRights = defaultBannedRights
                self.version = version
            }
        }
        public class Cons_updateChatParticipant {
            public var flags: Int32
            public var chatId: Int64
            public var date: Int32
            public var actorId: Int64
            public var userId: Int64
            public var prevParticipant: Api.ChatParticipant?
            public var newParticipant: Api.ChatParticipant?
            public var invite: Api.ExportedChatInvite?
            public var qts: Int32
            public init(flags: Int32, chatId: Int64, date: Int32, actorId: Int64, userId: Int64, prevParticipant: Api.ChatParticipant?, newParticipant: Api.ChatParticipant?, invite: Api.ExportedChatInvite?, qts: Int32) {
                self.flags = flags
                self.chatId = chatId
                self.date = date
                self.actorId = actorId
                self.userId = userId
                self.prevParticipant = prevParticipant
                self.newParticipant = newParticipant
                self.invite = invite
                self.qts = qts
            }
        }
        public class Cons_updateChatParticipantAdd {
            public var chatId: Int64
            public var userId: Int64
            public var inviterId: Int64
            public var date: Int32
            public var version: Int32
            public init(chatId: Int64, userId: Int64, inviterId: Int64, date: Int32, version: Int32) {
                self.chatId = chatId
                self.userId = userId
                self.inviterId = inviterId
                self.date = date
                self.version = version
            }
        }
        public class Cons_updateChatParticipantAdmin {
            public var chatId: Int64
            public var userId: Int64
            public var isAdmin: Api.Bool
            public var version: Int32
            public init(chatId: Int64, userId: Int64, isAdmin: Api.Bool, version: Int32) {
                self.chatId = chatId
                self.userId = userId
                self.isAdmin = isAdmin
                self.version = version
            }
        }
        public class Cons_updateChatParticipantDelete {
            public var chatId: Int64
            public var userId: Int64
            public var version: Int32
            public init(chatId: Int64, userId: Int64, version: Int32) {
                self.chatId = chatId
                self.userId = userId
                self.version = version
            }
        }
        public class Cons_updateChatParticipants {
            public var participants: Api.ChatParticipants
            public init(participants: Api.ChatParticipants) {
                self.participants = participants
            }
        }
        public class Cons_updateChatUserTyping {
            public var chatId: Int64
            public var fromId: Api.Peer
            public var action: Api.SendMessageAction
            public init(chatId: Int64, fromId: Api.Peer, action: Api.SendMessageAction) {
                self.chatId = chatId
                self.fromId = fromId
                self.action = action
            }
        }
        public class Cons_updateDcOptions {
            public var dcOptions: [Api.DcOption]
            public init(dcOptions: [Api.DcOption]) {
                self.dcOptions = dcOptions
            }
        }
        public class Cons_updateDeleteChannelMessages {
            public var channelId: Int64
            public var messages: [Int32]
            public var pts: Int32
            public var ptsCount: Int32
            public init(channelId: Int64, messages: [Int32], pts: Int32, ptsCount: Int32) {
                self.channelId = channelId
                self.messages = messages
                self.pts = pts
                self.ptsCount = ptsCount
            }
        }
        public class Cons_updateDeleteGroupCallMessages {
            public var call: Api.InputGroupCall
            public var messages: [Int32]
            public init(call: Api.InputGroupCall, messages: [Int32]) {
                self.call = call
                self.messages = messages
            }
        }
        public class Cons_updateDeleteMessages {
            public var messages: [Int32]
            public var pts: Int32
            public var ptsCount: Int32
            public init(messages: [Int32], pts: Int32, ptsCount: Int32) {
                self.messages = messages
                self.pts = pts
                self.ptsCount = ptsCount
            }
        }
        public class Cons_updateDeleteQuickReply {
            public var shortcutId: Int32
            public init(shortcutId: Int32) {
                self.shortcutId = shortcutId
            }
        }
        public class Cons_updateDeleteQuickReplyMessages {
            public var shortcutId: Int32
            public var messages: [Int32]
            public init(shortcutId: Int32, messages: [Int32]) {
                self.shortcutId = shortcutId
                self.messages = messages
            }
        }
        public class Cons_updateDeleteScheduledMessages {
            public var flags: Int32
            public var peer: Api.Peer
            public var messages: [Int32]
            public var sentMessages: [Int32]?
            public init(flags: Int32, peer: Api.Peer, messages: [Int32], sentMessages: [Int32]?) {
                self.flags = flags
                self.peer = peer
                self.messages = messages
                self.sentMessages = sentMessages
            }
        }
        public class Cons_updateDialogFilter {
            public var flags: Int32
            public var id: Int32
            public var filter: Api.DialogFilter?
            public init(flags: Int32, id: Int32, filter: Api.DialogFilter?) {
                self.flags = flags
                self.id = id
                self.filter = filter
            }
        }
        public class Cons_updateDialogFilterOrder {
            public var order: [Int32]
            public init(order: [Int32]) {
                self.order = order
            }
        }
        public class Cons_updateDialogPinned {
            public var flags: Int32
            public var folderId: Int32?
            public var peer: Api.DialogPeer
            public init(flags: Int32, folderId: Int32?, peer: Api.DialogPeer) {
                self.flags = flags
                self.folderId = folderId
                self.peer = peer
            }
        }
        public class Cons_updateDialogUnreadMark {
            public var flags: Int32
            public var peer: Api.DialogPeer
            public var savedPeerId: Api.Peer?
            public init(flags: Int32, peer: Api.DialogPeer, savedPeerId: Api.Peer?) {
                self.flags = flags
                self.peer = peer
                self.savedPeerId = savedPeerId
            }
        }
        public class Cons_updateDraftMessage {
            public var flags: Int32
            public var peer: Api.Peer
            public var topMsgId: Int32?
            public var savedPeerId: Api.Peer?
            public var draft: Api.DraftMessage
            public init(flags: Int32, peer: Api.Peer, topMsgId: Int32?, savedPeerId: Api.Peer?, draft: Api.DraftMessage) {
                self.flags = flags
                self.peer = peer
                self.topMsgId = topMsgId
                self.savedPeerId = savedPeerId
                self.draft = draft
            }
        }
        public class Cons_updateEditChannelMessage {
            public var message: Api.Message
            public var pts: Int32
            public var ptsCount: Int32
            public init(message: Api.Message, pts: Int32, ptsCount: Int32) {
                self.message = message
                self.pts = pts
                self.ptsCount = ptsCount
            }
        }
        public class Cons_updateEditMessage {
            public var message: Api.Message
            public var pts: Int32
            public var ptsCount: Int32
            public init(message: Api.Message, pts: Int32, ptsCount: Int32) {
                self.message = message
                self.pts = pts
                self.ptsCount = ptsCount
            }
        }
        public class Cons_updateEmojiGameInfo {
            public var info: Api.messages.EmojiGameInfo
            public init(info: Api.messages.EmojiGameInfo) {
                self.info = info
            }
        }
        public class Cons_updateEncryptedChatTyping {
            public var chatId: Int32
            public init(chatId: Int32) {
                self.chatId = chatId
            }
        }
        public class Cons_updateEncryptedMessagesRead {
            public var chatId: Int32
            public var maxDate: Int32
            public var date: Int32
            public init(chatId: Int32, maxDate: Int32, date: Int32) {
                self.chatId = chatId
                self.maxDate = maxDate
                self.date = date
            }
        }
        public class Cons_updateEncryption {
            public var chat: Api.EncryptedChat
            public var date: Int32
            public init(chat: Api.EncryptedChat, date: Int32) {
                self.chat = chat
                self.date = date
            }
        }
        public class Cons_updateFolderPeers {
            public var folderPeers: [Api.FolderPeer]
            public var pts: Int32
            public var ptsCount: Int32
            public init(folderPeers: [Api.FolderPeer], pts: Int32, ptsCount: Int32) {
                self.folderPeers = folderPeers
                self.pts = pts
                self.ptsCount = ptsCount
            }
        }
        public class Cons_updateGeoLiveViewed {
            public var peer: Api.Peer
            public var msgId: Int32
            public init(peer: Api.Peer, msgId: Int32) {
                self.peer = peer
                self.msgId = msgId
            }
        }
        public class Cons_updateGroupCall {
            public var flags: Int32
            public var peer: Api.Peer?
            public var call: Api.GroupCall
            public init(flags: Int32, peer: Api.Peer?, call: Api.GroupCall) {
                self.flags = flags
                self.peer = peer
                self.call = call
            }
        }
        public class Cons_updateGroupCallChainBlocks {
            public var call: Api.InputGroupCall
            public var subChainId: Int32
            public var blocks: [Buffer]
            public var nextOffset: Int32
            public init(call: Api.InputGroupCall, subChainId: Int32, blocks: [Buffer], nextOffset: Int32) {
                self.call = call
                self.subChainId = subChainId
                self.blocks = blocks
                self.nextOffset = nextOffset
            }
        }
        public class Cons_updateGroupCallConnection {
            public var flags: Int32
            public var params: Api.DataJSON
            public init(flags: Int32, params: Api.DataJSON) {
                self.flags = flags
                self.params = params
            }
        }
        public class Cons_updateGroupCallEncryptedMessage {
            public var call: Api.InputGroupCall
            public var fromId: Api.Peer
            public var encryptedMessage: Buffer
            public init(call: Api.InputGroupCall, fromId: Api.Peer, encryptedMessage: Buffer) {
                self.call = call
                self.fromId = fromId
                self.encryptedMessage = encryptedMessage
            }
        }
        public class Cons_updateGroupCallMessage {
            public var call: Api.InputGroupCall
            public var message: Api.GroupCallMessage
            public init(call: Api.InputGroupCall, message: Api.GroupCallMessage) {
                self.call = call
                self.message = message
            }
        }
        public class Cons_updateGroupCallParticipants {
            public var call: Api.InputGroupCall
            public var participants: [Api.GroupCallParticipant]
            public var version: Int32
            public init(call: Api.InputGroupCall, participants: [Api.GroupCallParticipant], version: Int32) {
                self.call = call
                self.participants = participants
                self.version = version
            }
        }
        public class Cons_updateInlineBotCallbackQuery {
            public var flags: Int32
            public var queryId: Int64
            public var userId: Int64
            public var msgId: Api.InputBotInlineMessageID
            public var chatInstance: Int64
            public var data: Buffer?
            public var gameShortName: String?
            public init(flags: Int32, queryId: Int64, userId: Int64, msgId: Api.InputBotInlineMessageID, chatInstance: Int64, data: Buffer?, gameShortName: String?) {
                self.flags = flags
                self.queryId = queryId
                self.userId = userId
                self.msgId = msgId
                self.chatInstance = chatInstance
                self.data = data
                self.gameShortName = gameShortName
            }
        }
        public class Cons_updateLangPack {
            public var difference: Api.LangPackDifference
            public init(difference: Api.LangPackDifference) {
                self.difference = difference
            }
        }
        public class Cons_updateLangPackTooLong {
            public var langCode: String
            public init(langCode: String) {
                self.langCode = langCode
            }
        }
        public class Cons_updateMessageExtendedMedia {
            public var peer: Api.Peer
            public var msgId: Int32
            public var extendedMedia: [Api.MessageExtendedMedia]
            public init(peer: Api.Peer, msgId: Int32, extendedMedia: [Api.MessageExtendedMedia]) {
                self.peer = peer
                self.msgId = msgId
                self.extendedMedia = extendedMedia
            }
        }
        public class Cons_updateMessageID {
            public var id: Int32
            public var randomId: Int64
            public init(id: Int32, randomId: Int64) {
                self.id = id
                self.randomId = randomId
            }
        }
        public class Cons_updateMessagePoll {
            public var flags: Int32
            public var pollId: Int64
            public var poll: Api.Poll?
            public var results: Api.PollResults
            public init(flags: Int32, pollId: Int64, poll: Api.Poll?, results: Api.PollResults) {
                self.flags = flags
                self.pollId = pollId
                self.poll = poll
                self.results = results
            }
        }
        public class Cons_updateMessagePollVote {
            public var pollId: Int64
            public var peer: Api.Peer
            public var options: [Buffer]
            public var qts: Int32
            public init(pollId: Int64, peer: Api.Peer, options: [Buffer], qts: Int32) {
                self.pollId = pollId
                self.peer = peer
                self.options = options
                self.qts = qts
            }
        }
        public class Cons_updateMessageReactions {
            public var flags: Int32
            public var peer: Api.Peer
            public var msgId: Int32
            public var topMsgId: Int32?
            public var savedPeerId: Api.Peer?
            public var reactions: Api.MessageReactions
            public init(flags: Int32, peer: Api.Peer, msgId: Int32, topMsgId: Int32?, savedPeerId: Api.Peer?, reactions: Api.MessageReactions) {
                self.flags = flags
                self.peer = peer
                self.msgId = msgId
                self.topMsgId = topMsgId
                self.savedPeerId = savedPeerId
                self.reactions = reactions
            }
        }
        public class Cons_updateMonoForumNoPaidException {
            public var flags: Int32
            public var channelId: Int64
            public var savedPeerId: Api.Peer
            public init(flags: Int32, channelId: Int64, savedPeerId: Api.Peer) {
                self.flags = flags
                self.channelId = channelId
                self.savedPeerId = savedPeerId
            }
        }
        public class Cons_updateMoveStickerSetToTop {
            public var flags: Int32
            public var stickerset: Int64
            public init(flags: Int32, stickerset: Int64) {
                self.flags = flags
                self.stickerset = stickerset
            }
        }
        public class Cons_updateNewAuthorization {
            public var flags: Int32
            public var hash: Int64
            public var date: Int32?
            public var device: String?
            public var location: String?
            public init(flags: Int32, hash: Int64, date: Int32?, device: String?, location: String?) {
                self.flags = flags
                self.hash = hash
                self.date = date
                self.device = device
                self.location = location
            }
        }
        public class Cons_updateNewChannelMessage {
            public var message: Api.Message
            public var pts: Int32
            public var ptsCount: Int32
            public init(message: Api.Message, pts: Int32, ptsCount: Int32) {
                self.message = message
                self.pts = pts
                self.ptsCount = ptsCount
            }
        }
        public class Cons_updateNewEncryptedMessage {
            public var message: Api.EncryptedMessage
            public var qts: Int32
            public init(message: Api.EncryptedMessage, qts: Int32) {
                self.message = message
                self.qts = qts
            }
        }
        public class Cons_updateNewMessage {
            public var message: Api.Message
            public var pts: Int32
            public var ptsCount: Int32
            public init(message: Api.Message, pts: Int32, ptsCount: Int32) {
                self.message = message
                self.pts = pts
                self.ptsCount = ptsCount
            }
        }
        public class Cons_updateNewQuickReply {
            public var quickReply: Api.QuickReply
            public init(quickReply: Api.QuickReply) {
                self.quickReply = quickReply
            }
        }
        public class Cons_updateNewScheduledMessage {
            public var message: Api.Message
            public init(message: Api.Message) {
                self.message = message
            }
        }
        public class Cons_updateNewStickerSet {
            public var stickerset: Api.messages.StickerSet
            public init(stickerset: Api.messages.StickerSet) {
                self.stickerset = stickerset
            }
        }
        public class Cons_updateNewStoryReaction {
            public var storyId: Int32
            public var peer: Api.Peer
            public var reaction: Api.Reaction
            public init(storyId: Int32, peer: Api.Peer, reaction: Api.Reaction) {
                self.storyId = storyId
                self.peer = peer
                self.reaction = reaction
            }
        }
        public class Cons_updateNotifySettings {
            public var peer: Api.NotifyPeer
            public var notifySettings: Api.PeerNotifySettings
            public init(peer: Api.NotifyPeer, notifySettings: Api.PeerNotifySettings) {
                self.peer = peer
                self.notifySettings = notifySettings
            }
        }
        public class Cons_updatePaidReactionPrivacy {
            public var `private`: Api.PaidReactionPrivacy
            public init(`private`: Api.PaidReactionPrivacy) {
                self.`private` = `private`
            }
        }
        public class Cons_updatePeerBlocked {
            public var flags: Int32
            public var peerId: Api.Peer
            public init(flags: Int32, peerId: Api.Peer) {
                self.flags = flags
                self.peerId = peerId
            }
        }
        public class Cons_updatePeerHistoryTTL {
            public var flags: Int32
            public var peer: Api.Peer
            public var ttlPeriod: Int32?
            public init(flags: Int32, peer: Api.Peer, ttlPeriod: Int32?) {
                self.flags = flags
                self.peer = peer
                self.ttlPeriod = ttlPeriod
            }
        }
        public class Cons_updatePeerLocated {
            public var peers: [Api.PeerLocated]
            public init(peers: [Api.PeerLocated]) {
                self.peers = peers
            }
        }
        public class Cons_updatePeerSettings {
            public var peer: Api.Peer
            public var settings: Api.PeerSettings
            public init(peer: Api.Peer, settings: Api.PeerSettings) {
                self.peer = peer
                self.settings = settings
            }
        }
        public class Cons_updatePeerWallpaper {
            public var flags: Int32
            public var peer: Api.Peer
            public var wallpaper: Api.WallPaper?
            public init(flags: Int32, peer: Api.Peer, wallpaper: Api.WallPaper?) {
                self.flags = flags
                self.peer = peer
                self.wallpaper = wallpaper
            }
        }
        public class Cons_updatePendingJoinRequests {
            public var peer: Api.Peer
            public var requestsPending: Int32
            public var recentRequesters: [Int64]
            public init(peer: Api.Peer, requestsPending: Int32, recentRequesters: [Int64]) {
                self.peer = peer
                self.requestsPending = requestsPending
                self.recentRequesters = recentRequesters
            }
        }
        public class Cons_updatePhoneCall {
            public var phoneCall: Api.PhoneCall
            public init(phoneCall: Api.PhoneCall) {
                self.phoneCall = phoneCall
            }
        }
        public class Cons_updatePhoneCallSignalingData {
            public var phoneCallId: Int64
            public var data: Buffer
            public init(phoneCallId: Int64, data: Buffer) {
                self.phoneCallId = phoneCallId
                self.data = data
            }
        }
        public class Cons_updatePinnedChannelMessages {
            public var flags: Int32
            public var channelId: Int64
            public var messages: [Int32]
            public var pts: Int32
            public var ptsCount: Int32
            public init(flags: Int32, channelId: Int64, messages: [Int32], pts: Int32, ptsCount: Int32) {
                self.flags = flags
                self.channelId = channelId
                self.messages = messages
                self.pts = pts
                self.ptsCount = ptsCount
            }
        }
        public class Cons_updatePinnedDialogs {
            public var flags: Int32
            public var folderId: Int32?
            public var order: [Api.DialogPeer]?
            public init(flags: Int32, folderId: Int32?, order: [Api.DialogPeer]?) {
                self.flags = flags
                self.folderId = folderId
                self.order = order
            }
        }
        public class Cons_updatePinnedForumTopic {
            public var flags: Int32
            public var peer: Api.Peer
            public var topicId: Int32
            public init(flags: Int32, peer: Api.Peer, topicId: Int32) {
                self.flags = flags
                self.peer = peer
                self.topicId = topicId
            }
        }
        public class Cons_updatePinnedForumTopics {
            public var flags: Int32
            public var peer: Api.Peer
            public var order: [Int32]?
            public init(flags: Int32, peer: Api.Peer, order: [Int32]?) {
                self.flags = flags
                self.peer = peer
                self.order = order
            }
        }
        public class Cons_updatePinnedMessages {
            public var flags: Int32
            public var peer: Api.Peer
            public var messages: [Int32]
            public var pts: Int32
            public var ptsCount: Int32
            public init(flags: Int32, peer: Api.Peer, messages: [Int32], pts: Int32, ptsCount: Int32) {
                self.flags = flags
                self.peer = peer
                self.messages = messages
                self.pts = pts
                self.ptsCount = ptsCount
            }
        }
        public class Cons_updatePinnedSavedDialogs {
            public var flags: Int32
            public var order: [Api.DialogPeer]?
            public init(flags: Int32, order: [Api.DialogPeer]?) {
                self.flags = flags
                self.order = order
            }
        }
        public class Cons_updatePrivacy {
            public var key: Api.PrivacyKey
            public var rules: [Api.PrivacyRule]
            public init(key: Api.PrivacyKey, rules: [Api.PrivacyRule]) {
                self.key = key
                self.rules = rules
            }
        }
        public class Cons_updateQuickReplies {
            public var quickReplies: [Api.QuickReply]
            public init(quickReplies: [Api.QuickReply]) {
                self.quickReplies = quickReplies
            }
        }
        public class Cons_updateQuickReplyMessage {
            public var message: Api.Message
            public init(message: Api.Message) {
                self.message = message
            }
        }
        public class Cons_updateReadChannelDiscussionInbox {
            public var flags: Int32
            public var channelId: Int64
            public var topMsgId: Int32
            public var readMaxId: Int32
            public var broadcastId: Int64?
            public var broadcastPost: Int32?
            public init(flags: Int32, channelId: Int64, topMsgId: Int32, readMaxId: Int32, broadcastId: Int64?, broadcastPost: Int32?) {
                self.flags = flags
                self.channelId = channelId
                self.topMsgId = topMsgId
                self.readMaxId = readMaxId
                self.broadcastId = broadcastId
                self.broadcastPost = broadcastPost
            }
        }
        public class Cons_updateReadChannelDiscussionOutbox {
            public var channelId: Int64
            public var topMsgId: Int32
            public var readMaxId: Int32
            public init(channelId: Int64, topMsgId: Int32, readMaxId: Int32) {
                self.channelId = channelId
                self.topMsgId = topMsgId
                self.readMaxId = readMaxId
            }
        }
        public class Cons_updateReadChannelInbox {
            public var flags: Int32
            public var folderId: Int32?
            public var channelId: Int64
            public var maxId: Int32
            public var stillUnreadCount: Int32
            public var pts: Int32
            public init(flags: Int32, folderId: Int32?, channelId: Int64, maxId: Int32, stillUnreadCount: Int32, pts: Int32) {
                self.flags = flags
                self.folderId = folderId
                self.channelId = channelId
                self.maxId = maxId
                self.stillUnreadCount = stillUnreadCount
                self.pts = pts
            }
        }
        public class Cons_updateReadChannelOutbox {
            public var channelId: Int64
            public var maxId: Int32
            public init(channelId: Int64, maxId: Int32) {
                self.channelId = channelId
                self.maxId = maxId
            }
        }
        public class Cons_updateReadHistoryInbox {
            public var flags: Int32
            public var folderId: Int32?
            public var peer: Api.Peer
            public var topMsgId: Int32?
            public var maxId: Int32
            public var stillUnreadCount: Int32
            public var pts: Int32
            public var ptsCount: Int32
            public init(flags: Int32, folderId: Int32?, peer: Api.Peer, topMsgId: Int32?, maxId: Int32, stillUnreadCount: Int32, pts: Int32, ptsCount: Int32) {
                self.flags = flags
                self.folderId = folderId
                self.peer = peer
                self.topMsgId = topMsgId
                self.maxId = maxId
                self.stillUnreadCount = stillUnreadCount
                self.pts = pts
                self.ptsCount = ptsCount
            }
        }
        public class Cons_updateReadHistoryOutbox {
            public var peer: Api.Peer
            public var maxId: Int32
            public var pts: Int32
            public var ptsCount: Int32
            public init(peer: Api.Peer, maxId: Int32, pts: Int32, ptsCount: Int32) {
                self.peer = peer
                self.maxId = maxId
                self.pts = pts
                self.ptsCount = ptsCount
            }
        }
        public class Cons_updateReadMessagesContents {
            public var flags: Int32
            public var messages: [Int32]
            public var pts: Int32
            public var ptsCount: Int32
            public var date: Int32?
            public init(flags: Int32, messages: [Int32], pts: Int32, ptsCount: Int32, date: Int32?) {
                self.flags = flags
                self.messages = messages
                self.pts = pts
                self.ptsCount = ptsCount
                self.date = date
            }
        }
        public class Cons_updateReadMonoForumInbox {
            public var channelId: Int64
            public var savedPeerId: Api.Peer
            public var readMaxId: Int32
            public init(channelId: Int64, savedPeerId: Api.Peer, readMaxId: Int32) {
                self.channelId = channelId
                self.savedPeerId = savedPeerId
                self.readMaxId = readMaxId
            }
        }
        public class Cons_updateReadMonoForumOutbox {
            public var channelId: Int64
            public var savedPeerId: Api.Peer
            public var readMaxId: Int32
            public init(channelId: Int64, savedPeerId: Api.Peer, readMaxId: Int32) {
                self.channelId = channelId
                self.savedPeerId = savedPeerId
                self.readMaxId = readMaxId
            }
        }
        public class Cons_updateReadStories {
            public var peer: Api.Peer
            public var maxId: Int32
            public init(peer: Api.Peer, maxId: Int32) {
                self.peer = peer
                self.maxId = maxId
            }
        }
        public class Cons_updateSavedDialogPinned {
            public var flags: Int32
            public var peer: Api.DialogPeer
            public init(flags: Int32, peer: Api.DialogPeer) {
                self.flags = flags
                self.peer = peer
            }
        }
        public class Cons_updateSentPhoneCode {
            public var sentCode: Api.auth.SentCode
            public init(sentCode: Api.auth.SentCode) {
                self.sentCode = sentCode
            }
        }
        public class Cons_updateSentStoryReaction {
            public var peer: Api.Peer
            public var storyId: Int32
            public var reaction: Api.Reaction
            public init(peer: Api.Peer, storyId: Int32, reaction: Api.Reaction) {
                self.peer = peer
                self.storyId = storyId
                self.reaction = reaction
            }
        }
        public class Cons_updateServiceNotification {
            public var flags: Int32
            public var inboxDate: Int32?
            public var type: String
            public var message: String
            public var media: Api.MessageMedia
            public var entities: [Api.MessageEntity]
            public init(flags: Int32, inboxDate: Int32?, type: String, message: String, media: Api.MessageMedia, entities: [Api.MessageEntity]) {
                self.flags = flags
                self.inboxDate = inboxDate
                self.type = type
                self.message = message
                self.media = media
                self.entities = entities
            }
        }
        public class Cons_updateSmsJob {
            public var jobId: String
            public init(jobId: String) {
                self.jobId = jobId
            }
        }
        public class Cons_updateStarGiftAuctionState {
            public var giftId: Int64
            public var state: Api.StarGiftAuctionState
            public init(giftId: Int64, state: Api.StarGiftAuctionState) {
                self.giftId = giftId
                self.state = state
            }
        }
        public class Cons_updateStarGiftAuctionUserState {
            public var giftId: Int64
            public var userState: Api.StarGiftAuctionUserState
            public init(giftId: Int64, userState: Api.StarGiftAuctionUserState) {
                self.giftId = giftId
                self.userState = userState
            }
        }
        public class Cons_updateStarsBalance {
            public var balance: Api.StarsAmount
            public init(balance: Api.StarsAmount) {
                self.balance = balance
            }
        }
        public class Cons_updateStarsRevenueStatus {
            public var peer: Api.Peer
            public var status: Api.StarsRevenueStatus
            public init(peer: Api.Peer, status: Api.StarsRevenueStatus) {
                self.peer = peer
                self.status = status
            }
        }
        public class Cons_updateStickerSets {
            public var flags: Int32
            public init(flags: Int32) {
                self.flags = flags
            }
        }
        public class Cons_updateStickerSetsOrder {
            public var flags: Int32
            public var order: [Int64]
            public init(flags: Int32, order: [Int64]) {
                self.flags = flags
                self.order = order
            }
        }
        public class Cons_updateStoriesStealthMode {
            public var stealthMode: Api.StoriesStealthMode
            public init(stealthMode: Api.StoriesStealthMode) {
                self.stealthMode = stealthMode
            }
        }
        public class Cons_updateStory {
            public var peer: Api.Peer
            public var story: Api.StoryItem
            public init(peer: Api.Peer, story: Api.StoryItem) {
                self.peer = peer
                self.story = story
            }
        }
        public class Cons_updateStoryID {
            public var id: Int32
            public var randomId: Int64
            public init(id: Int32, randomId: Int64) {
                self.id = id
                self.randomId = randomId
            }
        }
        public class Cons_updateTheme {
            public var theme: Api.Theme
            public init(theme: Api.Theme) {
                self.theme = theme
            }
        }
        public class Cons_updateTranscribedAudio {
            public var flags: Int32
            public var peer: Api.Peer
            public var msgId: Int32
            public var transcriptionId: Int64
            public var text: String
            public init(flags: Int32, peer: Api.Peer, msgId: Int32, transcriptionId: Int64, text: String) {
                self.flags = flags
                self.peer = peer
                self.msgId = msgId
                self.transcriptionId = transcriptionId
                self.text = text
            }
        }
        public class Cons_updateUser {
            public var userId: Int64
            public init(userId: Int64) {
                self.userId = userId
            }
        }
        public class Cons_updateUserEmojiStatus {
            public var userId: Int64
            public var emojiStatus: Api.EmojiStatus
            public init(userId: Int64, emojiStatus: Api.EmojiStatus) {
                self.userId = userId
                self.emojiStatus = emojiStatus
            }
        }
        public class Cons_updateUserName {
            public var userId: Int64
            public var firstName: String
            public var lastName: String
            public var usernames: [Api.Username]
            public init(userId: Int64, firstName: String, lastName: String, usernames: [Api.Username]) {
                self.userId = userId
                self.firstName = firstName
                self.lastName = lastName
                self.usernames = usernames
            }
        }
        public class Cons_updateUserPhone {
            public var userId: Int64
            public var phone: String
            public init(userId: Int64, phone: String) {
                self.userId = userId
                self.phone = phone
            }
        }
        public class Cons_updateUserStatus {
            public var userId: Int64
            public var status: Api.UserStatus
            public init(userId: Int64, status: Api.UserStatus) {
                self.userId = userId
                self.status = status
            }
        }
        public class Cons_updateUserTyping {
            public var flags: Int32
            public var userId: Int64
            public var topMsgId: Int32?
            public var action: Api.SendMessageAction
            public init(flags: Int32, userId: Int64, topMsgId: Int32?, action: Api.SendMessageAction) {
                self.flags = flags
                self.userId = userId
                self.topMsgId = topMsgId
                self.action = action
            }
        }
        public class Cons_updateWebPage {
            public var webpage: Api.WebPage
            public var pts: Int32
            public var ptsCount: Int32
            public init(webpage: Api.WebPage, pts: Int32, ptsCount: Int32) {
                self.webpage = webpage
                self.pts = pts
                self.ptsCount = ptsCount
            }
        }
        public class Cons_updateWebViewResultSent {
            public var queryId: Int64
            public init(queryId: Int64) {
                self.queryId = queryId
            }
        }
        case updateAttachMenuBots
        case updateAutoSaveSettings
        case updateBotBusinessConnect(Cons_updateBotBusinessConnect)
        case updateBotCallbackQuery(Cons_updateBotCallbackQuery)
        case updateBotChatBoost(Cons_updateBotChatBoost)
        case updateBotChatInviteRequester(Cons_updateBotChatInviteRequester)
        case updateBotCommands(Cons_updateBotCommands)
        case updateBotDeleteBusinessMessage(Cons_updateBotDeleteBusinessMessage)
        case updateBotEditBusinessMessage(Cons_updateBotEditBusinessMessage)
        case updateBotInlineQuery(Cons_updateBotInlineQuery)
        case updateBotInlineSend(Cons_updateBotInlineSend)
        case updateBotMenuButton(Cons_updateBotMenuButton)
        case updateBotMessageReaction(Cons_updateBotMessageReaction)
        case updateBotMessageReactions(Cons_updateBotMessageReactions)
        case updateBotNewBusinessMessage(Cons_updateBotNewBusinessMessage)
        case updateBotPrecheckoutQuery(Cons_updateBotPrecheckoutQuery)
        case updateBotPurchasedPaidMedia(Cons_updateBotPurchasedPaidMedia)
        case updateBotShippingQuery(Cons_updateBotShippingQuery)
        case updateBotStopped(Cons_updateBotStopped)
        case updateBotWebhookJSON(Cons_updateBotWebhookJSON)
        case updateBotWebhookJSONQuery(Cons_updateBotWebhookJSONQuery)
        case updateBusinessBotCallbackQuery(Cons_updateBusinessBotCallbackQuery)
        case updateChannel(Cons_updateChannel)
        case updateChannelAvailableMessages(Cons_updateChannelAvailableMessages)
        case updateChannelMessageForwards(Cons_updateChannelMessageForwards)
        case updateChannelMessageViews(Cons_updateChannelMessageViews)
        case updateChannelParticipant(Cons_updateChannelParticipant)
        case updateChannelReadMessagesContents(Cons_updateChannelReadMessagesContents)
        case updateChannelTooLong(Cons_updateChannelTooLong)
        case updateChannelUserTyping(Cons_updateChannelUserTyping)
        case updateChannelViewForumAsMessages(Cons_updateChannelViewForumAsMessages)
        case updateChannelWebPage(Cons_updateChannelWebPage)
        case updateChat(Cons_updateChat)
        case updateChatDefaultBannedRights(Cons_updateChatDefaultBannedRights)
        case updateChatParticipant(Cons_updateChatParticipant)
        case updateChatParticipantAdd(Cons_updateChatParticipantAdd)
        case updateChatParticipantAdmin(Cons_updateChatParticipantAdmin)
        case updateChatParticipantDelete(Cons_updateChatParticipantDelete)
        case updateChatParticipants(Cons_updateChatParticipants)
        case updateChatUserTyping(Cons_updateChatUserTyping)
        case updateConfig
        case updateContactsReset
        case updateDcOptions(Cons_updateDcOptions)
        case updateDeleteChannelMessages(Cons_updateDeleteChannelMessages)
        case updateDeleteGroupCallMessages(Cons_updateDeleteGroupCallMessages)
        case updateDeleteMessages(Cons_updateDeleteMessages)
        case updateDeleteQuickReply(Cons_updateDeleteQuickReply)
        case updateDeleteQuickReplyMessages(Cons_updateDeleteQuickReplyMessages)
        case updateDeleteScheduledMessages(Cons_updateDeleteScheduledMessages)
        case updateDialogFilter(Cons_updateDialogFilter)
        case updateDialogFilterOrder(Cons_updateDialogFilterOrder)
        case updateDialogFilters
        case updateDialogPinned(Cons_updateDialogPinned)
        case updateDialogUnreadMark(Cons_updateDialogUnreadMark)
        case updateDraftMessage(Cons_updateDraftMessage)
        case updateEditChannelMessage(Cons_updateEditChannelMessage)
        case updateEditMessage(Cons_updateEditMessage)
        case updateEmojiGameInfo(Cons_updateEmojiGameInfo)
        case updateEncryptedChatTyping(Cons_updateEncryptedChatTyping)
        case updateEncryptedMessagesRead(Cons_updateEncryptedMessagesRead)
        case updateEncryption(Cons_updateEncryption)
        case updateFavedStickers
        case updateFolderPeers(Cons_updateFolderPeers)
        case updateGeoLiveViewed(Cons_updateGeoLiveViewed)
        case updateGroupCall(Cons_updateGroupCall)
        case updateGroupCallChainBlocks(Cons_updateGroupCallChainBlocks)
        case updateGroupCallConnection(Cons_updateGroupCallConnection)
        case updateGroupCallEncryptedMessage(Cons_updateGroupCallEncryptedMessage)
        case updateGroupCallMessage(Cons_updateGroupCallMessage)
        case updateGroupCallParticipants(Cons_updateGroupCallParticipants)
        case updateInlineBotCallbackQuery(Cons_updateInlineBotCallbackQuery)
        case updateLangPack(Cons_updateLangPack)
        case updateLangPackTooLong(Cons_updateLangPackTooLong)
        case updateLoginToken
        case updateMessageExtendedMedia(Cons_updateMessageExtendedMedia)
        case updateMessageID(Cons_updateMessageID)
        case updateMessagePoll(Cons_updateMessagePoll)
        case updateMessagePollVote(Cons_updateMessagePollVote)
        case updateMessageReactions(Cons_updateMessageReactions)
        case updateMonoForumNoPaidException(Cons_updateMonoForumNoPaidException)
        case updateMoveStickerSetToTop(Cons_updateMoveStickerSetToTop)
        case updateNewAuthorization(Cons_updateNewAuthorization)
        case updateNewChannelMessage(Cons_updateNewChannelMessage)
        case updateNewEncryptedMessage(Cons_updateNewEncryptedMessage)
        case updateNewMessage(Cons_updateNewMessage)
        case updateNewQuickReply(Cons_updateNewQuickReply)
        case updateNewScheduledMessage(Cons_updateNewScheduledMessage)
        case updateNewStickerSet(Cons_updateNewStickerSet)
        case updateNewStoryReaction(Cons_updateNewStoryReaction)
        case updateNotifySettings(Cons_updateNotifySettings)
        case updatePaidReactionPrivacy(Cons_updatePaidReactionPrivacy)
        case updatePeerBlocked(Cons_updatePeerBlocked)
        case updatePeerHistoryTTL(Cons_updatePeerHistoryTTL)
        case updatePeerLocated(Cons_updatePeerLocated)
        case updatePeerSettings(Cons_updatePeerSettings)
        case updatePeerWallpaper(Cons_updatePeerWallpaper)
        case updatePendingJoinRequests(Cons_updatePendingJoinRequests)
        case updatePhoneCall(Cons_updatePhoneCall)
        case updatePhoneCallSignalingData(Cons_updatePhoneCallSignalingData)
        case updatePinnedChannelMessages(Cons_updatePinnedChannelMessages)
        case updatePinnedDialogs(Cons_updatePinnedDialogs)
        case updatePinnedForumTopic(Cons_updatePinnedForumTopic)
        case updatePinnedForumTopics(Cons_updatePinnedForumTopics)
        case updatePinnedMessages(Cons_updatePinnedMessages)
        case updatePinnedSavedDialogs(Cons_updatePinnedSavedDialogs)
        case updatePrivacy(Cons_updatePrivacy)
        case updatePtsChanged
        case updateQuickReplies(Cons_updateQuickReplies)
        case updateQuickReplyMessage(Cons_updateQuickReplyMessage)
        case updateReadChannelDiscussionInbox(Cons_updateReadChannelDiscussionInbox)
        case updateReadChannelDiscussionOutbox(Cons_updateReadChannelDiscussionOutbox)
        case updateReadChannelInbox(Cons_updateReadChannelInbox)
        case updateReadChannelOutbox(Cons_updateReadChannelOutbox)
        case updateReadFeaturedEmojiStickers
        case updateReadFeaturedStickers
        case updateReadHistoryInbox(Cons_updateReadHistoryInbox)
        case updateReadHistoryOutbox(Cons_updateReadHistoryOutbox)
        case updateReadMessagesContents(Cons_updateReadMessagesContents)
        case updateReadMonoForumInbox(Cons_updateReadMonoForumInbox)
        case updateReadMonoForumOutbox(Cons_updateReadMonoForumOutbox)
        case updateReadStories(Cons_updateReadStories)
        case updateRecentEmojiStatuses
        case updateRecentReactions
        case updateRecentStickers
        case updateSavedDialogPinned(Cons_updateSavedDialogPinned)
        case updateSavedGifs
        case updateSavedReactionTags
        case updateSavedRingtones
        case updateSentPhoneCode(Cons_updateSentPhoneCode)
        case updateSentStoryReaction(Cons_updateSentStoryReaction)
        case updateServiceNotification(Cons_updateServiceNotification)
        case updateSmsJob(Cons_updateSmsJob)
        case updateStarGiftAuctionState(Cons_updateStarGiftAuctionState)
        case updateStarGiftAuctionUserState(Cons_updateStarGiftAuctionUserState)
        case updateStarsBalance(Cons_updateStarsBalance)
        case updateStarsRevenueStatus(Cons_updateStarsRevenueStatus)
        case updateStickerSets(Cons_updateStickerSets)
        case updateStickerSetsOrder(Cons_updateStickerSetsOrder)
        case updateStoriesStealthMode(Cons_updateStoriesStealthMode)
        case updateStory(Cons_updateStory)
        case updateStoryID(Cons_updateStoryID)
        case updateTheme(Cons_updateTheme)
        case updateTranscribedAudio(Cons_updateTranscribedAudio)
        case updateUser(Cons_updateUser)
        case updateUserEmojiStatus(Cons_updateUserEmojiStatus)
        case updateUserName(Cons_updateUserName)
        case updateUserPhone(Cons_updateUserPhone)
        case updateUserStatus(Cons_updateUserStatus)
        case updateUserTyping(Cons_updateUserTyping)
        case updateWebPage(Cons_updateWebPage)
        case updateWebViewResultSent(Cons_updateWebViewResultSent)

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
