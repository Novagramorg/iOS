import UIKit

/// The injected-time rebake orchestrator for a keyframe deceleration over a `PhysicsScrollCore`.
/// Shared by `PhysicsScrollEngine` (real layer-local time + CA playback) and `TestScrollEngine`
/// (`SyntheticClock`, no CA), so both run the SAME logic. Holds the live `Trajectory`, its `startTime`
/// (caller's time base), a `generation` (stale-completion guard), and the persistent `coordinateShift`.
/// No UIKit drawing, no `CADisplayLink`, no CA — the engines own those.
/// See docs/plans/2026-05-26-keyframe-list-deceleration-design.md §3.
final class KeyframeFlight {
    private let core: PhysicsScrollCore
    private(set) var trajectory: Trajectory
    private(set) var startTime: TimeInterval
    /// Bumped once per REBAKE within THIS flight (so a rebaked CA animation's stale completion is
    /// guarded). Cross-flight staleness (launch/catch) is the ENGINE's responsibility — a fresh flight
    /// instance resets this to 0, so an engine must NOT use it as a whole-lifecycle guard on its own.
    private(set) var generation: Int = 0

    /// Accumulated coordinate translation: (list coordinate) − (trajectory coordinate) since the
    /// trajectory was last baked. PERSISTS across ticks. A pure coordinate shift (container re-base)
    /// is a rigid translation of the decel path — it changes no SHAPE — so it does NOT rebake/re-emit:
    /// `noteShift` just accumulates here, and the engine slides the layer model by the same `dy` so the
    /// already-playing additive animation rides along. (Re-emitting the animation on every shift — which
    /// happens every frame at scroll speed — was the residual scroll jank.) Only an edge/shape change
    /// rebakes; the splice then folds this into the new trajectory's coordinate and resets it to 0.
    private var coordinateShift: CGFloat = 0
    /// A real edge change invalidates the baked future until a rebake consumes it. This is deliberately
    /// not tick-local: `applyChanges` can call `setEdges` between sampling ticks, and the next
    /// `beginTick` must preserve that notification while it reseeds the live state.
    private var edgeRebakePending = false
    var hasPendingEdgeRebake: Bool { edgeRebakePending }

    init(core: PhysicsScrollCore, startTime: TimeInterval) {
        self.core = core
        self.startTime = startTime
        // bakeTrajectory → Trajectory.build requires a `.decelerating` axis (post-endDrag). The caller
        // (engine) must construct a flight only after endDrag returned .decelerate.
        assert(core.isDecelerating, "KeyframeFlight must be built from a core in .decelerating state")
        self.trajectory = core.bakeTrajectory()
    }

    var duration: TimeInterval { trajectory.duration }
    func isComplete(now: TimeInterval) -> Bool { now - startTime >= trajectory.duration }

    /// Live scroll offset (LIST coordinate) at `now` — the trajectory sample re-based by every shift
    /// accumulated since the last bake.
    func liveOffset(now: TimeInterval) -> CGFloat { trajectory.offset(at: now - startTime) + coordinateShift }
    /// Velocity is shift-invariant — a rigid re-base moves position only (ScrollAxis.shift leaves
    /// velocity untouched), so this does NOT add `coordinateShift` (unlike `liveOffset`).
    func liveVelocity(now: TimeInterval) -> CGFloat { trajectory.velocity(at: now - startTime) }
    /// Where the flight comes to rest, in the CURRENT (list) coordinate.
    var settledOffset: CGFloat { trajectory.finalOffset + coordinateShift }

    /// Start of a sampling tick: re-anchor the core's decel state at the live LIST-coordinate sample (so
    /// a subsequent `applyShift`/`setEdges` composes on it). Does NOT reset `coordinateShift` or a
    /// pending edge invalidation — both persist until an edge-change rebake folds them in.
    func beginTick(now: TimeInterval) {
        core.reseedDeceleration(offset: liveOffset(now: now), velocity: liveVelocity(now: now))
    }

    /// The list re-based the coordinate this tick (container repositioned). A pure rigid translation —
    /// the decel SHAPE is unchanged — so this does NOT request a rebake. The engine slides the layer
    /// model by the same `dy`; the in-flight additive animation keeps playing, just translated.
    func noteShift(_ dy: CGFloat) { coordinateShift += dy }

    /// The list changed a bounce edge this tick. The decel SHAPE changes (a bounce appears/disappears),
    /// so this DOES request a rebake/re-emit. The engine calls it alongside `core.setEdges(...)`.
    func noteEdgesChanged() { edgeRebakePending = true }

    /// After `onScroll`/rebalance: if an edge changed, rebake+splice (a pure shift does not get here —
    /// it rode the model translation). Returns true if rebaked (the engine then re-emits the CA animation
    /// from `trajectory` at `startTime`). The core already reflects the live LIST-coordinate state
    /// (beginTick) plus the shift/edges the list applied this tick.
    @discardableResult
    func rebakeIfNeeded(now: TimeInterval) -> Bool {
        guard edgeRebakePending else { return false }
        // The per-tick protocol requires beginTick(now:) to have reseeded the core this tick (which
        // sets phase = .decelerating), so bakeTrajectory's precondition holds. Tripwire if miswired.
        assert(core.isDecelerating, "rebakeIfNeeded requires beginTick to have reseeded the core this tick")
        let future = core.bakeTrajectory()                    // from the re-based / re-edged live state
        let spliced = Trajectory.spliced(current: trajectory, prevBeginTime: startTime, now: now,
                                         future: future, shift: coordinateShift)
        trajectory = spliced.trajectory
        startTime = spliced.beginTime
        coordinateShift = 0                                   // folded into the new trajectory's coordinate
        edgeRebakePending = false
        generation &+= 1
        return true
    }
}
