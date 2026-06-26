import XCTest
import Postbox
import TelegramCore

final class ChatInputContentInstantPageTests: XCTestCase {
    private func assertRoundTrips(_ c: ChatInputContent, _ msg: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(chatInputContent(fromInstantPage: instantPage(from: c)), c, msg, file: file, line: line)
    }

    private func body(_ runs: [ChatInputRun]) -> ChatInputBlock {
        return .paragraph(ChatInputParagraph(style: .body, runs: runs))
    }

    private func quote(collapsed: Bool, _ runs: [ChatInputRun]) -> ChatInputBlock {
        return .paragraph(ChatInputParagraph(style: .quote(isCollapsed: collapsed), runs: runs))
    }

    // 1. Plain + each inline attribute separately, plus several combined into one run.
    func test_plainAndInlineAttributes() {
        var bold = ChatInputInlineAttributes(); bold.bold = true
        var italic = ChatInputInlineAttributes(); italic.italic = true
        var mono = ChatInputInlineAttributes(); mono.monospace = true
        var strike = ChatInputInlineAttributes(); strike.strikethrough = true
        var under = ChatInputInlineAttributes(); under.underline = true
        var spoiler = ChatInputInlineAttributes(); spoiler.spoiler = true

        assertRoundTrips(ChatInputContent(blocks: [body([
            ChatInputRun(text: "plain"),
            ChatInputRun(text: "b", attributes: bold),
            ChatInputRun(text: "i", attributes: italic),
            ChatInputRun(text: "m", attributes: mono),
            ChatInputRun(text: "s", attributes: strike),
            ChatInputRun(text: "u", attributes: under),
            ChatInputRun(text: "p", attributes: spoiler)
        ])]), "each inline attribute as a separate run")

        var all = ChatInputInlineAttributes()
        all.bold = true; all.italic = true; all.monospace = true
        all.strikethrough = true; all.underline = true; all.spoiler = true
        assertRoundTrips(ChatInputContent(blocks: [body([
            ChatInputRun(text: "combined", attributes: all)
        ])]), "all inline attributes combined in one run")

        // A subset combination too.
        var subset = ChatInputInlineAttributes()
        subset.bold = true; subset.underline = true
        assertRoundTrips(ChatInputContent(blocks: [body([
            ChatInputRun(text: "bu", attributes: subset)
        ])]), "bold+underline combined run")
    }

    // 2. Custom emoji run.
    func test_customEmoji() {
        var attrs = ChatInputInlineAttributes()
        attrs.entity = .customEmoji(fileId: 42, file: nil, enableAnimation: true)
        assertRoundTrips(ChatInputContent(blocks: [body([
            ChatInputRun(text: "\u{FFFC}", attributes: attrs)
        ])]), "custom emoji run")
    }

    // `enableAnimation` has no `RichText` carrier and is canonicalized to `true` on the reverse — matching the
    // production `.textEntities` draft path (the `CustomEmoji` entity carries no animation flag, so it's re-derived
    // at decoration). This pins that contract: an `enableAnimation: false` input round-trips to `true` (NOT strict
    // identity for this render-time flag — everything else about the run is preserved).
    func test_customEmoji_enableAnimationFalse() {
        var attrs = ChatInputInlineAttributes()
        attrs.entity = .customEmoji(fileId: 42, file: nil, enableAnimation: false)
        let input = ChatInputContent(blocks: [body([ChatInputRun(text: "\u{FFFC}", attributes: attrs)])])

        var expectedAttrs = ChatInputInlineAttributes()
        expectedAttrs.entity = .customEmoji(fileId: 42, file: nil, enableAnimation: true)
        let expected = ChatInputContent(blocks: [body([ChatInputRun(text: "\u{FFFC}", attributes: expectedAttrs)])])

        XCTAssertEqual(chatInputContent(fromInstantPage: instantPage(from: input)), expected,
                       "enableAnimation:false canonicalizes to true on the InstantPage round-trip")
    }

    // 3. Mention / date / url entity runs.
    func test_entityRuns() {
        var mention = ChatInputInlineAttributes(); mention.entity = .mention(EnginePeer.Id(123))
        var date = ChatInputInlineAttributes(); date.entity = .date(1717171717)
        var url = ChatInputInlineAttributes(); url.entity = .url("https://example.com")
        assertRoundTrips(ChatInputContent(blocks: [body([
            ChatInputRun(text: "John", attributes: mention),
            ChatInputRun(text: "tomorrow", attributes: date),
            ChatInputRun(text: "link", attributes: url)
        ])]), "mention/date/url entity runs")
    }

