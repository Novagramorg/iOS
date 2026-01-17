public extension Api {
    enum NotificationSound: TypeConstructorDescription {
        public class Cons_notificationSoundLocal {
            public var title: String
            public var data: String
            public init(title: String, data: String) {
                self.title = title
                self.data = data
            }
        }
        public class Cons_notificationSoundRingtone {
            public var id: Int64
            public init(id: Int64) {
                self.id = id
            }
        }
        case notificationSoundDefault
        case notificationSoundLocal(Cons_notificationSoundLocal)
        case notificationSoundNone
        case notificationSoundRingtone(Cons_notificationSoundRingtone)

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

        public static func parse_notificationSoundDefault(_ reader: BufferReader) -> NotificationSound? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_notificationSoundLocal(_ reader: BufferReader) -> NotificationSound? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_notificationSoundNone(_ reader: BufferReader) -> NotificationSound? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_notificationSoundRingtone(_ reader: BufferReader) -> NotificationSound? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum NotifyPeer: TypeConstructorDescription {
        public class Cons_notifyForumTopic {
            public var peer: Api.Peer
            public var topMsgId: Int32
            public init(peer: Api.Peer, topMsgId: Int32) {
                self.peer = peer
                self.topMsgId = topMsgId
            }
        }
        public class Cons_notifyPeer {
            public var peer: Api.Peer
            public init(peer: Api.Peer) {
                self.peer = peer
            }
        }
        case notifyBroadcasts
        case notifyChats
        case notifyForumTopic(Cons_notifyForumTopic)
        case notifyPeer(Cons_notifyPeer)
        case notifyUsers

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

        public static func parse_notifyBroadcasts(_ reader: BufferReader) -> NotifyPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_notifyChats(_ reader: BufferReader) -> NotifyPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_notifyForumTopic(_ reader: BufferReader) -> NotifyPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_notifyPeer(_ reader: BufferReader) -> NotifyPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_notifyUsers(_ reader: BufferReader) -> NotifyPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum OutboxReadDate: TypeConstructorDescription {
        public class Cons_outboxReadDate {
            public var date: Int32
            public init(date: Int32) {
                self.date = date
            }
        }
        case outboxReadDate(Cons_outboxReadDate)

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

        public static func parse_outboxReadDate(_ reader: BufferReader) -> OutboxReadDate? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum Page: TypeConstructorDescription {
        public class Cons_page {
            public var flags: Int32
            public var url: String
            public var blocks: [Api.PageBlock]
            public var photos: [Api.Photo]
            public var documents: [Api.Document]
            public var views: Int32?
            public init(flags: Int32, url: String, blocks: [Api.PageBlock], photos: [Api.Photo], documents: [Api.Document], views: Int32?) {
                self.flags = flags
                self.url = url
                self.blocks = blocks
                self.photos = photos
                self.documents = documents
                self.views = views
            }
        }
        case page(Cons_page)

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

        public static func parse_page(_ reader: BufferReader) -> Page? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum PageBlock: TypeConstructorDescription {
        public class Cons_pageBlockAnchor {
            public var name: String
            public init(name: String) {
                self.name = name
            }
        }
        public class Cons_pageBlockAudio {
            public var audioId: Int64
            public var caption: Api.PageCaption
            public init(audioId: Int64, caption: Api.PageCaption) {
                self.audioId = audioId
                self.caption = caption
            }
        }
        public class Cons_pageBlockAuthorDate {
            public var author: Api.RichText
            public var publishedDate: Int32
            public init(author: Api.RichText, publishedDate: Int32) {
                self.author = author
                self.publishedDate = publishedDate
            }
        }
        public class Cons_pageBlockBlockquote {
            public var text: Api.RichText
            public var caption: Api.RichText
            public init(text: Api.RichText, caption: Api.RichText) {
                self.text = text
                self.caption = caption
            }
        }
        public class Cons_pageBlockChannel {
            public var channel: Api.Chat
            public init(channel: Api.Chat) {
                self.channel = channel
            }
        }
        public class Cons_pageBlockCollage {
            public var items: [Api.PageBlock]
            public var caption: Api.PageCaption
            public init(items: [Api.PageBlock], caption: Api.PageCaption) {
                self.items = items
                self.caption = caption
            }
        }
        public class Cons_pageBlockCover {
            public var cover: Api.PageBlock
            public init(cover: Api.PageBlock) {
                self.cover = cover
            }
        }
        public class Cons_pageBlockDetails {
            public var flags: Int32
            public var blocks: [Api.PageBlock]
            public var title: Api.RichText
            public init(flags: Int32, blocks: [Api.PageBlock], title: Api.RichText) {
                self.flags = flags
                self.blocks = blocks
                self.title = title
            }
        }
        public class Cons_pageBlockEmbed {
            public var flags: Int32
            public var url: String?
            public var html: String?
            public var posterPhotoId: Int64?
            public var w: Int32?
            public var h: Int32?
            public var caption: Api.PageCaption
            public init(flags: Int32, url: String?, html: String?, posterPhotoId: Int64?, w: Int32?, h: Int32?, caption: Api.PageCaption) {
                self.flags = flags
                self.url = url
                self.html = html
                self.posterPhotoId = posterPhotoId
                self.w = w
                self.h = h
                self.caption = caption
            }
        }
        public class Cons_pageBlockEmbedPost {
            public var url: String
            public var webpageId: Int64
            public var authorPhotoId: Int64
            public var author: String
            public var date: Int32
            public var blocks: [Api.PageBlock]
            public var caption: Api.PageCaption
            public init(url: String, webpageId: Int64, authorPhotoId: Int64, author: String, date: Int32, blocks: [Api.PageBlock], caption: Api.PageCaption) {
                self.url = url
                self.webpageId = webpageId
                self.authorPhotoId = authorPhotoId
                self.author = author
                self.date = date
                self.blocks = blocks
                self.caption = caption
            }
        }
        public class Cons_pageBlockFooter {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
        }
        public class Cons_pageBlockHeader {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
        }
        public class Cons_pageBlockKicker {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
        }
        public class Cons_pageBlockList {
            public var items: [Api.PageListItem]
            public init(items: [Api.PageListItem]) {
                self.items = items
            }
        }
        public class Cons_pageBlockMap {
            public var geo: Api.GeoPoint
            public var zoom: Int32
            public var w: Int32
            public var h: Int32
            public var caption: Api.PageCaption
            public init(geo: Api.GeoPoint, zoom: Int32, w: Int32, h: Int32, caption: Api.PageCaption) {
                self.geo = geo
                self.zoom = zoom
                self.w = w
                self.h = h
                self.caption = caption
            }
        }
        public class Cons_pageBlockOrderedList {
            public var items: [Api.PageListOrderedItem]
            public init(items: [Api.PageListOrderedItem]) {
                self.items = items
            }
        }
        public class Cons_pageBlockParagraph {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
        }
        public class Cons_pageBlockPhoto {
            public var flags: Int32
            public var photoId: Int64
            public var caption: Api.PageCaption
            public var url: String?
            public var webpageId: Int64?
            public init(flags: Int32, photoId: Int64, caption: Api.PageCaption, url: String?, webpageId: Int64?) {
                self.flags = flags
                self.photoId = photoId
                self.caption = caption
                self.url = url
                self.webpageId = webpageId
            }
        }
        public class Cons_pageBlockPreformatted {
            public var text: Api.RichText
            public var language: String
            public init(text: Api.RichText, language: String) {
                self.text = text
                self.language = language
            }
        }
        public class Cons_pageBlockPullquote {
            public var text: Api.RichText
            public var caption: Api.RichText
            public init(text: Api.RichText, caption: Api.RichText) {
                self.text = text
                self.caption = caption
            }
        }
        public class Cons_pageBlockRelatedArticles {
            public var title: Api.RichText
            public var articles: [Api.PageRelatedArticle]
            public init(title: Api.RichText, articles: [Api.PageRelatedArticle]) {
                self.title = title
                self.articles = articles
            }
        }
        public class Cons_pageBlockSlideshow {
            public var items: [Api.PageBlock]
            public var caption: Api.PageCaption
            public init(items: [Api.PageBlock], caption: Api.PageCaption) {
                self.items = items
                self.caption = caption
            }
        }
        public class Cons_pageBlockSubheader {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
        }
        public class Cons_pageBlockSubtitle {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
        }
        public class Cons_pageBlockTable {
            public var flags: Int32
            public var title: Api.RichText
            public var rows: [Api.PageTableRow]
            public init(flags: Int32, title: Api.RichText, rows: [Api.PageTableRow]) {
                self.flags = flags
                self.title = title
                self.rows = rows
            }
        }
        public class Cons_pageBlockTitle {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
        }
        public class Cons_pageBlockVideo {
            public var flags: Int32
            public var videoId: Int64
            public var caption: Api.PageCaption
            public init(flags: Int32, videoId: Int64, caption: Api.PageCaption) {
                self.flags = flags
                self.videoId = videoId
                self.caption = caption
            }
        }
        case pageBlockAnchor(Cons_pageBlockAnchor)
        case pageBlockAudio(Cons_pageBlockAudio)
        case pageBlockAuthorDate(Cons_pageBlockAuthorDate)
        case pageBlockBlockquote(Cons_pageBlockBlockquote)
        case pageBlockChannel(Cons_pageBlockChannel)
        case pageBlockCollage(Cons_pageBlockCollage)
        case pageBlockCover(Cons_pageBlockCover)
        case pageBlockDetails(Cons_pageBlockDetails)
        case pageBlockDivider
        case pageBlockEmbed(Cons_pageBlockEmbed)
        case pageBlockEmbedPost(Cons_pageBlockEmbedPost)
        case pageBlockFooter(Cons_pageBlockFooter)
        case pageBlockHeader(Cons_pageBlockHeader)
        case pageBlockKicker(Cons_pageBlockKicker)
        case pageBlockList(Cons_pageBlockList)
        case pageBlockMap(Cons_pageBlockMap)
        case pageBlockOrderedList(Cons_pageBlockOrderedList)
        case pageBlockParagraph(Cons_pageBlockParagraph)
        case pageBlockPhoto(Cons_pageBlockPhoto)
        case pageBlockPreformatted(Cons_pageBlockPreformatted)
        case pageBlockPullquote(Cons_pageBlockPullquote)
        case pageBlockRelatedArticles(Cons_pageBlockRelatedArticles)
        case pageBlockSlideshow(Cons_pageBlockSlideshow)
        case pageBlockSubheader(Cons_pageBlockSubheader)
        case pageBlockSubtitle(Cons_pageBlockSubtitle)
        case pageBlockTable(Cons_pageBlockTable)
        case pageBlockTitle(Cons_pageBlockTitle)
        case pageBlockUnsupported
        case pageBlockVideo(Cons_pageBlockVideo)

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

        public static func parse_pageBlockAnchor(_ reader: BufferReader) -> PageBlock? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_pageBlockAudio(_ reader: BufferReader) -> PageBlock? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_pageBlockAuthorDate(_ reader: BufferReader) -> PageBlock? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_pageBlockBlockquote(_ reader: BufferReader) -> PageBlock? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_pageBlockChannel(_ reader: BufferReader) -> PageBlock? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_pageBlockCollage(_ reader: BufferReader) -> PageBlock? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_pageBlockCover(_ reader: BufferReader) -> PageBlock? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_pageBlockDetails(_ reader: BufferReader) -> PageBlock? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_pageBlockDivider(_ reader: BufferReader) -> PageBlock? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_pageBlockEmbed(_ reader: BufferReader) -> PageBlock? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_pageBlockEmbedPost(_ reader: BufferReader) -> PageBlock? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_pageBlockFooter(_ reader: BufferReader) -> PageBlock? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_pageBlockHeader(_ reader: BufferReader) -> PageBlock? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_pageBlockKicker(_ reader: BufferReader) -> PageBlock? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_pageBlockList(_ reader: BufferReader) -> PageBlock? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_pageBlockMap(_ reader: BufferReader) -> PageBlock? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_pageBlockOrderedList(_ reader: BufferReader) -> PageBlock? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_pageBlockParagraph(_ reader: BufferReader) -> PageBlock? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_pageBlockPhoto(_ reader: BufferReader) -> PageBlock? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_pageBlockPreformatted(_ reader: BufferReader) -> PageBlock? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_pageBlockPullquote(_ reader: BufferReader) -> PageBlock? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_pageBlockRelatedArticles(_ reader: BufferReader) -> PageBlock? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_pageBlockSlideshow(_ reader: BufferReader) -> PageBlock? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_pageBlockSubheader(_ reader: BufferReader) -> PageBlock? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_pageBlockSubtitle(_ reader: BufferReader) -> PageBlock? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_pageBlockTable(_ reader: BufferReader) -> PageBlock? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_pageBlockTitle(_ reader: BufferReader) -> PageBlock? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_pageBlockUnsupported(_ reader: BufferReader) -> PageBlock? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_pageBlockVideo(_ reader: BufferReader) -> PageBlock? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
