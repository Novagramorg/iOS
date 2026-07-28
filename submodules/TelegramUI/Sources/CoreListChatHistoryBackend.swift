import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import Display
import CoreList
import ComponentFlow
import ComponentDisplayAdapters

// CoreList cannot depend on ComponentFlow — its Bazel target has no `deps` and its demo builds
// standalone in Xcode — so it carries a case-for-case copy of the transition value model. This is
// where the two meet.
//
// The one asymmetry is interpretation, not data: CoreList treats a zero duration as immediate, while
// ComponentFlow animates it. That difference is preserved here rather than smoothed over — a
// zero-duration CoreList transition maps to `.immediate`, so a caller converting one and handing it
// to UIKit gets the behavior CoreList meant.
extension ComponentTransition {
    init(_ transition: CoreListTransition) {
        switch transition.animation {
        case .none:
            self.init(animation: .none)
        case let .curve(duration, curve):
            guard !transition.isImmediate else {
                self.init(animation: .none)
                return
            }
            self.init(animation: .curve(duration: duration,
                                        curve: ComponentTransition.Animation.Curve(curve)))
        }
    }
}

private extension ComponentTransition.Animation.Curve {
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

// PoC alternative ChatHistoryListViewBackend backed by CoreVirtualListView (from the vendored
// CoreList module). Selected via the `coreListChatBackend` experimental flag; the default
// ListViewImpl path is unaffected.
//
// This is a proof of concept: it targets display / scroll / load-more only. Members outside that
// scope are safe stubs (no-ops / plain storage) and must never crash. Architecture, invariants, and
// deferred items: docs/chat/corelist-chat-history-backend.md
final class CoreListChatHistoryBackend: ASDisplayNode, ChatHistoryListViewBackend {
    // Matches ListViewImpl's rotation math: the wrapper (ChatHistoryListNodeImpl) applies the chat's
    // π rotation to itself, and each chat item node (ChatMessageItemView.init(rotated:)) applies its
    // own π rotation. Those two compose to upright content in a bottom-anchored inverted list (the
    // wrapper's π also flips stacking so index 0 = newest lands at the screen bottom, and flips touch
    // direction). The hosted CoreVirtualListView must therefore stay at IDENTITY — a third rotation
    // here renders the whole chat 180°-rotated. Stored for the makeListView contract; no transform.
    var rotated: Bool = false

    private let coreList: CoreVirtualListView

    // Ordered entry array: the source of truth for what CoreVirtualListView displays. Mirrors the
    // ListView transaction model (delete/insert/update over indices) with a stable serial per entry
    // used as the CoreListItem identity.
    private var entries: [CoreListEntryItem] = []
    private var currentSize: CGSize = .zero
    private var currentInsets: UIEdgeInsets = .zero
    
    private var nextStableVersion: Int = 1

    // MARK: - Narrow scroll-view accessors
    var bounces: Bool = true
    var contentHeight: CGFloat { return self.coreList.settledContentHeight }
    func setTopContentInset(_ inset: CGFloat) { self.currentInsets.top = inset }

    // MARK: - Config flags (plain storage; no behavior for the PoC)
    var scrollEnabled: Bool = true
    var preloadPages: Bool = true
    var experimentalSnapScrollToItem: Bool = false
    var stackFromBottom: Bool = false
    var enableExtractedBackgrounds: Bool = false
    var autoScrollWhenReordering: Bool = false
    var defaultToSynchronousTransactionWhileScrolling: Bool = false
    var verticalScrollIndicatorColor: UIColor? = nil
    var accessibilityPageScrolledString: ((String, String) -> String)? = nil
    var globalIgnoreScrollingEvents: Bool = false

    // MARK: - Geometry / range (real values populated in later tasks)
    var insets: UIEdgeInsets = .zero
    var visibleSize: CGSize = .zero
    var trackingOffset: CGFloat = 0.0
    var beganTrackingAtTopOrigin: Bool = false
    var displayedItemRange: ListViewDisplayedItemRange = ListViewDisplayedItemRange(loadedRange: nil, visibleRange: nil)
    // ListViewImpl keeps this mirror alongside displayedItemRange so updateVisibleItemRange can fire
    // displayedItemRangeChanged only on an actual change. Optional (not the empty range) so the very
    // first computation always counts as a change.
    private var internalDisplayedItemRange: ListViewDisplayedItemRange?
    var opaqueTransactionState: Any? = nil

