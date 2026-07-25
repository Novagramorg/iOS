import CoreGraphics
import Foundation // log

/// One axis of UIScrollView's scroll state machine. See analysis doc §1–§6.
/// `velocity` is points/millisecond. Pixel-rounded offsets are returned by `step`;
/// the internal `offset` stays full-precision across frames (matching the integrator).
struct ScrollAxis {
    enum Decision { case decelerate, stop }
    enum Phase { case idle, dragging, decelerating }

    // Config
    private(set) var min: CGFloat
    private(set) var max: CGFloat
    let range: CGFloat
    let rate: CGFloat
    let lnRate: CGFloat
    let scale: CGFloat
    let vScale: CGFloat
    let c: CGFloat

    // State
    private(set) var offset: CGFloat
    private(set) var velocity: CGFloat = 0
    private var prevVelocity: CGFloat = 0
    private var dragStartOffset: CGFloat = 0
    private(set) var phase: Phase = .idle

    init(offset: CGFloat, min: CGFloat, max: CGFloat, range: CGFloat,
         rate: CGFloat, scale: CGFloat, vScale: CGFloat = 1, c: CGFloat = RubberBand.touchCoefficient) {
        self.offset = offset
        self.min = min; self.max = max; self.range = range
        self.rate = rate; self.lnRate = log(rate)
        self.scale = scale; self.vScale = vScale; self.c = c
    }

    mutating func beginDrag() {
        dragStartOffset = offset
        velocity = 0
        prevVelocity = 0
        phase = .dragging
    }

    /// `translation`/`recognizerVelocity` are the pan recognizer's values (points, points/sec).
    mutating func drag(translation: CGFloat, recognizerVelocity: CGFloat) {
        let proposed = dragStartOffset - translation                       // §3
        offset = RubberBand.offset(proposed, min: min, max: max, range: range, c: c) // §1
        prevVelocity = velocity
        velocity = -recognizerVelocity * 0.001                              // §3: pts/s → pts/ms, negated
    }

    mutating func endDrag() -> Decision {
        // §4 low-pass. Empirically confirmed by Plan 2's recorded-fixture regression: UIScrollView
        // weights the PREVIOUS drag-frame velocity 0.75 and the latest 0.25. (The medium-flick
        // fixture's deceleration distance matches 0.75·prev + 0.25·latest to ~1px, vs a ~23px
        // undershoot when reversed.) Resolves the ambiguity in the decoded _endPanNormal: swaps.
        velocity = 0.75 * prevVelocity + 0.25 * velocity
        // Released while overscrolled (past an edge) → must spring back even with no flick velocity,
        // matching `_endPanNormal` starting the decel timer when bouncing. Without this, a tap or tiny
        // drag during a bounce ends as `.stop` and the content freezes off the edge.
        if offset < min || offset > max {
            phase = .decelerating
            return .decelerate
        }
        if velocity * velocity < 0.0625 {                                   // §4 threshold (|v| < 0.25)
            velocity = 0
            phase = .idle
            return .stop
        }
        phase = .decelerating
        return .decelerate
    }

    /// Advance one deceleration frame; returns the pixel-rounded offset to write and whether settled.
    /// Call only after `endDrag()` has returned `.decelerate`.
    mutating func step(dtMs: CGFloat) -> (written: CGFloat, settled: Bool) {
        // Deceleration is a single-frame value type; reconstruct it each frame from the live
        // full-precision offset/velocity. Do NOT hoist it into stored state — that would discard
        // the inter-frame precision the integrator depends on.
        var d = Deceleration(offset: offset, velocity: velocity, min: min, max: max,
                             rate: rate, vScale: vScale)
        let settled = d.step(dtMs: dtMs)
        offset = d.offset                                                   // keep full precision
        velocity = d.velocity
        if settled { phase = .idle }
        return (OffsetMath.pixelRound(offset, scale: scale), settled)       // §6 write rounds
    }

    /// Move the bounce points without disturbing any dynamic state (offset/velocity/phase/
    /// dragStartOffset/prevVelocity). The analogue of a UIScrollView `contentSize` change — lets a
    /// scroll engine declare a freshly-loaded edge mid-interaction. Changes no physics formula.
    /// `range` (the viewport dimension, not the content span) is intentionally left unchanged.
    mutating func setBounds(min: CGFloat, max: CGFloat) {
        self.min = min
        self.max = max
    }

    /// Rigidly re-base the axis: the offset AND the in-progress drag anchor move together, so a
    /// rebalance reposition mid-drag/mid-decel composes (the next `drag()` recomputes from the
    /// shifted anchor, and a decel continues from the shifted offset with velocity untouched). The
    /// analogue of a UIScrollView `bounds.origin.y` shift.
    mutating func shift(by dy: CGFloat) {
        offset += dy
        dragStartOffset += dy
    }

    /// Re-anchor a deceleration at an explicit offset/velocity under the current edges. The analogue
    /// of catching an in-flight decel and relaunching from the live sample — the keyframe rebake's
    /// substrate. `velocity` is the integrator's unit (pts/ms). Sets phase to `.decelerating`; the
    /// next `step` continues from here. Changes no physics formula. Sets only the `step`/`build`
    /// substate (offset/velocity/phase) — it does NOT update `dragStartOffset`, so a caller must go
    /// straight into `step`/`build` and never follow a reseed with `drag()`/`endDrag()`.
    mutating func reseedDeceleration(offset: CGFloat, velocity: CGFloat) {
        self.offset = offset
        self.velocity = velocity
        self.prevVelocity = velocity
        self.phase = .decelerating
    }

    func projectedTarget() -> CGFloat {
        Projection.target(offset: offset, velocity: velocity, lnRate: lnRate, vScale: vScale)
    }
}

/// Two-axis UIScrollView physics. Each axis is independent.
struct ScrollPhysics {
    var x: ScrollAxis
    var y: ScrollAxis

    mutating func beginDrag() { x.beginDrag(); y.beginDrag() }

    mutating func endDrag() -> (x: ScrollAxis.Decision, y: ScrollAxis.Decision) {
        (x.endDrag(), y.endDrag())
    }

    mutating func drag(translation: CGPoint, recognizerVelocity: CGPoint) {
        x.drag(translation: translation.x, recognizerVelocity: recognizerVelocity.x)
        y.drag(translation: translation.y, recognizerVelocity: recognizerVelocity.y)
    }

    /// Returns the offset to write and whether BOTH axes have settled.
    mutating func step(dtMs: CGFloat) -> (written: CGPoint, settled: Bool) {
        let rx = x.step(dtMs: dtMs)
        let ry = y.step(dtMs: dtMs)
        return (CGPoint(x: rx.written, y: ry.written), rx.settled && ry.settled)
    }
}