    // 4. Entity run that ALSO carries inline attributes (e.g. a bold mention).
    func test_entityWithAttributes() {
        var boldMention = ChatInputInlineAttributes()
        boldMention.bold = true
        boldMention.entity = .mention(EnginePeer.Id(999))
        assertRoundTrips(ChatInputContent(blocks: [body([
            ChatInputRun(text: "Alice", attributes: boldMention)
        ])]), "bold mention")

        var spoilerUrl = ChatInputInlineAttributes()
        spoilerUrl.spoiler = true
        spoilerUrl.italic = true
        spoilerUrl.entity = .url("https://hidden.example")
        assertRoundTrips(ChatInputContent(blocks: [body([
            ChatInputRun(text: "secret", attributes: spoilerUrl)
        ])]), "spoiler+italic url")
    }

    // 5. Code blocks with and without a language.
    func test_codeBlocks() {
        assertRoundTrips(ChatInputContent(blocks: [
            .code(ChatInputCode(language: "swift", runs: [ChatInputRun(text: "let x = 1\nlet y = 2")]))
        ]), "code with language")

        assertRoundTrips(ChatInputContent(blocks: [
            .code(ChatInputCode(language: nil, runs: [ChatInputRun(text: "no language")]))
        ]), "code without language")
    }

    // 6. Single quote paragraph and TWO consecutive same-collapse quote paragraphs (coalesce ⇄ split).
    func test_quoteParagraphs() {
        assertRoundTrips(ChatInputContent(blocks: [
            quote(collapsed: false, [ChatInputRun(text: "one line quote")])
        ]), "single quote paragraph")

        assertRoundTrips(ChatInputContent(blocks: [
            quote(collapsed: false, [ChatInputRun(text: "line 1")]),
            quote(collapsed: false, [ChatInputRun(text: "line 2")])
        ]), "two consecutive non-collapsed quote paragraphs")
    }

    // 7. Adjacent quote paragraphs with DIFFERENT collapse state must NOT coalesce together.
    //
    // NOTE on the forward design (taken verbatim from the task spec): a `.quote(isCollapsed: true)`
    // PARAGRAPH and a `.collapsedQuote` BLOCK both forward to `.blockQuote(collapsed: true)`, and the
    // reverse canonicalizes `.blockQuote(collapsed: true)` to `.collapsedQuote`. So a *collapsed-style
    // quote paragraph* is the one input shape that does not survive a full round-trip — it normalizes to
    // the `.collapsedQuote` block (which IS its semantic folded equivalent). We therefore verify the
    // stated intent of this case — that differently-collapsed adjacent quotes do NOT coalesce — at the
    // InstantPage level (two distinct blockQuote blocks with the right `collapsed` flags), rather than
    // asserting full identity on the collapsed-true paragraph. The non-collapsed coalescing identity is
    // covered by `test_quoteParagraphs`; the collapsed-true block identity by `test_collapsedQuote`.
    func test_quoteParagraphsDifferentCollapse() {
        let content = ChatInputContent(blocks: [
            quote(collapsed: false, [ChatInputRun(text: "open")]),
            quote(collapsed: true, [ChatInputRun(text: "folded")])
        ])
        let page = instantPage(from: content)
        XCTAssertEqual(page.blocks.count, 2, "differently-collapsed quotes must not coalesce into one blockQuote")
        guard case let .blockQuote(_, _, c0) = page.blocks[0], case let .blockQuote(_, _, c1) = page.blocks[1] else {
            XCTFail("expected two blockQuote blocks"); return
        }
        XCTAssertEqual(c0, false, "first quote keeps its non-collapsed flag")
        XCTAssertEqual(c1, true, "second quote keeps its collapsed flag")
    }

    // 8. collapsedQuote, and a nested collapsedQuote inside a collapsedQuote.
    func test_collapsedQuote() {
        assertRoundTrips(ChatInputContent(blocks: [
            .collapsedQuote(ChatInputContent(blocks: [
                body([ChatInputRun(text: "folded body")])
            ]))
        ]), "single collapsedQuote")

        assertRoundTrips(ChatInputContent(blocks: [
            .collapsedQuote(ChatInputContent(blocks: [
                body([ChatInputRun(text: "outer")]),
                .collapsedQuote(ChatInputContent(blocks: [
                    body([ChatInputRun(text: "inner")])
                ]))
            ]))
        ]), "nested collapsedQuote inside collapsedQuote")
    }

