public extension Api {
    enum StickerSetCovered: TypeConstructorDescription {
        public class Cons_stickerSetCovered {
            public var set: Api.StickerSet
            public var cover: Api.Document
            public init(set: Api.StickerSet, cover: Api.Document) {
                self.set = set
                self.cover = cover
            }
        }
        public class Cons_stickerSetFullCovered {
            public var set: Api.StickerSet
            public var packs: [Api.StickerPack]
            public var keywords: [Api.StickerKeyword]
            public var documents: [Api.Document]
            public init(set: Api.StickerSet, packs: [Api.StickerPack], keywords: [Api.StickerKeyword], documents: [Api.Document]) {
                self.set = set
                self.packs = packs
                self.keywords = keywords
                self.documents = documents
            }
        }
        public class Cons_stickerSetMultiCovered {
            public var set: Api.StickerSet
            public var covers: [Api.Document]
            public init(set: Api.StickerSet, covers: [Api.Document]) {
                self.set = set
                self.covers = covers
            }
        }
        public class Cons_stickerSetNoCovered {
            public var set: Api.StickerSet
            public init(set: Api.StickerSet) {
                self.set = set
            }
        }
        case stickerSetCovered(Cons_stickerSetCovered)
        case stickerSetFullCovered(Cons_stickerSetFullCovered)
        case stickerSetMultiCovered(Cons_stickerSetMultiCovered)
        case stickerSetNoCovered(Cons_stickerSetNoCovered)

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

