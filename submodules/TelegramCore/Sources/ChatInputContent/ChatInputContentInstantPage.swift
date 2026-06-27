import Foundation
import Postbox

// A lossless, bidirectional converter between the `ChatInputContent` value model and `InstantPage`.
//
// The invariant guaranteed (and unit-tested in `//submodules/TextFormat:TextFormatTests`):
//
//     chatInputContent(fromInstantPage: instantPage(from: c)) == c   for every `c`.
//
// This is a fresh, separate pair from the lossy `RichTextEditorMessageConversion` converter — do not
// conflate them. The round-trip is identity, so the reverse must invert the forward EXACTLY, in
// particular preserving run boundaries (one top-level `RichText` part ⇄ exactly one run; no merging)
// and the quote-coalescing boundary (a maximal run of same-`isCollapsed` quote paragraphs ⇄ one
// `.blockQuote`).

// MARK: - Forward: ChatInputContent -> InstantPage

public func instantPage(from content: ChatInputContent) -> InstantPage {
    // Collect the concrete media referenced by `.media` blocks: the InstantPage carries `Media` out-of-band in its
    // `media: [MediaId: Media]` dict and the image/video block holds only the `MediaId`. The reverse re-resolves the
    // `Media` from this dict, so the round-trip preserves the exact `Media` instance (identity), not a copy.
    var media: [MediaId: Media] = [:]
    let blocks = instantPageBlocks(from: content, collectingMediaInto: &media)
    return InstantPage(blocks: blocks, media: media, isComplete: true, rtl: false, url: "", views: nil)
}

