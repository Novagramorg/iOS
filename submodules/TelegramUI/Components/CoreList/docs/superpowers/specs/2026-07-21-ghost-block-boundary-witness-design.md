# Ghost-block boundary witness ledger

**Date:** 2026-07-21
**Status:** IMPLEMENTED / CURRENT

## Implementation record

The design landed in six reviewed implementation commits and two final hardening waves:

- `2af9629` — analytic/controller/compiler ghost-block position tracks;
- `27c65f6` — UIKit-free boundary-witness ledger and dependency graph;
- `7e66519` — contiguous-departure grouping, rigid wrappers, members, and initial witnesses;
- `fc2c6b9` — retained live-boundary riding and same-target/zero-duration behavior;
- `419323b` — current-pass anchorward migration, exact ghost handoff, and dependent lifetime;
- `a1996b8` — pure/mixed viewport composition, coordinate remaps, empty/reset lifecycle;
- `6893ce3` — post-rebase old-edge coordinates, move-ambiguous formation, semantic no-op gating, and
  cross-layer debug invariants;
- `0b20fbf` — linear mapped-survivor content checks, ambiguous-new-block-first migration ordering, and
  positive changed-size/dirty gate guards.

The implemented product contract matches this design. Approved deviations were limited to test fixtures:

1. Task 5 changed the below-anchor integration viewport from 300pt to 200pt because six 50pt rows exactly
   filled 300pt and clamped the requested offset, so the original fixture could not establish a below-boundary
   anchor.
2. Task 6 placed `viewport:` before `items:` to match `VirtualListFixture`'s actual initializer and replaced
   duplicate-identity data `[0, 8, 9] + Array(2..<20)` with `[0, 1] + Array(10..<28)`, preserving the intended
   witness/scroll geometry while satisfying the list's uniqueness precondition.
3. The five prescribed Task 6 viewport cases were already green on the Task 1–5 implementation, so the
   carry-only empty no-op cleanup case supplied the required genuine RED and closed the remaining lifecycle
   gap without changing the spatial contract.

Task 6 verification passed 120/120 focused model/compiler/ledger/list tests and the complete 342/342 K2
suite, with zero failures or unexpected tests. Task 7 rebuilt, installed, and shell-launched the Debug Demo on
the dedicated iPhone 17 Pro K2 with deterministic 3.0-second transactions (the Demo's 0.3-second timing under
10× Slow Animations). Log/state evidence confirmed 0.000pt boundary discontinuity for both single and
three-member retargets, unchanged rigid local member offsets `[0, 75, 150]`, exact current-pass
`ghostMinY` handoff while the older member remained visible, and unchanged block generation/witness across
both the user-scroll callback path and pure programmatic `scrollTo`.

The final hardening verification passed 128/128 focused model/compiler/ledger/list tests and the complete
350/350 K2 suite. Old invalid live edges now enter migration in the same post-rebase coordinate space as
ledger roots and new live edges. Move-ambiguous formation rejects current-pass move occupants, resolves
ambiguous new blocks before pre-existing invalid blocks, then permits exact settled-edge ghost handoff.
Semantic no-ops preserve witness and track state exactly; real order, logical-size, content, and dirty measured
geometry changes still resolve. Content-change detection follows `diff.survivorMap` in linear work, and debug
validation covers exact ledger/render/member/owner/model agreement.

The open-boundary follow-up (`bc9dbcd`) makes delayed replacement spatially equivalent to same-pass
replacement: a deletion-only boundary remains open until an exact genuine insertion occupies and seals it,
while a same-pass inserted occupant seals immediately. Its automated verification passed 76/76 focused tests,
350/350 complete K2 tests, and a fresh Debug build. Manual K2 Slow Animations verification confirmed the
delayed Del/Add sequence behaves correctly.

## Context

Before this design was implemented, departed views moved from the live container into `exitOverlay`, froze
at their analytic current absolute content position and visual height, and continued only their opacity fade.
The overlay participated in scrolling, viewport animation, and coordinate rebases, but a later structural
pass had no way to move a departure when the list boundary it visually occupied moved.

The motivating failure sequence was:

