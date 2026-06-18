#if canImport(UIKit)
import UIKit

@available(iOS 17.0, *)
extension DocumentCanvasView {
    /// Next text position to the right: within the current leaf region, or to the next region's
    /// start — except when an image gap sits before that region (then stop at the gap). Handles
    /// paragraphs, image captions, and table cells uniformly (regions are in document order).
    func nextTextPosition(after pos: Int) -> Int {
        let regions = allLeafRegions()
        if let i = regions.firstIndex(where: { pos >= $0.globalStart && pos <= $0.globalStart + $0.length }) {
            if pos < regions[i].globalStart + regions[i].length { return pos + 1 }
            guard i + 1 < regions.count else { return pos }
            let nextStart = regions[i + 1].globalStart
            let gap = nextStart - 2
            return isGapPosition(gap) ? gap : nextStart
        }
        if let img = imageBox(atGap: pos) { return img.textStart }   // on a gap → into the caption
        return min(pos + 1, documentSize)
    }

    /// Previous text position to the left: within the current region, or to the previous region's
    /// end — except when the current region is an image caption (stop at the gap before the image).
    func prevTextPosition(before pos: Int) -> Int {
        let regions = allLeafRegions()
        if let i = regions.firstIndex(where: { pos >= $0.globalStart && pos <= $0.globalStart + $0.length }) {
            if pos > regions[i].globalStart { return pos - 1 }
            let gap = regions[i].globalStart - 2
            if isGapPosition(gap) { return gap }
            if i > 0 { return regions[i - 1].globalStart + regions[i - 1].length }
            return pos
        }
        if let img = imageBox(atGap: pos) {   // on a gap → previous block's text end, or doc start
            if let idx = boxIndex(of: img), idx > 0 { return boxes[idx - 1].textStart + boxes[idx - 1].textLength }
            return 0
        }
        return max(pos - 1, 0)
    }

    /// The table whose CELL TEXT contains `pos` (via `cellLocation`); nil for a structural token slot
    /// between cells. Distinct from `tableBox(containingGlobal:)` (node-span based — see DocumentCanvasView).
    private func tableBox(containing pos: Int) -> TableBlockBox? {
        boxes.first { ($0 as? TableBlockBox)?.cellLocation(containing: pos) != nil } as? TableBlockBox
    }

    /// A position the caret can actually occupy and be drawn at: inside a leaf text region (incl. its
    /// trailing slot) or on an image gap. Structural token slots (block/table/row/cell open-close) are
    /// NOT renderable — a caret there is invisible.
    func isRenderablePosition(_ pos: Int) -> Bool {
        leafRegion(containingGlobal: pos) != nil || isGapPosition(pos)
    }

    /// Snaps an arbitrary (possibly structural) global offset onto the nearest renderable caret slot,
    /// biased by the direction of motion (`forward` → the next renderable at/after `pos`, else the
    /// previous at/before). A no-op on positions that are already renderable. This enforces the
    /// caret-renderable invariant for the system tokenizer's stepping primitive (`position(from:offset:)`),
    /// which otherwise walks the global axis onto non-renderable structural slots (e.g. Option+Arrow word
    /// nav parking the caret on a paragraph's close-token slot at the document end).
    func snapToRenderable(_ pos: Int, forward: Bool) -> Int {
        let p = clampGlobal(pos)
        if isRenderablePosition(p) { return p }
        // Candidate renderable slots: each leaf region's start and end, plus each image gap.
        var candidates: [Int] = []
        for r in allLeafRegions() { candidates.append(r.globalStart); candidates.append(r.globalStart + r.length) }
        for box in boxes where box is ImageBlockBox { candidates.append(box.nodeStart) }
        guard !candidates.isEmpty else { return p }
        let atOrAfter = candidates.filter { $0 >= p }.min()
        let atOrBefore = candidates.filter { $0 <= p }.max()
        return forward ? (atOrAfter ?? atOrBefore ?? p) : (atOrBefore ?? atOrAfter ?? p)
    }

