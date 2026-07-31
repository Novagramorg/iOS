# CoreListTransition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace CoreList's bespoke `ListAnimationSpec`/`ListAnimationCurve` animation descriptor and its 20 scattered `CATransaction` blocks with a self-contained, ComponentTransition-shaped `CoreListTransition`, and pass that transition into `CoreListItem.apply(to:transition:)` and `CoreListItemView.update(width:transition:)`.

**Architecture:** `ListAnimationModel` remains the sole presentation authority — tracks, generations, C0-continuous retargeting, and `CoreAnimationCompiler`'s explicitly-timed keyframes are untouched. `CoreListTransition` is (a) the `duration + curve` descriptor that flows into that model, (b) an imperative executor that item views use for their own content animation, and (c) the single owner of every `CATransaction` scope in the module. Design: [`../specs/2026-07-27-corelist-transition-design.md`](../specs/2026-07-27-corelist-transition-design.md).

**Tech Stack:** Swift 5, UIKit, QuartzCore. No new dependencies — CoreList's Bazel target has no `deps` and the demo builds standalone in Xcode, which is exactly why the type is vendored rather than imported.

## Global Constraints

- **Working directory:** `submodules/TelegramUI/Components/CoreList` for every `xcodebuild` command. Paths below are relative to it unless prefixed with `submodules/`.
- **Simulator:** only `iPhone 17 Pro K2`. If unavailable, stop and ask.
- **Every test command** must pass `-parallel-testing-enabled NO`.
- **Baseline:** the suite is at **535** passing before Task 1 — the "480" figure in older notes is stale — and **552** after Task 1 adds `CoreListTransitionCurveTests`. Any task that ends with fewer passing tests than it started with is not done.
- **Commit hygiene:** stage only task-named files with explicit paths. Never `git add .` or `git add -A` — the tree carries unrelated WIP. Never amend, never push.
- **Branch:** work on the current branch (`feature/listviewitem-neighbor-descriptors`). Do not switch or create branches.
- **`ListAnimationModel` is not to be modified beyond retyping its curve parameter and deleting its duration-only overloads.** No changes to track semantics, generations, epsilons, or retarget rules.
- **`CoreAnimationCompiler` must never scale a duration.** Scaling happens once, in `ListAnimationController`. The executor path scales inside `CALayer.animate`. The two paths never meet.
- **Every branch on a transition tests `isImmediate`**, never `if case .none`.
- **Exact curve constants:** `.easeInOut` = `bezierPoint(0.42, 0, 0.58, 1)`, `.easeIn` = `bezierPoint(0.42, 0, 1, 1)`, `.spring` = `bezierPoint(0.23, 1, 0.32, 1)`, `.linear` = identity, `.slide` = `.custom(0.33, 0.52, 0.25, 0.99)`.

**Test commands:**

```bash
# full suite
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro K2' \
  -parallel-testing-enabled NO test

# one class
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro K2' \
  -parallel-testing-enabled NO test \
  -only-testing:CoreListDemoTests/CoreListTransitionCurveTests
```

---

## File Structure

| File | Responsibility |
|---|---|
| `CoreListDemo/Transition/CoreListTransition.swift` | **Create.** The value type: `Animation`/`Curve`, `isImmediate`, `duration`/`curve`/`scaled(by:)`, `withAnimation`/`userData`, the imperative setters, and `commit()` — the module's only `CATransaction` scope. |
| `CoreListDemo/Transition/CoreListTransition+Curve.swift` | **Create.** `bezierPoint` Newton solver (copied from `Display/Source/Spring.swift`) and `Curve.solve(at:)`. Pure math, no UIKit. |
| `CoreListDemo/Transition/CALayer+CoreListAnimate.swift` | **Create.** `CALayer.animate(from:to:keyPath:…curve:…)` for the executor, applying `UIView.animationDurationFactor` once. |
| `CoreListDemoTests/CoreListTransitionCurveTests.swift` | **Create.** Curve solver correctness, `isImmediate` semantics, setter equality early-outs. |
| `CoreListDemoTests/TransitionPropagationTests.swift` | **Create.** Which transition each `update`/`apply` call receives. |
| `CoreListDemo/ListAnimationModel.swift` | Delete `ListAnimationSpec`/`ListAnimationCurve`; retype `ListAnimationTrack.curve`; drop duration-only overloads. |
| `CoreListDemo/ListAnimationController.swift` | `write*` helpers become `.immediate` setters; `animation:`/`logicalDuration:` params become `transition:`. |
| `CoreListDemo/CoreAnimationCompiler.swift` | `install`/`remove` use `CoreListTransition.commit`. |
| `CoreListDemo/CoreVirtualListView.swift` | Protocol changes, `reconciledIdentities` propagation, 9 `CATransaction` blocks, `transition:` parameter. |
| `CoreListDemo/InsetRectOverlayAnimator.swift` | `transition:` parameter, 1 `CATransaction` block. |
| `CoreListDemo/PhysicsScrollEngine.swift`, `CoreListDemo/PhysicsScrollView.swift` | 3 completion-only `CATransaction` blocks. |
| `CoreListDemo/DemoRow.swift`, `CoreListDemo/ViewController.swift` | New `update`/`apply` signatures; `DemoRow` demonstrates the executor. |
| `submodules/TelegramUI/Sources/CoreListTransitionBridge.swift` | **Create.** `ComponentTransition` ⇄ `CoreListTransition`. |
| `submodules/TelegramUI/Sources/CoreListChatHistoryBackend.swift` | New signatures + `.easeInOut`. |
| `CLAUDE.md` | Item protocol, curve names, two new gotchas. |

---

### Task 1: The vendored transition type

Purely additive — nothing references it yet, so the module keeps compiling throughout.

**Files:**
- Create: `CoreListDemo/Transition/CoreListTransition.swift`
- Create: `CoreListDemo/Transition/CoreListTransition+Curve.swift`
- Create: `CoreListDemo/Transition/CALayer+CoreListAnimate.swift`
- Test: `CoreListDemoTests/CoreListTransitionCurveTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `CoreListTransition` with `init(animation:)`, `static var immediate`, `static func easeInOut(duration: Double)`, `static func spring(duration: Double)`, `var animation: Animation`, `var isImmediate: Bool`, `var duration: TimeInterval`, `var curve: Animation.Curve?`, `func scaled(by: Double) -> CoreListTransition`, `func withAnimation(_:)`, `func withAnimationIfAnimated(_:)`, `func userData<T>(_:)`, `func withUserData(_:)`. `CoreListTransition.Animation` = `.none | .curve(duration: Double, curve: Curve)`, both `Equatable`. `CoreListTransition.Animation.Curve` = `.easeInOut | .easeIn | .spring | .linear | .custom(Float, Float, Float, Float) | .bounce(stiffness: CGFloat, damping: CGFloat)`, `Equatable`, with `static var slide` and `func solve(at: CGFloat) -> CGFloat`. Free function `coreListBezierPoint(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, _ x: CGFloat) -> CGFloat`. `CALayer.animate(from:to:keyPath:duration:delay:curve:removeOnCompletion:additive:completion:key:)`.

- [ ] **Step 1: Write the failing curve tests**

Create `CoreListDemoTests/CoreListTransitionCurveTests.swift`:

```swift
import XCTest
import QuartzCore
@testable import CoreListDemo

final class CoreListTransitionCurveTests: XCTestCase {
    // MARK: - Curve solve

    func testEaseInOutMatchesDisplayBezier() {
        // bezierPoint(0.42, 0, 0.58, 1, x). Values computed from the same Newton solver
        // Display uses; see the design doc's verification table.
        XCTAssertEqual(CoreListTransition.Animation.Curve.easeInOut.solve(at: 0.25),
                       0.12916193104731982, accuracy: 1e-12)
        XCTAssertEqual(CoreListTransition.Animation.Curve.easeInOut.solve(at: 0.75),
                       0.87083806895268023, accuracy: 1e-12)
    }

    func testEaseInOutIsSymmetricAboutMidpoint() {
        // Load-bearing: every existing test assertion sampling phase 0.5 keeps its expected
        // value across the smoothstep -> easeInOut swap because of this exact identity.
        XCTAssertEqual(CoreListTransition.Animation.Curve.easeInOut.solve(at: 0.5), 0.5,
                       accuracy: 1e-15)
    }

    func testEveryCurveHasExactEndpoints() {
        let curves: [CoreListTransition.Animation.Curve] = [
            .easeInOut, .easeIn, .spring, .linear,
            .custom(1.0 / 3.0, 0.0, 2.0 / 3.0, 1.0)
        ]
        for curve in curves {
            XCTAssertEqual(curve.solve(at: 0), 0, accuracy: 1e-15, "\(curve) at 0")
            XCTAssertEqual(curve.solve(at: 1), 1, accuracy: 1e-15, "\(curve) at 1")
        }
    }

    func testEveryCurveIsMonotonicAndClamps() {
        let curves: [CoreListTransition.Animation.Curve] = [
            .easeInOut, .easeIn, .spring, .linear,
            .custom(1.0 / 3.0, 0.0, 2.0 / 3.0, 1.0)
        ]
        for curve in curves {
            var previous = curve.solve(at: 0)
            for step in 1...200 {
                let value = curve.solve(at: CGFloat(step) / 200.0)
                XCTAssertGreaterThanOrEqual(value, previous - 1e-12, "\(curve) at \(step)")
                previous = value
            }
            // Out-of-range input is clamped, not extrapolated.
            XCTAssertEqual(curve.solve(at: -0.5), 0, accuracy: 1e-15)
            XCTAssertEqual(curve.solve(at: 1.5), 1, accuracy: 1e-15)
        }
    }

    func testLinearIsIdentity() {
        for step in 0...10 {
            let x = CGFloat(step) / 10.0
            XCTAssertEqual(CoreListTransition.Animation.Curve.linear.solve(at: x), x,
                           accuracy: 1e-15)
        }
    }

    // The two curves the old ListAnimationCurve carried are exact cubic beziers. Task 3 relies
    // on this to prove the type swap changes no motion, so it is pinned here.
    func testSmoothstepIsExactlyACustomBezier() {
        let curve = CoreListTransition.Animation.Curve.custom(1.0 / 3.0, 0.0, 2.0 / 3.0, 1.0)
        for step in 0...100 {
            let x = CGFloat(step) / 100.0
            let smoothstep = x * x * (3 - 2 * x)
            let expected = smoothstep >= 0.997 ? 1.0 : smoothstep
            XCTAssertEqual(curve.solve(at: x), expected, accuracy: 1e-12, "at \(x)")
        }
    }

    func testCubicEaseOutIsExactlyACustomBezier() {
        let curve = CoreListTransition.Animation.Curve.custom(1.0 / 3.0, 1.0, 2.0 / 3.0, 1.0)
        for step in 0...100 {
            let x = CGFloat(step) / 100.0
            let inverse = 1 - x
            let easeOut = 1 - inverse * inverse * inverse
            let expected = easeOut >= 0.997 ? 1.0 : easeOut
            XCTAssertEqual(curve.solve(at: x), expected, accuracy: 1e-12, "at \(x)")
        }
    }

    // MARK: - isImmediate

    func testZeroDurationIsImmediate() {
        XCTAssertTrue(CoreListTransition.immediate.isImmediate)
        XCTAssertTrue(CoreListTransition.easeInOut(duration: 0).isImmediate)
        XCTAssertTrue(CoreListTransition(animation: .curve(duration: -1, curve: .linear))
                        .isImmediate)
        XCTAssertFalse(CoreListTransition.easeInOut(duration: 0.3).isImmediate)
    }

