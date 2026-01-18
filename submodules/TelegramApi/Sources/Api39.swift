public extension Api.stories {
    enum PeerStories: TypeConstructorDescription {
        public class Cons_peerStories {
            public var stories: Api.PeerStories
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(stories: Api.PeerStories, chats: [Api.Chat], users: [Api.User]) {
                self.stories = stories
                self.chats = chats
                self.users = users
            }
        }
        case peerStories(Cons_peerStories)

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

        public static func parse_peerStories(_ reader: BufferReader) -> PeerStories? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.stories {
    enum Stories: TypeConstructorDescription {
        public class Cons_stories {
            public var flags: Int32
            public var count: Int32
            public var stories: [Api.StoryItem]
            public var pinnedToTop: [Int32]?
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(flags: Int32, count: Int32, stories: [Api.StoryItem], pinnedToTop: [Int32]?, chats: [Api.Chat], users: [Api.User]) {
                self.flags = flags
                self.count = count
                self.stories = stories
                self.pinnedToTop = pinnedToTop
                self.chats = chats
                self.users = users
            }
        }
        case stories(Cons_stories)

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

        public static func parse_stories(_ reader: BufferReader) -> Stories? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.stories {
    enum StoryReactionsList: TypeConstructorDescription {
        public class Cons_storyReactionsList {
            public var flags: Int32
            public var count: Int32
            public var reactions: [Api.StoryReaction]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public var nextOffset: String?
            public init(flags: Int32, count: Int32, reactions: [Api.StoryReaction], chats: [Api.Chat], users: [Api.User], nextOffset: String?) {
                self.flags = flags
                self.count = count
                self.reactions = reactions
                self.chats = chats
                self.users = users
                self.nextOffset = nextOffset
            }
        }
        case storyReactionsList(Cons_storyReactionsList)

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

        public static func parse_storyReactionsList(_ reader: BufferReader) -> StoryReactionsList? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.stories {
    enum StoryViews: TypeConstructorDescription {
        public class Cons_storyViews {
            public var views: [Api.StoryViews]
            public var users: [Api.User]
            public init(views: [Api.StoryViews], users: [Api.User]) {
                self.views = views
                self.users = users
            }
        }
        case storyViews(Cons_storyViews)

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
public extension Api.stories {
    enum StoryViewsList: TypeConstructorDescription {
        public class Cons_storyViewsList {
            public var flags: Int32
            public var count: Int32
            public var viewsCount: Int32
            public var forwardsCount: Int32
            public var reactionsCount: Int32
            public var views: [Api.StoryView]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public var nextOffset: String?
            public init(flags: Int32, count: Int32, viewsCount: Int32, forwardsCount: Int32, reactionsCount: Int32, views: [Api.StoryView], chats: [Api.Chat], users: [Api.User], nextOffset: String?) {
                self.flags = flags
                self.count = count
                self.viewsCount = viewsCount
                self.forwardsCount = forwardsCount
                self.reactionsCount = reactionsCount
                self.views = views
                self.chats = chats
                self.users = users
                self.nextOffset = nextOffset
            }
        }
        case storyViewsList(Cons_storyViewsList)

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

        public static func parse_storyViewsList(_ reader: BufferReader) -> StoryViewsList? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.updates {
    indirect enum ChannelDifference: TypeConstructorDescription {
        public class Cons_channelDifference {
            public var flags: Int32
            public var pts: Int32
            public var timeout: Int32?
            public var newMessages: [Api.Message]
            public var otherUpdates: [Api.Update]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(flags: Int32, pts: Int32, timeout: Int32?, newMessages: [Api.Message], otherUpdates: [Api.Update], chats: [Api.Chat], users: [Api.User]) {
                self.flags = flags
                self.pts = pts
                self.timeout = timeout
                self.newMessages = newMessages
                self.otherUpdates = otherUpdates
                self.chats = chats
                self.users = users
            }
        }
        public class Cons_channelDifferenceEmpty {
            public var flags: Int32
            public var pts: Int32
            public var timeout: Int32?
            public init(flags: Int32, pts: Int32, timeout: Int32?) {
                self.flags = flags
                self.pts = pts
                self.timeout = timeout
            }
        }
        public class Cons_channelDifferenceTooLong {
            public var flags: Int32
            public var timeout: Int32?
            public var dialog: Api.Dialog
            public var messages: [Api.Message]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(flags: Int32, timeout: Int32?, dialog: Api.Dialog, messages: [Api.Message], chats: [Api.Chat], users: [Api.User]) {
                self.flags = flags
                self.timeout = timeout
                self.dialog = dialog
                self.messages = messages
                self.chats = chats
                self.users = users
            }
        }
        case channelDifference(Cons_channelDifference)
        case channelDifferenceEmpty(Cons_channelDifferenceEmpty)
        case channelDifferenceTooLong(Cons_channelDifferenceTooLong)

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

        public static func parse_channelDifference(_ reader: BufferReader) -> ChannelDifference? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelDifferenceEmpty(_ reader: BufferReader) -> ChannelDifference? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelDifferenceTooLong(_ reader: BufferReader) -> ChannelDifference? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.updates {
    enum Difference: TypeConstructorDescription {
        public class Cons_difference {
            public var newMessages: [Api.Message]
            public var newEncryptedMessages: [Api.EncryptedMessage]
            public var otherUpdates: [Api.Update]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public var state: Api.updates.State
            public init(newMessages: [Api.Message], newEncryptedMessages: [Api.EncryptedMessage], otherUpdates: [Api.Update], chats: [Api.Chat], users: [Api.User], state: Api.updates.State) {
                self.newMessages = newMessages
                self.newEncryptedMessages = newEncryptedMessages
                self.otherUpdates = otherUpdates
                self.chats = chats
                self.users = users
                self.state = state
            }
        }
        public class Cons_differenceEmpty {
            public var date: Int32
            public var seq: Int32
            public init(date: Int32, seq: Int32) {
                self.date = date
                self.seq = seq
            }
        }
        public class Cons_differenceSlice {
            public var newMessages: [Api.Message]
            public var newEncryptedMessages: [Api.EncryptedMessage]
            public var otherUpdates: [Api.Update]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public var intermediateState: Api.updates.State
            public init(newMessages: [Api.Message], newEncryptedMessages: [Api.EncryptedMessage], otherUpdates: [Api.Update], chats: [Api.Chat], users: [Api.User], intermediateState: Api.updates.State) {
                self.newMessages = newMessages
                self.newEncryptedMessages = newEncryptedMessages
                self.otherUpdates = otherUpdates
                self.chats = chats
                self.users = users
                self.intermediateState = intermediateState
            }
        }
        public class Cons_differenceTooLong {
            public var pts: Int32
            public init(pts: Int32) {
                self.pts = pts
            }
        }
        case difference(Cons_difference)
        case differenceEmpty(Cons_differenceEmpty)
        case differenceSlice(Cons_differenceSlice)
        case differenceTooLong(Cons_differenceTooLong)

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

        public static func parse_difference(_ reader: BufferReader) -> Difference? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_differenceEmpty(_ reader: BufferReader) -> Difference? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_differenceSlice(_ reader: BufferReader) -> Difference? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_differenceTooLong(_ reader: BufferReader) -> Difference? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.updates {
    enum State: TypeConstructorDescription {
        public class Cons_state {
            public var pts: Int32
            public var qts: Int32
            public var date: Int32
            public var seq: Int32
            public var unreadCount: Int32
            public init(pts: Int32, qts: Int32, date: Int32, seq: Int32, unreadCount: Int32) {
                self.pts = pts
                self.qts = qts
                self.date = date
                self.seq = seq
                self.unreadCount = unreadCount
            }
        }
        case state(Cons_state)

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

        public static func parse_state(_ reader: BufferReader) -> State? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.upload {
    enum CdnFile: TypeConstructorDescription {
        public class Cons_cdnFile {
            public var bytes: Buffer
            public init(bytes: Buffer) {
                self.bytes = bytes
            }
        }
        public class Cons_cdnFileReuploadNeeded {
            public var requestToken: Buffer
            public init(requestToken: Buffer) {
                self.requestToken = requestToken
            }
        }
        case cdnFile(Cons_cdnFile)
        case cdnFileReuploadNeeded(Cons_cdnFileReuploadNeeded)

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

        public static func parse_cdnFile(_ reader: BufferReader) -> CdnFile? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_cdnFileReuploadNeeded(_ reader: BufferReader) -> CdnFile? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.upload {
    enum File: TypeConstructorDescription {
        public class Cons_file {
            public var type: Api.storage.FileType
            public var mtime: Int32
            public var bytes: Buffer
            public init(type: Api.storage.FileType, mtime: Int32, bytes: Buffer) {
                self.type = type
                self.mtime = mtime
                self.bytes = bytes
            }
        }
        public class Cons_fileCdnRedirect {
            public var dcId: Int32
            public var fileToken: Buffer
            public var encryptionKey: Buffer
            public var encryptionIv: Buffer
            public var fileHashes: [Api.FileHash]
            public init(dcId: Int32, fileToken: Buffer, encryptionKey: Buffer, encryptionIv: Buffer, fileHashes: [Api.FileHash]) {
                self.dcId = dcId
                self.fileToken = fileToken
                self.encryptionKey = encryptionKey
                self.encryptionIv = encryptionIv
                self.fileHashes = fileHashes
            }
        }
        case file(Cons_file)
        case fileCdnRedirect(Cons_fileCdnRedirect)

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

        public static func parse_file(_ reader: BufferReader) -> File? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_fileCdnRedirect(_ reader: BufferReader) -> File? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.upload {
    enum WebFile: TypeConstructorDescription {
        public class Cons_webFile {
            public var size: Int32
            public var mimeType: String
            public var fileType: Api.storage.FileType
            public var mtime: Int32
            public var bytes: Buffer
            public init(size: Int32, mimeType: String, fileType: Api.storage.FileType, mtime: Int32, bytes: Buffer) {
                self.size = size
                self.mimeType = mimeType
                self.fileType = fileType
                self.mtime = mtime
                self.bytes = bytes
            }
        }
        case webFile(Cons_webFile)

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

        public static func parse_webFile(_ reader: BufferReader) -> WebFile? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.users {
    enum SavedMusic: TypeConstructorDescription {
        public class Cons_savedMusic {
            public var count: Int32
            public var documents: [Api.Document]
            public init(count: Int32, documents: [Api.Document]) {
                self.count = count
                self.documents = documents
            }
        }
        public class Cons_savedMusicNotModified {
            public var count: Int32
            public init(count: Int32) {
                self.count = count
            }
        }
        case savedMusic(Cons_savedMusic)
        case savedMusicNotModified(Cons_savedMusicNotModified)

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

        public static func parse_savedMusic(_ reader: BufferReader) -> SavedMusic? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_savedMusicNotModified(_ reader: BufferReader) -> SavedMusic? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.users {
    enum UserFull: TypeConstructorDescription {
        public class Cons_userFull {
            public var fullUser: Api.UserFull
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(fullUser: Api.UserFull, chats: [Api.Chat], users: [Api.User]) {
                self.fullUser = fullUser
                self.chats = chats
                self.users = users
            }
        }
        case userFull(Cons_userFull)

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

        public static func parse_userFull(_ reader: BufferReader) -> UserFull? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.users {
    enum Users: TypeConstructorDescription {
        public class Cons_users {
            public var users: [Api.User]
            public init(users: [Api.User]) {
                self.users = users
            }
        }
        public class Cons_usersSlice {
            public var count: Int32
            public var users: [Api.User]
            public init(count: Int32, users: [Api.User]) {
                self.count = count
                self.users = users
            }
        }
        case users(Cons_users)
        case usersSlice(Cons_usersSlice)

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

        public static func parse_users(_ reader: BufferReader) -> Users? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_usersSlice(_ reader: BufferReader) -> Users? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
