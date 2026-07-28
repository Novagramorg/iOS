# CoreListTransition: a ComponentTransition-shaped animation descriptor for CoreList

Date: 2026-07-27
Status: implemented 2026-07-27 (`2e50799` … `d31a0c8`); see the "as built" note in section 9

## Problem

CoreList speaks its own animation vocabulary. `ListAnimationSpec(duration:curve:)` with a two-case
`ListAnimationCurve` (`smoothstep`, `easeOut`) is the descriptor every mutation carries, and 20
`CATransaction` blocks scattered across six files express "write this settled value without an
implicit animation" and "run this when the animation finishes".

Nothing in that vocabulary reaches the rest of the app. Telegram animates through
`ComponentTransition` (`submodules/ComponentFlow/Source/Base/Transition.swift`): a
`duration + curve` value with imperative setters. A `CoreListItem` that wants to animate its own
content on a reconcile has no way to learn what the enclosing pass is doing, because `apply(to:)`
receives no transition at all.

Three changes follow:

1. Replace `ListAnimationSpec`/`ListAnimationCurve` with a vendored type whose shape is
   case-for-case identical to `ComponentTransition`.
2. Pass that transition into `CoreListItem.apply(to:transition:)` and
   `CoreListItemView.update(width:transition:)`.
3. Route every `CATransaction` use through one scope primitive on that type.

CoreList cannot depend on ComponentFlow — its Bazel target has no `deps`, and the demo builds
standalone in Xcode — so the type is a self-contained copy, not an import.

## Non-goals

`ListAnimationModel` remains the sole presentation authority. Tracks, generations, C0-continuous
retargeting, and `CoreAnimationCompiler`'s explicitly-timed `CAKeyframeAnimation` output are
untouched. The transition supplies `duration + curve` to that model and serves as an executor for
item-owned content animation; it does not replace the model. Every invariant in the module's
"Granular animation contract" survives verbatim.

## Design

### 1. The vendored type

Three new files under `CoreListDemo/Transition/`, depending on nothing beyond UIKit/QuartzCore.

**`CoreListTransition.swift`** — the value type, case-for-case identical to `ComponentTransition`:

```swift
public struct CoreListTransition {
    public enum Animation {
        public enum Curve {
            case easeInOut, easeIn, spring, linear
            case custom(Float, Float, Float, Float)
            case bounce(stiffness: CGFloat, damping: CGFloat)
            public func solve(at offset: CGFloat) -> CGFloat
            public static var slide: Curve { .custom(0.33, 0.52, 0.25, 0.99) }
        }
        case none
        case curve(duration: Double, curve: Curve)
    }
    public var animation: Animation
    // immediate / easeInOut(duration:) / spring(duration:)
    // withAnimation / withAnimationIfAnimated / userData / withUserData
}
```

**`CoreListTransition+Curve.swift`** — a copy of `Display/Source/Spring.swift`'s `bezierPoint`
Newton solver (~55 lines of pure math). `.easeInOut` → `bezierPoint(0.42, 0, 0.58, 1)`,
`.easeIn` → `(0.42, 0, 1, 1)`, `.linear` → identity: the same formulas `ComponentTransition.solve`
reaches through Display's `listViewAnimationCurve*` constants.

**`CALayer+CoreListAnimate.swift`** — a self-contained
`animate(from:to:keyPath:duration:delay:curve:removeOnCompletion:additive:completion:key:)` for the
imperative setters, scaling duration by `UIView.animationDurationFactor` exactly as Display's
equivalent does.

`ListAnimationSpec` and `ListAnimationCurve` are deleted. `ListAnimationTrack.curve` becomes
`CoreListTransition.Animation.Curve`; `scaled(by:)` moves to an extension on `CoreListTransition`.

### 2. Curve vocabulary: ComponentTransition's cases only

