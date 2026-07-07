#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// A whole-row or whole-column structural selection within a table — a contiguous, ≥1-wide range.
@available(iOS 13.0, *)
enum TableStructuralSelection: Equatable { case rows(ClosedRange<Int>); case columns(ClosedRange<Int>) }

/// What a tap on a table handle does: select its row/column, or — if that one is already selected —
/// open the context menu.
@available(iOS 13.0, *)
enum TableHandleTap: Equatable { case select(TableStructuralSelection); case menu }

/// Which end of a structural range a resize knob moves: the lower bound (left/top) or upper (right/bottom).
@available(iOS 13.0, *)
enum TableRangeEnd: Equatable { case lower, upper }

@available(iOS 13.0, *)
extension DocumentCanvasView {
    /// Hit/draw rects for the row (left gutter) and column (below table) handles. Draw and hit-test share
    /// these rects, so the visible-band clip in `drawTableChrome` is draw-only — a scrolled-off handle is
    /// simply off-screen and unreachable by touch.
    /// The two handles for the caret's current cell in its table: a vertical ⋮ row handle in the left
    /// gutter, and a horizontal ••• column handle just below the table bottom (matching the reference).
    /// Empty when the caret isn't in a table. `rect` is the hit/draw rect in canvas coordinates.
    func tableHandles() -> [(rect: CGRect, kind: TableStructuralSelection)] {
        guard let a = activeTable() else { return [] }
        let b = TableBlockBox.border
        // The grip spans the active structural RANGE when one is selected, else the caret's single cell.
        let rowRange = structuralRowRange() ?? (a.row...a.row)
        let colRange = structuralColumnRange() ?? (a.col...a.col)
        var out: [(rect: CGRect, kind: TableStructuralSelection)] = []
        if let top = a.box.cellRect(row: rowRange.lowerBound, column: 0),
           let bot = a.box.cellRect(row: rowRange.upperBound, column: 0) {
            let y = top.minY - b
            // The row grip sits in the LEFT gutter, its right edge tucking `gripTuck` under the table's left
            // border, so it's ALWAYS drawn to the LEFT of the table — even with a zero page margin (the chat
            // composer), where it draws into the field's left padding rather than over the first column. Anchored
            // to the table's (unscrolled) left edge, this is x==1 for the full-page editor's 16pt page margin
            // (unchanged) and negative for the composer. (Was a fixed x:1, which assumed a page-margin gutter and
            // landed inside the table when there was none.)
            let gripWidth: CGFloat = 17, gripTuck: CGFloat = 2
            let x = a.box.frame.minX + gripTuck - gripWidth
            out.append((CGRect(x: x, y: y, width: gripWidth, height: bot.maxY + b - y), .rows(rowRange)))
        }
        if let lo = a.box.cellRect(row: 0, column: colRange.lowerBound),
           let hi = a.box.cellRect(row: 0, column: colRange.upperBound) {
            let off = a.box.contentOffsetX
            let tableBottom = (a.box.cellRect(row: a.box.rowCount - 1, column: colRange.lowerBound)?.maxY ?? a.box.frame.maxY) + b
            let width = hi.maxX + b - (lo.minX - b)   // unscrolled span
            out.append((CGRect(x: lo.minX - b - off, y: tableBottom, width: width, height: 17), .columns(colRange)))
        }
        return out
    }

    /// The handle hit by `point`, or nil.
    func tableHandle(at point: CGPoint) -> TableStructuralSelection? {
        for h in tableHandles() where h.rect.contains(point) {
            return h.kind
        }
        return nil
    }

