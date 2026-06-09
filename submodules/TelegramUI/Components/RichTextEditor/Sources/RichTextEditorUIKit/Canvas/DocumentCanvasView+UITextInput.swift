#if canImport(UIKit)
import UIKit
import RichTextEditorCore

@available(iOS 17.0, *)
extension DocumentCanvasView: UITextInput {
    private func clamp(_ n: Int) -> Int { clampGlobal(n) }

    func text(in range: UITextRange) -> String? {
        guard let r = range as? DocumentTextRange else { return nil }
        let lo = clamp(min(r.from.offset, r.to.offset)), hi = clamp(max(r.from.offset, r.to.offset))
        var result = ""
        for region in allLeafRegions() {
            let a = max(lo, region.globalStart), b = min(hi, region.globalStart + region.length)
            guard a < b else { continue }
            let attr = region.layout.attributedString
            let ns = attr.string as NSString
            let slice = NSRange(location: a - region.globalStart, length: b - a)
            // Replace each emoji spacer (U+FFFC + EmojiTextAttachment) with its altText (or nothing);
            // copy every other span verbatim. Keeps non-emoji behaviour identical.
            attr.enumerateAttribute(.attachment, in: slice, options: []) { value, sub, _ in
                if let att = value as? EmojiTextAttachment {
                    result += att.ref.altText ?? ""
                } else {
                    result += ns.substring(with: sub)
                }
            }
        }
        return result
    }

    func replace(_ range: UITextRange, withText text: String) {
        guard let r = range as? DocumentTextRange else { return }
        let lo = min(r.from.offset, r.to.offset)
        let hi = max(r.from.offset, r.to.offset)
        // Route through the 3-way selection logic, not applyReplace directly: a system-initiated
        // replacement (autocorrect/dictation/marked-text) can span a table boundary, which the
        // same-stack-guarded applyReplace would silently drop.
        editing { applySelectionReplace(globalFrom: lo, globalTo: hi, text: text) }
    }

    func typingAttributeDict(region: LeafTextRegion, atLocal location: Int) -> [NSAttributedString.Key: Any] {
        let storage = region.layout.attributedString
        if storage.length == 0 {
            // An empty image caption is render-only centered (not in the model), so the next typed
            // character must carry that centered paragraph style explicitly or it would land left-aligned.
            if let img = boxes.compactMap({ $0 as? ImageBlockBox }).first(where: { region.ref == .caption($0.id) }) {
                return img.captionTypingAttributes()
            }
            // Recover the owning paragraph (if any) so an empty styled/listed paragraph keeps its
            // paragraph style on the next typed character — identical to the prior box-based logic.
            let p = boxes.compactMap { $0 as? BlockBox }.first { region.ref == .paragraph($0.id) }
            let style = p?.style ?? .body
            let para = p?.paragraphAttributes ?? .default
            let list = p?.listMembership
            var attrs = mapper.attributes(for: CharacterAttributes(), style: style)
            attrs[.paragraphStyle] = mapper.styleSheet.paragraphStyle(for: style, attributes: para, list: list)
            return attrs
        }
        return storage.attributes(at: min(max(0, location - 1), storage.length - 1), effectiveRange: nil)
    }

    /// Typing attributes for the caret at a global position: the leaf region's attributes, or body
    /// defaults at a structural boundary (no region). Used by the structural-edit engine.
    func typingAttributesAtGlobal(_ pos: Int) -> [NSAttributedString.Key: Any] {
        if let (region, local) = leafRegion(containingGlobal: clamp(pos)) {
            return typingAttributeDict(region: region, atLocal: local)
        }
        return mapper.attributes(for: CharacterAttributes(), style: .body)
    }

    var selectedTextRange: UITextRange? {
        get { DocumentTextRange(DocumentTextPosition(anchor), DocumentTextPosition(head)) }
        set {
            finalizeMarkedText()     // a deliberate selection move commits a composition / dismisses a prediction
            clearStructuralSelections()
            let r = newValue as? DocumentTextRange
            anchor = clamp(r?.from.offset ?? 0); head = clamp(r?.to.offset ?? 0)
            setNeedsDisplay(); refreshSelectionUI()
            onSelectionChange?()     // host scrolls the (possibly off-screen) caret into view — e.g. arrow-key nav up out of a tall image
        }
    }

    var inputDelegate: UITextInputDelegate? {
        get { textInputDelegate }
        set { textInputDelegate = newValue }
    }
    var tokenizer: UITextInputTokenizer {
        if let t = inputTokenizer { return t }
        let t = DocumentTokenizer(canvas: self)
        inputTokenizer = t
        return t
    }

    // The first/last positions the caret can occupy must be RENDERABLE (a leaf region start/end or an
    // image gap), not the document's structural open/close token slots (0 / documentSize) — otherwise
    // "move to start/end of document" would hide the caret.
    var beginningOfDocument: UITextPosition { DocumentTextPosition(snapToRenderable(0, forward: true)) }
    var endOfDocument: UITextPosition { DocumentTextPosition(snapToRenderable(documentSize, forward: false)) }

