import UIKit

public protocol CoreListItemView: AnyObject {
    func update(width: CGFloat) -> CGFloat
    var onContentDidChange: ((_ animated: Bool) -> Void)? { get set }
}

public protocol CoreListItem: AnyObject {
    /// Stable identity: drives diff matching (survive / insert / delete / move) and the uniqueness
    /// invariant, and is the animation/owner key. Two items are "the same row" iff their `identity` is
    /// equal.
    var identity: AnyHashable { get }
    func view() -> UIView & CoreListItemView
    /// Value/content equality for an already-identity-matched survivor. The engine matches rows by
    /// `identity`; this only decides whether a matched survivor's content changed — it reconfigures
    /// (`apply(to:)` + remeasure) iff `!isEqual`. Deliberately has NO default: equality-by-identity is
    /// almost never correct in production, so every item must state its content equality explicitly.
    func isEqual(to other: CoreListItem) -> Bool
    func apply(to view: UIView & CoreListItemView)
}

public extension CoreListItem {
    func apply(to view: UIView & CoreListItemView) {}
}

public enum CoreListAnchorMode: Equatable {
    case automatic
    case preserveVisibleContent
}

public enum CoreListLoadedEdge: Hashable {
    case top
    case bottom
}

public final class CoreVirtualListView: UIView {
    struct Window {
        struct Item {
            let index: Int
            let view: UIView & CoreListItemView
            var frame: CGRect
        }

        var items: [Item] = []

        var startIndex: Int { items.first?.index ?? 0 }
        var endIndex: Int { items.last?.index ?? -1 }
        var isEmpty: Bool { items.isEmpty }
        var minY: CGFloat { items.first?.frame.minY ?? 0 }
        var maxY: CGFloat { items.last?.frame.maxY ?? 0 }
        var height: CGFloat { maxY - minY }

        func contains(index: Int) -> Bool {
            guard let first = items.first, let last = items.last else { return false }
            return index >= first.index && index <= last.index
        }

        func localFrame(for index: Int) -> CGRect? {
            items.first(where: { $0.index == index })?.frame
        }

        // The loaded view at a collection index. Filters rather than subscripts: `items` is the
        // settled window, whose array positions are offset from collection indices whenever the
        // window has scrolled away from index 0.
        func view(for index: Int) -> (UIView & CoreListItemView)? {
            items.first(where: { $0.index == index })?.view
        }
    }

    struct ItemDiff {
        var survivorMap: [Int: Int]
        var deletes: [Int]
        var inserts: [Int]
        var moves: [(old: Int, new: Int)] = []

        func survivingNewIndex(forOldIndex oldIndex: Int) -> Int? {
            survivorMap[oldIndex]
                ?? moves.first(where: { $0.old == oldIndex })?.new
        }
    }

    private struct ResolvedAnchor {
        let index: Int
        let pointOffset: CGFloat
        let preservesVisibleContent: Bool
    }

    static func computeDiff(old: [CoreListItem], new: [CoreListItem]) -> ItemDiff {
        var oldMatched = Array(repeating: false, count: old.count)
        var survivorMap: [Int: Int] = [:]
        var inserts: [Int] = []

        for newIndex in new.indices {
            var matched = false
            for oldIndex in old.indices where !oldMatched[oldIndex] {
                if old[oldIndex].identity == new[newIndex].identity {
                    oldMatched[oldIndex] = true
                    survivorMap[oldIndex] = newIndex
                    matched = true
                    break
                }
            }
            if !matched { inserts.append(newIndex) }
        }

        let oldSurvivors = survivorMap.keys.sorted()
        let newIndexSequence = oldSurvivors.map { survivorMap[$0]! }
        let keptPositions = Set(longestIncreasingSubsequenceIndices(newIndexSequence))
        var reorderedOldIndices: Set<Int> = []
        for position in oldSurvivors.indices where !keptPositions.contains(position) {
            reorderedOldIndices.insert(oldSurvivors[position])
        }

        var moves: [(old: Int, new: Int)] = []
        for oldIndex in reorderedOldIndices {
            let newIndex = survivorMap[oldIndex]!
            inserts.append(newIndex)
            moves.append((old: oldIndex, new: newIndex))
            survivorMap[oldIndex] = nil
        }
        moves.sort { $0.new < $1.new }

        var deletes: [Int] = []
        for oldIndex in old.indices where !oldMatched[oldIndex] || reorderedOldIndices.contains(oldIndex) {
            deletes.append(oldIndex)
        }
        inserts.sort()
        return ItemDiff(survivorMap: survivorMap,
                        deletes: deletes,
                        inserts: inserts,
                        moves: moves)
    }

    static func firstDuplicatePair(in items: [CoreListItem]) -> (first: Int, second: Int)? {
        for first in items.indices {
            for second in items.indices where second > first {
                if items[first].identity == items[second].identity {
                    return (first, second)
                }
            }
        }
        return nil
    }

    static func longestIncreasingSubsequenceIndices(_ values: [Int]) -> [Int] {
        guard !values.isEmpty else { return [] }
        var tails: [Int] = []
        var predecessors = Array(repeating: -1, count: values.count)

        for index in values.indices {
            var lower = 0
            var upper = tails.count
            while lower < upper {
                let middle = (lower + upper) / 2
                if values[tails[middle]] < values[index] {
                    lower = middle + 1
                } else {
                    upper = middle
                }
            }
            if lower > 0 { predecessors[index] = tails[lower - 1] }
            if lower == tails.count {
                tails.append(index)
            } else {
                tails[lower] = index
            }
        }

        var result: [Int] = []
        var index = tails.last ?? -1
        while index >= 0 {
            result.append(index)
            index = predecessors[index]
        }
        return result.reversed()
    }

    private struct SettledLiveItem {
        let index: Int
        let identity: AnyHashable
        let view: UIView & CoreListItemView
        let contentX: CGFloat
        let contentY: CGFloat
        let positionOffsetX: CGFloat
        let positionOffset: CGFloat
        let opacity: CGFloat
        let size: CGSize
        let visualWidth: CGFloat
        let visualHeight: CGFloat
    }

    private struct GhostMember {
        let owner: ListAnimationOwner
        let view: UIView
        var settledX: CGFloat
        var settledWidth: CGFloat
    }

    private struct GhostBlockRender {
        let owner: ListAnimationOwner
        let wrapper: UIView
        var members: [ObjectIdentifier: GhostMember]
        let departedRange: Range<Int>
    }

    private struct GhostWitnessCandidate {
        let witness: GhostBoundaryWitness
        let edgeY: CGFloat
        let carrierOrder: Int
    }

    private struct ViewportCarry {
        var generation: UInt64
        let owner: ListAnimationOwner
        let identity: AnyHashable
        let view: UIView
        var settledX: CGFloat
        var settledWidth: CGFloat
    }

    struct CrossingCarrySnapshot: Equatable {
        let identity: AnyHashable
        let settledContentY: CGFloat
        let releaseGeneration: UInt64?
    }

    private struct CrossingCarry {
        let identity: AnyHashable
        let view: UIView & CoreListItemView
        var settledX: CGFloat
        var settledWidth: CGFloat
        var settledContentY: CGFloat
        var releaseGeneration: UInt64?
    }

    private struct SurvivorEndpointIndices {
        let oldIndex: Int
        let newIndex: Int
        let isMoveParticipant: Bool
    }

    private var _items: [CoreListItem] = []
    var items: [CoreListItem] {
        get { _items }
        set {
            _items = newValue
            rebuildFromScratch()
        }
    }

    public var preloadMargin: CGFloat = 160
    public var loadedEdgeMargin: CGFloat = 0 {
        didSet {
            guard loadedEdgeMargin != oldValue else { return }
            refreshReachedLoadedEdges()
        }
    }
    let engine: ScrollEngine
    let container = UIView()
    let crossingOverlay = UIView()
    let exitOverlay = UIView()
    let animationController: ListAnimationController
    let scheduler: Scheduler
    private(set) var logicalSize: CGSize = .zero
    private(set) var viewportInsets: UIEdgeInsets = .zero
    var viewportGeometry: ListViewportGeometry {
        ListViewportGeometry(size: logicalSize, insets: viewportInsets)
    }
    private var contentWidth: CGFloat { viewportGeometry.contentWidth }
    private(set) var activeWindow = Window()
    private(set) var containerOriginY: CGFloat = 0
    private var viewportCarries: [ViewportCarry] = []
    var viewportCarryViews: [UIView] { viewportCarries.map(\.view) }
    private var crossingCarries: [AnyHashable: CrossingCarry] = [:]
    var crossingCarrySnapshots: [CrossingCarrySnapshot] {
        crossingCarries.values.map {
            CrossingCarrySnapshot(identity: $0.identity,
                                  settledContentY: $0.settledContentY,
                                  releaseGeneration: $0.releaseGeneration)
        }.sorted { String(reflecting: $0.identity) < String(reflecting: $1.identity) }
    }

    func crossingCarryView(identity: AnyHashable) -> UIView? {
        crossingCarries[identity]?.view
    }
    private let ghostLedger = GhostBlockLedger()
    private var ghostRenders: [GhostBlockID: GhostBlockRender] = [:]
    var ghostBlockSnapshots: [GhostBlockSnapshot] { ghostLedger.snapshots }
    var ghostMemberViews: [UIView] {
        ghostRenders.values.flatMap { render in render.members.values.map(\.view) }
    }
    struct DetachedHorizontalSnapshot {
        let owner: ListAnimationOwner
        let view: UIView
        let settledX: CGFloat
        let settledWidth: CGFloat
    }
    var ghostMemberHorizontalSnapshots: [DetachedHorizontalSnapshot] {
        ghostRenders.values.flatMap { render in
            render.members.values.map {
                DetachedHorizontalSnapshot(owner: $0.owner,
                                           view: $0.view,
                                           settledX: $0.settledX,
                                           settledWidth: $0.settledWidth)
            }
        }
    }
    private var previousOffset: CGFloat = 0
    public private(set) var reachedLoadedEdges: Set<CoreListLoadedEdge> = []
    public var onLoadedEdgeReached: ((CoreListLoadedEdge) -> Void)?

    // Embedding seam (used by the TelegramUI ChatHistoryListViewBackend adapter).
    // Fired after each user-scroll rebalance so a host can recompute its visible index range.
    public var onVisibleWindowChanged: (() -> Void)?
    // Fired when the user starts an interactive drag (the scroll engine's pan reaches `.began`); not
    // fired for programmatic scrolls or momentum/bounce. Analogous to ListViewImpl's
    // `beganInteractiveDragging`.
    public var willBeginDragging: (() -> Void)?
    // The contiguous loaded item-index span of the settled window, or nil when empty.
    public var loadedIndexRange: (first: Int, last: Int)? {
        activeWindow.isEmpty ? nil : (activeWindow.startIndex, activeWindow.endIndex)
    }

    /// Non-copying, in-ascending-index-order iteration over the currently loaded item views (the
    /// settled window). Walks the window in place — no array is built and no element is copied. This is
    /// CoreList's analogue of `ListViewImpl.forEachItemNode`, but iterator-based rather than
    /// closure-based, so a host can `for view in listView.loadedItemViews { … }`. The iterator holds a
    /// stable snapshot of the window (a COW retain of its buffer), so mutating the list mid-iteration is
    /// safe. Only settled/loaded rows are visited — not off-screen entries or exit-overlay ghosts.
    public struct LoadedItemViews: Sequence, IteratorProtocol {
        private let items: [Window.Item]
        private var index = 0
        fileprivate init(_ items: [Window.Item]) { self.items = items }
        public mutating func next() -> (UIView & CoreListItemView)? {
            guard index < items.count else { return nil }
            defer { index += 1 }
            return items[index].view
        }
    }
    public var loadedItemViews: LoadedItemViews { LoadedItemViews(activeWindow.items) }

    /// The loaded item view at `index` in the current item collection, or nil when that index is not
    /// in the settled window. The index-keyed sibling of `loadedItemViews`: this view is the authority
    /// on the index ↔ view mapping (it owns `activeWindow`), so a host must never re-derive it by
    /// walking `loadedItemViews` to a position inferred from `loadedIndexRange`. Only settled/loaded
    /// rows resolve — never off-screen entries or exit-overlay ghosts. A pure read of settled state:
    /// it starts no transaction and mutates nothing.
    public func loadedItemView(at index: Int) -> (UIView & CoreListItemView)? {
        activeWindow.view(for: index)
    }

