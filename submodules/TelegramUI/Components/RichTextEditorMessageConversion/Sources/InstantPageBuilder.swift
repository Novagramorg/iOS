import Foundation
import Postbox
import TelegramCore
import RichTextEditorCore

/// Build a chat rich-message `InstantPage` from already-normalized blocks (media blocks resolved via the supplied map).
func buildInstantPage(from blocks: [Block], media: [String: Media]) -> InstantPage {
    var pageBlocks: [InstantPageBlock] = []
    var pageMedia: [MediaId: Media] = [:]
    var index = 0
    while index < blocks.count {
        let block = blocks[index]
        switch block {
        case let .paragraph(paragraph):
            if paragraph.list != nil {
                var run: [ParagraphBlock] = []
                while index < blocks.count, case let .paragraph(next) = blocks[index], next.list != nil {
                    run.append(next)
                    index += 1
                }
                pageBlocks.append(contentsOf: buildListBlocks(from: run[...]))
                continue
            } else if paragraph.style == .quote {
                var quotes: [RichText] = []
                while index < blocks.count, case let .paragraph(next) = blocks[index], next.list == nil, next.style == .quote {
                    quotes.append(richText(from: next.runs))
                    index += 1
                }
                pageBlocks.append(.blockQuote(blocks: quotes.map { .paragraph($0) }, caption: .empty))
                continue
            } else {
                pageBlocks.append(headingOrParagraphBlock(paragraph))
                index += 1
            }
        case let .table(table):
            pageBlocks.append(tableBlock(table))
            index += 1
        case let .media(mediaBlock):
            // Media.id is optional on the protocol; real TelegramMedia* types always return non-nil.
            if let resolved = media[mediaBlock.mediaID], let mediaId = resolved.id {
                pageMedia[mediaId] = resolved // idempotent if the same mediaID appears in multiple blocks
                let caption = InstantPageCaption(text: richText(from: mediaBlock.caption), credit: .empty)
                switch mediaBlock.kind {
                case .image:
                    pageBlocks.append(.image(id: mediaId, caption: caption, url: nil, webpageId: nil))
                case .video:
                    pageBlocks.append(.video(id: mediaId, caption: caption, autoplay: false, loop: false))
                }
            }
            index += 1
        }
    }
    return InstantPage(blocks: pageBlocks, media: pageMedia, isComplete: true, rtl: false, url: "", views: nil)
}

/// A non-list, non-quote paragraph → a heading or a paragraph block.
private func headingOrParagraphBlock(_ paragraph: ParagraphBlock) -> InstantPageBlock {
    let text = richText(from: paragraph.runs)
    switch paragraph.style {
    case .heading1:
        return .heading(text: text, level: 1)
    case .heading2:
        return .heading(text: text, level: 2)
    case .heading3:
        return .heading(text: text, level: 3)
    case .body, .caption:
        return .paragraph(text)
    case .quote:
        // Quotes are merged by the caller; this is an unreached fallback for exhaustiveness.
        return .blockQuote(blocks: [.paragraph(text)], caption: .empty)
    }
}

/// Recursively build `.list` blocks from a consecutive run of list paragraphs.
/// Items at the same level + marker are siblings; deeper-level runs nest under the preceding item.
private func buildListBlocks(from paragraphs: ArraySlice<ParagraphBlock>) -> [InstantPageBlock] {
    var result: [InstantPageBlock] = []
    var index = paragraphs.startIndex
    while index < paragraphs.endIndex {
        let baseLevel = paragraphs[index].list?.level ?? 0
        let baseMarker = paragraphs[index].list?.marker ?? .bullet
        var items: [InstantPageListItem] = []
        while index < paragraphs.endIndex,
              (paragraphs[index].list?.level ?? 0) == baseLevel,
              (paragraphs[index].list?.marker ?? .bullet) == baseMarker {
            let text = richText(from: paragraphs[index].runs)
            index += 1
            let childStart = index
            while index < paragraphs.endIndex, (paragraphs[index].list?.level ?? 0) > baseLevel {
                index += 1
            }
            if index > childStart {
                let nested = buildListBlocks(from: paragraphs[childStart ..< index])
                items.append(.blocks([.paragraph(text)] + nested, nil, nil))
            } else {
                items.append(.text(text, nil, nil))
            }
        }
        result.append(.list(items: items, ordered: baseMarker == .ordered))
    }
    return result
}

/// A table block → `.table`, mapping per-column alignment and the header row.
private func tableBlock(_ table: TableBlock) -> InstantPageBlock {
    let rows = table.rows.map { row -> InstantPageTableRow in
        let cells = row.cells.enumerated().map { columnIndex, cell -> InstantPageTableCell in
            let alignment: TableHorizontalAlignment
            if columnIndex < table.columns.count {
                switch table.columns[columnIndex].alignment {
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
            return InstantPageTableCell(
                text: cellRichText(cell),
                header: row.isHeader,
                alignment: alignment,
                verticalAlignment: .top,
                colspan: 1,
                rowspan: 1
            )
        }
        return InstantPageTableRow(cells: cells)
    }
    return .table(title: .empty, rows: rows, bordered: true, striped: false)
}

/// Concatenate a cell's paragraph blocks into one `RichText` (newline-joined). Images in cells dropped.
private func cellRichText(_ cell: Cell) -> RichText {
    let paragraphs = cell.blocks.compactMap { block -> RichText? in
        if case let .paragraph(paragraph) = block {
            return richText(from: paragraph.runs)
        }
        return nil
    }
    if paragraphs.isEmpty {
        return .empty
    }
    if paragraphs.count == 1 {
        return paragraphs[0]
    }
    var joined: [RichText] = []
    for (offset, text) in paragraphs.enumerated() {
        if offset > 0 {
            joined.append(.plain("\n"))
        }
        joined.append(text)
    }
    return .concat(joined)
}
