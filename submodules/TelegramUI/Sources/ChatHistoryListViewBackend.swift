import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import Display

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
    var trackingOffset: CGFloat { get }
    var beganTrackingAtTopOrigin: Bool { get }
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
    )

    func addAfterTransactionsCompleted(_ f: @escaping () -> Void)
    func visibleContentOffset() -> ListViewVisibleContentOffset
    func visibleBottomContentOffset() -> ListViewVisibleContentOffset
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
        updateOpaqueState: Any?,
        completion: @escaping (ListViewDisplayedItemRange) -> Void
    ) {
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
            completion: completion
        )
    }
}
