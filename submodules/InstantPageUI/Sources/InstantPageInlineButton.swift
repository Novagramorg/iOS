import Foundation
import UIKit
import CoreText
import TelegramCore

/// A measured inline button. Mirrors `InstantPageMathAttachment` (`InstantPageMath.swift:18`): the
/// attribute payload carries both the model and the metrics, because the V2 line-breaker raises the
/// line's ascent/descent from the attachment itself and has no `styleStack` with which to re-measure.
public final class InstantPageInlineButtonAttachment: NSObject {
    public let button: InstantPageButton
    /// The label, already laid out with the surrounding style stack.
    public let labelString: NSAttributedString
    /// Full pill size — the label's ink box inflated by the padding below.
    public let size: CGSize
    public let ascent: CGFloat
    public let descent: CGFloat

    public init(button: InstantPageButton, labelString: NSAttributedString, size: CGSize, ascent: CGFloat, descent: CGFloat) {
        self.button = button
        self.labelString = labelString
        self.size = size
        self.ascent = ascent
        self.descent = descent
    }
}

/// Padding between the label's ink and the pill edge. Starting values — tune at the visual pass.
/// For scale, `TextRenderView`'s `markedItems` highlight uses ±2pt horizontal with a 2.2x height
/// inflation; a button wants noticeably more horizontal room than a highlight.
public let instantPageInlineButtonHorizontalPadding: CGFloat = 7.0
public let instantPageInlineButtonVerticalPadding: CGFloat = 1.0

/// Button labels carry their own typography rather than inheriting the paragraph's — semibold in both
/// cases, one point smaller inline than in a block row. Fixed sizes, so they do not scale with the
/// Instant View font-size setting; the chat bubble's own text categories are likewise fixed.
public let instantPageInlineButtonFontSize: CGFloat = 15.0
public let instantPageBlockButtonFontSize: CGFloat = 16.0

/// Truncates `labelString` with a tail ellipsis so its ink fits `availableWidth`. Returns the input
/// unchanged when it already fits.
private func instantPageButtonTruncatedLabel(_ labelString: NSAttributedString, availableWidth: CGFloat) -> NSAttributedString {
    guard labelString.length != 0, availableWidth > 0.0 else {
        return labelString
    }
    let fullWidth = CGFloat(CTLineGetTypographicBounds(CTLineCreateWithAttributedString(labelString), nil, nil, nil))
    if fullWidth <= availableWidth {
        return labelString
    }

    // Inherit the label's own attributes (font, weight) so the ellipsis matches the text it replaces.
    let tailAttributes = labelString.attributes(at: labelString.length - 1, effectiveRange: nil)
    let ellipsis = NSAttributedString(string: "\u{2026}", attributes: tailAttributes)
    let ellipsisWidth = CGFloat(CTLineGetTypographicBounds(CTLineCreateWithAttributedString(ellipsis), nil, nil, nil))

    // Not enough room for even one character plus the ellipsis: show the ellipsis alone.
    let widthForText = availableWidth - ellipsisWidth
    guard widthForText > 0.0 else {
        return ellipsis
    }

    let typesetter = CTTypesetterCreateWithAttributedString(labelString)
    let fittingCount = CTTypesetterSuggestClusterBreak(typesetter, 0, Double(widthForText))
    guard fittingCount > 0 else {
        return ellipsis
    }

    let result = NSMutableAttributedString(attributedString: labelString.attributedSubstring(from: NSRange(location: 0, length: min(fittingCount, labelString.length))))
    result.append(ellipsis)
    return result
}

/// Measures `labelString` and inflates it by the pill padding. The single construction path for both
/// inline `textButton`s and `pageBlockButtonRow` members, so `size`, `ascent` and `descent` mean the
/// same thing in both — the pill view relies on that when it centres the label.
///
/// `maxWidth` caps the whole pill. A pill wider than the line it sits on cannot be moved anywhere by
/// the line-breaker's re-break (that path requires the line to hold more than the pill), so the label
/// is truncated with an ellipsis instead of overflowing. Pass nil for no cap.
public func instantPageInlineButtonAttachment(button: InstantPageButton, labelString: NSAttributedString, maxWidth: CGFloat? = nil) -> InstantPageInlineButtonAttachment {
    let hPad = instantPageInlineButtonHorizontalPadding
    let vPad = instantPageInlineButtonVerticalPadding

    var effectiveLabel = labelString
    if let maxWidth {
        effectiveLabel = instantPageButtonTruncatedLabel(labelString, availableWidth: max(0.0, maxWidth - hPad * 2.0))
    }

    let line = CTLineCreateWithAttributedString(effectiveLabel)
    var labelAscent: CGFloat = 0.0
    var labelDescent: CGFloat = 0.0
    let labelWidth = CGFloat(CTLineGetTypographicBounds(line, &labelAscent, &labelDescent, nil))
    return InstantPageInlineButtonAttachment(
        button: button,
        labelString: effectiveLabel,
        size: CGSize(width: labelWidth + hPad * 2.0, height: labelAscent + labelDescent + vPad * 2.0),
        ascent: labelAscent + vPad,
        descent: labelDescent + vPad
    )
}

/// Fill and label colours for a button pill. Mirrors the semantics of
/// `ChatMessageActionButtonsNode.swift:468-472` (coloured background at reduced alpha) but sources
/// from `InstantPageTheme`, which is what the V2 renderer is handed. Alphas are tunable.
///
/// `isInline` distinguishes an inline `RichText.textButton` pill from a block-level
/// `pageBlockButtonRow` pill. Both currently resolve to the same colours — the parameter is the seam
/// for giving them different treatments (an inline pill sits inside a paragraph and may want a lighter
/// fill than a standalone row button).
public func instantPageButtonColors(
    _ color: ReplyMarkupButton.Style.Color?,
    theme: InstantPageTheme,
    isInline: Bool,
    isDisabled: Bool
) -> (fill: UIColor, label: UIColor) {
    let fill: UIColor
    let label: UIColor
    switch color {
    case .none:
        if isInline {
            fill = theme.panelBackgroundColor
            label = theme.panelAccentColor
        } else {
            fill = theme.tableHeaderColor
            label = theme.panelPrimaryColor
        }
    case .some(.primary):
        fill = theme.checkboxFill
        label = theme.checkboxForeground
    case .some(.danger):
        fill = theme.buttonDangerColor.withMultipliedAlpha(0.15)
        label = theme.buttonDangerColor
    case .some(.success):
        fill = theme.buttonSuccessColor.withMultipliedAlpha(0.15)
        label = theme.buttonSuccessColor
    }
    if isDisabled {
        return (fill, label.withMultipliedAlpha(0.4))
    }
    return (fill, label)
}
