#if canImport(UIKit)
import UIKit
import RichTextEditorCore

@available(iOS 17.0, *)
extension DocumentCanvasView {
    /// Wraps a mutation: snapshots the document + selection, brackets the input-delegate change,
    /// runs `body`, registers a self-re-registering undo, and refreshes layout/display. This is
    /// the single entry point for every editing operation (typing, structural, list).
    func editing(_ body: () -> Void) {
        finalizeMarkedText()   // commit a composition (own undo step) / dismiss a prediction before this edit
        dismissEditMenuForSelectionOrTextChange()   // the text is about to change → close any open menu (native UITextView)
        let before = currentBlocks()
        let beforeAnchor = anchor, beforeHead = head
        textInputDelegate?.textWillChange(self)
        body()
        textInputDelegate?.textDidChange(self)
        registerUndo(snapshot: before, anchor: beforeAnchor, head: beforeHead)
        recomputeDocumentHasSpoilers()   // an edit (toggleSpoiler/delete/paste/insert/structural) may add or remove the last spoiler — refresh the syncSpoilers gate before refreshSelectionUI runs it
        notifyContentSizeChanged(); setNeedsDisplay(); refreshSelectionUI()
        onSelectionChange?()   // an edit moves the caret too — ask the host to scroll it into view (like the arrow-key setter)
    }

    /// Restores a whole-document snapshot, then re-registers the inverse for redo (Phase 1 trick).
    func registerUndo(snapshot blocks: [Block], anchor: Int, head: Int) {
        effectiveUndoManager?.registerUndo(withTarget: self) { target in
            // A system Cmd-Z / shake-undo can fire while composing (the public undo()/redo() finalize first,
            // but the responder path doesn't). Drop any marked-text view state so the snapshot restore can't
            // leave a stale markedRange pointing into the replaced document.
            target.markedRange = nil; target.markedTextIsPrediction = false; target.ghostStyledLayout = nil
            let redo = target.currentBlocks()
            let redoAnchor = target.anchor, redoHead = target.head
            target.textInputDelegate?.textWillChange(target)
            target.setBlocks(blocks, width: target.effectiveWidth)
            target.anchor = min(anchor, target.documentSize)
            target.head = min(head, target.documentSize)
            target.textInputDelegate?.textDidChange(target)
            target.registerUndo(snapshot: redo, anchor: redoAnchor, head: redoHead)
            target.notifyContentSizeChanged()
            target.setNeedsDisplay(); target.refreshSelectionUI()
        }
    }

