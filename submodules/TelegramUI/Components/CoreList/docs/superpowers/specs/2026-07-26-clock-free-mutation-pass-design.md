# Clock-Free Mutation Pass Design

**Date:** 2026-07-26
**Status:** IMPLEMENTED / CURRENT (2026-07-26)
**Outcome:** the reported symptom — occasional stutter while flinging a virtualized list — is **gone**,
confirmed by the user in the running app after all three follow-ups landed. Everything below was measured in
the deterministic harness; that in-app check is the only evidence that the harness was measuring the right
thing.
**Validation:** fix applied and measured in an isolated worktree (lurch 0.00 in every cell against an
instrument the fix does not touch; 500/500 suite green, no new failures), plus six audit lenses and adversarial
refutation. See Amendments below — several original claims were wrong and are corrected in place.

## Goal

A list mutation pass that runs while a `.keyframe` flight is in the air must not move the content. Today
it re-places the content exactly where it was when the pass *started*, discarding the flight advance that
happened during the pass — a backward lurch of `velocity × pass duration` on every mid-flight
`applyChanges`. The fix is to stop reporting an animation sample as the scroll position: `ScrollEngine.offset`
becomes the physics core's own offset, which the driver advances once per frame, so the deceleration's shape,
duration and very existence are invisible to every consumer outside the engine.

## Root Cause

`PhysicsScrollCore.offset` reports the CA animation's additive **base** instead of the scroll position, and
`PhysicsScrollEngine` papers over that by clock-sampling the flight.

```swift
// PhysicsScrollCore.swift:44
var offset: CGFloat { contentHost.bounds.origin.y }
```

During a `.keyframe` flight the host layer's `bounds.origin.y` is parked at `trajectory.finalOffset` (plus
accrued shifts) — the flight's **destination**, because that is what an additive keyframe animation must be
based on to resolve to zero at settle. It is an artifact of `boundsOriginKeyframeAnimation`, not a position.

The authoritative scroll position already exists next to it: `physics.y.offset`, which every computation
inside the core uses (`PhysicsScrollCore.swift:64, 73, 120, 151, 163, 194, 201, 203`) and which the driver
advances exactly once per frame — `.stepped` through `core.step`, `.keyframe` through `beginTick`'s
`core.reseedDeceleration(offset: liveOffset(now:), …)`. It is per-frame stable, expressed in the list's
coordinate, and owes nothing to the flight's shape, duration or existence.

`PhysicsScrollEngine` saw that `core.offset` was wrong mid-flight and reached for the clock rather than
fixing the accessor (`PhysicsScrollEngine.swift:72-75`):

```swift
/// During a `.keyframe` flight the host's `bounds.origin.y` model is parked at the trajectory's
/// `finalOffset` (the additive animation carries the path), so the live position must come from the
/// flight sample, not `core.offset`.
var offset: CGFloat { flight.map { $0.liveOffset(now: localNow()) } ?? core.offset }
```

That is what turned `ScrollEngine.offset` from a per-frame-stable value into a function of the clock, and
every consumer written against the old contract inherited a clock.

### How that reaches the list

For `UIKitScrollEngine` and `.stepped` physics `ScrollEngine.offset` is a model value: it changes only when
the code changes it (`setOffset`/`applyShift`, or a `contentSize` shrink clamping `bounds.origin.y`). Reading
it twice in a row yields the same number, so differencing two reads yields exactly the shift the code applied
in between — a pattern the list uses in four places.

Under a `.keyframe` flight it is a function of the clock, and
`CoreVirtualListView.applyChanges` reads it at least twice, with all of the pass's measurement work in
between:

- `:539` — `let oldBoundsOriginY = engine.offset` — the snapshot every geometry decision is built from
  (`oldSettledOffset`, `presentationOverscroll`, the anchor witness and its preserved distance).
- `:832` — `setBoundsOriginY(newBoundsOriginY)` → `:1347` — `applyEngineShift(y - engine.offset)` — the
  final coordinate re-base, measured against a **second, later** sample.
- `:849` — `let transactionOffset = engine.offset` — a **third, later** sample, feeding
  `oldLiveEdgeCoordinateShift` (`:850`), every ghost/crossing coordinate (`:850-1284`) and the shared viewport
  track's `from` (`:989-1071`). Collapsing all three to one value is therefore a correctness fix for viewport
  and ghost geometry too, not only for the re-base.

