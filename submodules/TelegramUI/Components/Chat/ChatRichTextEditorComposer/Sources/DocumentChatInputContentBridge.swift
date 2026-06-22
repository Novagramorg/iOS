import Foundation
import Postbox
import TelegramCore
import RichTextEditorCore
import TextFormat

/// A DIRECT, structure-preserving bridge between the RichTextEditor `Document` and TelegramCore's
/// `ChatInputContent` value model — the draft currency for the native composer node.
///
/// This bypasses the `NSAttributedString` hop (`ComposerDocumentBridge`), which silently drops the
/// structural blocks the `NSAttributedString` vocabulary can't carry (`.media` / `.table`, plus
/// heading/list information). The mapping is a 1:1 block tree + inline-run transcode that reuses the
/// existing inline rules (link classification via `TextFormat`'s `classifyChatLink` / `mentionMarkdownURL`
/// / `dateMarkdownURL`; custom emoji ↔ `EmojiRef`; spoiler/bold/italic/mono/strike/underline) so the two
/// converters can't drift. The non-chat-representable character attributes (`fontFamily` / `fontSize` /
/// `foreground` / `highlight` / `baselineOffset`) are dropped, matching what the chat layer can express.
/// An editor `EmojiRef`'s `altText` / `instanceID` are also dropped — `ChatInputContent`'s
/// `customEmoji(fileId:file:enableAnimation:)` has no slot for them, so the emoji placeholder text degrades to a
/// bare `U+FFFC` on a `Document → ChatInputContent → Document` round-trip (an inherent model limitation; `altText`
/// is otherwise load-bearing on the send path). `enableAnimation` is canonicalized to `true` (no editor field).
///
/// The two media/emoji indirections are threaded as closures so the node (Task #44) supplies its own
/// host resolvers:
/// - `resolveEmoji` maps an editor `EmojiRef` to the chat layer's `(fileId, file)`; nil ⇒ the run degrades
///   to plain text (no representable emoji), matching `ComposerDocumentBridge`'s non-numeric-id fallback.
/// - `resolveMedia` maps the editor's opaque `MediaBlock.mediaID` to a concrete `Media`; nil ⇒ the media
///   block is dropped (an unresolved medium has no `ChatInputMedia` representation).
/// - `registerEmoji` / `registerMedia` are the reverse: they hand the chat-layer identity back to the host
///   and return the editor-side ref/key for it.

// MARK: - Document → ChatInputContent

/// Convert the editor's live `Document` to the chat-layer `ChatInputContent` value model.
/// `resolveEmoji` and `resolveMedia` map the editor's opaque host keys to concrete chat-layer values; an
/// unresolvable emoji degrades to plain text and an unresolvable medium is dropped (see the type doc).
public func chatInputContent(
    fromDocument document: Document,
    resolveEmoji: (EmojiRef) -> (fileId: Int64, file: TelegramMediaFile?)?,
    resolveMedia: (String) -> Media?
) -> ChatInputContent {
    var blocks: [ChatInputBlock] = []
    for block in document.blocks {
        switch block {
        case let .paragraph(paragraph):
            blocks.append(.paragraph(ChatInputParagraph(
                style: chatInputStyle(fromParagraphStyle: paragraph.style),
                list: paragraph.list.map(chatInputList(fromList:)),
                runs: chatInputRuns(fromRuns: paragraph.runs, resolveEmoji: resolveEmoji)
            )))
        case let .code(code):
            blocks.append(.code(ChatInputCode(
                language: code.language,
                runs: chatInputRuns(fromRuns: code.runs, resolveEmoji: resolveEmoji)
            )))
        case let .media(media):
            // An unresolved medium has no `ChatInputMedia` representation (`media:` is non-optional) — drop it.
            guard let resolved = resolveMedia(media.mediaID) else {
                continue
            }
            blocks.append(.media(ChatInputMedia(
                media: resolved,
                kind: chatInputMediaKind(fromKind: media.kind),
                naturalSize: ChatInputSize(width: media.naturalSize.width, height: media.naturalSize.height),
                displayWidth: media.displayWidth,
                alignment: chatInputMediaAlignment(fromAlignment: media.alignment),
                caption: chatInputRuns(fromRuns: media.caption, resolveEmoji: resolveEmoji)
            )))
        case let .table(table):
            blocks.append(.table(chatInputTable(fromTable: table, resolveEmoji: resolveEmoji)))
        }
    }
    return ChatInputContent(blocks: blocks)
}

