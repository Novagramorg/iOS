import Foundation
import UIKit
import TelegramCore

/// Geometry for a block-level `pageBlockButtonRow`.
///
/// Split out of `InstantPageV2Layout`'s `.buttonRow` arm because the packing is this block's real
/// complexity and `layoutBlock` is already a ~600-line switch. The arm keeps the typography — it owns
/// the file-private style-stack helpers — and hands the measured label strings down here.

/// Fixed rather than label-derived: this is a touch target. The pill centres its label, so the inner
/// vertical inset is (height − labelBox) / 2 — raising the height by 4 adds 2pt top and bottom.
let instantPageBlockButtonHeight: CGFloat = 40.0

/// Used both between pills within a row and between rows.
let instantPageBlockButtonSpacing: CGFloat = 6.0

/// The schema's own cap.
let instantPageBlockButtonsPerRow: Int = 8

/// Room a badge-bearing pill must keep clear on EACH side beyond the ordinary horizontal padding, so
/// that a centred label cannot run under the top-right type badge. `instantPageInlineButtonAttachment`
/// already adds `instantPageInlineButtonHorizontalPadding` per side, so only the difference is added
/// on top of the measured attachment. Buttons without a badge reserve nothing.
private func instantPageBlockButtonExtraSideInset(for button: InstantPageButton) -> CGFloat {
    guard instantPageBlockButtonIconName(for: button.action) != nil else {
        return 0.0
    }
    return max(0.0, instantPageBlockButtonIconReserve - instantPageInlineButtonHorizontalPadding)
}

/// Where a row's content starts within the available width, given its leftover space.
///
/// One rule, applied to every mode: **a row lays out in the page's reading direction**. `align_left`
/// therefore means *leading* — the right edge on an RTL page — and `align_right` means trailing.
/// `center` is unaffected by direction, and `justify` has no slack to distribute.
private func instantPageBlockButtonRowSlackOffset(alignment: InstantPageButtonRowAlignment, slack: CGFloat, rtl: Bool) -> CGFloat {
    switch alignment {
    case .justify:
        return 0.0
    case .left:
        return rtl ? slack : 0.0
    case .center:
        return slack / 2.0
    case .right:
        return rtl ? 0.0 : slack
    }
}

/// Lays out one `pageBlockButtonRow`. Entries come back in **model order** (the view maps entry *i*
/// onto pill *i* and reuses pills positionally); reading direction lives in the frames.
///
/// Unlike .audio/media, which are flush at the full `boundingWidth`, a button row is chrome and
/// respects the page's horizontal inset.
func instantPageV2LayoutButtonRow(
    labelledButtons: [(button: InstantPageButton, labelString: NSAttributedString)],
    alignment: InstantPageButtonRowAlignment,
    boundingWidth: CGFloat,
    horizontalInset: CGFloat,
    rtl: Bool,
    metrics: InstantPageMetrics
) -> (entries: [(attachment: InstantPageInlineButtonAttachment, frame: CGRect)], totalHeight: CGFloat) {
    let availableWidth = boundingWidth - horizontalInset * 2.0
    guard !labelledButtons.isEmpty, availableWidth > 0.0 else {
        return ([], 0.0)
    }

    switch alignment {
    case .justify:
        return instantPageV2LayoutJustifiedButtonRow(
            labelledButtons: labelledButtons,
            availableWidth: availableWidth,
            horizontalInset: horizontalInset,
            rtl: rtl,
            metrics: metrics
        )
    case .left, .center, .right:
        return instantPageV2LayoutHuggingButtonRow(
            labelledButtons: labelledButtons,
            alignment: alignment,
            availableWidth: availableWidth,
            horizontalInset: horizontalInset,
            rtl: rtl,
            metrics: metrics
        )
    }
}