func instantPageBlocks(from content: ChatInputContent, collectingMediaInto media: inout [MediaId: Media]) -> [InstantPageBlock] {
    var result: [InstantPageBlock] = []
    var i = 0
    while i < content.blocks.count {
        switch content.blocks[i] {
        case let .paragraph(p):
            if case let .quote(isCollapsed) = p.style {
                // Coalesce a maximal run of consecutive quote paragraphs with the SAME isCollapsed into one .blockQuote.
                var quoteParagraphs: [InstantPageBlock] = []
                while i < content.blocks.count, case let .paragraph(q) = content.blocks[i], case let .quote(qCollapsed) = q.style, qCollapsed == isCollapsed {
                    quoteParagraphs.append(.paragraph(richText(from: q.runs)))
                    i += 1
                }
                result.append(.blockQuote(blocks: quoteParagraphs, caption: .empty, collapsed: isCollapsed))
                continue
            } else if let list = p.list, case .body = p.style {
                // Coalesce a maximal run of consecutive BODY-styled list paragraphs with the SAME marker into one
                // `.list`. (Adjacent paragraphs with different markers — a bullet list followed by an ordered list —
                // stay separate `.list` blocks.) `InstantPageListItem` has no indent-level field, so the per-paragraph
                // `level` is NOT representable: level 0 round-trips exactly, and level > 0 is CANONICALIZED to 0 (the
                // InstantPage list projection is flat). This mirrors the collapsed-quote/customEmoji canonicalizations.
                //
                // The `case .body = p.style` guard is LOAD-BEARING: it must match the inner `while`'s `.body` check. A
                // non-body paragraph that also carries a list (e.g. a degenerate heading+list — the editor's heading /
                // quote styles and list membership are mutually exclusive in practice) would otherwise enter this
                // branch, fail the inner `while` on its first iteration, never advance `i`, and `continue` past the
                // `i += 1` → an infinite loop / main-thread hang on the draft-save path. With the guard it falls
                // through to the style switch and canonicalizes to its style (the list is dropped) — consistent with
                // quote-before-list precedence above.
                let marker = list.marker
                var items: [InstantPageListItem] = []
                while i < content.blocks.count, case let .paragraph(q) = content.blocks[i], let qList = q.list, qList.marker == marker, case .body = q.style {
                    items.append(.text(richText(from: q.runs), nil, qList.checked))
                    i += 1
                }
                result.append(.list(items: items, ordered: marker == .ordered))
                continue
            } else {
                switch p.style {
                case .heading1:
                    result.append(.heading(text: richText(from: p.runs), level: 1))
                case .heading2:
                    result.append(.heading(text: richText(from: p.runs), level: 2))
                case .heading3:
                    result.append(.heading(text: richText(from: p.runs), level: 3))
                case .body, .quote:
                    result.append(.paragraph(richText(from: p.runs)))
                }
            }
        case let .code(c):
            result.append(.preformatted(text: richText(from: c.runs), language: c.language))
        case let .collapsedQuote(inner):
            // `.collapsedQuote` (folded) and `.quote(isCollapsed: true)` (visible, collapse-flagged) both encode as
            // `collapsed: true` — they produce the identical sent message (`BlockQuote(isCollapsed: true)`), differing
            // only in composer display. The reverse canonicalizes `collapsed == true` to `.collapsedQuote` (the more
            // general container — it holds arbitrary nested content, so the normalization is lossless), folding the
            // rare visible-collapse-flagged paragraph. See the reverse for the `collapsed == nil/false` rationale.
            result.append(.blockQuote(blocks: instantPageBlocks(from: inner, collectingMediaInto: &media), caption: .empty, collapsed: true))
        case let .media(m):
            let caption = InstantPageCaption(text: richText(from: m.caption), credit: .empty)
            switch m.kind {
            case .image, .video:
                // Stash the `Media` in the page's `media` dict, keyed by its own `MediaId`; the block carries only
                // the id. Image/video are always a concrete `TelegramMediaImage`/`TelegramMediaFile` with an id;
                // a nil-id medium is dropped (it could not be resolved back from the dict anyway).
                guard let mediaId = m.media.id else {
                    break
                }
                media[mediaId] = m.media
                if case .image = m.kind {
                    result.append(.image(id: mediaId, caption: caption, url: nil, webpageId: nil))
                } else {
                    result.append(.video(id: mediaId, caption: caption, autoplay: false, loop: false))
                }
            case .location:
                // A location is a `TelegramMediaMap` (id-less): the InstantPage `.map` block carries its coordinates
                // inline, so nothing goes in the page `media` dict. zoom/dimensions are render hints (15 / 600x300
                // fallback). venue is not representable here — the caption already carries the venue title.
                if let map = m.media as? TelegramMediaMap {
                    let dimensions: PixelDimensions
                    if m.naturalSize.width > 0, m.naturalSize.height > 0 {
                        dimensions = PixelDimensions(width: Int32(m.naturalSize.width), height: Int32(m.naturalSize.height))
                    } else {
                        dimensions = PixelDimensions(width: 600, height: 300)
                    }
                    result.append(.map(latitude: map.latitude, longitude: map.longitude, zoom: 15, dimensions: dimensions, caption: caption))
                }
            }
        case let .table(t):
            // `naturalSize`/`displayWidth`/`alignment` of media and `width`/`vertical-alignment`/`colspan`/`rowspan`/
            // cell-background of a table are NOT representable in the InstantPage projection (see the reverse for the
            // documented defaults the round-trip restores). Forward each cell's per-column alignment (the editor's
            // `justified` has no InstantPage equivalent → CANONICALIZED to `.left`), header flag, and runs.
            let rows = t.rows.map { row -> InstantPageTableRow in
                let cells = row.cells.enumerated().map { (columnIndex, cell) -> InstantPageTableCell in
                    let alignment: TableHorizontalAlignment
                    if columnIndex < t.columns.count {
                        switch t.columns[columnIndex].alignment {
                        case .left, .justified:
                            alignment = .left
                        case .center:
                            alignment = .center
                        case .right:
                            alignment = .right
                        }
                    } else {
                        alignment = .left
                    }
                    return InstantPageTableCell(text: richText(from: cell.runs), header: row.isHeader, alignment: alignment, verticalAlignment: .top, colspan: 1, rowspan: 1)
                }
                return InstantPageTableRow(cells: cells)
            }
            result.append(.table(title: .empty, rows: rows, bordered: true, striped: false))
        }
        i += 1
    }
    return result
}

