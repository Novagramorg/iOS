# Presented Geometry For Hosts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** EXECUTED 2026-07-26. All three tasks landed; suite 517/0, whole-app Bazel build green. Task 3's
manual in-app A/B was run by the user (it needs XcodeBuildMCP, unavailable to the executing session): the
stutter is gone. One deviation, recorded below: Task 2's mid-flight test failed by 32pt on first run and the
plan's predicted cause ("the sign is inverted") was wrong — the test asked for the *instantaneous* position
while the accessor is built on the per-frame-stable `engine.offset`. The accessor was right; the semantic needed
stating, and a test now pins that `presentedFrame` is stable off-tick.

**Goal:** Stop `CoreListChatHistoryBackend` from reporting chat geometry measured in a keyframe flight's *destination* viewport. Give `CoreVirtualListView` a presented-space frame accessor and route the backend through it.

**Architecture:** `UIView.convert` composes ancestor **model** `bounds.origin`, and the host's model `bounds.origin.y` is the additive base of whatever animates the viewport — a `.keyframe` deceleration parks it at the flight's destination, and a programmatic `scrollTo` leaves the settled endpoint there while an additive `viewportOffset` track carries the motion. So a host that converts through `contentHost` reads destination-space geometry for the whole animation. Only `CoreVirtualListView` knows both the model base and the physics position, so it owns the correction: a new `presentedFrame(of:)` does the convert and applies it. The deterministic harness cannot currently express this defect at all, so Task 1 closes that gap first.

**Tech Stack:** Swift 5, UIKit, XCTest, Bazel (the backend is app-side and has no test target).

## Global Constraints

- Work on `main` directly. No worktrees, no feature branches.
- Every test command MUST include `-destination 'platform=iOS Simulator,name=iPhone 17 Pro K2'` and `-parallel-testing-enabled NO`.
- Stage only task-named files with explicit paths. Never `git add .` / `git add -A`. Never amend or push.
- Baseline: **506 tests, 0 failures** (or 512 if `2026-07-26-pass-entry-viewport-currency.md` landed first — the two plans are independent and can be executed in either order).
- `CoreListChatHistoryBackend` is debug-flag-gated (production default is `ListViewImpl`), so this is a correctness fix for the PoC path, not a shipping-path regression risk.
- Read first: `docs/chat/corelist-chat-history-backend.md` (repo root `docs/`), `docs/superpowers/specs/2026-07-26-clock-free-mutation-pass-design.md`, and the `ScrollEngine.offset` gotcha in this module's `CLAUDE.md`.

## The correction, derived

With `container` a child of `contentHost` and `contentHost.frame.origin.y == 0`:

```
convert(view.bounds, from: view).minY = view.frame.minY + containerOriginY − D      // D = contentHost.bounds.origin.y (MODEL)
presented screen y                    = view.frame.minY + containerOriginY − (engine.offset + viewportCorrection)
⇒ presented = convert − [ (engine.offset − D) + viewportCorrection ]
```

Cross-checks: with nothing animating, `writeOffset` keeps `D == engine.offset` and `viewportCorrection == 0`, so the correction is 0 and `presentedFrame == convert`. Mid-flight `engine.offset < D` for a downward fling, so the correction is negative and rows are reported *lower* on screen — correct, the content has not travelled as far as the model claims. The second form matches `CoreVirtualListView.swift:531`'s own `renderedOldViewport = oldSettledOffset + currentViewportCorrection`.

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `CoreListDemoTests/TestSupport/TestScrollEngine.swift` | deterministic mirror of the physics engine | park/bump the host layer exactly as production does |
| `CoreListDemo/CoreVirtualListView.swift` | the list; sole owner of the model↔presented relationship | add `presentedFrame(of:)` |
| `CoreListDemoTests/PresentedGeometryTests.swift` | new | pin the accessor against a flight and a programmatic scroll |
| `submodules/TelegramUI/Sources/CoreListChatHistoryBackend.swift` | chat host | route both `convert` sites through the accessor |

---

### Task 1: Make the harness model the parked host layer

