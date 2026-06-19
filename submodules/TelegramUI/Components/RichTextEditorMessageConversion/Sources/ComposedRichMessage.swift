import Foundation
import TelegramCore
import Postbox
import RichTextEditorCore

/// The result of serializing a RichTextEditor `Document` into a sendable Telegram message.
public enum ComposedRichMessage {
    /// Structured content → a rich message (`RichTextMessageAttribute(instantPage:)`, sent with `text: ""`).
    case rich(instantPage: InstantPage)
    /// Entity-expressible content → a normal message (`text` + `TextEntitiesMessageAttribute`).
    case plain(text: String, entities: [MessageTextEntity])
    /// Nothing worth sending (empty / whitespace-only document).
    case empty
}

/// Serialize a RichTextEditor `Document` into a `ComposedRichMessage`.
public func composeRichMessage(from document: Document, media: [String: Media] = [:]) -> ComposedRichMessage {
    let blocks = trimmedTrailingEmpty(normalizedBlocks(document.blocks, media: media))
    if blocks.isEmpty {
        return .empty
    }
    if documentNeedsRichLayout(blocks) {
        return .rich(instantPage: buildInstantPage(from: blocks, media: media))
    } else {
        let message = buildEntityMessage(from: blocks)
        if message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .empty
        }
        return .plain(text: message.text, entities: message.entities)
    }
}

/// Pass paragraphs/tables through. Keep a media block whose `mediaID` resolves (it becomes an image/video
/// block downstream); for an UNresolvable media block, fall back to its caption as a body paragraph.
func normalizedBlocks(_ blocks: [Block], media: [String: Media]) -> [Block] {
    var out: [Block] = []
    for block in blocks {
        switch block {
        case .paragraph, .table:
            out.append(block)
        case let .media(mediaBlock):
            if media[mediaBlock.mediaID] != nil {
                out.append(block)
            } else if !mediaBlock.caption.isEmpty {
                out.append(.paragraph(ParagraphBlock(id: mediaBlock.id, style: .body, runs: mediaBlock.caption)))
            }
        }
    }
    return out
}

/// Trim trailing empty body/quote paragraphs (e.g. the editor's blank end paragraph).
func trimmedTrailingEmpty(_ blocks: [Block]) -> [Block] {
    var result = blocks
    while let last = result.last,
          case let .paragraph(paragraph) = last,
          paragraph.list == nil,
          paragraph.style == .body || paragraph.style == .quote,
          paragraph.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        result.removeLast()
    }
    return result
}

/// True when the content needs the rich (InstantPage) path: any table, heading/title, list item, or resolvable media block.
func documentNeedsRichLayout(_ blocks: [Block]) -> Bool {
    for block in blocks {
        switch block {
        case .table:
            return true
        case let .paragraph(paragraph):
            if paragraph.list != nil {
                return true
            }
            switch paragraph.style {
            case .heading1, .heading2, .heading3:
                return true
            case .body, .caption, .quote:
                break
            }
        case .media:
            // normalizedBlocks already dropped unresolvable media, so any surviving .media block forces rich layout.
            return true
        }
    }
    return false
}
