#if canImport(UIKit)
import UIKit
import RichTextEditorCore

@available(iOS 13.0, *)
extension DocumentCanvasView {
    /// Inserts a fresh, expanded detail (folding) block (empty title + one empty body paragraph) into the
    /// caret's OWN stack (top level OR another detail block's body — nesting is allowed) via the container-aware
    /// `activeStack`, using the replace-empty / split / insert-before-after idiom. No-op inside a table cell or
    /// a block quote (v1). Caret lands in the title. Guarded BEFORE `editing { }` so a no-op registers no undo.
    func insertDetailsBlock() {
        guard !boxes.isEmpty, !isInsideTable(head), !isInsideBlockQuote(head),
              let a = activeStack(at: head), a.box is BlockBox else { return }
        editing {
            if selFrom != selTo { applySelectionReplace(globalFrom: selFrom, globalTo: selTo, text: "") }
            guard let active = activeStack(at: head), let p = active.box as? BlockBox else { return }
            let model = DetailsBlock(id: BlockID.generate(), title: [],
                                     children: [.paragraph(ParagraphBlock(id: BlockID.generate(), style: .body, runs: []))],
                                     expanded: true)
            let detailsBox = DetailsBox(details: model, mapper: mapper, quoteStyle: quoteStyle,
                                        pullQuoteStyle: pullQuoteStyle,
                                        expandImage: quoteCollapseIcons?.expand,
                                        collapseImage: quoteCollapseIcons?.collapse, width: effectiveWidth)
            var newBoxes = active.stack.boxes
            let idx = active.index
            if p.textLength == 0 {
                newBoxes.replaceSubrange(idx...idx, with: [detailsBox])   // empty paragraph → replace it
            } else if active.local > 0, active.local < p.textLength {
                let (upper, lower) = p.currentParagraph().split(at: active.local, newID: BlockID.generate())
                let upperBox = BlockBox(paragraph: upper, mapper: p.mapper, width: effectiveWidth)
                let lowerBox = BlockBox(paragraph: lower, mapper: p.mapper, width: effectiveWidth)
                let replacement: [any CanvasBlock] = [upperBox, detailsBox, lowerBox]
                newBoxes.replaceSubrange(idx...idx, with: replacement)
            } else if active.local == 0 {
                newBoxes.insert(detailsBox, at: idx)            // before the caret's block
            } else {
                newBoxes.insert(detailsBox, at: idx + 1)        // after the caret's block
            }
            active.stack.boxes = newBoxes
            recomputeSpans()
            // Caret into the title (first leaf region).
            let caret = detailsBox.leafRegions().first?.globalStart ?? (detailsBox.nodeStart + 2)
            anchor = caret; head = caret
        }
    }

    /// Flips `expanded` on `box` (rebuild, relocate the caret, recompute) as ONE undo step. Mirrors
    /// `toggleCollapsed(box:)` — but `expanded` is the inverse of `collapsed`, and the title is always
    /// present, so the caret stays in the title on either fold direction when it was inside the box.
    func toggleDetailsExpanded(box: DetailsBox) {
        guard let (parentStack, index) = parentStackAndIndex(of: box),
              case .details(var d) = box.currentBlock() else { return }
        d.expanded.toggle()
        let oldStart = box.nodeStart, oldSize = box.nodeSize
        let beforeAnchor = anchor, beforeHead = head
        let caretTouched = (beforeHead >= oldStart && beforeHead < oldStart + oldSize)
            || (beforeAnchor >= oldStart && beforeAnchor < oldStart + oldSize)
        editing {
            let newBox = DetailsBox(details: d, mapper: mapper, quoteStyle: quoteStyle,
                                    pullQuoteStyle: pullQuoteStyle,
                                    expandImage: quoteCollapseIcons?.expand,
                                    collapseImage: quoteCollapseIcons?.collapse, width: effectiveWidth)
            parentStack.boxes.replaceSubrange(index...index, with: [newBox])
            recomputeSpans()
            if caretTouched {
                // Title is always present → keep the caret in the title on either fold direction.
                let caret = newBox.leafRegions().first?.globalStart ?? (newBox.nodeStart + 2)
                anchor = caret; head = caret
            } else {                // caret outside — preserve, shifted by the size delta
                let delta = newBox.nodeSize - oldSize
                func remap(_ p: Int) -> Int { p < oldStart ? p : p + delta }
                anchor = remap(beforeAnchor); head = remap(beforeHead)
            }
        }
    }

