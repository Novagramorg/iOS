#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class StyleSheetTests: XCTestCase {
    func test_color_roundTrips() {
        let c = RGBAColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.8)
        let back = c.uiColor.rgba
        XCTAssertEqual(back.red, 0.2, accuracy: 0.01)
        XCTAssertEqual(back.alpha, 0.8, accuracy: 0.01)
    }

    func test_font_appliesBoldItalicAndSize() {
        let f = FontResolver.font(family: nil, size: 20, bold: true, italic: true)
        XCTAssertEqual(f.pointSize, 20, accuracy: 0.5)
        XCTAssertTrue(f.fontDescriptor.symbolicTraits.contains(.traitBold))
        XCTAssertTrue(f.fontDescriptor.symbolicTraits.contains(.traitItalic))
    }

    func test_styleSheet_headingIsLargerThanBody() {
        let sheet = StyleSheet.default
        let h1 = sheet.font(for: .heading1, attributes: .plain)
        let body = sheet.font(for: .body, attributes: .plain)
        XCTAssertGreaterThan(h1.pointSize, body.pointSize)
    }

    func test_caption_is15ptSans_andBodyIsSans() {
        let sheet = StyleSheet.default
        let caption = sheet.font(for: .caption, attributes: .plain)
        XCTAssertEqual(caption.pointSize, 15, accuracy: 0.5)
        XCTAssertEqual(caption.familyName, UIFont.systemFont(ofSize: 15).familyName, "captions are sans")
        XCTAssertEqual(sheet.font(for: .body, attributes: .plain).familyName,
                       UIFont.systemFont(ofSize: 17).familyName, "body is sans")
    }

    func test_heading_isSerif_andNotBoldByDefault() {
        let f = StyleSheet.default.font(for: .heading1, attributes: .plain)
        XCTAssertTrue(f.fontName.contains("NewYork"), "headings stay serif")
        XCTAssertFalse(f.fontDescriptor.symbolicTraits.contains(.traitBold),
                       "headings are regular weight by default — bold is user emphasis only")
    }

    func test_heading_userBoldStillApplies() {
        var bold = CharacterAttributes(); bold.bold = true
        let f = StyleSheet.default.font(for: .heading1, attributes: bold)
        XCTAssertTrue(f.fontDescriptor.symbolicTraits.contains(.traitBold),
                      "a user can still bold a heading explicitly")
    }

    func test_body_is17pt() {
        XCTAssertEqual(StyleSheet.default.font(for: .body, attributes: .plain).pointSize, 17, accuracy: 0.5)
    }

    func test_headingSizes_matchTypeScale() {
        let sheet = StyleSheet.default
        XCTAssertEqual(sheet.font(for: .heading1, attributes: .plain).pointSize, 24, accuracy: 0.5)
        XCTAssertEqual(sheet.font(for: .heading2, attributes: .plain).pointSize, 21, accuracy: 0.5)
        XCTAssertEqual(sheet.font(for: .heading3, attributes: .plain).pointSize, 19, accuracy: 0.5)
    }

    func test_perStyleSpacing_applied() {
        let sheet = StyleSheet.default
        let body = sheet.paragraphStyle(for: .body, attributes: .default) as! NSParagraphStyle
        XCTAssertGreaterThan(body.lineHeightMultiple, 1.0)                 // body gets a line-height bump
        let h1 = sheet.paragraphStyle(for: .heading1, attributes: .default) as! NSParagraphStyle
        XCTAssertGreaterThan(h1.paragraphSpacingBefore, 0)                 // headings get space before
    }
}
#endif
