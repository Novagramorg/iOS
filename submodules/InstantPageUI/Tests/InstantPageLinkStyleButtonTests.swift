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

    /// The chat rich bubble's paragraph is 17pt with `lineSpacingFactor` 0.9
    /// (`ChatMessageRichDataBubbleContentNode`), giving a 12pt line box and a 22pt line-to-line
    /// advance. A body-sized emoji is 24.29pt — **taller than the whole row** — so it overlaps the
    /// lines above and below and reads as an inflated, shoved line. A link button's label emoji must
    /// therefore fit inside the advance.
    ///
    /// The requirement is the row, not a particular constant, so that is what this asserts. Both
    /// alternatives were tried against real content and rejected: body sizing (24.29pt) inflates the
    /// row, and the bare line box (`floor(A + D)`, 12pt) fits but renders at 49% of a neighbouring
    /// emoji, reading as a shrunken glyph.
    func testLinkButtonEmojiFitsTheProductionRow() {
        let stack = InstantPageTextStyleStack()
        stack.push(.textColor(.black))
        stack.push(.linkColor(.blue))
        stack.push(.fontSize(17.0))
        stack.push(.lineSpacingFactor(0.9))

        let emoji = RichText.textCustomEmoji(fileId: 1, alt: "x")
        let string = attributedStringForRichText(
            .concat([
                .plain("Hello there "),
                .textButton(InstantPageButton(text: emoji, action: .copyText(payload: "p"), color: nil, isLink: true)),
                .plain(" and some more words here too")
            ]),
            styleStack: stack
        )
        let (item, _, _) = layoutTextItem(string, boundingWidth: 200.0, offset: CGPoint())
        let lines = item?.lines ?? []

        guard lines.count > 1, let emojiItem = lines[0].emojiItems.first else {
            XCTFail("expected a wrapped paragraph with one emoji on the first line")
            return
        }
        let advance = lines[1].frame.minY - lines[0].frame.minY
        XCTAssertLessThanOrEqual(
            emojiItem.frame.height, advance,
            "emoji is taller than the line-to-line advance, so it collides with adjacent rows"
        )
        // And it must not have shrunk to the bare line box, which reads as a half-size glyph.
        XCTAssertGreaterThan(emojiItem.frame.height, lines[0].frame.height * 1.5)
    }

    /// The tap/progress highlight must cover the WHOLE label, not the one attribute run under the
    /// finger. A button label of text + emoji is at least two runs — the emoji placeholder carries a
    /// run delegate and the custom-emoji attribute that the text does not — and
    /// `attribute(_:at:effectiveRange:)` is explicitly NOT required to return the maximal range, so
    /// it hands back just that run. Touching the text and touching the emoji must therefore produce
    /// the same rects.
    func testHighlightRectsCoverTheWholeLabelNotOneRun() {
        let emoji = RichText.textCustomEmoji(fileId: 1, alt: "x")
        let string = attributedStringForRichText(
            .textButton(InstantPageButton(
                text: .concat([.plain("Open"), emoji]),
                action: .copyText(payload: "p"),
                color: nil,
                isLink: true
            )),
            styleStack: makeParagraphStyleStack()
        )
        let (item, _, _) = layoutTextItem(string, boundingWidth: 300.0, offset: CGPoint())

        guard let item, let line = item.lines.first, let emojiItem = line.emojiItems.first else {
            XCTFail("expected a laid-out line with an emoji")
            return
        }
        let overText = item.linkSelectionRects(at: CGPoint(x: line.frame.minX + 2.0, y: line.frame.midY))
        let overEmoji = item.linkSelectionRects(at: CGPoint(x: emojiItem.frame.midX, y: line.frame.midY))

        XCTAssertFalse(overText.isEmpty, "no highlight rects over the label's text")
        XCTAssertEqual(overText, overEmoji, "highlight differs depending on which run is touched")
        // And it genuinely spans the label rather than coinciding on one narrow run.
        let widest = overText.map({ $0.width }).max() ?? 0.0
        XCTAssertGreaterThan(widest, emojiItem.frame.width * 1.5)
    }

    /// Regression guard: a button WITHOUT the bit must still take the pill path untouched.
    func testNonLinkButtonStillBuildsAPill() {
        let button = RichText.textButton(InstantPageButton(text: .plain("Open"), action: .url("https://telegram.org"), color: nil))
        let result = attributedStringForRichText(button, styleStack: makeParagraphStyleStack())

        XCTAssertNotNil(attribute(result, InstantPageInlineButtonAttribute) as? InstantPageInlineButtonAttachment)
        XCTAssertNil(attribute(result, InstantPageButtonActionAttribute))
    }
}
