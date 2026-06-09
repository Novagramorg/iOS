#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class KeyboardAvoidanceTests: XCTestCase {
    func test_keyboardOverlap_whenKeyboardCoversBottom() {
        let scroll = CGRect(x: 0, y: 0, width: 375, height: 800)
        let kb = CGRect(x: 0, y: 500, width: 375, height: 336)   // covers bottom 300pt
        XCTAssertEqual(RichTextEditorView.keyboardOverlap(scrollFrameInWindow: scroll, keyboardFrameInWindow: kb), 300)
    }
    func test_keyboardOverlap_whenKeyboardFullyBelow_isZero() {
        let scroll = CGRect(x: 0, y: 0, width: 375, height: 500)
        let kb = CGRect(x: 0, y: 600, width: 375, height: 300)   // entirely below the scroll view
        XCTAssertEqual(RichTextEditorView.keyboardOverlap(scrollFrameInWindow: scroll, keyboardFrameInWindow: kb), 0)
    }
    func test_keyboardOverlap_partial() {
        let scroll = CGRect(x: 0, y: 100, width: 375, height: 700) // maxY = 800
        let kb = CGRect(x: 0, y: 650, width: 375, height: 336)     // overlaps [650,800] = 150
        XCTAssertEqual(RichTextEditorView.keyboardOverlap(scrollFrameInWindow: scroll, keyboardFrameInWindow: kb), 150)
    }
    func test_applyKeyboardOverlap_setsBottomInset() {
        let v = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 375, height: 800))
        v.applyKeyboardOverlap(250)
        XCTAssertEqual(v.bottomContentInsetForTesting, 250)
        v.applyKeyboardOverlap(0)
        XCTAssertEqual(v.bottomContentInsetForTesting, 0)
    }
}
#endif
