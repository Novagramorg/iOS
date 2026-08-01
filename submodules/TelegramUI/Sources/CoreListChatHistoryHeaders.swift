import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import CoreList
import ComponentFlow
import ComponentDisplayAdapters
import TelegramPresentationData
import ChatMessageItem
import ChatMessageItemImpl

// Adapts a ListViewItemHeader onto CoreList's attachment feature.
//
// The mapping is near-exact rather than a translation, because CoreList's attachment solve
// (AttachmentOffsetMap) IS ListViewImpl.updateItemHeaders' math — same two clamp cases in the same
// order, with the degenerate-band comment citing Display/Source/ListView.swift:4019 and :4032.
// CoreListAttachedItem.combines(with:) exists because of ChatMessageAvatarHeader's 10-minute rule.
//
// Architecture and deferred items: docs/chat/corelist-chat-history-backend.md
final class CoreListHeaderAttachedItem: CoreListAttachedItem {
    let header: ListViewItemHeader
    // Weak, and read at `view()` time rather than stored as a value: a view is created whenever a run
    // enters the loaded window, which happens during a scroll rebalance long after this descriptor
    // was built. Only the backend knows whether headers are flashing RIGHT NOW.
    private weak var backend: CoreListChatHistoryBackend?

    init(header: ListViewItemHeader, backend: CoreListChatHistoryBackend?) {
        self.header = header
        self.backend = backend
    }

    // Chat rows already reserve the header's height in their own layout insets
    // (`layoutConstants.timestampHeaderHeight` folded into `layoutInsets.top` — see
    // ChatMessageBubbleItemNode.swift:3742 and its four sibling item nodes), so the attachment
    // overlays a gap it was already given. `.reservesSpace` would double it.
    var placement: CoreListAttachmentPlacement {
        return .overlay
    }

    // A direct mapping, not a flip. ListViewImpl(rotated: true) and CoreVirtualListView both lay
    // index 0 at their own top and let the chat wrapper's π put it at the screen bottom, and
    // ChatMessageDateHeader/ChatMessageAvatarHeader already resolve stickDirection against
    // controllerInteraction.chatIsRotated. `.topEdge` is unreachable from chat — no chat header
    // declares it — and `.top` is its nearest meaning.
    var edge: CoreListAttachmentEdge {
        switch self.header.stickDirection {
        case .top, .topEdge:
            return .top
        case .bottom:
            return .bottom
        }
    }

    var isFloating: Bool {
        return self.header.isSticky
    }

    // The flashing state must be seeded HERE, from the backend's live value.
    //
    // `setHeadersFlashing` pushes only on a CHANGE, so a view created while the flag is already true
    // — which is exactly what happens as new date runs stream in during a fling — would otherwise
    // never receive it and would seed its node from its own default `false`. Within that same frame
    // `renderAttachments` then delivers the first stick distance; if the run arrives already parked,
    // the factor crosses 0.5 and `updateFlashing` computes `false || false` and hides the pill. It
    // reappears only on the next flag flip, i.e. the user's next drag.
    func view() -> UIView & CoreListAttachedItemView {
        return CoreListHeaderHostView(header: self.header,
                                      isFlashingOnScrolling: self.backend?.isFlashingHeaders ?? false)
    }

    // Content equality, NOT instance equality. Chat rebuilds its header instances on every
    // transaction, so `===` would reconcile and re-measure every visible attachment on every pass.
    // These are the fields the header's own `updateNode` pushes into the node — nothing else can
    // change what the node renders.
    func isEqual(to other: CoreListAttachedItem) -> Bool {
        guard let other = other as? CoreListHeaderAttachedItem else {
            return false
        }
        if other.header.id != self.header.id {
            return false
        }
        if let lhs = self.header as? ChatMessageDateHeader,
           let rhs = other.header as? ChatMessageDateHeader {
            return lhs.presentationData === rhs.presentationData
        }
        if let lhs = self.header as? ChatMessageAvatarHeader,
           let rhs = other.header as? ChatMessageAvatarHeader {
            return lhs.presentationData === rhs.presentationData
                && lhs.peer?.id == rhs.peer?.id
                && lhs.storyStats == rhs.storyStats
        }
        // An unrecognised header type reconciles every pass rather than going stale.
        return false
    }

    func apply(to view: UIView & CoreListAttachedItemView, transition: CoreListTransition) {
        (view as? CoreListHeaderHostView)?.setHeader(self.header)
    }

    // The reason CoreListAttachedItem has this at all: ChatMessageAvatarHeader folds its day bucket
    // into its id and STILL needs "break the run if these two are ≥10 minutes apart", which is a
    // delta between neighbours that no key can express.
    func combines(with other: CoreListAttachedItem) -> Bool {
        guard let other = other as? CoreListHeaderAttachedItem else {
            return false
        }
        return self.header.combinesWith(other: other.header)
    }
}

// Hosts a ListViewItemHeaderNode inside CoreVirtualListView's attachment container. The
// attachment-side sibling of CoreListNodeHostView.
final class CoreListHeaderHostView: UIView, CoreListAttachedItemView {
    private(set) var header: ListViewItemHeader
    private(set) var headerNode: ListViewItemHeaderNode?
    private var appliedStickDistance: CGFloat?
    private var isFlashingOnScrolling = false

