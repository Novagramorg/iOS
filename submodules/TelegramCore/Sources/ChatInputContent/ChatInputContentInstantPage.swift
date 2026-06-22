import Foundation

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
    return InstantPage(blocks: instantPageBlocks(from: content), media: [:], isComplete: true, rtl: false, url: "", views: nil)
}

func instantPageBlocks(from content: ChatInputContent) -> [InstantPageBlock] {
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
            } else {
                result.append(.paragraph(richText(from: p.runs)))
            }
        case let .code(c):
            result.append(.preformatted(text: richText(from: c.runs), language: c.language))
        case let .collapsedQuote(inner):
            // `.collapsedQuote` (folded) and `.quote(isCollapsed: true)` (visible, collapse-flagged) both encode as
            // `collapsed: true` — they produce the identical sent message (`BlockQuote(isCollapsed: true)`), differing
            // only in composer display. The reverse canonicalizes `collapsed == true` to `.collapsedQuote` (the more
            // general container — it holds arbitrary nested content, so the normalization is lossless), folding the
            // rare visible-collapse-flagged paragraph. See the reverse for the `collapsed == nil/false` rationale.
            result.append(.blockQuote(blocks: instantPageBlocks(from: inner), caption: .empty, collapsed: true))
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
    return ChatInputContent(blocks: chatInputBlocks(fromInstantPageBlocks: page.blocks))
}

func chatInputBlocks(fromInstantPageBlocks blocks: [InstantPageBlock]) -> [ChatInputBlock] {
    var result: [ChatInputBlock] = []
    for block in blocks {
        switch block {
        case let .paragraph(rt):
            result.append(.paragraph(ChatInputParagraph(style: .body, runs: chatInputRuns(fromRichText: rt))))
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
                result.append(.collapsedQuote(ChatInputContent(blocks: chatInputBlocks(fromInstantPageBlocks: innerBlocks))))
            } else {
                // The forward emitted one `.paragraph(rt)` per quote line; map each back to a quote-style paragraph.
                for inner in innerBlocks {
                    if case let .paragraph(rt) = inner {
                        result.append(.paragraph(ChatInputParagraph(style: .quote(isCollapsed: false), runs: chatInputRuns(fromRichText: rt))))
                    } else {
                        // Defensive: a non-paragraph inside a non-collapsed quote (won't happen from forward) — recurse.
                        result.append(contentsOf: chatInputBlocks(fromInstantPageBlocks: [inner]))
                    }
                }
            }
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
