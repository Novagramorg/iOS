// Tests/RichTextEditorCoreTests/DocumentFragmentTests.swift
import XCTest
@testable import RichTextEditorCore

final class DocumentFragmentTests: XCTestCase {
    func para(_ id: String, _ t: String, style: ParagraphStyleName = .body) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), style: style, runs: [TextRun(text: t)]))
    }
    func doc(_ blocks: Block...) -> Document { Document(blocks: blocks) }

    // Two paragraphs "Hello"(text 1..6) and "World"(text 8..13) on the axis:
    //   p0: open@0, text@1..6 ("Hello"), close@6   -> size 7
    //   p1: open@7, text@8..13 ("World"), close@13 -> size 7
    func twoParas() -> Document { doc(para("a", "Hello"), para("b", "World")) }

    func test_extract_withinOneParagraph_truncatesRuns() {
        let f = twoParas().extractFragment(globalFrom: 2, globalTo: 4)   // "el"
        XCTAssertEqual(f.blocks.count, 1)
        guard case .paragraph(let p) = f.blocks[0] else { return XCTFail() }
        XCTAssertEqual(p.text, "el")
    }

    func test_extract_spanningTwoParagraphs_keepsTwoBlocksTruncatedAtEnds() {
        // globalFrom:3 lands on the first 'l' (H@1,e@2,l@3,l@4,o@5); globalTo:10 lands on 'o'@10 in "World" (W@8,o@9,r@10...).
        // Extracting global [3,10) from "Hello" gives local [2,5) = "llo"; from "World" gives local [0,2) = "Wo".
        let f = twoParas().extractFragment(globalFrom: 3, globalTo: 10)
        XCTAssertEqual(f.blocks.map { b -> String in
            if case .paragraph(let p) = b { return p.text } else { return "?" }
        }, ["llo", "Wo"])
    }

    func test_extract_preservesInlineAttributes() {
        let d = doc(.paragraph(ParagraphBlock(id: BlockID("a"), runs: [
            TextRun(text: "AB", attributes: CharacterAttributes(bold: true, link: "https://x")),
        ])))
        let f = d.extractFragment(globalFrom: 1, globalTo: 3)
        guard case .paragraph(let p) = f.blocks[0] else { return XCTFail() }
        XCTAssertTrue(p.runs[0].attributes.bold)
        XCTAssertEqual(p.runs[0].attributes.link, "https://x")
    }

    func test_topLevelTextLocus_resolvesIndexAndLocal() {
        XCTAssertEqual(twoParas().topLevelTextLocus(globalCaret: 9).map { [$0.index, $0.local] }, [1, 1])
    }

    func test_globalTextStart_ofSecondBlock() {
        XCTAssertEqual(twoParas().globalTextStart(ofBlockAt: 1), 8)
    }

    // Axis for [AB][empty][CD]: p_a open@0,A@1,B@2,close@3; p_e open@4,(empty)@5,close@5; p_c open@6,C@7,D@8,close@9.
    func emptyMiddle() -> Document { doc(para("a", "AB"), para("e", ""), para("c", "CD")) }

    func test_extract_emptyParagraphAtExclusiveEnd_isNotCaptured() {
        // [1,5): covers "AB" but STOPS before the blank line's position (5) — half-open excludes it.
        let f = emptyMiddle().extractFragment(globalFrom: 1, globalTo: 5)
        XCTAssertEqual(f.blocks.count, 1)
        guard case .paragraph(let p) = f.blocks[0] else { return XCTFail() }
        XCTAssertEqual(p.text, "AB")
    }

    func test_extract_emptyParagraphStrictlyInside_isCaptured() {
        // [1,8): covers "AB", the blank line (pos 5 < 8), and into "CD".
        let f = emptyMiddle().extractFragment(globalFrom: 1, globalTo: 8)
        XCTAssertEqual(f.blocks.map { b -> String in
            if case .paragraph(let p) = b { return p.text } else { return "?" }
        }, ["AB", "", "C"])
    }

    func test_extract_emptyRange_returnsEmptyDocument() {
        XCTAssertTrue(twoParas().extractFragment(globalFrom: 4, globalTo: 4).blocks.isEmpty)
    }

    // MARK: - Block-quote extraction (I3)

    /// A block quote containing one paragraph "hi".
    func blockQuoteDoc() -> Document {
        let bq = BlockQuote(id: BlockID("q"),
                            children: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hi")]))],
                            collapsed: false)
        return Document(blocks: [.blockQuote(bq)])
    }

    func test_extract_blockQuote_fullyCovered_capturesBlock() {
        // A document consisting of exactly one block quote. Selecting the whole document [0, size)
        // must extract a fragment containing that block quote.
        let d = blockQuoteDoc()
        let size = DocumentTree.documentSize(d)
        let f = d.extractFragment(globalFrom: 0, globalTo: size)
        XCTAssertEqual(f.blocks.count, 1, "one block quote should be captured")
        guard case .blockQuote(let bq) = f.blocks[0] else { return XCTFail("extracted block is not a block quote") }
        XCTAssertFalse(bq.collapsed)
        XCTAssertEqual(bq.children.count, 1)
    }

    func test_extract_blockQuote_partiallyCovered_isDropped() {
        // Place a paragraph before the block quote. Select only the paragraph — the block quote
        // is NOT fully covered and must be dropped (partial coverage stays dropped).
        let d = Document(blocks: [
            para("a", "AB"),
            .blockQuote(BlockQuote(id: BlockID("q"),
                                   children: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hi")]))],
                                   collapsed: false))
        ])
        // globalFrom: start of "AB", globalTo: just before the block quote
        let paraSize = DocumentTree.documentSize(Document(blocks: [para("a", "AB")]))
        let f = d.extractFragment(globalFrom: 1, globalTo: paraSize)
        XCTAssertEqual(f.blocks.count, 1)
        guard case .paragraph = f.blocks[0] else { return XCTFail("expected only the paragraph") }
    }

    func test_extract_skipsMediaBlock() {
        let d = Document(blocks: [
            para("a", "AB"),
            .media(MediaBlock(id: BlockID("m"), mediaID: "x", naturalSize: Size2D(width: 10, height: 10))),
            para("c", "CD"),
        ])
        let f = d.extractFragment(globalFrom: 0, globalTo: 9999)
        XCTAssertEqual(f.blocks.map { b -> String in
            if case .paragraph(let p) = b { return p.text } else { return "?" }
        }, ["AB", "CD"])
    }

    func test_topLevelTextLocus_mediaBlock_returnsNil() {
        let d = Document(blocks: [.media(MediaBlock(id: BlockID("m"), mediaID: "x", naturalSize: Size2D(width: 10, height: 10)))])
        XCTAssertNil(d.topLevelTextLocus(globalCaret: 1))
    }

    // MARK: - Task 3: insertingFragment tests

    func code(_ id: String, _ t: String) -> Block { .code(CodeBlock(id: BlockID(id), runs: [TextRun(text: t)])) }
    func listItem(_ id: String, _ t: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), style: .body,
                                  list: ListMembership(marker: .bullet),
                                  runs: t.isEmpty ? [] : [TextRun(text: t)]))
    }

    func test_insert_singleInlineParagraph_mergesAtCaret() {
        // host "Hello" caret after "He" (global 3). Fragment one body paragraph "XX".
        let host = doc(para("a", "Hello"))
        let frag = doc(para("f", "XX"))
        let r = host.insertingFragment(frag, atGlobal: 3)!
        guard case .paragraph(let p) = r.document.blocks[0] else { return XCTFail() }
        XCTAssertEqual(p.text, "HeXXllo")
        XCTAssertEqual(r.caret, 5)               // 3 + len("XX")
        XCTAssertEqual(r.document.blocks.count, 1)
    }

    func test_insert_multiBlock_splitsHostAndMergesEnds() {
        // host "Hello" caret after "He" (3). Fragment two body paragraphs "AA","BB".
        let r = doc(para("a", "Hello")).insertingFragment(doc(para("x", "AA"), para("y", "BB")), atGlobal: 3)!
        let texts = r.document.blocks.compactMap { b -> String? in
            if case .paragraph(let p) = b { return p.text } else { return nil }
        }
        XCTAssertEqual(texts, ["HeAA", "BBllo"])  // first merges head, last merges tail
        // caret at the boundary between the pasted "BB" and the "llo" remainder:
        XCTAssertEqual(r.caret, r.document.globalTextStart(ofBlockAt: 1) + 2)
    }

    func test_insert_leadingListItem_insertsAsOwnBlock() {
        // Fragment [list-item "Q", body "B"] pasted into "Hello" at caret 3.
        // A list item is not inline-mergeable → inserts as its own block; "B" merges into tail "llo".
        let r = doc(para("a", "Hello")).insertingFragment(doc(listItem("q", "Q"), para("b", "B")), atGlobal: 3)!
        XCTAssertEqual(r.document.blocks.count, 3)
        guard case .paragraph(let h) = r.document.blocks[0] else { return XCTFail() }
        guard case .paragraph(let q) = r.document.blocks[1] else { return XCTFail() }
        XCTAssertEqual(h.text, "He")
        XCTAssertNotNil(q.list, "list item survives as its own block")
        XCTAssertEqual(q.text, "Q")
    }

    func test_insert_regeneratesIDs_noCollisionWithHost() {
        // global 6 = end of "Hello" (textStart=1, utf16Count=5, so textStart+utf16Count=6)
        let r = doc(para("a", "Hello")).insertingFragment(doc(para("a", "XX")), atGlobal: 6)!
        // single inline merge keeps host id "a"; ensure the merge didn't duplicate-id anything
        XCTAssertEqual(r.document.blocks.count, 1)
        guard case .paragraph(let p) = r.document.blocks[0] else { return XCTFail() }
        XCTAssertEqual(p.text, "HelloXX")
    }

    func test_insert_emptyFragment_isNoOp() {
        let r = doc(para("a", "Hello")).insertingFragment(Document(blocks: []), atGlobal: 2)!
        XCTAssertEqual(r.caret, 2)
        XCTAssertEqual(r.document, doc(para("a", "Hello")))
    }

    func test_insert_caretNotInTextRegion_returnsNil() {
        // A media-only doc has no top-level paragraph/code text region at caret 1.
        let media = Document(blocks: [.media(MediaBlock(id: BlockID("m"), mediaID: "x", naturalSize: Size2D(width: 10, height: 10)))])
        XCTAssertNil(media.insertingFragment(doc(para("f", "X")), atGlobal: 1))
    }

    func test_insert_intoCodeBlock_flattensFragmentToText() {
        // A code block "let x" — text axis: open@0, text@1..6, close@6. Caret after "let " (global 5).
        let host = Document(blocks: [code("c", "let x")])
        let frag = doc(para("p", "AA"), para("q", "BB"))   // two paragraphs
        let r = host.insertingFragment(frag, atGlobal: 5)!
        guard case .code(let c) = r.document.blocks[0] else { return XCTFail() }
        XCTAssertEqual(c.text, "let AA\nBBx")   // paragraphs joined by "\n", inserted inline
        XCTAssertEqual(r.caret, 5 + ("AA\nBB" as NSString).length)
    }

    func test_insert_intoCodeBlock_keepsCodeBlockIdentity() {
        let host = Document(blocks: [code("c", "ab")])
        let r = host.insertingFragment(doc(para("p", "X")), atGlobal: 2)!
        XCTAssertEqual(r.document.blocks.count, 1)
        XCTAssertEqual(r.document.blocks[0].id, BlockID("c"))
    }

    // MARK: - Spurious-empty-split-half on fragment paste (trailing/leading empty paragraph bug)

    /// A bullet-list paragraph (NOT inline-mergeable → pastes as its own block).
    func bullet(_ id: String, _ t: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id),
                                  list: ListMembership(marker: .bullet, level: 0),
                                  runs: t.isEmpty ? [] : [TextRun(text: t)]))
    }

    /// The global caret at the END of the (single-block) document's only paragraph "abc".
    /// Axis: open@0, a@1,b@2,c@3, close@3 → end-of-text caret = 3 (= 1 + utf16Count("abc")).
    func endOfFirstParagraph(_ d: Document) -> Int {
        guard case .paragraph(let p) = d.blocks[0] else { return 0 }
        return d.globalTextStart(ofBlockAt: 0) + p.utf16Count
    }

    /// Helper: the plain texts + list markers of a result document's blocks. `empty` is text-emptiness
    /// (a blank-line paragraph may carry either no runs or one zero-length run — both read as empty).
    private func summarize(_ d: Document) -> [(text: String, isBullet: Bool, empty: Bool)] {
        d.blocks.compactMap { b in
            if case .paragraph(let p) = b {
                return (p.text, p.list?.marker == .bullet, p.text.isEmpty)
            }
            return nil
        }
    }

    // CASE 1 — paste a bullet list at the END of "abc" → ["abc", bullet-a, bullet-b] (3 blocks, no trailing empty).
    func test_insert_bulletListAtParagraphEnd_noTrailingEmpty() {
        let host = doc(para("h", "abc"))
        let frag = doc(bullet("x", "a"), bullet("y", "b"))
        let r = host.insertingFragment(frag, atGlobal: endOfFirstParagraph(host))!
        let s = summarize(r.document)
        XCTAssertEqual(r.document.blocks.count, 3, "expected 3 blocks, got \(s.map { $0.text })")
        XCTAssertEqual(s.map { $0.text }, ["abc", "a", "b"])
        XCTAssertTrue(s[1].isBullet && s[2].isBullet)
        XCTAssertFalse(s.last!.empty, "the host's empty tail must not survive as a trailing empty paragraph")
    }

    // CASE 2 — paste a SINGLE bullet at the end of "abc" → ["abc", bullet-a] (2 blocks, no trailing empty).
    func test_insert_singleBulletAtParagraphEnd_noTrailingEmpty() {
        let host = doc(para("h", "abc"))
        let r = host.insertingFragment(doc(bullet("x", "a")), atGlobal: endOfFirstParagraph(host))!
        let s = summarize(r.document)
        XCTAssertEqual(r.document.blocks.count, 2, "expected 2 blocks, got \(s.map { $0.text })")
        XCTAssertEqual(s.map { $0.text }, ["abc", "a"])
        XCTAssertTrue(s[1].isBullet)
    }

    // CASE 3 — paste a bullet list into an EMPTY doc (one empty body paragraph, caret 0) → [bullet-a, bullet-b]
    // (no leading and no trailing empty).
    func test_insert_bulletListIntoEmptyDoc_noLeadingOrTrailingEmpty() {
        let host = doc(para("h", ""))   // empty body paragraph, caret at global 1 (start of its text)
        let frag = doc(bullet("x", "a"), bullet("y", "b"))
        let r = host.insertingFragment(frag, atGlobal: 1)!
        let s = summarize(r.document)
        XCTAssertEqual(r.document.blocks.count, 2, "expected 2 blocks, got \(s.map { $0.text })")
        XCTAssertEqual(s.map { $0.text }, ["a", "b"])
        XCTAssertTrue(s[0].isBullet && s[1].isBullet)
    }

    // CASE 4 — plain-text-style fragment ["X", empty body] (a "X\n") at end of "abc" → ["abcX"] (the empty body must not survive).
    func test_insert_plainTextTrailingEmpty_dropsTheEmptyBody() {
        let host = doc(para("h", "abc"))
        let frag = doc(para("x", "X"), para("e", ""))   // "X\n"
        let r = host.insertingFragment(frag, atGlobal: endOfFirstParagraph(host))!
        let s = summarize(r.document)
        XCTAssertEqual(r.document.blocks.count, 1, "expected 1 block, got \(s.map { $0.text })")
        XCTAssertEqual(s.map { $0.text }, ["abcX"])
    }

    // CASE 5a — PRESERVE: paste a bullet list in the MIDDLE of "ab|cd" → ["ab", bullet-a, bullet-b, "cd"].
    func test_insert_bulletListMidParagraph_preservesNonEmptyTail() {
        // host "abcd" caret after "ab": axis open@0,a@1,b@2,c@3,d@4 → caret global = 3.
        let host = doc(para("h", "abcd"))
        let frag = doc(bullet("x", "a"), bullet("y", "b"))
        let r = host.insertingFragment(frag, atGlobal: 3)!
        let s = summarize(r.document)
        XCTAssertEqual(s.map { $0.text }, ["ab", "a", "b", "cd"])
        XCTAssertTrue(s[1].isBullet && s[2].isBullet)
        XCTAssertFalse(s[3].isBullet)
    }

    // CASE 5b — PRESERVE: paste body ["A","B"] at end of "abc" → ["abcA", "B"] (2 blocks).
    func test_insert_bodyAtParagraphEnd_inlineMergesBothEnds() {
        let host = doc(para("h", "abc"))
        let r = host.insertingFragment(doc(para("x", "A"), para("y", "B")), atGlobal: endOfFirstParagraph(host))!
        let s = summarize(r.document)
        XCTAssertEqual(s.map { $0.text }, ["abcA", "B"])
    }

    // CASE 5c — PRESERVE: an INTERIOR empty body paragraph in a fragment ["A", empty, "B"] is preserved.
    func test_insert_interiorEmptyParagraph_isPreserved() {
        let host = doc(para("h", "abc"))
        let frag = doc(para("x", "A"), para("e", ""), para("y", "B"))
        let r = host.insertingFragment(frag, atGlobal: endOfFirstParagraph(host))!
        let s = summarize(r.document)
        // "A" inline-merges into head "abc" → "abcA"; interior empty kept; "B" merges into empty tail → "B".
        XCTAssertEqual(s.map { $0.text }, ["abcA", "", "B"])
        XCTAssertTrue(s[1].empty, "the interior empty paragraph must be preserved")
    }

    // CASE 6 — CARET: after pasting the bullet list at the end of "abc", caret is at the END of bullet-b,
    // not inside a trailing empty paragraph.
    func test_insert_bulletListAtParagraphEnd_caretAtEndOfLastPastedBlock() {
        let host = doc(para("h", "abc"))
        let frag = doc(bullet("x", "a"), bullet("y", "b"))
        let r = host.insertingFragment(frag, atGlobal: endOfFirstParagraph(host))!
        // bullet-b is the last block (index 2). Its end caret = globalTextStart(2) + utf16Count("b").
        let bulletBIndex = r.document.blocks.count - 1
        guard case .paragraph(let last) = r.document.blocks[bulletBIndex] else { return XCTFail() }
        XCTAssertEqual(last.text, "b")
        XCTAssertEqual(r.caret, r.document.globalTextStart(ofBlockAt: bulletBIndex) + last.utf16Count)
    }
}
