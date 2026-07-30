# Infinite-Loading Anchor Preservation Design

**Date:** 2026-07-23
**Status:** IMPLEMENTED / CURRENT

## Context

`CoreVirtualListView.applyChanges` currently resolves a useful survivor anchor for ordinary
mutations, but its automatic policy deliberately gives loaded top and bottom edges priority. At the
loaded top, prepending items therefore pins the new index zero below the top inset and moves the old
first item. That behavior is correct for an ordinary finite collection update, but it is unsuitable
for an infinite-loading controller that prepends or removes pages around content the user is already
reading.

The list needs an opt-in, per-transaction anchoring mode. When requested, it should keep a current
loaded witness at the same settled distance from the top-inset edge while applying any mutation.
Loading triggers and pagination state remain the caller's responsibility.

## Goal

Add a policy-aware anchor-resolution mode to `applyChanges`. The mode preserves one loaded
survivor's settled position relative to the top-inset edge across item, size, inset, and dirty-content
changes, subject to finite-content edge clamping. It must remain compatible with virtualization,
granular animation, ghost blocks, crossing carries, programmatic scrolling, and all scroll-engine
implementations.

## Non-goals

- Do not add load thresholds, pagination callbacks, request state, or data fetching.
- Do not create a persistent list-wide loading mode.
- Do not accept a caller-supplied anchor identity or offset.
- Do not read `CALayer.presentation()`.
- Do not measure old off-screen rows solely to recover a fallback anchor.
- Do not add a post-layout scroll correction or a second positioning authority.
- Do not change the existing automatic anchor behavior.

## Public Transaction API

Introduce a transaction policy:

```swift
enum CoreListAnchorMode {
    case automatic
    case preserveVisibleContent
}
```

Both `applyChanges` overloads receive:

```swift
anchorMode: CoreListAnchorMode = .automatic
```

The default keeps existing source compatibility and behavior. The mode is selected independently for
each transaction and is forwarded unchanged when a re-entrant transaction is deferred through the
scheduler.

An explicit `scrollTo` is authoritative. If a pass supplies both `scrollTo` and
`.preserveVisibleContent`, normal programmatic-scroll anchor resolution runs and preservation is
ignored for that pass.

## Settled Witness Selection

Preservation is based on settled geometry. Active viewport corrections, active row corrections, and
presentation overscroll do not change which row is selected or the offset being preserved.

For a nonempty old settled window:

1. Express the old top-inset edge in absolute settled content coordinates:
   `oldSettledOffset + oldTopInset`.
2. Select the first loaded item whose settled `maxY` is strictly greater than that edge. An item
   ending exactly at the edge is above it; the next item is the witness.
3. Record the witness's own settled inset-relative position:
   `oldScreenMinY - oldTopInset`.
4. If the witness survives the diff, map it to its new index.
5. If it is removed, scan old loaded items after it in collection order and choose the nearest
   survivor below. Preserve that survivor's own old inset-relative position.
6. If no loaded survivor exists below, scan backward and choose the nearest loaded survivor above,
   again preserving that survivor's own position.
7. If no loaded survivor exists, preservation is unavailable and the transaction uses ordinary
   anchor resolution.

The fallback scan is intentionally limited to the old settled loaded window. A survivor outside that
window has no already-known old screen position, and measuring toward it would violate the
virtualization boundary.

## Projecting the Preserved Anchor

The selected witness becomes the one authoritative input to final window construction. Its requested
new screen position is:

```swift
newTopInset + oldInsetRelativePosition
```

This has two consequences:

- with unchanged insets, the witness retains the same settled screen `minY`;
- with a changed top inset, it retains the same distance from the inset edge and therefore moves by
  exactly `newTopInset - oldTopInset`.

The policy bypasses the automatic loaded-top shortcut that returns new index zero and later pins it
to the top inset. This is the defining infinite-loading behavior: if new items are prepended while
the old first item is the witness, those new items are placed above it rather than displacing it.

The existing one-pass `buildWindow` traversal remains responsible for constructing only the final
viewport-plus-preload projection. Its normal loaded-edge rules clip an impossible requested
position:

- reaching the loaded top may move the witness down or up to eliminate a leading gap;
- reaching the loaded bottom may move it to eliminate a trailing gap;
- an underfilled collection remains top-aligned;
- overscroll remains display-only and is restored only through the existing settled-edge path.

No corrective engine shift runs after window construction. The completed window remains the sole
source of the settled engine endpoint.

## Mutation and Animation Composition

The mode selects settled geometry; it does not introduce an animation primitive.

