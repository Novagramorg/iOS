#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// Character-format toggles. Each works over EVERY leaf text region the selection touches — body
/// paragraphs, image captions, and table cells (via `allLeafRegions`) — so formatting is continuous
/// across cells like selection itself. Attribute-only (no span change), wrapped in `editing { }` so
/// undo is the existing whole-document `[Block]` snapshot. A collapsed caret is a no-op (collapsed
/// "typing attributes" are deferred).
@available(iOS 13.0, *)
extension DocumentCanvasView {
    /// The (storage, range) pairs a character-format command applies to. When a table row/column is
    /// structurally selected, that's every cell's full text in the row/column (so toolbar formatting
    /// works on the whole row/column). Otherwise it's the text selection's intersection with each leaf
    /// region — body paragraphs, captions, and table cells alike. Empty when nothing applies (e.g. a
    /// bare collapsed caret).
    func characterFormatTargets() -> [(storage: NSTextStorage, range: NSRange, layout: BlockLayoutEngine)] {
        if let regions = tableStructuralSelectionRegions() {
            return regions.compactMap { r in
                guard r.length > 0, let storage = r.layout.backingStorage else { return nil }
                return (storage, NSRange(location: 0, length: r.length), r.layout)
            }
        }
        guard selFrom < selTo else { return [] }
        return allLeafRegions().compactMap { r in
            let a = max(selFrom, r.globalStart), b = min(selTo, r.globalStart + r.length)
            guard a < b, let storage = r.layout.backingStorage else { return nil }
            return (storage, NSRange(location: a - r.globalStart, length: b - a), r.layout)
        }
    }

    /// The toggle engine. `isSet` reports whether a storage range already fully carries the format;
    /// the direction is decided once globally (all covered ranges set → remove, else add) and passed
    /// to `setOn` as `allOn`.
    func applyCharacterToggle(isSet: (NSTextStorage, NSRange) -> Bool,
                              setOn: (NSTextStorage, NSRange, _ allOn: Bool) -> Void) {
        let covered = characterFormatTargets()
        guard !covered.isEmpty else { return }
        let allOn = covered.allSatisfy { isSet($0.storage, $0.range) }
        editing {
            for c in covered {
                setOn(c.storage, c.range, allOn)
                // Direct NSTextStorage mutation bypasses BlockLayout's renderVersion bump sites, so a
                // view-backed paragraph wouldn't repaint (its renderSignature wouldn't change). Bump here.
                c.layout.bumpRenderVersion()
            }
        }
    }

    // MARK: - Format predicates (shared by toggle and state reader)

    func rangeIsBold(_ storage: NSTextStorage, _ range: NSRange) -> Bool {
        // Bold is the user-intent `.rtBold` marker, NOT the rendered `.traitBold` — the latter is forced onto
        // substituted scripts by the system "Bold Text" setting and would misreport ambient bold as user bold.
        var all = true
        storage.enumerateAttribute(.rtBold, in: range, options: []) { v, _, stop in
            if ((v as? Bool) ?? false) == false { all = false; stop.pointee = true }
        }
        return all
    }

    func rangeIsItalic(_ storage: NSTextStorage, _ range: NSRange) -> Bool {
        var all = true
        storage.enumerateAttribute(.font, in: range, options: []) { v, _, stop in
            let f = (v as? UIFont) ?? UIFont.systemFont(ofSize: 16)
            if !f.fontDescriptor.symbolicTraits.contains(.traitItalic) { all = false; stop.pointee = true }
        }
        return all
    }

    func rangeIsUnderline(_ storage: NSTextStorage, _ range: NSRange) -> Bool {
        var all = true
        storage.enumerateAttribute(.underlineStyle, in: range, options: []) { v, _, stop in
            if ((v as? Int) ?? 0) == 0 { all = false; stop.pointee = true }
        }
        return all
    }

    func rangeIsStrikethrough(_ storage: NSTextStorage, _ range: NSRange) -> Bool {
        var all = true
        storage.enumerateAttribute(.strikethroughStyle, in: range, options: []) { v, _, stop in
            if ((v as? Int) ?? 0) == 0 { all = false; stop.pointee = true }
        }
        return all
    }

    func rangeIsInlineCode(_ storage: NSTextStorage, _ range: NSRange) -> Bool {
        var all = true
        storage.enumerateAttribute(.rtInlineCode, in: range, options: []) { v, _, stop in
            if ((v as? Bool) ?? false) == false { all = false; stop.pointee = true }
        }
        return all
    }