Between them: `settledState`, `crossingCarryState`, content reconcile + remeasure, `resolveAnchor`,
`buildWindow` (which creates and measures newly loaded rows), `computeContainerOriginY`, `render()`.

So the pass preserves the anchor against sample #1 and then re-bases the coordinate so that sample #2 sits
at the target — pinning the content to where it was at sample #1.

## Answering the Design Question: Why Read the Live Position At All?

The flight is purely additive over a parked model, so one might expect the pass to need no live value at
all. The algebra says something sharper: **any single consistent value works exactly, and two values fail
by exactly their difference.**

Write the anchor row's on-screen position as

```
A(t) = containerOrigin + localY − presented(t),   presented(t) = model + delta(t)
```

`delta(t)` is the additive keyframe. A mutation pass rewrites `containerOrigin`, `localY` and `model`, and
never touches `delta`. Let `V` be whatever value the pass reads for "the current viewport" and let the pass
end with `applyEngineShift(newBoundsOriginY − V)`. The pass's own contract is that it preserves the anchor
measured against `V`:

```
containerOrigin_new + localY_new − newBoundsOriginY  =  containerOrigin_old + localY_old − V
```

Substituting, the post-pass screen position is

```
A_new(t) = (containerOrigin_old + localY_old − V) + V − presented_old(t) = A_old(t)
```

**`V` cancels identically.** Continuity does not depend on the value being current, or even correct — only
on it being the *same* value on both sides. Use `V₁` for the geometry and `V₂` for the re-base and the
residual is exactly `V₂ − V₁`, which for a live-sampled offset is `velocity × pass duration`. That is
precisely the measured lurch.

So the pass needs no live value at all — it needs *a* scroll position, and there must be exactly one.

That one position is `physics.y.offset`: advanced once per frame by the driver, expressed in the list's
coordinate, and independent of the animation's shape, duration or presence. `resolvePreservedAnchor`
(`:1475-1487`) picks the row crossing `oldSettledOffset + oldTopInset` and preserves that row's distance from
the inset edge; with `engine.offset` sourced from the physics, `oldSettledOffset = clamp(engine.offset, edges)`
is exactly the notion `CLAUDE.md` already documents — *"mutation anchors use the engine offset clamped to the
currently known loaded edges"*, rubber-band displacement presentation-only — resolved against the settled
model with no animation state in the arithmetic. It behaves identically under `.stepped`.

What must never be read as a position is the host layer's `bounds.origin.y`. It is the additive base of the
emitted keyframe animation, so mid-flight it holds the flight's destination — hundreds to thousands of points
from what the user is looking at. Anchoring on *that* would select a witness near the destination viewport, a
row that is not even loaded, and would load the wrong window. That value is an emission artifact; it belongs
to `boundsOriginKeyframeAnimation` and to nothing else.

Hence: **one physics-owned scroll position per frame, read as many times as anyone likes.**

## Measured Evidence

`CoreListDemoTests/MidFlightPassLurchExperiment.swift` amplifies the defect by making a row's
measure/reconcile advance the injected clock — what a slow row measure costs in production. Metric is the
probe row's presented screen y at the same final clock time, with the pass versus a counterfactual that
only advances the clock.

| flick | pass Δt | y without pass | y with pass | lurch | implied v |
|---|---|---|---|---|---|
| 3000 pt/s | 0.00 ms | −43.00 | −43.00 | 0.00 | — |
| | 1.20 ms | −46.37 | −43.20 | +3.17 | 2.64 pt/ms |
| | 4.80 ms | −56.46 | −43.79 | +12.67 | 2.64 pt/ms |
| | 24.0 ms | −110.26 | −46.96 | +63.30 | 2.64 pt/ms |
| 9000 pt/s | 1.15 ms | −38.85 | −29.61 | +9.25 | 8.04 pt/ms |
| | 4.60 ms | −71.42 | −34.43 | +36.98 | 8.04 pt/ms |
| | 23.5 ms | −249.04 | −64.18 | +184.86 | 7.87 pt/ms |
| stepped control | 23.0 ms | −27.78 | −27.78 | 0.00 | — |

