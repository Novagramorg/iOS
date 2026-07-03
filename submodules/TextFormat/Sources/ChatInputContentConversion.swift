import Foundation
import TelegramCore

/// Chat input content → a SEMANTIC NSAttributedString (text + `ChatTextInputAttributes` only; NO display
/// decoration — no fonts/colors/spoiler-attachments/emoji views). Display-neutral on purpose; the node owns
/// decoration. Tree-shaped successor to `ChatTextInputStateText.attributedText()`.
public func attributedString(from content: ChatInputContent) -> NSAttributedString {
    let result = NSMutableAttributedString()
    let marker = true as NSNumber
    var isFirst = true

    func appendSeparatorIfNeeded() {
        if !isFirst { result.append(NSAttributedString(string: "\n")) }
        isFirst = false
    }

    func appendRuns(_ paragraph: ChatInputParagraph) {
        for run in paragraph.runs {
            let piece = NSMutableAttributedString(string: run.text)
            let r = NSRange(location: 0, length: piece.length)
            let a = run.attributes
            if a.bold { piece.addAttribute(ChatTextInputAttributes.bold, value: marker, range: r) }
            if a.italic { piece.addAttribute(ChatTextInputAttributes.italic, value: marker, range: r) }
            if a.monospace { piece.addAttribute(ChatTextInputAttributes.monospace, value: marker, range: r) }
            if a.strikethrough { piece.addAttribute(ChatTextInputAttributes.strikethrough, value: marker, range: r) }
            if a.underline { piece.addAttribute(ChatTextInputAttributes.underline, value: marker, range: r) }
            if a.spoiler { piece.addAttribute(ChatTextInputAttributes.spoiler, value: marker, range: r) }
            switch a.entity {
            case let .mention(peerId):
                piece.addAttribute(ChatTextInputAttributes.textMention,
                    value: ChatTextInputTextMentionAttribute(peerId: peerId), range: r)
            case let .url(url):
                piece.addAttribute(ChatTextInputAttributes.textUrl,
                    value: ChatTextInputTextUrlAttribute(url: url), range: r)
            case let .date(timestamp):
                piece.addAttribute(ChatTextInputAttributes.date,
                    value: ChatTextInputTextDateAttribute(date: timestamp), range: r)
            case let .customEmoji(fileId, file, enableAnimation):
                // `interactivelySelectedFromPackId`/`custom` are intentionally not modelled — the canonical
                // `ChatTextInputStateText` drops them too (a draft save/restore already loses them), so this
                // matches the persisted fidelity. Only the recently-used-pack bump side effect is affected.
                piece.addAttribute(ChatTextInputAttributes.customEmoji,
                    value: ChatTextInputTextCustomEmojiAttribute(
                        interactivelySelectedFromPackId: nil,
                        fileId: fileId,
                        file: file,
                        enableAnimation: enableAnimation), range: r)
            case nil:
                break
            }
            result.append(piece)
        }
    }

    var i = 0
    while i < content.blocks.count {
        let block = content.blocks[i]
        switch block {
        case let .code(code):
            appendSeparatorIfNeeded()
            let start = result.length
            result.append(NSAttributedString(string: code.text))
            let len = result.length - start
            if len > 0 {
                let attr = chatInputCodeBlockAttribute(language: code.language)
                result.addAttribute(attr.key, value: attr.value, range: NSRange(location: start, length: len))
            }
        case let .paragraph(paragraph):
            appendSeparatorIfNeeded()
            appendRuns(paragraph)
        case let .pullQuote(pq):
            // Legacy UITextView projection: render pull-quote text as a quote-attributed block, mirroring `.code`.
            // The native Document ↔ ChatInputContent bridge bypasses this path for pull-quote blocks entirely.
            appendSeparatorIfNeeded()
            let start = result.length
            result.append(NSAttributedString(string: pq.text))
            let len = result.length - start
            if len > 0 {
                result.addAttribute(ChatTextInputAttributes.block,
                    value: ChatTextInputTextQuoteAttribute(kind: .quote, isCollapsed: false),
                    range: NSRange(location: start, length: len))
            }
        case let .blockQuote(bq):
            // Legacy UITextView projection for the structured blockQuote. The native Document ↔ ChatInputContent
            // bridge bypasses this path entirely (like `.pullQuote`). For the flat view:
            // - collapsed → " " placeholder with `.collapsedBlock`
            // - expanded → inner plain text with `.block` / `.quote` attribute (mirrors quote paragraphs)
            appendSeparatorIfNeeded()
            if bq.collapsed {
                result.append(NSAttributedString(string: " ", attributes: [
                    ChatTextInputAttributes.collapsedBlock: attributedString(from: bq.content)
                ]))
            } else {
                let start = result.length
                result.append(NSAttributedString(string: bq.content.plainText))
                let len = result.length - start
                if len > 0 {
                    result.addAttribute(ChatTextInputAttributes.block,
                        value: ChatTextInputTextQuoteAttribute(kind: .quote, isCollapsed: false),
                        range: NSRange(location: start, length: len))
                }
            }
        case .media, .table:
            // INTENTIONAL render-only filter (not deferred): the legacy `UITextView` composer cannot represent a
            // structural media/table block, so this `NSAttributedString` projection drops them. Heading/list
            // paragraphs above similarly render as plain text (`appendRuns` ignores heading style + list membership).
            // `ChatInputContent` stays the sole authoritative storage; this flat view is lossy by design. The native
            // engine carries these blocks via the direct `Document ↔ ChatInputContent` bridge, never this path.
            break
        }
        i += 1
    }
    return result
}

