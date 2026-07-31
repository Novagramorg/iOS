# Finite-Edge Shift and Terminal Keyframe Re-bake Design

**Date:** 2026-07-24
**Status:** IMPLEMENTED / CURRENT

## Goal

Ensure any change to a flight's geometry relative to a finite scroll edge supersedes the old
physics-keyframe future, including an engine offset shift that leaves the finite edge fixed and an
edge invalidation that arrives near the old trajectory's completion. Once newly loaded content
changes the distance to an edge, the scroller must not continue or finalize the obsolete bounce.
The replacement must preserve the current analytic position and velocity whenever motion remains.

## Root Cause

The existing engine treats every `applyShift` during a keyframe flight as a pure coordinate
translation: it shifts the core offset, layer model, and baked trajectory together without
rebaking. That classification is exact only while both edges are open. If a minimum or maximum is
finite, the edge coordinate stays fixed while the offset shifts, so the trajectory's distance to
that edge changes.

At top Auto Load, the projected window still declares `minEdge == 0`, so `setEdges` sees no numeric
change. Preserving the existing anchor then shifts the engine by the inserted block height. The
old baked top bounce is translated by that amount even though the real minimum remains zero, and
no invalidation is raised. The render server therefore follows the previous loaded edge after the
new rows appear.

The existing durable invalidation also preserves `noteEdgesChanged()` across sampling-tick
boundaries but not across flight completion. Both keyframe engines check the old trajectory's
deadline before calling `beginTick` and `rebakeIfNeeded`. Production also installs a CA completion
that finalizes independently of the sampler. Once a finite-edge shift correctly raises an
invalidation, either terminal path could still discard it near the old deadline.

The earlier regression changes an edge immediately after launching a flight. It does not exercise
an edge change near the old bounce deadline, so both terminal races remain uncovered.

## Chosen Model

A shift is translation-only when both scroll edges are open. If either edge is finite, shifting the
offset while the edge stays fixed changes trajectory shape and raises the same durable edge
invalidation as a real `setEdges` change. Any pending invalidation outranks every completion path
belonging to the invalidated trajectory.

- `KeyframeFlight` exposes whether an edge re-bake is pending.
- A real edge change still updates `PhysicsScrollCore` immediately and marks the flight invalid.
- `PhysicsScrollCore` exposes whether either authoritative edge is finite.
- `applyShift` continues to accumulate the exact coordinate translation, but it also marks the
  flight invalid whenever either edge is finite. The existing splice composes the accumulated
  translation with the replacement future.
- In `PhysicsScrollEngine`, that transition also invalidates the currently installed CA completion
  generation. The obsolete completion becomes inert while the sampling link remains alive.
- A sampling tick may finalize an old trajectory only when no edge re-bake is pending.
- Otherwise the tick reseeds the core from the current analytic position and velocity, lets normal
  list rebalancing contribute any further edge changes, and consumes all pending edge changes in
  one splice against the latest bounds.
- `TestScrollEngine` uses the same pending-before-completion ordering.
- If the replacement trajectory has no remaining duration, the engine settles it normally rather
  than installing a degenerate CA animation.

The invariant is:

> An active flight may finalize only when its currently installed trajectory is authoritative for
> the latest declared edges.

## Data Flow

1. A list mutation extends or contracts the loaded content.
2. `CoreVirtualListView.render()` declares the new finite/open edges.
3. Anchor preservation calls `applyShift` with the settled offset delta.
4. The physics core reports that a finite edge remains authoritative, so the engine accumulates the
   translation and marks the active flight invalid.
5. The engine invalidates the old CA completion token immediately; no synchronous re-bake occurs
   inside list rendering.
6. On the next sampling tick, pending invalidation bypasses old-trajectory finalization.
7. `beginTick(now:)` samples the old trajectory at the engine's animation-local time and reseeds
   the core under the latest bounds.
8. The normal `onScroll` callback may rebase the list or declare further edges.
9. `rebakeIfNeeded(now:)` coalesces the final edge state and accumulated shift into one continuous
   splice.
10. The engine installs the replacement keyframe, or settles if no motion remains.

## Scope and Composition

The change is general to every real minimum or maximum edge change during an active keyframe
flight. It is not specific to Auto Load, response delays, list direction, or top/bottom loading.

Coordinate shifts with two open edges remain translation-only and do not invalidate completion.
Repeated identical edge declarations remain no-ops. Stepped physics, drag behavior, programmatic
scroll-to, physics constants, bounce formulas, list edge observation, and controller loading policy
do not change.

## Testing

Testing is deterministic and does not use sleeps, screenshots, or video.

1. Start a keyframe flight toward a finite edge, then apply an anchor-preserving shift while the
   finite edge remains numerically unchanged.
2. Verify the shift requests one re-bake and the replacement settles against the authoritative
   finite edge instead of the translated old bounce endpoint.
3. Repeat with the shift delivered across the old trajectory deadline and verify pending
   invalidation is consumed before terminal finalization.
4. Verify a shift with two open edges remains translation-only.
5. Verify multiple terminal edge changes still coalesce into one re-bake.
6. Retain existing between-tick durability, position/velocity continuity, stepped/keyframe parity,
   list integration, and full serial K2 coverage.

Temporary Demo instrumentation may log edge declarations, flight generations, completion attempts,
and re-bake consumption if real-runtime evidence is needed. It must be removed before commit.

## Alternatives Rejected

- **Synchronous re-bake from `setEdges`:** reacts immediately but couples list rendering to
  animation-local time and CA replacement during a potentially re-entrant render call.
- **Finish the old flight and launch a new one:** creates an artificial stop and cannot preserve
  velocity.
- **Ignore only the sampler's completion check:** leaves the independent CA completion race.
- **Invalidate only the CA completion:** leaves the sampler free to finalize the obsolete deadline
  before consuming the pending edge change.
- **Special-case Auto Load or prepends:** hides the physics invariant and misses bottom loading,
  removals, geometry changes, and any other finite-edge shift.
- **Treat every shift as a shape change:** correct but needlessly re-emits keyframes during ordinary
  open-edge virtualization, recreating the frequent replacement path that pure translations avoid.