    /// Non-copying, in-ascending-index-order iteration over the loaded item views **paired with their
    /// collection indices**. Same in-place COW-snapshot walk as `loadedItemViews` — no array built, no
    /// element copied, safe to mutate the list mid-iteration — but each element also carries the
    /// window's own `index`. Use this instead of counting iterations over `loadedItemViews`: array
    /// position equals collection index only while the window still starts at 0. Visits only
    /// settled/loaded rows, never off-screen entries or exit-overlay ghosts.
    public struct LoadedItemEntries: Sequence, IteratorProtocol {
        public typealias Element = (index: Int, view: UIView & CoreListItemView)
        private let items: [Window.Item]
        private var position = 0
        fileprivate init(_ items: [Window.Item]) { self.items = items }
        public mutating func next() -> Element? {
            guard position < items.count else { return nil }
            defer { position += 1 }
            let item = items[position]
            return (index: item.index, view: item.view)
        }
    }
    public var loadedItemEntries: LoadedItemEntries { LoadedItemEntries(activeWindow.items) }
    // The current settled scroll offset reported by the scroll engine.
    public var currentScrollOffset: CGFloat { engine.offset }
    // The height of the currently loaded (settled) window.
    public var settledContentHeight: CGFloat { activeWindow.height }

    private var dirtyIndices: Set<Int> = []
    private var dirtyAnimated = false
    private var dirtyFlushScheduled = false
    private var isApplyingChanges = false
    var defaultDirtyDuration: TimeInterval = 0.3

    init(frame: CGRect = .zero,
         engine: ScrollEngine = UIKitScrollEngine(),
         animationController: ListAnimationController = ListAnimationController(),
         scheduler: Scheduler = MainQueueScheduler()) {
        self.engine = engine
        self.animationController = animationController
        self.scheduler = scheduler
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        self.engine = UIKitScrollEngine()
        self.animationController = ListAnimationController()
        self.scheduler = MainQueueScheduler()
        super.init(coder: coder)
        setup()
    }

    // Public entry point for cross-module consumers (e.g. the TelegramUI adapter).
    // Uses a distinct argument label so it does not collide with the all-defaulted
    // internal designated initializer, and keeps the ScrollEngine/Scheduler types
    // module-internal.
    public convenience init(forEmbedding frame: CGRect) {
        let engine = PhysicsScrollEngine()
        engine.decelerationMode = .keyframe
        self.init(frame: frame, engine: engine, animationController: ListAnimationController(), scheduler: MainQueueScheduler())
    }

    private func setup() {
        // No background: the list is transparent by default and never paints its own backdrop. Hosts
        // composite it over whatever they own (a chat wallpaper, a themed controller view), so an
        // opaque background here would hide that. Callers that want one set it themselves.
        engine.onScroll = { [weak self] offset in
            self?.handleUserScroll(offset)
        }
        engine.onWillBeginDragging = { [weak self] in
            self?.willBeginDragging?()
        }
        container.backgroundColor = .clear
        container.clipsToBounds = false
        crossingOverlay.backgroundColor = .clear
        crossingOverlay.clipsToBounds = false
        crossingOverlay.isUserInteractionEnabled = false
        exitOverlay.backgroundColor = .clear
        exitOverlay.clipsToBounds = false
        exitOverlay.isUserInteractionEnabled = false
        addSubview(engine.contentHost)
        engine.contentHost.addSubview(container)
        engine.contentHost.addSubview(crossingOverlay)
        engine.contentHost.addSubview(exitOverlay)
        animationController.setReferenceLayer(container.layer)
        animationController.seedViewport(layer: engine.contentHost.layer)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        engine.contentHost.frame = bounds
        layoutExitOverlay()
    }

    public func applyChanges(items newItems: [CoreListItem]? = nil,
                      newSize: CGSize? = nil,
                      scrollTo: (index: Int, pointOffset: CGFloat)? = nil,
                      anchorMode: CoreListAnchorMode = .automatic,
                      animationDuration: TimeInterval) {
        applyChanges(items: newItems,
                     newSize: newSize,
                     newInsets: nil,
                     scrollTo: scrollTo,
                     anchorMode: anchorMode,
                     animation: .smoothstep(duration: animationDuration))
    }