Linear in Δt with the implied velocity constant per flick, `y with pass` equal to the pre-pass screen y to
the digit, zero at Δt = 0, and zero for `.stepped`. The rebake path is not involved: an independent
simulation of `Deceleration.step` → `Trajectory.build` → `spliced` → CA `.linear` evaluation puts the
splice's own error at ≤ 0.35 pt per frame and ≤ 3.3 pt total drift across 400 rebakes, with sub-frame
rebake jitter worth ≤ 0.2 pt. Rebakes correlate with the symptom only because the passes that mutate
content are the passes that change edges.

## Chosen Model

**There is one scroll position — the physics core's — advanced once per frame by whichever driver is
running. The deceleration animation is presentation-only and no consumer outside the engine may sample it.**

No new state is required; the per-frame-stable value already exists. Two lines:

- `PhysicsScrollCore.swift:44` — `var offset: CGFloat { physics.y.offset }` instead of
  `contentHost.bounds.origin.y`.
- `PhysicsScrollEngine.swift:75` and `TestScrollEngine.swift:40` — `var offset: CGFloat { core.offset }`
  unconditionally. The flight leaves the seam entirely.

Supporting facts, all verified in the current code:

- `beginTick` reseeds `physics.y.offset` to the frame's live sample **before** `onScroll`, so the list always
  reads a current value; `rebakeIfNeeded` runs after. The ordering already holds.
- `applyShiftPhysicsOnly` shifts the physics offset, so it stays in the list's coordinate across a container
  re-base.
- With no flight, `writeOffset` keeps the layer and physics offsets equal, so the change is a no-op outside a
  keyframe flight, where it becomes correct.
- `finalizeFlight`'s `onScroll?(core.offset)` follows `core.setOffset(f.settledOffset)`, so it is identical
  either way; `catchFlight` keeps sampling `f.liveOffset(now: localNow())` directly — catching a moving flight
  is the one operation that genuinely needs the instant, and it is engine-internal.

This is preferable to freezing a snapshot inside `applyChanges`, or to latching a sampled value in the engine:
it removes the clock from the seam instead of managing it, fixes every consumer including the three
differencing sites below, and needs no lifecycle.

It is *continuity-safe* but not *currency-safe*. By the cancellation above, a pass triggered outside a sampler
tick is exactly continuous regardless of how stale `V` is. Staleness is **not** bounded by one frame:
`KeyframeFlight.beginTick` (`KeyframeFlight.swift:75-78`) is the only reseed and it runs off a main-thread
`CADisplayLink` (`PhysicsScrollEngine.swift:338-344`) while the render server plays the flight regardless — so
staleness equals main-thread busy time since the last tick. Continuity survives; *membership* does not. The
anchor witness (`:1481`), `buildWindow`'s projected load band (`:1614-1616`), `refreshReachedLoadedEdges`
(`:1805`) and the `wasOverscrolledPrePass` 0.5 pt gate (`:588`, `:819-828`) all resolve against that stale
viewport. 9000 pt/s x one 16.7 ms frame = 150 pt against `preloadMargin = 160` (`:251`), so a stalled frame can
leave the leading edge momentarily unfilled until the next tick's `rebalanceActiveWindow` repairs it.

### Invariant

> `ScrollEngine.offset` is the physics scroll position, advanced once per frame. Within one frame every read
> returns the same value, so a mutation pass observes a single coherent position and its coordinate re-base is
> a rigid translation that leaves `delta(t)` — and thus the visible motion — untouched. The host layer's
> `bounds.origin.y` is the emitted animation's additive base, not a position, and no CoreList code may read it
> as one. The invariant is not enforceable against UIKit itself: `UIView.convert` composes ancestor model
> `bounds.origin`, so a host converting through `contentHost` (`CoreListChatHistoryBackend.swift:130-132`)
> receives settled-endpoint geometry mid-flight. That is the pre-existing model-vs-presentation contract of
> every additive CoreList track, including the `viewportOffset` used for programmatic scroll, and is out of
> scope here.

## Call Sites

The two lines above. Plus the differencing patterns, which become **exact** for the physics engine (`setEdges`
never moves `physics.y.offset`, so `:1873-1875` is exactly 0; `applyShift` moves it by exactly `dy`, so
`:2695-2697` is exactly `delta`) — **and which must stay differences.** `UIKitScrollEngine` can clamp both a
`bounds.origin.y` write and a `contentSize` shrink (`UIKitScrollEngine.swift:46-55, 57-77`), and the realized
shift is the only correct amount to move exit-overlay children, ghost roots and crossing carries by. The same
holds for `previousOffset` (`:1533`), which follows a possibly-clamped write. This fix removes the clock from
these sites; it does not license replacing them with a stated delta:

- `CoreVirtualListView.swift:849-850` — `oldLiveEdgeCoordinateShift = transactionOffset − oldBoundsOriginY`
  infers the pass's deliberate shift by differencing; it should be the shift the pass applied. Feeds ghost
  and crossing-survivor geometry (`:850-1284`) and, in the overlap/carousel branches, the shared viewport
  track (`:993-1071`), which moves all content.
- `CoreVirtualListView.swift:1873-1875` — `render()`'s exit-overlay compensation across `setEdges`. Real for
  `UIKitScrollEngine` (a `contentSize` shrink clamps `bounds.origin.y`, `UIKitScrollEngine.swift:68-77`);
  the engine should report that clamp instead of the list inferring it.
- `CoreVirtualListView.swift:2695-2697` — `applyEngineShift`'s own before/after differencing, when it
  already knows `delta`.
- `CoreVirtualListView.swift:1533` — `previousOffset = engine.offset` re-reads instead of using
  `handleUserScroll`'s `currentY` argument; with a physics-sourced offset they coincide. It follows a possibly
  clamped write, so it stays a read.

### The §4(b) halt idiom — `engine.setOffset(engine.offset)`

`CoreVirtualListView.swift:581` (items emptied), `:1353` (`rebuildFromScratch`), `:1401` (**every** `scrollTo`
pass), `:1417` (no-overlap swap). Swift evaluates the argument before the call; `PhysicsScrollEngine.setOffset`
(`:87-90`) then catches the flight at the true instant (`:302-310`) and overwrites it with the argument. Today
the argument *is* that instant, so the clobber is benign; with a physics-sourced offset it is the last tick's
position.

The intermediate write is never presented — one synchronous pass, and the pass ends with an absolute
`setBoundsOriginY` (`:819-832`) — so there is no rewind on screen. The observable is the viewport track's
`from`, built from `oldBoundsOriginY` (`:989-999`), so **these paths were already discontinuous by
`v x pass-work`**; the fix adds `v x (t₅₃₉ − t_lastTick)`, one display frame at most. Only `:1401` with
`animationDuration > 0` is visible at all; `:581`/`:1353`/`:1417` discard or rebuild every live row.

A bare `halt()` is **not** the remedy: leaving `V₂ = live(t₂)` while `V₁` is stale re-breaks
`oldLiveEdgeCoordinateShift` (`:849-850`) and `appliedEngineShift` (`:2607`, `:2634`) by the same amount. The
remedy is one engine-internal sync of `physics.y.offset` to the presented position at pass entry (before
`:539`) — consistency *and* currency — or the non-goal's real answer: re-base/rebake the flight instead of
halting it.

## Non-Goals

