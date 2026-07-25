# Carousel-Exclusive Row Motion Design

**Date:** 2026-07-22
**Status:** IMPLEMENTED / CURRENT

## Goal

Keep every non-overlapping programmatic-scroll carousel rigid when the same `applyChanges` pass also
changes viewport geometry or list structure. The outgoing and incoming loaded strips must remain internally
contiguous throughout the animation, with the additive viewport track owning their shared travel.

## Runtime Evidence

Launch-argument-gated Demo instrumentation reproduced `V+300 + Jump40` on the dedicated K2 simulator.
The pass correctly chose destination rows 37–49 and retained ten outgoing carousel rows, but it also
installed a live `positionY` track on every destination row.

At the animation boundary, adjacent destination offsets differed by about -75 points, collapsing most
neighbors onto one another, while rows 39 and 40 had an approximately 884-point discontinuity. Halfway
through, the same discontinuity was still about 411 points. At settlement all row tracks ended, adjacency
returned to zero error, and the correct endpoint appeared. Temporary instrumentation was removed after the
log capture.

## Root Cause

`CoreVirtualListView.applyChanges` classifies any inset, size, or structural mutation as a settled-membership
transition. Destination-only identities from the existing collection are then sent through the incoming
crossing-survivor planner.

That rule is valid when membership changes around one settled viewport. It is not valid after the same pass
has selected a non-overlapping carousel. The carousel has already mapped the complete outgoing strip next to
the complete destination strip and installed one additive viewport track. Incoming crossing tracks give the
destination rows a second, independently inferred motion and therefore destroy strip rigidity until those
tracks settle.

## Invariant

Once a pass resolves as `isCarouselScroll`, programmatic travel is the exclusive owner of vertical motion for
destination-only survivors:

- destination-only identities that already existed in the collection receive no incoming crossing-survivor
  `positionY` track;
- the destination window is rendered at its final internal layout and rides only the additive viewport track;
- outgoing loaded survivors remain viewport carries and form the other rigid strip;
- genuine inserts retain their independent opacity animation;
- exact shared live endpoints do not exist in carousel mode, so no structural residual position can be
  inferred losslessly for an unloaded destination survivor;
- horizontal position, width, height, ghost, and viewport properties keep their existing independent rules.

This is a mode invariant, not an inset special case. It applies equally to carousel passes combined with size,
inset, content, insertion, removal, replacement, or move inputs.

## Implementation

Exclude carousel passes from the incoming crossing-survivor membership set. Leave overlap-mode scrolling and
ordinary non-scroll membership transitions unchanged. No new animation property, planner mode, or Demo-only
branch is introduced.

The existing viewport carry path already excludes outgoing carousel survivors from crossing carries, maps
them into the carousel coordinate base, and releases them with the viewport generation. The fix makes the
destination side follow the same single-owner model.

## Testing

Add a direct list regression for one far `newInsets + scrollTo` transaction:

1. establish non-overlapping source and destination windows;
2. assert a viewport carousel track and outgoing carries exist;
3. assert every destination-only existing identity has no live `positionY` track;
4. sample the analytic animation at multiple phases and assert consecutive destination rows remain exactly
   contiguous;
5. assert the outgoing and incoming strip boundary remains adjacent;
6. assert the requested inset and target row endpoint are correct at settlement.

Retain the existing mixed structural carousel, inset-carousel adjacency, overlap-scroll, crossing-carry, and
full K2 suites as regression coverage. Demo verification uses temporary logs/output only, never screenshots or
video.

## Non-Goals

- Animating a best-effort structural residual for a survivor that was unloaded at the source endpoint.
- Changing overlap-scroll coordinate mapping.
- Changing crossing carries for non-scroll geometry or structural passes.
- Adding a special path for the `V+300 + Jump40` button.

## Implementation Record

The deterministic regression landed in `c37f6fe` after failing on K2 with non-nil destination-row position
tracks and sampled adjacency errors. The minimal eligibility fix landed in `86edb93`: carousel passes now
exclude destination-only survivors from incoming crossing inference, without changing the viewport, overlap,
ghost, opacity, or extent paths.

Focused K2 verification executed 131 tests across `ProgrammaticScrollAnimationTests`,
`CoreVirtualListAnimationTests`, and `DemoInteractionTests`, with zero failures. Complete K2 verification
executed 417 tests with zero failures. XcodeBuildMCP then built, installed, and launched
`org.telegram.CoreListDemo` on the dedicated iPhone 17 Pro K2 simulator and captured its runtime logs.