    public func applyChanges(items newItems: [CoreListItem]? = nil,
                      newSize: CGSize? = nil,
                      newInsets: UIEdgeInsets? = nil,
                      scrollTo: (index: Int, pointOffset: CGFloat)? = nil,
                      anchorMode: CoreListAnchorMode = .automatic,
                      animation: ListAnimationSpec) {
        let animationDuration = animation.duration
        if isApplyingChanges {
            scheduler.schedule { [weak self] in
                self?.applyChanges(items: newItems,
                                   newSize: newSize,
                                   newInsets: newInsets,
                                   scrollTo: scrollTo,
                                   anchorMode: anchorMode,
                                   animation: animation)
            }
            return
        }
        isApplyingChanges = true
        defer {
            isApplyingChanges = false
            refreshReachedLoadedEdges()
        }

        let hasItems = newItems != nil
        let hasNewSize = newSize != nil
        let hasNewInsets = newInsets != nil
        let hasScrollTo = scrollTo != nil
        let hasDirty = !dirtyIndices.isEmpty
        guard hasItems || hasNewSize || hasNewInsets || hasScrollTo || hasDirty else { return }

        if let newItems, let duplicate = Self.firstDuplicatePair(in: newItems) {
            preconditionFailure(
                "applyChanges: items must be mutually unique by identity. Duplicate at indices \(duplicate.first) and \(duplicate.second)."
            )
        }

        if activeWindow.isEmpty, let newSize { logicalSize = newSize }
        if activeWindow.isEmpty, let newInsets { viewportInsets = newInsets }

        if activeWindow.isEmpty, newItems == nil {
            if _items.isEmpty {
                engine.contentHost.frame = bounds
                layoutExitOverlay()
            } else {
                rebuildFromScratch()
            }
            return
        }
        if activeWindow.isEmpty, let newItems, newItems.isEmpty {
            _items = newItems
            if ghostMemberViews.isEmpty, ghostLedger.snapshots.isEmpty {
                rebuildFromScratch()
            }
            return
        }

        let oldItems = _items
        let oldViewportInsets = viewportInsets
        let effectiveItems = newItems ?? oldItems
        let logicalSizeChanged = newSize.map { $0 != logicalSize } ?? false
        let insetsChanged = newInsets.map { $0 != viewportInsets } ?? false
        let diff: ItemDiff
        if hasItems {
            diff = Self.computeDiff(old: oldItems, new: effectiveItems)
        } else {
            diff = ItemDiff(
                survivorMap: Dictionary(uniqueKeysWithValues: oldItems.indices.map { ($0, $0) }),
                deletes: [],
                inserts: []
            )
        }
        let hasContentChanges = hasItems && diff.survivorMap.contains { oldIndex, newIndex in
            !oldItems[oldIndex].isEqual(to: effectiveItems[newIndex])
        }

        var survivorMapNewToOld: [Int: Int] = [:]
        for (oldIndex, newIndex) in diff.survivorMap {
            survivorMapNewToOld[newIndex] = oldIndex
        }

        let oldWindow = activeWindow
        let oldContainerOriginY = containerOriginY
        let oldBoundsOriginY = engine.offset
        let transactionTime = animationController.now()
        let currentViewportCorrection = animationController.viewportOffset(at: transactionTime)
        let oldEdges = loadedEdgeRange(for: oldWindow,
                                       originY: oldContainerOriginY,
                                       itemCount: oldItems.count)
        var oldMaximum = oldEdges.max
        if let minimum = oldEdges.min,
           let maximum = oldMaximum,
           maximum < minimum {
            oldMaximum = minimum
        }
        var oldSettledOffset = oldBoundsOriginY
        if let minimum = oldEdges.min {
            oldSettledOffset = max(oldSettledOffset, minimum)
        }
        if let maximum = oldMaximum {
            oldSettledOffset = min(oldSettledOffset, maximum)
        }
        let presentationOverscroll = oldBoundsOriginY - oldSettledOffset
        let oldState = settledState(oldWindow,
                                    sourceItems: oldItems,
                                    containerOriginY: oldContainerOriginY,
                                    at: transactionTime)
        var oldRenderedState = oldState
        for (identity, state) in crossingCarryState(sourceItems: oldItems,
                                                    at: transactionTime) {
            precondition(oldRenderedState[identity] == nil)
            oldRenderedState[identity] = state
        }
        let renderedOldViewport = oldSettledOffset + currentViewportCorrection
        let currentAnchorIdentity = oldWindow.items.first { item in
            guard oldItems.indices.contains(item.index),
                  let state = oldState[oldItems[item.index].identity]
            else { return false }
            return state.contentY + state.size.height > renderedOldViewport
        }.map { oldItems[$0.index].identity }
            ?? oldWindow.items.last.map { oldItems[$0.index].identity }

        if let newSize { logicalSize = newSize }
        if let newInsets { viewportInsets = newInsets }
        if !oldItems.isEmpty, effectiveItems.isEmpty {
            engine.setOffset(engine.offset)
        }

        let consumedDirty = dirtyIndices
        dirtyIndices.removeAll()
        dirtyAnimated = false

        let wasOverscrolledPrePass = abs(presentationOverscroll) > 0.5

        var moveReuseNewToOld: [Int: Int] = [:]
        for move in diff.moves where oldWindow.contains(index: move.old) {
            moveReuseNewToOld[move.new] = move.old
        }

        if hasItems {
            func reconcileContent(newIndex: Int, oldIndex: Int) {
                guard oldItems.indices.contains(oldIndex),
                      effectiveItems.indices.contains(newIndex),
                      !oldItems[oldIndex].isEqual(to: effectiveItems[newIndex]),
                      let view = oldRenderedState[oldItems[oldIndex].identity]?.view
                else { return }
                effectiveItems[newIndex].apply(to: view)
            }
            for (newIndex, oldIndex) in survivorMapNewToOld {
                reconcileContent(newIndex: newIndex, oldIndex: oldIndex)
            }
            for (newIndex, oldIndex) in moveReuseNewToOld {
                reconcileContent(newIndex: newIndex, oldIndex: oldIndex)
            }
        }

        for index in consumedDirty {
            if let item = oldWindow.items.first(where: { $0.index == index }) {
                _ = item.view.update(width: contentWidth)
            }
        }

        if hasItems { _items = effectiveItems }

        let isNoOverlapSwap = hasItems && !hasScrollTo
            && diff.survivorMap.isEmpty && !effectiveItems.isEmpty
        let resolvedAnchor: ResolvedAnchor?
        if effectiveItems.isEmpty {
            resolvedAnchor = nil
        } else {
            guard let anchor = resolveAnchor(
                scrollTo: scrollTo,
                anchorMode: anchorMode,
                isNoOverlapSwap: isNoOverlapSwap,
                diff: diff,
                oldWindow: oldWindow,
                oldContainerOriginY: oldContainerOriginY,
                oldSettledOffset: oldSettledOffset,
                oldTopInset: oldViewportInsets.top,
                oldItemCount: oldItems.count
            )
            else {
                rebuildFromScratch()
                return
            }
            resolvedAnchor = anchor
        }

        let newWindow: Window
        if let resolvedAnchor {
            let topInsetDelta = viewportInsets.top - oldViewportInsets.top
            let projectedPointOffset = hasScrollTo
                ? viewportInsets.top + resolvedAnchor.pointOffset
                : resolvedAnchor.pointOffset + topInsetDelta
            let pinsLoadedTop = !resolvedAnchor.preservesVisibleContent
                && !hasScrollTo
                && oldWindow.startIndex == 0
                && oldEdges.min.map { abs(oldSettledOffset - $0) <= 1e-6 } == true
            newWindow = buildWindow(anchoredAt: resolvedAnchor.index,
                                    pointOffset: projectedPointOffset,
                                    pinsLoadedTop: pinsLoadedTop,
                                    sourceWindow: oldWindow,
                                    survivorMapNewToOld: survivorMapNewToOld,
                                    moveReuseNewToOld: moveReuseNewToOld)
        } else {
            newWindow = Window()
        }

        let newIdentities = Set(effectiveItems.map(\.identity))
        let oldLoadedIdentities = oldWindow.items.map { oldItems[$0.index].identity }
        let newLoadedIdentities = newWindow.items.map { effectiveItems[$0.index].identity }
        let promotedCrossingIdentities = Set(crossingCarries.keys)
            .intersection(newLoadedIdentities)
        for identity in promotedCrossingIdentities {
            crossingCarries.removeValue(forKey: identity)
        }
        let sharedLoadedIdentities = Set(oldLoadedIdentities).intersection(newLoadedIdentities)
        let isOverlappingScroll = hasScrollTo && !sharedLoadedIdentities.isEmpty
        let isCarouselScroll = hasScrollTo && sharedLoadedIdentities.isEmpty
            && !oldWindow.isEmpty && !newWindow.isEmpty
        let potentialCarryIdentities: Set<AnyHashable> = {
            guard (isOverlappingScroll || isCarouselScroll), animationDuration > 0 else {
                return []
            }
            return Set(oldLoadedIdentities)
                .subtracting(newLoadedIdentities)
                .intersection(newIdentities)
        }()
        let hasStructuralMutation = !diff.deletes.isEmpty
            || !diff.inserts.isEmpty || !diff.moves.isEmpty
        let hasSettledMembershipTransition = hasStructuralMutation
            || logicalSizeChanged
            || insetsChanged
        let outgoingCrossingIdentities: Set<AnyHashable> = {
            guard hasSettledMembershipTransition else { return [] }
            return Set(oldRenderedState.keys)
                .subtracting(newLoadedIdentities)
                .intersection(newIdentities)
                .subtracting(potentialCarryIdentities)
        }()
        var survivorEndpointIndices: [AnyHashable: SurvivorEndpointIndices] = [:]
        for (oldIndex, newIndex) in diff.survivorMap {
            let identity = oldItems[oldIndex].identity
            survivorEndpointIndices[identity] = SurvivorEndpointIndices(
                oldIndex: oldIndex,
                newIndex: newIndex,
                isMoveParticipant: false
            )
        }
        for move in diff.moves where oldItems.indices.contains(move.old) {
            let identity = oldItems[move.old].identity
            survivorEndpointIndices[identity] = SurvivorEndpointIndices(
                oldIndex: move.old,
                newIndex: move.new,
                isMoveParticipant: true
            )
        }
        let hasStructuralPositionChange = hasScrollTo
            || !diff.deletes.isEmpty || !diff.inserts.isEmpty || !diff.moves.isEmpty
        if hasStructuralPositionChange {
            // Snapshot and settle while these owners are still unbound. Rendering can
            // synchronously reattach an owner that enters the new window, after which
            // it is too late to discard a correction based on stale predecessor geometry.
            for identity in animationController.activeUnboundPositionIdentities(at: transactionTime)
                where settledPredecessorsChanged(identity: identity,
                                                  oldItems: oldItems,
                                                  newItems: effectiveItems) {
                animationController.settleUnboundPosition(identity: identity,
                                                          at: transactionTime)
            }
        }

        let exitingIdentities = Set(oldRenderedState.keys).subtracting(newIdentities)
        var departingRuns: [[SettledLiveItem]] = []
        let departingStates = oldRenderedState.values
            .filter { !newIdentities.contains($0.identity) }
            .sorted { $0.index < $1.index }
        for state in departingStates {
            crossingCarries.removeValue(forKey: state.identity)
            if let last = departingRuns.indices.last,
               departingRuns[last].last?.index == state.index - 1 {
                departingRuns[last].append(state)
            } else {
                departingRuns.append([state])
            }
        }
        let newGhostBlockIDs = departingRuns.map {
            makeGhostBlock(from: $0,
                           logicalDuration: animationDuration,
                           transactionTime: transactionTime)
        }
        var newGhostBlockByDepartedIdentity: [AnyHashable: GhostBlockID] = [:]
        for (run, blockID) in zip(departingRuns, newGhostBlockIDs) {
            for item in run {
                newGhostBlockByDepartedIdentity[item.identity] = blockID
            }
        }
        for identity in outgoingCrossingIdentities {
            guard crossingCarries[identity] == nil,
                  let old = oldRenderedState[identity] else { continue }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            old.view.onContentDidChange = nil
            old.view.layer.anchorPoint = CGPoint(x: 0, y: 0)
            old.view.frame = CGRect(origin: CGPoint(x: old.contentX, y: old.contentY),
                                    size: old.size)
            crossingOverlay.addSubview(old.view)
            CATransaction.commit()
            crossingCarries[identity] = CrossingCarry(
                identity: identity,
                view: old.view,
                settledX: old.contentX,
                settledWidth: old.size.width,
                settledContentY: old.contentY,
                releaseGeneration: nil
            )
        }
        let newViews = Set(newWindow.items.map { ObjectIdentifier($0.view) })
        for oldItem in oldWindow.items where !newViews.contains(ObjectIdentifier(oldItem.view)) {
            let identity = oldItems[oldItem.index].identity
            if !exitingIdentities.contains(identity),
               !potentialCarryIdentities.contains(identity),
               !outgoingCrossingIdentities.contains(identity) {
                animationController.unbind(identity: identity,
                                           layer: oldItem.view.layer,
                                           at: transactionTime)
            }
        }
        for item in oldItems
            where !newIdentities.contains(item.identity)
                && !exitingIdentities.contains(item.identity) {
            animationController.removeLive(identity: item.identity)
        }

        activeWindow = newWindow
        render()

        let resolvedAnchorIdentity = resolvedAnchor.flatMap { anchor in
            effectiveItems.indices.contains(anchor.index)
                ? effectiveItems[anchor.index].identity
                : nil
        }
        let anchorCoordinateShift: CGFloat = {
            guard let resolvedAnchor,
                  let identity = resolvedAnchorIdentity,
                  let oldAnchorY = oldState[identity]?.contentY,
                  let newAnchorY = settledContentY(in: newWindow,
                                                   index: resolvedAnchor.index,
                                                   containerOriginY: containerOriginY)
            else { return 0 }
            return newAnchorY - oldAnchorY
        }()
#if DEBUG
        if (logicalSizeChanged || insetsChanged),
           !hasItems, !hasScrollTo,
           !oldWindow.isEmpty, !newWindow.isEmpty {
            assert(resolvedAnchorIdentity.flatMap { oldState[$0] } != nil,
                   "nonempty geometry-only passes must retain their resolved anchor")
        }
#endif

        var newSettledOffset = containerOriginY - newWindow.minY
        let geometryMustSettleToLoadedEdges = logicalSizeChanged || insetsChanged
        if !hasScrollTo, diff.moves.isEmpty || geometryMustSettleToLoadedEdges,
           (!wasOverscrolledPrePass || geometryMustSettleToLoadedEdges) {
            let edges = loadedEdgeRange(for: newWindow, originY: containerOriginY)
            var maximum = edges.max
            if let minimum = edges.min, let rawMaximum = maximum, rawMaximum < minimum {
                maximum = minimum
            }
            if let minimum = edges.min { newSettledOffset = max(newSettledOffset, minimum) }
            if let maximum { newSettledOffset = min(newSettledOffset, maximum) }
        }
        let newBoundsOriginY = hasScrollTo
            ? newSettledOffset
            : newSettledOffset + presentationOverscroll
        setBoundsOriginY(newBoundsOriginY)

        for item in newWindow.items {
            let identity = effectiveItems[item.index].identity
            if oldRenderedState[identity]?.view !== item.view {
                attachLive(identity: identity, layer: item.view.layer)
            }
        }

        let newState = settledState(newWindow,
                                    sourceItems: effectiveItems,
                                    containerOriginY: containerOriginY,
                                    at: transactionTime)
        let liveEdges = Dictionary(uniqueKeysWithValues: newState.map { identity, state in
            (identity, GhostLiveEdges(minY: state.contentY,
                                      maxY: state.contentY + state.size.height))
        })
        let transactionOffset = engine.offset
        let oldLiveEdgeCoordinateShift = transactionOffset - oldBoundsOriginY
        let oldLiveEdges = Dictionary(uniqueKeysWithValues: oldState.map { identity, state in
            (identity, GhostLiveEdges(
                minY: state.contentY + oldLiveEdgeCoordinateShift,
                maxY: state.contentY + state.size.height + oldLiveEdgeCoordinateShift
            ))
        })
        let oldIDs = Set(oldRenderedState.keys)
        let newIDs = Set(newState.keys)
        let movedIDs = Set(diff.moves.compactMap { move in
            effectiveItems.indices.contains(move.new)
                ? effectiveItems[move.new].identity
                : nil
        })
        let hasGhostOrderChange = !diff.deletes.isEmpty
            || !diff.inserts.isEmpty
            || !diff.moves.isEmpty
        let hasMeasuredGhostGeometryChange = (hasDirty || hasContentChanges)
            && oldIDs.intersection(newIDs).contains { identity in
                guard let old = oldRenderedState[identity], let new = newState[identity] else {
                    return false
                }
                let epsilon: CGFloat = 1e-6
                return abs(old.contentY + oldLiveEdgeCoordinateShift - new.contentY) > epsilon
                    || abs(old.size.width - new.size.width) > epsilon
                    || abs(old.size.height - new.size.height) > epsilon
            }
        let hasGhostGeometryPass = hasGhostOrderChange
            || logicalSizeChanged || insetsChanged
            || hasMeasuredGhostGeometryChange
        let movedOldIndices = Set(diff.moves.map { $0.old })
        let movedNewIndices = Set(diff.moves.map { $0.new })
        let insertedIdentities: Set<AnyHashable> = Set(diff.inserts.compactMap { index -> AnyHashable? in
            guard effectiveItems.indices.contains(index),
                  !movedNewIndices.contains(index) else { return nil }
            return effectiveItems[index].identity
        })
        let anchorIdentity = resolvedAnchorIdentity
        let anchorY = anchorIdentity.flatMap { newState[$0]?.contentY }
        var moveAmbiguousNewBlockIDs: Set<GhostBlockID> = []
        for id in newGhostBlockIDs {
            guard let render = ghostRenders[id],
                  let block = ghostLedger.snapshot(for: id) else { continue }
            let initialWitness = initialGhostWitness(
                block: block,
                departedRange: render.departedRange,
                diff: diff,
                movedOldIndices: movedOldIndices,
                movedNewIndices: movedNewIndices,
                insertedIdentities: insertedIdentities,
                oldItems: oldItems,
                newItems: effectiveItems,
                newState: newState,
                anchorY: anchorY
            )
            _ = ghostLedger.setBoundaryLink(
                attachmentEdge: initialWitness.attachmentEdge,
                witness: initialWitness.witness,
                for: id
            )
            if let identity = ghostWitnessIdentity(initialWitness.witness),
               insertedIdentities.contains(identity) {
                ghostLedger.sealBoundary(for: id)
            }
            if initialWitness.isMoveAmbiguous {
                moveAmbiguousNewBlockIDs.insert(id)
            }
        }
        if hasGhostGeometryPass {
            let allNewBlockIDs = Set(newGhostBlockIDs)
            migrateInvalidGhostWitnesses(
                blockIDs: moveAmbiguousNewBlockIDs,
                insertedIdentities: insertedIdentities,
                newBlockByDepartedIdentity: newGhostBlockByDepartedIdentity,
                movedIDs: movedIDs,
                liveState: newState,
                liveEdges: liveEdges,
                oldLiveEdges: oldLiveEdges,
                anchorIdentity: anchorIdentity
            )
            migrateInvalidGhostWitnesses(
                blockIDs: Set(ghostLedger.snapshots.map(\.id))
                    .subtracting(allNewBlockIDs),
                insertedIdentities: insertedIdentities,
                newBlockByDepartedIdentity: newGhostBlockByDepartedIdentity,
                movedIDs: movedIDs,
                liveState: newState,
                liveEdges: liveEdges,
                oldLiveEdges: oldLiveEdges,
                anchorIdentity: anchorIdentity
            )
        }
        assertGhostInvariants()

        var overlapCoordinateShift: CGFloat?
        var transitionViewportFrom: CGFloat?
        var viewportTrack: ListAnimationTrack?
        if let scrollTo, isOverlappingScroll || isCarouselScroll {
            let newOrder = effectiveItems.map(\.identity)
            let directionAnchorIdentity: AnyHashable? = {
                if let currentAnchorIdentity,
                   newIdentities.contains(currentAnchorIdentity) {
                    return currentAnchorIdentity
                }
                guard let currentAnchorIdentity,
                      let oldAnchorIndex = oldItems.firstIndex(where: {
                          $0.identity == currentAnchorIdentity
                      })
                else { return nil }
                let survivingOldIndices = oldItems.indices.filter {
                    newIdentities.contains(oldItems[$0].identity)
                }
                guard let nearestOldIndex = survivingOldIndices.min(by: { lhs, rhs in
                    let lhsDistance = abs(lhs - oldAnchorIndex)
                    let rhsDistance = abs(rhs - oldAnchorIndex)
                    return lhsDistance == rhsDistance
                        ? lhs < rhs
                        : lhsDistance < rhsDistance
                }) else { return nil }
                return oldItems[nearestOldIndex].identity
            }()
            let direction = ViewportTransitionGeometry.direction(
                currentAnchor: directionAnchorIdentity,
                targetIndex: scrollTo.index,
                newOrder: newOrder
            )
            if isOverlappingScroll,
               let reference = ViewportTransitionGeometry.overlapReference(
                currentAnchor: currentAnchorIdentity,
                direction: direction,
                oldLoaded: oldLoadedIdentities,
                newLoaded: newLoadedIdentities,
                newOrder: newOrder
            ), let oldReference = oldState[reference],
               let newReference = newState[reference] {
                let coordinateShift = ViewportTransitionGeometry.coordinateShift(
                    oldReferenceY: oldReference.contentY,
                    newReferenceY: newReference.contentY
                )
                let viewportFrom = ViewportTransitionGeometry.overlapViewportFrom(
                    oldEngineOffset: oldBoundsOriginY,
                    currentViewportCorrection: currentViewportCorrection,
                    coordinateShift: coordinateShift,
                    newEngineOffset: transactionOffset
                )
                let mutation = transitionViewportPreservingDetachedBoundary(
                    oldEngineOffset: oldBoundsOriginY,
                    currentViewportCorrection: currentViewportCorrection,
                    oldSettledOffset: oldBoundsOriginY + coordinateShift,
                    newSettledOffset: transactionOffset,
                    animation: animation,
                    transactionTime: transactionTime) { [weak self] generation in
                    self?.finishViewportGeneration(generation)
                }
                overlapCoordinateShift = coordinateShift
                transitionViewportFrom = viewportFrom
                viewportTrack = mutation.startedTrack

                if case .immediate = mutation {
                    resetViewportCarries()
                }
            } else if isCarouselScroll {
                let oldRenderedOffset = oldBoundsOriginY + currentViewportCorrection
                let oldLoadedTop = oldContainerOriginY - oldRenderedOffset
                let newLoadedTop = containerOriginY - transactionOffset
                let viewportFrom = ViewportTransitionGeometry.carouselViewportFrom(
                    direction: direction,
                    oldVisibleTop: oldLoadedTop,
                    newVisibleTop: newLoadedTop,
                    oldStripHeight: oldWindow.height,
                    newWindowHeight: newWindow.height
                )
                let syntheticOldSettledOffset = transactionOffset
                    + viewportFrom - currentViewportCorrection
                let mutation = transitionViewportPreservingDetachedBoundary(
                    oldEngineOffset: oldBoundsOriginY,
                    currentViewportCorrection: currentViewportCorrection,
                    oldSettledOffset: syntheticOldSettledOffset,
                    newSettledOffset: transactionOffset,
                    animation: animation,
                    transactionTime: transactionTime) { [weak self] generation in
                    self?.finishViewportGeneration(generation)
                }
                transitionViewportFrom = viewportFrom
                viewportTrack = mutation.startedTrack

                if case .immediate = mutation {
                    resetViewportCarries()
                }

#if DEBUG
                if let track = mutation.startedTrack {
                    assert(abs(track.from - viewportFrom) <= 1e-6)
                    let mappedOldTop = ViewportTransitionGeometry.mappedContentY(
                        oldScreenY: oldLoadedTop,
                        newEngineOffset: transactionOffset,
                        viewportFrom: viewportFrom
                    )
                    let initialOutgoingTop = mappedOldTop
                        - (transactionOffset + viewportFrom)
                    let initialIncomingTop = newLoadedTop - viewportFrom
                    assert(abs(initialOutgoingTop - oldLoadedTop) <= 1e-6)
                    switch direction {
                    case .forward:
                        assert(abs(initialIncomingTop
                                   - (initialOutgoingTop + oldWindow.height)) <= 1e-6)
                    case .backward:
                        assert(abs(initialIncomingTop + newWindow.height
                                   - initialOutgoingTop) <= 1e-6)
                    }
                }
#endif
            }
        }

        if viewportTrack == nil, logicalSizeChanged || insetsChanged {
            let syntheticOldOffset = oldBoundsOriginY + anchorCoordinateShift
            let mutation = transitionViewportPreservingDetachedBoundary(
                oldEngineOffset: oldBoundsOriginY,
                currentViewportCorrection: currentViewportCorrection,
                oldSettledOffset: syntheticOldOffset,
                newSettledOffset: transactionOffset,
                animation: animation,
                transactionTime: transactionTime) { [weak self] generation in
                self?.finishViewportGeneration(generation)
            }
            transitionViewportFrom = mutation.startedTrack?.from
            viewportTrack = mutation.startedTrack
            // Row geometry remains in content coordinates; the shared viewport track owns
            // the screen-space displacement for this pass.
            overlapCoordinateShift = anchorCoordinateShift
            if case .immediate = mutation {
                resetViewportCarries()
            }
        }

        if let track = viewportTrack, let viewportFrom = transitionViewportFrom {
            for index in viewportCarries.indices {
                viewportCarries[index].generation = track.generation
            }
            for identity in oldLoadedIdentities where potentialCarryIdentities.contains(identity) {
                guard let old = oldState[identity] else { continue }
                let oldScreenY = old.contentY + old.positionOffset
                    - (oldBoundsOriginY + currentViewportCorrection)
                let mappedY = ViewportTransitionGeometry.mappedContentY(
                    oldScreenY: oldScreenY,
                    newEngineOffset: transactionOffset,
                    viewportFrom: viewportFrom
                )
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                old.view.onContentDidChange = nil
                old.view.layer.anchorPoint = CGPoint(x: 0, y: 0)
                old.view.layer.position.x = old.contentX + old.positionOffsetX
                old.view.layer.bounds.size.width = old.visualWidth
                exitOverlay.addSubview(old.view)
                CATransaction.commit()
                let owner = animationController.makeTransient(
                    identity: identity,
                    layer: old.view.layer,
                    contentY: mappedY,
                    transactionTime: transactionTime
                )
                viewportCarries.append(ViewportCarry(
                    generation: track.generation,
                    owner: owner,
                    identity: identity,
                    view: old.view,
                    settledX: old.contentX + old.positionOffsetX,
                    settledWidth: old.visualWidth
                ))
            }
        } else {
            for identity in oldLoadedIdentities where potentialCarryIdentities.contains(identity) {
                guard let old = oldState[identity] else { continue }
                animationController.unbind(identity: identity,
                                           layer: old.view.layer,
                                           at: transactionTime)
            }
        }

        if logicalSizeChanged || insetsChanged {
            transitionDetachedHorizontalGeometry(animation: animation,
                                                 transactionTime: transactionTime)
        }

        if hasGhostGeometryPass {
            transitionGhostBlocks(liveEdges: liveEdges,
                                  logicalDuration: animationDuration,
                                  transactionTime: transactionTime)
        }

        let sharedDisplacementSamples: [CrossingDisplacementSample] = oldIDs
            .intersection(newIDs)
            .compactMap { identity in
                guard !movedIDs.contains(identity),
                      let indices = survivorEndpointIndices[identity],
                      let old = oldRenderedState[identity],
                      let new = newState[identity]
                else { return nil }
                let coordinates = transitionCoordinates(
                    old: old,
                    new: new,
                    oldBoundsOriginY: oldBoundsOriginY,
                    transactionOffset: transactionOffset,
                    overlapCoordinateShift: overlapCoordinateShift
                )
                return CrossingDisplacementSample(
                    identity: identity,
                    oldIndex: indices.oldIndex,
                    newIndex: indices.newIndex,
                    oldY: coordinates.oldY,
                    newY: coordinates.newY
                )
            }
        let newCoordinateBase = overlapCoordinateShift == nil ? 0 : transactionOffset
        let newCoordinateY: (SettledLiveItem) -> CGFloat = { state in
            overlapCoordinateShift == nil
                ? state.contentY - transactionOffset
                : state.contentY
        }
        let newOccupiedMinY = newState.values.map(newCoordinateY).min()
        let newOccupiedMaxY = newState.values.map {
            newCoordinateY($0) + $0.size.height
        }.max()
        let newCrossingBand = CrossingRetentionBand(
            minY: newCoordinateBase - preloadMargin,
            maxY: newCoordinateBase + logicalSize.height + preloadMargin,
            anchorY: anchorIdentity.flatMap { newState[$0] }.map(newCoordinateY),
            anchorIndex: resolvedAnchor?.index,
            occupiedMinY: newOccupiedMinY,
            occupiedMaxY: newOccupiedMaxY
        )
        let oldCoordinateBase = overlapCoordinateShift.map {
            oldBoundsOriginY + $0
        } ?? 0
        let oldCoordinateY: (SettledLiveItem) -> CGFloat = { state in
            if let shift = overlapCoordinateShift {
                return state.contentY + shift
            }
            return state.contentY - oldBoundsOriginY
        }
        let oldOccupiedMinY = oldState.values.map(oldCoordinateY).min()
        let oldOccupiedMaxY = oldState.values.map {
            oldCoordinateY($0) + $0.size.height
        }.max()
        let oldAnchorY = currentAnchorIdentity.flatMap { oldRenderedState[$0] }
            .map(oldCoordinateY)
        let oldCrossingBand = CrossingRetentionBand(
            minY: oldCoordinateBase - preloadMargin,
            maxY: oldCoordinateBase + logicalSize.height + preloadMargin,
            anchorY: oldAnchorY,
            anchorIndex: currentAnchorIdentity.flatMap { oldRenderedState[$0]?.index },
            occupiedMinY: oldOccupiedMinY,
            occupiedMaxY: oldOccupiedMaxY
        )
        let outgoingEndpoints = outgoingCrossingIdentities.compactMap {
            identity -> CrossingKnownEndpoint? in
            guard let old = oldRenderedState[identity],
                  let indices = survivorEndpointIndices[identity]
            else { return nil }
            let knownOldY = overlapCoordinateShift.map { old.contentY + $0 }
                ?? (old.contentY - oldBoundsOriginY)
            return CrossingKnownEndpoint(
                identity: identity,
                side: .old,
                oldIndex: indices.oldIndex,
                newIndex: indices.newIndex,
                y: knownOldY,
                height: old.size.height,
                isMoveParticipant: indices.isMoveParticipant
            )
        }.sorted { $0.oldIndex < $1.oldIndex }
        for plan in CrossingSurvivorPlanner.infer(
            endpoints: outgoingEndpoints,
            samples: sharedDisplacementSamples,
            band: newCrossingBand
        ) {
            guard let old = oldRenderedState[plan.identity] else { continue }
            let newSettledContentY = overlapCoordinateShift == nil
                ? plan.newY + transactionOffset
                : plan.newY
            installOutgoingCrossingCarry(
                from: old,
                plan: plan,
                newSettledContentY: newSettledContentY,
                logicalDuration: animationDuration,
                transactionTime: transactionTime,
                fallbackReleaseGeneration: viewportTrack?.generation
            )
        }
        let oldCollectionIdentities = Set(oldItems.map(\.identity))
        let incomingCrossingIdentities: Set<AnyHashable> = {
            guard hasSettledMembershipTransition, !isCarouselScroll else { return [] }
            return newIDs.subtracting(oldIDs).intersection(oldCollectionIdentities)
        }()
        let incomingEndpoints = incomingCrossingIdentities.compactMap {
            identity -> CrossingKnownEndpoint? in
            guard let new = newState[identity],
                  let indices = survivorEndpointIndices[identity]
            else { return nil }
            let knownNewY = overlapCoordinateShift == nil
                ? new.contentY - transactionOffset
                : new.contentY
            return CrossingKnownEndpoint(
                identity: identity,
                side: .new,
                oldIndex: indices.oldIndex,
                newIndex: indices.newIndex,
                y: knownNewY,
                height: new.size.height,
                isMoveParticipant: indices.isMoveParticipant
            )
        }.sorted { $0.newIndex < $1.newIndex }
        for plan in CrossingSurvivorPlanner.infer(
            endpoints: incomingEndpoints,
            samples: sharedDisplacementSamples,
            band: oldCrossingBand
        ) {
            guard let new = newState[plan.identity] else { continue }
            transitionIncomingCrossingSurvivor(
                new,
                plan: plan,
                logicalDuration: animationDuration,
                transactionTime: transactionTime
            )
        }

        for identity in oldIDs.intersection(newIDs) {
            guard let old = oldRenderedState[identity], let new = newState[identity] else { continue }
            let coordinates = transitionCoordinates(
                old: old,
                new: new,
                oldBoundsOriginY: oldBoundsOriginY,
                transactionOffset: transactionOffset,
                overlapCoordinateShift: overlapCoordinateShift
            )
            animationController.transitionPosition(
                identity: identity,
                layer: new.view.layer,
                oldSettledY: coordinates.oldY,
                newSettledY: coordinates.newY,
                animation: animation,
                transactionTime: transactionTime
            )
            animationController.transitionPositionX(
                identity: identity,
                layer: new.view.layer,
                oldSettledX: old.contentX,
                newSettledX: new.contentX,
                animation: animation,
                transactionTime: transactionTime
            )
            animationController.transitionWidth(
                identity: identity,
                layer: new.view.layer,
                oldSettledWidth: old.size.width,
                newSettledWidth: new.size.width,
                animation: animation,
                transactionTime: transactionTime
            )
            animationController.transitionHeight(
                identity: identity,
                layer: new.view.layer,
                oldSettledHeight: old.size.height,
                newSettledHeight: new.size.height,
                animation: animation,
                transactionTime: transactionTime
            )
        }

        let insertedIDs = Set(diff.inserts.compactMap { newIndex in
            effectiveItems.indices.contains(newIndex)
                ? effectiveItems[newIndex].identity
                : nil
        }).subtracting(movedIDs)
        for identity in newIDs.subtracting(oldIDs).intersection(insertedIDs) {
            guard let new = newState[identity] else { continue }
            animationController.insert(identity: identity,
                                       layer: new.view.layer,
                                       logicalDuration: animationDuration,
                                       transactionTime: transactionTime)
        }
    }