    // Optional iOS-18 UITextInput member: tells the system the view supports editing so Writing Tools
    // can apply results in place (vs treating content as read-only). Together with our `UIEditMenuInteraction`
    // (the non-UITextInteraction path, WWDC24 #10168), this surfaces the system Writing Tools item on
    // Apple-Intelligence hardware.
    @available(iOS 18.0, *)
    var isEditable: Bool { true }

    func textRange(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> UITextRange? {
        guard let f = fromPosition as? DocumentTextPosition, let t = toPosition as? DocumentTextPosition else { return nil }
        return f.offset <= t.offset ? DocumentTextRange(f, t) : DocumentTextRange(t, f)
    }

    func position(from position: UITextPosition, offset: Int) -> UITextPosition? {
        guard let p = position as? DocumentTextPosition else { return nil }
        let n = p.offset + offset
        guard n >= 0, n <= documentSize else { return nil }
        // The system tokenizer (Option+Arrow word nav, double-tap select, …) steps through positions
        // via this primitive; snap to a renderable slot so it can never park the caret on a structural
        // token (which would be invisible). No-op for positions already renderable.
        return DocumentTextPosition(snapToRenderable(n, forward: offset >= 0))
    }

    func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult {
        let a = (position as? DocumentTextPosition)?.offset ?? 0
        let b = (other as? DocumentTextPosition)?.offset ?? 0
        return a < b ? .orderedAscending : (a > b ? .orderedDescending : .orderedSame)
    }

    func offset(from: UITextPosition, to toPosition: UITextPosition) -> Int {
        ((toPosition as? DocumentTextPosition)?.offset ?? 0) - ((from as? DocumentTextPosition)?.offset ?? 0)
    }

    func position(within range: UITextRange, farthestIn direction: UITextLayoutDirection) -> UITextPosition? {
        guard let r = range as? DocumentTextRange else { return nil }
        return (direction == .left || direction == .up) ? r.start : r.end
    }

    func characterRange(byExtending position: UITextPosition, in direction: UITextLayoutDirection) -> UITextRange? {
        guard let p = position as? DocumentTextPosition else { return nil }
        return (direction == .left || direction == .up)
            ? DocumentTextRange(DocumentTextPosition(0), p)
            : DocumentTextRange(p, DocumentTextPosition(documentSize))
    }

    func baseWritingDirection(for position: UITextPosition, in direction: UITextStorageDirection) -> NSWritingDirection { .leftToRight }
    func setBaseWritingDirection(_ writingDirection: NSWritingDirection, for range: UITextRange) {}

    func firstRect(for range: UITextRange) -> CGRect {
        guard let r = range as? DocumentTextRange else { return .zero }
        return selectionRects(globalFrom: min(r.from.offset, r.to.offset),
                              globalTo: max(r.from.offset, r.to.offset)).first ?? .zero
    }

    func caretRect(for position: UITextPosition) -> CGRect {
        // A structural row/column selection hides the caret entirely (the outline is the indicator).
        // An image atom selection does NOT zero the caret here: `caretRect` must keep reporting the gap
        // geometry so the OS can run arrow-key navigation OUT of a tap-selected image — vertical arrows
        // read the caret's rect to step a line, so a `.zero` rect strands them (the reported "Up does
        // nothing / caret vanishes" bug). The VISIBLE caret is suppressed separately in `updateCaretView`
        // (the image tint is the selection indicator), so no blinking caret shows over a selected image.
        if tableSelection != nil { return .zero }
        guard let p = position as? DocumentTextPosition else { return .zero }
        let pos = clamp(p.offset)
        if let (r, local) = leafRegion(containingGlobal: pos) {
            // `emptyLineLeadingIndent`/`emptyLineHeight` only matter on an empty line, whose caret TextKit
            // would otherwise place at x=0 with a fixed 20pt height (no glyphs to carry the indent/metrics).
            return r.caretRect(atLocal: local)
                .offsetBy(dx: r.canvasOrigin.x + r.emptyLineLeadingIndent - tableContentOffsetX(forGlobal: pos),
                          dy: r.canvasOrigin.y)
        }
        // An image gap is a real caret slot but not a text leaf. Report a vertical bar at the image's
        // leading edge; `updateCaretView` renders the app's own caret there (and this geometry also feeds the
        // loupe / hit-test / edit menu). (This returned .zero before, which is why draw(_:) used to hand-draw
        // a custom GapCursor bar.)
        if let img = imageBox(atGap: pos) {
            let rr = img.imageRect()
            return CGRect(x: rr.minX, y: rr.minY, width: 2, height: rr.height)
        }
        return .zero
    }

    func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        guard let r = range as? DocumentTextRange else { return [] }
        let rects = selectionRects(globalFrom: min(r.from.offset, r.to.offset),
                                   globalTo: max(r.from.offset, r.to.offset))
        return rects.enumerated().map { index, frame in
            DocumentSelectionRect(rect: frame, containsStart: index == 0, containsEnd: index == rects.count - 1)
        }
    }

    func closestPosition(to point: CGPoint) -> UITextPosition? {
        DocumentTextPosition(closestGlobalPosition(to: point))
    }

