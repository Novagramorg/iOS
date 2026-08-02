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
supported in full, and `ensureItemNodeVisible` with it (see "Scroll to item"). Floating date headers
and gutter avatars are implemented on top of CoreList's attachment feature (see "Floating headers and
avatars"), which makes `forEachItemHeaderNode` real.

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

- `items:` — the rebuilt `entries` on a structural change **or a horizontal-inset change**, else `nil`.
- `newSize:` / `newInsets:` — the current size and the **vertical** insets (an unchanged inset is an
  exact no-op in CoreList, so passing it on every pass is safe and correctly propagates
  `setTopContentInset` deltas). Horizontal insets are deliberately *not* passed — see below.
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

### Horizontal insets go to the item, not the viewport

A side inset (the topics sidebar) reaches the hosted node as
`ListViewItemLayoutParams.leftInset`/`rightInset` — rows are always laid out at the **full viewport
width**. `coreListInsets` therefore zeroes `.left`/`.right` before `applyChanges`, and
`CoreListEntryItem` / `CoreListHeaderAttachedItem` carry the values instead.

This is `ListViewImpl`'s arrangement, not a workaround for it: there is no `x: insets.left` anywhere in
`ListView.swift`, its rows are full width, and the inset is a layout param (`ListView.swift:2384`,
`:4098` for headers). Letting CoreList's viewport insets frame the row instead — its natural mode,
`contentWidth = width - left - right` (`CoreVirtualListView.swift:2262`) — breaks in two independent
ways:

- **Orientation.** Item nodes carry their *own* π (`ChatMessageItemView.init(rotated:)`, which flips x
  as well as y). Item π + wrapper π = identity, so an inset applied **inside** the item lands on the
  screen side the chat named; framing the row takes only the wrapper's π, so `insets.left` came out on
  the screen *right*. Measured: the sidebar's 92pt shrank the bubbles by 92pt on the right and moved
  nothing away from the left, so the sidebar overlapped the content it was making room for. Swapping
  left/right at the boundary fixes this symptom alone, and was the first attempt.
- **Animation.** Framing the row cannot animate the move, swapped or not. Subviews do not follow their
  superview's `bounds.size.width`, so the content only moves when the hosted node is re-laid out — at
  the destination width, immediately, mirrored about a centre that had itself jumped by half the inset.
  The visible result was items animating correctly while sitting 46pt (half of 92) off from the first
  frame. As a layout param it is an ordinary item relayout, animated on the pass transition.

The trigger is content equality, not a special case: `isEqual(to:)` on both the entry item and the
header attachment compares the insets, so a sidebar opening makes every row a **survivor whose content
changed** — the same path an edited message takes — and each host is reached with the pass transition.
`withSideInsets(left:right:)` re-pins the entries while preserving `stableId`/`stableVersion` so they
reconcile as survivors rather than replacements. Vertical insets need none of this: both backends let
the list place a row vertically, one π either way, which `ChatControllerNode.swift:2500` already
accounts for.

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
the insert/move/height animations of the **row**; the pass transition is handed to the item as its own
`ListViewItemUpdateAnimation` so it can animate its **internals** (mapped through
`ComponentTransition` → `ContainedViewLayoutTransition`, with the immediate case mapped to `.None` —
`ListViewItemUpdateAnimation.isAnimated` is true for *any* `.System` regardless of duration, and
`ChatMessageBubbleItemNode` branches on it in ~20 places to run its own hard-coded animations).

### Height changes need the node's content compensated

`update(width:transition:)` frames the node at the **settled** height and never animates that write —
the engine animates the row. But the node carries its own π and anchors at its centre, so its content
reads `screenY = height - localY`: a height change displaces the content by the full delta, instantly,
while the row's height and position animate underneath it. That is a vertical snap of the whole item,
and it is what remained after the horizontal fix above (bubbles genuinely rewrap taller/shorter at a
new width, so the height change is real and unavoidable).