private func chatInputStyle(fromParagraphStyle style: ParagraphStyleName) -> ChatInputParagraphStyle {
    switch style {
    case .body:
        return .body
    case .heading1:
        return .heading1
    case .heading2:
        return .heading2
    case .heading3:
        return .heading3
    case .quote:
        // The editor `quote` has no collapse flag — it is always a regular (expanded) quote.
        return .quote(isCollapsed: false)
    case .caption:
        // `caption` is a render-only style (only ever appears in a media block's caption runs, handled
        // there). A `caption`-styled top-level paragraph should not exist, but map it to `.body` defensively.
        return .body
    }
}

private func chatInputList(fromList list: ListMembership) -> ChatInputListMembership {
    let marker: ChatInputListMarker
    switch list.marker {
    case .bullet:
        marker = .bullet
    case .ordered:
        marker = .ordered
    }
    return ChatInputListMembership(marker: marker, level: Int32(list.level))
}

private func chatInputMediaKind(fromKind kind: MediaKind) -> ChatInputMediaKind {
    switch kind {
    case .image:
        return .image
    case .video:
        return .video
    }
}

private func chatInputMediaAlignment(fromAlignment alignment: MediaAlignment) -> ChatInputMediaAlignment {
    switch alignment {
    case .left:
        return .left
    case .center:
        return .center
    case .right:
        return .right
    }
}

private func chatInputTextAlignment(fromAlignment alignment: TextAlignment) -> ChatInputTextAlignment {
    switch alignment {
    case .left:
        return .left
    case .center:
        return .center
    case .right:
        return .right
    case .justified:
        return .justified
    }
}

private func chatInputColor(fromColor color: RGBAColor) -> ChatInputColor {
    return ChatInputColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
}

private func chatInputTable(
    fromTable table: TableBlock,
    resolveEmoji: (EmojiRef) -> (fileId: Int64, file: TelegramMediaFile?)?
) -> ChatInputTable {
    let columns = table.columns.map { column in
        ChatInputColumnSpec(width: column.width, alignment: chatInputTextAlignment(fromAlignment: column.alignment))
    }
    let rows = table.rows.map { row -> ChatInputTableRow in
        let cells = row.cells.map { cell -> ChatInputTableCell in
            // A `ChatInputTableCell` is inline-only (a flat run list). A well-formed editor cell holds a
            // single `.paragraph`; defensively flatten ANY cell content to runs (a non-paragraph block —
            // media/table/code — contributes its text only, ignoring structure the cell can't carry).
            ChatInputTableCell(
                runs: chatInputRuns(fromRuns: cellRuns(fromBlocks: cell.blocks), resolveEmoji: resolveEmoji),
                background: cell.background.map(chatInputColor(fromColor:))
            )
        }
        return ChatInputTableRow(height: row.height, isHeader: row.isHeader, cells: cells)
    }
    return ChatInputTable(columns: columns, rows: rows)
}

/// Flatten a table cell's blocks to a single run list. A paragraph contributes its runs verbatim; any other
/// block type contributes a plain-text run of its text (its structure is not representable inline). Blocks
/// are concatenated with no separator (cells are conceptually single-paragraph).
private func cellRuns(fromBlocks blocks: [Block]) -> [TextRun] {
    var runs: [TextRun] = []
    for block in blocks {
        switch block {
        case let .paragraph(paragraph):
            runs.append(contentsOf: paragraph.runs)
        case let .code(code):
            runs.append(contentsOf: code.runs)
        case let .media(media):
            // No inline text for the medium itself; keep only its caption text.
            runs.append(contentsOf: media.caption)
        case .table:
            // A nested table has no flat-run form; contribute nothing.
            break
        }
    }
    return runs
}

private func chatInputRuns(
    fromRuns runs: [TextRun],
    resolveEmoji: (EmojiRef) -> (fileId: Int64, file: TelegramMediaFile?)?
) -> [ChatInputRun] {
    return runs.map { run in
        ChatInputRun(text: run.text, attributes: chatInputInlineAttributes(fromCharacterAttributes: run.attributes, resolveEmoji: resolveEmoji))
    }
}

