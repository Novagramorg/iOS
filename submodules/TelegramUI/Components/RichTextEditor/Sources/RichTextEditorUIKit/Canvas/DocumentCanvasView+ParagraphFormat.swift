#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// Paragraph-level formatting commands. They apply to every top-level `BlockBox` the selection
/// touches (a collapsed caret = its one paragraph), mutate the box's `style` / `paragraphAttributes`,
/// and run inside `editing { }` for undo. Top-level only in 5a — paragraph styles inside table cells
/// (headings in cells aren't meaningful GFM) are out of scope.
@available(iOS 13.0, *)
extension DocumentCanvasView {
    /// Assigns a named paragraph style (Title/H1–H3/Body/Quote) to the touched paragraphs and rebuilds
    /// their run layout so the style's font (size/weight) actually applies. Run size/family pins are
    /// cleared so the style decides them; user bold/italic/strike/code and links are preserved.
    /// Title/headings are regular-weight by default (StyleSheet.font no longer forces bold), so bold is a
    /// pure user toggle that round-trips uniformly — a heading→body down-convert carries no residual bold.
    func setParagraphStyle(_ name: ParagraphStyleName) {
        guard !boxes.isEmpty else { return }
        editing {
            for box in boxes {
                guard let p = box as? BlockBox else { continue }
                let lo = p.textStart, hi = p.textStart + p.textLength
                guard selFrom <= hi && selTo >= lo else { continue }
                p.style = name
                var para = p.currentParagraph()
                para.runs = para.runs.map { run in
                    var a = run.attributes
                    a.fontSize = nil
                    a.fontFamily = nil
                    return TextRun(text: run.text, attributes: a)
                }
                p.layout.attributedString = mapper.attributedString(for: para)
            }
            recomputeSpans()
        }
    }

    /// Toggle the touched top-level paragraphs into a single code block, or (if the selection is already a
    /// single code block) toggle it back into body paragraphs split on "\n". Top-level only. Runs in
    /// `editing { }`.
    func makeCodeBlock() {
        guard !boxes.isEmpty else { return }
        let touched = boxes.indices.filter { i in
            let b = boxes[i]
            let lo = b.textStart, hi = b.textStart + b.textLength
            return selFrom <= hi && selTo >= lo
        }
        guard let first = touched.first, let last = touched.last else { return }
        // Gathers flat text from a paragraph or code block; nil for non-text blocks (image/table).
        func boxText(_ box: CanvasBlock) -> String? {
            if let p = box as? BlockBox { return p.currentParagraph().text }
            if let c = box as? CodeBlockBox { return c.currentCode().text }
            return nil   // media/table: no flat-text representation
        }
        let isToggleOff = touched.count == 1 && boxes[first] is CodeBlockBox
        // Refuse a toggle-ON that spans a non-text block (image/table) — replaceSubrange would
        // otherwise silently delete it. Must run BEFORE `editing { }` to avoid a no-op undo entry.
        if !isToggleOff, (first...last).contains(where: { boxText(boxes[$0]) == nil }) { return }
        editing {
            if isToggleOff, let codeBox = boxes[first] as? CodeBlockBox {
                // Toggle OFF: split the code text on "\n" into body paragraphs.
                let lines = codeBox.currentCode().text.components(separatedBy: "\n")
                let paras: [CanvasBlock] = lines.map { line in
                    BlockBox(paragraph: ParagraphBlock(id: BlockID.generate(), style: .body,
                                                       runs: line.isEmpty ? [] : [TextRun(text: line)]),
                             mapper: mapper, width: effectiveWidth)
                }
                var newBoxes = boxes
                newBoxes.replaceSubrange(first...first, with: paras)
                boxes = newBoxes
                recomputeSpans()
                anchor = paras[0].textStart; head = paras[0].textStart
                return
            }
            // Toggle ON: join the touched blocks' text with "\n" into one code block. Existing code
            // block text is preserved (not dropped); the guard above already ensured every block
            // in range has a flat-text representation.
            let text = (first...last).compactMap { boxText(boxes[$0]) }.joined(separator: "\n")
            let codeBox = CodeBlockBox(code: CodeBlock(id: BlockID.generate(), language: nil,
                                                       runs: [TextRun(text: text)]),
                                       mapper: mapper, width: effectiveWidth)
            var newBoxes = boxes
            newBoxes.replaceSubrange(first...last, with: [codeBox])
            boxes = newBoxes
            recomputeSpans()
            anchor = codeBox.textStart + codeBox.textLength    // caret at END of new code block
            head = anchor
        }
    }