    /// The structural-edit engine, now operating on the `BlockStack` that owns the selection (the
    /// root stack, or a table cell's stack — resolved via `activeStack`). Replaces the global range
    /// `[from, to)` with `text` WITHIN that one stack. Same-block: in-place. Cross-block: split/merge
    /// (paragraph↔paragraph) or truncate (image endpoint), dropping covered middle boxes. The endpoints
    /// MUST live in the same stack — callers guarantee this (top-level OR same-cell); a cross-stack
    /// range goes to `applyMultiRegionClear` instead. NOT wrapped in undo — call inside `editing { … }`.
    /// Precondition: `text` must not contain a newline — callers split paragraphs first (see
    /// `insertParagraphBreak`); multi-line paste is deferred (Phase 2c).
    func applyReplace(globalFrom: Int, globalTo: Int, text: String) {
        guard !boxes.isEmpty else { return }
        let lo = clampGlobal(min(globalFrom, globalTo))
        let hi = clampGlobal(max(globalFrom, globalTo))
        guard let start = activeStack(at: lo), let end = activeStack(at: hi), start.stack === end.stack else { return }
        let stack = start.stack

        if start.index == end.index {
            let b = start.box
            let attrs = typingAttributesAtGlobal(b.textStart + start.local)
            b.textLayout.replace(start: start.local, end: end.local,
                                 with: NSAttributedString(string: text, attributes: attrs))
            recomputeSpans()
            let caret = b.textStart + start.local + (text as NSString).length
            anchor = caret; head = caret
            return
        }

        // Cross-block. A media (image/video) endpoint is REMOVED only when the selection covers its
        // whole node (the leading gap + the entire caption); a selection that ends/starts PARTWAY through
        // a caption keeps the image, truncated (the Phase 2c partial behavior — see the truncate branch).
        // Select-All over a document whose first/last block is an image fully covers that image, so it is
        // dropped here exactly as a covered MIDDLE image already is.
        func mediaFullyCovered(_ box: CanvasBlock) -> Bool {
            box is MediaBlockBox && lo <= box.nodeStart && hi >= box.textStart + box.textLength
        }
        let keepStartMedia = (start.box is MediaBlockBox) && !mediaFullyCovered(start.box)
        let keepEndMedia = (end.box is MediaBlockBox) && !mediaFullyCovered(end.box)

        // Merge path: each endpoint is a paragraph OR a fully-covered media (which contributes nothing
        // and is dropped). The surviving paragraph is startPrefix + text + endSuffix; replaceSubrange over
        // [start.index ... end.index] drops every box between the endpoints — including a fully-covered
        // endpoint image. (Paragraph↔paragraph is the original 2b split/merge, unchanged.)
        if !keepStartMedia && !keepEndMedia {
            let headPart = (start.box as? BlockBox)?.currentParagraph().split(at: start.local, newID: BlockID.generate()).0
            let tailPart = (end.box as? BlockBox)?.currentParagraph().split(at: end.local, newID: BlockID.generate()).1
            var headRuns = headPart?.runs ?? []
            if !text.isEmpty {
                let ca = mapper.characterAttributes(from: typingAttributesAtGlobal(start.box.textStart + start.local), style: (start.box as? BlockBox)?.style ?? .body)
                headRuns.append(TextRun(text: text, attributes: ca))
            }
            // Base paragraph carries the start paragraph's identity/style when present (preserving the
            // upper block's style across the merge), else the end paragraph's, else a fresh body paragraph
            // (both endpoints were fully-covered media — e.g. Select-All over [image, image]).
            var merged = headPart ?? tailPart ?? ParagraphBlock(id: BlockID.generate(), runs: [])
            merged.runs = headRuns
            if let tailPart { merged = merged.merging(tailPart) }
            let mergedBox = BlockBox(paragraph: merged, mapper: mapper, width: effectiveWidth)
            var newBoxes = stack.boxes
            newBoxes.replaceSubrange(start.index...end.index, with: [mergedBox])
            stack.boxes = newBoxes
            recomputeSpans()
            let caret = mergedBox.textStart + (headPart?.utf16Count ?? 0) + (text as NSString).length
            anchor = caret; head = caret
            return
        }
        // A media endpoint is only PARTIALLY covered (selection starts/ends partway through its caption):
        // TRUNCATE each endpoint's text region (start keeps [0, start.local) + inserted text; end keeps
        // [end.local, …)) and drop ONLY the strictly-covered middle boxes. Do NOT remove the endpoint
        // boxes — a selection ending inside an image caption keeps that image with its surviving suffix.
        start.box.textLayout.replace(start: start.local, end: start.box.textLength,
                                     with: NSAttributedString(string: text,
                                         attributes: typingAttributesAtGlobal(start.box.textStart + start.local)))
        end.box.textLayout.replace(start: 0, end: end.local, with: NSAttributedString(string: ""))
        if end.index > start.index + 1 {
            var newBoxes = stack.boxes
            newBoxes.removeSubrange((start.index + 1)..<end.index)
            stack.boxes = newBoxes
        }
        recomputeSpans()
        let caret = start.box.textStart + start.local + (text as NSString).length
        anchor = caret; head = caret
    }

    /// Removes the image box at `index`, placing the caret at the end of the previous block's text
    /// (or the start of the new first block's text region). Caller wraps this in `editing { … }`.
    func deleteImageBox(at index: Int) {
        guard boxes.indices.contains(index) else { return }
        var newBoxes = boxes
        newBoxes.remove(at: index)
        boxes = newBoxes
        recomputeSpans()
        let caret = index > 0 ? boxes[index - 1].textStart + boxes[index - 1].textLength
                              : (boxes.first?.textStart ?? 0)
        anchor = caret; head = caret
    }

