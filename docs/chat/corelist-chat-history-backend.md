# CoreList chat-history backend (PoC)

`CoreListChatHistoryBackend` (`submodules/TelegramUI/Sources/CoreListChatHistoryBackend.swift`) is a
**proof-of-concept** alternative chat-history list backend built on the vendored `CoreList` module's
`CoreVirtualListView` (a from-scratch UIKit virtualized list — see
`submodules/TelegramUI/Components/CoreList/CLAUDE.md`).

It is **opt-in behind the `coreListChatBackend` experimental flag** and selected in
`ChatHistoryListNodeImpl.makeListView(rotated:useCoreListBackend:)`
(`submodules/TelegramUI/Sources/ChatHistoryListNode.swift`). The production default —
`ListViewImpl` — is unaffected. See the "ChatHistoryListNode composition" section of the root
`CLAUDE.md` for the backend seam (`ChatHistoryListViewBackend`) this conforms to.

## Scope

The PoC targets **display / scroll / load-more only**. Every `ChatHistoryListViewBackend` member
outside that scope is a **safe stub** — no-op closure or plain stored property — that must never
crash. Real geometry/range values are populated only for the members the display path needs
(`displayedItemRange`, `visibleContentOffset`, `contentHeight`) plus the item-node enumerators
(`forEachItemNode` / `forEachVisibleItemNode` / `enumerateItemNodes` — see below) and
`didInteractivelyDragFromTopOrigin`, which is outside that scope but was implemented because its stub
silently disabled a user-visible behavior (see "Interactive drag start"). `ListViewScrollToItem` is
supported in full, and `ensureItemNodeVisible` with it (see "Scroll to item").

## Architecture

- **Composition, not inheritance.** It is an `ASDisplayNode` that hosts a single
  `CoreVirtualListView` (`self.coreList`) as a subview and conforms to `ChatHistoryListViewBackend`.
- **Rotation invariant (load-bearing).** The chat wrapper (`ChatHistoryListNodeImpl`) applies the
  chat's π rotation to *itself*, and each item node (`ChatMessageItemView.init(rotated:)`) applies its
  own π; those compose to upright content in a bottom-anchored inverted list. **The hosted
  `CoreVirtualListView` must stay at IDENTITY** — a third rotation here renders the whole chat
  180°-rotated. So CoreList lays out index 0 at its own *top*, and the wrapper's π flips it to appear
  at the screen *bottom* (index 0 = newest). `rotated` is stored only to satisfy the `makeListView`
  contract; it applies no transform. `layout()` sizes the child via `bounds` + `center` (not `frame`)
  so it stays transform-safe.
- **Entry array is the source of truth.** `private var entries: [CoreListEntryItem]` mirrors the
  ListView transaction model (delete/insert/update over indices). `CoreListEntryItem` is a
  `final class` conforming to `CoreListItem`, keyed on the message **`stableId`** as `identity`
  (matching the diff indices produced by `mergeListsStableWithUpdates`); a monotonic `stableVersion`
  is its content-equality discriminator, so a same-stableId entry whose content was swapped
  reconfigures its reused view.
- **Eager view load.** `let _ = self.view` in `init` forces the node's view to load, because the
  composed wrapper gates its history dequeue on `isNodeLoaded` (mirroring `ListViewImpl`).

## Transaction flow

`chatHistoryTransaction(...)` applies a ListView-style batch to `entries` in ListView's own order
(**deletes first** — descending index so earlier removals don't shift later ones — **then inserts**
in ascending index order, **then updates**), maps size/insets, then re-renders the full settled set
via `CoreVirtualListView.applyChanges`:

- `items:` — the rebuilt `entries` on a structural change, else `nil`.
- `newSize:` / `newInsets:` — the current size/insets (an unchanged inset is an exact no-op in
  CoreList, so passing it on every pass is safe and correctly propagates `setTopContentInset` deltas).
- `scrollTo:` — a `CoreListScrollTarget` mapped from `ListViewScrollToItem` (see "Scroll to item").
- `additionalScrollDistance:` — passed straight through. Both backends fold it into the same addend as
  the inset compensation, so a pass can re-inset and scroll by a caller-chosen delta as one movement;
  positive moves content down. **The chat never sends a non-zero value** —
  `ChatControllerNode.containerLayoutUpdated` declares `let additionalScrollDistance: CGFloat = 0.0`
  (`ChatControllerNode.swift:2451`) and has since the repo's first commit, and
  `ChatHistoryListNodeImpl.updateLayout` zeroes it again whenever the live sibling `scrollToTop` is set.
  It is implemented so the two backends answer a non-zero value the same way if one is ever wired up,
  not because anything depends on it today. Two divergences from `ListViewImpl`, both unreachable from
  that producer: ListViewImpl drops the value entirely unless the pass also changed size/insets (the
  addend sits inside `if let updateSizeAndInsets`, `ListView.swift:3257`), and its momentum halt does not
  need the pass to run.
