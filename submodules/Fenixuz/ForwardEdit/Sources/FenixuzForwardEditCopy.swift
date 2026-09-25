import Foundation
import Postbox
import TelegramCore
import TextFormat

/// The post the user is forwarding: one message, or one album (up to 10 grouped messages).
struct FenixuzForwardEditSource {
    enum PreviewItem {
        case photo(message: Message, image: TelegramMediaImage)
        case video(message: Message, file: TelegramMediaFile)
        case file(file: TelegramMediaFile)
    }

    /// Sorted by id, which is the album order.
    let messages: [Message]
    /// The message whose text the editor shows — the album caption, or the post text.
    let captionMessage: Message
    let previewItems: [PreviewItem]
    /// Users can't send inline keyboards, so a copy always loses them.
    let hasButtons: Bool

    var hasMedia: Bool {
        return !self.previewItems.isEmpty
    }

    init?(messages: [Message], targetPeerId: PeerId) {
        // The copy re-sends the media by its cloud id, which a secret chat can't take.
        if targetPeerId.namespace == Namespaces.Peer.SecretChat {
            return nil
        }
        let sortedMessages = messages.sorted(by: { $0.id < $1.id })
        guard let firstMessage = sortedMessages.first, sortedMessages.count <= FenixuzForwardEditCopy.maxAlbumSize else {
            return nil
        }
        // Several messages only make sense as one album. Several separate posts would need
        // several editors, so the menu item is simply not offered for them.
        if sortedMessages.count > 1 {
            guard let groupingKey = firstMessage.groupingKey, sortedMessages.allSatisfy({ $0.groupingKey == groupingKey }) else {
                return nil
            }
        }

        var previewItems: [PreviewItem] = []
        var hasButtons = false
        for message in sortedMessages {
            if message.id.namespace != Namespaces.Message.Cloud || message.isCopyProtected() || message.richText != nil {
                return nil
            }
            guard let content = FenixuzForwardEditCopy.content(of: message) else {
                return nil
            }
            switch content {
            case .text, .webpage:
                if sortedMessages.count > 1 {
                    return nil
                }
            case let .media(media):
                if let image = media as? TelegramMediaImage {
                    previewItems.append(.photo(message: message, image: image))
                } else if let file = media as? TelegramMediaFile {
                    if file.isVideo {
                        previewItems.append(.video(message: message, file: file))
                    } else {
                        previewItems.append(.file(file: file))
                    }
                }
            }
            if let markup = message.attributes.first(where: { $0 is ReplyMarkupMessageAttribute }) as? ReplyMarkupMessageAttribute, !markup.rows.isEmpty {
                hasButtons = true
            }
        }

        let captionMessage = sortedMessages.first(where: { !$0.text.isEmpty }) ?? firstMessage
        if previewItems.isEmpty && captionMessage.text.isEmpty {
            return nil
        }

        self.messages = sortedMessages
        self.captionMessage = captionMessage
        self.previewItems = previewItems
        self.hasButtons = hasButtons
    }
}

/// Builds the new messages that replace a forward: same media (re-sent by cloud reference, no
/// upload), edited text, no forward header. Like the Bot API `copyMessage`.
enum FenixuzForwardEditCopy {
    static let maxAlbumSize = 10
    /// Telegram's limit for a plain text message; captions use the account's caption limit.
    static let maxTextLength = 4096

    enum Content {
        case text
        case media(Media)
        case webpage(TelegramMediaWebpage)
    }

    /// What a message carries, or nil when it holds something a copy can't reproduce
    /// (poll, location, contact, dice, story, paid media, sticker, round video, …).
    static func content(of message: Message) -> Content? {
        var result: Content = .text
        for media in message.media {
            guard case .text = result else {
                return nil
            }
            if let image = media as? TelegramMediaImage {
                guard let reference = image.reference, case .cloud = reference else {
                    return nil
                }
                result = .media(image)
            } else if let file = media as? TelegramMediaFile {
                guard file.resource is CloudDocumentMediaResource else {
                    return nil
                }
                if file.isSticker || file.isInstantVideo || file.isCustomEmoji || file.isAnimatedSticker || file.isVideoSticker {
                    return nil
                }
                result = .media(file)
            } else if let webpage = media as? TelegramMediaWebpage {
                result = .webpage(webpage)
            } else {
                return nil
            }
        }
        return result
    }

    /// Text the editor starts with, in the chat-input attribute format.
    static func initialInputText(source: FenixuzForwardEditSource, allowCustomEmoji: Bool) -> NSAttributedString {
        let message = source.captionMessage
        var entities = message.textEntitiesAttribute?.entities ?? []
        if !allowCustomEmoji {
            // Without Premium the server drops custom emoji, so show plain emoji from the start.
            entities = removingCustomEmoji(entities)
        }
        return chatInputStateStringWithAppliedEntities(message.text, entities: entities)
    }