    func testDurationAndCurveAccessors() {
        XCTAssertEqual(CoreListTransition.immediate.duration, 0)
        XCTAssertNil(CoreListTransition.immediate.curve)
        let transition = CoreListTransition.easeInOut(duration: 0.4)
        XCTAssertEqual(transition.duration, 0.4, accuracy: 1e-12)
        XCTAssertEqual(transition.curve, .easeInOut)
    }

    func testScaledMultipliesDurationAndKeepsCurve() {
        let scaled = CoreListTransition.easeInOut(duration: 0.5).scaled(by: 10)
        XCTAssertEqual(scaled.duration, 5, accuracy: 1e-12)
        XCTAssertEqual(scaled.curve, .easeInOut)
        // A negative factor cannot produce a negative duration.
        XCTAssertEqual(CoreListTransition.easeInOut(duration: 0.5).scaled(by: -2).duration, 0)
        // Scaling .none stays .none.
        XCTAssertTrue(CoreListTransition.immediate.scaled(by: 10).isImmediate)
    }

    func testEqualityComparesAnimationAndIgnoresUserData() {
        let a = CoreListTransition.easeInOut(duration: 0.3)
        let b = CoreListTransition.easeInOut(duration: 0.3).withUserData("tag")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, CoreListTransition.easeInOut(duration: 0.4))
        XCTAssertEqual(b.userData(String.self), "tag")
    }

    // MARK: - Executor

    func testImmediateSetterWritesValueAndLeavesNoAnimation() {
        let layer = CALayer()
        layer.position = CGPoint(x: 0, y: 10)
        CoreListTransition.immediate.setPositionY(layer: layer, 40)
        XCTAssertEqual(layer.position.y, 40, accuracy: 1e-12)
        XCTAssertNil(layer.animation(forKey: "position"))
    }

    func testAnimatedSetterWritesFinalValueAndInstallsAnimation() {
        let layer = CALayer()
        layer.position = CGPoint(x: 0, y: 10)
        CoreListTransition.easeInOut(duration: 0.3).setPositionY(layer: layer, 40)
        XCTAssertEqual(layer.position.y, 40, accuracy: 1e-12)
        XCTAssertNotNil(layer.animation(forKey: "position"))
    }

    func testSetterEarlyOutsOnEqualTarget() {
        let layer = CALayer()
        layer.position = CGPoint(x: 0, y: 40)
        CoreListTransition.easeInOut(duration: 0.3).setPositionY(layer: layer, 40)
        XCTAssertNil(layer.animation(forKey: "position"),
                     "an equal target must not install an animation")
    }

    func testAnimateScalesDurationByAnimationDurationFactor() throws {
        UIView.debugAnimationDurationFactorOverride = 4
        defer { UIView.debugAnimationDurationFactorOverride = nil }
        let layer = CALayer()
        layer.animate(from: 0, to: 1, keyPath: "opacity",
                      duration: 0.25, delay: 0, curve: .linear,
                      removeOnCompletion: true, additive: false)
        let animation = try XCTUnwrap(layer.animation(forKey: "opacity"))
        XCTAssertEqual(animation.duration, 1.0, accuracy: 1e-9)
    }

    func testSetTransformWritesAndAnimates() throws {
        let layer = CALayer()
        let target = CATransform3DMakeRotation(0.5, 0, 0, 1)
        CoreListTransition.immediate.setTransform(layer: layer, transform: target)
        XCTAssertTrue(CATransform3DEqualToTransform(layer.transform, target))
        XCTAssertNil(layer.animation(forKey: "transform"))
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro K2' \
  -parallel-testing-enabled NO test \
  -only-testing:CoreListDemoTests/CoreListTransitionCurveTests
```

Expected: compile failure — `cannot find 'CoreListTransition' in scope`.

- [ ] **Step 3: Write the bézier solver**

Create `CoreListDemo/Transition/CoreListTransition+Curve.swift`:

```swift
import CoreGraphics

// Cubic-bezier solver copied from Display/Source/Spring.swift so CoreList stays dependency-free.
// Do not "improve" the algorithm: ComponentFlow's curves are defined by exactly these four Newton
// iterations and the 0.997 clamp, and CoreList's parity with them depends on matching it.

private func bezierA(_ a1: CGFloat, _ a2: CGFloat) -> CGFloat { 1.0 - 3.0 * a2 + 3.0 * a1 }
private func bezierB(_ a1: CGFloat, _ a2: CGFloat) -> CGFloat { 3.0 * a2 - 6.0 * a1 }
private func bezierC(_ a1: CGFloat) -> CGFloat { 3.0 * a1 }

private func calcBezier(_ t: CGFloat, _ a1: CGFloat, _ a2: CGFloat) -> CGFloat {
    ((bezierA(a1, a2) * t + bezierB(a1, a2)) * t + bezierC(a1)) * t
}

private func calcSlope(_ t: CGFloat, _ a1: CGFloat, _ a2: CGFloat) -> CGFloat {
    3.0 * bezierA(a1, a2) * t * t + 2.0 * bezierB(a1, a2) * t + bezierC(a1)
}

private func getTForX(_ x: CGFloat, _ x1: CGFloat, _ x2: CGFloat) -> CGFloat {
    var t = x
    var i = 0
    while i < 4 {
        let currentSlope = calcSlope(t, x1, x2)
        if currentSlope == 0.0 { return t }
        t -= (calcBezier(t, x1, x2) - x) / currentSlope
        i += 1
    }
    return t
}

func coreListBezierPoint(_ x1: CGFloat, _ y1: CGFloat,
                         _ x2: CGFloat, _ y2: CGFloat,
                         _ x: CGFloat) -> CGFloat {
    var value = calcBezier(getTForX(x, x1, x2), y1, y2)
    if value >= 0.997 { value = 1.0 }
    return value
}

public extension CoreListTransition.Animation.Curve {
    /// Progress at unit phase `offset`. Mirrors `ComponentTransition.Animation.Curve.solve(at:)`.
    ///
    /// `.spring` uses Display's own pre-iOS-9 bezier fallback rather than the private
    /// `springAnimationValueAt`, and `.bounce` is not a unit curve at all — ComponentFlow's own
    /// `solve` asserts on it and routes to private spring API instead. Both are documented
    /// approximations; CoreList adopts neither as a default.
    func solve(at offset: CGFloat) -> CGFloat {
        let x = min(max(offset, 0.0), 1.0)
        switch self {
        case .easeInOut:
            return coreListBezierPoint(0.42, 0.0, 0.58, 1.0, x)
        case .easeIn:
            return coreListBezierPoint(0.42, 0.0, 1.0, 1.0, x)
        case .spring:
            return coreListBezierPoint(0.23, 1.0, 0.32, 1.0, x)
        case .linear:
            return x
        case let .custom(c1x, c1y, c2x, c2y):
            return coreListBezierPoint(CGFloat(c1x), CGFloat(c1y), CGFloat(c2x), CGFloat(c2y), x)
        case .bounce:
            assertionFailure("`.bounce` is not a unit curve; CoreList samples `.spring` instead")
            return coreListBezierPoint(0.23, 1.0, 0.32, 1.0, x)
        }
    }
}
```

Note `.linear` returns the clamped `x` **without** the 0.997 clamp — identity must stay identity, matching `listViewAnimationCurveLinear`.

- [ ] **Step 4: Write the layer animation helper**

Create `CoreListDemo/Transition/CALayer+CoreListAnimate.swift`:

```swift
import UIKit
import QuartzCore

extension CALayer {
    /// Executor-path animation. Samples the curve into a keyframe animation, which is how CoreList
    /// renders every curve (`CoreAnimationCompiler` does the same for model tracks) — so `.custom`
    /// and `.spring` need no `CAMediaTimingFunction` equivalent.
    ///
    /// Duration is scaled by `UIView.animationDurationFactor` HERE, exactly once, mirroring
    /// Display's `CAAnimationUtils`. The model path scales in `ListAnimationController` and never
    /// reaches this function; see the design doc's "two authorities, one scaling rule".
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

        let sampleCount = max(2, Int(ceil(scaledDuration * 240.0)) + 1)
        let lastIndex = sampleCount - 1
        var values: [NSNumber] = []
        var keyTimes: [NSNumber] = []
        values.reserveCapacity(sampleCount)
        keyTimes.reserveCapacity(sampleCount)
        for index in 0...lastIndex {
            let phase = CGFloat(index) / CGFloat(lastIndex)
            values.append(NSNumber(value: Double(from + (to - from) * curve.solve(at: phase))))
            keyTimes.append(NSNumber(value: Double(phase)))
        }

        let animation = CAKeyframeAnimation(keyPath: keyPath)
        animation.values = values
        animation.keyTimes = keyTimes
        animation.calculationMode = .linear
        animation.duration = scaledDuration
        animation.isAdditive = additive
        animation.isRemovedOnCompletion = removeOnCompletion
        animation.fillMode = removeOnCompletion ? .forwards : .both
        if delay > 0 {
            animation.beginTime = convertTime(CACurrentMediaTime(), from: nil) + delay * factor
        }
        if let completion {
            CoreListTransition.commit(disablingImplicitActions: true,
                                      completion: { completion(true) }) {
                self.add(animation, forKey: key ?? keyPath)
            }
        } else {
            CoreListTransition.commit { self.add(animation, forKey: key ?? keyPath) }
        }
    }

    /// `NSNumber`-typed overload for callers that already hold boxed values.
    func animate(from: NSNumber,
                 to: NSNumber,
                 keyPath: String,
                 duration: Double,
                 delay: Double = 0.0,
                 curve: CoreListTransition.Animation.Curve,
                 removeOnCompletion: Bool = true,
                 additive: Bool = false,
                 completion: ((Bool) -> Void)? = nil,
                 key: String? = nil) {
        animate(from: CGFloat(from.doubleValue), to: CGFloat(to.doubleValue), keyPath: keyPath,
                duration: duration, delay: delay, curve: curve,
                removeOnCompletion: removeOnCompletion, additive: additive,
                completion: completion, key: key)
    }
}
```

- [ ] **Step 5: Write the value type and its setters**

Create `CoreListDemo/Transition/CoreListTransition.swift`. Header comment, value model, then setters:

```swift
import UIKit
import QuartzCore

/// A ComponentTransition-shaped animation descriptor, vendored into CoreList.
///
/// CoreList cannot depend on ComponentFlow — its Bazel target has no `deps` and the demo builds
/// standalone in Xcode — so this is a self-contained copy of the value model in
/// `submodules/ComponentFlow/Source/Base/Transition.swift`. The `Animation`/`Curve` case shape is
/// identical, so `CoreListTransitionBridge.swift` in TelegramUI maps between the two case-for-case.
///
/// Deliberate divergences, all recorded in
/// `docs/superpowers/specs/2026-07-27-corelist-transition-design.md`:
///
/// - **A zero duration is immediate.** ComponentFlow treats only `.none` as immediate;
///   `.curve(duration: 0, …)` still animates there. CoreList's model settles a zero-duration
///   property immediately and half its test suite says "no animation" as `duration: 0`, so every
///   branch here tests `isImmediate` and none writes `if case .none`.
/// - **`.spring` is an approximation** (Display's bezier fallback, not the private
///   `springAnimationValueAt`), and **`.bounce` is not a unit curve** — ComponentFlow's own `solve`
///   asserts on it too. CoreList adopts neither as a default; both are supported on input.
/// - **Additions over ComponentTransition:** `Animation`/`Curve` are `Equatable` (because
///   `ListAnimationTrack` is), the struct has a hand-written `==` over `animation` alone
///   (`_userData: [Any]` blocks synthesis), and `duration`/`curve`/`scaled(by:)` carry over from the
///   deleted `ListAnimationSpec`.
/// - **Not vendored:** shape-layer, gradient, blur, mesh, parabolic, and keyframe-transform helpers.
///   No CoreList consumer, and several need private API.
public struct CoreListTransition: Equatable {
    public enum Animation: Equatable {
        public enum Curve: Equatable {
            case easeInOut
            case easeIn
            case spring
            case linear
            case custom(Float, Float, Float, Float)
            case bounce(stiffness: CGFloat, damping: CGFloat)

