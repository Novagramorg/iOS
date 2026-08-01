import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import Display
import CoreList
import ComponentFlow
import ComponentDisplayAdapters
import ChatMessageItem
import ChatMessageItemImpl

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

    // Internal rather than private: the header adapter in CoreListChatHistoryHeaders.swift
    // enumerates attachments through it. Still invisible outside TelegramUI.
    let coreList: CoreVirtualListView

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
    var displayedItemRange: ListViewDisplayedItemRange = ListViewDisplayedItemRange(loadedRange: nil, visibleRange: nil)
    // ListViewImpl keeps this mirror alongside displayedItemRange so updateVisibleItemRange can fire
    // displayedItemRangeChanged only on an actual change. Optional (not the empty range) so the very
    // first computation always counts as a change.
    private var internalDisplayedItemRange: ListViewDisplayedItemRange?
    var opaqueTransactionState: Any? = nil

    // MARK: - Interactive-drag origin
    //
    // Parity with `ListViewImpl.didInteractivelyDragFromTopOrigin`: the current-or-most-recent gesture was
    // a real drag — content actually moved — that began pinned to the newest-message edge. Its one
    // consumer is the chat's keyboard-dismissal path, which reads it to decide whether to snap back to the
    // newest message once the keyboard is gone (`ChatControllerNode.swift:2453`). Both halves reset on
    // drag BEGIN, never on drag end, so the value survives to the layout pass that reads it — as in
    // ListViewImpl, where `trackingOffset` is reset only in the pan's `.began`.
    private var beganDragPinnedToNewestEdge = false
    private var didMoveContentDuringDrag = false

    var didInteractivelyDragFromTopOrigin: Bool {
        return self.beganDragPinnedToNewestEdge && self.didMoveContentDuringDrag
    }

    // MARK: - Tracking
    //
    // Parity with `ListViewImpl.isTracking`: a finger is on the list right now. Unlike the two flags
    // above — which deliberately survive drag end so a later layout pass can read them — this one is
    // strictly the finger-down interval, and it is false throughout the momentum phase (ListViewImpl
    // keeps that distinction too: momentum is `isDeceleratingAfterTracking`, and the inset-compensation
    // suppression below checks only `isTracking`).
    //
    // Its consumer is that suppression. The chat's insets change WHILE the list is being dragged, by the
    // same finger: `Window1`'s `WindowPanRecognizer` implements interactive system-keyboard dismissal
    // (`Display/Source/WindowContent.swift:1332`) and its delegate returns true from
    // `shouldRecognizeSimultaneouslyWith` (`WindowContent.swift:254`), so one downward drag both scrolls
    // the history and shrinks `inputHeight` frame by frame. Each frame therefore reaches the list twice —
    // once as a scroll delta, once as a smaller bottom inset — and compensating the inset change on top of
    // the scroll moves content by double the finger's travel. ListViewImpl answers this by zeroing
    // `offsetFix` while tracking (`Display/Source/ListView.swift:3276`).
    //
    // Sampled at drag BEGIN rather than finger-down, which is the same approximation
    // `beganDragPinnedToNewestEdge` makes above and for the same reason: drag-begin is the earliest hook
    // the scroll-engine seam has. The residual is bounded by the pan recognizer's threshold and is not
    // visible, because in that pre-threshold window the content is not yet scrolling — so the inset
    // compensation is the only thing moving it, in the same direction and by the same amount the finger
    // would have. The handover is continuous rather than a step.
    private var isTracking = false

    // Mirror for updateAvatarSelectionState (CoreListChatHistoryHeaders.swift). Optional so the
    // first push can be un-animated.
    var appliedSelectionStateIsActive: Bool?

    // Backing state for the header flashing driver in CoreListChatHistoryHeaders.swift.
    // `SwiftSignalKit.Timer` explicitly: `Timer` alone is ambiguous here, since Foundation's is in
    // scope too.
    var headerFlashTimer: SwiftSignalKit.Timer?
    var isFlashingHeaders = false

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

    // The collection index of a loaded row, or nil when `node` is not currently loaded.
    //
    // ListViewImpl's ensureItemNodeVisible opens with `if let index = node.index`, which cannot work
    // here: ListViewItemNode.index is `public internal(set)` to Display, so a hosted node never
    // carries one. Resolving through CoreList's loadedItemEntries — the (index, view) sibling of
    // loadedItemViews — is the equivalent, and its nil case is the same liveness guard
    // loadedFrame(of:) relies on: genuine departures move to the exitOverlay and never appear here.
    private func loadedIndex(of node: ListViewItemNode) -> Int? {
        for entry in self.coreList.loadedItemEntries {
            if (entry.view as? CoreListNodeHostView)?.itemNode === node {
                return entry.index
            }
        }
        return nil
    }

    // ListViewImpl's scroll-position arithmetic (Display/Source/ListView.swift:3166-3204),
    // translated from "a delta added to every frame" into "the target row's minY, minus insets.top"
    // — which is what CoreList's resolver returns (its projected screen target for the row's minY is
    // viewportInsets.top + the returned value).
    //
    // Runs inside CoreList's mutation pass, at the moment the anchor row has been measured. It reads
    // geometry only: never mutate the entry array or re-enter a transaction from here.
    //
    // Geometry comes from currentSize/currentInsets, which chatHistoryTransaction has already
    // updated to this pass's values before calling applyChanges — the same values CoreList is
    // resolving against, since they are what was submitted as newSize/newInsets. This diverges from
    // ListViewImpl, which reads the OLD self.insets in this branch (note the commented-out
    // `// updateSizeAndInsets?.insets ?? self.insets` at ListView.swift:3143) and applies the
    // size/inset change separately afterwards.
    private func pointOffset(for position: ListViewScrollPosition,
                             index: Int,
                             height: CGFloat,
                             view: UIView & CoreListItemView) -> CGFloat {
        let node = (view as? CoreListNodeHostView)?.itemNode
        // ChatUnreadItem and ChatReplyCountItem set (top: 5, bottom: 6) — the unread separator is a
        // primary scroll target, so this is load-bearing rather than a rounding detail.
        let scrollPositioningInsets = node?.scrollPositioningInsets ?? UIEdgeInsets()
        let viewportHeight = self.currentSize.height
        let insetTop = self.currentInsets.top
        let insetBottom = self.currentInsets.bottom
        let contentAreaHeight = viewportHeight - insetTop - insetBottom

        switch position {
        case let .top(additionalOffset):
            return additionalOffset + scrollPositioningInsets.top
        case let .bottom(additionalOffset):
            let targetMaxY = (viewportHeight - insetBottom)
                + scrollPositioningInsets.bottom
                + additionalOffset
            return targetMaxY - height - insetTop
        case let .center(overflow):
            if height <= contentAreaHeight + CGFloat.ulpOfOne {
                return floor((contentAreaHeight - height) / 2.0)
            }
            switch overflow {
            case .top:
                return 0.0
            case .bottom:
                return (viewportHeight - insetBottom) - height - insetTop
            case let .custom(getOverflow):
                guard let node else {
                    return 0.0
                }
                let targetMaxY = (viewportHeight - insetBottom)
                    + node.insets.top
                    + getOverflow(node)
                    - floor(contentAreaHeight * 0.5)
                return targetMaxY - height - insetTop
            }
        case .visible:
            // `.visible` is the one position that depends on where the row already is, so it needs
            // the row loaded. It is produced only by ensureItemNodeVisible — which always holds a
            // loaded node — and by the experimentalSnapScrollToItem path, which nothing in chat ever
            // enables. An unloaded target therefore falls back to center-with-top-overflow.
            guard let frame = self.loadedFrame(atIndex: index) else {
                return height <= contentAreaHeight + CGFloat.ulpOfOne
                    ? floor((contentAreaHeight - height) / 2.0)
                    : 0.0
            }
            if frame.maxY > viewportHeight - insetBottom {
                let targetMaxY = (viewportHeight - insetBottom) + scrollPositioningInsets.bottom
                return targetMaxY - height - insetTop
            }
            if height <= contentAreaHeight + CGFloat.ulpOfOne, frame.minY < insetTop {
                return -scrollPositioningInsets.top
            }
            return frame.minY - insetTop
        }
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
            // Reaching here means USER-driven content movement, which is what makes it the analogue of
            // ListViewImpl accumulating a non-zero `trackingOffset`: `handleUserScroll` is the
            // `engine.onScroll` sink, programmatic offset writes are isProgrammatic-guarded, and the
            // additive viewport track moves content with no engine offset change at all.
            //
            // It also fires during momentum, where ListViewImpl has stopped accumulating (`isTracking` is
            // false by then). Harmless: momentum only follows a drag that already moved content, so the
            // flag is set either way.
            self.didMoveContentDuringDrag = true
            self.noteHeaderFlashingActivity()
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

            // Sample the drag's origin before it can move anything. ListViewImpl samples in
            // `touchesBegan` — finger down — whereas CoreVirtualListView's earliest hook is drag-begin,
            // which fires after the pan recognizer's own threshold, i.e. a few points of movement. The
            // 10pt tolerance (verbatim from ListView.swift:4959) is wide enough to absorb exactly that,
            // which is plausibly why it is 10 and not 0.
            if case let .known(value) = self.visibleContentOffset(), value <= 10.0 {
                self.beganDragPinnedToNewestEdge = true
            } else {
                self.beganDragPinnedToNewestEdge = false
            }
            self.didMoveContentDuringDrag = false
            self.isTracking = true
            self.noteHeaderFlashingActivity()

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
            self.cancelAttachmentContextGestures()

            self.beganInteractiveDragging(.zero)
        }
        // Close the tracking interval. Fires on `.ended` AND `.cancelled`, so a drag torn down by a
        // competing recognizer cannot leave the flag stuck on and permanently suppress inset compensation.
        //
        // Deliberately does NOT call `self.endedInteractiveDragging`: that callback drives the
        // overscroll-to-open-next-channel behavior, which is a separate unimplemented item rather than
        // something to switch on as a side effect of this hook becoming available.
        self.coreList.didEndDragging = { [weak self] in
            guard let self else { return }
            self.isTracking = false
        }
    }

    deinit {
        // The timer holds `self` weakly, so this is not a cycle — but a fired timer on a dead
        // backend is still wasted work on the main run loop.
        self.headerFlashTimer?.invalidate()
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
        maintainsUnreadItemAlignment: Bool,
        updateOpaqueState: Any?,
        completion: @escaping (ListViewDisplayedItemRange) -> Void
    ) {
        if let updateOpaqueState = updateOpaqueState {
            self.opaqueTransactionState = updateOpaqueState
        }

        // Evaluated HERE, before the new insets are installed below, because the predicate is "is the
        // separator sitting exactly where the previous pass pinned it" and that is a question about
        // the OLD geometry. Same reason `compensatesInsetChange` is read at this call site rather
        // than inside CoreList: the value must be the one that held when the transaction was
        // submitted.
        //
        // Unlike ListViewImpl, which cannot compose a scroll with an inset change and so re-issues
        // the re-pin as a second transaction from its completion, `applyChanges` takes `newInsets`
        // and `scrollTo` together — so this rides the same pass as one movement, with no
        // intermediate frame and a single animation.
        var effectiveScrollToItem = scrollToItem
        if maintainsUnreadItemAlignment,
           effectiveScrollToItem == nil,
           let sizeAndInsets = updateSizeAndInsets,
           sizeAndInsets.insets.bottom != self.currentInsets.bottom {
            let pinnedMaxY = self.currentSize.height - self.currentInsets.bottom + 6.0
            for entry in self.coreList.loadedItemEntries {
                guard let hostView = entry.view as? CoreListNodeHostView,
                      let itemNode = hostView.itemNode,
                      itemNode is ChatUnreadItemNode else {
                    continue
                }
                if abs(self.listFrame(of: hostView).maxY - pinnedMaxY) < 1.0 {
                    effectiveScrollToItem = ListViewScrollToItem(
                        index: entry.index,
                        position: .bottom(0.0),
                        animated: sizeAndInsets.duration != 0.0,
                        curve: sizeAndInsets.curve,
                        directionHint: .Up
                    )
                    break
                }
            }
        }
        let scrollToItem = effectiveScrollToItem

        var sizeChanged = false
        if let sizeAndInsets = updateSizeAndInsets, (sizeAndInsets.size != self.currentSize || sizeAndInsets.insets != self.currentInsets) {
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
                let entry = CoreListEntryItem(stableId: insert.stableId, stableVersion: stableVersion, listItem: insert.item, backend: self)
                let clamped = min(max(insert.index, 0), updated.count)
                updated.insert(entry, at: clamped)
            }
            // Updates: same index, keep the stable serial, swap the ListViewItem so content refreshes.
            for update in updateIndicesAndItems {
                if update.index >= 0 && update.index < updated.count {
                    let stableVersion = self.nextStableVersion
                    self.nextStableVersion += 1
                    updated[update.index] = CoreListEntryItem(stableId: update.stableId, stableVersion: stableVersion, listItem: update.item, backend: self)
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
        
        // The row's placement can depend on its own measured height (bottom-align, center,
        // make-visible), and on a history jump the target is not loaded — the entries array was
        // replaced wholesale — so the backend cannot measure it. CoreList measures the anchor as the
        // first act of its window build and calls back here at that point. See pointOffset(for:...).
        var scrollTo: CoreListScrollTarget?
        if let scrollToItem, !self.entries.isEmpty {
            // buildWindow traps on an out-of-range anchor; ListViewImpl instead no-ops silently when
            // no node carries the index, so clamp rather than crash on a stale index.
            let index = min(max(scrollToItem.index, 0), self.entries.count - 1)
            let position = scrollToItem.position
            // ListViewImpl's `.Down` pins the old content's bottom to the new content's top, so the
            // new content arrives from higher indices — CoreList's `.forward`. Chat's index space is
            // reversed (0 = newest), which is why ChatHistoryViewForLocation.swift:59 picks `.Down`
            // for an older target. The hint only decides a travel CoreList cannot witness itself.
            let direction: CoreListScrollTarget.Direction
            switch scrollToItem.directionHint {
            case .Down:
                direction = .forward
            case .Up:
                direction = .backward
            }
            scrollTo = CoreListScrollTarget(index: index, direction: direction) { [weak self] height, view in
                guard let self else {
                    return 0.0
                }
                return self.pointOffset(for: position, index: index, height: height, view: view)
            }
        }

        // The applied animation and the reported transition are one value, so they cannot drift.
        // Mirrors ListViewImpl's own precedence: an animated scrollToItem wins, then a
        // size/inset update's curve, then an insertion animation.
        var transition: CoreListTransition = .immediate
        if let scrollToItem, scrollToItem.animated {
            // ListViewImpl's own switch (Display/Source/ListView.swift:3611-3618) rather than one
            // flat spring; `.Default` resolves a nil duration to 0.3 exactly as it does there. A
            // zero duration lands immediate, because CoreList reads 0 as immediate.
            switch scrollToItem.curve {
            case let .Spring(duration):
                transition = .spring(duration: duration)
            case let .Default(duration):
                transition = .easeInOut(duration: duration ?? 0.3)
            case let .Custom(duration, x1, y1, x2, y2):
                transition = .init(animation: .curve(duration: duration,
                                                     curve: .custom(x1, y1, x2, y2)))
            }
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

        // `additionalScrollDistance` displaces content by a caller-chosen delta in the same pass that
        // re-insets it — positive moves content DOWN, composing with the inset compensation rather
        // than replacing it. ListViewImpl folds it into the very same `offsetFix`
        // (Display/Source/ListView.swift:3275) and CoreList folds it into the same anchor projection,
        // so both animate it on the pass curve as one movement.
        //
        // Two deliberate divergences from ListViewImpl, neither reachable from the chat's producer:
        //   • ListViewImpl applies the delta ONLY inside the branch where the size or insets genuinely
        //     changed, and silently drops it otherwise (the addend sits inside
        //     `if let updateSizeAndInsets` at ListView.swift:3257). Here a non-zero delta always moves
        //     content, which is what the parameter means. Every real producer pairs it with an
        //     `updateSizeAndInsets` that does change geometry, so the two agree in practice.
        //   • The halt for a non-zero delta lives inside `applyChanges`, so it needs the pass to run;
        //     ListViewImpl halts before deciding anything (ListView.swift:3238). Same reachability
        //     argument — a delta with nothing else to do would be a layout pass that changes nothing.
        //
        // NOTE the chat never sends a non-zero value: `ChatControllerNode.containerLayoutUpdated`
        // declares `let additionalScrollDistance: CGFloat = 0.0` (ChatControllerNode.swift:2451) and has
        // since the first commit, and `ChatHistoryListNodeImpl.updateLayout` zeroes it again whenever
        // the live sibling `scrollToTop` is set. This exists so the two backends answer a non-zero value
        // the same way if one is ever wired up — it is not load-bearing today.

        // An inset change arriving mid-drag was produced by the drag itself (see `isTracking`), so its
        // compensation would double the finger's travel. Suppressing it leaves the scroll as the single
        // owner of the movement — ListViewImpl's `offsetFix = 0.0` while tracking
        // (Display/Source/ListView.swift:3276). The insets themselves still apply, so the viewport band,
        // the load band, content width and the loaded-top pin all move: at the newest-message edge the pin
        // keeps index 0 on the inset edge, which is how the bottom of the chat still follows the keyboard
        // down under suppression. Note the read happens HERE rather than inside CoreList, so the value is
        // the one that held when this transaction was submitted even if `applyChanges` defers it past a
        // re-entrant pass.
        //
        // Cancelling the compensation with `additionalScrollDistance: -topInsetDelta` would look
        // equivalent and is not: a non-zero distance halts momentum and opts the pass out of
        // `pinsLoadedTop`, so the newest message would stop tracking the inset edge — the one case that
        // must keep working.
        let compensatesInsetChange = !self.isTracking
        if structurallyChanged || sizeChanged || scrollTo != nil || additionalScrollDistance != 0.0 {
            self.coreList.applyChanges(
                items: structurallyChanged ? self.entries : nil,
                newSize: self.currentSize == .zero ? nil : self.currentSize,
                newInsets: self.currentInsets,
                scrollTo: scrollTo,
                additionalScrollDistance: additionalScrollDistance,
                anchorMode: stationaryItemRange == nil ? .automatic : .preserveVisibleContent,
                compensatesInsetChange: compensatesInsetChange,
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
        // cosmetic, since consumers use the transition only to co-animate their own chrome.
        let offsetTransition: ContainedViewLayoutTransition = ComponentTransition(transition).containedViewLayoutTransition
        self.updateVisibleItemRange(force: false)
        self.updateVisibleContentOffset(transition: offsetTransition)
        self.updateAvatarSelectionState()
        self.pushHeaderFlashingState(animated: false)
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
    // Its two chat consumers are the live theme/presentation update
    // (ChatHistoryListNode.swift:2649) and the chat-loading fade-in (:4418). Backed by CoreList's
    // own live attachment set — see itemHeaderNodes in CoreListChatHistoryHeaders.swift.
    func forEachItemHeaderNode(_ f: (ListViewItemHeaderNode) -> Void) {
        for node in self.itemHeaderNodes {
            f(node)
        }
    }

    // ListViewImpl's own body (Display/Source/ListView.swift:5159-5199) with four substitutions: the
    // index comes from loadedIndex(of:) because a hosted node carries no ListView index; the node's
    // frame comes from loadedFrame(of:), which is list-space and presented rather than host-local;
    // apparentHeight is that rect's height; and the geometry is currentSize/currentInsets.
    //
    // Every branch issues its scroll through chatHistoryTransaction, exactly as ListViewImpl issues
    // its own through self.transaction — one code path, and the "already visible, do nothing" shape
    // is preserved by simply not reaching a branch.
    func ensureItemNodeVisible(_ node: ListViewItemNode, animated: Bool, overflow: CGFloat, allowIntersection: Bool, atTop: Bool, curve: ListViewAnimationCurve) {
        guard let index = self.loadedIndex(of: node), let frame = self.loadedFrame(of: node) else {
            return
        }
        let viewportHeight = self.currentSize.height
        let insetTop = self.currentInsets.top
        let insetBottom = self.currentInsets.bottom

        func scroll(to position: ListViewScrollPosition, directionHint: ListViewScrollToItemDirectionHint) {
            self.chatHistoryTransaction(
                deleteIndices: [],
                insertIndicesAndItems: [],
                updateIndicesAndItems: [],
                options: ListViewDeleteAndInsertOptions(),
                scrollToItem: ListViewScrollToItem(index: index,
                                                   position: position,
                                                   animated: animated,
                                                   curve: curve,
                                                   directionHint: directionHint),
                additionalScrollDistance: 0.0,
                updateSizeAndInsets: nil,
                stationaryItemRange: nil,
                customAnimationTransition: nil,
                updateOpaqueState: nil,
                completion: { _ in }
            )
        }

        if frame.height > viewportHeight - insetTop - insetBottom {
            if atTop {
                if frame.maxY > viewportHeight - insetBottom {
                    scroll(to: .top(-overflow), directionHint: .Down)
                } else if frame.minY < insetTop && overflow > 0.0 {
                    scroll(to: .top(-overflow), directionHint: .Up)
                }
            } else {
                if frame.maxY > viewportHeight - insetBottom {
                    scroll(to: .bottom(-overflow), directionHint: .Down)
                } else if frame.minY < insetTop && overflow > 0.0 {
                    scroll(to: .top(-overflow), directionHint: .Up)
                }
            }
        } else if self.experimentalSnapScrollToItem {
            scroll(to: .visible, directionHint: .Up)
        } else if frame.minY < insetTop + overflow {
            if !allowIntersection || frame.maxY < insetTop {
                scroll(to: allowIntersection ? .center(.top) : .top(overflow), directionHint: .Up)
            }
        } else if frame.maxY > viewportHeight - insetBottom - overflow {
            if !allowIntersection || frame.minY > viewportHeight - insetBottom {
                scroll(to: allowIntersection ? .center(.bottom) : .bottom(-overflow), directionHint: .Down)
            }
        }
    }

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
    // conversion is needed here. Both sides are live: the restore path resolves `.top(offset)`
    // through pointOffset(for:index:height:view:).
    func itemNodeRelativeOffset(_ node: ListViewItemNode) -> CGFloat? {
        guard let frame = self.loadedFrame(of: node) else {
            return nil
        }
        return frame.minY - self.currentInsets.top
    }

    // The loaded row's rect in list space — what `ListViewItemNode.frame` means on ListViewImpl and
    // does NOT mean here, since a hosted node's view sits at (0, 0, width, height) inside its host.
    // Chat-layer geometry must go through this rather than the node's own frame.
    func itemNodeFrame(_ node: ListViewItemNode) -> CGRect? {
        return self.loadedFrame(of: node)
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

    // Built once here rather than computed on demand: CoreList consults `attachedItems` repeatedly
    // within a pass — `AttachmentRuns.pendingRuns` runs per row during stacking as well as once per
    // window build. It depends only on the item's headers, never on geometry, so a pass that changes
    // only size or insets cannot invalidate it.
    let attachedItems: [AnyHashable: CoreListAttachedItem]

    var identity: AnyHashable { AnyHashable(self.stableId) }

    init(stableId: UInt64,
         stableVersion: Int,
         listItem: ListViewItem,
         backend: CoreListChatHistoryBackend?,
         neighbors: ListViewItemNeighbors = .none) {
        self.stableId = stableId
        self.stableVersion = stableVersion
        self.listItem = listItem
        self.neighbors = neighbors

        var attachedItems: [AnyHashable: CoreListAttachedItem] = [:]
        if let headerItem = listItem as? ChatHistoryItemWithHeaders {
            for header in headerItem.headers {
                // Topic headers — a date header carrying a separableThreadId — are deferred.
                // ListViewImpl resolves their overlap against the plain date header with a two-pass
                // nudge loop (Display/Source/ListView.swift:4036-4086), and a single attachment key
                // cannot express that stacking.
                if header.stackingId != nil {
                    continue
                }
                attachedItems[AnyHashable(header.id)] = CoreListHeaderAttachedItem(header: header,
                                                                                  backend: backend)
            }
        }
        self.attachedItems = attachedItems
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

    /// The most recent rect from CoreList, held so a node built after the notification still gets it.
    private var visibleRect: CGRect?

    func visibleRectUpdated(_ visibleRect: CGRect?) {
        self.visibleRect = visibleRect
        self.applyVisibility()
    }

    // ListViewImpl's own formula (Display/Source/ListView.swift:4344) with the host's geometry:
    // `subRect` is the visible part in the row's own space, and `fraction` is that part's overlap
    // with the node's content box — the row minus its insets — over that box's height, which is what
    // `apparentContentFrame` gives ListViewImpl. Assign only on change: the property's didSet fans
    // out to every content node.
    private func applyVisibility() {
        guard let itemNode = self.itemNode else {
            return
        }
        var visibility: ListViewItemNodeVisibility = .none
        if let rect = self.visibleRect {
            let insets = itemNode.insets
            let contentTop = insets.top
            let contentBottom = self.lastHeight - insets.bottom
            let contentHeight = contentBottom - contentTop
            var fraction: CGFloat = 0.0
            if contentHeight > 0.0 {
                fraction = max(0.0, min(rect.maxY, contentBottom) - max(rect.minY, contentTop)) / contentHeight
            }
            visibility = .visible(fraction, rect)
        }
        if itemNode.visibility != visibility {
            itemNode.visibility = visibility
        }
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
                nodeApply(ListViewItemApply())
                // Same fields, same order ListViewImpl stamps in updateNodeAtIndex. Load-bearing:
                // `insets` is the content-box term the visibility fraction divides by, and the flip
                // term inside ChatMessageBubbleItemNode.mapVisibility. ChatMessageItemImpl assigns
                // these on its nodeConfiguredForParams path only, so without this they go stale
                // whenever a relayout changes them — a date header appearing, say.
                itemNode.contentSize = nodeLayout.contentSize
                itemNode.insets = nodeLayout.insets
                itemNode.apparentHeight = height
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
                    applyFn(ListViewItemApply())
                }
                // contentSize/insets are already assigned on this path by
                // ChatMessageItemImpl.nodeConfiguredForParams; only apparentHeight is missing, and
                // ListViewImpl keeps it in step with the row's rendered height.
                let height = node.contentSize.height + node.insets.top + node.insets.bottom
                node.apparentHeight = height
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
        // A rect may have arrived before this node existed, and a relayout can change the insets the
        // fraction divides by, so re-derive visibility from the rect we hold.
        self.applyVisibility()
    }
}
