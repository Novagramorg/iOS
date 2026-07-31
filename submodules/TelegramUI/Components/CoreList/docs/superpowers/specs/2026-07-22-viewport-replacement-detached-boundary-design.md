# Viewport Replacement Detached-Boundary Design

**Status:** IMPLEMENTED / CURRENT

**Implementation record:** regression `9c31058`; centralized boundary mapper `10716db`. The focused
K2 suite passed 118/118. Runtime traces at duration factors 1 and 10 reduced the former approximately
300-point detached-carry discontinuity to ordinary intended between-frame motion; destination analytic
and presentation coordinates agreed within render-clock noise after the replacement transaction committed.

## Goal

Every replacement of the additive viewport track preserves the screen-space position of existing
detached content at the transaction boundary. This includes outgoing carousel strips, crossing
survivors, and ghost blocks during overlapping programmatic scroll, inset, size, and combined
geometry transitions.

## Reproduction and Root Cause

The deterministic K2 sequence is:

1. Start the Demo at the loaded top.
2. Tap **Jump to 40**, which creates a non-overlapping carousel and an outgoing detached strip.
3. After 0.1 seconds, toggle the 300-point top inset.

Launch-argument-gated instrumentation sampled analytic and presentation-layer coordinates. Immediately
before the inset pass, destination row 40 differed by only 0.064 points between the analytic model and
the presentation layer. The first outgoing carousel row was at -207.35 points. On the first committed
frame after the inset replacement, that carry appeared at -565.46 points: its intended continuing
motion plus an erroneous coordinate jump of approximately the 300-point inset delta.

The destination window is rebuilt in projected coordinates. Its rows therefore receive the new
300-point content-coordinate base while the shared additive viewport correction is retargeted into
the same base. Existing detached content remains in the old content-coordinate base. The geometry
branch updates its viewport generation but, unlike the overlap-scroll and carousel branches, does not
apply the existing detached-content boundary mapping before replacing the viewport track.

## General Invariant

Replacing the viewport property changes the relationship between settled content coordinates and the
rendered viewport. Any content detached from the newly rendered live window must be remapped at the
same boundary.

For every changed, positive-duration viewport replacement:

```text
oldRenderedViewport = oldEngineOffset + currentViewportCorrection
newRenderedViewport = newEngineOffset + replacementViewportFrom
engineShift          = newEngineOffset - oldEngineOffset
detachedShift        = newRenderedViewport - oldRenderedViewport - engineShift
```

Before the replacement animation is installed, every child of the crossing and exit overlays moves by
`detachedShift`. Crossing-carry settled coordinates and ghost-ledger roots move by the same amount.
The existing overlay shift primitive already performs these updates atomically with implicit actions
disabled.

This is not an inset rule. It is a viewport-replacement rule. For a projected top-inset change away
from clipping, `detachedShift` resolves to the anchor coordinate shift (300 points in the repro). For
an overlap or carousel retarget it resolves to the existing boundary mapping. Engine rebases are
subtracted exactly once.

An unchanged or immediate viewport mutation does not create a detached remap. Existing no-op,
generation, and cleanup behavior remains unchanged.

## Implementation Shape

Centralize viewport replacement behind one CoreVirtualListView helper. The helper:

1. receives the old/new settled offsets, old/new rendered viewport values, applied engine shift,
   animation specification, transaction clock, and completion;
2. applies the detached boundary mapping when a changed positive-duration transition requires it;
3. invokes `ListAnimationController.transitionViewport`;
4. returns the mutation so each caller can retain its existing carry-generation and immediate-cleanup
   behavior.

The overlapping-scroll, carousel-scroll, and geometry branches all use this helper. This removes the
current possibility that one viewport-producing path replaces the additive track without remapping
detached content.

The animation model, compiler, viewport curve, duration, projected-window construction, and item
property transitions do not change. `UIViewPropertyAnimator` and presentation-state authority are not
introduced.

## Testing and Runtime Verification

Add a deterministic regression using the existing synthetic list driver:

- create a disjoint Jump-to-40 carousel;
- advance 0.1 seconds;
- capture every existing viewport carry's screen Y;
- apply a 300-point top inset with positive duration;
- assert each carry has the same screen Y at the transaction boundary;
- assert a destination live row is also continuous;
- assert the viewport replacement uses the incoming ease-out curve and duration;
- assert the original carry views remain owned by the replacement generation and clean up when it
  completes.

Retain existing overlap-scroll, carousel, geometry, ghost, and crossing-carry suites as compatibility
coverage. Run focused tests and then the complete K2 suite with parallel testing disabled.

Finally rerun the temporary Demo trace at normal and Slow Animations factors. The outgoing carry's
boundary discontinuity must fall from approximately 300 points to render-clock noise. Remove all
temporary launch arguments, display-link sampling, and trace logging before committing production code.
No screenshots or video are used.
