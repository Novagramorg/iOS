#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// Link commands. Like the character toggles, they operate over the same targets as
/// `characterFormatTargets()` — every leaf region the text selection touches, or every cell of a
/// structurally-selected table row/column — so a link is continuous across cells. A link carries a
/// value, so these build on `applyCharacterAttribute` (a value-set sibling of `applyCharacterToggle`)
/// rather than the toggle engine. A bare collapsed caret (no table selection) is a no-op. The visible
/// blue styling (no underline) is injected into the live storage here AND emitted by the mapper on
/// rebuild, and suppressed on read-back — so the model stays link-only (see `AttributedStringMapper`).
@available(iOS 17.0, *)
extension DocumentCanvasView {
    /// Runs `mutate` on each (storage, range) `characterFormatTargets()` covers, inside `editing { }`.
    /// No toggle direction — just a per-range mutation. No-op when nothing is targeted.
    func applyCharacterAttribute(_ mutate: (NSTextStorage, NSRange) -> Void) {
        let covered = characterFormatTargets()
        guard !covered.isEmpty else { return }
        editing {
            for c in covered {
                mutate(c.storage, c.range)
                // Direct NSTextStorage mutation bypasses BlockLayout's renderVersion bump sites, so a
                // view-backed paragraph wouldn't repaint (its renderSignature wouldn't change). Bump here.
                c.layout.bumpRenderVersion()
            }
        }
    }

    /// Sets `url` as the link over the selection, with the render-only blue styling (no underline).
    func setLink(_ url: String) {
        applyCharacterAttribute { storage, range in
            storage.addAttribute(.link, value: url, range: range)
            storage.addAttribute(.foregroundColor, value: UIColor.link, range: range)
            // No underline: reference design shows links as blue text only.
        }
    }

    /// Removes the link over the selection and its render-only styling (resets foreground to the
    /// mapper's default so the text renders like any other unlinked run).
    func removeLink() {
        applyCharacterAttribute { storage, range in
            storage.removeAttribute(.link, range: range)
            // Defensive: storage written before 6a may carry a link underline; clear it.
            storage.removeAttribute(.underlineStyle, range: range)
            // Match the mapper's default for unlinked runs (it writes (ca.foreground ?? .black)); don't
            // removeAttribute(.foregroundColor) — that would leave live storage colorless until the next rebuild.
            storage.addAttribute(.foregroundColor, value: UIColor.black, range: range)
        }
    }

    /// The link the entire target carries (the text selection, or a structurally-selected table
    /// row/column — matching what `setLink` would apply), or nil if nothing is targeted, any covered
    /// text is unlinked, or two different links are mixed. Used to prefill the demo's URL prompt.
    func currentLink() -> String? {
        let targets = characterFormatTargets()
        guard !targets.isEmpty else { return nil }
        var values = Set<String>()
        var sawUnlinked = false
        for t in targets {
            t.storage.enumerateAttribute(.link, in: t.range, options: []) { v, _, _ in
                if let s = (v as? String) ?? (v as? URL)?.absoluteString { values.insert(s) }
                else { sawUnlinked = true }
            }
        }
        guard !sawUnlinked, values.count == 1 else { return nil }
        return values.first
    }
}
#endif