private func chatInputInlineAttributes(
    fromCharacterAttributes attributes: CharacterAttributes,
    resolveEmoji: (EmojiRef) -> (fileId: Int64, file: TelegramMediaFile?)?
) -> ChatInputInlineAttributes {
    // The entity slot is mutually exclusive (one of mention/url/date/customEmoji). Prefer the emoji over a
    // link when a run improbably carries both — matching `ComposerDocumentBridge`, which short-circuits on
    // a custom-emoji run before reading any other attribute.
    var entity: ChatInputInlineEntity?
    if let emoji = attributes.emoji, let resolved = resolveEmoji(emoji) {
        entity = .customEmoji(fileId: resolved.fileId, file: resolved.file, enableAnimation: true)
    } else if let link = attributes.link {
        switch classifyChatLink(link) {
        case let .mention(peerId):
            entity = .mention(peerId)
        case let .date(timestamp):
            entity = .date(timestamp)
        case let .url(url):
            entity = .url(url)
        }
    }
    return ChatInputInlineAttributes(
        bold: attributes.bold,
        italic: attributes.italic,
        monospace: attributes.inlineCode,
        strikethrough: attributes.strikethrough,
        underline: attributes.underline,
        spoiler: attributes.spoiler,
        entity: entity
    )
}

// MARK: - ChatInputContent → Document

/// Convert the chat-layer `ChatInputContent` value model back to an editor `Document`. `registerEmoji` and
/// `registerMedia` hand the chat-layer identity back to the host and return the editor-side ref/key for it.
/// A `.collapsedQuote` (no editor analogue) is flattened to expanded quote paragraphs.
public func document(
    fromChatInputContent content: ChatInputContent,
    registerEmoji: (Int64, TelegramMediaFile?) -> EmojiRef,
    registerMedia: (Media) -> String
) -> Document {
    var blocks: [Block] = []
    for block in content.blocks {
        blocks.append(contentsOf: documentBlocks(fromChatInputBlock: block, registerEmoji: registerEmoji, registerMedia: registerMedia))
    }
    return Document(blocks: blocks)
}

/// One chat-input block maps to one or more editor blocks (a `.collapsedQuote` expands to N quote
/// paragraphs).
private func documentBlocks(
    fromChatInputBlock block: ChatInputBlock,
    registerEmoji: (Int64, TelegramMediaFile?) -> EmojiRef,
    registerMedia: (Media) -> String
) -> [Block] {
    switch block {
    case let .paragraph(paragraph):
        return [.paragraph(ParagraphBlock(
            id: BlockID.generate(),
            style: paragraphStyle(fromChatInputStyle: paragraph.style),
            list: paragraph.list.map(list(fromChatInputList:)),
            runs: runs(fromChatInputRuns: paragraph.runs, registerEmoji: registerEmoji)
        ))]
    case let .code(code):
        return [.code(CodeBlock(
            id: BlockID.generate(),
            language: code.language,
            runs: runs(fromChatInputRuns: code.runs, registerEmoji: registerEmoji)
        ))]
    case let .collapsedQuote(inner):
        // The editor has no folded-quote block — flatten the inner content's blocks to EXPANDED quote
        // paragraphs (recursing, so a nested collapsed quote also flattens). A non-paragraph inner block is
        // re-mapped normally (it keeps its own block type), then any inner paragraph is forced to `.quote`.
        var result: [Block] = []
        for innerBlock in inner.blocks {
            for mapped in documentBlocks(fromChatInputBlock: innerBlock, registerEmoji: registerEmoji, registerMedia: registerMedia) {
                if case var .paragraph(paragraph) = mapped {
                    paragraph.style = .quote
                    result.append(.paragraph(paragraph))
                } else {
                    result.append(mapped)
                }
            }
        }
        return result
    case let .media(media):
        return [.media(MediaBlock(
            id: BlockID.generate(),
            mediaID: registerMedia(media.media),
            kind: mediaKind(fromChatInputKind: media.kind),
            naturalSize: Size2D(width: media.naturalSize.width, height: media.naturalSize.height),
            displayWidth: media.displayWidth,
            alignment: mediaAlignment(fromChatInputAlignment: media.alignment),
            caption: runs(fromChatInputRuns: media.caption, registerEmoji: registerEmoji)
        ))]
    case let .table(table):
        return [.table(tableBlock(fromChatInputTable: table, registerEmoji: registerEmoji))]
    }
}