    func toggleBold() {
        applyCharacterToggle(isSet: { s, r in self.rangeIsBold(s, r) }, setOn: { storage, range, allOn in
            storage.enumerateAttribute(.font, in: range, options: []) { v, sub, _ in
                let f = (v as? UIFont) ?? UIFont.systemFont(ofSize: 16)
                var t = f.fontDescriptor.symbolicTraits
                if allOn { t.remove(.traitBold) } else { t.insert(.traitBold) }
                if let d = f.fontDescriptor.withSymbolicTraits(t) {
                    storage.addAttribute(.font, value: UIFont(descriptor: d, size: f.pointSize), range: sub)
                }
            }
            // Carry the user-intent marker alongside the render trait so model bold round-trips (read by
            // `characterAttributes`/`rangeIsBold`); absence == not bold.
            if allOn { storage.removeAttribute(.rtBold, range: range) }
            else { storage.addAttribute(.rtBold, value: true, range: range) }
        })
    }

    func toggleItalic() {
        applyCharacterToggle(isSet: { s, r in self.rangeIsItalic(s, r) }, setOn: { storage, range, allOn in
            storage.enumerateAttribute(.font, in: range, options: []) { v, sub, _ in
                let f = (v as? UIFont) ?? UIFont.systemFont(ofSize: 16)
                var t = f.fontDescriptor.symbolicTraits
                if allOn { t.remove(.traitItalic) } else { t.insert(.traitItalic) }
                if let d = f.fontDescriptor.withSymbolicTraits(t) {
                    storage.addAttribute(.font, value: UIFont(descriptor: d, size: f.pointSize), range: sub)
                }
            }
        })
    }

    func toggleStrikethrough() {
        applyCharacterToggle(isSet: { s, r in self.rangeIsStrikethrough(s, r) }, setOn: { storage, range, allOn in
            if allOn { storage.removeAttribute(.strikethroughStyle, range: range) }
            else { storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range) }
        })
    }

    func toggleUnderline() {
        applyCharacterToggle(isSet: { s, r in self.rangeIsUnderline(s, r) }, setOn: { storage, range, allOn in
            if allOn { storage.removeAttribute(.underlineStyle, range: range) }
            else { storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range) }
        })
    }

    /// Toggles the spoiler marker (`.rtSpoiler`) over the selection (cell/row/column-aware via
    /// `characterFormatTargets`). Additive — it touches no font/colour, so it composes with every other
    /// format. The display-only hide + dust overlay are driven separately by `syncSpoilers`.
    func toggleSpoiler() {
        applyCharacterToggle(isSet: { storage, range in
            var all = true
            storage.enumerateAttribute(.rtSpoiler, in: range, options: []) { v, _, stop in
                if ((v as? Bool) ?? false) == false { all = false; stop.pointee = true }
            }
            return all
        }, setOn: { storage, range, allOn in
            if allOn { storage.removeAttribute(.rtSpoiler, range: range) }
            else { storage.addAttribute(.rtSpoiler, value: true, range: range) }
        })
    }

    /// Inline code swaps the run's font for a monospaced one (and marks it). GFM code spans can't
    /// carry emphasis, so toggling off restores a plain system font at the same size (any bold/italic
    /// inside is intentionally dropped); the named-style font returns on the next model round-trip.
    func toggleInlineCode() {
        applyCharacterToggle(isSet: { s, r in self.rangeIsInlineCode(s, r) }, setOn: { storage, range, allOn in
            storage.enumerateAttribute(.font, in: range, options: []) { v, sub, _ in
                let size = ((v as? UIFont) ?? UIFont.systemFont(ofSize: 16)).pointSize
                if allOn {
                    storage.removeAttribute(.rtInlineCode, range: sub)
                    storage.removeAttribute(.backgroundColor, range: sub)
                    storage.addAttribute(.font, value: UIFont.systemFont(ofSize: size), range: sub)
                } else {
                    storage.addAttribute(.rtInlineCode, value: true, range: sub)
                    storage.addAttribute(.backgroundColor, value: UIColor.systemGray5, range: sub)
                    storage.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: size, weight: .regular), range: sub)
                }
            }
        })
    }
}
#endif
