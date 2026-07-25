# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with this repository.

> **How to use this file.** It is a map, not a substitute for the source. Each architecture section
> ends with a **`📖 Read before changing:`** list. Read those files and the matching design before
> editing that subsystem.

## Project

iOS UIKit demo (Swift 5, iOS 26.2 deployment target) showcasing `CoreVirtualListView`, a custom
virtualized scroll view that renders only a loaded window from a large item collection. Single Xcode
scheme: `CoreListDemo`. Test target: `CoreListDemoTests` (XCTest).

**This directory (vendored into telegram-ios) is the source of truth.** `~/Documents/CoreListDemo`
is a stale backup, not the live project. `CoreListDemo.xcodeproj` is committed here even though the
root telegram-ios `.gitignore` ignores `*.xcodeproj` — it is re-included via a `!CoreListDemo.xcodeproj`
negation in this directory's `.gitignore` (the same trick `Telegram/WatchApp` uses for `tgwatch.xcodeproj`),
so the demo + tests build and run on the K2 simulator directly from within telegram-ios. The project
uses `PBXFileSystemSynchronizedRootGroup`, so it tracks the `CoreListDemo/` + `CoreListDemoTests/`
sources on disk automatically (only `Info.plist` is a membership exception). `project.xcworkspace` and
`xcuserdata` stay git-ignored; xcodebuild regenerates the implicit workspace, so a fresh clone builds
with just the committed `project.pbxproj` + shared scheme. These files are **excluded from the Bazel
`CoreList` swift_library** (see `BUILD`), so the Telegram app build does NOT compile the demo/tests —
the xcodebuild suite below is their only build/verification surface.

## Build / Test

```bash
# Build
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro K2' build

# Run all tests
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro K2' \
  -parallel-testing-enabled NO test

# Run one test class
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro K2' \
  -parallel-testing-enabled NO test \
  -only-testing:CoreListDemoTests/CoreVirtualListAnimationTests
```

Every test command must use both mandatory options:

- `-destination 'platform=iOS Simulator,name=iPhone 17 Pro K2'` — use only the dedicated K2
  simulator. A generic similarly named simulator is a different device and may be in use.
- `-parallel-testing-enabled NO` — keep one boot target and deterministic execution.

The project uses `PBXFileSystemSynchronizedRootGroup`; files added under `CoreListDemo/` or
`CoreListDemoTests/` are discovered automatically without editing `project.pbxproj`.

## Architecture

Core files are `CoreVirtualListView.swift` (diff, settled window, rendering, transaction composition),
`ListAnimationModel.swift` (analytic state), `ListAnimationController.swift` (model/layer lifecycle),
`CoreAnimationCompiler.swift` (CA keyframe output), `Scheduler.swift` (deferred dirty flush), and the
scroll-engine seam.

### Scroll-engine seam

`CoreVirtualListView` consumes `ScrollEngine`; it does not touch `UIScrollView` directly. The seam
provides `offset`, programmatic `setOffset`/`applyShift`, edge declaration, user-scroll callbacks
(`onScroll` per-frame, and `onWillBeginDragging` when the pan reaches `.began` — UIKit via
`scrollViewWillBeginDragging`, physics via `handlePan(.began)`), `contentHost`, and
`containerOrigin(windowHeight:topLoaded:bottomLoaded:)`.

- `UIKitScrollEngine` is the production default and the only list component that knows
  `UIScrollView`. It owns the private 10,000,000-point virtual canvas and prevents programmatic
  offset writes from re-entering the user-scroll callback.
- `PhysicsScrollEngine` is an additive selectable backend with `.stepped` and `.keyframe`
  deceleration. A finger on moving content grabs the scroll and absorbs the stopping tap. The
  stopping-tap absorption works by declaring, via `shouldBeRequiredToFailBy`, that content
  recognizers under `host` must wait for the pan to fail — and that declaration is **gated on content
  actually moving**; see the gotcha below before touching it.
