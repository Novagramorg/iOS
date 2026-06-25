#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class RTFConversionTests: XCTestCase {
    func test_export_producesRTFContainingText() throws {
        let frag = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("a"),
            runs: [TextRun(text: "Hi", attributes: CharacterAttributes(bold: true))]))])
        let data = try XCTUnwrap(RTFConversion.rtfData(from: frag))
        let s = try NSAttributedString(data: data,
                                       options: [.documentType: NSAttributedString.DocumentType.rtf],
                                       documentAttributes: nil)
        XCTAssertTrue(s.string.contains("Hi"))
        let font = try XCTUnwrap(s.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitBold))
    }

    func test_roundTrip_preservesBoldAndLink() {
        let frag = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("a"), runs: [
            TextRun(text: "B", attributes: CharacterAttributes(bold: true)),
            TextRun(text: "L", attributes: CharacterAttributes(link: "https://x.test")),
        ]))])
        let back = RTFConversion.fragment(fromRTF: RTFConversion.rtfData(from: frag)!)!
        guard case .paragraph(let p) = back.blocks[0] else { return XCTFail() }
        XCTAssertEqual(p.text, "BL")
        XCTAssertTrue(p.runs.first { $0.text == "B" }!.attributes.bold)
        XCTAssertEqual(p.runs.first { $0.text == "L" }!.attributes.link, "https://x.test")
    }

    func test_import_multiParagraph_splitsOnNewline() {
        let frag = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "one")])),
            .paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "two")])),
        ])
        let back = RTFConversion.fragment(fromRTF: RTFConversion.rtfData(from: frag)!)!
        XCTAssertEqual(back.blocks.compactMap { b -> String? in
            if case .paragraph(let p) = b { return p.text } else { return nil }
        }, ["one", "two"])
    }

    // MARK: Custom emoji cross-app via tg://emoji?id= (spec addendum 2026-06-24)

    private func emojiRun(id: String, alt: String?) -> TextRun {
        TextRun(text: "\u{FFFC}",
                attributes: CharacterAttributes(emoji: EmojiRef(id: id, instanceID: "inst", altText: alt)))
    }

    func test_export_emoji_emitsAltTextHyperlinkedToMarker() throws {
        let frag = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("a"), runs: [emojiRun(id: "12345", alt: ":star:")]))])
        let data = try XCTUnwrap(RTFConversion.rtfData(from: frag))
        let s = try NSAttributedString(data: data,
                                       options: [.documentType: NSAttributedString.DocumentType.rtf],
                                       documentAttributes: nil)
        XCTAssertTrue(s.string.contains(":star:"))                       // altText is the visible text
        let link = s.attribute(.link, at: 0, effectiveRange: nil)
        let urlString = (link as? URL)?.absoluteString ?? (link as? String)
        // id carried in the marker URL (a `&n=` per-emoji de-dup suffix may follow — see import tests)
        XCTAssertEqual(urlString?.hasPrefix("tg://emoji?id=12345"), true)
    }

    func test_import_emojiMarkerLink_reconstructsSingleObjectReplacementRun() throws {
        // RTF carrying a tg://emoji?id= hyperlink on ":star:" text (what another app would round-trip).
        let attr = NSAttributedString(string: ":star:", attributes: [
            .font: UIFont.systemFont(ofSize: 17),
            .link: URL(string: "tg://emoji?id=99")!,
        ])
        let data = try attr.data(from: NSRange(location: 0, length: attr.length),
                                 documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        let back = try XCTUnwrap(RTFConversion.fragment(fromRTF: data))
        guard case .paragraph(let p) = back.blocks[0] else { return XCTFail() }
        let run = try XCTUnwrap(p.runs.first { $0.attributes.emoji != nil })
        XCTAssertEqual(run.text, "\u{FFFC}")                             // one object-replacement char
        XCTAssertEqual(run.attributes.emoji?.id, "99")
        XCTAssertEqual(run.attributes.emoji?.altText, ":star:")          // display text preserved as altText
        XCTAssertNil(run.attributes.link)                                // reconstructed as emoji, not a link
    }

    func test_roundTrip_preservesCustomEmoji() throws {
        let frag = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("a"), runs: [
            TextRun(text: "hi "),
            emojiRun(id: "777", alt: ":fire:"),
        ]))])
        let back = try XCTUnwrap(RTFConversion.fragment(fromRTF: RTFConversion.rtfData(from: frag)!))
        guard case .paragraph(let p) = back.blocks[0] else { return XCTFail() }
        let run = try XCTUnwrap(p.runs.first { $0.attributes.emoji != nil })
        XCTAssertEqual(run.attributes.emoji?.id, "777")
        XCTAssertEqual(run.attributes.emoji?.altText, ":fire:")
        XCTAssertEqual(run.text, "\u{FFFC}")
    }

    func test_roundTrip_adjacentIdenticalEmoji_staySeparateRuns() throws {
        // Two adjacent emoji with the SAME id+altText+instanceID: a per-emoji boundary must keep them
        // distinct so RTF (which coalesces adjacent runs with identical attributes) doesn't merge them
        // into one. Worst case for de-duplication.
        let frag = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("a"), runs: [
            emojiRun(id: "5", alt: ":x:"),
            emojiRun(id: "5", alt: ":x:"),
        ]))])
        let back = try XCTUnwrap(RTFConversion.fragment(fromRTF: RTFConversion.rtfData(from: frag)!))
        guard case .paragraph(let p) = back.blocks[0] else { return XCTFail() }
        let emojiRuns = p.runs.filter { $0.attributes.emoji != nil }
        XCTAssertEqual(emojiRuns.count, 2)                                // both survived (not coalesced)
        XCTAssertTrue(emojiRuns.allSatisfy { $0.attributes.emoji?.id == "5" })
        XCTAssertTrue(emojiRuns.allSatisfy { $0.text == "\u{FFFC}" })
    }

    func test_import_normalLink_isNotTreatedAsEmoji() throws {
        let frag = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("a"), runs: [
            TextRun(text: "site", attributes: CharacterAttributes(link: "https://example.com")),
        ]))])
        let back = try XCTUnwrap(RTFConversion.fragment(fromRTF: RTFConversion.rtfData(from: frag)!))
        guard case .paragraph(let p) = back.blocks[0] else { return XCTFail() }
        let run = try XCTUnwrap(p.runs.first { $0.text == "site" })
        XCTAssertNil(run.attributes.emoji)                               // a normal link is NOT an emoji
        XCTAssertEqual(run.attributes.link, "https://example.com")
    }

    func test_import_repeatedLines_attributesNotCrossContaminated() {
        // Two paragraphs with identical text "note" but different formatting: first bold, second plain.
        let frag = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "note", attributes: CharacterAttributes(bold: true))])),
            .paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "note")])),
        ])
        let back = RTFConversion.fragment(fromRTF: RTFConversion.rtfData(from: frag)!)!
        let paras = back.blocks.compactMap { b -> ParagraphBlock? in
            if case .paragraph(let p) = b { return p } else { return nil }
        }
        XCTAssertEqual(paras.count, 2)
        XCTAssertEqual(paras[0].text, "note"); XCTAssertEqual(paras[1].text, "note")
        XCTAssertTrue(paras[0].runs.allSatisfy { $0.attributes.bold })   // first paragraph bold
        XCTAssertFalse(paras[1].runs.contains { $0.attributes.bold })    // second paragraph NOT bold
    }
}
#endif
