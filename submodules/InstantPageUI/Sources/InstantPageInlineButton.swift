import Foundation
import UIKit
import CoreText
import TelegramCore
import TextFormat

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

/// Extra gap between two *directly adjacent* pills — two `textButton`s with no rich text between
/// them. Without it they touch: each pill's width lives entirely on its placeholder's CTRunDelegate,
/// which reports exactly the pill width, so consecutive placeholders leave no advance between the
/// two fills. Only adjacency is padded; a pill next to ordinary text already gets that text's own
/// spaces.
public let instantPageInlineButtonAdjacentSpacing: CGFloat = 3.0

/// Button labels carry their own typography rather than inheriting the paragraph's — semibold in both
/// cases, one point smaller inline than in a block row. Fixed sizes, so they do not scale with the
/// Instant View font-size setting; the chat bubble's own text categories are likewise fixed.
public let instantPageInlineButtonFontSize: CGFloat = 15.0
public let instantPageBlockButtonFontSize: CGFloat = 16.0

/// The side of an emoji square inside a button label: the font's own line box, `A − D`
/// (≈20.1pt at 17pt, against a body emoji's ≈24.3pt).
///
/// Deliberately NOT the body-text emoji size (`A − D + 4·pointSize/17`, `InstantPageTextItem.swift`).
/// It has to be smaller for two independent reasons, and both land on this same value:
///
/// - **A pill** is `clipsToBounds = true` — load-bearing, without it the capsule renders as a rect —
///   and its height is the label's ink box plus 2pt of padding, so the body size overflows and the
///   capsule shaves the emoji's top and bottom.
/// - **A link-styled button** is flowing text, and the chat bubble's paragraph
///   (`ChatMessageRichDataBubbleContentNode`: 17pt, `lineSpacingFactor` 0.9) has a line box of 12pt
///   and a line-to-line advance of just 22pt. A body-sized 24.3pt emoji is taller than the entire
///   row: it overhangs 6.15pt per side against 5pt of leading and visibly collides with the lines
///   above and below. `A − D` overhangs 4.05pt, clearing them.
///
/// So this is the largest standard size that fits a body row, which is why it is not tuned by eye.
/// The cost is that a button-label emoji reads at 84% of a neighbouring body emoji; sizing it to the
/// bare line box instead (`floor(A + D)`, 12pt) removes the overhang entirely but renders at 49%,
/// which reads as a shrunken glyph.
func instantPageButtonLabelEmojiSide(font: UIFont) -> CGFloat {
    return font.ascender - font.descender
}

