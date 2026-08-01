import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import Display
import ChatMessageItemImpl

// A chat-specific abstraction of the list-view backend used by ChatHistoryListNodeImpl.
//
// This is the minimal surface ChatHistoryListNodeImpl actually accesses on its list view — exactly
// the distinct `listView.<member>` accesses in ChatHistoryListNode.swift. It is standalone BY DESIGN:
// it does NOT refine the shared `ListView` protocol even though ~37 members overlap. The duplication
// is intentional (a deliberate design choice) so the chat history surface owns its own contract on
// the path toward an eventual alternative backend.
//
// See docs/superpowers/specs/2026-07-23-chat-history-listview-backend-protocol-design.md
public protocol ChatHistoryListViewBackend: ASDisplayNode {
    // MARK: - Narrow scroll-view accessors (replacing the previously-exposed `scroller: ListViewScroller`).
    var bounces: Bool { get set }
    var contentHeight: CGFloat { get }
    func setTopContentInset(_ inset: CGFloat)

    // MARK: - Members shared with the `ListView` protocol (signatures copied from ListViewProtocol.swift).
    var scrollEnabled: Bool { get set }
    var preloadPages: Bool { get set }
    var experimentalSnapScrollToItem: Bool { get set }
    var stackFromBottom: Bool { get set }
    var enableExtractedBackgrounds: Bool { get set }
    var autoScrollWhenReordering: Bool { get set }
    var defaultToSynchronousTransactionWhileScrolling: Bool { get set }
    var verticalScrollIndicatorColor: UIColor? { get set }
    var accessibilityPageScrolledString: ((String, String) -> String)? { get set }

    var insets: UIEdgeInsets { get }
    var visibleSize: CGSize { get }
    // One member rather than the raw `trackingOffset`/`beganTrackingAtTopOrigin` pair those two used to
    // be. Its only consumer needs them combined, and as separate members a backend could implement one
    // and stub the other — which is exactly what happened: `CoreListChatHistoryBackend` stubbed both to
    // constants, silently disabling the chat's keyboard-dismissal snap-back rather than failing to build.
    var didInteractivelyDragFromTopOrigin: Bool { get }
    var displayedItemRange: ListViewDisplayedItemRange { get }
    var opaqueTransactionState: Any? { get }

    var displayedItemRangeChanged: (ListViewDisplayedItemRange, Any?) -> Void { get set }
    var visibleContentOffsetChanged: (ListViewVisibleContentOffset, ContainedViewLayoutTransition) -> Void { get set }
    var beganInteractiveDragging: (CGPoint) -> Void { get set }
    var endedInteractiveDragging: (CGPoint) -> Void { get set }
    var didEndScrolling: ((Bool) -> Void)? { get set }
    var didEndScrollingWithOverscroll: (() -> Void)? { get set }
    var updateFloatingHeaderOffset: ((CGFloat, ContainedViewLayoutTransition) -> Void)? { get set }
    var didScrollWithOffset: ((CGFloat, ContainedViewLayoutTransition, ListViewItemNode?, Bool) -> Void)? { get set }
    var addContentOffset: ((CGFloat, ListViewItemNode?) -> Void)? { get set }
    var tapped: (() -> Void)? { get set }
    var reorderItem: (Int, Int, Any?) -> Signal<Bool, NoError> { get set }

