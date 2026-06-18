#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// Pure, directly-callable selection logic, factored OUT of the gesture/menu callbacks so it can be
/// unit-tested without synthesizing touch events. The recognizers (DocumentCanvasView+Interaction) and
/// the menu actions (DocumentCanvasView+EditMenu) are thin wrappers over these.
@available(iOS 17.0, *)
extension DocumentCanvasView {
    /// What a single tap at `resolved` should do. `.toggleMenu` — the tap landed on the existing collapsed
    /// caret OR inside the active selection → toggle the edit menu, KEEPING the current caret/selection (the
    /// gesture handler presents or dismisses depending on whether the menu is already showing). `.setCaret`
    /// — the tap landed elsewhere → place the caret there (collapsing any selection) and dismiss the menu.
    enum TapOutcome: Equatable { case toggleMenu, setCaret(Int) }

    func tapOutcome(forResolvedPosition resolved: Int) -> TapOutcome {
        if selFrom != selTo {
            // Tap inside the selection → toggle the menu (keep the selection); outside → collapse to a caret.
            return (resolved >= selFrom && resolved <= selTo) ? .toggleMenu : .setCaret(resolved)
        }
        return resolved == head ? .toggleMenu : .setCaret(resolved)
    }

    /// The outcome of a toggle-tap on the caret/selection.
    enum MenuToggleAction: Equatable { case present, dismiss }

    /// Window (seconds) within which a just-fired `willDismiss` is attributed to the current tap, so the
    /// handler doesn't re-present the menu the system just closed. A generous margin over the brief gap
    /// between the system's tap-down auto-dismiss and our tap-up handler.
    static let menuToggleSuppressWindow: TimeInterval = 0.75

    /// A tap on the caret/selection toggles the edit menu: DISMISS when the menu is showing OR was just
    /// auto-dismissed by this same tap; otherwise PRESENT. Pure (unit-tested) — the `justDismissed` race
    /// fix is what stops the close-then-reopen flicker.
    func menuToggleAction(menuVisible: Bool, justDismissed: Bool) -> MenuToggleAction {
        (menuVisible || justDismissed) ? .dismiss : .present
    }

    /// Which selection endpoint a drag should move, by global-offset proximity. nil when collapsed.
    enum SelectionEndpoint: Equatable { case anchor, head }

    func nearerSelectionEndpoint(toGlobal pos: Int) -> SelectionEndpoint? {
        guard selFrom != selTo else { return nil }
        return abs(pos - anchor) <= abs(pos - head) ? .anchor : .head
    }

    /// Select the word enclosing `pos` (Select menu item / double tap). No-op at a structural gap.
    func selectWord(at pos: Int) {
        guard let t = tokenizer as? DocumentTokenizer, let r = t.wordRange(at: pos) else { return }
        applySelection(from: r.from.offset, to: r.to.offset)
    }

    /// Select the paragraph/region enclosing `pos` (triple tap). No-op at a structural gap.
    func selectParagraph(at pos: Int) {
        guard let t = tokenizer as? DocumentTokenizer, let r = t.paragraphRange(at: pos) else { return }
        applySelection(from: r.from.offset, to: r.to.offset)
    }

    /// Select the whole document, bounded to renderable start/end (so the trailing caret is renderable).
    func selectAllText() {
        applySelection(from: (beginningOfDocument as? DocumentTextPosition)?.offset ?? 0,
                       to: (endOfDocument as? DocumentTextPosition)?.offset ?? documentSize)
    }

    private func applySelection(from: Int, to: Int) {
        finalizeMarkedText()     // Select-All / word / paragraph is a deliberate selection change: commit a
                                 // composition / dismiss a prediction first, else insertText would replace the
                                 // stale marked range instead of the new selection. clampGlobal below re-bounds.
        clearImageSelection()    // word/paragraph/Select-All deselects an atom-selected image
        textInputDelegate?.selectionWillChange(self)
        anchor = clampGlobal(from); head = clampGlobal(to)
        textInputDelegate?.selectionDidChange(self)
        setNeedsDisplay(); refreshSelectionUI()
    }
}
#endif