    /// The DEEPEST `DetailsBox` whose token span contains `pos`, plus the stack it lives in and its index.
    /// Descends `DetailsBox`/`BlockQuoteBox` children and table cells so a nested detail block is found.
    func enclosingDetails(at pos: Int) -> (box: DetailsBox, parentStack: BlockStack, index: Int)? {
        var result: (DetailsBox, BlockStack, Int)? = nil
        func descend(_ stack: BlockStack) {
            for (i, b) in stack.boxes.enumerated() {
                if let d = b as? DetailsBox, pos > b.nodeStart, pos < b.nodeStart + b.nodeSize {
                    result = (d, stack, i)          // record; a deeper details inside overwrites it
                    descend(d.children)
                } else if let bq = b as? BlockQuoteBox, pos > b.nodeStart, pos < b.nodeStart + b.nodeSize {
                    descend(bq.children)
                } else if let t = b as? TableBlockBox, pos > b.nodeStart, pos < b.nodeStart + b.nodeSize {
                    for row in t.cells { for cell in row { descend(cell) } }
                }
            }
        }
        descend(root)
        return result
    }

    /// Double-return escape from a detail block's BODY: a collapsed caret on an EMPTY trailing body child,
    /// with ≥2 body children (so a single empty body line needs a second Return to escape — the title is
    /// children[0] and is never the escape target). Removes the empty trailing body line (or, when the whole
    /// body is empty, clears it — keeping the title) and drops a body paragraph AFTER the details block, caret
    /// there. Mirrors `blockQuoteEmptyTrailingChildExit`, scoped to the body. Returns true when it handled the
    /// exit. Runs in `editing { }`.
    func detailsEmptyTrailingBodyExit() -> Bool {
        guard selFrom == selTo,
              let active = activeStack(at: head), let child = active.box as? BlockBox, child.textLength == 0,
              let (dBox, parentStack, index) = enclosingDetails(at: head),
              dBox.children.boxes.last === child else { return false }
        let bodyBoxes = Array(dBox.children.boxes.dropFirst())          // children[0] is the always-present title
        // A single empty body line does NOT escape on the first Return (requires \n\n) — matches quotes.
        guard bodyBoxes.count > 1 else { return false }
        editing {
            let body = BlockBox(paragraph: ParagraphBlock(id: BlockID.generate(), style: .body, runs: []),
                                mapper: mapper, width: effectiveWidth)
            let allBodyEmpty = bodyBoxes.allSatisfy { ($0 as? BlockBox)?.textLength == 0 }
            if allBodyEmpty {
                dBox.children.boxes.removeLast(bodyBoxes.count)         // \n\n in an all-empty body → clear it (keep title)
            } else {
                dBox.children.boxes.removeLast()                        // drop just the empty trailing body line
            }
            parentStack.boxes.insert(body, at: index + 1)              // body paragraph AFTER the details block
            recomputeSpans()
            let caret = body.leafRegions().first?.globalStart ?? body.nodeStart
            anchor = caret; head = caret
        }
        return true
    }

    /// The first `DetailsBox` whose chevron rect (with a ±12pt touch inset) contains `point`. Descends
    /// `DetailsBox`/`BlockQuoteBox` children and table cells so a nested detail block's chevron is reachable.
    /// Deepest match wins (a nested block's chevron before its ancestor's).
    func firstDetailsGlyphHit(at point: CGPoint) -> DetailsBox? {
        func searchStack(_ b: CanvasBlock) -> DetailsBox? {
            if let d = b as? DetailsBox {
                if d.expanded {
                    for child in d.children.boxes { if let found = searchStack(child) { return found } }
                }
                if d.chevronRect().insetBy(dx: -12, dy: -12).contains(point) { return d }
                return nil
            }
            if let bq = b as? BlockQuoteBox, !bq.collapsed {
                for child in bq.children.boxes { if let found = searchStack(child) { return found } }
            }
            if let t = b as? TableBlockBox {
                for row in t.cells { for cell in row { for cellBox in cell.boxes { if let found = searchStack(cellBox) { return found } } } }
            }
            return nil
        }
        for b in boxes { if let found = searchStack(b) { return found } }
        return nil
    }
}
#endif
