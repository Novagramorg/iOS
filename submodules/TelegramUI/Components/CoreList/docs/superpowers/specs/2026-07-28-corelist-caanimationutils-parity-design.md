# CAAnimationUtils parity for CoreList

Date: 2026-07-28
Status: design approved, not implemented

## Problem

CoreList emits animations two ways, and neither matches what the rest of the app emits.

`CoreAnimationCompiler` samples an analytic track into a 240 Hz `CAKeyframeAnimation`.
`CALayer.animate` (the executor) samples the same way, except for `.spring`, which since
`dd96b3e` routes to a verbatim copy of `CAAnimationUtils`' treatment. Display's
`CAAnimationUtils.makeAnimation` — what every other Telegram surface animates through — emits a
`CABasicAnimation` with a `CAMediaTimingFunction`, or a real `CASpringAnimation` for two
special-cased durations.

Three consequences:

1. **A chat row under the CoreList backend does not move like a chat row under `ListViewImpl`.** The
   clearest case: chat forwards `updateSizeAndInsets.curve == .Spring(duration:)` straight through,
   and at duration 0.5 `ListViewImpl` renders a real `CASpringAnimation` while CoreList renders a
   sampled adjusted bézier.
2. **The two CoreList emitters can drift from each other.** They already did: `.spring` was fixed in
   the executor and left wrong in the compiler, which is the path all row and viewport motion
   actually takes.
3. The sampling exists to keep `ListAnimationModel` authoritative, but it is not the only way to get
   that. Handing CA the same control points the model solves gives the same guarantee, because CA
   evaluates the same cubic bézier.

**Goal: everything CoreList animates matches `CAAnimationUtils` exactly, except the physics
deceleration flights.** Those are baked trajectories with no curve to match and are out of scope.

## Success criterion

**Rendered motion.** A CoreList row and a `ListViewImpl` row given the same curve and duration move
identically on screen. The emitted object shape follows from that rather than being the goal itself —
but in practice it converges, because matching the motion means emitting what `CAAnimationUtils`
emits.

## Non-goals

- The deceleration flights (`PhysicsScrollEngine`, `PhysicsScrollView`) keep their
  `CAKeyframeAnimation`s. They play a pre-baked trajectory, not a curve.
- `ListAnimationModel` remains the presentation authority for retargeting, deadlines, and reaping.
  This changes how it evaluates curves, not what it decides.

## Design

### 1. One shared factory

`Transition/CoreListCAAnimation.swift` gets a verbatim copy of `CAAnimationUtils.makeAnimation`'s
branch tree, minus the branches CoreList has no caller for (the
`kCAMediaTimingFunctionCustomSpringPrefix` custom-spring parse, and the `mediaTimingFunction`
override):

```swift
func makeCoreListAnimation(from: CGFloat,
                           to: CGFloat,
                           keyPath: String,
                           curve: CoreListTransition.Animation.Curve,
                           springKind: CoreListSpringKind,   // resolved from the LOGICAL duration, see §4
                           scaledDuration: Double,
                           additive: Bool) -> CABasicAnimation
```

| curve | emitted |
|---|---|
| `.easeInOut` / `.easeIn` / `.linear` / `.custom` | `CABasicAnimation` + `CAMediaTimingFunction(controlPoints:)` |
| `.spring`, iOS 26 and `duration ≈ 0.3832` (±0.0001) | `CASpringAnimation` — mass 1, stiffness 555.027, damping 47.118, `allowsOverdamping = false` |
| `.spring`, `duration == 0.5` | `CASpringAnimation` — mass 3, stiffness 1000, damping 500 |
| `.spring`, any other duration | `CABasicAnimation` + `controlPoints(0.380, 0.700, 0.125, 1.000)` |
| `.bounce` | asserts, degrades to `.spring` (unchanged) |

**No `CAKeyframeAnimation` remains on either path.**

Two callers:

- **The executor** (`CALayer.animate`) calls it, attaches the completion delegate, installs. Its
  sampling loop and the spring copy added in `dd96b3e` are deleted — that copy moves into the
  factory, where both callers get it.