The host compensates with `layer.animateBoundsOriginYAdditive(from: previousHeight - newHeight, to: 0)`
on the node. This is `ListViewImpl`'s own compensation, taken from the one branch of it that ports:
`ListViewImpl` has two, and the display-link branch seeds `node.transitionOffset` (with an explicit
`node.rotated` formula, `ListView.swift:2515`/`:2554`/`:2581`) and relies on `updateAnimations()` to
walk it back to zero — **nothing drives that here**, so seeding it would displace the content
permanently. The CA-driven branch, taken when `customAnimationTransition` is set, instead calls
`animateOffsetAdditive(node:offset:)` with `previousApparentHeight - updatedApparentHeight`
(`ListView.swift:3035`) and needs no driver. Being additive, the model value stays the settled one and
only the presentation starts displaced, so it composes with the engine's own tracks and there is
nothing to unwind. Skipped for a fresh view, which has no previous height to travel from.

Each row is measured **once per pass** (the `buildWindow` anchor plus the two extension paths, and the
pre-build `consumedDirty` sweep which already carries the animated pass transition), so the delta
cannot be consumed by an earlier immediate call in the same pass.

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

### Horizontal insets are mirrored on the way to CoreList

`coreListInsets` swaps `left` and `right` before handing the pass's insets to
`CoreVirtualListView.applyChanges(newInsets:)`. Vertical passes through untouched. This is not
symmetry for its own sake — the two backends apply a horizontal inset at **different levels**, so the
chat's single mirrored value (`ChatControllerNode.swift:2500` mirrors all four) takes a different
number of π flips in each:

- **`ListViewImpl`** keeps rows FULL WIDTH — there is no `x: insets.left` anywhere in `ListView.swift`
  — and hands the inset to the **item** as `ListViewItemLayoutParams.leftInset`/`rightInset`. The item
  applies it inside a node carrying its own π (`ChatMessageItemView.init(rotated:)` →
  `CATransform3DMakeRotation(π, 0, 0, 1)`, which flips **x as well as y**). Item π + wrapper π =
  identity, so `insets.left` lands on the screen **left**.
- **CoreList** frames the row itself at `x = viewportInsets.left` with
  `contentWidth = width - left - right` (`CoreVirtualListView.swift:2262`), and the backend passes
  `leftInset: 0, rightInset: 0` to the hosted item because that framing already happened. Only the
  wrapper's π applies, so without the swap `insets.left` lands on the screen **right**.

Vertical needs no such correction because both backends let the *list* decide a row's vertical
position — one π either way, which the chat's pre-mirror already accounts for.

**It is invisible until the two sides differ**, which is why it survived: portrait phone has
`left == right == 0`, and the `.regular`/`.regular` case adds 6.0 to both. It shows up with the
topics sidebar (`floatingTopicsPanelInsets.left`, added to `.left` only) and with landscape safe
areas. Measured before the fix: forcing the sidebar's 92pt onto `listInsets.left` shrank the bubbles
by exactly 92pt **on the right** and moved nothing away from the left, so the sidebar overlapped the
content it was meant to make room for. After: the 92pt band is on the left and the avatars sit
against it.

Swapping in the backend rather than the chat is deliberate: this is CoreList's framing convention,
not a chat-layer fact, and `currentInsets` stays exactly what the chat submitted, so every other
reader (`visibleBand`, both content offsets, the scroll resolver — all vertical) is unaffected.
`applyChanges` is the only place CoreList receives insets and nothing else in the backend reads
`.left`/`.right`, so `coreListInsets` is the single point of truth. The attachment hosts are framed
at `viewportInsets.left` too, so they are corrected by the same swap.

**No test covers this** — it is a TelegramUI-level fact and TelegramUI has no test target. CoreList's
half (that it *does* offset rows by `insets.left` and shrink `contentWidth`) is locked by
`CoreVirtualListAnimationTests.testImmediateInsetsSetTopOffsetAndHorizontalFrames`.

