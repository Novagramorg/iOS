# CAAnimationUtils Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every animation CoreList emits — except the physics deceleration flights — identical to what Display's `CAAnimationUtils` emits, so a chat row under the CoreList backend moves exactly like one under `ListViewImpl`.

**Architecture:** One shared factory holds a verbatim copy of `CAAnimationUtils.makeAnimation`'s branch tree; both the executor (`CALayer.animate`) and the model path (`CoreAnimationCompiler`) call it, so `CAKeyframeAnimation` disappears from both. `ListAnimationModel` stays the presentation authority but changes how it evaluates curves: exact béziers for the timing-function branches, and the private `valueAt:` for the two real-`CASpringAnimation` branches.

**Tech Stack:** Swift 5, UIKit, QuartzCore, one ObjC-runtime shim. No new module dependencies. Design: [`../specs/2026-07-28-corelist-caanimationutils-parity-design.md`](../specs/2026-07-28-corelist-caanimationutils-parity-design.md).

## Global Constraints

- **Working directory:** `submodules/TelegramUI/Components/CoreList` for all `xcodebuild` commands.
- **Simulator:** only `iPhone 17 Pro K2`. If unavailable, stop and ask.
- **Every test command** passes `-parallel-testing-enabled NO` AND `-collect-test-diagnostics never`. Without the latter, any run containing a failing test hangs forever in `collectSimulatorDiagnostics` — which is exactly the TDD red step. See CLAUDE.md's Build/Test section.
- **Baseline: 559 tests passing.** Any task ending below that is not done.
- **Commit hygiene:** stage only task-named files with explicit paths. Never `git add .`/`-A`. Never amend, never push.
- **Branch:** stay on the current branch. Do not switch or create branches.
- **The deceleration flights are out of scope.** `KeyframeFlight`, `Trajectory+Keyframe`, and the `CAKeyframeAnimation`s in `PhysicsScrollEngine`/`PhysicsScrollView` are untouched.
- **`ListAnimationModel` keeps its authority.** This changes how it evaluates curves, not what it decides about tracks, generations, deadlines, or reaping.
- **The spring-kind predicate reads the LOGICAL duration, never the scaled one.** `0.5` and `0.3832` are logical values; CoreList pre-scales for Slow Animations, so resolving from a scaled duration silently misses the system-spring branches under a drag coefficient.
- **Duration scaling still happens exactly once, in `ListAnimationController`.** The factory receives an already-scaled duration and sets `speed = 1`. This is the one intentional divergence from `CAAnimationUtils`, which instead keeps duration logical and sets `speed = 1/k`.
- **Exact spring constants** (from `UIKitUtils.m:53`, `:68`): 0.5-branch = mass 3.0, stiffness 1000.0, damping 500.0, duration 0.5. iOS-26 branch = mass 1.0, stiffness 555.027, damping 47.118, `allowsOverdamping = false`, `preferredFrameRateRange(80, 120, 120)`.
- **Adjusted spring bézier:** `controlPoints(0.380, 0.700, 0.125, 1.000)`.

**Test commands:**

```bash
# full suite
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro K2' \
  -parallel-testing-enabled NO -collect-test-diagnostics never test

# one class
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro K2' \
  -parallel-testing-enabled NO -collect-test-diagnostics never test \
  -only-testing:CoreListDemoTests/CoreListSpringValueAtTests
```

---

## File Structure

| File | Responsibility |
|---|---|
| `CoreListDemo/Transition/CoreListSpringAnimation.swift` | **Create.** The two `CASpringAnimation` factories, `CoreListSpringKind`, `coreListSpringKind(logicalDuration:)`, and the `valueAt:` shim with its `responds(to:)` fallback. |
| `CoreListDemo/Transition/CoreListCAAnimation.swift` | **Create.** `makeCoreListAnimation(…)` — the verbatim `CAAnimationUtils.makeAnimation` branch tree. |
| `CoreListDemo/Transition/CoreListTransition+Curve.swift` | Exact solver: clamp removed, Newton with early exit, bisection fallback. |
| `CoreListDemo/Transition/CoreListTransition.swift` | `springKind` stored on the transition, resolved at init from the logical duration, preserved by `scaled(by:)`. |
| `CoreListDemo/Transition/CALayer+CoreListAnimate.swift` | Delete the sampling loop and the local spring copy; call the factory. |
| `CoreListDemo/CoreAnimationCompiler.swift` | Call the factory; keep the model-path properties and the `ListAnimatedProperty` → keyPath/additivity map. |
| `CoreListDemo/ListAnimationModel.swift` | `import QuartzCore`; `ListAnimationTrack.springKind`; system-spring evaluation. |
| `CoreListDemoTests/CoreListSpringValueAtTests.swift` | **Create.** Pins `valueAt:`'s time domain. |
| `CoreListDemoTests/CoreAnimationCompilerParityTests.swift` | Casts updated; sampled-array test deleted; paused-layer sweep parameterized per curve. |
| `CoreListDemoTests/TestSupport/MixedPassStressOracle.swift` | Relax the `CAKeyframeAnimation` cast. |

---

### Task 1: Pin `valueAt:`'s time domain

Nothing else can be built until this is known: Display calls it with a unit phase but builds the animation with `duration: 0.5`, so seconds is equally plausible, and guessing wrong produces a silently wrong curve rather than an error.

**Files:**
- Create: `CoreListDemo/Transition/CoreListSpringAnimation.swift`
- Test: `CoreListDemoTests/CoreListSpringValueAtTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `enum CoreListSpringKind { case system26, system05, adjustedBezier }`; `func coreListSpringKind(logicalDuration: Double) -> CoreListSpringKind`; `func makeCoreListSpringAnimation(_ keyPath: String, duration: Double) -> CABasicAnimation`; `func makeCoreList26SpringAnimation(_ keyPath: String, _ duration: Double) -> CABasicAnimation`; `func coreListSpringValue(kind: CoreListSpringKind, phase: CGFloat) -> CGFloat?` (nil when the private selector is unavailable).

- [ ] **Step 1: Write the failing test**

Create `CoreListDemoTests/CoreListSpringValueAtTests.swift`:

```swift
import XCTest
import QuartzCore
@testable import CoreListDemo