    func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? {
        guard let p = closestPosition(to: point) as? DocumentTextPosition, let r = range as? DocumentTextRange else { return nil }
        return DocumentTextPosition(min(max(p.offset, r.from.offset), r.to.offset))
    }

    func characterRange(at point: CGPoint) -> UITextRange? {
        guard let p = closestPosition(to: point) as? DocumentTextPosition else { return nil }
        return DocumentTextRange(p, DocumentTextPosition(min(p.offset + 1, documentSize)))
    }
}

@available(iOS 17.0, *)
extension DocumentCanvasView: UIKeyInput {
    var hasText: Bool { documentSize > 0 }

    func insertText(_ text: String) {
        // A committing keystroke while composing: replace the WHOLE marked range with `text`, then
        // finalize the composition as one undo step. (The system delivers a confirming char this way.)
        if let m = markedRange {
            textInputDelegate?.textWillChange(self)
            applyReplace(globalFrom: m.from, globalTo: m.to, text: text)   // in place; caret → end
            textInputDelegate?.textDidChange(self)
            commitMarkedText()
            invalidateIntrinsicContentSize(); setNeedsLayout(); setNeedsDisplay(); refreshSelectionUI()
            onSelectionChange?()   // committing a composition moves the caret — scroll it into view too
            return
        }
        clearStructuralSelections()
        // Caret on an image's gap cursor → open a new body paragraph immediately before the image
        // (Enter inserts an empty one), rather than letting the text fall into the caption. Symmetric
        // to deleteBackward's gap branch below.
        if selFrom == selTo, let img = imageBox(atGap: head), let i = boxIndex(of: img) {
            editing { insertParagraphBeforeImage(at: i, text: text == "\n" ? "" : text) }
            return
        }
        if text == "\n" { insertParagraphBreak(); return }
        if selFrom != selTo {
            editing { applySelectionReplace(globalFrom: selFrom, globalTo: selTo, text: text) }
            return
        }
        // A collapsed caret that resolves to a table box (e.g. before a leading table / after a
        // trailing table) is a structural boundary — snap it into the nearest cell so the edit goes
        // through that cell's stack, never through the table's degenerate textLayout (which would drop
        // the keystroke).
        if !isInsideTable(head), let r = resolveBox(at: head), r.box is TableBlockBox {
            let snapped = caretSnappedIntoCell(head)
            anchor = snapped; head = snapped
        }
        if isInsideTable(head) {
            // collapsed caret in a cell: text is in-place.
            editing { applyLeafReplace(globalFrom: selFrom, globalTo: selTo, text: text) }
            return
        }
        editing { applyReplace(globalFrom: selFrom, globalTo: selTo, text: text) }
    }

    func deleteBackward() {
        if markedRange != nil { commitMarkedText() }   // delete acts on committed text, not the composition
        guard !boxes.isEmpty else { return }
        if selFrom != selTo {
            editing { applySelectionReplace(globalFrom: selFrom, globalTo: selTo, text: "") }
            return
        }
        if isInsideTable(head) {
            guard let active = activeStack(at: head) else { return }
            if active.local > 0 {
                editing { applyLeafReplace(globalFrom: head - 1, globalTo: head, text: "") }
            } else if active.index > 0 {
                editing { mergeParagraphs(in: active.stack, upperIndex: active.index - 1) }
            } else {
                // Caret at the cell's first-paragraph start: move WITHOUT deleting to the previous text
                // position — the previous cell's end (row-major), or, at the table's FIRST cell, the end
                // of the block before the table. No-op only when the table is the document's first block
                // (nothing before — like Backspace at the very start of a document).
                let prev = prevTextPosition(before: head)
                if prev != head { setCaret(global: prev) }
            }
            return
        }
        // Gap before an image → delete that image (also the path for a tap-selected image atom, whose
        // hidden caret is parked at the gap). Clear the now-stale image selection after.
        if let img = imageBox(atGap: head), let i = boxIndex(of: img) {
            editing { deleteImageBox(at: i) }
            clearImageSelection()
            return
        }
        guard let pos = resolveBox(at: head) else { return }
        if pos.box is ImageBlockBox, pos.local == 0 {        // caption start → delete the image
            editing { deleteImageBox(at: pos.index) }
        } else if pos.local > 0 {
            editing { applyReplace(globalFrom: head - 1, globalTo: head, text: "") }
        } else if pos.index > 0, boxes[pos.index - 1] is ImageBlockBox {
            editing { deleteImageBox(at: pos.index - 1) }     // start of a block after an image
        } else if pos.index > 0, boxes[pos.index - 1] is TableBlockBox {
            // Start of a block after a table → move WITHOUT deleting into the table's last cell (no merge
            // across the table boundary). Mirrors Backspace at a cell's first-paragraph start, which moves
            // to the block before. Avoids parking the caret on the table's degenerate node-start boundary.
            let prev = prevTextPosition(before: head)
            if prev != head { setCaret(global: prev) }
        } else if pos.index > 0 {
            let prev = boxes[pos.index - 1]
            let from = prev.textStart + prev.textLength
            editing { applyReplace(globalFrom: from, globalTo: head, text: "") }
        }
    }
}
#endif
