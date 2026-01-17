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
        case messagePeerVote(peer: Api.Peer, option: Buffer, date: Int32)
        case messagePeerVoteInputOption(peer: Api.Peer, date: Int32)
        case messagePeerVoteMultiple(peer: Api.Peer, options: [Buffer], date: Int32)

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
        case messageRange(minId: Int32, maxId: Int32)

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
        case messageReactions(flags: Int32, results: [Api.ReactionCount], recentReactions: [Api.MessagePeerReaction]?, topReactors: [Api.MessageReactor]?)

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
        case messageReactor(flags: Int32, peerId: Api.Peer?, count: Int32)

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
        case messageReplies(flags: Int32, replies: Int32, repliesPts: Int32, recentRepliers: [Api.Peer]?, channelId: Int64?, maxId: Int32?, readMaxId: Int32?)

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
        case messageReplyHeader(flags: Int32, replyToMsgId: Int32?, replyToPeerId: Api.Peer?, replyFrom: Api.MessageFwdHeader?, replyMedia: Api.MessageMedia?, replyToTopId: Int32?, quoteText: String?, quoteEntities: [Api.MessageEntity]?, quoteOffset: Int32?, todoItemId: Int32?)
        case messageReplyStoryHeader(peer: Api.Peer, storyId: Int32)

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
        case messageReportOption(text: String, option: Buffer)

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
        case messageViews(flags: Int32, views: Int32?, forwards: Int32?, replies: Api.MessageReplies?)

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
        case inputMessagesFilterChatPhotos
        case inputMessagesFilterContacts
        case inputMessagesFilterDocument
        case inputMessagesFilterEmpty
        case inputMessagesFilterGeo
        case inputMessagesFilterGif
        case inputMessagesFilterMusic
        case inputMessagesFilterMyMentions
        case inputMessagesFilterPhoneCalls(flags: Int32)
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
        case missingInvitee(flags: Int32, userId: Int64)

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