            public static var slide: Curve { .custom(0.33, 0.52, 0.25, 0.99) }
        }

        case none
        case curve(duration: Double, curve: Curve)
    }

    public var animation: Animation
    private var _userData: [Any] = []

    public init(animation: Animation) {
        self.animation = animation
    }

    public static var immediate: CoreListTransition { CoreListTransition(animation: .none) }

    public static func easeInOut(duration: Double) -> CoreListTransition {
        CoreListTransition(animation: .curve(duration: duration, curve: .easeInOut))
    }

    public static func spring(duration: Double) -> CoreListTransition {
        CoreListTransition(animation: .curve(duration: duration, curve: .spring))
    }

    /// True when this transition must settle its target with no animation. Unlike ComponentFlow,
    /// a non-positive duration counts: CoreList's model settles such a property immediately.
    public var isImmediate: Bool {
        switch self.animation {
        case .none:
            return true
        case let .curve(duration, _):
            return duration <= 0
        }
    }

    public var duration: TimeInterval {
        switch self.animation {
        case .none:
            return 0
        case let .curve(duration, _):
            return max(0, duration)
        }
    }

    public var curve: Animation.Curve? {
        switch self.animation {
        case .none:
            return nil
        case let .curve(_, curve):
            return curve
        }
    }

    /// Multiplies the duration, keeping the curve. Used by `ListAnimationController` to apply the
    /// Slow Animations factor exactly once on the model path.
    public func scaled(by factor: Double) -> CoreListTransition {
        switch self.animation {
        case .none:
            return self
        case let .curve(duration, curve):
            var result = self
            result.animation = .curve(duration: max(0, duration * factor), curve: curve)
            return result
        }
    }

    public func withAnimation(_ animation: Animation) -> CoreListTransition {
        var result = self
        result.animation = animation
        return result
    }

    public func withAnimationIfAnimated(_ animation: Animation) -> CoreListTransition {
        if self.isImmediate { return self }
        return self.withAnimation(animation)
    }

    public func userData<T>(_ type: T.Type) -> T? {
        for item in self._userData.reversed() {
            if let item = item as? T { return item }
        }
        return nil
    }

    public func withUserData(_ userData: Any) -> CoreListTransition {
        var result = self
        result._userData.append(userData)
        return result
    }

    /// `_userData` is `[Any]` and cannot participate; equality is the animation alone.
    public static func == (lhs: CoreListTransition, rhs: CoreListTransition) -> Bool {
        lhs.animation == rhs.animation
    }
}
```

Then, in the same file, the `commit` scope and the setters. `commit` is added here in Task 1 because `CALayer.animate` already calls it; Task 2 is what migrates the existing call sites onto it.

```swift
public extension CoreListTransition {
    /// The module's ONLY `CATransaction` scope. Every settled write, every animation install, and
    /// the physics deceleration flights go through this; `CATransaction` must not be named anywhere
    /// else in CoreList. Verified by the grep guard in the plan's final task.
    ///
    /// - Parameter disablingImplicitActions: mirrors `CATransaction.setDisableActions`. The
    ///   deceleration-flight sites pass `false` deliberately — they never disabled actions.
    /// - Parameter completion: mirrors `CATransaction.setCompletionBlock`.
    static func commit(disablingImplicitActions: Bool = true,
                       completion: (() -> Void)? = nil,
                       _ body: () -> Void) {
        CATransaction.begin()
        if disablingImplicitActions {
            CATransaction.setDisableActions(true)
        }
        if let completion {
            CATransaction.setCompletionBlock(completion)
        }
        body()
        CATransaction.commit()
    }

    // MARK: - Setters
    //
    // Each early-outs on an equal target, exactly as ComponentTransition's do, and each writes the
    // final value before installing an animation. `.immediate` writes inside `commit` so an
    // enclosing UIView animation block cannot capture the write implicitly.

    func setPositionY(layer: CALayer, _ value: CGFloat) {
        if layer.position.y == value { return }
        if self.isImmediate {
            CoreListTransition.commit {
                layer.position.y = value
                layer.removeAnimation(forKey: "position")
            }
            return
        }
        let previous = layer.presentation()?.position.y ?? layer.position.y
        CoreListTransition.commit { layer.position.y = value }
        self.animateScalar(layer: layer, keyPath: "position.y", from: previous, to: value)
    }

    func setPositionX(layer: CALayer, _ value: CGFloat) {
        if layer.position.x == value { return }
        if self.isImmediate {
            CoreListTransition.commit {
                layer.position.x = value
                layer.removeAnimation(forKey: "position")
            }
            return
        }
        let previous = layer.presentation()?.position.x ?? layer.position.x
        CoreListTransition.commit { layer.position.x = value }
        self.animateScalar(layer: layer, keyPath: "position.x", from: previous, to: value)
    }

    func setPosition(layer: CALayer, _ position: CGPoint) {
        self.setPositionX(layer: layer, position.x)
        self.setPositionY(layer: layer, position.y)
    }

    func setBoundsHeight(layer: CALayer, _ value: CGFloat) {
        if layer.bounds.size.height == value { return }
        if self.isImmediate {
            CoreListTransition.commit {
                layer.bounds.size.height = value
                layer.removeAnimation(forKey: "bounds.size.height")
            }
            return
        }
        let previous = layer.presentation()?.bounds.size.height ?? layer.bounds.size.height
        CoreListTransition.commit { layer.bounds.size.height = value }
        self.animateScalar(layer: layer, keyPath: "bounds.size.height", from: previous, to: value)
    }

    func setBoundsWidth(layer: CALayer, _ value: CGFloat) {
        if layer.bounds.size.width == value { return }
        if self.isImmediate {
            CoreListTransition.commit {
                layer.bounds.size.width = value
                layer.removeAnimation(forKey: "bounds.size.width")
            }
            return
        }
        let previous = layer.presentation()?.bounds.size.width ?? layer.bounds.size.width
        CoreListTransition.commit { layer.bounds.size.width = value }
        self.animateScalar(layer: layer, keyPath: "bounds.size.width", from: previous, to: value)
    }

    func setBoundsOriginY(layer: CALayer, _ value: CGFloat) {
        if layer.bounds.origin.y == value { return }
        if self.isImmediate {
            CoreListTransition.commit {
                layer.bounds.origin.y = value
                layer.removeAnimation(forKey: "bounds.origin.y")
            }
            return
        }
        let previous = layer.presentation()?.bounds.origin.y ?? layer.bounds.origin.y
        CoreListTransition.commit { layer.bounds.origin.y = value }
        self.animateScalar(layer: layer, keyPath: "bounds.origin.y", from: previous, to: value)
    }

    func setOpacity(layer: CALayer, _ value: CGFloat) {
        if layer.opacity == Float(value) { return }
        if self.isImmediate {
            CoreListTransition.commit {
                layer.opacity = Float(value)
                layer.removeAnimation(forKey: "opacity")
            }
            return
        }
        let previous = CGFloat(layer.presentation()?.opacity ?? layer.opacity)
        CoreListTransition.commit { layer.opacity = Float(value) }
        self.animateScalar(layer: layer, keyPath: "opacity", from: previous, to: value)
    }

    func setAlpha(view: UIView, _ value: CGFloat) {
        self.setOpacity(layer: view.layer, value)
    }

    func setFrame(view: UIView, frame: CGRect) {
        self.setFrame(layer: view.layer, frame: frame)
    }

    func setFrame(layer: CALayer, frame: CGRect) {
        if layer.frame == frame { return }
        if self.isImmediate {
            CoreListTransition.commit { layer.frame = frame }
            return
        }
        let anchor = layer.anchorPoint
        self.setBoundsWidth(layer: layer, frame.width)
        self.setBoundsHeight(layer: layer, frame.height)
        self.setPosition(layer: layer,
                         CGPoint(x: frame.minX + frame.width * anchor.x,
                                 y: frame.minY + frame.height * anchor.y))
    }

    func setScale(layer: CALayer, _ scale: CGFloat) {
        let current = sqrt((layer.transform.m11 * layer.transform.m11)
                           + (layer.transform.m12 * layer.transform.m12)
                           + (layer.transform.m13 * layer.transform.m13))
        if current == scale { return }
        if self.isImmediate {
            CoreListTransition.commit {
                layer.transform = CATransform3DMakeScale(scale, scale, 1.0)
                layer.removeAnimation(forKey: "transform.scale")
            }
            return
        }
        CoreListTransition.commit { layer.transform = CATransform3DMakeScale(scale, scale, 1.0) }
        self.animateScalar(layer: layer, keyPath: "transform.scale", from: current, to: scale)
    }

    func setScale(view: UIView, _ scale: CGFloat) {
        self.setScale(layer: view.layer, scale)
    }

    func setTransform(layer: CALayer, transform: CATransform3D) {
        if CATransform3DEqualToTransform(layer.transform, transform) { return }
        if self.isImmediate {
            CoreListTransition.commit {
                layer.transform = transform
                layer.removeAnimation(forKey: "transform")
            }
            return
        }
        // A CATransform3D is not a scalar, so this samples the keyframes itself rather than going
        // through animateScalar.
        guard case let .curve(duration, curve) = self.animation, duration > 0 else { return }
        let previous = layer.presentation()?.transform ?? layer.transform
        CoreListTransition.commit { layer.transform = transform }
        let scaledDuration = max(0.0, duration * UIView.animationDurationFactor)
        let sampleCount = max(2, Int(ceil(scaledDuration * 240.0)) + 1)
        var values: [NSValue] = []
        var keyTimes: [NSNumber] = []
        for index in 0..<sampleCount {
            let phase = CGFloat(index) / CGFloat(sampleCount - 1)
            let t = curve.solve(at: phase)
            var interpolated = CATransform3DIdentity
            // Element-wise interpolation. Correct for the affine transforms CoreList item views
            // use (translate / scale / rotate about z); it is not a general matrix interpolation.
            withUnsafeBytes(of: previous) { fromBytes in
                withUnsafeBytes(of: transform) { toBytes in
                    withUnsafeMutableBytes(of: &interpolated) { outBytes in
                        let from = fromBytes.bindMemory(to: CGFloat.self)
                        let to = toBytes.bindMemory(to: CGFloat.self)
                        let out = outBytes.bindMemory(to: CGFloat.self)
                        for i in 0..<16 {
                            out[i] = from[i] + (to[i] - from[i]) * t
                        }
                    }
                }
            }
            values.append(NSValue(caTransform3D: interpolated))
            keyTimes.append(NSNumber(value: Double(phase)))
        }
        let animation = CAKeyframeAnimation(keyPath: "transform")
        animation.values = values
        animation.keyTimes = keyTimes
        animation.calculationMode = .linear
        animation.duration = scaledDuration
        animation.isRemovedOnCompletion = true
        animation.fillMode = .forwards
        CoreListTransition.commit { layer.add(animation, forKey: "transform") }
    }

    func setTransform(view: UIView, transform: CATransform3D) {
        self.setTransform(layer: view.layer, transform: transform)
    }

    /// Scalar animation primitive. All setters funnel here so duration scaling and the sampled-curve
    /// rendering live in one place.
    func animateScalar(layer: CALayer,
                       keyPath: String,
                       from: CGFloat,
                       to: CGFloat,
                       additive: Bool = false,
                       completion: ((Bool) -> Void)? = nil) {
        guard case let .curve(duration, curve) = self.animation, duration > 0 else {
            completion?(true)
            return
        }
        layer.animate(from: from, to: to, keyPath: keyPath, duration: duration, delay: 0,
                      curve: curve, removeOnCompletion: true, additive: additive,
                      completion: completion)
    }