- `anchorMode:` — `.preserveVisibleContent` when `stationaryItemRange != nil`, else `.automatic`.
- `transition:` — derived once and reused as both the applied animation and the reported transition, in
  ListViewImpl's own precedence: an animated `scrollToItem` (its own `.curve`, mapped case-for-case),
  then a size/inset update's curve, then `.AnimateInsertion` (`.spring(0.4)`), else `.immediate`.

`applyChanges` fires when *any* of structural / size / scroll / displacement changed.

## Node hosting

`CoreListNodeHostView` (a `UIView & CoreListItemView`) hosts one `ListViewItemNode`. `update(width:)`
rebuilds when the node is missing, content is dirty, or the width changed, then stamps
`node.view.frame` to the measured height. `rebuild(width:)`:

- **Incremental reuse:** when an `itemNode` already exists, it calls `listItem.updateNode(...)` to
  update in place (the node's view stays a subview), taking the height from the returned
  `ListViewItemNodeLayout`.
- **Fresh build:** when there is no node yet, it calls `listItem.nodeConfiguredForParams(...)` and adds
  the resulting `node.view`.

Both paths drive the item **synchronously** (`async: { f in f() }`); this is sound because
`ChatMessageItemImpl.updateNode`/`nodeConfiguredForParams` wrap work in `Queue.mainQueue().async`,
which runs inline when already on the main queue (the transaction path is main-thread). CoreList owns
the actual insert/move/height animations; the item update passes `ListViewItemUpdateAnimation.None`.

Both paths also stamp `contentSize` / `insets` / `apparentHeight` on the node, as `ListViewImpl` does
on every node it lays out. This is not bookkeeping for its own sake — see "Item visibility" below for
what reads it. Note `ChatMessageItemImpl` assigns `contentSize`/`insets` itself on the
`nodeConfiguredForParams` path but **not** on `updateNode`, which is why the host must.

## Item visibility

`CoreVirtualListView` pushes each loaded row its visible rect through
`CoreListItemView.visibleRectUpdated(_:)` (see the CoreList `CLAUDE.md` embedding-seam paragraph);
`CoreListNodeHostView` maps it onto `ListViewItemNode.visibility` — `subRect` is the rect as given,
`fraction` is its overlap with the node's content box over that box's height, matching what
`ListViewImpl` derives from `apparentContentFrame`. That property is what makes animated stickers,
GIFs, video and instant video play, flips `visibilityStatus`, registers one-time media as seen, and
fades ad messages in. Before this existed every hosted row sat at `.none` for its whole life, so none
of that happened at all.

Three things about it are load-bearing:

- **The fraction divides by the node's content box**, so the host must keep `insets` / `contentSize` /
  `apparentHeight` stamped on the hosted node exactly as `ListViewImpl` does — including on the
  update path, which `ChatMessageItemImpl.updateNode` does not do for itself.
- **The rect is measured against the full viewport**, not the inset-reduced band. This diverges from
  `ListViewImpl`, which reduces by `visualInsets ?? insets`; a row sliding under the input panel keeps
  playing. `forEachVisibleItemNode` / `itemNodeVisibleInsideInsets` deliberately keep the
  inset-reduced `visibleBand`, because they drive read tracking and unseen-reaction animations, where
  under-reporting is the safe direction.
- **There is no `onlyPositive` deferral and no animation-completion pass.** `ListViewImpl` needs both
  because its geometry is settled-only while an inset transition animates; here the loaded window and
  the reported rects are both destination-based within one pass, so a single full update is coherent.

Rotation needs no handling: CoreList lays index 0 at its own top and the wrapper's π maps that to the
screen bottom — the convention `ListViewImpl(rotated: true)` uses — so the values are already in the
space `ChatMessageBubbleItemNode.mapVisibility` expects.

## Pagination

`CoreVirtualListView.onVisibleWindowChanged` / `onLoadedEdgeReached` call
`updateVisibleItemRange(force:)`, which is how the history controller paginates. Callbacks are read off
`self` at call time so a later controller assignment is picked up. See "Content offsets and displayed
item range" below for the range computation and its firing conditions.

## Interactive drag start

On `CoreVirtualListView.willBeginDragging` (fired when the scroll engine's pan reaches `.began`) the
backend mirrors `ListViewImpl`: it walks every loaded item node and **cancels any in-flight
`ContextGesture`** (so a message's long-press/context menu doesn't fire once the user starts
scrolling), then reports `beganInteractiveDragging` to the history controller. The walk uses
`itemNodes` — a lazy, non-copying view over the loaded nodes, built from
`CoreVirtualListView.loadedItemViews` (each loaded item view is a `CoreListNodeHostView`, mapped to
its hosted `ListViewItemNode`). Nothing materializes an array. `beganInteractiveDragging` is passed
`.zero`: CoreList doesn't surface the touch point and every consumer ignores it.

It also **samples the drag's origin** for `didInteractivelyDragFromTopOrigin` — "the current-or-most-recent
gesture was a real drag, and it began pinned to the newest-message edge". The chat's one consumer reads it
after the keyboard is dismissed by dragging, to decide whether to snap back to the newest message
(`ChatControllerNode.swift:2453`). Two pieces of state, both reset on drag **begin** and never on drag end,
so the value survives to the layout pass that reads it (`ListViewImpl` likewise resets `trackingOffset` only
in the pan's `.began`):

- *began pinned* — `visibleContentOffset()` is `.known(value)` with `value <= 10.0`, the tolerance copied
  verbatim from `ListView.swift:4959`. `ListViewImpl` samples this at `touchesBegan` (finger down) while
  the earliest hook here is drag-begin, after the pan recognizer's threshold; 10pt is wide enough to absorb
  that difference, which is plausibly why the tolerance is 10 and not 0.
- *content moved* — set on any `onVisibleWindowChanged`, which is the `engine.onScroll` sink and therefore
  user-driven movement only: programmatic offset writes are isProgrammatic-guarded, and the additive
  viewport track moves content with no engine offset change at all. It also fires during momentum, where
  `ListViewImpl` has stopped accumulating; harmless, since momentum only follows a drag that already moved
  content.

This was previously two stubbed constants (`trackingOffset = 0.0`, `beganTrackingAtTopOrigin = false`),
which made the predicate permanently false and silently disabled the snap-back under this backend. The
contract now carries the single combined member, so a backend can no longer implement one half.
**Manually verified working** (2026-07-28) on the CoreList backend — this is behavior no build or test
in the repo covers, so it is the only kind of evidence available for it.

### Inset changes while tracking (keyboard dismissal)

A third piece of drag state, `isTracking`, is the analogue of `ListViewImpl.isTracking`: a finger is on
the list **right now**. Unlike the two above it does not survive drag end — it is set on
`willBeginDragging` and cleared on `didEndDragging`, and is false throughout momentum. `ListViewImpl`
keeps the same distinction (momentum is `isDeceleratingAfterTracking`, and the suppression below tests
only `isTracking`).

Its single consumer is inset-compensation suppression. **The chat's insets change while the list is being
dragged, by the same finger.** `Window1` installs a `WindowPanRecognizer` implementing interactive
system-keyboard dismissal (`Display/Source/WindowContent.swift:1332`), and its delegate returns `true`
from `shouldRecognizeSimultaneouslyWith` (`WindowContent.swift:254`), so one downward drag both scrolls
the history and shrinks `inputHeight` frame by frame. Each frame therefore reaches the list twice — once
as a scroll delta, once as a smaller bottom inset — and compensating the inset change on top of the
scroll moves content by **double** the finger's travel. `ListViewImpl` answers this by zeroing
`offsetFix` while tracking:

```swift
if (self.isTracking && !self.allowInsetFixWhileTracking) || isExperimentalSnapToScrollToItem {
    offsetFix = 0.0                       // Display/Source/ListView.swift:3276
}
```

The backend reproduces it by passing `compensatesInsetChange: !self.isTracking` to `applyChanges`, which
drops CoreList's `newTopInset - oldTopInset` anchor projection — the exact analogue of `offsetFix` — and
nothing else. Three properties are load-bearing:

- **The insets themselves still apply.** Content x/width, the viewport band, the load band and the
  loaded-top pin all move. That is what keeps the bottom of the chat following the keyboard down under
  suppression: under the wrapper's π rotation the newest message is CoreList's *loaded top*, and
  `pinsLoadedTop` puts index 0 on the new inset edge regardless of the anchor projection. `ListViewImpl`
  splits it identically — `self.insets` is still assigned and `snapToBounds` still runs.
- **`additionalScrollDistance` is untouched.** It is a caller-chosen displacement, not compensation;
  `ListViewImpl` orders it the same way (the `+=` comes after the tracking branch).
- **The flag is read at the call site**, not inside CoreList, so the value is the one that held when the
  transaction was submitted even if `applyChanges` defers it past a re-entrant pass.

Cancelling the compensation with `additionalScrollDistance: -topInsetDelta` instead looks equivalent and
is not: a non-zero distance halts momentum and opts the pass out of `pinsLoadedTop`, so the newest
message would stop tracking the inset edge — the one case that must keep working.

`didEndDragging` was added to the seam for this (`ScrollEngine.onDidEndDragging` → both engines →
`CoreVirtualListView.didEndDragging`). It deliberately does **not** yet call the backend's
`endedInteractiveDragging`: that callback drives overscroll-to-open-next-channel, a separate
unimplemented item rather than something to switch on as a side effect of the hook existing.

Covered by `CoreListDemoTests/InsetCompensationSuppressionTests` on the CoreList side (8 tests). The
chat-side wiring — that a real interactive keyboard dismissal no longer double-offsets — has no
automated coverage; it was **manually verified working** (2026-07-28) on the CoreList backend, which is
the only kind of evidence available for it. Before the fix the history visibly moved by roughly twice the
finger's travel as the keyboard was dragged away.

### Long-press / context menu (gesture arbitration)

Bubbles' long-press-for-context-menu (`ContextGesture`) depends on a **load-bearing gate inside
CoreList**: `PhysicsScrollEngine.gestureRecognizer(_:shouldBeRequiredToFailBy:)` declares that content
recognizers under the list must wait for the scroll pan to fail, and that declaration is applied
**only while content is moving**. Removing the gate silently kills every long-press in the chat — a
press-and-hold has to recognize while the finger is still down, but the pan does not fail until lift,
so UIKit tears the recognizer down instead of activating it. The failure is easy to misread: no
`activated`, no `cancel()`, no `touchesCancelled` — just a half-run press animation that springs back,
and a `Gestures`-internal `_resetGestureRecognizer` in the stack. Taps are unaffected, so the CoreList
demo (tap-only rows) cannot catch a regression here. See the matching gotcha in the CoreList
`CLAUDE.md`.

## Item-node enumeration

`forEachItemNode` / `enumerateItemNodes` / `forEachVisibleItemNode` are real (they were no-op stubs
in the first PoC cut). Two private lazy, non-copying sequences back them, both derived from
`CoreVirtualListView.loadedItemViews` (ascending item index; a COW snapshot of the settled window, so
a callback that re-enters `applyChanges` cannot corrupt iteration):

- `itemNodeHostViews` — the loaded `CoreListNodeHostView`s. This is the **geometry-bearing** level: a
  host view sits in the CoreList hierarchy, whereas its hosted node's frame is host-local.
- `itemNodes` — each host view's hosted `ListViewItemNode`, skipping any not-yet-built. Also used by
  the `willBeginDragging` gesture-cancel walk.

`ListViewImpl` guards each node on `index != nil` to skip removed-but-still-animating nodes; CoreList
needs no analogue, because genuine departures move to the non-interactive `exitOverlay` as ghost
blocks and never appear in `loadedItemViews`.

`forEachVisibleItemNode` applies `ListViewImpl`'s own filter — `frame.maxY > insets.top &&
frame.minY < height - insets.bottom` — to each row's rect obtained via `listFrame(of:)`, i.e.
`coreList.presentedFrame(of: hostView)`. Two load-bearing details:

- **The filter is not optional.** CoreList's loaded window is viewport **plus preload margin**, so
  forwarding to `forEachItemNode` would report off-screen rows as visible and misdrive
  `hasVisiblePlayableItemNodesPromise` (video with sound), unseen-reaction animations,
  `isMessageVisible(id:)`, and read tracking.
- **The band uses `currentSize`/`currentInsets`, not the protocol-exposed `visibleSize`/`insets`,**
  because `setTopContentInset(_:)` writes only `currentInsets.top`. Orientation already matches:
  CoreList lays index 0 at its own top and the wrapper's π maps that to the screen bottom — the same
  convention `ListViewImpl(rotated: true)` uses — and both backends receive identical insets from the
  same transaction. Before the first `updateSizeAndInsets`, `currentSize` is `.zero` and nothing
  reports visible, matching `ListViewImpl` with a zero `visibleSize`.

**All row geometry goes through `CoreVirtualListView.presentedFrame(of:)`, never a bare
`UIView.convert`.** The `convert`-based reasoning still holds — it walks whatever ancestor path the row
currently has (`container` normally, `crossingOverlay` while a structural transition carries it), so it
cannot drift from what is rendered — but `convert` alone composes ancestor **model** `bounds.origin`, and
CoreList's `contentHost` model origin is the additive base of whatever animates the viewport. Under a
`.keyframe` flight it is parked at the flight's *destination* for the entire fling, and a programmatic
`scrollTo` leaves the settled endpoint there while an additive `viewportOffset` track carries the motion.
So a bare `convert` reported every row hundreds of points from where the user saw it for the whole
momentum phase — visible range, content offsets, read tracking and unseen-reaction animations all
described the end of the fling rather than the middle of it. `presentedFrame(of:)` applies the correction
(only CoreList holds both the model base and the engine position). It is presented **as of the last
sampling tick**, which is what a host wants: these callbacks all run per frame, where the two coincide.
`ListViewImpl` reads settled endpoints too, but there the model *is* the presented value — that is why
the original reasoning did not transfer. Verified in the app: with this fix (plus the two engine-side ones it
shipped with) the occasional stutter while flinging through unloaded history is gone. See
`submodules/TelegramUI/Components/CoreList/docs/superpowers/specs/2026-07-26-clock-free-mutation-pass-design.md`.

### Index lookup, relative offset, inset visibility

`itemNodeAtIndex` / `itemNodeRelativeOffset` / `itemNodeVisibleInsideInsets` are real. All three of
`ListViewImpl`'s versions are index-based, and `ListViewItemNode.index` is `public internal(set)` to
`Display` — so a hosted node can never carry a ListView index and each needed a CoreList-native
equivalent:

- **`itemNodeAtIndex`** resolves through `CoreVirtualListView.loadedItemView(at:)`, the index-keyed
  sibling of `loadedItemViews`. CoreList owns `activeWindow` and is the authority on the index ↔ view
  mapping; the backend must not re-derive it by walking `loadedItemViews` to a position inferred from
  `loadedIndexRange`, which would leak CoreList's contiguity and index-base invariants into TelegramUI.
  `index` is in the `entries` index space, matching the one caller (the ad-message anchors, built as
  `filteredEntries.count - 1 - i`).
- **`loadedFrame(of:)`** is the shared helper behind the other two: it scans `itemNodeHostViews` for
  the host view whose `itemNode ===` the argument and returns its converted rect. **Its nil case is the
  liveness guard** — absence from the loaded window is the CoreList equivalent of `index == nil`, since
  genuine departures move to the `exitOverlay` and never appear there.
- **`itemNodeVisibleInsideInsets`** applies the same band as `forEachVisibleItemNode`; both read the
  single private `visibleBand` property so they cannot drift.
- **`itemNodeRelativeOffset`** returns `frame.minY - currentInsets.top`, matching `ListViewImpl`
  exactly. This convention is load-bearing: the value is persisted as
  `ChatInterfaceHistoryScrollState.relativeOffset` and restored as
  `ListViewScrollToItem(position: .top(offset))`, which `ListViewImpl` resolves to
  `frame.minY == insets.top + offset` — the exact inverse. CoreList's `scrollTo.pointOffset` uses the
  identical convention (screen target = `viewportInsets.top + pointOffset`), so **no unit conversion is
  needed**. Both sides are live: the restore path resolves `.top(offset)` through the scroll resolver.

`loadedFrame(of:)` is also what backs `itemNodeFrame(_:)` — see "Item-node geometry" below.

## Content offsets and displayed item range

`visibleContentOffset()` / `visibleBottomContentOffset()` / `updateVisibleItemRange(force:)` follow
`ListViewImpl` (`ListView.swift:1380`, `:1412`, `:4673`). They previously returned
`.known(rawEngineOffset)`, a constant `.known(0.0)`, and nothing — which broke real behavior, since
chat reads `abs(offset) <= 0.9` as "pinned to the newest message"
(`ChatHistoryListNode.swift:2425`) and short-circuits `scrollToEndOfHistory` on `value <= ulpOfOne`
(`:3690`).

- **`.known` is reserved for a loaded list edge.** `visibleContentOffset()` is `.known` only when the
  settled window starts at collection index 0, and its value is that row's distance from the top inset
  edge, **negated** (`0` = flush against `insets.top`, positive = scrolled away).
  `visibleBottomContentOffset()` is `.known` only when the window ends at the last entry, valued
  `maxY - (height - insets.bottom)` and **not** negated. Both then read as "how much content lies
  beyond that edge". An empty window is `.none`; a loaded window not reaching the edge is `.unknown`.
  `ListViewImpl`'s fold over removed-but-animating nodes above the top item has no analogue — CoreList
  departures live in the `exitOverlay`.
- **`updateVisibleItemRange(force:)` is the only writer of `displayedItemRange`,** and fires
  `displayedItemRangeChanged` only on an actual change, against a private optional
  `internalDisplayedItemRange` mirror (optional so the first computation always counts). The mirror is
  committed before the callback fires, so a callback that triggers another update cannot recurse.
- **`immediateDisplayedItemRange()`** reports `loadedRange` as the settled window's index span and
  `visibleRange` as the sub-span intersecting the viewport band — a real visible range, replacing the
  earlier placeholder that reported the loaded span for both. It walks
  `CoreVirtualListView.loadedItemEntries`, the `(index, view)` sibling of `loadedItemViews`, so indices
  come from the window rather than from an iteration counter.
  **Deliberate divergence:** `ListViewImpl`'s first-visible scan tests `minY < visibleSize.height +
  insets.bottom` (`:4711`) while its last-visible scan tests `- insets.bottom` (`:4723`); the `+` looks
  like an upstream typo, so both scans here use the symmetric bound.
- **`visibleContentOffsetChanged` fires on all scrolling.** `onVisibleWindowChanged` covers every
  user-scroll frame including momentum (`handleUserScroll` is the `engine.onScroll` sink and calls it
  unconditionally, whether or not the window rebalanced — its "after each user-scroll rebalance" doc
  comment understates it). Programmatic movement is covered at **transaction end**, because
  `setOffset` / `applyShift` / `setEdges` are `isProgrammatic`-guarded in `UIKitScrollEngine` and the
  additive viewport track moves content with no engine offset change at all. `ListViewImpl` is
  structured the same way, so no CoreList scroll seam was needed. The transaction passes a transition
  matching the applied animation; `ContainedViewLayoutTransitionCurve` has no `.easeOut`, so a standard
  ease-out bezier approximates CoreList's, which is cosmetic (consumers only co-animate chrome with it).

**Known difference:** `ListViewImpl` also updates the content offset per-frame *during* animations
(`ListView.swift:4908`). CoreList animates through analytic CA tracks with no per-frame host callback,
so the backend reports the settled endpoint plus a matching transition and lets the consumer animate
alongside.

## Neighbor awareness

Rows are laid out with the descriptors published by their adjacent entries, so bubbles merge and
date headers collapse the way they do on `ListViewImpl`. Before this existed the backend passed
`previousItem: nil, nextItem: nil`, which rendered every message unmerged with its own date header.

`CoreListEntryItem` carries a `ListViewItemNeighbors`, computed in one pass **after** the
insert/update/delete operations have settled — neighbors are a function of final adjacency, so
computing them per-operation would use indices that later shift. The index bases match
`ListView.neighbors(at:)`; that is valid because the backend feeds items in `ListView` index order,
and it means the `isRotated` flip inside `ChatMessageItem.merged(with:isRotated:)` needs no
special-casing here.

The value participates in `isEqual(to:)` alongside `stableId`/`stableVersion`, so a row whose
neighbors changed is unequal and re-applies. That is the backend's equivalent of `ListViewImpl`'s
descriptor-diff invalidation.

See the "Neighbor descriptors" section of the root `CLAUDE.md` for the load-bearing invariant: a
descriptor must encode everything a neighbor reads, or the omitted fact goes stale on screen.

## Scroll to item

`chatHistoryTransaction` maps `ListViewScrollToItem` onto a `CoreListScrollTarget` whose **resolver**
computes the row's offset once CoreList has measured it. That indirection is the whole design: three
of the four `ListViewScrollPosition` cases need the target row's height, and on a history jump the
target is not loaded — the entries array is replaced wholesale — so the backend has nothing to
measure. CoreList measures the anchor as the first act of `buildWindow` and calls back there.

`pointOffset(for:index:height:view:)` holds `ListViewImpl`'s arithmetic
(`Display/Source/ListView.swift:3166-3204`), translated from "a delta added to every frame" into "the
target row's `minY`, minus `insets.top`" — CoreList's convention, where the projected screen target
is `viewportInsets.top + pointOffset`. It reads `scrollPositioningInsets` and the `.center(.custom)`
quote/subject rect off the hosted `ListViewItemNode`, which exists because `update(width:)` has
already driven a synchronous layout. **All ListView placement semantics live here**, not in CoreList,
which learns nothing about chat.

The curve maps case-for-case onto `CoreListTransition` (`ListView.swift:3611-3618`) instead of
collapsing to one spring, and `directionHint` becomes the carousel's travel direction —
`.Down → .forward`, `.Up → .backward`. That mapping is what `ChatHistoryViewForLocation.swift:59`
means: it picks `.Down` when the target is *older*, and chat's index space is reversed, so older is a
higher index, which is forward. The hint is consumed **only** when the viewport transition has no
anchor witness; a full replace is exactly that case, and without it every long jump travelled forward
regardless of direction.

A jump also fades nothing at either end. CoreList suppresses insert and exit opacity on a
**full-replace** carousel — one whose loaded windows are disjoint *and* whose destination window is
entirely new content — because that is a rigid travel between two strips already owned by the shared
viewport track. The fades were an artifact of the chat expressing a jump as delete-all + insert-all.
`ListViewImpl` likewise slides its `temporaryPreviousNodes` out at full opacity.

**The destination window is the load-bearing unit**, and getting it wrong is easy in both directions.
Testing only loaded-window disjointness fades a genuinely new row inserted among survivors at the
destination. Testing whole-*collection* disjointness — which this did at first — never fires here at
all: `ChatHistoryEntry` gives the non-message rows **constant** stable ids (`UnreadEntry` is
`4 << 40`, `ReplyCountEntry` `5 << 40`, `ChatInfoEntry` `6 << 40`), so a wholesale history replace
always leaves one identity alive and the collection-level test was permanently false. It looked
correct in CoreList's own tests, whose synthetic collections are cleanly disjoint, and failed on
every real jump. What decides it is whether anything in the place being travelled *to* was already
there.

`ensureItemNodeVisible` is built on the same path (as it is in `ListViewImpl`), with the collection
index resolved through `CoreVirtualListView.loadedItemEntries` — a hosted node can never carry a
`ListViewItemNode.index`.

**Verification status (2026-07-31): runtime-verified.** `CoreListDemoTests` covers resolver placement
against a far unloaded target, the direction fallback, and carousel fade suppression from both sides
(616 tests green). All six chat behaviors were then confirmed on screen: scroll-to-unread (including
in a chat whose navigation bar changes height mid-open), long-jump travel direction and opacity,
jump-to-reply centering, quote centering in an over-tall bubble, scroll-position restore on chat
open, and reply-thread unread refocus.

**Two of those six failed on first contact, and neither failure was visible to the test suite.** The
unread separator landed ~70pt off because `enableUnreadAlignment` was dead code under this backend
(see "Unread item alignment"), and long jumps still cross-faded because the fade-suppression
predicate tested whole-collection disjointness, which never holds for real chat data (see "Scroll to
item"). Both bugs had green CoreList tests over them the whole time — the synthetic fixtures use
disjoint identities, uniform row heights, and no constant-id rows, so they are systematically cleaner
than what the chat produces. **Treat CoreList test coverage as necessary and not sufficient for
anything in this backend; the on-screen check is the real gate.**

## Item-node geometry

`ListViewItemNode.frame` is list-space **only on `ListViewImpl`**. Here a node's view is a subview of
its `CoreListNodeHostView` at `(0, 0, width, height)`, so the node's own frame is host-local and every
comparison against it reads the wrong space — silently, since the values are plausible.
`ChatHistoryListViewBackend.itemNodeFrame(_:)` is the list-space accessor both backends implement
(`ListViewImpl` returns `node.frame` guarded on `index != nil`; the CoreList backend returns
`loadedFrame(of:)`), and its nil case is the liveness guard on both.

Nine chat-layer sites were migrated onto it: the visible-message scan, both scroll-reset anchor
offsets, the animate-in delay factor, the next-item scroll-restore check, `messagesAtPoint`, and both
snapshot inset loops. `messagesAtPoint` is the one that was outright broken — it tested a point
against a host-local rect and could never match.

## Unread item alignment

The chat re-pins the unread separator to the bottom inset edge whenever that inset changes
(`enableUnreadAlignment`, default true). This is **not** cosmetic: when the navigation bar changes
height mid-open — a Report Spam bar appearing, which lives in `navigationBar.additionalContentNode`
and so grows the chrome without moving `containerInsets` — the separator must be re-pinned, or it
keeps the position computed against the pre-panel geometry.

It used to live in `ChatHistoryListNodeImpl.updateLayout` gated on `itemNode.index`, which is
`public internal(set)` to `Display` and therefore **always nil for a hosted node** — so the entire
behavior was dead code under this backend, with no build error. It is now the
`maintainsUnreadItemAlignment` parameter on `chatHistoryTransaction`.

**One member, not two, deliberately.** The predicate ("is the separator currently pinned?") must be
evaluated against the OLD insets and the re-pin applied with the NEW ones. As a measure-then-reapply
pair a backend could implement one half and stub the other — precisely how
`trackingOffset`/`beganTrackingAtTopOrigin` silently disabled keyboard-dismissal snap-back before they
were collapsed into `didInteractivelyDragFromTopOrigin`.

The two backends realise it differently, which is the point of the seam: `ListViewImpl` cannot compose
a scroll with an inset change, so it measures, runs the transaction, and re-issues the scroll from the
completion. The CoreList backend evaluates the predicate before overwriting `currentInsets` and
submits the re-pin as the `scrollTo` of the *same* `applyChanges` — one movement, one animation, no
intermediate frame. The read-at-the-call-site pattern is the same one `compensatesInsetChange` uses,
and for the same reason: the value must be the one that held when the transaction was submitted.

**Deliberate divergences from `ListViewImpl`:**

- **`displayLink` is unused.** `ListViewImpl` re-samples the quote rect per frame during the scroll;
  CoreList animates through analytic CA tracks with no per-frame host callback, so `.center(.custom)`
  resolves once, at pass time.
- **The insets used are the pass's *new* ones.** `ListViewImpl` reads the old `self.insets` here —
  `ListView.swift:3143` still carries a commented-out `// updateSizeAndInsets?.insets ?? self.insets`
  — and applies the size/inset change separately afterwards. The backend resolves both in one
  coordinate system.
- **`.center` uses the single measured height.** `ListViewImpl` guards on
  `apparentFrame.size.height` but divides `itemNode.frame.size.height` (`:3173-3174`).
- **`.visible` on an unloaded target** falls back to center-with-top-overflow. Only reachable from
  the `experimentalSnapScrollToItem` path, which nothing in chat enables; `ensureItemNodeVisible`
  always holds a loaded node.
- **Pin-to-edge is still unimplemented.** `ListViewImpl` synthesizes its own `scrollToItem` for
  `pinToEdgeWithInset` items via `experimentalSnapScrollToPinnedItem` (`ListView.swift:2737-2765`),
  and `isStrictlyScrolledToPinToEdgeItem()` remains `false`.
- **`resetScrolledToItem()` remains a no-op**, which is correct while nothing sets
  `experimentalSnapScrollToItem = true` (the only assignments, `ChatHistoryListNode.swift:1023` and
  `ChatController.swift:7674`, are both `false`).

## Deferred items / known limitations

These are accepted for the PoC and are the follow-ups before the CoreList backend could be a real
option:

1. **Per-item animation selectivity.** The pass transition is now derived from `scrollToItem` /
   `updateSizeAndInsets` / `options` (see Transaction flow), but it applies to the pass as a whole:
   `options` distinctions finer than "does this animate, and on what curve" — per-index insertion
   animations, `.AnimateCrossfade`, `.AnimateTopItemPosition` — still have no analogue.
2. **Fine-grained transaction features ignored.** `customAnimationTransition` is not honored, and
   `stationaryItemRange` is mapped only by its nil-ness (to `anchorMode`): the range's actual bounds
   are discarded, so a transaction asking to hold a *specific* index range stationary gets CoreList's
   general visible-content preservation instead.
3. **Config/geometry stubs.** The `// Config flags` and `// Geometry / range` members are plain
   storage with no behavior; only the display-path values are real. (`didInteractivelyDragFromTopOrigin`
   used to be two of these and is now real — see "Interactive drag start". It is worth reading that
   entry as a warning about the rest: a stub that returns a plausible constant reports *no* problem,
   and this one disabled a user-visible behavior for as long as it existed.) Several installed callbacks
   are likewise never fired: `endedInteractiveDragging` (overscroll-to-open-next-channel),
   `didEndScrolling`, `didEndScrollingWithOverscroll`. `endedInteractiveDragging` now *could* be — the
   seam gained `didEndDragging` for the tracking flag — but wiring it would switch on the next-channel
   behavior, so it stays a deliberate follow-up rather than a side effect.
4. **`itemNode.frame` is still host-local** — the *fact* is unchanged, but every chat-layer consumer
   has been migrated off it (see "Item-node geometry" above), so nothing in the chat currently reads
   it. A hosted node's view remains a subview of its `CoreListNodeHostView` at
   `(0, 0, width, height)`, so any **new** caller reaching for `ListViewItemNode.frame` will silently
   read the wrong space. Use `ChatHistoryListViewBackend.itemNodeFrame(_:)`. Item **header** nodes
   have no equivalent yet (`forEachItemHeaderNode` is still a stub).
