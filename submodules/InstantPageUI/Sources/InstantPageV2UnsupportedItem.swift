import Foundation
import UIKit
import TelegramCore
import UnsupportedContentPill

/// A laid-out "this build cannot render this content" card, standing in for one or more
/// `InstantPageBlock.unsupported` blocks.
public struct InstantPageV2UnsupportedItem {
    public var frame: CGRect
    public let layout: UnsupportedContentPillLayout
    /// Carried on the item because the view is built later, from the item alone — the layout pass
    /// is the last place with access to the page's `PresentationStrings`.
    public let strings: UnsupportedContentPillStrings
    /// This pill stands for a block that is a direct child of the page, not one nested in a
    /// container.
    ///
    /// It has to be recorded here because it cannot be recovered from the finished layout. A
    /// blockquote (and a list) lays its children out with `layoutBlock` and appends the resulting
    /// items straight into its PARENT's item array, offset — so a nested pill is indistinguishable
    /// from a top-level one by position in `items` alone. Only the layout pass still knows the
    /// difference.
    public let isTopLevel: Bool
}

/// Indices of the `.unsupported` blocks that directly follow another one, so a maximal run renders
/// as a single pill with a single set of block gaps.
///
/// Returns indices to SKIP rather than a filtered array on purpose: `layoutBlockSequence` feeds its
/// loop index into `pathPrefix + [i]`, which is the structural path checkbox toggling and anchors
/// address blocks by. Filtering the array would renumber every block after a collapsed run and
/// silently toggle the wrong checkbox.
///
/// Applied in every block sequence — including nested ones (details bodies, table cells, quotes) —
/// so the rule holds everywhere rather than only at the top level.
func redundantUnsupportedBlockIndices(_ blocks: [InstantPageBlock]) -> Set<Int> {
    var result: Set<Int> = []
    var previousWasUnsupported = false
    for (index, block) in blocks.enumerated() {
        if case .unsupported = block {
            if previousWasUnsupported {
                result.insert(index)
            }
            previousWasUnsupported = true
        } else {
            previousWasUnsupported = false
        }
    }
    return result
}

/// Lays out one pill, inset horizontally like a paragraph and stretched to the content width.
func layoutUnsupportedBlock(
    boundingWidth: CGFloat,
    horizontalInset: CGFloat,
    strings: UnsupportedContentPillStrings,
    colors: UnsupportedContentPillColors,
    isTopLevel: Bool
) -> [InstantPageV2LaidOutItem] {
    let contentWidth = max(1.0, boundingWidth - horizontalInset * 2.0)
    let pillLayout = UnsupportedContentPill.layout(strings: strings, colors: colors, constrainedWidth: contentWidth)
    let frame = CGRect(x: horizontalInset, y: 0.0, width: contentWidth, height: pillLayout.size.height)
    return [.unsupportedContent(InstantPageV2UnsupportedItem(frame: frame, layout: pillLayout, strings: strings, isTopLevel: isTopLevel))]
}

/// Page-space rects a host may cut out of whatever it draws behind the page, one per pill.
///
/// Top level only, deliberately: a pill nested inside a `<details>` body, a blockquote or a table
/// cell is not full-width relative to the host's background, so tearing across it would cut a band
/// through unrelated content.
///
/// The `isTopLevel` filter is what enforces that, NOT the non-recursive walk. A blockquote appends
/// its children's items into its parent's array, so a quoted pill sits in `layout.items` looking
/// exactly like a top-level one. Not recursing merely keeps the walk cheap — it excludes only the
/// containers that build a sub-layout of their own (`details`, table cells).
///
/// Only the vertical extent is meaningful to the caller — the horizontal extent of a tear is the
/// host's business, since only the host knows how wide its background is — but the pill's own
/// horizontal box is returned unchanged rather than zeroed, so the value stays a rect that means
/// something on its own.
public func unsupportedContentTearZones(in layout: InstantPageV2Layout) -> [CGRect] {
    /// Vertical breathing room added above and below a pill when a host tears its background across it.
    /// Without it the bubble's cut edges land exactly on the pill's box and the two touch.
    let instantPageUnsupportedTearPadding: CGFloat = 6.0
    
    var result: [CGRect] = []
    for item in layout.items {
        if case let .unsupportedContent(unsupported) = item, unsupported.isTopLevel {
            result.append(unsupported.frame.insetBy(dx: 0.0, dy: -instantPageUnsupportedTearPadding))
        }
    }
    return result
}