    var onContentDidChange: ((_ animated: Bool) -> Void)? = nil

    init(header: ListViewItemHeader, isFlashingOnScrolling: Bool) {
        self.header = header
        self.isFlashingOnScrolling = isFlashingOnScrolling
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // A strict PASSTHROUGH, for the same reason `AttachmentContainerView` is one: this host spans the
    // full content width (`update` frames the node at `width` × `header.height`) and floats above the
    // rows, so anything it claims and does not use is a touch a message bubble never sees.
    //
    // Delegating to the node's `hitTest` — not its `point(inside:)` — is the load-bearing part. The
    // node's view is full-width too, so its `point(inside:)` is true across the whole band; only
    // `hitTest` knows where the interactive content actually is, and both chat header nodes implement
    // exactly that. `ChatMessageDateHeaderNode` returns its view only inside the date/peer pill's
    // `backgroundNode.frame` and `nil` everywhere else, and `ChatMessageAvatarHeaderNode` forwards to
    // its `containerNode`, so a tap beside the pill or beside a gutter avatar belongs to the bubble
    // underneath. Testing `point(inside:)` one level down would reproduce the bug one level down.
    //
    // Overriding `point(inside:)` rather than `hitTest` is deliberate: `AttachmentContainerView`
    // decides whether to claim a point by asking each attachment's `point(inside:)`, so that is the
    // question this view has to answer correctly. `hitTest` then composes for free — UIKit's default
    // implementation recurses into the node view, whose own `hitTest` returns the right target.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard let nodeView = self.headerNode?.view else {
            return false
        }
        return nodeView.hitTest(self.convert(point, to: nodeView), with: event) != nil
    }

    func setHeader(_ header: ListViewItemHeader) {
        self.header = header
    }

    func update(width: CGFloat, transition: CoreListTransition) -> CGFloat {
        let headerNode: ListViewItemHeaderNode
        if let existing = self.headerNode {
            headerNode = existing
        } else {
            headerNode = self.header.node(synchronousLoad: true)
            self.headerNode = headerNode
            self.addSubview(headerNode.view)
            // ListViewImpl seeds a new header node the same way
            // (Display/Source/ListView.swift:4162). `isFlashingOnScrolling` came from the backend's
            // live value at `view()` time, so a header built mid-fling starts out correctly flashed
            // rather than hiding itself the moment its first stick distance crosses 0.5.
            headerNode.updateFlashingOnScrolling(self.isFlashingOnScrolling, animated: false)
        }

        // ListViewImpl's own guard (Display/Source/ListView.swift:4137 and :4158): push the new
        // descriptor into the node exactly when the instance changed.
        if headerNode.item !== self.header {
            self.header.updateNode(headerNode, previous: nil, next: nil)
            headerNode.item = self.header
        }

        // The node carries its own π when the chat is rotated, exactly as item nodes do, so it
        // counter-rotates inside this host and composes to upright content. Assigning `frame` on a
        // π-rotated node is what ListViewImpl does too (:4098) — the rotation preserves the bounding
        // box.
        let size = CGSize(width: width, height: self.header.height)
        headerNode.frame = CGRect(origin: CGPoint(), size: size)

        // Zero insets because CoreList already frames this view at `viewportInsets.left` with
        // `contentWidth`, whereas ListViewImpl hands header nodes the full list width plus the real
        // insets. The avatar's `leftInset + 7.0` therefore lands in the same place either way. One
        // deliberate divergence: the date pill centres in the content width rather than the full
        // width, so a landscape safe-area inset centres it in the visible content.
        headerNode.updateLayoutInternal(
            size: size,
            leftInset: 0.0,
            rightInset: 0.0,
            transition: ComponentTransition(transition).containedViewLayoutTransition
        )
        return size.height
    }

    // CoreList delivers points; ListViewImpl's header nodes take a 0…1 factor AND the raw distance.
    // The clamp is `max(0.0, min(1.0, distance / height))` verbatim from
    // Display/Source/ListView.swift:4024 — it lives here rather than in the engine because the
    // consumer is the side that knows its own height, and because the raw value is meaningful too
    // (a band shorter than its attachment reports a negative distance).
    //
    // `.immediate` matches ListViewImpl, whose scroll-driven updateItemHeaders calls pass the
    // default immediate transition.
    func stickDistanceUpdated(_ distance: CGFloat) {
        guard let headerNode = self.headerNode else {
            return
        }
        if let applied = self.appliedStickDistance, applied == distance {
            return
        }
        self.appliedStickDistance = distance
        let height = self.header.height
        let factor = height > 0.0 ? max(0.0, min(1.0, distance / height)) : 0.0
        headerNode.updateStickDistanceFactor(factor, distance: distance, transition: .immediate)
    }

    // The flag is stored even when no node exists yet, because `update(width:transition:)` seeds a
    // freshly built node from it. Both halves are needed: the backend pushes at transaction end
    // (which a view created during that pass receives), while a view created mid-scroll gets nothing
    // — `setHeadersFlashing` only pushes on a CHANGE, and the flag stays true throughout a scroll.
    func updateFlashingOnScrolling(_ isFlashing: Bool, animated: Bool) {
        guard self.isFlashingOnScrolling != isFlashing else {
            return
        }
        self.isFlashingOnScrolling = isFlashing
        self.headerNode?.updateFlashingOnScrolling(isFlashing, animated: animated)
    }
}

