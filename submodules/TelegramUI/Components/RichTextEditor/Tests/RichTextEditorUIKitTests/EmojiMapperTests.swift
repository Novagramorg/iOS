#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class EmojiMapperTests: XCTestCase {
    private let mapper = AttributedStringMapper()

    private func ref() -> EmojiRef { EmojiRef(id: "star", instanceID: "i1", altText: ":star:") }

    func test_attributesForEmoji_carryAttachmentWithRef() {
        let attrs = mapper.attributes(for: CharacterAttributes(emoji: ref()), style: .body)
        let att = attrs[.attachment] as? EmojiTextAttachment
        XCTAssertNotNil(att, "an emoji run must carry an EmojiTextAttachment")
        XCTAssertEqual(att?.ref, ref())
        XCTAssertNotNil(attrs[.font], "the attachment is sized from the run's font, which must be present")
    }

    func test_emojiAttachmentBounds_isSquareSizedToFont() {
        let font = UIFont.systemFont(ofSize: 17)
        let att = EmojiTextAttachment(ref: ref(), scale: 1.0)
        let bounds = att.attachmentBounds(for: [.font: font], location: DummyLocation(),
                                          textContainer: nil, proposedLineFragment: .zero, position: .zero)
        XCTAssertEqual(bounds.width, bounds.height, accuracy: 0.01, "emoji box must be square")
        XCTAssertEqual(bounds.width, font.ascender - font.descender, accuracy: 0.5, "side = ascender + |descender|")
        XCTAssertEqual(bounds.origin.y, font.descender, accuracy: 0.5, "baseline-aligned (y = descender)")
    }

    func test_emojiScale_appliesToSide() {
        let font = UIFont.systemFont(ofSize: 17)
        let att = EmojiTextAttachment(ref: ref(), scale: 2.0)
        let bounds = att.attachmentBounds(for: [.font: font], location: DummyLocation(),
                                          textContainer: nil, proposedLineFragment: .zero, position: .zero)
        XCTAssertEqual(bounds.width, (font.ascender - font.descender) * 2.0, accuracy: 0.5)
    }

    func test_characterAttributesFromEmojiDict_recoversRefAndNothingElse() {
        let attrs = mapper.attributes(for: CharacterAttributes(emoji: ref()), style: .body)
        let back = mapper.characterAttributes(from: attrs)
        XCTAssertEqual(back.emoji, ref())
        XCTAssertNil(back.fontFamily, "the style font must not leak into the model")
        XCTAssertNil(back.foreground)
        XCTAssertFalse(back.bold)
    }

    func test_runsRoundTrip_keepsEmojiAsItsOwnRun() {
        let block = ParagraphBlock(id: BlockID("p1"), style: .body, runs: [
            TextRun(text: "A"),
            TextRun(text: "\u{FFFC}", attributes: CharacterAttributes(emoji: ref())),
            TextRun(text: "B"),
        ])
        let attr = mapper.attributedString(for: block)
        XCTAssertEqual(attr.string, "A\u{FFFC}B")
        let runs = mapper.runs(from: attr)
        XCTAssertEqual(runs.count, 3)
        XCTAssertEqual(runs[1].text, "\u{FFFC}")
        XCTAssertEqual(runs[1].attributes.emoji, ref())
        XCTAssertNil(runs[0].attributes.emoji)
        XCTAssertNil(runs[2].attributes.emoji)
    }

    func test_layoutReservesSquareBoxForEmoji() {
        let block = ParagraphBlock(id: BlockID("p1"), style: .body,
                                   runs: [TextRun(text: "\u{FFFC}", attributes: CharacterAttributes(emoji: ref()))])
        let layout = BlockLayout(attributedString: mapper.attributedString(for: block), width: 320)
        let rects = layout.selectionRects(start: 0, end: 1)
        XCTAssertFalse(rects.isEmpty, "the emoji must reserve a layout box")
        let font = mapper.styleSheet.font(for: .body, attributes: CharacterAttributes())
        XCTAssertEqual(rects[0].width, font.ascender - font.descender, accuracy: 4.0,
                       "the reserved box width ≈ the square side")
    }
}

/// A minimal NSTextLocation for exercising attachmentBounds in a unit test.
private final class DummyLocation: NSObject, NSTextLocation {
    func compare(_ location: NSTextLocation) -> ComparisonResult { .orderedSame }
}
#endif
