#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class StyleSheetQuoteTests: XCTestCase {
    func test_quote_defaults_matchTodaysValues() {
        let s = StyleSheet()
        let ps = s.paragraphStyle(for: .quote, attributes: .default)
        XCTAssertEqual(ps.headIndent, 16, accuracy: 0.01)
        XCTAssertEqual(ps.firstLineHeadIndent, 16, accuracy: 0.01)
        XCTAssertEqual(ps.paragraphSpacingBefore, 8, accuracy: 0.01)
        XCTAssertEqual(ps.paragraphSpacing, 8, accuracy: 0.01)
    }

    func test_quote_customIndentAndSpacing_areApplied() {
        var s = StyleSheet()
        s.quoteIndent = 4
        s.quoteSpacingBefore = 2
        s.quoteSpacingAfter = 6
        let ps = s.paragraphStyle(for: .quote, attributes: .default)
        XCTAssertEqual(ps.headIndent, 4, accuracy: 0.01)
        XCTAssertEqual(ps.firstLineHeadIndent, 4, accuracy: 0.01)
        XCTAssertEqual(ps.paragraphSpacingBefore, 2, accuracy: 0.01)
        XCTAssertEqual(ps.paragraphSpacing, 6, accuracy: 0.01)
    }

    func test_body_unaffectedByQuoteFields() {
        var s = StyleSheet()
        s.quoteIndent = 99
        let ps = s.paragraphStyle(for: .body, attributes: .default)
        XCTAssertEqual(ps.headIndent, 0, accuracy: 0.01)
    }
}
#endif
