# Settled Edge Anchors and Two-Sided Ghost Attachments

**Status:** IMPLEMENTED / CURRENT

## Goal

Correct top-edge mutations without adding index-specific animation rules:

- inserting at collection index `0` while settled at the loaded top edge places the new row below
  the top inset and pushes the former first row down;
- removing a row above the current pass anchor keeps the departing ghost above that anchor by
  attaching the ghost block's `maxY` to the following boundary's `minY`;
- rubber-band overscroll remains display-only and never changes structural anchor decisions.

This refines the boundary-witness model in
`2026-07-21-ghost-block-boundary-witness-design.md`. All unchanged contracts from that design remain
in force.

## Settled Viewport Geometry

`ScrollEngine.offset` may contain temporary rubber-band displacement outside the declared loaded edge
range. A structural pass derives a semantic settled offset by clamping that displayed offset to every
known old loaded edge. The difference between displayed and settled offset is presentation-only
overscroll.

Anchor identity, top-visible-row selection, anchor direction, and edge-pinning decisions use the
settled offset. They do not use the overscroll displacement. Existing programmatic viewport animation
state is not classified as rubber-band overscroll and retains its current behavior.

When the old window has its top edge loaded and the semantic offset equals the minimum edge within the
existing geometry epsilon, a non-`scrollTo` mutation is anchored to the top boundary itself. If the new
collection is nonempty, new index `0` is built at point offset `0`. An insertion at index `0` therefore
occupies the top inset, while existing rows receive ordinary independent position transitions to their
new settled locations.

Live overscroll remains owned by the scroll engine and its bounce. The existing overscroll exclusion
continues to prevent edge-underfill settling from treating rubber-band displacement as a requested
logical position. A mutation must not use the overscrolled row position to select a different semantic
anchor.

## Two-Sided Boundary Links

A ghost block boundary link contains two independent pieces:

1. the frozen local edge of the source ghost block that touches the boundary: `minY` or `maxY`;
2. the existing witness edge that supplies the boundary coordinate: live/ghost `minY` or `maxY`, or
   unresolved.

If `B` is the resolved witness coordinate and `L` is the selected frozen local source edge, the block's
settled root is:

```text
rootY = B - L
```

This replaces the implicit assumption that every witness coordinate is the block root. A source
`minY` of zero preserves the current behavior exactly.

The source edge is stored with each ledger node and exposed in its snapshot. Witness replacement is
atomic with source-edge replacement whenever the chosen side changes. Graph edges and cycle detection
continue to depend only on the witness target.

## Creation Selection

Initial selection continues to begin from the departure's transformed ordinal.

- A genuine same-pass insertion occupying that ordinal represents the departure's original slot. The
  ghost attaches its `minY` to the inserted row's `minY`, and the open boundary seals immediately.
- For a deletion-only boundary whose current pass anchor is below the departed block, the successor is
  stationary relative to the anchor. The ghost attaches its `maxY` to that successor's `minY`.
- For a deletion-only boundary whose current pass anchor is above the departed block, the boundary is
  represented from above. The ghost attaches its `minY` to the selected predecessor/successor boundary
  under the existing ordinal rule.
- Tail and unavailable-geometry cases retain the existing best-effort witness selection. Their source
  edge is chosen from the same anchor-relative side; unresolved links retain the sampled root.

This is spatial and anchor-relative. It does not associate the ghost with a removed identity's later
counterpart.

## Open Boundary Claiming and Migration

A deletion-only boundary remains open as before. A later genuine insertion whose settled `minY` equals
the ghost's settled root within epsilon claims the original slot. Claiming atomically switches the link
to `ghost.minY -> inserted.minY` and seals it. This preserves delayed replacement equivalence even when
the provisional deletion-only carrier used `ghost.maxY -> successor.minY`.

During invalid-witness migration, the current pass anchor selects both sides of the new link:

- a candidate above the invalid boundary yields `ghost.minY -> candidate.maxY`;
- a candidate below the invalid boundary yields `ghost.maxY -> candidate.minY`.

Exact live-to-ghost handoff preserves the source edge when it preserves the same boundary. A later pass
may change the source edge when migration crosses to the other anchor-relative side. Ghost-to-ghost
links use the referenced block's resolved selected edge exactly as live links do.

Retention of a still-valid witness retains both the witness and source edge. Pure scrolling, coordinate
rebases, and semantic no-op passes remain exact link and animation no-ops.

## Animation and Continuity

The ledger resolves the new root using the two-sided equation before the existing ghost-block position
transition. A changed root replaces only the block's additive position track from its analytic current
root under the current pass duration and curve. An unchanged root is the same strict no-op as before.

No new renderer, display link, `UIViewPropertyAnimator`, identity link, or special Del/Add path is added.
Production motion remains model-owned additive CA keyframe animation.

## Verification

Automated tests must prove:

1. at the loaded settled top edge, inserting at index `0` settles the new row at screen `minY == 0`
   and moves the former first row downward;
2. a deletion-only ghost above the pass anchor resolves
   `ghostRoot + ghost.localMaxY == successor.minY` and does not acquire a downward position track;
3. a top rubber-band displacement produces the same semantic anchor and settled row geometry as offset
   `0`, without being interpreted as an interior scroll position;
4. same-pass and delayed replacement still claim `ghost.minY -> inserted.minY` and seal the boundary;
5. migration above and below the current pass anchor chooses the corresponding source and witness edges;
6. ghost-to-ghost handoff, coordinate rebasing, no-op retention, lifecycle cleanup, and the complete
   existing test suite remain green.

Manual K2 verification uses Slow Animations for `Top -> +top`, `+top -> -top`, and a top-edge
rubber-band followed by each mutation. The new row must originate below the top inset, and a ghost above
the inset must remain attached by its bottom edge instead of sliding down into the next row.