No bespoke curve names and no bespoke factories. Production, demo, and app sites all use
`.easeInOut`. The tests reintroduce `.linear` purely as the contrast curve that keeps their curve
*identity* assertions meaningful (`XCTAssertEqual(track.curve, …)` needs two distinguishable
curves to prove a pass's curve reached its track).

This is a deliberate, reviewable motion change:

| today | after |
|---|---|
| `.smoothstep` = `x²(3−2x)` | `.easeInOut` = `bezierPoint(0.42, 0, 0.58, 1)` — both symmetric S-curves, ≈0.03 max deviation |
| `.easeOut` = `1−(1−x)³` | `.easeInOut` — ComponentTransition has no plain ease-out case |

For the record, both old curves *are* cubic béziers — `smoothstep` is `.custom(1/3, 0, 2/3, 1)` and
`easeOut` is `.custom(1/3, 1, 2/3, 1)`, because control-x at 1/3 and 2/3 makes `x(t) = t`
identically. Preserving them was therefore possible and was rejected in favour of the smaller
vocabulary.

**Measured caveat on that identity** (found while implementing, and it matters for the migration
below): the identity is exact in real arithmetic but not in the enum. `Curve.custom` carries `Float`
payloads — that is ComponentTransition's own case shape, which the vendored copy matches — so `1/3`
and `2/3` round to float32 (`0.3333333432674408`, `0.6666666865348816`) and `x(t)` drifts from `t`.
The realized worst-case deviation over `[0, 1]` is **1.7e-8 in progress**: 4e-7 pt on a 25 pt extent,
1.7e-6 pt on a 100 pt extent. Physically nil, but above the existing suite's `accuracy: 1e-9` on
curve samples, so those assertions need their *tolerance* loosened (not their values changed) during
the type swap. With exact `Double` control points the deviation is 2.2e-16, confirming the `Float`
payload is the entire error. `CoreListTransitionCurveTests` pins the bound at 1e-7 so a future
widening fails loudly.

Two curves cannot be reproduced faithfully, because ComponentFlow resolves both through private
API in `UIKitRuntimeUtils`:

- **`.spring`** — **revised during implementation.** The design said to use
  `bezierPoint(0.23, 1, 0.32, 1)`, Display's pre-iOS-9 fallback. That was wrong: it matches nothing
  the app renders today. Both `ComponentTransition.Curve.spring` and
  `ContainedViewLayoutTransitionCurve.spring` emit via `kCAMediaTimingFunctionSpring`, and
  `CAAnimationUtils.swift:119` resolves that to `controlPoints(0.380, 0.700, 0.125, 1.000)` for every
  duration except two it special-cases with real `CASpringAnimation`s (0.5, and 0.3832 on iOS 26).
  The vendored `solve` therefore samples the adjusted bezier; the two curves differ by up to **0.228
  in progress**, 23% of the travel, so this was a visible error, not a rounding one. At the two
  special-cased durations CoreList still approximates — those are real springs behind private
  `UIKitRuntimeUtils` API. No current site uses them (the chat backend springs at 0.4).

  Note the adjusted curve is deliberately not what ComponentFlow's own `solve(at:)` returns: that
  routes to `listViewAnimationCurveSystem`, which samples the 0.5s `CASpringAnimation`, so
  ComponentFlow's analytic spring and its emitted spring agree only at duration 0.5. CoreList is
  analytic-first — what it samples is exactly what it emits — so it follows the emitted curve.
- **`.bounce(stiffness:damping:)`** — not a unit curve at all. `ComponentTransition.Curve.solve`
  itself `assertionFailure()`s on it and routes to `animateSpring`/`CALayerSpringParametersOverride`.
  The vendored `solve` matches that: asserts in debug, falls back to `.spring` in release.

`bezierPoint` clamps a result ≥ 0.997 to 1.0. Today's `ListAnimationCurve` has no such clamp. For
`.easeInOut` the clamp engages at `x ≈ 0.9606`, so a curve sits at exactly 1.0 for its final ~3.9%
of duration — 12 ms of a 0.3 s pass, 156 ms of a 4 s test pass. This is harmless to the model:
`ListAnimationTrack.isComplete(at:)` is duration-based, not value-based, so a clamped track stays
active until its real deadline, and a retarget sampling that tail reads the exact endpoint. The
clamp is kept for fidelity to ComponentFlow; the analytic model and the keyframe compiler both call
the same `solve`, so parity stays self-consistent.

### 3. Public surface

```swift
public protocol CoreListItem: AnyObject {
    var identity: AnyHashable { get }
    func view() -> UIView & CoreListItemView
    func isEqual(to other: CoreListItem) -> Bool
    func apply(to view: UIView & CoreListItemView, transition: CoreListTransition)
}

public extension CoreListItem {
    func apply(to view: UIView & CoreListItemView, transition: CoreListTransition) {}
}

public protocol CoreListItemView: AnyObject {
    func update(width: CGFloat, transition: CoreListTransition) -> CGFloat
    var onContentDidChange: ((_ animated: Bool) -> Void)? { get set }
}

public func applyChanges(items: [CoreListItem]? = nil,
                         newSize: CGSize? = nil,
                         newInsets: UIEdgeInsets? = nil,
                         scrollTo: (index: Int, pointOffset: CGFloat)? = nil,
                         anchorMode: CoreListAnchorMode = .automatic,
                         transition: CoreListTransition)
```

The parallel duration-only conveniences go away with the spec type: **146 `animationDuration:` call
sites and 68 `logicalDuration:` call sites collapse into the single `transition:` parameter**, since
`.easeInOut(duration:)` is already a `CoreListTransition` static. Mechanically this is a rewrite of
`animationDuration: X` → `transition: .easeInOut(duration: X)`, overwhelmingly in tests, and it
leaves `applyChanges` with the one entry point the module's docs already claim it has. The same
collapse applies to `ListAnimationController.transitionPosition/transitionPositionX/…` and
`InsetRectOverlayAnimator.transition`.

`update(width:transition:)` is a source-breaking change for ~11 conformances (demo `DemoRow`, app
`CoreListNodeHostView`, ~9 test item views). `apply` keeps its no-op default.

### 4. Zero duration is immediate — the one semantic divergence

`ComponentTransition` treats only `.none` as immediate; `.curve(duration: 0, …)` still takes the
animated branch. CoreList's semantics are the opposite and load-bearing: `ListAnimationTrack.value`
returns `to` when `duration <= 0`, the model contract states that a changed zero-duration property
settles immediately, and `applyChanges(animationDuration: 0)` is how roughly half the test suite
expresses "no animation".

```swift
var isImmediate: Bool {
    switch animation {
    case .none: return true
    case let .curve(duration, _): return duration <= 0
    }
}
```

**Every branch in CoreList tests `isImmediate`; none writes `if case .none`.** The bridge preserves
this in both directions because the underlying data is unchanged — only CoreList's interpretation of
a zero duration differs, and that difference already existed.

### 5. When an item view gets a real transition

`update(width:transition:)` has four call contexts and only some should animate:

| call site | transition |
|---|---|
| content reconcile — the row that just received `apply(to:transition:)` | pass transition |
| dirty self-update flush (`consumedDirty`) | flush transition (`dirtyAnimated ? .easeInOut(defaultDirtyDuration) : .immediate`) |
| `seedWindow`/`prependItem`/`appendItem` for a fresh view, a scroll-in load, or an unchanged survivor | `.immediate` |
| off-screen remeasure | `.immediate` |

The reconcile step (`CoreVirtualListView.swift:655`) already knows which identities it
reconfigured, so it records them in a per-pass `reconciledIdentities: Set<AnyHashable>`; window
construction consults that set when measuring. An unchanged survivor measures with `.immediate` —
its content did not change, only its outer geometry, and that is the model's job.

A row's `update` can be called twice in one pass (dirty remeasure, then window construction).
Passing the same transition both times is safe because the vendored setters early-out on an equal
target, exactly as `ComponentTransition.setFrame` does: the second call finds the target already
reached and does nothing.

### 6. Two authorities, one scaling rule

The module's existing rule is that duration scaling happens exactly once, in
`ListAnimationController`. An executor inside the module creates a second path, so the rule becomes
explicit:

- **Model path** — `ListAnimationController` scales by `animationDurationFactor`;
  `CoreAnimationCompiler` receives the final duration and must not scale. Unchanged.
- **Executor path** — the vendored `CALayer.animate` scales internally, as Display's does, so item
  views behave like the rest of the app under Slow Animations.
- **Therefore the transition handed to items is always the logical, unscaled one.** The two paths
  never meet: the compiler never calls the executor, and the executor never touches a model track.

### 7. The CATransaction sweep — superseded, see below

All 20 blocks route through one scope primitive, so `CATransaction` is named in exactly one file:

```swift
extension CoreListTransition {
    /// The module's only CATransaction scope.
    static func commit(disablingImplicitActions: Bool = true,
                       completion: (() -> Void)? = nil,
                       _ body: () -> Void)
}
```

| sites | today | after |
|---|---|---|
| `ListAnimationController.writePositionY/X/Opacity/Height/Width`, `InsetRectOverlayAnimator` (6) | disable-actions + one property write | `.immediate.setPositionY(layer:…)` etc. — the setter owns the scope |
| `CoreVirtualListView` (9) | disable-actions around property writes mixed with `addSubview`/`removeFromSuperview`/`onContentDidChange` assignment | `CoreListTransition.commit { … }` directly; these cannot reduce to setters |
| `CoreAnimationCompiler.install`/`remove` (2) | disable-actions + `setCompletionBlock` | `commit(completion: completion) { layer.add(animation, forKey: key) }` |
| `PhysicsScrollEngine` ×2, `PhysicsScrollView` ×1 | `setCompletionBlock` only — **no** disable-actions | `commit(disablingImplicitActions: false, completion: { … }) { layer.add(flightAnim, …) }` |

The flag exists for that last row: the deceleration-flight sites deliberately do not disable implicit
actions, and their generation-guarded completion drives deceleration handoff. They keep their exact
semantics and merely stop naming `CATransaction`.

**Superseded during implementation.** The sweep first routed all 20 blocks through one
`CoreListTransition.commit` scope, then removed them outright:

- **Completions** moved onto the animation, via a copy of Display's `CALayerAnimationDelegate`
  (`CAAnimationUtils.swift:4`). Every completion site adds exactly one animation and wants exactly
  that animation's completion, so none needed transaction-wide semantics.
- **`setDisableActions` turned out to be unnecessary everywhere.** Every layer CoreList writes is
  UIView-backed — it creates no standalone `CALayer` — and a UIView's layer returns a null action by
  default outside an animation block, so there is no implicit animation to suppress. (The
  `SimpleLayer`/`nullAction` pattern exists for standalone layers, which CoreList has none of.)

`CATransaction` therefore appears nowhere in CoreList, and the grep guard changed from "named in one
directory" to "not named at all".

### 8. Executor surface

Setters CoreList itself needs plus what item views plausibly need: `setFrame(view:/layer:)`,
`setBounds`, `setBoundsSize`, `setBoundsOriginY`, `setPosition`, `setPositionX/Y`, `setAlpha`,
`setScale`, `setTransform`, the `animate*` primitives, and `animateView`. Each early-outs on an
equal target, as `ComponentTransition` does.

`animateView`'s curve → `UIView.AnimationOptions` mapping reproduces `.linear/.easeIn/.easeInOut/
.spring` (`7 << 16` is a raw value, not private API); `.custom` and `.bounce` degrade to
ease-in-out options, since faithful handling needs `CALayerSpringParametersOverride`. Documented in
the file header alongside the `.spring`/`.bounce` `solve` gaps.

Shape-layer, gradient, blur, mesh, parabolic, and keyframe-transform helpers are **not** vendored.
They have no CoreList consumer, and several cannot work without the private APIs.

### 9. Host bridge

`CoreListTransition` is a distinct name so a file importing both CoreList and ComponentFlow is never
ambiguous.

**As built** (revised during implementation): the conversion lives in
`submodules/TelegramUI/Sources/CoreListChatHistoryBackend.swift`, its only consumer, rather than a
dedicated bridge file, and only the forward direction exists:

```swift
extension ComponentTransition { init(_ transition: CoreListTransition) }
```

The design originally called for a standalone `CoreListTransitionBridge.swift` carrying both
directions. The reverse direction had no caller, so it was dropped rather than shipped as speculative
API. The forward init deliberately does NOT round-trip a zero duration: CoreList reads that as
immediate, so the conversion yields `.immediate` instead of a zero-length animation, which is what a
consumer co-animating its own chrome needs.

## Files

```
CoreList/CoreListDemo/Transition/
    CoreListTransition.swift            value type, setters, commit()
    CoreListTransition+Curve.swift      bezierPoint solver + solve(at:)
    CALayer+CoreListAnimate.swift       animate(from:to:keyPath:…), duration scaling
TelegramUI/Sources/CoreListChatHistoryBackend.swift  ComponentTransition.init(_:) (as built)
```

Modified: `CoreVirtualListView.swift`, `ListAnimationModel.swift`, `ListAnimationController.swift`,
`CoreAnimationCompiler.swift`, `InsetRectOverlayAnimator.swift`, `PhysicsScrollEngine.swift`,
`PhysicsScrollView.swift`, `DemoRow.swift`, `ViewController.swift`,
`TelegramUI/Sources/CoreListChatHistoryBackend.swift`, and the test suite.

Deleted: `ListAnimationSpec`, `ListAnimationCurve`, and the `animationDuration:`/`logicalDuration:`
overload family.

## Verification

- **Demo suite on iPhone 17 Pro K2**, `-parallel-testing-enabled NO`. Currently 480/480; every test
  compiles against the new signatures. **Twelve** shape-dependent literals across three test files
  are recomputed from the bézier solver, not guessed:

  | literal | sites | new value |
  |---|---|---|
  | `0.15625` (opacity, phase 0.25) | `CoreVirtualListAnimationTests:1171`, `:2562` | `0.12916193104731982` |
  | `78.90625` (height 75→100, phase 0.25) | `CoreVirtualListAnimationTests:2601`; `ListAnimationModelTests:129`, `:136`, `:138`, `:257`, `:305`, `:308`, `:468` | `78.229048276182994` |
  | `15.625` (0→100, phase 0.25) | `ListAnimationModelTests:14` | `12.916193104731983` |
  | `57.8125` (the ex-`easeOut` contrast case) | `ListAnimationModelTests:15` | `25.0` under `.linear` |

  `ListAnimationModelTests:308` compares exactly, with no `accuracy:` argument; it gains
  `accuracy: 1e-9`, because the new value is not a short decimal literal.

  Assertions sampling phase 0 or phase 0.5 are **unaffected** — both the old and new curves are
  symmetric about `(0.5, 0.5)`, and `bezierPoint(0.42, 0, 0.58, 1, 0.5) == 0.5` exactly. That covers
  `ListAnimationModelTests:75`–`:77`, `:102`, and `:105`. The compiler-parity assertions
  (`CoreAnimationCompilerParityTests:168`–`:169`) compare model against compiler and are
  curve-agnostic by construction.
- **New tests:**
  - `CoreListTransitionCurveTests` — per-case `solve(at:)`, endpoints exactly 0 and 1, monotonicity,
    `.easeInOut` equals `bezierPoint(0.42, 0, 0.58, 1)`, `.bounce` asserts.
  - `isImmediate` semantics — `.curve(duration: 0)` behaves identically to `.none` through
    `applyChanges`: no track installed, property settles. This is the divergence from ComponentFlow,
    so it gets a dedicated test.
  - Transition-propagation probe — an item view recording `(call, transition)` pairs, asserting the
    section-5 table, and that `apply(to:transition:)` receives the pass transition.
- **Grep guard:** `grep -rn CATransaction CoreListDemo/ | grep -v Transition/` must be empty.
- **Full Bazel app build** (`Telegram/Telegram`) — the chat backend's item and host view change
  signatures and the bridge file is new.
- **Manual on K2 and the simulator:** the demo's animation controls, and a chat with the
  `coreListChatBackend` flag enabled. The `.easeOut` → `.easeInOut` swap is a real if small motion
  change and deserves one look.
- **Docs:** CoreList `CLAUDE.md` — the item-protocol section, curve names in the granular-animation
  contract, and two new gotchas (zero duration is not `.none`; the two-authority scaling rule).

## Risks

- **Motion change is intentional but broad.** Every CoreList animation switches curve. The demo and
  the chat backend both need a visual pass; nothing automated can catch "feels wrong".
- **`.spring` and `.bounce` are lossy.** A host passing either gets an approximation. Acceptable
  because CoreList adopts neither as a default, but it must be documented at the type, not only here.
- **The zero-duration divergence is invisible at the type level.** A reader who knows
  `ComponentTransition` will assume `.curve(duration: 0)` animates. The `isImmediate`-only rule and
  its test are the mitigation.
- **Mechanical churn is large** (~214 call-site rewrites, ~11 protocol conformances). Almost all of
  it is in the test suite, where the compiler catches every miss, so the risk is tedium rather than
  defect.
