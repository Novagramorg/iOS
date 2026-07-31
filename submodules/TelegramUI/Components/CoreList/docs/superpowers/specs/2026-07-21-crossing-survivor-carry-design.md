# Crossing Survivor Carry Design

**Date:** 2026-07-21  
**Status:** IMPLEMENTED / CURRENT

## Goal

Preserve continuous motion when an ordinary structural mutation moves surviving items across the
virtualized loaded-window boundary.

The motivating Demo operations are `+5` and `-5`, but the model applies to any insertion, removal, or
mixed structural pass that changes which surviving identities belong to the viewport-plus-preload window.

## Observed Failure

The granular animation transaction currently creates position transitions only for identities present in
both the old and new settled windows. This works while the changed geometry is smaller than the retained
window, but window membership becomes visible for a sufficiently large block:

- an insertion pushes previously loaded survivors below the new window, so `render()` removes their views
  immediately instead of letting them travel out;
- a removal pulls previously unloaded survivors into the new window, so `attachLive` seeds them directly at
  their final positions instead of letting them travel in.

A diagnostic fixture using 75-point rows, a 600-point viewport, and a 200-point preload margin confirmed the
boundary exactly:

- before insertion, old identities `0...10` were loaded;
- after inserting five rows at index 5, only old identities `0...5` remained loaded;
- old identity 5 received the correct `-375 -> 0` additive track, while old identities `6...10` were removed
  immediately;
- after removing the five rows, old identities `6...10` became loaded again but were seeded at settled
  geometry, while only identity 5 received the correct `+375 -> 0` track.

The position model and Core Animation compiler are therefore not the source of the discontinuity. The
transaction discards or lacks one geometry endpoint before animation modeling begins.

## Required Contract

### Retention domain

The visual continuity domain is the viewport expanded in both directions by the configured
`preloadMargin`.

For a structural pass, animation participation is based on the union of identities already rendered in the
old retention domain and identities selected for the new settled retention domain:

```text
transition participants = old rendered survivors union new loaded survivors
```

Only surviving identities in that union participate in crossing animation. Items outside both sets are not
loaded, measured, instantiated, or animated.

### No additional measurement

The list must never extend either endpoint layout to obtain missing geometry for this feature. It must not
instantiate intervening items, enlarge the preload margin, or measure an inserted/removed range merely to
discover an offscreen endpoint.

Missing endpoint geometry is inferred solely from already available old/new loaded survivor geometry. Where
that inference is not trustworthy, the corresponding viewport-plus-preload boundary is the fallback.

### Existing semantic roles remain unchanged

- A genuine insertion remains a full-height row at its final frame with an opacity fade.
- A genuine removal remains a ghost member and fades through the ghost-block system.
- A move remains the same live identity and view.
- A crossing carry is always a survivor. It neither fades nor becomes a new semantic identity merely because
  it crosses the virtualization boundary.

## Architecture

### Settled window remains pure

`activeWindow` remains the authoritative new settled window. Its range continues to be chosen using the
ordinary viewport-plus-preload rules, and it remains a contiguous projection of the current collection.

Crossing continuity must not enlarge `activeWindow` or make it retain obsolete settled membership. This
preserves existing anchor, edge, scrolling, and rebalancing behavior.

### Rendered survivor set

Animation planning uses a rendered survivor set that contains:

1. the old `activeWindow` views; and
2. unfinished outgoing crossing carries from earlier passes.

The pass compares those identities with the new `activeWindow` identities after excluding genuine inserts
and removals.

- Present at both endpoints: ordinary loaded-survivor transition.
- Present only in the rendered old set: outgoing crossing survivor.
- Present only in the new active window: incoming crossing survivor.
- Present in neither: irrelevant to this transaction.

An unfinished carry counts as rendered geometry for later animation composition, but never participates in
anchor resolution or settled-window construction.

### Per-identity carry

Each outgoing crossing survivor has one `CrossingCarry` record containing conceptually:

```swift
struct CrossingCarry {
    let identity: AnyHashable
    let view: UIView & CoreListItemView
    var settledContentY: CGFloat
    var releaseGeneration: UInt64?
}
```

The concrete representation may include binding or coordinate metadata, but it must preserve these
semantics:

- ownership remains `.live(identity)`;
- there is exactly one rendered view for an identity;
- the view resides in a dedicated, non-layout crossing overlay while outside `activeWindow`;
- release is tied to the exact position generation that carries the survivor out of the retention domain.

The crossing overlay is a footprint-free child of the scrolling content hierarchy. It is distinct from the
ghost-block ledger because its members remain live survivors and do not fade.

Incoming crossing survivors use their ordinary active-window views. They require inferred old geometry but
do not require overlay ownership or completion cleanup.

## Missing-Endpoint Inference

### Structural displacement, not another identity's full track

Every shared survivor with exact old and new settled geometry supplies a displacement sample:

```text
delta = newSettledY - oldSettledY
```

A crossing survivor inherits the nearest eligible shared survivor's settled displacement in collection
order:

```text
outgoing: inferredNewY = exactOldY + delta
incoming: inferredOldY = exactNewY - delta
```

Only `delta` is inherited. The crossing identity never copies the shared identity's complete position track,
because that track may contain unrelated in-flight correction.

The normal analytic transition rule then incorporates the crossing identity's own current offset:

```text
from = currentVisibleY - inferredNewSettledY
to   = 0
```

This preserves composition during interruptions. For example, if the crossing row already has an active
position track, its current analytic presentation remains the new transition's exact starting point.

### Selecting the displacement sample

Candidates are unmoved shared survivors from the diff's monotonic survivor map whose ordinal displacement
`newIndex - oldIndex` equals the crossing survivor's ordinal displacement. This equality defines a structural
region without loading geometry: it prevents a survivor beyond a large inserted or removed block from
borrowing the unrelated displacement of a shared survivor on the other side. Among eligible candidates,
choose the smallest ordinal distance from the crossing identity in the endpoint collection where its geometry
is known. Ties resolve toward the independently selected current-pass anchor. A crossing move participant
does not borrow a displacement sample because its missing endpoint represents a reorder rather than local
structural translation; it uses the boundary fallback.

Multiple separated structural changes therefore form a piecewise displacement field. Crossing rows inherit
the nearest applicable local sample, not one transaction-wide shift.

### Boundary fallback

When no eligible shared sample exists, place the missing endpoint immediately beyond the corresponding edge
of the viewport-plus-preload retention band. If the crossing item lies below the pass anchor, its fallback
places `item.minY` at the band's bottom edge; if it lies above the anchor, it places `item.maxY` at the band's
top edge. Collection order relative to the anchor resolves the side when anchor geometry is unavailable.

The fallback promises continuous entrance or exit throughout the retained visual domain without claiming to
know unloaded geometry. It performs no additional measurement.

## Transaction Data Flow

For a structural `applyChanges` pass:

1. Capture the transaction clock, old active-window settled state, and analytic state for unfinished
   crossing carries.
2. Resolve the anchor and build the ordinary new settled `activeWindow` exactly as today.
3. Compute shared, outgoing-crossing, incoming-crossing, inserted, and removed identities.
4. Derive exact shared-survivor displacement samples from available endpoint geometry.
5. Infer one missing endpoint for each crossing survivor using the nearest valid sample or retention-boundary
   fallback.
6. Move old-only survivor views into the crossing overlay with implicit actions disabled. Write their
   synthetic settled bases and start or replace their existing live position properties from analytic
   current presentation.
7. Reuse or create the ordinary active-window views for new-only survivors, write final settled frames, and
   start their live position properties from inferred old endpoints.
8. Run existing insertion fades, ghost formation/migration, shared-survivor position and height transitions,
   and viewport animation composition independently.
9. Release outgoing carries only through exact generation-safe position completion.

A zero-duration structural pass writes the inferred/final state immediately and releases outgoing carries
without installing a track.

## Composition and Interruption

### Promotion and demotion

On every later pass, an identity has at most one view across `activeWindow` and the crossing overlay.

- If an outgoing carry enters the new active window, promote the same view into the live container, retain
  `.live(identity)`, sample its analytic current position, and retarget normally.
- If an active survivor leaves the new active window, demote the same view into the crossing overlay and
  install its inferred transition.
- If a carry remains outside and a related structural pass changes its inferred target, retarget only its
  position property from analytic current presentation.
- If a pass does not change the carry's endpoint, preserve its exact track, generation, phase, curve,
  deadline, completion, and installed CA key.

This makes `+5` followed mid-flight by `-5` a promotion of the same carried views rather than destruction and
recreation.