## Content offsets and displayed item range

`visibleContentOffset()` / the bottom offset (reached through `settledContentOffsets()`) /
`updateVisibleItemRange(force:)` follow `ListViewImpl` (`ListView.swift:1380`, `:1412`, `:4673`).
They previously returned
`.known(rawEngineOffset)`, a constant `.known(0.0)`, and nothing — which broke real behavior, since
chat reads `abs(offset) <= 0.9` as "pinned to the newest message"
(`ChatHistoryListNode.swift:2425`) and short-circuits `scrollToEndOfHistory` on `value <= ulpOfOne`
(`:3690`).

- **`.known` is reserved for a loaded list edge.** `visibleContentOffset()` is `.known` only when the
  settled window starts at collection index 0, and its value is that row's distance from the top inset
  edge, **negated** (`0` = flush against `insets.top`, positive = scrolled away). The bottom offset is
  `.known` only when the window ends at the last entry, valued `maxY - (height - insets.bottom)` and
  **not** negated. Both then read as "how much content lies beyond that edge". An empty window is
  `.none`; a loaded window not reaching the edge is `.unknown`. `ListViewImpl`'s fold over
  removed-but-animating nodes above the top item has no analogue — CoreList departures live in the
  `exitOverlay`.
- **The bottom offset is not on the backend contract; `settledContentOffsets()` is.** Chat asks for it
  in exactly one place — the ad-insertion check at `ChatHistoryListNode.swift:2425`, which tests "am I
  pinned to the newest message" against `visibleContentOffset` and "does the content fill the screen"
  against the bottom one. Two facts follow. It has **no per-frame consumer at all**, so unlike its
  sibling there is no reading of it for which the mid-animation position is the question — settled is
  simply right. And the caller **compares the two**, so exposing them as separate members let them
  describe different moments of the same animation; one member returning both makes that
  unrepresentable. The thresholds stay in the chat layer — this fixes only the instant. `ListViewImpl`
  satisfies it by returning its own two values unchanged, so the default backend is bit-for-bit as
  before.
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
- **The two emission points want two different geometries, and this is the one place `settledFrame(of:)`
  is correct.** The scroll path reports `.presented` — it fires per frame while content moves, so "where
  is it now" is both question and answer, and a frame that is slightly off is corrected by the next one.
  The transaction point reports `.settled`, because it is reporting the *outcome* of the pass it just
  submitted: the pass has been applied but its animation has moved nothing yet, so the presented value
  there is the **pre-animation** position, and **no per-frame hook exists to correct it** —
  `onVisibleWindowChanged` fires only on user scrolls. `OffsetGeometry` in the backend selects between
  them; `visibleContentOffset()` (the protocol member, a question about now) stays `.presented`.

  Reporting presented at the transaction point is what made the scroll-to-bottom button misbehave under
  this backend: tapping it left the button on screen until the next manual scroll (the emission described
  where the jump *started*), and opening the keyboard or emoji panel at the bottom of a chat made the
  button appear — mid-inset-animation the emission read ~98pt against a settled `-0.0`, past the 40pt
  `minOffsetForNavigation` threshold in `ChatControllerLoadDisplayNode.swift:5393`. Both are single-shot
  errors that persist until the user drags.

  Settled is self-correcting in the one case where the two disagree for a reason — a transaction landing
  mid-fling, where settled is the flight's destination — because the next scroll frame re-reports
  presented, and the consumer's own alpha change is animated anyway.

**Why `ListViewImpl` needs no such distinction:** its model *is* its presented geometry.
`replayOperations` writes final item-node frames immediately and animates the layers additively, so the
single value it reports at transaction end is already the endpoint. It additionally updates the offset
per-frame during animations (`ListView.swift:4908`); CoreList animates through analytic CA tracks with no
per-frame host callback, which is exactly why the transaction emission must carry the endpoint rather
than a sample of the way there.

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