1. an item at position B departs and another item occupies B, either in the same pass or a later pass;
2. while the old item is still fading, a change at position A moves the settled B boundary;
3. the live content moves, but the old ghost remains fixed in content space.

The required behavior was for the ghost to follow that boundary on a best-effort basis without linking it
semantically to a reinserted counterpart identity. Its spatial reference could be a completely different
live item, or another ghost created by a block deletion.

## Goals

1. Let active departures follow the absolute settled list boundary they occupied when created.
2. Preserve contiguous departed runs as coherent visual blocks.
3. Re-home a boundary reference toward the current pass anchor when its carrier is removed, moved, or no
   longer has usable geometry.
4. Use the existing granular animation contract:
   - unchanged endpoint is an exact no-op;
   - changed endpoint replaces from analytic current position on the current pass duration and curve;
   - zero duration settles immediately.
5. Render all production ghost movement with additive `CAKeyframeAnimation` output from the analytic model.
6. Keep the feature a best-effort spatial attachment ledger, not a second layout, logical-height, overlap,
   footprint, or band model.

## Non-goals

- Linking an outgoing ghost to a new live incarnation with the same identity.
- Giving ghosts structural height or allowing them to push or pull live rows.
- Reproducing an arbitrary witness presentation composed from unrelated older position and height clocks.
- Retargeting ghost witnesses during pure user or programmatic scrolling.
- Extending a visible ghost's opacity lifetime merely to finish position motion.
- Reading `CALayer.presentation()` as animation authority.
- A display-link production renderer or `UIViewPropertyAnimator`.

## Terms

- **Ghost member:** one departed loaded view, with its own exit-opacity owner and frozen visual geometry.
- **Ghost block:** one or more ghost members removed as a contiguous run in one pass. A one-item departure is
  represented by the same block type with one member.
- **Block root:** the absolute content Y that owns the block's spatial motion.
- **Boundary witness:** a live-item or ghost-block edge whose absolute settled Y is the block root's target.
- **Pass anchor:** the anchor selected independently by the existing `applyChanges` transaction for that
  pass. Reference migration direction is always relative to this anchor, never a persistent global direction.

## Architecture

### Ownership boundaries

`CoreVirtualListView` owns the ghost-block ledger and reference graph. It already owns collection order,
identity diffing, pass-anchor resolution, settled window geometry, exit-overlay placement, and content
coordinate rebases. The animation model must not duplicate any of those responsibilities.

`ListAnimationModel` owns only analytic property state. `ListAnimationController` owns model-to-layer
bindings, CA installation, generations, and completion safety. `CoreAnimationCompiler` remains an output
renderer.

### Ghost-block record

Conceptually, each active block contains:

```swift
struct GhostBlock {
    let id: GhostBlockID
    let positionOwner: ListAnimationOwner
    let wrapperView: UIView
    var witness: GhostBoundaryWitness
    var settledRootY: CGFloat
    let localBounds: ClosedRange<CGFloat>
    var members: [GhostMember]
    var dependents: Set<GhostBlockID>
}

enum GhostBoundaryWitness {
    case liveMinY(AnyHashable)
    case liveMaxY(AnyHashable)
    case ghostMinY(GhostBlockID)
    case ghostMaxY(GhostBlockID)
    case unresolved
}
```

The concrete representation may differ, but these semantics are required. References describe spatial
edges only; they imply no item equivalence or replacement relationship.

### Stable wrapper

Each block uses one stable wrapper view directly under `exitOverlay`. Member views become children with
fixed local frames. The wrapper owns vertical position animation; member layers own opacity only.

This wrapper is safe in a way that parenting a ghost under a live carrier would not be: it remains in the
dedicated overlay, is unaffected by live-view reuse and clipping, and survives witness migration without
reparenting.

## Block formation

Only loaded genuine departures produce ghost members. Moved identities retain their live views and do not
become departures. Departed loaded rows that are contiguous in the old collection and leave in the same pass
form one block. A surviving row between two departures splits them into separate blocks.

Before reconciliation releases the live layers, the pass samples each member's analytic absolute content Y,
visual height, and opacity. The block root starts at the first member's sampled Y. Each member stores its
sampled frame relative to that root, preserving the exact in-flight visual arrangement even if prior
independent tracks mean the sampled frames are not tightly stacked. The block's frozen local bounds are the
envelope of those member frames.

