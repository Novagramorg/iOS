# Composable Viewport Geometry Animation Design

**Status:** IMPLEMENTED / CURRENT

## Goal

Make viewport size and inset changes first-class list transactions. The list receives its own size
and full `UIEdgeInsets`, but never learns or animates its position in its parent. Geometry changes
must compose continuously with one another and with item mutations, programmatic scrolling,
crossing survivors, and departed ghost blocks.

The demo gains a button that toggles the top inset between 0 and 300 points over 0.5 seconds. The
button is a manual probe of the general geometry model, not a special animation path.

## Viewport Geometry

Introduce a value describing the list-owned geometry:

```swift
struct ListViewportGeometry: Equatable {
    var size: CGSize
    var insets: UIEdgeInsets
}
```

`applyChanges` accepts optional size and inset updates and resolves them into one new settled
geometry before diffing and rendering. Existing size-only callers retain their current behavior by
using the current insets. Insets default to zero.

The list's outer bounds remain the visible and interactive area. Insets do not create a smaller
clipping or hit-testing view. Rows may remain visible within inset regions and virtualization still
uses the outer size plus the configured preload margin.

The inset-adjusted content width is
`max(0, size.width - insets.left - insets.right)`. Row x is `insets.left`; width changes remeasure
rows and may consequently change their heights. At the loaded top edge, the first row rests below
the top inset. At the loaded bottom edge, the last row rests above the bottom inset.

## Animation Specification

Replace the duration-only internal transition description with a value containing a logical
duration and an analytic curve. Existing call sites continue to use the current smoothstep curve.
The curve is stored on each `ListAnimationTrack`, sampled by both the model and
`CoreAnimationCompiler`, and preserved by unchanged-track no-ops. A replacement track samples the
old track using its original curve and uses the new pass's curve from that boundary onward.

The demo inset toggle uses a 0.5-second ease-out curve so it is visibly distinct from existing
0.3-second smoothstep actions. Slow Animations scaling remains controller-owned and applies exactly
once.

## Granular Geometry Model

Extend the analytic property set with horizontal position and absolute visual width. A stable live
row can therefore own independent `positionX`, `positionY`, `width`, `height`, and `opacity`
properties. The existing rules continue unchanged for every property:

- Writing an unchanged settled endpoint is an exact no-op that preserves generation, phase,
  deadline, curve, and installed CA animation.
- Writing a changed endpoint replaces only that property from its analytic current presentation,
  guaranteeing C0 continuity across overlapping passes.
- Final settled frames are written immediately with implicit actions disabled.
- The compiler emits additive position animations and absolute size animations. Production motion
  remains CA-keyframe driven; layer presentation state is never animation authority.

Horizontal inset changes update row x and width. Width remeasurement may also produce a new row
height, which transitions independently. Structural loading remains limited to the old/new
viewport-plus-preload union; the geometry pass does not measure extra items.

## Shared Vertical Displacement

A top-inset change adjusts the settled engine offset so all currently visible content moves by the
inset delta, even away from the loaded top edge. The existing model-owned additive viewport track
renders that shared displacement on `engine.contentHost.layer`. Because live rows, crossing carries,
and ghost blocks share that hierarchy, they move rigidly together without duplicate per-identity
tracks.

If a size or inset update arrives while the viewport track is active, the new pass samples the
analytic current viewport correction and replaces the track toward the newly resolved settled
offset. Unrelated item tracks remain exact no-ops. A simultaneous programmatic scroll and geometry
change resolves one final settled offset and emits one viewport replacement, rather than competing
animations.

Bottom inset and height changes update the inset-adjusted bottom edge. Loaded-edge pinning and the
current mutation anchor determine the new settled offset using the same general anchor rules as
other transactions. Rubber-band displacement remains display-only and cannot influence this
settled calculation.

## Structural Composition

Geometry participates in the ordinary `applyChanges` pass:

1. Capture one transaction time, old settled geometry, and analytic property values.
2. Resolve the new size, insets, collection, anchor, and engine endpoint.
3. Reconcile and remeasure only identities in the structural old/new loaded union.
4. Write final engine, container, overlay, and row geometry without implicit actions.
5. Replace only properties whose settled endpoints changed, using the pass animation specification.

Departed ghost blocks continue to use their boundary-witness ledger. Shared vertical viewport motion
needs no witness migration because the entire content hierarchy carries it. Geometry-driven row
changes can still move a ghost's witness; those boundary changes use the same pass duration and
curve. Crossing survivors retain their per-identity endpoint inference and receive horizontal/size
tracks only when their own loaded endpoint is known.

## Demo

Add one inline control to the existing edge-actions row. Its title alternates between
`Inset +300` and `Inset -300`. The first tap applies `top = 300`; the next restores `top = 0`.
Other inset components and the outer list size remain unchanged. Repeated taps while the 0.5-second
transition is active exercise analytic retargeting rather than canceling or snapping the prior
motion.

Changing scroll engines rebuilds the list with the currently selected inset state so the control
and displayed geometry stay consistent.

## Verification

Model tests prove curve sampling, unchanged preservation, and C0 replacement for the new horizontal
and width properties. Compiler parity tests cover additive x and absolute width keyframes with the
track-owned curve.

List tests cover:

- settled top and bottom edge positions under insets;
- visible-row displacement for a top-inset change away from the top edge;
- overlapping top-inset retargets;
- simultaneous and overlapping geometry, insert/delete/move, and programmatic-scroll passes;
- ghost blocks and crossing survivors riding shared viewport displacement;
- left/right inset changes, width remeasurement, and resulting height animation;
- no extra creation or measurement beyond the old/new viewport-plus-preload union;
- parity between immediate and animated final state.

A demo interaction test taps the button twice, verifies the titles and inset endpoints, and confirms
the second tap restores the original geometry. The complete suite and Debug build run on the
dedicated `iPhone 17 Pro K2` simulator with parallel testing disabled.
