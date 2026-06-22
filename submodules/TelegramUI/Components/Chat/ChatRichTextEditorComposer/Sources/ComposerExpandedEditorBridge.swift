import Foundation
import Postbox
import TelegramCore
import RichTextEditorCore

/// Convenience converters for the chat composer ↔ expanded article-editor (`RichTextAttachmentScreen`)
/// handoff. They wrap the structure-preserving `Document ↔ ChatInputContent` bridge with the media-store
/// collection / lookup the article editor speaks (`(Document, [String: Media])`), so the handoff can flow
/// entirely through the chat input STATE (`ChatInputContent`) rather than poking the composer node directly.

/// Stable, opaque editor-side key for a `Media`, derived from its `MediaId` (`"namespace:id"`), or an
/// object-identity fallback for an id-less medium. Shared by the composer node's media store
/// (`RichTextEditorChatInputNode.registerMediaValue`), the `documentAndMedia(fromChatInputContent:)` expand
/// seed, and `RichTextAttachmentScreen.attachedMedia`, so a medium keyed one way resolves the other.
public func composerMediaKey(_ media: Media) -> String {
    if let id = media.id {
        return "\(id.namespace):\(id.id)"
    } else {
        // No stable media id (rare): fall back to an object-identity key so the same value still
        // round-trips within a single set/get cycle.
        return "anon:\(ObjectIdentifier(media as AnyObject).hashValue)"
    }
}

/// Convert a chat-layer `ChatInputContent` to an editor `Document` plus the media store it references (keyed
/// by `composerMediaKey`) — the OUT (expand) half of the composer ↔ article-editor handoff. Custom emoji are
/// minted into the `Document` carrying only their fileId STRING (the article editor renders custom emoji via
/// its own emoji store, keyed by fileId); the `TelegramMediaFile` is intentionally dropped here. The inverse
/// is `chatInputContent(fromDocument:media:)`.
public func documentAndMedia(fromChatInputContent content: ChatInputContent) -> (document: Document, media: [String: Media]) {
    var media: [String: Media] = [:]
    let doc = document(
        fromChatInputContent: content,
        registerEmoji: { fileId, _ in EmojiRef(id: String(fileId), instanceID: BlockID.generate().rawValue, altText: nil) },
        registerMedia: { value in
            let key = composerMediaKey(value)
            media[key] = value
            return key
        }
    )
    return (document: doc, media: media)
}

/// Convert an expanded article editor's `Document` + its media store back to the chat-layer `ChatInputContent`
/// — the IN (collapse) half of the handoff (`RichTextAttachmentScreen.sendMessage`). The inverse of
/// `documentAndMedia(fromChatInputContent:)`. A medium is resolved from `media` (an unresolved key drops the
/// block); a custom emoji resolves to `(fileId, file: nil)` — the editor `Document` carries only the fileId,
/// and the chat decoration re-derives the `TelegramMediaFile` from it (the file is not part of
/// `ChatInputContent` equality, so this loses nothing the chat layer tracks). A non-numeric emoji id (should
/// not occur from this path) degrades the run to plain text.
public func chatInputContent(fromDocument document: Document, media: [String: Media]) -> ChatInputContent {
    return chatInputContent(
        fromDocument: document,
        resolveEmoji: { emojiRef in
            guard let fileId = Int64(emojiRef.id) else {
                return nil
            }
            return (fileId: fileId, file: nil)
        },
        resolveMedia: { mediaID in media[mediaID] }
    )
}