        public static func parse_stickerSetCovered(_ reader: BufferReader) -> StickerSetCovered? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_stickerSetFullCovered(_ reader: BufferReader) -> StickerSetCovered? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_stickerSetMultiCovered(_ reader: BufferReader) -> StickerSetCovered? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_stickerSetNoCovered(_ reader: BufferReader) -> StickerSetCovered? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StoriesStealthMode: TypeConstructorDescription {
        public class Cons_storiesStealthMode {
            public var flags: Int32
            public var activeUntilDate: Int32?
            public var cooldownUntilDate: Int32?
            public init(flags: Int32, activeUntilDate: Int32?, cooldownUntilDate: Int32?) {
                self.flags = flags
                self.activeUntilDate = activeUntilDate
                self.cooldownUntilDate = cooldownUntilDate
            }
        }
        case storiesStealthMode(Cons_storiesStealthMode)

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

        public static func parse_storiesStealthMode(_ reader: BufferReader) -> StoriesStealthMode? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum StoryAlbum: TypeConstructorDescription {
        public class Cons_storyAlbum {
            public var flags: Int32
            public var albumId: Int32
            public var title: String
            public var iconPhoto: Api.Photo?
            public var iconVideo: Api.Document?
            public init(flags: Int32, albumId: Int32, title: String, iconPhoto: Api.Photo?, iconVideo: Api.Document?) {
                self.flags = flags
                self.albumId = albumId
                self.title = title
                self.iconPhoto = iconPhoto
                self.iconVideo = iconVideo
            }
        }
        case storyAlbum(Cons_storyAlbum)

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
        public class Cons_storyFwdHeader {
            public var flags: Int32
            public var from: Api.Peer?
            public var fromName: String?
            public var storyId: Int32?
            public init(flags: Int32, from: Api.Peer?, fromName: String?, storyId: Int32?) {
                self.flags = flags
                self.from = from
                self.fromName = fromName
                self.storyId = storyId
            }
        }
        case storyFwdHeader(Cons_storyFwdHeader)

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
        public class Cons_storyItem {
            public var flags: Int32
            public var id: Int32
            public var date: Int32
            public var fromId: Api.Peer?
            public var fwdFrom: Api.StoryFwdHeader?
            public var expireDate: Int32
            public var caption: String?
            public var entities: [Api.MessageEntity]?
            public var media: Api.MessageMedia
            public var mediaAreas: [Api.MediaArea]?
            public var privacy: [Api.PrivacyRule]?
            public var views: Api.StoryViews?
            public var sentReaction: Api.Reaction?
            public var albums: [Int32]?
            public init(flags: Int32, id: Int32, date: Int32, fromId: Api.Peer?, fwdFrom: Api.StoryFwdHeader?, expireDate: Int32, caption: String?, entities: [Api.MessageEntity]?, media: Api.MessageMedia, mediaAreas: [Api.MediaArea]?, privacy: [Api.PrivacyRule]?, views: Api.StoryViews?, sentReaction: Api.Reaction?, albums: [Int32]?) {
                self.flags = flags
                self.id = id
                self.date = date
                self.fromId = fromId
                self.fwdFrom = fwdFrom
                self.expireDate = expireDate
                self.caption = caption
                self.entities = entities
                self.media = media
                self.mediaAreas = mediaAreas
                self.privacy = privacy
                self.views = views
                self.sentReaction = sentReaction
                self.albums = albums
            }
        }
        public class Cons_storyItemDeleted {
            public var id: Int32
            public init(id: Int32) {
                self.id = id
            }
        }
        public class Cons_storyItemSkipped {
            public var flags: Int32
            public var id: Int32
            public var date: Int32
            public var expireDate: Int32
            public init(flags: Int32, id: Int32, date: Int32, expireDate: Int32) {
                self.flags = flags
                self.id = id
                self.date = date
                self.expireDate = expireDate
            }
        }
        case storyItem(Cons_storyItem)
        case storyItemDeleted(Cons_storyItemDeleted)
        case storyItemSkipped(Cons_storyItemSkipped)

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
        public class Cons_storyReaction {
            public var peerId: Api.Peer
            public var date: Int32
            public var reaction: Api.Reaction
            public init(peerId: Api.Peer, date: Int32, reaction: Api.Reaction) {
                self.peerId = peerId
                self.date = date
                self.reaction = reaction
            }
        }
        public class Cons_storyReactionPublicForward {
            public var message: Api.Message
            public init(message: Api.Message) {
                self.message = message
            }
        }
        public class Cons_storyReactionPublicRepost {
            public var peerId: Api.Peer
            public var story: Api.StoryItem
            public init(peerId: Api.Peer, story: Api.StoryItem) {
                self.peerId = peerId
                self.story = story
            }
        }
        case storyReaction(Cons_storyReaction)
        case storyReactionPublicForward(Cons_storyReactionPublicForward)
        case storyReactionPublicRepost(Cons_storyReactionPublicRepost)

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
        public class Cons_storyView {
            public var flags: Int32
            public var userId: Int64
            public var date: Int32
            public var reaction: Api.Reaction?
            public init(flags: Int32, userId: Int64, date: Int32, reaction: Api.Reaction?) {
                self.flags = flags
                self.userId = userId
                self.date = date
                self.reaction = reaction
            }
        }
        public class Cons_storyViewPublicForward {
            public var flags: Int32
            public var message: Api.Message
            public init(flags: Int32, message: Api.Message) {
                self.flags = flags
                self.message = message
            }
        }
        public class Cons_storyViewPublicRepost {
            public var flags: Int32
            public var peerId: Api.Peer
            public var story: Api.StoryItem
            public init(flags: Int32, peerId: Api.Peer, story: Api.StoryItem) {
                self.flags = flags
                self.peerId = peerId
                self.story = story
            }
        }
        case storyView(Cons_storyView)
        case storyViewPublicForward(Cons_storyViewPublicForward)
        case storyViewPublicRepost(Cons_storyViewPublicRepost)

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
        public class Cons_storyViews {
            public var flags: Int32
            public var viewsCount: Int32
            public var forwardsCount: Int32?
            public var reactions: [Api.ReactionCount]?
            public var reactionsCount: Int32?
            public var recentViewers: [Int64]?
            public init(flags: Int32, viewsCount: Int32, forwardsCount: Int32?, reactions: [Api.ReactionCount]?, reactionsCount: Int32?, recentViewers: [Int64]?) {
                self.flags = flags
                self.viewsCount = viewsCount
                self.forwardsCount = forwardsCount
                self.reactions = reactions
                self.reactionsCount = reactionsCount
                self.recentViewers = recentViewers
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
public extension Api {
    enum SuggestedPost: TypeConstructorDescription {
        public class Cons_suggestedPost {
            public var flags: Int32
            public var price: Api.StarsAmount?
            public var scheduleDate: Int32?
            public init(flags: Int32, price: Api.StarsAmount?, scheduleDate: Int32?) {
                self.flags = flags
                self.price = price
                self.scheduleDate = scheduleDate
            }
        }
        case suggestedPost(Cons_suggestedPost)

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
        public class Cons_textWithEntities {
            public var text: String
            public var entities: [Api.MessageEntity]
            public init(text: String, entities: [Api.MessageEntity]) {
                self.text = text
                self.entities = entities
            }
        }
        case textWithEntities(Cons_textWithEntities)

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
        public class Cons_theme {
            public var flags: Int32
            public var id: Int64
            public var accessHash: Int64
            public var slug: String
            public var title: String
            public var document: Api.Document?
            public var settings: [Api.ThemeSettings]?
            public var emoticon: String?
            public var installsCount: Int32?
            public init(flags: Int32, id: Int64, accessHash: Int64, slug: String, title: String, document: Api.Document?, settings: [Api.ThemeSettings]?, emoticon: String?, installsCount: Int32?) {
                self.flags = flags
                self.id = id
                self.accessHash = accessHash
                self.slug = slug
                self.title = title
                self.document = document
                self.settings = settings
                self.emoticon = emoticon
                self.installsCount = installsCount
            }
        }
        case theme(Cons_theme)

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
        public class Cons_themeSettings {
            public var flags: Int32
            public var baseTheme: Api.BaseTheme
            public var accentColor: Int32
            public var outboxAccentColor: Int32?
            public var messageColors: [Int32]?
            public var wallpaper: Api.WallPaper?
            public init(flags: Int32, baseTheme: Api.BaseTheme, accentColor: Int32, outboxAccentColor: Int32?, messageColors: [Int32]?, wallpaper: Api.WallPaper?) {
                self.flags = flags
                self.baseTheme = baseTheme
                self.accentColor = accentColor
                self.outboxAccentColor = outboxAccentColor
                self.messageColors = messageColors
                self.wallpaper = wallpaper
            }
        }
        case themeSettings(Cons_themeSettings)

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
        public class Cons_timezone {
            public var id: String
            public var name: String
            public var utcOffset: Int32
            public init(id: String, name: String, utcOffset: Int32) {
                self.id = id
                self.name = name
                self.utcOffset = utcOffset
            }
        }
        case timezone(Cons_timezone)

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
        public class Cons_todoCompletion {
            public var id: Int32
            public var completedBy: Api.Peer
            public var date: Int32
            public init(id: Int32, completedBy: Api.Peer, date: Int32) {
                self.id = id
                self.completedBy = completedBy
                self.date = date
            }
        }
        case todoCompletion(Cons_todoCompletion)

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
        public class Cons_todoItem {
            public var id: Int32
            public var title: Api.TextWithEntities
            public init(id: Int32, title: Api.TextWithEntities) {
                self.id = id
                self.title = title
            }
        }
        case todoItem(Cons_todoItem)

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
        public class Cons_todoList {
            public var flags: Int32
            public var title: Api.TextWithEntities
            public var list: [Api.TodoItem]
            public init(flags: Int32, title: Api.TextWithEntities, list: [Api.TodoItem]) {
                self.flags = flags
                self.title = title
                self.list = list
            }
        }
        case todoList(Cons_todoList)

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
        public class Cons_topPeer {
            public var peer: Api.Peer
            public var rating: Double
            public init(peer: Api.Peer, rating: Double) {
                self.peer = peer
                self.rating = rating
            }
        }
        case topPeer(Cons_topPeer)

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