    // `maintainsUnreadItemAlignment` asks the backend to keep the unread separator pinned to the
    // bottom inset edge across this pass's geometry change — the chat's `enableUnreadAlignment`
    // policy. It is ONE member rather than the measure-then-reapply pair it decomposes into, because
    // the predicate ("is the separator currently pinned?") must be evaluated against the OLD insets
    // and the re-pin applied with the NEW ones. As two members a backend could implement one and
    // stub the other, which is exactly how `trackingOffset`/`beganTrackingAtTopOrigin` silently
    // disabled keyboard-dismissal snap-back until they were collapsed into
    // `didInteractivelyDragFromTopOrigin`.
    //
    // This lived in `ChatHistoryListNodeImpl.updateLayout` and read `itemNode.index`, which is
    // `public internal(set)` to Display and therefore always nil for a hosted node — so under the
    // CoreList backend the whole behavior was dead code with no build error. The nav bar changing
    // height mid-open (a Report Spam bar appearing) is what makes it load-bearing: without the
    // re-pin the separator keeps the position computed against the pre-panel geometry.
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
    )

    // A loaded item node's frame in LIST space, or nil when the node is not currently loaded.
    //
    // `ListViewItemNode.frame` is list-space only on `ListViewImpl`. Under a hosting backend the
    // node's view is a subview of its host at (0, 0, width, height), so its own frame is host-local
    // and every chat-layer geometry comparison against it silently reads the wrong space. The nil
    // case is the liveness guard: `ListViewImpl` answers it from `index != nil`, CoreList from
    // absence from the loaded window.
    func itemNodeFrame(_ node: ListViewItemNode) -> CGRect?

    func addAfterTransactionsCompleted(_ f: @escaping () -> Void)
    func visibleContentOffset() -> ListViewVisibleContentOffset

    // Both content offsets, sampled together in the SETTLED geometry — where the content will be once
    // whatever is animating finishes.
    //
    // One member rather than the `visibleContentOffset()` / `visibleBottomContentOffset()` pair it
    // replaces, for two reasons. It is a question about the list's STATE, asked while a transaction is
    // being prepared, so the mid-animation position is the wrong instant: on `ListViewImpl` the two
    // coincide (its model IS its presented geometry), but under a hosting backend they diverge by the
    // whole remaining travel of any pass in flight. And the caller COMPARES the two, so sampling them
    // separately lets them describe different instants — the failure the single member makes
    // unrepresentable. The thresholds stay in the chat layer; this only fixes the instant.
    func settledContentOffsets() -> (top: ListViewVisibleContentOffset, bottom: ListViewVisibleContentOffset)

    func transferVelocity(_ velocity: CGFloat)
    func resetScrolledToItem()

    func forEachItemNode(_ f: (ASDisplayNode) -> Void)
    func forEachVisibleItemNode(_ f: (ASDisplayNode) -> Void)
    func enumerateItemNodes(_ f: (ASDisplayNode) -> Bool)
    func forEachItemHeaderNode(_ f: (ListViewItemHeaderNode) -> Void)

    func ensureItemNodeVisible(_ node: ListViewItemNode, animated: Bool, overflow: CGFloat, allowIntersection: Bool, atTop: Bool, curve: ListViewAnimationCurve)

    // MARK: - Members NOT in the `ListView` protocol (signatures copied from ListView.swift).
    func updateVisibleItemRange(force: Bool)
    func itemNodeAtIndex(_ index: Int) -> ListViewItemNode?
    func itemNodeRelativeOffset(_ node: ListViewItemNode) -> CGFloat?
    func itemNodeVisibleInsideInsets(_ node: ListViewItemNode) -> Bool
    func isStrictlyScrolledToPinToEdgeItem() -> Bool
    func scrollWithDirection(_ direction: ListViewScrollDirection, distance: CGFloat) -> Bool
    var generalScrollDirectionUpdated: (GeneralScrollDirection) -> Void { get set }
    var getCustomItemDeleteAnimationDuration: ((ListViewItemNode) -> Double?)? { get set }
    var globalIgnoreScrollingEvents: Bool { get set }
}

// Swift protocol requirements cannot carry default parameter values, so — mirroring the
// `public extension ListView { ... }` block in ListViewProtocol.swift — provide the default-argument
// convenience overloads that ChatHistoryListNodeImpl relies on. They forward to the full requirement.
public extension ChatHistoryListViewBackend {
    func chatHistoryTransaction(
        deleteIndices: [ListViewDeleteItem],
        insertIndicesAndItems: [ChatHistoryListViewInsertItem],
        updateIndicesAndItems: [ChatHistoryListViewUpdateItem],
        options: ListViewDeleteAndInsertOptions,
        scrollToItem: ListViewScrollToItem? = nil,
        additionalScrollDistance: CGFloat = 0.0,
        updateSizeAndInsets: ListViewUpdateSizeAndInsets? = nil,
        stationaryItemRange: (Int, Int)? = nil,
        customAnimationTransition: ControlledTransition? = nil,
        maintainsUnreadItemAlignment: Bool = false,
        updateOpaqueState: Any?,
        completion: @escaping (ListViewDisplayedItemRange) -> Void = { _ in }
    ) {
        self.chatHistoryTransaction(
            deleteIndices: deleteIndices,
            insertIndicesAndItems: insertIndicesAndItems,
            updateIndicesAndItems: updateIndicesAndItems,
            options: options,
            scrollToItem: scrollToItem,
            additionalScrollDistance: additionalScrollDistance,
            updateSizeAndInsets: updateSizeAndInsets,
            stationaryItemRange: stationaryItemRange,
            customAnimationTransition: customAnimationTransition,
            maintainsUnreadItemAlignment: maintainsUnreadItemAlignment,
            updateOpaqueState: updateOpaqueState,
            completion: completion
        )
    }