    private func settledPredecessorsChanged(identity: AnyHashable,
                                            oldItems: [CoreListItem],
                                            newItems: [CoreListItem]) -> Bool {
        guard let oldIndex = oldItems.firstIndex(where: { $0.identity == identity }),
              let newIndex = newItems.firstIndex(where: { $0.identity == identity })
        else { return false }
        let oldPredecessors = Set(oldItems[..<oldIndex].map(\.identity))
        let newPredecessors = Set(newItems[..<newIndex].map(\.identity))
        return oldPredecessors != newPredecessors
    }

    func setBoundsOriginY(_ y: CGFloat) {
        applyEngineShift(y - engine.offset)
        previousOffset = engine.offset
    }

    private func rebuildFromScratch() {
        defer { refreshReachedLoadedEdges() }
        engine.setOffset(engine.offset)
        resetViewportCarries()
        animationController.reset()
        ghostLedger.reset()
        ghostRenders.removeAll()
        crossingCarries.removeAll()
        activeWindow = Window()
        container.subviews.forEach { $0.removeFromSuperview() }
        crossingOverlay.subviews.forEach { $0.removeFromSuperview() }
        exitOverlay.subviews.forEach { $0.removeFromSuperview() }
        engine.contentHost.frame = bounds
        layoutExitOverlay()
        engine.setEdges(min: 0, max: 0)
        containerOriginY = 0
        animationController.seedViewport(layer: engine.contentHost.layer)
        assertGhostInvariants()

        guard contentWidth > 0,
              logicalSize.height > 0,
              !_items.isEmpty else { return }

        activeWindow = buildWindow(anchoredAt: 0,
                                   pointOffset: 0,
                                   pinsLoadedTop: true,
                                   sourceWindow: nil)
        render()
        var initialOffset = containerOriginY - activeWindow.minY
        let edges = loadedEdgeRange(for: activeWindow, originY: containerOriginY)
        if let minimum = edges.min { initialOffset = max(initialOffset, minimum) }
        if let maximum = edges.max { initialOffset = min(initialOffset, maximum) }
        if activeWindow.startIndex == 0 { initialOffset = viewportGeometry.minimumOffset }
        setBoundsOriginY(initialOffset)
        for item in activeWindow.items {
            animationController.seedLive(identity: _items[item.index].identity,
                                         layer: item.view.layer)
        }
    }