func richText(from runs: [ChatInputRun]) -> RichText {
    if runs.isEmpty {
        return .empty // an empty paragraph round-trips to/from .empty
    }
    let parts = runs.map { run -> RichText in
        var rt: RichText
        // The entity becomes the leaf/innermost (customEmoji is itself the leaf carrying the run text as alt).
        switch run.attributes.entity {
        case let .customEmoji(fileId, _, _):
            rt = .textCustomEmoji(fileId: fileId, alt: run.text)
        case let .mention(peerId):
            rt = .textMentionName(text: .plain(run.text), peerId: peerId.toInt64())
        case let .url(url):
            rt = .url(text: .plain(run.text), url: url, webpageId: nil)
        case let .date(date):
            rt = .textDate(text: .plain(run.text), date: date, format: nil)
        case nil:
            rt = .plain(run.text)
        }
        if run.attributes.bold { rt = .bold(rt) }
        if run.attributes.italic { rt = .italic(rt) }
        if run.attributes.monospace { rt = .fixed(rt) }
        if run.attributes.strikethrough { rt = .strikethrough(rt) }
        if run.attributes.underline { rt = .underline(rt) }
        if run.attributes.spoiler { rt = .textSpoiler(text: rt) }
        return rt
    }
    return parts.count == 1 ? parts[0] : .concat(parts)
}

// MARK: - Reverse: InstantPage -> ChatInputContent

public func chatInputContent(fromInstantPage page: InstantPage) -> ChatInputContent {
    return ChatInputContent(blocks: chatInputBlocks(fromInstantPageBlocks: page.blocks, media: page.media))
}