/// Equal columns filling the width, wrapping at a fixed 8 per row — the behaviour every row had
/// before the alignment bits were honoured, unchanged apart from the reading-direction ordering.
private func instantPageV2LayoutJustifiedButtonRow(
    labelledButtons: [(button: InstantPageButton, labelString: NSAttributedString)],
    availableWidth: CGFloat,
    horizontalInset: CGFloat,
    rtl: Bool,
    metrics: InstantPageMetrics
) -> (entries: [(attachment: InstantPageInlineButtonAttachment, frame: CGRect)], totalHeight: CGFloat) {
    var entries: [(attachment: InstantPageInlineButtonAttachment, frame: CGRect)] = []
    var y: CGFloat = 0.0
    var index = 0
    while index < labelledButtons.count {
        let rowButtons = Array(labelledButtons[index ..< min(index + instantPageBlockButtonsPerRow, labelledButtons.count)])
        let totalSpacing = metrics.blockButtonSpacing * CGFloat(max(0, rowButtons.count - 1))
        let buttonWidth = max(0.0, (availableWidth - totalSpacing) / CGFloat(rowButtons.count))
        for (position, entry) in rowButtons.enumerated() {
            // Cap the label at the column it will be stretched to. The pill centres its label, so the
            // reserve is taken off BOTH sides — otherwise a long label, centred, would run under the
            // top-right type badge.
            //
            // Deliberately kept as the shipped `columnWidth − 2·iconReserve` rather than the hug
            // path's tighter formula: `instantPageInlineButtonAttachment` subtracts 2·hPad again
            // internally, so this is ~14pt more conservative, and matching it would move where
            // ellipses appear on already-published pages.
            let iconReserve = instantPageBlockButtonIconName(for: entry.button.action) != nil ? instantPageBlockButtonIconReserve * 2.0 : 0.0
            let attachment = instantPageInlineButtonAttachment(button: entry.button, labelString: entry.labelString, maxWidth: max(0.0, buttonWidth - iconReserve))
            let column = rtl ? (rowButtons.count - 1 - position) : position
            let x = horizontalInset + CGFloat(column) * (buttonWidth + metrics.blockButtonSpacing)
            entries.append((attachment, CGRect(x: x, y: y, width: buttonWidth, height: metrics.blockButtonHeight)))
        }
        y += metrics.blockButtonHeight + metrics.blockButtonSpacing
        index += instantPageBlockButtonsPerRow
    }
    return (entries, max(0.0, y - metrics.blockButtonSpacing))
}

/// Left / centre / right: every pill hugs its label, rows fill greedily, and each row is placed at its
/// own origin (a short last row re-aligns on itself).
private func instantPageV2LayoutHuggingButtonRow(
    labelledButtons: [(button: InstantPageButton, labelString: NSAttributedString)],
    alignment: InstantPageButtonRowAlignment,
    availableWidth: CGFloat,
    horizontalInset: CGFloat,
    rtl: Bool,
    metrics: InstantPageMetrics
) -> (entries: [(attachment: InstantPageInlineButtonAttachment, frame: CGRect)], totalHeight: CGFloat) {
    // Pass 1 — measure each pill at its natural width, capped so that even the longest label fits
    // `availableWidth` on its own (the attachment builder ellipsises past the cap). Pass 2 depends on
    // that: a row can then never overflow, and an over-long single label truncates instead.
    let measured: [(attachment: InstantPageInlineButtonAttachment, width: CGFloat)] = labelledButtons.map { entry in
        let extra = instantPageBlockButtonExtraSideInset(for: entry.button)
        let attachment = instantPageInlineButtonAttachment(
            button: entry.button,
            labelString: entry.labelString,
            maxWidth: max(0.0, availableWidth - extra * 2.0)
        )
        return (attachment, min(availableWidth, attachment.size.width + extra * 2.0))
    }

    // Pass 2a — greedy packing, still capped at the schema's 8 per row.
    var rows: [[Int]] = []
    var currentRow: [Int] = []
    var currentWidth: CGFloat = 0.0
    for index in 0 ..< measured.count {
        let width = measured[index].width
        if !currentRow.isEmpty {
            let projected = currentWidth + metrics.blockButtonSpacing + width
            if projected > availableWidth || currentRow.count >= instantPageBlockButtonsPerRow {
                rows.append(currentRow)
                currentRow = []
                currentWidth = 0.0
            }
        }
        currentWidth = currentRow.isEmpty ? width : currentWidth + metrics.blockButtonSpacing + width
        currentRow.append(index)
    }
    if !currentRow.isEmpty {
        rows.append(currentRow)
    }

    // Pass 2b — place each row at its own origin.
    var frames = [CGRect](repeating: .zero, count: measured.count)
    var y: CGFloat = 0.0
    for row in rows {
        let rowWidth = row.reduce(0.0) { $0 + measured[$1].width } + metrics.blockButtonSpacing * CGFloat(max(0, row.count - 1))
        let slack = max(0.0, availableWidth - rowWidth)
        var x = horizontalInset + instantPageBlockButtonRowSlackOffset(alignment: alignment, slack: slack, rtl: rtl)
        // The first button sits at the reading start, so on an RTL page the pills run right-to-left.
        let visualOrder = rtl ? Array(row.reversed()) : row
        for index in visualOrder {
            frames[index] = CGRect(x: x, y: y, width: measured[index].width, height: metrics.blockButtonHeight)
            x += measured[index].width + metrics.blockButtonSpacing
        }
        y += metrics.blockButtonHeight + metrics.blockButtonSpacing
    }

    // Indexed rather than `enumerated().map { (offset, item) in … }`: Swift rejects destructuring a
    // tuple in a closure parameter list.
    let entries = (0 ..< measured.count).map { index in
        return (attachment: measured[index].attachment, frame: frames[index])
    }
    return (entries, max(0.0, y - metrics.blockButtonSpacing))
}