- The rebake/re-emit path. Exonerated above; the unreachable-edge filter landed separately.
- The `handleUserScroll` delta clamp (`:1529-1532`), which calls `engine.setOffset` → `catchFlight` and
  kills the fling outright. It needs one tick's delta to exceed a viewport (~89 ms of stall at 9000 pt/s,
  800 pt viewport) — genuinely reachable in the app, but a distinct defect with a distinct fix (a flight
  should be re-based or rebaked, never hard-stopped; the keyframe design's §4 already flags this).
- Pixel-rounding ripple: baked vertices are rounded to `1/scale`, so per-frame deltas ripple by ±1/3 pt at
  `scale: 3`. Inherent to the bake, not pass-related.
- Whether the model should carry rubber-band overscroll during a flight. `presentationOverscroll`
  (`:558`) is computed as `live − clamp(live, edges)` and is 0 mid-list, since `loadedEdgeRange` returns
  `nil` edges unless the window reaches a collection end. Near an end during a flight the notion needs
  its own thinking — overscroll then lives in the animation, not the model — but it is not what produces
  the measured lurch and should not be conflated with it.

## Testing

The deterministic suite is currently blind to this whole class: `SyntheticClock` never advances inside a
pass, so `engine.offset` is constant there by construction and Δt is structurally zero. That is why 498
tests pass over the defect.

- Promote `MidFlightPassLurchExperiment` to a regression test: assert `lurch ≈ 0` (±0.5 pt) across the
  cost sweep and both flick speeds. It fails today by up to 185 pt.
- The regression test needs a ground truth once `offset` stops tracking the clock, since its counterfactual
  measures by advancing the clock and re-reading `engine.offset`. Expose an instantaneous accessor on
  `TestScrollEngine` (test-support only, e.g. `liveOffsetForMeasurement`) and keep the seam clock-free.
- Add a seam test: with a live flight, two `engine.offset` reads separated by a clock advance return the same
  value; a `tick` then moves it.
- **Precondition, same commit, before any assertion is promoted:** the instantaneous accessor. Post-fix both
  arms of the experiment read `engine.offset` (`MidFlightPassLurchExperiment.swift:69-76` for screen y,
  `:112-115` for the counterfactual), so both freeze and `lurch ≡ 0` **even with the bug fully present** —
  deleting `flight?.noteShift(dy)` (`PhysicsScrollEngine.swift:101`) would leave it green. A working
  instrument exists: `TestScrollEngine.liveViewportOffset` plus `MidFlightPassLurchTrueScreenDiagnostic.swift`,
  built during validation, which measures against `flight.liveOffset(now:)` — an expression the fix does not
  touch — and reproduces the pre-fix table to the digit when the fix is reverted.
- Do NOT add the "mid-flight `engine.offset` is the position while `contentHost.bounds.origin.y` is the
  destination" test against `TestScrollEngine`: it never parks the host at `finalOffset` and never bumps it on
  shift (`TestScrollEngine.swift:58-69` vs `PhysicsScrollEngine.swift:99, 233`), so the assertion is
  unwritable there. Re-target it as production-only or drop it.
- Membership staleness: start a flight, `clock.advance` **without** ticking, run `applyChanges`, assert the
  built window still covers `−preloadMargin … height+preloadMargin` measured against the instantaneous
  accessor, not against `engine.offset`.
- Halt-path start-of-animation discontinuity: advance the clock between a tick and
  `applyChanges(scrollTo:, animationDuration: 0.3)`, assert the anchor's presented y at t=0⁺ equals its
  pre-pass presented y within 0.5 pt. **This fails today and after the fix** — land it red or skipped with the
  follow-up rather than hiding it.
- One assertion on `core.offset` after `applyShiftPhysicsOnly` in `PhysicsScrollCoreTests`: it is the only
  method that decouples the two offsets and it is untested either way.
- Re-run the full suite. `.keyframe` numbers change wherever a test advanced the clock without ticking; each
  such change needs reading rather than rebaselining.

## Landed

- `PhysicsScrollCore.swift` — `offset` returns `physics.y.offset`; the y axis is seeded from
  `contentHost.bounds.origin.y` so the identity holds by construction.
- `PhysicsScrollEngine.swift` / `TestScrollEngine.swift` — `offset` is `core.offset` unconditionally; the stale
  doc comment that asserted the opposite is replaced with the contract. `catchFlight` still samples the instant.
- `TestScrollEngine.liveViewportOffset` — the presented viewport, test instrument only.
- `MidFlightPassLurchTests` (replaces the experiment) — lurch ≈ 0 at every pass duration and both flick speeds,
  measured against `liveViewportOffset`; a shape test that lurch no longer scales with pass duration; the
  stepped control; per-frame stability of `engine.offset`; `offset == presented` at every tick boundary; and
  the membership-lag characterization.
- `PhysicsScrollCoreTests` — `offset` follows the physics across `applyShiftPhysicsOnly` (the one method that
  decouples the two, previously untested either way), and the construction-time seed.
- `CLAUDE.md` — seam contract plus a gotcha covering the invariant, the three-reads-per-pass reason it is
  load-bearing, the accepted membership-staleness cost, and the two corollaries (differencing sites stay
  differences; lurch tests must not measure through `engine.offset`).

Suite: 506 tests, 0 failures at the time of this section; 517 after the three follow-ups below.

**Follow-ups, and their outcomes:**

1. ~~The §4(b) halt idiom.~~ **DONE** — `feat(corelist): ScrollEngine.haltMotionInPlace…` +
   `fix(corelist): halt momentum before a pass reads the scroll offset`. A `scrollTo` arriving mid-fling was
   measured starting its viewport animation 65pt from where the content was; the halt moved to pass entry,
   ahead of the first offset read, and all four sites now use an argument-free `haltMotionInPlace()`.
   Note the audit's guess that a bare `halt()` would be insufficient was right about the mechanism but wrong
   about the remedy: hoisting the halt above the first read is what makes `V₁ == V₂`.
2. ~~The `wasOverscrolledPrePass` 0.5 pt gate resolved against a stale sample.~~ **DONE** —
   `fix(corelist): re-anchor the engine on the presented viewport at pass entry`. `syncToPresentedPosition()`
   fixes the gate's input rather than the gate, and with it the anchor witness, the load band and
   `refreshReachedLoadedEdges`. The gate's continuity was already intact (its test passed before the change
   too) — the defect was currency, not continuity.
