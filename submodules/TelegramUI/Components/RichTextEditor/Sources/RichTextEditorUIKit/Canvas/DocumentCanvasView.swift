#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// The multi-block document surface. ONE view owns every block and the unified global selection.
/// (Internal — only `RichTextEditorView` is public; keeps `UITextInput` witnesses internal.)
final class DocumentCanvasView: UIView {
    let root = BlockStack()
    var boxes: [CanvasBlock] { get { root.boxes } set { root.boxes = newValue } }
    let mapper: AttributedStringMapper
    var imageProvider: (String) -> UIImage? = { _ in nil }
    /// Returns a FRESH, non-interactive view for an emoji `id` sized to the requested square, or nil.
    /// The canvas owns/positions/removes it; a host with only a CALayer wraps it in a plain UIView.
    var emojiViewProvider: (_ id: String, _ size: CGSize) -> UIView? = { _, _ in nil }
    /// Hosted emoji views, keyed by `EmojiRef.instanceID` so edits/undo reuse (not recreate) them.
    /// Plain `internal` (NOT `private(set)`): the reconciler in `DocumentCanvasView+Emoji.swift` mutates it.
    var emojiViews: [String: HostedEmoji] = [:]
    /// Back-most container for blockquote run fills (see `BlockquoteUnderlay`). Behind every block view.
    let blockquoteUnderlay = BlockquoteUnderlay()
    /// Non-interactive container for body/caption emoji views (canvas coords). Kept below the chrome
    /// overlay (which is brought to front each layout pass). Cell emoji live in the table content view.
    let emojiOverlay = UIView()
    /// Hide an emoji view when its canvas frame is more than this far outside the visible viewport.
    var emojiCullMargin: CGFloat = 50
    /// Pooled dust views, keyed by spoiler-run identity so a hidden run keeps its animating emitter across
    /// reconcile passes. Mutated by the reconciler in `DocumentCanvasView+Spoilers.swift`.
    var spoilerDustViews: [SpoilerKey: HostedSpoilerDust] = [:]
    /// The spoiler runs found by the last `syncSpoilers` (hidden-state + canvas rects). Drives the tap
    /// hit-test. Recomputed each pass; never persisted.
    var spoilerRuns: [SpoilerRun] = []
    /// Set by a tap on a hidden spoiler so the next reconcile plays the EXPLOSION (vs a cross-fade) for that
    /// run, from the tap point. Consumed + cleared in one pass.
    var spoilerRevealHint: (key: SpoilerKey, canvasPoint: CGPoint)?
    /// Non-interactive container for body/caption dust views (canvas coords), above emoji, below the wash.
    /// Cell dust rides the table content view (like cell emoji).
    let spoilerOverlay = UIView()
    /// Hide a dust view when its canvas frame is more than this far outside the visible viewport.
    var spoilerCullMargin: CGFloat = 50
    /// True iff some leaf region currently carries a `.rtSpoiler` run. A cheap gate so `syncSpoilers` (which
    /// runs on every caret move) does NO work in a spoiler-free document. Recomputed only when the model
    /// changes (load / edit / undo) — never on a pure selection change.
    var documentHasSpoilers = false
    /// Overscan band (points) realized above AND below the visible viewport, so scrolling reveals an
    /// already-drawn paragraph instead of a blank flash. NEGATIVE (the default) ⇒ auto = one viewport
    /// height each side. Tunable via the façade (`RichTextEditorView.blockViewOverscan`).
    var blockViewOverscan: CGFloat = -1
    /// Persistent block-view subviews, keyed by BlockID so edits/undo reuse (not recreate) them.
    private(set) var blockViews: [BlockID: BlockBackingView] = [:]
    /// Bounded reuse queue of free PARAGRAPH/IMAGE backing views (both plain `BlockBackingView`). A culled
    /// view is detached + dropped from `blockViews` and pushed here; a newly-realized paragraph/image pops
    /// it and rebinds. Tables (`TableBackingView`) are heavyweight + few, so they are created/destroyed,
    /// not queued. Excess beyond the cap is released.
    private var recycleQueue: [BlockBackingView] = []
    private let recycleQueueCap = 24   // ~2–3 screenfuls of paragraphs at typical heights; excess freed views are released
    /// Topmost overlay that draws table structural chrome (outline, handles, knobs) ABOVE the block views.
    private let blockChromeOverlay = BlockChromeOverlay()
    /// Dedicated overlay that draws the selection highlight + image washes ON TOP of all non-table content
    /// (text, emoji, image atoms) — above the emoji overlay, below the chrome. Table-cell highlights ride
    /// their own content-view overlay (`CellSelectionView`) to keep horizontal overscroll.
    let selectionHighlight = SelectionHighlightView()

    /// The app's own blinking text caret (the canvas installs no `UITextSelectionDisplayInteraction`, so
    /// there is no OS caret). When the caret is inside a horizontally-scrollable table cell it's reparented
    /// into that table's scrolling content view so it rides the scroll/overscroll; otherwise it's a direct
    /// subview of the canvas.
    let caretView = CaretView()
    /// Own-drawn selection-handle lollipops (one per endpoint), shown for a ranged selection. Like the
    /// caret, each is hosted in the canvas or a table's scrolling content view per its endpoint's region,
    /// ON TOP of the wash. The handle DRAG is a separate proximity-gated pan (`isSelectionDragTouch`).
    let startHandleView = SelectionHandleView(isStart: true)
    let endHandleView = SelectionHandleView(isStart: false)
    /// The container + frame the caret view was last placed at, so a repeated `updateCaretView()` (e.g. on a
    /// scroll tick) that lands the caret at the SAME spot does NOT restart the blink.
    private weak var lastCaretContainer: UIView?
    private var lastCaretFrame: CGRect = .null