    private func resolveAnchor(scrollTo: (index: Int, pointOffset: CGFloat)?,
                               anchorMode: CoreListAnchorMode,
                               isNoOverlapSwap: Bool,
                               diff: ItemDiff,
                               oldWindow: Window,
                               oldContainerOriginY: CGFloat,
                               oldSettledOffset: CGFloat,
                               oldTopInset: CGFloat,
                               oldItemCount: Int) -> ResolvedAnchor? {
        if let scrollTo {
            engine.setOffset(engine.offset)
            return ResolvedAnchor(index: scrollTo.index,
                                  pointOffset: scrollTo.pointOffset,
                                  preservesVisibleContent: false)
        }
        if anchorMode == .preserveVisibleContent,
           let preserved = resolvePreservedAnchor(
               diff: diff,
               oldWindow: oldWindow,
               oldContainerOriginY: oldContainerOriginY,
               oldSettledOffset: oldSettledOffset,
               oldTopInset: oldTopInset
           ) {
            return preserved
        }
        if isNoOverlapSwap {
            engine.setOffset(engine.offset)
            return ResolvedAnchor(index: 0,
                                  pointOffset: 0,
                                  preservesVisibleContent: false)
        }
        let oldEdges = loadedEdgeRange(for: oldWindow,
                                       originY: oldContainerOriginY,
                                       itemCount: oldItemCount)
        if oldWindow.startIndex == 0,
           let minimum = oldEdges.min,
           abs(oldSettledOffset - minimum) <= 1e-6 {
            return ResolvedAnchor(index: 0,
                                  pointOffset: 0,
                                  preservesVisibleContent: false)
        }

        let scrollY = oldSettledOffset
        let absoluteBase = oldContainerOriginY - oldWindow.minY
        let topItem = oldWindow.items.first { absoluteBase + $0.frame.maxY > scrollY }
        let topItemWasDeleted = topItem.map { diff.survivorMap[$0.index] == nil } ?? false
        let firstVisibleSurvivor = oldWindow.items.first {
            diff.survivorMap[$0.index] != nil && absoluteBase + $0.frame.maxY > scrollY
        }
        let lastSurvivorAbove = oldWindow.items.last {
            diff.survivorMap[$0.index] != nil && absoluteBase + $0.frame.maxY <= scrollY
        }

        func pinnedOffset(_ item: Window.Item) -> CGFloat {
            oldContainerOriginY + item.frame.minY - oldWindow.minY - oldSettledOffset
        }

        if topItemWasDeleted,
           let item = lastSurvivorAbove,
           let newIndex = diff.survivorMap[item.index] {
            return ResolvedAnchor(index: newIndex,
                                  pointOffset: pinnedOffset(item),
                                  preservesVisibleContent: false)
        }
        if let item = firstVisibleSurvivor,
           let newIndex = diff.survivorMap[item.index] {
            return ResolvedAnchor(index: newIndex,
                                  pointOffset: pinnedOffset(item),
                                  preservesVisibleContent: false)
        }
        if let item = lastSurvivorAbove,
           let newIndex = diff.survivorMap[item.index] {
            return ResolvedAnchor(index: newIndex,
                                  pointOffset: pinnedOffset(item),
                                  preservesVisibleContent: false)
        }
        if let nearest = diff.survivorMap.min(by: { $0.value < $1.value }) {
            return ResolvedAnchor(index: nearest.value,
                                  pointOffset: 0,
                                  preservesVisibleContent: false)
        }
        return nil
    }

    private func resolvePreservedAnchor(diff: ItemDiff,
                                        oldWindow: Window,
                                        oldContainerOriginY: CGFloat,
                                        oldSettledOffset: CGFloat,
                                        oldTopInset: CGFloat) -> ResolvedAnchor? {
        let absoluteBase = oldContainerOriginY - oldWindow.minY
        let insetEdgeY = oldSettledOffset + oldTopInset
        guard let witnessPosition = oldWindow.items.firstIndex(where: {
            absoluteBase + $0.frame.maxY > insetEdgeY
        }) else {
            return nil
        }

        func resolved(_ positions: [Int]) -> ResolvedAnchor? {
            for position in positions {
                let item = oldWindow.items[position]
                guard let newIndex = diff.survivingNewIndex(
                    forOldIndex: item.index
                ) else { continue }
                let pointOffset = absoluteBase + item.frame.minY - oldSettledOffset
                return ResolvedAnchor(index: newIndex,
                                      pointOffset: pointOffset,
                                      preservesVisibleContent: true)
            }
            return nil
        }

        if let below = resolved(Array(witnessPosition..<oldWindow.items.endIndex)) {
            return below
        }
        return resolved(Array(
            oldWindow.items.indices[..<witnessPosition].reversed()
        ))
    }

    fileprivate func markDirty(_ view: UIView, animated: Bool) {
        guard let item = activeWindow.items.first(where: { $0.view === view }) else { return }
        dirtyIndices.insert(item.index)
        dirtyAnimated = dirtyAnimated || animated
        if !dirtyFlushScheduled {
            dirtyFlushScheduled = true
            scheduler.schedule { [weak self] in self?.flushDirtyItems() }
        }
    }

    private func flushDirtyItems() {
        dirtyFlushScheduled = false
        guard !dirtyIndices.isEmpty else { return }
        let animated = dirtyAnimated
        applyChanges(animationDuration: animated ? defaultDirtyDuration : 0)
    }

    private func handleUserScroll(_ currentY: CGFloat) {
        var delta = currentY - previousOffset
        if abs(delta) > logicalSize.height {
            delta = logicalSize.height * (delta > 0 ? 1 : -1)
            engine.setOffset(previousOffset + delta)
        }
        previousOffset = engine.offset
        rebalanceActiveWindow()
        refreshReachedLoadedEdges()
        onVisibleWindowChanged?()
    }

    private func rebalanceActiveWindow() {
        guard !activeWindow.isEmpty else { return }

        let scrollY = engine.offset
        let band = projectedLoadBand
        let width = contentWidth
        let preRebalanceIdentities = Set(activeWindow.items.map { _items[$0.index].identity })
        let absoluteBase = containerOriginY - activeWindow.minY
        var window = activeWindow
        var changed = false

        while window.items.count > 1,
              let first = window.items.first,
              projectedFrame(first.frame,
                             contentBaseY: absoluteBase,
                             viewportOffset: scrollY).maxY < band.lowerBound {
            animationController.unbind(identity: _items[first.index].identity,
                                       layer: first.view.layer)
            window.items.removeFirst()
            changed = true
        }

        while window.items.count > 1,
              let last = window.items.last,
              projectedFrame(last.frame,
                             contentBaseY: absoluteBase,
                             viewportOffset: scrollY).minY > band.upperBound {
            animationController.unbind(identity: _items[last.index].identity,
                                       layer: last.view.layer)
            window.items.removeLast()
            changed = true
        }

        while let first = window.items.first,
              projectedFrame(first.frame,
                             contentBaseY: absoluteBase,
                             viewportOffset: scrollY).minY > band.lowerBound,
              window.startIndex > 0 {
            prependItem(to: &window, width: width, sourceWindow: nil)
            changed = true
        }

        while let last = window.items.last,
              projectedFrame(last.frame,
                             contentBaseY: absoluteBase,
                             viewportOffset: scrollY).maxY < band.upperBound,
              window.endIndex < _items.count - 1 {
            appendItem(to: &window, width: width, sourceWindow: nil)
            changed = true
        }

        guard changed else { return }
        let promotedCrossingIdentities = Set(window.items.map {
            _items[$0.index].identity
        }).intersection(crossingCarries.keys)
        for identity in promotedCrossingIdentities {
            crossingCarries.removeValue(forKey: identity)
        }
        activeWindow = window
        let newOriginY = computeContainerOriginY(for: window)
        let newAbsoluteBase = newOriginY - window.minY
        if abs(newAbsoluteBase - absoluteBase) > 0.5 {
            applyEngineShift(newAbsoluteBase - absoluteBase)
            previousOffset = engine.offset
        }
        render()

        for item in window.items {
            let identity = _items[item.index].identity
            if !preRebalanceIdentities.contains(identity) {
                attachLive(identity: identity, layer: item.view.layer)
            }
        }
    }

    private var projectedLoadBand: ClosedRange<CGFloat> {
        -preloadMargin ... logicalSize.height + preloadMargin
    }

    private func projectedFrame(_ frame: CGRect,
                                contentBaseY: CGFloat,
                                viewportOffset: CGFloat) -> CGRect {
        frame.offsetBy(dx: 0, dy: contentBaseY - viewportOffset)
    }

    private func translate(_ window: inout Window, by deltaY: CGFloat) {
        guard abs(deltaY) > 1e-9 else { return }
        for index in window.items.indices {
            window.items[index].frame.origin.y += deltaY
        }
    }