/// `valueAt:` is a private CASpringAnimation selector. Display calls it with a unit phase
/// (`listViewAnimationCurveSystem` passes `offset ∈ [0,1]`) but builds the animation with
/// `duration: 0.5`, so a seconds domain is equally plausible from the call site alone. Getting it
/// wrong yields a silently wrong curve, so it is pinned here before anything depends on it.
final class CoreListSpringValueAtTests: XCTestCase {
    func testSpringKindResolvesFromLogicalDuration() {
        XCTAssertEqual(coreListSpringKind(logicalDuration: 0.5), .system05)
        XCTAssertEqual(coreListSpringKind(logicalDuration: 0.4), .adjustedBezier)
        XCTAssertEqual(coreListSpringKind(logicalDuration: 0.3), .adjustedBezier)
        // A Slow-Animations-scaled 0.5 must NOT resolve as the system spring.
        XCTAssertEqual(coreListSpringKind(logicalDuration: 5.0), .adjustedBezier)
        if #available(iOS 26.0, *) {
            XCTAssertEqual(coreListSpringKind(logicalDuration: 0.3832), .system26)
            XCTAssertEqual(coreListSpringKind(logicalDuration: 0.38325), .system26)
            XCTAssertEqual(coreListSpringKind(logicalDuration: 0.3840), .adjustedBezier)
        }
    }

    /// The domain assertion. A unit-phase evaluator is 0 at 0 and 1 at 1; a seconds evaluator fed
    /// a unit phase would still be mid-flight at 1.0 for the 0.5s spring.
    func testValueAtTakesUnitPhaseAndSpansZeroToOne() throws {
        let atZero = try XCTUnwrap(coreListSpringValue(kind: .system05, phase: 0))
        let atOne = try XCTUnwrap(coreListSpringValue(kind: .system05, phase: 1))
        XCTAssertEqual(atZero, 0, accuracy: 1e-6,
                       "valueAt: is not a unit-phase evaluator — see the plan's fallback note")
        XCTAssertEqual(atOne, 1, accuracy: 1e-3,
                       "valueAt: is not a unit-phase evaluator — see the plan's fallback note")
    }

    func testSystemSpringIsMonotonicAndOvershootFree() throws {
        // mass 3 / stiffness 1000 / damping 500 is heavily overdamped (critical ≈ 109.5),
        // so it approaches its target without overshoot.
        var previous: CGFloat = -1
        for step in 0...100 {
            let value = try XCTUnwrap(coreListSpringValue(kind: .system05,
                                                          phase: CGFloat(step) / 100.0))
            XCTAssertGreaterThanOrEqual(value, previous - 1e-9, "regressed at step \(step)")
            XCTAssertLessThanOrEqual(value, 1.0 + 1e-6, "overshot at step \(step)")
            previous = value
        }
    }

    func testAdjustedBezierKindHasNoSpringEvaluator() {
        XCTAssertNil(coreListSpringValue(kind: .adjustedBezier, phase: 0.5),
                     "the bezier branch is solved by Curve.solve, not by a CASpringAnimation")
    }
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro K2' \
  -parallel-testing-enabled NO -collect-test-diagnostics never test \
  -only-testing:CoreListDemoTests/CoreListSpringValueAtTests
```

Expected: compile failure — `cannot find 'coreListSpringKind' in scope`.

- [ ] **Step 3: Write the spring factories, the kind predicate, and the shim**

Create `CoreListDemo/Transition/CoreListSpringAnimation.swift`:

```swift
import UIKit
import QuartzCore

// Spring factories copied verbatim from UIKitRuntimeUtils' `makeSpringAnimationImpl` /
// `make26SpringAnimationImpl` (UIKitUtils.m:53, :68). Only `valueAt:` and the
// `highFrameRateReason` key were private there; the CASpringAnimation parameters themselves are
// public API, so CoreList builds the same animations without taking the dependency.

func makeCoreListSpringAnimation(_ keyPath: String, duration: Double) -> CABasicAnimation {
    if #available(iOS 26.0, *) {
        return makeCoreList26SpringAnimation(keyPath, duration)
    }
    let springAnimation = CASpringAnimation(keyPath: keyPath)
    springAnimation.mass = 3.0
    springAnimation.stiffness = 1000.0
    springAnimation.damping = 500.0
    springAnimation.duration = 0.5
    springAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
    return springAnimation
}

func makeCoreList26SpringAnimation(_ keyPath: String, _ duration: Double) -> CABasicAnimation {
    let springAnimation = CASpringAnimation(keyPath: keyPath)
    springAnimation.mass = 1.0
    springAnimation.stiffness = 555.027
    springAnimation.damping = 47.118
    springAnimation.duration = duration
    springAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
    if #available(iOS 17.0, *) {
        springAnimation.allowsOverdamping = false
    }
    if #available(iOS 15.0, *) {
        springAnimation.preferredFrameRateRange = CAFrameRateRange(minimum: 80.0,
                                                                   maximum: 120.0,
                                                                   preferred: 120.0)
    }
    return springAnimation
}

/// Which of `CAAnimationUtils.swift:119`'s three `kCAMediaTimingFunctionSpring` branches a duration
/// selects.
///
/// **Always resolved from the LOGICAL duration.** `0.5` and `0.3832` are logical values —
/// `CAAnimationUtils` sees them unscaled because it handles Slow Animations with `speed`, whereas
/// CoreList pre-scales. Resolving from a scaled duration would see `5.0` under a ×10 drag
/// coefficient, miss `.system05`, and silently emit a bezier: a divergence visible only under Slow
/// Animations.
enum CoreListSpringKind: Equatable {
    case system26
    case system05
    case adjustedBezier
}

func coreListSpringKind(logicalDuration: Double) -> CoreListSpringKind {
    if #available(iOS 26.0, *), abs(logicalDuration - 0.3832) <= 0.0001 {
        return .system26
    }
    if logicalDuration == 0.5 {
        return .system05
    }
    return .adjustedBezier
}

/// The private `-[CASpringAnimation valueAt:]`, which is how Display samples a real spring
/// analytically (`springAnimationValueAtImpl`, UIKitUtils.m:106).
@objc private protocol CoreListSpringValueAt {
    @objc(valueAt:) func value(at t: CGFloat) -> CGFloat
}

private let system05Spring: CABasicAnimation = makeCoreListSpringAnimation("", duration: 0.5)
private let system26Spring: CABasicAnimation = makeCoreList26SpringAnimation("", 0.3832)

/// Analytic value of a system spring at unit `phase`, or nil for `.adjustedBezier` (solved by
/// `Curve.solve`) and on any OS where the private selector has gone away — callers fall back to the
/// adjusted bezier so the model and the emitter degrade together rather than disagreeing.
func coreListSpringValue(kind: CoreListSpringKind, phase: CGFloat) -> CGFloat? {
    let animation: CABasicAnimation
    switch kind {
    case .system05: animation = system05Spring
    case .system26: animation = system26Spring
    case .adjustedBezier: return nil
    }
    guard animation.responds(to: NSSelectorFromString("valueAt:")) else { return nil }
    let evaluator = unsafeBitCast(animation, to: CoreListSpringValueAt.self)
    return evaluator.value(at: min(max(phase, 0.0), 1.0))
}
```

- [ ] **Step 4: Run the tests**

```bash
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro K2' \
  -parallel-testing-enabled NO -collect-test-diagnostics never test \
  -only-testing:CoreListDemoTests/CoreListSpringValueAtTests
```

Expected: PASS.

**If `testValueAtTakesUnitPhaseAndSpansZeroToOne` fails**, the domain is seconds, not unit phase. Do not weaken the test. Change `coreListSpringValue` to scale the phase by the animation's own duration:

```swift
    return evaluator.value(at: min(max(phase, 0.0), 1.0) * CGFloat(animation.duration))
```

and add a comment recording the measured domain. Then re-run; the endpoint assertions must pass unchanged.

**If `coreListSpringValue` returns nil on this OS**, the selector is gone. Stop and report — the design's fallback keeps the app correct but makes the rest of this plan pointless, and that is a decision for the user.

- [ ] **Step 5: Run the full suite**

Additive so far; expect `** TEST SUCCEEDED **` at 559 + 4.

- [ ] **Step 6: Commit**

```bash
git add CoreListDemo/Transition/CoreListSpringAnimation.swift \
        CoreListDemoTests/CoreListSpringValueAtTests.swift