## Floating headers and avatars

Date separators and group avatars are `ListViewItemHeader`s adapted onto CoreList's
`CoreListAttachedItem` feature by `CoreListChatHistoryHeaders.swift`. The mapping is near-exact —
key = `header.id`, `combines(with:)` = `combinesWith(other:)`, `edge` = `stickDirection`,
`isFloating` = `isSticky` — because CoreList's attachment solve is `updateItemHeaders`' math, down
to the clamp order and its degenerate-band comment citing `ListView.swift:4019`/`:4032`.

Four things are load-bearing:

- **`.overlay`, never `.reservesSpace`.** Chat rows already carry the header's 34pt in their own
  `layoutInsets.top` (`layoutConstants.timestampHeaderHeight`), so reserving it again would double
  the gap. CoreList's reservation path is unused by chat.
- **The edge mapping is direct, not flipped.** `ListViewImpl(rotated: true)` and CoreList both lay
  index 0 at their own top and let the wrapper's π put it at the screen bottom, and the chat headers
  already resolve `stickDirection` against `chatIsRotated`. The header node carries its own π exactly
  as item nodes do, so it counter-rotates inside its host.
- **The stick factor and `updateFlashingOnScrolling` are one feature.** The date pill's alpha is
  `flashingOnScrolling || stickDistanceFactor < 0.5`, so reporting the factor without driving the
  flashing hides the pill for exactly as long as it is parked at the display edge — strictly worse
  than reporting neither. Flashing needs no CoreList seam: `onVisibleWindowChanged` is the
  `engine.onScroll` sink and ticks through momentum, so "no content movement for 0.3s" is the
  predicate `ListViewImpl`'s timer expresses (`ListView.swift:859`).
- **`attachedItems` is built once per entry**, not computed per access: `AttachmentRuns.pendingRuns`
  consults it per row during stacking as well as once per window build. It depends only on the item's
  headers, so a geometry-only pass cannot invalidate it.

The header host passes `leftInset: 0` because CoreList already frames an attachment at
`viewportInsets.left` with `contentWidth`, where `ListViewImpl` hands header nodes the full width plus
the real insets. The avatar lands identically; the date pill centres in the content width rather than
the full width — a deliberate divergence, visible only under a landscape safe-area inset.

Headers reach the backend from the **item**, via `ChatHistoryItemWithHeaders` in the `ChatMessageItem`
module, because CoreList computes runs before any row view exists. `ChatUnreadItem` and
`ChatReplyCountItem` conform for a specific reason: an item between messages that publishes no key
breaks the run, so an unread separator mid-day would float two pills for one date.

Two CoreList additions serve this: `loadedAttachmentViews` (the attachment sibling of
`loadedItemViews`, and the live set — departed runs are in the fade-out path) and
`AttachmentOffsetMap.stickDistance(atOffset:)`. See the CoreList `CLAUDE.md` gotcha for why the
attachment's frame and its stick distance deliberately solve at different offsets.

### Deferred

- **Topic headers** (`ChatMessageDateHeader` with a `separableThreadId`: space 3 carrying a
  `stackingId` in space 2). `updateItemHeaders` resolves these with a two-pass loop that nudges the
  stacked header off whichever header it most intersects (`ListView.swift:4036-4086`); CoreList has no
  stacking notion and one attachment key cannot express it. The adapter skips any header with a
  non-nil `stackingId`, so monoforum/thread separators do not render under this backend.
- **`ListViewItemNode.attachedHeaderNodes`** — the frame-intersection walk binding a header node to
  the row it most overlaps (`ListView.swift:4203-4242`). Its live consequence is
  `updateAttachedAvatarNodeIsHidden`, so the avatar stays visible while a sent message flies in the
  message-transition animation. `updateAttachedDateHeader(hasDate:hasPeer:)` needs nothing —
  `ChatMessageDateHeaderNodeImpl.updateItem` has an empty body. The avatar's selection-mode offset,
  which ListViewImpl also routes this way, is driven directly instead: the node reads
  `controllerInteraction.selectionState` itself, so the backend only has to say when to re-read.
