import UIKit

/// Shared seam glue between a `ScrollEngine` wrapper and the reverse-engineered `ScrollPhysics` core.
/// Owns the physics and writes the scroll position onto a content host's `bounds.origin.y` (mirroring
/// how a `UIScrollView`'s bounds IS its content offset), so `CoreVirtualListView`'s layout math is
/// unchanged. `PhysicsScrollEngine` (real pan + display link) and `TestScrollEngine` (synthetic clock)
/// both wrap one of these, so the deterministic tests exercise the SHIPPING integration glue.
///
/// `.stepped` deceleration only. An open edge (`nil`) maps to a far sentinel so the existing
/// rubber-band/deceleration math sees "no reachable bound" → free travel; the list re-declares edges
/// after every rebalance, so the sentinel is always refreshed before it could be reached.
final class PhysicsScrollCore {
    let contentHost: UIView

    /// Fired on USER-driven motion (drag/step). Programmatic `setOffset`/`applyShift` never fire it —
    /// there is no UIScrollView delegate to re-enter, so suppression is just "don't call the sink".
    var onScroll: ((CGFloat) -> Void)?

    /// Distance used for an open edge: far enough that a single deceleration can never reach it before
    /// the next rebalance refreshes it. Applied as ±offset from the current position, so open bounds
    /// float with the content — the clampless analogue of the UIScrollView adapter's 10M canvas size.
    static let sentinelDistance: CGFloat = 10_000_000

    private var scale: CGFloat
    /// Rubber-band coefficient used by the NEXT `makePhysics`. Default is touch's 0.55; the owning
    /// engine sets it to `RubberBand.trackpadCoefficient` (0.715) for an indirect (trackpad) gesture so
    /// overscroll is looser — the one real physics difference for trackpad (see the 2026-05-25 work).
    /// Refreshed per gesture from the recognizer's per-gesture `isIndirectScroll`, so it never leaks.
    private var coefficient: CGFloat = RubberBand.touchCoefficient
    private var physics: ScrollPhysics
    private var minEdge: CGFloat?
    private var maxEdge: CGFloat?

    init(contentHost: UIView, scale: CGFloat = 1) {
        self.contentHost = contentHost
        self.scale = Swift.max(scale, 1)
        physics = ScrollPhysics(
            x: ScrollAxis(offset: 0, min: 0, max: 0,
                          range: Swift.max(1, contentHost.bounds.width), rate: 0.998, scale: self.scale),
            y: ScrollAxis(offset: 0, min: -PhysicsScrollCore.sentinelDistance, max: PhysicsScrollCore.sentinelDistance,
                          range: Swift.max(1, contentHost.bounds.height), rate: 0.998, scale: self.scale))
    }

    var offset: CGFloat { contentHost.bounds.origin.y }
    var isDecelerating: Bool { physics.y.phase == .decelerating }
    var hasFiniteEdge: Bool { minEdge != nil || maxEdge != nil }

    /// Set the pixel-rounding scale used by the NEXT `makePhysics` (i.e. the next `beginDrag`/resume/
    /// reseed). The owning engine refreshes this from the host's real display scale before a gesture so
    /// the deceleration rounds to DEVICE PIXELS, not whole points — whole-point rounding makes the
    /// end-of-decel `.discrete` staircase snap visibly. Default stays 1 for the deterministic tests.
    func updateScale(_ newScale: CGFloat) { scale = Swift.max(newScale, 1) }

    /// Set the rubber-band coefficient used by the NEXT `makePhysics`. Mirrors `updateScale`: the engine
    /// refreshes it at gesture start from `PhysicsPanGestureRecognizer.isIndirectScroll`. Default 0.55
    /// keeps the deterministic tests touch-faithful.
    func updateRubberBandCoefficient(_ c: CGFloat) { coefficient = c }

    var isOverscrolled: Bool {
        let o = physics.y.offset
        if let lo = minEdge, o < lo { return true }
        if let hi = maxEdge, o > hi { return true }
        return false
    }

    // MARK: - Programmatic (never fires onScroll)

    func setOffset(_ y: CGFloat) {
        physics.y.shift(by: y - physics.y.offset)
        writeOffset(fireScroll: false)
    }

    func applyShift(_ dy: CGFloat) {
        physics.y.shift(by: dy)
        writeOffset(fireScroll: false)
    }

    /// Shift the physics offset by `dy` WITHOUT writing the content host's `bounds.origin.y`. Used by a
    /// keyframe flight, which owns the layer model: it slides `bounds.origin.y` itself so the in-flight
    /// additive animation rides along, and must NOT have the model clobbered to the physics offset (which
    /// tracks the live position, not the animation's `finalOffset` base). Keeps the physics in list
    /// coordinates so a same-tick edge rebake / finalize bakes from the right state.
    func applyShiftPhysicsOnly(_ dy: CGFloat) {
        physics.y.shift(by: dy)
        refreshBounds()
    }

    /// Returns whether the edges actually changed. The list re-declares edges on every changed
    /// rebalance (often the same `nil`/`nil` during free travel); a keyframe flight only needs to
    /// rebake on a REAL edge change, so the caller gates `noteEdgesChanged` on this (avoids a
    /// redundant off-cadence re-emit — see the splice/stutter fix).
    @discardableResult
    func setEdges(min: CGFloat?, max: CGFloat?) -> Bool {
        let changed = (minEdge != min) || (maxEdge != max)
        minEdge = min
        maxEdge = max
        refreshBounds()
        return changed
    }

