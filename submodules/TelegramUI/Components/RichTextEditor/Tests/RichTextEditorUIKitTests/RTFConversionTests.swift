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
