# Topic-Header Stacking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render monoforum/thread topic headers under the CoreList chat-history backend, with the same collision-avoidance against floating date pills that `ListViewImpl` provides.

**Architecture:** An attachment declares a `stackingGroup` tag and, optionally, a `stackingYield` naming a group it defers to plus a minimum gap. The yield resolves **inside** `AttachmentOffsetMap.y(atOffset:)` — not as a post-solve fix-up — because `composedKeyframe` samples that function to bake the CA track a momentum flight rides, and the render server cannot consult another attachment. The chat maps header `space` onto the group tag.

**Tech Stack:** Swift, UIKit, Bazel (app), xcodebuild + XCTest (CoreList demo suite).

**Design spec:** `docs/superpowers/specs/2026-08-03-corelist-topic-header-stacking-design.md`

## Global Constraints

- **Do not modify `ListViewImpl`** (`submodules/Display/Source/ListView.swift`), including its order-dependent overlap pick. Divergence is confined to inputs where its result is arbitrary.
- **One level of yielding only.** A map that yields must not itself be a yield target. Enforce with `assert`, not comments alone.
- Both new `CoreListAttachedItem` members are **defaulted in the protocol extension** (`nil`), so no existing attachment or demo row changes behavior.
- The `27.0` gap lives **chat-side** as a named constant (`7 + 20`, gap plus the date pill's visual height). CoreList never learns it.
- `submodules/TelegramUI/Components/CoreList/` is vendored; 658/665 submodule BUILDs use `-warnings-as-errors`, so unused vars and always-false casts fail the build.
- Test sim is **`iPhone 17 Pro K2`** (dedicated; the shared default is flaky).

**Suite command** (run from `submodules/TelegramUI/Components/CoreList`):

```bash
xcodebuild test -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro K2' 2>&1 | tail -20
```

**App build command** (run from repo root):

```bash
source ~/.zshrc 2>/dev/null; python3 build-system/Make/Make.py --overrideXcodeVersion \
  --cacheDir ~/telegram-bazel-cache build \
  --configurationPath build-system/appstore-configuration.json \
  --gitCodesigningRepository git@gitlab.com:peter-iakovlev/fastlanematch.git \
  --gitCodesigningType development --gitCodesigningUseCurrent --buildNumber=1 \
  --configuration=debug_sim_arm64 --continueOnError 2>&1 | grep -E "error:|Build completed"
```

---

## File Structure

| File | Responsibility |
|---|---|
| `CoreListDemo/CoreListAttachedItem.swift` | The two new protocol members + defaults |
| `CoreListDemo/AttachmentSolve.swift` | `AttachmentOffsetMap` yield composition — the core |
| `CoreListDemo/CoreVirtualListView+Attachments.swift` | Build partner maps, pass them into `attachmentMap` |
| `CoreListDemo/AttachmentRuns.swift` | Attachment sort: a yielder sorts below its target group |
| `CoreListDemoTests/AttachmentStackingTests.swift` | **New.** All solve/order/parity tests |
| `TelegramUI/Sources/CoreListChatHistoryHeaders.swift` | `stackingGroup` / `stackingYield` from header spaces |
| `TelegramUI/Sources/CoreListChatHistoryBackend.swift` | Drop the `stackingId` skip |
| `docs/chat/corelist-chat-history-backend.md` | Move the item out of Deferred |

---

### Task 1: Yield declaration on the attachment protocol

**Files:**
- Modify: `submodules/TelegramUI/Components/CoreList/CoreListDemo/CoreListAttachedItem.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `CoreListAttachedItem.stackingGroup: AnyHashable?` and `CoreListAttachedItem.stackingYield: (group: AnyHashable, gap: CGFloat)?`, both defaulted to `nil`.

- [ ] **Step 1: Add the two members to the protocol**

In `public protocol CoreListAttachedItem`, after `var spansMemberInsets: Bool { get }`:

```swift
    /// The group this attachment belongs to for stacking purposes. Default `nil` — participates in
    /// none. A tag rather than a type, so the engine never learns what the members are.
    var stackingGroup: AnyHashable? { get }

    /// The group this attachment defers to, and the minimum gap it keeps from any member of it.
    /// Default `nil`.
    ///
    /// ONE LEVEL ONLY: an attachment that yields must not itself be named as a `stackingGroup`
    /// target, or the solve would need cycle detection. Asserted in `AttachmentOffsetMap`.
    var stackingYield: (group: AnyHashable, gap: CGFloat)? { get }
```

- [ ] **Step 2: Add the defaults**

In `public extension CoreListAttachedItem`, alongside `var spansMemberInsets: Bool { true }`:

```swift
    var stackingGroup: AnyHashable? { nil }
    var stackingYield: (group: AnyHashable, gap: CGFloat)? { nil }
```

- [ ] **Step 3: Run the suite to confirm nothing regressed**

Run the suite command. Expected: `** TEST SUCCEEDED **`. Defaulted members alone change no behavior.

- [ ] **Step 4: Commit**

```bash
git add submodules/TelegramUI/Components/CoreList/CoreListDemo/CoreListAttachedItem.swift
git commit -m "feat(corelist): declare stacking groups on attachments"
```

---

### Task 2: Yield composition in the solve

**Files:**
- Modify: `submodules/TelegramUI/Components/CoreList/CoreListDemo/AttachmentSolve.swift`
- Create: `submodules/TelegramUI/Components/CoreList/CoreListDemoTests/AttachmentStackingTests.swift`

**Interfaces:**
- Consumes: Task 1's protocol members (not directly — this task is pure geometry).
- Produces: `AttachmentOffsetMap.init(..., yield: (partners: [AttachmentOffsetMap], gap: CGFloat)? = nil)`, and a `y(atOffset:)` that resolves it.

- [ ] **Step 1: Write the failing tests**

Create `AttachmentStackingTests.swift`. Build maps with the existing `AttachmentOffsetMap` init (read its current signature in `AttachmentSolve.swift` — it takes `bandTop:bandBottom:height:` plus the geometry params) and add `yield:`.

```swift
import XCTest
@testable import CoreListDemo

final class AttachmentStackingTests: XCTestCase {
    // A partner far above must NOT drag the yielding attachment up: only an OVERLAPPING
    // partner participates. Without the overlap test, `partnerY - gap` wins the min
    // unconditionally and the header flies to the top of the band.
    func testFarAbovePartnerDoesNotPull() { }

    // The nudge engages on overlap and lands exactly `gap` clear.
    func testOverlappingPartnerPushesByGap() { }

    // Never above the band top.
    func testNudgeClampsAtBandTop() { }

    // Deterministic among several overlapping partners: the topmost wins, and the result does
    // not depend on the order partners are supplied in.
    func testTopmostPartnerWinsRegardlessOfOrder() { }

    // The case ListViewImpl needed two passes for: pushing clear of one partner creates a NEW
    // overlap with a partner that was not overlapping before.
    func testPushCreatingNewOverlapConvergesToFixedPoint() { }
}
```

Fill each body with concrete geometry, e.g. for `testOverlappingPartnerPushesByGap`: partner solved at `y = 100`, own natural `y = 110`, `gap = 27` → expect `73`.

- [ ] **Step 2: Run to verify they fail**

Run the suite command. Expected: compile failure — `yield:` is not a parameter of `AttachmentOffsetMap.init`.

- [ ] **Step 3: Add the stored yield and the composition**

In `AttachmentSolve.swift`, add a stored property and init parameter:

```swift
    /// Partner maps this attachment defers to, and the gap it keeps. `nil` for the common case.
    ///
    /// The partners are maps, not solved values, because the resolution has to be a pure function
    /// of offset: `composedKeyframe` SAMPLES `y(atOffset:)` along the trajectory to bake the CA
    /// track a momentum flight rides, and nothing on the render server can consult another
    /// attachment. A post-solve fix-up would simply not exist during a flight.
    private let yield: (partners: [AttachmentOffsetMap], gap: CGFloat)?
```

Rename the existing body of `y(atOffset:)` to `ownY(atOffset:)` (make it `private`), then:

```swift
    func y(atOffset offset: CGFloat) -> CGFloat {
        let own = ownY(atOffset: offset)
        guard let yield, !yield.partners.isEmpty else {
            return own
        }
        var result = own
        // Fixed point rather than ListViewImpl's `for _ in 0 ..< 2` (ListView.swift:4054): pushing
        // clear of one partner can create a new overlap with one that was clear before, which is
        // exactly what its second pass catches. Bounded by partner count — each iteration that
        // changes anything strictly lowers `result` past at least one partner.
        for _ in 0 ... yield.partners.count {
            var next = result
            for partner in yield.partners {
                assert(partner.yield == nil, "stacking yield must be one level only")
                let partnerY = partner.y(atOffset: offset)
                // Overlap test, and it is load-bearing: without it a partner far above wins the
                // min unconditionally and drags the attachment up with it.
                guard partnerY < next + height, partnerY + partner.height > next else {
                    continue
                }
                next = min(next, partnerY - yield.gap)
            }
            next = max(lo, next)
            if next == result {
                break
            }
            result = next
        }
        return result
    }
```

Note: taking the `min` over every overlapping partner is what makes this deterministic — no tie-break, so `ListViewImpl`'s order-dependent pick (`ListView.swift:4064-4070`) has nothing to reproduce.

- [ ] **Step 4: Run tests to verify they pass**

Run the suite command. Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add submodules/TelegramUI/Components/CoreList/CoreListDemo/AttachmentSolve.swift \
        submodules/TelegramUI/Components/CoreList/CoreListDemoTests/AttachmentStackingTests.swift
git commit -m "feat(corelist): resolve attachment yielding inside the solve"
```

---

### Task 3: Keyframe parity for a yielding map

**Files:**
- Modify: `submodules/TelegramUI/Components/CoreList/CoreListDemoTests/AttachmentStackingTests.swift`

**Interfaces:**
- Consumes: Task 2's `yield:` init parameter.
- Produces: nothing — this is the test that would have caught the rejected post-solve design.

- [ ] **Step 1: Write the failing test**

```swift
    // The whole reason the yield lives in the solve. `composedKeyframe` bakes the CA track a
    // momentum flight rides by SAMPLING `y(atOffset:)` (AttachmentSolve.swift:103), so a yield
    // resolved anywhere else would be absent from the flight: the attachment would ride un-nudged
    // for the whole deceleration and snap at the end. Assert vertex-by-vertex, as
    // AttachmentKeyframeParityTests does.
    func testComposedKeyframeCarriesTheNudge() { }
```

Build a trajectory whose offsets sweep the yielding attachment through overlap and out again, call `composedKeyframe(trajectory:coordinateShift:)`, and assert each baked value equals `y(atOffset: sample.offset + shift) - settled` for that sample. Model it on the existing `AttachmentKeyframeParityTests`.

- [ ] **Step 2: Run to verify it passes**

Run the suite command. Expected: `** TEST SUCCEEDED **` — this passes with Task 2's implementation. It is a regression guard, so confirm it FAILS if you temporarily move the yield out of `y(atOffset:)` into a caller, then restore.

- [ ] **Step 3: Commit**

```bash
git add submodules/TelegramUI/Components/CoreList/CoreListDemoTests/AttachmentStackingTests.swift
git commit -m "test(corelist): pin that a yielding attachment bakes its nudge into the flight"
```

---

### Task 4: Feed partner maps into the solve

**Files:**
- Modify: `submodules/TelegramUI/Components/CoreList/CoreListDemo/CoreVirtualListView+Attachments.swift` (`attachmentMap(_:window:)`, ~line 398)

**Interfaces:**
- Consumes: Task 1's protocol members, Task 2's `yield:` parameter.
- Produces: `attachmentMap(_:window:)` returning a map whose `yield` is populated for a yielding attachment.

- [ ] **Step 1: Populate the yield in `attachmentMap`**

`Window.Attachment` needs the two declarations available at solve time. Carry `stackingGroup` and `stackingYield` onto `Window.Attachment` where `placement`/`edge`/`isFloating` are already copied from `run.representative` (`CoreVirtualListView+Attachments.swift`, the `resolved.append(Window.Attachment(...))` call), then in `attachmentMap`:

```swift
        var yield: (partners: [AttachmentOffsetMap], gap: CGFloat)?
        if let declared = attachment.stackingYield {
            // Partners are the OTHER attachments tagged into the named group. Built here rather
            // than cached because a map is a value derived from this pass's band geometry.
            let partners = window.attachments
                .filter { $0.stackingGroup == declared.group && $0.serial != attachment.serial }
                .map { attachmentMap($0, window: window) }
            if !partners.isEmpty {
                yield = (partners: partners, gap: declared.gap)
            }
        }
```

and pass `yield: yield` to the `AttachmentOffsetMap` init. The recursion terminates because of the one-level rule: a partner is in a group, and a group member does not itself yield (asserted in Task 2).

- [ ] **Step 2: Run the suite**

Run the suite command. Expected: `** TEST SUCCEEDED **` — no demo attachment declares a group, so every `yield` is `nil`.

- [ ] **Step 3: Commit**

```bash
git add submodules/TelegramUI/Components/CoreList/CoreListDemo/CoreVirtualListView+Attachments.swift
git commit -m "feat(corelist): build partner maps for a yielding attachment"
```

---

### Task 5: Stick distance against the adjusted bound

**Files:**
- Modify: `submodules/TelegramUI/Components/CoreList/CoreListDemo/AttachmentSolve.swift` (`stickDistance(atOffset:)`)
- Modify: `submodules/TelegramUI/Components/CoreList/CoreListDemoTests/AttachmentStackingTests.swift`

**Interfaces:**
- Consumes: Task 2's `yield`.
- Produces: `stickDistance(atOffset:)` measuring a yielding attachment against its adjusted natural bound.

- [ ] **Step 1: Write the failing test**

```swift
    // ListViewImpl recomputes the stick distance against `naturalOverlapLowerBound`
    // (ListView.swift:4039-4052, :4084), not the attachment's own natural edge — otherwise a
    // header that has been pushed clear reports itself as parked and fades out.
    func testStickDistanceMeasuresAgainstTheAdjustedBound() { }
```

- [ ] **Step 2: Run to verify it fails**

Run the suite command. Expected: FAIL — the distance is currently measured against the unadjusted bound.

- [ ] **Step 3: Implement**

In `stickDistance(atOffset:)`, when `yield` is non-nil and a partner shares this attachment's natural origin at `offset`, measure against `partnerNaturalY - gap` instead of the own natural edge. Keep it in this file: a second derivation of "how far is it stuck" would be free to disagree with the rendered position, which is the reason the method lives here at all.

- [ ] **Step 4: Run tests to verify they pass**

Run the suite command. Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add submodules/TelegramUI/Components/CoreList/CoreListDemo/AttachmentSolve.swift \
        submodules/TelegramUI/Components/CoreList/CoreListDemoTests/AttachmentStackingTests.swift
git commit -m "feat(corelist): measure a yielding attachment's stick distance against its adjusted bound"
```

---

### Task 6: Attachment sort order (z-index)

**Files:**
- Modify: `submodules/TelegramUI/Components/CoreList/CoreListDemo/AttachmentRuns.swift` (the sort in `pendingRuns`)
- Modify: `submodules/TelegramUI/Components/CoreList/CoreListDemoTests/AttachmentStackingTests.swift`

**Interfaces:**
- Consumes: Task 1's `stackingYield`.
- Produces: attachment order in which a yielder precedes (renders below) its target group.

- [ ] **Step 1: Write the failing test**

```swift
    // ListViewImpl's `insertItemBelowOtherHeaders` (ListView.swift:4037). NOT free: the sort is
    // currently (memberRange.lowerBound, key description), and this makes the yield declaration an
    // input to an ordering other behavior already depends on — hence its own test.
    func testYieldingAttachmentSortsBelowItsTargetGroup() { }
```

- [ ] **Step 2: Run to verify it fails**

Run the suite command. Expected: FAIL — order is currently independent of the yield.

- [ ] **Step 3: Implement**

Add a leading sort key: an attachment whose `stackingYield` names another attachment's `stackingGroup` sorts before it. Preserve `(memberRange.lowerBound, key description)` as the tiebreak so existing ordering is untouched wherever no yield is declared.

- [ ] **Step 4: Run tests to verify they pass**

Run the suite command. Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add submodules/TelegramUI/Components/CoreList/CoreListDemo/AttachmentRuns.swift \
        submodules/TelegramUI/Components/CoreList/CoreListDemoTests/AttachmentStackingTests.swift
git commit -m "feat(corelist): sort a yielding attachment below its target group"
```

---

### Task 7: Chat wiring

**Files:**
- Modify: `submodules/TelegramUI/Sources/CoreListChatHistoryHeaders.swift` (`CoreListHeaderAttachedItem`)
- Modify: `submodules/TelegramUI/Sources/CoreListChatHistoryBackend.swift` (the `attachedItems` loop, ~line 1086)

**Interfaces:**
- Consumes: Task 1's protocol members.
- Produces: topic headers present in `attachedItems`, tagged and yielding.

- [ ] **Step 1: Drop the skip**

In `CoreListChatHistoryBackend.swift`, delete the `if header.stackingId != nil { continue }` guard and its comment.

- [ ] **Step 2: Declare the group and the yield**

In `CoreListHeaderAttachedItem`, after `spansMemberInsets`:

```swift
    // `7.0 + 20.0` from ListView.swift:4047 — the gap plus the date pill's visual height inside its
    // 34pt band. A chat visual fact, so it stays here; CoreList never learns it.
    private static let stackingGap: CGFloat = 27.0

    // The header's own space IS the group: date pills are space 2, topic headers space 3
    // (ChatMessageDateHeader.swift:80-88). Tag, not type — see CoreListAttachedItem.
    var stackingGroup: AnyHashable? {
        return AnyHashable(self.header.id.space)
    }

    var stackingYield: (group: AnyHashable, gap: CGFloat)? {
        guard let stackingId = self.header.stackingId else {
            return nil
        }
        return (group: AnyHashable(stackingId.space), gap: Self.stackingGap)
    }
```

- [ ] **Step 3: Build the app**

Run the app build command. Expected: `Build completed successfully`.

- [ ] **Step 4: Commit**

```bash
git add submodules/TelegramUI/Sources/CoreListChatHistoryHeaders.swift \
        submodules/TelegramUI/Sources/CoreListChatHistoryBackend.swift
git commit -m "feat(chat): render topic headers on the CoreList backend"
```

---

### Task 8: Runtime verification and docs

**Files:**
- Modify: `docs/chat/corelist-chat-history-backend.md` (the `### Deferred` list)
- Modify: `CLAUDE.md` (the still-open deferred list in the ChatHistoryListNode composition section)

**Interfaces:**
- Consumes: everything above.
- Produces: nothing.

- [ ] **Step 1: Verify on the simulator**

Install the fresh build over the running sim (whole-`.app` copy recipe in `CLAUDE.md`), open a monoforum whose topics span a day boundary, and scroll a date pill into a topic header. Confirm the topic header slides clear rather than overlapping, recovers as the pill scrolls away, and — critically — **stays clear during a momentum fling**, not only under a slow drag. A nudge that works while dragging but not while flinging means the yield is not reaching the baked track.

- [ ] **Step 2: Move the item out of Deferred**

In `docs/chat/corelist-chat-history-backend.md`, strike the **Topic headers** bullet the way the band-trim and `attachedHeaderNodes` bullets were struck, recording: the yield-group API, why the resolution lives in the solve, the deterministic divergence from `ListViewImpl`'s arbitrary pick, and the sort-order change.

- [ ] **Step 3: Update the root CLAUDE.md**

Remove topic-header stacking from the still-open list, leaving per-item animation selectivity and `stationaryItemRange` bounds.

- [ ] **Step 4: Commit**

```bash
git add docs/chat/corelist-chat-history-backend.md CLAUDE.md
git commit -m "docs: record topic-header stacking as implemented"
```

---

## Self-Review

**Spec coverage:** Yield-group API → Task 1. Solve composition, determinism, overlap test, fixed point, one-level assert → Task 2. Baking → Task 3. Partner-map construction → Task 4. Stick distance → Task 5. Z-order → Task 6. Chat wiring, drop skip, 27 chat-side → Task 7. Tests 1-5 of the spec → Tasks 2/6; test 6 → Task 3. Non-goals → Global Constraints. Runtime verification → Task 8. **No gaps.**

**Type consistency:** `stackingGroup: AnyHashable?` and `stackingYield: (group: AnyHashable, gap: CGFloat)?` are spelled identically in Tasks 1, 4, 6 and 7. `AttachmentOffsetMap`'s stored member is `yield: (partners: [AttachmentOffsetMap], gap: CGFloat)?` in Tasks 2, 4 and 5. `ownY(atOffset:)` is introduced in Task 2 and referenced nowhere else.

**Known soft spots for the implementer:**
- Task 2 asks you to read `AttachmentOffsetMap`'s existing init signature before adding `yield:`; the surrounding parameters are not reproduced here.
- Task 5's implementation step describes the adjusted-bound rule rather than giving the diff, because it depends on how `stickDistance` currently reads `lo`/`hi`. Read `AttachmentSolve.swift:108-125` first.
- Task 6 does not spell out the comparator; the existing sort must remain the tiebreak.
