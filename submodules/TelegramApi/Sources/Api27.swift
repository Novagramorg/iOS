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