The old live position and height animations are removed only after their analytic boundary values have been
captured. Exit height remains frozen. Each member receives a fresh exit-opacity owner, so reinsertion and
stale completion rules remain identity-safe.

## Initial witness

The pass maps the departed run's former leading ordinal through the current collection difference into the
post-pass order. This is a transformed collection boundary, not an unadjusted reuse of the old integer index.
For an unambiguous non-move run, the boundary is immediately after the nearest non-moved surviving predecessor
of the run in final order, or ordinal zero when no such predecessor exists. This naturally accounts for
earlier insertions and deletions: a newly inserted item immediately after that predecessor occupies the
vacated boundary. If current-pass moves make that predecessor mapping inconsistent with the run's old order,
the transform is ambiguous and uses the anchorward fallback below.

Witness selection is:

1. If a live item occupies the transformed ordinal, use its `minY`.
2. If the boundary is after the final item, use the final live item's `maxY`.
3. A ghost-block edge occupying that boundary is eligible when no live edge represents it.
4. If the new list has no usable edge, use `.unresolved` and keep the sampled root.

The occupying live item may be a newly inserted identity. It is selected because it represents the spatial
boundary, not because it matches the departure.

The ledger also records whether the creation boundary is still open. A genuine insertion selected as the
initial live occupant seals the boundary immediately. When deletion initially pulls an existing survivor
across the vacated boundary, the boundary remains open: a later genuine insertion whose settled `minY`
exactly equals the block root becomes the spatial occupant and seals it. This makes delayed replacement
equivalent to same-pass replacement without linking the ghost to a counterpart identity. Once sealed, later
insertions above the occupant do not steal the witness; the ghost continues riding its established carrier.

After the new settled window is rendered, the new block is processed by the same transition rule as every
existing block. If its selected edge differs from the sampled root, it snaps or animates according to this
pass's duration and curve. No special freeze exception applies to the creation pass.

When moves make the transformed ordinal ambiguous—including when a current-pass move participant occupies the
transformed ordinal—witness selection falls back to the anchorward migration rule below. Move-ambiguous new
blocks resolve first in deterministic block-ID order; only then do pre-existing invalid blocks migrate. This
lets an older departing-carrier witness test exact handoff against the new block's settled resolved edge rather
than its sampled in-flight root. Ordinary unambiguous new blocks are not reprocessed by migration.

## Witness retention and migration

Witnesses are reconsidered only on passes with a real insert/delete/move, genuinely changed logical size, or
measured loaded geometry change from content reconciliation or a dirty view. Content comparison follows the
already computed old/new survivor mapping and inspects each mapped pair at most once. Equal items and an
unchanged size are semantic no-ops even when a retained witness is unloaded: witness, model track, generation,
phase, curve, deadline, completion, and installed CA metadata remain exact. A mixed real change plus `scrollTo`
still resolves witnesses; a pure scroll pass does not.

### Retention

A live witness remains valid when all of the following hold:

- its identity remains present;
- it is not a move participant in the current pass;
- the selected edge has settled geometry available in the active window.

A content or height change does not invalidate the witness. `minY` continues to refer to its top edge and
`maxY` continues to include its new settled height.

Before ordinary retention, an open creation boundary gives an exact current-pass insertion at the block root
one opportunity to become its `liveMinY` carrier. This is a spatial occupancy rule, not invalid-witness
migration: it applies even when the provisional survivor witness remains otherwise valid, and it seals after
the first exact occupant. Move participants are not genuine insertions and cannot claim an open boundary.

A ghost witness remains valid while the referenced block node exists in the ledger, including when its own
members are already invisible but it still has dependents.

### Anchorward migration

If the witness is removed, moved, geometrically unavailable, or otherwise cannot still represent its edge,
the block searches from the invalid boundary toward the current pass anchor. It selects the nearest usable
candidate in that direction:

- if an invalid live witness departs into a new ghost block in this pass, first prefer the corresponding
  settled edge of that new block when it equals the invalid boundary within the position epsilon;