    /// Removes the block at `index` (an empty paragraph just before `media`), parking the caret at
    /// `media`'s leading gap — which shifts up into the removed block's place. Used by backspace at a
    /// media block's gap when the previous paragraph is empty. Caller wraps this in `editing { … }`.
    func deleteBlock(at index: Int, parkingCaretAtGapOf media: CanvasBlock) {
        guard boxes.indices.contains(index) else { return }
        var newBoxes = boxes
        newBoxes.remove(at: index)
        boxes = newBoxes
        recomputeSpans()
        anchor = media.nodeStart; head = media.nodeStart   // media moved up; its gap is its (recomputed) nodeStart
    }

    /// Resolves a global position to its owning `BlockStack` — a cell stack when inside a table,
    /// else the root stack (via `resolveBox`, which snaps boundary positions). Returns the box and
    /// the local offset + index within that stack.
    func activeStack(at pos: Int) -> (stack: BlockStack, box: CanvasBlock, local: Int, index: Int)? {
        if isInsideTable(pos) {
            for box in boxes {
                if let t = box as? TableBlockBox, let hit = t.cellStack(containing: pos) { return hit }
            }
            return nil
        }
        guard let r = resolveBox(at: pos) else { return nil }
        return (root, r.box, r.local, r.index)
    }

    /// True when a range can be safely edited by the top-level cross-block engine: neither endpoint
    /// is inside a cell, and neither endpoint resolves to a table box. (Spanning a table is fine —
    /// the table is a covered middle box that the merge drops.)
    func selectionEndpointsEditableTopLevel(_ a: Int, _ b: Int) -> Bool {
        if isInsideTable(a) || isInsideTable(b) { return false }
        if let ra = resolveBox(at: a), ra.box is TableBlockBox { return false }
        if let rb = resolveBox(at: b), rb.box is TableBlockBox { return false }
        return true
    }

    /// True when both positions resolve to the **same** table cell's `BlockStack` — so the full
    /// (stack-scoped) `applyReplace` engine can edit within that cell, exactly like top-level.
    func bothInSameCellStack(_ a: Int, _ b: Int) -> Bool {
        guard isInsideTable(a), isInsideTable(b),
              let sa = activeStack(at: a), let sb = activeStack(at: b) else { return false }
        return sa.stack === sb.stack
    }

    /// THE single routing point for replacing a (non-empty) selection `[from, to)` with `text`. A
    /// selection whose endpoints share a stack (both top-level, or both in one cell) goes to the
    /// stack-scoped `applyReplace`; a selection that crosses stack boundaries (cross-cell, cell↔body,
    /// cross-table, or an endpoint resting on a table box) goes to the structure-preserving
    /// `applyMultiRegionClear`. Every selection-replacing edit (typing, delete, paste, replace-witness,
    /// insert-image's pre-clear) MUST route through here so none drives a cross-stack range into
    /// `applyReplace`'s same-stack guard (which would silently no-op). Caller wraps in `editing { … }`.
    func applySelectionReplace(globalFrom: Int, globalTo: Int, text: String) {
        if selectionEndpointsEditableTopLevel(globalFrom, globalTo) || bothInSameCellStack(globalFrom, globalTo) {
            applyReplace(globalFrom: globalFrom, globalTo: globalTo, text: text)
        } else {
            applyMultiRegionClear(globalFrom: globalFrom, globalTo: globalTo, text: text)
        }
    }