git commit -m "feat(corelist): spring factories, kind predicate, and the valueAt: shim

Pins the private selector's time domain before anything depends on it:
Display calls it with a unit phase but builds the animation with
duration 0.5, so seconds was equally plausible from the call site.

coreListSpringKind always reads the LOGICAL duration — resolving from a
Slow-Animations-scaled value would miss the 0.5 branch and silently emit
a bezier.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: Exact bézier solver

**Files:**
- Modify: `CoreListDemo/Transition/CoreListTransition+Curve.swift`
- Test: `CoreListDemoTests/CoreListTransitionCurveTests.swift`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: `coreListBezierPoint(_:_:_:_:_:)` with no 0.997 clamp and a bisection fallback; `Curve.solve(at:)` unchanged in signature.

- [ ] **Step 1: Write the failing test**

Append to `CoreListDemoTests/CoreListTransitionCurveTests.swift`:

```swift
    // MARK: - Exact solver

    /// Reference cubic-bezier evaluation by bisection — slow but unconditionally correct, so it
    /// pins `solve` without reusing `solve`'s own Newton code as its own oracle.
    private func referenceBezier(_ x1: CGFloat, _ y1: CGFloat,
                                 _ x2: CGFloat, _ y2: CGFloat, _ x: CGFloat) -> CGFloat {
        func curveAt(_ t: CGFloat, _ a1: CGFloat, _ a2: CGFloat) -> CGFloat {
            let a = 1.0 - 3.0 * a2 + 3.0 * a1
            let b = 3.0 * a2 - 6.0 * a1
            let c = 3.0 * a1
            return ((a * t + b) * t + c) * t
        }
        var lo: CGFloat = 0, hi: CGFloat = 1
        for _ in 0..<100 {
            let mid = (lo + hi) * 0.5
            if curveAt(mid, x1, x2) < x { lo = mid } else { hi = mid }
        }
        return curveAt((lo + hi) * 0.5, y1, y2)
    }

    func testSolveIsExactWithNoTailClamp() {
        let curves: [(CoreListTransition.Animation.Curve, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (.easeInOut, 0.42, 0.0, 0.58, 1.0),
            (.easeIn, 0.42, 0.0, 1.0, 1.0),
            (.spring, 0.380, 0.700, 0.125, 1.000),
            (.custom(0.33, 0.52, 0.25, 0.99), 0.33, 0.52, 0.25, 0.99)
        ]
        for (curve, x1, y1, x2, y2) in curves {
            for step in 0...1000 {
                let x = CGFloat(step) / 1000.0
                XCTAssertEqual(curve.solve(at: x), referenceBezier(x1, y1, x2, y2, x),
                               accuracy: 1e-9, "\(curve) at \(x)")
            }
        }
    }

    /// The clamp used to snap everything from x ≈ 0.9606 onward to exactly 1.0. Its removal is the
    /// whole point: CA keeps interpolating there, so the model must too.
    func testTailIsInterpolatedNotSnapped() {
        let curve = CoreListTransition.Animation.Curve.easeInOut
        XCTAssertLessThan(curve.solve(at: 0.97), 1.0)
        XCTAssertLessThan(curve.solve(at: 0.99), 1.0)
        XCTAssertGreaterThan(curve.solve(at: 0.99), curve.solve(at: 0.97))
        XCTAssertEqual(curve.solve(at: 1.0), 1.0, accuracy: 1e-12)
    }

    /// Control points whose x-derivative vanishes defeat Newton; bisection must still land it.
    func testDegenerateControlPointsStillSolve() {
        let curve = CoreListTransition.Animation.Curve.custom(0.0, 0.0, 0.0, 1.0)
        XCTAssertEqual(curve.solve(at: 0.0), 0.0, accuracy: 1e-9)
        XCTAssertEqual(curve.solve(at: 1.0), 1.0, accuracy: 1e-9)
        var previous = curve.solve(at: 0)
        for step in 1...200 {
            let value = curve.solve(at: CGFloat(step) / 200.0)
            XCTAssertGreaterThanOrEqual(value, previous - 1e-9)
            XCTAssertFalse(value.isNaN, "degenerate control points produced NaN")
            previous = value
        }
    }
```

Also **delete** the two now-obsolete tests in that file that assert the clamped behaviour — `testSmoothstepIsACustomBezierWithinFloatPayloadPrecision` and `testCubicEaseOutIsACustomBezierWithinFloatPayloadPrecision` both compute `expected = value >= 0.997 ? 1.0 : value`. Replace that expression in each with the unclamped value:

```swift
            let expected = smoothstep          // was: smoothstep >= 0.997 ? 1.0 : smoothstep
```
```swift
            let expected = easeOut             // was: easeOut >= 0.997 ? 1.0 : easeOut
```

and in `testCustomBezierFloatDeviationStaysBelowOnePartInTenMillion`, likewise drop both `>= 0.997 ? 1.0 :` guards.

- [ ] **Step 2: Run to verify it fails**

Expected: `testTailIsInterpolatedNotSnapped` fails — `solve(at: 0.97)` returns exactly 1.0.

- [ ] **Step 3: Replace the solver**

In `CoreListDemo/Transition/CoreListTransition+Curve.swift`, replace `getTForX` and `coreListBezierPoint`:

```swift
/// Inverts x(t) for the given control-x values.
///
/// Newton first — it converges in two or three steps for every well-conditioned curve — then
/// bisection for control points where `x'(t)` vanishes and Newton cannot make progress. Display's
/// version runs a fixed 4 iterations with no fallback; the extra robustness matters because
/// `.custom` control points come from callers.
private func getTForX(_ x: CGFloat, _ x1: CGFloat, _ x2: CGFloat) -> CGFloat {
    var t = x
    for _ in 0..<8 {
        let error = calcBezier(t, x1, x2) - x
        if abs(error) < 1e-12 { return t }
        let slope = calcSlope(t, x1, x2)
        if slope == 0.0 { break }
        let next = t - error / slope
        if next < 0.0 || next > 1.0 || next.isNaN { break }
        t = next
    }

    var lo: CGFloat = 0.0
    var hi: CGFloat = 1.0
    for _ in 0..<60 {
        let mid = (lo + hi) * 0.5
        if calcBezier(mid, x1, x2) < x { lo = mid } else { hi = mid }
    }
    return (lo + hi) * 0.5
}

/// Cubic-bezier progress. Unlike Display's `bezierPoint` there is **no 0.997 clamp**: Core
/// Animation keeps interpolating through the tail, and this value has to agree with what CA
/// renders. Measured, the clamp was the entire 2.9e-3 error — the iteration count was already
/// exact to 4.4e-16.
func coreListBezierPoint(_ x1: CGFloat, _ y1: CGFloat,
                         _ x2: CGFloat, _ y2: CGFloat,
                         _ x: CGFloat) -> CGFloat {
    calcBezier(getTForX(x, x1, x2), y1, y2)
}
```

- [ ] **Step 4: Run the full suite**

Expected: `** TEST SUCCEEDED **`. Per the design, existing curve-derived expectations sample phase 0.25 and 0.5 where the change is 2.8e-17 and 0, so **no expected value should need editing.** If one does, read it before touching it — a value moving by more than ~1e-15 means the solver is wrong, not the expectation.

- [ ] **Step 5: Commit**

```bash
git add CoreListDemo/Transition/CoreListTransition+Curve.swift \
        CoreListDemoTests/CoreListTransitionCurveTests.swift