    private func buildWindow(anchoredAt index: Int,
                             pointOffset: CGFloat,
                             pinsLoadedTop: Bool = false,
                             sourceWindow: Window?,
                             survivorMapNewToOld: [Int: Int]? = nil,
                             moveReuseNewToOld: [Int: Int]? = nil) -> Window {
        let width = contentWidth
        let itemX = viewportInsets.left
        let view = viewForItem(at: index,
                               sourceWindow: sourceWindow,
                               survivorMapNewToOld: survivorMapNewToOld,
                               moveReuseNewToOld: moveReuseNewToOld)
        let height = view.update(width: width)
        var window = Window(items: [
            Window.Item(index: index,
                        view: view,
                        frame: CGRect(x: itemX, y: pointOffset, width: width, height: height))
        ])

        let band = projectedLoadBand
        let topEdge = viewportInsets.top
        let bottomEdge = logicalSize.height - viewportInsets.bottom

        func alignTopIfUnderfilled() -> Bool {
            guard window.startIndex == 0, window.minY > topEdge else { return false }
            translate(&window, by: topEdge - window.minY)
            return true
        }

        func alignBottomIfUnderfilled() -> Bool {
            guard window.endIndex == _items.count - 1,
                  window.maxY < bottomEdge else { return false }
            translate(&window, by: bottomEdge - window.maxY)
            return true
        }

        func prependUntilCoveredOrAtTop() {
            while window.minY > band.lowerBound, window.startIndex > 0 {
                prependItem(to: &window,
                            width: width,
                            sourceWindow: sourceWindow,
                            survivorMapNewToOld: survivorMapNewToOld,
                            moveReuseNewToOld: moveReuseNewToOld)
            }
        }

        func appendUntilCoveredOrAtBottom() {
            while window.maxY < band.upperBound,
                  window.endIndex < _items.count - 1 {
                appendItem(to: &window,
                           width: width,
                           sourceWindow: sourceWindow,
                           survivorMapNewToOld: survivorMapNewToOld,
                           moveReuseNewToOld: moveReuseNewToOld)
            }
        }

        prependUntilCoveredOrAtTop()
        if pinsLoadedTop, window.startIndex == 0 {
            translate(&window, by: topEdge - window.minY)
        } else {
            _ = alignTopIfUnderfilled()
        }
        appendUntilCoveredOrAtBottom()

        if window.endIndex == _items.count - 1,
           window.maxY < bottomEdge {
            let wholeCollectionIsUnderfilled = window.startIndex == 0
                && window.height + viewportInsets.top + viewportInsets.bottom
                    <= logicalSize.height
            if wholeCollectionIsUnderfilled {
                translate(&window, by: topEdge - window.minY)
            } else if alignBottomIfUnderfilled() {
                prependUntilCoveredOrAtTop()
                if window.startIndex == 0,
                   window.height + viewportInsets.top + viewportInsets.bottom
                        <= logicalSize.height {
                    translate(&window, by: topEdge - window.minY)
                } else {
                    _ = alignTopIfUnderfilled()
                }
            }
        }

        return window
    }

    private func prependItem(to window: inout Window,
                             width: CGFloat,
                             sourceWindow: Window?,
                             survivorMapNewToOld: [Int: Int]? = nil,
                             moveReuseNewToOld: [Int: Int]? = nil) {
        let index = window.startIndex - 1
        guard index >= 0, let first = window.items.first else { return }
        let view = viewForItem(at: index,
                               sourceWindow: sourceWindow,
                               survivorMapNewToOld: survivorMapNewToOld,
                               moveReuseNewToOld: moveReuseNewToOld)
        let height = view.update(width: width)
        window.items.insert(
            Window.Item(index: index,
                        view: view,
                        frame: CGRect(x: viewportInsets.left,
                                      y: first.frame.minY - height,
                                      width: width,
                                      height: height)),
            at: 0
        )
    }

    private func appendItem(to window: inout Window,
                            width: CGFloat,
                            sourceWindow: Window?,
                            survivorMapNewToOld: [Int: Int]? = nil,
                            moveReuseNewToOld: [Int: Int]? = nil) {
        let index = window.endIndex + 1
        guard _items.indices.contains(index) else { return }
        let view = viewForItem(at: index,
                               sourceWindow: sourceWindow,
                               survivorMapNewToOld: survivorMapNewToOld,
                               moveReuseNewToOld: moveReuseNewToOld)
        let height = view.update(width: width)
        window.items.append(
            Window.Item(index: index,
                        view: view,
                        frame: CGRect(x: viewportInsets.left,
                                      y: window.items.last?.frame.maxY ?? 0,
                                      width: width,
                                      height: height))
        )
    }

    private func viewForItem(at index: Int,
                             sourceWindow: Window?,
                             survivorMapNewToOld: [Int: Int]? = nil,
                             moveReuseNewToOld: [Int: Int]? = nil) -> UIView & CoreListItemView {
        if let oldIndex = survivorMapNewToOld?[index],
           let existing = sourceWindow?.items.first(where: { $0.index == oldIndex })?.view {
            return existing
        }
        if let oldIndex = moveReuseNewToOld?[index],
           let existing = sourceWindow?.items.first(where: { $0.index == oldIndex })?.view {
            return existing
        }
        let identity = _items[index].identity
        if let carry = crossingCarries[identity] {
            return carry.view
        }
        return _items[index].view()
    }

    private func loadedEdgeRange(for window: Window,
                                 originY: CGFloat,
                                 itemCount: Int? = nil) -> (min: CGFloat?, max: CGFloat?) {
        guard !window.isEmpty else { return (0, 0) }
        let count = itemCount ?? _items.count
        let minimum: CGFloat? = window.startIndex == 0
            ? viewportGeometry.minimumOffset
            : nil
        let maximum: CGFloat? = window.endIndex == count - 1
            ? viewportGeometry.maximumOffset(
                contentBottom: originY - window.minY + window.maxY
            )
            : nil
        return (minimum, maximum)
    }

    private func refreshReachedLoadedEdges() {
        guard !activeWindow.isEmpty, !_items.isEmpty else {
            reachedLoadedEdges.removeAll()
            return
        }

        let limits = loadedEdgeRange(for: activeWindow, originY: containerOriginY)
        var settledOffset = engine.offset
        if let minimum = limits.min {
            settledOffset = max(settledOffset, minimum)
        }
        if let maximum = limits.max {
            settledOffset = min(settledOffset, maximum)
        }

        let epsilon: CGFloat = 1e-6
        let topBoundaryY = containerOriginY - settledOffset
        let bottomBoundaryY = containerOriginY
            - activeWindow.minY
            + activeWindow.maxY
            - settledOffset
        let topLine = loadedEdgeMargin
        let bottomLine = logicalSize.height - loadedEdgeMargin

        var reached: Set<CoreListLoadedEdge> = []
        if activeWindow.startIndex == 0,
           topBoundaryY >= topLine - epsilon {
            reached.insert(.top)
        }
        if activeWindow.endIndex == _items.count - 1,
           bottomBoundaryY <= bottomLine + epsilon {
            reached.insert(.bottom)
        }

        let arrivals = reached.subtracting(reachedLoadedEdges)
        reachedLoadedEdges = reached
        for edge in [CoreListLoadedEdge.top, .bottom] where arrivals.contains(edge) {
            onLoadedEdgeReached?(edge)
        }
    }

    private func computeContainerOriginY(for window: Window) -> CGFloat {
        guard !window.isEmpty else { return 0 }
        return engine.containerOrigin(windowHeight: window.height,
                                      topLoaded: window.startIndex == 0,
                                      bottomLoaded: window.endIndex == _items.count - 1)
    }

    private func render() {
        let window = activeWindow
        let newOriginY = computeContainerOriginY(for: window)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        container.frame = CGRect(x: 0,
                                 y: newOriginY,
                                 width: logicalSize.width,
                                 height: max(1, window.height))
        for subview in container.subviews
            where !window.items.contains(where: { $0.view === subview }) {
            subview.removeFromSuperview()
        }
        for item in window.items {
            item.view.layer.anchorPoint = CGPoint(x: 0, y: 0)
            item.view.frame = item.frame.offsetBy(dx: 0, dy: -window.minY)
            item.view.layer.opacity = 1
            item.view.onContentDidChange = { [weak self, weak view = item.view] animated in
                guard let self, let view else { return }
                self.markDirty(view, animated: animated)
            }
            if item.view.superview !== container { container.addSubview(item.view) }
        }
        CATransaction.commit()

        let edges = loadedEdgeRange(for: window, originY: newOriginY)
        let offsetBeforeEdges = engine.offset
        engine.setEdges(min: edges.min, max: edges.max)
        shiftExitOverlayChildren(by: engine.offset - offsetBeforeEdges)
        containerOriginY = newOriginY
    }

    private func settledState(_ window: Window,
                              sourceItems: [CoreListItem],
                              containerOriginY: CGFloat,
                              at time: TimeInterval) -> [AnyHashable: SettledLiveItem] {
        Dictionary(uniqueKeysWithValues: window.items.map { item in
            let identity = sourceItems[item.index].identity
            let localY = item.frame.minY - window.minY
            let positionOffset = animationController.positionOffset(
                identity: identity,
                at: time
            ) ?? 0
            let positionOffsetX = animationController.positionOffsetX(
                identity: identity,
                at: time
            ) ?? 0
            return (
                identity,
                SettledLiveItem(
                    index: item.index,
                    identity: identity,
                    view: item.view,
                    contentX: item.frame.minX,
                    contentY: containerOriginY + localY,
                    positionOffsetX: positionOffsetX,
                    positionOffset: positionOffset,
                    opacity: animationController.opacity(
                        owner: .live(identity),
                        at: time
                    ) ?? 1,
                    size: item.frame.size,
                    visualWidth: animationController.width(
                        identity: identity,
                        at: time
                    ) ?? item.frame.width,
                    visualHeight: animationController.height(
                        identity: identity,
                        at: time
                    ) ?? item.frame.height
                )
            )
        })
    }

    private func settledContentY(in window: Window,
                                 index: Int,
                                 containerOriginY: CGFloat) -> CGFloat? {
        guard let frame = window.localFrame(for: index) else { return nil }
        return containerOriginY + frame.minY - window.minY
    }

    private func crossingCarryState(
        sourceItems: [CoreListItem],
        at time: TimeInterval
    ) -> [AnyHashable: SettledLiveItem] {
        Dictionary(uniqueKeysWithValues: crossingCarries.values.compactMap { carry in
            guard let index = sourceItems.firstIndex(where: {
                $0.identity == carry.identity
            }) else { return nil }
            let size = carry.view.bounds.size
            return (
                carry.identity,
                SettledLiveItem(
                    index: index,
                    identity: carry.identity,
                    view: carry.view,
                    contentX: carry.view.layer.position.x,
                    contentY: carry.settledContentY,
                    positionOffsetX: animationController.positionOffsetX(
                        identity: carry.identity,
                        at: time
                    ) ?? 0,
                    positionOffset: animationController.positionOffset(
                        identity: carry.identity,
                        at: time
                    ) ?? 0,
                    opacity: animationController.opacity(
                        owner: .live(carry.identity),
                        at: time
                    ) ?? 1,
                    size: size,
                    visualWidth: animationController.width(
                        identity: carry.identity,
                        at: time
                    ) ?? size.width,
                    visualHeight: animationController.height(
                        identity: carry.identity,
                        at: time
                    ) ?? size.height
                )
            )
        })
    }

    private func transitionCoordinates(
        old: SettledLiveItem,
        new: SettledLiveItem,
        oldBoundsOriginY: CGFloat,
        transactionOffset: CGFloat,
        overlapCoordinateShift: CGFloat?
    ) -> (oldY: CGFloat, newY: CGFloat) {
        if let overlapCoordinateShift {
            return (old.contentY + overlapCoordinateShift, new.contentY)
        }
        return (old.contentY - oldBoundsOriginY,
                new.contentY - transactionOffset)
    }