**Files:**
- Modify: `CoreListDemoTests/TestSupport/TestScrollEngine.swift` — `applyShift`, `endDrag`, `tick`
- Test: `CoreListDemoTests/TestSupport/TestScrollEngine.swift` is test support; its fidelity is pinned by the new test in Task 2. This task's own check is the existing suite staying green.

**Why:** `PhysicsScrollEngine` parks the host layer at the trajectory's `finalOffset` on launch (`:240`) and on re-emit (`:284`), bumps it on a mid-flight shift (`:106`), and restores it on catch (`:313`) and finalize (via `core.setOffset` → `writeOffset`). `TestScrollEngine` does none of the parking, so in the harness `contentHost.bounds.origin.y` never diverges from the physics offset and the destination-space defect is invisible. No existing test reads the host's `bounds.origin.y` (verified by grep), so adding the parking is safe.

- [ ] **Step 1: Park the host on flight launch**

In `endDrag()`, replace the flight construction:

```swift
    @discardableResult func endDrag() -> Bool {
        let decelerate = core.endDrag()
        if decelerate && decelerationMode == .keyframe {
            let f = KeyframeFlight(core: core, startTime: clock.now)
            flight = f
            // Mirror PhysicsScrollEngine.launchFlight (:240): the layer model is parked at the trajectory's
            // settled endpoint because the emitted keyframe animation is ADDITIVE around it. The harness
            // emits no CA, but it must reproduce the model value or a host reading geometry through
            // `UIView.convert` cannot be tested against it.
            host.bounds.origin.y = f.trajectory.finalOffset
        }
        return decelerate
    }
```

- [ ] **Step 2: Bump the host on a mid-flight shift**

In `applyShift(_:)`, inside the `flight != nil` branch, add the host write as the first statement (mirroring `PhysicsScrollEngine.swift:106`, where it precedes `applyShiftPhysicsOnly`):

```swift
    func applyShift(_ dy: CGFloat) {
        if flight != nil {
            let changesShape = core.hasFiniteEdge
            host.bounds.origin.y += dy          // mirror PhysicsScrollEngine:106 — the model rides the re-base
            core.applyShiftPhysicsOnly(dy)
            flight?.noteShift(dy)
            if changesShape {
                flight?.noteEdgesChanged()
            }
        } else {
            core.applyShift(dy)
        }
    }
```

- [ ] **Step 3: Re-park after a rebake**

In `tick(dt:)`, inside the `if f.rebakeIfNeeded(now: clock.now)` branch, before the `isComplete` check:

```swift
            if f.rebakeIfNeeded(now: clock.now) {
                keyframeRebakeCount += 1
                host.bounds.origin.y = f.trajectory.finalOffset   // mirror reemitFlightAnimation (:284)
                if f.isComplete(now: clock.now) {
```

- [ ] **Step 4: Run the full suite**

```sh
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro K2' \
  -parallel-testing-enabled NO test
```

Expected: unchanged totals, 0 failures. A failure here means some test *was* depending on the harness's host layer holding the physics offset — read it before touching anything, because that dependency is itself the bug this plan is about.

- [ ] **Step 5: Commit**

```sh
git add submodules/TelegramUI/Components/CoreList/CoreListDemoTests/TestSupport/TestScrollEngine.swift
git commit -m "test(corelist): mirror the parked host layer in TestScrollEngine"
```

---

### Task 2: `CoreVirtualListView.presentedFrame(of:)`

**Files:**
- Modify: `CoreListDemo/CoreVirtualListView.swift` — add next to `currentScrollOffset` (`:372`)
- Create: `CoreListDemoTests/PresentedGeometryTests.swift`

**Interfaces:**
- Produces: `public func presentedFrame(of view: UIView) -> CGRect` — a loaded row's rect in the list's coordinate space as presented. Consumed by Task 3.

- [ ] **Step 1: Write the failing test**

Create `CoreListDemoTests/PresentedGeometryTests.swift`:

