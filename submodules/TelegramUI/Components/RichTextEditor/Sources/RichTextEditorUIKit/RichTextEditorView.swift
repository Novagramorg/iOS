#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// Public façade. Renders all block types (paragraphs, images, tables) in a vertical canvas
/// with continuous cross-block selection.
@available(iOS 17.0, *)
public final class RichTextEditorView: UIView, UIScrollViewDelegate {
    private let scrollView = UIScrollView()
    let canvas = DocumentCanvasView()
    private var metadata = DocumentMetadata(title: "", createdAt: Date(timeIntervalSince1970: 0),
                                            modifiedAt: Date(timeIntervalSince1970: 0))
    private var assets: [String: UIImage] = [:]

    public override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(scrollView)
        // Don't hold touches during pan-arbitration (~150ms) before delivering them to the canvas's tap
        // recognizer — that delay compounded the tap-to-caret latency. The handle-pan↔scroll arbitration
        // is gate-only (DocumentCanvasView.gestureRecognizerShouldBegin), so this is safe.
        scrollView.delaysContentTouches = false
        scrollView.delegate = self
        scrollView.addSubview(canvas)
        canvas.installSelectionInteractions()
        canvas.imageProvider = { [weak self] id in self?.assets[id] }
        // The canvas is sized frame-based in layoutSubviews, so a content-height change (typing wraps a
        // line, a cell grows, undo, …) must re-trigger our layout — otherwise it only updates on the next
        // layout pass (e.g. a rotation).
        canvas.onContentSizeChange = { [weak self] in self?.setNeedsLayout() }
        // The OS moves the caret via arrows through the canvas's selectedTextRange setter, which can land
        // it off-screen (e.g. arrowing up out of a tall image to the block above). Scroll it back into view.
        canvas.onSelectionChange = { [weak self] in self?.scrollCaretIntoView() }
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(keyboardFrameWillChange(_:)),
                       name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        nc.addObserver(self, selector: #selector(keyboardWillHide(_:)),
                       name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }
    deinit { NotificationCenter.default.removeObserver(self) }