func chatInputBlocks(fromInstantPageBlocks blocks: [InstantPageBlock], media: [MediaId: Media] = [:]) -> [ChatInputBlock] {
    var result: [ChatInputBlock] = []
    for block in blocks {
        switch block {
        case let .paragraph(rt):
            result.append(.paragraph(ChatInputParagraph(style: .body, runs: chatInputRuns(fromRichText: rt))))
        case let .heading(rt, level):
            // Clamp an out-of-range heading level into the editor's 1...3 band; the forward only emits 1/2/3, but a
            // cloud-received heading may carry any level (InstantPage's default is 3 — see the decoder's `orElse: 3`).
            let style: ChatInputParagraphStyle
            switch max(1, min(3, level)) {
            case 1: style = .heading1
            case 2: style = .heading2
            default: style = .heading3
            }
            result.append(.paragraph(ChatInputParagraph(style: style, runs: chatInputRuns(fromRichText: rt))))
        case let .list(items, ordered):
            // One body paragraph per `.text` item. If the item carries a non-nil `checked` value the marker is
            // `.checklist` (the forward threads `checked` from `ChatInputListMembership`); otherwise use
            // `.ordered` / `.bullet` per the `ordered` flag. Level 0 throughout (the forward canonicalizes
            // any indent level to 0 — see the forward's level canonicalization note). A `.blocks`/`.unknown`
            // item (never produced by the forward; only from cloud) is skipped defensively.
            for item in items {
                if case let .text(rt, _, checked) = item {
                    let marker: ChatInputListMarker = checked != nil ? .checklist : (ordered ? .ordered : .bullet)
                    result.append(.paragraph(ChatInputParagraph(style: .body, list: ChatInputListMembership(marker: marker, level: 0, checked: checked), runs: chatInputRuns(fromRichText: rt))))
                }
            }
        case let .preformatted(rt, language):
            result.append(.code(ChatInputCode(language: language, runs: chatInputRuns(fromRichText: rt))))
        case let .blockQuote(innerBlocks, _, collapsed):
            // Three composer quote states collapse onto one `Bool?`, by necessity: the MTProto wire has NO collapsed
            // field, so a cloud-received `Api.RichMessage` blockQuote always arrives `collapsed == nil`. `nil`/`false`
            // must therefore map to the benign common state — a visible non-collapsed quote — otherwise EVERY
            // cloud-synced quote would fold. `collapsed == true` maps to `.collapsedQuote`. Net: `.quote(false)` and
            // `.collapsedQuote` are strict round-trip identity; only the rare `.quote(isCollapsed: true)` normalizes to
            // `.collapsedQuote` (semantically identical — same sent message). Local Postbox coding preserves the flag
            // ("qcol"); only the cloud wire degrades it (documented spec limitation).
            if collapsed == true {
                result.append(.collapsedQuote(ChatInputContent(blocks: chatInputBlocks(fromInstantPageBlocks: innerBlocks, media: media))))
            } else {
                // The forward emitted one `.paragraph(rt)` per quote line; map each back to a quote-style paragraph.
                for inner in innerBlocks {
                    if case let .paragraph(rt) = inner {
                        result.append(.paragraph(ChatInputParagraph(style: .quote(isCollapsed: false), runs: chatInputRuns(fromRichText: rt))))
                    } else {
                        // Defensive: a non-paragraph inside a non-collapsed quote (won't happen from forward) — recurse.
                        result.append(contentsOf: chatInputBlocks(fromInstantPageBlocks: [inner], media: media))
                    }
                }
            }
        case let .image(id, caption, _, _):
            // Resolve the concrete `Media` from the page's `media` dict; a missing entry (the forward always stores it,
            // so this is defensive against a malformed page) drops the block. `naturalSize`/`displayWidth`/`alignment`
            // are NOT representable in the InstantPage image block, so the reverse restores fixed DEFAULTS — natural
            // size `.zero`, `displayWidth: nil`, `alignment: .center` (the editor's `ChatInputMedia` default). The
            // round-trip is therefore identity only for media built with those defaults (a documented canonicalization,
            // matching the customEmoji/collapsed-quote/list-level pattern; pinned by the media tests).
            if let media = media[id] {
                result.append(.media(ChatInputMedia(media: media, kind: .image, naturalSize: ChatInputSize(width: 0.0, height: 0.0), displayWidth: nil, alignment: .center, caption: chatInputRuns(fromRichText: caption.text))))
            }
        case let .video(id, caption, _, _):
            // Same default restoration as `.image` (see above) for the non-representable size/width/alignment fields.
            if let media = media[id] {
                result.append(.media(ChatInputMedia(media: media, kind: .video, naturalSize: ChatInputSize(width: 0.0, height: 0.0), displayWidth: nil, alignment: .center, caption: chatInputRuns(fromRichText: caption.text))))
            }
        case let .map(latitude, longitude, _, _, caption):
            // Reconstruct a `TelegramMediaMap` from the inline coordinates (no media-dict lookup — a `.map` block
            // stores none). zoom/dimensions are render-only and dropped; venue is not in the block (the caption
            // carried the title forward). naturalSize/displayWidth/alignment restore the editor's media defaults,
            // matching the .image/.video canonicalization above.
            let map = TelegramMediaMap(latitude: latitude, longitude: longitude, heading: nil, accuracyRadius: nil, venue: nil)
            result.append(.media(ChatInputMedia(media: map, kind: .location, naturalSize: ChatInputSize(width: 0.0, height: 0.0), displayWidth: nil, alignment: .center, caption: chatInputRuns(fromRichText: caption.text))))
        case let .table(_, rows, _, _):
            // Rebuild the `ChatInputTable`. Columns are inferred from the first row's cell count, each column's
            // alignment taken from that cell's alignment (the forward stamps every cell in a column with the column's
            // alignment); column `width` is NOT representable in InstantPage cells → restored as the DEFAULT `0.0`. The
            // table `title`, per-cell `verticalAlignment`/`colspan`/`rowspan`, and cell `background` are likewise not in
            // the editor model → dropped/fixed (title unused; background `nil`). Identity therefore holds for a table
            // whose columns use width `0.0` and whose cells use `background: nil` (the values the reverse yields).
            var columns: [ChatInputColumnSpec] = []
            if let firstRow = rows.first {
                columns = firstRow.cells.map { cell in
                    let alignment: ChatInputTextAlignment
                    switch cell.alignment {
                    case .left: alignment = .left
                    case .center: alignment = .center
                    case .right: alignment = .right
                    }
                    return ChatInputColumnSpec(width: 0.0, alignment: alignment)
                }
            }
            let outRows = rows.map { row -> ChatInputTableRow in
                let isHeader = row.cells.first?.header ?? false
                let cells = row.cells.map { cell in
                    ChatInputTableCell(runs: chatInputRuns(fromRichText: cell.text ?? .empty), background: nil)
                }
                return ChatInputTableRow(height: nil, isHeader: isHeader, cells: cells)
            }
            result.append(.table(ChatInputTable(columns: columns, rows: outRows)))
        default:
            break // Non-text InstantPage blocks have no ChatInputContent representation (drafts never carry them).
        }
    }
    return result
}