    /// Called whenever the canvas invalidates its intrinsic content size (its height may have changed
    /// after an edit/undo). The host (`RichTextEditorView`) sizes the canvas frame-based, not via Auto
    /// Layout, so `invalidateIntrinsicContentSize()` alone does NOT re-flow the host — without this hook
    /// a height change is only reflected on the next host layout pass (e.g. a rotation).
    var onContentSizeChange: (() -> Void)?
    /// Fired whenever the caret moves to a spot the host may need to reveal: the OS moving the selection
    /// through the `selectedTextRange` setter (hardware arrow navigation), and every editing operation
    /// that relocates the caret (typing, delete, Enter, IME-composition commit — via `editing { }` and the
    /// marked-text branch). The host uses it to scroll the caret into view, since these can land the caret
    /// off-screen (arrowing up out of a tall image; typing the line below the keyboard).
    var onSelectionChange: (() -> Void)?

    // Selection as global UTF-16 positions; `anchor` fixed, `head` moving.
    var anchor = 0
    var head = 0

    /// Last non-zero width laid out; used to rebuild boxes during undo (extensions can't add
    /// stored properties, so it lives here).
    var lastLayoutWidth: CGFloat = 0
    var effectiveWidth: CGFloat { lastLayoutWidth > 0 ? lastLayoutWidth : (bounds.width > 0 ? bounds.width : 320) }

    func clampGlobal(_ n: Int) -> Int { min(max(n, 0), documentSize) }

    /// Resolves a global position to the box that owns it, snapping structural-boundary and
    /// end-of-document positions to the nearest in-text position. Returns the box, the local
    /// UTF-16 offset, and the box's index.
    func resolveBox(at pos: Int) -> (box: CanvasBlock, local: Int, index: Int)? {
        if let (b, l) = box(containingGlobal: pos), let i = boxIndex(of: b) { return (b, l, i) }
        for (i, b) in boxes.enumerated() {
            if pos < b.textStart { return (b, 0, i) }
            if pos <= b.textStart + b.textLength { return (b, pos - b.textStart, i) }
        }
        if let last = boxes.last { return (last, last.textLength, boxes.count - 1) }
        return nil
    }
    private(set) var documentSize = 0
    var selFrom: Int { min(anchor, head) }
    var selTo: Int { max(anchor, head) }

    // UITextInput plumbing + undo.
    var textInputDelegate: UITextInputDelegate?
    // Created lazily in the `tokenizer` getter (Task 5) — declaring it with `= ...textInput: self`
    // here would require the UITextInput conformance to type-check before it exists.
    var inputTokenizer: UITextInputTokenizer?
    var editMenuInteraction: UIEditMenuInteraction?
    /// Whether the edit menu is currently presented (tracked via UIEditMenuInteractionDelegate), so a tap
    /// on the caret/selection can TOGGLE the menu instead of re-presenting it (the close-then-reopen flicker).
    var editMenuVisible = false
    /// Reference-time of the last edit-menu dismissal. The system auto-dismisses the menu on a tap-down,
    /// BEFORE our single-tap handler runs (on tap-up), so `editMenuVisible` is already false by then; this
    /// lets the handler tell "this tap just dismissed the menu" from "no menu was up".
    var lastMenuDismissTime: TimeInterval = 0
    /// Manual multi-tap counting (see `handleTap`). The single-tap recognizer is no longer gated on a
    /// double-tap recognizer FAILING — that `require(toFail:)` made every caret placement wait out the
    /// ~0.35s multi-tap window. One 1-tap recognizer now fires immediately and these track the rapid-tap
    /// run that escalates caret → word → paragraph.
    var lastTapTime: TimeInterval = 0
    var lastTapLocation: CGPoint = .zero
    var tapCount = 0
    /// Active magnifier loupe during a long-press caret drag (iOS 17+). Begun on `.began`, moved on
    /// `.changed`, invalidated + niled on `.ended`/`.cancelled`/`.failed`.
    var loupeSession: UITextLoupeSession?
    var draggingEndpoint: SelectionEndpoint?
    var draggingTableKnob: TableRangeEnd?
    var selectionHandlePan: UIPanGestureRecognizer?
    // Auto-scroll state while dragging a text-selection handle into a table's left/right edge zone.
    private(set) var dragAutoScrollLink: CADisplayLink?
    private(set) var dragAutoScrollTable: TableBlockBox?
    private(set) var dragAutoScrollVelocity: CGFloat = 0   // points/tick, signed
    private(set) var dragAutoScrollPoint: CGPoint = .zero   // last touch (canvas coords), for re-extending
    /// Transient table row/column structural selection (separate from the text selection). The `table` id
    /// guards against a stale selection after the active table is rebuilt. nil = none. Mutually exclusive
    /// with `imageSelection`.
    var tableSelection: (table: BlockID, kind: TableStructuralSelection)?
    /// Transient atom-selection of a top-level image (separate from the text selection). The BlockID
    /// guards a stale selection after a relayout/undo. nil = none. Mutually exclusive with `tableSelection`.
    var imageSelection: BlockID?
    /// Marked (composing/provisional) text as global positions over the same axis as `(anchor, head)`.
    /// nil = no active composition. The provisional characters live in the leaf region's storage like
    /// any committed text; this just tracks which range is provisional (for the underline + commit).
    var markedRange: (from: Int, to: Int)?
    /// True when the active marked text is a system INLINE PREDICTION (ghost text: `setMarkedText` with
    /// the caret at the start, `sel == {0,0}`) rather than CJK/IME composition. Predictions are
    /// keyboard-owned provisional text: a gesture/focus interruption must DISMISS the ghost (remove it),
    /// never COMMIT it — committing desyncs the keyboard's shadow doc and duplicates the word on accept.
    var markedTextIsPrediction = false
    /// The layout currently carrying the grey prediction-ghost rendering colour (display-only), so it
    /// can be cleared when the prediction moves or ends. Weak: the layout is owned by its box.
    weak var ghostStyledLayout: BlockLayout?
    /// Document + selection snapshot captured at composition START, registered as ONE undo at commit
    /// (so undo removes the whole composed word, not each keystroke).
    var compositionUndoSnapshot: [Block]?
    var compositionAnchorHead: (Int, Int)?
    /// Injectable pasteboard (defaults to the system pasteboard; tests inject a fake — see TextPasteboard).
    var pasteboard: TextPasteboard = UIPasteboard.general
    var undoManagerOverride: UndoManager?
    var effectiveUndoManager: UndoManager? { undoManagerOverride ?? undoManager }