    /// UIView-block animation, for item views laying out with UIKit rather than layer writes.
    /// `.custom` and `.bounce` degrade to ease-in-out options: faithful handling needs
    /// `CALayerSpringParametersOverride`, which is private API CoreList cannot reach.
    func animateView(allowUserInteraction: Bool = true,
                     delay: Double = 0.0,
                     _ body: @escaping () -> Void,
                     completion: ((Bool) -> Void)? = nil) {
        guard case let .curve(duration, curve) = self.animation, duration > 0 else {
            body()
            completion?(true)
            return
        }
        var options: UIView.AnimationOptions
        switch curve {
        case .linear:
            options = [.curveLinear]
        case .easeIn:
            options = [.curveEaseIn]
        case .spring:
            options = UIView.AnimationOptions(rawValue: 7 << 16)
        case .easeInOut, .custom, .bounce:
            options = [.curveEaseInOut]
        }
        if allowUserInteraction {
            options.insert(.allowUserInteraction)
        }
        UIView.animate(withDuration: duration * UIView.animationDurationFactor,
                       delay: delay * UIView.animationDurationFactor,
                       options: options,
                       animations: body,
                       completion: completion)
    }
}
```

- [ ] **Step 6: Run the new tests to verify they pass**

```bash
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro K2' \
  -parallel-testing-enabled NO test \
  -only-testing:CoreListDemoTests/CoreListTransitionCurveTests
```

Expected: PASS. If `testEaseInOutMatchesDisplayBezier` fails, the solver deviates from Display's — do **not** adjust the expected values; find the deviation in the copied algorithm.

- [ ] **Step 7: Run the full suite to confirm nothing regressed**

The three new files are additive, so the pre-existing 480 must still pass:

```bash
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro K2' \
  -parallel-testing-enabled NO test 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`, with all 480 pre-existing tests plus the new `CoreListTransitionCurveTests` cases. Record the exact new total — later tasks compare against it.

- [ ] **Step 8: Commit**

```bash
git add CoreListDemo/Transition/CoreListTransition.swift \
        CoreListDemo/Transition/CoreListTransition+Curve.swift \
        CoreListDemo/Transition/CALayer+CoreListAnimate.swift \
        CoreListDemoTests/CoreListTransitionCurveTests.swift
git commit -m "feat(corelist): vendor a ComponentTransition-shaped transition type

Self-contained copy of ComponentFlow's Transition value model: CoreList
has no Bazel deps and the demo builds standalone, so it cannot import
ComponentFlow. Case shape is identical so the host bridge is mechanical.

Divergences are documented at the type: a zero duration is immediate
(CoreList's model settles such a property), .spring uses Display's own
bezier fallback rather than private spring API, and .bounce is not a unit
curve (ComponentFlow's own solve asserts on it too).

Additive: nothing references it yet.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: Route all 20 CATransaction blocks through `commit`

Behavior-preserving. No signatures change, so the full suite is the oracle: it must pass unchanged.

**Files:**
- Modify: `CoreListDemo/ListAnimationController.swift:845-880` (5 blocks)
- Modify: `CoreListDemo/CoreVirtualListView.swift:809, 1152, 1904, 2055, 2120, 2242, 2307, 2739, 2757` (9 blocks)
- Modify: `CoreListDemo/CoreAnimationCompiler.swift:69, 77` (2 blocks)
- Modify: `CoreListDemo/InsetRectOverlayAnimator.swift:36` (1 block)
- Modify: `CoreListDemo/PhysicsScrollEngine.swift:255, 299` (2 blocks)
- Modify: `CoreListDemo/PhysicsScrollView.swift:167` (1 block)

**Interfaces:**
- Consumes: `CoreListTransition.commit(disablingImplicitActions:completion:_:)`, `CoreListTransition.immediate`, and the setters from Task 1.
- Produces: no new API. Afterwards `CATransaction` appears only in `CoreListDemo/Transition/`.

- [ ] **Step 1: Convert the controller's five settled-write helpers**

In `ListAnimationController.swift`, replace the five `write*` bodies (currently `CATransaction.begin()` / `setDisableActions(true)` / one property write / `commit()`):

```swift
    private func writePositionY(_ value: CGFloat, on layer: CALayer) {
        CoreListTransition.immediate.setPositionY(layer: layer, value)
    }

    private func writePositionX(_ value: CGFloat, on layer: CALayer) {
        CoreListTransition.immediate.setPositionX(layer: layer, value)
    }

    private func writeOpacity(_ value: CGFloat, on layer: CALayer) {
        CoreListTransition.immediate.setOpacity(layer: layer, value)
    }

    private func writeHeight(_ value: CGFloat, on layer: CALayer) {
        CoreListTransition.immediate.setBoundsHeight(layer: layer, value)
    }

    private func writeWidth(_ value: CGFloat, on layer: CALayer) {
        CoreListTransition.immediate.setBoundsWidth(layer: layer, value)
    }
```

The setters early-out on an equal target where the old code wrote unconditionally. That is a safe strengthening — writing an identical value was already a no-op — but it also means the `removeAnimation` in the `.immediate` branch is skipped when the value already matches. That matches the old behavior, which had no `removeAnimation` at all.

**These five must stay `.immediate`.** They are the model path: `ListAnimationController` has already scaled its duration by `durationFactor()`, and `CoreAnimationCompiler` emits the animation. Handing an *animated* transition to a setter here would run the write through `CALayer.animate`, which scales again — a silent double-scale under Slow Animations, and two competing animations on the same property.

- [ ] **Step 2: Convert the compiler's install/remove**

In `CoreAnimationCompiler.swift`:

```swift
    func install(_ track: ListAnimationTrack,
                 property: ListAnimatedProperty,
                 on layer: CALayer,
                 completion: (() -> Void)? = nil) {
        guard emitsAnimations else { return }
        let animation = animation(for: track, property: property)
        CoreListTransition.commit(completion: completion) {
            layer.add(animation, forKey: animationKey(for: property))
        }
    }

    func remove(property: ListAnimatedProperty, from layer: CALayer) {
        CoreListTransition.commit {
            layer.removeAnimation(forKey: animationKey(for: property))
        }
    }
```

`CoreAnimationCompiler.swift` imports only `QuartzCore`; add `import UIKit` if the build complains about `CoreListTransition`'s module.

- [ ] **Step 3: Convert the inset overlay animator's frame write**

In `InsetRectOverlayAnimator.swift:36-39`, the block writes `layer.frame = finalFrame` with actions disabled:

```swift
        CoreListTransition.immediate.setFrame(layer: layer, frame: finalFrame)
```

- [ ] **Step 4: Convert the nine `CoreVirtualListView` blocks**

These mix property writes with `addSubview`/`removeFromSuperview`/closure assignment, so they keep the scope form rather than becoming setters. Replace each

```swift
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // …body…
        CATransaction.commit()
```

with

```swift
        CoreListTransition.commit {
            // …body unchanged…
        }
```

Body contents must not change in this task — indentation only. `render()` (`:1904`) is the largest; it sets `container.frame`, then per item `layer.anchorPoint`, `frame`, `layer.opacity`, `onContentDidChange`, and `addSubview`. Leave all of it inside the closure verbatim.

A bare `return` inside a `commit { }` closure would return from the closure rather than the enclosing function, so this was checked ahead of time: **none of the nine bodies contains enclosing-function control flow.** The only `return` that appears inside one is in `render()`'s `onContentDidChange` assignment (`guard let self, let view else { return }`), which is already inside a nested closure and is unaffected. Every other `return`/`continue` near these line numbers sits *after* the `CATransaction.commit()` call, outside the body. If a future edit introduces one, hoist the guard above the `commit` call rather than restructuring inside it.

- [ ] **Step 5: Convert the three deceleration-flight blocks**

`PhysicsScrollEngine.swift:255` and `:299`, and `PhysicsScrollView.swift:167`. These set **only** a completion block — they never disabled implicit actions — so they must pass `disablingImplicitActions: false`. For `PhysicsScrollEngine.swift:255`:

```swift
        CoreListTransition.commit(disablingImplicitActions: false, completion: { [weak self] in
            guard let self, self.flightGeneration == g else { return }   // ignore stale completions
            self.finalizeFlight()
        }) {
            let flightAnim = f.trajectory.boundsOriginKeyframeAnimation(beginTime: now)
            flightAnim.preferHighRefreshRate()
            if #available(iOS 15.0, *), let r = maxRefreshRange() {
                flightAnim.preferredFrameRateRange = r   // pin the floor: hold the rate
            }
            host.layer.add(flightAnim, forKey: Self.flightKey)
        }
```

Apply the same shape to `:299` (which uses `beginTime: f.startTime`) and to `PhysicsScrollView.swift:167` (`traj.positionKeyframeAnimation(beginTime: now)`, key `Self.flightAnimationKey`, generation variable `generation`). Passing `true` here would newly disable implicit actions inside a flight install and is a behavior change — do not.

- [ ] **Step 6: Verify `CATransaction` is confined to one directory**

```bash
grep -rn CATransaction CoreListDemo/ | grep -v '^CoreListDemo/Transition/'
```

Expected: no output.

- [ ] **Step 7: Run the full suite**

```bash
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro K2' \
  -parallel-testing-enabled NO test 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **` with the same count as Task 1. This task changes no behavior; a single failure means a body was altered or a flight site wrongly disabled actions.

- [ ] **Step 8: Commit**

