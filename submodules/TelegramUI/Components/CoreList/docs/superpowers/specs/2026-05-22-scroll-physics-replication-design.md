# Scroll physics replication — design spec

**Date:** 2026-05-22
**Status:** IMPLEMENTED / CURRENT

## Goal

Replicate `UIScrollView`'s exact scroll physics (drag, rubber-band, flick velocity, deceleration, bounce, settle) in a standalone **pure, non-UIKit Swift core** (`ScrollPhysics`), and prove it matches a real `UIScrollView` via a **record-and-replay** regression suite backed by **method swizzling**.

The physics formulas were reverse-engineered from UIKitCore (iOS 26.2, arm64e) and are documented — with exact constants and asm provenance — in [`docs/plans/2026-05-22-uikit-scrollview-physics-analysis.md`](../../plans/2026-05-22-uikit-scrollview-physics-analysis.md). **That analysis doc is the source of truth for the math; this spec does not re-derive it.**

## Context & constraints

- **Clean-room exploration.** This module must not depend on, import, or modify `CoreVirtualListView`, `TestableScrollView`, `ListAnimator`, or the existing deterministic test harness. It lives in its own directories.
- Eventual intent (out of scope here): drive `CoreVirtualListView` with this core instead of `UIScrollView`. Not part of this spec.
- Same Xcode project / two existing targets — no new target. The `PBXFileSystemSynchronizedRootGroup` auto-includes new files under `CoreListDemo/` and `CoreListDemoTests/`.

## Non-goals

- Paging, zoom, directional lock, scroll-to-top, keyboard avoidance.
- The no-bounce (`_getStandardDecelerationOffset`) and paging (`_getPagingDecelerationOffset`) deceleration variants — out of scope; a normal bouncing list never hits them.
- Re-implementing `UIPanGestureRecognizer` (its velocity smoothing). We consume the recognizer's `translation`/`velocity`, exactly as `UIScrollView` does (Option A boundary, below).
- A production `CADisplayLink` driver. The pure steppable core is the deliverable; a thin wrapper is trivial to add later and is not specified here.
- Any change to shipping demo behavior. The recorder/swizzler are debug-only and unreferenced by the demo flow.

## Architecture

```
CoreListDemo/ScrollPhysics/
  ScrollPhysics.swift          # pure core (no UIKit) — the deliverable; 2-axis, composes ScrollAxis
  RubberBand.swift             # pure §1 formula (free functions)
  Deceleration.swift           # pure §2 step: decay + mid-frame bound-split + spring + settle
  Projection.swift             # pure §5 flick target
  OffsetMath.swift             # pure §6 min/max bounds + pixel rounding
  Recording/                   # UIKit, debug-only, NOT in the shipping demo flow
    ScrollRecorderViewController.swift
    UIScrollViewPhysicsSwizzler.swift
    GestureRecording.swift     # Codable fixture model + JSON I/O
CoreListDemoTests/ScrollPhysics/
  Fixtures/*.json              # committed, hand-recorded canonical gestures
  ScrollPhysicsReplayTests.swift     # end-to-end trajectory
  ScrollPhysicsFormulaTests.swift    # per-formula vs swizzle-captured tuples
```

Boundaries: the pure core has zero UIKit imports; the recorder/swizzler are the only UIKit pieces and are debug-only; tests import only the pure core + Foundation (to decode fixtures).

## Component: `ScrollPhysics` core (pure, both axes)

Per-axis engine `ScrollAxis` composed into a 2-axis `ScrollPhysics` (the math is axis-symmetric, so both axes are free). The detailed numerical formulas live in the analysis doc §1–§6; this is the API surface and which formula each step uses.

```swift
struct ScrollAxis {
    // Config (from the scrolled view's geometry at gesture start):
    //   min, max          — content-offset bounds (analysis §6)
    //   range             — visible bounds dimension (rubber-band asymptote, §1)
    //   rate              — decelerationRate (0.998 normal / 0.99 fast), per ms (§2)
    //   lnRate            — ln(rate), precomputed (§2/§5)
    //   vScale            — velocity scale (default 1.0; §2/§3)  [open question: confirm default]
    //   scale             — screen scale, for pixel rounding (§6)
    //   c                 — rubber-band coefficient (0.55, §1)
    // State:
    //   offset, velocity (pts/ms), prevVelocity, dragStartOffset, phase ∈ {idle, dragging, decelerating}

    mutating func beginDrag()
        // dragStartOffset = offset; phase = .dragging

    mutating func drag(translation: CGFloat, recognizerVelocity: CGFloat)
        // proposed   = dragStartOffset − translation                 (§3)
        // offset     = RubberBand.offset(proposed, min, max, range, c) (§1) — or hard clamp if bounce disabled
        // prevVelocity = velocity
        // velocity   = −recognizerVelocity · 0.001                    (§3, pts/s→pts/ms, negated)

    mutating func endDrag() -> Decision   // .decelerate | .stop
        // velocity = 0.75·velocity + 0.25·prevVelocity                (§4 low-pass)
        // |v|² < 0.0625 → .stop ; else → .decelerate, phase = .decelerating  (§4 thresholds)

    mutating func step(dtMs: CGFloat) -> (offset: CGFloat, settled: Bool)
        // Deceleration.step: free decay (offset += v·rate·(1−rate^dtMs)/(1−rate); v·=rate^dtMs),
        //   mid-frame bound-crossing split, spring (fixed 0.99/ms stiffness), 0.5px settle.  (§2)

    func projectedTarget() -> CGFloat
        // offset + sign(v)·(|v| − 0.01)/|lnRate| · vScale             (§5)
}
```