    init(mapper: AttributedStringMapper = AttributedStringMapper()) {
        self.mapper = mapper
        super.init(frame: .zero)
        backgroundColor = .systemBackground
        blockChromeOverlay.canvas = self
        addSubview(blockquoteUnderlay)   // back-most: blockquote fills behind every block view
        emojiOverlay.isUserInteractionEnabled = false
        emojiOverlay.backgroundColor = .clear
        addSubview(emojiOverlay)
        spoilerOverlay.isUserInteractionEnabled = false
        spoilerOverlay.backgroundColor = .clear
        addSubview(spoilerOverlay)   // above emoji, below the selection wash
        selectionHighlight.canvas = self
        addSubview(selectionHighlight)   // selection wash, above text + emoji, below chrome
        addSubview(blockChromeOverlay)
        addSubview(caretView)   // own caret, above content; reparented into a table's content view when needed
        addSubview(startHandleView)   // own-drawn selection handles, hosted per-endpoint like the caret
        addSubview(endHandleView)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    override var canBecomeFirstResponder: Bool { true }

    @discardableResult
    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became { updateCaretView(); updateSelectionHandleViews() }   // show own-drawn caret/handles once focused
        return became
    }

    @discardableResult
    override func resignFirstResponder() -> Bool {
        finalizeMarkedText()
        let resigned = super.resignFirstResponder()
        if resigned { updateCaretView(); updateSelectionHandleViews() }   // hide caret + handles (no longer FR)
        return resigned
    }

