public extension Api {
    enum NotificationSound: TypeConstructorDescription {
        case notificationSoundDefault
        case notificationSoundLocal(title: String, data: String)
        case notificationSoundNone
        case notificationSoundRingtone(id: Int64)

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
        case notifyBroadcasts
        case notifyChats
        case notifyForumTopic(peer: Api.Peer, topMsgId: Int32)
        case notifyPeer(peer: Api.Peer)
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
        case outboxReadDate(date: Int32)

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
        case page(flags: Int32, url: String, blocks: [Api.PageBlock], photos: [Api.Photo], documents: [Api.Document], views: Int32?)

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
        case pageBlockAnchor(name: String)
        case pageBlockAudio(audioId: Int64, caption: Api.PageCaption)
        case pageBlockAuthorDate(author: Api.RichText, publishedDate: Int32)
        case pageBlockBlockquote(text: Api.RichText, caption: Api.RichText)
        case pageBlockChannel(channel: Api.Chat)
        case pageBlockCollage(items: [Api.PageBlock], caption: Api.PageCaption)
        case pageBlockCover(cover: Api.PageBlock)
        case pageBlockDetails(flags: Int32, blocks: [Api.PageBlock], title: Api.RichText)
        case pageBlockDivider
        case pageBlockEmbed(flags: Int32, url: String?, html: String?, posterPhotoId: Int64?, w: Int32?, h: Int32?, caption: Api.PageCaption)
        case pageBlockEmbedPost(url: String, webpageId: Int64, authorPhotoId: Int64, author: String, date: Int32, blocks: [Api.PageBlock], caption: Api.PageCaption)
        case pageBlockFooter(text: Api.RichText)
        case pageBlockHeader(text: Api.RichText)
        case pageBlockKicker(text: Api.RichText)
        case pageBlockList(items: [Api.PageListItem])
        case pageBlockMap(geo: Api.GeoPoint, zoom: Int32, w: Int32, h: Int32, caption: Api.PageCaption)
        case pageBlockOrderedList(items: [Api.PageListOrderedItem])
        case pageBlockParagraph(text: Api.RichText)
        case pageBlockPhoto(flags: Int32, photoId: Int64, caption: Api.PageCaption, url: String?, webpageId: Int64?)
        case pageBlockPreformatted(text: Api.RichText, language: String)
        case pageBlockPullquote(text: Api.RichText, caption: Api.RichText)
        case pageBlockRelatedArticles(title: Api.RichText, articles: [Api.PageRelatedArticle])
        case pageBlockSlideshow(items: [Api.PageBlock], caption: Api.PageCaption)
        case pageBlockSubheader(text: Api.RichText)
        case pageBlockSubtitle(text: Api.RichText)
        case pageBlockTable(flags: Int32, title: Api.RichText, rows: [Api.PageTableRow])
        case pageBlockTitle(text: Api.RichText)
        case pageBlockUnsupported
        case pageBlockVideo(flags: Int32, videoId: Int64, caption: Api.PageCaption)

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
