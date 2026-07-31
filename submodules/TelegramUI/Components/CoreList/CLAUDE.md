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
  -parallel-testing-enabled NO -collect-test-diagnostics never test

# Run one test class
xcodebuild -project CoreListDemo.xcodeproj -scheme CoreListDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro K2' \
  -parallel-testing-enabled NO -collect-test-diagnostics never test \
  -only-testing:CoreListDemoTests/CoreVirtualListAnimationTests
```

Every test command must use all three mandatory options:

- `-destination 'platform=iOS Simulator,name=iPhone 17 Pro K2'` — use only the dedicated K2
  simulator. A generic similarly named simulator is a different device and may be in use.
- `-parallel-testing-enabled NO` — keep one boot target and deterministic execution.
- `-collect-test-diagnostics never` — **without this, any run with a failing test hangs forever.**
  xcodebuild defaults to `on-failure`, and on failure it blocks in
  `XCTHRunDestinationAllocator.collectSimulatorDiagnostics` gathering a sysdiagnose; with several
  simulators booted it effectively never returns. Measured on the same deliberately-failing test:
  5.26s with the flag, still blocked after 240s without it (and only ~1.7s of CPU, so it is waiting,
  not working). A PASSING run exits in ~5s either way, which is what makes this so confusing — the
  hang appears only when you have something to fix.

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
(`onScroll` per-frame, plus `onWillBeginDragging`/`onDidEndDragging` when the pan reaches
`.began` and `.ended`/`.cancelled` — UIKit via `scrollViewWillBeginDragging` /
`scrollViewDidEndDragging`, physics via `handlePan`), `contentHost`, and
`containerOrigin(windowHeight:topLoaded:bottomLoaded:)`. The drag pair brackets the **finger-down
interval only**: neither fires for momentum, bounce or programmatic writes, so a host can maintain a
`ListViewImpl.isTracking` equivalent from them.

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
  motion remains. Only an edge that can REACH the flight's remaining path counts as a real change:
  the deceleration integrator is edge-independent until the path crosses an edge, so the declared
  edges plus the baked offset band identify the motion, and a change outside that band leaves the
  flight — and the animation the render server is already playing, with its completion — untouched.

The UIKit-backed suite remains the core-list additivity oracle. The physics-backed list path is
covered by `PhysicsListIntegrationTests` plus the physics and keyframe unit suites. The Virtual List
demo defaults to `PhysicsScrollEngine` with keyframe deceleration; UIKit and stepped physics remain
selectable from the engine control.

`ScrollEngine.offset` is **the physics scroll position, advanced once per frame** by whichever driver is
running — never a sample of a running animation. See the gotcha below and
`docs/superpowers/specs/2026-07-26-clock-free-mutation-pass-design.md`.

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
distance from the inset edge — unless the caller passes `compensatesInsetChange: false`, which drops
**only** that addend so content holds its screen position while the inset edge moves under it (see
`applyChanges` below). Window construction traverses toward lower indices and clips at the loaded
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
edge transitions (above); `willBeginDragging` / `didEndDragging` fire on interactive drag start and end
(forwarded from `ScrollEngine.onWillBeginDragging`/`onDidEndDragging`; the analogues of
`ListViewImpl.beganInteractiveDragging`/`endedInteractiveDragging`, and together the finger-down
interval a host needs to reproduce `ListViewImpl.isTracking`).
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

`visibleRectUpdated(_:)` on `CoreListItemView` pushes each loaded row the part of itself inside the
viewport, in the row's own coordinate space, or `nil` when it is not visible. It fires at the end of
`render()` and at the end of `handleUserScroll` — the two points the window is maintained — using the
projection `rebalanceActiveWindow` uses (settled frames at the live engine offset), against the FULL
viewport rect: inset space is visible, interactive list space. During a programmatic animated viewport
move it therefore reports the destination, which is the window that pass already loaded; there is no
display link here to sample an in-flight animation. A row leaving the live window is notified `nil`
by one uniform rule — the notifier holds weak references to the views it last reported visible — which
covers rebalance unloads, ghost-block members and the transient exit-overlay carry alike. It has a
default no-op, so item views opt in. `CoreListNodeHostView` (TelegramUI) maps it onto
`ListViewItemNode.visibility`.

📖 **Read before changing:** `CoreVirtualListView.Window`, `buildWindow`, `render`,
`rebalanceActiveWindow`, `loadedEdgeRange`, and design
`docs/plans/2026-03-21-virtual-list-rewrite-design.md`, plus
`docs/superpowers/specs/2026-07-22-projected-anchor-inset-transition-design.md` for inset transitions.

### `applyChanges`: the sole mutation entry point

```swift
func applyChanges(items: [CoreListItem]? = nil,
                  newSize: CGSize? = nil,
                  newInsets: UIEdgeInsets? = nil,
                  scrollTo: CoreListScrollTarget? = nil,
                  additionalScrollDistance: CGFloat = 0.0,
                  anchorMode: CoreListAnchorMode = .automatic,
                  compensatesInsetChange: Bool = true,
                  transition: CoreListTransition)