    // MARK: - Callbacks the controller installs
    var displayedItemRangeChanged: (ListViewDisplayedItemRange, Any?) -> Void = { _, _ in }
    var visibleContentOffsetChanged: (ListViewVisibleContentOffset, ContainedViewLayoutTransition) -> Void = { _, _ in }
    var beganInteractiveDragging: (CGPoint) -> Void = { _ in }
    var endedInteractiveDragging: (CGPoint) -> Void = { _ in }
    var didEndScrolling: ((Bool) -> Void)? = nil
    var didEndScrollingWithOverscroll: (() -> Void)? = nil
    var updateFloatingHeaderOffset: ((CGFloat, ContainedViewLayoutTransition) -> Void)? = nil
    var didScrollWithOffset: ((CGFloat, ContainedViewLayoutTransition, ListViewItemNode?, Bool) -> Void)? = nil
    var addContentOffset: ((CGFloat, ListViewItemNode?) -> Void)? = nil
    var tapped: (() -> Void)? = nil
    var reorderItem: (Int, Int, Any?) -> Signal<Bool, NoError> = { _, _, _ in .single(false) }
    var generalScrollDirectionUpdated: (GeneralScrollDirection) -> Void = { _ in }
    var getCustomItemDeleteAnimationDuration: ((ListViewItemNode) -> Double?)? = nil

    // Non-copying, lazy view over the loaded item host views, in ascending item index. Backed by
    // CoreVirtualListView.loadedItemViews, which walks the settled window in place (a COW snapshot of
    // its buffer, so mutating the list mid-iteration is safe). This is the geometry-bearing level:
    // a host view sits in the CoreList hierarchy, whereas its hosted node's frame is host-local.
    // Only settled/loaded rows are visited — never off-screen entries or exit-overlay ghosts.
    private var itemNodeHostViews: some Sequence<CoreListNodeHostView> {
        self.coreList.loadedItemViews.lazy.compactMap { $0 as? CoreListNodeHostView }
    }

    // Non-copying, lazy view over the loaded chat item nodes — the CoreList analogue of
    // ListViewImpl.itemNodes. Maps each loaded host view to its hosted node, skipping any
    // not-yet-built. Lazy: no array is materialized.
    private var itemNodes: some Sequence<ListViewItemNode> {
        self.itemNodeHostViews.lazy.compactMap { $0.itemNode }
    }

    // The inset-reduced viewport band in the hosted CoreVirtualListView's coordinate space, shared by
    // forEachVisibleItemNode and itemNodeVisibleInsideInsets so the two predicates cannot drift.
    //
    // Uses currentSize/currentInsets, not the protocol-exposed visibleSize/insets:
    // setTopContentInset(_:) writes only currentInsets.top, so these are the values actually submitted
    // to applyChanges. Their orientation already matches — CoreList lays index 0 at its own top and
    // the wrapper's π maps that to the screen bottom, the same convention ListViewImpl(rotated: true)
    // uses, and both receive the same insets from the same transaction. Before the first
    // updateSizeAndInsets, currentSize is .zero and nothing is inside the band, which is also
    // ListViewImpl's behavior with a zero visibleSize.
    private var visibleBand: (top: CGFloat, bottom: CGFloat) {
        return (self.currentInsets.top, self.currentSize.height - self.currentInsets.bottom)
    }