    /// If a collapsed caret resolves to a table box — a structural boundary such as the position just
    /// before a leading table or after a trailing table — returns the global start of that table's
    /// nearest cell so the edit can route through the cell's stack. Returns `pos` unchanged when it is
    /// not at such a boundary (or the table has no cells). Prevents writing through a table's degenerate
    /// `textLayout` (which would silently drop the keystroke).
    func caretSnappedIntoCell(_ pos: Int) -> Int {
        guard !isInsideTable(pos), let r = resolveBox(at: pos), let table = r.box as? TableBlockBox else { return pos }
        let snap = pos <= table.nodeStart
            ? table.cellTextStart(row: 0, column: 0)
            : table.cellTextStart(row: table.rowCount - 1, column: table.columnCount - 1)
        return snap ?? pos
    }

    /// Splits the caret's paragraph at the caret, within whatever `BlockStack` owns the caret (root
    /// or a cell). Deletes any selection first (bounded if it touches a table). Caret → new block start.
    func insertParagraphBreak() {
        guard !boxes.isEmpty else { return }
        // Return on an EMPTY list item does NOT continue the list: a nested item outdents one level, a
        // top-level (level 0) one ends the list (becomes a body paragraph). The caret stays put. Matches
        // the placeholder hint; a non-empty list item or plain paragraph falls through to a normal split.
        if selFrom == selTo, let active = activeStack(at: head), let p = active.box as? BlockBox,
           let list = p.listMembership, p.textLength == 0 {
            if list.level > 0 {
                outdent()
            } else {
                editing {
                    p.listMembership = nil
                    p.style = .body
                    restyle(p)
                    recomputeSpans()
                }
            }
            return
        }
        editing {
            if selFrom != selTo {
                applySelectionReplace(globalFrom: selFrom, globalTo: selTo, text: "")
            }
            guard let active = activeStack(at: head), let p = active.box as? BlockBox else { return }
            let (upper, lower) = p.currentParagraph().split(at: active.local, newID: BlockID.generate())
            let upperBox = BlockBox(paragraph: upper, mapper: mapper, width: effectiveWidth)
            let lowerBox = BlockBox(paragraph: lower, mapper: mapper, width: effectiveWidth)
            var newBoxes = active.stack.boxes
            newBoxes.replaceSubrange(active.index...active.index, with: [upperBox, lowerBox])
            active.stack.boxes = newBoxes
            recomputeSpans()
            anchor = lowerBox.textStart; head = lowerBox.textStart
        }
    }

    /// Merges `stack.boxes[upperIndex+1]` into `stack.boxes[upperIndex]` (both paragraphs), within the
    /// given stack. Caret lands at the join. Caller wraps in `editing { }`.
    func mergeParagraphs(in stack: BlockStack, upperIndex: Int) {
        guard stack.boxes.indices.contains(upperIndex), stack.boxes.indices.contains(upperIndex + 1),
              let upper = stack.boxes[upperIndex] as? BlockBox,
              let lower = stack.boxes[upperIndex + 1] as? BlockBox else { return }
        let joinLocal = upper.currentParagraph().utf16Count
        let merged = upper.currentParagraph().merging(lower.currentParagraph())
        let mergedBox = BlockBox(paragraph: merged, mapper: mapper, width: effectiveWidth)
        var newBoxes = stack.boxes
        newBoxes.replaceSubrange(upperIndex...(upperIndex + 1), with: [mergedBox])
        stack.boxes = newBoxes
        recomputeSpans()
        let caret = mergedBox.textStart + joinLocal
        anchor = caret; head = caret
    }