```

`compensatesInsetChange: false` drops the `newTopInset - oldTopInset` anchor projection and nothing
else — the new insets still drive content x/width, the viewport band, the load band and the
loaded-top pin, so at the loaded top index 0 still rides the inset edge. It is the analogue of
`ListViewImpl` zeroing `offsetFix` while tracking (`Display/Source/ListView.swift:3276`) — which
likewise still assigns `self.insets` and still runs `snapToBounds`. It exists for an inset change
produced by the user's own in-progress drag, where compensating on top of the scroll doubles the
finger's travel; deciding that a pass is such a case is caller policy (`CoreListChatHistoryBackend`
does, from `willBeginDragging`/`didEndDragging`). Do NOT emulate it with
`additionalScrollDistance: -topInsetDelta`: a non-zero distance halts momentum and opts the pass out
of `pinsLoadedTop`, so the loaded top stops tracking the inset edge.

`CoreListScrollTarget` carries the target index and a **resolver** rather than a fixed offset:
`resolve(measuredHeight, view)` returns the row's settled Y as an offset from the top inset edge
(projected screen target = `viewportInsets.top + returned value`). It is called exactly once, inside
`buildWindow`, immediately after the anchor row is measured — the only point at which a
height-dependent placement (bottom-align, center, make-visible) can be computed for a target outside
the loaded window, which is what a host's far jump always is. The closure must be pure with respect
to the list: it may read geometry, never mutate the collection or re-enter `applyChanges`.
`CoreListScrollTarget(index:pointOffset:)` is the constant-resolver shorthand and is exactly the old
tuple. This keeps every host-specific placement semantic in the host —
`CoreListChatHistoryBackend` resolves `ListViewScrollPosition` there, including
`scrollPositioningInsets` and quote rects, and CoreList learns none of it.

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

`ListAnimationModel` is the sole presentation authority. It depends only on Foundation, CoreGraphics
and QuartzCore — the last solely to evaluate the two system springs through the same
`CASpringAnimation` CA renders — and stores at most one analytic track per stable
`ListAnimationOwner` and `ListAnimatedProperty`. Live owners use
`CoreListItem.identity`; every departure receives a fresh exit-owner serial so a fading old
incarnation and a newly inserted live incarnation with the same identity can coexist. The current
properties are additive horizontal/vertical position offsets, absolute visual width/height, opacity,
and one shared additive viewport offset.

Each `ListAnimationTrack` has a monotonically increasing generation, `from`, `to`, immutable start
time, duration, and a track-owned `CoreListTransition.Animation.Curve`. The transaction rules are
strict:

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
- a **full-replace carousel** — an explicit `scrollTo` whose old and new loaded windows share no
  identity, AND whose **destination window** is entirely new content — fades nothing at either end.
  Incoming rows install at full geometry and full opacity, and departing rows ride their ghost block
  at the opacity they had. It is one rigid travel between two strips, already owned by the shared
  additive viewport track; the fades only appear because a host expressing a jump as delete-all +
  insert-all makes every row look genuinely new or genuinely departed. `ListViewImpl` slides its
  `temporaryPreviousNodes` out at full opacity too. **The destination window is the right unit, and
  this predicate has been wrong in BOTH directions:** plain loaded-window disjointness fades a
  genuinely new row inserted among survivors where you are travelling to, while whole-*collection*
  disjointness never fires for a real host — chat's non-message rows carry constant identities (the
  unread separator is `4 << 40`) that survive any replace, so one always lives somewhere. What
  decides it is whether anything in the destination was already there. A non-fading exit still
  installs an opacity track with the pass duration — `replace` does not early-out on an equal
  endpoint — so the teardown deadline, generation, binding and completion ledger are unchanged;
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

`CoreListTransition` (`CoreListDemo/Transition/`) is the module's animation descriptor: a
self-contained copy of ComponentFlow's `ComponentTransition` value model, vendored because CoreList
has no Bazel `deps` and the demo builds standalone. The case shape is identical, so
`ComponentTransition.init(_ CoreListTransition)` — in
`TelegramUI/Sources/CoreListChatHistoryBackend.swift`, the only consumer — is a case-for-case map.
It deliberately does NOT round-trip a zero duration: CoreList means "immediate" by it, so the
conversion yields `.immediate` rather than a zero-length animation.
`applyChanges(…, transition:)` is the only mutation entry point; the parallel duration-only overloads
are gone. Production uses `.easeInOut` throughout, and the tests keep `.linear` (via a test-only
`CoreListTransition.linear(duration:)`) as the contrast curve their curve-identity assertions need.
`.spring` samples the app's **adjusted** spring bezier `(0.380, 0.700, 0.125, 1.000)` — what
`CAAnimationUtils.swift:119` emits for `kCAMediaTimingFunctionSpring` at any duration other than the
two it special-cases with real `CASpringAnimation`s (0.5, and 0.3832 on iOS 26); at exactly those
durations CoreList approximates. Note this is deliberately NOT what ComponentFlow's own `solve(at:)`
returns (`listViewAnimationCurveSystem`, which samples the 0.5s spring), so ComponentFlow's analytic
and emitted springs agree only at duration 0.5 — CoreList is analytic-first, so it follows the
emitted curve. `.bounce` is not a unit curve (ComponentFlow's own `solve` asserts on it) and degrades
to `.spring`.

CoreList uses **no `CATransaction` at all**. Every layer it writes is UIView-backed — it creates no
standalone `CALayer` — and a UIView's layer returns a null action by default outside an animation
block, so there is no implicit animation to suppress. (`SimpleLayer`/`nullAction` exists for
standalone layers, which CoreList has none of.) Animation completions attach to the animation itself
through `CAAnimation.setCoreListCompletion`, a copy of Display's `CALayerAnimationDelegate`, rather
than to a transaction. See
`docs/superpowers/specs/2026-07-27-corelist-transition-design.md`.

`CoreAnimationCompiler` is an output renderer, never an authority. It builds through the shared
`makeCoreListAnimation` factory — a copy of `CAAnimationUtils.makeAnimation`'s branch tree — so what
CoreList emits is what every other Telegram surface emits: a `CABasicAnimation` with a
`CAMediaTimingFunction` for bezier curves, and a real `CASpringAnimation` for the two system-spring
durations (0.5, and 0.3832 on iOS 26). It then adds the model-path properties the factory does not
set: `beginTime = track.startTime`, `fillMode = .both`, `isRemovedOnCompletion = false`, and the
generation metadata. Position is additive on `position.x`/`position.y`, width/height absolute on
`bounds.size.width`/`bounds.size.height`, opacity absolute, all on the track's own curve, start time,
and already-scaled duration. **No `CAKeyframeAnimation` is emitted outside the physics deceleration
flights** (`KeyframeFlight`, `Trajectory+Keyframe`, the two physics engines), which play baked
trajectories rather than curves.
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
`additionalScrollDistance` is a caller-chosen displacement of that same viewport, in points, positive moving
content DOWN — the analogue of `ListViewImpl.transaction`'s parameter of the same name, folded into the same
addend as the inset compensation (`Display/Source/ListView.swift:3275`) so one pass can re-inset and scroll by
a delta as a single movement. It displaces the resolved anchor before window construction rather than writing
an offset afterwards, so it composes with edge clipping, loaded membership, crossing carries, and an explicit
`scrollTo` (which positions content first, the displacement then moving it). A non-zero value halts momentum
for the same reason `scrollTo` does, except under `.preserveVisibleContent` — ListViewImpl's stationary-item
branch does not halt either. It also opts the pass out of the loaded-top pin, which would otherwise swallow the
displacement whole; ListViewImpl's equivalent (`snapToBounds`) only closes a gap above the top item, so a
downward displacement at the top edge is clipped by both and an upward one is honoured by both.

Every changed positive-duration viewport replacement first remaps all detached overlay content from the old
rendered viewport coordinate base into the replacement base. The exact mapping subtracts the engine shift
once and applies equally to carousel carries, crossing survivors, and ghost blocks; no viewport-producing
branch may replace the track without this boundary remap.

Carousel travel direction comes from comparing the current anchor's position in the new order against
the target index. When no old identity survives into the new collection — a full replace, which is
how a host expresses a jump to a disjoint region — there is no witness to compare, and
`CoreListScrollTarget.direction` supplies the answer; `nil` keeps the historical `.forward`. A
present witness always wins, mirroring `ListViewImpl`, which computes the offset geometrically from a
surviving anchor node and consults its own `directionHint` only when that yields nothing
(`Display/Source/ListView.swift:3590`).

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
    func apply(to view: UIView & CoreListItemView, transition: CoreListTransition)
}

protocol CoreListItemView: AnyObject {
    func update(width: CGFloat, transition: CoreListTransition) -> CGFloat
    var onContentDidChange: ((_ animated: Bool) -> Void)? { get set }
}
```