```bash
git add CoreListDemo/ListAnimationController.swift \
        CoreListDemo/CoreVirtualListView.swift \
        CoreListDemo/CoreAnimationCompiler.swift \
        CoreListDemo/InsetRectOverlayAnimator.swift \
        CoreListDemo/PhysicsScrollEngine.swift \
        CoreListDemo/PhysicsScrollView.swift
git commit -m "refactor(corelist): route every CATransaction through commit()

All 20 blocks now go through CoreListTransition.commit, so CATransaction
is named in exactly one directory. Settled writes become .immediate
setters; the blocks that mix property writes with subview surgery keep
the scope form.

The three deceleration-flight installs pass disablingImplicitActions:
false — they never disabled actions, and doing so now would be a
behavior change. Their generation-guarded completions are unchanged.

Behavior-preserving: the suite passes with the same count.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: Swap the descriptor type behind typealiases (no motion change)

> **AMENDED DURING EXECUTION — Task 3 is merged into Task 4.** The intent was to isolate the *type*
> change from the *curve* change, with a green suite as proof. That proof turned out to be
> unreachable: an exact shim is impossible because `Curve.custom` carries `Float` payloads, so
> `1/3`/`2/3` round to float32 and every sampled value drifts by up to 1.7e-8 in progress — including
> phase-0.5 samples (the "symmetry makes 0.5 exact" note holds for the ideal bézier, not the float32
> one). Executing Task 3 alone left **554 tests with 61 failures, every one a numeric-tolerance
> failure at the 8th significant digit** (`-40.00000134` vs `-40.0`), with no structural failures of
> any kind. Reaching green would have meant 61 tolerance edits that Task 4 immediately discards when
> it changes those same values.
>
> The equivalent proof lives in `CoreListTransitionCurveTests` instead, which quantifies the solver's
> agreement with the old formulas at ≤1.7e-8 and pins the bound at 1e-7. The uniform-failure
> measurement above is itself the evidence that the type swap changed nothing structural.
>
> Steps 1–4 below were executed as written; Step 5's green gate was not achievable and Step 6's
> commit was folded into Task 4's. Note the deviation disappears entirely in Task 4: `.easeInOut` and
> `.linear` are payload-free cases whose control points are `Double` literals, so
> `easeInOut.solve(at: 0.5) == 0.5` exactly (pinned at 1e-15 in Task 1).

The point of this task was to isolate the *type* change from the *curve* change. Every call site keeps compiling, and every existing test keeps its expected values.

**Files:**
- Modify: `CoreListDemo/ListAnimationModel.swift:31-101`
- Modify: `CoreListDemo/CoreAnimationCompiler.swift` (`track.curve` usage, if it type-checks differently)

**Interfaces:**
- Consumes: `CoreListTransition`, `CoreListTransition.Animation.Curve`, `Curve.solve(at:)`.
- Produces: `typealias ListAnimationSpec = CoreListTransition`, `typealias ListAnimationCurve = CoreListTransition.Animation.Curve`, `ListAnimationSpec.smoothstep(duration:)`, `ListAnimationSpec.easeOut(duration:)`, `ListAnimationCurve.smoothstep`, `ListAnimationCurve.easeOut`, and `ListAnimationTrack.curve: CoreListTransition.Animation.Curve`. All four shims are deleted in Task 4.

- [ ] **Step 1: Write the failing equivalence test**

Append to `CoreListDemoTests/CoreListTransitionCurveTests.swift`:

```swift
    // MARK: - Task 3 bridge (deleted with the shims in Task 4)

    func testShimCurvesAreTheExactOldFormulas() {
        for step in 0...100 {
            let x = CGFloat(step) / 100.0
            let smoothstep = x * x * (3 - 2 * x)
            let inverse = 1 - x
            let easeOut = 1 - inverse * inverse * inverse
            XCTAssertEqual(ListAnimationCurve.smoothstep.solve(at: x),
                           smoothstep >= 0.997 ? 1.0 : smoothstep, accuracy: 1e-12, "at \(x)")
            XCTAssertEqual(ListAnimationCurve.easeOut.solve(at: x),
                           easeOut >= 0.997 ? 1.0 : easeOut, accuracy: 1e-12, "at \(x)")
        }
    }

    func testShimSpecsCarryDurationAndCurve() {
        XCTAssertEqual(ListAnimationSpec.smoothstep(duration: 0.4).duration, 0.4, accuracy: 1e-12)
        XCTAssertEqual(ListAnimationSpec.smoothstep(duration: 0.4).curve, .smoothstep)
        XCTAssertEqual(ListAnimationSpec.easeOut(duration: 0.4).curve, .easeOut)
    }
```

- [ ] **Step 2: Run it to verify it fails**

```bash
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro K2' \
  -parallel-testing-enabled NO test \
  -only-testing:CoreListDemoTests/CoreListTransitionCurveTests
```

Expected: FAIL — `type 'ListAnimationCurve' has no member 'solve'` (the old enum has `value(at:)`, not `solve(at:)`).

- [ ] **Step 3: Replace the old types with typealiases plus shims**

In `ListAnimationModel.swift`, delete `public enum ListAnimationCurve` and `public struct ListAnimationSpec` entirely and put in their place:

```swift
/// Transitional aliases. The module's descriptor is `CoreListTransition`; these keep the ~214
/// existing call sites compiling while the type swap is verified in isolation. Task 4 deletes them
/// along with the two named curves.
typealias ListAnimationSpec = CoreListTransition
typealias ListAnimationCurve = CoreListTransition.Animation.Curve

extension CoreListTransition.Animation.Curve {
    /// `x²(3−2x)` — exactly the cubic bezier with control-x at 1/3 and 2/3 (which makes `x(t) = t`
    /// identically) and control-y at 0 and 1.
    static var smoothstep: CoreListTransition.Animation.Curve {
        .custom(1.0 / 3.0, 0.0, 2.0 / 3.0, 1.0)
    }

    /// `1−(1−x)³` — the same bezier with both control-y at 1.
    static var easeOut: CoreListTransition.Animation.Curve {
        .custom(1.0 / 3.0, 1.0, 2.0 / 3.0, 1.0)
    }
}

extension CoreListTransition {
    static func smoothstep(duration: TimeInterval) -> CoreListTransition {
        CoreListTransition(animation: .curve(duration: duration, curve: .smoothstep))
    }

    static func easeOut(duration: TimeInterval) -> CoreListTransition {
        CoreListTransition(animation: .curve(duration: duration, curve: .easeOut))
    }
}
```

- [ ] **Step 4: Retype the track and route its sampling through `solve`**

In `ListAnimationModel.swift`, `ListAnimationTrack.curve` is already declared `ListAnimationCurve`, which now resolves to the new enum, so only `value(at:)` changes:

```swift
    func value(at time: TimeInterval) -> CGFloat {
        guard duration > 0 else { return to }
        let x = min(max((time - startTime) / duration, 0), 1)
        let eased = curve.solve(at: CGFloat(x))
        return from + (to - from) * eased
    }
```

The default argument `curve: ListAnimationCurve = .smoothstep` on `ListAnimationTrack.init` keeps working through the shim.

`ListAnimationSpec`'s `Equatable` conformance is now `CoreListTransition`'s hand-written `==`; `ListAnimationTrack: Equatable` still synthesizes because `Curve` is `Equatable`.

- [ ] **Step 5: Run the full suite — with no expected *value* edits**

```bash
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro K2' \
  -parallel-testing-enabled NO test 2>&1 | tail -30
```

Expected: `** TEST SUCCEEDED **` at 552 tests. **Do not change any expected value in this task** — the twelve shape-dependent literals (`15.625`, `57.8125`, `0.15625`, `78.90625`) all stay as written, because the shim curves are the old formulas.

Two legitimate causes of failure, both requiring a *tolerance* edit rather than a value edit:

1. **`Float`-payload precision** (measured in Task 1, expected here). `Curve.custom` carries `Float` payloads — ComponentTransition's own case shape — so `1/3` and `2/3` round to float32 and `x(t)` drifts from `t` by up to 1.7e-8 in progress. On the `78.90625` assertions that is a 2.0e-7 discrepancy, which exceeds their `accuracy: 1e-9`. Fix by loosening those assertions to `accuracy: 1e-6`, with a comment naming the Float payload. The values themselves are unchanged, so the shape match is still what the test proves.
2. **The 0.997 clamp**, if a sample lands in a curve's final ~4% (`x ≥ 0.9597` for smoothstep). Keep the clamp and adjust that assertion to the clamped value, commenting the clamp.

Any *other* failure means the solver or the typealias is wrong — read it before editing.

- [ ] **Step 6: Commit**

```bash
git add CoreListDemo/ListAnimationModel.swift \
        CoreListDemoTests/CoreListTransitionCurveTests.swift
git commit -m "refactor(corelist): back ListAnimationSpec with CoreListTransition

ListAnimationSpec and ListAnimationCurve become typealiases onto the
vendored type, with .smoothstep and .easeOut kept as static factories
returning the exact cubic beziers they always were: control-x at 1/3 and
2/3 makes x(t) = t identically, so .custom(1/3, 0, 2/3, 1) IS x²(3−2x)
and .custom(1/3, 1, 2/3, 1) IS 1−(1−x)³.

Tracks now sample via Curve.solve. No call site and no expected value
changed, so a green suite is the proof that the vendored solver
reproduces the old curves bit-exactly. The shims die in the next commit.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: Collapse to one `transition:` parameter and adopt `.easeInOut`

The motion change lands here, isolated from the type change by Task 3.

**Files:**
- Modify: `CoreListDemo/ListAnimationModel.swift` (delete shims; delete duration-only overloads at `:190`, `:219`, `:262`, `:276`, `:304`, `:353`, `:368`, `:382`, `:560`)
- Modify: `CoreListDemo/ListAnimationController.swift` (`animation:` → `transition:`; delete `logicalDuration:` overloads at `:104`, `:190`, `:236`(ghost), and siblings)
- Modify: `CoreListDemo/CoreVirtualListView.swift` (delete the `animationDuration:` overload at `:481`; rename `animation:` → `transition:` at `:499`, `:2112`, `:2682`; the `let animationDuration = animation.duration` binding at `:500` becomes `let animationDuration = transition.duration`)
- Modify: `CoreListDemo/InsetRectOverlayAnimator.swift` (`animation:` → `transition:`)
- Modify: `CoreListDemo/ViewController.swift:544`
- Modify: every test file that names `animationDuration:`, `logicalDuration:`, `animation:`, `.smoothstep`, or `.easeOut`
- Modify: `CoreListDemoTests/ListAnimationModelTests.swift:14`, `:15`, `:129`, `:136`, `:138`, `:257`, `:305`, `:308`, `:468`
- Modify: `CoreListDemoTests/CoreVirtualListAnimationTests.swift:1171`, `:2562`, `:2601`
- Modify: `CoreListDemoTests/CoreListTransitionCurveTests.swift` (delete the two Task-3 shim tests)

**Interfaces:**
- Consumes: `CoreListTransition.easeInOut(duration:)`, `.immediate`, `Curve.linear`.
- Produces: `CoreVirtualListView.applyChanges(items:newSize:newInsets:scrollTo:anchorMode:transition:)` as the only mutation entry point; `ListAnimationModel.transition*(…, transition: CoreListTransition)` and `ListAnimationController.transition*(…, transition: CoreListTransition)` as the only overloads; `InsetRectOverlayAnimator.transition(view:to:transition:)`. `ListAnimationSpec`, `ListAnimationCurve`, `.smoothstep`, and `.easeOut` no longer exist.

- [ ] **Step 1: Delete the shims and the duration-only overloads**

Remove from `ListAnimationModel.swift` the four shim declarations added in Task 3 (both `typealias`es and both extensions). Then delete every duration-only overload in `ListAnimationModel.swift`, `ListAnimationController.swift`, and `CoreVirtualListView.swift` — each is a two-line forwarder onto its `animation:` sibling. Find them with:

```bash
grep -rn "duration: TimeInterval)\|logicalDuration: TimeInterval\|animationDuration: TimeInterval" CoreListDemo/
```

Rename the surviving parameter `animation:` to `transition:` and its type to `CoreListTransition` everywhere it appears in a declaration.

- [ ] **Step 2: Rewrite the call sites mechanically**

Roughly 214 sites, nearly all in tests. Order matters — do the duration-only forms first so the `animation:` rewrite does not double-apply:

```bash
# 1. duration-only call sites -> transition:
grep -rl "animationDuration:" CoreListDemo CoreListDemoTests | xargs sed -i '' \
  -E 's/animationDuration: ([^,)]+)/transition: .easeInOut(duration: \1)/g'
grep -rl "logicalDuration:" CoreListDemo CoreListDemoTests | xargs sed -i '' \
  -E 's/logicalDuration: ([^,)]+)/transition: .easeInOut(duration: \1)/g'

# 2. spec-carrying call sites -> transition:
grep -rl "animation: \." CoreListDemo CoreListDemoTests | xargs sed -i '' \
  's/animation: \./transition: ./g'

# 3. both named curves -> .easeInOut
grep -rl "smoothstep(duration:\|easeOut(duration:" CoreListDemo CoreListDemoTests | xargs sed -i '' \
  -E 's/\.(smoothstep|easeOut)\(duration:/.easeInOut(duration:/g'
```

Then fix by hand what `sed` cannot: the bare `duration:` argument label on the model's own overloads (e.g. `ListAnimationModelTests:100`, `:103`, `:112` call `transitionPosition(…, duration: 4)`), which becomes `transition: .easeInOut(duration: 4)`. The compiler enumerates every one; iterate until it builds.

`MixedPassScenario.swift:190` builds a spec in a branch and declares `let animation: ListAnimationSpec` — retype it to `let transition: CoreListTransition` and collapse both branches onto `.easeInOut(duration: duration)`, keeping the `positivePassSerial` parity logic but switching its two arms to `.easeInOut` and `.linear` so the scenario still exercises two curves.

