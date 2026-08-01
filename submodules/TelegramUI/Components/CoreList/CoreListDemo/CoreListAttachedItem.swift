import UIKit

/// Whether an attachment's measured height enters the item flow.
public enum CoreListAttachmentPlacement {
    /// The list reserves the attachment's measured height at its run's edge; rows move to make room.
    case reservesSpace
    /// The attachment overlays its run and has no effect on row geometry.
    case overlay
}

/// Which edge of its run an attachment pins to. Always list-space: a rotated host counter-rotates its
/// own views, exactly as item views already do.
public enum CoreListAttachmentEdge {
    case top
    case bottom
}

/// An item published by a `CoreListItem` that belongs to a RUN of adjacent rows rather than to that
/// row alone — a date header, a section footer, a gutter avatar.
///
/// A run is the maximal span of adjacent items publishing this attachment's key and agreeing under
/// `combines(with:)`. All members of a run must agree on `placement`, `edge` and `isFloating`.
public protocol CoreListAttachedItem: AnyObject {
    var placement: CoreListAttachmentPlacement { get }
    var edge: CoreListAttachmentEdge { get }
    /// When true the attachment is clamped into the inset display area while its run is on screen.
    /// When false it sits rigidly at its band edge and scrolls away with the run.
    var isFloating: Bool { get }

    func view() -> UIView & CoreListAttachedItemView

    /// Content equality for an already-key-matched run representative. The list reconfigures
    /// (`apply(to:transition:)` + remeasure) iff this is false. Compared independently of the row's
    /// own `isEqual`: an avatar whose story ring changed must reconfigure even when the row it
    /// hangs off did not.
    func isEqual(to other: CoreListAttachedItem) -> Bool

    /// Reconfigures a reused attachment view in place. Default: no-op.
    func apply(to view: UIView & CoreListAttachedItemView, transition: CoreListTransition)

    /// Whether two adjacent items' attachments under the same key belong to ONE run. Default `true`.
    ///
    /// This exists because a key cannot express a pairwise rule: `ChatMessageAvatarHeader` folds its
    /// timestamp bucket into its id and STILL needs "break the run if these two are ≥10 minutes
    /// apart", which is a delta between neighbours rather than a bucket.
    func combines(with other: CoreListAttachedItem) -> Bool
}

public extension CoreListAttachedItem {
    func apply(to view: UIView & CoreListAttachedItemView, transition: CoreListTransition) {}
    func combines(with other: CoreListAttachedItem) -> Bool { true }
}

public protocol CoreListAttachedItemView: AnyObject {
    /// Lays the attachment out at `width` and returns its measured height. Same contract as
    /// `CoreListItemView.update(width:transition:)`: non-immediate ONLY when this attachment's own
    /// content was reconciled in the pass.
    func update(width: CGFloat, transition: CoreListTransition) -> CGFloat

    /// Self-update. Marks this attachment dirty and schedules one coalesced flush, exactly as
    /// `CoreListItemView.onContentDidChange` does for a row.
    var onContentDidChange: ((_ animated: Bool) -> Void)? { get set }
}