git commit -m "fix(corelist): exact bezier solver, no tail clamp

Display's bezierPoint clamps any result >= 0.997 to 1.0, so the model
reported 'arrived' over a curve's final ~4% while CA kept interpolating.
Once CA evaluates the bezier the model has to agree with it.

Measured: 4-iteration Newton was already exact to 4.4e-16 and the clamp
was the entire 2.9e-3 error, so removing it costs nothing. Adds a
bisection fallback for caller-supplied .custom control points where x'(t)
vanishes and Newton cannot converge.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: Carry the spring kind on the transition and the track

**Files:**
- Modify: `CoreListDemo/Transition/CoreListTransition.swift`
- Modify: `CoreListDemo/ListAnimationModel.swift` (`ListAnimationTrack`, `replace`)
- Test: `CoreListDemoTests/CoreListTransitionCurveTests.swift`

**Interfaces:**
- Consumes: `CoreListSpringKind`, `coreListSpringKind(logicalDuration:)` from Task 1.
- Produces: `CoreListTransition.springKind: CoreListSpringKind` (resolved at init, preserved by `scaled(by:)`); `ListAnimationTrack.springKind: CoreListSpringKind` with default `.adjustedBezier` on the memberwise init.

- [ ] **Step 1: Write the failing test**

Append to `CoreListDemoTests/CoreListTransitionCurveTests.swift`:

```swift
    // MARK: - Spring kind

    func testTransitionResolvesSpringKindAtConstruction() {
        XCTAssertEqual(CoreListTransition.spring(duration: 0.5).springKind, .system05)
        XCTAssertEqual(CoreListTransition.spring(duration: 0.4).springKind, .adjustedBezier)
        XCTAssertEqual(CoreListTransition.easeInOut(duration: 0.5).springKind, .adjustedBezier,
                       "a non-spring curve never selects a system spring")
        XCTAssertEqual(CoreListTransition.immediate.springKind, .adjustedBezier)
    }

    /// The load-bearing one. The controller scales before the model sees the transition, so if
    /// `scaled(by:)` recomputed the kind, a ×10 drag coefficient would turn the 0.5 system spring
    /// into a bezier and nobody would notice outside Slow Animations.
    func testScalingPreservesSpringKind() {
        let scaled = CoreListTransition.spring(duration: 0.5).scaled(by: 10)
        XCTAssertEqual(scaled.duration, 5.0, accuracy: 1e-12)
        XCTAssertEqual(scaled.springKind, .system05,
                       "scaling must not re-resolve the kind from the scaled duration")
    }
```

- [ ] **Step 2: Run to verify it fails**

Expected: `value of type 'CoreListTransition' has no member 'springKind'`.

- [ ] **Step 3: Store the kind on the transition**

In `CoreListDemo/Transition/CoreListTransition.swift`, add the stored property and resolve it in `init`:

```swift
    public var animation: Animation
    /// Which `kCAMediaTimingFunctionSpring` branch this transition's `.spring` selects, resolved
    /// once from the duration this transition was CONSTRUCTED with — which is the logical one.
    /// `scaled(by:)` carries it through untouched; re-resolving from a scaled duration would miss
    /// the system-spring branches under Slow Animations.
    public private(set) var springKind: CoreListSpringKind
    private var _userData: [Any] = []

    public init(animation: Animation) {
        self.animation = animation
        switch animation {
        case .none:
            self.springKind = .adjustedBezier
        case let .curve(duration, curve):
            if case .spring = curve {
                self.springKind = coreListSpringKind(logicalDuration: duration)
            } else {
                self.springKind = .adjustedBezier
            }
        }
    }
```

In `scaled(by:)`, the existing `var result = self` already copies `springKind`; only `animation` is reassigned, so it is preserved with no further change. In `withAnimation(_:)` and `withAnimationIfAnimated(_:)`, the animation is replaced wholesale with a presumably-logical one, so re-resolve:

```swift
    public func withAnimation(_ animation: Animation) -> CoreListTransition {
        var result = CoreListTransition(animation: animation)
        result._userData = self._userData
        return result
    }
```

`_userData` is `private`, and this is inside the same file, so the assignment compiles.

- [ ] **Step 4: Store the kind on the track**

In `CoreListDemo/ListAnimationModel.swift`, add the field to `ListAnimationTrack`:

```swift
struct ListAnimationTrack: Equatable {
    let generation: UInt64
    let from: CGFloat
    let to: CGFloat
    let startTime: TimeInterval
    let duration: TimeInterval
    let curve: CoreListTransition.Animation.Curve
    /// Resolved from the LOGICAL duration by the transition that produced this track. The track's
    /// own `duration` is already Slow-Animation-scaled and must never be used to re-resolve it.
    let springKind: CoreListSpringKind

    init(generation: UInt64,
         from: CGFloat,
         to: CGFloat,
         startTime: TimeInterval,
         duration: TimeInterval,
         curve: CoreListTransition.Animation.Curve = .easeInOut,
         springKind: CoreListSpringKind = .adjustedBezier) {
        self.generation = generation
        self.from = from
        self.to = to
        self.startTime = startTime
        self.duration = duration
        self.curve = curve
        self.springKind = springKind
    }
```

and pass it through in `replace`:

```swift
        let track = ListAnimationTrack(generation: nextGeneration,
                                       from: from,
                                       to: to,
                                       startTime: time,
                                       duration: duration,
                                       curve: curve,
                                       springKind: transition.springKind)
```

- [ ] **Step 5: Run the full suite**

Expected: `** TEST SUCCEEDED **` at 559 + 6. The default argument keeps every existing `ListAnimationTrack(…)` in the tests compiling unchanged.

- [ ] **Step 6: Commit**