    /// Toggle the touched top-level paragraphs into a single pull-quote block, or (if the selection
    /// is already a single pull-quote block) toggle it back into body paragraphs split on "\n".
    /// Top-level only. Runs in `editing { }`. Unlike `makeCodeBlock`, a pull quote PRESERVES inline
    /// formatting (bold/italic/link/…): runs are gathered/emitted, not flattened to plain text.
    func makePullQuote() {
        guard !boxes.isEmpty else { return }
        let touched = boxes.indices.filter { i in
            let b = boxes[i]
            let lo = b.textStart, hi = b.textStart + b.textLength
            return selFrom <= hi && selTo >= lo
        }
        guard let first = touched.first, let last = touched.last else { return }
        // Gathers runs from a paragraph or pull-quote block; nil for non-text blocks (image/table/code).
        func boxRuns(_ box: CanvasBlock) -> [TextRun]? {
            if let p = box as? BlockBox { return p.currentParagraph().runs }
            if let pq = box as? PullQuoteBox, case .pullQuote(let q) = pq.currentBlock() { return q.runs }
            return nil   // media/table/code/collapsedQuote: refuse
        }
        let isToggleOff = touched.count == 1 && boxes[first] is PullQuoteBox
        // Refuse a toggle-ON that spans a non-text block (image/table/code) — replaceSubrange would
        // otherwise silently delete it. Must run BEFORE `editing { }` to avoid a no-op undo entry.
        if !isToggleOff, (first...last).contains(where: { boxRuns(boxes[$0]) == nil }) { return }
        editing {
            if isToggleOff, let pqBox = boxes[first] as? PullQuoteBox,
               case .pullQuote(let q) = pqBox.currentBlock() {
                // Toggle OFF: split the pull-quote runs on "\n" into body paragraphs, preserving attributes.
                let paras: [CanvasBlock] = paragraphRunsSplitByNewline(q.runs).map { runs in
                    BlockBox(paragraph: ParagraphBlock(id: BlockID.generate(), style: .body, runs: runs),
                             mapper: mapper, width: effectiveWidth)
                }
                var newBoxes = boxes
                newBoxes.replaceSubrange(first...first, with: paras)
                boxes = newBoxes
                recomputeSpans()
                anchor = paras[0].textStart; head = paras[0].textStart
                return
            }
            // Toggle ON: join the touched blocks' runs with a "\n" separator between blocks into one
            // pull-quote. The guard above already ensured every block in range has a run representation.
            var joined: [TextRun] = []
            for (n, i) in (first...last).enumerated() {
                if n > 0 { joined.append(TextRun(text: "\n")) }
                joined.append(contentsOf: boxRuns(boxes[i]) ?? [])
            }
            let pqBox = PullQuoteBox(pullQuote: PullQuote(id: BlockID.generate(), runs: joined),
                                     mapper: mapper, pullQuoteStyle: pullQuoteStyle, width: effectiveWidth)
            var newBoxes = boxes
            newBoxes.replaceSubrange(first...last, with: [pqBox])
            boxes = newBoxes
            recomputeSpans()
            anchor = pqBox.textStart + pqBox.textLength    // caret at END of new pull-quote block
            head = anchor
        }
    }

    /// Split a run array at "\n" characters into separate per-paragraph run arrays, preserving per-run
    /// attributes. Used by `makePullQuote` to toggle a pull-quote back into body paragraphs.
    private func paragraphRunsSplitByNewline(_ runs: [TextRun]) -> [[TextRun]] {
        var paras: [[TextRun]] = [[]]
        for run in runs {
            let segs = run.text.components(separatedBy: "\n")
            for (i, seg) in segs.enumerated() {
                if i > 0 { paras.append([]) }
                if !seg.isEmpty { paras[paras.count - 1].append(TextRun(text: seg, attributes: run.attributes)) }
            }
        }
        return paras
    }

    /// Sets paragraph alignment on the touched paragraphs. Alignment is a pure paragraph-style
    /// property, so `restyle` (which re-applies `.paragraphStyle`) suffices — no font rebuild.
    func setAlignment(_ alignment: TextAlignment) {
        guard !boxes.isEmpty else { return }
        editing {
            for box in boxes {
                guard let p = box as? BlockBox else { continue }
                let lo = p.textStart, hi = p.textStart + p.textLength
                guard selFrom <= hi && selTo >= lo else { continue }
                p.paragraphAttributes.alignment = alignment
                restyle(p)
            }
            recomputeSpans()
        }
    }
}
#endif