    // The settled rect of a loaded row in the hosted CoreVirtualListView's coordinate space, or nil
    // when `node` is not currently loaded.
    //
    // The nil case IS the CoreList analogue of ListViewImpl's `node.index != nil` liveness guard:
    // ListViewItemNode.index is `public internal(set)` to Display, so a hosted node can never carry a
    // ListView index and is always nil. Absence from the loaded window is the equivalent test —
    // genuine departures move to the non-interactive exitOverlay and never appear here.
    //
    // Frames come from `presentedFrame(of:)` rather than a bare `convert`: it walks whatever ancestor
    // path the row currently has (`container` normally, `crossingOverlay` while a structural
    // transition carries it), so it cannot drift from what is rendered, AND it corrects for the
    // additive viewport animations. A bare `convert` composes ancestor MODEL bounds, and CoreList's
    // host layer is parked at a keyframe flight's DESTINATION for the whole fling — so it would report
    // every row hundreds of points from where the user sees it, for the entire momentum phase.
    // (ListViewImpl reads settled endpoints, but there model == presented; here it does not.)
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

    // The settled rect of the row at a collection index, or nil when that index is not loaded.
    private func loadedFrame(atIndex index: Int) -> CGRect? {
        guard let view = self.coreList.loadedItemView(at: index) else {
            return nil
        }
        return self.listFrame(of: view)
    }

    override init() {
        self.coreList = CoreVirtualListView(forEmbedding: .zero)
        super.init()
        // Force the ASDisplayNode's view to load eagerly. The composed ChatHistoryListNode wrapper
        // gates its history dequeue on isNodeLoaded, mirroring ListViewImpl's eager view load.
        let _ = self.view
        self.view.addSubview(self.coreList)

        // Report visible-range and content-offset changes so the history controller paginates and the
        // chat chrome tracks the scroll. Reading the callbacks off `self` at call time picks up
        // whatever the controller has since assigned.
        //
        // onVisibleWindowChanged fires on EVERY user-scroll frame, including momentum — handleUserScroll
        // is the engine.onScroll sink and calls it unconditionally, whether or not the window
        // rebalanced. So this covers all interactive scrolling; programmatic scrolls are covered at
        // transaction end instead (see chatHistoryTransaction).
        self.coreList.onVisibleWindowChanged = { [weak self] in
            guard let self else { return }
            self.updateVisibleItemRange(force: false)
            self.updateVisibleContentOffset(transition: .immediate)
        }
        self.coreList.onLoadedEdgeReached = { [weak self] _ in
            guard let self else { return }
            self.updateVisibleItemRange(force: false)
        }
        // Report interactive drag start to the history controller (parity with ListViewImpl's
        // beganInteractiveDragging). CoreVirtualListView doesn't surface the touch point and every
        // consumer ignores it, so pass .zero.
        self.coreList.willBeginDragging = { [weak self] in
            guard let self else { return }
            
            func cancelContextGestures(view: UIView) {
                if let gestureRecognizers = view.gestureRecognizers {
                    for gesture in gestureRecognizers {
                        if let gesture = gesture as? ContextGesture {
                            gesture.cancel()
                        }
                    }
                }
                for subview in view.subviews {
                    cancelContextGestures(view: subview)
                }
            }
            
            for itemNode in self.itemNodes {
                cancelContextGestures(view: itemNode.view)
            }
            
            self.beganInteractiveDragging(.zero)
        }
    }

    override func layout() {
        super.layout()
        // Transform-safe sizing: set bounds + center rather than frame while a rotation is applied.
        self.coreList.bounds = CGRect(origin: .zero, size: self.bounds.size)
        self.coreList.center = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
    }