    static func removingCustomEmoji(_ entities: [MessageTextEntity]) -> [MessageTextEntity] {
        return entities.filter { entity in
            if case .CustomEmoji = entity.type {
                return false
            }
            return true
        }
    }

    static func makeMessages(source: FenixuzForwardEditSource, text: String, entities: [MessageTextEntity], inlineStickers: [MediaId: Media], threadId: Int64?, allowCustomEmoji: Bool) -> [EnqueueMessage] {
        let groupingKey: Int64? = source.messages.count > 1 ? Int64.random(in: Int64.min ... Int64.max) : nil

        var result: [EnqueueMessage] = []
        for message in source.messages {
            let messageText: String
            var messageEntities: [MessageTextEntity]
            if message.id == source.captionMessage.id {
                messageText = text
                messageEntities = entities
            } else {
                // Other album items keep their own captions untouched.
                messageText = message.text
                messageEntities = message.textEntitiesAttribute?.entities ?? []
            }
            if !allowCustomEmoji {
                messageEntities = removingCustomEmoji(messageEntities)
            }

            var attributes: [MessageAttribute] = []
            if !messageEntities.isEmpty {
                attributes.append(TextEntitiesMessageAttribute(entities: messageEntities))
            }

            var mediaReference: AnyMediaReference?
            switch content(of: message) {
            case let .media(media):
                mediaReference = .message(message: MessageReference(message), media: media)
                for attribute in message.attributes {
                    if attribute is MediaSpoilerMessageAttribute || attribute is InvertMediaMessageAttribute {
                        attributes.append(attribute)
                    }
                }
            case let .webpage(webpage):
                if case let .Loaded(webpageContent) = webpage.content, keepsLinkPreview(webpageContent, source: message, editedText: messageText, editedEntities: messageEntities) {
                    mediaReference = .standalone(media: webpage)
                    for attribute in message.attributes {
                        if attribute is WebpagePreviewMessageAttribute || attribute is InvertMediaMessageAttribute {
                            attributes.append(attribute)
                        }
                    }
                }
                // Otherwise the previewed link was removed: let the server preview what is left,
                // the same as a freshly typed post.
            case .text, .none:
                // The original showed no preview although it had links, so keep it that way.
                if hasLinks(messageEntities) {
                    attributes.append(OutgoingContentInfoMessageAttribute(flags: [.disableLinkPreviews]))
                }
            }

            var messageInlineStickers: [MediaId: Media] = [:]
            for entity in messageEntities {
                if case let .CustomEmoji(_, fileId) = entity.type {
                    let mediaId = MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)
                    if let file = inlineStickers[mediaId] ?? message.associatedMedia[mediaId] {
                        messageInlineStickers[mediaId] = file
                    }
                }
            }

            result.append(.message(
                text: messageText,
                attributes: attributes,
                inlineStickers: messageInlineStickers,
                mediaReference: mediaReference,
                threadId: threadId,
                replyToMessageId: nil,
                replyToStoryId: nil,
                localGroupingKey: groupingKey,
                correlationId: nil,
                bubbleUpEmojiOrStickersets: []
            ))
        }
        return result
    }

    private static func hasLinks(_ entities: [MessageTextEntity]) -> Bool {
        return entities.contains { entity in
            switch entity.type {
            case .Url, .TextUrl:
                return true
            default:
                return false
            }
        }
    }

    /// The preview stays only while the text still links to the previewed page. A preview whose
    /// link was never in the text (attached by hand) always stays.
    private static func keepsLinkPreview(_ webpage: TelegramMediaWebpageLoadedContent, source: Message, editedText: String, editedEntities: [MessageTextEntity]) -> Bool {
        let targets = Set([normalizedLink(webpage.url), normalizedLink(webpage.displayUrl)])
        let sourceEntities = source.textEntitiesAttribute?.entities ?? []
        if !links(text: source.text, entities: sourceEntities).contains(where: { targets.contains($0) }) {
            return true
        }
        return links(text: editedText, entities: editedEntities).contains(where: { targets.contains($0) })
    }

    private static func links(text: String, entities: [MessageTextEntity]) -> [String] {
        let nsText = text as NSString
        var result: [String] = []
        for entity in entities {
            switch entity.type {
            case .Url:
                let range = NSRange(location: entity.range.lowerBound, length: entity.range.count)
                if range.location >= 0 && range.location + range.length <= nsText.length {
                    result.append(normalizedLink(nsText.substring(with: range)))
                }
            case let .TextUrl(url):
                result.append(normalizedLink(url))
            default:
                break
            }
        }
        return result
    }

    private static func normalizedLink(_ link: String) -> String {
        var value = link.lowercased()
        for prefix in ["https://", "http://"] where value.hasPrefix(prefix) {
            value.removeFirst(prefix.count)
        }
        if value.hasPrefix("www.") {
            value.removeFirst(4)
        }
        while value.hasSuffix("/") {
            value.removeLast()
        }
        return value
    }
}