- Both physics modes use `PhysicsScrollCore`. The keyframe mode renders deceleration through
  `KeyframeFlight`; coordinate-only rebases update its persistent shift without restarting the
  flight, while a true edge or trajectory-shape change rebakes with a seamless splice. A real edge
  change is a durable trajectory invalidation: it survives sampling-tick boundaries, coalesces with
  later edge changes, and is consumed only after one continuous rebake against the latest bounds.
  A shift is translation-only while both edges are open. If either edge is finite, moving the
  engine offset while that edge stays fixed changes relative trajectory geometry, so the shift and
  latest edges are folded into one continuous re-bake. Pending invalidation outranks completion of
  the obsolete sampler or CA trajectory, preserving analytic current position and velocity whenever
  motion remains.

The UIKit-backed suite remains the core-list additivity oracle. The physics-backed list path is
covered by `PhysicsListIntegrationTests` plus the physics and keyframe unit suites. The Virtual List
demo defaults to `PhysicsScrollEngine` with keyframe deceleration; UIKit and stepped physics remain
selectable from the engine control.

📖 **Read before changing:** `ScrollEngine.swift`, `UIKitScrollEngine.swift`,
`PhysicsScrollEngine.swift`, `PhysicsScrollCore.swift`, `KeyframeFlight.swift`, and designs
`docs/plans/2026-05-26-scroll-engine-seam-design.md`,
`docs/plans/2026-05-26-physics-scroll-engine-design.md`,
`docs/plans/2026-05-26-keyframe-list-deceleration-design.md`, and
`docs/plans/2026-05-28-trackpad-list-engine-design.md`.

### Virtual content and settled window

The list declares scrollable limits through `engine.setEdges(min:max:)`. `UIKitScrollEngine` maps an
open edge to its private virtual canvas and a fully bounded list to a tight viewport-aware range.
The plain `container` holds loaded live views:

- top loaded: minimum edge 0 and container origin 0;
- bottom loaded: the engine supplies the bottom-aligned origin;
- neither edge loaded: the engine supplies its neutral origin and `applyShift` preserves screen
  position across container rebases.

`activeWindow` is a pure settled `Window` value containing contiguous `(index, view, frame)` items.
It is the loaded projection of the current item collection, not animation state. Frames are
container-local; `minY` may be negative, and `render()` places each view at
`frame.minY - window.minY`. Absolute content Y is therefore
`containerOriginY + frame.minY - window.minY`.

Transaction windows are built once in final projected viewport coordinates against
`-preloadMargin ... logicalSize.height + preloadMargin`. Loaded-edge constraints are resolved during
that bounded traversal; render-time container parking is membership-neutral. User-scroll
rebalancing uses the same projected load band. When a container rebase is required, the engine
offset and any exit-overlay children receive the same shift so their visible positions do not jump.
For size/inset transitions, the shared anchor's old-to-new absolute content-Y delta identifies that
coordinate-only rebase. Without an explicit `scrollTo`, a top-inset change projects the resolved anchor
point by `newTopInset - oldTopInset` before the one-pass window build, preserving the anchor's settled
distance from the inset edge. Window construction traverses toward lower indices and clips at the loaded
top first, then traverses toward higher indices and clips at the loaded bottom; top wins for an underfilled
collection. The completed projected window is the sole source of the new settled engine offset. The
anchor coordinate shift is used only to cancel container parking in the additive viewport track. Shared rows do
not receive compensating position tracks, and captured overscroll is restored only after settled edge
resolution as presentation-only state; moves keep ownership of their geometry.

`applyChanges(anchorMode: .preserveVisibleContent)` is an opt-in infinite-loading policy. It selects
the loaded item crossing the old top-inset edge from settled geometry and preserves that identity's
own distance from the inset edge. A moved identity remains the witness; a departing identity falls
back to the nearest loaded survivor below, then above. The policy never measures old off-screen rows,
never post-corrects the engine offset, and yields to explicit `scrollTo` and normal finite-edge
clipping. `.automatic` retains the finite-list edge behavior.