    private func installOutgoingCrossingCarry(
        from old: SettledLiveItem,
        plan: CrossingEndpointPlan,
        newSettledContentY: CGFloat,
        logicalDuration: TimeInterval,
        transactionTime: TimeInterval,
        fallbackReleaseGeneration: UInt64?
    ) {
        guard var carry = crossingCarries[old.identity], carry.view === old.view else {
            return
        }
        if carry.releaseGeneration != nil,
           abs(carry.settledContentY - newSettledContentY) <= 1e-6 {
            return
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        old.view.layer.position.y = newSettledContentY
        CATransaction.commit()
        carry.settledContentY = newSettledContentY
        crossingCarries[old.identity] = carry

        let mutation = animationController.transitionPosition(
            identity: old.identity,
            layer: old.view.layer,
            oldSettledY: plan.oldY,
            newSettledY: plan.newY,
            logicalDuration: logicalDuration,
            transactionTime: transactionTime
        ) { [weak self, weak view = old.view] generation in
            guard let view else { return }
            self?.finishCrossingCarry(identity: old.identity,
                                      generation: generation,
                                      view: view)
        }
        switch mutation {
        case let .started(track):
            guard var current = crossingCarries[old.identity],
                  current.view === old.view else { return }
            current.releaseGeneration = track.generation
            crossingCarries[old.identity] = current
        case .immediate:
            removeCrossingCarry(identity: old.identity, removeLiveOwner: true)
        case .unchanged:
            if let fallbackReleaseGeneration,
               var current = crossingCarries[old.identity],
               current.view === old.view {
                current.releaseGeneration = fallbackReleaseGeneration
                crossingCarries[old.identity] = current
            } else if crossingCarries[old.identity]?.releaseGeneration == nil {
                removeCrossingCarry(identity: old.identity, removeLiveOwner: true)
            }
        }
    }

    private func transitionIncomingCrossingSurvivor(
        _ new: SettledLiveItem,
        plan: CrossingEndpointPlan,
        logicalDuration: TimeInterval,
        transactionTime: TimeInterval
    ) {
        animationController.transitionPosition(
            identity: new.identity,
            layer: new.view.layer,
            oldSettledY: plan.oldY,
            newSettledY: plan.newY,
            logicalDuration: logicalDuration,
            transactionTime: transactionTime
        )
    }

    private func transitionDetachedHorizontalGeometry(
        animation: ListAnimationSpec,
        transactionTime: TimeInterval
    ) {
        let targetX = viewportInsets.left
        let targetWidth = contentWidth

        for blockID in Array(ghostRenders.keys) {
            guard var render = ghostRenders[blockID] else { continue }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            render.wrapper.layer.bounds.size.width = logicalSize.width
            CATransaction.commit()
            for key in Array(render.members.keys) {
                guard var member = render.members[key] else { continue }
                animationController.transitionPositionX(
                    owner: member.owner,
                    layer: member.view.layer,
                    oldSettledX: member.settledX,
                    newSettledX: targetX,
                    animation: animation,
                    transactionTime: transactionTime
                )
                animationController.transitionWidth(
                    owner: member.owner,
                    layer: member.view.layer,
                    oldSettledWidth: member.settledWidth,
                    newSettledWidth: targetWidth,
                    animation: animation,
                    transactionTime: transactionTime
                )
                member.settledX = targetX
                member.settledWidth = targetWidth
                render.members[key] = member
            }
            ghostRenders[blockID] = render
        }

        for identity in Array(crossingCarries.keys) {
            guard var carry = crossingCarries[identity] else { continue }
            animationController.transitionPositionX(
                identity: identity,
                layer: carry.view.layer,
                oldSettledX: carry.settledX,
                newSettledX: targetX,
                animation: animation,
                transactionTime: transactionTime
            )
            animationController.transitionWidth(
                identity: identity,
                layer: carry.view.layer,
                oldSettledWidth: carry.settledWidth,
                newSettledWidth: targetWidth,
                animation: animation,
                transactionTime: transactionTime
            )
            carry.settledX = targetX
            carry.settledWidth = targetWidth
            crossingCarries[identity] = carry
        }

        for index in viewportCarries.indices {
            var carry = viewportCarries[index]
            animationController.transitionPositionX(
                owner: carry.owner,
                layer: carry.view.layer,
                oldSettledX: carry.settledX,
                newSettledX: targetX,
                animation: animation,
                transactionTime: transactionTime
            )
            animationController.transitionWidth(
                owner: carry.owner,
                layer: carry.view.layer,
                oldSettledWidth: carry.settledWidth,
                newSettledWidth: targetWidth,
                animation: animation,
                transactionTime: transactionTime
            )
            carry.settledX = targetX
            carry.settledWidth = targetWidth
            viewportCarries[index] = carry
        }
    }

    private func finishCrossingCarry(identity: AnyHashable,
                                     generation: UInt64,
                                     view: UIView) {
        guard let carry = crossingCarries[identity],
              carry.releaseGeneration == generation,
              carry.view === view,
              !activeWindow.items.contains(where: {
                  _items.indices.contains($0.index)
                      && _items[$0.index].identity == identity
              })
        else { return }
        crossingCarries.removeValue(forKey: identity)
        animationController.unbind(identity: identity, layer: view.layer)
        view.removeFromSuperview()
    }

    private func removeCrossingCarry(identity: AnyHashable,
                                     removeLiveOwner: Bool) {
        guard let carry = crossingCarries.removeValue(forKey: identity) else { return }
        if removeLiveOwner {
            animationController.unbind(identity: identity, layer: carry.view.layer)
        }
        carry.view.removeFromSuperview()
    }

    private func makeGhostBlock(from items: [SettledLiveItem],
                                logicalDuration: TimeInterval,
                                transactionTime: TimeInterval) -> GhostBlockID {
        precondition(!items.isEmpty)
        let rootY = items[0].contentY + items[0].positionOffset
        let localYs = items.map { $0.contentY + $0.positionOffset - rootY }
        let localMinY = localYs.min() ?? 0
        let localMaxY = zip(items, localYs).map { item, localY in
            localY + item.visualHeight
        }.max() ?? 0
        let id = ghostLedger.insert(rootY: rootY,
                                    localMinY: localMinY,
                                    localMaxY: localMaxY,
                                    witness: .unresolved,
                                    visibleMemberCount: items.count)
        let owner = ListAnimationOwner.ghostBlock(id.rawValue)
        let wrapper = UIView()
        wrapper.backgroundColor = .clear
        wrapper.clipsToBounds = false
        wrapper.isUserInteractionEnabled = false

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        wrapper.layer.anchorPoint = CGPoint(x: 0, y: 0)
        wrapper.layer.bounds = CGRect(x: 0,
                                      y: 0,
                                      width: logicalSize.width,
                                      height: max(1, localMaxY - localMinY))
        wrapper.layer.position = CGPoint(x: 0, y: rootY)
        exitOverlay.addSubview(wrapper)
        for (item, localY) in zip(items, localYs) {
            item.view.onContentDidChange = nil
            item.view.layer.anchorPoint = CGPoint(x: 0, y: 0)
            wrapper.addSubview(item.view)
            item.view.frame = CGRect(x: item.contentX + item.positionOffsetX,
                                     y: localY,
                                     width: item.visualWidth,
                                     height: item.visualHeight)
            item.view.layer.opacity = Float(item.opacity)
        }
        CATransaction.commit()

        animationController.seedGhostBlock(owner: owner,
                                           layer: wrapper.layer,
                                           settledRootY: rootY)
        let placeholderMembers = Dictionary(uniqueKeysWithValues: items.map { item in
            let member = GhostMember(owner: .live(item.identity),
                                     view: item.view,
                                     settledX: item.contentX + item.positionOffsetX,
                                     settledWidth: item.visualWidth)
            return (ObjectIdentifier(item.view), member)
        })
        ghostRenders[id] = GhostBlockRender(
            owner: owner,
            wrapper: wrapper,
            members: placeholderMembers,
            departedRange: items[0].index..<(items[items.count - 1].index + 1)
        )

        for (item, localY) in zip(items, localYs) {
            let memberOwner = makeExit(from: item,
                                       localY: localY,
                                       blockID: id,
                                       logicalDuration: logicalDuration,
                                       transactionTime: transactionTime)
            let key = ObjectIdentifier(item.view)
            if var render = ghostRenders[id], render.members[key] != nil {
                render.members[key] = GhostMember(
                    owner: memberOwner,
                    view: item.view,
                    settledX: item.contentX + item.positionOffsetX,
                    settledWidth: item.visualWidth
                )
                ghostRenders[id] = render
            }
        }
        assertGhostInvariants()
        return id
    }

    @discardableResult
    private func makeExit(from item: SettledLiveItem,
                          localY: CGFloat,
                          blockID: GhostBlockID,
                          logicalDuration: TimeInterval,
                          transactionTime: TimeInterval) -> ListAnimationOwner {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        item.view.frame = CGRect(x: item.contentX + item.positionOffsetX,
                                 y: localY,
                                 width: item.visualWidth,
                                 height: item.visualHeight)
        item.view.layer.opacity = Float(item.opacity)
        CATransaction.commit()

        return animationController.makeExit(
            identity: item.identity,
            layer: item.view.layer,
            contentY: localY,
            logicalDuration: logicalDuration,
            transactionTime: transactionTime
        ) { [weak self, weak view = item.view] in
            guard let view else { return }
            self?.finishGhostMember(blockID: blockID, view: view)
        }
    }

    private func finishGhostMember(blockID: GhostBlockID, view: UIView) {
        let key = ObjectIdentifier(view)
        guard var render = ghostRenders[blockID],
              let member = render.members.removeValue(forKey: key),
              member.view === view else { return }
        view.removeFromSuperview()
        ghostRenders[blockID] = render
        ghostLedger.removeVisibleMember(from: blockID)
        collectGhostBlocks()
        assertGhostInvariants()
    }

    private func collectGhostBlocks() {
        for id in ghostLedger.collectOrphanedEmptyBlocks() {
            guard let render = ghostRenders.removeValue(forKey: id) else { continue }
            render.wrapper.removeFromSuperview()
            animationController.removeGhostBlock(owner: render.owner,
                                                 layer: render.wrapper.layer)
        }
    }

    private func migrateInvalidGhostWitnesses(
        blockIDs: Set<GhostBlockID>,
        insertedIdentities: Set<AnyHashable>,
        newBlockByDepartedIdentity: [AnyHashable: GhostBlockID],
        movedIDs: Set<AnyHashable>,
        liveState: [AnyHashable: SettledLiveItem],
        liveEdges: [AnyHashable: GhostLiveEdges],
        oldLiveEdges: [AnyHashable: GhostLiveEdges],
        anchorIdentity: AnyHashable?
    ) {
        let epsilon: CGFloat = 1e-6
        let anchorY = anchorIdentity.flatMap { liveState[$0]?.contentY }

        let snapshots = ghostLedger.snapshots
            .filter { blockIDs.contains($0.id) }
            .sorted { $0.id < $1.id }
        for snapshot in snapshots {
            if snapshot.isBoundaryOpen,
               let occupant = insertedIdentities.compactMap({ identity -> SettledLiveItem? in
                   guard let state = liveState[identity],
                         abs(state.contentY - snapshot.settledRootY) <= epsilon else { return nil }
                   return state
               }).min(by: { $0.index < $1.index }) {
                _ = ghostLedger.setBoundaryLink(
                    attachmentEdge: .minY,
                    witness: .liveMinY(occupant.identity),
                    for: snapshot.id
                )
                ghostLedger.sealBoundary(for: snapshot.id)
                continue
            }
            guard ghostWitnessNeedsMigration(snapshot.witness,
                                             movedIDs: movedIDs,
                                             liveState: liveState) else { continue }
            let boundaryY = invalidGhostBoundaryY(snapshot,
                                                  oldLiveEdges: oldLiveEdges)

            if let exact = exactDepartingWitnessHandoff(
                from: snapshot.witness,
                sourceID: snapshot.id,
                boundaryY: boundaryY,
                newBlockByDepartedIdentity: newBlockByDepartedIdentity,
                liveEdges: liveEdges,
                epsilon: epsilon
            ) {
                _ = ghostLedger.setWitness(exact, for: snapshot.id)
                continue
            }

            guard let anchorY else {
                _ = ghostLedger.setWitness(.unresolved, for: snapshot.id)
                continue
            }

            let searchesAbove = anchorY < boundaryY - epsilon
            var candidates: [GhostWitnessCandidate] = []
            for (identity, state) in liveState where !movedIDs.contains(identity) {
                let edgeY = searchesAbove
                    ? state.contentY + state.size.height
                    : state.contentY
                guard searchesAbove
                    ? edgeY <= boundaryY + epsilon
                    : edgeY >= boundaryY - epsilon else { continue }
                candidates.append(GhostWitnessCandidate(
                    witness: searchesAbove ? .liveMaxY(identity) : .liveMinY(identity),
                    edgeY: edgeY,
                    carrierOrder: state.index
                ))
            }

            let provisionalTargets = ghostLedger.resolvedTargets(liveEdges: liveEdges)
            for carrier in ghostLedger.snapshots where carrier.id != snapshot.id {
                guard let rootY = provisionalTargets[carrier.id],
                      let render = ghostRenders[carrier.id] else { continue }
                let witness: GhostBoundaryWitness = searchesAbove
                    ? .ghostMaxY(carrier.id)
                    : .ghostMinY(carrier.id)
                guard ghostLedger.canSetWitness(witness, for: snapshot.id) else { continue }
                let edgeY = rootY + (searchesAbove ? carrier.localMaxY : carrier.localMinY)
                guard searchesAbove
                    ? edgeY <= boundaryY + epsilon
                    : edgeY >= boundaryY - epsilon else { continue }
                candidates.append(GhostWitnessCandidate(
                    witness: witness,
                    edgeY: edgeY,
                    carrierOrder: render.departedRange.lowerBound
                ))
            }

            let selected = candidates.min { lhs, rhs in
                let lhsDistance = abs(lhs.edgeY - boundaryY)
                let rhsDistance = abs(rhs.edgeY - boundaryY)
                if abs(lhsDistance - rhsDistance) > epsilon {
                    return lhsDistance < rhsDistance
                }
                if lhs.carrierOrder != rhs.carrierOrder {
                    return lhs.carrierOrder < rhs.carrierOrder
                }
                let lhsDescription = ghostWitnessStableDescription(lhs.witness)
                let rhsDescription = ghostWitnessStableDescription(rhs.witness)
                if lhsDescription != rhsDescription {
                    return lhsDescription < rhsDescription
                }
                return ghostWitnessBlockID(lhs.witness) < ghostWitnessBlockID(rhs.witness)
            }
            if let selected {
                _ = ghostLedger.setBoundaryLink(
                    attachmentEdge: searchesAbove ? .minY : .maxY,
                    witness: selected.witness,
                    for: snapshot.id
                )
            } else {
                _ = ghostLedger.setWitness(.unresolved, for: snapshot.id)
            }
        }
    }

    private func invalidGhostBoundaryY(
        _ snapshot: GhostBlockSnapshot,
        oldLiveEdges: [AnyHashable: GhostLiveEdges]
    ) -> CGFloat {
        switch snapshot.witness {
        case let .liveMinY(identity):
            return oldLiveEdges[identity]?.minY ?? snapshot.settledRootY
        case let .liveMaxY(identity):
            return oldLiveEdges[identity]?.maxY ?? snapshot.settledRootY
        case .ghostMinY, .ghostMaxY, .unresolved:
            return snapshot.settledRootY
        }
    }

    private func ghostWitnessNeedsMigration(
        _ witness: GhostBoundaryWitness,
        movedIDs: Set<AnyHashable>,
        liveState: [AnyHashable: SettledLiveItem]
    ) -> Bool {
        switch witness {
        case let .liveMinY(identity), let .liveMaxY(identity):
            return movedIDs.contains(identity) || liveState[identity] == nil
        case .unresolved:
            return true
        case .ghostMinY, .ghostMaxY:
            return false
        }
    }

    private func ghostWitnessIdentity(_ witness: GhostBoundaryWitness) -> AnyHashable? {
        switch witness {
        case let .liveMinY(identity), let .liveMaxY(identity): return identity
        case .ghostMinY, .ghostMaxY, .unresolved: return nil
        }
    }

    private func exactDepartingWitnessHandoff(
        from witness: GhostBoundaryWitness,
        sourceID: GhostBlockID,
        boundaryY: CGFloat,
        newBlockByDepartedIdentity: [AnyHashable: GhostBlockID],
        liveEdges: [AnyHashable: GhostLiveEdges],
        epsilon: CGFloat
    ) -> GhostBoundaryWitness? {
        let identity: AnyHashable
        let useMinimum: Bool
        switch witness {
        case let .liveMinY(value):
            identity = value
            useMinimum = true
        case let .liveMaxY(value):
            identity = value
            useMinimum = false
        case .ghostMinY, .ghostMaxY, .unresolved:
            return nil
        }
        guard let targetID = newBlockByDepartedIdentity[identity],
              let target = ghostLedger.snapshot(for: targetID) else { return nil }
        let candidate: GhostBoundaryWitness = useMinimum
            ? .ghostMinY(targetID)
            : .ghostMaxY(targetID)
        guard ghostLedger.canSetWitness(candidate, for: sourceID),
              let rootY = ghostLedger.resolvedTargets(liveEdges: liveEdges)[targetID]
        else { return nil }
        let edgeY = rootY + (useMinimum ? target.localMinY : target.localMaxY)
        return abs(edgeY - boundaryY) <= epsilon ? candidate : nil
    }

    private func ghostWitnessStableDescription(_ witness: GhostBoundaryWitness) -> String {
        switch witness {
        case let .liveMinY(identity): return "liveMinY:\(String(reflecting: identity))"
        case let .liveMaxY(identity): return "liveMaxY:\(String(reflecting: identity))"
        case .ghostMinY: return "ghostMinY"
        case .ghostMaxY: return "ghostMaxY"
        case .unresolved: return "unresolved"
        }
    }

    private func ghostWitnessBlockID(_ witness: GhostBoundaryWitness) -> UInt64 {
        switch witness {
        case let .ghostMinY(id), let .ghostMaxY(id): return id.rawValue
        case .liveMinY, .liveMaxY, .unresolved: return 0
        }
    }

    private func transitionGhostBlocks(
        liveEdges: [AnyHashable: GhostLiveEdges],
        logicalDuration: TimeInterval,
        transactionTime: TimeInterval
    ) {
        let targets = ghostLedger.resolvedTargets(liveEdges: liveEdges)
        for snapshot in ghostLedger.snapshots.sorted(by: { $0.id < $1.id }) {
            guard let target = targets[snapshot.id],
                  let render = ghostRenders[snapshot.id] else { continue }
            animationController.transitionGhostBlock(
                owner: render.owner,
                layer: render.wrapper.layer,
                oldSettledY: snapshot.settledRootY,
                newSettledY: target,
                logicalDuration: logicalDuration,
                transactionTime: transactionTime
            )
            ghostLedger.setSettledRootY(target, for: snapshot.id)
        }
    }

    private func initialGhostWitness(
        block: GhostBlockSnapshot,
        departedRange: Range<Int>,
        diff: ItemDiff,
        movedOldIndices: Set<Int>,
        movedNewIndices: Set<Int>,
        insertedIdentities: Set<AnyHashable>,
        oldItems: [CoreListItem],
        newItems: [CoreListItem],
        newState: [AnyHashable: SettledLiveItem],
        anchorY: CGFloat?
    ) -> (attachmentEdge: GhostBlockEdge,
          witness: GhostBoundaryWitness,
          isMoveAmbiguous: Bool) {
        let ghostMaxY = block.settledRootY + block.localMaxY
        let anchorFacingEdge: GhostBlockEdge = anchorY.map {
            $0 >= ghostMaxY - 1e-6
        } == true ? .maxY : .minY
        let predecessor = oldItems.indices[..<departedRange.lowerBound].reversed().first {
            diff.survivorMap[$0] != nil && !movedOldIndices.contains($0)
        }
        let ordinal = predecessor.flatMap { diff.survivorMap[$0] }.map { $0 + 1 } ?? 0
        if newItems.indices.contains(ordinal) {
            if movedNewIndices.contains(ordinal) {
                return (anchorFacingEdge, .unresolved, true)
            }
            let identity = newItems[ordinal].identity
            let witness: GhostBoundaryWitness = newState[identity] == nil
                ? .unresolved
                : .liveMinY(identity)
            let attachmentEdge: GhostBlockEdge = insertedIdentities.contains(identity)
                ? .minY
                : anchorFacingEdge
            return (attachmentEdge, witness, false)
        }
        if ordinal == newItems.count,
           let identity = newItems.last?.identity,
           newState[identity] != nil {
            return (.minY, .liveMaxY(identity), false)
        }
        return (anchorFacingEdge, .unresolved, false)
    }

    func ghostRender(for id: GhostBlockID)
        -> (owner: ListAnimationOwner, wrapper: UIView)? {
        guard let render = ghostRenders[id] else { return nil }
        return (render.owner, render.wrapper)
    }

    func ghostBlockID(containing view: UIView) -> GhostBlockID? {
        let key = ObjectIdentifier(view)
        return ghostRenders.first { _, render in
            render.members[key]?.view === view
        }?.key
    }

    private func finishViewportGeneration(_ generation: UInt64) {
        let finished = viewportCarries.filter { $0.generation == generation }
        viewportCarries.removeAll { $0.generation == generation }
        for carry in finished {
            animationController.removeTransient(owner: carry.owner,
                                                layer: carry.view.layer)
            carry.view.removeFromSuperview()
        }
        let finishedCrossings = crossingCarries.values.filter {
            $0.releaseGeneration == generation
        }
        for carry in finishedCrossings {
            finishCrossingCarry(identity: carry.identity,
                                generation: generation,
                                view: carry.view)
        }
    }

    private func resetViewportCarries() {
        let carries = viewportCarries
        viewportCarries.removeAll()
        for carry in carries {
            animationController.removeTransient(owner: carry.owner,
                                                layer: carry.view.layer)
            carry.view.removeFromSuperview()
        }
    }

    private func prepareViewportCarriesForReplacement(
        oldRenderedViewport: CGFloat,
        newRenderedViewport: CGFloat,
        appliedEngineShift: CGFloat,
        oldSettledOffset: CGFloat,
        newSettledOffset: CGFloat,
        logicalDuration: TimeInterval
    ) {
        let epsilon: CGFloat = 1e-6
        guard logicalDuration > 0,
              abs(newSettledOffset - oldSettledOffset) > epsilon
        else { return }

        // Normal rendering/rebasing has already shifted overlay children by the
        // engine's actual delta. Apply the remainder of the exact boundary mapping
        // before replacing the additive viewport animation.
        let boundaryShift = newRenderedViewport - oldRenderedViewport
        shiftExitOverlayChildren(by: boundaryShift - appliedEngineShift)
    }

    private func transitionViewportPreservingDetachedBoundary(
        oldEngineOffset: CGFloat,
        currentViewportCorrection: CGFloat,
        oldSettledOffset: CGFloat,
        newSettledOffset: CGFloat,
        animation: ListAnimationSpec,
        transactionTime: TimeInterval,
        completion: @escaping (UInt64) -> Void
    ) -> ListAnimationMutation {
        let replacementFrom = oldSettledOffset
            + currentViewportCorrection - newSettledOffset
        prepareViewportCarriesForReplacement(
            oldRenderedViewport: oldEngineOffset + currentViewportCorrection,
            newRenderedViewport: newSettledOffset + replacementFrom,
            appliedEngineShift: newSettledOffset - oldEngineOffset,
            oldSettledOffset: oldSettledOffset,
            newSettledOffset: newSettledOffset,
            logicalDuration: animation.duration
        )
        let previousGeneration = animationController.model.track(
            for: .viewport,
            property: .viewportOffset
        )?.generation
        let mutation = animationController.transitionViewport(
            layer: engine.contentHost.layer,
            oldSettledOffset: oldSettledOffset,
            newSettledOffset: newSettledOffset,
            animation: animation,
            transactionTime: transactionTime,
            completion: completion
        )
        migrateCrossingViewportReleases(
            from: previousGeneration,
            through: mutation
        )
        return mutation
    }

    private func migrateCrossingViewportReleases(
        from previousGeneration: UInt64?,
        through mutation: ListAnimationMutation
    ) {
        guard let previousGeneration else { return }
        let identities = crossingCarries.compactMap { identity, carry in
            carry.releaseGeneration == previousGeneration ? identity : nil
        }

        switch mutation {
        case let .started(track):
            for identity in identities {
                crossingCarries[identity]?.releaseGeneration = track.generation
            }
        case .immediate:
            for identity in identities {
                removeCrossingCarry(identity: identity, removeLiveOwner: true)
            }
        case .unchanged:
            break
        }
    }

    private func layoutExitOverlay() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        crossingOverlay.frame = CGRect(origin: .zero,
                                       size: engine.contentHost.bounds.size)
        exitOverlay.frame = CGRect(origin: .zero,
                                   size: engine.contentHost.bounds.size)
        CATransaction.commit()
    }