- Inserts and removals above the witness rebase content coordinates so the witness and unaffected
  surrounding survivors retain their inset-relative settled endpoints.
- Mutations below the witness do not change its endpoint.
- Moves, replacements, content-height changes, dirty updates, and mixed mutations use the same
  policy whenever the caller requests it.
- Inserted rows retain full final geometry and opacity-only reveals.
- Departures retain ghost-block ownership and boundary-witness behavior.
- Loaded/unloaded membership changes retain per-identity crossing carries.
- Existing row position, size, opacity, and viewport tracks keep the granular unchanged-or-retarget
  rules.

If the transaction begins while animation is active, witness selection and the requested endpoint
still use old settled geometry. Existing analytic tracks are not snapped to settlement. An unchanged
endpoint preserves its exact track; a changed property retargets from analytic presentation through
the existing C0 path. Coordinate-only rebases continue through the current animation-controller and
scroll-engine seams.

User drag or deceleration is not cancelled merely because the preservation mode is present.
Physics-engine coordinate shifts remain trajectory-preserving. An explicit `scrollTo` retains its
existing behavior of superseding user momentum and anchor preservation.

## Empty and Non-overlapping Collections

- Empty-to-nonempty and nonempty-to-empty transitions retain existing rebuild/teardown behavior.
- A full identity replacement has no survivor witness. It falls back to ordinary non-overlap
  resolution.
- A mutation that leaves no loaded survivor below or above the removed witness also falls back to
  ordinary resolution; it does not load or measure toward an off-screen identity.
- Duplicate-identity validation and all existing item contracts remain unchanged.

## Demo

Add separate `Load +5` and `Load -5` controls:

- `Load +5` prepends five fresh identities using `.preserveVisibleContent`;
- `Load -5` removes up to five leading identities while leaving the collection nonempty, also using
  `.preserveVisibleContent`.

The existing `+top` and `-top` controls remain unchanged so they continue exercising automatic
finite-list edge behavior. Both new controls use the existing Demo animation duration and work with
all three engine selections.

Runtime diagnosis, if needed, may temporarily log the chosen witness identity, old and new
inset-relative offsets, whether edge clipping changed the requested position, loaded indices, and
engine offset. Remove instrumentation after verification. Per project policy, do not use screenshot
or video testing.

## Verification

Implementation is test-driven through the public transaction path.

### Anchor policy

- Prepending above a mid-list witness preserves its inset-relative settled position.
- Removing rows above it preserves the same position.
- The behavior also holds while initially at the loaded top; new rows appear above the old first
  row instead of replacing its pinned position.
- Removing the witness selects the nearest loaded survivor below and preserves that survivor's own
  old position.
- With no loaded survivor below, it selects the nearest loaded survivor above.
- With no loaded survivor at all, it falls back to ordinary resolution.
- Exact top and bottom preservation requests clamp to newly reached finite edges.
- Underfilled content remains top-aligned.

### Mixed transaction behavior

- A simultaneous top-inset change preserves the witness's distance from the new inset edge.
- Mixed insertion/removal, move, replacement, row-height, dirty-content, size, and inset changes
  resolve through the same witness policy.
- An explicit `scrollTo` wins over preservation.
- `.automatic` retains all current edge and mutation behavior.
- Re-entrant deferred passes retain their requested mode.

### Animation and engine parity

- Immediate and positive-duration transactions have the same settled anchor result.
- Overlapping passes preserve analytic C0 continuity and exact unchanged-track metadata.
- Installed CA metadata remains equal to corresponding analytic tracks.
- UIKit, stepped-physics, and keyframe-physics engines agree on the settled endpoint.
- Active deceleration remains active for ordinary preserved mutations unless existing edge rules
  require a trajectory change.

### Virtualization

- Measurement counters prove witness fallback does not inspect old off-screen rows.
- The final active window remains contiguous, unique, in range, and bounded by the
  viewport-plus-preload projection.
- Crossing carries, viewport carries, ghosts, and analytic owners tear down after settlement.

## Success Criteria

1. Callers can opt into visible-content preservation on one `applyChanges` transaction without
   changing default behavior.
2. The selected loaded witness retains its settled distance from the top-inset edge whenever finite
   edges permit it.
3. Anchor removal follows the loaded-survivor order: nearest below, then nearest above.
4. The policy does not measure old off-screen rows or correct the offset after final window
   construction.
5. Existing animation and scroll-engine composition rules remain authoritative.
6. The Demo exposes independent loading controls for manual K2 verification.
7. Focused and complete serial K2 test suites pass with no project warnings.