Two test-support helpers — `VirtualListFixture.apply(_:duration:)` (`:70`) and `VirtualListDriver.apply(_:duration:)` (`:88`) — forward to `applyChanges`. **Keep their `duration:` label** and build the transition inside the body; they are harness sugar, not the module API this task collapses, and renaming them would churn dozens of unrelated call sites for no gain:

```swift
    func apply(_ items: [CoreListItem], duration: TimeInterval) {
        listView.applyChanges(items: items, transition: .easeInOut(duration: duration))
    }
```

(`run(duration:step:)` in the same files advances the synthetic clock and is unrelated — leave it alone.)

- [ ] **Step 3: Keep the curve-identity assertions meaningful**

Assertions of the form `XCTAssertEqual(track.curve, .easeOut)` exist to prove a pass's curve reached its track. With every production site on `.easeInOut`, they need a contrast curve. In each such test, change the *pass* that is being distinguished to `.linear` and assert `.linear`:

```swift
        fixture.listView.applyChanges(
            items: items,
            transition: CoreListTransition(animation: .curve(duration: 4, curve: .linear))
        )
        // …
        XCTAssertEqual(fixture.viewportTrack?.curve, .linear)
```

Find them with:

```bash
grep -rn "curve, \.\|\.curve, " CoreListDemoTests/
```

- [ ] **Step 4: Recompute the twelve shape-dependent literals**

Each is a sample at phase 0.25, where `easeInOut(0.25) = 0.12916193104731982` replaces `smoothstep(0.25) = 0.15625`:

| file:line | old | new |
|---|---|---|
| `CoreVirtualListAnimationTests:1171` | `0.15625` | `0.12916193104731982` |
| `CoreVirtualListAnimationTests:2562` | `0.15625` | `0.12916193104731982` |
| `CoreVirtualListAnimationTests:2601` | `78.90625` | `78.229048276182994` |
| `ListAnimationModelTests:14` | `15.625` | `12.916193104731983` |
| `ListAnimationModelTests:15` | `57.8125` | `25.0` (that track becomes the `.linear` contrast case) |
| `ListAnimationModelTests:129` | `78.90625` | `78.229048276182994` |
| `ListAnimationModelTests:136` | `78.90625` | `78.229048276182994` |
| `ListAnimationModelTests:138` | `78.90625` | `78.229048276182994` |
| `ListAnimationModelTests:257` | `78.90625` | `78.229048276182994` |
| `ListAnimationModelTests:305` | `78.90625` | `78.229048276182994` |
| `ListAnimationModelTests:308` | `78.90625` | `78.229048276182994` |
| `ListAnimationModelTests:468` | `78.90625` | `78.229048276182994` |

`ListAnimationModelTests:308` currently compares exactly, with no `accuracy:`. Add one — the new value is not a short decimal and exact equality on it is fragile:

```swift
        XCTAssertEqual(model.value(for: first.owner, property: .height, at: 1),
                       78.229048276182994, accuracy: 1e-9)
```

`ListAnimationModelTests:14`–`:15` is `testTrackUsesItsOwnCurve`, whose whole point is two different curves. Make the second track `.linear`:

```swift
    func testTrackUsesItsOwnCurve() {
        let eased = ListAnimationTrack(generation: 1, from: 0, to: 100,
                                       startTime: 0, duration: 4, curve: .easeInOut)
        let linear = ListAnimationTrack(generation: 2, from: 0, to: 100,
                                        startTime: 0, duration: 4, curve: .linear)

        XCTAssertEqual(eased.value(at: 1), 12.916193104731983, accuracy: 1e-9)
        XCTAssertEqual(linear.value(at: 1), 25.0, accuracy: 1e-9)
    }
```

Do **not** touch assertions sampling phase 0 or 0.5 — `ListAnimationModelTests:75`–`:77`, `:102`, `:105`. Both curves are symmetric about `(0.5, 0.5)` and `easeInOut(0.5) == 0.5` exactly, so those values are unchanged. If one of them fails, something else broke.

- [ ] **Step 5: Delete the Task-3 shim tests**

Remove `testShimCurvesAreTheExactOldFormulas` and `testShimSpecsCarryDurationAndCurve` from `CoreListTransitionCurveTests.swift` — they reference deleted symbols. Keep `testSmoothstepIsACustomBezierWithinFloatPayloadPrecision`, `testCubicEaseOutIsACustomBezierWithinFloatPayloadPrecision`, and `testCustomBezierFloatDeviationStaysBelowOnePartInTenMillion`, which assert on `.custom` directly and remain valid.

- [ ] **Step 6: Verify the old vocabulary is gone**

```bash
grep -rn "ListAnimationSpec\|ListAnimationCurve\|animationDuration:\|logicalDuration:\|smoothstep" \
  CoreListDemo/ CoreListDemoTests/ \
  | grep -v 'CoreListTransitionCurveTests.swift'
```

Expected: no output. The exclusion is deliberate: `testSmoothstepIsACustomBezierWithinFloatPayloadPrecision` keeps a local named `smoothstep` holding the old formula it asserts against, which is the point of that test.

- [ ] **Step 7: Run the full suite**

```bash
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro K2' \
  -parallel-testing-enabled NO test 2>&1 | tail -30
```

Expected: `** TEST SUCCEEDED **`, same count as Task 3 minus the two deleted shim tests.

- [ ] **Step 8: Commit**

```bash
git add CoreListDemo/ CoreListDemoTests/
git commit -m "refactor(corelist)!: one transition: parameter, .easeInOut everywhere

Deletes ListAnimationSpec, ListAnimationCurve, and the parallel
duration-only overload family: 146 animationDuration: and 68
logicalDuration: call sites collapse onto the single transition:
parameter, so applyChanges finally has the one entry point its docs
claim.

Adopts ComponentTransition's own vocabulary: smoothstep and cubic
easeOut both become .easeInOut. This is a real if small motion change —
the two curves differ from easeInOut by about 0.03 and 0.09 at their
widest. The tests keep .linear as the contrast curve their curve-identity
assertions need.

Twelve shape-dependent literals recomputed from the bezier solver.
Assertions at phase 0 and 0.5 are untouched: both curves are symmetric
about (0.5, 0.5) and easeInOut(0.5) is exactly 0.5.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: Pass the transition into items

**Files:**
- Modify: `CoreListDemo/CoreVirtualListView.swift:3-24` (both protocols), `:648-663` (reconcile), `:665-669` (dirty remeasure), `:1697`, `:1783`, `:1806` (window construction), `:1567-1578` (dirty flush)
- Modify: `CoreListDemo/DemoRow.swift:126`
- Modify: every test item view: `CoreListDemoTests/TestSupport/SampleItems.swift:17`, `:53`, `:93`, `:177`, `:255`; `CoreListDemoTests/TestSupport/MixedPassScenario.swift:21`; `CoreListDemoTests/CoreVirtualListAnimationTests.swift:520`; `CoreListDemoTests/MidFlightPassLurchTests.swift:64`; `CoreListDemoTests/SampleItemsTests.swift:25`
- Test: `CoreListDemoTests/TransitionPropagationTests.swift` (create)

**Interfaces:**
- Consumes: `CoreListTransition`, `.immediate`, and the setters.
- Produces: `CoreListItem.apply(to view: UIView & CoreListItemView, transition: CoreListTransition)` (no-op default retained); `CoreListItemView.update(width: CGFloat, transition: CoreListTransition) -> CGFloat`; private `CoreVirtualListView.reconciledIdentities: Set<AnyHashable>`.

- [ ] **Step 1: Write the failing propagation test**

Create `CoreListDemoTests/TransitionPropagationTests.swift`:

```swift
import XCTest
@testable import CoreListDemo

/// A row that records the transition of every `update`/`apply` call it receives, so the
/// propagation rule in the design's section 5 is directly observable.
private final class RecordingRowView: UIView, CoreListItemView {
    enum Call: Equatable {
        case update(isImmediate: Bool, duration: TimeInterval)
        case apply(isImmediate: Bool, duration: TimeInterval)
    }

    var calls: [Call] = []
    var height: CGFloat = 40
    var onContentDidChange: ((Bool) -> Void)?

    func update(width: CGFloat, transition: CoreListTransition) -> CGFloat {
        calls.append(.update(isImmediate: transition.isImmediate, duration: transition.duration))
        return height
    }

    func noteApply(_ transition: CoreListTransition) {
        calls.append(.apply(isImmediate: transition.isImmediate, duration: transition.duration))
    }
}

private final class RecordingRow: CoreListItem {
    let id: Int
    let version: Int
    private let sharedView: RecordingRowView

    init(id: Int, version: Int, sharedView: RecordingRowView) {
        self.id = id
        self.version = version
        self.sharedView = sharedView
    }

    var identity: AnyHashable { AnyHashable(id) }
    func view() -> UIView & CoreListItemView { sharedView }

    func isEqual(to other: CoreListItem) -> Bool {
        guard let other = other as? RecordingRow else { return false }
        return other.id == id && other.version == version
    }

    func apply(to view: UIView & CoreListItemView, transition: CoreListTransition) {
        (view as? RecordingRowView)?.noteApply(transition)
    }
}

final class TransitionPropagationTests: XCTestCase {
    /// `VirtualListFixture` takes its items at init and builds a window immediately, so every test
    /// clears the recorded calls after construction. The fixture pins `durationFactor: { 1 }` and
    /// `emitsCA: false`, so recorded durations are the logical ones.
    private func makeFixture(_ view: RecordingRowView)
        -> (VirtualListFixture, RecordingRowView) {
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800),
                                         items: [RecordingRow(id: 1, version: 0, sharedView: view)])
        view.calls.removeAll()
        return (fixture, view)
    }

    private func updates(_ view: RecordingRowView) -> [(isImmediate: Bool, duration: TimeInterval)] {
        view.calls.compactMap { call in
            if case let .update(isImmediate, duration) = call {
                return (isImmediate: isImmediate, duration: duration)
            }
            return nil
        }
    }

    private func sawApply(_ view: RecordingRowView) -> Bool {
        view.calls.contains { if case .apply = $0 { return true } else { return false } }
    }

    func testFreshViewMeasuresImmediately() {
        let view = RecordingRowView()
        let fixture = VirtualListFixture(viewport: CGSize(width: 390, height: 800), items: [])
        view.calls.removeAll()

        fixture.listView.applyChanges(items: [RecordingRow(id: 1, version: 0, sharedView: view)],
                                      transition: .easeInOut(duration: 0.5))

        let measured = updates(view)
        XCTAssertFalse(measured.isEmpty, "the fresh row must be measured")
        XCTAssertTrue(measured.allSatisfy(\.isImmediate),
                      "a newly created view has nothing to animate from")
        XCTAssertFalse(sawApply(view), "apply is only for reused survivors")
    }

    func testReconciledSurvivorReceivesThePassTransition() {
        let (fixture, view) = makeFixture(RecordingRowView())

        fixture.listView.applyChanges(items: [RecordingRow(id: 1, version: 1, sharedView: view)],
                                      transition: .easeInOut(duration: 0.5))

        XCTAssertEqual(view.calls.first, .apply(isImmediate: false, duration: 0.5))
        let measured = updates(view)
        XCTAssertFalse(measured.isEmpty, "the reconciled row must be remeasured")
        XCTAssertTrue(measured.allSatisfy { !$0.isImmediate && abs($0.duration - 0.5) < 1e-9 },
                      "a reconciled survivor measures with the pass transition")
    }

    func testUnchangedSurvivorMeasuresImmediately() {
        let (fixture, view) = makeFixture(RecordingRowView())

        // Same identity AND same version: isEqual is true, so no reconcile.
        fixture.listView.applyChanges(items: [RecordingRow(id: 1, version: 0, sharedView: view),
                                              RecordingRow(id: 2, version: 0,
                                                           sharedView: RecordingRowView())],
                                      transition: .easeInOut(duration: 0.5))

        XCTAssertFalse(sawApply(view))
        XCTAssertTrue(updates(view).allSatisfy(\.isImmediate),
                      "an unchanged survivor's content did not change; only its geometry, "
                      + "which ListAnimationModel owns")
    }

    func testDirtyFlushUsesTheFlushTransition() {
        let (fixture, view) = makeFixture(RecordingRowView())

        view.height = 90
        view.onContentDidChange?(true)
        fixture.flushScheduler()

        let expected = fixture.listView.defaultDirtyDuration
        XCTAssertTrue(updates(view).contains { !$0.isImmediate && abs($0.duration - expected) < 1e-9 },
                      "an animated self-update must measure with the flush transition")
    }

    func testDirtyFlushWithoutAnimationMeasuresImmediately() {
        let (fixture, view) = makeFixture(RecordingRowView())

        view.height = 90
        view.onContentDidChange?(false)
        fixture.flushScheduler()

        XCTAssertTrue(updates(view).allSatisfy(\.isImmediate))
    }
}
```

`RecordingRow` returns the same `sharedView` from `view()` every time, which is what lets a test observe one view across passes. `testUnchangedSurvivorMeasuresImmediately` adds a second row so the pass has a real structural change to animate — otherwise `applyChanges` could short-circuit before measuring anything.

- [ ] **Step 2: Run it to verify it fails**

```bash
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro K2' \
  -parallel-testing-enabled NO test \
  -only-testing:CoreListDemoTests/TransitionPropagationTests
