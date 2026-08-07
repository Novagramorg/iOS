import Foundation
import UIKit
import TelegramCore

enum BlockSequenceKind {
    case topLevel
    case detail
    case cell
    case list
}

/// Per-block-type contribution to the vertical rhythm of a block sequence.
///
/// `verticalPadding` is symmetric: it is added on BOTH sides of the block, on top of the base gap
/// (`instantPageBaseBlockSpacing`). The flush flags suppress a gap entirely on that side — the base
/// AND both neighbours' padding — for blocks that must butt against what precedes or follows them.
///
/// The flags are directional because every structural zero in this layout is one-sided: a cover is
/// flush against the page above it but takes a real gap below, before its title; related articles
/// are flush below but not above. `.anchor` is the one block that sets both, being an invisible
/// zero-height marker.
struct InstantPageBlockSpacing {
    var verticalPadding: CGFloat = 4.0
    var flushAbove: Bool = false
    var flushBelow: Bool = false
}

/// The gap between any two adjacent blocks, before either block's padding is added.
let instantPageBaseBlockSpacing: CGFloat = 8.0

extension InstantPageBlock {
    /// Resolved from the whole block value, not just its case, so a rule may depend on the payload
    /// (e.g. a checklist reading differently from a bullet list) without widening the model.
    ///
    /// Deliberately NOT exhaustive: every unnamed case takes the defaults, which are a genuine
    /// correct value rather than a silently-wrong one. Naming all thirty-odd cases to return the
    /// same literal would bury the four that carry meaning.
    var spacing: InstantPageBlockSpacing {
        switch self {
        case .anchor:
            // A zero-height invisible marker: transparent to spacing on both sides. The padding is
            // pinned to 0 rather than left at the default — it is unreachable while both flush flags
            // are set, but a default 8.0 here reads as "an anchor has padding" and would come alive
            // the moment a flag is dropped or a new read forgets to check flush first.
            return InstantPageBlockSpacing(verticalPadding: 0.0, flushAbove: true, flushBelow: true)
        case .cover, .channelBanner:
            // Page-header elements: they butt against the top of the page, while their successor
            // (the title) takes a normal gap.
            return InstantPageBlockSpacing(flushAbove: true)
        case .relatedArticles:
            // A full-bleed footer section: flush against whatever follows it.
            return InstantPageBlockSpacing(flushBelow: true)
        case .heading:
            return InstantPageBlockSpacing(verticalPadding: 8.0)
        case .divider:
            return InstantPageBlockSpacing(verticalPadding: 4.0)
        case let .image(_, caption, _, _, _), let .video(_, caption, _, _, _), let .document(_, caption), let .audio(_, caption), let .slideshow(_, caption), let .collage(_, caption), let .map(_, _, _, _, caption):
            if caption.credit != .empty && caption.credit != .plain("") {
                return InstantPageBlockSpacing(flushAbove: true, flushBelow: false)
            } else {
                return InstantPageBlockSpacing(flushAbove: true, flushBelow: true)
            }
        default:
            return InstantPageBlockSpacing()
        }
    }
}

