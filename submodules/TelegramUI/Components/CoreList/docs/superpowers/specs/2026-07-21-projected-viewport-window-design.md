# Projected Viewport Window Design

**Status:** IMPLEMENTED / CURRENT

## Goal

Construct every transaction's settled loaded window directly in projected viewport coordinates so
container parking cannot change virtualization membership. Fix the top-inset removal case where the
builder accepts a raw anchored strip that becomes too short after top-edge normalization.

## Root Cause

`buildWindow` currently fills the fixed raw-coordinate band
`-preloadMargin ... logicalSize.height + preloadMargin`. With a 300-point anchor offset it can accept
`300...825`; top-loaded rendering then subtracts `window.minY` and presents only `0...525`. The
builder and the settled window therefore validate different coordinate ranges. A later user scroll
runs `rebalanceActiveWindow`, notices the missing bottom coverage, and loads the absent rows.

Runtime tracing under the Physics keyframe engine reproduced the mismatch:

- final viewport-plus-preload interval: `-200...760`;
- raw candidate accepted by the builder: `300...825`;
- settled presented content after top parking: `0...525`.

## Model

Window membership is defined only by the new settled viewport projection. The target load band is:

```text
-preloadMargin ... viewportHeight + preloadMargin
```

The builder resolves the anchor's final projected screen position under the new size, insets,
scroll target, and anchor policy. It then measures and places rows outward from that anchor until
their projected frames cover the target band.

Container origin and engine offset are not inputs to membership. They are chosen only after the
projected window is complete and form a coordinate rebase that must preserve every projected frame.

## One-Pass Edge Resolution

The builder does not iterate toward a parking fixpoint.

1. Seed the anchor at its resolved projected viewport position.
2. Extend upward and downward until the projected strip covers the target load band or reaches an
   item-collection edge.
3. If an edge is loaded, apply its settled alignment constraint once:
   - top loaded: the first row begins at `topInset`;
   - bottom loaded: the last row ends at `viewportHeight - bottomInset`;
   - both loaded with short content: top alignment wins.
4. Extend only the opposite side if that one translation exposes an uncovered part of the target
   band.
5. Convert the completed projected frames into the engine/container coordinate representation.

This is a bounded outward traversal. Each newly loaded row is measured once; no unavailable row is
loaded merely to estimate a transform.

## Composition

The projected new window remains the settled endpoint used by the existing old/new identity union.
Rows crossing viewport-plus-preload membership continue through the per-identity crossing-carry
model. Existing additive viewport and per-property tracks are unchanged. Parking, rebasing, and
engine selection must not alter membership or presentation endpoints.

Pure user scrolling uses the same projected load-band definition in `rebalanceActiveWindow`. Shared
helpers should express projected coverage and edge alignment so transaction construction and scroll
rebalance cannot diverge.

## Demo Default and Diagnostics

The Virtual List demo defaults to `PhysicsScrollEngine` with keyframe deceleration selected. The
UIScrollView and stepped physics engines remain selectable.

Temporary launch-argument instrumentation reproduces `+300` followed by `-300` and logs the old
window, projected new window, settled offset, and target load band. It is removed after the automated
regression and instrumented run prove complete initial coverage without a user scroll.

## Tests

- Demo interaction test: Physics keyframe is the default engine and selected segment.
- Deterministic physics-list regression at the loaded top: `+300` then `-300` immediately produces a
  settled window covering the complete viewport-plus-preload band.
- Assert the required newly exposed bottom identities are loaded in the `-300` transaction, before
  any user-scroll callback.
- Assert the transaction does not construct or measure identities beyond the projected load band.
- Preserve existing top/bottom edge, scroll-to, crossing-carry, mixed geometry, and engine parity
  suites.
