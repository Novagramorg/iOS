#if canImport(UIKit)
import UIKit

/// A minimal pasteboard seam so copy/cut/paste are unit-testable with a fake — the simulator's
/// UIPasteboard.general can be unauthorized and hang on reads. Production uses UIPasteboard.general.
protocol TextPasteboard: AnyObject {
    var string: String? { get set }
    var hasStrings: Bool { get }
}
extension UIPasteboard: TextPasteboard {}

/// The system edit menu (UIEditMenuInteraction, iOS 16+) + the responder actions that populate it.
/// Presentation is gesture-driven (see DocumentCanvasView+Interaction); the actions delegate to the
/// pure helpers in DocumentCanvasView+SelectionActions and the UITextInput witnesses. Select/Select All
/// here; Copy/Cut/Paste are added in the clipboard task.
extension DocumentCanvasView {
    func installEditMenuInteraction() {
        guard editMenuInteraction == nil else { return }
        let interaction = UIEditMenuInteraction(delegate: self)
        addInteraction(interaction)
        editMenuInteraction = interaction
    }

    /// How far the edit-menu target rect grows above/below a text selection so the menu clears the round
    /// selection-handle knobs (the OS draws them a few points beyond the first/last line; UIEditMenuInteraction
    /// reserves no space for them on its own — we must include them in the target rect). Tuned visually.
    static let selectionHandleAllowance: CGFloat = 12

    /// The content the edit menu must not obscure, in canvas coordinates: a structurally-selected table
    /// row/column, else the selection union, else the image atom at a gap caret, else the collapsed caret.
    /// Pure function of the current selection — `targetRectFor` is re-invoked on every layout change.
    func editMenuContentRect() -> CGRect {
        if let outline = tableSelectionOutlineRect() { return outline }
        if selFrom != selTo {
            let union = selectionRects(globalFrom: selFrom, globalTo: selTo)
                .reduce(CGRect.null) { $0.union($1) }
            if !union.isNull { return union }   // fall through to the caret if the range produced no rects
        }
        if let img = imageBox(atGap: head) { return img.imageRect() }
        return caretRect(for: DocumentTextPosition(head))
    }

    /// The rect `UIEditMenuInteraction` lays the menu out AROUND (the `targetRectFor` value). It is the
    /// content rect grown to clear the drag handles for a non-collapsed TEXT selection; a caret, image, or
    /// structural table outline has no text handles, so it is returned unpadded.
    func editMenuTargetRect() -> CGRect {
        let content = editMenuContentRect()
        if selFrom != selTo, tableSelection == nil {
            return content.insetBy(dx: 0, dy: -Self.selectionHandleAllowance)
        }
        return content
    }

    /// Present the system menu, anchored at the top-center of the content rect (a meaningful point inside
    /// the selection so hit-testing resolves to this responder). The menu lays itself out AROUND the
    /// `targetRectFor` rect (see the delegate below), so it no longer covers the word or its handles.
    func presentEditMenu() {
        guard let interaction = editMenuInteraction, isFirstResponder else { return }
        let rect = editMenuContentRect()
        let cfg = UIEditMenuConfiguration(identifier: nil, sourcePoint: CGPoint(x: rect.midX, y: rect.minY))
        interaction.presentEditMenu(with: cfg)
    }

    /// Present the edit menu anchored at an explicit point (used for the table handle menu).
    func presentEditMenu(sourcePoint: CGPoint) {
        guard let interaction = editMenuInteraction, isFirstResponder else { return }
        interaction.presentEditMenu(with: UIEditMenuConfiguration(identifier: nil, sourcePoint: sourcePoint))
    }

    func dismissEditMenu() { editMenuInteraction?.dismissMenu() }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        switch action {
        case #selector(select(_:)):
            return hasText && selFrom == selTo && leafRegion(containingGlobal: head) != nil
        case #selector(selectAll(_:)):
            // "Everything already selected" is measured against the RENDERABLE bounds (what
            // `selectAllText` lands on), not the raw 0/documentSize: a document ending in a
            // structural block (e.g. a table) has `endOfDocument < documentSize`, so comparing
            // against documentSize would wrongly keep Select All enabled after a select-all.
            let begin = (beginningOfDocument as? DocumentTextPosition)?.offset ?? 0
            let end = (endOfDocument as? DocumentTextPosition)?.offset ?? documentSize
            return hasText && !(selFrom <= begin && selTo >= end)
        case #selector(copy(_:)), #selector(cut(_:)):
            return selFrom < selTo
        case #selector(paste(_:)):
            return pasteboard.hasStrings
        default:
            return super.canPerformAction(action, withSender: sender)
        }
    }

    @objc override func select(_ sender: Any?) {
        selectWord(at: head)
        presentEditMenu()
    }

    @objc override func selectAll(_ sender: Any?) {
        selectAllText()
        presentEditMenu()
    }

    @objc override func copy(_ sender: Any?) {
        guard selFrom < selTo, let range = selectedTextRange else { return }
        pasteboard.string = text(in: range)
    }

    @objc override func cut(_ sender: Any?) {
        guard selFrom < selTo, let range = selectedTextRange else { return }
        pasteboard.string = text(in: range)
        replace(range, withText: "")   // routes through editing { } + applySelectionReplace
    }

    @objc override func paste(_ sender: Any?) {
        guard let raw = pasteboard.string, let range = selectedTextRange else { return }
        // Multi-line paragraph-splitting paste is Phase 5d; flatten newlines so applyReplace's
        // no-newline precondition holds.
        // Normalize CRLF first so \r\n doesn't flatten to a double space; multi-line paragraph-splitting
        // paste is Phase 5d, so newlines collapse to a single space.
        let flattened = raw.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: .newlines).joined(separator: " ")
        replace(range, withText: flattened)
    }
}

/// Tracks edit-menu visibility so a tap on the caret/selection can toggle it (see handleSingleTap).
extension DocumentCanvasView: UIEditMenuInteractionDelegate {
    /// Without this, the menu's target rect defaults to a zero-size rect at the source point, so the system
    /// only avoids that single point and overlaps the selection + handles. Returning the content rect makes
    /// the menu present AROUND it. Recomputed each call (the system re-invokes this on layout changes).
    func editMenuInteraction(_ interaction: UIEditMenuInteraction,
                             targetRectFor configuration: UIEditMenuConfiguration) -> CGRect {
        editMenuTargetRect()
    }

    func editMenuInteraction(_ interaction: UIEditMenuInteraction,
                             willPresentMenuFor configuration: UIEditMenuConfiguration,
                             animator: UIEditMenuInteractionAnimating) {
        editMenuVisible = true
    }
    func editMenuInteraction(_ interaction: UIEditMenuInteraction,
                             willDismissMenuFor configuration: UIEditMenuConfiguration,
                             animator: UIEditMenuInteractionAnimating) {
        editMenuVisible = false
        lastMenuDismissTime = Date().timeIntervalSinceReferenceDate
    }
}
#endif
