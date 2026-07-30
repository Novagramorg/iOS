# Pass-Entry Viewport Currency Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** EXECUTED 2026-07-26. All four tasks landed; suite 512/0 at the end of Task 3, whole-app Bazel build
green (818 actions). The reported in-app stutter is gone. Two deviations from the plan as written, both recorded
in the amended text below: a fourth `ScrollEngine` conformer (`ClampingScrollEngine`) was found in
pre-execution review and added to Task 1; and in Task 3 the two continuity tests passed *before* the change
(continuity was already bought by the clock-free-offset fix — the off-tick defect was currency), so only the
currency test was a red→green.

**Goal:** Make a `CoreVirtualListView` mutation pass exactly continuous in two cases the clock-free-offset fix left open: a pass that halts a live keyframe flight, and a pass that runs between sampling ticks.

**Architecture:** Two additions to the `ScrollEngine` seam. `haltMotionInPlace()` stops momentum without round-tripping through a caller-side read of `offset` (today's `engine.setOffset(engine.offset)` reads a per-frame-stable value, then `catchFlight` internally snaps to the true instant, and the stale argument overwrites it). `syncToPresentedPosition()` re-anchors the engine's reported position on what the render server is presenting, called once at pass entry so every downstream decision — anchor witness, load band, overscroll gate, coordinate re-base — resolves against the current viewport rather than the last tick's. The `scrollTo` halt also moves to pass entry, ahead of the first `engine.offset` read.

**Tech Stack:** Swift 5, UIKit, XCTest. The `CoreListDemo.xcodeproj` suite is the only verification surface (these files are excluded from the app's Bazel build only for the demo entry points; `PhysicsScrollEngine`/`CoreVirtualListView` do compile into `//submodules/TelegramUI/Components/CoreList`, so a full app build is a useful final check but not a test surface).

## Global Constraints

- Work on `main` directly. No worktrees, no feature branches (this module's CLAUDE.md).
- Every test command MUST include `-destination 'platform=iOS Simulator,name=iPhone 17 Pro K2'` and `-parallel-testing-enabled NO`. If K2 is unavailable, stop and ask.
- Stage only task-named files with explicit paths. Never `git add .` / `git add -A` — the tree carries unrelated WIP.
- Never amend or push.
- Baseline before starting: **506 tests, 0 failures**.
- Read first: `docs/superpowers/specs/2026-07-26-clock-free-mutation-pass-design.md` (the fix this extends), and the `ScrollEngine.offset` gotcha in this module's `CLAUDE.md`.
- Test command shape used throughout (run from `submodules/TelegramUI/Components/CoreList`):

```sh
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro K2' \
  -parallel-testing-enabled NO test -only-testing:CoreListDemoTests/<Class>/<method>
```

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `CoreListDemo/ScrollEngine.swift` | the seam contract | add `haltMotionInPlace()`, `syncToPresentedPosition()` |
| `CoreListDemo/PhysicsScrollEngine.swift` | physics backend | implement both; `catchFlight` stays the only instantaneous sampler |
| `CoreListDemo/UIKitScrollEngine.swift` | UIScrollView backend | implement both (halt = today's idiom; sync = no-op) |
| `CoreListDemoTests/TestSupport/TestScrollEngine.swift` | deterministic mirror | implement both, mirroring `PhysicsScrollEngine` |
| `CoreListDemoTests/CoreVirtualListAnimationTests.swift:654` | `ClampingScrollEngine`, a test-local conformer modelling a UIScrollView-style clamp | implement both |
| `CoreListDemo/CoreVirtualListView.swift` | the list | hoist the `scrollTo` halt to pass entry; call the sync at pass entry; replace 4 halt idioms |
| `CoreListDemoTests/TestScrollEngineTests.swift` | seam behavior | halt/sync unit tests |
| `CoreListDemoTests/MidFlightPassLurchTests.swift` | pass continuity | off-tick and scrollTo continuity tests |

---

### Task 1: `haltMotionInPlace()` on the seam

**Files:**
- Modify: `CoreListDemo/ScrollEngine.swift`
- Modify: `CoreListDemo/PhysicsScrollEngine.swift:78-91` (`setOffset`), add the new method next to it
- Modify: `CoreListDemo/UIKitScrollEngine.swift`
- Modify: `CoreListDemoTests/TestSupport/TestScrollEngine.swift:50-62` (`setOffset`), add the new method next to it
- Modify: `CoreListDemoTests/CoreVirtualListAnimationTests.swift:654-676` (`ClampingScrollEngine`)
- Test: `CoreListDemoTests/TestScrollEngineTests.swift`

**Interfaces:**
- Produces: `ScrollEngine.haltMotionInPlace()` — stops any deceleration/flight and leaves the content exactly where it is presented. Idempotent. Never fires `onScroll`. Used by Tasks 2 and 3.

- [ ] **Step 1: Write the failing test**

Append to `CoreListDemoTests/TestScrollEngineTests.swift` (inside the existing class, which already has the `makeEngine()` helper):

```swift
    func test_haltMotionInPlace_stopsAtThePresentedPosition_notTheLastTick() {
        let (engine, clock) = makeEngine()
        engine.decelerationMode = .keyframe
        engine.setEdges(min: nil, max: nil)
        engine.setOffset(0)
        engine.simulateFlick(offsetVelocity: 9_000)
        clock.advance(by: 1.0 / 120)
        engine.tick(dt: 1.0 / 120)

        // Main-thread work since the last sampling tick: `offset` holds still (per-frame stable) while
        // the render server keeps playing the flight.
        clock.advance(by: 0.008)
        let presented = engine.liveViewportOffset
        let lastTick = engine.offset
        XCTAssertGreaterThan(presented - lastTick, 10,
                             "precondition: the presented position must have moved past the last tick's")

        engine.haltMotionInPlace()

        XCTAssertFalse(engine.isDecelerating, "the halt idles the physics")
        XCTAssertEqual(engine.offset, presented, accuracy: 0.001,
                       "the halt stops the content where it IS, not where the last tick left it")
        XCTAssertEqual(engine.liveViewportOffset, presented, accuracy: 0.001,
                       "and nothing moves on screen")
    }

    func test_haltMotionInPlace_isIdempotentAndSafeWithNoMotion() {
        let (engine, _) = makeEngine()
        engine.setEdges(min: nil, max: nil)
        engine.setOffset(140)
        var fired: [CGFloat] = []
        engine.onScroll = { fired.append($0) }

        engine.haltMotionInPlace()
        engine.haltMotionInPlace()

        XCTAssertEqual(engine.offset, 140, accuracy: 0.001)
        XCTAssertFalse(engine.isDecelerating)
        XCTAssertTrue(fired.isEmpty, "a programmatic halt must not fire onScroll")
    }
```

- [ ] **Step 2: Run to verify it fails**

```sh
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro K2' \
  -parallel-testing-enabled NO test -only-testing:CoreListDemoTests/TestScrollEngineTests
```

Expected: **compile failure** — `value of type 'TestScrollEngine' has no member 'haltMotionInPlace'`. A Swift compile error is the red state for a new API; do not proceed until you see it.

- [ ] **Step 3: Add it to the protocol**

In `CoreListDemo/ScrollEngine.swift`, after `func setOffset(_ y: CGFloat)`:

```swift
    /// Stop any deceleration/momentum, leaving the content exactly where it is PRESENTED. Idempotent, and
    /// never fires `onScroll`.
    ///
    /// This exists so a caller never has to write `setOffset(offset)` to halt. Under a `.keyframe` flight
    /// that idiom is a trap: `offset` is per-frame stable, the call internally catches the flight at its
    /// true instantaneous position, and then the stale argument overwrites it — so the halt lands on the
    /// last sampling tick's position instead of the current one. See
    /// docs/superpowers/specs/2026-07-26-clock-free-mutation-pass-design.md.
    func haltMotionInPlace()
```

- [ ] **Step 4: Implement it in the physics engine**

In `CoreListDemo/PhysicsScrollEngine.swift`, immediately after `setOffset(_:)`:

```swift
    func haltMotionInPlace() {
        // Same teardown as `setOffset` minus the offset write: `catchFlight` already snaps the physics and
        // the layer model to the live position and removes the animation, so the content does not move.
        if flight != nil { catchFlight() }
        stopDisplayLink()
        core.cancelDeceleration()
    }
```

- [ ] **Step 5: Implement it in the UIKit engine**

In `CoreListDemo/UIKitScrollEngine.swift`, next to `setOffset(_:)`:

```swift
    func haltMotionInPlace() {
        // A `UIScrollView`'s `bounds.origin` IS its presented position, so writing it back is already an
        // exact halt-in-place here — this is the historical idiom, now stated once instead of at four
        // call sites.
        setOffset(offset)
    }
```

- [ ] **Step 6: Implement it in the test engine**

In `CoreListDemoTests/TestSupport/TestScrollEngine.swift`, immediately after `setOffset(_:)`:

```swift
    func haltMotionInPlace() {
        // Mirrors PhysicsScrollEngine.haltMotionInPlace: catch the flight at its live position (production
        // additionally removes the CA animation), then idle the core.
        if let f = flight {
            core.setOffset(f.liveOffset(now: clock.now))
            flight = nil
        }
        core.cancelDeceleration()
    }
```

- [ ] **Step 7: Implement it in the test-local clamping engine**

`ClampingScrollEngine` (`CoreListDemoTests/CoreVirtualListAnimationTests.swift:654`) is a fourth conformer —
a deliberate UIScrollView-style clamp used to test the list against an engine that refuses part of a write.
Add next to its `setOffset`:

```swift
        func haltMotionInPlace() {
            // Nothing to halt: this engine has no momentum. `setOffset` re-clamps, which is the correct
            // no-motion behaviour and mirrors UIKitScrollEngine.
            setOffset(offset)
        }
```

- [ ] **Step 8: Run to verify it passes**

Same command as Step 2. Expected: all `TestScrollEngineTests` pass.

- [ ] **Step 9: Run the full suite**

```sh
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro K2' \
  -parallel-testing-enabled NO test
```

Expected: `Executed 508 tests, with 0 failures` (506 baseline + 2 new).

- [ ] **Step 10: Commit**

```sh
git add submodules/TelegramUI/Components/CoreList/CoreListDemo/ScrollEngine.swift \
        submodules/TelegramUI/Components/CoreList/CoreListDemo/PhysicsScrollEngine.swift \
        submodules/TelegramUI/Components/CoreList/CoreListDemo/UIKitScrollEngine.swift \
        submodules/TelegramUI/Components/CoreList/CoreListDemoTests/TestSupport/TestScrollEngine.swift \
        submodules/TelegramUI/Components/CoreList/CoreListDemoTests/TestScrollEngineTests.swift \
        submodules/TelegramUI/Components/CoreList/CoreListDemoTests/CoreVirtualListAnimationTests.swift
git commit -m "feat(corelist): ScrollEngine.haltMotionInPlace for argument-free momentum halt"
```

---

### Task 2: Route the four halt sites through it, and hoist the `scrollTo` halt

**Files:**
- Modify: `CoreListDemo/CoreVirtualListView.swift` — `:581`, `:1353`, `:1401`, `:1417`, plus a new call at `:512`
- Test: `CoreListDemoTests/MidFlightPassLurchTests.swift`

**Interfaces:**
- Consumes: `ScrollEngine.haltMotionInPlace()` from Task 1.

**Why the hoist is exact:** `resolveAnchor`'s first branch is `if let scrollTo { … }`, so `hasScrollTo` (computed at `:483`, before any offset read) implies that branch is always the one taken. The other three sites are NOT hoisted: `:1417`'s `isNoOverlapSwap` halt fires only when the earlier `.preserveVisibleContent` branch did not resolve, and replicating that precedence at the top of the pass would be fragile. They do not need hoisting — a no-overlap swap shares no rows and an emptied list discards all of them, so there is no visible content to be continuous with; `rebuildFromScratch` re-places everything absolutely.

- [ ] **Step 1: Write the failing test**

Append to `CoreListDemoTests/MidFlightPassLurchTests.swift` (it already has `SlowRow`, `screenY`, `flying`):

```swift
    /// A `scrollTo` arriving mid-momentum (jump-to-bottom during a fling) halts the flight. Its viewport
    /// animation must START from where the content actually is. The halt used to run inside `resolveAnchor`,
    /// i.e. AFTER the pass had already read `engine.offset` at :539 and built its geometry from it — so the
    /// animation's `from` was computed against a position the content had already left.
    func test_scrollToDuringMomentum_startsItsAnimationFromThePresentedPosition() {
        let (f, clock) = flying(cost: 0.0001, velocity: 9000)
        // Loaded window is ~[60…88] after the setup scrollTo(60) + flick, so a 10-row jump keeps the probe
        // in both the old and the new window (no carousel, no removal).
        let probeIndex = 72
        XCTAssertNotNil(f.activeWindow.items.first(where: { $0.index == probeIndex }),
                        "probe must be loaded before the pass")
        let probe = (f.listView.items[probeIndex] as! SlowRow).identity

        clock.advance(by: 0.008)          // the pass arrives between sampling ticks
        let before = screenY(f, identity: probe)!

        f.listView.applyChanges(scrollTo: (index: 70, pointOffset: 0), animationDuration: 0.3)

        let after = screenY(f, identity: probe)!
        XCTAssertEqual(after, before, accuracy: 0.5, """
            the scroll animation started \(after - before)pt away from where the content was — \
            the halt must happen before the pass reads engine.offset
            """)
    }
```

- [ ] **Step 2: Run to verify it fails**

```sh
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro K2' \
  -parallel-testing-enabled NO test \
  -only-testing:CoreListDemoTests/MidFlightPassLurchTests/test_scrollToDuringMomentum_startsItsAnimationFromThePresentedPosition
```

Expected: FAIL, `XCTAssertEqual failed` with a discrepancy of roughly 60-80pt (8ms of staleness plus the pass's own work at ~8pt/ms).

- [ ] **Step 3: Hoist the `scrollTo` halt to pass entry**

In `CoreVirtualListView.swift`, immediately before `let oldItems = _items` (currently `:513`):

```swift
        // A `scrollTo` pass halts any live momentum (the §4(b) halt idiom). Do it HERE, before the first
        // `engine.offset` read below: the halt catches a keyframe flight at its true instantaneous
        // position, so halting mid-pass would leave every geometry decision — and the viewport
        // animation's `from` — anchored on a position the content has already left. `resolveAnchor`'s
        // `scrollTo` branch is its first branch, so this fires for exactly the passes that used to halt
        // there. See docs/superpowers/specs/2026-07-26-clock-free-mutation-pass-design.md.
        if hasScrollTo { engine.haltMotionInPlace() }
```

- [ ] **Step 4: Remove the now-duplicate halt from `resolveAnchor`**

In `resolveAnchor`, the `scrollTo` branch (currently `:1400-1405`) becomes:

```swift
        if let scrollTo {
            // Momentum was already halted at pass entry (see applyChanges) — deliberately, so this pass's
            // geometry is built against the caught position rather than a stale sample.
            return ResolvedAnchor(index: scrollTo.index,
                                  pointOffset: scrollTo.pointOffset,
                                  preservesVisibleContent: false)
        }
```

- [ ] **Step 5: Replace the remaining three idioms**

`:581` (items emptied):

```swift
        if !oldItems.isEmpty, effectiveItems.isEmpty {
            engine.haltMotionInPlace()
        }
```

`:1353` (in `rebuildFromScratch`):

```swift
        engine.haltMotionInPlace()
```

`:1417` (the `isNoOverlapSwap` branch in `resolveAnchor`):

```swift
        if isNoOverlapSwap {
            engine.haltMotionInPlace()
            return ResolvedAnchor(index: 0,
                                  pointOffset: 0,
                                  preservesVisibleContent: false)
        }
```

- [ ] **Step 6: Run to verify it passes**

Same command as Step 2. Expected: PASS.

- [ ] **Step 7: Run the full suite**

```sh
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro K2' \
  -parallel-testing-enabled NO test
```

Expected: `Executed 509 tests, with 0 failures`.

`ApplyChangesDuringFlightMutationTests.testScrollToAndNoOverlapReplacementIntentionallyHaltMotion` is the test most likely to react — it asserts these passes DO halt, which they still do. If it fails, read it before changing anything: a behavior difference there means the hoist changed *which* passes halt, which it must not.

- [ ] **Step 8: Commit**

```sh
git add submodules/TelegramUI/Components/CoreList/CoreListDemo/CoreVirtualListView.swift \
        submodules/TelegramUI/Components/CoreList/CoreListDemoTests/MidFlightPassLurchTests.swift
git commit -m "fix(corelist): halt momentum before a pass reads the scroll offset"
```

---

### Task 3: `syncToPresentedPosition()` at pass entry

**Files:**
- Modify: `CoreListDemo/ScrollEngine.swift`
- Modify: `CoreListDemo/PhysicsScrollEngine.swift`
- Modify: `CoreListDemo/UIKitScrollEngine.swift`
- Modify: `CoreListDemoTests/TestSupport/TestScrollEngine.swift`
- Modify: `CoreListDemo/CoreVirtualListView.swift:512` (next to Task 2's halt)
- Test: `CoreListDemoTests/MidFlightPassLurchTests.swift`

**Interfaces:**
- Produces: `ScrollEngine.syncToPresentedPosition()` — re-anchors the engine's reported `offset` on the presented position. No-op when nothing is animating.

**Why this is safe:** it is the operation `KeyframeFlight.beginTick` already performs on every sampling tick — reseed the physics at the flight's live sample. It does not touch the CA animation, so the flight keeps playing; it only makes the value the list reads current. It also updates `lastTickTime`, which makes the unreachable-edge filter's remaining-path test *more* precise, never less.

- [ ] **Step 1: Write the failing tests**

Append to `CoreListDemoTests/MidFlightPassLurchTests.swift`:

```swift
    /// A pass triggered between sampling ticks (a network batch, a scheduler flush) must resolve its
    /// geometry against the CURRENT viewport, not the last tick's. Continuity held either way — that is the
    /// cancellation algebra — but membership, the anchor witness and the overscroll gate were all decided
    /// against a stale position.
    func test_passRunBetweenTicks_resolvesAgainstThePresentedViewport() {
        let (f, clock) = flying(cost: 0, velocity: 9000)
        clock.advance(by: 0.008)
        XCTAssertGreaterThan(f.engine.liveViewportOffset - f.engine.offset, 10,
                             "precondition: engine.offset is deliberately stale between ticks")

        let changed: [CoreListItem] = (0..<200).map {
            SlowRow(id: $0, revision: 1, clock: clock, cost: 0)
        }
        f.listView.applyChanges(items: changed, animationDuration: 0)

        XCTAssertEqual(f.engine.offset, f.engine.liveViewportOffset, accuracy: 1e-6,
                       "the pass must have re-anchored the engine on the presented position")
    }

    /// The same pass must still be continuous — the sync must not become a second, inconsistent read.
    func test_passRunBetweenTicks_doesNotMoveTheContent() {
        let (b, clockB) = flying(cost: 0.0001, velocity: 9000)
        let probe = (b.listView.items[b.activeWindow.items[3].index] as! SlowRow).identity
        clockB.advance(by: 0.008)
        let t0 = clockB.now
        let changed: [CoreListItem] = (0..<200).map {
            SlowRow(id: $0, revision: 1, clock: clockB, cost: 0.0001)
        }
        b.listView.applyChanges(items: changed, animationDuration: 0)
        let withPass = screenY(b, identity: probe)!

        let (a, clockA) = flying(cost: 0.0001, velocity: 9000)
        clockA.advance(by: 0.008 + (clockB.now - t0))
        let withoutPass = screenY(a, identity: probe)!

        XCTAssertEqual(withPass, withoutPass, accuracy: 0.5,
                       "an off-tick pass moved the content by \(withPass - withoutPass)pt")
    }

    /// The overscroll gate (`wasOverscrolledPrePass`, CoreVirtualListView.swift:588) is a 0.5pt threshold on
    /// `engine.offset − clamp(engine.offset, loadedEdges)`. Off-tick during a bounce that threshold was
    /// resolved against a stale sample, so it could take the wrong branch at :819-828 and clamp the settled
    /// offset to a loaded edge the content is not actually at. Pin the user-visible property: continuity.
    func test_offTickPassDuringABounce_doesNotMoveTheContent() {
        func bouncing(cost: TimeInterval) -> (PhysicsListFixture, SyntheticClock) {
            let clock = SyntheticClock()
            // 30 rows x 50pt = 1500pt of content in an 800pt viewport: the bottom edge is loaded, so
            // loadedEdgeRange reports a finite maximum and a hard flick overshoots into the bounce.
            let items: [CoreListItem] = (0..<30).map { SlowRow(id: $0, clock: clock, cost: cost) }
            let f = PhysicsListFixture(items: items, decelerationMode: .keyframe, clock: clock)
            f.simulateFlick(offsetVelocity: 6000)
            for _ in 0..<40 { f.tick(dt: 1.0 / 120) }   // reach the edge and enter the bounce
            return (f, clock)
        }

        let (b, clockB) = bouncing(cost: 0.0001)
        guard let probeItem = b.activeWindow.items.first else { return XCTFail("no loaded rows") }
        let probe = (b.listView.items[probeItem.index] as! SlowRow).identity
        clockB.advance(by: 0.004)
        let t0 = clockB.now
        let changed: [CoreListItem] = (0..<30).map {
            SlowRow(id: $0, revision: 1, clock: clockB, cost: 0.0001)
        }
        b.listView.applyChanges(items: changed, animationDuration: 0)
        let withPass = screenY(b, identity: probe)!

        let (a, clockA) = bouncing(cost: 0.0001)
        clockA.advance(by: 0.004 + (clockB.now - t0))
        let withoutPass = screenY(a, identity: probe)!

        XCTAssertEqual(withPass, withoutPass, accuracy: 0.5,
                       "an off-tick pass during a bounce moved the content by \(withPass - withoutPass)pt")
    }
```

- [ ] **Step 2: Run to verify they fail**

```sh
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro K2' \
  -parallel-testing-enabled NO test -only-testing:CoreListDemoTests/MidFlightPassLurchTests
```

Expected: `test_passRunBetweenTicks_resolvesAgainstThePresentedViewport` FAILS (the offset stays ~75pt behind the presented position). The other two may already pass — continuity is what the clock-free-offset fix bought; they are here to prove the sync does not break it. Record which ones fail before implementing.

- [ ] **Step 3: Add it to the protocol**

In `CoreListDemo/ScrollEngine.swift`, after `haltMotionInPlace()`:

```swift
    /// Re-anchor the reported `offset` on what the render server is currently presenting, without disturbing
    /// any animation. Call once at the top of a mutation pass so the pass reads a CURRENT position: `offset`
    /// is per-frame stable by contract, which makes it stale by however long the main thread has been busy
    /// since the last sampling tick. Continuity does not require currency (a single consistent value cancels
    /// algebraically), but membership, the anchor witness and the overscroll gate all do. No-op for an engine
    /// whose offset is already the presented value.
    func syncToPresentedPosition()
```

- [ ] **Step 4: Implement it**

`CoreListDemo/PhysicsScrollEngine.swift`, next to `haltMotionInPlace()`:

```swift
    func syncToPresentedPosition() {
        // Exactly what a sampling tick does first: reseed the physics at the flight's live sample. The CA
        // animation is untouched, so the flight keeps playing — only the value the list reads becomes current.
        flight?.beginTick(now: localNow())
    }
```

`CoreListDemo/UIKitScrollEngine.swift`:

```swift
    func syncToPresentedPosition() {
        // A `UIScrollView`'s `bounds.origin` is always the presented value; there is nothing to re-anchor.
    }
```

`CoreListDemoTests/TestSupport/TestScrollEngine.swift`:

```swift
    func syncToPresentedPosition() {
        flight?.beginTick(now: clock.now)
    }
```

`CoreListDemoTests/CoreVirtualListAnimationTests.swift` (`ClampingScrollEngine`):

```swift
        func syncToPresentedPosition() {
            // Its offset is already the presented value — nothing animates behind it.
        }
```

- [ ] **Step 5: Call it at pass entry**

In `CoreVirtualListView.swift`, directly below Task 2's `if hasScrollTo { engine.haltMotionInPlace() }`:

```swift
        // Re-anchor on the presented viewport once, before the first `engine.offset` read below. Everything
        // downstream — the anchor witness (:1481), buildWindow's projected load band, the overscroll gate
        // (:588, :819-828), refreshReachedLoadedEdges and the final coordinate re-base — then resolves
        // against the current viewport instead of the last sampling tick's. No-op after a halt above.
        engine.syncToPresentedPosition()
```

- [ ] **Step 6: Run to verify they pass**

Same command as Step 2. Expected: all `MidFlightPassLurchTests` pass.

- [ ] **Step 7: Run the full suite**

```sh
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro K2' \
  -parallel-testing-enabled NO test
```

Expected: `Executed 512 tests, with 0 failures`.

Two suites are the likely reactors, and both need reading rather than rebaselining if they move: `MidFlightPassLurchTests.test_membershipLag_equalsVelocityTimesStaleness` (it asserts the lag EXISTS between ticks — still true; the sync happens at pass entry, not on every read) and `ApplyChangesDuringFlightMutationTests` (mid-flight mutation geometry, which now resolves against a current position — assertions there are about offsets and windows and should be unchanged).

- [ ] **Step 8: Update the module docs**

In `CLAUDE.md`, in the `ScrollEngine.offset` gotcha, replace the sentence:

> The accepted cost is that membership/preload decisions trail the presented viewport by `velocity × (main-thread time since the last tick)`, against a 160pt `preloadMargin`.

with:

> A mutation pass calls `syncToPresentedPosition()` at entry, so it resolves against a current viewport; between ticks a plain `offset` read still trails the presented position by `velocity × (main-thread time since the last tick)`, which is what makes it stable. Halting momentum uses `haltMotionInPlace()` — never `setOffset(offset)`, which reads a stable value and then has it overwritten by the catch's instantaneous one.

- [ ] **Step 9: Update the spec's status**

In `docs/superpowers/specs/2026-07-26-clock-free-mutation-pass-design.md`, in the `## Landed` section's deferred list, mark items 1 and 3 done with the commit subjects, and delete them from `## Ranked: What This Fix Does NOT Address` (renumbering the rest).

- [ ] **Step 10: Commit**

```sh
git add submodules/TelegramUI/Components/CoreList/CoreListDemo/ScrollEngine.swift \
        submodules/TelegramUI/Components/CoreList/CoreListDemo/PhysicsScrollEngine.swift \
        submodules/TelegramUI/Components/CoreList/CoreListDemo/UIKitScrollEngine.swift \
        submodules/TelegramUI/Components/CoreList/CoreListDemo/CoreVirtualListView.swift \
        submodules/TelegramUI/Components/CoreList/CoreListDemoTests/TestSupport/TestScrollEngine.swift \
        submodules/TelegramUI/Components/CoreList/CoreListDemoTests/MidFlightPassLurchTests.swift \
        submodules/TelegramUI/Components/CoreList/CoreListDemoTests/CoreVirtualListAnimationTests.swift \
        submodules/TelegramUI/Components/CoreList/CLAUDE.md \
        submodules/TelegramUI/Components/CoreList/docs/superpowers/specs/2026-07-26-clock-free-mutation-pass-design.md
git commit -m "fix(corelist): re-anchor the engine on the presented viewport at pass entry"
```

---

### Task 4: Whole-app build check

**Files:** none.

`PhysicsScrollEngine`, `CoreVirtualListView` and `ScrollEngine` all compile into `//submodules/TelegramUI/Components/CoreList`, and `CoreListChatHistoryBackend` consumes that module. A grep for `: ScrollEngine` across `submodules/` and `Telegram/` found exactly four conformers, all inside this module (`UIKitScrollEngine`, `PhysicsScrollEngine`, `TestScrollEngine`, `ClampingScrollEngine`), so no out-of-module break is expected — this step confirms it and that the module still compiles under Bazel's stricter settings.

- [ ] **Step 1: Build the app**

```sh
source ~/.zshrc 2>/dev/null; python3 build-system/Make/Make.py --overrideXcodeVersion \
 --cacheDir ~/telegram-bazel-cache build \
 --configurationPath build-system/appstore-configuration.json \
 --gitCodesigningRepository git@gitlab.com:peter-iakovlev/fastlanematch.git \
 --gitCodesigningType development --gitCodesigningUseCurrent --buildNumber=1 \
 --configuration=debug_sim_arm64 --continueOnError
```

Expected: build succeeds. A failure here means some other `ScrollEngine` conformer exists outside the demo module; add the two methods to it rather than weakening the protocol.

- [ ] **Step 2: If a conformer had to be fixed, commit it**

Only reachable if Step 1 failed. Add the two methods to the conformer the compiler names, then:

```sh
git add <the file the compiler named>
git commit -m "fix(corelist): conform the remaining ScrollEngine implementation to the extended seam"
```