- **The compiler** (`CoreAnimationCompiler`) calls it, then applies the properties only the model
  path needs: `beginTime = track.startTime` (in the past on rebind, which is how phase survives),
  `fillMode = .both`, `isRemovedOnCompletion = false` (the controller owns removal by generation),
  the `CoreListAnimation.generation` metadata, and `preferHighRefreshRate()` for position/viewport
  only. It remains the thin place that maps `ListAnimatedProperty` to keyPath and additivity.

### 2. Slow Animations: a deliberate mechanism divergence

`CAAnimationUtils` keeps `duration` logical and sets `animation.speed = 1/k`. CoreList pre-scales
duration in `ListAnimationController` and leaves `speed = 1`.

**Superseded during implementation — CoreList now uses `speed`, matching `CAAnimationUtils`.**

The original decision was to keep pre-scaling, on the grounds that it renders identically and that
the model's deadlines live on the scaled clock. The second half of that is true; the first half made
it look like a free choice, and it was not: the emitted object did not match what the rest of the app
emits, which is the whole point of this work.

Both are now satisfied. `CoreListTransition.scaled(by:)` records the factor it applied in
`appliedDurationFactor`; `ListAnimationTrack` carries it alongside the scaled `duration`; and the
compiler divides it back out so the animation carries a **logical** duration with `speed = 1/factor`.
The model keeps reasoning on the scaled clock, CA plays at logical-duration-and-speed, and the two
describe the same wall time. System springs use `CAAnimationUtils`' own formula,
`speed * (springDuration / logicalDuration)`.

### 3. An exact solver

`Curve.solve(at:)` is currently a verbatim copy of Display's `bezierPoint`: 4-iteration Newton, and
any result ≥ 0.997 clamped to 1.0. Once CA evaluates the bézier, the model has to agree with it.

**Drop the clamp. Keep the 4 Newton iterations. Add a bisection fallback.**

Measured, for `.easeInOut` over `[0, 1]` at 1000 samples:

| | max deviation from the exact bézier |
|---|---|
| 4-iteration Newton alone | 4.441e-16 |
| 4-iteration Newton **+ 0.997 clamp** | 2.924e-03 |

The iteration count is already exact to floating-point; the clamp is the entire error. So removing
it costs nothing in convergence and buys model↔CA agreement.

**Test churn is near zero.** The existing curve-derived expectations sample phase 0.25 and 0.5,
where the difference is 2.8e-17 and exactly 0. Only assertions landing in a curve's final ~4% would
move, and the suite has none. (An earlier estimate in this session put ~34 values at risk; that
conflated the clamp with the iteration count.)

The bisection fallback covers control points where `x'(t) → 0` and Newton cannot invert. None of
CoreList's curves hit it; `.custom` is caller-supplied, so it is reachable in principle.

### 4. Duration-dependent spring, resolved once

`Curve.solve(at:)` takes only a phase, but `.spring` needs the **duration** to know whether it is a
real spring or the adjusted bézier. If the emitter and the model each decided that independently
they could disagree — precisely the drift this work removes. The predicate is therefore defined once
and shared:

```swift
enum CoreListSpringKind { case system26, system05, adjustedBezier }
func coreListSpringKind(logicalDuration: Double) -> CoreListSpringKind
```

`makeCoreListAnimation` switches on it to choose the animation; `ListAnimationTrack.value(at:)`
switches on it to choose the evaluator. One predicate, two consumers, no way to diverge.

**The predicate reads the LOGICAL duration, never the scaled one.** This is load-bearing and easy to
get wrong. `0.5` and `0.3832` are logical durations — `CAAnimationUtils` sees them unscaled because
it handles Slow Animations with `speed`. CoreList pre-scales (§2), so a naive
`coreListSpringKind(duration:)` fed the scaled value would see `5.0` under a ×10 drag coefficient,
miss the `system05` branch, and silently emit the adjusted bézier instead of the real spring — a
Slow-Animations-only divergence, i.e. one that only appears where it is hardest to notice.

Both paths therefore resolve the kind *before* scaling:

- **Model path:** the kind is resolved by `ListAnimationController` from the logical transition and
  stored on `ListAnimationTrack` alongside the scaled `duration`, so the track's own
  `value(at:)` and the compiler's emission both read the same already-resolved value.
- **Executor path:** `CALayer.animate` resolves the kind from its logical `duration` parameter before
  applying `animationDurationFactor`, then passes both the resolved kind and the scaled duration to
  the factory.