3. ~~Chat-side destination-space geometry.~~ **DONE** —
   `feat(corelist): presentedFrame(of:) for hosts reading row geometry` +
   `fix(corelist-chat): report presented row geometry, not the flight's destination`. Plan:
   `docs/superpowers/plans/2026-07-26-presented-geometry-for-hosts.md`. Landing it needed a harness fidelity
   fix first (`TestScrollEngine` never parked the host layer, so the defect was inexpressible in tests).

**Which of the three actually mattered is not established.** All three landed before the in-app check, so the
stutter's disappearance is attributed to the set, not to any one of them. If a future change needs to trade one
away, re-verify in the app rather than reasoning from this document — the harness cannot see the symptom, only
the mechanisms.

## Documentation

Landing this requires two doc edits alongside the code: a `📖 Read before changing` pointer to this file in
the scroll-engine-seam section of `CoreList/CLAUDE.md`, and a new entry in its **Non-obvious gotchas** list
stating the invariant — `ScrollEngine.offset` is per-frame stable, never sample it twice expecting a delta,
and the instantaneous position belongs to the engine internals.

## Risks

- **`currentScrollOffset` (`:372`) has zero call sites repo-wide.** Delete it, or document the per-frame
  contract on it — it is the seam through which a future host would silently inherit the clock. Its own doc
  comment ("the current *settled* scroll offset") is false today and becomes true with this change.
- **Flight boundaries.** Launch, catch and finalize must each leave `physics.y.offset` in the list's current
  coordinate. Verified above for every path, but it is the property to re-check if any of them changes.
- **The chat backend reads the parked additive base, not `engine.offset`.** `CoreListChatHistoryBackend`
  contains no `engine.offset` read at all; it converts model geometry through `contentHost`
  (`CoreListChatHistoryBackend.swift:130-132`, and consumers at `:313-341`, `:364-385`, `:469-483`), so for the
  whole momentum phase its visible range, content offset and read tracking are measured in the flight's
  destination viewport. A separate medium-severity defect, untouched by this change, and the highest-ranked
  remaining candidate for the reported stutter (it suppresses mid-flight work, then dumps pagination and
  read-state into one batch at settle).

## Ranked: What Remains

All three originally deferred items are fixed — see Landed — and the reported stutter is gone in the app. The
items below are therefore **theoretical rather than observed**: each is a real mechanism found by reading, none
is currently known to produce a visible symptom. Do not treat this ordering as a bug queue; it is a list of
places to look first if a stutter reappears.

1. **Rebake + CA re-emit at the frame a loaded window first reaches a collection end.**
   `KeyframeFlight.canChangeRemainingMotion` (`:104-109`) is true whenever a finite edge is within
   `edgeClearance` of the remaining extent, so a large container re-base plus a newly reachable finite edge in
   the same frame forces a splice and `removeAnimation`/`add` (`PhysicsScrollEngine.swift:274-290`) at the worst
   moment. The unreachable-edge filter narrowed this; it did not close it.
2. **Undocumented hard stops mid-fling.** `rebuildFromScratch` (`:1361`) and the populated→empty branch
   (`:589`) kill a live flight outright — reachable from a hole reload, a thread switch, or any pass where
   `resolveAnchor` finds no survivor. A dead stop is the largest possible "stutter". They now halt cleanly via
   `haltMotionInPlace()`, but they still halt.
3. **The one-viewport delta clamp** (`:1537-1540`) — already a non-goal above, correctly.
4. **Sub-threshold container re-base.** The rebalance skips engine compensation below 0.5 pt while `render()`
   moves the container unconditionally, so a mixed-height rebalance in that band translates the whole window by
   up to 0.5 pt uncompensated. Composes with the ±⅓ pt bake-rounding ripple.
5. **`previousOffset` not refreshed after `render()`'s `setEdges`**, so a UIKit `contentSize` shrink clamp is
   later differenced as user-scroll delta and can trip the one-viewport clamp. UIKit backend only.
