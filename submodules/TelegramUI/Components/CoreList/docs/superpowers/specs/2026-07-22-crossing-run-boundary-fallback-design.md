# Crossing-Run Boundary Fallback Design

**Status:** IMPLEMENTED / CURRENT

## Goal

Preserve the known internal geometry of a contiguous group of live survivors when the group crosses the
virtualization boundary and no loaded shared survivor can provide its missing-endpoint displacement.

The motivating `H+Size+5` pass grows the first row, inserts five rows, and changes horizontal insets. Every
old survivor below the insertion leaves the settled window. The current per-identity fallback assigns all of
those rows the same bottom retention-boundary Y, so the rows collapse together while exiting. The inverse
removal makes them fan outward from the same point.

This is a general missing-endpoint inference defect, not a Demo-action or horizontal-geometry special case.

## Requirements

- Keep `activeWindow` as the pure viewport-plus-preload settled window.
- Never load or measure an additional item to animate it.
- Continue using exact shared-survivor displacement samples whenever one is eligible.
- When no sample exists, preserve the known endpoint's member order, variable heights, and gaps.
- Keep crossing ownership and lifecycle per identity so overlapping passes can independently retarget or
  release members.
- Compose unchanged with horizontal position, width, height, opacity, viewport, ghost, and carousel tracks.
- Apply the same rule symmetrically to outgoing and incoming crossings above or below the current-pass anchor.

## Rejected Alternatives

### Reconstruct the structural displacement

The list could derive the exact missing endpoint from inserted, removed, and resized footprints. That is only
reliable while all intervening geometry is already known. Generalizing it would either measure unloaded items
or create another partial layout model, both contrary to virtualization and the established best-effort rule.

### Chain independent peer witnesses

The first missing row could fall back to the boundary and each following row could reference its predecessor.
This produces the desired geometry in a single pass, but makes the answer depend on evaluation order and
complicates interruption and partial re-entry. The planner should instead derive the whole segment from an
immutable known-endpoint snapshot.

## Architecture

### Preserve exact shared-sample inference

The existing eligibility rule remains authoritative: an unmoved shared survivor may supply a displacement
only when its `newIndex - oldIndex` equals the crossing survivor's ordinal displacement. Each crossing member
that has such a sample keeps its existing independently inferred endpoint.

### Plan ordered crossing runs

The list supplies the planner with crossing endpoints ordered on the side whose geometry is known. Endpoints
are partitioned by:

1. crossing side (`old` for outgoing or `new` for incoming);
2. direction relative to the current-pass anchor (above or below);
3. structural region, represented by ordinal displacement; and
4. contiguity in both old and new collection indices.

Move participants do not join a fallback run because their missing geometry represents a reorder rather than
local structural translation. They retain the existing individual boundary fallback.

Within each ordered run, the planner first resolves members with eligible shared samples. Consecutive members
without a sample form a fallback segment. This lets distinct structural regions and locally witnessed pieces
remain independent while eliminating pile-up inside an unwitnessed contiguous segment.

### Project one fallback segment rigidly

The planner computes one translation from the segment's known geometry:

- below the anchor: translate the segment so its first member's `minY` equals `band.maxY`;
- above the anchor: translate the segment so its last member's `maxY` equals `band.minY`.

Apply that same translation to every member's known `minY`. This preserves all internal spacing, including
variable heights and pre-existing gaps. Only the anchorward segment edge is guaranteed to touch the retention
boundary; the remaining members may extend farther outside it.

For outgoing members, the known endpoint is old and the translated endpoint is new. For incoming members,
the known endpoint is new and the translated endpoint is old. Thus removal is the exact geometric inverse of
insertion when the same members and retention band participate.

The resulting plans remain per identity:

```text
outgoing: exact oldY -> rigidly projected newY
incoming: rigidly projected oldY -> exact newY
```

`CoreVirtualListView` continues installing or transitioning one live owner per member. No group owner,
wrapper view, shared CA animation, or new lifecycle registry is introduced.

## Composition and Interruptions

Run planning consumes only pass-boundary settled geometry. The existing animation model still samples each
identity's current analytic presentation when replacing its position track, so an interrupted member remains
C0-continuous even if its newly planned segment differs from the previous pass.

If a later pass gives a member an eligible shared witness, that exact witness supersedes fallback geometry.
If only part of a fallback segment re-enters the settled window, the remaining ordered endpoints are planned
again from their current known endpoint geometry. Per-identity completion generations remain unchanged.

Horizontal inset transitions continue to retarget crossing member x and width properties independently.
Inserted rows remain at complete final geometry with opacity-only animation. Ghost blocks and carousel strips
do not use this planner and are unaffected.

## Testing

### Pure planner coverage

- An outgoing unwitnessed run below the anchor preserves member spacing with its first `minY` at `band.maxY`.
- An incoming unwitnessed run below the anchor is the inverse projection.
- Above-anchor projection places the last member's `maxY` at `band.minY`.
- Variable heights and nonzero gaps remain exact.
- Eligible shared samples remain unchanged and split unwitnessed fallback segments.
- Different ordinal-displacement regions never join.
- Move participants retain individual fallback behavior.

### Core-list regression

Reproduce the structural shape of `H+Size+5` without relying on the Demo button:

- start with the top loaded window;
- grow row 0, insert five rows at index 5, and apply horizontal insets in one animated pass;
- assert the outgoing crossing carries form an ordered rigid run rather than sharing one settled Y;
- reverse the pass and assert incoming rows begin from the corresponding rigid run;
- assert horizontal x/width tracks and inserted-row opacity-only behavior still compose.

Use paused-layer compiler parity to confirm the emitted additive position keyframes match analytic values for
multiple members in the run. Run the complete serial K2 suite and verify the Demo through temporary logs, not
screenshots or video.

## Acceptance

In `H+Size+5`, rows pushed out below the preload band translate as one visually rigid ordered run while their
individual live-owner tracks remain independent. `H-Size-5` brings the returning rows in from the same rigid
offscreen arrangement. No row pile-up, fan-out, extra measurement, or special handling of the Demo action is
present.
