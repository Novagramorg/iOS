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

    /// Fires when the user's interactive drag ENDS (the pan gesture reaches `.ended`/`.cancelled`),
    /// whether or not momentum follows — so `onWillBeginDragging`/`onDidEndDragging` bracket exactly the
    /// finger-down interval, and NOT the momentum phase after it. Not fired for programmatic writes, nor
    /// when deceleration or a bounce finishes. The UIKit analogue is
    /// `UIScrollViewDelegate.scrollViewDidEndDragging(_:willDecelerate:)`.
    var onDidEndDragging: (() -> Void)? { get set }

    /// Programmatic absolute write (the old `setBoundsOriginY` + the fast-flick delta clamp).
    func setOffset(_ y: CGFloat)

    /// Stop any deceleration/momentum, leaving the content exactly where it is PRESENTED. Idempotent, and
    /// never fires `onScroll`.
    ///
    /// This exists so a caller never has to write `setOffset(offset)` to halt. Under a `.keyframe` flight
    /// that idiom is a trap: `offset` is per-frame stable, the call internally catches the flight at its
    /// true instantaneous position, and then the stale argument overwrites it — so the halt lands on the
    /// last sampling tick's position instead of the current one. See
    /// docs/superpowers/specs/2026-07-26-clock-free-mutation-pass-design.md.
    func haltMotionInPlace()

    /// Re-anchor the reported `offset` on what the render server is currently presenting, without disturbing
    /// any animation. Call once at the top of a mutation pass so the pass reads a CURRENT position: `offset`
    /// is per-frame stable by contract, which makes it stale by however long the main thread has been busy
    /// since the last sampling tick. Continuity does not require currency (a single consistent value cancels
    /// algebraically), but membership, the anchor witness and the overscroll gate all do. No-op for an engine
    /// whose offset is already the presented value.
    func syncToPresentedPosition()

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