### Genuine removal of a carry

If a carried identity leaves the collection before its crossing completes, sample its current analytic
position, height, and opacity and transfer the view into the ordinary ghost/exit path. Adjacent carried
departures may form the same contiguous ghost-block representation as other loaded departures. The stale
crossing-position completion must become inert.

### Scrolling and coordinate rebases

Pure user scrolling does not create, replace, or restart crossing tracks. The crossing overlay scrolls with
the content hierarchy.

Coordinate rebases shift each crossing view's settled base by the same exact delta applied to the scrolling
content and ghost overlay. The analytic additive position correction and its generation remain unchanged.

User-scroll rebalancing may promote a carried identity when it becomes part of the active window, but ordinary
scroll unloading does not manufacture structural crossing animations.

### Programmatic viewport animation

The parent `viewportOffset` track remains independent. A crossing survivor's local live-position correction
composes additively beneath it.

If a mixed pass also requires viewport carry behavior, the identity must still have only one physical carried
view. Carry selection and view reuse must deduplicate by identity; viewport and local position generations
must not independently remove the same view.

## Completion and Storage

Outgoing carry cleanup is position-generation-specific:

- completion removes the view only if it is still outside `activeWindow` and the recorded live position
  generation remains current;
- promotion, retargeting, genuine removal, reset, or view replacement invalidates the old release;
- an early callback reschedules or remains inert according to the controller's existing analytic-deadline
  rules;
- after release, settled unbound live-owner state follows the existing pruning policy;
- reset and populated-to-empty paths remove every crossing view and record.

No display link is introduced. Production motion remains analytic state rendered by additive
`CAKeyframeAnimation`.

## Testing Requirements

### Membership boundary regressions

- A five-row insertion keeps every old-only loaded survivor at its exact pre-pass presentation at time zero,
  assigns the inferred tail displacement, and retains it until generation-safe completion.
- Removing the same block installs every new-only survivor at its inferred old presentation and moves it into
  its settled frame without opacity animation.
- Equivalent tests cover variable row heights, insertion/removal above and below a scrolled anchor, and both
  retention edges.

### Measurement boundary

- Instrument item creation and `update(width:)` calls.
- Prove that no identity outside `old rendered survivors union new active-window survivors` is instantiated or
  measured for crossing inference.
- Large changed ranges must not expand the active window or preload margin.

### Composition

- `+5` followed mid-flight by `-5` promotes the same view instances and is C0-continuous for every crossing
  identity.
- Repeated insertion/removal and multiple separated changed regions use local displacement samples.
- Unrelated passes preserve exact crossing generations and CA metadata.
- A changed crossing target replaces only position from analytic current presentation.
- A carried identity genuinely removed mid-flight converts continuously into the ghost path.
- Coordinate rebasing and user scrolling preserve crossing tracks.
- Programmatic viewport motion composes without duplicate views or double cleanup.

### Fallback and lifecycle

- Ambiguous move/reorder crossings use the correct retention-boundary fallback and never measure extra items.
- Zero-duration passes release outgoing carries immediately and seed incoming survivors at settled geometry.
- Stale position completions cannot remove promoted, retargeted, rebound, or ghost-converted views.
- Long mutation sequences leave no crossing records, views, bindings, or model owners after all tracks settle.

### Core Animation parity

Paused-layer tests compare analytic and emitted additive position values for outgoing and incoming crossing
survivors at the start, intermediate samples, and deadline. Slow Animations scaling is applied exactly once.

## Non-Goals

- Reconstructing or measuring exact geometry outside the loaded retention domain.
- Expanding `activeWindow`, `preloadMargin`, or the settled scroll range for animation.
- Giving surviving crossing rows opacity fades.
- Replacing granular identity/property tracks with a container animation or rigid tail animation.
- Introducing `UIViewPropertyAnimator`, a display-link renderer, or presentation-layer readback.
- Redesigning ghost boundary witnesses or programmatic carousel geometry except where one physical view must be
  deduplicated across carry roles.

## Success Criteria

The feature is complete when large structural changes are visually indistinguishable from ordinary granular
position animation throughout the viewport-plus-preload domain: rows crossing out remain present and move out;
rows crossing in begin outside and move in; interruptions remain C0-continuous; no unrelated track restarts;
and no item outside the old/new rendered union is loaded or measured.