extension CoreListChatHistoryBackend {
    // The live header nodes, in the settled window's attachment order.
    //
    // `loadedAttachmentViews` is CoreList's own live set — a departed run is carried by the fade-out
    // path and never appears there — so this needs no liveness guard of its own. Same argument
    // `itemNodes` makes for rows.
    var itemHeaderNodes: some Sequence<ListViewItemHeaderNode> {
        return self.coreList.loadedAttachmentViews.lazy.compactMap {
            ($0 as? CoreListHeaderHostView)?.headerNode
        }
    }

    // Entering selection mode shifts bubbles right by 42pt and the avatars must follow.
    //
    // ListViewImpl routes this through ListViewItemNode.attachedHeaderNodes, which is deferred here
    // — and does not need to be reproduced for this: ChatMessageAvatarHeaderNodeImpl reads
    // `controllerInteraction.selectionState` itself, so the backend only has to say WHEN to re-read.
    // Mirrored as one Bool so an unchanged pass animates nothing, and left un-animated on the very
    // first push (nil mirror) so a chat that opens already in selection mode does not slide its
    // avatars in.
    //
    // A freshly built node needs nothing: ChatMessageAvatarHeaderNodeImpl.init ends with
    // `updateSelectionState(animated: false)`.
    func updateAvatarSelectionState() {
        var isActive: Bool?
        for view in self.coreList.loadedAttachmentViews {
            guard let hostView = view as? CoreListHeaderHostView,
                  let header = hostView.header as? ChatMessageAvatarHeader else {
                continue
            }
            isActive = header.controllerInteraction?.selectionState != nil
            break
        }
        guard let isActive, self.appliedSelectionStateIsActive != isActive else {
            return
        }
        let animated = self.appliedSelectionStateIsActive != nil
        self.appliedSelectionStateIsActive = isActive
        for node in self.itemHeaderNodes {
            (node as? ChatMessageAvatarHeaderNode)?.updateSelectionState(animated: animated)
        }
    }

    // The avatar's long-press context menu is a ContextControllerSourceNode inside the header node,
    // so starting a scroll must cancel it exactly as it does for a bubble's. Nothing more is needed:
    // `attachmentContainer` is a subview of `engine.contentHost`
    // (CoreVirtualListView.swift:677), so it already sits inside the
    // PhysicsScrollEngine.gestureRecognizer(_:shouldBeRequiredToFailBy:) gate that makes
    // press-and-hold recognize at all under this list.
    func cancelAttachmentContextGestures() {
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
        for view in self.coreList.loadedAttachmentViews {
            cancelContextGestures(view: view)
        }
    }

    // Parity with ListViewImpl's `scroller.isDragging || isDeceleratingAfterTracking ||
    // flashNodesDelayTimer != nil` (Display/Source/ListView.swift:859).
    //
    // This is NOT cosmetic and NOT separable from the stick distance. The date pill's alpha is
    // `flashingOnScrolling || stickDistanceFactor < 0.5` (ChatMessageDateHeader.swift,
    // updateFlashing), so a backend that reports the factor without this would hide the pill for
    // exactly as long as it is parked at the display edge.
    //
    // No new CoreList seam is needed: onVisibleWindowChanged is the engine.onScroll sink and
    // therefore ticks through momentum as well as dragging, so "no content movement for 0.3s" is the
    // same predicate ListViewImpl's timer expresses with the drag and deceleration terms folded in.
    func noteHeaderFlashingActivity() {
        self.headerFlashTimer?.invalidate()
        let timer = SwiftSignalKit.Timer(timeout: 0.3, repeat: false, completion: { [weak self] in
            guard let self else {
                return
            }
            self.headerFlashTimer = nil
            self.setHeadersFlashing(false, animated: true)
        }, queue: Queue.mainQueue())
        self.headerFlashTimer = timer
        timer.start()
        self.setHeadersFlashing(true, animated: true)
    }

    func setHeadersFlashing(_ flashing: Bool, animated: Bool) {
        guard self.isFlashingHeaders != flashing else {
            return
        }
        self.isFlashingHeaders = flashing
        self.pushHeaderFlashingState(animated: animated)
    }

    // Also called at transaction end, un-animated: a header view built during that pass has just
    // been seeded with this backend's flag, but one that already existed needs the current value
    // pushed to it.
    func pushHeaderFlashingState(animated: Bool) {
        for view in self.coreList.loadedAttachmentViews {
            (view as? CoreListHeaderHostView)?.updateFlashingOnScrolling(self.isFlashingHeaders,
                                                                         animated: animated)
        }
    }
}