/// Rewrites every custom-emoji run delegate in a button label so the emoji fits the pill.
///
/// A custom emoji arrives as a ONE-character `" "` placeholder carrying a `CTRunDelegate` and a
/// `ChatTextInputAttributes.customEmoji` value, built by `attributedStringForRichText`'s
/// `.textCustomEmoji` arm for BODY TEXT. Two of that delegate's three numbers are wrong in a pill:
///
/// - **width** is the body-text emoji size, which overflows the capsule (see
///   `instantPageButtonLabelEmojiSide`).
/// - **descent** is `font.descender`, which is NEGATIVE. In body text nothing reads it — the V2 line
///   layout pins `lineDescent` to `fontDescentBelowBaseline` — but a pill measures its own height with
///   `CTLineGetTypographicBounds`. For a label that is ONLY an emoji no other run contributes a
///   positive descent, so the line's descent comes back negative and the pill collapses from ~19.7pt
///   to ~12.9pt.
///
/// Correcting them HERE, inside the single construction path and BEFORE truncation and measurement,
/// is what makes the reserved advance and the drawn square the same number by construction. The body
/// text arm is deliberately left alone so no existing page's metrics move.
///
/// Shared with the LINK-styled path (`attributedStringForLinkStyleButton`), which needs the same
/// sizing for a different reason — see `instantPageButtonLabelEmojiSide`. That path is the reason
/// `InstantPageEmojiSizeAttribute` is written as well as the delegate: a link button's label is laid
/// out by the V2 line layout, which derives the drawn square from the FONT and never reads the
/// delegate, so rewriting the delegate alone would shrink the advance and leave a body-sized emoji
/// drawn on top of it. The attribute is inert for a pill, which draws its own label.
func instantPageButtonLabelWithFittedEmoji(_ labelString: NSAttributedString) -> NSAttributedString {
    struct RunStruct {
        let ascent: CGFloat
        let descent: CGFloat
        let width: CGFloat
    }

    var emojiIndices: [Int] = []
    // Character-by-character rather than `enumerateAttribute`: attribute enumeration coalesces
    // adjacent runs carrying equal values, which would merge two side-by-side emoji into one range.
    // Every placeholder is exactly one character, so indices are the natural unit.
    for index in 0 ..< labelString.length {
        if labelString.attribute(ChatTextInputAttributes.customEmoji, at: index, effectiveRange: nil) != nil {
            emojiIndices.append(index)
        }
    }
    guard !emojiIndices.isEmpty else {
        return labelString
    }

    let result = labelString.mutableCopy() as! NSMutableAttributedString
    for index in emojiIndices {
        let font = (labelString.attribute(.font, at: index, effectiveRange: nil) as? UIFont) ?? UIFont.systemFont(ofSize: 17.0)
        let side = instantPageButtonLabelEmojiSide(font: font)
        let extentBuffer = UnsafeMutablePointer<RunStruct>.allocate(capacity: 1)
        // Descent is negated: CTLine wants a positive distance below the baseline, whereas
        // `font.descender` is negative.
        extentBuffer.initialize(to: RunStruct(ascent: font.ascender, descent: -font.descender, width: side))
        var callbacks = CTRunDelegateCallbacks(version: kCTRunDelegateVersion1, dealloc: { pointer in
            pointer.assumingMemoryBound(to: RunStruct.self).deallocate()
        }, getAscent: { pointer -> CGFloat in
            return pointer.assumingMemoryBound(to: RunStruct.self).pointee.ascent
        }, getDescent: { pointer -> CGFloat in
            return pointer.assumingMemoryBound(to: RunStruct.self).pointee.descent
        }, getWidth: { pointer -> CGFloat in
            return pointer.assumingMemoryBound(to: RunStruct.self).pointee.width
        })
        let delegate = CTRunDelegateCreate(&callbacks, extentBuffer)
        // Replaces the body-text delegate; the old one's buffer is freed by its own dealloc callback.
        // The size attribute rides along for the link path — see this function's note.
        result.addAttributes([
            kCTRunDelegateAttributeName as NSAttributedString.Key: delegate as Any,
            NSAttributedString.Key(rawValue: InstantPageEmojiSizeAttribute): side as NSNumber
        ], range: NSRange(location: index, length: 1))
    }
    return result
}

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

    // MUST run before truncation and before measurement: the ellipsis cut and the returned
    // size/ascent/descent are all computed against the rewritten delegates.
    var effectiveLabel = instantPageButtonLabelWithFittedEmoji(labelString)
    if let maxWidth {
        effectiveLabel = instantPageButtonTruncatedLabel(effectiveLabel, availableWidth: max(0.0, maxWidth - hPad * 2.0))
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

/// True when `string`'s first (respectively last) character carries a pill. Asked of the *rendered*
/// attributed string rather than of the `RichText` tree, so it also holds for a button wrapped in
/// formatting — `bold(textButton(…))` — and for a button reached through nested `concat`s.
func instantPageStringStartsWithInlineButton(_ string: NSAttributedString) -> Bool {
    guard string.length != 0 else {
        return false
    }
    return string.attribute(NSAttributedString.Key(rawValue: InstantPageInlineButtonAttribute), at: 0, effectiveRange: nil) != nil
}

func instantPageStringEndsWithInlineButton(_ string: NSAttributedString) -> Bool {
    guard string.length != 0 else {
        return false
    }
    return string.attribute(NSAttributedString.Key(rawValue: InstantPageInlineButtonAttribute), at: string.length - 1, effectiveRange: nil) != nil
}

/// The gap run inserted between two adjacent pills. The width has to travel on a CTRunDelegate: a
/// plain space would advance by whatever the font says, and this is a tuned pixel amount.
///
/// Reports 0 ascent/descent — like the inline-image path and unlike the pill itself — so it can never
/// grow the line box. Carries no button attribute, so the V2 line-breaker skips it when collecting
/// pending pills.
func instantPageInlineButtonSpacerString(attributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
    struct RunStruct {
        let ascent: CGFloat
        let descent: CGFloat
        let width: CGFloat
    }
    let extentBuffer = UnsafeMutablePointer<RunStruct>.allocate(capacity: 1)
    extentBuffer.initialize(to: RunStruct(ascent: 0.0, descent: 0.0, width: instantPageInlineButtonAdjacentSpacing))
    var callbacks = CTRunDelegateCallbacks(version: kCTRunDelegateVersion1, dealloc: { pointer in
        pointer.assumingMemoryBound(to: RunStruct.self).deallocate()
    }, getAscent: { (pointer) -> CGFloat in
        return pointer.assumingMemoryBound(to: RunStruct.self).pointee.ascent
    }, getDescent: { (pointer) -> CGFloat in
        return pointer.assumingMemoryBound(to: RunStruct.self).pointee.descent
    }, getWidth: { (pointer) -> CGFloat in
        return pointer.assumingMemoryBound(to: RunStruct.self).pointee.width
    })
    let delegate = CTRunDelegateCreate(&callbacks, extentBuffer)
    let result = NSMutableAttributedString(string: " ", attributes: attributes)
    result.addAttribute(kCTRunDelegateAttributeName as NSAttributedString.Key, value: delegate as Any, range: NSMakeRange(0, result.length))
    return result
}

/// Where a pill draws its label, in pill-local coordinates: `x` is the left edge of the label's ink,
/// `y` is its BASELINE.
///
/// Extracted verbatim from `InstantPageV2ButtonPillContentView.draw(_:)` — including the `- 0.33`
/// optical nudge — so that the emoji placement below and the actual drawing cannot drift apart.
/// A pure function of `(attachment, pillSize)`: `updateInlineEmoji()` runs before a freshly created
/// pill's `layoutSubviews`, so its live `bounds` are still zero at that point and must not be read.
func instantPageButtonLabelOrigin(attachment: InstantPageInlineButtonAttachment, pillSize: CGSize) -> CGPoint {
    // Horizontally centre the label: for an inline pill this equals the padding, but a row pill's
    // frame is stretched to an equal column width, so the label must centre within it.
    let labelWidth = attachment.size.width - instantPageInlineButtonHorizontalPadding * 2.0
    let x = max(instantPageInlineButtonHorizontalPadding, (pillSize.width - labelWidth) / 2.0)
    // Vertically: `attachment.ascent` is the baseline's distance from the pill top for an inline
    // pill. A row pill has a fixed taller height, so centre the label's box instead.
    let labelBoxHeight = attachment.ascent + attachment.descent
    let y = (pillSize.height - labelBoxHeight) / 2.0 + attachment.ascent - 0.33
    return CGPoint(x: x, y: y)
}

/// The squares a pill's custom emoji occupy, in pill-local coordinates.
///
/// Each square spans exactly the label font's ascender→descender box — precisely the extent
/// `instantPageButtonLabelWithFittedEmoji` reserved for it — so it always sits inside the pill's
/// padding and is never shaved by the capsule clip.
func instantPageButtonEmojiPlacements(
    attachment: InstantPageInlineButtonAttachment,
    pillSize: CGSize
) -> [(emoji: ChatTextInputTextCustomEmojiAttribute, frame: CGRect)] {
    let labelString = attachment.labelString
    var result: [(emoji: ChatTextInputTextCustomEmojiAttribute, frame: CGRect)] = []
    guard labelString.length != 0 else {
        return result
    }

    var line: CTLine?
    let origin = instantPageButtonLabelOrigin(attachment: attachment, pillSize: pillSize)

    // Character-by-character, matching the rewrite in `instantPageButtonLabelWithFittedEmoji`:
    // `enumerateAttribute` would coalesce two adjacent emoji into a single range.
    for index in 0 ..< labelString.length {
        guard let emoji = labelString.attribute(ChatTextInputAttributes.customEmoji, at: index, effectiveRange: nil) as? ChatTextInputTextCustomEmojiAttribute else {
            continue
        }
        // Built lazily: the overwhelming majority of button labels carry no emoji at all.
        let resolvedLine: CTLine
        if let line {
            resolvedLine = line
        } else {
            resolvedLine = CTLineCreateWithAttributedString(labelString)
            line = resolvedLine
        }

        let font = (labelString.attribute(.font, at: index, effectiveRange: nil) as? UIFont) ?? UIFont.systemFont(ofSize: 17.0)
        let side = instantPageButtonLabelEmojiSide(font: font)
        let xOffset = v2LeadingOffsetForRange(resolvedLine, range: NSRange(location: index, length: 1))
        result.append((
            emoji: emoji,
            frame: CGRect(
                x: origin.x + xOffset,
                y: origin.y - font.ascender,
                width: side,
                height: side
            )
        ))
    }
    return result
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
            fill = theme.neutralButtonBackgroundColor
            label = theme.neutralButtonForegroundColor
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
