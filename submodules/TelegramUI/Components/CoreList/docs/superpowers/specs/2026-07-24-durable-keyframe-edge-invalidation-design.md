# Durable Keyframe Edge Invalidation Design

**Date:** 2026-07-24
**Status:** IMPLEMENTED / CURRENT

## Goal

Ensure a physics-keyframe flight always rebakes when its real scrollable edge changes, including
changes made by `applyChanges` between display-link sampling ticks. The replacement trajectory must
preserve the exact live position and velocity, use the latest edge state, and coalesce multiple
between-tick edge changes into one rebake.

## Root Cause

`PhysicsScrollEngine.setEdges` and `TestScrollEngine.setEdges` correctly call
`KeyframeFlight.noteEdgesChanged()` when `PhysicsScrollCore.setEdges` reports a real minimum or
maximum change.

The flight currently treats that notification as tick-local state. `beginTick(now:)`
unconditionally clears `rebakeNeeded` before reseeding the core. This works when the list changes an
edge from the `onScroll` callback later in the same tick, but loses any notification delivered
between ticks. An external `applyChanges` can therefore change the physics bounds while the render
server continues playing the old baked trajectory. The flight then bounces against an edge that is
no longer authoritative.

## Chosen Model

An edge notification is a persistent trajectory invalidation, not a per-tick note.

- `noteEdgesChanged()` marks the current trajectory invalid.
- `beginTick(now:)` samples the current trajectory's exact live offset and velocity and reseeds the
  core, but does not clear the invalidation.
- The normal `onScroll` callback then performs list rebalancing and may add further edge changes.
- `rebakeIfNeeded(now:)` bakes once from the reseeded core under its latest bounds, splices the new
  future continuously onto the old trajectory, and clears the invalidation only after consuming it.
- Multiple real edge changes before that point coalesce into the same rebake and use the final
  bounds.

This preserves the current next-sampling-tick architecture. It does not synchronously rebake from
`setEdges`, which lacks the engine's authoritative animation-local time and may run re-entrantly
during list rendering.

## Composition Rules

The existing distinction remains unchanged:

- A pure `applyShift` is a coordinate translation. It updates `coordinateShift`, moves the layer
  model, and does not rebake.
- A real minimum or maximum edge change alters trajectory shape and persistently requests a rebake.
- Repeated declarations of identical edges remain no-ops because `PhysicsScrollCore.setEdges`
  reports `false`.
- A pending edge invalidation and any coordinate shifts compose in the existing splice:
  `beginTick` samples in list coordinates, and `rebakeIfNeeded` folds the accumulated shift into the
  replacement trajectory.
- Stepped physics, drag behavior, programmatic scroll-to halting, physics constants, and bounce
  formulas do not change.

## Testing

Testing uses the deterministic `KeyframeFlight`/`TestScrollEngine` path first, then list integration:

1. An edge changed after one tick and before the next `beginTick` must survive that boundary and
   increment the flight generation exactly once.
2. Multiple real edge changes before the next tick must coalesce into one generation increment, and
   the rebaked trajectory must settle against the final edge.
3. A keyframe list flight followed by a structural or geometry mutation that changes a finite edge
   must preserve motion, rebake on the next tick, and settle against the new edge rather than the old
   one.
4. Existing same-tick edge rebakes, pure-shift no-rebake behavior, stepped/keyframe parity, and the
   complete serial K2 suite remain green.

No screenshot or video validation is required. If real-app evidence is needed, the Demo will be
temporarily instrumented and its logs captured.

## Alternatives Rejected

- **Edge revision numbers:** explicit, but would spread flight-consumption state into
  `PhysicsScrollCore` without improving the one-flight/one-pending-invalidation result.
- **Synchronous rebake from `setEdges`:** would require threading local animation time and CA
  re-emission through a re-entrant render call, increasing coupling and continuity risk.
- **Always rebake every tick:** correct but discards the render-server efficiency and reintroduces
  the frequent CA replacement that the current shape-change gate intentionally avoids.
