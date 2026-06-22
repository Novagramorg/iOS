import XCTest
import TelegramCore
import Postbox
@testable import TextFormat

final class ChatInputContentConversionTests: XCTestCase {

    // MARK: - Task 4: attributedString(from:)

    func test_attributedString_emitsSemanticAttributes() {
        var a = ChatInputInlineAttributes(); a.bold = true
        let content = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "Hi", attributes: a)]))
        ])
        let s = attributedString(from: content)
        XCTAssertEqual(s.string, "Hi")
        XCTAssertNotNil(s.attribute(ChatTextInputAttributes.bold, at: 0, effectiveRange: nil))
    }

    func test_attributedString_blocksJoinedByNewline_andCodeContiguous() {
        let content = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "a")])),
            .code(ChatInputCode(language: "py", runs: [ChatInputRun(text: "b\nc")]))
        ])
        let s = attributedString(from: content)
        XCTAssertEqual(s.string, "a\nb\nc")
        let q = s.attribute(ChatTextInputAttributes.block, at: 2, effectiveRange: nil) as? ChatTextInputTextQuoteAttribute
        if case .code(let lang)? = q?.kind { XCTAssertEqual(lang, "py") } else { XCTFail("expected .code") }
    }

    // MARK: - Task 0 (1b-ii): multi-line quote contiguity

    /// A multi-line non-collapsed blockquote must emit as ONE contiguous `.block` range carrying a SINGLE
    /// shared quote object (interior "\n"s included) — the display groups quote boxes by object identity and
    /// the send path merges only directly-touching ranges, so per-line fragments would render N boxes / send N
    /// entities. This matches `ChatTextInputStateText`, which keeps a quote contiguous.
    func test_attributedString_multiLineQuote_emitsOneContiguousBlock() {
        let content = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "x")])),
            .paragraph(ChatInputParagraph(style: .quote(isCollapsed: false), runs: [ChatInputRun(text: "a")])),
            .paragraph(ChatInputParagraph(style: .quote(isCollapsed: false), runs: [ChatInputRun(text: "b")])),
        ])
        let s = attributedString(from: content)
        XCTAssertEqual(s.string, "x\na\nb")
        var ranges: [NSRange] = []
        var objects = Set<ObjectIdentifier>()
        s.enumerateAttribute(ChatTextInputAttributes.block, in: NSRange(location: 0, length: s.length), options: []) { value, range, _ in
            if let v = value as? ChatTextInputTextQuoteAttribute, case .quote = v.kind {
                ranges.append(range); objects.insert(ObjectIdentifier(v))
            }
        }
        XCTAssertEqual(ranges, [NSRange(location: 2, length: 3)], "quote must be one contiguous range incl. the interior newline")
        XCTAssertEqual(objects.count, 1, "the whole quote must share one attribute object")
        XCTAssertEqual(chatInputContent(from: s), content)
    }

    /// Worst-case draft-restore shape: a multi-line quote arriving as PER-LINE separate ranges carrying
    /// DISTINCT `ChatTextInputTextQuoteAttribute` objects (what a naive serialization round-trip can produce),
    /// surrounded by body text. The conversion must still re-contiguate it to ONE block range with ONE shared
    /// object — otherwise the restored composer renders stacked quote boxes. This isolates the conversion layer
    /// (the only quote-touching code Piece 2 changed) from the UIKit fix-up/rendering.
    func test_chatCurrencyRoundTrip_multiLineQuote_perLineObjects_recontiguates() {
        let s = NSMutableAttributedString(string: "before\nq1\nq2\nafter")
        // "before"=[0,6] \n=6 "q1"=[7,2] \n=9 "q2"=[10,2] \n=12 "after"=[13,5]
        s.addAttribute(ChatTextInputAttributes.block,
            value: ChatTextInputTextQuoteAttribute(kind: .quote, isCollapsed: false),
            range: NSRange(location: 7, length: 2))
        s.addAttribute(ChatTextInputAttributes.block,
            value: ChatTextInputTextQuoteAttribute(kind: .quote, isCollapsed: false),
            range: NSRange(location: 10, length: 2))

        let back = attributedString(from: chatInputContent(from: s))
        XCTAssertEqual(back.string, "before\nq1\nq2\nafter")
        var ranges: [NSRange] = []
        var objects = Set<ObjectIdentifier>()
        back.enumerateAttribute(ChatTextInputAttributes.block, in: NSRange(location: 0, length: back.length), options: []) { value, range, _ in
            if let v = value as? ChatTextInputTextQuoteAttribute, case .quote = v.kind {
                ranges.append(range); objects.insert(ObjectIdentifier(v))
            }
        }
        XCTAssertEqual(ranges, [NSRange(location: 7, length: 5)], "quote must re-contiguate to one range incl. the interior newline")
        XCTAssertEqual(objects.count, 1, "the whole quote must share one attribute object")
    }

    // MARK: - Task 5: chatInputContent(from:)

    func test_chatInputContent_parsesInlineAndBlocks() {
        let s = NSMutableAttributedString(string: "a\nq")
        s.addAttribute(ChatTextInputAttributes.bold, value: true as NSNumber, range: NSRange(location: 0, length: 1))
        s.addAttribute(ChatTextInputAttributes.block,
            value: ChatTextInputTextQuoteAttribute(kind: .quote, isCollapsed: false),
            range: NSRange(location: 2, length: 1))
        let c = chatInputContent(from: s)
        XCTAssertEqual(c.blocks.count, 2)
        guard case let .paragraph(p0) = c.blocks[0],
              case let .paragraph(p1) = c.blocks[1] else { return XCTFail() }
        XCTAssertTrue(p0.runs.first?.attributes.bold == true)
        if case .quote(let collapsed) = p1.style { XCTAssertFalse(collapsed) } else { XCTFail("expected quote") }
    }

    // MARK: - Task 6: round-trip identity

    private func file(_ id: Int64) -> TelegramMediaFile {
        TelegramMediaFile(
            fileId: MediaId(namespace: 0, id: id),
            partialReference: nil,
            resource: LocalFileMediaResource(fileId: id),
            previewRepresentations: [],
            videoThumbnails: [],
            immediateThumbnailData: nil,
            mimeType: "image/webp",
            size: nil,
            attributes: [],
            alternativeRepresentations: []
        )
    }

    func test_modelRoundTrip_identity_overCoveredFeatures() {
        var bold = ChatInputInlineAttributes(); bold.bold = true
        var emoji = ChatInputInlineAttributes(); emoji.entity = .customEmoji(fileId: 42, file: file(42), enableAnimation: true)
        var mention = ChatInputInlineAttributes(); mention.entity = .mention(EnginePeer.Id(9))
        let content = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .body, runs: [
                ChatInputRun(text: "Hi "),
                ChatInputRun(text: "bold", attributes: bold),
                ChatInputRun(text: "\u{FFFC}", attributes: emoji),
                ChatInputRun(text: "@x", attributes: mention),
            ])),
            .paragraph(ChatInputParagraph(style: .quote(isCollapsed: false), runs: [ChatInputRun(text: "q")])),
            .code(ChatInputCode(language: "swift", runs: [ChatInputRun(text: "let x = 1\nlet y = 2")])),
        ])
        XCTAssertEqual(chatInputContent(from: attributedString(from: content)), content)
    }

    // MARK: - Piece 4: model affordances must match the attributed string exactly

    /// A rich fixture exercising every block kind + inline attribute, so `plainText`/`length` parity is
    /// meaningfully tested (body run + bold + custom emoji + mention, a multi-line quote, a code block with an
    /// interior newline, and a collapsed quote).
    private func richFixture() -> ChatInputContent {
        var bold = ChatInputInlineAttributes(); bold.bold = true
        var emoji = ChatInputInlineAttributes(); emoji.entity = .customEmoji(fileId: 7, file: nil, enableAnimation: true)
        var mention = ChatInputInlineAttributes(); mention.entity = .mention(EnginePeer.Id(3))
        let collapsedNested = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "folded")]))
        ])
        return ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .body, runs: [
                ChatInputRun(text: "Hi "),
                ChatInputRun(text: "bold", attributes: bold),
                ChatInputRun(text: "\u{FFFC}", attributes: emoji),
                ChatInputRun(text: "@x", attributes: mention),
            ])),
            .paragraph(ChatInputParagraph(style: .quote(isCollapsed: false), runs: [ChatInputRun(text: "q1")])),
            .paragraph(ChatInputParagraph(style: .quote(isCollapsed: false), runs: [ChatInputRun(text: "q2")])),
            .code(ChatInputCode(language: "swift", runs: [ChatInputRun(text: "let a = 1\nlet b = 2")])),
            .collapsedQuote(collapsedNested),
        ])
    }

    func test_plainText_matchesAttributedStringString() {
        let content = richFixture()
        XCTAssertEqual(content.plainText, attributedString(from: content).string)
    }

    func test_length_matchesAttributedStringLength() {
        let content = richFixture()
        XCTAssertEqual(content.length, attributedString(from: content).length)
    }

    func test_plainText_emptyAndSingleBlock() {
        XCTAssertEqual(ChatInputContent().plainText, "")
        XCTAssertEqual(ChatInputContent().length, 0)
        let single = ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "abc")]))])
        XCTAssertEqual(single.plainText, "abc")
        XCTAssertEqual(single.plainText, attributedString(from: single).string)
        XCTAssertEqual(single.length, 3)
    }

    // MARK: - Piece 3: value-equality unlock (emoji object identity must NOT defeat equality)

    /// The mechanism `ChatTextInputState.==` relies on in Piece 3: two composer strings that carry the SAME
    /// custom emoji (same `fileId` + `enableAnimation`) but as DISTINCT attribute objects — and even differing
    /// `interactivelySelectedFromPackId` / `file` resolution — must convert to EQUAL `ChatInputContent` models.
    /// `ChatTextInputTextCustomEmojiAttribute.isEqual` is reference-based, so `NSAttributedString.isEqual(to:)`
    /// would call these strings unequal; the value model is what makes the model-routed GET read-back compare
    /// equal instead of churning change-detection.
    func test_modelEquality_sameEmojiDistinctObjects_areEqual() {
        let lhs = NSMutableAttributedString(string: "\u{FFFC}")
        lhs.addAttribute(ChatTextInputAttributes.customEmoji,
            value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: EngineItemCollectionId(namespace: 0, id: 111), fileId: 42, file: nil, enableAnimation: true),
            range: NSRange(location: 0, length: 1))
        let rhs = NSMutableAttributedString(string: "\u{FFFC}")
        rhs.addAttribute(ChatTextInputAttributes.customEmoji,
            value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 42, file: file(42), enableAnimation: true),
            range: NSRange(location: 0, length: 1))

        XCTAssertFalse(lhs.isEqual(to: rhs), "precondition: reference-based isEqual treats distinct emoji objects as unequal")
        XCTAssertEqual(chatInputContent(from: lhs), chatInputContent(from: rhs), "value model must ignore object identity / packId / file resolution")
    }

    /// Guard the other direction: a genuinely different emoji (different `fileId`) must convert to a DIFFERENT
    /// model — coarser-or-equal equality must not collapse distinct content.
    func test_modelEquality_differentFileId_areNotEqual() {
        let lhs = NSMutableAttributedString(string: "\u{FFFC}")
        lhs.addAttribute(ChatTextInputAttributes.customEmoji,
            value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 42, file: nil, enableAnimation: true),
            range: NSRange(location: 0, length: 1))
        let rhs = NSMutableAttributedString(string: "\u{FFFC}")
        rhs.addAttribute(ChatTextInputAttributes.customEmoji,
            value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 99, file: nil, enableAnimation: true),
            range: NSRange(location: 0, length: 1))

        XCTAssertNotEqual(chatInputContent(from: lhs), chatInputContent(from: rhs))
    }

    func test_modelRoundTrip_customEmoji_withNilFile_preservesFileId() {
        var e = ChatInputInlineAttributes(); e.entity = .customEmoji(fileId: 77, file: nil, enableAnimation: true)
        let content = ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "\u{FFFC}", attributes: e)]))])
        XCTAssertEqual(chatInputContent(from: attributedString(from: content)), content)
    }

    // MARK: - Task 0 (1b-ii): customEmoji enableAnimation fidelity

    func test_modelRoundTrip_customEmoji_preservesEnableAnimationFalse() {
        // enableAnimation defaults to true in the chat attribute; dropping it would silently
        // re-animate a non-animated emoji. The model must carry it (matching ChatTextInputStateText).
        var e = ChatInputInlineAttributes(); e.entity = .customEmoji(fileId: 5, file: nil, enableAnimation: false)
        let content = ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "\u{FFFC}", attributes: e)]))])
        XCTAssertEqual(chatInputContent(from: attributedString(from: content)), content)
    }

    // MARK: - Task 0 (1b-ii): collapsed-quote fidelity

    func test_modelRoundTrip_collapsedQuote_preservesNestedContent() {
        var bold = ChatInputInlineAttributes(); bold.bold = true
        let nested = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .body, runs: [
                ChatInputRun(text: "secret "),
                ChatInputRun(text: "stuff", attributes: bold),
            ]))
        ])
        let content = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "before")])),
            .collapsedQuote(nested),
            .paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "after")])),
        ])
        XCTAssertEqual(chatInputContent(from: attributedString(from: content)), content)
    }

    func test_modelRoundTrip_collapsedQuote_atStart() {
        let nested = ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "q")]))])
        let content = ChatInputContent(blocks: [
            .collapsedQuote(nested),
            .paragraph(ChatInputParagraph(style: .body, runs: [ChatInputRun(text: "after")])),
        ])
        XCTAssertEqual(chatInputContent(from: attributedString(from: content)), content)
    }

    /// The chat-currency direction: a hand-built FOLDED `.collapsedBlock` string (exactly what
    /// `textAttributedStringForStateText` consumes) must survive model round-trip with its nested
    /// content + placement intact — proving the legacy composer's display path stays byte-identical.
    func test_chatCurrencyRoundTrip_collapsedBlock_preserved() {
        let nested = NSMutableAttributedString(string: "hi")
        nested.addAttribute(ChatTextInputAttributes.bold, value: true as NSNumber, range: NSRange(location: 0, length: 2))
        let s = NSMutableAttributedString(string: "before\n \nafter")
        s.addAttribute(ChatTextInputAttributes.collapsedBlock, value: nested, range: NSRange(location: 7, length: 1))

        let back = attributedString(from: chatInputContent(from: s))
        XCTAssertEqual(back.string, "before\n \nafter")
        var found = false
        back.enumerateAttribute(ChatTextInputAttributes.collapsedBlock, in: NSRange(location: 0, length: back.length), options: []) { value, range, _ in
            if let v = value as? NSAttributedString {
                found = true
                XCTAssertEqual(range, NSRange(location: 7, length: 1))
                XCTAssertEqual(v.string, "hi")
                XCTAssertNotNil(v.attribute(ChatTextInputAttributes.bold, at: 0, effectiveRange: nil))
            }
        }
        XCTAssertTrue(found, "collapsedBlock attribute must survive the round-trip")
    }
}