`reachedLoadedEdges` exposes which finite collection edges the settled viewport currently reaches,
and `onLoadedEdgeReached` reports only transitions into those states. Load-line observation is
independent of content insets and engine limits. The top line is `loadedEdgeMargin`; the bottom line
is `logicalSize.height - loadedEdgeMargin`. Positive margins load later, negative margins load
earlier, and overscroll is excluded by using the settled clamped engine offset. The list recomputes
the deduplicated state after construction, mutation settlement, user-scroll rebalancing, and margin
changes. This is an observation seam only: pagination, batching, and item creation remain
caller-owned.

**Host-facing embedding seam** (used by the TelegramUI `ChatHistoryListViewBackend` adapter):
`onVisibleWindowChanged` fires after each user-scroll rebalance; `onLoadedEdgeReached` reports
edge transitions (above); `willBeginDragging` fires on interactive drag start (forwarded from
`ScrollEngine.onWillBeginDragging`; the analogue of `ListViewImpl.beganInteractiveDragging`).
`loadedItemViews` is a **non-copying** `Sequence` over the settled window's item views in ascending
index order — it walks `activeWindow.items` in place (a COW snapshot; no array built, no element
copied, safe to mutate the list mid-iteration), the iterator-based analogue of
`ListViewImpl.forEachItemNode`. It visits only loaded rows, never off-screen entries or exit-overlay
ghosts. `loadedItemView(at:)` is its index-keyed sibling, resolving one collection index to its loaded
view (nil outside the settled window) — this view owns `activeWindow` and is therefore the authority on
the index ↔ view mapping, so hosts must use it instead of walking `loadedItemViews` to a position
inferred from `loadedIndexRange`. `loadedItemEntries` is the same in-place walk as `loadedItemViews`
but yields `(index, view)` pairs, for hosts that need each row's collection index during a full-window
pass (computing a visible range, say) without counting iterations — array position equals collection
index only while the window still starts at 0.

📖 **Read before changing:** `CoreVirtualListView.Window`, `buildWindow`, `render`,
`rebalanceActiveWindow`, `loadedEdgeRange`, and design
`docs/plans/2026-03-21-virtual-list-rewrite-design.md`, plus
`docs/superpowers/specs/2026-07-22-projected-anchor-inset-transition-design.md` for inset transitions.

### `applyChanges`: the sole mutation entry point

```swift
func applyChanges(items: [CoreListItem]? = nil,
                  newSize: CGSize? = nil,
                  scrollTo: (index: Int, pointOffset: CGFloat)? = nil,
                  animationDuration: TimeInterval)
```

All mutations flow through one transaction. A pass:

1. serializes re-entrant requests and applies `newSize` to `logicalSize`;
2. validates unique identities and computes survivors, inserts, deletes, and LIS-derived moves;
3. captures one transaction clock and the old settled live state, including analytic position, height,
   and opacity values;
4. reconciles changed content in reused views and remeasures dirty rows at the current width;
5. resolves the anchor and builds the new settled window, reusing survivor and move views;
6. transfers loaded departures to the exit overlay, then renders final live frames and scroll edges
   with implicit layer actions disabled;
7. binds newly loaded layers, independently transitions every loaded survivor whose settled position or
   height changed, and starts opacity-only fades for genuine inserts.

Insertions, removals, replacements, moves, and mixed passes compose from those independent rules.
The old container-wide animation path is gone. Every loaded survivor is evaluated on every pass. Final
settled frames are written immediately; each changed settled position and height then transitions
independently from its analytic current presentation on the pass duration and curve, even if that property
had no prior track. An unchanged endpoint remains an exact no-op.

📖 **Read before changing:** `CoreVirtualListView.applyChanges`, `ItemDiff`, `settledState`,
`makeExit`, `attachLive`, and `docs/plans/2026-07-20-list-animation-model-design.md`.

### Granular animation contract

`ListAnimationModel` is the sole presentation authority. It is UIKit-free and stores at most one
analytic track per stable `ListAnimationOwner` and `ListAnimatedProperty`. Live owners use
`CoreListItem.identity`; every departure receives a fresh exit-owner serial so a fading old
incarnation and a newly inserted live incarnation with the same identity can coexist. The current
properties are additive horizontal/vertical position offsets, absolute visual width/height, opacity,
and one shared additive viewport offset.