    // 9. Two adjacent plain runs in one paragraph must survive as TWO runs (no-merge rule).
    func test_adjacentPlainRunsNotMerged() {
        let c = ChatInputContent(blocks: [body([
            ChatInputRun(text: "a"),
            ChatInputRun(text: "b")
        ])])
        assertRoundTrips(c, "two adjacent plain runs survive as two runs")
        // Explicitly assert they did not merge into one "ab" run.
        let restored = chatInputContent(fromInstantPage: instantPage(from: c))
        if case let .paragraph(p) = restored.blocks[0] {
            XCTAssertEqual(p.runs.count, 2, "adjacent runs must not merge")
        } else {
            XCTFail("expected a paragraph block")
        }
    }

    // 10. An empty body paragraph (runs: []).
    func test_emptyBodyParagraph() {
        assertRoundTrips(ChatInputContent(blocks: [
            body([])
        ]), "empty body paragraph")
    }

    // 11. Heading paragraphs at each level (1/2/3) round-trip identically.
    func test_headings() {
        func heading(_ style: ChatInputParagraphStyle, _ text: String) -> ChatInputBlock {
            return .paragraph(ChatInputParagraph(style: style, runs: [ChatInputRun(text: text)]))
        }
        assertRoundTrips(ChatInputContent(blocks: [heading(.heading1, "Title")]), "heading1")
        assertRoundTrips(ChatInputContent(blocks: [heading(.heading2, "Section")]), "heading2")
        assertRoundTrips(ChatInputContent(blocks: [heading(.heading3, "Subsection")]), "heading3")
        // All three levels in one document, plus a body paragraph (must not coalesce with headings).
        assertRoundTrips(ChatInputContent(blocks: [
            heading(.heading1, "H1"),
            heading(.heading2, "H2"),
            heading(.heading3, "H3"),
            body([ChatInputRun(text: "body")])
        ]), "all heading levels + body")
    }