    // MARK: - Transaction
    // Applies a ListView-style batch to the entry array (mirroring ListView's own ordering:
    // deletes first, then inserts, then updates), maps size/insets, and re-renders the full settled
    // set via CoreVirtualListView.applyChanges. Fine-grained insert/delete animations and
    // stationaryItemRange/customAnimationTransition are intentionally ignored for the PoC.
    func chatHistoryTransaction(
        deleteIndices: [ListViewDeleteItem],
        insertIndicesAndItems: [ChatHistoryListViewInsertItem],
        updateIndicesAndItems: [ChatHistoryListViewUpdateItem],
        options: ListViewDeleteAndInsertOptions,
        scrollToItem: ListViewScrollToItem?,
        additionalScrollDistance: CGFloat,
        updateSizeAndInsets: ListViewUpdateSizeAndInsets?,
        stationaryItemRange: (Int, Int)?,
        customAnimationTransition: ControlledTransition?,
        updateOpaqueState: Any?,
        completion: @escaping (ListViewDisplayedItemRange) -> Void
    ) {
        if let updateOpaqueState = updateOpaqueState {
            self.opaqueTransactionState = updateOpaqueState
        }

        var sizeChanged = false
        if let sizeAndInsets = updateSizeAndInsets {
            self.currentSize = sizeAndInsets.size
            self.currentInsets = sizeAndInsets.insets
            self.visibleSize = sizeAndInsets.size
            self.insets = sizeAndInsets.insets
            sizeChanged = true
        }

        let structurallyChanged = !deleteIndices.isEmpty || !insertIndicesAndItems.isEmpty || !updateIndicesAndItems.isEmpty
        if structurallyChanged {
            var updated = self.entries
            // Deletes: apply in descending index order so earlier removals don't shift later ones.
            for index in deleteIndices.map({ $0.index }).sorted(by: >) {
                if index >= 0 && index < updated.count {
                    updated.remove(at: index)
                }
            }
            // Inserts: apply in ascending index order; each carries its final index in the new array.
            for insert in insertIndicesAndItems.sorted(by: { $0.index < $1.index }) {
                let stableVersion = self.nextStableVersion
                self.nextStableVersion += 1
                let entry = CoreListEntryItem(stableId: insert.stableId, stableVersion: stableVersion, listItem: insert.item)
                let clamped = min(max(insert.index, 0), updated.count)
                updated.insert(entry, at: clamped)
            }
            // Updates: same index, keep the stable serial, swap the ListViewItem so content refreshes.
            for update in updateIndicesAndItems {
                if update.index >= 0 && update.index < updated.count {
                    let stableVersion = self.nextStableVersion
                    self.nextStableVersion += 1
                    updated[update.index] = CoreListEntryItem(stableId: update.stableId, stableVersion: stableVersion, listItem: update.item)
                }
            }
            // Neighbors are a function of final adjacency, so they are computed once the array has
            // settled rather than per-operation. Same index bases as ListView.neighbors(at:) — the
            // backend feeds items in ListView index order.
            for index in 0 ..< updated.count {
                updated[index].neighbors = ListViewItemNeighbors(
                    previous: index == 0 ? nil : updated[index - 1].listItem.neighborDescriptor,
                    next: index == updated.count - 1 ? nil : updated[index + 1].listItem.neighborDescriptor
                )
            }
            self.entries = updated
        }
        
        // Deferred: this drops scrollToItem.position/curve/animated/directionHint and anchors at
        // pointOffset 0.0 (CoreList's top → screen bottom under the wrapper's π), so mid-history
        // jump-to-reply / scroll-to-unread land at the bottom. See deferred item #1 in
        // docs/chat/corelist-chat-history-backend.md
        var scrollTo: (index: Int, pointOffset: CGFloat)?
        if let scrollToItem {
            scrollTo = (scrollToItem.index, 0.0)
        }

        // The applied animation and the reported transition are one value, so they cannot drift.
        // Mirrors ListViewImpl's own precedence: an animated scrollToItem wins, then a
        // size/inset update's curve, then an insertion animation.
        var transition: CoreListTransition = .immediate
        if let scrollToItem, scrollToItem.animated {
            transition = .spring(duration: 0.4)
        } else if let updateSizeAndInsets, updateSizeAndInsets.duration != 0.0 {
            switch updateSizeAndInsets.curve {
            case let .Spring(duration):
                transition = .spring(duration: duration)
            case let .Default(duration):
                // `.Default` carries an optional duration; ListViewImpl resolves it as
                // max(updateSizeAndInsets.duration, duration ?? 0.3), so mirror that rather than
                // inventing a different default.
                transition = .easeInOut(duration: max(updateSizeAndInsets.duration,
                                                      duration ?? 0.3))
            case let .Custom(duration, x1, y1, x2, y2):
                transition = .init(animation: .curve(duration: duration, curve: .custom(x1, y1, x2, y2)))
            }
        } else if options.contains(.AnimateInsertion) {
            transition = .spring(duration: 0.4)
        }

        if structurallyChanged || sizeChanged || scrollTo != nil {
            self.coreList.applyChanges(
                items: structurallyChanged ? self.entries : nil,
                newSize: self.currentSize == .zero ? nil : self.currentSize,
                newInsets: self.currentInsets,
                scrollTo: scrollTo,
                anchorMode: stationaryItemRange == nil ? .automatic : .preserveVisibleContent,
                transition: transition
            )
        }

        // Transaction end is where programmatic movement is reported: setOffset / applyShift /
        // setEdges are isProgrammatic-guarded in UIKitScrollEngine so a scrollTo fires no onScroll, and
        // the additive viewport track moves content with no engine offset change at all. Structural and
        // size/inset passes move content the same way. ListViewImpl likewise calls
        // updateVisibleContentOffset at its transaction points rather than relying on the scroll
        // callback.
        //
        // The transition mirrors the animation applied above. ContainedViewLayoutTransitionCurve has no
        // .easeOut, so the standard ease-out bezier approximates CoreList's .easeOut(0.3); this is
        // cosmetic, since consumers use the transition only to co-animate their own chrome. The
        // hardcoded duration goes away with deferred item #2 (derive the animation spec from `options`).
        let offsetTransition: ContainedViewLayoutTransition = ComponentTransition(transition).containedViewLayoutTransition
        self.updateVisibleItemRange(force: false)
        self.updateVisibleContentOffset(transition: offsetTransition)
        completion(self.displayedItemRange)
    }