Each `ListAnimationTrack` has a monotonically increasing generation, `from`, `to`, immutable start
time, duration, and a track-owned curve (`smoothstep` or `easeOut`). The transaction rules are strict:

- unchanged settled position (within `1e-6pt`) is a true no-op: the exact track, generation, phase,
  curve, deadline, and installed CA animation survive untouched;
- unchanged settled x/width/height (within `1e-6pt`) is the same exact no-op for each independent track;
- a changed animated property replaces only that owner/property from its analytic current value,
  guaranteeing C0 continuity; velocity continuity is intentionally not promised;
- a changed zero-duration property settles immediately, while an unrelated zero-duration pass
  cannot erase an unchanged track;
- every loaded survivor whose settled position changes starts or replaces its position track from analytic
  current visible Y, whether or not it already had a position track;
- every loaded survivor whose settled height changes starts or replaces an independent height track from
  analytic current visual height, compiled as absolute `bounds.size.height`;
- inserted rows are installed at their complete final x/y/width/height geometry, seed that complete geometry
  in the analytic model, and fade from 0 to 1; they receive no position or extent animation;
- structural animation membership uses the union of old rendered survivors and the new settled
  viewport-plus-preload window. A survivor present at only one endpoint keeps or receives one live view and
  inherits only the nearest unmoved shared survivor's settled displacement; its own analytic correction
  remains independent. Old-only survivors remain under the scrolling crossing overlay until exact
  position-generation completion, while new-only survivors animate in the live container. No item outside
  that union is loaded or measured, and `activeWindow` remains the pure settled window;
- when no eligible shared survivor witnesses a missing crossing endpoint, contiguous unmoved survivors in
  the same structural region use one boundary translation. The anchorward run edge clears both the raw
  retention threshold and the settled loaded-window extent, and all known member spacing is preserved;
  ownership, tracks, and completion remain per identity. This fallback never expands the settled window or
  measures unloaded geometry;
- moved identities retain their view and identity and animate each changed geometry property independently;
- resize, inset changes, content reconciliation, and self-update write final settled frames immediately,
  then animate each changed survivor x/y/width/height independently on the pass duration and curve.

Position tracks are additive corrections relative to the current settled endpoint. At a pass
boundary the list samples `oldSettled + oldOffset`, renders the new settled position, and replaces
the changed track with `(currentVisible - newSettled) -> 0`. Because the correction is parent-space
independent, scrolling and coordinate rebasing do not look like target changes.

Width and height tracks are absolute visual extents. At a pass boundary the list samples the analytic
current extent, writes the new settled bounds, and replaces only a changed extent track. Horizontal and
vertical position/extents compose independently, and writing any same settled endpoint is a strict no-op.

`ListViewportGeometry` contains only the list's received size and full `UIEdgeInsets`; the list never
derives parent-space position. Insets define settled content x/width and vertical edges but remain visible,
interactive list space. Size/inset passes resolve one final engine offset and replace one shared additive
viewport track from its analytic current correction whenever the projected, edge-clipped window changes
the viewport target; an unchanged target is an exact no-op. Overlapping geometry, scroll-to, live rows,
crossing carries, carousel carries, and ghost members all use property-level retargeting from the same
transaction clock. Load membership remains the outer viewport plus preload margin, and unavailable
endpoints are never loaded or measured merely to animate them.

`ListAnimationController` owns model-to-layer bindings, applies Slow Animations scaling exactly once,
and passes one captured local clock to every mutation in a list pass. Stable property keys replace
only the affected CA animation. Completions capture the track generation and binding; stale
completions cannot clear a replacement, remove a rebound layer, or tear down a reinserted live view.
Before a layer binds to another owner, all controller-owned keys are removed. If an off-screen owner
becomes live again, `rebind` first reconciles retained height state with the freshly measured/rendered
layer height. An unchanged height target within `1e-6pt` keeps the exact original height track, phase,
deadline, generation, and CA metadata. A changed target settles only height to the fresh geometry and
invalidates only its stale height track/completion; this also covers retained height state without an
active height track. Every remaining track is emitted using its original phase and deadline. An active
unbound owner retains its analytic state through that deadline; the controller schedules a generation-
and binding-safe reap at the analytic completion time, without a display link. Rebinding or replacing
the generation makes the scheduled callback inert.