/// NSAttributedString → ChatInputContent (two-pass: carve `.block`/code regions via `codeBlockRanges`,
/// fill gaps with paragraphs, consuming one separator "\n" per boundary — mirrors
/// `ComposerDocumentBridge.document(from:)`).
public func chatInputContent(from attributedText: NSAttributedString) -> ChatInputContent {
    let full = attributedText.string as NSString
    var blocks: [ChatInputBlock] = []

    func appendParagraphs(in range: NSRange) {
        guard range.length > 0 else { return }
        var paraRanges: [NSRange] = []
        var lineStart = range.location
        let end = range.location + range.length
        var i = range.location
        while i < end {
            if full.character(at: i) == 0x0A {
                paraRanges.append(NSRange(location: lineStart, length: i - lineStart))
                lineStart = i + 1
            }
            i += 1
        }
        paraRanges.append(NSRange(location: lineStart, length: end - lineStart))
        for pr in paraRanges {
            var runs: [ChatInputRun] = []
            var isQuote = false
            var quoteCollapsed = false
            if pr.length > 0 {
                attributedText.enumerateAttributes(in: pr, options: []) { dict, r, _ in
                    var a = ChatInputInlineAttributes()
                    if dict[ChatTextInputAttributes.bold] != nil { a.bold = true }
                    if dict[ChatTextInputAttributes.italic] != nil { a.italic = true }
                    if dict[ChatTextInputAttributes.monospace] != nil { a.monospace = true }
                    if dict[ChatTextInputAttributes.strikethrough] != nil { a.strikethrough = true }
                    if dict[ChatTextInputAttributes.underline] != nil { a.underline = true }
                    if dict[ChatTextInputAttributes.spoiler] != nil { a.spoiler = true }
                    if let m = dict[ChatTextInputAttributes.textMention] as? ChatTextInputTextMentionAttribute {
                        a.entity = .mention(m.peerId)
                    } else if let d = dict[ChatTextInputAttributes.date] as? ChatTextInputTextDateAttribute {
                        a.entity = .date(d.date)
                    } else if let e = dict[ChatTextInputAttributes.customEmoji] as? ChatTextInputTextCustomEmojiAttribute {
                        a.entity = .customEmoji(fileId: e.fileId, file: e.file, enableAnimation: e.enableAnimation)
                    } else if let u = dict[ChatTextInputAttributes.textUrl] as? ChatTextInputTextUrlAttribute {
                        a.entity = .url(u.url)
                    }
                    // A `.block`/`.quote`-kind attribute now maps to `.blockQuote` (Task 16b).
                    if let q = dict[ChatTextInputAttributes.block] as? ChatTextInputTextQuoteAttribute,
                       case .quote = q.kind {
                        isQuote = true
                        quoteCollapsed = q.isCollapsed
                    }
                    runs.append(ChatInputRun(text: full.substring(with: r), attributes: a))
                }
            }
            if isQuote {
                // A `.block`/`.quote`-kind attribute now maps to `.blockQuote` (Task 16b). Each quote
                // paragraph on the legacy NSAttributedString path becomes its own `.blockQuote` block
                // (multi-paragraph grouping is handled by the native Document ↔ ChatInputContent bridge).
                blocks.append(.blockQuote(ChatInputBlockQuote(
                    content: ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .body, runs: runs))]),
                    collapsed: quoteCollapsed)))
            } else {
                blocks.append(.paragraph(ChatInputParagraph(style: .body, runs: runs)))
            }
        }
    }

    // Carve out the non-paragraph block regions (code blocks + collapsed blockQuotes), then fill the
    // gaps with paragraphs, consuming one separator "\n" per boundary — mirrors `ComposerDocumentBridge`.
    enum CarveKind {
        case code(language: String?)
        /// A `.collapsedBlock`-attributed character: maps to `.blockQuote(collapsed: true)` (Task 16b).
        case collapsedBlock(content: NSAttributedString)
    }
    var carves: [(range: NSRange, kind: CarveKind)] = []
    for region in codeBlockRanges(in: attributedText) {
        carves.append((range: region.range, kind: .code(language: region.language)))
    }
    attributedText.enumerateAttribute(ChatTextInputAttributes.collapsedBlock, in: NSRange(location: 0, length: attributedText.length), options: []) { value, range, _ in
        if let nested = value as? NSAttributedString {
            carves.append((range: range, kind: .collapsedBlock(content: nested)))
        }
    }
    carves.sort { $0.range.location < $1.range.location }

    var cursor = 0
    for carve in carves {
        var gapEnd = carve.range.location
        if gapEnd > cursor && full.character(at: gapEnd - 1) == 0x0A { gapEnd -= 1 }
        if gapEnd > cursor { appendParagraphs(in: NSRange(location: cursor, length: gapEnd - cursor)) }
        switch carve.kind {
        case let .code(language):
            blocks.append(.code(ChatInputCode(
                language: language,
                runs: [ChatInputRun(text: full.substring(with: carve.range))])))
        case let .collapsedBlock(content):
            // `.collapsedBlock` attribute now maps to a collapsed `.blockQuote` (Task 16b).
            blocks.append(.blockQuote(ChatInputBlockQuote(
                content: chatInputContent(from: content),
                collapsed: true)))
        }
        cursor = carve.range.location + carve.range.length
        if cursor < full.length && full.character(at: cursor) == 0x0A { cursor += 1 }
    }
    if cursor < full.length { appendParagraphs(in: NSRange(location: cursor, length: full.length - cursor)) }

    if blocks.isEmpty { blocks = [.paragraph(ChatInputParagraph())] }
    return ChatInputContent(blocks: blocks)
}