    /// The first caret position in the block immediately AFTER `table` (where Tab exits the table to),
    /// or nil when the table is the document's last block. A paragraph → its text start; an image → the
    /// gap before it (the GapCursor); a following table → its first cell.
    private func positionAfterTable(_ table: TableBlockBox) -> Int? {
        guard let idx = boxIndex(of: table), idx + 1 < boxes.count else { return nil }
        let next = boxes[idx + 1]
        if let t = next as? TableBlockBox { return t.cellTextStart(row: 0, column: 0) }
        if next is ImageBlockBox { return next.nodeStart }
        return next.textStart
    }

    /// Vertical movement by geometry: from the current leaf region's caret rect, step one line up/down
    /// at the same x, then snap to the closest global position. `closestGlobalPosition` recurses into
    /// table cells (via `TableBlockBox.closestPosition`), so Up/Down always lands in a real text region
    /// — never a structural gap such as a table's degenerate node start.
    /// The renderable caret slot a caret lands on when entering `box` from BELOW (i.e. arrowing UP into it):
    /// a table → its LAST row's cell in `preferColumn` (NOT the table's degenerate node boundary —
    /// `textLength == 0` — which `snapToRenderable(forward:false)` would otherwise walk straight past, skipping
    /// the table to the block before it); an image → its gap; a paragraph/caption → the end of its text. Always
    /// renderable. `preferColumn` (clamped to the table's columns) preserves the source caret's column so Up
    /// into a table lands under it, like ordinary geometric vertical nav — see the gap-branch caller.
    private func entryPositionBottom(of box: CanvasBlock, preferColumn: Int = 0) -> Int {
        if let t = box as? TableBlockBox {
            let col = min(max(preferColumn, 0), max(t.columnCount - 1, 0))
            return t.cellTextStart(row: t.rowCount - 1, column: col) ?? box.textStart + box.textLength
        }
        if box is ImageBlockBox { return box.nodeStart }
        return box.textStart + box.textLength
    }

    func verticalPosition(from pos: Int, down: Bool) -> Int {
        // An image gap (before the atom) owns no text region, so the geometric path below would stall
        // (it used to return `pos`, stranding the caret on the gap). Step to the STRUCTURAL neighbour,
        // which is guaranteed renderable (and visible): Up → the end of the block above the image, Down →
        // the caption start. A geometric probe here is unsafe — the point just above/below the image can
        // land in a non-renderable inter-block slot, which `closestGlobalPosition` may resolve to a
        // structural position, hiding the caret (the reported "Up hides the caret" bug).
        if let img = imageBox(atGap: pos), let idx = boxIndex(of: img) {
            if down { return nextTextPosition(after: pos) }   // → caption start
            guard idx > 0 else { return pos }                 // leading image → nothing above to move to
            let above = boxes[idx - 1]
            // Into a table above, land under WHERE THE GAP CARET IS DRAWN: `caretRect` draws the gap bar at
            // `imageRect().minX` (the image's leading edge), so map that same x (folding in any horizontal
            // scroll) → a column. For a full-bleed image the leading edge is the page's left, i.e. column 0;
            // an aligned/narrow image follows the caret. Pure arithmetic over cached widths — no layout/async
            // dependency (does not reintroduce the determinism issue the scroll fix solved).
            let col = (above as? TableBlockBox).map { $0.columnIndex(atX: img.imageRect().minX + $0.contentOffsetX) } ?? 0
            return entryPositionBottom(of: above, preferColumn: col)   // table → LAST row @col; image → gap; paragraph → end
        }
        guard let (region, local) = leafRegion(containingGlobal: pos) else { return pos }
        let caret = region.layout.caretRect(atOffset: local).offsetBy(dx: region.canvasOrigin.x, dy: region.canvasOrigin.y)
        let off = tableContentOffsetX(forGlobal: pos)   // unscrolled caret.midX -> visible x for top-level hit-tests
        let step = max(caret.height, 16)
        let targetY = down ? caret.maxY + step / 2 : caret.minY - step / 2
        let snapped = closestGlobalPosition(to: CGPoint(x: caret.midX - off, y: targetY))

        // Inside a table cell: stay within the cell while it has more lines; at the cell's edge line,
        // move to the same-column neighbor cell (row above for Up / below for Down) if one exists; only
        // escape past the whole table when already in the edge row (no neighbor cell that direction).
        if let table = tableBox(containing: pos), let loc = table.cellLocation(containing: pos) {
            if snapped != pos, let snapLoc = table.cellLocation(containing: snapped), snapLoc == loc {
                return snapped   // moved to another line within the same cell
            }
            let neighborRow = down ? loc.row + 1 : loc.row - 1
            if neighborRow >= 0, neighborRow < table.rowCount, let rect = table.cellRect(row: neighborRow, column: loc.column) {
                // Land on the neighbor cell's edge line nearest the current cell, at the same x.
                let edgeY = down ? rect.minY + min(step / 2, rect.height / 2) : rect.maxY - min(step / 2, rect.height / 2)
                return table.cells[neighborRow][loc.column].closestPosition(toCanvasPoint: CGPoint(x: caret.midX, y: edgeY))
            }
            // Edge row → escape past the whole table into the block above/below.
            let escapeY = down ? table.frame.maxY + step / 2 : table.frame.minY - step / 2
            let escaped = closestGlobalPosition(to: CGPoint(x: caret.midX - off, y: escapeY))
            return escaped != pos ? escaped : snapped
        }

        // Top-level: the geometric snap can stall (e.g. just above a table, the one-line step re-snaps
        // to the same paragraph). On no progress, push the target just past the owning top-level box and
        // re-snap so the caret escapes over an adjacent table.
        if let (snapRegion, _) = leafRegion(containingGlobal: snapped),
           snapRegion.globalStart == region.globalStart, snapped == pos,
           let owner = boxes.first(where: { caret.midY >= $0.frame.minY && caret.midY < $0.frame.maxY }) {
            let escapeY = down ? owner.frame.maxY + step / 2 : owner.frame.minY - step / 2
            let escaped = closestGlobalPosition(to: CGPoint(x: caret.midX - off, y: escapeY))
            if escaped != pos { return escaped }
        }
        return snapped
    }