    // Parity with ListViewImpl.immediateDisplayedItemRange (ListView.swift:4683). loadedRange is the
    // settled window's index span; visibleRange is the sub-span actually intersecting the viewport
    // band. Items are fed in ListView index order and the hosted view is π-counter-rotated, so indices
    // map straight through.
    //
    // Deliberate divergence: ListViewImpl's first-visible scan tests
    // `minY < visibleSize.height + insets.bottom` (ListView.swift:4711) while its last-visible scan
    // tests `minY < visibleSize.height - insets.bottom` (4723). The `+` looks like an upstream typo, so
    // both scans here use the symmetric `- insets.bottom` (i.e. `visibleBand.bottom`). The `- 10.0`
    // fully-visible tolerance is reproduced verbatim.
    private func immediateDisplayedItemRange() -> ListViewDisplayedItemRange {
        guard let range = self.coreList.loadedIndexRange else {
            return ListViewDisplayedItemRange(loadedRange: nil, visibleRange: nil)
        }
        let loadedRange = ListViewItemRange(firstIndex: range.first, lastIndex: range.last)
        let band = self.visibleBand

        var firstVisible: (index: Int, fullyVisible: Bool)?
        var lastVisibleIndex: Int?
        for entry in self.coreList.loadedItemEntries {
            let frame = self.listFrame(of: entry.view)
            if frame.maxY >= band.top && frame.minY < band.bottom {
                if firstVisible == nil {
                    firstVisible = (entry.index, frame.minY >= band.top - 10.0)
                }
                lastVisibleIndex = entry.index
            }
        }

        var visibleRange: ListViewVisibleItemRange?
        if let firstVisible = firstVisible, let lastVisibleIndex = lastVisibleIndex {
            visibleRange = ListViewVisibleItemRange(
                firstIndex: firstVisible.index,
                firstIndexFullyVisible: firstVisible.fullyVisible,
                lastIndex: lastVisibleIndex
            )
        }
        return ListViewDisplayedItemRange(loadedRange: loadedRange, visibleRange: visibleRange)
    }

    // Fires visibleContentOffsetChanged. ListViewImpl's namesake also fires
    // visibleBottomContentOffsetChanged, but ChatHistoryListViewBackend has no such member — chat
    // calls visibleBottomContentOffset() directly.
    private func updateVisibleContentOffset(transition: ContainedViewLayoutTransition) {
        self.visibleContentOffsetChanged(self.visibleContentOffset(), transition)
    }

