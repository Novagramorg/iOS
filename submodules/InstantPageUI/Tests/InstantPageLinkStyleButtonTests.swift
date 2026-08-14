import XCTest
import UIKit
import TelegramCore
import TextFormat
@testable import InstantPageUI

/// A style stack shaped like a body paragraph's: a 17pt regular face, black text, blue links.
/// `.link(false)` only takes effect when a `linkColor` is on the stack, so the tests must supply one.
private func makeParagraphStyleStack() -> InstantPageTextStyleStack {
    let stack = InstantPageTextStyleStack()
    stack.push(.textColor(.black))
    stack.push(.linkColor(.blue))
    stack.push(.fontSize(17.0))
    return stack
}

private func linkButton(action: ReplyMarkupButtonAction) -> RichText {
    return .textButton(InstantPageButton(text: .plain("Open"), action: action, color: nil, isLink: true))
}

private func attribute(_ string: NSAttributedString, _ key: String) -> Any? {
    guard string.length != 0 else {
        return nil
    }
    return string.attribute(NSAttributedString.Key(rawValue: key), at: 0, effectiveRange: nil)
}

final class InstantPageLinkStyleButtonTests: XCTestCase {
    /// A `.url` action must become an ordinary link — same attribute every other link in the page
    /// uses — so it inherits the long-press menu and the concealed-URL confirmation for free.
    func testUrlActionBecomesAnOrdinaryLink() {
        let result = attributedStringForRichText(linkButton(action: .url("https://telegram.org")), styleStack: makeParagraphStyleStack())

        XCTAssertEqual(result.string, "Open")
        let url = attribute(result, TelegramTextAttributes.URL) as? InstantPageUrlItem
        XCTAssertEqual(url?.url, "https://telegram.org")
        XCTAssertNil(attribute(result, InstantPageButtonActionAttribute))
        XCTAssertNil(attribute(result, InstantPageInlineButtonAttribute))
    }

    /// Every non-URL action carries the button itself instead, for the bubble to dispatch.
    /// `.copyText` rather than `.callback` on purpose: `.callback`'s payload is a Postbox
    /// `MemoryBuffer`, and this test target does not depend on Postbox.
    func testNonUrlActionCarriesTheButtonAttribute() {
        let action = ReplyMarkupButtonAction.copyText(payload: "abc")
        let result = attributedStringForRichText(linkButton(action: action), styleStack: makeParagraphStyleStack())

        XCTAssertEqual(result.string, "Open")
        let item = attribute(result, InstantPageButtonActionAttribute) as? InstantPageButtonActionItem
        XCTAssertEqual(item?.button.action, action)
        XCTAssertNil(attribute(result, TelegramTextAttributes.URL))
        XCTAssertNil(attribute(result, InstantPageInlineButtonAttribute))
    }

    /// A link-coloured span that does nothing is worse than plain text, so `.disabled` renders as
    /// ordinary text: no link styling, no tap attribute of either kind.
    func testDisabledActionRendersAsInertPlainText() {
        let result = attributedStringForRichText(linkButton(action: .disabled), styleStack: makeParagraphStyleStack())

        XCTAssertEqual(result.string, "Open")
        XCTAssertNil(attribute(result, TelegramTextAttributes.URL))
        XCTAssertNil(attribute(result, InstantPageButtonActionAttribute))
        // Body colour, not link colour: `.link(false)` was never pushed.
        XCTAssertEqual(result.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, UIColor.black)
    }

    /// "Lays out like all other links" means it inherits the paragraph's typography — the exact
    /// inverse of a pill, which pushes its own 15pt medium face.
    func testLinkButtonInheritsParagraphTypography() {
        let plain = attributedStringForRichText(.plain("Open"), styleStack: makeParagraphStyleStack())
        let link = attributedStringForRichText(linkButton(action: .url("https://telegram.org")), styleStack: makeParagraphStyleStack())

        let plainFont = plain.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        let linkFont = link.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertNotNil(plainFont)
        XCTAssertEqual(linkFont, plainFont)
    }

    /// A link button is ORDINARY TEXT in the paragraph, not a pill, so its label emoji must be exactly
    /// the size of the same emoji sitting beside it in that paragraph.
    ///
    /// This reverses an earlier rule that shrank it to `A - D` to fit the chat bubble's 22pt
    /// line-to-line advance. That never solved the overlap it cited — an ordinary body emoji in the
    /// same paragraph overhangs the row by exactly as much — it only made link buttons inconsistent
    /// with the text around them. The pill rewrite (`instantPageButtonLabelWithFittedEmoji`) stays,
    /// because a pill really does clip its label with `clipsToBounds`.
    func testLinkButtonEmojiMatchesBodyEmojiSize() {
        let stack = InstantPageTextStyleStack()
        stack.push(.textColor(.black))
        stack.push(.linkColor(.blue))
        stack.push(.fontSize(17.0))
        stack.push(.lineSpacingFactor(0.9))

        let emoji = RichText.textCustomEmoji(fileId: 1, alt: "x")
        // A plain emoji and a link-button emoji on the SAME line, so the comparison is like-for-like.
        let string = attributedStringForRichText(
            .concat([
                .plain("a "),
                emoji,
                .plain(" b "),
                .textButton(InstantPageButton(text: emoji, action: .copyText(payload: "p"), color: nil, isLink: true)),
                .plain(" c")
            ]),
            styleStack: stack
        )
        let (item, _, _) = layoutTextItem(string, boundingWidth: 400.0, offset: CGPoint())
        guard let line = item?.lines.first, line.emojiItems.count == 2 else {
            XCTFail("expected both emoji on one line, got \(item?.lines.first?.emojiItems.count ?? -1)")
            return
        }
        XCTAssertEqual(line.emojiItems[0].frame.height, line.emojiItems[1].frame.height, accuracy: 0.01,
                       "a link button's emoji must match the body emoji beside it")
        XCTAssertEqual(line.emojiItems[0].frame.width, line.emojiItems[1].frame.width, accuracy: 0.01)
    }

}
