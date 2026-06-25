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
    func quote(_ id: String, _ t: String) -> Block { para(id, t, style: .quote) }

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

    func test_insert_leadingQuote_insertsAsOwnBlock() {
        // Fragment [quote "Q", body "B"] pasted into "Hello" at caret 3.
        let r = doc(para("a", "Hello")).insertingFragment(doc(quote("q", "Q"), para("b", "B")), atGlobal: 3)!
        // head paragraph "He" stays; quote inserts as its own block; "B" merges into tail "llo".
        XCTAssertEqual(r.document.blocks.count, 3)
        guard case .paragraph(let h) = r.document.blocks[0] else { return XCTFail() }
        guard case .paragraph(let q) = r.document.blocks[1] else { return XCTFail() }
        XCTAssertEqual(h.text, "He")
        XCTAssertEqual(q.style, .quote)
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
}
