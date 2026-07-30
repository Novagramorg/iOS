# Normalized Carousel Adjacency Design

**Status:** IMPLEMENTED / CURRENT

## Goal

A non-overlapping programmatic scroll places the incoming loaded window immediately beside the
outgoing loaded window at the animation boundary. Forward travel places the incoming loaded top at
the outgoing loaded bottom. Backward travel places the incoming loaded bottom at the outgoing loaded
top. Insets, preload margins, window parking, and nonzero window-local origins must not introduce
overlap or empty space.

This refines the carousel geometry in `docs/plans/2026-07-20-additive-viewport-scroll-design.md`.
It does not change overlap-scroll geometry or the detached-boundary remapping introduced by
`2026-07-22-viewport-replacement-detached-boundary-design.md`.

## Reproduction and Root Cause

The deterministic K2 sequence is:

1. Launch the Demo at the loaded top.
2. Toggle the top inset to 300 points and let the transition settle.
3. Tap **Jump to 40**.

Presentation-layer instrumentation recorded:

```text
old loaded strip       300 ... 825
outgoing carry strip   300 ... 825
incoming loaded strip  300 ... 1350
row 40 initial top     525
```

The incoming and outgoing strips overlap by exactly 525 points, the complete outgoing-window
height. Because the exit overlay is above the live container, the outgoing rows cover the incoming
rows until viewport-generation cleanup removes them at the animation deadline.

`render()` normalizes each item frame into its loaded-window container:

```text
localItemY = item.frame.minY - window.minY
```

Therefore the rendered top of the loaded strip is independent of `window.minY`:

```text
loadedTop = containerOriginY - renderedViewport
```

The carousel branch currently calculates:

```text
containerOriginY - window.minY - renderedViewport
```

It subtracts `window.minY` a second time after render normalization. Both carousel inputs are
therefore expressed in a fictional coordinate base. Existing assertions prove only that the mapped
outgoing top remains at that fictional old top; they never assert adjacency to the incoming strip.

## Normalized Loaded-Strip Geometry

Define the actual old and new loaded-strip tops:

```text
oldLoadedTop = oldContainerOriginY
             - (oldEngineOffset + currentViewportCorrection)

newLoadedTop = newContainerOriginY
             - newEngineOffset
```

Use these values with the existing carousel formula.

For forward travel:

```text
viewportFrom = newLoadedTop - (oldLoadedTop + oldWindowHeight)
```

At the initial boundary:

```text
incomingInitialTop = newLoadedTop - viewportFrom
                   = oldLoadedTop + oldWindowHeight
                   = outgoingInitialBottom
```

For backward travel:

```text
viewportFrom = newLoadedTop + newWindowHeight - oldLoadedTop
```

At the initial boundary:

```text
incomingInitialBottom = newLoadedTop - viewportFrom + newWindowHeight
                      = oldLoadedTop
                      = outgoingInitialTop
```

The full loaded strips, including their endpoint preload rows, are adjacent. There is no separate
visible-viewport rule and no inset-specific correction. Since outgoing and incoming content share the
same additive viewport animation after this placement, their zero separation remains rigid throughout
the transition.

## Integration

Only the two top-coordinate inputs in the non-overlapping carousel branch change. The existing:

- direction selection;
- `ViewportTransitionGeometry.carouselViewportFrom` formula;
- synthetic old settled offset;
- centralized detached-boundary remapping;
- transient carry creation and ownership;
- one additive `bounds.origin.y` keyframe;
- virtualization and endpoint-window membership;
- generation-safe cleanup;

remain unchanged.

Update the debug assertion to check the complete invariant, not only outgoing-top preservation. It
must assert forward incoming-top/outgoing-bottom equality or backward incoming-bottom/outgoing-top
equality at the initial boundary.

## Tests and Runtime Verification

Add deterministic integration coverage with a nonzero 300-point top inset:

- forward Jump-to-40 starts the incoming loaded top exactly at the outgoing loaded bottom;
- backward Top starts the incoming loaded bottom exactly at the outgoing loaded top;
- both cases use windows with nonzero `minY`, proving render normalization is respected;
- the separation remains zero at intermediate analytic samples because both strips ride the same
  viewport property;
- carries retain the replacement generation and clean up at the deadline;
- no intermediate logical rows are instantiated or measured.

Run the focused programmatic-scroll, viewport-geometry, inset-geometry, crossing, and ghost suites,
then the complete K2 suite with parallel testing disabled.

Finally rerun the temporary Demo trace at normal and Slow Animations factors. It must report zero
loaded-strip overlap/gap at the initial boundary and throughout the animation. Remove all temporary
launch arguments, display-link sampling, and logs before committing shipping code. Do not use
screenshots or video.

## Implementation Record

Implemented on 2026-07-22. Regression commit `2eb3543` locks forward and backward normalized strip
adjacency with a 300-point top inset. Fix commit `3a09c1c` removes the duplicate `Window.minY`
subtraction and strengthens the debug-only invariant for both directions.

K2 runtime instrumentation confirmed `gap=0.000` on every committed frame at the normal duration
factor and at factor 10 after the inset had fully settled. The same zero-gap result also held when the
slow inset transition was still active at the jump boundary. The synchronous post-mutation sample was
intentionally excluded because Core Animation had not committed its new presentation tree; the analytic
transaction-boundary equality is covered by the deterministic integration tests. All trace-only launch
arguments, display-link sampling, duration overrides, and logging were then removed.