```

Expected: compile failure — `RecordingRowView` does not satisfy `CoreListItemView` (its `update` has an extra parameter).

- [ ] **Step 3: Change both protocols**

In `CoreVirtualListView.swift`:

```swift
public protocol CoreListItemView: AnyObject {
    /// Lays the row out at `width` and returns its measured height.
    ///
    /// `transition` describes the enclosing pass, and is non-immediate ONLY when this row's content
    /// changed in that pass (a reconciled survivor, or an animated self-update flush). A fresh view,
    /// a row loaded by scrolling, an unchanged survivor, and an off-screen remeasure all receive
    /// `.immediate`: there is nothing to animate from, or the change is purely outer geometry, which
    /// `ListAnimationModel` owns. The returned height must be the settled height either way.
    ///
    /// This may be called twice in one pass (dirty remeasure, then window construction). The
    /// transition's setters early-out on an equal target, so the second call is a no-op.
    func update(width: CGFloat, transition: CoreListTransition) -> CGFloat
    var onContentDidChange: ((_ animated: Bool) -> Void)? { get set }
}

public protocol CoreListItem: AnyObject {
    var identity: AnyHashable { get }
    func view() -> UIView & CoreListItemView
    func isEqual(to other: CoreListItem) -> Bool
    /// Reconfigures a reused survivor's content. `transition` is the enclosing pass's transition;
    /// a view that animates its own internals should use it (or hold it for its next layout).
    func apply(to view: UIView & CoreListItemView, transition: CoreListTransition)
}

public extension CoreListItem {
    func apply(to view: UIView & CoreListItemView, transition: CoreListTransition) {}
}
```

- [ ] **Step 4: Thread the transition through the pass**

Add the per-pass set beside the existing `dirtyIndices` storage in `CoreVirtualListView`:

```swift
    /// Identities whose content was reconciled in the pass currently being applied. Window
    /// construction measures exactly these with the pass transition; everything else measures
    /// `.immediate`. Cleared at the end of each pass.
    private var reconciledIdentities: Set<AnyHashable> = []
```

In the reconcile block (`:648-663`), record each reconciled identity and forward the transition:

```swift
        reconciledIdentities.removeAll()
        if hasItems {
            func reconcileContent(newIndex: Int, oldIndex: Int) {
                guard oldItems.indices.contains(oldIndex),
                      effectiveItems.indices.contains(newIndex),
                      !oldItems[oldIndex].isEqual(to: effectiveItems[newIndex]),
                      let view = oldRenderedState[oldItems[oldIndex].identity]?.view
                else { return }
                effectiveItems[newIndex].apply(to: view, transition: transition)
                reconciledIdentities.insert(effectiveItems[newIndex].identity)
            }
            for (newIndex, oldIndex) in survivorMapNewToOld {
                reconcileContent(newIndex: newIndex, oldIndex: oldIndex)
            }
            for (newIndex, oldIndex) in moveReuseNewToOld {
                reconcileContent(newIndex: newIndex, oldIndex: oldIndex)
            }
        }
```

The dirty rows are content-changed too, so fold them into the same set right where `consumedDirty` is remeasured (`:665-669`):

```swift
        for index in consumedDirty {
            if let item = oldWindow.items.first(where: { $0.index == index }) {
                if _items.indices.contains(index) {
                    reconciledIdentities.insert(_items[index].identity)
                }
                _ = item.view.update(width: contentWidth, transition: transition)
            }
        }
```

Add a private helper and use it at the three window-construction measure sites (`:1697`, `:1783`, `:1806`):

```swift
    private func measureTransition(forItemAt index: Int,
                                   passTransition: CoreListTransition) -> CoreListTransition {
        guard _items.indices.contains(index),
              reconciledIdentities.contains(_items[index].identity)
        else { return .immediate }
        return passTransition
    }
```

`seedWindow`, `prependItem`, and `appendItem` need the pass transition to consult it, so add a `passTransition: CoreListTransition` parameter to each (threading it from `buildWindow`'s caller) and change each measure to:

```swift
        let height = view.update(width: width,
                                 transition: measureTransition(forItemAt: index,
                                                               passTransition: passTransition))
```

Clear the set in `applyChanges`'s existing `defer` block (`:513-517`):

```swift
        defer {
            isApplyingChanges = false
            reconciledIdentities.removeAll()
            refreshReachedLoadedEdges()
            assertOverlayInvariants()
        }
```

Finally, the dirty flush (`:1577-1578`) must build a real transition instead of a duration:

```swift
        let animated = dirtyAnimated
        applyChanges(transition: animated ? .easeInOut(duration: defaultDirtyDuration) : .immediate)