    public var document: Document {
        get { Document(metadata: metadata, blocks: canvas.currentBlocks()) }
        set {
            metadata = newValue.metadata
            var blocks = newValue.blocks
            if blocks.isEmpty { blocks = [.paragraph(ParagraphBlock(id: BlockID.generate()))] }
            canvas.reload(blocks, width: bounds.width)
            setNeedsLayout()
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = bounds
        canvas.setParagraphsWidthIfNeeded(bounds.width)
        let height = canvas.intrinsicContentSize.height
        canvas.frame = CGRect(x: 0, y: 0, width: bounds.width, height: max(height, 44))
        canvas.layoutIfNeeded()
        scrollView.contentSize = CGSize(width: bounds.width, height: canvas.frame.height)
    }

    // MARK: Keyboard avoidance

    /// The vertical overlap (points) between the scroll view's window-space frame and the keyboard's
    /// window-space frame — i.e. the bottom inset the scroll content needs so nothing hides behind the
    /// keyboard. 0 when they don't intersect (keyboard offscreen / below the editor).
    static func keyboardOverlap(scrollFrameInWindow: CGRect, keyboardFrameInWindow: CGRect) -> CGFloat {
        let intersection = scrollFrameInWindow.intersection(keyboardFrameInWindow)
        return intersection.isNull ? 0 : intersection.height
    }

    /// Applies `overlap` as the scroll view's bottom content + indicator inset. Internal so the keyboard
    /// notification handler and tests share one path.
    func applyKeyboardOverlap(_ overlap: CGFloat) {
        scrollView.contentInset.bottom = overlap
        scrollView.verticalScrollIndicatorInsets.bottom = overlap
    }
    /// Test accessor: the current bottom content inset.
    var bottomContentInsetForTesting: CGFloat { scrollView.contentInset.bottom }
    /// Test accessor: the scroll view's content offset (read to assert caret-follow scrolling; set to
    /// simulate the caret being scrolled off-screen).
    var contentOffsetForTesting: CGPoint {
        get { scrollView.contentOffset }
        set { scrollView.contentOffset = newValue }
    }

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

    /// Increases the list nesting level of the touched list items (no-op on non-list paragraphs).
    public func indent() { canvas.indent() }
    /// Decreases the list nesting level of the touched list items (clamps at 0; no-op on non-list).
    public func outdent() { canvas.outdent() }

    /// Inserts an inline custom emoji `id` (host-resolved to a view via `registerEmojiViewProvider`) at
    /// the caret. `altText` is its plain-text / Markdown form (optional).
    public func insertEmoji(id: String, altText: String? = nil) { canvas.insertEmoji(id: id, altText: altText) }

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

    public func insertImage(_ image: UIImage, naturalSize: CGSize) {
        let assetID = BlockID.generate().rawValue
        assets[assetID] = image
        canvas.insertImage(image, naturalSize: naturalSize, assetID: assetID)
    }

    /// Registers an image for an assetID referenced by the loaded document (demo/asset-store seam).
    public func registerAsset(_ image: UIImage, forAssetID assetID: String) {
        assets[assetID] = image
        canvas.setNeedsDisplay()
    }

    /// Demo helper: place a gap cursor just before the first image block.
    public func placeGapCursorBeforeFirstImage() {
        canvas.placeGapCursorBeforeFirstImage()
    }

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

    // MARK: Keyboard notification handlers

    @objc private func keyboardFrameWillChange(_ note: Notification) {
        // Only react to our own keyboard (the editor is focused); hide is handled separately so the
        // inset still resets if focus was already lost.
        guard canvas.isFirstResponder,
              let info = note.userInfo,
              let endFrame = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
        else { return }
        // The keyboard frame is in screen coordinates; for a standard single-window app this matches the
        // window. Convert the scroll view's frame to window space for the overlap.
        let scrollInWindow = convert(scrollView.frame, to: nil)
        let overlap = Self.keyboardOverlap(scrollFrameInWindow: scrollInWindow, keyboardFrameInWindow: endFrame)
        animateAlongsideKeyboard(info) {
            self.applyKeyboardOverlap(overlap)
        } completion: {
            self.scrollCaretIntoView(animated: true)   // keyboard show: a single, non-arrow event → smooth scroll is fine
        }
    }

    @objc private func keyboardWillHide(_ note: Notification) {
        animateAlongsideKeyboard(note.userInfo, { self.applyKeyboardOverlap(0) }, completion: nil)
    }

    /// Runs `changes` inside the keyboard's own animation (duration + curve from the notification),
    /// falling back to a no-animation apply if the info is missing.
    private func animateAlongsideKeyboard(_ info: [AnyHashable: Any]?, _ changes: @escaping () -> Void,
                                          completion: (() -> Void)?) {
        let duration = (info?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
        let curveRaw = (info?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt)
            ?? UInt(UIView.AnimationCurve.easeInOut.rawValue)
        UIView.animate(withDuration: duration, delay: 0,
                       options: UIView.AnimationOptions(rawValue: curveRaw << 16),
                       animations: changes) { _ in completion?() }
    }

    /// Scrolls the outer scroll view so the caret is visible (above the keyboard; respects contentInset).
    /// Arrow-key nav drives this via `onSelectionChange` with `animated: false`: a synchronous scroll
    /// settles before the setter returns, so a rapid second arrow queries a stable layout. An ANIMATED
    /// scroll mutates `contentOffset` mid-flight, and a second arrow then computes its destination against
    /// that in-flux state → non-deterministic arrow results (the reported "random" behaviour). Only scrolls
    /// when the caret is actually outside the visible band, so in-screen nav/typing never churns the scroll.
    private func scrollCaretIntoView(animated: Bool = false) {
        guard canvas.isFirstResponder else { return }
        // After a content-changing edit the canvas frame + scroll `contentSize` are invalidated but not yet
        // flushed (`onContentSizeChange` only schedules our layout). Flush now so `caretRect` and the
        // scrollable extent reflect the edit before we measure/scroll. No-op for arrow nav (no pending
        // layout), so that path is unchanged.
        layoutIfNeeded()
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
}
#endif