    func addAfterTransactionsCompleted(_ f: @escaping () -> Void) { f() }
    // Parity with ListViewImpl.visibleContentOffset (ListView.swift:1380). `.known` is reserved for
    // when the list's TOP edge is loaded — i.e. the settled window starts at collection index 0 — and
    // the value is that row's distance from the top inset edge, negated: 0 means index 0 sits flush
    // against insets.top, positive means scrolled away from it. An empty window is `.none`; a loaded
    // window that does not reach index 0 is `.unknown`.
    //
    // Never fabricate `.known`: chat reads `abs(offset) <= 0.9` as "pinned to the newest message"
    // (ChatHistoryListNode.swift:2425) and short-circuits scrollToEndOfHistory on
    // `value <= ulpOfOne` (3690).
    //
    // ListViewImpl also folds in the minY of removed-but-still-animating nodes above the top item;
    // that has no analogue here, because CoreList departures live in the exitOverlay and never appear
    // in the loaded window.
    func visibleContentOffset() -> ListViewVisibleContentOffset {
        guard let range = self.coreList.loadedIndexRange else {
            return .none
        }
        guard range.first == 0, let frame = self.loadedFrame(atIndex: 0) else {
            return .unknown
        }
        return .known(-(frame.minY - self.currentInsets.top))
    }

    // Parity with ListViewImpl.visibleBottomContentOffset (ListView.swift:1412): `.known` only when the
    // list's BOTTOM edge is loaded (the window ends at the last entry). Note this one is NOT negated —
    // both offsets read as "how much content lies beyond that visible edge", positive = more hidden.
    func visibleBottomContentOffset() -> ListViewVisibleContentOffset {
        guard let range = self.coreList.loadedIndexRange else {
            return .none
        }
        guard range.last == self.entries.count - 1, let frame = self.loadedFrame(atIndex: range.last) else {
            return .unknown
        }
        return .known(frame.maxY - (self.currentSize.height - self.currentInsets.bottom))
    }
    func transferVelocity(_ velocity: CGFloat) {}
    func resetScrolledToItem() {}

    // ListViewImpl guards each node on `index != nil` to skip removed-but-still-animating nodes.
    // CoreList needs no analogue: genuine departures are transferred to the non-interactive
    // exitOverlay as ghost blocks and are never returned by loadedItemViews, so every loaded row is
    // live. The only exclusion is a host view whose node has not been built yet, which `itemNodes`
    // already performs.
    func forEachItemNode(_ f: (ASDisplayNode) -> Void) {
        for itemNode in self.itemNodes {
            f(itemNode)
        }
    }

    // Mirrors ListViewImpl.forEachVisibleItemNode: intersect each loaded row against the
    // inset-reduced viewport band. CoreList's loaded window is viewport *plus preload margin*, so
    // "loaded" is not "visible" — over-reporting here would play sound for off-screen video and fire
    // read tracking / unseen-reaction animations for messages the user cannot see.
    //
    // Geometry comes from `listFrame(of:)`, i.e. CoreList's `presentedFrame(of:)`: the frames must be
    // where the rows ARE, not their settled endpoints. Reporting settled geometry mid-fling would fire
    // read tracking and unseen-reaction animations for whatever is visible at the flight's DESTINATION,
    // since the host layer is parked there for the flight's whole duration.
    //
    // See `visibleBand` for why the band reads currentSize/currentInsets.
    func forEachVisibleItemNode(_ f: (ASDisplayNode) -> Void) {
        let band = self.visibleBand
        for hostView in self.itemNodeHostViews {
            guard let itemNode = hostView.itemNode else {
                continue
            }
            let frame = self.listFrame(of: hostView)
            if frame.maxY > band.top && frame.minY < band.bottom {
                f(itemNode)
            }
        }
    }

    // Same set as forEachItemNode, in the same ascending-index order (which ListViewImpl's callers
    // depend on), stopping at the first `f` returning false.
    func enumerateItemNodes(_ f: (ASDisplayNode) -> Bool) {
        for itemNode in self.itemNodes {
            if !f(itemNode) {
                break
            }
        }
    }
    func forEachItemHeaderNode(_ f: (ListViewItemHeaderNode) -> Void) {}

    func ensureItemNodeVisible(_ node: ListViewItemNode, animated: Bool, overflow: CGFloat, allowIntersection: Bool, atTop: Bool, curve: ListViewAnimationCurve) {}