All canonical fixtures use a **bounce-enabled** scroll view (the default), so the rubber-band path is the one under test; the `_clampScrollOffsetToBounds:` hard-clamp branch is implemented for completeness but not exercised by these fixtures (it is *not* the no-bounce *deceleration* variant, which is a non-goal).

Pure free-function formula modules (so the per-formula tests can call them directly against swizzle-captured tuples):
- `RubberBand.offset(_:min:max:range:c:) -> CGFloat`  (§1)
- `OffsetMath.minOffset(...)`, `OffsetMath.maxOffset(...)`, `OffsetMath.pixelRound(_:scale:)`  (§6)
- `Deceleration.step(...)`  (§2)
- `Projection.target(...)`  (§5)

## Component: recorder + swizzling (capture fidelity)

`UIScrollViewPhysicsSwizzler` exchanges IMPs to capture ground truth **at the source** (private signatures with `CGFloat`/pointer args use typed `@convention(c)` IMP casts):
- `setContentOffset:` → every exact offset write (the true trajectory, not a frame-sampled approximation).
- `_rubberBandOffsetForOffset:maxOffset:minOffset:range:outside:` → `(offset, min, max, range) → output` tuples.
- recognizer `translationInView:` / `velocityInView:` → the exact per-frame input `UIScrollView` consumed.

`ScrollRecorderViewController`: a standalone screen (not wired into the demo) with a plain tall `UIScrollView`; record / stop / save controls. Hand-driven — you perform the canonical gestures by finger. On stop it serializes a `GestureRecording` to JSON; you commit the JSON into `CoreListDemoTests/ScrollPhysics/Fixtures/`.

`GestureRecording` (Codable):
- geometry: `contentSize`, `bounds`, `contentInset`, `screenScale`, `decelerationRate`
- `inputSamples: [(t, translation: CGPoint, velocity: CGPoint)]`  (drag phase)
- `offsetWrites: [(t, offset: CGPoint)]`  (whole gesture + deceleration; ground-truth trajectory)
- `rubberBandSamples: [(offset, min, max, range, out)]`  (per-formula ground truth)
- metadata: gesture name/kind

## Data flow

`hand gesture → swizzle capture → GestureRecording → JSON fixture (committed) → deterministic replay test → assertions`

## Verification

Canonical fixtures: **slow drag-release** · **medium flick** (settles mid-content) · **fast flick into top/bottom edge** (decel → bounce) · **drag-past-edge-release** (rubber-band return).

- **Per-formula** (`ScrollPhysicsFormulaTests`): for each captured `rubberBandSample`, assert `RubberBand.offset(...) == out` within **1e-6**. Add bounds checks if those are captured too. Pinpoints *which* formula diverges, independent of integration.
- **End-to-end** (`ScrollPhysicsReplayTests`): replay `inputSamples` through `ScrollPhysics` **at the recorded timestamps** (identical `dt` sequence — frame timing cannot masquerade as a physics bug). At each `offsetWrites` timestamp, assert our offset matches the recorded write. Tolerance starts at **≤ 0.5 px** (the settle tolerance) and is tightened toward **1e-3** once green; residual divergence beyond that flags a real formula gap to chase in the analysis doc.

Run with the project-standard incantation:
```
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test \
  -only-testing:CoreListDemoTests/ScrollPhysicsReplayTests \
  -only-testing:CoreListDemoTests/ScrollPhysicsFormulaTests
```

## Risks / open questions

- **`vScale` default** (ivar `0x1ea7983c4`): assumed 1.0; confirm from its initializer. If it isn't 1.0 the swizzle captures will reveal it (rubber-band/decel tuples won't match) — self-correcting via the per-formula tests.
- **Swizzling `CGFloat`/pointer signatures from Swift**: needs correctly-typed `@convention(c)` casts of `class_getMethodImplementation`; the `outside:` `BOOL*` out-param must be modeled as `UnsafeMutablePointer<ObjCBool>`. Verify type encodings match before trusting captures.
- **Private-method dependence**: the swizzled selectors are private and version-specific. Acceptable — this never ships and is gated to the recorder. If a selector is absent at runtime, the swizzler should no-op that hook and the recording omits those tuples (end-to-end still works via `setContentOffset:`).
- **Tolerance**: 0.5px start is a scaffold, not the goal; the intent is to reach ~1e-3 on the pure-math phases.