`identity` is the stable animation key AND the diff key: it drives survive/insert/delete/move matching
and the uniqueness invariant. `isEqual(to:)` is **value/content equality** for an already-identity-matched
survivor — the engine reconfigures a survivor (`apply(to:)` + remeasure) iff `!isEqual`. It has **no
default** (equality-by-identity is almost never correct in production, so every item states its content
equality explicitly); an identity-only item still opts in by writing `isEqual` to compare just its
identity field(s). `apply(to:transition:)` updates a reused view in place (default: no-op).
`update(width:transition:)` lays out the row and returns its measured height.

Both receive the enclosing pass's `CoreListTransition`, so a row can animate its own internals on the
same curve and duration as its outer geometry. It is non-immediate **only** when that row's content
changed in the pass — a reconciled survivor, or an animated self-update flush. Fresh views, scroll-in
loads, unchanged survivors, and off-screen remeasures receive `.immediate`: there is nothing to
animate from, or the change is purely outer geometry, which `ListAnimationModel` owns. `update` must
return the settled height either way, and may be called twice in one pass (dirty remeasure, then
window construction) — the transition's setters early-out on an equal target, so the second call is a
no-op. The mechanism is a per-pass `reconciledIdentities` set paired with `currentPassTransition`;
scroll-driven rebalancing leaves the set empty, which is what makes its rows `.immediate` for free.

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
- **`ScrollEngine.offset` is per-frame stable; never sample a running animation through it, and never read
  `contentHost.bounds.origin.y` as a position.** That layer value is the additive BASE of the emitted keyframe
  animation, parked at the trajectory's `finalOffset` for the whole flight — mid-flight it holds the flight's
  *destination*, hundreds to thousands of points from what is on screen. `PhysicsScrollCore.offset` returns
  `physics.y.offset` instead, which the active driver advances exactly once per frame (`.stepped` via `step`,
  `.keyframe` via `KeyframeFlight.beginTick`'s reseed). This is load-bearing because `CoreVirtualListView`
  reads the offset **three times** in one mutation pass (`:539`, `:849`, and `:1347` via `setBoundsOriginY`)
  and treats the difference as the shift the pass itself applied: any per-read drift becomes geometry error.
  When it sampled the flight, every mid-flight `applyChanges` re-placed the content where it was when the pass
  *started* — a backward lurch of `velocity × pass duration`, measured up to 185pt. Continuity needs
  *consistency*, not currency: one value used throughout cancels algebraically no matter how stale it is.
  A mutation pass calls `syncToPresentedPosition()` at entry, so it resolves against a current viewport;
  between ticks a plain `offset` read still trails the presented position by `velocity × (main-thread time
  since the last tick)`, which is what makes it stable. Halting momentum uses `haltMotionInPlace()` — never
  `setOffset(offset)`, which reads a stable value and then has it overwritten by the catch's instantaneous
  one (that cost 65pt of discontinuity on a `scrollTo` arriving mid-fling). Corollaries: the
  before/after differencing in `render()` / `applyEngineShift` must **stay** differences (`UIKitScrollEngine`
  genuinely clamps on a `contentSize` shrink, and the realized shift is the only correct amount); and any
  lurch test must measure against `TestScrollEngine.liveViewportOffset`, never `engine.offset`, or it passes
  by its own measuring stick freezing.
- **Anything that displaces screen-space content must join `displacesViewport`, or it silently degrades
  to per-row tracks.** The predicate (`logicalSizeChanged || insetsChanged || hasAdditionalScrollDistance`)
  gates the ONE shared additive viewport track that owns a pass's displacement. Omitted from it, a pass
  that moves the settled engine offset reads as a pure coordinate rebase, and every loaded row animates
  its own position instead. That renders as the *same* rigid motion for the rows that happen to be loaded
  — which is what makes it so easy to ship — while ghost blocks, viewport carries, and rows entering the
  window stay behind, because they follow the viewport track and nothing else. It caught
  `additionalScrollDistance` during implementation: the shift was correct, exact, and animating on the
  right curve, through the wrong owner.
- **A zero duration is immediate, which is the opposite of ComponentFlow.** `ComponentTransition`
  treats only `.none` as immediate and animates `.curve(duration: 0, …)`. CoreList settles a
  zero-duration property immediately, and roughly half the test suite says "no animation" as
  `duration: 0`. Every branch must therefore test `CoreListTransition.isImmediate`; `if case .none`
  silently animates a pass that must not.
- **Slow Animations reaches the emitted animation as `speed`, not as a longer duration** — exactly
  as `CAAnimationUtils` does it. The model still reasons on the SCALED clock, because its deadlines,
  `isComplete(at:)`, and the controller's reap scheduling all live there; `CoreListTransition.scaled(by:)`
  records the factor it applied in `appliedDurationFactor`, `ListAnimationTrack` carries it, and the
  compiler divides it back out so the animation gets a logical duration plus `speed = 1/factor`. The
  two describe the same wall time. Applying it once per path is still the rule: the model path in
  `ListAnimationController`, the executor path in `CALayer.animate`, and the transition handed to
  items is always the LOGICAL one. For the same reason `ListAnimationController`'s settled-write helpers use
  `CoreListTransition.commit` directly rather than `.immediate` setters: the setters clear the
  matching standard animation key (`position`, `opacity`, `bounds.size.height`) as ComponentTransition
  does, and the executor installs ITEM-VIEW animations under exactly those keys, so a settled write
  would cancel a row's own fade.
- **`Curve.custom` carries `Float`, so it is not a route to exact curves.** `.custom(1/3, 0, 2/3, 1)`
  is `x²(3−2x)` in real arithmetic, but 1/3 and 2/3 round to float32 and every sample drifts by up to
  1.7e-8 — including at phase 0.5, where the ideal bezier is exactly 0.5. Payload-free cases
  (`.easeInOut`, `.linear`) use `Double` literals and are exact.
- **The physics deceleration flights deliberately ignore the drag coefficient.** Every other CoreList
  animation honours Slow Animations; a fling or edge bounce does not. `Trajectory` bakes its path in
  real seconds and `boundsOriginKeyframeAnimation` installs it with `speed` at 1, so the toggle has no
  effect there — and the `.stepped` mode is likewise driven by real display-link deltas. This is
  accepted rather than verified: `UIScrollView`'s own deceleration is a physics simulation rather than
  a UIKit animation, so it plausibly ignores the coefficient too, in which case matching it is
  correct. Nobody has confirmed that against a real `UIScrollView`. If you make the flights honour the
  coefficient, scale the baked trajectory's playback (`speed`), not its sample times, and check the
  `KeyframeFlight` rebake/splice paths — they compare layer-local time against trajectory time and
  would drift if only one side were scaled.
- **The spring-kind predicate reads the LOGICAL duration.** `0.5` and `0.3832` select real
  `CASpringAnimation`s; every other duration gets the adjusted bezier
  `controlPoints(0.380, 0.700, 0.125, 1.000)`. CoreList pre-scales duration for Slow Animations, so
  resolving the kind from a scaled value would see `5.0` under a ×10 drag coefficient and silently
  emit a bezier — a divergence visible only under Slow Animations. `CoreListTransition` resolves it
  once at construction, `scaled(by:)` carries it through, and `ListAnimationTrack` stores what the
  transition resolved.
- **`Curve.solve(at:)` deliberately differs from Display's `bezierPoint`:** no 0.997 clamp, and a
  bisection fallback after Newton. CA keeps interpolating through a curve's tail, and the model must
  agree with what CA renders now that CA evaluates the bezier itself. (Measured: 4-iteration Newton
  was already exact to 4.4e-16; the clamp was the entire 2.9e-3 error.)
- **The model evaluates system springs through the private `_solveForInput:`**, resolved by an
  ObjC-runtime lookup in `CoreListSpringAnimation.swift`. Note `valueAt:` — which Display calls — is
  Display's OWN category in `UIKitUtils.m:24`, not an Apple selector, so `CASpringAnimation` does not
  respond to it here. The argument is `float` on some builds and `double` on others, which is why the
  lookup inspects the encoding. If the selector disappears, both the model and the emitter fall back
  to the adjusted bezier, degrading together rather than disagreeing.
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