    func ensureItemNodeVisible(_ node: ListViewItemNode, animated: Bool = true, overflow: CGFloat = 0.0, allowIntersection: Bool = false, atTop: Bool = false, curve: ListViewAnimationCurve = .Default(duration: 0.25)) {
        self.ensureItemNodeVisible(node, animated: animated, overflow: overflow, allowIntersection: allowIntersection, atTop: atTop, curve: curve)
    }
}

// Almost all members declared above are already `public` on ListViewImpl. The narrow scroll-view
// accessors bridge to ListViewImpl's `scroller`, keeping the ListViewScroller concrete type off the
// protocol contract.
extension ListViewImpl: ChatHistoryListViewBackend {
    public var bounces: Bool {
        get { self.scroller.bounces }
        set { self.scroller.bounces = newValue }
    }
    public var contentHeight: CGFloat {
        return self.scroller.contentSize.height
    }
    public func setTopContentInset(_ inset: CGFloat) {
        self.scroller.contentInset = UIEdgeInsets(top: inset, left: 0.0, bottom: 0.0, right: 0.0)
    }
    
    public func itemNodeFrame(_ node: ListViewItemNode) -> CGRect? {
        // On ListViewImpl a node's own frame IS list space; `index != nil` is its liveness guard,
        // skipping removed-but-still-animating nodes exactly as its internal scans do.
        guard node.index != nil else {
            return nil
        }
        return node.frame
    }

    // Settled and presented are the same thing here: `replayOperations` writes final item-node frames
    // immediately and animates the layers additively, so these two reads already return the endpoint.
    // This is the pair the chat used to sample separately, which on this backend is exactly equivalent.
    public func settledContentOffsets() -> (top: ListViewVisibleContentOffset, bottom: ListViewVisibleContentOffset) {
        return (self.visibleContentOffset(), self.visibleBottomContentOffset())
    }

    public func chatHistoryTransaction(
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
        // Measured against the OLD insets, before the transaction below installs the new ones — this
        // is the code that used to sit in ChatHistoryListNodeImpl.updateLayout, moved here verbatim
        // (including its 6.0, which is ChatUnreadItem's scrollPositioningInsets.bottom). ListViewImpl
        // cannot compose the re-pin into the same pass, so it is re-issued as a second transaction
        // from the completion, exactly as before.
        var postScrollToItem: ListViewScrollToItem?
        if maintainsUnreadItemAlignment, let updateSizeAndInsets, updateSizeAndInsets.insets.bottom != self.insets.bottom {
            self.forEachVisibleItemNode { itemNode in
                if let itemNode = itemNode as? ChatUnreadItemNode, let index = itemNode.index {
                    if abs(itemNode.frame.maxY - (self.visibleSize.height - self.insets.bottom + 6.0)) < 1.0 {
                        postScrollToItem = ListViewScrollToItem(index: index, position: .bottom(0.0), animated: updateSizeAndInsets.duration != 0.0, curve: updateSizeAndInsets.curve, directionHint: .Up)
                    }
                }
            }
        }

        let wrappedCompletion: (ListViewDisplayedItemRange) -> Void
        if let postScrollToItem {
            wrappedCompletion = { [weak self] displayedRange in
                guard let self else {
                    completion(displayedRange)
                    return
                }
                self.transaction(
                    deleteIndices: [],
                    insertIndicesAndItems: [],
                    updateIndicesAndItems: [],
                    options: [.Synchronous, .LowLatency],
                    scrollToItem: postScrollToItem,
                    additionalScrollDistance: 0.0,
                    updateSizeAndInsets: nil,
                    stationaryItemRange: nil,
                    updateOpaqueState: nil,
                    completion: completion
                )
            }
        } else {
            wrappedCompletion = completion
        }

        self.transaction(
            deleteIndices: deleteIndices,
            insertIndicesAndItems: insertIndicesAndItems.map { item in
                return ListViewInsertItem(
                    index: item.index,
                    previousIndex: item.previousIndex,
                    item: item.item,
                    directionHint: item.directionHint,
                    forceAnimateInsertion: item.forceAnimateInsertion
                )
            },
            updateIndicesAndItems: updateIndicesAndItems.map { item in
                return ListViewUpdateItem(
                    index: item.index,
                    previousIndex: item.previousIndex,
                    item: item.item,
                    directionHint: item.directionHint
                )
            },
            options: options,
            scrollToItem: scrollToItem,
            additionalScrollDistance: additionalScrollDistance,
            updateSizeAndInsets: updateSizeAndInsets,
            stationaryItemRange: stationaryItemRange,
            customAnimationTransition: customAnimationTransition,
            updateOpaqueState: updateOpaqueState,
            completion: wrappedCompletion
        )
    }
}