```

- [ ] **Step 5: Update every conformance**

Each of the nine test item views and `DemoRow` gains the parameter. For the test views the body is unchanged — only the signature:

```swift
    nonisolated func update(width: CGFloat, transition: CoreListTransition) -> CGFloat {
```

`SampleItemsTests:25` calls `update` directly: `view.update(width: 100, transition: .immediate)`.

`DemoRow` is the demo's proof that the executor works end-to-end, so route its three subview frames through the transition. Full replacement for `DemoRow.swift:126-143`:

```swift
    func update(width: CGFloat, transition: CoreListTransition) -> CGFloat {
        let contentInsets = UIEdgeInsets(top: 16, left: 18, bottom: 16, right: 18)
        let pillSize = CGSize(width: 12, height: 12)
        let labelWidth = max(0, width - contentInsets.left - contentInsets.right)
        let titleHeight = titleLabel.sizeThatFits(CGSize(width: labelWidth, height: .greatestFiniteMagnitude)).height

        transition.setFrame(view: pillView, frame: CGRect(x: contentInsets.left, y: contentInsets.top + 2, width: pillSize.width, height: pillSize.height))
        transition.setFrame(view: titleLabel, frame: CGRect(x: contentInsets.left, y: contentInsets.top + pillSize.height + 10, width: labelWidth, height: titleHeight))

        var totalHeight = contentInsets.top + pillSize.height + 10 + titleHeight + contentInsets.bottom
        if isExpanded {
            let detailHeight = detailLabel.sizeThatFits(CGSize(width: labelWidth, height: .greatestFiniteMagnitude)).height
            transition.setFrame(view: detailLabel, frame: CGRect(x: contentInsets.left, y: titleLabel.frame.maxY + 8, width: labelWidth, height: detailHeight))
            totalHeight += 8 + detailHeight
        }

        return max(ceil(totalHeight + extraHeight), minHeight)
    }
```

Note `titleLabel.frame.maxY` on the `detailLabel` line reads the frame *after* `setFrame` wrote it — `setFrame` writes the settled value synchronously before animating, so this still reads the new layout, exactly as the old direct assignment did.

- [ ] **Step 6: Run the propagation tests, then the full suite**

```bash
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro K2' \
  -parallel-testing-enabled NO test \
  -only-testing:CoreListDemoTests/TransitionPropagationTests

xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro K2' \
  -parallel-testing-enabled NO test 2>&1 | tail -30
```

Expected: both PASS. A `DemoInteractionTests` failure most likely means `DemoRow` now animates a frame a test reads synchronously — in that case assert against the settled frame, not the presentation.

- [ ] **Step 7: Commit**

```bash
git add CoreListDemo/CoreVirtualListView.swift CoreListDemo/DemoRow.swift \
        CoreListDemoTests/
git commit -m "feat(corelist)!: pass the pass transition into items

apply(to:transition:) and update(width:transition:) now carry the
enclosing pass's transition, so a row can animate its own internals on
the same curve and duration as its outer geometry.

A row receives a non-immediate transition only when its content actually
changed in that pass: a reconciled survivor or an animated self-update
flush. Fresh views, scroll-in loads, unchanged survivors, and off-screen
remeasures get .immediate — there is nothing to animate from, or the
change is purely outer geometry, which ListAnimationModel owns. A
per-pass reconciledIdentities set is what window construction consults.

DemoRow lays its subviews out through the transition, exercising the
executor end-to-end in the demo.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: App side — the bridge and the chat backend

**Files:**
- Create: `submodules/TelegramUI/Sources/CoreListTransitionBridge.swift`
- Modify: `submodules/TelegramUI/Sources/CoreListChatHistoryBackend.swift:286-294` (`animation:` → `transition:`), `:540-543` (`apply`), `:570` (`update`)
- Modify: `submodules/TelegramUI/BUILD` only if the new file needs a `deps` entry (it should not — `ComponentFlow` and `CoreList` are already deps of the `TelegramUI` target; verify with `grep -n 'ComponentFlow\|CoreList' submodules/TelegramUI/BUILD`)

**Interfaces:**
- Consumes: `CoreListTransition` from Task 1, `ComponentTransition` from ComponentFlow.
- Produces: `ComponentTransition.init(_ transition: CoreListTransition)` and `CoreListTransition.init(_ transition: ComponentTransition)`.

- [ ] **Step 1: Write the bridge**

Create `submodules/TelegramUI/Sources/CoreListTransitionBridge.swift`:

```swift
import Foundation
import UIKit
import ComponentFlow
import CoreList

// CoreList cannot depend on ComponentFlow (no Bazel deps; the demo builds standalone), so it carries
// its own case-for-case copy of the transition value model. This file — which sees both modules — is
// the only place the two meet.
//
// The one asymmetry is interpretation, not data: CoreList treats a zero duration as immediate, while
// ComponentFlow animates it. Round-tripping preserves the payload exactly; each side keeps its own
// reading of `duration: 0`.

extension ComponentTransition.Animation.Curve {
    init(_ curve: CoreListTransition.Animation.Curve) {
        switch curve {
        case .easeInOut: self = .easeInOut
        case .easeIn: self = .easeIn
        case .spring: self = .spring
        case .linear: self = .linear
        case let .custom(a, b, c, d): self = .custom(a, b, c, d)
        case let .bounce(stiffness, damping): self = .bounce(stiffness: stiffness, damping: damping)
        }
    }
}

extension CoreListTransition.Animation.Curve {
    init(_ curve: ComponentTransition.Animation.Curve) {
        switch curve {
        case .easeInOut: self = .easeInOut
        case .easeIn: self = .easeIn
        case .spring: self = .spring
        case .linear: self = .linear
        case let .custom(a, b, c, d): self = .custom(a, b, c, d)
        case let .bounce(stiffness, damping): self = .bounce(stiffness: stiffness, damping: damping)
        }
    }
}

public extension ComponentTransition {
    init(_ transition: CoreListTransition) {
        switch transition.animation {
        case .none:
            self = ComponentTransition(animation: .none)
        case let .curve(duration, curve):
            self = ComponentTransition(animation: .curve(duration: duration,
                                                         curve: Animation.Curve(curve)))
        }
    }
}

public extension CoreListTransition {
    init(_ transition: ComponentTransition) {
        switch transition.animation {
        case .none:
            self = CoreListTransition(animation: .none)
        case let .curve(duration, curve):
            self = CoreListTransition(animation: .curve(duration: duration,
                                                        curve: Animation.Curve(curve)))
        }
    }
}
```

- [ ] **Step 2: Update the chat backend**

At `CoreListChatHistoryBackend.swift:286-294`:

```swift
            self.coreList.applyChanges(
                items: structurallyChanged ? self.entries : nil,
                newSize: self.currentSize == .zero ? nil : self.currentSize,
                newInsets: self.currentInsets,
                scrollTo: scrollTo,
                anchorMode: stationaryItemRange == nil ? .automatic : .preserveVisibleContent,
                transition: animated ? .easeInOut(duration: 0.3) : .immediate
            )
```

Note `.immediate` replaces `.easeOut(duration: 0.0)` — same meaning, and `isImmediate` now covers both.

At `:540`, `CoreListEntryItem.apply` gains the parameter and forwards it:

```swift
    func apply(to view: UIView & CoreListItemView, transition: CoreListTransition) {
        (view as? CoreListNodeHostView)?.setListItem(self.listItem,
                                                     neighbors: self.neighbors,
                                                     transition: transition)
    }
```

At `:564`, `setListItem` stores it for the next layout, since `rebuild` is where the node is laid out:

```swift
    func setListItem(_ item: ListViewItem,
                     neighbors: ListViewItemNeighbors,
                     transition: CoreListTransition) {
        self.listItem = item
        self.neighbors = neighbors
        self.pendingTransition = transition
        self.contentDirty = true
    }
```

with `private var pendingTransition: CoreListTransition = .immediate` alongside the other stored properties.

At `:570`, `update` takes the parameter. The item node's own frame write stays immediate for now — `ListViewItemNode` animation is driven by `ListViewItemUpdateAnimation`, and wiring that to the transition is a separate change beyond this plan's scope. Keep the deferred item explicit:

```swift
    func update(width: CGFloat, transition: CoreListTransition) -> CGFloat {
        // Deferred: map `transition` onto ListViewItemUpdateAnimation so a reconciled chat row
        // animates its internal layout. Today the node relayouts with .None and the row's outer
        // geometry animates via ListAnimationModel, which is the pre-existing behavior.
        _ = transition
        if self.itemNode == nil || self.contentDirty || abs(width - self.lastWidth) > 0.5 {
            self.rebuild(width: width)
        }
        if let itemNode = self.itemNode {
            itemNode.frame = CGRect(x: 0.0, y: 0.0, width: width, height: self.lastHeight)
        }
        return self.lastHeight
    }
```

- [ ] **Step 3: Build the app**

```bash
cd /Users/isaac/build/telegram/telegram-ios
source ~/.zshrc 2>/dev/null; python3 build-system/Make/Make.py --overrideXcodeVersion \
 --cacheDir ~/telegram-bazel-cache \
 build \
 --configurationPath build-system/appstore-configuration.json \
 --gitCodesigningRepository git@gitlab.com:peter-iakovlev/fastlanematch.git \
 --gitCodesigningType development --gitCodesigningUseCurrent --buildNumber=1 \
 --configuration=debug_sim_arm64 --continueOnError
```

Expected: build succeeds. `--continueOnError` surfaces every signature mismatch in one pass rather than stopping at the first.

- [ ] **Step 4: Re-run the demo suite**

The CoreList sources are shared between the Bazel library and the demo project, so confirm the demo still passes after any fix the app build forced:

```bash
cd submodules/TelegramUI/Components/CoreList
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro K2' \
  -parallel-testing-enabled NO test 2>&1 | tail -20
```

- [ ] **Step 5: Commit**

```bash
cd /Users/isaac/build/telegram/telegram-ios
git add submodules/TelegramUI/Sources/CoreListTransitionBridge.swift \
        submodules/TelegramUI/Sources/CoreListChatHistoryBackend.swift
git commit -m "feat(telegramui): bridge ComponentTransition and CoreListTransition

CoreList carries its own case-for-case copy of the transition value
model because it cannot depend on ComponentFlow. This file, which sees
both modules, is the only place they meet; the mapping is total in both
directions.

The chat backend passes .immediate for a non-animated pass (was
.easeOut(duration: 0.0), which means the same thing now that isImmediate
covers a zero duration) and .easeInOut(duration: 0.3) otherwise.

Mapping the transition onto ListViewItemUpdateAnimation so a reconciled
chat row animates its internal layout is left deferred and commented at
the call site.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 7: Documentation and final verification

**Files:**
- Modify: `CLAUDE.md` (item protocol block, curve names in "Granular animation contract", two new gotchas)
- Modify: `docs/plans/CHANGELOG.md`

**Interfaces:**
- Consumes: everything above.
- Produces: no code.

- [ ] **Step 1: Update the item protocol block in `CLAUDE.md`**

Replace the `protocol CoreListItem` / `CoreListItemView` code block in the "Item protocol" section with the Task 5 signatures, and add after the existing prose:

```markdown
`apply(to:transition:)` and `update(width:transition:)` receive the enclosing pass's
`CoreListTransition`. It is non-immediate ONLY when that row's content changed in the pass (a
reconciled survivor, or an animated self-update flush); fresh views, scroll-in loads, unchanged
survivors, and off-screen remeasures receive `.immediate`. `update` must return the settled height
regardless, and may be called twice in one pass — the transition's setters early-out on an equal
target, so the second call is a no-op.
```

- [ ] **Step 2: Update the animation contract's curve vocabulary**

In the "Granular animation contract" section, replace `a track-owned curve (`smoothstep` or `easeOut`)` with:

```markdown
a track-owned `CoreListTransition.Animation.Curve`
```

and add a paragraph after that list:

```markdown
`CoreListTransition` (`CoreListDemo/Transition/`) is a self-contained copy of ComponentFlow's
`ComponentTransition` value model — CoreList has no Bazel `deps` and the demo builds standalone, so
it cannot import it. The case shape is identical, and
`TelegramUI/Sources/CoreListTransitionBridge.swift` maps between the two. Production uses
`.easeInOut` throughout; the tests keep `.linear` as the contrast curve their curve-identity
assertions need. `.spring` and `.bounce` are documented approximations (ComponentFlow resolves both
through private `UIKitRuntimeUtils` API) and are supported on input only. `CoreListTransition` is
also the module's only `CATransaction` scope, via `commit(disablingImplicitActions:completion:_:)`.
See `docs/superpowers/specs/2026-07-27-corelist-transition-design.md`.
```

- [ ] **Step 3: Add the two gotchas**

Append to "Non-obvious gotchas":

```markdown
- **A zero duration is immediate, which is the opposite of ComponentFlow.** `ComponentTransition`
  treats only `.none` as immediate and animates `.curve(duration: 0, …)`. CoreList settles a
  zero-duration property immediately, and roughly half the test suite says "no animation" as
  `duration: 0`. Every branch must therefore test `CoreListTransition.isImmediate`; `if case .none`
  silently animates a pass that must not.
- **Duration scaling happens once per path, and the paths must not meet.** The model path scales in
  `ListAnimationController` and `CoreAnimationCompiler` must not scale again; the executor path
  scales inside `CALayer.animate` (as Display's does). Consequently the transition handed to items is
  always the LOGICAL, unscaled one — handing them a pre-scaled transition double-scales under Slow
  Animations.
```

- [ ] **Step 4: Add a CHANGELOG entry**

Append to `docs/plans/CHANGELOG.md`, matching the file's existing entry format:

```markdown
- **2026-07-27 — CoreListTransition.** `ListAnimationSpec`/`ListAnimationCurve` replaced by a
  vendored, ComponentTransition-shaped `CoreListTransition`; 146 `animationDuration:` + 68
  `logicalDuration:` call sites collapsed onto one `transition:` parameter; `.smoothstep`/`.easeOut`
  replaced by `.easeInOut` (a real if small motion change); `apply(to:transition:)` and
  `update(width:transition:)` now carry the pass transition; all 20 `CATransaction` blocks routed
  through `CoreListTransition.commit`. Bridged to ComponentFlow in
  `TelegramUI/Sources/CoreListTransitionBridge.swift`.
```

- [ ] **Step 5: Final verification sweep**

```bash
cd submodules/TelegramUI/Components/CoreList

# 1. CATransaction confined to one directory
grep -rn CATransaction CoreListDemo/ | grep -v '^CoreListDemo/Transition/'

# 2. old vocabulary fully gone (the curve test legitimately names the old formula)
grep -rn "ListAnimationSpec\|ListAnimationCurve\|animationDuration:\|logicalDuration:\|smoothstep" \
  CoreListDemo/ CoreListDemoTests/ | grep -v 'CoreListTransitionCurveTests.swift'

# 3. no branch tests .none instead of isImmediate
grep -rn "case .none" CoreListDemo/ | grep -v '^CoreListDemo/Transition/CoreListTransition.swift'

# 4. full suite
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro K2' \
  -parallel-testing-enabled NO test 2>&1 | tail -20
```

Expected: greps 1, 2, and 3 produce no output; the suite reports `** TEST SUCCEEDED **`. Grep 3 may legitimately match unrelated optional/enum handling — inspect each hit rather than assuming it is a transition branch.

- [ ] **Step 6: Manual check on the simulator**

Build and run the demo on K2, then exercise the Virtual List tab's insert, delete, replacement, reorder, size, mixed-chaos, and the 300pt top-inset toggle. The motion should read as before but with a slightly different easing; nothing should snap, lurch, or leave a stale row.

Then, in the app, enable the `coreListChatBackend` experimental flag, open a chat, and scroll and send a message. Use the `mcp__XcodeBuildMCP__*` tools to drive the simulator — not `cliclick`/`osascript`. If those tools are absent from the session, say so and hand this step to the user rather than attempting the privilege-blocked fallbacks.

- [ ] **Step 7: Commit**

```bash
git add CLAUDE.md docs/plans/CHANGELOG.md
git commit -m "docs(corelist): record the transition refactor

Item-protocol signatures, the curve vocabulary, and two gotchas that are
invisible in the types: a zero duration is immediate (the opposite of
ComponentFlow), and the model and executor paths each scale duration
once, which is why items receive the logical transition.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Deferred (explicitly not in this plan)

- **Mapping `CoreListTransition` onto `ListViewItemUpdateAnimation`** so a reconciled chat row animates its internal layout. Commented at `CoreListNodeHostView.update`. Needs its own design: `ListViewItemUpdateAnimation` carries a `ListViewItemSpringAnimation`, not a curve.
- **Faithful `.spring`/`.bounce`.** Would need `springAnimationValueAt` and `CALayerSpringParametersOverride`, i.e. a `UIKitRuntimeUtils` dependency CoreList deliberately does not have.
- **Vendoring the shape-layer/gradient/blur/mesh/parabolic helpers.** No consumer.