- for a candidate above the boundary, use the candidate's `maxY`;
- for a candidate below the boundary, use the candidate's `minY`.

Adjacent live `maxY` and `minY` edges commonly have the same coordinate. That coordinate tie is resolved by
the current pass anchor side, not by a persistent min/max preference.

Candidates may be live items with available settled geometry or ghost blocks with resolvable spatial nodes.
A current-pass move participant is not eligible because it is leaving the boundary the ghost needs to
represent. A moved identity may become eligible again on a later pass when it is an ordinary survivor at its
new location.

If a candidate would create a reference cycle, it is skipped and the search continues toward the anchor. If
no usable candidate exists, the witness becomes unresolved and the block freezes at its current settled
endpoint.

The search uses the same independently resolved pass anchor as the core list transaction. It does not retain
the direction from a previous pass.

## Reference graph

Ghost-to-ghost references form a directed anchorward graph. Production candidate selection must keep it
acyclic; debug builds additionally assert acyclicity and valid IDs after every mutation.

New settled block endpoints are resolved in dependency order:

- `liveMinY(id)` is the live item's new settled absolute content Y;
- `liveMaxY(id)` is that Y plus its new settled height;
- `ghostMinY(id)` is the referenced block's new settled root plus its frozen local minimum;
- `ghostMaxY(id)` is the referenced block's new settled root plus its frozen local maximum;
- `unresolved` retains the block's existing settled root.

This makes block deletion coherent without chaining individual member tracks. It also lets an older block
continue riding when its live witness departs into a newer block.

## Position animation contract

Ghost-block position uses the same additive correction representation as live-item position, but its settled
base is the ledger's absolute block root.

At one captured transaction time:

1. sample the old analytic block offset;
2. compute `currentAbsoluteRoot = oldSettledRoot + oldOffset`;
3. resolve the new witness edge and write it as the wrapper's model-layer root;
4. if the endpoint changed, replace the block position track with
   `currentAbsoluteRoot - newSettledRoot -> 0`;
5. if the endpoint is unchanged within the existing position epsilon, do nothing.

Consequences:

- changed endpoints are C0-continuous at the transaction boundary;
- the current pass curve and duration determine the reattachment motion;
- a zero-duration pass snaps to the new witness edge;
- an unchanged endpoint preserves the exact analytic track, generation, CA key, phase, curve, deadline, and
  completion state;
- velocity continuity is not promised;
- block members remain rigid relative to the wrapper after creation.

The compiler emits the block root as an additive `position.y` keyframe animation and uses the existing
high-refresh-rate preference. No new production renderer is introduced.

## Best-effort boundary

The contract follows the witness's settled edge under the current pass transition. It is exact when the
block and witness begin aligned and share the same current transition. It does not attempt to synthesize the
sum of unrelated older position and height curves still running on the witness.

Even in that case:

- the ghost never jumps at an animated transaction boundary;
- it reaches the selected absolute edge if it remains visible through the transition;
- missing information freezes the ghost instead of inventing unloaded geometry.

## Scrolling and coordinate changes

User scrolling already moves `exitOverlay` through the scrolling content hierarchy. Programmatic scrolling
already moves it through the additive viewport track and carousel mapping. Pure scrolling therefore cannot
replace a block position track or migrate a witness.

Container rebases and explicit overlay coordinate remaps are different: existing code changes overlay-child
model positions to preserve the same screen presentation. Every exact delta applied to a ghost wrapper must
also be applied to its ledger `settledRootY`. This is a coordinate representation change only. The block's
witness, additive offset, track, generation, phase, curve, and deadline remain untouched.

When migration follows a structural rebase, the invalid old live min/max edge is translated by the actual
authoritative engine-offset delta before candidate selection or exact handoff. Old edges, new live edges, and
ledger roots are therefore compared in one settled post-rebase coordinate space without presentation reads.

## Opacity and lifetime

Each member's sampled opacity fades independently to zero under its creation pass. Its exact owner,
generation, binding, and view guard teardown. A stale completion cannot remove another member, a replacement
live view, or a rebound wrapper.

Position motion does not prolong a visible member's fade. When a member opacity completes, that view and its
opacity owner are removed even if the block root still has position motion.