`ListAnimationTrack` gains one field for this; it does not gain the logical duration itself, since
nothing else needs it.

### 5. The model evaluates system springs

`ListAnimationModel` gains `import QuartzCore`. For `.system26` and `.system05` it evaluates through
`valueAt:` on a cached `CASpringAnimation` — one instance per kind, since building one per query
would be absurd and the `.system26` branch is a single duration by construction.

The private selector is reached through an `@objc protocol` + `unsafeBitCast` shim in the Transition
directory, so CoreList takes no Bazel dependency and the standalone demo still builds:

```swift
@objc private protocol CoreListSpringValueAt {
    @objc(valueAt:) func value(at t: CGFloat) -> CGFloat
}
```

CLAUDE.md's "UIKit-free" claim for the model becomes "Foundation, CoreGraphics, QuartzCore".

**`valueAt:`'s time domain is unverified and must be pinned first.** Display calls
`springAnimationValueAt(springAnimationIn, t)` with `t ∈ [0, 1]` from `listViewAnimationCurveSystem`,
which implies a normalized phase — but that animation is built with `duration: 0.5`, so seconds is
equally plausible, and guessing wrong yields a silently wrong curve rather than an error. The first
implementation task is a test evaluating at t = 0, 0.25, 0.5, 1.0 and asserting the endpoints are 0
and 1. If it turns out to be seconds, the model multiplies phase by the spring's own duration.

## Testing

The strongest oracle already exists. `CoreAnimationCompilerParityTests:260-273` sets `layer.speed = 0`,
sweeps `timeOffset` across a track, reads `presentation().position.y`, and compares against
`track.value(at:)`. That measures rendered-motion-against-model directly, which *is* the success
criterion, so it survives untouched and becomes the primary parity mechanism rather than a
supporting check.

**Extended, not replaced:** the same sweep runs per curve — `.easeInOut`, `.easeIn`, `.linear`,
`.custom`, `.spring` at 0.4 (bézier branch), and `.spring` at 0.5 and 0.3832 (system branches). That
parameterized test is the 100%-match proof.

Tests that must change:

| site | change |
|---|---|
| `CoreAnimationCompilerParityTests`, 8 × `as? CAKeyframeAnimation` | cast to `CABasicAnimation` / `CASpringAnimation` |
| same file, `:163-169` (`values.count == 31`, first/last) | delete — the sampled array no longer exists, and the paused-layer sweep covers what it approximated |
| `MixedPassStressOracle.validateTrack:460` | relax the cast to `CAAnimation`; its generation / `beginTime` / `duration` checks are unaffected |

Verification: full suite on iPhone 17 Pro K2 with `-parallel-testing-enabled NO`; full Bazel
`debug_sim_arm64` build; and a grep guard that `CAKeyframeAnimation` appears only in the deceleration
paths (`KeyframeFlight`, `Trajectory+Keyframe`, `PhysicsScrollEngine`, `PhysicsScrollView`).

## Files

```
Transition/CoreListCAAnimation.swift        CREATE — factory, coreListSpringKind, valueAt: shim
Transition/CoreListTransition+Curve.swift   exact solver; clamp removed; spring dispatch moves out
Transition/CALayer+CoreListAnimate.swift    delete sampling loop and the local spring copy; call factory
CoreAnimationCompiler.swift                 call factory; keep model-path properties and keyPath map
ListAnimationModel.swift                    import QuartzCore; system-spring evaluation via the shim
CoreListDemoTests/…                         parity casts, paused-layer sweep, oracle cast
CLAUDE.md, docs/plans/CHANGELOG.md          contract updates
```

## Risks

- **`valueAt:` time domain** — pinned by a test before anything else is built.
- **Private selector absent on a future OS.** The shim does a `responds(to:)` check and both the
  model and the emitter fall back to the adjusted bézier — degraded but *consistent*, never a crash.
  The selector already ships via Display's `UIKitRuntimeUtils`, so this adds no new App Store
  exposure.
- **Executor-path item views** get `CABasicAnimation` where they got keyframes. `DemoRow` is the only
  caller and the motion is equivalent by construction.
- **Model/CA agreement for system springs** rests on `valueAt:` being the same evaluator CA renders
  with. It is the API Display uses for exactly this purpose, and the paused-layer sweep verifies it
  empirically per curve.