    /// The two resize knobs (◇) at the structural selection's ends, in canvas coordinates. Column
    /// selection → left/right edges (vertically centered); row selection → top/bottom edges
    /// (horizontally centered). `rect` is a generous square hit/anchor rect centered on the knob.
    /// Empty when there is no structural selection.
    func tableResizeKnobs() -> [(rect: CGRect, end: TableRangeEnd)] {
        guard let sel = tableSelection, let outline = tableSelectionOutlineRect() else { return [] }
        let hit: CGFloat = 44
        func box(_ center: CGPoint) -> CGRect {
            CGRect(x: center.x - hit / 2, y: center.y - hit / 2, width: hit, height: hit)
        }
        switch sel.kind {
        case .columns:
            let y = outline.midY
            return [(box(CGPoint(x: outline.minX, y: y)), .lower),
                    (box(CGPoint(x: outline.maxX, y: y)), .upper)]
        case .rows:
            let x = outline.midX
            return [(box(CGPoint(x: x, y: outline.minY)), .lower),
                    (box(CGPoint(x: x, y: outline.maxY)), .upper)]
        }
    }

    /// Which resize knob (if any) `point` hits.
    func tableResizeKnob(at point: CGPoint) -> TableRangeEnd? {
        tableResizeKnobs().first { $0.rect.contains(point) }?.end
    }