- **Band trim for `stickOverInsets: false`.** `updateItemHeaders` shortens a non-`stickOverInsets`
  run's far bound by the last row's top inset (`ListView.swift:4278`); CoreList's band is the raw
  member frames, so the avatar rides roughly 34pt further before being pushed out.
- `.topEdge` stick direction (no chat header declares it; the adapter maps it to `.top`),
  `itemHeaderNodesAlpha` (chat never sets it), and `contributesToEdgeEffect` (nothing in the repo sets
  it — the one assignment is commented out).

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

**Jumping to the newest message is the edge case of the edge case.** A jump renders as a carousel:
two strips travelling rigidly, both carried by CoreList's one shared additive viewport track. A
departing row also joins a ghost block, and a ghost block normally attaches to a live boundary
witness so it stays glued to its neighbourhood — but a carousel's departed strip *has* no live
neighbourhood, and attaching one gives it a second vertical owner that walks it across the incoming
window. CoreList's `initialGhostWitness` proposes the head of the new collection when no predecessor
survives, which a wholesale history replace guarantees; that proposal resolves only when collection
index 0 is loaded, i.e. only when the destination is the newest message. Jump-to-reply and
jump-to-date leave it unloaded and stayed rigid, which is why the six verified behaviors above did
not catch it. Fixed CoreList-side (carousel passes attach no witness) and **runtime-verified
2026-07-31**; locked by `FullReplaceCarouselStripSeparationTests`, which covers both collection edges
(the far end had the same bug through `initialGhostWitness`'s `ordinal == newItems.count` branch), a
mid-collection control, and the mechanism itself. Note the shape this bug shares with the two below:
**a chat's jump differs from CoreList's synthetic fixtures precisely at the collection edges and at
the constant-identity rows, and all three times that difference was invisible to a green suite.**

**Verification status (2026-07-31): runtime-verified.** `CoreListDemoTests` covers resolver placement
against a far unloaded target, the direction fallback, carousel fade suppression from both sides, and
carousel strip separation at both collection edges (620 tests green). All six chat behaviors were
then confirmed on screen: scroll-to-unread (including
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

**A third of the same class surfaced only in use**, after those six passed: jumping to the newest
message dragged the outgoing window across the incoming one (see "Jumping to the newest message" in
"Scroll to item"). It never reached a screen during the sweep because the six behaviors exercise
jumps to *interior* targets, and the bug needs a destination window touching a collection edge. Two
things generalize. Enumerate the **edges** of whatever a host actually asks for — first index, last
index, empty, single-row — not just a representative interior case; the carousel suites all sat at
index 50. And when a symptom is a wrong *animation*, measure it instead of watching it: sample
`ListAnimationModel` for the two strips' screen bounds at several phases and assert the overlap, as
`FullReplaceCarouselStripSeparationTests` does. That turned an eyeballed "heavy intersection" into a
348pt number and a named owner (a ghost block's position track) in one 15ms run, with no app build.

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

   Not honoring `customAnimationTransition` is believed to be harmless, and the reasoning is worth
   keeping: the chat sets it in exactly one place — a floating topics **side panel** change
   (`ChatControllerNode.swift:2610-2615`) — and that same `containerLayoutUpdated` also puts the
   panel's width onto `listInsets.left` (`:2527`). `contentBounds` is independent of the panel
   (`:2049`, derived from `wrappingInsets`, which is only the iPad centring margin), so
   `contentWidth` genuinely changes in that pass and CoreList's own `contentWidthChangedInPass`
   already makes every row and attachment measure with the pass transition. `ListViewImpl` needs the
   explicit flag only because it never infers anything from geometry.
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