    override var keyCommands: [UIKeyCommand]? {
        [UIKeyCommand(input: "\t", modifierFlags: [], action: #selector(handleTabKey)),
         UIKeyCommand(input: "\t", modifierFlags: .shift, action: #selector(handleShiftTabKey))]
    }
    @objc private func handleTabKey() { moveToCell(forward: true) }
    @objc private func handleShiftTabKey() { moveToCell(forward: false) }

    /// Builds a box per block (paragraph, image, or table). Tables become `TableBlockBox`es whose
    /// cells the canvas reaches via `leafRegions()`.
    func setBlocks(_ blocks: [Block], width: CGFloat) {
        if width > 0 { lastLayoutWidth = width }
        tableSelection = nil
        imageSelection = nil   // a full document swap drops any transient structural selection
        spoilerDustViews.values.forEach { $0.view.removeFromSuperview() }
        spoilerDustViews.removeAll()
        spoilerRuns = []
        spoilerRevealHint = nil
        // `width` here is the raw canvas width; the per-box TextKit layout is re-done at the content width
        // (bounds − 2·pageMargin) on the next `layoutSubviews` pass, so this init width is a transient hint.
        boxes = blocks.compactMap { block -> CanvasBlock? in
            switch block {
            case .paragraph(let p): return BlockBox(paragraph: p, mapper: mapper, width: width)
            case .image(let img): return ImageBlockBox(image: img, mapper: mapper, width: width)
            case .table(let t): return TableBlockBox(table: t, mapper: mapper, width: width)
            }
        }
        recomputeSpans()
        recomputeDocumentHasSpoilers()   // a fresh document may load spoilers, or none (gates syncSpoilers)
        anchor = min(anchor, documentSize); head = min(head, documentSize)
        invalidateIntrinsicContentSize(); setNeedsLayout(); setNeedsDisplay()
    }

    /// A full-document replacement that NOTIFIES the input system (so the keyboard's shadow document
    /// stays in sync — an unbracketed reload is a top cause of stale/misplaced predictions). Use this
    /// from the public `document` setter; `setBlocks` alone is for internal layout-only rebuilds.
    func reload(_ blocks: [Block], width: CGFloat) {
        finalizeMarkedText()
        textInputDelegate?.textWillChange(self)
        textInputDelegate?.selectionWillChange(self)
        setBlocks(blocks, width: width)
        textInputDelegate?.selectionDidChange(self)
        textInputDelegate?.textDidChange(self)
    }

    func currentBlocks() -> [Block] { boxes.map { $0.currentBlock() } }

    // MARK: - Viewport helpers

    /// The visible canvas rect: the host scroll view's window onto the content, or `bounds` when there
    /// is no scroll-view host (most unit tests / a non-scroll embed) — in which case the band covers the
    /// whole document and every box realizes (behavioral invariance).
    func viewportRect() -> CGRect {
        if let sv = superview as? UIScrollView { return CGRect(origin: sv.contentOffset, size: sv.bounds.size) }
        return bounds
    }

    /// The visible rect grown by the overscan band (one viewport height each side by default).
    func viewportBand() -> CGRect { overscanRect(for: viewportRect()) }

    /// The blockquote run fills that intersect `band` (off-screen runs are dropped so they allocate no
    /// underlay image view). The no-scroll-host fallback band covers the whole document ⇒ all runs kept.
    func visibleBlockquoteFills(band: CGRect) -> [CGRect] {
        blockquoteDecorations().map { $0.fill }.filter { $0.intersects(band) }
    }

    /// Reconciles the back-most blockquote underlay to only the on-screen quote runs.
    func syncBlockquoteUnderlay() {
        blockquoteUnderlay.sync(runFills: visibleBlockquoteFills(band: viewportBand()))
    }

    private func overscanRect(for visible: CGRect) -> CGRect {
        let overscan = blockViewOverscan >= 0 ? blockViewOverscan : visible.height
        return visible.insetBy(dx: 0, dy: -overscan)
    }

    /// Indices of the boxes whose drawn extent overlaps `band` — boundary-touching boxes ARE included
    /// (a conservative over-realization that avoids a blank strip at the exact viewport edge). Binary-
    /// searches the y-monotonic box frames (`BlockStack.layout` stacks them top-to-bottom, so `frame.minY`
    /// strictly increases), then widens outward while a neighbor's `blockViewFrame` (which may spill past
    /// `frame`, e.g. a full-bleed image) still intersects. Cost: O(log N + window).
    func blockWindow(forBand band: CGRect) -> [Int] {
        let n = boxes.count
        guard n > 0 else { return [] }
        // first index whose frame is NOT entirely above the band (frame.maxY >= band.minY)
        var lo = 0, hi = n
        while lo < hi { let m = (lo + hi) / 2; if boxes[m].frame.maxY < band.minY { lo = m + 1 } else { hi = m } }
        var first = lo
        // last index that STARTS at or before the band's bottom (frame.minY <= band.maxY)
        lo = 0; hi = n
        while lo < hi { let m = (lo + hi) / 2; if boxes[m].frame.minY <= band.maxY { lo = m + 1 } else { hi = m } }
        var last = lo - 1
        guard first <= last else { return [] }
        // Forward-looking guard: current types (image/table) don't spill vertically past their frame, but
        // a future non-text embed might — so widen on blockViewFrame, not frame.
        while first > 0 && boxes[first - 1].blockViewFrame.intersects(band) { first -= 1 }
        while last < n - 1 && boxes[last + 1].blockViewFrame.intersects(band) { last += 1 }
        return Array(first...last)
    }

    // MARK: - Block view pool

    /// Reconciles the block-view pool against the boxes currently in (or near) the viewport: realize the
    /// boxes whose drawn extent intersects the overscan band, recycle the rest. `blockViews` therefore
    /// holds only the *realized* views. Called from `layoutSubviews` (via `syncBlockViews()`) and the
    /// host's `scrollViewDidScroll` (via `viewportDidChange()`).
    /// Returns `true` when a fresh `TableBackingView` was created this call (used by `viewportDidChange`
    /// to decide whether to re-host cell emoji into the new content view).
    @discardableResult
    func reconcileBlockViews(visibleRect: CGRect) -> Bool {
        var createdFreshTable = false
        let window = blockWindow(forBand: overscanRect(for: visibleRect))
        var wantedIDs = Set<BlockID>()
        for i in window {
            let box = boxes[i]
            guard box.rendersAsBlockView else { continue }
            wantedIDs.insert(box.id)
            if let view = blockViews[box.id] {
                bindRealizedView(view, to: box, fresh: false)          // stayed realized
            } else {
                let view: BlockBackingView
                if box is TableBlockBox {
                    let t = TableBackingView(); t.canvas = self
                    t.pendingOffsetRestore = true                       // restore saved H-scroll on first layout
                    view = t
                    createdFreshTable = true
                } else {
                    view = dequeueRecycledView()                        // reuse (or create) a plain backing view
                }
                blockViews[box.id] = view
                insertSubview(view, aboveSubview: blockquoteUnderlay)    // above the back-most quote fills, below the overlays
                bindRealizedView(view, to: box, fresh: true)
            }
        }
        for (id, view) in blockViews where !wantedIDs.contains(id) {
            view.removeFromSuperview()
            blockViews[id] = nil
            if !(view is TableBackingView) {
                view.box = nil                                          // drop the strong ref to the old box
                view.lastRenderedSignature = nil
                if recycleQueue.count < recycleQueueCap { recycleQueue.append(view) }
            }
            // A TableBackingView is released; its `contentOffsetX` already lives on the box.
        }
        return createdFreshTable
    }

    /// `syncBlockViews()` keeps its old call sites (`layoutSubviews`) but is now viewport-aware.
    func syncBlockViews() { reconcileBlockViews(visibleRect: viewportRect()) }

    /// Called when only the VIEWPORT moved (the host scrolled) — frames are unchanged, so no relayout:
    /// re-realize block views + emoji against the moved viewport, re-cull the blockquote underlay, and
    /// re-home the caret/handles (a caret hosted in a table that was just realized must re-attach).
    func viewportDidChange() {
        let realizedFreshTable = reconcileBlockViews(visibleRect: viewportRect())
        syncBlockquoteUnderlay()
        // A freshly re-realized table has a brand-new (empty) content view; re-host emoji so its cell
        // emoji migrate back into it. Otherwise the cheap hide/show cull suffices (frames unchanged).
        if realizedFreshTable { syncEmojiViews() } else { cullEmojiViews() }
        refreshSelectionUI()
        scrollCaretIntoViewIfNeeded()
    }

    private func dequeueRecycledView() -> BlockBackingView {
        if let v = recycleQueue.popLast() { return v }
        let v = BlockBackingView(); v.canvas = self; return v
    }

    /// Binds (or re-binds) a realized view to its box: frame, table H-scroll sync, and the repaint gate.
    /// `fresh` = the view was just created/recycled (its bitmap is stale ⇒ force a repaint).
    private func bindRealizedView(_ view: BlockBackingView, to box: CanvasBlock, fresh: Bool) {
        view.box = box
        view.frame = box.blockViewFrame                                  // image: full drawn extent; table: visible window
        if let t = box as? TableBlockBox, let tv = view as? TableBackingView, !fresh {
            t.contentOffsetX = max(0, tv.scroll.contentOffset.x)         // a stays-realized table: sync view→box
        }
        view.setNeedsLayout()
        if let p = box as? BlockBox {
            let sig = p.renderSignature
            if fresh || view.lastRenderedSignature != sig {              // recycled OR content changed
                view.lastRenderedSignature = sig
                view.setNeedsDisplay()
            }
        } else {
            view.setNeedsDisplay()   // image/table: no renderSignature gate, so always repaint (they're few)
        }
    }

    var realizedBlockViewCountForTesting: Int { blockViews.count }
    func isBlockViewRealizedForTesting(_ id: BlockID) -> Bool { blockViews[id] != nil }
    var recycleQueueDepthForTesting: Int { recycleQueue.count }

    /// Called by a `TableBackingView` whenever its inner scroll view moves: keep the box's `contentOffsetX`
    /// in lock-step (canvas-space queries fold it in, Task 3) and repaint the offset-dependent chrome/caret.
    func tableDidScroll(_ view: TableBackingView) {
        guard let t = view.box as? TableBlockBox else { return }
        t.contentOffsetX = max(0, view.scroll.contentOffset.x)
        refreshSelectionUI()
        blockChromeOverlay.setNeedsDisplay()
    }

    func setParagraphs(_ paragraphs: [ParagraphBlock], width: CGFloat) {
        setBlocks(paragraphs.map { .paragraph($0) }, width: width)
    }

    func currentParagraphs() -> [ParagraphBlock] {
        boxes.compactMap { ($0 as? BlockBox)?.currentParagraph() }
    }

    /// Assigns each box its `nodeStart` (= prior tokens + 1) and accumulates `documentSize` from each
    /// box's `nodeSize` (paragraph: textLength+2; image: textLength+5). Matches `RichTextEditorCore`
    /// row-major token addressing.
    func recomputeSpans() {
        documentSize = root.recompute(baseOffset: 0)
        for case let t as TableBlockBox in boxes { t.recompute() }
    }

    /// The box whose text contains `pos` (inclusive of the trailing caret slot), or nil at a
    /// structural boundary between blocks.
    func box(containingGlobal pos: Int) -> (box: CanvasBlock, local: Int)? {
        for box in boxes where pos >= box.textStart && pos <= box.textStart + box.textLength {
            return (box, pos - box.textStart)
        }
        return nil
    }

    /// All editable leaf regions in document order (recurses into tables). v1: rebuilt per call; cache
    /// if profiling shows it matters.
    func allLeafRegions() -> [LeafTextRegion] { root.leafRegions() }

    /// The leaf region containing `pos` (inclusive of the trailing caret slot), with the local offset.
    func leafRegion(containingGlobal pos: Int) -> (region: LeafTextRegion, local: Int)? {
        for r in allLeafRegions() where pos >= r.globalStart && pos <= r.globalStart + r.length {
            return (r, pos - r.globalStart)
        }
        return nil
    }

    func boxIndex(of box: CanvasBlock) -> Int? { boxes.firstIndex { $0 === box } }

    /// Public-within-module accessor for the façade.
    var documentSizeValue: Int { documentSize }

    /// Re-flows boxes to a new width if it changed (called from the façade's layout).
    func setParagraphsWidthIfNeeded(_ width: CGFloat) {
        let content = max(width - CanvasMetrics.pageMargin * 2, 1)
        guard let first = boxes.first, abs(first.frame.width - content) > 0.5 || first.frame.width == 0 else { return }
        for box in boxes { box.setWidth(content) }
        recomputeSpans()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.width > 0 { lastLayoutWidth = bounds.width }
        _ = root.layout(origin: CGPoint(x: CanvasMetrics.pageMargin, y: 0),
                        width: max(bounds.width - CanvasMetrics.pageMargin * 2, 1))
        for case let t as TableBlockBox in boxes { t.recompute() }   // cell frames depend on the table frame
        stampListMarkers()
        syncBlockViews()
        blockquoteUnderlay.frame = bounds
        sendSubviewToBack(blockquoteUnderlay)
        syncBlockquoteUnderlay()
        emojiOverlay.frame = bounds
        syncEmojiViews()
        spoilerOverlay.frame = bounds
        syncSpoilers()
        selectionHighlight.frame = bounds
        bringSubviewToFront(selectionHighlight)   // above emoji
        blockChromeOverlay.frame = bounds
        bringSubviewToFront(blockChromeOverlay)    // chrome stays above the selection wash
        blockChromeOverlay.setNeedsDisplay()
        updateCaretView()              // frames/geometry may have changed (re-flow, table relayout); idempotent.
        updateSelectionHandleViews()   // reposition the own-drawn handles too
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow == nil { stopDragAutoScroll() }   // don't let a CADisplayLink retain a torn-down view
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: boxes.reduce(0) { $0 + $1.height })
    }

    /// The canvas is frame-managed by its host, so this is a no-op for layout on its own; forward the
    /// signal to the host (`onContentSizeChange`) so it re-flows the canvas frame + scroll content size.
    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        onContentSizeChange?()
    }

    /// Selection/caret changes call `setNeedsDisplay()` without a layout pass; propagate the repaint to
    /// the selection overlays and the chrome overlay — and to TABLE views only (their cell wash is
    /// selection-dependent). Paragraph/image views are NOT cascaded: their pixels don't depend on the
    /// selection, so they repaint only via the signature gate in `syncBlockViews`.
    override func setNeedsDisplay() {
        super.setNeedsDisplay()
        for v in blockViews.values where v is TableBackingView { v.setNeedsDisplay() }
        selectionHighlight.setNeedsDisplay()
        blockChromeOverlay.setNeedsDisplay()
    }

    // No `draw(_:)` override: the canvas paints nothing of its own, so it allocates no document-sized
    // backing store (the surface-size lever). Every visual is a bounded subview — block content via each
    // `BlockBackingView`, the blockquote fills via the back-most `blockquoteUnderlay`, the selection wash
    // via `selectionHighlight` / each table's `CellSelectionView`, table chrome via `blockChromeOverlay`,
    // and the caret/handles via their own-drawn views.

    /// Draws the selection highlight for all NON-TABLE regions (body + image captions) plus the image-atom
    /// washes, in canvas coordinates. Called by the `selectionHighlight` overlay so it renders ON TOP of
    /// the text and the emoji subviews. Table-cell regions are excluded (their highlight rides each table's
    /// own content-view overlay so it tracks horizontal overscroll).
    func drawNonTableSelectionHighlight(in ctx: CGContext) {
        UIColor.tintColor.withAlphaComponent(0.30).setFill()
        if selFrom != selTo {
            for r in selectionRects(globalFrom: selFrom, globalTo: selTo,
                                    regionFilter: { !self.isRegionInTable($0) }) {
                ctx.fill(r)
            }
        }
        // Image-atom wash for a selected (range-covered or tap-selected) image — moved here from the
        // image's BlockBackingView so it sits above any caption emoji and reads consistently.
        for case let img as ImageBlockBox in boxes {
            if let rect = imageSelectionTintRect(for: img) { ctx.fill(rect) }
        }
    }

    /// True if `region` belongs to a table (its global start falls in a `TableBlockBox`'s node span). Such
    /// regions' highlight is drawn by the table's content-view overlay, not the canvas overlay.
    func isRegionInTable(_ region: LeafTextRegion) -> Bool {
        boxes.contains { ($0 is TableBlockBox)
            && region.globalStart >= $0.nodeStart
            && region.globalStart < $0.nodeStart + $0.nodeSize }
    }

    /// Rect-union: clamp the global range to each leaf region, enumerate `.selection` segments,
    /// offset into canvas coordinates. The cross-block continuous highlight.
    /// - Parameter regionFilter: Optional predicate; only regions that pass are included (the canvas
    ///   selection overlay passes `{ !isRegionInTable($0) }` so table-cell regions are drawn by their
    ///   own content-view overlay). Defaults to `{ _ in true }` so existing callers are unaffected.
    func selectionRects(globalFrom: Int, globalTo: Int,
                        regionFilter: (LeafTextRegion) -> Bool = { _ in true }) -> [CGRect] {
        var rects: [CGRect] = []
        for r in allLeafRegions() where regionFilter(r) {
            let lo = max(globalFrom, r.globalStart), hi = min(globalTo, r.globalStart + r.length)
            guard lo < hi else { continue }
            let offX = tableContentOffsetX(forGlobal: r.globalStart)
            for seg in r.layout.selectionRects(start: lo - r.globalStart, end: hi - r.globalStart) {
                rects.append(seg.offsetBy(dx: r.canvasOrigin.x - offX, dy: r.canvasOrigin.y))
            }
        }
        return rects
    }

    /// Maps a point in canvas coordinates to the closest global text position.
    func closestGlobalPosition(to point: CGPoint) -> Int { root.closestPosition(toCanvasPoint: point) }

    /// The `TableBlockBox` whose node span (incl. structural token slots) contains `pos`, if any — used to
    /// fold in horizontal scroll. Wider than `tableBox(containing:)` in Navigation (which matches cell text only).
    func tableBox(containingGlobal pos: Int) -> TableBlockBox? {
        boxes.first { ($0 as? TableBlockBox).map { pos >= $0.nodeStart && pos < $0.nodeStart + $0.nodeSize } ?? false } as? TableBlockBox
    }

    /// The horizontal scroll offset of the table containing `pos` (0 if none) — subtract it to turn an
    /// unscrolled-canvas rect into a VISIBLE canvas rect.
    func tableContentOffsetX(forGlobal pos: Int) -> CGFloat { tableBox(containingGlobal: pos)?.contentOffsetX ?? 0 }

    /// True if `pos` is the gap before an image atom (an image box's `nodeStart`).
    func isGapPosition(_ pos: Int) -> Bool {
        boxes.contains { $0 is ImageBlockBox && $0.nodeStart == pos }
    }

    /// The image box whose gap-before-atom is at `pos`, if any.
    func imageBox(atGap pos: Int) -> ImageBlockBox? {
        boxes.first { ($0 as? ImageBlockBox)?.nodeStart == pos } as? ImageBlockBox
    }

    /// If the caret (`head`) is inside a horizontally-scrollable table, scroll its cell into view.
    /// Non-animated (fires during typing/nav); the scroll callback syncs `contentOffsetX` + repaints.
    func scrollCaretIntoViewIfNeeded() {
        // Note: an image-gap caret inside a cell isn't found by cellLocation (no UI path inserts one today),
        // so this simply no-ops for that case.
        guard let t = tableBox(containingGlobal: head),
              let tv = blockViews[t.id] as? TableBackingView,
              let loc = t.cellLocation(containing: head),
              let cellRect = t.cellRect(row: loc.row, column: loc.column) else { return }
        guard t.gridWidth > tv.bounds.width else { return }   // not scrollable → cheap early exit, no layout flush
        tv.layoutIfNeeded()                                   // ensure scroll.frame/contentSize are current
        let x = cellRect.minX - t.frame.minX                  // cell x in the scroll view's content space
        let target = CGRect(x: x, y: 0, width: cellRect.width, height: 1)
        tv.scroll.scrollRectToVisible(target, animated: false)
    }

    /// While dragging a selection, if `point` is in a scrollable table's left/right edge zone (and the
    /// dragged head is in that table), start nudging the table's scroll + re-extending the head each tick.
    func updateDragAutoScroll(point: CGPoint, headInTable: Bool) {
        guard headInTable, let t = tableBox(containingGlobal: head),
              let tv = blockViews[t.id] as? TableBackingView, t.gridWidth > tv.bounds.width else {
            stopDragAutoScroll(); return
        }
        dragAutoScrollPoint = point
        let edge: CGFloat = 36, step: CGFloat = 12
        let left = t.frame.minX, right = t.frame.minX + tv.bounds.width
        var v: CGFloat = 0
        if point.x < left + edge { v = -step } else if point.x > right - edge { v = step }
        if v == 0 { stopDragAutoScroll(); return }
        dragAutoScrollTable = t
        dragAutoScrollVelocity = v
        if dragAutoScrollLink == nil {
            let link = CADisplayLink(target: self, selector: #selector(dragAutoScrollTick))
            link.add(to: .main, forMode: .common)
            dragAutoScrollLink = link
        }
    }

    func stopDragAutoScroll() {
        dragAutoScrollLink?.invalidate(); dragAutoScrollLink = nil
        dragAutoScrollTable = nil; dragAutoScrollVelocity = 0
        dragAutoScrollPoint = .zero
    }

    @objc func dragAutoScrollTick() {
        guard let t = dragAutoScrollTable, let tv = blockViews[t.id] as? TableBackingView else { stopDragAutoScroll(); return }
        let maxX = max(tv.scroll.contentSize.width - tv.bounds.width, 0)
        let newX = min(max(tv.scroll.contentOffset.x + dragAutoScrollVelocity, 0), maxX)
        guard newX != tv.scroll.contentOffset.x else { return }   // already at the edge
        tv.scroll.contentOffset.x = newX            // triggers tableDidScroll → syncs contentOffsetX
        // The tick owns the scroll position; suppress scrollCaretIntoViewIfNeeded so it doesn't fight `newX`.
        setSelectionHead(global: closestGlobalPosition(to: dragAutoScrollPoint), scrollIntoView: false)
    }

    /// Sets a collapsed caret (clears the drag anchor).
    func setCaret(global pos: Int) {
        var target = pos
        if let g = finalizeMarkedText() {            // a dismissed prediction shifts later positions left
            if pos >= g.to { target = pos - (g.to - g.from) }
            else if pos > g.from { target = g.from }
        }
        target = clampGlobal(target)
        clearStructuralSelections()
        textInputDelegate?.selectionWillChange(self)
        anchor = target; head = target
        textInputDelegate?.selectionDidChange(self)
        setNeedsDisplay(); refreshSelectionUI()
        scrollCaretIntoViewIfNeeded()
        onSelectionChange?()   // tap is harmless (caret already visible → no-op); covers non-tap movers —
                               // Backspace-at-cell-start / Tab cell-nav — that can land the caret off-screen
    }

    /// Moves the selection head, keeping the anchor (drag-to-select).
    func setSelectionHead(global pos: Int, scrollIntoView: Bool = true) {
        finalizeMarkedText()
        clearStructuralSelections()
        textInputDelegate?.selectionWillChange(self)
        head = pos
        textInputDelegate?.selectionDidChange(self)
        setNeedsDisplay(); refreshSelectionUI()
        if scrollIntoView { scrollCaretIntoViewIfNeeded() }
    }

    /// Moves the selection anchor (keeps the head), bracketing the input-delegate change like setSelectionHead.
    func setSelectionAnchor(global pos: Int) {
        finalizeMarkedText()
        clearStructuralSelections()
        textInputDelegate?.selectionWillChange(self)
        anchor = pos
        textInputDelegate?.selectionDidChange(self)
        setNeedsDisplay(); refreshSelectionUI()
    }

    func refreshSelectionUI() {
        // The canvas owns every selection visual (caret, wash, handles); there is no
        // `UITextSelectionDisplayInteraction` to notify (see `installSelectionInteractions`).
        updateCaretView()
        updateSelectionHandleViews()
        syncSpoilers()
    }

    /// Positions the two own-drawn selection-handle views at the ranged selection's endpoints — each hosted
    /// in the table's scrolling content view for a cell endpoint, else the canvas — ON TOP of the wash and
    /// riding the right scroll. Hidden for a collapsed / structural / non-renderable selection. Mirrors
    /// `updateCaretView`; idempotent, so it's safe from `refreshSelectionUI` and `layoutSubviews`.
    func updateSelectionHandleViews() {
        guard isFirstResponder, selFrom != selTo, tableSelection == nil, imageSelection == nil else {
            hideHandle(startHandleView); hideHandle(endHandleView); return
        }
        positionHandle(startHandleView, atGlobal: selFrom)
        positionHandle(endHandleView, atGlobal: selTo)
    }

    private func positionHandle(_ handle: SelectionHandleView, atGlobal pos: Int) {
        guard let region = leafRegion(containingGlobal: pos) else { return hideHandle(handle) }
        let unscrolled = region.region.caretRect(atLocal: region.local)
            .offsetBy(dx: region.region.canvasOrigin.x + region.region.emptyLineLeadingIndent,
                      dy: region.region.canvasOrigin.y)
        if let table = tableBox(containingGlobal: pos),
           let tv = blockViews[table.id] as? TableBackingView,
           region.region.globalStart >= table.nodeStart,
           region.region.globalStart < table.nodeStart + table.nodeSize {
            // Cell endpoint → host in the table's content view (content-local = unscrolled − frame.origin),
            // so it rides the horizontal scroll like the caret.
            let contentCaret = unscrolled.offsetBy(dx: -table.frame.minX, dy: -table.frame.minY)
            tv.hostHandle(handle, at: handle.boundingFrame(forCaret: contentCaret))
        } else {
            if handle.superview !== self { addSubview(handle) }
            bringSubviewToFront(handle)   // above the wash (and chrome — they're never co-visible with a text range)
            handle.frame = handle.boundingFrame(forCaret: unscrolled)
        }
        handle.isHidden = false
    }

    private func hideHandle(_ handle: SelectionHandleView) {
        handle.isHidden = true
        if handle.superview !== self { addSubview(handle) }   // never leave it parked in a torn-down table
    }

    /// Positions (and shows/hides) the app's own blinking caret. Idempotent and cheap: re-running it for the
    /// same caret (a scroll tick / relayout) does NOT restart the blink (only a real container/frame change
    /// does), so it's safe to call from `refreshSelectionUI` (every selection change) and `layoutSubviews`.
    ///
    /// The caret shows iff we're first responder, the selection is COLLAPSED (`selFrom == selTo`), there's
    /// no structural table selection, and `head` is renderable. When the caret is inside a horizontally-
    /// scrollable table CELL it's hosted in that table's scrolling content view (so it rides the scroll);
    /// otherwise (paragraph / image-gap) it's a subview of the canvas.
    func updateCaretView() {
        // Should it show?
        guard isFirstResponder, selFrom == selTo, tableSelection == nil, imageSelection == nil else { return hideCaretView() }

        var container: UIView = self
        var frame: CGRect

        let leaf = leafRegion(containingGlobal: head)
        if let region = leaf,
           let table = tableBox(containingGlobal: head),
           let tv = blockViews[table.id] as? TableBackingView,
           region.region.globalStart >= table.nodeStart,
           region.region.globalStart < table.nodeStart + table.nodeSize {
            // Caret inside a table cell → host it in the table's scrolling content view (content-local =
            // unscrolled-canvas − table.frame.origin; the content view draws via a -blockViewFrame.origin
            // translate, and a table's blockViewFrame.origin == frame.origin).
            let unscrolled = region.region.caretRect(atLocal: region.local)
                .offsetBy(dx: region.region.canvasOrigin.x + region.region.emptyLineLeadingIndent,
                          dy: region.region.canvasOrigin.y)
            frame = caretBar(from: unscrolled)
                .offsetBy(dx: -table.frame.minX, dy: -table.frame.minY)
            tv.hostCaret(caretView, at: frame)
            container = tv
        } else if let region = leaf {
            // A non-table leaf region (paragraph / image caption): unscrolled == canvas coords.
            frame = caretBar(from: region.region.caretRect(atLocal: region.local)
                .offsetBy(dx: region.region.canvasOrigin.x + region.region.emptyLineLeadingIndent,
                          dy: region.region.canvasOrigin.y))
            hostCaretOnCanvas(at: frame)
        } else if let img = imageBox(atGap: head) {
            // An image gap: a vertical bar at the image's leading edge (full height).
            let rr = img.imageRect()
            frame = CGRect(x: rr.minX, y: rr.minY, width: 2, height: rr.height)
            hostCaretOnCanvas(at: frame)
        } else {
            return hideCaretView()   // not renderable → no caret
        }

        caretView.isHidden = false
        // Reset the blink ONLY when the caret actually moved (container or frame changed). A no-op refresh
        // (scroll tick / relayout at the same spot) keeps the existing blink running.
        let changed = container !== lastCaretContainer || !frame.equalTo(lastCaretFrame)
        if changed { caretView.resetBlink() } else { caretView.startBlink() }
        lastCaretContainer = container
        lastCaretFrame = frame
    }

    /// A 2pt-wide caret bar from a TextKit caret rect (keeps the OS-caret look used by `caretRect`).
    private func caretBar(from rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: rect.minY, width: 2, height: rect.height)
    }

    private func hostCaretOnCanvas(at frame: CGRect) {
        if caretView.superview !== self { addSubview(caretView) }
        bringSubviewToFront(caretView)
        caretView.frame = frame
    }

    private func hideCaretView() {
        caretView.stopBlink()
        if caretView.superview !== self { addSubview(caretView) }   // never leave it parked in a table's content view
        lastCaretContainer = nil
        lastCaretFrame = .null
    }

    /// Demo helper: set a selection spanning the middle of two blocks by index.
    func selectAcrossBlocks(firstIndex: Int, secondIndex: Int) {
        guard boxes.indices.contains(firstIndex), boxes.indices.contains(secondIndex) else { return }
        anchor = boxes[firstIndex].textStart + boxes[firstIndex].textLength / 2
        head = boxes[secondIndex].textStart + boxes[secondIndex].textLength / 2
        becomeFirstResponder()
        setNeedsDisplay(); refreshSelectionUI()
    }

    /// Demo helper: set a selection spanning mid-way through two leaf regions by document-order index.
    func selectAcrossLeafRegions(firstLeaf: Int, secondLeaf: Int) {
        let regions = allLeafRegions()
        guard regions.indices.contains(firstLeaf), regions.indices.contains(secondLeaf) else { return }
        let r1 = regions[firstLeaf], r2 = regions[secondLeaf]
        anchor = r1.globalStart + max(1, r1.length / 2)
        head   = r2.globalStart + max(1, r2.length / 2)
        becomeFirstResponder()
        setNeedsDisplay(); refreshSelectionUI()
    }
}

/// One pooled emoji: the host view plus its last canvas-space frame (for offscreen culling).
final class HostedEmoji {
    let view: UIView
    var canvasFrame: CGRect
    init(view: UIView, canvasFrame: CGRect) { self.view = view; self.canvasFrame = canvasFrame }
}
#endif