    /// Draws the two resize knobs as plain accent-colored filled circles (diameter 8, no inner dot),
    /// centered on each knob's hit rect. Calibrated against ReferenceDesign/TexEditor_8.
    func drawTableResizeKnobs(in ctx: CGContext) {
        let radius: CGFloat = 4
        for knob in tableResizeKnobs() {
            let c = CGPoint(x: knob.rect.midX, y: knob.rect.midY)
            let circle = CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2)
            self.mapper.theme.accent.setFill(); UIBezierPath(ovalIn: circle).fill()
        }
    }

    /// Outcome of a tap on `point`: select the hit handle's row/column, or open the menu when that
    /// row/column is already the structural selection. nil if the point isn't on a handle.
    func tableHandleTap(at point: CGPoint) -> TableHandleTap? {
        guard let hit = tableHandle(at: point) else { return nil }
        return tableSelection?.kind == hit ? .menu : .select(hit)
    }

    /// Selects the row range `range` (single-row tap → `r...r`); parks the caret in the range's first
    /// cell so the structural commands resolve to it. The structural selection bypasses the text caret.
    func selectTableRows(_ range: ClosedRange<Int>) {
        finalizeMarkedText()   // deliberate selection change finalizes marked text (uniform invariant)
        clearImageSelection()  // structural selections are mutually exclusive
        guard let a = activeTable(), let pos = a.box.cellTextStart(row: range.lowerBound, column: 0) else { return }
        // Bracket the caret move (like setCaret/selectImage) so the OS re-reads selectedTextRange = the parked
        // cell; without it a hardware Arrow navigates from the STALE prior caret instead of the selected row.
        textInputDelegate?.selectionWillChange(self)
        anchor = pos; head = pos
        textInputDelegate?.selectionDidChange(self)
        tableSelection = (a.box.id, .rows(range))
        refreshSelectionUI(); setNeedsDisplay()
    }

    func selectTableColumns(_ range: ClosedRange<Int>) {
        finalizeMarkedText()   // deliberate selection change finalizes marked text (uniform invariant)
        clearImageSelection()  // structural selections are mutually exclusive
        guard let a = activeTable(), let pos = a.box.cellTextStart(row: 0, column: range.lowerBound) else { return }
        textInputDelegate?.selectionWillChange(self)   // see selectTableRows: keep the OS's selectedTextRange in sync
        anchor = pos; head = pos
        textInputDelegate?.selectionDidChange(self)
        tableSelection = (a.box.id, .columns(range))
        refreshSelectionUI(); setNeedsDisplay()
    }

    /// Convenience: select a single row / column (the 6d entry points; demo + tests use these).
    func selectTableRow(_ r: Int) { selectTableRows(r...r) }
    func selectTableColumn(_ c: Int) { selectTableColumns(c...c) }

    /// All leaf text regions inside the currently structurally-selected table row or column range, or nil if
    /// there is no structural table selection. Lets a character-format command apply to the whole
    /// row/column (every cell's text) instead of the collapsed caret it parks in.
    func tableStructuralSelectionRegions() -> [LeafTextRegion]? {
        guard let sel = tableSelection,
              let box = boxes.compactMap({ $0 as? TableBlockBox }).first(where: { $0.id == sel.table }) else { return nil }
        switch sel.kind {
        case .rows(let range):
            return range.filter { box.cells.indices.contains($0) }.flatMap { box.cells[$0].flatMap { $0.leafRegions() } }
        case .columns(let range):
            return box.cells.flatMap { row in range.compactMap { row.indices.contains($0) ? row[$0] : nil } }
                            .flatMap { $0.leafRegions() }
        }
    }

    func clearTableSelection() {
        guard tableSelection != nil else { return }
        tableSelection = nil
        refreshSelectionUI(); setNeedsDisplay()
    }

    /// The selected row range, when a row structural selection is active (else nil → commands use the caret row).
    func structuralRowRange() -> ClosedRange<Int>? {
        if let s = tableSelection, case .rows(let r) = s.kind { return r }
        return nil
    }
    /// The selected column range, when a column structural selection is active.
    func structuralColumnRange() -> ClosedRange<Int>? {
        if let s = tableSelection, case .columns(let c) = s.kind { return c }
        return nil
    }

    /// The selected row/column range's bounding rect, expanded by the border so its outer edge is flush
    /// with the table's outer border (cells are inset from the grid by `border`). nil if nothing is selected.
    func tableSelectionOutlineRect() -> CGRect? {
        guard let sel = tableSelection, let a = activeTable(), a.box.id == sel.table else { return nil }
        let rect: CGRect
        switch sel.kind {
        case .rows(let range):
            guard let lo = a.box.cellRect(row: range.lowerBound, column: 0),
                  let hi = a.box.cellRect(row: range.upperBound, column: a.box.columnCount - 1) else { return nil }
            rect = lo.union(hi)
        case .columns(let range):
            guard let lo = a.box.cellRect(row: 0, column: range.lowerBound),
                  let hi = a.box.cellRect(row: a.box.rowCount - 1, column: range.upperBound) else { return nil }
            rect = lo.union(hi)
        }
        return rect.insetBy(dx: -TableBlockBox.border, dy: -TableBlockBox.border)
            .offsetBy(dx: -a.box.contentOffsetX, dy: 0)
    }

    /// Which corners of the selection outline round to match the table's rounded OUTER corners. Interior
    /// corners stay square; so do the corners ADJACENT to the selection handle (the handle bar abuts the
    /// outline there with a square edge). Empty = a fully-square selection.
    func tableSelectionOutlineCorners() -> UIRectCorner {
        guard let sel = tableSelection, let a = activeTable(), a.box.id == sel.table else { return [] }
        var corners: UIRectCorner = []
        switch sel.kind {
        case .columns(let range):
            // Column grip sits at the BOTTOM → bottom corners square; round the top corners where the
            // range reaches the table's rounded outer corners.
            if range.lowerBound == 0 { corners.insert(.topLeft) }
            if range.upperBound == a.box.columnCount - 1 { corners.insert(.topRight) }
        case .rows(let range):
            // Row grip sits at the LEFT → left corners square; round the right corners.
            if range.lowerBound == 0 { corners.insert(.topRight) }
            if range.upperBound == a.box.rowCount - 1 { corners.insert(.bottomRight) }
        }
        return corners
    }

    /// Draws the table structural chrome (outline + handles + resize knobs). Called by the chrome overlay
    /// (which sits above the block views) instead of from the canvas's own `draw(_:)`.
    func drawTableChrome(in ctx: CGContext) {
        guard let a = activeTable() else { drawTableChromeLayers(in: ctx); return }
        ctx.saveGState()
        // Clip to the table's visible horizontal band (full height). Extend LEFT past x=0 so the left-gutter row
        // grip stays visible even when it sits at a NEGATIVE x — the composer's zero page margin draws it into
        // the field's left padding (the canvas/scroll/editor are all clipsToBounds=false, so the field's own
        // background is the real left bound). The right edge still clips chrome for scrolled-off columns.
        let leftGutter: CGFloat = 30
        ctx.clip(to: CGRect(x: -leftGutter, y: 0, width: a.box.blockViewFrame.maxX + leftGutter, height: bounds.height))
        drawTableChromeLayers(in: ctx)
        ctx.restoreGState()
    }

    private func drawTableChromeLayers(in ctx: CGContext) {
        drawTableSelectionOutline(in: ctx)
        drawTableHandles(in: ctx)
        drawTableResizeKnobs(in: ctx)
    }

    func drawTableSelectionOutline(in ctx: CGContext) {
        guard let outer = tableSelectionOutlineRect() else { return }
        let lineWidth: CGFloat = 2
        // CG centers a stroke on its path, so inset by half the line width to keep the stroke's OUTER
        // edge flush with the table's outer border (the rect that `tableSelectionOutlineRect` aligns to).
        let rect = outer.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
        // Round only the corners meeting the table's rounded outer border (concentric: table radius −
        // the half-line-width inset); interior corners stay square. accent — from TexEditor_8.
        let corners = tableSelectionOutlineCorners()
        let r = max(TableBlockBox.outerCornerRadius - lineWidth / 2, 0)
        let path = corners.isEmpty
            ? UIBezierPath(rect: rect)
            : UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: r, height: r))
        self.mapper.theme.accent.setStroke(); path.lineWidth = lineWidth; path.stroke()
    }

    // tableHandles() returns the handles for the caret's cell; the one matching tableSelection.kind is tinted with the accent color.
    // Row handle = vertical ⋮ (left gutter); column handle = horizontal ••• (below the table).
    func drawTableHandles(in ctx: CGContext) {
        for h in tableHandles() {
            let active = tableSelection?.kind == h.kind
            let horizontal: Bool
            if case .columns = h.kind { horizontal = true } else { horizontal = false }
            drawHandleDots(in: h.rect, active: active, horizontal: horizontal)
        }
    }

    /// Three dots centered in `rect` — along x when `horizontal` (column ⋯), else along y (row ⋮).
    /// When `active` (its row/column is selected) the dots sit on an accent-colored rounded pill and turn
    /// `systemBackground` (white in light) — matching the reference's highlighted handle.
    private func drawHandleDots(in rect: CGRect, active: Bool, horizontal: Bool) {
        if active {
            // accent bar spanning the whole selection (rect = column width / row height), rounded ends
            self.mapper.theme.accent.setFill()
            if horizontal {
                UIBezierPath(roundedRect: rect, byRoundingCorners: [.bottomLeft, .bottomRight], cornerRadii: CGSize(width: min(rect.width, rect.height), height: min(rect.width, rect.height))).fill()
            } else {
                UIBezierPath(roundedRect: rect, byRoundingCorners: [.topLeft, .bottomLeft], cornerRadii: CGSize(width: min(rect.width, rect.height), height: min(rect.width, rect.height))).fill()
            }
        }
        (active ? UIColor.systemBackground : .secondaryLabel).setFill()
        let d: CGFloat = 4, gap: CGFloat = 3
        let cx = rect.midX, cy = rect.midY
        for i in -1...1 {
            let off = CGFloat(i) * (d + gap)
            let x = horizontal ? cx + off : cx
            let y = horizontal ? cy : cy + off
            UIBezierPath(ovalIn: CGRect(x: x - d / 2, y: y - d / 2, width: d, height: d)).fill()
        }
    }

    /// The standard structural-action handler: run a structural command, then clear the selection.
    private func structuralPerform(_ run: @escaping (DocumentCanvasView) -> Void) -> () -> Void {
        { [weak self] in guard let self else { return }; run(self); self.clearTableSelection() }
    }

    /// The structural row/column menu, described for the host to present its own menu. nil when there is
    /// no structural selection. `view`/`sourceRect` anchor to the active handle, in canvas coordinates.
    func tableStructuralMenuRequest() -> TableStructuralMenuRequest? {
        guard let sel = tableSelection, let a = activeTable(), a.box.id == sel.table else { return nil }
        let sourceRect = tableHandles().first { $0.kind == sel.kind }?.rect ?? .zero
        switch sel.kind {
        case .columns(let range):
            var actions: [TableStructuralMenuRequest.Action] = [
                .init(kind: .addColumnLeft, perform: structuralPerform { $0.insertTableColumnLeft() }),
                .init(kind: .addColumnRight, perform: structuralPerform { $0.insertTableColumnRight() }),
            ]
            // Hide Delete when the range covers every column (deleting all would empty the table).
            let coversAll = range.lowerBound == 0 && range.upperBound == a.box.columnCount - 1
            if !coversAll {
                actions.append(.init(kind: .deleteColumn, perform: structuralPerform { $0.deleteTableColumn() }))
            }
            let current = a.box.columns.indices.contains(range.lowerBound) ? a.box.columns[range.lowerBound].alignment : nil
            let alignment = TableStructuralMenuRequest.Alignment(
                options: [.left, .center, .right],
                current: current,
                select: { [weak self] al in guard let self else { return }; self.setTableColumnAlignment(al); self.clearTableSelection() })
            return TableStructuralMenuRequest(view: self, sourceRect: sourceRect, actions: actions, alignment: alignment)
        case .rows(let range):
            let includesHeader = range.contains { a.box.isHeaderRow($0) }
            let hasBodyRow = range.contains { a.box.cells.indices.contains($0) && !a.box.isHeaderRow($0) }
            var actions: [TableStructuralMenuRequest.Action] = []
            if !includesHeader {                       // can't insert above the header
                actions.append(.init(kind: .addRowAbove, perform: structuralPerform { $0.insertTableRowAbove() }))
            }
            actions.append(.init(kind: .addRowBelow, perform: structuralPerform { $0.insertTableRowBelow() }))
            if hasBodyRow {                             // at least one deletable (non-header) row
                actions.append(.init(kind: .deleteRow, perform: structuralPerform { $0.deleteTableRow() }))
            }
            return TableStructuralMenuRequest(view: self, sourceRect: sourceRect, actions: actions, alignment: nil)
        }
    }

    /// Moves the structural selection's `end` knob to the row/column under `point`, keeping the other
    /// end fixed. The dragged end cannot cross the fixed end (minimum range width 1; no swap); both are
    /// bounded to the grid. Live (`setNeedsDisplay`) for outline/knob/bar feedback.
    func extendTableSelection(end: TableRangeEnd, toward point: CGPoint) {
        guard let sel = tableSelection,
              let box = boxes.compactMap({ $0 as? TableBlockBox }).first(where: { $0.id == sel.table }) else { return }
        switch sel.kind {
        case .rows(let range):
            if end == .upper {
                let fixed = range.lowerBound
                let moved = max(min(box.rowIndex(atY: point.y), box.rowCount - 1), fixed)
                tableSelection = (sel.table, .rows(fixed...moved))
            } else {
                let fixed = range.upperBound
                let moved = min(max(box.rowIndex(atY: point.y), 0), fixed)
                tableSelection = (sel.table, .rows(moved...fixed))
            }
        case .columns(let range):
            let x = point.x + box.contentOffsetX
            if end == .upper {
                let fixed = range.lowerBound
                let moved = max(min(box.columnIndex(atX: x), box.columnCount - 1), fixed)
                tableSelection = (sel.table, .columns(fixed...moved))
            } else {
                let fixed = range.upperBound
                let moved = min(max(box.columnIndex(atX: x), 0), fixed)
                tableSelection = (sel.table, .columns(moved...fixed))
            }
        }
        setNeedsDisplay()
    }

    /// Demo helper: place the caret in the first table's (0,0) cell and select column 0 (shows handles + outline).
    func selectFirstTableColumn() {
        guard let t = boxes.compactMap({ $0 as? TableBlockBox }).first,
              let pos = t.cellTextStart(row: 0, column: 0) else { return }
        anchor = pos; head = pos
        selectTableColumn(0)
    }
}
#endif