```bash
git add CoreListDemo/Transition/CoreListTransition.swift \
        CoreListDemo/ListAnimationModel.swift \
        CoreListDemoTests/CoreListTransitionCurveTests.swift
git commit -m "feat(corelist): carry the resolved spring kind on transition and track

The controller scales duration before the model sees the transition, so
the model cannot resolve the spring branch itself: 0.5 and 0.3832 are
logical values. The transition resolves the kind once at construction and
scaled(by:) carries it through; the track stores what the transition
resolved.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: The model evaluates system springs

**Files:**
- Modify: `CoreListDemo/ListAnimationModel.swift` (`import QuartzCore`, `ListAnimationTrack.value(at:)`)
- Test: `CoreListDemoTests/CoreListSpringValueAtTests.swift`

**Interfaces:**
- Consumes: `coreListSpringValue(kind:phase:)` from Task 1, `ListAnimationTrack.springKind` from Task 3.
- Produces: `ListAnimationTrack.value(at:)` evaluating system springs through `valueAt:` and béziers through `Curve.solve`.

- [ ] **Step 1: Write the failing test**

Append to `CoreListDemoTests/CoreListSpringValueAtTests.swift`:

```swift
    func testTrackWithSystemSpringUsesTheSpringEvaluatorNotTheBezier() throws {
        let spring = ListAnimationTrack(generation: 1, from: 0, to: 100,
                                        startTime: 0, duration: 0.5,
                                        curve: .spring, springKind: .system05)
        let bezier = ListAnimationTrack(generation: 2, from: 0, to: 100,
                                        startTime: 0, duration: 0.5,
                                        curve: .spring, springKind: .adjustedBezier)

        XCTAssertEqual(spring.value(at: 0), 0, accuracy: 1e-6)
        XCTAssertEqual(spring.value(at: 0.5), 100, accuracy: 0.1)

        // The two branches are genuinely different curves; if the springKind were ignored these
        // would coincide and the test would be vacuous.
        var maxDifference: CGFloat = 0
        for step in 0...100 {
            let t = 0.5 * Double(step) / 100.0
            maxDifference = max(maxDifference, abs(spring.value(at: t) - bezier.value(at: t)))
        }
        XCTAssertGreaterThan(maxDifference, 1.0,
                             "system spring and adjusted bezier should not coincide")
    }

    func testZeroDurationTrackStillSettlesRegardlessOfSpringKind() {
        let track = ListAnimationTrack(generation: 3, from: 0, to: 100,
                                       startTime: 0, duration: 0,
                                       curve: .spring, springKind: .system05)
        XCTAssertEqual(track.value(at: 0), 100)
        XCTAssertEqual(track.value(at: 99), 100)
    }
```

- [ ] **Step 2: Run to verify it fails**

Expected: `testTrackWithSystemSpringUsesTheSpringEvaluatorNotTheBezier` fails — `maxDifference` is 0, because `value(at:)` still routes everything through `Curve.solve`.

- [ ] **Step 3: Route system springs through the spring evaluator**

In `CoreListDemo/ListAnimationModel.swift`, add the import at the top:

```swift
import Foundation
import CoreGraphics
import QuartzCore
```

and change `ListAnimationTrack.value(at:)`:

```swift
    func value(at time: TimeInterval) -> CGFloat {
        guard duration > 0 else { return to }
        let x = min(max((time - startTime) / duration, 0), 1)
        // A system spring is not a unit bezier; it is evaluated by the same CASpringAnimation Core
        // Animation will render, so the model and the screen cannot disagree. `nil` means the
        // private selector is unavailable, in which case both the model and the emitter fall back
        // to the adjusted bezier — degraded together rather than disagreeing.
        let eased = coreListSpringValue(kind: springKind, phase: CGFloat(x))
            ?? curve.solve(at: CGFloat(x))
        return from + (to - from) * eased
    }
```

- [ ] **Step 4: Run the full suite**

Expected: `** TEST SUCCEEDED **` at 559 + 8.

- [ ] **Step 5: Commit**

```bash
git add CoreListDemo/ListAnimationModel.swift \
        CoreListDemoTests/CoreListSpringValueAtTests.swift
git commit -m "feat(corelist): evaluate system springs analytically in the model

A real CASpringAnimation is not a unit bezier, so the model now evaluates
the two system-spring branches with the same animation object CA renders,
via the private valueAt:. When the selector is unavailable both the model
and the emitter fall back to the adjusted bezier, so they degrade
together rather than disagreeing.

ListAnimationModel gains QuartzCore; it is no longer UIKit-free in the
strict sense, which CLAUDE.md records.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: The shared factory, and the executor on it

**Files:**
- Create: `CoreListDemo/Transition/CoreListCAAnimation.swift`
- Modify: `CoreListDemo/Transition/CALayer+CoreListAnimate.swift`
- Test: `CoreListDemoTests/CoreListTransitionCurveTests.swift`

**Interfaces:**
- Consumes: `CoreListSpringKind`, the spring factories from Task 1.
- Produces: `func makeCoreListAnimation(from: CGFloat, to: CGFloat, keyPath: String, curve: CoreListTransition.Animation.Curve, springKind: CoreListSpringKind, scaledDuration: Double, additive: Bool) -> CABasicAnimation`.

- [ ] **Step 1: Write the failing test**

Append to `CoreListDemoTests/CoreListTransitionCurveTests.swift`:

```swift
    // MARK: - Shared factory

    func testFactoryEmitsBasicAnimationWithTimingFunctionForBezierCurves() throws {
        let animation = makeCoreListAnimation(from: 0, to: 100, keyPath: "position.y",
                                              curve: .easeInOut, springKind: .adjustedBezier,
                                              scaledDuration: 0.3, additive: true)
        XCTAssertFalse(animation is CASpringAnimation)
        XCTAssertEqual(animation.keyPath, "position.y")
        XCTAssertTrue(animation.isAdditive)
        XCTAssertEqual(animation.duration, 0.3, accuracy: 1e-12)
        XCTAssertEqual(animation.speed, 1.0, "CoreList pre-scales duration instead of using speed")
        XCTAssertNotNil(animation.timingFunction)
    }

    func testFactoryEmitsRealSpringForTheSystemBranch() throws {
        let animation = makeCoreListAnimation(from: 0, to: 100, keyPath: "position.y",
                                              curve: .spring, springKind: .system05,
                                              scaledDuration: 0.5, additive: false)
        let spring = try XCTUnwrap(animation as? CASpringAnimation)
        XCTAssertEqual(spring.mass, 3.0, accuracy: 1e-9)
        XCTAssertEqual(spring.stiffness, 1000.0, accuracy: 1e-9)
        XCTAssertEqual(spring.damping, 500.0, accuracy: 1e-9)
    }

    func testFactoryEmitsAdjustedBezierForANonSpecialSpringDuration() throws {
        let animation = makeCoreListAnimation(from: 0, to: 100, keyPath: "position.y",
                                              curve: .spring, springKind: .adjustedBezier,
                                              scaledDuration: 0.4, additive: false)
        XCTAssertFalse(animation is CASpringAnimation)
        XCTAssertNotNil(animation.timingFunction)
    }

    func testFactoryNeverEmitsKeyframes() {
        let curves: [CoreListTransition.Animation.Curve] = [
            .easeInOut, .easeIn, .linear, .custom(0.1, 0.2, 0.3, 0.4), .spring
        ]
        for curve in curves {
            for kind in [CoreListSpringKind.adjustedBezier, .system05] {
                let animation = makeCoreListAnimation(from: 0, to: 1, keyPath: "opacity",
                                                      curve: curve, springKind: kind,
                                                      scaledDuration: 0.3, additive: false)
                XCTAssertFalse(animation is CAKeyframeAnimation, "\(curve)/\(kind)")
            }
        }
    }
```

- [ ] **Step 2: Run to verify it fails**

Expected: `cannot find 'makeCoreListAnimation' in scope`.

- [ ] **Step 3: Write the factory**

Create `CoreListDemo/Transition/CoreListCAAnimation.swift`:

```swift
import UIKit
import QuartzCore

/// The single place CoreList turns a curve into a CAAnimation — a copy of
/// `CAAnimationUtils.makeAnimation`'s branch tree (`CAAnimationUtils.swift:69`), minus the branches
/// CoreList has no caller for (the `kCAMediaTimingFunctionCustomSpringPrefix` parse and the
/// `mediaTimingFunction` override).
///
/// Both emitters call this: `CALayer.animate` installs the result directly, and
/// `CoreAnimationCompiler` layers the model-path properties on top (`beginTime`, `fillMode`,
/// `isRemovedOnCompletion`, generation metadata). One branch tree, so the two cannot drift — which
/// they already did once for `.spring`.
///
/// **`scaledDuration` is already Slow-Animation-scaled.** `CAAnimationUtils` instead keeps duration
/// logical and sets `speed = 1/k`; CoreList pre-scales in `ListAnimationController` because the
/// model's deadlines and reaping live on the same scaled clock. Both render identically. This is
/// the one intentional divergence, so `speed` stays 1.
func makeCoreListAnimation(from: CGFloat,
                           to: CGFloat,
                           keyPath: String,
                           curve: CoreListTransition.Animation.Curve,
                           springKind: CoreListSpringKind,
                           scaledDuration: Double,
                           additive: Bool) -> CABasicAnimation {
    let animation: CABasicAnimation
    var isSystemSpring = false

    if case .spring = curve {
        switch springKind {
        case .system26:
            animation = makeCoreList26SpringAnimation(keyPath, scaledDuration)
            isSystemSpring = true
        case .system05:
            animation = makeCoreListSpringAnimation(keyPath, duration: scaledDuration)
            isSystemSpring = true
        case .adjustedBezier:
            animation = CABasicAnimation(keyPath: keyPath)
            animation.timingFunction = CAMediaTimingFunction(controlPoints: 0.380, 0.700, 0.125, 1.000)
        }
    } else {
        animation = CABasicAnimation(keyPath: keyPath)
        animation.timingFunction = curve.mediaTimingFunction
    }

    if isSystemSpring {
        // The spring factories set their own duration from the spring's settling behaviour; scale
        // playback so it lands in `scaledDuration`. This is algebraically what CAAnimationUtils
        // computes: it does `speed * (animation.duration / logicalDuration)` with `speed = 1/k`,
        // and `scaledDuration == logicalDuration * k`, so both reduce to
        // `springDuration / (logicalDuration * k)`. Note `animation.duration` is deliberately left
        // at the spring's own settling duration — `speed` is what maps it onto the pass duration.
        animation.speed = Float(animation.duration / scaledDuration)
    } else {
        animation.duration = scaledDuration
        animation.speed = 1.0
    }

    animation.fromValue = from as NSNumber
    animation.toValue = to as NSNumber
    animation.isAdditive = additive
    animation.isRemovedOnCompletion = true
    animation.fillMode = .forwards
    return animation
}

extension CoreListTransition.Animation.Curve {
    /// The `CAMediaTimingFunction` CA should evaluate for this curve. Every case here is a cubic
    /// bezier, and it is the SAME bezier `solve(at:)` computes — which is what lets the model stay
    /// authoritative while CA does the interpolating.
    var mediaTimingFunction: CAMediaTimingFunction {
        switch self {
        case .easeInOut:
            return CAMediaTimingFunction(controlPoints: 0.42, 0.0, 0.58, 1.0)
        case .easeIn:
            return CAMediaTimingFunction(controlPoints: 0.42, 0.0, 1.0, 1.0)
        case .linear:
            return CAMediaTimingFunction(name: .linear)
        case let .custom(a, b, c, d):
            return CAMediaTimingFunction(controlPoints: a, b, c, d)
        case .spring, .bounce:
            // Reached only for `.spring`'s adjustedBezier branch, handled by the caller, and for
            // `.bounce`, which degrades to the same adjusted curve.
            return CAMediaTimingFunction(controlPoints: 0.380, 0.700, 0.125, 1.000)
        }
    }
}
```

- [ ] **Step 4: Put the executor on the factory**

Replace the whole body of `CALayer.animate` in `CoreListDemo/Transition/CALayer+CoreListAnimate.swift`, and delete both private spring factories from that file (they now live in `CoreListSpringAnimation.swift`) along with `animateSpring` and the sampling loop:

```swift
import UIKit
import QuartzCore

extension CALayer {
    /// Executor-path animation: builds through the shared factory, so it emits exactly what the
    /// model path and the rest of the app emit.
    ///
    /// Duration is scaled by `UIView.animationDurationFactor` HERE, exactly once, mirroring
    /// Display's `CAAnimationUtils`. The model path scales in `ListAnimationController` and never
    /// reaches this function. The spring kind is resolved from the LOGICAL duration, before scaling.
    func animate(from: CGFloat,
                 to: CGFloat,
                 keyPath: String,
                 duration: Double,
                 delay: Double = 0.0,
                 curve: CoreListTransition.Animation.Curve,
                 removeOnCompletion: Bool = true,
                 additive: Bool = false,
                 completion: ((Bool) -> Void)? = nil,
                 key: String? = nil) {
        let factor = UIView.animationDurationFactor
        let scaledDuration = max(0.0, duration * factor)
        guard scaledDuration > 0 else {
            completion?(true)
            return
        }

        let springKind = coreListSpringKind(logicalDuration: duration)
        let animation = makeCoreListAnimation(from: from, to: to, keyPath: keyPath, curve: curve,
                                              springKind: springKind,
                                              scaledDuration: scaledDuration, additive: additive)
        animation.isRemovedOnCompletion = removeOnCompletion
        if !delay.isZero {
            animation.beginTime = convertTime(CACurrentMediaTime(), from: nil) + delay * factor
            animation.fillMode = .both
        }
        animation.preferHighRefreshRate()
        if let completion {
            animation.setCoreListCompletion(completion)
        }
        add(animation, forKey: key ?? keyPath)
    }
}
```

- [ ] **Step 5: Run the full suite**

Expected: `** TEST SUCCEEDED **` at 559 + 12. `testAnimateScalesDurationByAnimationDurationFactor` still passes — the factory receives the scaled duration and sets it verbatim.

- [ ] **Step 6: Commit**

