import UIKit

/// The seam between `CoreVirtualListView` (virtualization/layout/animation) and the scroll
/// engine that provides the scroll position + physics (drag, momentum, rubber-band, bounce).
/// Physics-semantic on purpose: an offset, programmatic writes, edges, and a per-frame
/// user-scroll callback — NOT `UIScrollView`'s `bounds`/`contentSize` vocabulary. The first
/// implementation (`UIKitScrollEngine`) wraps `UIScrollView`; a later one drives `ScrollPhysics`.
protocol ScrollEngine: AnyObject {
    /// Current scroll position in the engine's offset coordinate.
    var offset: CGFloat { get }

    /// Fires ONLY on user-driven scroll (drag/momentum/bounce). The programmatic writes below
    /// never re-enter this — the adapter absorbs the old `CoreVirtualListView.isUpdating` guard.
    var onScroll: ((_ offset: CGFloat) -> Void)? { get set }

    /// Fires when the user STARTS an interactive drag (the pan gesture reaches `.began`). Not fired for
    /// programmatic writes or momentum/bounce. The UIKit analogue is
    /// `UIScrollViewDelegate.scrollViewWillBeginDragging`.
    var onWillBeginDragging: (() -> Void)? { get set }

    /// Programmatic absolute write (the old `setBoundsOriginY` + the fast-flick delta clamp).
    func setOffset(_ y: CGFloat)

    /// Programmatic relative shift — the rebalance reposition (the old `bounds.origin.y += shift`).
    func applyShift(_ dy: CGFloat)

    /// Declares the scrollable extent as edges; either may be open (`nil` = unbounded / no
    /// bounce on that side). Replaces `contentSize`. Offsets are in the engine's coordinate.
    func setEdges(min: CGFloat?, max: CGFloat?)

    /// Where the list parents `container` and exit snapshots. Snapshots must NOT ride container
    /// repositioning, so they sit here (above the container), as today.
    var contentHost: UIView { get }

    /// The container origin (in the engine's offset coordinate) at which to park a loaded window of
    /// `windowHeight`, given which edges are loaded. The engine parks the strip so any OPEN side has
    /// room to scroll into: the `UIScrollView` adapter parks far from its [0, contentSize] clamp; the
    /// clampless physics core parks in a natural small coordinate. Top-loaded ⇒ 0 in every engine.
    func containerOrigin(windowHeight: CGFloat, topLoaded: Bool, bottomLoaded: Bool) -> CGFloat
}
