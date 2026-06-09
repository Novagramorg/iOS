#if canImport(UIKit)
import UIKit
import RichTextEditorCore

extension DocumentCanvasView {
    /// True when `img` should render its selection tint — either it is the tap-selected atom, or a
    /// non-collapsed text selection spans across its atom (a range flowing over it). A collapsed gap
    /// caret and a caption-only selection are both excluded.
    /// (`selFrom <= nodeStart && selTo >= textStart` ⇒ the range runs from at/before the gap to at/after
    /// the caption start, i.e. it fully contains the image atom.)
    func isImageSelected(_ img: ImageBlockBox) -> Bool {
        if imageSelection == img.id { return true }
        return selFrom != selTo && selFrom <= img.nodeStart && selTo >= img.textStart
    }

    /// The canvas-coords rect the selection tint fills for `img`, or nil when it isn't selected.
    /// Single geometry seam so a unit test and the actual draw cannot diverge.
    func imageSelectionTintRect(for img: ImageBlockBox) -> CGRect? {
        isImageSelected(img) ? img.imageRect() : nil
    }

    func clearImageSelection() {
        guard imageSelection != nil else { return }
        imageSelection = nil
        refreshSelectionUI(); setNeedsDisplay()
    }

    /// Clears BOTH structural selections (table row/column AND image atom). Called by every
    /// "this action moves on" site that previously cleared only the table selection.
    func clearStructuralSelections() { clearTableSelection(); clearImageSelection() }

    /// Selects the top-level image `img` as an atom: parks the (hidden) caret at its gap, sets
    /// `imageSelection`, and clears any table structural selection. The tint over the image is the
    /// indicator. Mirrors `selectTableRows`.
    func selectImage(_ img: ImageBlockBox) {
        finalizeMarkedText()        // a deliberate selection change finalizes marked text (uniform invariant)
        clearTableSelection()
        // Bracket the caret move with the input-delegate notification (like `setCaret`) so the OS re-reads
        // `selectedTextRange` = the gap. Without it the OS keeps the STALE prior caret, and a hardware Arrow
        // key runs `position(from:in:)` from the previous position instead of the image (the reported bug).
        textInputDelegate?.selectionWillChange(self)
        anchor = img.nodeStart; head = img.nodeStart
        textInputDelegate?.selectionDidChange(self)
        imageSelection = img.id
        refreshSelectionUI(); setNeedsDisplay()
    }

    /// Two-step tap on an image (mirrors the table-handle two-step): first tap selects it; a tap on the
    /// already-selected image toggles its edit menu (reusing the flicker guard).
    func handleImageTap(_ img: ImageBlockBox, wasMenuVisible: Bool) {
        if imageSelection != img.id {
            dismissEditMenu()
            selectImage(img)
        } else {
            let justDismissed = Date().timeIntervalSinceReferenceDate - lastMenuDismissTime < Self.menuToggleSuppressWindow
            switch menuToggleAction(menuVisible: wasMenuVisible, justDismissed: justDismissed) {
            case .present: presentEditMenu()
            case .dismiss: dismissEditMenu()
            }
        }
    }

    /// The edit menu for the tap-selected image: Delete (whole block) only. Cut/Copy are deferred to the
    /// rich-clipboard phase (the pasteboard is plaintext and an image has no plaintext form).
    func imageSelectionMenu() -> UIMenu? {
        guard imageSelection != nil else { return nil }
        return UIMenu(children: [
            UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) {
                [weak self] _ in
                guard let self, let id = self.imageSelection,
                      let i = self.boxes.firstIndex(where: { $0.id == id }) else { return }
                self.editing { self.deleteImageBox(at: i) }
                self.clearImageSelection()
            }
        ])
    }
}
#endif