```swift
import XCTest
import UIKit
@testable import CoreListDemo

/// `presentedFrame(of:)` — the accessor a host must use instead of `UIView.convert`.
///
/// `convert` composes ancestor MODEL `bounds.origin`, and `contentHost`'s model origin is the additive base
/// of whatever animates the viewport: a `.keyframe` flight parks it at the flight's DESTINATION, and a
/// programmatic `scrollTo` leaves the settled endpoint there while the additive `viewportOffset` track
/// carries the motion. A host converting through `contentHost` therefore reads destination-space geometry
/// for the whole animation. See docs/superpowers/plans/2026-07-26-presented-geometry-for-hosts.md.
final class PresentedGeometryTests: XCTestCase {

    private func fixture(rows: Int = 200, mode: TestScrollEngine.DecelerationMode = .keyframe)
        -> (PhysicsListFixture, SyntheticClock) {
        let clock = SyntheticClock()
        let items: [CoreListItem] = (0..<rows).map { _ in IdentifiableFixedHeightItem(id: UUID(), height: 50) }
        return (PhysicsListFixture(items: items, decelerationMode: mode, clock: clock), clock)
    }

    /// The screen y the presented geometry must agree with, computed the way the lurch tests do it.
    private func expectedScreenY(_ f: PhysicsListFixture, _ item: CoreVirtualListView.Window.Item) -> CGFloat {
        f.containerOriginY + item.view.frame.minY - (f.engine.liveViewportOffset + f.viewportCorrection)
    }

    func test_atRest_presentedFrameEqualsConvert() {
        let (f, _) = fixture()
        f.listView.applyChanges(scrollTo: (index: 60, pointOffset: 0), animationDuration: 0)
        let item = f.activeWindow.items[3]
        let converted = f.listView.convert(item.view.bounds, from: item.view)
        XCTAssertEqual(f.listView.presentedFrame(of: item.view).minY, converted.minY, accuracy: 0.001,
                       "with nothing animating the model IS the presented value")
    }

    func test_duringAFlight_convertReportsTheDestination_presentedFrameReportsTheScreen() {
        let (f, clock) = fixture()
        f.listView.applyChanges(scrollTo: (index: 60, pointOffset: 0), animationDuration: 0)
        f.simulateFlick(offsetVelocity: 9000)
        for _ in 0..<6 { f.tick(dt: 1.0 / 120) }
        clock.advance(by: 0.004)

        let item = f.activeWindow.items[3]
        let converted = f.listView.convert(item.view.bounds, from: item.view)
        let presented = f.listView.presentedFrame(of: item.view)

        XCTAssertGreaterThan(abs(converted.minY - presented.minY), 100,
                             "mid-flight the model is the destination, hundreds of points from the screen")
        XCTAssertEqual(presented.minY, expectedScreenY(f, item), accuracy: 0.5,
                       "presentedFrame must equal where the row actually is")
        XCTAssertEqual(presented.height, item.view.frame.height, accuracy: 0.001,
                       "only the origin is corrected")
    }

    func test_duringAProgrammaticScroll_presentedFrameFollowsTheViewportTrack() {
        let (f, _) = fixture()
        f.listView.applyChanges(scrollTo: (index: 60, pointOffset: 0), animationDuration: 0)
        f.listView.applyChanges(scrollTo: (index: 66, pointOffset: 0), animationDuration: 0.3)
        XCTAssertGreaterThan(abs(f.viewportCorrection), 1, "precondition: a viewport track must be live")

        let item = f.activeWindow.items[3]
        XCTAssertEqual(f.listView.presentedFrame(of: item.view).minY, expectedScreenY(f, item), accuracy: 0.5)
    }

    func test_afterTheFlightSettles_presentedFrameEqualsConvertAgain() {
        let (f, _) = fixture()
        f.listView.applyChanges(scrollTo: (index: 60, pointOffset: 0), animationDuration: 0)
        f.simulateFlick(offsetVelocity: 3000)
        var ticks = 0
        while f.engine.isDecelerating && ticks < 900 {
            f.tick(dt: 1.0 / 120)
            ticks += 1
        }
        XCTAssertFalse(f.engine.isDecelerating)

        let item = f.activeWindow.items[3]
        let converted = f.listView.convert(item.view.bounds, from: item.view)
        XCTAssertEqual(f.listView.presentedFrame(of: item.view).minY, converted.minY, accuracy: 0.001)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

```sh
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro K2' \
  -parallel-testing-enabled NO test -only-testing:CoreListDemoTests/PresentedGeometryTests