    // 12. A bullet list and an ordered list (each 2 items, level 0) round-trip identically.
    func test_lists() {
        func listItem(_ marker: ChatInputListMarker, _ text: String) -> ChatInputBlock {
            return .paragraph(ChatInputParagraph(style: .body, list: ChatInputListMembership(marker: marker, level: 0), runs: [ChatInputRun(text: text)]))
        }
        assertRoundTrips(ChatInputContent(blocks: [
            listItem(.bullet, "first"),
            listItem(.bullet, "second")
        ]), "two-item bullet list")
        assertRoundTrips(ChatInputContent(blocks: [
            listItem(.ordered, "one"),
            listItem(.ordered, "two")
        ]), "two-item ordered list")
        // A bullet list directly followed by an ordered list — they must stay two distinct `.list` blocks and
        // each item must round-trip back to its own marker.
        assertRoundTrips(ChatInputContent(blocks: [
            listItem(.bullet, "b1"),
            listItem(.bullet, "b2"),
            listItem(.ordered, "o1"),
            listItem(.ordered, "o2")
        ]), "adjacent bullet then ordered list")
        // A list item carrying an inline attribute on its run still round-trips.
        var bold = ChatInputInlineAttributes(); bold.bold = true
        assertRoundTrips(ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .body, list: ChatInputListMembership(marker: .bullet, level: 0), runs: [ChatInputRun(text: "bold", attributes: bold)]))
        ]), "bullet list item with a bold run")
    }

    // 13. A 2x2 table (header row, per-column alignment, default width, nil-background cells) round-trips
    //     identically — built to match exactly what the reverse produces for the non-representable fields
    //     (column width = 0.0, cell background = nil; table title / vertical-alignment / colspan / rowspan dropped).
    func test_table() {
        var bold = ChatInputInlineAttributes(); bold.bold = true
        let table = ChatInputTable(
            columns: [
                ChatInputColumnSpec(width: 0.0, alignment: .left),
                ChatInputColumnSpec(width: 0.0, alignment: .center)
            ],
            rows: [
                ChatInputTableRow(height: nil, isHeader: true, cells: [
                    ChatInputTableCell(runs: [ChatInputRun(text: "H1")], background: nil),
                    ChatInputTableCell(runs: [ChatInputRun(text: "H2")], background: nil)
                ]),
                ChatInputTableRow(height: nil, isHeader: false, cells: [
                    ChatInputTableCell(runs: [ChatInputRun(text: "a", attributes: bold)], background: nil),
                    ChatInputTableCell(runs: [ChatInputRun(text: "b")], background: nil)
                ])
            ]
        )
        assertRoundTrips(ChatInputContent(blocks: [.table(table)]), "2x2 table with header row + per-column alignment")
    }

    // 14. An image medium and a video medium round-trip identically — built with the default
    //     naturalSize/displayWidth/alignment the reverse restores (the InstantPage image/video block carries
    //     none of those, so they canonicalize to natural size .zero, nil display width, .center alignment).
    func test_media() {
        let imageId = MediaId(namespace: 1, id: 1001)
        let image = TelegramMediaImage(imageId: imageId, representations: [], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        var caption = ChatInputInlineAttributes(); caption.italic = true
        let imageMedia = ChatInputMedia(
            media: image,
            kind: .image,
            naturalSize: ChatInputSize(width: 0.0, height: 0.0),
            displayWidth: nil,
            alignment: .center,
            caption: [ChatInputRun(text: "a photo", attributes: caption)]
        )
        assertRoundTrips(ChatInputContent(blocks: [.media(imageMedia)]), "image medium with a caption")

        let fileId = MediaId(namespace: 1, id: 2002)
        let file = TelegramMediaFile(
            fileId: fileId,
            partialReference: nil,
            resource: EmptyMediaResource(),
            previewRepresentations: [],
            videoThumbnails: [],
            immediateThumbnailData: nil,
            mimeType: "video/mp4",
            size: nil,
            attributes: [],
            alternativeRepresentations: []
        )
        let videoMedia = ChatInputMedia(
            media: file,
            kind: .video,
            naturalSize: ChatInputSize(width: 0.0, height: 0.0),
            displayWidth: nil,
            alignment: .center,
            caption: []
        )
        assertRoundTrips(ChatInputContent(blocks: [.media(videoMedia)]), "video medium with no caption")
    }

    // Bonus: a mixed document combining several block kinds.
    func test_mixedDocument() {
        var bold = ChatInputInlineAttributes(); bold.bold = true
        var mention = ChatInputInlineAttributes(); mention.entity = .mention(EnginePeer.Id(5))
        assertRoundTrips(ChatInputContent(blocks: [
            body([ChatInputRun(text: "intro "), ChatInputRun(text: "bold", attributes: bold)]),
            quote(collapsed: false, [ChatInputRun(text: "q1")]),
            quote(collapsed: false, [ChatInputRun(text: "q2")]),
            .code(ChatInputCode(language: "py", runs: [ChatInputRun(text: "print(1)")])),
            body([ChatInputRun(text: "by ", attributes: ChatInputInlineAttributes()), ChatInputRun(text: "@user", attributes: mention)]),
            .collapsedQuote(ChatInputContent(blocks: [body([ChatInputRun(text: "hidden")])]))
        ]), "mixed multi-block document")
    }

    // Regression: a non-body paragraph that ALSO carries a list (a degenerate heading+list — the editor's heading/
    // quote styles and list membership are mutually exclusive in practice) previously infinite-looped the forward
    // because the list branch didn't guard on `.body`. It must return promptly and canonicalize to its style (the
    // list is dropped). If the guard regressed, this test would HANG (timeout), not just fail.
    func test_headingWithList_doesNotHang_canonicalizesToHeading() {
        let input = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .heading1, list: ChatInputListMembership(marker: .bullet, level: 0), runs: [ChatInputRun(text: "x")]))
        ])
        let expected = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .heading1, list: nil, runs: [ChatInputRun(text: "x")]))
        ])
        XCTAssertEqual(chatInputContent(fromInstantPage: instantPage(from: input)), expected,
                       "heading+list canonicalizes to a plain heading (list dropped), no hang")
    }

    // 17. A checklist with mixed checked state round-trips identically (checked=false/true/false).
    func test_checklist_roundTrips_withMixedCheckedState() {
        func checkItem(_ checked: Bool, _ text: String) -> ChatInputBlock {
            .paragraph(ChatInputParagraph(style: .body,
                list: ChatInputListMembership(marker: .checklist, level: 0, checked: checked),
                runs: [ChatInputRun(text: text)]))
        }
        assertRoundTrips(ChatInputContent(blocks: [
            checkItem(false, "todo"),
            checkItem(true, "done"),
            checkItem(false, "later"),
        ]), "checklist with mixed checked state")
    }

    // 16. ChatInputListMarker.checklist (rawValue 2) Codable round-trip, and back-compat: an old payload
    //     without `checked` decodes correctly (nil checked, marker preserved).
    func test_checklistMembership_codableRoundTrip_andBackCompat() throws {
        let m = ChatInputListMembership(marker: .checklist, level: 0, checked: true)
        let data = try JSONEncoder().encode(m)
        XCTAssertEqual(try JSONDecoder().decode(ChatInputListMembership.self, from: data), m)
        // Back-compat: an old payload without `checked` decodes to nil, marker preserved.
        let old = #"{"marker":{"raw":0},"level":0}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ChatInputListMembership.self, from: old)
        XCTAssertEqual(decoded.marker, .bullet)
        XCTAssertNil(decoded.checked)
    }
}