```bash
git add CoreListDemo/Transition/CoreListCAAnimation.swift \
        CoreListDemo/Transition/CALayer+CoreListAnimate.swift \
        CoreListDemoTests/CoreListTransitionCurveTests.swift
git commit -m "feat(corelist): one shared CAAnimationUtils-shaped factory

Copies CAAnimationUtils.makeAnimation's branch tree into a single
function and puts the executor on it: CABasicAnimation with a
CAMediaTimingFunction for every bezier curve, a real CASpringAnimation
for the two system-spring durations. The executor's sampling loop and its
private copy of the spring factories are deleted.

speed stays 1 because CoreList pre-scales duration — the one intentional
divergence from CAAnimationUtils, documented at the factory.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: The compiler on the factory

**Files:**
- Modify: `CoreListDemo/CoreAnimationCompiler.swift`
- Modify: `CoreListDemoTests/CoreAnimationCompilerParityTests.swift`
- Modify: `CoreListDemoTests/TestSupport/MixedPassStressOracle.swift:460`

**Interfaces:**
- Consumes: `makeCoreListAnimation(…)` from Task 5, `ListAnimationTrack.springKind` from Task 3.
- Produces: `CoreAnimationCompiler.animation(for:property:) -> CAAnimation` returning a `CABasicAnimation`/`CASpringAnimation`. `samplesPerSecond` is removed.

- [ ] **Step 1: Rewrite the compiler**

Replace `animation(for:property:)` in `CoreListDemo/CoreAnimationCompiler.swift`:

```swift
    func animation(for track: ListAnimationTrack,
                   property: ListAnimatedProperty) -> CAAnimation {
        let animation = makeCoreListAnimation(from: track.from,
                                              to: track.to,
                                              keyPath: keyPath(for: property),
                                              curve: track.curve,
                                              springKind: track.springKind,
                                              scaledDuration: track.duration,
                                              additive: isAdditive(property))
        // Model-path properties the shared factory deliberately does not set.
        animation.beginTime = track.startTime
        animation.fillMode = .both
        animation.isRemovedOnCompletion = false
        animation.setValue(track.generation, forKey: "CoreListAnimation.generation")
        if property == .viewportOffset || property == .positionX || property == .positionY {
            animation.preferHighRefreshRate()
        }
        return animation
    }

    private func keyPath(for property: ListAnimatedProperty) -> String {
        switch property {
        case .viewportOffset: return "bounds.origin.y"
        case .positionX: return "position.x"
        case .positionY: return "position.y"
        case .width: return "bounds.size.width"
        case .height: return "bounds.size.height"
        case .opacity: return "opacity"
        }
    }

    private func isAdditive(_ property: ListAnimatedProperty) -> Bool {
        switch property {
        case .viewportOffset, .positionX, .positionY: return true
        case .width, .height, .opacity: return false
        }
    }
```

Delete the `samplesPerSecond` stored property and its `init` parameter; the init becomes:

```swift
    init(emitsAnimations: Bool = true) {
        self.emitsAnimations = emitsAnimations
    }
