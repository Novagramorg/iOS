# Projected-Anchor Inset Transition Design

**Status:** IMPLEMENTED / CURRENT

## Goal

Vertical inset changes preserve the settled anchor's offset relative to the inset edge. Increasing
the top inset by 300 points moves the anchor and its surrounding rows down by exactly 300 points;
decreasing it moves them back by exactly 300 points. A loaded collection edge may clip that motion,
but container parking, virtualization, and animation overlap must not change it.

This design supersedes the earlier absolute-positioned endpoint and membership policy, which remains
available in Git history. It retains the shared-anchor coordinate-rebase witness, presentation-only
overscroll, and one-pass projected-window requirement.

## Root Cause

The absolute-position policy deliberately made every valid inset pass a viewport no-op:

```text
newSettledOffset = oldSettledOffset + anchorCoordinateShift
```

That behavior matches its tests but violates the intended inset invariant. The only visible motion
occurs when the new edge range clamps the candidate, explaining why `-300` still moves at the true
loaded-top minimum while toggles elsewhere do nothing.

Restoring a post-build `-insetDelta` endpoint would make rows move, but window membership would still
be constructed around the old anchor position. That disconnect previously caused projected-window
and carry problems. The target anchor position must be an input to window construction, not a
correction applied after it.

## Anchor-Relative Invariant

For a top inset transition, preserve:

```text
anchorScreenY - topInset
```

Let:

```text
insetDelta = newTopInset - oldTopInset
```

For an ordinary resolved anchor:

```text
projectedAnchorPoint = oldSettledAnchorPoint + insetDelta
```

When the old viewport owns the loaded top, row zero is semantically pinned rather than represented by
an ordinary screen point. Pin row zero directly to the new top-inset edge.

Horizontal insets continue to affect row x and width independently. A bottom-inset or height change
does not translate an unconstrained middle anchor; it participates in bottom-edge clipping when the
last item is reached.

## One-Pass Projected Window

Seed `buildWindow` with the projected anchor point and construct the final window once:

1. Traverse toward lower indices until the upper preload boundary is covered or item zero is reached.
2. If item zero is reached below the permitted top-inset edge, translate the window upward to that
   edge. This clips only the portion of the requested scroll that lies beyond the loaded minimum.
3. Traverse toward higher indices until the lower preload boundary is covered or the last item is
   reached.
4. If the last item is reached above the permitted bottom edge, translate the window downward to that
   edge. This clips only the portion beyond the loaded maximum.
5. If the whole collection is shorter than the usable viewport and both alignments cannot hold, top
   alignment takes precedence.

Traversal, measurement, and view construction remain bounded to the final projected
viewport-plus-preload window and the old/new membership union required for crossing carries. The list
must not build at the old position and retry after discovering the endpoint.

## Settled Endpoint and Animation

After edge alignment, the projected window itself determines the settled engine offset:

```text
newSettledOffset = containerOriginY - newWindow.minY
```

There is no post-build inset-delta adjustment. For any shared anchor:

```text
anchorCoordinateShift = newAnchorContentY - oldAnchorContentY
syntheticOldOffset     = oldBoundsOriginY + anchorCoordinateShift
```

The existing additive viewport transition from `syntheticOldOffset` to `newSettledOffset` then owns
exactly the projected screen displacement. If edge clipping reduces the projected anchor movement,
the additive track contains only the surviving displacement. Container parking cancels through the
coordinate shift and shared rows receive no compensating position tracks.

An overlapping pass samples the analytic current viewport correction and replaces only a genuinely
changed viewport target on the incoming duration and curve, preserving C0 continuity. An explicit
`scrollTo` remains authoritative and bypasses inset projection for its pass.

## Overscroll and Gestures

Rubber-band displacement remains presentation-only:

1. Clamp the old displayed engine offset to the old settled loaded-edge range.
2. Resolve and project the anchor from that settled state.
3. Build and edge-clip the final window.
4. Restore the captured presentation overscroll exactly once after the new settled endpoint is known.

Overscroll cannot influence anchor identity, projected point, membership, or edge ownership. User
dragging continues to update the settled state beneath any additive viewport animation.

## Tests and Runtime Evidence

- Away from an edge clamp, `+300` moves every shared row's settled endpoint down exactly 300 points;
  `-300` returns it exactly.
- At the loaded top, row zero moves from the old inset edge to the new inset edge and window membership
  covers exactly the final viewport-plus-preload band.
- At the loaded bottom, requested motion is clipped only when it would exceed the maximum edge.
- An underfilled collection remains top-aligned when both edge alignments cannot be satisfied.
- Projected membership creates/measures no row outside the old/new required union; crossing carries
  represent only identities that actually cross those endpoint windows.
- Overlapping inset passes and inset changes during programmatic viewport motion are C0-continuous and
  use the incoming transition curve only when the viewport target changes.
- Top and bottom rubber-band displacement is restored exactly once.
- The emitted additive `bounds.origin.y` keyframe matches the analytic viewport track's endpoints,
  duration, curve samples, and generation.
- Launch-argument-gated demo instrumentation on K2 records settled anchor/inset distance, projected
  window indices, analytic viewport correction, and actual CA presentation coordinates. Validation uses
  captured logs/output files, never screenshots or video; temporary instrumentation is removed afterward.
