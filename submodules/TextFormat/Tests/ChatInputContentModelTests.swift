import XCTest
import TelegramCore
@testable import TextFormat

final class ChatInputContentModelTests: XCTestCase {
    func test_inlineEntity_equatable_byValue() {
        XCTAssertEqual(ChatInputInlineEntity.mention(EnginePeer.Id(7)), .mention(EnginePeer.Id(7)))
        XCTAssertNotEqual(ChatInputInlineEntity.mention(EnginePeer.Id(7)), .mention(EnginePeer.Id(8)))
        XCTAssertEqual(ChatInputInlineEntity.url("a"), .url("a"))
        XCTAssertEqual(ChatInputInlineEntity.date(5), .date(5))
        XCTAssertNotEqual(ChatInputInlineEntity.url("a"), .date(5))
    }

    func test_run_equatable() {
        var a = ChatInputInlineAttributes(); a.bold = true
        XCTAssertEqual(ChatInputRun(text: "x", attributes: a), ChatInputRun(text: "x", attributes: a))
        var b = ChatInputInlineAttributes(); b.italic = true
        XCTAssertNotEqual(ChatInputRun(text: "x", attributes: a), ChatInputRun(text: "x", attributes: b))
    }

    func test_content_equatable_andText() {
        let p = ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "ab")])
        let code = ChatInputCode(language: "swift", runs: [ChatInputRun(text: "x\ny")])
        let c1 = ChatInputContent(blocks: [.paragraph(p), .code(code)])
        XCTAssertEqual(c1, ChatInputContent(blocks: [.paragraph(p), .code(code)]))
        XCTAssertNotEqual(c1, ChatInputContent(blocks: [.paragraph(p)]))
        XCTAssertEqual(ChatInputParagraphStyle.quote(isCollapsed: true), .quote(isCollapsed: true))
        XCTAssertNotEqual(ChatInputParagraphStyle.quote(isCollapsed: true), .quote(isCollapsed: false))
    }

    // MARK: - Structural selection + content-aware bridge (Piece 5 stage 1)

    /// Fixture: body "ab" / code "x\ny" / collapsedQuote — plainText "ab\nx\ny\n " (length 8).
    private func bridgeFixture() -> ChatInputContent {
        ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "ab")])),
            .code(ChatInputCode(language: "swift", runs: [ChatInputRun(text: "x\ny")])),
            .collapsedQuote(ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "z")]))])),
        ])
    }

    /// The bridge must be a bijection over flat offsets: `init(nsRange:in:)` then `nsRange(in:)` = identity for
    /// every range (including collapsed carets and ranges straddling inter-block "\n").
    func test_selection_bridge_roundTripsEveryFlatNSRange() {
        let content = bridgeFixture()
        let total = (content.plainText as NSString).length
        XCTAssertEqual(total, 8)
        for loc in 0 ... total {
            for len in 0 ... (total - loc) {
                let r = NSRange(location: loc, length: len)
                XCTAssertEqual(ChatInputSelection(nsRange: r, in: content).nsRange(in: content), r, "round-trip failed for \(r)")
            }
        }
    }

    /// Depth-1 positions + the inter-block boundary convention (`end of block i` and `start of block i+1` are
    /// distinct consecutive offsets straddling the separator "\n").
    func test_position_depth1_blockBoundaries() {
        let content = bridgeFixture() // "ab"=[0,2] \n=2 "x\ny"=[3,6] \n=6 " "=[7,8]
        XCTAssertEqual(content.position(forFlatOffset: 2), ChatInputPosition(path: [ChatInputPathStep(blockIndex: 0)], offset: 2)) // end of block 0
        XCTAssertEqual(content.position(forFlatOffset: 3), ChatInputPosition(path: [ChatInputPathStep(blockIndex: 1)], offset: 0)) // start of block 1
        XCTAssertEqual(content.position(forFlatOffset: 7), ChatInputPosition(path: [ChatInputPathStep(blockIndex: 2)], offset: 0)) // before collapsed placeholder
        XCTAssertEqual(content.position(forFlatOffset: 8), ChatInputPosition(path: [ChatInputPathStep(blockIndex: 2)], offset: 1)) // after it
        // flatOffset is the inverse
        XCTAssertEqual(content.flatOffset(for: ChatInputPosition(path: [ChatInputPathStep(blockIndex: 1)], offset: 0)), 3)
        XCTAssertEqual(content.flatOffset(for: ChatInputPosition(path: [ChatInputPathStep(blockIndex: 2)], offset: 1)), 8)
    }

    func test_selection_isCollapsed_andEquatable() {
        let content = ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "abcd")]))])
        XCTAssertTrue(ChatInputSelection(nsRange: NSRange(location: 2, length: 0), in: content).isCollapsed)
        XCTAssertFalse(ChatInputSelection(nsRange: NSRange(location: 1, length: 3), in: content).isCollapsed)
        XCTAssertEqual(
            ChatInputSelection(nsRange: NSRange(location: 1, length: 3), in: content),
            ChatInputSelection(nsRange: NSRange(location: 1, length: 3), in: content)
        )
    }

    func test_isEmpty_matchesPlainTextIsEmpty() {
        func p(_ s: String) -> ChatInputBlock { .paragraph(ChatInputParagraph(style: .body, runs: s.isEmpty ? [] : [ChatInputRun(text: s)])) }
        let cases: [ChatInputContent] = [
            ChatInputContent(),                                   // no blocks
            ChatInputContent(blocks: [p("")]),                    // single empty paragraph
            ChatInputContent(blocks: [p("a")]),                   // single non-empty
            ChatInputContent(blocks: [p(""), p("")]),             // two empty paragraphs -> "\n" -> non-empty
            ChatInputContent(blocks: [.collapsedQuote(ChatInputContent(blocks: [p("x")]))]), // placeholder -> non-empty
            ChatInputContent(blocks: [.code(ChatInputCode(runs: []))]),                      // single empty code
        ]
        for c in cases {
            XCTAssertEqual(c.isEmpty, c.plainText.isEmpty, "isEmpty must match plainText.isEmpty for \(c.plainText.debugDescription)")
            XCTAssertEqual(c.isEmpty, c.length == 0)
        }
    }

    func test_position_emptyContent_isSafe() {
        let empty = ChatInputContent()
        XCTAssertEqual(empty.position(forFlatOffset: 0), ChatInputPosition(path: [ChatInputPathStep(blockIndex: 0)], offset: 0))
        XCTAssertEqual(empty.flatOffset(for: ChatInputPosition(path: [ChatInputPathStep(blockIndex: 0)], offset: 0)), 0)
        XCTAssertEqual(ChatInputSelection(nsRange: NSRange(location: 0, length: 0), in: empty).nsRange(in: empty), NSRange(location: 0, length: 0))
    }
}
