#if canImport(UIKit)
import UIKit
import RichTextEditorCore

@available(iOS 13.0, *)
extension DocumentCanvasView {
    /// Replaces the maximal run of consecutive top-level `.quote` paragraphs containing `index` with one
    /// `.collapsedQuote` atom (one undo step). No-op if the block at `index` is not a quote paragraph.
    func collapseQuoteRun(atIndex index: Int) {
        guard boxes.indices.contains(index),
              let startBox = boxes[index] as? BlockBox, startBox.style == .quote else { return }
        // Extend to find the maximal consecutive run of quote paragraphs.
        var lo = index, hi = index
        while lo > 0, let q = boxes[lo - 1] as? BlockBox, q.style == .quote { lo -= 1 }
        while hi + 1 < boxes.count, let q = boxes[hi + 1] as? BlockBox, q.style == .quote { hi += 1 }
        let paragraphs: [ParagraphBlock] = (lo...hi).compactMap { i in
            (boxes[i] as? BlockBox)?.currentParagraph()
        }
        // Caret bookkeeping (captured BEFORE the structural change). We only relocate the caret when it was
        // INSIDE the folded run — that text is gone, so its position must move. A caret OUTSIDE the run is
        // preserved: positions before the run are unchanged; positions after shift by the run→atom size delta.
        let runStart = boxes[lo].nodeStart
        let runEnd = boxes[hi].nodeStart + boxes[hi].nodeSize
        let oldRunSize = runEnd - runStart
        let beforeAnchor = anchor, beforeHead = head
        let caretWasInsideRun = (beforeHead >= runStart && beforeHead < runEnd)
            || (beforeAnchor >= runStart && beforeAnchor < runEnd)
        editing {
            let atom = CollapsedQuote(id: .generate(), paragraphs: paragraphs)
            let newBox = CollapsedQuoteBox(collapsedQuote: atom, mapper: mapper, quoteStyle: quoteStyle, expandImage: quoteCollapseIcons?.expand, width: effectiveWidth)
            var newBoxes = boxes
            newBoxes.replaceSubrange(lo...hi, with: [newBox])
            if caretWasInsideRun {
                // The caret was inside the folded run; relocate it just AFTER the collapsed quote into a real
                // text block — so the user keeps typing past the folded quote and a keystroke never lands on the
                // atom's display-only gap (where insertText would be swallowed into the preview layout, leaving
                // the model unchanged — the "typing expands / cursor doesn't move" bug). Reuse the following
                // paragraph when there is one; otherwise append an empty body paragraph and land there.
                let caretBox: CanvasBlock
                if lo + 1 < newBoxes.count, let next = newBoxes[lo + 1] as? BlockBox {
                    caretBox = next
                } else {
                    let trailing = BlockBox(paragraph: ParagraphBlock(id: .generate(), style: .body), mapper: mapper, width: effectiveWidth)
                    newBoxes.insert(trailing, at: lo + 1)
                    caretBox = trailing
                }
                boxes = newBoxes
                recomputeSpans()
                anchor = caretBox.textStart; head = caretBox.textStart
            } else {
                // The caret was OUTSIDE the run — leave it where it was. Positions before the run are unchanged;
                // positions at/after the run shift down by the size the run lost when it folded to one atom.
                boxes = newBoxes
                recomputeSpans()
                let delta = newBox.nodeSize - oldRunSize
                func remap(_ p: Int) -> Int { p < runStart ? p : p + delta }
                anchor = remap(beforeAnchor); head = remap(beforeHead)
            }
        }
    }

    /// Replaces the `.collapsedQuote` atom at `index` with its folded `.quote` paragraphs (one undo step).
    /// No-op if the block at `index` is not a collapsed quote.
    func expandCollapsedQuote(atIndex index: Int) {
        guard boxes.indices.contains(index),
              let cqBox = boxes[index] as? CollapsedQuoteBox else { return }
        // Mirror of collapse: only move the caret INTO the restored quote when it was ON the collapsed atom
        // (the user was interacting with it — a tap/backspace on the atom). A caret OUTSIDE the atom is
        // preserved: positions before are unchanged; positions at/after shift up as the atom grows into its
        // paragraphs. (Previously the caret always landed inside the restored quote, even when it was outside.)
        let atomStart = cqBox.nodeStart
        let atomEnd = cqBox.nodeStart + cqBox.nodeSize
        let beforeAnchor = anchor, beforeHead = head
        let caretWasOnAtom = (beforeHead >= atomStart && beforeHead < atomEnd)
            || (beforeAnchor >= atomStart && beforeAnchor < atomEnd)
        editing {
            let restored: [CanvasBlock] = cqBox.paragraphs.map { p in
                BlockBox(paragraph: p, mapper: cqBox.mapper, width: effectiveWidth)
            }
            // A collapsed quote always holds ≥1 paragraph; guard against an empty list defensively.
            let replacement: [CanvasBlock] = restored.isEmpty
                ? [BlockBox(paragraph: ParagraphBlock(id: .generate(), style: .quote), mapper: mapper, width: effectiveWidth)]
                : restored
            var newBoxes = boxes
            newBoxes.replaceSubrange(index...index, with: replacement)
            boxes = newBoxes
            recomputeSpans()
            if caretWasOnAtom {
                anchor = replacement[0].textStart; head = replacement[0].textStart
            } else {
                let newSize = replacement.reduce(0) { $0 + $1.nodeSize }
                let delta = newSize - (atomEnd - atomStart)
                func remap(_ p: Int) -> Int { p < atomStart ? p : p + delta }
                anchor = remap(beforeAnchor); head = remap(beforeHead)
            }
        }
    }
}
#endif