    // Parity with ListViewImpl.updateVisibleItemRange (ListView.swift:4673): recompute, and fire
    // displayedItemRangeChanged only when the range actually changed (or when forced). This is the one
    // place displayedItemRange is written. The mirror is committed before the callback fires, so a
    // callback that triggers another update sees the settled value instead of recursing.
    func updateVisibleItemRange(force: Bool) {
        let currentRange = self.immediateDisplayedItemRange()
        if currentRange != self.internalDisplayedItemRange || force {
            self.displayedItemRange = currentRange
            self.internalDisplayedItemRange = currentRange
            self.displayedItemRangeChanged(currentRange, self.opaqueTransactionState)
        }
    }
    // ListViewImpl scans its item nodes for `index == index`; hosted nodes can never carry a ListView
    // index, so resolve through CoreList, which owns activeWindow and is the authority on the
    // index ↔ view mapping. `index` is in the same space as `self.entries` — which is also the space
    // the one caller uses (ChatHistoryListNode's ad-message anchors, built as
    // `filteredEntries.count - 1 - i`).
    func itemNodeAtIndex(_ index: Int) -> ListViewItemNode? {
        return (self.coreList.loadedItemView(at: index) as? CoreListNodeHostView)?.itemNode
    }

    // Parity with ListViewImpl's `node.frame.minY - insets.top`.
    //
    // The convention is load-bearing: this value is persisted as
    // ChatInterfaceHistoryScrollState.relativeOffset and restored as
    // ListViewScrollToItem(position: .top(offset)), which ListViewImpl resolves to
    // `frame.minY == insets.top + offset` — the exact inverse. CoreList's scrollTo pointOffset uses
    // the identical convention (screen target = viewportInsets.top + pointOffset), so no unit
    // conversion is needed here. Note the restore path still discards the offset until deferred item
    // #1 (scrollTo fidelity) is fixed, so only the write side is live today.
    func itemNodeRelativeOffset(_ node: ListViewItemNode) -> CGFloat? {
        guard let frame = self.loadedFrame(of: node) else {
            return nil
        }
        return frame.minY - self.currentInsets.top
    }

    // Same predicate as forEachVisibleItemNode's filter, via the shared band.
    func itemNodeVisibleInsideInsets(_ node: ListViewItemNode) -> Bool {
        guard let frame = self.loadedFrame(of: node) else {
            return false
        }
        let band = self.visibleBand
        return frame.maxY > band.top && frame.minY < band.bottom
    }
    func isStrictlyScrolledToPinToEdgeItem() -> Bool { return false }
    func scrollWithDirection(_ direction: ListViewScrollDirection, distance: CGFloat) -> Bool { return false }
}

// A CoreListItem wrapping a ListViewItem.
// `listItem` is the value content (a fresh instance on update). Reused views reconcile via apply(to:).
private final class CoreListEntryItem: CoreListItem {
    let stableId: UInt64
    let stableVersion: Int
    let listItem: ListViewItem
    // Descriptors published by the adjacent entries. Compared in isEqual(to:) so a row re-applies
    // when a neighbor changed, and passed into layout so merge/date decisions are correct.
    var neighbors: ListViewItemNeighbors

    var identity: AnyHashable { AnyHashable(self.stableId) }
    
    init(stableId: UInt64, stableVersion: Int, listItem: ListViewItem, neighbors: ListViewItemNeighbors = .none) {
        self.stableId = stableId
        self.stableVersion = stableVersion
        self.listItem = listItem
        self.neighbors = neighbors
    }

    func view() -> UIView & CoreListItemView {
        return CoreListNodeHostView(listItem: self.listItem, neighbors: self.neighbors)
    }

    // Content equality: the engine matches rows by `identity` (= stableId); this additionally compares
    // `stableVersion` so a same-stableId entry whose content was swapped (a new stableVersion) is not
    // equal and reconfigures its reused view.
    func isEqual(to other: CoreListItem) -> Bool {
        guard let other = other as? CoreListEntryItem else {
            return false
        }
        if other.stableId != self.stableId {
            return false
        }
        if other.stableVersion != self.stableVersion {
            return false
        }
        if other.neighbors != self.neighbors {
            return false
        }
        return true
    }

