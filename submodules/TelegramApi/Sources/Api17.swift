public extension Api {
    enum MessagePeerReaction: TypeConstructorDescription {
        public class Cons_messagePeerReaction {
            public var flags: Int32
            public var peerId: Api.Peer
            public var date: Int32
            public var reaction: Api.Reaction
            public init(flags: Int32, peerId: Api.Peer, date: Int32, reaction: Api.Reaction) {
                self.flags = flags
                self.peerId = peerId
                self.date = date
                self.reaction = reaction
            }
        }
        case messagePeerReaction(Cons_messagePeerReaction)

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

        public static func parse_messagePeerReaction(_ reader: BufferReader) -> MessagePeerReaction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum MessagePeerVote: TypeConstructorDescription {
        public class Cons_messagePeerVote {
            public var peer: Api.Peer
            public var option: Buffer
            public var date: Int32
            public init(peer: Api.Peer, option: Buffer, date: Int32) {
                self.peer = peer
                self.option = option
                self.date = date
            }
        }
        public class Cons_messagePeerVoteInputOption {
            public var peer: Api.Peer
            public var date: Int32
            public init(peer: Api.Peer, date: Int32) {
                self.peer = peer
                self.date = date
            }
        }
        public class Cons_messagePeerVoteMultiple {
            public var peer: Api.Peer
            public var options: [Buffer]
            public var date: Int32
            public init(peer: Api.Peer, options: [Buffer], date: Int32) {
                self.peer = peer
                self.options = options
                self.date = date
            }
        }
        case messagePeerVote(Cons_messagePeerVote)
        case messagePeerVoteInputOption(Cons_messagePeerVoteInputOption)
        case messagePeerVoteMultiple(Cons_messagePeerVoteMultiple)

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

        public static func parse_messagePeerVote(_ reader: BufferReader) -> MessagePeerVote? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messagePeerVoteInputOption(_ reader: BufferReader) -> MessagePeerVote? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messagePeerVoteMultiple(_ reader: BufferReader) -> MessagePeerVote? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum MessageRange: TypeConstructorDescription {
        public class Cons_messageRange {
            public var minId: Int32
            public var maxId: Int32
            public init(minId: Int32, maxId: Int32) {
                self.minId = minId
                self.maxId = maxId
            }
        }
        case messageRange(Cons_messageRange)

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

        public static func parse_messageRange(_ reader: BufferReader) -> MessageRange? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum MessageReactions: TypeConstructorDescription {
        public class Cons_messageReactions {
            public var flags: Int32
            public var results: [Api.ReactionCount]
            public var recentReactions: [Api.MessagePeerReaction]?
            public var topReactors: [Api.MessageReactor]?
            public init(flags: Int32, results: [Api.ReactionCount], recentReactions: [Api.MessagePeerReaction]?, topReactors: [Api.MessageReactor]?) {
                self.flags = flags
                self.results = results
                self.recentReactions = recentReactions
                self.topReactors = topReactors
            }
        }
        case messageReactions(Cons_messageReactions)

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

        public static func parse_messageReactions(_ reader: BufferReader) -> MessageReactions? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum MessageReactor: TypeConstructorDescription {
        public class Cons_messageReactor {
            public var flags: Int32
            public var peerId: Api.Peer?
            public var count: Int32
            public init(flags: Int32, peerId: Api.Peer?, count: Int32) {
                self.flags = flags
                self.peerId = peerId
                self.count = count
            }
        }
        case messageReactor(Cons_messageReactor)

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

        public static func parse_messageReactor(_ reader: BufferReader) -> MessageReactor? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum MessageReplies: TypeConstructorDescription {
        public class Cons_messageReplies {
            public var flags: Int32
            public var replies: Int32
            public var repliesPts: Int32
            public var recentRepliers: [Api.Peer]?
            public var channelId: Int64?
            public var maxId: Int32?
            public var readMaxId: Int32?
            public init(flags: Int32, replies: Int32, repliesPts: Int32, recentRepliers: [Api.Peer]?, channelId: Int64?, maxId: Int32?, readMaxId: Int32?) {
                self.flags = flags
                self.replies = replies
                self.repliesPts = repliesPts
                self.recentRepliers = recentRepliers
                self.channelId = channelId
                self.maxId = maxId
                self.readMaxId = readMaxId
            }
        }
        case messageReplies(Cons_messageReplies)

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

        public static func parse_messageReplies(_ reader: BufferReader) -> MessageReplies? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum MessageReplyHeader: TypeConstructorDescription {
        public class Cons_messageReplyHeader {
            public var flags: Int32
            public var replyToMsgId: Int32?
            public var replyToPeerId: Api.Peer?
            public var replyFrom: Api.MessageFwdHeader?
            public var replyMedia: Api.MessageMedia?
            public var replyToTopId: Int32?
            public var quoteText: String?
            public var quoteEntities: [Api.MessageEntity]?
            public var quoteOffset: Int32?
            public var todoItemId: Int32?
            public init(flags: Int32, replyToMsgId: Int32?, replyToPeerId: Api.Peer?, replyFrom: Api.MessageFwdHeader?, replyMedia: Api.MessageMedia?, replyToTopId: Int32?, quoteText: String?, quoteEntities: [Api.MessageEntity]?, quoteOffset: Int32?, todoItemId: Int32?) {
                self.flags = flags
                self.replyToMsgId = replyToMsgId
                self.replyToPeerId = replyToPeerId
                self.replyFrom = replyFrom
                self.replyMedia = replyMedia
                self.replyToTopId = replyToTopId
                self.quoteText = quoteText
                self.quoteEntities = quoteEntities
                self.quoteOffset = quoteOffset
                self.todoItemId = todoItemId
            }
        }
        public class Cons_messageReplyStoryHeader {
            public var peer: Api.Peer
            public var storyId: Int32
            public init(peer: Api.Peer, storyId: Int32) {
                self.peer = peer
                self.storyId = storyId
            }
        }
        case messageReplyHeader(Cons_messageReplyHeader)
        case messageReplyStoryHeader(Cons_messageReplyStoryHeader)

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

        public static func parse_messageReplyHeader(_ reader: BufferReader) -> MessageReplyHeader? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageReplyStoryHeader(_ reader: BufferReader) -> MessageReplyHeader? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum MessageReportOption: TypeConstructorDescription {
        public class Cons_messageReportOption {
            public var text: String
            public var option: Buffer
            public init(text: String, option: Buffer) {
                self.text = text
                self.option = option
            }
        }
        case messageReportOption(Cons_messageReportOption)

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

        public static func parse_messageReportOption(_ reader: BufferReader) -> MessageReportOption? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum MessageViews: TypeConstructorDescription {
        public class Cons_messageViews {
            public var flags: Int32
            public var views: Int32?
            public var forwards: Int32?
            public var replies: Api.MessageReplies?
            public init(flags: Int32, views: Int32?, forwards: Int32?, replies: Api.MessageReplies?) {
                self.flags = flags
                self.views = views
                self.forwards = forwards
                self.replies = replies
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
public extension Api {
    enum MessagesFilter: TypeConstructorDescription {
        public class Cons_inputMessagesFilterPhoneCalls {
            public var flags: Int32
            public init(flags: Int32) {
                self.flags = flags
            }
        }
        case inputMessagesFilterChatPhotos
        case inputMessagesFilterContacts
        case inputMessagesFilterDocument
        case inputMessagesFilterEmpty
        case inputMessagesFilterGeo
        case inputMessagesFilterGif
        case inputMessagesFilterMusic
        case inputMessagesFilterMyMentions
        case inputMessagesFilterPhoneCalls(Cons_inputMessagesFilterPhoneCalls)
        case inputMessagesFilterPhotoVideo
        case inputMessagesFilterPhotos
        case inputMessagesFilterPinned
        case inputMessagesFilterRoundVideo
        case inputMessagesFilterRoundVoice
        case inputMessagesFilterUrl
        case inputMessagesFilterVideo
        case inputMessagesFilterVoice

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

        public static func parse_inputMessagesFilterChatPhotos(_ reader: BufferReader) -> MessagesFilter? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMessagesFilterContacts(_ reader: BufferReader) -> MessagesFilter? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMessagesFilterDocument(_ reader: BufferReader) -> MessagesFilter? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMessagesFilterEmpty(_ reader: BufferReader) -> MessagesFilter? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMessagesFilterGeo(_ reader: BufferReader) -> MessagesFilter? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMessagesFilterGif(_ reader: BufferReader) -> MessagesFilter? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMessagesFilterMusic(_ reader: BufferReader) -> MessagesFilter? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMessagesFilterMyMentions(_ reader: BufferReader) -> MessagesFilter? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMessagesFilterPhoneCalls(_ reader: BufferReader) -> MessagesFilter? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMessagesFilterPhotoVideo(_ reader: BufferReader) -> MessagesFilter? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMessagesFilterPhotos(_ reader: BufferReader) -> MessagesFilter? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMessagesFilterPinned(_ reader: BufferReader) -> MessagesFilter? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMessagesFilterRoundVideo(_ reader: BufferReader) -> MessagesFilter? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMessagesFilterRoundVoice(_ reader: BufferReader) -> MessagesFilter? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMessagesFilterUrl(_ reader: BufferReader) -> MessagesFilter? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMessagesFilterVideo(_ reader: BufferReader) -> MessagesFilter? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMessagesFilterVoice(_ reader: BufferReader) -> MessagesFilter? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum MissingInvitee: TypeConstructorDescription {
        public class Cons_missingInvitee {
            public var flags: Int32
            public var userId: Int64
            public init(flags: Int32, userId: Int64) {
                self.flags = flags
                self.userId = userId
            }
        }
        case missingInvitee(Cons_missingInvitee)

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

        public static func parse_missingInvitee(_ reader: BufferReader) -> MissingInvitee? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum MyBoost: TypeConstructorDescription {
        case myBoost(flags: Int32, slot: Int32, peer: Api.Peer?, date: Int32, expires: Int32, cooldownUntilDate: Int32?)

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

        public static func parse_myBoost(_ reader: BufferReader) -> MyBoost? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum NearestDc: TypeConstructorDescription {
        case nearestDc(country: String, thisDc: Int32, nearestDc: Int32)

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

        public static func parse_nearestDc(_ reader: BufferReader) -> NearestDc? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