    /// Inserts a media block (`kind`, with an empty caption) at the caret, splitting the caret's paragraph
    /// if mid-text. The host resolves `mediaID` to a view via the canvas's `mediaViewProvider` (each
    /// occurrence gets its own view, keyed by the new block's `BlockID`). Caret lands in the new caption.
    func insertMedia(mediaID: String, naturalSize: CGSize, kind: MediaKind) {
        guard !boxes.isEmpty else { return }
        editing {
            if selFrom != selTo { applySelectionReplace(globalFrom: selFrom, globalTo: selTo, text: "") }
            guard let pos = resolveBox(at: head) else { return }
            let mediaBlock = MediaBlock(id: BlockID.generate(), mediaID: mediaID, kind: kind,
                                        naturalSize: Size2D(width: Double(naturalSize.width),
                                                            height: Double(naturalSize.height)))
            let mediaBox = MediaBlockBox(media: mediaBlock, mapper: mapper, width: effectiveWidth)
            var newBoxes = boxes
            if let p = pos.box as? BlockBox, pos.local > 0, pos.local < p.textLength {
                // split the paragraph and insert the media between the halves
                let (upper, lower) = p.currentParagraph().split(at: pos.local, newID: BlockID.generate())
                let upperBox = BlockBox(paragraph: upper, mapper: mapper, width: effectiveWidth)
                let lowerBox = BlockBox(paragraph: lower, mapper: mapper, width: effectiveWidth)
                let replacement: [any CanvasBlock] = [upperBox, mediaBox, lowerBox]
                newBoxes.replaceSubrange(pos.index...pos.index, with: replacement)
            } else if pos.local == 0 {
                newBoxes.insert(mediaBox, at: pos.index)        // before the caret's block
            } else {
                newBoxes.insert(mediaBox, at: pos.index + 1)    // after the caret's block
            }
            boxes = newBoxes
            recomputeSpans()
            anchor = mediaBox.textStart; head = mediaBox.textStart
        }
    }

    /// Inserts a new body paragraph immediately before the (top-level) image box at `index`, containing
    /// `text` (empty for a bare newline). Caret lands at the end of the inserted text in the new
    /// paragraph. Mirrors `insertMedia`'s block-insert. Caller wraps this in `editing { … }`.
    func insertParagraphBeforeImage(at index: Int, text: String) {
        guard boxes.indices.contains(index) else { return }
        let runs = text.isEmpty ? [] : [TextRun(text: text)]
        let newBox = BlockBox(paragraph: ParagraphBlock(id: BlockID.generate(), runs: runs),
                              mapper: mapper, width: effectiveWidth)
        var newBoxes = boxes
        newBoxes.insert(newBox, at: index)
        boxes = newBoxes
        recomputeSpans()
        let caret = newBox.textStart + (text as NSString).length
        anchor = caret; head = caret
    }

    /// Inserts an empty body paragraph at `insertIndex` (shifting later boxes down), placing the caret in
    /// it. The escape hatch for a quote (tap below it / Shift+Return) — there is otherwise no way to start
    /// a normal paragraph adjacent to a quote at the document's edge. Undoable.
    func insertEmptyBodyParagraph(at insertIndex: Int) {
        guard insertIndex >= 0, insertIndex <= boxes.count else { return }
        editing {
            let newBox = BlockBox(paragraph: ParagraphBlock(id: BlockID.generate(), style: .body, runs: []),
                                  mapper: mapper, width: effectiveWidth)
            var newBoxes = boxes
            newBoxes.insert(newBox, at: insertIndex)
            boxes = newBoxes
            recomputeSpans()
            anchor = newBox.textStart; head = newBox.textStart
        }
    }

    /// True when the caret at `local` sits on the FIRST visual (wrapped) line of `box` — i.e. its caret
    /// shares the y of offset 0. Drives Shift+Return's exit direction out of a quote.
    func caretIsOnFirstLine(of box: BlockBox, atLocal local: Int) -> Bool {
        let firstY = box.textLayout.caretRect(atOffset: 0).minY
        return abs(box.textLayout.caretRect(atOffset: local).minY - firstY) < 1
    }

    /// Shift+Return EXITS a quote with a new empty body paragraph (caret there): ABOVE the quote when the
    /// caret is on its first visual line, else BELOW it. Outside a quote it falls back to a normal
    /// paragraph break (like Return). Undoable.
    func performShiftReturn() {
        guard selFrom == selTo, let pos = resolveBox(at: head), let p = pos.box as? BlockBox, p.style == .quote else {
            insertParagraphBreak()
            return
        }
        insertEmptyBodyParagraph(at: caretIsOnFirstLine(of: p, atLocal: pos.local) ? pos.index : pos.index + 1)
    }