    private func applyEngineShift(_ delta: CGFloat) {
        guard delta != 0 else { return }
        let offsetBeforeShift = engine.offset
        engine.applyShift(delta)
        shiftExitOverlayChildren(by: engine.offset - offsetBeforeShift)
    }

    private func shiftExitOverlayChildren(by delta: CGFloat) {
        guard delta != 0 else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for view in crossingOverlay.subviews {
            view.layer.position.y += delta
        }
        for view in exitOverlay.subviews {
            view.layer.position.y += delta
        }
        CATransaction.commit()
        for identity in Array(crossingCarries.keys) {
            guard var carry = crossingCarries[identity] else { continue }
            carry.settledContentY += delta
            crossingCarries[identity] = carry
        }
        ghostLedger.shiftRoots(by: delta)
        assertGhostInvariants()
    }

    private func assertGhostInvariants() {
#if DEBUG
        ghostLedger.assertInvariants()
        assert(Set(ghostMemberViews.map(ObjectIdentifier.init)).count
            == ghostMemberViews.count)
        let snapshots = ghostLedger.snapshots
        assert(Set(snapshots.map(\.id)) == Set(ghostRenders.keys))
        for snapshot in snapshots {
            guard let render = ghostRenders[snapshot.id] else {
                assertionFailure("ghost ledger node is missing its render record")
                continue
            }
            assert(render.members.count == snapshot.visibleMemberCount)
            assert(render.owner == .ghostBlock(snapshot.id.rawValue))
            assert(render.wrapper.superview === exitOverlay)
            assert(animationController.model.contains(render.owner))
        }
#endif
    }

    private func attachLive(identity: AnyHashable, layer: CALayer) {
        let now = animationController.now()
        if animationController.positionOffset(identity: identity, at: now) != nil
            || animationController.opacity(owner: .live(identity), at: now) != nil {
            animationController.rebind(identity: identity, layer: layer)
        } else {
            animationController.seedLive(identity: identity, layer: layer)
        }
    }
}

private extension ListAnimationMutation {
    var startedTrack: ListAnimationTrack? {
        guard case let .started(track) = self else { return nil }
        return track
    }
}