```

- [ ] **Step 2: Update the parity tests**

In `CoreListDemoTests/CoreAnimationCompilerParityTests.swift`:

1. Replace every `CoreAnimationCompiler(samplesPerSecond: 240)` / `(samplesPerSecond: 20)` / `(samplesPerSecond: 10)` with `CoreAnimationCompiler()`, and `CoreAnimationCompiler(samplesPerSecond: 240, emitsAnimations: false)` with `CoreAnimationCompiler(emitsAnimations: false)`.
2. Replace all eight `as? CAKeyframeAnimation` casts with `as? CABasicAnimation`.
3. **Delete** `testCompilationUsesInclusiveSamplingAndPreservesGenerationAndSlowClock` and `testCompiledSamplesLinearlyInterpolateTheAnalyticTrack` outright — both assert on `animation.values`, which no longer exists. Their content is subsumed by the paused-layer sweep in Step 3, which measures rendered output rather than the sample array that approximated it. Replace them with the generation/duration half that is still meaningful:

```swift
    func testCompilationPreservesGenerationAndDoesNotRescaleDuration() throws {
        let compiler = CoreAnimationCompiler()
        // The duration is already Slow-Animation-scaled before it reaches the compiler.
        let track = ListAnimationTrack(generation: 91, from: 20, to: 0,
                                       startTime: 40, duration: 3)
        let animation = try XCTUnwrap(compiler.animation(for: track, property: .positionY)
                                      as? CABasicAnimation)
        XCTAssertEqual(animation.beginTime, 40)
        XCTAssertEqual(animation.duration, 3, "the compiler must not apply Slow Animation scaling twice")
        XCTAssertEqual(animation.speed, 1.0)
        XCTAssertEqual((animation.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value,
                       track.generation)
        XCTAssertEqual(animation.fromValue as? CGFloat, 20)
        XCTAssertEqual(animation.toValue as? CGFloat, 0)
    }
```

4. Delete the now-unused `interpolatedValue(of:phase:)` helper if the compiler no longer has any caller for it (the Swift compiler will warn).

- [ ] **Step 3: Parameterize the paused-layer sweep**

Replace `testPausedWindowBackedLayerPresentationMatchesAnalyticPositionTrack` with a per-curve version. This is the 100%-match proof: it compares what Core Animation actually renders against what the model says.

```swift
    func testPausedLayerPresentationMatchesAnalyticTrackForEveryCurve() throws {
        let compiler = CoreAnimationCompiler()
        let cases: [(String, CoreListTransition.Animation.Curve, CoreListSpringKind, Double)] = [
            ("easeInOut", .easeInOut, .adjustedBezier, 3.0),
            ("easeIn", .easeIn, .adjustedBezier, 3.0),
            ("linear", .linear, .adjustedBezier, 3.0),
            ("custom", .custom(0.33, 0.52, 0.25, 0.99), .adjustedBezier, 3.0),
            ("spring@0.4", .spring, .adjustedBezier, 0.4),
            ("spring@0.5", .spring, .system05, 0.5)
        ]

        for (name, curve, springKind, duration) in cases {
            let track = ListAnimationTrack(generation: 44, from: -80, to: 0,
                                           startTime: 12, duration: duration,
                                           curve: curve, springKind: springKind)
            let (window, root) = try visibleWindow()
            defer { window.isHidden = true }

            let layer = CALayer()
            layer.bounds = CGRect(x: 0, y: 0, width: 40, height: 40)
            layer.position = CGPoint(x: 100, y: 200)
            layer.backgroundColor = UIColor.red.cgColor
            layer.speed = 0
            layer.timeOffset = track.startTime
            root.view.layer.addSublayer(layer)
            compiler.install(track, property: .positionY, on: layer)

            for phase in [0.0, 0.25, 0.5, 0.75, 1.0] {
                layer.timeOffset = track.startTime + phase * track.duration
                root.view.layoutIfNeeded()
                flushCoreAnimation()

                let presentation = try XCTUnwrap(layer.presentation())
                let rendered = presentation.position.y - layer.position.y
                let analytic = track.value(at: layer.timeOffset)
                XCTAssertEqual(rendered, analytic, accuracy: 0.5,
                               "\(name) diverged at phase \(phase)")
            }
        }
    }
```

The 0.5pt tolerance is deliberate: it is well inside a pixel on a 3× display, so a passing sweep means the two are visually identical, while the ~23%-of-travel class of error this work fixes would fail it by orders of magnitude.

- [ ] **Step 4: Relax the oracle's cast**

In `CoreListDemoTests/TestSupport/MixedPassStressOracle.swift:460`:

```swift
        guard let animation = animation as? CABasicAnimation else {
            throw MixedPassOracleError.missingAnimation(property)
        }
```

Its generation and `beginTime` checks below are unaffected. **Its `duration` check needs a caveat**
— a system spring's `animation.duration` is the spring's own settling duration, not the track's, so
`abs(animation.duration - expected.duration) < 1e-9` would fail for one. No current scenario
produces one (`MixedPassScenario` alternates `.easeInOut` and `.linear`), so this is latent rather
than broken. Guard it explicitly so a future scenario that adds a system spring fails with a clear
message instead of a confusing duration mismatch:

```swift
        if expected.springKind == .adjustedBezier {
            guard abs(animation.duration - expected.duration) < 1e-9 else {
                throw MixedPassOracleError.wrongDuration
            }
        }
        // A system spring's animation.duration is its settling duration; `speed` maps it onto the
        // pass duration, so the track duration is not expected to appear on the animation.
```

Keep whatever error case the existing code throws here rather than inventing `wrongDuration` if one
already exists — check the enum before editing.

- [ ] **Step 5: Run the full suite**

Expected: `** TEST SUCCEEDED **`. Two tests were deleted and one added, so the count is 559 + 12 − 1.

If the paused-layer sweep fails for `spring@0.5` specifically, the model and CA disagree about the system spring — check `valueAt:`'s domain finding from Task 1 before touching the tolerance.

- [ ] **Step 6: Commit**

```bash
git add CoreListDemo/CoreAnimationCompiler.swift \
        CoreListDemoTests/CoreAnimationCompilerParityTests.swift \
        CoreListDemoTests/TestSupport/MixedPassStressOracle.swift
git commit -m "feat(corelist)!: compile tracks through the shared factory

CoreAnimationCompiler stops sampling tracks into 240Hz keyframes and
builds through the same factory the executor uses, then layers on the
model-path properties: beginTime, fillMode .both, no auto-removal, and
the generation metadata. samplesPerSecond is gone.

The parity tests' array-shape assertions are replaced by a paused-layer
sweep run per curve — easeInOut, easeIn, linear, custom, spring at 0.4
and at 0.5 — comparing what Core Animation actually renders against
track.value(at:). That measures the success criterion directly instead of
approximating it.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 7: Verification and documentation

**Files:**
- Modify: `CLAUDE.md`
- Modify: `docs/plans/CHANGELOG.md`

- [ ] **Step 1: Grep guard — no keyframes outside deceleration**

```bash
grep -rn "CAKeyframeAnimation" CoreListDemo/ \
  | grep -vE "KeyframeFlight|Trajectory|PhysicsScroll"
```

Expected: no output.

- [ ] **Step 2: Full Bazel app build**

```bash
cd /Users/isaac/build/telegram/telegram-ios
source ~/.zshrc 2>/dev/null; python3 build-system/Make/Make.py --overrideXcodeVersion \
 --cacheDir ~/telegram-bazel-cache build \
 --configurationPath build-system/appstore-configuration.json \
 --gitCodesigningRepository git@gitlab.com:peter-iakovlev/fastlanematch.git \
 --gitCodesigningType development --gitCodesigningUseCurrent --buildNumber=1 \
 --configuration=debug_sim_arm64 --continueOnError
```

Expected: `Build completed successfully`.

- [ ] **Step 3: Update `CLAUDE.md`**

Replace the `CoreAnimationCompiler` paragraph in the "Granular animation contract" section:

```markdown
`CoreAnimationCompiler` is an output renderer, never an authority. It builds through the shared
`makeCoreListAnimation` factory — a copy of `CAAnimationUtils.makeAnimation`'s branch tree — so what
CoreList emits is what every other Telegram surface emits: a `CABasicAnimation` with a
`CAMediaTimingFunction` for bezier curves, a real `CASpringAnimation` for the two system-spring
durations (0.5, and 0.3832 on iOS 26). It then adds the model-path properties the factory does not
set: `beginTime = track.startTime`, `fillMode = .both`, `isRemovedOnCompletion = false`, and the
generation metadata. Position is additive on `position.x`/`position.y`, width/height absolute on
`bounds.size.*`, opacity absolute. **No `CAKeyframeAnimation` is emitted outside the physics
deceleration flights.** Interruption never reads layer presentation state back into the model.
Production uses no display-link list renderer and no `UIViewPropertyAnimator`.
```

Add to "Non-obvious gotchas":

```markdown
- **The spring-kind predicate reads the LOGICAL duration.** `0.5` and `0.3832` select real
  `CASpringAnimation`s; every other duration gets the adjusted bezier. CoreList pre-scales duration
  for Slow Animations, so resolving the kind from a scaled value would see `5.0` under a ×10 drag
  coefficient and silently emit a bezier — visible only under Slow Animations. `CoreListTransition`
  resolves it once at construction and `scaled(by:)` carries it through; `ListAnimationTrack` stores
  what the transition resolved.
- **`Curve.solve(at:)` deliberately differs from Display's `bezierPoint`:** no 0.997 clamp, and a
  bisection fallback after Newton. CA keeps interpolating through a curve's tail, and the model has
  to agree with what CA renders now that CA evaluates the bezier itself.
```

Update the model's dependency claim in the same section — `ListAnimationModel` is "UIKit-free" becomes:

```markdown
`ListAnimationModel` is the sole presentation authority. It depends only on Foundation, CoreGraphics
and QuartzCore (the latter solely to evaluate system springs through the same `CASpringAnimation` CA
renders) and stores at most one analytic track per stable `ListAnimationOwner` and
`ListAnimatedProperty`.
```

- [ ] **Step 4: Add a CHANGELOG entry**

Insert at the top of `## Landed work` in `docs/plans/CHANGELOG.md`:

```markdown
- **2026-07-28 — CAAnimationUtils parity**
  ([design](../superpowers/specs/2026-07-28-corelist-caanimationutils-parity-design.md)): CoreList
  stopped sampling curves into 240Hz keyframes. Both emitters now build through one shared factory
  holding a copy of `CAAnimationUtils.makeAnimation`'s branch tree, so a chat row under the CoreList
  backend moves exactly like one under `ListViewImpl` — including the real `CASpringAnimation` at
  duration 0.5, which CoreList previously rendered as a sampled bezier. The model's solver dropped
  Display's 0.997 clamp (the clamp was the entire 2.9e-3 error; 4-iteration Newton was already exact
  to 4.4e-16) and evaluates system springs through the private `valueAt:`. Keyframes remain only in
  the physics deceleration flights. Verified by a paused-layer sweep per curve comparing rendered
  presentation against `track.value(at:)`.
```

- [ ] **Step 5: Final full suite**

```bash
cd submodules/TelegramUI/Components/CoreList
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro K2' \
  -parallel-testing-enabled NO -collect-test-diagnostics never test 2>&1 | tail -20
```

- [ ] **Step 6: Manual check**

Run the demo on K2 and exercise insert/delete/reorder/inset. Then enable `coreListChatBackend` and scroll/send in a chat — the spring paths are what changed, and a keyboard-driven inset transition is the likeliest way to hit `.Spring(duration: 0.5)`. Use `mcp__XcodeBuildMCP__*`; if those tools are absent from the session, say so and hand this step to the user rather than using `cliclick`/`osascript`.

- [ ] **Step 7: Commit**

```bash
git add CLAUDE.md docs/plans/CHANGELOG.md
git commit -m "docs(corelist): record CAAnimationUtils parity

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Deferred

- **Adopting `speed = 1/k` instead of pre-scaled durations.** Would match `CAAnimationUtils`'
  mechanism exactly, but requires moving the model's deadlines and reap scheduling onto a logical
  clock. No visible difference; see the design's §2.
- **The unused executor surface.** `setPositionX`, `setBoundsHeight`, `setBoundsWidth`,
  `setBoundsOriginY`, `setOpacity`, `setAlpha`, `setScale`, `animateView`, and `animateScalar` have
  no callers outside the type and its tests. Trim once the chat item views' `ListViewItemUpdateAnimation`
  mapping lands and it is clear which survive.