```

Expected: **compile failure** — `value of type 'CoreVirtualListView' has no member 'presentedFrame'`.

If `IdentifiableFixedHeightItem`'s initialiser does not accept `(id: Int, height:)`, open `CoreListDemoTests/TestSupport/SampleItems.swift` and use whatever identity type it takes — the item type is irrelevant to these assertions, only that heights are uniform.

- [ ] **Step 3: Implement the accessor**

In `CoreVirtualListView.swift`, immediately after `currentScrollOffset` (`:372`):

```swift
    /// A view's rect in this list's coordinate space, as PRESENTED — where it is on screen right now, not
    /// where its settled model geometry says it will end up.
    ///
    /// Hosts MUST use this instead of `convert(_:from:)`. `UIView.convert` composes ancestor MODEL
    /// `bounds.origin`, and `contentHost`'s model origin is the additive base of whatever animates the
    /// viewport: a `.keyframe` deceleration parks it at the flight's destination for the flight's whole
    /// duration, and a programmatic `scrollTo` leaves the settled endpoint there while the additive
    /// `viewportOffset` track carries the motion. Converting through `contentHost` therefore yields
    /// destination-space geometry — which silently made a host's visible-range, content-offset and
    /// read-tracking reporting describe the end of a fling rather than the middle of it.
    ///
    /// Only this view can apply the correction, because only it holds both the model base and the engine's
    /// scroll position. Ancestor-path-agnostic like `convert` itself: a row carried by `crossingOverlay`
    /// during a structural transition converts correctly too.
    public func presentedFrame(of view: UIView) -> CGRect {
        convert(view.bounds, from: view)
            .offsetBy(dx: 0, dy: -modelToPresentedViewportDelta)
    }

    /// How far the model viewport leads the presented one: `(engine.offset − contentHost model origin)` plus
    /// the additive viewport correction. Zero whenever nothing is animating the viewport.
    private var modelToPresentedViewportDelta: CGFloat {
        (engine.offset - engine.contentHost.bounds.origin.y)
            + animationController.viewportOffset(at: animationController.now())
    }
```

- [ ] **Step 4: Run to verify it passes**

Same command as Step 2. Expected: 4 tests pass.

If `test_duringAFlight_…` fails on the `expectedScreenY` comparison, the sign is inverted: check it against `CoreVirtualListView.swift:531` (`renderedOldViewport = oldSettledOffset + currentViewportCorrection`) rather than flipping it by trial.

- [ ] **Step 5: Run the full suite**

```sh
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro K2' \
  -parallel-testing-enabled NO test
```

Expected: baseline + 4, 0 failures.

- [ ] **Step 6: Commit**

```sh
git add submodules/TelegramUI/Components/CoreList/CoreListDemo/CoreVirtualListView.swift \
        submodules/TelegramUI/Components/CoreList/CoreListDemoTests/PresentedGeometryTests.swift