    func position(from position: UITextPosition, in direction: UITextLayoutDirection, offset: Int) -> UITextPosition? {
        guard let p = position as? DocumentTextPosition else { return nil }
        var pos = p.offset
        switch direction {
        case .right: for _ in 0..<offset { pos = nextTextPosition(after: pos) }
        case .left:  for _ in 0..<offset { pos = prevTextPosition(before: pos) }
        case .down:  for _ in 0..<offset { pos = verticalPosition(from: pos, down: true) }
        case .up:    for _ in 0..<offset { pos = verticalPosition(from: pos, down: false) }
        @unknown default: break
        }
        // Defense-in-depth for VERTICAL moves: the caret must land on a renderable slot, else it vanishes.
        // The gap step helper already returns renderable positions, so this is a no-op for it — it guards a
        // future vertical result drifting onto a structural slot. Horizontal moves keep their exact existing
        // behaviour (e.g. Left from a leading image's gap intentionally returns doc start = a non-renderable 0).
        if direction == .up || direction == .down { pos = snapToRenderable(pos, forward: direction == .down) }
        return DocumentTextPosition(pos)
    }

    /// Tab/Shift-Tab: move the caret to the next/previous cell. Tab in the last cell exits to the start
    /// of the block after the table (no-op if the table is the document's last block); Shift-Tab in the
    /// first cell is a no-op. Outside a table, no-op.
    func moveToCell(forward: Bool) {
        guard let table = boxes.first(where: { ($0 as? TableBlockBox)?.cellLocation(containing: head) != nil }) as? TableBlockBox,
              let loc = table.cellLocation(containing: head) else { return }
        let cols = table.columnCount, rows = table.rowCount
        var target: (row: Int, column: Int)?
        if forward {
            if loc.column + 1 < cols { target = (loc.row, loc.column + 1) }
            else if loc.row + 1 < rows { target = (loc.row + 1, 0) }
            else {
                // last cell → exit the table to the start of the block after it. No-op when the table
                // is the document's last block (nothing after to move to).
                if let exit = positionAfterTable(table) { setCaret(global: exit) }
                return
            }
        } else {
            if loc.column > 0 { target = (loc.row, loc.column - 1) }
            else if loc.row > 0 { target = (loc.row - 1, cols - 1) }
            else { return }   // first cell → no-op
        }
        if let t = target, let pos = table.cellTextStart(row: t.row, column: t.column) { setCaret(global: pos) }
    }
}
#endif