private func paragraphStyle(fromChatInputStyle style: ChatInputParagraphStyle) -> ParagraphStyleName {
    switch style {
    case .body:
        return .body
    case .heading1:
        return .heading1
    case .heading2:
        return .heading2
    case .heading3:
        return .heading3
    case .quote:
        // The editor `quote` carries no collapse flag — both `.quote(isCollapsed: false/true)` map to it.
        return .quote
    }
}

private func list(fromChatInputList list: ChatInputListMembership) -> ListMembership {
    let marker: ListMarker
    switch list.marker {
    case .bullet:
        marker = .bullet
    case .ordered:
        marker = .ordered
    }
    return ListMembership(marker: marker, level: Int(list.level))
}

private func mediaKind(fromChatInputKind kind: ChatInputMediaKind) -> MediaKind {
    switch kind {
    case .image:
        return .image
    case .video:
        return .video
    }
}

private func mediaAlignment(fromChatInputAlignment alignment: ChatInputMediaAlignment) -> MediaAlignment {
    switch alignment {
    case .left:
        return .left
    case .center:
        return .center
    case .right:
        return .right
    }
}

private func textAlignment(fromChatInputAlignment alignment: ChatInputTextAlignment) -> TextAlignment {
    switch alignment {
    case .left:
        return .left
    case .center:
        return .center
    case .right:
        return .right
    case .justified:
        return .justified
    }
}

private func color(fromChatInputColor color: ChatInputColor) -> RGBAColor {
    return RGBAColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
}

private func tableBlock(
    fromChatInputTable table: ChatInputTable,
    registerEmoji: (Int64, TelegramMediaFile?) -> EmojiRef
) -> TableBlock {
    let columns = table.columns.map { column in
        ColumnSpec(width: column.width, alignment: textAlignment(fromChatInputAlignment: column.alignment))
    }
    let rows = table.rows.map { row -> Row in
        let cells = row.cells.map { cell -> Cell in
            // A `ChatInputTableCell` is a flat run list; wrap it back into the editor's expected single
            // body paragraph per cell.
            Cell(
                id: BlockID.generate(),
                blocks: [.paragraph(ParagraphBlock(
                    id: BlockID.generate(),
                    style: .body,
                    runs: runs(fromChatInputRuns: cell.runs, registerEmoji: registerEmoji)
                ))],
                background: cell.background.map(color(fromChatInputColor:))
            )
        }
        return Row(id: BlockID.generate(), height: row.height, isHeader: row.isHeader, cells: cells)
    }
    return TableBlock(id: BlockID.generate(), columns: columns, rows: rows)
}

private func runs(
    fromChatInputRuns runs: [ChatInputRun],
    registerEmoji: (Int64, TelegramMediaFile?) -> EmojiRef
) -> [TextRun] {
    return runs.map { run in
        TextRun(text: run.text, attributes: characterAttributes(fromChatInputInlineAttributes: run.attributes, registerEmoji: registerEmoji))
    }
}

private func characterAttributes(
    fromChatInputInlineAttributes attributes: ChatInputInlineAttributes,
    registerEmoji: (Int64, TelegramMediaFile?) -> EmojiRef
) -> CharacterAttributes {
    var result = CharacterAttributes.plain
    result.bold = attributes.bold
    result.italic = attributes.italic
    result.inlineCode = attributes.monospace
    result.strikethrough = attributes.strikethrough
    result.underline = attributes.underline
    result.spoiler = attributes.spoiler
    // The entity slot is mutually exclusive — emoji lands in `emoji`, mention/date/url in the shared `link`
    // field as a `tg://` marker (mention/date) or the raw URL, symmetric with the forward classifier.
    if let entity = attributes.entity {
        switch entity {
        case let .customEmoji(fileId, file, _):
            result.emoji = registerEmoji(fileId, file)
        case let .mention(peerId):
            result.link = mentionMarkdownURL(peerId: peerId)
        case let .date(timestamp):
            result.link = dateMarkdownURL(timestamp: timestamp)
        case let .url(url):
            result.link = url
        }
    }
    return result
}
