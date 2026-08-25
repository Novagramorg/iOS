import Foundation
import UIKit

public extension InstantPageTextCategories {
    /// The text categories a rich message renders with in a chat bubble.
    ///
    /// This was three hand-copied tables — the bubble, the long-press send preview, and the
    /// TextProcessing screen — which had DRIFTED apart: the bubble carried heading
    /// `lineSpacingFactor` 1.0 and body 0.9, the other two 0.685 and 1.0, so the send preview did not
    /// match the bubble it was previewing. The bubble's values won because it is the surface the
    /// recipient actually sees.
    ///
    /// It is also what both rich-text editor hosts lay text out with, via
    /// `InstantPageTheme.richTextRenderMetrics()` — so the composer and the article editor are
    /// WYSIWYG against this table. Changing a value here moves the editor too, by design.
    static func chatMessage(primaryText: UIColor, secondaryText: UIColor) -> InstantPageTextCategories {
        return InstantPageTextCategories(
            kicker: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 15.0, lineSpacingFactor: 1.0), color: primaryText),
            header: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: 24.0, lineSpacingFactor: 1.0, weight: .medium), color: primaryText),
            subheader: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: instantPageNominalSubheaderFontSize, lineSpacingFactor: 1.0, weight: .medium), color: primaryText),
            paragraph: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 17.0, lineSpacingFactor: 0.9), color: primaryText),
            caption: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 15.0, lineSpacingFactor: 1.0), color: secondaryText),
            credit: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 13.0, lineSpacingFactor: 1.0), color: secondaryText),
            table: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: 15.0, lineSpacingFactor: 1.0), color: primaryText),
            article: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: 18.0, lineSpacingFactor: 1.0), color: primaryText),
            codeBlock: InstantPageTextAttributes(font: InstantPageFont(style: .monospace, size: 14.0, lineSpacingFactor: 1.0), color: primaryText)
        )
    }
}
