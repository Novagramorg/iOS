#if canImport(UIKit)
import UIKit
import RichTextEditorCore

@available(iOS 17.0, *)
extension DocumentCanvasView {
    /// Per-block marker strings, computed by Core `ListNumbering` from each box's list membership
    /// (runs are irrelevant to numbering, so we pass lightweight paragraphs). Keyed by `BlockID`.
    func listMarkerLabels() -> [BlockID: String] {
        // Image blocks have no list membership → a nil-list ParagraphBlock, which ListNumbering treats
        // as a non-list paragraph (resets numbering). That is the intended behavior.
        ListNumbering.labels(for: boxes.map { box in
            ParagraphBlock(id: box.id, list: (box as? BlockBox)?.listMembership)
        })
    }

    struct ListMarkerDraw { let label: String; let origin: CGPoint; let font: UIFont; let id: BlockID }

    /// Stamps each top-level list box with its Core-computed marker label and flags each as
    /// `isTopLevelBlock` (the top-level placeholder gate) and `isLastBlock` (the last-line gate for the
    /// body placeholder). Called during layout so a box can draw its own marker. Table-cell boxes are
    /// intentionally NOT stamped (parity: markers in cells aren't drawn today, and cell paragraphs draw
    /// no placeholder).
    func stampListMarkers() {
        let labels = listMarkerLabels()
        let last = boxes.last
        for case let p as BlockBox in boxes {
            p.isTopLevelBlock = true
            p.isLastBlock = (p === last)
            p.resolvedListMarker = labels[p.id]
            p.placeholders = self.placeholders
        }
    }

    /// Test/geometry seam: the per-box marker draws keyed by `BlockID`. Production draws each marker in
    /// `BlockBox.draw`; this re-derives the same geometry (via `BlockBox.listMarkerDraw()`) for assertions.
    func listMarkerDraws() -> [ListMarkerDraw] {
        boxes.compactMap { box in
            guard let p = box as? BlockBox, let d = p.listMarkerDraw() else { return nil }
            return ListMarkerDraw(label: d.label, origin: d.origin, font: d.font, id: p.id)
        }
    }

    /// Sets (or clears, with `nil`) list membership on every box the current selection touches,
    /// re-styling each affected box. Undoable.
    func setList(_ marker: ListMarker?) {
        guard !boxes.isEmpty else { return }
        editing {
            for box in boxes {
                guard let p = box as? BlockBox else { continue }
                let boxLo = p.textStart, boxHi = p.textStart + p.textLength
                guard selFrom <= boxHi && selTo >= boxLo else { continue }
                if let marker = marker {
                    p.listMembership = ListMembership(marker: marker, level: p.listMembership?.level ?? 0)
                } else {
                    p.listMembership = nil
                }
                restyle(p)
            }
            recomputeSpans()
        }
    }

    /// Re-applies the paragraph style (reflecting the box's current style + list membership) across
    /// the box's text. No-op for an empty box (typing applies the style via `typingAttributeDict`).
    func restyle(_ box: BlockBox) {
        let ps = mapper.styleSheet.paragraphStyle(for: box.style, attributes: box.paragraphAttributes,
                                                  list: box.listMembership)
        let storage = box.layout.attributedString
        guard storage.length > 0 else { return }
        let m = NSMutableAttributedString(attributedString: storage)
        m.addAttribute(.paragraphStyle, value: ps, range: NSRange(location: 0, length: m.length))
        box.layout.attributedString = m
    }
}
#endif