    /// In-place text replace within the leaf region's layout (used for typing inside cells, and as
    /// the same-leaf fast path generally). Recomputes spans. Caller wraps in `editing { }`.
    func applyLeafReplace(globalFrom: Int, globalTo: Int, text: String) {
        guard let (region, _) = leafRegion(containingGlobal: clampGlobal(min(globalFrom, globalTo))) else { return }
        let lo = clampGlobal(min(globalFrom, globalTo)) - region.globalStart
        let hi = min(clampGlobal(max(globalFrom, globalTo)) - region.globalStart, region.length)
        guard lo >= 0, hi >= lo else { return }
        let attrs = typingAttributeDict(region: region, atLocal: lo)
        region.layout.replace(start: lo, end: hi, with: NSAttributedString(string: text, attributes: attrs))
        recomputeSpans()
        let caret = region.globalStart + lo + (text as NSString).length
        anchor = caret; head = caret
    }

    /// Structure-preserving clear of a selection that crosses `BlockStack` boundaries (cross-cell,
    /// cell↔body, cross-table). Clears the covered text in EVERY touched leaf region (paragraph or
    /// image caption), and lands any replacement `text` in the region owning **selFrom** (its kept
    /// prefix + text), exactly as a single-region replace would. Never removes a box, cell, row, or the
    /// grid — a fully-covered cell keeps an empty paragraph; a covered image keeps its atom (only its
    /// caption clears). One `recomputeSpans()`; caret always collapses to selFrom (+ text length), even
    /// when the selection covered only empty regions (so a keystroke is never lost / the selection never
    /// sticks). Mirrors `selectionRects` so what clears == what was highlighted. Caller wraps in `editing { … }`.
    func applyMultiRegionClear(globalFrom: Int, globalTo: Int, text: String) {
        let lo = clampGlobal(min(globalFrom, globalTo))
        let hi = clampGlobal(max(globalFrom, globalTo))
        guard lo < hi else { return }
        // The region owning selFrom is where replacement text lands (it may be empty, hence not in
        // `touched`). Capture its attrs before any clearing mutates it.
        let anchorRegion = leafRegion(containingGlobal: lo)
        let insertAttrs = anchorRegion.map { typingAttributeDict(region: $0.region, atLocal: $0.local) } ?? [:]
        let touched: [(region: LeafTextRegion, rLo: Int, rHi: Int)] = allLeafRegions().compactMap { r in
            let a = max(lo, r.globalStart), b = min(hi, r.globalStart + r.length)
            guard a < b else { return nil }
            return (r, a - r.globalStart, b - r.globalStart)
        }
        var insertedIntoAnchor = false
        for t in touched {
            let isAnchor = (anchorRegion?.region.layout) === t.region.layout
            let s = isAnchor ? text : ""
            let attrs: [NSAttributedString.Key: Any] = isAnchor ? insertAttrs : [:]
            t.region.layout.replace(start: t.rLo, end: t.rHi, with: NSAttributedString(string: s, attributes: attrs))
            if isAnchor { insertedIntoAnchor = true }
        }
        // The selFrom region had no covered text (e.g. an empty start cell), so it wasn't cleared
        // above — insert `text` there directly so the keystroke isn't lost.
        if !insertedIntoAnchor, !text.isEmpty, let a = anchorRegion {
            a.region.layout.replace(start: a.local, end: a.local,
                                    with: NSAttributedString(string: text, attributes: insertAttrs))
        }
        recomputeSpans()
        // selFrom's region start is unaffected by the edit (nothing before lo changed), so this is
        // valid post-recompute. With no owning region (range in a structural gap), just collapse to lo.
        let caret = anchorRegion.map { $0.region.globalStart + $0.local + (text as NSString).length } ?? clampGlobal(lo)
        anchor = caret; head = caret
    }

    /// True if `pos` is inside a table (its owning top-level box is a `TableBlockBox`).
    func isInsideTable(_ pos: Int) -> Bool {
        for box in boxes where box is TableBlockBox {
            for r in box.leafRegions() where pos >= r.globalStart && pos <= r.globalStart + r.length { return true }
        }
        return false
    }
}
#endif
