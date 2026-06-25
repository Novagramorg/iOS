#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// Public façade. Renders all block types (paragraphs, images, tables) in a vertical canvas
/// with continuous cross-block selection.
@available(iOS 13.0, *)
public final class RichTextEditorView: UIView, UIScrollViewDelegate {
    private let scrollView = UIScrollView()
    let canvas = DocumentCanvasView()

    /// Floor for the content height returned by `update(...)`/`performLayout`. Defaults to 44pt (a document
    /// editor wants a tappable minimum body). A compact host (e.g. the chat composer) sets it to 0 so the
    /// measured height hugs the actual text and the host owns the minimum field height.
    public var minimumContentHeight: CGFloat = 44

    /// Host-settable colors. Defaults to `.default` (today's look). Assigning re-applies colors to the live
    /// editor: the mapper (text/link), the caret/selection/blockquote accent, and a reload so boxes rebuild
    /// with the themed mapper. A reload resets the live selection — theme changes are host-driven (e.g. an
    /// app appearance switch), so this is acceptable.
    public var theme: RichTextEditorTheme = .default {
        didSet {
            canvas.applyTheme(theme)
            if bounds.width > 0.0 {
                canvas.reload(self.document.blocks, width: bounds.width)
            }
            canvas.setNeedsDisplay()
        }
    }

    /// Fires (no payload) whenever anything changes — a content edit, a content-size change, or a
    /// selection/caret move. The host responds by re-running its own layout (which calls
    /// `update(size:insets:)`). May fire more than once per logical change; treat it as idempotent.
    public var onChange: (() -> Void)?

    /// Fires once when the editor gains first-responder focus (the editing surface becomes first
    /// responder) — not on a repeat tap while already focused. A host can react by showing chrome.
    public var onBecameFirstResponder: (() -> Void)?

    /// Fires once when the editor loses first-responder focus (resigns first responder). A host can
    /// react by dismissing a panel / chrome.
    public var onResignedFirstResponder: (() -> Void)?

    /// Pasting media (image/gif/video/sticker) is a host concern — the editor never embeds it. Set these to
    /// route a media paste to the host (e.g. the chat send flow): `canPasteMedia` gates whether Paste is
    /// offered; `onPasteMedia` performs it (returns whether it consumed the paste). Text paste is handled by
    /// the editor regardless of these.
    public var canPasteMedia: (() -> Bool)? { didSet { canvas.canPasteMedia = canPasteMedia } }
    public var onPasteMedia: (() -> Bool)? { didSet { canvas.onPasteMedia = onPasteMedia } }

    /// Transform the editor's default edit-menu elements into the final set. `defaultElements` is the system
    /// suggested actions (Cut/Copy/Paste/Select + Writing Tools) followed by the editor's own custom items
    /// (the built-in "Format" submenu + Look Up / Translate / Share). Return the elements to present.
    /// Consulted ONLY for a non-collapsed selection, ONLY on iOS 16+ (`UIEditMenuInteraction`); on iOS 13–15
    /// the editor's built-in items are shown unchanged. nil ⇒ default menu.
    public var contextMenuItemsProvider: ((_ defaultElements: [UIMenuElement]) -> [UIMenuElement])? {
        get { canvas.hostContextMenuItemsProvider }
        set { canvas.hostContextMenuItemsProvider = newValue }
    }

    /// A read-only snapshot of the editor at the current selection — drives a host toolbar's per-action
    /// availability + selected state. Pure: never mutates or fires `onChange`.
    public struct EditorState: Equatable {
        public let bold: Bool
        public let italic: Bool
        public let underline: Bool
        public let strikethrough: Bool
        public let code: Bool
        public let paragraphStyle: ParagraphStyleName?
        public let listMarker: ListMarker?
        public let link: String?
        public let hasSelection: Bool
        public let isInTable: Bool
        public let canUndo: Bool
        public let canRedo: Bool
    }