One property-granular exception applies while an owner is unbound: if a structural pass changes the
owner's predecessor identity set, its position correction safely settles to zero before render/rebind
because unloaded geometry cannot supply an exact retarget endpoint. This includes an owner that enters
the new loaded window in the same pass. Its height and opacity tracks are untouched. An off-screen owner whose
predecessors are unchanged keeps the exact original position track, phase, and deadline.

`CoreAnimationCompiler` is an output renderer, never an authority. It samples the model curve into
one explicitly timed `CAKeyframeAnimation`: position is additive on `position.x`/`position.y`, width/height
are absolute on `bounds.size.width`/`bounds.size.height`, opacity is absolute, and all use the track's own
curve, start time, and already-scaled duration.
Interruption never reads layer presentation state back into the model. Production uses no display-link list
renderer and no `UIViewPropertyAnimator`.

Loaded genuine departures are grouped by contiguous old-collection runs into rigid ghost blocks under the
non-interactive, footprint-free `exitOverlay`. Each block has one stable wrapper and one additive position
owner; member views keep fixed sampled local frames and independent fresh exit owners that fade opacity only,
so a reinserted live identity can coexist safely with its departure. Each block-ledger boundary link stores
both the ghost's attached local edge and a live/ghost `minY` or `maxY` witness edge, then resolves
`root = witnessBoundary - localEdge`. Geometry/order passes retain a usable link or migrate both sides toward
that pass's independently resolved anchor, including ghost-to-ghost handoff when a live carrier departs. A
ghost above the pass anchor therefore rides its `maxY` on the following boundary's `minY`, while a genuine
same-pass or delayed replacement carries the ghost at matching `minY` edges.

Mutation anchors use the engine offset clamped to the currently known loaded edges. Rubber-band displacement
is presentation-only: it is restored to the displayed engine offset after settled geometry is resolved and
must not influence anchor identity, direction, or edge pinning. At the settled loaded top edge, an ordinary
mutation pins new collection index 0 to point offset 0.

A deletion-only block keeps its creation boundary open while a survivor provisionally carries that edge. A
later genuine insertion landing exactly at the block root becomes the spatial carrier and seals the boundary,
making delayed replacement match same-pass replacement. A same-pass inserted occupant seals immediately, so
unrelated later insertions cannot steal its ghost.

Pure user and programmatic scrolling are exact witness no-ops: the scrolling hierarchy or viewport track
moves ghost wrappers without replacing their block-position tracks. Coordinate rebases and overlay remaps
instead shift every wrapper and its ledger `settledRootY` by the same exact delta while preserving witness,
generation, phase, curve, and deadline. Member opacity completion does not wait for block motion. An empty
referenced block persists as a nonvisual spatial node until its dependents finish, after which cascading
collection removes its graph edge, wrapper, position owner, and ledger entry.

Production keyframes for position call `preferHighRefreshRate()`. `Info.plist` must retain
`CADisableMinimumFrameDurationOnPhone = true`; without it, ProMotion devices cap app-driven refresh.

### Programmatic viewport scrolling

Programmatic `scrollTo` writes the settled engine endpoint immediately and emits one model-owned additive
`viewportOffset` bounds track on `contentHost.layer`. The old and destination loaded identity sets select
overlap geometry for shared rows or a one-window carousel for disjoint windows; distant jumps instantiate
neither intermediate rows nor intermediate windows. Gestures change the settled logical engine state beneath
the unchanged viewport correction. A later target replaces the viewport property from its analytic current
value for C0 continuity. A pass with neither `scrollTo` nor a geometry-induced target change is an exact
viewport no-op that preserves its generation, CA key, phase, curve, deadline, and transient carries.
An explicit `scrollTo.pointOffset` is relative to the received top inset: its projected screen target is
`viewportInsets.top + pointOffset`. This conversion happens before projected window construction, so same-pass
inset changes, loaded membership, edge clipping, crossing carries, and carousel placement all use one final
coordinate system.
Every changed positive-duration viewport replacement first remaps all detached overlay content from the old
rendered viewport coordinate base into the replacement base. The exact mapping subtracts the engine shift
once and applies equally to carousel carries, crossing survivors, and ghost blocks; no viewport-producing
branch may replace the track without this boundary remap.