An empty block remains as a nonvisual spatial node while another block references it. Its wrapper and
analytic position state may remain solely to preserve dependency behavior. Once it has no visible members
and no dependents, the list removes its outgoing graph edge, wrapper, block-position owner, and ledger entry.
Garbage collection repeats until no newly orphaned empty block remains.

An explicit animation reset or rebuild-from-scratch clears member owners, block owners, wrappers, and graph
edges deterministically. A normal animated populated-to-empty `applyChanges` pass is not a reset: its blocks
remain until their fades and dependency lifetimes finish.

## Failure handling and invariants

- Missing live geometry is a normal best-effort miss and freezes or migrates the block; it is not recovered
  from estimated unloaded heights.
- Candidate search continues past unusable or cycle-forming candidates.
- Each visible exit member belongs to exactly one block.
- Each block has exactly one position owner and at most one outgoing witness edge.
- Each ghost reference points to an existing block node.
- Graph dependency counts agree with the actual edges.
- All production layer writes happen with implicit actions disabled before explicit CA installation.
- Interruption samples come exclusively from `ListAnimationModel`.

Debug builds assert ownership uniqueness, graph integrity, acyclicity, and exact cross-layer agreement at
mutation boundaries: ledger and render IDs are one-to-one, visible-member counts match, each render owner is
`.ghostBlock(id.rawValue)`, each wrapper remains under `exitOverlay`, and the controller/model contains every
ledger owner. Production falls back to an unresolved frozen witness rather than risking a cycle or invalid
reference.

## Test strategy

### Model and compiler

- Block-position transition starts from analytic current absolute root.
- Same target is an exact no-op for model and CA state.
- Changed target replaces only block position with the current pass clock and curve.
- Zero duration settles immediately.
- Additive compiler samples match model samples at birth, interior phases, deadline, and settlement.
- A paused real layer matches analytic block position.
- Coordinate-only base shifts preserve the active track unchanged.

### List integration

- Remove/insert at B, then mutate A above: the old ghost targets the B boundary.
- Same-pass and different-pass remove/insert produce the same spatial behavior and never inspect counterpart
  identity.
- Contiguous deletion creates one rigid block and preserves sampled member offsets.
- Disjoint deletion runs create independent blocks.
- Deleting the final row references the last live item's `maxY`.
- A witness height or content change preserves the witness and follows the selected edge.
- Witness removal and move migrate anchorward for anchors on either side.
- A block can reference another block, including a multi-block dependency chain.
- A referenced block may become visually empty before its dependent and is collected only after the
  dependency disappears.
- No-candidate and unavailable-geometry cases freeze without a boundary jump.
- Cycle-forming candidates are rejected.
- Unrelated structural passes with the same endpoint preserve the exact block position track and CA key.
- Animated and zero-duration passes respectively animate and snap absolute reattachment.
- User scroll, pure programmatic scroll, viewport interruption, and coordinate rebase do not replace ghost
  tracks; rebases update ledger roots by the exact applied delta.
- Reinsertion, stale completions, populated-to-empty, repeated delete/add, and reset leave no leaked owners,
  wrappers, members, or graph nodes after settlement.

### Manual demo oracle

The existing Demo controls are sufficient. Slow Animations should make the key sequence visible:

1. create a remove/insert ghost at B;
2. before its fade completes, change geometry/order at A above it;
3. observe the ghost animate to and ride the selected B boundary;
4. repeat with a contiguous deletion and with removal or movement of the current witness.

Temporary debug instrumentation may log block IDs, member IDs, witnesses, roots, graph edges, generations,
and analytic samples. No production display-link instrumentation is required.

## Acceptance criteria

1. The motivating B-then-A sequence has no transaction-boundary snap and the ghost reaches B's selected
   absolute boundary under the A pass transition.
2. A contiguous departed run remains a rigid block throughout its visible lifetime.
3. Removing or moving a witness re-homes the block toward that pass's anchor when a usable candidate exists.
4. Ghost-to-ghost riding works without cycles or lifetime leaks.
5. Same-target, scrolling, and coordinate-only operations preserve unrelated animation state exactly.
6. Analytic model and emitted Core Animation remain parity-tested; production never reads presentation state.