git commit -m "feat(corelist): presentedFrame(of:) for hosts reading row geometry"
```

---

### Task 3: Route the chat backend through it

**Files:**
- Modify: `submodules/TelegramUI/Sources/CoreListChatHistoryBackend.swift` — `:116-132` (`listFrame(of:)` and its doc comment), `:405-419` (`forEachVisibleItemNode`)

**Interfaces:**
- Consumes: `CoreVirtualListView.presentedFrame(of:)` from Task 2.

There are exactly two conversion sites (verified by grep for `.convert(`): `listFrame(of:)` at `:130-132`, which funnels `loadedFrame(of:)`, `loadedFrame(atIndex:)` and `immediateDisplayedItemRange`; and a second, duplicated `convert` inside `forEachVisibleItemNode` at `:419`. Downstream consumers needing no edit: `visibleContentOffset()` `:364-372`, `visibleBottomContentOffset()` `:376-385`, `itemNodeRelativeOffset` `:469-475`, `itemNodeVisibleInsideInsets` `:477-484`.

- [ ] **Step 1: Reroute the funnel**

Replace `listFrame(of:)` (`:130-132`) and the trailing paragraph of the comment above `loadedFrame(of:)` (`:116-119`, the one beginning "Frames come from UIKit `convert`"):

```swift
    // Frames come from `presentedFrame(of:)` rather than `convert`: it walks whatever ancestor path the row
    // currently has (`container` normally, `crossingOverlay` while a structural transition carries it), so it
    // cannot drift from what is rendered, AND it corrects for the additive viewport animations. A bare
    // `convert` composes ancestor MODEL bounds, and CoreList's host layer is parked at a keyframe flight's
    // DESTINATION for the whole fling — so it would report every row hundreds of points from where the user
    // sees it, for the entire momentum phase.
    private func loadedFrame(of node: ListViewItemNode) -> CGRect? {
        for hostView in self.itemNodeHostViews {
            if hostView.itemNode === node {
                return self.listFrame(of: hostView)
            }
        }
        return nil
    }

    // A loaded row's rect in the hosted CoreVirtualListView's coordinate space, as presented.
    private func listFrame(of view: UIView) -> CGRect {
        return self.coreList.presentedFrame(of: view)
    }
```

- [ ] **Step 2: Reroute `forEachVisibleItemNode`**

At `:419`, replace the duplicated conversion so this path shares the funnel:

```swift
            let frame = self.listFrame(of: hostView)
```

and in the comment above it (`:405-410`), replace the paragraph beginning "Geometry comes from UIKit rather than a CoreList accessor" with:

```swift
    // Geometry comes from `listFrame(of:)`, i.e. CoreList's `presentedFrame(of:)`: the frames must be where
    // the rows ARE, not their settled endpoints. Reporting settled geometry mid-fling would fire read
    // tracking and unseen-reaction animations for whatever is visible at the flight's destination.
```

- [ ] **Step 3: Build the app**

```sh
source ~/.zshrc 2>/dev/null; python3 build-system/Make/Make.py --overrideXcodeVersion \
 --cacheDir ~/telegram-bazel-cache build \
 --configurationPath build-system/appstore-configuration.json \
 --gitCodesigningRepository git@gitlab.com:peter-iakovlev/fastlanematch.git \
 --gitCodesigningType development --gitCodesigningUseCurrent --buildNumber=1 \
 --configuration=debug_sim_arm64
```

Expected: build succeeds.

- [ ] **Step 4: Verify in the running app**

Install per this repo's CLAUDE.md whole-`.app` copy procedure onto the K1 simulator, enable the CoreList chat-history backend in Debug Settings, open a long chat, and flick hard through unloaded history. Drive it with the `mcp__XcodeBuildMCP__*` tools; if they are absent from the session, say so and hand this step to the user rather than reaching for `cliclick`/`osascript`.

What should change: read-state and pagination should track the rows the user actually passes rather than arriving in a burst when the fling settles. Compare against the same flick with the flag off (`ListViewImpl`) — behavior should now match it.

- [ ] **Step 5: Commit**

```sh
git add submodules/TelegramUI/Sources/CoreListChatHistoryBackend.swift
git commit -m "fix(corelist-chat): report presented row geometry, not the flight's destination"
```

- [ ] **Step 6: Update the docs**

In `docs/chat/corelist-chat-history-backend.md` (repo root), note that all row geometry goes through `presentedFrame(of:)` and why a bare `convert` is wrong. In `docs/superpowers/specs/2026-07-26-clock-free-mutation-pass-design.md`, remove the chat-backend entry from `## Ranked: What This Fix Does NOT Address` and from the deferred list in `## Landed`, citing this commit.

```sh
git add docs/chat/corelist-chat-history-backend.md \
        submodules/TelegramUI/Components/CoreList/docs/superpowers/specs/2026-07-26-clock-free-mutation-pass-design.md
git commit -m "docs(corelist-chat): presented-geometry contract for hosts"
```