Carousel adjacency is computed from normalized loaded-strip tops
(`containerOriginY - renderedViewport`), never by subtracting `Window.minY` again after render
normalization. Forward travel places the incoming loaded top at the outgoing loaded bottom; backward
travel places the incoming loaded bottom at the outgoing loaded top.

For a non-overlapping carousel, the additive viewport track is the exclusive vertical-motion owner for
destination-only survivors. A simultaneous geometry or structural membership transition must not route those
rows through incoming crossing-survivor position inference; the destination remains one rigid final-layout
strip. Genuine insert opacity and independent horizontal/extent properties still compose normally.

📖 **Read before changing:** `ListAnimationModel.swift`, `ListAnimationController.swift`,
`CoreAnimationCompiler.swift`, the animation transaction in `CoreVirtualListView.swift`, and
designs `docs/plans/2026-07-20-list-animation-model-design.md` and
`docs/plans/2026-07-20-additive-viewport-scroll-design.md`, plus
`docs/superpowers/specs/2026-07-21-ghost-block-boundary-witness-design.md` for departed-block motion and
`docs/superpowers/specs/2026-07-22-projected-anchor-inset-transition-design.md` for geometry rebases.

### Self-update and view reuse

A view's `onContentDidChange` marks its index dirty and schedules one coalesced flush through the
injected `Scheduler`. The flush re-enters `applyChanges` and remeasures exactly the dirty rows.
The flush writes final settled geometry immediately even when the callback requests animation, then each
changed survivor position and height property transitions independently on that flush duration. Unchanged
identity/property tracks remain intact.

`buildWindow` reuses a view from the old window for survivors and move endpoints. A reused view is
reconfigured with `apply(to:)` only when `isEqual` is false, before measurement. Rows loaded
by scrolling are attached to their stable owner; known owners rebind after height reconciliation,
preserving eligible position/opacity tracks and unchanged-target height tracks without restarting them,
while new owners seed settled state.

## Item protocol

```swift
protocol CoreListItem: AnyObject {
    var identity: AnyHashable { get }
    func view() -> UIView & CoreListItemView
    func isEqual(to other: CoreListItem) -> Bool
    func apply(to view: UIView & CoreListItemView)
}

protocol CoreListItemView: AnyObject {
    func update(width: CGFloat) -> CGFloat
    var onContentDidChange: ((_ animated: Bool) -> Void)? { get set }
}
```

`identity` is the stable animation key AND the diff key: it drives survive/insert/delete/move matching
and the uniqueness invariant. `isEqual(to:)` is **value/content equality** for an already-identity-matched
survivor — the engine reconfigures a survivor (`apply(to:)` + remeasure) iff `!isEqual`. It has **no
default** (equality-by-identity is almost never correct in production, so every item states its content
equality explicitly); an identity-only item still opts in by writing `isEqual` to compare just its
identity field(s). `apply(to:)` updates a reused view in place (default: no-op). `update(width:)` lays
out the row and returns its measured height.

📖 **Read before changing:** `DemoRow.swift` and
`docs/plans/2026-05-31-item-content-reconcile-design.md`.

## Demo app

`SceneDelegate` installs two production demo tabs: **Virtual List** (`ViewController`) and
**Physics Scroll** (`PhysicsScrollDemoViewController`). The Virtual List tab retains manual controls
for inserts/deletes, edge deletes, replacement and delayed replacement, reorder and delayed
reorder/size, immediate growth, mixed-operation chaos, top/jump navigation, a 300pt animated top-inset
toggle, and all three scroll engines. `ViewController` lays the list out at the controller's full bounds and
submits only size and insets as list-owned viewport geometry. It expresses overlaid controls and safe-area
chrome through a layout-derived chrome inset, then component-wise adds independent animated test deltas. Demo
controls mutate only those deltas, so removing a test inset restores the current chrome baseline exactly.

