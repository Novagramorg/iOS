# Seeded Mixed-Pass Stress Harness Design

**Date:** 2026-07-23
**Status:** IMPLEMENTED / CURRENT

## Context

The granular list-animation model now handles insertions, removals, replacements, moves, row-size
changes, viewport-size and inset changes, programmatic scrolling, virtualization crossings,
carousel jumps, and departed ghost blocks. The focused regression suite specifies the individual
rules, and manual K2 validation has confirmed the latest combined horizontal-inset, first-row-size,
and five-row structural pass.

The remaining risk is interaction coverage. Most regressions have appeared when individually valid
operations overlap before prior tracks settle, particularly when loaded-window membership changes.
A deterministic stress harness should search those compositions while preserving a small,
replayable failure surface.

## Goal

Add a deterministic integration stress harness that drives the real `CoreVirtualListView` transaction
path through overlapping mixed passes and checks the granular model's general invariants. A failure
must report enough information to reproduce it as one focused regression test.

## Considered Approaches

### 1. Model-only generated transactions

Generate `ListAnimationModel` mutations directly and compare its tracks with compiled keyframes.
This is fast, but it cannot exercise window construction, anchor selection, view reuse, crossing
carries, carousels, ghost witnesses, or rebinding. Those integration seams have caused most recent
bugs, so this is insufficient as the primary harness.

### 2. Seeded full-list integration harness — selected

Use `VirtualListFixture`, `SyntheticClock`, `TestScheduler`, and `SeededRNG` to submit generated
`applyChanges` passes to the real list. Inspect settled windows, analytic presentation values,
overlay state, and installed CA metadata through existing test-visible surfaces. This exercises the
production transaction path while remaining deterministic and fast.

### 3. Automated Demo-button chaos

Drive the Demo UI and inspect temporary logs. This remains useful when diagnosing an observed runtime
problem, but it is too slow and timing-sensitive for a repeatable test oracle. It also provides less
precise ownership and track evidence than the test fixture.

## Harness Structure

Create a test-only scenario runner with two layers:

- `MixedPassScenario` owns the deterministic mutable item collection, viewport geometry, identity
  serial, RNG, and an append-only action log. It generates valid actions and translates each pass
  into one `CoreVirtualListView.applyChanges` call.
- `MixedPassStressTests` owns the fixture, captures presentation state immediately before and after
  each pass, advances the synthetic clock by generated sub-duration intervals, and checks invariants.

The runner must not add production hooks, load or measure rows merely for assertion purposes, read
`CALayer.presentation()`, or use screenshots/video. Existing compiler parity tests remain the only
tests that treat an actual paused presentation layer as evidence; the stress harness treats
`ListAnimationModel` as presentation authority and verifies installed CA metadata against observed
model tracks.

## Deterministic Scenario

Each scenario starts with at least 120 stable-identity rows, a `390 × 800` viewport, and a `160pt`
preload margin. Row heights vary among a small fixed set so block changes exercise non-uniform
geometry.

Use a fixed, checked-in seed list. Each seed runs a bounded number of passes so the suite remains
appropriate for every local test run. On failure, the assertion includes:

- seed;
- pass number;
- complete generated action prefix;
- current logical size and insets;
- engine offset;
- active loaded indices;
- crossing-carry identities and ghost-block snapshots.

This turns a generated failure into a deterministic one-command reproduction. Once a seed exposes a
production bug, preserve the minimal sequence as a named focused regression test; do not rely only on
the long generated sequence.

## Action Grammar

A pass chooses one to three compatible actions and submits their final combined state once:

- insert a block of one to five new identities at a valid collection boundary;
- remove a block of one to five identities while retaining a non-empty collection;
- move a contiguous block to another valid boundary;
- replace one identity in place;
- change one or more existing row heights;
- change horizontal insets;
- change vertical insets;
- change viewport width and/or height;
- programmatically scroll to a valid identity-relative index and point offset;
- submit an explicit same-target geometry or item pass.

Durations include zero and positive values. Positive passes alternate `smoothstep` and `easeOut`.
Between passes, advance by zero or a fraction of the active duration so later operations land at
birth, early, middle, and late phases. Periodically settle completely, then continue, to cover both
clean and overlapping transaction boundaries.

User drag/deceleration is out of scope for the first harness. Physics and gesture integration already
have dedicated deterministic suites; mixing them into the initial action grammar would obscure
whether a failure belongs to transaction composition or scroll physics.

## Boundary Invariants

Capture all observable live/carry identities and their analytic property values immediately before
each pass. Immediately after the pass:

1. Every identity continuously represented on both sides has the same visible position and extent at
   the transaction boundary unless the operation explicitly creates or destroys that incarnation.
2. A property whose settled target did not change preserves its exact track generation, start time,
   duration, curve, and deadline.
3. A changed property begins from its pre-pass analytic presentation and uses the current pass
   duration and curve.
4. Inserted rows use complete final x/y/width/height geometry and animate opacity only.
5. All scalar values are finite; widths and heights are non-negative.
6. The active window contains contiguous, in-range indices with unique identities matching the
   current collection.
7. Any installed CA animation observed on a loaded live layer, viewport layer, crossing carry,
   ghost wrapper, or ghost member has the same generation, begin time, duration, endpoints,
   additivity, and key path as its corresponding analytic track.

Some inserted and departing visuals intentionally overlap while their logical structure transitions.
The harness therefore does not impose a blanket no-overlap/no-gap rule during animation.

## Settled Invariants

At periodic settlement checkpoints and at the end of every seed:

1. No analytic animation remains active.
2. Crossing carries, viewport carousel carries, and ghost blocks are fully torn down.
3. Every loaded live row has zero additive x/y correction, full opacity, and visual width/height
   equal to its settled frame.
4. Loaded frames are ordered and contiguous in collection order.
5. The active window remains a bounded viewport-plus-preload projection; the harness never forces
   additional membership to prove this.
6. Reapplying the exact settled items/size/insets with zero duration is an exact no-op.

## Failure Policy

The harness itself should initially be implemented test-first around deterministic generation,
action-log reproduction, and invariant detection. If a generated scenario reveals a production
failure:

1. record the seed and action prefix;
2. minimize it to a named focused failing test;
3. diagnose the violated ownership or coordinate rule;
4. fix the general rule using that focused test;
5. keep both the focused regression and the bounded seeded harness.

Do not weaken an invariant merely to make a seed green. If an invariant conflicts with intentional
behavior, update this design explicitly before changing the oracle.

## Files

- Add `CoreListDemoTests/TestSupport/MixedPassScenario.swift` for deterministic action generation,
  state mutation, application, and replay descriptions.
- Add `CoreListDemoTests/MixedPassStressTests.swift` for generated integration runs and invariants.
- Modify `CoreListDemoTests/TestSupport/VirtualListFixture.swift` only for narrowly reusable,
  read-only diagnostic helpers needed by the assertions.
- Update `CLAUDE.md`, `docs/plans/2026-07-20-list-animation-model-design.md`, and
  `docs/plans/CHANGELOG.md` after the harness is verified.

No production source change is planned. Any production defect discovered by the harness receives its
own focused regression and implementation change.