/// The vertical gap between two adjacent blocks, or at a sequence edge when one side is nil.
///
/// Three rules, in order: a flush side wins and yields 0; two `.paragraph` (body) blocks have no gap
/// at all, neither the base nor either block's padding; otherwise the gap is
/// `upper.verticalPadding + instantPageBaseBlockSpacing + lower.verticalPadding`. At an edge only the
/// one present block contributes — the base is strictly a *between two blocks* quantity.
///
/// `kind` is currently unread. It is kept because container-specific spacing (denser table cells,
/// tighter list sub-blocks) is expected to return; do not delete it as dead, and do not read its
/// absence from the body as a bug.
func spacingBetweenBlocks(upper: InstantPageBlock?, lower: InstantPageBlock?, kind: BlockSequenceKind) -> CGFloat {
    if let upper, let lower {
        var upperSpacing = upper.spacing
        let lowerSpacing = lower.spacing
        
        var upperIsRawMedia = false
        switch upper {
        case let .image(_, caption, _, _, _), let .video(_, caption, _, _, _), let .document(_, caption), let .audio(_, caption), let .slideshow(_, caption), let .collage(_, caption), let .map(_, _, _, _, caption):
            if caption.credit != .empty && caption.credit != .plain("") {
                upperSpacing.verticalPadding += 2.0
            } else {
                switch upper {
                case .image, .video, .slideshow, .collage, .map:
                    upperIsRawMedia = true
                default:
                    break
                }
            }
            break
        default:
            break
        }
        
        var lowerIsRawMedia = false
        switch lower {
        case let .image(_, caption, _, _, _), let .video(_, caption, _, _, _), let .document(_, caption), let .audio(_, caption), let .slideshow(_, caption), let .collage(_, caption), let .map(_, _, _, _, caption):
            if caption.credit != .empty && caption.credit != .plain("") {
            } else {
                switch lower {
                case .image, .video, .slideshow, .collage, .map:
                    lowerIsRawMedia = true
                default:
                    break
                }
            }
            break
        default:
            break
        }
        
        if upperIsRawMedia && lowerIsRawMedia {
            return 1.0
        }
        
        if case .list = kind {
            return upperSpacing.verticalPadding + lowerSpacing.verticalPadding
        } else {
            if case .list = upper, case .list = lower {
                return upperSpacing.verticalPadding + lowerSpacing.verticalPadding
            }
            switch upper {
            case .heading:
                switch lower {
                case .heading:
                    return upperSpacing.verticalPadding
                case .paragraph, .thinking, .list:
                    return upperSpacing.verticalPadding + lowerSpacing.verticalPadding
                default:
                    break
                }
            default:
                break
            }
            switch upper {
            case .paragraph:
                switch lower {
                case .heading:
                    return upperSpacing.verticalPadding + instantPageBaseBlockSpacing + lowerSpacing.verticalPadding
                case .paragraph:
                    return 1.0
                default:
                    if lowerIsRawMedia {
                        return max(1.0, upperSpacing.verticalPadding + lowerSpacing.verticalPadding + 1.0)
                    }
                }
            default:
                break
            }
            switch lower {
            case .paragraph, .thinking, .list:
                if upperIsRawMedia {
                    return max(1.0, upperSpacing.verticalPadding + lowerSpacing.verticalPadding + 1.0)
                }
            default:
                break
            }
        }
        if case .details = upper {
            if case .details = lower {
                return upperSpacing.verticalPadding + lowerSpacing.verticalPadding
            }
            return upperSpacing.verticalPadding + 4.0 + lowerSpacing.verticalPadding
        }
        return upperSpacing.verticalPadding + instantPageBaseBlockSpacing + lowerSpacing.verticalPadding
    } else if let lower {
        let lowerSpacing = lower.spacing
        switch lower {
        case .paragraph, .thinking:
            return lowerSpacing.verticalPadding + 2.0
        default:
            break
        }
        return lowerSpacing.flushAbove ? 0.0 : lowerSpacing.verticalPadding
    } else if let upper {
        let upperSpacing = upper.spacing
        switch upper {
        case .paragraph, .thinking:
            return upperSpacing.verticalPadding + 2.0
        default:
            break
        }
        switch upper {
        case let .image(_, caption, _, _, _), let .video(_, caption, _, _, _), let .slideshow(_, caption), let .collage(_, caption), let .document(_, caption), let .audio(_, caption):
            if caption.credit != .empty && caption.credit != .plain("") {
                return upperSpacing.verticalPadding + 2.0
            }
            break
        default:
            break
        }
        return upperSpacing.flushBelow ? 0.0 : upperSpacing.verticalPadding
    } else {
        return 0.0
    }
}