Four deterministic mixed-action controls submit vertical inset plus Jump40, horizontal inset plus
replacement, first-item size plus move, and reversible horizontal inset plus first-item size plus five-row
changes in one `applyChanges` pass. Each uses 0.5-second ease-out timing and keeps the inset guide on the
same transition.

An opt-in `Auto Load` toggle demonstrates caller-owned bidirectional loading. The controller
coalesces newly reached top/bottom edges on the next main-queue turn, deduplicates them across
separate queued and in-flight sets, and returns each accepted request after a 0.2-second response
delay. A response prepends five fresh rows for the top edge, appends five for the bottom edge, and
applies simultaneous edges in one zero-duration `.preserveVisibleContent` pass. An accepted response
still applies if scrolling leaves its edge while it is in flight. After each response, the controller
rechecks the settled reached-edge set; every continuation is a fresh request with its own 0.2-second
delay. Disabling the mode advances a generation and suppresses queued or delayed responses, while
scroll-engine replacement preserves enabled state and an existing in-flight request without
duplication. The mode defaults off. `CoreVirtualListView` remains a policy-free edge observer.

`PhysicsScrollView` is the standalone custom-scroll consumer of `ScrollPhysics`; it does not use
`UIScrollView`. Its gesture path supports touch and continuous trackpad input, and deceleration is
runtime-selectable between stepped and keyframe modes.

## Scroll physics replica

`CoreListDemo/ScrollPhysics/` is a standalone, UIKit-free value-model replica derived from UIKitCore
on iOS 26.2. Core files implement per-axis drag, release, deceleration, rubber banding, projection,
and offset math. `PanRecognizer.swift` handles input. `Trajectory.swift` and
`Trajectory+Keyframe.swift` bake rate-independent linear keyframe playback and seamless splicing.
Recording support and tests live under the corresponding production/test folders.

📖 **Read before changing any physics constant or formula:**
`docs/plans/2026-05-22-uikit-scrollview-physics-analysis.md` and
`docs/plans/2026-05-23-pan-recognizer-reproduction-design.md`. The formulas come from assembly;
decompiler SIMD/FP pseudocode is not authoritative.

## Tests

The deterministic harness in `CoreListDemoTests/TestSupport/` injects `SyntheticClock`,
`ListAnimationController` with CA emission optionally disabled, `TestScheduler`, and UIKit- or
physics-backed engines. `VirtualListDriver`/`VirtualListFixture` and
`PhysicsListDriver`/`PhysicsListFixture` expose settled and analytic state without making Core
Animation an authority.

- `ListAnimationModelTests` specify strict unchanged no-op, C0 position/extent replacement and track curves,
  generations, immediate settlement, and off-screen state.
- `CoreAnimationCompilerParityTests` compare model samples with compiled keyframes, including an
  actual paused layer check.
- `CoreVirtualListAnimationTests` cover insert, remove, replacement, move, mixed passes, view reuse,
  overlay teardown, unchanged-track preservation, full viewport-geometry retargeting, and scrolling while active.
- `MixedPassStressTests` run a bounded fixed-seed grammar over structural, row-geometry,
  viewport-geometry, and programmatic-scroll changes. They verify transaction-boundary C0
  continuity, exact unchanged-track preservation, installed CA/model metadata parity for observed
  owners, settled window integrity, and carry/ghost teardown. Failures report the seed, pass, and
  full action prefix; minimize any production failure into the owning focused suite before fixing it.
- Core-window, content, engine, and physics suites retain non-animation behavior coverage.

## Non-obvious gotchas

- Core Animation layer properties are settled endpoints during animation; analytic queries come
  from `ListAnimationModel`. Only compiler parity tests inspect actual layer presentation output.
- One pass must capture one controller-local time from the bound layer's
  `convertTime(CACurrentMediaTime(), from: nil)`. Layer-local time, not raw media time, preserves
  analytic/CA agreement when Simulator Slow Animations changes layer speed. Sampling once per row
  creates clock skew and breaks cross-property transaction guarantees.
- Every emitted CA keyframe uses the analytic track's explicit `beginTime`; allowing Core Animation
  to choose commit time introduces phase drift at retarget boundaries.
