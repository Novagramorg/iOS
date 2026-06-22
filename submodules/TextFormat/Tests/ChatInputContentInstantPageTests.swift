import XCTest
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
}