    func apply(to view: UIView & CoreListItemView, transition: CoreListTransition) {
        (view as? CoreListNodeHostView)?.setListItem(self.listItem,
                                                     neighbors: self.neighbors,
                                                     transition: transition)
    }
}

// Hosts a ListViewItemNode's view inside CoreVirtualListView
private final class CoreListNodeHostView: UIView, CoreListItemView {
    private var listItem: ListViewItem
    private var neighbors: ListViewItemNeighbors
    fileprivate private(set) var itemNode: ListViewItemNode?
    private var lastWidth: CGFloat = -1.0
    private var lastHeight: CGFloat = 0.0
    private var contentDirty: Bool = true
    /// The transition from the most recent `setListItem`, held for the layout that follows.
    private var pendingTransition: CoreListTransition = .immediate

    var onContentDidChange: ((_ animated: Bool) -> Void)? = nil

    init(listItem: ListViewItem, neighbors: ListViewItemNeighbors) {
        self.listItem = listItem
        self.neighbors = neighbors
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setListItem(_ item: ListViewItem,
                     neighbors: ListViewItemNeighbors,
                     transition: CoreListTransition) {
        self.listItem = item
        self.neighbors = neighbors
        self.pendingTransition = transition
        self.contentDirty = true
    }

    func update(width: CGFloat, transition: CoreListTransition) -> CGFloat {
        // Deferred: map `transition` onto ListViewItemUpdateAnimation so a reconciled chat row
        // animates its internal layout. Today the node relayouts with .None and the row's outer
        // geometry animates via ListAnimationModel, which is the pre-existing behavior.
        _ = transition
        _ = self.pendingTransition
        if self.itemNode == nil || self.contentDirty || abs(width - self.lastWidth) > 0.5 {
            self.rebuild(width: width)
        }
        if let itemNode = self.itemNode {
            itemNode.frame = CGRect(x: 0.0, y: 0.0, width: width, height: self.lastHeight)
        }
        return self.lastHeight
    }

    private func rebuild(width: CGFloat) {
        let params = ListViewItemLayoutParams(width: width, leftInset: 0.0, rightInset: 0.0, availableHeight: .greatestFiniteMagnitude, isStandalone: false)
        
        if let itemNode = self.itemNode {
            var layoutAndApply: (ListViewItemNodeLayout, (ListViewItemApply) -> Void)?
            self.listItem.updateNode(async: { f in f() }, node: { itemNode }, params: params, neighbors: self.neighbors, animation: ListViewItemUpdateAnimation.None, completion: { nodeLayout, nodeApply in
                layoutAndApply = (nodeLayout, nodeApply)
            })
            if let (nodeLayout, nodeApply) = layoutAndApply {
                let height = nodeLayout.contentSize.height + nodeLayout.insets.top + nodeLayout.insets.bottom
                nodeApply(ListViewItemApply(isOnScreen: true))
                itemNode.frame = CGRect(x: 0.0, y: 0.0, width: width, height: self.lastHeight)
                self.lastHeight = height
            } else {
                print("[CoreList] async-only item, no synchronous node: \(type(of: self.listItem))")
                self.lastHeight = 0.0
            }
        } else {
            var resolvedNode: ListViewItemNode?
            var applyClosure: (() -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void))?
            self.listItem.nodeConfiguredForParams(async: { f in f() }, params: params, synchronousLoads: true, neighbors: self.neighbors, completion: { node, apply in
                resolvedNode = node
                applyClosure = apply
            })
            if let node = resolvedNode {
                if let applyClosure {
                    let (_, applyFn) = applyClosure()
                    applyFn(ListViewItemApply(isOnScreen: true))
                }
                let height = node.contentSize.height + node.insets.top + node.insets.bottom
                self.itemNode = node
                self.addSubview(node.view)
                self.lastHeight = height
            } else {
                print("[CoreList] async-only item, no synchronous node: \(type(of: listItem))")
                self.lastHeight = 0.0
            }
        }
        self.lastWidth = width
        self.contentDirty = false
    }
}