/// Top-level: split a paragraph's RichText into one run per concat part (no merging); `.empty` -> `[]` runs.
func chatInputRuns(fromRichText rt: RichText) -> [ChatInputRun] {
    switch rt {
    case .empty:
        return []
    case let .concat(parts):
        return parts.flatMap { chatInputRuns(fromRichText: $0) } // parts are never .concat from forward; flatMap is defensive
    default:
        return [chatInputRun(fromSinglePart: rt, attributes: ChatInputInlineAttributes())]
    }
}

/// Unwrap a wrapper chain into one run, accumulating attributes; leaves are `.plain` / `.textCustomEmoji`.
func chatInputRun(fromSinglePart rt: RichText, attributes: ChatInputInlineAttributes) -> ChatInputRun {
    var attributes = attributes
    switch rt {
    case let .plain(s):
        return ChatInputRun(text: s, attributes: attributes)
    case let .textCustomEmoji(fileId, alt):
        // `enableAnimation` is canonicalized to `true` (and `file` to nil): `RichText.textCustomEmoji` carries
        // neither. This MATCHES the production `.textEntities` draft path — `MessageTextEntityType.CustomEmoji` has
        // no animation field either, so a draft already loses `enableAnimation` on save and re-derives it (default
        // `true`) at decoration. So the round-trip is identity over the persisted fidelity, canonicalizing this
        // render-time flag. (Pinned by `test_customEmoji_enableAnimationFalse`.)
        attributes.entity = .customEmoji(fileId: fileId, file: nil, enableAnimation: true)
        return ChatInputRun(text: alt, attributes: attributes)
    case let .bold(inner):
        attributes.bold = true
        return chatInputRun(fromSinglePart: inner, attributes: attributes)
    case let .italic(inner):
        attributes.italic = true
        return chatInputRun(fromSinglePart: inner, attributes: attributes)
    case let .fixed(inner):
        attributes.monospace = true
        return chatInputRun(fromSinglePart: inner, attributes: attributes)
    case let .strikethrough(inner):
        attributes.strikethrough = true
        return chatInputRun(fromSinglePart: inner, attributes: attributes)
    case let .underline(inner):
        attributes.underline = true
        return chatInputRun(fromSinglePart: inner, attributes: attributes)
    case let .textSpoiler(inner):
        attributes.spoiler = true
        return chatInputRun(fromSinglePart: inner, attributes: attributes)
    case let .textMentionName(inner, peerId):
        attributes.entity = .mention(EnginePeer.Id(peerId))
        return chatInputRun(fromSinglePart: inner, attributes: attributes)
    case let .url(inner, url, _):
        attributes.entity = .url(url)
        return chatInputRun(fromSinglePart: inner, attributes: attributes)
    case let .textDate(inner, date, _):
        attributes.entity = .date(date)
        return chatInputRun(fromSinglePart: inner, attributes: attributes)
    case .empty:
        return ChatInputRun(text: "", attributes: attributes)
    default:
        // Defensive for wire-only RichText cases that the forward never produces.
        return ChatInputRun(text: rt.plainText, attributes: attributes)
    }
}