    /// Where to park a loaded window of height `h` on the physics path. The core is clampless (open
    /// sides get room via the far sentinel), so it parks in a natural small coordinate rather than a
    /// 10M canvas: top-loaded glues to 0, bottom-only glues the bottom just below 0, neither centres on
    /// 0. The wrapping engines (`PhysicsScrollEngine`, `TestScrollEngine`) delegate here.
    func containerOrigin(windowHeight h: CGFloat, topLoaded: Bool, bottomLoaded: Bool) -> CGFloat {
        if topLoaded { return 0 }
        if bottomLoaded { return -h }
        return -h / 2
    }

    // MARK: - User-driven (fires onScroll)

    func beginDrag() {
        // Rebuild at the current offset/viewport (mirrors PhysicsScrollView.makePhysics): a fresh drag
        // captures the current viewport for the rubber-band range and a clean dynamic state.
        physics = makePhysics(offset: physics.y.offset)
        physics.beginDrag()
    }

    /// `translation`/`velocity` are the pan recognizer's vertical values (points, points/sec).
    func drag(translation: CGFloat, velocity: CGFloat) {
        physics.drag(translation: CGPoint(x: 0, y: translation),
                     recognizerVelocity: CGPoint(x: 0, y: velocity))
        writeOffset(fireScroll: true)
    }

    /// Returns true if the release should decelerate/spring (the caller starts its stepping driver).
    @discardableResult
    func endDrag() -> Bool {
        let d = physics.endDrag()
        return d.x == .decelerate || d.y == .decelerate
    }

    /// Advance one deceleration frame. Returns true once settled (the caller stops its driver).
    @discardableResult
    func step(dtMs: CGFloat) -> Bool {
        let settled = physics.step(dtMs: dtMs).settled
        writeOffset(fireScroll: true)
        return settled
    }

    /// Resume a spring-back if the content was left overscrolled by a bare touch (no drag). Mirrors
    /// PhysicsScrollView.startBounceBackIfNeeded. Returns true if it is now decelerating.
    @discardableResult
    func resumeBounceIfOverscrolled() -> Bool {
        guard isOverscrolled else { return false }
        physics = makePhysics(offset: physics.y.offset)
        physics.beginDrag()
        _ = physics.endDrag()           // overscrolled ⇒ .decelerate (spring back)
        return physics.y.phase == .decelerating
    }


    /// Cancel an in-flight deceleration WITHOUT moving the content (the analogue of catching a moving
    /// UIScrollView on touch-down). Rebuilds the axis at the current offset so `phase` returns to
    /// `.idle` and `isDecelerating` correctly reports false, while the content is held where it caught.
    /// Edges (`minEdge`/`maxEdge`) are preserved by `makePhysics`. Does not fire `onScroll`.
    func cancelDeceleration() {
        physics = makePhysics(offset: physics.y.offset)
    }

    // MARK: - Keyframe deceleration (increment 4a)

    /// Bake the current y-axis decel state into a `Trajectory`. Call after `endDrag()` returned
    /// `.decelerate`, or after `reseedDeceleration` — both leave the axis `.decelerating`.
    func bakeTrajectory() -> Trajectory { Trajectory.build(from: physics.y) }

    /// Re-anchor the y-axis deceleration at a live (offset, velocity) under the current edges, then
    /// refresh the open-edge sentinel relative to the new offset. The keyframe rebake's substrate.
    func reseedDeceleration(offset: CGFloat, velocity: CGFloat) {
        physics.y.reseedDeceleration(offset: offset, velocity: velocity)
        refreshBounds()
    }

    // MARK: - Internals

    private func makePhysics(offset: CGFloat) -> ScrollPhysics {
        let lo = minEdge ?? (offset - PhysicsScrollCore.sentinelDistance)
        let hi = maxEdge ?? (offset + PhysicsScrollCore.sentinelDistance)
        return ScrollPhysics(
            x: ScrollAxis(offset: 0, min: 0, max: 0,
                          range: Swift.max(1, contentHost.bounds.width), rate: 0.998, scale: scale, c: coefficient),
            y: ScrollAxis(offset: offset, min: lo, max: hi,
                          range: Swift.max(1, contentHost.bounds.height), rate: 0.998, scale: scale, c: coefficient))
    }

    /// Re-point the y-axis bounds: a finite edge stays put; an open edge re-centres on the current
    /// offset so a coasting flight can never reach it before the next rebalance.
    private func refreshBounds() {
        let o = physics.y.offset
        let lo = minEdge ?? (o - PhysicsScrollCore.sentinelDistance)
        let hi = maxEdge ?? (o + PhysicsScrollCore.sentinelDistance)
        physics.y.setBounds(min: lo, max: hi)
    }

    private func writeOffset(fireScroll: Bool) {
        contentHost.bounds.origin.y = physics.y.offset
        refreshBounds()
        if fireScroll { onScroll?(physics.y.offset) }
    }
}