    public func currentState() -> EditorState { canvas.currentState() }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(scrollView)
        scrollView.clipsToBounds = false
        // Don't hold touches during pan-arbitration (~150ms) before delivering them to the canvas's tap
        // recognizer — that delay compounded the tap-to-caret latency. The handle-pan↔scroll arbitration
        // is gate-only (DocumentCanvasView.gestureRecognizerShouldBegin), so this is safe.
        scrollView.delaysContentTouches = false
        // The parent owns insets exactly (via update(size:insets:)). The editor frame can reach into the
        // bottom safe area, so the default .automatic adjustment would ADD the home-indicator inset on top
        // of the parent's contentInset.bottom (double-counting it at rest). .never keeps the inset contract exact.
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.delegate = self
        scrollView.addSubview(canvas)
        canvas.installSelectionInteractions()
        // The canvas is sized frame-based in layoutSubviews, so a content-height change (typing wraps a
        // line, a cell grows, undo, …) must re-trigger our layout — otherwise it only updates on the next
        // layout pass (e.g. a rotation).
        canvas.onContentSizeChange = { [weak self] in self?.onChange?() }   // pure relay; the host re-lays-out via update()
        // The OS moves the caret via arrows through the canvas's selectedTextRange setter, which can land
        // it off-screen (e.g. arrowing up out of a tall image to the block above). Scroll it back into view.
        canvas.onSelectionChange = { [weak self] in self?.scrollCaretIntoView(); self?.onChange?() }
        // Surface first-responder transitions (the canvas is the actual first responder) to the host.
        canvas.onBecameFirstResponder = { [weak self] in self?.onBecameFirstResponder?() }
        canvas.onResignedFirstResponder = { [weak self] in self?.onResignedFirstResponder?() }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    public var document: Document {
        get { Document(blocks: canvas.currentBlocks()) }
        set {
            var blocks = newValue.blocks
            if blocks.isEmpty { blocks = [.paragraph(ParagraphBlock(id: BlockID.generate()))] }
            canvas.reload(blocks, width: bounds.width)
            performLayout(size: bounds.size)   // explicit parent-driven layout for the content swap (no self-schedule)
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        performLayout(size: bounds.size)
    }

    /// Parent-driven layout. Lays the document out at `size.width`, applies `insets` to the internal scroll
    /// view (bottom = the keyboard/input-panel overlap the parent owns), and returns the measured content
    /// height (a 44pt minimum, matching the laid-out canvas) so a content-hugging host can size to it; a
    /// fixed-region host ignores it. The view does NOT set its own frame — the parent does that, then calls
    /// this (and may use the return to pick the frame).
    ///
    /// `contentMargins` is interior padding that is PART of the content (distinct from `insets`): the text
    /// lays out inset by it (wrapping narrower, offset from the edges), the content height grows by
    /// top+bottom, and the margin area still hit-tests to the nearest position. Insets are non-interactable
    /// bands the content scrolls UNDER (nav bar / keyboard / input panel). Both are layout-affecting inputs,
    /// so — like `insets` — margins are applied HERE rather than via a side-effecting property setter (which
    /// would hide a re-layout and could re-enter `onChange`); pass them every `update`, and they persist
    /// across intervening system layout passes until the next `update`.
    @discardableResult
    public func update(size: CGSize, insets: UIEdgeInsets, contentMargins: UIEdgeInsets = .zero) -> CGFloat {
        scrollView.contentInset = insets
        scrollView.verticalScrollIndicatorInsets = insets
        canvas.contentMargins = contentMargins
        return performLayout(size: size)
    }

    /// Sizes the scroll view + canvas to `size` and returns the measured CONTENT height (min 44). The
    /// canvas is laid out at least as tall as the VISIBLE viewport (`size.height` minus the top/bottom
    /// content insets) even when the content is shorter, so its tap/long-press/loupe recognizers receive
    /// touches anywhere in the unobscured editor area — a tap in the empty space below the text maps to the
    /// nearest position (document end), matching UITextView. Flooring at the visible height (not the full
    /// frame) keeps the scroll content == visible area for a short doc, so the scrollable range is zero (no
    /// phantom scroll/bounce over the inset bands); the insets are read here so a later `update` with new
    /// insets re-flows the content size. Insets themselves are NOT written here, so a system layout pass
    /// (rotation, etc.) never clobbers the parent-applied inset; only `update(size:insets:)` changes them.
    @discardableResult
    private func performLayout(size: CGSize) -> CGFloat {
        scrollView.frame = CGRect(origin: .zero, size: size)
        canvas.setParagraphsWidthIfNeeded(size.width)
        let contentHeight = max(canvas.intrinsicContentSize.height, self.minimumContentHeight)
        let insets = scrollView.contentInset
        let visibleHeight = max(size.height - insets.top - insets.bottom, 0)   // unobscured viewport
        let canvasHeight = max(contentHeight, visibleHeight)   // fill the visible area so empty-area taps still hit the canvas
        canvas.frame = CGRect(x: 0, y: 0, width: size.width, height: canvasHeight)
        canvas.layoutContent()   // drive the canvas layout explicitly (not via the needsLayout flag), so a
                                 // setting applied just above (margins, width) takes effect even when the
                                 // canvas frame didn't change (e.g. a short doc whose height is floored).
        scrollView.contentSize = CGSize(width: size.width, height: canvasHeight)
        return contentHeight
    }

    /// Measures the content height the document would have at `width`, WITHOUT mutating the live layout
    /// — no reflow of the displayed boxes, no frame/scroll/overlay/caret change, no `onChange`. Applies
    /// the same `minimumContentHeight` floor and `contentMargins` as `update(...)`, so the measured value
    /// equals what a subsequent `update` at this width returns (measure == commit). Pure read.
    public func height(forWidth width: CGFloat) -> CGFloat {
        max(canvas.measuredContentHeight(forWidth: width), minimumContentHeight)
    }

    /// Test accessor: the current bottom content inset.
    var bottomContentInsetForTesting: CGFloat { scrollView.contentInset.bottom }
    /// Test accessor: the scroll view's content height (the scrollable extent).
    var scrollContentHeightForTesting: CGFloat { scrollView.contentSize.height }
    /// Test accessor: the scroll view's content offset (read to assert caret-follow scrolling; set to
    /// simulate the caret being scrolled off-screen).
    var contentOffsetForTesting: CGPoint {
        get { scrollView.contentOffset }
        set { scrollView.contentOffset = newValue }
    }
    /// Test accessor: the underlying canvas (to set up selection in unit tests).
    var canvasForTesting: DocumentCanvasView { canvas }

    public func toggleBold() { canvas.toggleBold() }
    public func toggleItalic() { canvas.toggleItalic() }
    public func toggleStrikethrough() { canvas.toggleStrikethrough() }
    public func toggleUnderline() { canvas.toggleUnderline() }
    public func toggleInlineCode() { canvas.toggleInlineCode() }
    public func toggleSpoiler() { canvas.toggleSpoiler() }
    public func setParagraphStyle(_ name: ParagraphStyleName) { canvas.setParagraphStyle(name) }
    public func setAlignment(_ alignment: TextAlignment) { canvas.setAlignment(alignment) }
    public func setList(_ marker: ListMarker?) { canvas.setList(marker) }

    public func undo() { canvas.finalizeMarkedText(); canvas.effectiveUndoManager?.undo() }
    public func redo() { canvas.finalizeMarkedText(); canvas.effectiveUndoManager?.redo() }

    // MARK: Table structural commands (operate on the caret's table; no-op otherwise)
    public func insertTableRowAbove() { canvas.insertTableRowAbove() }
    public func insertTableRowBelow() { canvas.insertTableRowBelow() }
    public func deleteTableRow() { canvas.deleteTableRow() }
    public func insertTableColumnLeft() { canvas.insertTableColumnLeft() }
    public func insertTableColumnRight() { canvas.insertTableColumnRight() }
    public func deleteTableColumn() { canvas.deleteTableColumn() }
    /// Deletes the table the caret is in (no-op otherwise).
    public func deleteTable() { canvas.deleteTable() }
    public func setTableColumnAlignment(_ alignment: TextAlignment) { canvas.setTableColumnAlignment(alignment) }

    /// Inserts an empty `rows`×`cols` table (row 0 a header) at the caret. No-op unless the caret is in
    /// a top-level paragraph.
    public func insertTable(rows: Int, cols: Int) { canvas.insertTable(rows: rows, columns: cols) }

    /// Sets `url` as a link over the current selection (no-op if the selection is empty).
    public func setLink(_ url: String) { canvas.setLink(url) }
    /// Removes any link over the current selection.
    public func removeLink() { canvas.removeLink() }
    /// The link the entire selection carries (for prefilling a link editor), or nil.
    public func currentLink() -> String? { canvas.currentLink() }

    /// The plain text of the current selection (empty string when the selection is collapsed). Used by a
    /// host link editor to label the prompt and decide add-vs-edit.
    public func selectedText() -> String {
        guard let range = canvas.selectedTextRange else { return "" }
        return canvas.text(in: range) ?? ""
    }

    /// Increases the list nesting level of the touched list items (no-op on non-list paragraphs).
    public func indent() { canvas.indent() }
    /// Decreases the list nesting level of the touched list items (clamps at 0; no-op on non-list).
    public func outdent() { canvas.outdent() }

    /// Inserts an inline custom emoji `id` (host-resolved to a view via `registerEmojiViewProvider`) at
    /// the caret. `altText` is its plain-text / Markdown form (optional).
    public func insertEmoji(id: String, altText: String? = nil) { canvas.insertEmoji(id: id, altText: altText) }

    /// Inserts plain `text` at the caret (replacing any selection) in one undo step. Used for unicode
    /// emoji and any programmatic plain-text insertion.
    public func insertText(_ text: String) { canvas.insertText(text) }

    /// Deletes one unit before the caret (drives a custom keyboard's backspace key).
    public func deleteBackward() { canvas.deleteBackward() }

    /// A custom input view that replaces the system keyboard while the editor is first responder.
    /// Set an `EmptyInputView` to hide the keyboard while showing a separate input panel (the caret
    /// stays visible because the canvas remains first responder); `nil` restores the system keyboard.
    public var customInputView: UIView? {
        get { canvas.customInputView }
        set {
            canvas.customInputView = newValue
            if canvas.isFirstResponder {
                canvas.reloadInputViews()
            }
        }
    }

    /// Registers the closure that turns an emoji `id` (+ requested square size) into a FRESH, non-
    /// interactive view. The editor owns/positions/removes it and makes it ride scrolling.
    public func registerEmojiViewProvider(_ provider: @escaping (_ id: String, _ size: CGSize) -> UIView?) {
        canvas.emojiViewProvider = provider
    }

    /// Hide an emoji view when its frame is more than this far outside the viewport (default 50pt).
    public var emojiCullMargin: CGFloat {
        get { canvas.emojiCullMargin }
        set { canvas.emojiCullMargin = newValue }
    }

    /// Overscan band (points) of block views realized above/below the viewport. Negative ⇒ auto (one
    /// viewport height each side, the default). Larger = fewer pop-in flashes on fast flings, more memory.
    public var blockViewOverscan: CGFloat {
        get { canvas.blockViewOverscan }
        set { canvas.blockViewOverscan = newValue }
    }

    /// Inserts a media block (`kind`) at the caret. The host resolves `mediaID` to a view via
    /// `registerMediaViewProvider`. `naturalSize` drives the block's aspect-correct display height.
    public func insertMedia(mediaID: String, naturalSize: CGSize, kind: MediaKind) {
        canvas.insertMedia(mediaID: mediaID, naturalSize: naturalSize, kind: kind)
    }

    /// Registers the closure that turns a media `mediaID` (+ the medium's natural size) into a FRESH
    /// `RichTextMediaItemView`. Called once per occurrence; the editor owns/positions/resizes/culls it.
    public func registerMediaViewProvider(
        _ provider: @escaping (_ mediaID: String, _ naturalSize: CGSize) -> RichTextMediaItemView?
    ) {
        canvas.mediaViewProvider = provider
    }

    /// Hide a media view when its canvas frame is more than this far outside the viewport (default 50pt).
    public var mediaCullMargin: CGFloat {
        get { canvas.mediaCullMargin }
        set { canvas.mediaCullMargin = newValue }
    }

    /// Test seam: the hosted media view for the first media block in `document`, if realized.
    func hostedMediaViewForTesting(forFirstMediaBlock document: Document) -> RichTextMediaItemView? {
        for block in document.blocks { if case let .media(m) = block { return canvas.hostedMediaViewForTesting(m.id) } }
        return nil
    }

    /// Test seam: the number of realized hosted media views.
    var hostedMediaCountForTesting: Int { canvas.hostedMediaCountForTesting }

    /// Demo helper: select from mid-way through the 2nd block to mid-way through the 3rd.
    public func selectRangeAcrossFirstTwoBodyParagraphs() {
        canvas.selectAcrossBlocks(firstIndex: 1, secondIndex: 2)
    }

    /// Demo helper: set a cross-cell selection spanning from mid-way through leaf region at
    /// `firstLeaf` to mid-way through the region at `secondLeaf` (document order). Use this to
    /// demonstrate Phase 4 continuous cross-cell selection.
    public func selectAcrossLeafRegions(firstLeaf: Int, secondLeaf: Int) {
        canvas.selectAcrossLeafRegions(firstLeaf: firstLeaf, secondLeaf: secondLeaf)
    }

    /// Demo helper: select the first table's first column (showcases the table handles + selection outline).
    public func selectFirstTableColumn() { canvas.selectFirstTableColumn() }

    /// Demo helper: tap the first hidden spoiler (drives the reveal — text shows + dust dissolves).
    public func revealFirstSpoiler() { canvas.tapFirstSpoilerForTesting() }

    public func selectAll() {
        canvas.selectedTextRange = DocumentTextRange(DocumentTextPosition(0),
                                                     DocumentTextPosition(canvas.documentSizeValue))
    }

    @discardableResult
    public override func becomeFirstResponder() -> Bool { canvas.becomeFirstResponder() }

    /// Scrolls the outer scroll view so the caret is visible (above the bottom inset; respects contentInset).
    /// Arrow-key nav drives this via `onSelectionChange` with `animated: false`: a synchronous scroll
    /// settles before the setter returns, so a rapid second arrow queries a stable layout. An ANIMATED
    /// scroll mutates `contentOffset` mid-flight, and a second arrow then computes its destination against
    /// that in-flux state → non-deterministic arrow results (the reported "random" behaviour). Only scrolls
    /// when the caret is actually outside the visible band, so in-screen nav/typing never churns the scroll.
    private func scrollCaretIntoView(animated: Bool = false) {
        guard canvas.isFirstResponder else { return }
        // Lay the canvas out explicitly so `caretRect` + the scrollable extent reflect the latest edit
        // before we measure/scroll — the editor convention is parent-driven layout, so we don't rely on a
        // pending self-scheduled pass. Idempotent for arrow nav (content unchanged → same layout).
        performLayout(size: bounds.size)
        var caret = canvas.caretRect(for: DocumentTextPosition(canvas.head))
        guard caret != .zero, !caret.isNull else { return }
        // An image-gap caret is full-image-height; its whole rect would never fit the visible band (→ always
        // scroll) and would jump/oscillate. Track a short band at its top edge instead.
        if caret.height > 64 { caret = CGRect(x: caret.minX, y: caret.minY, width: caret.width, height: 24) }
        let target = caret.insetBy(dx: 0, dy: -12)
        let visible = scrollView.bounds.inset(by: scrollView.adjustedContentInset)
        guard !visible.contains(target) else { return }   // already visible → no scroll (kills churn + race)
        scrollView.scrollRectToVisible(target, animated: animated)
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        canvas.viewportDidChange()   // realize/recycle block views + emoji + blockquote underlay for the new viewport
    }

    // MARK: - Composer-host scroll accessors (internal — consumed by RichTextEditorView+ComposerHost.swift)

    var scrollViewContentOffset: CGPoint { self.scrollView.contentOffset }
    func setScrollViewIndicatorInsets(_ insets: UIEdgeInsets) { self.scrollView.verticalScrollIndicatorInsets = insets }
}
#endif