- Duration scaling happens only in `ListAnimationController`; the compiler receives the final
  duration and must not scale again.
- Same-target position and extent writes must return before touching the model, CA key, completion ledger,
  or layer.
- A changed position starts from `oldSettled + analyticOffset`, not the model layer and not viewport
  coordinates; this is what preserves continuity through scroll/container rebases.
- Every loaded survivor with a changed settled position or height must transition from its analytic current
  presentation, even without a prior track; restricting geometry composition to active tracks creates a
  delayed resize/content/self-update snap.
- Position and height tracks compose independently. Final settled frames are model-layer endpoints, while
  the additive `position.y` and absolute `bounds.size.height` animations preserve the boundary presentation.
- Rebinding position or opacity uses the original start/deadline. Height does too when its retained target
  matches the freshly measured settled height within epsilon; a changed off-screen height instead settles
  to fresh geometry and invalidates only stale height state. Restarting a preserved curve when a row scrolls
  back on-screen violates the stable-owner contract.
- Exit teardown is owner-, generation-, binding-, and view-specific. Exit position and height are frozen at
  sampled member-local geometry; identity alone is insufficient because reinsertion may coexist with a
  fading departure. Contiguous members move only through their stable block wrapper, whose additive position
  owner rides a live/ghost boundary witness.
- Ghost witnesses migrate toward the current pass anchor, not a remembered direction. Pure scroll must not
  reconsider witnesses or replace block tracks; coordinate-only remaps must shift wrapper model positions and
  ledger roots by the same exact delta. Empty referenced blocks remain spatial nodes until dependents finish.
- A crossing carry released by the shared viewport track must migrate from the old viewport generation to
  every replacement generation. Replacing the viewport property invalidates the old completion; retaining
  that stale release generation leaks the carry after all analytic tracks settle. An immediate viewport
  replacement releases those carries immediately.
- Resize/content/self-update writes final settled geometry immediately, then changed survivor position and
  height properties transition independently; unrelated active position, height, or opacity tracks remain
  exact no-ops.
- `UIScrollView` clamps `bounds.origin.y` assignments; tests must establish content limits before
  writing non-zero offsets.
- Trackpad indirect scroll ignores `pan.setTranslation(.zero)`; keep the explicit translation
  baseline in the physics engine.
- **`PhysicsScrollEngine`'s `shouldBeRequiredToFailBy` must stay gated on content motion**
  (`flight != nil || core.isDecelerating`). Declaring it unconditionally breaks every
  press-and-hold recognizer hosted in the list, because such a recognizer must recognize *while the
  finger is still down* while the pan only fails on lift — UIKit can never release the dependency and
  silently tears the recognizer down (`Gestures` → `_resetGestureRecognizer`): no activation, no
  cancellation callback, just a half-run press animation springing back. Taps are immune (they
  recognize on lift, the same instant the pan fails), so the demo's tap-only rows cannot catch this;
  it surfaced as chat bubbles' `ContextGesture` long-press-for-context-menu dying under the CoreList
  chat backend. Absorbing the stopping tap is the rule's only purpose and can only arise while
  content moves, so the gate costs nothing.

## Project conventions

- Work on `main` directly. The user explicitly opted out of worktrees and feature branches here.
- Planned task commits are authorized. Never amend or push unless explicitly asked.
- Stage only task-named files with explicit paths; never use `git add .` or `git add -A` because the
  tree may contain unrelated WIP.
- Use only the dedicated **iPhone 17 Pro K2** simulator. If it is unavailable, stop and ask.
- Every `xcodebuild ... test` command must include `-parallel-testing-enabled NO`.

## Documentation authority

`CLAUDE.md` is the repository map and concise current contract. Read the source files and retained
designs named by each subsystem before making a non-trivial change.

`docs/plans/` contains current foundational designs and reverse-engineering analyses.
`docs/superpowers/specs/` contains current extensions to those designs.
`docs/plans/CHANGELOG.md` is a compact digest of landed work in the current granular-animation era.
Completed execution plans, handoffs, result logs, proofs, and superseded architectures are retained
only in Git history.
